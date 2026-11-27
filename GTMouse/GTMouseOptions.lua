-- GTMouseOptions.lua : the standalone GTMouse window (/gtm). Settings are read and written through GTMouse.
local mouse = _G.GTMouse
if not mouse then return end

local WIDTH, HEIGHT = 340, 490
local MARGIN = 16
local GOLD = { 0.72, 0.58, 0.2 }

local frame = CreateFrame("Frame", "GTMouseOptionsFrame", UIParent)
frame:SetSize(WIDTH, HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()
tinsert(UISpecialFrames, "GTMouseOptionsFrame")     -- Esc closes the menu

local background = frame:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0.045, 0.05, 0.065, 0.97)

local function AddBar(point, relativePoint, x, y, width, height)
    local bar = frame:CreateTexture(nil, "BORDER")
    bar:SetPoint(point, frame, relativePoint, x, y)
    bar:SetSize(width, height)
    bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
end
AddBar("TOPLEFT", "TOPLEFT", 0, 0, WIDTH, 2)
AddBar("BOTTOMLEFT", "BOTTOMLEFT", 0, 0, WIDTH, 2)
AddBar("TOPLEFT", "TOPLEFT", 0, 0, 2, HEIGHT)
AddBar("TOPRIGHT", "TOPRIGHT", 0, 0, 2, HEIGHT)

local titleBar = frame:CreateTexture(nil, "ARTWORK")
titleBar:SetPoint("TOPLEFT", 2, -2)
titleBar:SetPoint("TOPRIGHT", -2, -2)
titleBar:SetHeight(24)
titleBar:SetColorTexture(0.12, 0.14, 0.19, 1)

-- header: the addon name; the On / Off state sits at the right, next to the close button
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("CENTER", titleBar, "CENTER")
title:SetText("GTMouse by GatherTimes")
local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local function UpdateTitle()
    status:SetText(mouse.IsEnabled() and "|cff40ff40On|r" or "|cffff4040Off|r")
end

local close = CreateFrame("Button", nil, frame)
close:SetSize(20, 20)
close:SetPoint("TOPRIGHT", -4, -4)
local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeText:SetPoint("CENTER")
closeText:SetText("X")
close:SetScript("OnClick", function() frame:Hide() end)
status:SetPoint("RIGHT", close, "LEFT", -4, 0)
UpdateTitle()

-- rowHeight (optional) centres the text vertically on a row of that height starting at y
local function AddLabel(text, x, y, font, rowHeight)
    local label = frame:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    if rowHeight then
        label:SetPoint("LEFT", frame, "TOPLEFT", x, y - rowHeight / 2)
    else
        label:SetPoint("TOPLEFT", x, y)
    end
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

-- section heading: gold text with a thin rule under it
local function AddSection(text, y)
    local heading = AddLabel(text, MARGIN, y, "GameFontNormalSmall")
    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", MARGIN, y - 15)
    rule:SetSize(WIDTH - MARGIN * 2, 1)
    rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.6)
    return heading
end

local function AddButton(text, x, y, width, height, callback)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", x, y)
    local texture = button:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(0.16, 0.2, 0.25, 1)
    button:SetNormalTexture(texture)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.32, 0.38, 0.46, 0.65)
    button:SetHighlightTexture(highlight)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(text)
    button.text = label
    button:SetScript("OnClick", callback)
    return button
end

local refreshers = {}

