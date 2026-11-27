-- GTMouseSettings.lua : the "GTMouse" page in Options > AddOns. /gtm opens the standalone window.
local mouse = _G.GTMouse
if not mouse then return end
if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

local category = Settings.RegisterVerticalLayoutCategory("GTMouse")

local function AddBooleanOption(key, label, tooltip)
    local setting = Settings.RegisterProxySetting(category, "GTMOUSE_" .. string.upper(key),
        Settings.VarType.Boolean, label, mouse.DEFAULTS[key] == true,
        function() return mouse.GetSetting(key) == true end,
        function(value) mouse.ChangeSetting(key, value == true) end)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddNumberOption(key, label, minimum, maximum, step, tooltip)
    local setting = Settings.RegisterProxySetting(category, "GTMOUSE_" .. string.upper(key),
        Settings.VarType.Number, label, mouse.DEFAULTS[key],
        function() return mouse.GetSetting(key) end,
        function(value) mouse.ChangeSetting(key, value) end)
    Settings.CreateSlider(category, setting, Settings.CreateSliderOptions(minimum, maximum, step), tooltip)
end

-- Camera turn speed. It is stored as the game's CVars, so it is shared by all characters and is not switched off
-- with the master switch.
local setting = Settings.RegisterProxySetting(
    category,
    "GTMOUSE_MOUSE_LOOK_SPEED",
    Settings.VarType.Number,
    "Mouse-look sensitivity",
    mouse.YAW_DEFAULT,
    mouse.GetYawSpeed,
    mouse.SetYawSpeed
)

local sliderOptions = Settings.CreateSliderOptions(mouse.YAW_MIN, mouse.YAW_MAX, 10)
sliderOptions:SetLabelFormatter(
    MinimalSliderWithSteppersMixin.Label.Right,
    function(value)
        return string.format("%.1f", mouse.YawToLevel(value))     -- the 1-10 scale of /gtmouse sensitivity
    end
)

Settings.CreateSlider(category, setting, sliderOptions,
    "How quickly the camera turns when using mouse-look. This is a game setting shared by all characters.")

AddBooleanOption("gtmoveEnabled", "Enable GTMouse",
    "Master switch. When off, the key binding, slash commands, automatic mouse-look and the red arrow do nothing. " ..
    "It is off by default; once turned on it stays on after reload or login.")
AddBooleanOption("gtmoveRightReenable", "Right-click turns mouse-look back on",
    "When the game ends mouse-look because of a right-click, the next right-click turns it back on. " ..
    "This also happens when you right-click NPCs, players or items. Off by default.")
AddBooleanOption("gtmoveMount", "Turn on when mounted",
    "Turn mouse-look on when you mount and off when you dismount.")
AddNumberOption("gtmoveNoteTop", "Notice position from top", 40, 400, 10,
    "Vertical position of mouse-look notices, in pixels.")
AddNumberOption("gtmoveNoteSecs", "Notice duration", 1, 10, 1,
    "How long mouse-look notices remain visible, in seconds.")
AddBooleanOption("gtmoveFarmArrow", "Red player arrow on FarmHud",
    "While mouse-look is on and FarmHud is showing, draw the player arrow in bright red.")
AddBooleanOption("gtmoveCharMarker", "Character marker without a HUD",
    "While mouse-look is on and no HUD (FarmHud or the GatherTimes HUD) is showing, an animated ring marks the centre of the screen, where your character is.")
AddNumberOption("gtmoveArrowSize", "Player arrow size", 16, 128, 4,
    "Size of the red player arrow on FarmHud, in pixels.")

Settings.RegisterAddOnCategory(category)
