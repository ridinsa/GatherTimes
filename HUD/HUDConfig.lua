-- HUDConfig.lua : the HUD settings panel  (main window: right-click the HUD button, or /gt hud config)
--
-- It is a normal GatherTimes panel (Panels.lua): 300 x 400, anchored to the right of the main window, not
-- movable, closed by its header button, by opening another panel, or by closing the main window. Inside it
-- follows PanelSettings.lua: a row of flat tab buttons across the top, flat sliders / checkboxes / buttons
-- (Widgets.lua) and 6 px padding. All values are read from / written to GatherTimesDB.hud through HUD.Set,
-- HUD.SetRoot and the profile functions in HUD.lua - nothing is stored here.
local _, GT = ...
local HUD = GT.HUD
GT.panelBuilders = GT.panelBuilders or {}

local Config = {}
HUD.Config = Config

local FLAT = "Interface\\Buttons\\WHITE8X8"
local COL_W = 288                     -- content width of a panel (300 - 2 x 6 padding)

local panel, built
local refreshers = {}                 -- functions that re-read every control from the database
local tabButtons, tabFrames = {}, {}
local RefreshProfiles = function() end

local TABS = {
    { "map",      "Map" },
    { "overlay",  "Rings" },
    { "tracking", "Track" },
    { "options",  "Options" },
    { "eagle",    "Eagle" },
    { "profiles", "Profile" },
}

-- ----------------------------------------------------------------------------------------------- helpers
local function Heading(parent, x, y, text)
    local fs = GT.Font(parent, nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x + 2, y)
    fs:SetText(GT.TR(text))
    return fs
end

