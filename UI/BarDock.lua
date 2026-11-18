-- BarDock.lua : makes room for the minimized bar, like Titan Panel does.
-- The bar (UI\MiniBar.lua) is a full-width strip at the top of the screen with a smaller panel below it.  While
-- they are shown, the game's own top-anchored frames (player, target, minimap, buffs ...) are moved down by their
-- combined height; when they go away they go back to where they were.
--
-- How a frame is handled:
--   * Only a frame whose points are ALL anchored to the top of the screen (UIParent, a TOP* point) is moved. A frame
--     anchored to another frame (the buffs next to the minimap, say) simply follows that frame.
--   * What the game had is remembered (orig) together with what this module set (shifted).  When the game re-anchors
--     the frame by itself (a post-hook on SetPoint and on UIParent_ManageFramePositions marks it dirty), the frame no
--     longer matches "shifted", so the new position is taken as the game's and shifted again.  When the bar goes away
--     a frame that still matches "shifted" is put back to orig; a frame the game has moved meanwhile is left alone.
--   * Nothing is moved during combat (the player and target frames are protected); it is done when combat ends.
--   * The frames are put back at logout / reload, because a frame the player moved with the mouse is saved by the
--     game with the position it has at that moment.
--   * The player, target and buff frames (the pet frame follows the player frame) only move down by the main bar, so they sit
--     level with the fps / ping panel instead of below it - as long as that panel is not in their way sideways. If it
--     is (small screen, big frames), they move down by both bars like the rest.
-- GatherTimesDB._ui.barDock = false turns the whole thing off (the bar then just covers the top of the screen).
-- GatherTimesDB._ui.barDockSameLine = false puts the player and target frames below the fps / ping panel again.
local _, GT = ...

local Dock = {}
GT.BarDock = Dock

-- game frames that sit at the top of the screen (a name the client does not have is skipped)
local NAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PartyMemberFrame1",
    "MinimapCluster", "BuffFrame", "TemporaryEnchantFrame",
    "UIWidgetTopCenterContainerFrame", "WorldStateAlwaysUpFrame", "ObjectiveTrackerFrame",
    "QuestWatchFrame", "WatchFrame", "DurabilityFrame", "TicketStatusFrame",
}

-- these sit level with the fps / ping panel (they only clear the main bar) when there is room beside the panel
-- The buffs are anchored to the minimap cluster, not to the screen, so they follow it: the cluster is what has to sit on the
-- same line (moving BuffFrame itself does nothing, it is not anchored to the top of the screen).
local SAME_LINE = { PlayerFrame = true, TargetFrame = true, BuffFrame = true, MinimapCluster = true }

local state = {}                       -- frame -> { orig = points, shifted = points }
local hooked = {}
local guard, dirty, pending, errored = false, false, false, false

local function Norm(rel) if rel == nil then return UIParent end return rel end

local function Snapshot(frame)
    local t = {}
    for i = 1, frame:GetNumPoints() do
        local p, rel, rp, x, y = frame:GetPoint(i)
        t[i] = { p, Norm(rel), rp, x or 0, y or 0 }
    end
    return t
end

local function Same(a, b)
    if not (a and b) or #a ~= #b then return false end
    for i = 1, #a do
        local u, v = a[i], b[i]
        if u[1] ~= v[1] or u[2] ~= v[2] or u[3] ~= v[3]
            or math.abs(u[4] - v[4]) > 0.01 or math.abs(u[5] - v[5]) > 0.01 then return false end
    end
    return true
end

local function Apply(frame, pts)
    guard = true
    local ok, err = pcall(function()
        frame:ClearAllPoints()
        for _, pt in ipairs(pts) do frame:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
    end)
    guard = false
    if not ok then error(err, 0) end
end

-- the same points moved down by px screen pixels (nil when the frame is not anchored to the top of the screen)
local function Shifted(frame, pts, px)
    if #pts == 0 then return nil end
    local d = px / math.max(0.01, frame:GetEffectiveScale() or 1)     -- offsets are in the frame's own units
    local out = {}
    for i, pt in ipairs(pts) do
        local rp = pt[3]
        if pt[2] ~= UIParent or type(rp) ~= "string" or not rp:find("TOP", 1, true) then return nil end
        out[i] = { pt[1], pt[2], rp, pt[4], pt[5] - d }
    end
    return out
end

-- Is the frame clear of the fps / ping panel sideways (so it can sit on the same line as the panel)? Screen pixels.
-- When the frame has no position yet, say no: it then gets the safe, lower place.
local function ClearOfPanel(frame, panel, margin)
    local fl, fr = frame:GetLeft(), frame:GetRight()
    local pl, pr = panel:GetLeft(), panel:GetRight()
    if not (fl and fr and pl and pr) then return false end
    local fs, ps = frame:GetEffectiveScale() or 1, panel:GetEffectiveScale() or 1
    margin = margin or 60              -- the panel's width changes with the fps text, so keep some room
    return fr * fs < pl * ps - margin or fl * fs > pr * ps + margin
end

-- a frame moved: sync once, 0.1 s later (one timer at a time), instead of checking the flag every frame
local flushScheduled = false
local function Flush()
    flushScheduled = false
    if dirty and GT.bar and GT.bar:IsShown() then Dock.Sync() end
end
local function Mark()
    if guard then return end
    dirty = true
    if not flushScheduled then
        flushScheduled = true
        C_Timer.After(0.1, Flush)
    end
end

