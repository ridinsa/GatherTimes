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
--   * The player and target frames (the pet frame follows the player frame) only move down by the main bar, so they sit
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
local SAME_LINE = { PlayerFrame = true, TargetFrame = true }

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
local function ClearOfPanel(frame, panel)
    local fl, fr = frame:GetLeft(), frame:GetRight()
    local pl, pr = panel:GetLeft(), panel:GetRight()
    if not (fl and fr and pl and pr) then return false end
    local fs, ps = frame:GetEffectiveScale() or 1, panel:GetEffectiveScale() or 1
    local margin = 60                  -- the panel's width changes with the fps text, so keep some room
    return fr * fs < pl * ps - margin or fl * fs > pr * ps + margin
end

local function Mark() if not guard then dirty = true end end

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
    local barPx = want and (bar:GetHeight() or 0) * bar:GetEffectiveScale() or 0
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
                    if sameLine and SAME_LINE[name] and ClearOfPanel(frame, bar.secondary) then framePx = barPx end
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
ev:SetScript("OnUpdate", function()
    if dirty and GT.bar and GT.bar:IsShown() then Dock.Sync() end
end)
