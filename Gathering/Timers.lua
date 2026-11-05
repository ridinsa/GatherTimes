-- Timers.lua
local addonName, GT = ...
local READY_LINGER = GT.READY_LINGER
local UI = GT.UI
local nodes = GT.nodes
local order = GT.order

GT.UpdateList = function() end
local errorShown = {}

-- A timer whose update raises an error is QUARANTINED: it is left alone for a while (its map label is removed,
-- its saved data is kept) instead of failing again every second.  It is tried again after QUARANTINE_FIRST
-- seconds, then after twice as long each time it fails again, up to QUARANTINE_MAX.  The first success lifts
-- the quarantine.  Runtime only (weak keys, never saved): a /reload gives every timer a fresh start.
local QUARANTINE_FIRST, QUARANTINE_MAX = 30, 300
local quarantine = setmetatable({}, { __mode = "k" })     -- node -> { fails = n, retryAt = server time }

local timerProfile
local function ProfileClock()
    return debugprofilestop and debugprofilestop() or GetTime() * 1000
end

local function ProfileBegin()
    if timerProfile and timerProfile.active then return ProfileClock() end
end

local function ProfileEnd(name, started)
    if not started or not (timerProfile and timerProfile.active) then return end
    local elapsed = ProfileClock() - started
    local stat = timerProfile.stats[name]
    if not stat then stat = { total = 0, calls = 0, max = 0 }; timerProfile.stats[name] = stat end
    stat.total = stat.total + elapsed
    stat.calls = stat.calls + 1
    if elapsed > stat.max then stat.max = elapsed end
end

local PROFILE_PHASES = {
    "total", "timer nodes", "empty-node detection", "proximity check", "group normalization",
    "route suggestion", "spawn pins", "list window",
}

function GT.ProfileTimerLoop(action)
    action = (action or ""):lower()
    if action == "start" then
        timerProfile = {
            startedAt = GetTime(),
            memoryAt = collectgarbage("count"),
            stats = {},
            nodes = 0,
            quarantined = 0,
            active = true,
        }
        GT.cprint("Timer-loop profiling started. Leave the addon idle, then use /gt profile report.")
        return
    end
    if action == "stop" then
        if not timerProfile then GT.cprint("Timer-loop profiling is not active."); return end
        timerProfile.stoppedAt = GetTime()
        timerProfile.memoryAtStop = collectgarbage("count")
        timerProfile.active = false
        GT.cprint("Timer-loop profiling stopped. Use /gt profile report to view the captured results.")
        return
    end
    if action ~= "report" then
        GT.cprint("/gt profile start | report | stop")
        return
    end
    if not timerProfile then GT.cprint("No timer-loop profile. Use /gt profile start first."); return end

    local p = timerProfile
    local elapsed = math.max(0, (p.stoppedAt or GetTime()) - p.startedAt)
    local memoryDelta = (p.memoryAtStop or collectgarbage("count")) - p.memoryAt
    GT.cprint(string.format("Timer-loop profile: %.1f s, %d node visits (%d quarantined skips), Lua heap %+0.1f KB",
        elapsed, p.nodes, p.quarantined, memoryDelta))
    for _, name in ipairs(PROFILE_PHASES) do
        local stat = p.stats[name]
        if stat then
            GT.cprint(string.format("  %s: %.2f ms total, %.3f ms avg, %.3f ms max (%d calls)",
                name, stat.total, stat.total / stat.calls, stat.max, stat.calls))
        end
    end
end

function GT.QuarantinedTimers()
    local n = 0
    for _ in pairs(quarantine) do n = n + 1 end
    return n
end

function GT.ClearQuarantine()
    for k in pairs(quarantine) do quarantine[k] = nil end
end

-- one line of timer text ("Peacebloom 9:55")  -- file level on purpose: a closure created inside
-- ProcessNode would be new garbage for every node, every second
local function TimerLine(nodeDef, n, now)
    local l = nodeDef.timer - (now - n.time)
    if l <= 0 then return string.format("%s |cff00ff00READY|r", nodeDef.prefix) end
    return string.format("%s %s%d:%02d", nodeDef.prefix, n.est and "~" or "",
        math.floor(l / 60), math.floor(l % 60))
end

