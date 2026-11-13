-- Route.lua
local addonName, GT = ...
local HBD = GT.HBD
local HBDPins = GT.HBDPins
local MAX_ROUTE_COST = GT.MAX_ROUTE_COST
local UI = GT.UI
local UNCHECKED_PENALTY = GT.UNCHECKED_PENALTY
local nodes = GT.nodes
local order = GT.order
local visitedSid = GT.visitedSid

-- ============================================================
-- ROUTE SUGGESTION
-- ============================================================
-- Candidate tables are reused: a new table for every group every two seconds was constant garbage.
-- Two alternating buffers, because last run's winner (GT.routeTarget) is still being read during this run.
local candLists, candPools, candFlip, candN = { {}, {} }, { {}, {} }, 1, 0
local scratchEntries = {}
local function NewCand(ref, kind, key, mapID, x, y, left, dist, cost)
    candN = candN + 1
    local pool = candPools[candFlip]
    local cd = pool[candN]
    if not cd then cd = {}; pool[candN] = cd end
    cd.ref, cd.kind, cd.key, cd.mapID, cd.x, cd.y, cd.left, cd.dist, cd.cost = ref, kind, key, mapID, x, y, left, dist, cost
    cd.wx, cd.wy, cd.inst = nil, nil, nil
    local speed = GT.cfg().speed
    cd.eta = (dist and speed and speed > 0) and (dist / speed) or nil     -- seconds to get there (TargetStatus: "ready on arrival")
    return cd
end

local function InventoryCost(key, c)
    if not c.routeLowStock or type(GetItemCount) ~= "function" then return 0 end
    local def = nodes[key]
    local itemID = def.countId or def.id
    local count = GetItemCount(itemID) or 0
    return math.min(120, count / c.routeStockTarget * 90)
end

-- A timer that is still running: the spot may well be taken by someone else by the time it is ready and you are there.
-- Spots that were often found taken (Taken % in the Timing panel) get the same penalty the ready ones already have.
local function RunningPenalty(node)
    local sp = node and node.sid and GT.spawnBySid[node.sid]
    return sp and GT.ContestedPenalty(sp) or 0
end

