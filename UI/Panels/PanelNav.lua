-- PanelNav.lua : the "Nav" panel  (sub-tabs: Route / Markers / Arrow / Move)
local _, GT = ...
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

-- nearest enabled spawn in range -> TomTom waypoint (without TomTom: only the route target, shown on the Timers panel)
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
    if GT.UI.TomTomAvailable() then
        if GT.navWp and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, GT.navWp) end
        if GT.listWp and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, GT.listWp) end
        GT.listWp = nil                              -- the last click wins: one GatherTimes click waypoint at a time
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, best.mapID, best.x, best.y,
            { title = label, persistent = false, minimap = true, world = true,
              crazy = true, from = "GatherTimes" })
        GT.navWp = ok and uid or nil
        GT.cprint(GT.TRF("TomTom waypoint set to %s (%d yd)", label, math.floor(bestD)))
    else
        -- no TomTom: the target still shows on the Timers panel ("Next:"), but no waypoint can be drawn
        GT.routeTarget = { ref = best, kind = "spawn", mapID = best.mapID, x = best.x, y = best.y, dist = bestD }
        GT.cprint(GT.TR("TomTom is not installed, or the TomTom option is off."))
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
        local b = GT:CreateFlatButton(content, text, 70, 20)
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
    local markers = AddSub("markers", "Markers", 72, "Control spawn pins and group labels on the map and minimap.")
    local arrow   = AddSub("arrow",   "Arrow",   144, "Configure the direction arrow and TomTom waypoint options.")
    local move    = AddSub("move",    "Move",    216, "GTMove: mouse-look toggle and mouse-look while a movement key is held.")

    local function Check(parent, y, text, get, set, description)
        local cb = GT:CreateCheckLabel(parent, text, get, set)
        cb:SetPoint("TOPLEFT", 2, y)
        AddTip(cb, text, description)
        return cb
    end
    -- per-character slider: the value is saved for this character (GT.CharGet / GT.CharSet)
    local CHAR_DEFAULTS = { gtmoveNoteTop = 160, gtmoveNoteSecs = 3, gtmoveArrowPct = 125 }
    local function CharSlider(parent, y, label, lo, hi, step, key, description, after)
        local s = GT:CreateSlider(parent, 288, label, lo, hi, step,
            function() return GT.CharGet(key, CHAR_DEFAULTS[key] or lo) end,
            function(v) GT.CharSet(key, v); if after then after() end end)
        s:SetPoint("TOPLEFT", 0, y)
        AddTip(s.slider, label:gsub(": %%s.*$", ""), description)
        GT.uiRefresh[#GT.uiRefresh + 1] = function() s:Refresh() end
        return s
    end

    local function Slider(parent, y, label, lo, hi, step, key, description, after)
        local s = GT:CreateSlider(parent, 288, label, lo, hi, step,
            function() return cfg()[key] end,
            function(v) cfg()[key] = v; if after then after() end end)
        s:SetPoint("TOPLEFT", 0, y)
        AddTip(s.slider, label:gsub(": %%s.*$", ""), description)
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
        function(v) cfg().tomtom = v; if not v then GT.ClearWaypoints() end end,   -- all waypoints + auto-nearest (refreshes the checkbox)
        "Use TomTom for navigation waypoints. Turning this off clears GatherTimes waypoints.")
    Check(arrow, -26, "Auto-advance arrow to next route node", function() return cfg().routeAutoArrow end,
        function(v) cfg().routeAutoArrow = v end,
        "Automatically point to the next route stop when you reach the current one.")
    Check(arrow, -48, "Auto-set waypoint to nearest node", function() return cfg().tomTomAutoNearest end,
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
    Slider(arrow, -76, "Arrow distance threshold: %s yd", 10, 500, 10, "routeRange",
        "Maximum distance used when selecting nearby nodes for route and waypoint targets.")
    Button(arrow, "Clear waypoint", 138, 0, -118, function()
        GT.ClearWaypoints()
        GT.cprint(GT.TR("Waypoint cleared."))
    end, "Remove GatherTimes waypoints from TomTom.")
    Button(arrow, "Waypoint to nearest", 138, 150, -118, WaypointToNearest,
        "Set a TomTom waypoint or direction arrow to the nearest enabled node within range.")
    Note(arrow, -148, "Needs TomTom. Points to the nearest enabled node in range and follows the active route.")

    ------------------------------------------------------------------ Move
    -- GTMove (the GatherTimes_GTMove module).  Switching it off keeps the movement keys working as normal keys.
    local gtmoveCheck = Check(move, -4, "GTMove: mouse-look keys",
        function() return GT.ModuleEnabled("gtmove") end,
        function(v)
            if not v and GT.GTMove and GT.GTMove.Stop then GT.GTMove.Stop() end      -- end a running mouse-look first
            GT.SetModuleEnabled("gtmove", v)
        end,
        "Turn GTMove on or off. Off: its key bindings and /gtmove do nothing and the module is not loaded.")
    GT.uiRefresh[#GT.uiRefresh + 1] = function() gtmoveCheck:SetChecked(GT.ModuleEnabled("gtmove")) end
    local mountCheck = Check(move, -26, "Turn on when mounted",
        function() return GT.CharGet("gtmoveMount", false) == true end, function(v) GT.CharSet("gtmoveMount", v) end,
        "Turn mouse-look on when you mount and off when you dismount. It only ends mouse-look that this option turned on.")
    GT.uiRefresh[#GT.uiRefresh + 1] = function() mountCheck:SetChecked(GT.CharGet("gtmoveMount", false) == true) end
    local rememberCheck = Check(move, -48, "Remember mouse-look on login",
        function() return GT.CharGet("gtmoveRemember", false) == true end, function(v) GT.CharSet("gtmoveRemember", v) end,
        "Turn mouse-look back on after logging in or reloading, if it was on the last time you turned it on or off.")
    GT.uiRefresh[#GT.uiRefresh + 1] = function() rememberCheck:SetChecked(GT.CharGet("gtmoveRemember", false) == true) end

    -- toggle key: click, press the key (Esc cancels); right-click removes it
    local keyLabel = GT.Font(move, nil, "OVERLAY", "GameFontHighlightSmall")
    keyLabel:SetPoint("TOPLEFT", 2, -84)
    keyLabel:SetText(GT.TR("Toggle key:"))
    local keyButton = GT:CreateFlatButton(move, "", 150, 20)
    keyButton:SetPoint("TOPLEFT", 90, -80)
    keyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
    local listening = false
    local function KeyText()
        local k = GetBindingKey and GetBindingKey("GTMOVE_TOGGLE")
        return k and GetBindingText(k) or GT.TR("Not bound")
    end
    local function RefreshKey()
        keyButton.label:SetText(listening and GT.TR("Press a key...") or KeyText())
    end
    local function StopListening()
        listening = false
        keyButton:EnableKeyboard(false)
        RefreshKey()
    end
    local function SaveBindingsNow()
        if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
    end
    local function Unbind()
        for _, k in ipairs({ GetBindingKey("GTMOVE_TOGGLE") }) do SetBinding(k) end
    end
    keyButton:SetScript("OnClick", function(_, mouseButton)
        if InCombatLockdown() then GT.cprint(GT.TR("Key bindings cannot be changed in combat.")); return end
        if listening then StopListening(); return end
        if mouseButton == "RightButton" then
            Unbind(); SaveBindingsNow(); RefreshKey()
            return
        end
        listening = true
        keyButton:EnableKeyboard(true)
        RefreshKey()
    end)
    keyButton:SetScript("OnKeyDown", function(_, key)
        if not listening then return end
        if MODIFIER_KEYS[key] then return end                       -- wait for the real key
        keyButton:SetPropagateKeyboardInput(false)
        if key == "ESCAPE" then StopListening(); return end
        if InCombatLockdown() then StopListening(); return end
        local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
            .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
        Unbind()
        if SetBinding(combo, "GTMOVE_TOGGLE") then
            SaveBindingsNow()
            GT.cprint(GT.TRF("GTMove toggle key: %s", GetBindingText(combo)))
            if GT.ModuleEnabled("gtmove") and not GT.ModuleLoaded("gtmove") then GT.LoadModule("gtmove", true) end
        end
        StopListening()
    end)
    keyButton:SetScript("OnHide", function() if listening then StopListening() end end)
    AddTip(keyButton, "Toggle key", "Click, then press the key (with Shift / Ctrl / Alt if you like) that switches mouse-look on and off. Esc cancels, right-click removes the key.", "ANCHOR_TOP")
    local keyEvents = CreateFrame("Frame")
    keyEvents:RegisterEvent("UPDATE_BINDINGS")
    keyEvents:SetScript("OnEvent", RefreshKey)
    GT.uiRefresh[#GT.uiRefresh + 1] = RefreshKey
    RefreshKey()
    Note(move, -112, "Mouse-look on a key: press it to switch mouse-look on, press it again (or Esc / chat) to stop.")
    CharSlider(move, -168, "Notice position: %s px from top", 40, 400, 10, "gtmoveNoteTop",
        "How far below the top of the screen the on-screen mouse-look notice sits.")
    CharSlider(move, -202, "Notice time: %s sec", 1, 10, 1, "gtmoveNoteSecs",
        "How long the on-screen mouse-look notice stays up.")
    Note(move, -140, "The movement keys that hold mouse-look while pressed are in Key Bindings > AddOns > GTMove. Or type /gtmove.")
    CharSlider(move, -236, "Mouse-look arrow size: %s%%", 100, 200, 5, "gtmoveArrowPct",
        "How big the player arrow is drawn while mouse-look is on. 100% is the normal size.",
        function() if GT.HUD and GT.HUD.RefreshArrow then GT.HUD.RefreshArrow() end end)
    Note(move, -270, "Sensitivity up / down keys: Key Bindings > AddOns > GTMove.")

    ------------------------------------------------------------- show/update
    panel:SetScript("OnShow", function() ShowSub(active) end)
    local t = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        if t >= 1 then
            t = 0
            if active == "route" then                       -- only while the Route tab is open
                GT.SetTextIfChanged(status, GT.TR("Route:") .. " " .. GT.UI.RouteOptimizer:GetStatus())
            end
        end
    end)
    GT.SetTextIfChanged(status, GT.TR("Route:") .. " " .. GT.UI.RouteOptimizer:GetStatus())
    ShowSub("route")
end
