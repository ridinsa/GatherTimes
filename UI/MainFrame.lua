-- MainFrame.lua : the GatherTimes main window
local _, GT = ...

local function CreateMinimapLauncher()
    if not Minimap or _G.GatherTimesMinimapButton then return end

    local button = CreateFrame("Button", "GatherTimesMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_Herb_15")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetAllPoints()

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function()
        if not GT.main then return end
        if GT.main:IsShown() then GT.main:Hide() else GT.main:Show() end
    end)
    button:SetScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_LEFT")
        GT.Tip:AddLine("GatherTimes")
        GT.Tip:AddLine(GT.TR("Left-click to open or close"), 1, 1, 1)
        GT.Tip:Show()
    end)
    button:SetScript("OnLeave", function() GT.Tip:Hide() end)
    button:SetScript("OnDragStart", function(self) self:StartMoving() end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local bx, by = self:GetCenter()
        local mx, my = Minimap:GetCenter()
        if not (bx and by and mx and my) then return end
        local angle = math.deg(math.atan2(by - my, bx - mx)) % 360
        GT.cfg().mmAngle = angle
        self:ClearAllPoints()
        local radius = (Minimap:GetWidth() / 2) + 4
        self:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(math.rad(angle)) * radius, math.sin(math.rad(angle)) * radius)
    end)

    local angle = GT.cfg().mmAngle or 225
    local radius = (Minimap:GetWidth() / 2) + 4
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(math.rad(angle)) * radius, math.sin(math.rad(angle)) * radius)
    button:Show()
end

-- Change the window scale without the window jumping across the screen.
function GT:SetWindowScale(scale)
    local f, ui = self.main, GatherTimesDB._ui
    scale = math.max(0.5, math.min(1.5, scale or 1))
    ui.scale = scale
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local oldEff = f:GetEffectiveScale()
    f:SetScale(scale)
    if cx and ux then
        local newEff, uEff = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
        local dx = (cx * oldEff - ux * uEff) / newEff
        local dy = (cy * oldEff - uy * uEff) / newEff
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
        ui.point, ui.x, ui.y = "CENTER", dx, dy
    end
    if f.table then f.table:Update() end      -- grid lines follow the new scale
    -- the minimized bar keeps its own scale (ui.barScale): the Window size slider only resizes the main window
end

-- Which node types have learned spots in the given zone.  Fills (and returns) one reusable table,
-- because this is called every second.
local presentScratch = {}
function GT:NodesInZone(mapID)
    local present = presentScratch
    for k in pairs(present) do present[k] = nil end
    if mapID then
        for _, key in ipairs(self.order) do
            if GT.SpawnsOnMap(key, mapID)[1] then present[key] = true end
        end
    end
    return present
end

