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
local tabFrames, sectionDropdown = {}, nil
local resetButton                    -- the Reset profile button: shown on the Profile tab only
local RefreshProfiles = function() end

local TABS = {
    { "map",      "Map",         "HUD map size, opacity, zoom, arrow, and key binding." },
    { "overlay",  "Rings",       "Configure ring size, units, colour, and style." },
    { "tracking", "Track",       "Set up the gathering tracking button and where it appears." },
    { "options",  "Options",     "Change HUD behaviour, minimap addon visibility, and diagnostics." },
    { "perf",     "Performance", "Adjust HUD performance settings and graphics options." },
    { "eagle",    "Eagle",       "Configure the map shown during Eagle Eye and similar spells." },
    { "profiles", "Profile",     "Switch HUD profiles or reset the current profile." },
}

-- ----------------------------------------------------------------------------------------------- helpers
-- Greying out: a control that has no effect right now is dimmed and disabled.  byKey maps a profile key to its
-- control (filled by KeySlider / KeyCheck); a gate lists the controls it governs and the condition that enables them.
local byKey = {}
local gates = {}
local DIMMED = 0.4

local function SetEnabledState(w, on)
    if w.Enable and w.Disable then
        if on then w:Enable() else w:Disable() end
    end
end

local function ApplyGates()
    for _, g in ipairs(gates) do
        local on = g.on() and true or false
        for _, item in ipairs(g.items) do
            local w = type(item) == "string" and byKey[item] or item
            if w then
                w:SetAlpha(on and 1 or DIMMED)
                if w.caption then w.caption:SetAlpha(on and 1 or DIMMED) end
                if w.slider then SetEnabledState(w.slider, on) end
                SetEnabledState(w, on)
            end
        end
    end
end

local function Gate(on, items)
    gates[#gates + 1] = { on = on, items = items }
end

-- shared layout for every HUD tab: rows and sliders step down the panel, groups are separated by GAP_H
local ROW_H, SLIDER_H, SECTION_H, GAP_H = 20, 34, 22, 8

-- tooltip for any control: a title and a short description, same look as the other panels
local function Tip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
        GT.Tip:AddLine(GT.TR(title))
        GT.Tip:AddLine(GT.TR(text), 0.85, 0.85, 0.85, true)
        GT.Tip:Show()
    end)
    frame:HookScript("OnLeave", function() GT.Tip:Hide() end)
end

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
    local s = Slider(parent, x, y, label, lo, hi, step,
        function() return HUD.db[key] end,
        function(v)
            if HUD.db[key] ~= v then HUD.Set(key, v, true) end
            ApplyGates()
        end,
        fmt)
    byKey[key] = s
    return s
end

