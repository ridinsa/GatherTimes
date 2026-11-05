-- TomTom.lua
local addonName, GT = ...
local UI = GT.UI
local nodes = GT.nodes
local order = GT.order

do
    local wp, wpKey, aimWp
    local function Have()
        return GT.cfg().tomtom and TomTom and TomTom.AddWaypoint and TomTom.RemoveWaypoint
    end
    local function Add(mapID, x, y, title)
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y,
            { title = title, persistent = false, minimap = true, world = true,
              crazy = true, from = "GatherTimes" })
        if ok then return uid end
        return nil
    end
    local function Remove(uid)
        if uid and TomTom and TomTom.RemoveWaypoint then
            pcall(TomTom.RemoveWaypoint, TomTom, uid)
        end
    end
    function UI.ClearTomTom()
        Remove(wp)
        wp, wpKey = nil, nil
    end
    function UI.TomTomActive() return wp ~= nil end
    local suppressKey                       -- route target the user dismissed (stays hidden until the target changes)
    local function TargetKey(t) return string.format("%s:%d:%.4f:%.4f", t.key, t.mapID, t.x, t.y) end
    function UI.DismissRouteWaypoint()
        local t = GT.routeTarget
        if t and t.mapID then suppressKey = TargetKey(t) end
        UI.ClearTomTom()
    end
    function UI.UpdateTomTom()
        if not Have() or not GT.routeTarget or not GT.routeTarget.mapID then
            if wp then UI.ClearTomTom() end
            return
        end
        local t = GT.routeTarget
        local key = TargetKey(t)
        if suppressKey then
            if key == suppressKey then return end        -- dismissed: do not bring it back
            suppressKey = nil                            -- a different target: show it again
        end
        if key == wpKey and wp then return end
        Remove(wp)
        local status = (GT.TargetStatus(t):gsub("|c%x%x%x%x%x%x%x%x", ""))
        status = (status:gsub("|r", ""))
        wp = Add(t.mapID, t.x, t.y, nodes[t.key].label .. " - " .. status)
        wpKey = key
    end
    function UI.AimWaypointOn() return aimWp ~= nil end
    function UI.ClearAimWaypoint()
        Remove(aimWp)
        aimWp = nil
    end
    function UI.SetAimWaypoint()
        if not Have() then GT.cprint(GT.TR("TomTom is not installed, or the TomTom option is off.")); return end
        local a = UI.aimTarget
        if not a then GT.cprint(GT.TR("No group to aim at here.")); return end
        Remove(aimWp)
        aimWp = Add(a.mapID, a.x, a.y, a.title)
        if aimWp then GT.cprint(GT.TR("TomTom waypoint set:") .. " " .. a.title)
        else GT.cprint(GT.TR("TomTom did not accept the waypoint.")) end
    end
    function UI.TomTomAvailable() return Have() and true or false end
    function UI.ClearAllTomTomWaypoints()
        Remove(wp)
        wp, wpKey = nil, nil
        Remove(aimWp)
        aimWp = nil
        UI.StopTomTomAutoNearest()
    end

    local nearestWp, nearestWpKey, nearestTimer
    local function ScheduleNearest()
        if nearestTimer then nearestTimer:Cancel() end        -- never two loops at once
        nearestTimer = C_Timer.NewTimer(5, UI.UpdateTomTomNearest)
    end
    function UI.UpdateTomTomNearest()
        if nearestTimer then nearestTimer:Cancel(); nearestTimer = nil end   -- called directly (login, checkbox): drop the pending tick
        if not Have() then GT.dprint("Auto-nearest: TomTom not available"); return end
        if not GT.cfg().tomTomAutoNearest then GT.dprint("Auto-nearest: disabled in config"); return end
        local curMap = C_Map.GetBestMapForUnit("player")
        if not curMap then ScheduleNearest() return end          -- loading screen: try again shortly
        local best, bestD, bestKey
        local checked = 0
        for _, key in ipairs(order) do
            if GT.IsEnabled(key) then
                for _, sp in ipairs(GT.SpawnsOnMap(key, curMap)) do
                    checked = checked + 1
                    local d = GT.GetDistance(sp)
                    if d and d <= GT.cfg().routeRange and (not bestD or d < bestD) then
                        best, bestD, bestKey = sp, d, key
                    end
                end
            end
        end
        GT.dprint("Auto-nearest: checked " .. checked .. " spawns, best=" .. (bestKey or "none")
            .. (bestD and (" " .. math.floor(bestD) .. "yd") or ""))
        if best then
            local wpKeyNew = string.format("%s:%d:%.4f:%.4f", bestKey, best.mapID, best.x, best.y)
            if not (nearestWp and wpKeyNew == nearestWpKey) then   -- same target as last time: leave the arrow alone
                Remove(nearestWp)
                nearestWp = Add(best.mapID, best.x, best.y, nodes[bestKey].label .. " (nearest)")
                nearestWpKey = nearestWp and wpKeyNew or nil
                GT.dprint("Auto-nearest: waypoint " .. (nearestWp and "created" or "FAILED"))
            end
        end
        ScheduleNearest()
    end
    function UI.StopTomTomAutoNearest()
        if nearestTimer then
            nearestTimer:Cancel()
            nearestTimer = nil
        end
        Remove(nearestWp)
        nearestWp, nearestWpKey = nil, nil
    end
end

-- ============================================================
-- TIMER ENGINE
-- ============================================================

-- Remove every waypoint arrow this addon created: the one from clicking a Timers row, the
-- "nearest node" ones, and the automatic route waypoint (which returns only for a NEW target).
function GT.ClearWaypoints()
    if TomTom and TomTom.RemoveWaypoint then
        if GT.listWp then pcall(TomTom.RemoveWaypoint, TomTom, GT.listWp) end
        if GT.navWp then pcall(TomTom.RemoveWaypoint, TomTom, GT.navWp) end
    end
    GT.listWp, GT.navWp = nil, nil
    pcall(GT.UI.DismissRouteWaypoint)
    pcall(GT.UI.StopTomTomAutoNearest)
    if GT.cfg().tomTomAutoNearest then
        GT.cfg().tomTomAutoNearest = false               -- otherwise it would put the arrow back
        for _, fn in ipairs(GT.uiRefresh) do pcall(fn) end   -- refresh the Nav checkbox
    end
    GT.PlaceArrow()
end