local function Hook(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    pcall(hooksecurefunc, frame, "SetPoint", Mark)
end

-- Bring every frame in line with the bar: shifted while the bar is shown, back to normal when it is not.
-- off = true forces "back to normal" (logout).
function Dock.Sync(off)
    dirty = false
    if InCombatLockdown and InCombatLockdown() then pending = true; return end
    pending = false
    local ui = GatherTimesDB and GatherTimesDB._ui
    local bar = GT.bar
    local want = not off and bar and bar:IsShown() and not (ui and ui.barDock == false)
    local secondaryHeight = bar and bar.secondary and bar.secondary:IsShown()
        and (bar.secondary:GetHeight() or 0) * bar.secondary:GetEffectiveScale() or 0
    local topOffPx = want and ((ui and ui.barTopOffset) or 0) * (UIParent:GetEffectiveScale() or 1) or 0   -- the bar's top offset
    local barPx = want and (bar:GetHeight() or 0) * bar:GetEffectiveScale() + topOffPx or 0
    local px = want and (barPx + secondaryHeight) or 0
    local sameLine = want and secondaryHeight > 0 and not (ui and ui.barDockSameLine == false)

    if want and not Dock.hookedManager and type(_G.UIParent_ManageFramePositions) == "function" then
        Dock.hookedManager = true
        pcall(hooksecurefunc, "UIParent_ManageFramePositions", Mark)
    end

    for _, name in ipairs(NAMES) do
        local frame = _G[name]
        if type(frame) == "table" and frame.GetNumPoints and frame.SetPoint and frame:GetNumPoints() > 0 then
            local ok, err = pcall(function()
                local rec, cur = state[frame], Snapshot(frame)
                local untouched = rec and Same(cur, rec.shifted)
                if want then
                    Hook(frame)
                    local base = untouched and rec.orig or cur         -- what the game has, not what we set
                    local framePx = px
                    -- the Buff frame sits at the top right and its icons are narrow, so it only needs a small gap from the panel
                    -- the Buff frame stays level with the bar by default (its icons sit at its right edge, so a wide
                    -- fps / ping line does not really cover them). Minimize > Bar can turn that off.
                    local buffsAlways = not (ui and ui.buffAlwaysSameLine == false)
                    local level = (name == "BuffFrame" and buffsAlways) or ClearOfPanel(frame, bar.secondary)
                    if sameLine and SAME_LINE[name] and level then framePx = barPx end
                    local sh = Shifted(frame, base, framePx)
                    if sh then
                        if not (untouched and Same(sh, rec.shifted)) then Apply(frame, sh) end
                        state[frame] = { orig = base, shifted = sh }
                    else
                        if untouched then Apply(frame, rec.orig) end
                        state[frame] = nil
                    end
                else
                    if untouched then Apply(frame, rec.orig) end
                    state[frame] = nil
                end
            end)
            if not ok and not errored then
                errored = true
                GT.ReportError("bar dock (" .. name .. ")", err)
            end
        end
    end
end

-- /gt dock debug : where every frame the dock knows is anchored, and what the dock did with it (to find out why one does not move)
local function Nm(f) return f and (f.GetName and f:GetName()) or tostring(f) end
local function Pts(f)
    local out = {}
    for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do
        local p, rel, rp, x, y = f:GetPoint(i)
        out[#out + 1] = string.format("%s>%s:%s %+.0f,%+.0f", p, Nm(rel or UIParent), tostring(rp), x or 0, y or 0)
    end
    return table.concat(out, " ; ")
end
function Dock.Debug()
    local bar = GT.bar
    GT.cprint(string.format("dock: bar shown=%s  secondary shown=%s  barDock=%s  in combat=%s", tostring(bar and bar:IsShown()),
        tostring(bar and bar.secondary and bar.secondary:IsShown()), tostring(not (GatherTimesDB._ui.barDock == false)), tostring(InCombatLockdown())))
    for _, name in ipairs(NAMES) do
        local f = _G[name]
        if type(f) == "table" and f.GetNumPoints then
            local clear = bar and bar.secondary and ClearOfPanel(f, bar.secondary)
            GT.cprint(string.format("%s: top=%s moved=%s sameLineFrame=%s clearOfPanel=%s protected=%s parent=%s", name,
                tostring(f:GetTop() and math.floor(f:GetTop() * f:GetEffectiveScale() + 0.5)), tostring(state[f] ~= nil),
                tostring(SAME_LINE[name] or false), tostring(clear), tostring(f.IsProtected and f:IsProtected()), Nm(f:GetParent())))
            GT.cprint("    " .. Pts(f))
        else
            GT.cprint(name .. ": (none)")
        end
    end
    -- the chain behind the buffs: what the buff frame hangs on
    local f, depth = _G.BuffFrame, 0
    while f and depth < 6 do
        local _, rel = f:GetPoint(1)
        GT.cprint(string.format("buff chain %d: %s  top=%s  points: %s", depth, Nm(f),
            tostring(f:GetTop() and math.floor(f:GetTop() * f:GetEffectiveScale() + 0.5)), Pts(f)))
        f, depth = rel, depth + 1
        if f == UIParent or f == nil then break end
    end
end

-- events and the once-per-frame check for frames the game re-anchored
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
pcall(ev.RegisterEvent, ev, "UI_SCALE_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then Dock.Sync(true)
    elseif GT.bar and GT.bar:IsShown() or pending then Dock.Sync() end
end)
pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")   -- leaving combat: sync what was held back (pending)