local function Check(parent, x, y, text, get, set, maxW)
    local cb, caption = GT:CreateCheckLabel(parent, text, get, set, maxW)
    cb:SetPoint("TOPLEFT", x + 2, y)
    cb.caption = caption
    refreshers[#refreshers + 1] = function() cb:Refresh() end
    return cb
end

-- checkbox bound to one profile setting
local function KeyCheck(parent, x, y, text, key, maxW)
    local cb = Check(parent, x, y, text,
        function() return HUD.db[key] and true or false end,
        function(v)
            HUD.Set(key, v, true)
            ApplyGates()
        end, maxW)
    byKey[key] = cb
    return cb
end

-- checkbox bound to an account-wide HUD switch (GatherTimesDB.hud.<key>)
local function RootCheck(parent, x, y, text, key)
    return Check(parent, x, y, text,
        function() return HUD.root[key] and true or false end,
        function(v) HUD.SetRoot(key, v) end)
end

local function Px(v) return GT.TRF("%d px", v) end
local function PxOrOff(v) return v == 0 and GT.TR("off") or GT.TRF("%d px", v) end

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
    Tip(keyBtn, "Toggle key", "Bind a key that shows or hides the HUD. Click the button, then press the key. Esc cancels.")
    Tip(clear, "Clear", "Remove the key that shows or hides the HUD.")
    local capturing = false

    -- every GatherTimes key with what it does (the names are the game's own binding names)
    local BIND_LIST = { "GATHERTIMES_HUD_TOGGLE", "GATHERTIMES_EAGLE_ZOOM_IN", "GATHERTIMES_EAGLE_ZOOM_OUT", "GATHERTIMES_EAGLE_SIZE" }
    local bindRows = {}
    for i = 1, #BIND_LIST do
        local fs = GT.Font(f, nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 2, y - 50 - (i - 1) * 16)
        fs:SetWidth(COL_W - 4)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        GT.MakeFitting(fs, COL_W - 4)
        bindRows[i] = fs
    end
    local function UpdateList()
        for i, action in ipairs(BIND_LIST) do
            local k1 = GetBindingKey(action)
            local keyText = k1 and (GetBindingText(k1) or k1) or GT.TR("Not bound")
            bindRows[i]:SetText(GT.TR(_G["BINDING_NAME_" .. action] or action) .. ":  " .. keyText)
        end
    end

    local function Update()
        keyBtn.label:SetText(capturing and GT.TR("Press a key...  (Esc = cancel)") or BoundKeyText())
        GT:SetButtonActive(keyBtn, capturing)
        UpdateList()
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
    local y = 0
    Heading(f, 0, y, "Minimap")
    -- Preview: shows the HUD while this panel is open, even when the HUD is off (nothing is saved; closing the panel ends it)
    local pv = Button(f, "", 120, COL_W - 120, y + 2)
    local function PreviewLabel()
        pv.label:SetText(GT.TR(HUD.Previewing() and "Stop preview" or "Preview HUD"))
        GT:SetButtonActive(pv, HUD.Previewing())
    end
    pv:SetScript("OnClick", function() HUD.Preview(not HUD.Previewing()) end)
    Tip(pv, "Preview HUD", "Show the HUD while this panel is open, even if it is off. Nothing is saved; closing the panel ends the preview.")
    refreshers[#refreshers + 1] = PreviewLabel
    PreviewLabel()
    y = y - SECTION_H

    local size = KeySlider(f, 0, y, "HUD size: %s", "size", 150, HUD.MaxSize(), 10, Px)
    Tip(size.slider, "HUD size", "How big the HUD map is, in pixels.")
    y = y - SLIDER_H

    local arrowSize = KeySlider(f, 0, y, "Arrow size: %s", "arrowScale", 50, 200, 10, function(v) return v .. "%" end)
    Tip(arrowSize.slider, "Arrow size", "How big the player arrow in the middle of the map is. 100% is the game's own arrow. Needs Show player arrow.")
    Gate(function() return HUD.db.arrow and true or false end, { "arrowScale" })
    y = y - SLIDER_H

    -- the opacity is one of the 11 mask textures Masks\a00.tga ... a10.tga (0% = blank, 100% = opaque)
    local alpha = Slider(f, 0, y, "Map opacity: %s", 0, 10, 1,
        function() return math.floor(HUD.db.alpha * 10 + 0.5) end,
        function(v)
            if math.floor(HUD.db.alpha * 10 + 0.5) ~= v then HUD.Set("alpha", v / 10, true) end
        end,
        function(v) return string.format("%d%%", math.floor(v * 10 + 0.5)) end)
    Tip(alpha.slider, "Map opacity", "How solid the map is. 0% is invisible, 100% is fully shown.")
    y = y - SLIDER_H

    local zoom = KeySlider(f, 0, y, "Minimap zoom: %s", "zoom", 0, 5, 1)
    Tip(zoom.slider, "Minimap zoom", "How far the map is zoomed in. Higher values show a smaller area.")
    y = y - SLIDER_H - GAP_H

    BuildKeybind(f, y)
end

local function BuildOverlay(f)
    local y = 0
    Heading(f, 0, y, "Rings")
    -- unit button: switches the ring radius between pixels and yards (top right of the heading row)
    local unitBtn = GT:CreateFlatButton(f, "", 76, 15)
    unitBtn:SetPoint("TOPLEFT", 212, 1)
    Tip(unitBtn, "Ring unit", "Switch the ring radius between pixels and yards.")
    y = y - SECTION_H

    -- ring radius: one pair per unit, only the pair for the chosen unit is shown
    local YdOrOff = function(v) return v == 0 and GT.TR("off") or GT.TRF("%d yd", v) end
    local sPx1 = KeySlider(f, 0, y, "Ring radius: %s", "ring", 0, 700, 1, PxOrOff)
    local sYd1 = KeySlider(f, 0, y, "Ring radius: %s", "ringYd", 0, 250, 5, YdOrOff)
    Tip(sPx1.slider, "Ring radius", "How far from the centre the first ring is drawn, in pixels. 0 = off.")
    Tip(sYd1.slider, "Ring radius", "How far from the centre the first ring is drawn, in yards. 0 = off.")
    y = y - SLIDER_H

    local sPx2 = KeySlider(f, 0, y, "Second ring: %s", "ring2", 0, 700, 1, PxOrOff)
    local sYd2 = KeySlider(f, 0, y, "Second ring: %s", "ring2Yd", 0, 250, 5, YdOrOff)
    Tip(sPx2.slider, "Second ring", "How far from the centre the second ring is drawn, in pixels. 0 = off.")
    Tip(sYd2.slider, "Second ring", "How far from the centre the second ring is drawn, in yards. 0 = off.")
    y = y - SLIDER_H

    local function ApplyUnit()
        local yd = HUD.db.ringUnit == "yd"
        sPx1:SetShown(not yd); sPx2:SetShown(not yd)
        sYd1:SetShown(yd); sYd2:SetShown(yd)
        unitBtn.label:SetText(GT.TR(yd and "Unit: yards" or "Unit: pixels"))
    end
    unitBtn:SetScript("OnClick", function()
        HUD.Set("ringUnit", HUD.db.ringUnit == "yd" and "px" or "yd", true)
        ApplyUnit()
        ApplyGates()
    end)
    refreshers[#refreshers + 1] = ApplyUnit
    ApplyUnit()

    local thick = KeySlider(f, 0, y, "Ring thickness: %s", "ringThickness", 1, 10, 1, Px)
    Tip(thick.slider, "Ring thickness", "How thick the ring lines are, in pixels.")
    y = y - SLIDER_H

    local smooth = KeySlider(f, 0, y, "Ring smoothness: %s", "ringSegments", 8, 256, 8)
    Tip(smooth.slider, "Ring smoothness", "How many segments make up each ring. More = a smoother circle, a little more work.")
    y = y - SLIDER_H

    local density = KeySlider(f, 0, y, "Ring density: %s", "ringDensity", 4, 128, 4)
    Tip(density.slider, "Ring density", "How many dots or stripes a ring has when it is not a solid line. More = closer together.")
    y = y - SLIDER_H - GAP_H

    -- colour and style, then the readouts, in one group
    Heading(f, 0, y, "Style and readouts")
    y = y - SECTION_H

    swatch = GT:CreateFlatFrame(nil, f, 20, 20)                -- ring 1 colour
    swatch:SetPoint("TOPLEFT", 2, y)
    swatch2 = GT:CreateFlatFrame(nil, f, 20, 20)               -- ring 2 colour (right next to ring 1)
    swatch2:SetPoint("TOPLEFT", 26, y)
    swatch:EnableMouse(true); swatch2:EnableMouse(true)
    Tip(swatch, "Ring 1 colour", "The colour of the first ring. Use Ring colour... to change it.")
    Tip(swatch2, "Ring 2 colour", "The colour of the second ring. Use Ring colour... to change it.")

    local pick = Button(f, "Ring colour...", 108, 54, y)
    pick:SetScript("OnClick", OpenColorPicker)
    Tip(pick, "Ring colour...", "Open the colour picker for the rings.")
    refreshers[#refreshers + 1] = UpdateSwatch

    -- ring style: line -> stripes -> dots -> line
    local STYLES = { "solid", "stripes", "dots" }
    local STYLE_TEXT = { solid = "Ring: line", stripes = "Ring: stripes", dots = "Ring: dots" }
    local styleBtn = Button(f, "", 100, 168, y)
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
    Tip(styleBtn, "Ring style", "Change how the rings are drawn: solid line, stripes or dots.")
    refreshers[#refreshers + 1] = StyleLabel

    -- ring settings only matter while ring 1 or ring 2 has a radius
    Gate(function()
        local db = HUD.db
        if db.ringUnit == "yd" then return (db.ringYd or 0) > 0 or (db.ring2Yd or 0) > 0 end
        return (db.ring or 0) > 0 or (db.ring2 or 0) > 0
    end, { "ringThickness", "ringSegments", "ringDensity", styleBtn, pick, swatch, swatch2 })

    y = y - ROW_H - GAP_H
    local compass = KeyCheck(f, 0, y, "Compass letters (N E S W)", "dirs", 150)
    Tip(compass, "Compass letters", "Show N, E, S and W around the edge of the map.")
    local heading = KeyCheck(f, 176, y, "Heading readout", "heading", 88)
    Tip(heading, "Heading readout", "Show the direction you are facing as a number of degrees.")
    y = y - ROW_H

    local hover = KeyCheck(f, 0, y, "Hover tooltips on nodes", "hudHover")
    Tip(hover, "Hover tooltips on nodes", "Show the name of a gathering node when you hover it on the HUD map. The Eagle map has its own setting on the Eagle tab.")
    y = y - ROW_H

    local priority = KeyCheck(f, 0, y, "Ready-first gathering readout", "priorityReadout")
    Tip(priority, "Ready-first gathering readout", "Show which gathering spot is ready first.")
    y = y - ROW_H

    local route = KeyCheck(f, 0, y, "Route progress readout", "routeReadout")
    Tip(route, "Route progress readout", "Show how far you have got along the current route.")
end

local MODES = { { "auto", "Auto" }, { "own", "HUD button" }, { "stock", "Blizzard" } }

local function BuildTracking(f)
    local y = 0
    Heading(f, 0, y, "While the HUD is on")
    y = y - SECTION_H

    local show = KeyCheck(f, 0, y, "Show tracking button", "tracking")
    Tip(show, "Show tracking button", "Show a button on the HUD for the gathering tracking spell (Find Herbs, Find Minerals, Find Treasure).")
    y = y - ROW_H

    local bsize = KeySlider(f, 0, y, "Button size: %s", "trackingSize", 20, 80, 1, Px)
    Tip(bsize.slider, "Button size", "How big the tracking button is, in pixels.")
    y = y - SLIDER_H

    local tx = KeySlider(f, 0, y, "Offset X: %s", "trackingX", -1500, 1500, 1)
    Tip(tx.slider, "Offset X", "Move the tracking button sideways, in pixels, from its normal place.")
    y = y - SLIDER_H

    local ty = KeySlider(f, 0, y, "Offset Y: %s", "trackingY", -1000, 1000, 1)
    Tip(ty.slider, "Offset Y", "Move the tracking button up or down, in pixels, from its normal place.")
    y = y - SLIDER_H - GAP_H

    Gate(function() return HUD.db.tracking and true or false end, { "trackingSize", "trackingX", "trackingY" })

    Heading(f, 0, y, "While the HUD is off")
    y = y - SECTION_H

    local MODE_TIPS = {
        auto  = "Choose the tracking button automatically while the HUD is off.",
        own   = "Use the HUD's own tracking button while the HUD is off.",
        stock = "Use the game's own tracking button while the HUD is off.",
    }
    local buttons = {}
    for i, m in ipairs(MODES) do
        local id = m[1]
        local b = Button(f, m[2], 92, (i - 1) * 96, y)
        b:SetScript("OnClick", function()
            HUD.Set("trackIdle", id, true)
            for mid, mb in pairs(buttons) do GT:SetButtonActive(mb, HUD.db.trackIdle == mid) end
        end)
        Tip(b, m[2], MODE_TIPS[id])
        buttons[id] = b
    end
    refreshers[#refreshers + 1] = function()
        for mid, mb in pairs(buttons) do GT:SetButtonActive(mb, HUD.db.trackIdle == mid) end
    end
    y = y - ROW_H - 6

    local ix = KeySlider(f, 0, y, "Offset X: %s", "idleX", -1500, 1500, 1)
    Tip(ix.slider, "Offset X (HUD off)", "Move the tracking button sideways, in pixels, while the HUD is off.")
    y = y - SLIDER_H

    local iy = KeySlider(f, 0, y, "Offset Y: %s", "idleY", -1500, 1500, 1)
    Tip(iy.slider, "Offset Y (HUD off)", "Move the tracking button up or down, in pixels, while the HUD is off.")
end

local function BuildOptions(f)
    -- Layout: one option per row, grouped, same spacing as the other tabs.
    local ROW, HEAD, GAP = ROW_H, SECTION_H - 4, GAP_H
    local y = 0

    local function Section(text)
        if y < 0 then y = y - GAP end         -- no gap above the first group
        Heading(f, 0, y, text)
        y = y - HEAD
    end

    -- checkbox bound to a profile setting
    local function OptKey(text, key, description)
        local cb = KeyCheck(f, 0, y, text, key)
        Tip(cb, text, description)
        y = y - ROW
    end

    -- checkbox bound to an account-wide switch
    local function OptRoot(text, key, description)
        local cb = RootCheck(f, 0, y, text, key)
        Tip(cb, text, description)
        y = y - ROW
    end

    Section("Behaviour")
    OptKey("Rotate map with player", "rotate",
        "On: the map turns so the direction you are facing is always up.")
    OptKey("Show player arrow", "arrow",
        "On: an arrow in the middle of the map shows which way you are facing. It is hidden while the Eagle map is up.")
    OptKey("Hide HUD while mounted", "mountFade",
        "On: the HUD hides while you are mounted and comes back when you dismount.")
    OptKey("Auto-enable with gathering tracking", "autoGather",
        "On: the HUD turns on by itself while a gathering tracking spell is active (Find Herbs, Find Minerals, Find Treasure), and turns off again afterwards.")
    OptRoot("Restore HUD after /reload or login", "restoreOnLogin",
        "On: if the HUD was on when you logged out or reloaded, it is turned on again.")
    OptKey("Hide Gx and (G) timers while the HUD is off", "hideLabelsIdle",
        "On: the Gx labels and (G) timers on the minimap are hidden while the HUD is off.")

    Section("Minimap addons")
    OptKey("Hide minimap addon skins / buttons", "hideAddons",
        "On: the buttons and borders that other addons put around the minimap (SexyMap, ElvUI, LibDBIcon and similar) are hidden while the HUD is on.")
    local seen = Note(f, 0, y, COL_W, "")      -- a text label, so it has no tooltip
    seen:SetHeight(26)
    refreshers[#refreshers + 1] = function()
        local list = HUD.LoadedSkinAddons()
        seen:SetText(GT.TRF("Detected: %s", #list > 0 and table.concat(list, ", ") or GT.TR("none")))
    end
    y = y - 26

    Section("Diagnostics (chat output)")
    OptRoot("Debug messages", "debug",
        "On: the HUD prints its debug messages in chat. Only useful when reporting a problem.")
    local status = Button(f, "Status", 92, 0, y)
    status:SetScript("OnClick", function() HUD.Status() end)
    Tip(status, "Status", "Print the HUD's current status and settings to chat.")
    local info = Button(f, "Info", 92, 96, y)
    info:SetScript("OnClick", function() HUD.Info() end)
    Tip(info, "Info", "Print general information about the HUD to chat.")
    local frames = Button(f, "Frames", 92, 192, y)
    frames:SetScript("OnClick", function() HUD.ListFrames() end)
    Tip(frames, "Frames", "List the minimap frames the HUD found, in chat.")
end

local function BuildPerf(f)
    local y = 0
    local function Section(text)
        if y < 0 then y = y - GAP_H end
        Heading(f, 0, y, text)
        y = y - (SECTION_H - 4)
    end

    Section("Performance level")
    local PERF = {
        { 0, "Full",     "Full speed and saved ring detail. While the HUD is on during Eagle Eye, the Eagle map uses the normal HUD rings instead." },
        { 1, "Balanced", "Keeps the Eagle map, hides its own Eagle rings and uses the HUD rings instead; rings are limited to 48 pieces; the update loops run slower; deep scan is off. Good for most slower PCs." },
        { 2, "Lowest",   "No rings and no Eagle map (the names still show during Eagle Eye); the slowest update loops (the compass and player arrow move in coarser steps), timers refresh every 2 s while the HUD is on; deep scan is off." },
    }
    local perfButtons = {}
    for i, m in ipairs(PERF) do
        local lvl = m[1]
        local b = Button(f, m[2], 92, (i - 1) * 96, y)
        b:SetScript("OnClick", function() HUD.SetPerfLevel(lvl) end)
        Tip(b, "Performance: " .. m[2], m[3] .. " Your saved ring values are kept, so going back to Full brings them back.")
        perfButtons[lvl] = b
    end
    y = y - ROW_H - 4

    local PERF_NOTES = {
        [0] = "Full: full speed and saved ring detail; the active Eagle map uses the normal HUD rings.",
        "Balanced: the Eagle map stays; its own rings are hidden and the HUD rings are used. Rings are limited to 48 pieces and the update loops run slower.",
        "Lowest: no rings and no Eagle map (names still show during Eagle Eye). Slowest update loops; timers refresh every 2 s while the HUD is on.",
    }
    local perfNote = Note(f, 0, y, COL_W, "")
    perfNote:SetHeight(40)
    perfNote:SetJustifyV("TOP")
    refreshers[#refreshers + 1] = function()
        local cur = HUD.PerfLevel()
        for lvl, pb in pairs(perfButtons) do GT:SetButtonActive(pb, cur == lvl) end
        perfNote:SetText(GT.TR(PERF_NOTES[cur]))
    end
    y = y - 44

    Section("Extras")
    local suggest = RootCheck(f, 0, y, "Suggest this when the frame rate is low", "perfSuggest")
    Tip(suggest, "Suggest this when the frame rate is low",
        "On: if the HUD is on at Full and the frame rate stays under 25 FPS for 30 seconds, one chat line points you to this tab. It is shown once.")
    y = y - ROW_H
    local deep = RootCheck(f, 0, y, "Deep scan for other minimap addons", "deepScan")
    Tip(deep, "Deep scan for other minimap addons",
        "On: the HUD also searches the other frames on screen for minimap addons it does not know by name. This uses more processing, so keep it off unless a minimap addon is not being hidden. It is always off in Balanced and Lowest (minimap skin addons the HUD knows by name, such as SexyMap, are still handled).")
    Gate(function() return HUD.PerfLevel() == 0 end, { deep })
    y = y - ROW_H

    Section("Game graphics")
    local gfxBtn = Button(f, "", COL_W, 0, y)
    local function GfxLabel()
        local on = GT.Gfx and GT.Gfx.GetLevel() > 0
        gfxBtn.label:SetText(GT.TR(on and "Restore my game graphics" or "Also lower game graphics (Low)"))
        GT:SetButtonActive(gfxBtn, on and true or false)
    end
    gfxBtn:SetScript("OnClick", function()
        if not GT.Gfx then return end
        local okSet = GT.Gfx.SetLevel(GT.Gfx.GetLevel() > 0 and 0 or 1)
        if okSet == false then
            HUD.Print(GT.TR("The game did not accept the graphics change (it may be locked in combat). Try again out of combat."))
        end
        GfxLabel()
    end)
    Tip(gfxBtn, "Game graphics", "Sets the game's own graphics quality to Low, the same as Settings > Display > Graphics quality. Press again to put your own settings back.")
    refreshers[#refreshers + 1] = GfxLabel
    y = y - ROW_H - 4
    Note(f, 0, y, COL_W, "The HUD levels above only change this addon. This button changes the game's own graphics; your settings are remembered and put back.")
end

local function BuildEagle(f)
    local y = 0
    Heading(f, 0, y, "Eagle Eye map")
    local preview = Button(f, "", 140, COL_W - 140, y + 2)
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
    Tip(preview, "Preview Eagle map", "Show the Eagle map now to see how it looks. Needs the HUD on and the first option below switched on.")
    refreshers[#refreshers + 1] = PreviewLabel
    y = y - SECTION_H

    local enable = KeyCheck(f, 0, y, "Show this map during Eagle Eye, Far Sight, Mind Vision", "eagleMap")
    Tip(enable, "Show this map during Eagle Eye", "On: the Eagle map is shown during Eagle Eye, Far Sight, Mind Vision and similar spells. The options below only apply while it is on.")
    y = y - ROW_H - 2

    local size = KeySlider(f, 0, y, "Map size: %s", "eagleSize", 150, HUD.MaxSize(), 10, Px)
    Tip(size.slider, "Map size", "How big the Eagle map is, in pixels.")
    y = y - SLIDER_H

    byKey.eagleAlpha = Slider(f, 0, y, "Map opacity: %s", 0, 10, 1,
        function() return math.floor(HUD.db.eagleAlpha * 10 + 0.5) end,
        function(v)
            if math.floor(HUD.db.eagleAlpha * 10 + 0.5) ~= v then HUD.Set("eagleAlpha", v / 10, true) end
        end,
        function(v) return string.format("%d%%", math.floor(v * 10 + 0.5)) end)
    Tip(byKey.eagleAlpha.slider, "Map opacity (Eagle)", "How solid the Eagle map is. 0% is invisible, 100% is fully shown.")
    y = y - SLIDER_H

    local zoom = KeySlider(f, 0, y, "Minimap zoom: %s", "eagleZoom", 0, 5, 1)
    Tip(zoom.slider, "Minimap zoom (Eagle)", "How far the Eagle map is zoomed in. Higher values show a smaller area.")
    y = y - SLIDER_H - GAP_H

    local rotate = KeyCheck(f, 0, y, "Rotate map with camera", "eagleRotate")
    Tip(rotate, "Rotate map with camera", "On: the Eagle map turns with the camera direction.")
    y = y - ROW_H
    local scale = KeyCheck(f, 0, y, "Distance scale in yards", "eagleScale")
    Tip(scale, "Distance scale in yards", "On: a distance scale in yards is drawn on the Eagle map.")
    y = y - ROW_H
    local nearest = KeyCheck(f, 0, y, "Nearest node readout", "eagleNearest")
    Tip(nearest, "Nearest node readout", "On: shows the nearest gathering node and how far away it is.")
    y = y - ROW_H
    local hover = KeyCheck(f, 0, y, "Hover tooltips on the map", "eagleHover")
    Tip(hover, "Hover tooltips on the map", "On: hover a gathering node on the Eagle map to see its name.")
    y = y - ROW_H
    local labels = KeyCheck(f, 0, y, "Hide Gx and (G) timers on the map", "eagleHideLabels")
    Tip(labels, "Hide Gx and (G) timers on the map", "On: the Gx labels and (G) timers are hidden on the Eagle map.")
    y = y - ROW_H
    local layer = KeyCheck(f, 0, y, "Hide layer info (e.g. Layer 1) on the map", "eagleHideLayer")
    Tip(layer, "Hide layer info", "On: hides the layer text, such as Layer 1, on the Eagle map.")

    Gate(function() return HUD.db.eagleMap and true or false end, {
        "eagleSize", "eagleAlpha", "eagleZoom", "eagleRotate", "eagleScale",
        "eagleNearest", "eagleHover", "eagleHideLabels", "eagleHideLayer",
    })
end

local function BuildProfiles(f)
    local nameBox
    local selected                                  -- the profile clicked in the list: the one Delete acts on

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
            if s.item and nameBox then selected = s.item; nameBox:SetText(s.item) end   -- select: then Switch or Delete
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
    -- typing a name (instead of clicking a row) means the highlighted profile is no longer the target
    nameBox:SetScript("OnTextChanged", function(_, byUser) if byUser then selected = nil end end)

    local function ApplyName()
        local raw = (nameBox:GetText() or ""):gsub("|", "")   -- "|" would break the colour codes in the text
        local name = strtrim(raw)
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
        local name = selected                         -- the profile highlighted in the list, not whatever is typed
        if not name then return HUD.Print(GT.TR("Select the profile to delete first.")) end
        local ok, err = HUD.ProfileDelete(name)
        HUD.Print(ok and GT.TRF("Deleted profile %s", name) or GT.TRF("Cannot delete: %s", tostring(err)))
        if ok then selected = nil; nameBox:SetText(HUD.ProfileCurrent()) end
        Config.Refresh()
    end)
    -- the first click names the profile it will delete; the second click (label back to normal) deletes it
    del:HookScript("OnClick", function(self)
        if selected and self.label:GetText() == GT.TR("Click again!") then
            HUD.Print(GT.TRF("Click Delete profile again to remove profile %s.", selected))
        end
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
    for i, def in ipairs(TABS) do
        if def[1] == id then sectionDropdown:SetSelected(i); break end
    end
    ApplyGates()
    if resetButton then resetButton:SetShown(id == "profiles") end
    if id == "profiles" then RefreshProfiles() end
end

-- Panel builder: GT:CreatePanel("HUD") (Panels.lua) makes the 300 x 400 frame, header and content area.
GT.panelBuilders.HUD = function(p, content)
    p.header.title:SetText(GT.TR("HUD"))

    local section = GT.Font(content, nil, "OVERLAY", "GameFontHighlightSmall")
    section:SetPoint("LEFT", content, "TOPLEFT", 2, -10)
    section:SetText(GT.TR("Section:"))
    local items = {}
    for i, def in ipairs(TABS) do
        items[i] = { text = GT.TR(def[2]), tooltip = def[3] }
    end
    sectionDropdown = GT:CreateDropdown(content, 160, 20, items, function(index)
        ShowTab(TABS[index][1])
    end)
    sectionDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", 62, 0)

    for _, def in ipairs(TABS) do
        local id = def[1]
        local sub = CreateFrame("Frame", nil, content)
        sub:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -30)
        sub:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, id == "profiles" and 28 or 0)   -- room for Reset profile
        sub:Hide()
        tabFrames[id] = sub
    end
    BuildMap(tabFrames.map)
    BuildOverlay(tabFrames.overlay)
    BuildTracking(tabFrames.tracking)
    BuildOptions(tabFrames.options)
    BuildPerf(tabFrames.perf)
    BuildEagle(tabFrames.eagle)
    BuildProfiles(tabFrames.profiles)

    -- Reset profile sits on the panel frame; ShowTab shows it on the Profile tab only
    local reset = GT:CreateFlatButton(p, "Reset profile", 142, 22)
    resetButton = reset
    reset:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 6, 6)
    reset:SetFrameLevel(p:GetFrameLevel() + 10)
    GT:SetConfirmClick(reset, "Reset profile", function() HUD.ResetProfile() end)
    Tip(reset, "Reset profile", "Reset the current HUD profile to the default settings. Click twice to confirm.")

    p:SetScript("OnShow", function() Config.Refresh() end)
    ShowTab("map")
end

-- ----------------------------------------------------------------------------------------------- public API
-- Called by HUD.Init() (GatherTimes' ADDON_LOADED), after GatherTimesDB.hud exists and the main window is built.
function Config.Init()
    if built then return end
    panel = GT:CreatePanel("HUD")
    panel:HookScript("OnHide", function() HUD.Preview(false) end)
    built = true
end

-- Re-read every control. Safe to call at any time (does nothing while the panel is closed; OnShow refreshes).
function Config.Refresh()
    if not (built and panel:IsShown()) then return end
    for _, fn in ipairs(refreshers) do fn() end
    ApplyGates()
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
