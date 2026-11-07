-- PanelNav.lua : the "Nav" panel  (sub-tabs: Route / Markers / Arrow)
local ADDON, GT = ...
GT.panelBuilders = GT.panelBuilders or {}
-- NOTE: GT.UI is created by Util.lua, which loads AFTER this file, so it is read lazily (GT.UI.x)

local function Note(parent, y, text)
    local fs = GT.Font(parent, nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", 2, y)
    fs:SetWidth(284)
    fs:SetJustifyH("LEFT")
    fs:SetText(GT.TR(text))
    return fs
end

local function AddTip(frame, title, description, anchor)
    if frame.EnableMouse then frame:EnableMouse(true) end
    frame:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        GT.Tip:AddLine(GT.TR(title))
        GT.Tip:AddLine(GT.TR(description), 0.85, 0.85, 0.85, true)
        GT.Tip:Show()
    end)
    frame:HookScript("OnLeave", function() GT.Tip:Hide() end)
end

-- nearest enabled spawn in range -> TomTom waypoint (or the plain arrow if TomTom is missing)
local function WaypointToNearest()
    local curMap = C_Map.GetBestMapForUnit("player")
    local best, bestD, bestKey
    for _, key in ipairs(GT.order) do
        if GT.IsEnabled(key) then
            for _, sp in ipairs(GT.spawns[key]) do
                if sp.mapID == curMap then
                    local d = GT.GetDistance(sp)
                    if d and d <= GT.cfg().routeRange and (not bestD or d < bestD) then
                        best, bestD, bestKey = sp, d, key
                    end
                end
            end
        end
    end
    if not best then GT.cprint(GT.TR("No node in range.")); return end

    local label = GT.nodes[bestKey].label
    if TomTom and TomTom.AddWaypoint then
        if GT.navWp and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, GT.navWp) end
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, best.mapID, best.x, best.y,
            { title = label, persistent = false, minimap = true, world = true,
              crazy = true, from = "GatherTimes" })
        GT.navWp = ok and uid or nil
        GT.cprint(GT.TRF("TomTom waypoint set to %s (%d yd)", label, math.floor(bestD)))
    else
        GT.routeTarget = { ref = best, kind = "spawn", mapID = best.mapID, x = best.x, y = best.y, dist = bestD }
        GT.PlaceArrow()
        GT.cprint(GT.TRF("Arrow set to %s (%d yd)", label, math.floor(bestD)))
    end
end