-- Fill the main-window dropdown: nodes CHECKED in the Nodes panel that also have learned spots in the
-- CURRENT zone (a checked node with nothing in this zone is left out).
-- Entry 1 is "All checked"; the choice is saved in _ui.mainItem and drives the table AND the map / minimap
-- labels (GT.ViewMode / GT.IsShown).
-- Runs every second, so it compares in place and only builds new lists when the content changed.
local keysNow, keysShown, countsNow, countsShown = { "all" }, { "all" }, {}, {}
function GT:RefreshMainDropdown()
    local f, ui = self.main, GatherTimesDB._ui
    if not (f and f.dropdown) then return end
    local present = self:NodesInZone(C_Map.GetBestMapForUnit("player"))
    local n = 1
    keysNow[1] = "all"
    countsNow[1] = nil
    for _, key in ipairs(self.order) do
        if self.IsEnabled(key) and present[key] then
            n = n + 1
            keysNow[n] = key
            local def = self.nodes[key]
            local countId = def.countId or def.id
            countsNow[n] = GetItemCount and (GetItemCount(countId) or 0) or 0
        end
    end
    for i = #keysNow, n + 1, -1 do keysNow[i], countsNow[i] = nil, nil end

    local index = 1
    for i = 1, n do if keysNow[i] == ui.mainItem then index = i end end
    ui.mainItem = keysNow[index]     -- a node that dropped out of the list falls back to "All checked"

    local same = (#keysShown == n) and (f._ddIndex == index)
    if same then
        for i = 1, n do
            if keysShown[i] ~= keysNow[i] or countsShown[i] ~= countsNow[i] then same = false; break end
        end
    end
    if same then return end

    -- The node list changes rarely; inventory counts are refreshed with the main frame.
    local names, keys, shownCounts = { { text = GT.TR("All checked") } }, {}, {}
    for i = 1, n do
        keys[i] = keysNow[i]
        shownCounts[i] = countsNow[i]
        if i > 1 then
            names[i] = { text = self.nodes[keysNow[i]].label, count = countsNow[i] }
        end
    end
    keysShown, countsShown = keys, shownCounts
    self.mainKeys = keys
    f._ddIndex = index
    f.dropdown:SetItems(names)
    f.dropdown:SetSelected(index)
end

-- An entry picked in the main-window dropdown or in the minimized bar's dropdown (UI\MiniBar.lua).
function GT:PickMainItem(index)
    local ui = GatherTimesDB._ui
    if GT.MiniXP then GT.MiniXP.SetOn(false) end      -- picking an item brings the gathering timers back
    local key = self.mainKeys and self.mainKeys[index]
    if not key then return end
    ui.mainItem = key
    if self.main and self.main.table then self.main.table:Update() end
    pcall(GT.SyncSpawnPins)           -- the map / minimap follow the dropdown
    pcall(GT.RefreshTimers)
    self:RefreshMainDropdown()        -- both dropdowns show the new pick
    if self.bar then self:UpdateMiniBar() end
end

-- call after anything that changes which nodes are checked
function GT:OnNodesChanged()
    self:RefreshMainDropdown()
    if self.main and self.main.table then self.main.table:Update() end
end

-- true while the cursor is over the main window, any open panel, or the dropdown list
local function Over(frame)
    if not (frame and frame:IsShown()) then return false end
    if frame.IsMouseOver then return frame:IsMouseOver() end
    return MouseIsOver and MouseIsOver(frame) or false
end
local function MouseOverWindow(f)
    if Over(f) or Over(f.dropdown and f.dropdown.list) then return true end
    for _, p in pairs(GT.panels) do if Over(p) then return true end end
    return false
end

-- "Keep window visible" (Settings > Display). Frames listed in UISpecialFrames are closed by the ESC key,
-- which is what also closed the window whenever the game menu / game settings were opened.
function GT:ApplyKeepVisible()
    local ui = GatherTimesDB and GatherTimesDB._ui
    local keep = ui and ui.keepVisible == true
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "GatherTimes" then tremove(UISpecialFrames, i) end
    end
    if not keep then tinsert(UISpecialFrames, "GatherTimes") end
end

-- "Doomhowl-Hardcore": the realm you are on, plus the game mode when the client can tell (Classic Era hardcore).
-- Same tag the timers carry (GT.RealmName, Core\Util.lua).
function GT.GetServerLabel()
    return GT.RealmName() or ""
end

function GT:CreateMainFrame()
    local ui = GatherTimesDB._ui
    local f = self:CreateFlatFrame("GatherTimes", UIParent, 300, self.frameHeight)
    f:SetScale(ui.scale or 1)
    f:SetPoint(ui.point, UIParent, ui.point, ui.x, ui.y)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    self.main = f
    self:ApplyKeepVisible()                 -- ESC / game menu closes the window only when "keep visible" is off

    f.header = self:CreateHeader(f, "GatherTimes", function() f:Hide() end)

    -- drag by the header
    f.header:EnableMouse(true)
    f.header:RegisterForDrag("LeftButton")
    f.header:SetScript("OnDragStart", function() f:StartMoving() end)
    f.header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        ui.point, ui.x, ui.y = point, x, y
    end)

    -- HUD button: full width, directly above the 5 bottom buttons (same 22 px height, same 6 px padding
    -- and 4 px gap). Left-click toggles the minimap HUD, right-click opens / closes the HUD settings panel.
    -- Its text is green while the HUD is on and grey while it is off.
    local hud = self:CreateFlatButton(f, "Minimap HUD On/Off", 288, 22)
    hud:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 6 + 22 + 4)
    hud:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hud:SetScript("OnClick", function(_, button)
        if not GT.HUD then return end
        if button == "RightButton" then GT.HUD.Config.Toggle() else GT.HUD.Toggle() end
    end)
    hud:HookScript("OnEnter", function(s)
        local on = GT.HUD and GT.HUD.IsActive()
        GT.ShowButtonTip(s, GT.TR("Minimap HUD"),
            on and ("|cff4cd964" .. GT.TR("HUD is on") .. "|r") or ("|cff9a9a9a" .. GT.TR("HUD is off") .. "|r"),
            { { GT.TR("Left-click"), GT.TR("Toggle the HUD") }, { GT.TR("Right-click"), GT.TR("HUD settings") } })
    end)
    hud:HookScript("OnLeave", function() GT.Tip:Hide() end)
    f.hudButton = hud
    function GT.RefreshHudButton()
        local on = GT.HUD and GT.HUD.IsActive() or false
        if on then
            hud.label:SetTextColor(0.298, 0.851, 0.392, 1)     -- green  (#4cd964)
        else
            hud.label:SetTextColor(0.604, 0.604, 0.604, 1)     -- grey   (#9a9a9a)
        end
    end
    GT.RefreshHudButton()

    -- server name, left aligned, directly above the Minimap HUD button (same 6 px padding, 4 px gap)
    local server = GT.Font(f, nil, "OVERLAY", "GameFontNormalSmall")
    server:SetPoint("BOTTOMLEFT", hud, "TOPLEFT", 2, 4)
    server:SetWidth(190)
    server:SetJustifyH("LEFT")
    server:SetWordWrap(false)
    server:SetTextColor(0.7, 0.7, 0.7)
    f.serverText = server

    -- session gold, right aligned on the same row (gold only)
    local gold = GT.Font(f, nil, "OVERLAY", "GameFontNormalSmall")
    gold:SetPoint("BOTTOMRIGHT", hud, "TOPRIGHT", -2, 4)
    gold:SetJustifyH("RIGHT")
    gold:SetWordWrap(false)
    gold:SetTextColor(1, 0.82, 0)
    f.goldText = gold

    local function UpdateServer()
        local label = GT.GetServerLabel()
        if label ~= f._server then
            f._server = label
            server:SetText(label)
        end
        local g = GT.SessionGoldText and GT.SessionGoldText() or "0g"
        if g ~= f._gold then
            f._gold = g
            gold:SetText(g)
        end
    end
    UpdateServer()

    -- dropdown: the nodes checked in the Nodes panel; the table below shows only the picked one
    f.dropdown = self:CreateDropdown(f, 288, 22, { GT.TR("All checked") }, function(index)
        GT:PickMainItem(index)
    end, 12)
    f.dropdown:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 6, -6)
    -- always rebuild the list from the current checkboxes when it is opened
    f.dropdown:HookScript("OnClick", function() GT:RefreshMainDropdown() end)

    -- Excel-style table (Group | Status | Timer) for the current zone
    f.table = self:CreateMainTable(f)
    self:RefreshMainDropdown()
    self.uiRefresh[#self.uiRefresh + 1] = function() GT:OnNodesChanged() end

    -- window title = "GatherTimes - <zone>"
    local function UpdateZone()
        local z = GetZoneText() or ""
        if z ~= f._zone then
            f._zone = z
            f.header.title:SetText(z ~= "" and ("GatherTimes - " .. z) or "GatherTimes")
        end
        GT:RefreshMainDropdown()          -- zone changed or a new spot was learned: keep the list current
        GT.RefreshHudButton()             -- HUD switched on/off by gathering tracking, a keybind or /gthud
        UpdateServer()                    -- realm / game mode (not always known at the first call)
        f.table:Update()
    end
    UpdateZone()

    -- 5 bottom buttons
    self.buttonFrames = {}
    local count, gap, pad = #self.buttons, 4, 6
    local w = (300 - pad * 2 - gap * (count - 1)) / count

    for i, name in ipairs(self.buttons) do
        local b = self:CreateFlatButton(f, name, w, 22)
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", pad + (i - 1) * (w + gap), pad)
        if name == "Settings" then
            -- Settings button: left-click opens the normal Settings panel; right-click opens Random Name.
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnClick", function(_, button)
                if button == "RightButton" then
                    if GT.ShowNameDisguiseFrame then
                        GT:ShowNameDisguiseFrame()
                    else
                        GT.cprint(GT.TR("Random Name settings are not available."))
                    end
                else
                    GT:ShowPanel(name)
                end
            end)
            b:HookScript("OnEnter", function(owner)
                GT.ShowButtonTip(owner, GT.TR("Settings"), GT.TR("Configure GatherTimes"), {
                    { GT.TR("Left-click"), GT.TR("Open / close Settings") },
                    { GT.TR("Right-click"), GT.TR("Open / close Random Name") },
                })
            end)
            b:HookScript("OnLeave", function() GT.Tip:Hide() end)
        else
            b:SetScript("OnClick", function() GT:ShowPanel(name) end)
        end
        self.buttonFrames[name] = b
        self:CreatePanel(name)
    end

    -- "?" button in the title bar, just left of the "x": opens / closes the Help panel (UI/Panels/PanelHelp.lua).
    -- It is registered in buttonFrames so it lights up while its panel is open, like the 5 bottom buttons.
    local help = self:CreateFlatButton(f.header, "?", 18, 18)
    help:SetPoint("RIGHT", f.header.close, "LEFT", -2, 0)
    help:SetScript("OnClick", function() GT:ShowPanel("Help") end)
    help:HookScript("OnEnter", function(s)
        GT.ShowButtonTip(s, GT.TR("Help"), GT.TR("How to use GatherTimes"),
            { { GT.TR("Left-click"), GT.TR("Open / close the guide") } })
    end)
    help:HookScript("OnLeave", function() GT.Tip:Hide() end)
    self.buttonFrames.Help = help
    self:CreatePanel("Help")
    self:CreatePanel("Summary")

    -- "-" button, just left of the "?": minimizes the window into a one-strip info bar (UI/MiniBar.lua)
    local minimize = self:CreateFlatButton(f.header, "-", 18, 18)
    minimize:SetPoint("RIGHT", help, "LEFT", -2, 0)
    -- left-click minimizes; right-click opens / closes the Minimize settings panel (UI/Panels/PanelMinimize.lua)
    minimize:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimize:SetScript("OnClick", function(_, button)
        if button == "RightButton" then GT:ShowPanel("Minimize") else GT:SetMinimized(true) end
    end)
    minimize:HookScript("OnEnter", function(s)
        GT.ShowButtonTip(s, GT.TR("Minimize"), GT.TR("Shrink to a small info bar"),
            { { GT.TR("Left-click"), GT.TR("Minimize") },
              { GT.TR("Right-click"), GT.TR("Minimize settings") } })
    end)
    minimize:HookScript("OnLeave", function() GT.Tip:Hide() end)
    f.minimizeButton = minimize
    self.buttonFrames.Minimize = minimize                 -- lights up while its panel is open
    local mp = self:CreatePanel("Minimize")
    mp.header.title:SetText(GT.TR("Panel Settings"))

    -- a long zone name must not run under the "-" button
    f.header.title:SetPoint("RIGHT", minimize, "LEFT", -4, 0)
    f.header.title:SetJustifyH("LEFT")
    f.header.title:SetWordWrap(false)

    -- optional: fade the whole window while the character is moving
    local acc, zacc = 0, 0
    f:SetScript("OnUpdate", function(self, elapsed)
        zacc = zacc + elapsed
        if zacc >= 1 then
            zacc = 0
            UpdateZone()                                  -- keep the title and the table current
        end
        acc = acc + elapsed
        if acc < 0.1 then return end
        acc = 0
        local faded = ui.fadeMoving and GetUnitSpeed("player") > 0
        if faded and MouseOverWindow(self) then faded = false end     -- hovering = fully visible
        local a = faded and (ui.moveAlpha or 0.35) or 1
        if self._alpha ~= a then self._alpha = a; self:SetAlpha(a) end
    end)
    -- shown again by anything (minimap button, /gt, the + on the bar): the window is back, so the bar goes
    f:SetScript("OnShow", function(self)
        UpdateZone()
        -- short fade-in each time the window is opened; ends at the window's current alpha (moving-fade aware)
        UIFrameFadeIn(self, 0.2, 0, self._alpha or 1)
        if ui.minimized then
            ui.minimized = false
            if GT.bar and not GT:AlwaysShowBar() then GT.bar:Hide() end
        end
        -- "Always show" on: opening the addon brings the bar up with it (also after the red x), and it stays
        GT._barDismissed = nil
        if GT:AlwaysShowBar() then GT:ShowBarAlways() end
    end)

    -- closing the main frame closes all panels.  A real close (x, ESC, /gt) also closes the bar;
    -- minimizing hides the window the same way but keeps the bar (GT._minimizing, UI\MiniBar.lua).
    f:SetScript("OnHide", function()
        f.dropdown.list:Hide()
        GT:HidePanels()
        if not GT._minimizing then
            ui.minimized = false
            if GT.bar and not GT:AlwaysShowBar() then GT.bar:Hide() end
        end
    end)
    CreateMinimapLauncher()

    -- Startup.  "Always show minimized panel" on (the default): the main window stays closed and the minimized bar is
    -- up from the moment the addon loads, with the window closed; open the window from the minimap button
    -- or /gt.  Off: the main window shows as usual, and the bar appears only from the "-" button, so a bar left open
    -- last session is not brought back.
    ui.minimized = false
    if self:AlwaysShowBar() then
        self.main:Hide()
        self:ShowBarAlways()
    end
end