-- onChange (optional) runs after the setting is written
local function AddCheckbox(key, text, y, onChange)
    local check = CreateFrame("CheckButton", nil, frame)
    check:SetSize(16, 16)
    check:SetPoint("TOPLEFT", MARGIN, y)
    local normal = check:CreateTexture(nil, "BACKGROUND")
    normal:SetAllPoints()
    normal:SetColorTexture(0.12, 0.13, 0.16, 1)
    check:SetNormalTexture(normal)
    local checked = check:CreateTexture(nil, "OVERLAY")
    checked:SetAllPoints()
    checked:SetColorTexture(0.25, 0.78, 0.38, 1)
    check:SetCheckedTexture(checked)
    AddLabel(text, MARGIN + 24, y, nil, 16)
    check:SetScript("OnClick", function(self)
        mouse.ChangeSetting(key, self:GetChecked() and true or false)
        if onChange then onChange() end
    end)
    refreshers[#refreshers + 1] = function()
        check:SetChecked(mouse.GetSetting(key) == true)
    end
end

-- getter / setter default to the saved setting named by key
local function AddSlider(key, label, y, minimum, maximum, step, formatter, getter, setter)
    getter = getter or function() return mouse.GetSetting(key) end
    setter = setter or function(value) mouse.ChangeSetting(key, value) end
    AddLabel(label, MARGIN, y, nil, 14)
    local valueText = AddLabel("", WIDTH - MARGIN - 50, y, "GameFontHighlightSmall", 14)
    valueText:SetWidth(50)
    valueText:SetJustifyH("RIGHT")
    local slider = CreateFrame("Slider", nil, frame)
    slider:SetPoint("TOPLEFT", 112, y)
    slider:SetSize(160, 14)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("CENTER")
    track:SetSize(160, 4)
    track:SetColorTexture(0.2, 0.22, 0.26, 1)
    local updating = false
    slider:SetScript("OnValueChanged", function(_, value)
        value = minimum + math.floor((value - minimum) / step + 0.5) * step
        if not updating then setter(value) end
        valueText:SetText(formatter(value))
    end)
    refreshers[#refreshers + 1] = function()
        local value = getter()
        updating = true
        slider:SetValue(value)
        updating = false
        valueText:SetText(formatter(value))
    end
end

-- colour picker: uses the newer ColorPickerFrame API when present, otherwise the older one
local function OpenColorPicker(r, g, b, onChange)
    local function FromPrevious(prev)
        onChange(prev.r or prev[1], prev.g or prev[2], prev.b or prev[3])
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                onChange(nr, ng, nb)
            end,
            cancelFunc = FromPrevious,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            onChange(nr, ng, nb)
        end
        ColorPickerFrame.cancelFunc = FromPrevious
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end
end

-- a small swatch button showing the current colour; clicking opens the colour picker
local function AddColorSwatch(key, x, y)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(84, 20)
    button:SetPoint("TOPLEFT", x, y)
    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.05, 0.05, 0.07, 1)
    local fill = button:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)
    button:SetHighlightTexture(highlight)
    local function Show()
        local r, g, b = mouse.GetColor(key)
        fill:SetColorTexture(r, g, b, 1)
    end
    button:SetScript("OnClick", function()
        local r, g, b = mouse.GetColor(key)
        OpenColorPicker(r, g, b, function(nr, ng, nb)
            mouse.ChangeSetting(key, { nr, ng, nb })
            Show()
        end)
    end)
    refreshers[#refreshers + 1] = Show
end

------------------------------------------------------------------------------------------------------------------
-- general options
------------------------------------------------------------------------------------------------------------------

AddSection("General", -34)
AddCheckbox("gtmoveEnabled", "Enable GTMouse", -56, UpdateTitle)
AddCheckbox("gtmoveMount", "Turn on when mounted", -78)
AddCheckbox("gtmoveFarmArrow", "Red player arrow on FarmHud", -100)

AddSection("Mouse-look", -128)
AddSlider("gtmoveSensitivity", "Sensitivity", -152, 1, 10, 0.5,
    function(value) return string.format("%.1f", value) end,
    function() return mouse.GetSensitivityLevel() end,
    function(value) mouse.SetSensitivityLevel(value, true) end)
AddSlider("gtmoveArrowSize", "Arrow size", -176, 16, 128, 4,
    function(value) return value .. " px" end)
AddSlider("gtmoveNoteTop", "Notice position", -200, 40, 400, 10,
    function(value) return value .. " px" end)
AddSlider("gtmoveNoteSecs", "Notice time", -224, 1, 10, 1,
    function(value) return value .. " s" end)
AddCheckbox("gtmoveRightReenable", "Right-click turns mouse-look back on", -242)

------------------------------------------------------------------------------------------------------------------
-- cursor aids (WoW cannot move the real cursor)
------------------------------------------------------------------------------------------------------------------

AddSection("Cursor", -264)
AddCheckbox("gtmoveCursorTrail", "Cursor trail after looking", -286)
AddColorSwatch("gtmoveTrailColor", 232, -284)
AddSlider("gtmoveTrailOpacity", "Trail opacity", -310, 10, 100, 5,
    function(value) return value .. "%" end)
AddCheckbox("gtmoveCursorSpot", "Show cursor spot while looking", -334)
AddLabel("Spot colour", MARGIN, -358, nil, 20)
AddColorSwatch("gtmoveSpotColor", 112, -358)
AddSlider("gtmoveSpotOpacity", "Spot opacity", -384, 10, 100, 5,
    function(value) return value .. "%" end)

-- size dropdown on the same line as the spot checkbox: a button that opens a short list
do
    local SIZE_NAMES = { "Tiny", "Small", "Medium", "Large" }
    local function Current()
        return math.max(1, math.min(4, tonumber(mouse.GetSetting("gtmoveCursorSpotSize")) or 3))
    end
    local drop = AddButton("", 232, -332, 84, 20, nil)
    drop.text:SetFontObject("GameFontHighlightSmall")
    local list = CreateFrame("Frame", nil, drop)
    list:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -1)
    list:SetSize(84, 4 * 20 + 2)
    list:SetFrameLevel(drop:GetFrameLevel() + 10)
    list:Hide()
    local listBg = list:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    listBg:SetColorTexture(0.08, 0.09, 0.12, 1)
    local function Show()
        drop.text:SetText(SIZE_NAMES[Current()] .. "  v")
    end
    for i, name in ipairs(SIZE_NAMES) do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(82, 20)
        row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 20)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.32, 0.38, 0.46, 0.65)
        row:SetHighlightTexture(hl)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 8, 0)
        fs:SetText(name)
        row:SetScript("OnClick", function()
            mouse.ChangeSetting("gtmoveCursorSpotSize", i)
            list:Hide()
            Show()
        end)
    end
    drop:SetScript("OnClick", function() list:SetShown(not list:IsShown()) end)
    frame:HookScript("OnHide", function() list:Hide() end)
    refreshers[#refreshers + 1] = Show
end

------------------------------------------------------------------------------------------------------------------
-- key bindings: click a button, press a key. Right-click clears, Esc cancels.
------------------------------------------------------------------------------------------------------------------

local ACTIONS = {
    { "GTMOUSE_TOGGLE", "Toggle" },
}

local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true,
}