local function Note(parent, x, y, w, text)
    local fs = GT.Font(parent, nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", x + 2, y)
    fs:SetWidth(w)
    fs:SetJustifyH("LEFT")
    fs:SetText(GT.TR(text))
    return fs
end

local function Button(parent, text, w, x, y)
    local b = GT:CreateFlatButton(parent, text, w, 20)
    b:SetPoint("TOPLEFT", x, y)
    return b
end

local function Slider(parent, x, y, label, lo, hi, step, get, set, fmt)
    local s = GT:CreateSlider(parent, COL_W, label, lo, hi, step, get, set, fmt)
    s:SetPoint("TOPLEFT", x, y)
    refreshers[#refreshers + 1] = function() s:Refresh() end
    return s
end

-- slider bound to one profile setting
local function KeySlider(parent, x, y, label, key, lo, hi, step, fmt)
    return Slider(parent, x, y, label, lo, hi, step,
        function() return HUD.db[key] end,
        function(v) if HUD.db[key] ~= v then HUD.Set(key, v, true) end end,
        fmt)
end

local function Check(parent, x, y, text, get, set)
    local cb = GT:CreateCheckLabel(parent, text, get, set)
    cb:SetPoint("TOPLEFT", x + 2, y)
    refreshers[#refreshers + 1] = function() cb:Refresh() end
    return cb
end

-- checkbox bound to one profile setting
local function KeyCheck(parent, x, y, text, key)
    return Check(parent, x, y, text,
        function() return HUD.db[key] and true or false end,
        function(v) HUD.Set(key, v, true) end)
end

-- checkbox bound to an account-wide HUD switch (GatherTimesDB.hud.<key>)
local function RootCheck(parent, x, y, text, key)
    return Check(parent, x, y, text,
        function() return HUD.root[key] and true or false end,
        function(v) HUD.SetRoot(key, v) end)
end

local function Px(v) return v .. " px" end
local function PxOrOff(v) return v == 0 and GT.TR("off") or (v .. " px") end

-- ----------------------------------------------------------------------------------------------- ring colour
local swatch, swatch2

local function UpdateSwatch()
    if swatch then swatch:SetBackdropColor(unpack(HUD.db.ringColor)) end
    if swatch2 then swatch2:SetBackdropColor(unpack(HUD.db.ringColor2)) end
end
if GT.RegisterSkinUpdater then
    GT:RegisterSkinUpdater(function()
        if not HUD.db then return end
        UpdateSwatch()
        if HUD.IsActive() then HUD.Overlay.Update() end
    end)
end

-- Colour picker: a small GatherTimes-style window (flat backdrop, header bar, flat sliders and buttons)
-- instead of Blizzard's ColorPickerFrame. Fixed next to the HUD panel, not movable. Two tabs at the top
-- ("Ring 1" / "Ring 2") choose which ring's colour the sliders edit. Changes apply live; "Cancel" (or the
-- header x) restores both colours as they were when the picker was opened.
local picker
local curKey = "ringColor"            -- "ringColor" (ring 1) or "ringColor2" (ring 2)
local pickerTabs = {}
local RING_TABS = { { "ringColor", "Ring 1" }, { "ringColor2", "Ring 2" } }

local function HexOf(c)
    return string.format("#%02X%02X%02X", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function ApplyColor(key, r, g, b, a)
    HUD.Set(key, { r, g, b, a }, true)
    UpdateSwatch()
    if picker and picker.Refresh then picker.Refresh() end
end

-- a random colour that stays visible on the minimap: any hue, saturation 55-100%, brightness 75-100%
local function RandomRGB()
    local h = math.random()
    local s = 0.55 + 0.45 * math.random()
    local v = 0.75 + 0.25 * math.random()
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local k = i % 6
    if k == 0 then return v, t, p
    elseif k == 1 then return q, v, p
    elseif k == 2 then return p, v, t
    elseif k == 3 then return p, q, v
    elseif k == 4 then return t, p, v
    else return v, q, p end
end

-- a random colour for one ring (key = "ringColor" or "ringColor2"); that ring's opacity is kept
local function RandomizeRing(key)
    local c = HUD.db[key]
    local r, g, b = RandomRGB()
    ApplyColor(key, r, g, b, c[4])
end

local function BuildPicker()
    local f = GT:CreateFlatFrame("GatherTimesHUDColor", panel, 300, 266)
    picker = f
    f:SetPoint("TOPLEFT", panel, "TOPRIGHT", 2, 0)             -- same spot as the panels: right of the panel
    f:EnableMouse(true)
    f:Hide()

    local function cancel()
        local p = f.prev
        if p then
            HUD.Set("ringColor", p.ringColor, true)
            HUD.Set("ringColor2", p.ringColor2, true)
            UpdateSwatch()
            f.Refresh()
        end
        f:Hide()
    end
    f.header = GT:CreateHeader(f, GT.TR("Ring colour"), cancel)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 6, -6)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)

    -- tab row: which ring is being edited
    for i, def in ipairs(RING_TABS) do
        local key, text = def[1], def[2]
        local b = GT:CreateFlatButton(content, text, 142, 20)
        b:SetPoint("TOPLEFT", (i - 1) * 146, 0)
        b:SetScript("OnClick", function()
            curKey = key
            f.Refresh()
        end)
        pickerTabs[key] = b
    end

    local sliders = {}
    local function Channel(i, y, label, hi, scale)
        local s = GT:CreateSlider(content, 288, label, 0, hi, 1,
            function() return math.floor(HUD.db[curKey][i] * scale + 0.5) end,
            function(v)
                local c = HUD.db[curKey]
                local n = { c[1], c[2], c[3], c[4] }
                n[i] = v / scale
                ApplyColor(curKey, n[1], n[2], n[3], n[4])
            end,
            i == 4 and function(v) return v .. "%" end or nil)
        s:SetPoint("TOPLEFT", 0, y)
        sliders[#sliders + 1] = s
    end
    Channel(1, -26,  "Red: %s",     255, 255)
    Channel(2, -64,  "Green: %s",   255, 255)
    Channel(3, -102, "Blue: %s",    255, 255)
    Channel(4, -140, "Opacity: %s", 100, 100)

    local preview = GT:CreateFlatFrame(nil, content, 24, 24)
    preview:SetPoint("TOPLEFT", 2, -182)
    local hex = GT.Font(content, nil, "OVERLAY", "GameFontHighlightSmall")
    hex:SetPoint("LEFT", preview, "RIGHT", 8, 0)

    function f.Refresh()
        for key, b in pairs(pickerTabs) do GT:SetButtonActive(b, key == curKey) end
        for _, s in ipairs(sliders) do s:Refresh() end
        local c = HUD.Overlay.RingColor(curKey == "ringColor" and 1 or 2)
        preview:SetBackdropColor(c[1], c[2], c[3], c[4])
        hex:SetText(HexOf(c))
    end

    local ok = GT:CreateFlatButton(content, "OK", 142, 22)
    ok:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    ok:SetScript("OnClick", function() f:Hide() end)
    local no = GT:CreateFlatButton(content, "Cancel", 142, 22)
    no:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 146, 0)
    no:SetScript("OnClick", cancel)

    local random = GT:CreateFlatButton(content, GT.TR("Random colour"), 142, 22)
    random:SetPoint("TOPLEFT", 146, -180)
    random:SetScript("OnClick", function() RandomizeRing(curKey) end)
end

local function OpenColorPicker()
    if not picker then BuildPicker() end
    if picker:IsShown() then picker:Hide(); return end        -- the button toggles it
    local c1, c2 = HUD.db.ringColor, HUD.db.ringColor2
    picker.prev = {
        ringColor  = { c1[1], c1[2], c1[3], c1[4] },
        ringColor2 = { c2[1], c2[2], c2[3], c2[4] },
    }
    curKey = "ringColor"
    picker.Refresh()
    picker:Show()
end

-- ----------------------------------------------------------------------------------------------- keybinding
-- Binds a key to the native "Toggle HUD" binding (Bindings.xml: GATHERTIMES_HUD_TOGGLE), so it also shows up
-- in Key Bindings -> AddOns -> GatherTimes. Click the key button, press the key (with Shift / Ctrl / Alt if you
-- like); Esc cancels. Bindings cannot be changed in combat.
local BIND_ACTION = "GATHERTIMES_HUD_TOGGLE"
local IGNORE_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true,
}