GT.panelBuilders.Nav = function(panel, content)
    local cfg = GT.cfg
    local subs, tabs, active = {}, {}, "route"

    local function ShowSub(id)
        active = id
        for sid, f in pairs(subs) do f:SetShown(sid == id) end
        for sid, b in pairs(tabs) do GT:SetButtonActive(b, sid == id) end
    end

    local function AddSub(id, text, x, description)
        local b = GT:CreateFlatButton(content, text, 92, 20)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetScript("OnClick", function() ShowSub(id) end)
        AddTip(b, text, description, "ANCHOR_TOP")
        tabs[id] = b
        local f = CreateFrame("Frame", nil, content)
        f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -30)
        f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
        f:Hide()
        subs[id] = f
        return f
    end
    local route   = AddSub("route",   "Route",   0, "Plan and manage an optimized gathering route.")
    local markers = AddSub("markers", "Markers", 96, "Control spawn pins and group labels on the map and minimap.")
    local arrow   = AddSub("arrow",   "Arrow",   192, "Configure the direction arrow and TomTom waypoint options.")

    local function Check(parent, y, text, get, set, description)
        local cb = GT:CreateCheckLabel(parent, text, get, set)
        cb:SetPoint("TOPLEFT", 2, y)
        AddTip(cb, text, description)
        return cb
    end
    local function Slider(parent, y, label, lo, hi, step, key, description, after)
        local s = GT:CreateSlider(parent, 288, label, lo, hi, step,
            function() return cfg()[key] end,
            function(v) cfg()[key] = v; if after then after() end end)
        s:SetPoint("TOPLEFT", 0, y)
        AddTip(s, label:gsub(": %%s.*$", ""), description)
        GT.uiRefresh[#GT.uiRefresh + 1] = function() s:Refresh() end
        return s
    end
    local function Button(parent, text, w, x, y, fn, description)
        local b = GT:CreateFlatButton(parent, text, w, 20)
        b:SetPoint("TOPLEFT", x, y)
        b:SetScript("OnClick", fn)
        AddTip(b, text, description, "ANCHOR_TOP")
        return b
    end

    ---------------------------------------------------------------- Route
    Check(route, -4, "Only include ready nodes",
        function() return cfg().routeOnlyReady end, function(v) cfg().routeOnlyReady = v end,
        "Include only nodes that are ready now; turn this off to include nodes ready by arrival.")
    Check(route, -26, "Draw route on map",
        function() return cfg().routeDrawMap end, function(v) cfg().routeDrawMap = v end,
        "Draw the planned route on the world map.")
    local routeItems = { GT.TR("All enabled resources") }
    for _, key in ipairs(GT.order) do routeItems[#routeItems + 1] = GT.TR(GT.nodes[key].label) end
    local routeItem = GT:CreateDropdown(route, 288, 18, routeItems, function(index)
        cfg().routeItem = index == 1 and "all" or GT.order[index - 1]
    end, 8)
    routeItem:SetPoint("TOPLEFT", 0, -48)
    AddTip(routeItem, "Route resources", "Choose one enabled resource type to route, or include all enabled resources.")
    local function RefreshRouteItem()
        local selected = 1
        for i, key in ipairs(GT.order) do
            if cfg().routeItem == key then selected = i + 1; break end
        end
        routeItem:SetSelected(selected)
    end
    RefreshRouteItem()
    GT.uiRefresh[#GT.uiRefresh + 1] = RefreshRouteItem
    Check(route, -72, "Prioritize low-inventory resources",
        function() return cfg().routeLowStock end, function(v) cfg().routeLowStock = v end,
        "Favor resources you have less of in your bags when choosing route stops.")
    Slider(route, -94, "Stock target: %s", 1, 200, 1, "routeStockTarget",
        "The inventory amount used as the target when prioritizing low-stock resources.")
    Slider(route, -128, "Max route nodes: %s", 10, 100, 5, "routeMaxNodes",
        "Limit how many candidate stops the route can include.")
    Slider(route, -162, "Time window: %s sec", 60, 1800, 60, "routeTimeWindow",
        "When ready-only is off, include timers expected to become ready within this window.")
    Button(route, "Build route", 92, 0, -196, function() GT.UI.RouteOptimizer:Plan() end,
        "Calculate an optimized route from the current settings and active node data.")
    Button(route, "Next step", 92, 96, -196, function() GT.UI.RouteOptimizer:Next() end,
        "Advance the active route to its next node.")
    Button(route, "Clear route", 92, 192, -196, function() GT.UI.RouteOptimizer:Clear() end,
        "Stop following the route and remove its map line and waypoint.")
    local status = GT.Font(route, nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", 2, -222)
    Note(route, -248, "Pick one resource or all enabled. Builds a route through active timers. Auto-arrow needs TomTom.")

    --------------------------------------------------------------- Markers
    Check(markers, -4,  "Show spawn pins on map and minimap", function() return cfg().showSpawns end,
        function(v) cfg().showSpawns = v; pcall(GT.SyncSpawnPins) end,
        "Show remembered herb and ore locations on the world map and minimap.")
    Check(markers, -26, "Show group labels (G1, G2...)", function() return cfg().showGroups end,
        function(v) cfg().showGroups = v; pcall(GT.SyncSpawnPins); GT.RefreshTimers() end,
        "Show each spawn group's label on map pins and in the Timers list.")
    Check(markers, -48, "Dots for other items", function() return cfg().otherDots ~= false end,
        function(v) cfg().otherDots = v; pcall(GT.SyncSpawnPins) end,
        "Show small unlabeled dots for other remembered resources on the map.")
    Check(markers, -70, "Hide spots gathered this session",
        function() return cfg().hideGatheredSpots end,
        function(v) cfg().hideGatheredSpots = v; pcall(GT.SyncSpawnPins) end,
        "Hide spawn pins for locations you have gathered from during this session.")
    Check(markers, -92, "Right-click a spot: group menu",
        function() return cfg().menuMap end,
        function(v)
            cfg().menuMap = v
            if GT.RefreshMenuMouse then GT.RefreshMenuMouse() end
        end,
        "Show the GatherTimes spot actions menu when you right-click a map or minimap spot.")
    Button(markers, "Refresh pins", 120, 0, -118, function()
        pcall(GT.SyncSpawnPins)
        GT.cprint(GT.TR("Map / minimap pins refreshed."))
    end, "Redraw the GatherTimes spawn pins on the map and minimap.")
    -- where a spot is recorded while you gather (moved here from General: it changes the spot's map position)
    local offsetSlider = GT:CreateSlider(markers, 288, "Node offset while gathering: %s", 0, 8, 1,
        function() return cfg().nodeOffsetYd end, function(v) cfg().nodeOffsetYd = v end,
        function(v) return v == 0 and GT.TR("off") or GT.TRF("%d yd", v) end)
    offsetSlider:SetPoint("TOPLEFT", 0, -146)
    GT.uiRefresh[#GT.uiRefresh + 1] = function() offsetSlider:Refresh() end
    AddTip(offsetSlider.slider, "Node offset while gathering",
        "Adjust the recorded node position by this distance while gathering. Zero disables the offset.")
    Note(markers, -190, "Pins mark remembered spots. The G number matches the Timers list.")

    ----------------------------------------------------------------- Arrow
    Check(arrow, -4,  "Use TomTom integration", function() return cfg().tomtom end,
        function(v) cfg().tomtom = v; if not v then GT.UI.ClearAllTomTomWaypoints() end end,
        "Use TomTom for navigation waypoints. Turning this off clears GatherTimes waypoints.")
    Check(arrow, -26, "Show arrow to nearest node", function() return cfg().showArrow end,
        function(v) cfg().showArrow = v; pcall(GT.RefreshArrowVisibility) end,
        "Show the on-screen direction arrow pointing to your current target.")
    Check(arrow, -48, "Auto-advance arrow to next route node", function() return cfg().routeAutoArrow end,
        function(v) cfg().routeAutoArrow = v end,
        "Automatically point to the next route stop when you reach the current one.")
    Check(arrow, -70, "Auto-set waypoint to nearest node", function() return cfg().tomTomAutoNearest end,
        function(v)
            cfg().tomTomAutoNearest = v
            if v then
                C_Timer.After(1, function()
                    if cfg().tomTomAutoNearest then GT.UI.UpdateTomTomNearest() end
                end)
            else
                GT.UI.StopTomTomAutoNearest()
            end
        end,
        "Keep a TomTom waypoint set to the nearest enabled node within the distance threshold.")
    Slider(arrow, -98, "Arrow distance threshold: %s yd", 10, 500, 10, "routeRange",
        "Maximum distance used when selecting nearby nodes for route and waypoint targets.")
    Button(arrow, "Clear waypoint", 138, 0, -140, function()
        GT.ClearWaypoints()
        GT.cprint(GT.TR("Waypoint cleared."))
    end, "Remove GatherTimes waypoints from TomTom.")
    Button(arrow, "Waypoint to nearest", 138, 150, -140, WaypointToNearest,
        "Set a TomTom waypoint or direction arrow to the nearest enabled node within range.")
    Note(arrow, -170, "Needs TomTom. Points to the nearest enabled node in range and follows the active route.")

    ------------------------------------------------------------- show/update
    panel:SetScript("OnShow", function() ShowSub(active) end)
    local t = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        if t >= 1 then
            t = 0
            status:SetText(GT.TR("Route:") .. " " .. GT.UI.RouteOptimizer:GetStatus())
        end
    end)
    status:SetText(GT.TR("Route:") .. " " .. GT.UI.RouteOptimizer:GetStatus())
    ShowSub("route")
end