local function GroupCandidates(key, curMap, c, cands)
    local res = GT.ComputeGroups(key, curMap)
    local now = GetServerTime()
    local def = nodes[key]
    for _, group in ipairs(res.groups) do
        local list, cap = GT.GroupEntries(key, group[1], scratchEntries)
        local ready, soonest
        for _, n in ipairs(list) do
            if n._left and n._left <= 0 and not ready then ready = n end
            if not soonest or n.time < soonest.time then soonest = n end
        end
        local running = (not ready) and soonest ~= nil and #list >= cap
        local entry = running and soonest or ready
        if running then
            local cx, cy = GT.GroupCentroid(group)
            local d = GT.GetDistanceXY(entry.mapID, cx, cy)
            if entry._left and d and d <= c.routeRange then
                local travel = d / c.speed
                local cost = travel + math.max(0, entry._left - travel) - GT.TransitionBonus(entry.sid)
                    + InventoryCost(key, c) + RunningPenalty(entry)
                cands[#cands + 1] = NewCand(entry, "timer", key, entry.mapID, cx, cy, entry._left, d, cost)
            end
        elseif entry or c.includeUnchecked then
            local readyAt = entry and (entry.time + def.timer) or (now - def.timer)
            local bestSp, bestD
            for _, sp in ipairs(group) do
                local v = visitedSid[sp.sid]
                if not (v and v > readyAt) then
                    local d = GT.GetDistance(sp)
                    if d and d > 12 and (not bestD or d < bestD) then bestSp, bestD = sp, d end
                end
            end
            if bestSp and bestD <= c.routeRange then
                local cost = bestD / c.speed + (entry and 0 or UNCHECKED_PENALTY)
                    + GT.ContestedPenalty(bestSp) - GT.TransitionBonus(bestSp.sid) + InventoryCost(key, c)
                cands[#cands + 1] = NewCand(entry or bestSp, entry and "timer" or "spawn", key,
                    bestSp.mapID, bestSp.x, bestSp.y, entry and entry._left or nil, bestD, cost)
            end
        end
    end
end

function GT.ComputeNext()
    -- A route you planned (Nav > Build route) owns the target until it is finished or cleared; the automatic
    -- suggestion below would replace the current step within two seconds.
    local ro = UI.RouteOptimizer
    if ro and ro:IsActive() then
        ro:UpdateProgress()
        return
    end
    local c = GT.cfg()
    local curMap = C_Map.GetBestMapForUnit("player")
    if not curMap then
        -- loading screen / unmapped zone: no suggestion (ComputeGroups needs a map).  The TomTom waypoint and the
        -- arrow follow GT.routeTarget, so they must be told too or the old one stays until the map is back.
        GT.routeTarget = nil
        if UI.UpdateTomTom then UI.UpdateTomTom() end
        return
    end
    candFlip = 3 - candFlip; candN = 0
    local cands = candLists[candFlip]
    for i = #cands, 1, -1 do cands[i] = nil end
    for _, key in ipairs(order) do
        if GT.IsEnabled(key) and c.groupMode then
            GroupCandidates(key, curMap, c, cands)
        elseif GT.IsEnabled(key) then
            for _, n in ipairs(GatherTimesDB[key]) do
                if n._left and n._dist and n._dist <= c.routeRange
                    and (not c.zoneOnly or n.mapID == curMap) then
                    local travel = n._dist / c.speed
                    local cost = travel + math.max(0, n._left - travel) - GT.TransitionBonus(n.sid)
                        + InventoryCost(key, c) + RunningPenalty(n)
                    cands[#cands + 1] = NewCand(n, "timer", key, n.mapID, n.x, n.y, n._left, n._dist, cost)
                end
            end
            if c.includeUnchecked then
                local tix = GT.BuildTimerIndex(key) or false         -- one index for all spots of this item
                for _, sp in ipairs(GT.SpawnsOnMap(key, curMap)) do
                    if not GT.HasActiveTimerAt(key, sp, tix) then
                        local d = GT.GetDistance(sp)
                        if d and d > 12 and d <= c.routeRange then
                            local cost = d / c.speed + UNCHECKED_PENALTY
                                + GT.ContestedPenalty(sp) - GT.TransitionBonus(sp.sid) + InventoryCost(key, c)
                            cands[#cands + 1] = NewCand(sp, "spawn", key, sp.mapID, sp.x, sp.y, nil, d, cost)
                        end
                    end
                end
            end
        end
    end
    local best
    for _, cd in ipairs(cands) do
        if not best or cd.cost < best.cost then best = cd end
    end
    if best and best.cost > MAX_ROUTE_COST then best = nil end
    if best and GT.routeTarget and GT.routeTarget.ref ~= best.ref then
        for _, cd in ipairs(cands) do
            if cd.ref == GT.routeTarget.ref and cd.cost <= best.cost + 5 then best = cd; break end
        end
    end
    if best and HBD then
        best.wx, best.wy, best.inst = HBD:GetWorldCoordinatesFromZone(best.x, best.y, best.mapID)
    end
    GT.routeTarget = best
    if UI.UpdateTomTom then UI.UpdateTomTom() end
end

-- ============================================================
-- ROUTE OPTIMIZER (open-path TSP: Nearest Neighbor + 2-opt on a distance matrix)
-- ============================================================
do
    local RouteOptimizer = {}
    local currentRoute = nil
    local currentStep = 1

    -- Every pair distance is computed ONCE into a matrix (world coordinates are converted once per node, not once per
    -- pair and per 2-opt step).  Nodes in different instances / continents, or without coordinates, are 1e9 apart.
    local function BuildMatrix(cands)
        local n = #cands
        local wx, wy, wi = {}, {}, {}
        for i = 1, n do
            local c = cands[i]
            if HBD then
                local ok, x, y, inst = pcall(HBD.GetWorldCoordinatesFromZone, HBD, c.x, c.y, c.mapID)
                if ok then wx[i], wy[i], wi[i] = x, y, inst end
            end
        end
        local M = {}
        for i = 1, n do M[i] = {} end
        for i = 1, n do
            M[i][i] = 0
            for j = i + 1, n do
                local d = 1e9
                if wx[i] and wx[j] and wi[i] == wi[j] then
                    local dx, dy = wx[i] - wx[j], wy[i] - wy[j]
                    d = math.sqrt(dx * dx + dy * dy)
                end
                M[i][j], M[j][i] = d, d
            end
        end
        return M
    end

    local function NearestNeighbor(M, n, startIdx)
        if n == 0 then return {} end
        local visited = {}
        local route = {}
        local cur = startIdx or 1
        for _ = 1, n do
            route[#route + 1] = cur
            visited[cur] = true
            local bestNext, bestDist = nil, 1e9
            local row = M[cur]
            for j = 1, n do
                if not visited[j] and row[j] < bestDist then bestDist = row[j]; bestNext = j end
            end
            if not bestNext then
                for j = 1, n do if not visited[j] then bestNext = j; break end end   -- only unreachable ones left
            end
            if not bestNext then break end
            cur = bestNext
        end
        return route
    end

    -- 2-opt on an OPEN path (the route is walked once, not as a loop): the first stop (nearest to you) stays first,
    -- the last stop has no edge back to the start.
    local function TwoOpt(M, route)
        local n = #route
        if n < 4 then return route end
        local improved = true
        local iterations = 0
        while improved and iterations < 5 do
            improved = false
            iterations = iterations + 1
            for i = 1, n - 2 do
                for j = i + 2, n do
                    local a, b, c = route[i], route[i + 1], route[j]
                    local d = route[j + 1]                       -- nil at the end of the path
                    local d1 = M[a][b] + (d and M[c][d] or 0)
                    local d2 = M[a][c] + (d and M[b][d] or 0)
                    if d2 < d1 * 0.95 then
                        local left, right = i + 1, j
                        while left < right do
                            route[left], route[right] = route[right], route[left]
                            left = left + 1
                            right = right - 1
                        end
                        improved = true
                    end
                end
            end
        end
        return route
    end

    local function TotalRouteDistance(M, route)
        local total = 0
        for i = 1, #route - 1 do
            total = total + M[route[i]][route[i + 1]]
        end
        return total
    end

    local function CollectRouteCandidates()
        local c = GT.cfg()
        local curMap = C_Map.GetBestMapForUnit("player")
        if not curMap then return {} end
        local now = GetServerTime()
        local candidates = {}
        for _, key in ipairs(order) do
            if GT.IsEnabled(key) and (c.routeItem == nil or c.routeItem == "all" or c.routeItem == key) then
                for _, n in ipairs(GatherTimesDB[key]) do
                    if n.mapID == curMap then
                        local left = n._left or (nodes[key].timer - (now - n.time))
                        local travel = GT.GetDistance(n)
                        local sid = n.sid
                        local readyAt = n.time + nodes[key].timer
                        local visited = sid and visitedSid[sid]
                        local unvisited = not (visited and visited > readyAt)
                        local include = unvisited and travel and travel <= c.routeRange
                        if include then
                            if c.routeOnlyReady then
                                include = left <= 0
                            else
                                include = left <= (c.routeTimeWindow or 0) + travel / c.speed
                            end
                        end
                        if include then
                            candidates[#candidates + 1] = {
                                node = n, key = key, left = left,
                                x = n.x, y = n.y, mapID = n.mapID,
                                stockCost = InventoryCost(key, c),
                            }
                        end
                    end
                end
            end
        end
        table.sort(candidates, function(a, b)
            if (a.left <= 0) ~= (b.left <= 0) then return a.left <= 0 end
            if c.routeLowStock and a.stockCost ~= b.stockCost then return a.stockCost < b.stockCost end
            return a.left < b.left
        end)
        if #candidates > c.routeMaxNodes then
            local limited = {}
            for i = 1, c.routeMaxNodes do limited[i] = candidates[i] end
            candidates = limited
        end
        return candidates
    end

    function RouteOptimizer:Plan()
        local candidates = CollectRouteCandidates()
        if #candidates < 2 then
            GT.cprint(GT.TRF("Route Optimizer: need at least 2 nodes. Found: %d", #candidates))
            currentRoute = nil
            return
        end
        local startIdx = 1
        local bestDist = 1e9
        for i, cand in ipairs(candidates) do
            local d = GT.GetDistance(cand)
            if d and d < bestDist then bestDist = d; startIdx = i end
        end
        local M = BuildMatrix(candidates)
        local route = NearestNeighbor(M, #candidates, startIdx)
        route = TwoOpt(M, route)
        local totalDist = TotalRouteDistance(M, route)
        currentRoute = { nodes = candidates, order = route, totalDist = totalDist, plannedAt = GetTime() }
        currentStep = 1
        GT.cprint(GT.TRF("Route planned: %d nodes, %.0f yd total distance", #candidates, totalDist))
        if GT.cfg().routeDrawMap then self:DrawOnMap() end
        if GT.cfg().routeAutoArrow then self:GoToStep(1) end
    end

    function RouteOptimizer:IsActive() return currentRoute ~= nil end

    function RouteOptimizer:GetGuidanceInfo()
        if not currentRoute then return nil end
        local idx = currentRoute.order[currentStep]
        local cand = idx and currentRoute.nodes[idx]
        if not cand then return nil end
        return {
            step = currentStep,
            total = #currentRoute.order,
            key = cand.key,
            distance = GT.GetDistance(cand),
            left = cand.left,
        }
    end

    function RouteOptimizer:UpdateProgress()
        if not currentRoute or not GT.cfg().routeAutoArrow then return end
        local idx = currentRoute.order[currentStep]
        local cand = idx and currentRoute.nodes[idx]
        if not cand then return end
        local distance = GT.GetDistance(cand)
        if distance and distance <= 12 then self:Next() end
    end

    function RouteOptimizer:GoToStep(step)
        if not currentRoute or step < 1 or step > #currentRoute.order then
            GT.routeTarget = nil
            return
        end
        currentStep = step
        local idx = currentRoute.order[step]
        local cand = currentRoute.nodes[idx]
        GT.routeTarget = {
            ref = cand.node, kind = "timer", key = cand.key,
            mapID = cand.mapID, x = cand.x, y = cand.y,
            left = cand.left, dist = GT.GetDistance(cand), cost = 0,
        }
        if HBD then
            pcall(function()
                GT.routeTarget.wx, GT.routeTarget.wy, GT.routeTarget.inst =
                    HBD:GetWorldCoordinatesFromZone(cand.x, cand.y, cand.mapID)
            end)
        end
        if UI.UpdateTomTom then UI.UpdateTomTom() end
        GT.cprint(GT.TRF("Route step %d/%d: %s (%d yd)",
            step, #currentRoute.order, nodes[cand.key].label, math.floor(GT.routeTarget.dist or 0)))
    end

    function RouteOptimizer:Next()
        if not currentRoute then
            GT.cprint(GT.TR("No route planned. Use Nav > Build route"))
            return
        end
        if currentStep >= #currentRoute.order then
            GT.cprint(GT.TR("Route complete! Use Nav > Build route for a new route."))
            currentRoute = nil
            GT.routeTarget = nil
            self:ClearMap()
            if UI.ClearTomTom then UI.ClearTomTom() end
            return
        end
        self:GoToStep(currentStep + 1)
    end

    function RouteOptimizer:Clear()
        currentRoute = nil
        currentStep = 1
        GT.routeTarget = nil
        self:ClearMap()
        if UI.ClearTomTom then UI.ClearTomTom() end
        GT.cprint(GT.TR("Route cleared."))
    end

    local routeMapPins, routePinPool = {}, {}

    -- map pins are REUSED (a frame can never be freed once created, so a new one per route step per
    -- "Build route" would pile up for the whole session)
    local function GetRoutePin()
        local pin = table.remove(routePinPool)
        if pin then return pin end
        pin = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
        pin:SetSize(12, 12)
        local tex = pin:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(1, 0.8, 0, 1)
        pin.num = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pin.num:SetPoint("CENTER")
        pin.num:SetTextColor(0, 0, 0, 1)
        return pin
    end

    function RouteOptimizer:DrawOnMap()
        self:ClearMap()
        if not currentRoute or not HBDPins then return end
        local ref = addonName .. "_route"
        for i = 1, #currentRoute.order do
            local idx = currentRoute.order[i]
            local cand = currentRoute.nodes[idx]
            local pin = GetRoutePin()
            pin.num:SetText(tostring(i))
            pin:Show()
            HBDPins:AddWorldMapIconMap(ref, pin, cand.mapID, cand.x, cand.y, 2)
            routeMapPins[#routeMapPins + 1] = pin
        end
    end

    function RouteOptimizer:ClearMap()
        if not HBDPins then return end
        local ref = addonName .. "_route"
        for _, pin in ipairs(routeMapPins) do
            HBDPins:RemoveWorldMapIcon(ref, pin)
            pin:Hide()
            routePinPool[#routePinPool + 1] = pin
        end
        wipe(routeMapPins)
    end

    function RouteOptimizer:GetStatus()
        if not currentRoute then return GT.TR("No route planned") end
        return GT.TRF("Step %d/%d, %.0f yd total",
            currentStep, #currentRoute.order, currentRoute.totalDist)
    end

    UI.RouteOptimizer = RouteOptimizer
end

-- ============================================================
-- SPAWN PINS (wrapped in do...end)
-- ============================================================

-- exports