local function ProcessNode(nodeKey, nodeDef, list, i, now, curMap)
    local node = list[i]
    local c = GT.cfg()
    local left = nodeDef.timer - (now - node.time)
    node._left = left
    if left <= -(c.readyLinger or READY_LINGER) then
        GT.RemoveTextTimer(node)
        table.remove(list, i)
        return
    end
    if not GT.IsEnabled(nodeKey) then
        GT.RemoveTextTimer(node)
        return
    end
    node._dist = GT.GetDistance(node)
    if c.leaveAlert and left > 0 and not node._leaveAlerted and (UI.lastLeave or 0) + 20 < now then
        local cx, cy = node.x, node.y
        local sp = c.groupMode and GT.SpawnOfNode(nodeKey, node)
        if sp then
            local res = GT.ComputeGroups(nodeKey, sp.mapID)
            local g = res.of[sp] and res.groups[res.of[sp]]
            if g then cx, cy = GT.GroupCentroid(g) end
        end
        local d = GT.GetDistanceXY(node.mapID, cx, cy)
        if d and d > 40 and d <= c.routeRange and left <= d / c.speed + c.leaveEarly then
            node._leaveAlerted = true
            if GT.CooldownOK("leave", nodeKey, node, 240) then     -- once per group
            UI.lastLeave = now
            -- the "leave now" ping only plays for node types that have a sound set (not "None")
            local snd = GT.SOUNDS[c.sounds[nodeKey] or 1]
            if snd and snd.id ~= 0 then pcall(PlaySound, 3175, "Master") end
            if c.screenAlert then
                local col = GT.Col(nodeKey)
                local gl = GT.GroupLabelForNode(nodeKey, node)
                GT.ShowScreenAlert(GT.TRF("Leave now: %s%s ready in %d:%02d",
                    nodeDef.label, gl and (" " .. gl) or "",
                    math.floor(left / 60), math.floor(left % 60)),
                    col[1], col[2], col[3], GT.NodeIcon(nodeKey), GT.TRF("%d yd", math.floor(d)))
            end
            end
        end
    end
    -- labels follow the main dropdown (picked item / all checked); alerts above do not
    local visible = GT.IsShown(nodeKey) and ((not c.zoneOnly) or node.mapID == curMap)
    if left <= 0 then
        if not node._hasAlerted then
            local r = c.alertRange
            if node.time + nodeDef.timer <= (GT.loginServerTime or 0) then
                node._hasAlerted = true          -- ran out before login: still shown as READY, but no alert / sound
            elseif GT.CanReadyAlert(nodeKey, node) and (r <= 0 or (node._dist and node._dist <= r)) then
                node._hasAlerted = true
                GT.FireReadyAlert(nodeKey, nodeDef, node)
            end
        end
    else
        node._hasAlerted = nil
    end
    local hideSibling = c.groupMode and node._primary == false
    if visible and not hideSibling then
        if not node._miniFrame then GT.CreateTextTimer(node, nodeKey) end
        local txt = TimerLine(nodeDef, node, now)
        if c.groupMode and node._peers then
            for _, peer in ipairs(node._peers) do txt = txt .. "\n" .. TimerLine(nodeDef, peer, now) end
        end
        local gl = GT.GroupLabelForNode(nodeKey, node)
        if gl then txt = gl .. "\n" .. txt end
        -- only touch a label when its text really changed; the world-map label only while the map is open
        if node._miniFrame and node._txtMini ~= txt then
            node._miniFrame.label:SetText(txt); node._txtMini = txt
        end
        if node._worldFrame and node._txtWorld ~= txt and WorldMapFrame and WorldMapFrame:IsShown() then
            node._worldFrame.label:SetText(txt); node._txtWorld = txt
        end
    else
        GT.RemoveTextTimer(node)
    end
end

function GT.RefreshTimers()
    local totalStart = ProfileBegin()
    local now = GetServerTime()
    local curMap = C_Map.GetBestMapForUnit("player")
    local nodesStart = ProfileBegin()
    for _, nodeKey in ipairs(order) do
        local nodeDef = nodes[nodeKey]
        local list = GatherTimesDB[nodeKey]
        for i = #list, 1, -1 do
            local node = list[i]
            local q = node ~= nil and quarantine[node]
            if timerProfile and timerProfile.active then
                if q and now < q.retryAt then
                    timerProfile.quarantined = timerProfile.quarantined + 1
                else
                    timerProfile.nodes = timerProfile.nodes + 1
                end
            end
            if not q or now >= q.retryAt then
                local ok, err = pcall(ProcessNode, nodeKey, nodeDef, list, i, now, curMap)
                if ok then
                    if q then quarantine[node] = nil end             -- it works again
                else
                    -- set this timer aside but keep its data: one bad entry must not wipe the saved timers,
                    -- and it must not fail again every second until the cause is fixed
                    if node ~= nil then
                        local fails = (q and q.fails or 0) + 1
                        quarantine[node] = { fails = fails,
                            retryAt = now + math.min(QUARANTINE_MAX, QUARANTINE_FIRST * 2 ^ (fails - 1)) }
                    end
                    pcall(GT.RemoveTextTimer, node)
                    if not errorShown[nodeKey] then
                        errorShown[nodeKey] = true
                        GT.ReportError("node " .. nodeKey .. " (timer set aside, retried later)", err)
                    end
                end
            end
        end
    end
    ProfileEnd("timer nodes", nodesStart)
    local dwellStart = ProfileBegin()
    local dok, derr = pcall(GT.CheckDwell)
    if not dok and not errorShown._dwell then
        errorShown._dwell = true
        GT.ReportError("empty-node detection", derr)
    end
    ProfileEnd("empty-node detection", dwellStart)
    local proximityStart = ProfileBegin()
    local cok, cerr = pcall(GT.CheckProximity)
    if not cok and not errorShown._chime then
        errorShown._chime = true
        GT.ReportError("proximity sound", cerr)
    end
    ProfileEnd("proximity check", proximityStart)
    GT.routeTick = GT.routeTick + 1
    if GT.cfg().groupMode and GT.routeTick % 3 == 0 then
        local normalizeStart = ProfileBegin()
        pcall(GT.NormalizeGroupTimers)
        ProfileEnd("group normalization", normalizeStart)
    end
    if GT.routeTick % 2 == 0 then
        local routeStart = ProfileBegin()
        local rok, rerr = pcall(GT.ComputeNext)
        if not rok and not errorShown._route then
            errorShown._route = true
            GT.ReportError("route suggestion", rerr)
        end
        ProfileEnd("route suggestion", routeStart)
    end
    if GT.routeTick % 3 == 0 then
        local pinsStart = ProfileBegin()
        local pok, perr = pcall(GT.SyncSpawnPins)
        if not pok and not errorShown._pins then
            errorShown._pins = true
            GT.ReportError("spawn dots", perr)
        end
        ProfileEnd("spawn pins", pinsStart)
    end
    local listStart = ProfileBegin()
    local ok, err = pcall(GT.UpdateList)
    if not ok and not errorShown._list then
        errorShown._list = true
        GT.ReportError("list window", err)
    end
    ProfileEnd("list window", listStart)
    ProfileEnd("total", totalStart)
end

-- ============================================================
-- STATS + HEALTH
-- ============================================================