local bindButtons = {}
local capturing                                 -- the binding button waiting for a key press

local function KeyText(action)
    local key = GetBindingKey(action)
    if not key then return "|cff808080not bound|r" end
    local ok, text = pcall(GetBindingText, key, "KEY_")
    return (ok and text) or key
end

local function RefreshBindings()
    for _, entry in ipairs(bindButtons) do
        if capturing ~= entry.button then entry.button.text:SetText(KeyText(entry.action)) end
    end
end

local function SaveAllBindings()
    local set = GetCurrentBindingSet and GetCurrentBindingSet() or 1
    SaveBindings(set)
end

local function StopCapture()
    capturing = nil
    frame:EnableKeyboard(false)
    frame:SetScript("OnKeyDown", nil)
    RefreshBindings()
end

local function ClearAction(action)
    local keys = { GetBindingKey(action) }
    for _, key in ipairs(keys) do SetBinding(key) end
end

local function ApplyKey(action, key)
    local old = GetBindingAction(key)
    ClearAction(action)
    if old and old ~= "" and old ~= action then
        local label = _G["BINDING_NAME_" .. old] or old
        print("|cff80ff80GTMouse:|r", key, "was bound to", label, "- replaced.")
    end
    SetBinding(key, action)
    SaveAllBindings()
end

local function OnCaptureKey(self, key)
    if not capturing then return end
    if MODIFIER_KEYS[key] then return end          -- wait for the real key
    local action = capturing.action
    if key == "ESCAPE" then
        StopCapture()
        return
    end
    if InCombatLockdown() then
        print("|cffff4040GTMouse:|r", "Key bindings cannot be changed in combat.")
        StopCapture()
        return
    end
    local combo = key
    if IsShiftKeyDown() then combo = "SHIFT-" .. combo end
    if IsControlKeyDown() then combo = "CTRL-" .. combo end
    if IsAltKeyDown() then combo = "ALT-" .. combo end
    StopCapture()
    ApplyKey(action, combo)
    RefreshBindings()
end

local function StartCapture(button)
    if InCombatLockdown() then
        print("|cffff4040GTMouse:|r", "Key bindings cannot be changed in combat.")
        return
    end
    if capturing then StopCapture() end
    capturing = button
    button.text:SetText("|cffffff00Press a key...|r")
    frame:EnableKeyboard(true)
    if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(false) end
    frame:SetScript("OnKeyDown", OnCaptureKey)
end

AddSection("Key binding", -410)

for _, info in ipairs(ACTIONS) do
    local action, name = info[1], info[2]
    AddLabel(name .. " key", MARGIN, -434, nil, 22)
    local button = AddButton("", 112, -434, 160, 22, nil)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if capturing then StopCapture() end
            if InCombatLockdown() then
                print("|cffff4040GTMouse:|r", "Key bindings cannot be changed in combat.")
                return
            end
            ClearAction(action)
            SaveAllBindings()
            RefreshBindings()
        else
            StartCapture(self)
        end
    end)
    button.action = action                      -- OnCaptureKey reads the action from the button being captured
    bindButtons[#bindButtons + 1] = { action = action, button = button }
end

AddLabel("Click, then press a key. Right-click clears.", MARGIN, -460, "GameFontDisableSmall")

------------------------------------------------------------------------------------------------------------------

local function Refresh()
    for _, refresh in ipairs(refreshers) do refresh() end
    UpdateTitle()
    RefreshBindings()
end

frame:SetScript("OnShow", Refresh)
frame:SetScript("OnHide", function()
    if capturing then StopCapture() end
end)
local elapsed = 0
frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.4 then return end
    elapsed = 0
    UpdateTitle()
    RefreshBindings()
end)

function mouse.OpenOptions()
    Refresh()
    frame:Show()
end

function mouse.ToggleOptions()
    if frame:IsShown() then frame:Hide() else mouse.OpenOptions() end
end

