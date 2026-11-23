-- GTMoveSettings.lua : the "GTMove" page in Options > AddOns (mouse-look sensitivity slider).
-- The page exists once this module is loaded; /gtmove sensitivity works before that.
if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

local YAW_MIN, YAW_MAX, YAW_STEP, YAW_DEFAULT = 90, 270, 10, 180

local category = Settings.RegisterVerticalLayoutCategory("GTMove")

local function GetYawSpeed()
    return tonumber(GetCVar("cameraYawMoveSpeed")) or YAW_DEFAULT
end

local function SetYawSpeed(value)
    SetCVar("cameraYawMoveSpeed", value)
    SetCVar("cameraPitchMoveSpeed", value / 2)
end

local setting = Settings.RegisterProxySetting(
    category,
    "GTMOVE_MOUSE_LOOK_SPEED",
    Settings.VarType.Number,
    "Mouse-look sensitivity",
    YAW_DEFAULT,
    GetYawSpeed,
    SetYawSpeed
)

local sliderOptions = Settings.CreateSliderOptions(YAW_MIN, YAW_MAX, YAW_STEP)
sliderOptions:SetLabelFormatter(
    MinimalSliderWithSteppersMixin.Label.Right,
    function(value)
        return string.format("%.1f", 1 + (value - YAW_MIN) / 20)      -- the 1-10 scale of /gtmove sensitivity
    end
)

Settings.CreateSlider(category, setting, sliderOptions, "Adjust how quickly the camera turns when using mouse-look.")
Settings.RegisterAddOnCategory(category)
