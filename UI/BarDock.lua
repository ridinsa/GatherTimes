-- BarDock.lua : makes room for the minimized bar, like Titan Panel does.
-- The bar (UI\MiniBar.lua) is a full-width strip at the top of the screen.  While it is shown, the game's own
-- top-anchored frames (player, target, minimap, buffs ...) are moved down by the height of the bar; when the bar
-- goes away they go back to where they were.
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
-- GatherTimesDB._ui.barDock = false turns the whole thing off (the bar then just covers the top of the screen).
local ADDON, GT = ...

local Dock = {}
GT.BarDock = Dock

-- game frames that sit at the top of the screen (a name the client does not have is skipped)
local NAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PartyMemberFrame1",
    "MinimapCluster", "BuffFrame", "TemporaryEnchantFrame",
    "UIWidgetTopCenterContainerFrame", "WorldStateAlwaysUpFrame", "ObjectiveTrackerFrame",
    "QuestWatchFrame", "WatchFrame", "DurabilityFrame", "TicketStatusFrame",
}

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
    local px = want and (bar:GetHeight() or 0) * bar:GetEffectiveScale() or 0

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
                    local sh = Shifted(frame, base, px)
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