local function BoundKeyText()
    local k1, k2 = GetBindingKey(BIND_ACTION)
    if not k1 then return GT.TR("Not bound") end
    local t = GetBindingText(k1) or k1
    if k2 then t = t .. ", " .. (GetBindingText(k2) or k2) end
    return t
end

local function ClearHudBinding()
    local keys = { GetBindingKey(BIND_ACTION) }
    for _, k in ipairs(keys) do SetBinding(k) end
end

local function SaveBindingsNow()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

local function BuildKeybind(f, y)
    Heading(f, 0, y, "Keybinding")
    local keyBtn = Button(f, "", 190, 0, y - 22)
    local clear  = Button(f, "Clear", 94, 194, y - 22)
    local capturing = false

    local function Update()
        keyBtn.label:SetText(capturing and GT.TR("Press a key...  (Esc = cancel)") or BoundKeyText())
        GT:SetButtonActive(keyBtn, capturing)
    end

    local function StopCapture()
        capturing = false
        keyBtn:EnableKeyboard(false)
        keyBtn:SetScript("OnKeyDown", nil)
        Update()
    end

    local function StartCapture()
        if InCombatLockdown() then return HUD.Print(GT.TR("Cannot change key bindings in combat.")) end
        capturing = true
        keyBtn:EnableKeyboard(true)
        if keyBtn.SetPropagateKeyboardInput then keyBtn:SetPropagateKeyboardInput(false) end
        keyBtn:SetScript("OnKeyDown", function(_, key)
            if IGNORE_KEYS[key] then return end              -- wait for the real key
            if key == "ESCAPE" then return StopCapture() end
            if InCombatLockdown() then StopCapture(); return HUD.Print(GT.TR("Cannot change key bindings in combat.")) end
            local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
                .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
            local other = GetBindingAction(combo)
            ClearHudBinding()                                -- one key at a time
            if SetBinding(combo, BIND_ACTION) then
                SaveBindingsNow()
                if other and other ~= "" and other ~= BIND_ACTION then
                    HUD.Print(GT.TRF("Key %s was bound to another action; it now toggles the HUD.", GetBindingText(combo) or combo))
                end
            else
                HUD.Print(GT.TR("That key cannot be bound."))
            end
            StopCapture()
        end)
        Update()
    end

    keyBtn:SetScript("OnClick", function() if capturing then StopCapture() else StartCapture() end end)
    keyBtn:SetScript("OnHide", function() if capturing then StopCapture() end end)
    clear:SetScript("OnClick", function()
        if InCombatLockdown() then return HUD.Print(GT.TR("Cannot change key bindings in combat.")) end
        ClearHudBinding()
        SaveBindingsNow()
        if capturing then StopCapture() else Update() end
    end)
    refreshers[#refreshers + 1] = Update
end

-- ----------------------------------------------------------------------------------------------- tabs
local function BuildMap(f)
    Heading(f, 0, 0, "Minimap")
    KeySlider(f, 0, -22, "HUD size: %s", "size", 150, HUD.MaxSize(), 10, Px)
    -- the opacity is one of the 11 mask textures Masks\a00.tga ... a10.tga (0% = blank, 100% = opaque)
    Slider(f, 0, -60, "Map opacity: %s", 0, 10, 1,
        function() return math.floor(HUD.db.alpha * 10 + 0.5) end,
        function(v)
            if math.floor(HUD.db.alpha * 10 + 0.5) ~= v then HUD.Set("alpha", v / 10, true) end
        end,
        function(v) return string.format("%d%%", math.floor(v * 10 + 0.5)) end)
    KeySlider(f, 0, -98,  "Minimap zoom: %s", "zoom", 0, 5, 1)
    BuildKeybind(f, -140)
end

local function BuildOverlay(f)
    -- Ring radius in pixels or in yards (the button at the top right of the first slider switches). Both pairs sit
    -- in the same place; only the pair for the chosen unit is shown.
    local YdOrOff = function(v) return v == 0 and GT.TR("off") or GT.TRF("%d yd", v) end
    local sPx1 = KeySlider(f, 0, 0,   "Ring radius: %s", "ring",    0, 700, 1, PxOrOff)
    local sPx2 = KeySlider(f, 0, -38, "Second ring: %s", "ring2",   0, 700, 1, PxOrOff)
    local sYd1 = KeySlider(f, 0, 0,   "Ring radius: %s", "ringYd",  0, 250, 5, YdOrOff)
    local sYd2 = KeySlider(f, 0, -38, "Second ring: %s", "ring2Yd", 0, 250, 5, YdOrOff)
    local unitBtn = GT:CreateFlatButton(f, "", 76, 15)
    unitBtn:SetPoint("TOPLEFT", 212, 1)
    local function ApplyUnit()
        local yd = HUD.db.ringUnit == "yd"
        sPx1:SetShown(not yd); sPx2:SetShown(not yd)
        sYd1:SetShown(yd); sYd2:SetShown(yd)
        unitBtn.label:SetText(GT.TR(yd and "Unit: yards" or "Unit: pixels"))
    end
    unitBtn:SetScript("OnClick", function()
        HUD.Set("ringUnit", HUD.db.ringUnit == "yd" and "px" or "yd", true)
        ApplyUnit()
    end)
    refreshers[#refreshers + 1] = ApplyUnit
    ApplyUnit()
    KeySlider(f, 0, -76, "Ring thickness: %s",  "ringThickness", 1, 10,  1, Px)
    KeySlider(f, 0, -114,"Ring smoothness: %s", "ringSegments",  8, 256, 8)
    KeySlider(f, 0, -150,"Ring density: %s", "ringDensity", 4, 128, 4)

    swatch = GT:CreateFlatFrame(nil, f, 20, 20)                -- ring 1 colour
    swatch:SetPoint("TOPLEFT", 2, -186)
    swatch2 = GT:CreateFlatFrame(nil, f, 20, 20)               -- ring 2 colour (right next to ring 1)
    swatch2:SetPoint("TOPLEFT", 26, -186)
    local function SetupSwatch(frame, title)
        frame:EnableMouse(true)
        frame:HookScript("OnEnter", function(self)
            GT.Tip:SetOwner(self, "ANCHOR_TOP")
            GT.Tip:AddLine(GT.TR(title))
            GT.Tip:Show()
        end)
        frame:HookScript("OnLeave", function() GT.Tip:Hide() end)
    end
    SetupSwatch(swatch, "Ring 1 colour")
    SetupSwatch(swatch2, "Ring 2 colour")

    local pick = Button(f, "Ring colour...", 108, 54, -186)
    pick:SetScript("OnClick", OpenColorPicker)

    refreshers[#refreshers + 1] = UpdateSwatch

    -- ring style: line -> stripes -> dots -> line
    local STYLES = { "solid", "stripes", "dots" }
    local STYLE_TEXT = { solid = "Ring: line", stripes = "Ring: stripes", dots = "Ring: dots" }
    local styleBtn = Button(f, "", 100, 168, -186)
    local function StyleLabel() styleBtn.label:SetText(GT.TR(STYLE_TEXT[HUD.db.ringStyle] or STYLE_TEXT.solid)) end
    styleBtn:SetScript("OnClick", function()
        local cur = HUD.db.ringStyle or "solid"
        local nextStyle = STYLES[1]
        for i, s in ipairs(STYLES) do
            if s == cur then nextStyle = STYLES[(i % #STYLES) + 1] end
        end
        HUD.Set("ringStyle", nextStyle, true)
        StyleLabel()
    end)
    refreshers[#refreshers + 1] = StyleLabel

    KeyCheck(f, 0, -214, "Compass letters (N E S W)", "dirs")
    KeyCheck(f, 0, -236, "Heading readout",           "heading")
    KeyCheck(f, 0, -258, "Ready-first gathering readout", "priorityReadout")
    KeyCheck(f, 0, -280, "Route progress readout", "routeReadout")
end

local MODES = { { "auto", "Auto" }, { "own", "HUD button" }, { "stock", "Blizzard" } }

local function BuildTracking(f)
    Heading(f, 0, 0, "While the HUD is on")
    KeyCheck(f, 0, -22, "Show tracking button", "tracking")
    KeySlider(f, 0, -48,  "Button size: %s", "trackingSize", 20, 80, 1, Px)
    KeySlider(f, 0, -86,  "Offset X: %s",    "trackingX", -1500, 1500, 1)
    KeySlider(f, 0, -124, "Offset Y: %s",    "trackingY", -1000, 1000, 1)

    Heading(f, 0, -170, "While the HUD is off")
    local buttons = {}
    for i, m in ipairs(MODES) do
        local id = m[1]
        local b = Button(f, m[2], 92, (i - 1) * 96, -192)
        b:SetScript("OnClick", function()
            HUD.Set("trackIdle", id, true)
            for mid, mb in pairs(buttons) do GT:SetButtonActive(mb, HUD.db.trackIdle == mid) end
        end)
        buttons[id] = b
    end
    refreshers[#refreshers + 1] = function()
        for mid, mb in pairs(buttons) do GT:SetButtonActive(mb, HUD.db.trackIdle == mid) end
    end
    KeySlider(f, 0, -220, "Offset X: %s", "idleX", -1500, 1500, 1)
    KeySlider(f, 0, -258, "Offset Y: %s", "idleY", -1500, 1500, 1)
end

local function BuildOptions(f)
    Heading(f, 0, 0, "Behaviour")
    KeyCheck(f, 0,   -22,  "Rotate map with player",              "rotate")
    KeyCheck(f, 144, -22,  "Show player arrow",                   "arrow")
    KeyCheck(f, 0, -44,  "Hide HUD while mounted",              "mountFade")
    KeyCheck(f, 0, -66,  "Auto-enable with gathering tracking", "autoGather")
    RootCheck(f, 0, -88, "Restore HUD after /reload or login", "restoreOnLogin")
    KeyCheck(f, 0, -110, "Hide Gx and (G) timers while the HUD is off", "hideLabelsIdle")

    Heading(f, 0, -138, "Minimap addons")
    KeyCheck(f, 0, -160, "Hide minimap addon skins / buttons", "hideAddons")
    RootCheck(f, 0, -182, "Deep scan for other minimap addons", "deepScan")
    local seen = Note(f, 0, -204, COL_W, "")
    refreshers[#refreshers + 1] = function()
        local list = HUD.LoadedSkinAddons()
        seen:SetText(GT.TRF("Detected: %s", #list > 0 and table.concat(list, ", ") or GT.TR("none")))
    end

    Heading(f, 0, -226, "Diagnostics (chat output)")
    RootCheck(f, 0, -248, "Debug messages", "debug")
    local status = Button(f, "Status", 92, 0, -274)
    status:SetScript("OnClick", function() HUD.Status() end)
    local info = Button(f, "Info", 92, 96, -274)
    info:SetScript("OnClick", function() HUD.Info() end)
    local frames = Button(f, "Frames", 92, 192, -274)
    frames:SetScript("OnClick", function() HUD.ListFrames() end)
end

-- Eagle Eye map: while the hunter's Eagle Eye is on, the HUD stays up as a smaller centred map (HUD.lua, HUD.Cfg)
local function BuildEagle(f)
    Heading(f, 0, 0, "Eagle Eye map")
    local preview = Button(f, "", 140, COL_W - 140, 2)
    local function PreviewLabel()
        preview.label:SetText(GT.TR(HUD.EaglePreviewing() and "Stop preview" or "Preview Eagle map"))
        GT:SetButtonActive(preview, HUD.EaglePreviewing())
    end
    preview:SetScript("OnClick", function()
        if not HUD.IsActive() then return HUD.Print(GT.TR("Turn the HUD on first (/gthud on), then preview.")) end
        if not HUD.db.eagleMap then return HUD.Print(GT.TR("Switch on \"Show this map during Eagle Eye\" first.")) end
        HUD.EaglePreview()
        PreviewLabel()
    end)
    refreshers[#refreshers + 1] = PreviewLabel

    KeyCheck(f, 0, -22, "Show this map during Eagle Eye, Far Sight, Mind Vision", "eagleMap")
    KeySlider(f, 0, -48, "Map size: %s", "eagleSize", 150, HUD.MaxSize(), 10, Px)
    Slider(f, 0, -86, "Map opacity: %s", 0, 10, 1,
        function() return math.floor(HUD.db.eagleAlpha * 10 + 0.5) end,
        function(v)
            if math.floor(HUD.db.eagleAlpha * 10 + 0.5) ~= v then HUD.Set("eagleAlpha", v / 10, true) end
        end,
        function(v) return string.format("%d%%", math.floor(v * 10 + 0.5)) end)
    KeySlider(f, 0, -124, "Minimap zoom: %s", "eagleZoom", 0, 5, 1)
    KeyCheck(f, 0,   -162, "Rotate map with camera",  "eagleRotate")
    KeyCheck(f, 144, -162, "Ring around the map",     "eagleRing")
    KeyCheck(f, 0,   -184, "Distance scale in yards", "eagleScale")
    KeyCheck(f, 144, -184, "Nearest node readout",    "eagleNearest")
    KeyCheck(f, 0,   -206, "Hover tooltips on the map", "eagleHover")
    KeyCheck(f, 0,   -228, "Hide Gx and (G) timers on the map", "eagleHideLabels")
end

local function BuildProfiles(f)
    local nameBox

    Heading(f, 0, 0, "Profiles")
    local current = GT.Font(f, nil, "OVERLAY", "GameFontHighlightSmall")
    current:SetPoint("TOPLEFT", 2, -20)

    local box = GT:CreateFlatFrame(nil, f, COL_W, 122)
    box:SetPoint("TOPLEFT", 0, -40)
    box:SetBackdropColor(0.04, 0.04, 0.04, 1)

    local function createRow(list)
        local r = CreateFrame("Button", nil, list)
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints()
        r.hl:SetTexture(FLAT)
        r.hl:SetVertexColor(unpack(GT.colors.hover))
        r.hl:Hide()
        r.text = GT.Font(r, nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 6, 0)
        r.text:SetPoint("RIGHT", -2, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r:SetScript("OnEnter", function(s) s.hl:Show() end)
        r:SetScript("OnLeave", function(s) s.hl:Hide() end)
        r:SetScript("OnClick", function(s)
            if s.item and nameBox then nameBox:SetText(s.item) end   -- select: then Switch or Delete
        end)
        return r
    end
    local function updateRow(row, name)
        row.text:SetText(name)
        if name == HUD.ProfileCurrent() then row.text:SetTextColor(1, 0.82, 0) else row.text:SetTextColor(1, 1, 1) end
    end
    local list = GT:CreateScrollList(box, COL_W - 2, 120, 20, createRow, updateRow)
    list:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)

    nameBox = GT:CreateEditBox(f, 196, 20)
    nameBox:SetPoint("TOPLEFT", 0, -172)
    nameBox:SetJustifyH("LEFT")
    nameBox:SetMaxLetters(24)

    local function ApplyName()
        local name = strtrim(nameBox:GetText() or "")
        if name == "" then return end
        local created = HUD.ProfileSwitch(name)
        HUD.Print(GT.TRF(created and "Created and switched to profile %s" or "Switched to profile %s", name))
        nameBox:ClearFocus()
    end
    local go = Button(f, "Switch / new", 88, 200, -172)
    go:SetScript("OnClick", ApplyName)
    nameBox:SetScript("OnEnterPressed", function() ApplyName() end)

    local del = Button(f, "Delete profile", 138, 0, -200)
    GT:SetConfirmClick(del, "Delete profile", function()
        local name = strtrim(nameBox:GetText() or "")
        if name == "" then return HUD.Print(GT.TR("Select the profile to delete first.")) end
        local ok, err = HUD.ProfileDelete(name)
        HUD.Print(ok and GT.TRF("Deleted profile %s", name) or GT.TRF("Cannot delete: %s", tostring(err)))
        if ok then nameBox:SetText(HUD.ProfileCurrent()) end
        Config.Refresh()
    end)
    Note(f, 0, -228, COL_W,
        "Click a profile to select it, or type a new name (a new profile starts as a copy of the current one). The profile in use and \"Default\" cannot be deleted. Profiles are shared by all characters; each character remembers its own.")

    RefreshProfiles = function()
        current:SetText(GT.TRF("Current profile: |cffffff00%s|r", HUD.ProfileCurrent()))
        list:SetItems(HUD.ProfileList())
    end
    nameBox:SetText(HUD.ProfileCurrent())
end

-- ----------------------------------------------------------------------------------------------- panel
local function ShowTab(id)
    for tid, f in pairs(tabFrames) do f:SetShown(tid == id) end
    for tid, b in pairs(tabButtons) do GT:SetButtonActive(b, tid == id) end
    if id == "profiles" then RefreshProfiles() end
end

-- Panel builder: GT:CreatePanel("HUD") (Panels.lua) makes the 300 x 400 frame, header and content area.
GT.panelBuilders.HUD = function(p, content)
    p.header.title:SetText(GT.TR("HUD"))

    -- tab row: 6 flat buttons, 2 px apart
    local TAB_W, TAB_GAP = 46, 2
    for i, def in ipairs(TABS) do
        local id, text = def[1], def[2]
        local b = GT:CreateFlatButton(content, text, TAB_W, 20)
        b:SetPoint("TOPLEFT", (i - 1) * (TAB_W + TAB_GAP), 0)
        b:SetScript("OnClick", function() ShowTab(id) end)
        tabButtons[id] = b

        local sub = CreateFrame("Frame", nil, content)
        sub:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -30)
        sub:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 28)   -- room for the button row below
        sub:Hide()
        tabFrames[id] = sub
    end
    BuildMap(tabFrames.map)
    BuildOverlay(tabFrames.overlay)
    BuildTracking(tabFrames.tracking)
    BuildOptions(tabFrames.options)
    BuildEagle(tabFrames.eagle)
    BuildProfiles(tabFrames.profiles)

    -- bottom row (visible on every tab)
    local reset = GT:CreateFlatButton(content, "Reset profile", 142, 22)
    reset:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    GT:SetConfirmClick(reset, "Reset profile", function() HUD.ResetProfile() end)

    p:SetScript("OnShow", function() Config.Refresh() end)
    ShowTab("map")
end

-- ----------------------------------------------------------------------------------------------- public API
-- Called by HUD.Init() (GatherTimes' ADDON_LOADED), after GatherTimesDB.hud exists and the main window is built.
function Config.Init()
    if built then return end
    panel = GT:CreatePanel("HUD")
    built = true
end

-- Re-read every control. Safe to call at any time (does nothing while the panel is closed; OnShow refreshes).
function Config.Refresh()
    if not (built and panel:IsShown()) then return end
    for _, fn in ipairs(refreshers) do fn() end
    RefreshProfiles()
end

local function ShowMain()
    if GT.main and not GT.main:IsShown() then GT.main:Show() end
end

function Config.Open()
    if not built then return HUD.Print(GT.TR("The settings panel is unavailable (it failed to build).")) end
    ShowMain()
    -- HUD configuration occupies the same side slot as Random Name. Close it first
    -- so opening HUD config never leaves the two windows stacked on top of each other.
    if GT.nameDisguiseFrame and GT.nameDisguiseFrame:IsShown() then
        GT.nameDisguiseFrame:Hide()
    end
    GT:HidePanels()
    panel:Show()
end

-- opens the panel, or closes it when it is already open (like the bottom buttons of the main window)
function Config.Toggle()
    if not built then return HUD.Print(GT.TR("The settings panel is unavailable (it failed to build).")) end
    if panel:IsShown() then GT:HidePanels() else Config.Open() end
end
