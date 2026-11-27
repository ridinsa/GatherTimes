-- GTMouse.lua : mouse-look toggle (one key binding) and a resizable red player arrow on FarmHud.
-- The shared API lives in the global GTMouse table. GTMouseSettings.lua and GTMouseOptions.lua build their menus on it.

local PREFIX_OK, PREFIX_ERR = "|cff80ff80GTMouse:|r", "|cffff4040GTMouse:|r"

-- Defaults for every saved setting. Both menus read their defaults from here.
local DEFAULTS = {
    gtmoveEnabled        = false,   -- master switch; off by default, then remembered across login / reload
    gtmoveRightReenable  = false,   -- after a right-click ends mouse-look, the next right-click turns it back on
    gtmoveMount          = false,   -- mouse-look follows mounting and dismounting
    gtmoveFarmArrow      = true,    -- red arrow on FarmHud while mouse-look is on
    gtmoveArrowSize      = 40,      -- 16-128 px
    gtmoveNoteTop        = 160,     -- 40-400 px from the top of the screen
    gtmoveNoteSecs       = 3,       -- 1-10 s
    gtmoveCursorTrail    = true,    -- ring that follows the cursor after mouse-look ends
    gtmoveCursorSpot     = true,    -- ring marking where the cursor was when mouse-look started
    gtmoveCursorSpotSize = 3,       -- 1 tiny, 2 small, 3 medium, 4 large
    gtmoveCharMarker     = true,    -- ring at the centre of the screen (the character) while looking and no HUD is shown
    gtmoveTrailColor     = { 1, 1, 1 },   -- r, g, b (0-1)
    gtmoveSpotColor      = { 1, 1, 1 },
    gtmoveTrailOpacity   = 100,     -- percent
    gtmoveSpotOpacity    = 100,
}

-- Sensitivity: level 1-10 maps to cameraYawMoveSpeed 90-270, 20 units per level.
local YAW_MIN, YAW_MAX, YAW_DEFAULT = 90, 270, 180
local DEFAULT_LEVEL = 5.5

local function LevelToYaw(level) return YAW_MIN + (level - 1) * 20 end
local function YawToLevel(yaw) return 1 + (yaw - YAW_MIN) / 20 end
local function RoundHalf(x) return math.floor(x * 2 + 0.5) / 2 end

if type(GTMouseDB) ~= "table" then GTMouseDB = {} end

local function GetSetting(key, default)
    if type(GTMouseDB) == "table" and GTMouseDB[key] ~= nil then return GTMouseDB[key] end
    if default ~= nil then return default end
    return DEFAULTS[key]
end

local function SetSetting(key, value)
    if type(GTMouseDB) ~= "table" then GTMouseDB = {} end
    GTMouseDB[key] = value
end

-- colour settings come back as r, g, b (0-1); opacity settings as a fraction (0-1)
local function GetColor(key)
    local c = GetSetting(key)
    if type(c) ~= "table" then c = DEFAULTS[key] end
    return c[1] or 1, c[2] or 1, c[3] or 1
end

local function GetOpacity(key)
    local v = tonumber(GetSetting(key)) or 100
    return math.max(0, math.min(100, v)) / 100
end

-- Saved variables are loaded by the time ADDON_LOADED fires for this addon. The master switch is NOT reset here:
-- it keeps its saved value across login / reload (default off). Settings from removed options are cleared.
local resetFrame = CreateFrame("Frame")
resetFrame:RegisterEvent("ADDON_LOADED")
resetFrame:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= "GTMouse" then return end
    self:UnregisterEvent("ADDON_LOADED")
    if type(GTMouseDB) ~= "table" then GTMouseDB = {} end
    GTMouseDB.gtmoveWasOn, GTMouseDB.gtmoveRemember = nil, nil
    GTMouseDB.gtmoveCursor, GTMouseDB.gtmoveCursorSize = nil, nil
end)

-- master switch: when off, GTMouse does nothing (key binding, slash commands, mount auto-on, arrow)
local function IsEnabled()
    return GetSetting("gtmoveEnabled") == true
end

-- Explains why nothing happened when the master switch is off. Returns true when GTMouse is enabled.
local function RequireEnabled()
    if IsEnabled() then return true end
    print(PREFIX_ERR, "GTMouse is turned off. Turn it on in /gtm first.")
    return false
end

BINDING_HEADER_GTMOUSE = "GTMouse"
BINDING_NAME_GTMOUSE_TOGGLE = "Toggle mouse-look"

local function IsMouseLooking()
    return IsMouselooking and IsMouselooking() and true or false
end

-- Declared here so the monitor and the settings code can call it before its body is defined below.
local UpdateArrow

------------------------------------------------------------------------------------------------------------------
-- sensitivity (stored as the game's camera CVars, so it applies to every character and stays after GTMouse is off)
------------------------------------------------------------------------------------------------------------------

local function GetYawSpeed()
    return tonumber(GetCVar("cameraYawMoveSpeed")) or YAW_DEFAULT
end

local function SetYawSpeed(yaw)
    yaw = math.max(YAW_MIN, math.min(YAW_MAX, tonumber(yaw) or YAW_DEFAULT))
    SetCVar("cameraYawMoveSpeed", yaw)
    SetCVar("cameraPitchMoveSpeed", yaw / 2)
end

local function SetSensitivityLevel(level, quiet)
    level = tonumber(level)
    if not level or level < 1 or level > 10 then
        print(PREFIX_ERR, "Sensitivity must be a number from 1 to 10.")
        return false
    end
    level = RoundHalf(level)
    SetYawSpeed(LevelToYaw(level))
    if not quiet then print(PREFIX_OK, string.format("Mouse-look sensitivity set to %.1f/10.", level)) end
    return true
end

local function GetSensitivityLevel()
    return math.max(1, math.min(10, RoundHalf(YawToLevel(GetYawSpeed()))))
end

------------------------------------------------------------------------------------------------------------------
-- mouse-look state
------------------------------------------------------------------------------------------------------------------

-- True only while GTMouse itself has mouse-look on. The game's IsMouselooking() also reports true while the
-- player's own turn keys steer, so this tracks GTMouse's state.
local ownLook = false

-- WoW cannot move the mouse cursor, so there are two aids:
--   cursor trail : when mouse-look ends, a pulsing ring follows the cursor for about 1.5 s
--   cursor spot  : while mouse-look is on, a ring marks where the cursor was when it started
local trail, trailLeft
local TRAIL_SECS = 1.5
local function ShowTrail()
    if GetSetting("gtmoveCursorTrail") ~= true then return end
    if not trail then
        trail = CreateFrame("Frame", nil, UIParent)
        trail:SetFrameStrata("TOOLTIP")
        trail:SetSize(64, 64)
        trail:EnableMouse(false)
        trail.tex = trail:CreateTexture(nil, "OVERLAY")
        trail.tex:SetAllPoints()
        trail.tex:SetTexture("Interface\\Cooldown\\ping4")
        trail.tex:SetBlendMode("ADD")
        trail:SetScript("OnUpdate", function(self, elapsed)
            trailLeft = trailLeft - elapsed
            if trailLeft <= 0 then self:Hide() return end
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
            local p = trailLeft / TRAIL_SECS                      -- 1 -> 0
            local size = 28 + 60 * (0.5 + 0.5 * math.sin(p * 18)) * p
            self:SetSize(size, size)
            self:SetAlpha(math.min(1, p * 1.5) * GetOpacity("gtmoveTrailOpacity"))
        end)
    end
    local r, g, b = GetColor("gtmoveTrailColor")
    trail.tex:SetVertexColor(r, g, b, 1)
    trailLeft = TRAIL_SECS
    trail:Show()
end

-- cursor spot: a white circle with a thin white crosshair inside, centred on where the cursor was
local SPOT_SIZES = { 28, 40, 56, 72 }     -- tiny, small, medium, large (gtmoveCursorSpotSize 1-4)
local SPOT_THICK, SPOT_GAP = 2, 5          -- crosshair line thickness and the open gap around the centre
local spot, spotRing, spotArms

-- arms run outward from the centre and stop short of the ring
local function LayoutSpot(size)
    local arm = size / 2 - SPOT_GAP - 3
    spotArms.left:SetSize(arm, SPOT_THICK)
    spotArms.left:SetPoint("RIGHT", spot, "CENTER", -SPOT_GAP, 0)
    spotArms.right:SetSize(arm, SPOT_THICK)
    spotArms.right:SetPoint("LEFT", spot, "CENTER", SPOT_GAP, 0)
    spotArms.top:SetSize(SPOT_THICK, arm)
    spotArms.top:SetPoint("BOTTOM", spot, "CENTER", 0, SPOT_GAP)
    spotArms.bottom:SetSize(SPOT_THICK, arm)
    spotArms.bottom:SetPoint("TOP", spot, "CENTER", 0, -SPOT_GAP)
end

local function BuildSpot()
    spot = CreateFrame("Frame", nil, UIParent)
    spot:SetFrameStrata("TOOLTIP")
    spot:EnableMouse(false)
    spotRing = spot:CreateTexture(nil, "ARTWORK")
    spotRing:SetTexture("Interface\\Cooldown\\ping4")
    spotRing:SetAllPoints()
    spotRing:SetVertexColor(1, 1, 1, 1)
    spotRing:SetBlendMode("ADD")          -- additive: the texture's dark pixels become transparent
    spotArms = {}
    for _, name in ipairs({ "left", "right", "top", "bottom" }) do
        local t = spot:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1)
        spotArms[name] = t
    end
end

local function HideSpot()
    if spot then spot:Hide() end
end

local function ShowSpot(x, y)
    if GetSetting("gtmoveCursorSpot") ~= true then return end
    if not spot then BuildSpot() end
    local scale = UIParent:GetEffectiveScale()
    local size = SPOT_SIZES[tonumber(GetSetting("gtmoveCursorSpotSize")) or 3] or SPOT_SIZES[3]
    spot:SetSize(size, size)
    LayoutSpot(size)
    local r, g, b = GetColor("gtmoveSpotColor")
    spotRing:SetVertexColor(r, g, b, 1)
    for _, arm in pairs(spotArms) do arm:SetColorTexture(r, g, b, 1) end
    spot:SetAlpha(GetOpacity("gtmoveSpotOpacity"))
    spot:ClearAllPoints()
    spot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    spot:Show()
end

-- character marker: with no HUD (FarmHud or the GatherTimes HUD) the same pulsing ring as the cursor trail is shown at
-- the centre of the screen, where the character is, for as long as mouse-look is on. It uses the cursor trail's
-- colour and opacity settings.
local charMark
local CHAR_MARK_SIZE = 28
local function ShowCharMark()
    if not charMark then
        charMark = CreateFrame("Frame", nil, UIParent)
        charMark:SetFrameStrata("HIGH")
        charMark:SetFrameLevel(5)
        charMark:EnableMouse(false)
        charMark:SetSize(CHAR_MARK_SIZE, CHAR_MARK_SIZE)
        charMark:SetPoint("CENTER", UIParent, "CENTER")
        charMark.tex = charMark:CreateTexture(nil, "OVERLAY")
        charMark.tex:SetAllPoints()
        charMark.tex:SetTexture("Interface\\Cooldown\\ping4")
        charMark.tex:SetBlendMode("ADD")
        charMark:SetScript("OnUpdate", function(self)
            -- the trail's pulse, looping: p goes 0 -> 1 -> 0 smoothly
            local p = 0.5 + 0.5 * math.sin(GetTime() * 4)
            local size = CHAR_MARK_SIZE + 60 * (0.5 + 0.5 * math.sin(p * 18)) * p
            self:SetSize(size, size)
            self:SetAlpha((0.2 + 0.8 * p) * GetOpacity("gtmoveTrailOpacity"))
        end)
    end
    local r, g, b = GetColor("gtmoveTrailColor")
    charMark.tex:SetVertexColor(r, g, b, 1)
    charMark:Show()
end

local function HideCharMark()
    if charMark then charMark:Hide() end
end

-- Right-click re-enable (option, off by default). The game itself ends mouse-look when the right button is pressed and released. When that
-- is what ended GTMouse's mouse-look, the next right-click turns it back on (after the button is released).
-- While GTMouse's mouse-look is on this notes when the right button was last down; once the game ends it, it waits for
-- the next click. A toggle-key or menu stop never re-arms it.
local rightWatch = CreateFrame("Frame")
rightWatch:Hide()
local lastRightSeen = 0
local rearm, rightPressed, rightWasDown = false, false, false
local SetMouseLooking                   -- defined below

local function DisarmRight()
    rearm, rightPressed = false, false
    rightWatch:Hide()
end

rightWatch:SetScript("OnUpdate", function()
    local down = IsMouseButtonDown("RightButton") and true or false
    if ownLook then
        if down then lastRightSeen = GetTime() end
    elseif rearm then
        if down and not rightWasDown then rightPressed = true end
        if not down and rightPressed then
            DisarmRight()
            if IsEnabled() then SetMouseLooking(true) end
        end
    end
    rightWasDown = down
end)

-- Runs only while GTMouse's mouse-look is on. Notices when the game ends it, and keeps the red arrow in step.
local monitor = CreateFrame("Frame")
monitor:Hide()
local monitorElapsed = 0
monitor:SetScript("OnUpdate", function(self, elapsed)
    monitorElapsed = monitorElapsed + elapsed
    if monitorElapsed < 0.1 then return end
    monitorElapsed = 0
    if not IsMouseLooking() then
        if ownLook then
            ShowTrail()
            if GetSetting("gtmoveRightReenable") == true and GetTime() - lastRightSeen < 0.4 then          -- the game ended it because of a right-click
                rearm, rightPressed = true, false
                rightWasDown = IsMouseButtonDown("RightButton") and true or false
            end
        end
        ownLook = false
        HideSpot()
        if not rearm then rightWatch:Hide() end
        self:Hide()
    end
    UpdateArrow()
end)

-- on-screen notice: a small dark panel near the top of the screen, sized to its text, that fades out
local noteFrame, noteLabel
local noteToken = 0
local function Note(text)
    if not noteFrame then
        noteFrame = CreateFrame("Frame", nil, UIParent)
        noteFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        local bg = noteFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.045, 0.05, 0.065, 0.85)
        noteLabel = noteFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noteLabel:SetPoint("CENTER")
        noteFrame:Hide()
    end
    noteToken = noteToken + 1
    local token = noteToken
    UIFrameFadeRemoveFrame(noteFrame)               -- cancel a fade-out still running from an earlier notice
    noteLabel:SetText(text)
    noteFrame:SetSize(noteLabel:GetStringWidth() + 28, 28)
    noteFrame:ClearAllPoints()
    noteFrame:SetPoint("TOP", UIParent, "TOP", 0, -GetSetting("gtmoveNoteTop"))
    noteFrame:SetAlpha(1)
    noteFrame:Show()
    C_Timer.After(GetSetting("gtmoveNoteSecs"), function()
        if token ~= noteToken then return end        -- a newer notice takes over
        UIFrameFade(noteFrame, {
            mode = "OUT", timeToFade = 0.5, startAlpha = 1, endAlpha = 0,
            finishedFunc = function() noteFrame:Hide() end,
        })
    end)
end

-- quiet = true suppresses the notice (used for automatic mounting and for UI-driven stops)
function SetMouseLooking(enabled, quiet)
    if enabled then
        if not IsEnabled() then return end
        if not IsMouseLooking() and MouselookStart then
            local x, y = GetCursorPosition()
            MouselookStart()
            ShowSpot(x, y)
        end
        ownLook = true
        rearm, rightPressed = false, false
        lastRightSeen = 0
        rightWatch:Show()
        monitor:Show()
        UpdateArrow()
        if IsMouseLooking() and not quiet then
            Note("Mouse-look |cff40ff40ON|r")
        end
    else
        local wasOn = ownLook
        DisarmRight()
        if IsMouseLooking() and MouselookStop then MouselookStop() end
        ownLook = false
        monitor:Hide()
        HideSpot()
        UpdateArrow()
        if wasOn then ShowTrail() end
        if not quiet then Note("Mouse-look |cffff4040OFF|r") end
    end
end

local function ToggleMouseLooking()
    if not RequireEnabled() then return end
    SetMouseLooking(not ownLook)
end

-- opening the game menu, closing windows, starting to type in chat, or pressing Esc in the chat box ends mouse-look
local function StopMouseLookForUI()
    if IsEnabled() and IsMouseLooking() then SetMouseLooking(false, true) end
end
for _, name in ipairs({ "ToggleGameMenu", "CloseWindows", "ChatEdit_ActivateChat", "ChatEdit_OnEscapePressed" }) do
    if type(_G[name]) == "function" then hooksecurefunc(name, StopMouseLookForUI) end
end

-- mount auto-toggle: MountOn starts mouse-look only if it is not already on, and MountOff ends only what it started
local mountStarted = false

local function MountOn()
    if ownLook or not IsEnabled() then return end
    mountStarted = true
    SetMouseLooking(true, true)
end

local function MountOff()
    if not mountStarted then return end
    mountStarted = false
    if ownLook then SetMouseLooking(false, true) end
end

local function SetEnabled(value)
    SetSetting("gtmoveEnabled", value == true)
    if value ~= true then
        DisarmRight()
        mountStarted = false
        if ownLook then SetMouseLooking(false, true) end     -- only GTMouse's own mouse-look; the player's own is left alone
    end
end

------------------------------------------------------------------------------------------------------------------
-- red player arrow on FarmHud
------------------------------------------------------------------------------------------------------------------

-- FarmHud turns the minimap into the HUD, and the game draws its player arrow at a fixed size that addons cannot
-- change. While the red arrow is wanted, the game's arrow is swapped for a blank texture and the default arrow,
-- tinted see-through red, is drawn at the chosen size over the middle of the minimap.
local ARROW_RED_TINT = { 1, 0.1, 0.1, 0.75 }
local ARROW_BLANK = "Interface\\AddOns\\GTMouse\\Blank"
local ARROW_DEFAULT = "Interface\\Minimap\\MinimapArrow"
local ARROW_SIZE_MIN, ARROW_SIZE_MAX = 16, 128
local lastArrow                     -- the texture FarmHud / the game last set, restored when the red arrow ends
local arrowRed = false

local arrowFrame = CreateFrame("Frame", nil, UIParent)
arrowFrame:EnableMouse(false)
arrowFrame:Hide()
local arrowTexture = arrowFrame:CreateTexture(nil, "OVERLAY")
arrowTexture:SetAllPoints()
arrowTexture:SetTexture(ARROW_DEFAULT)
arrowTexture:SetVertexColor(ARROW_RED_TINT[1], ARROW_RED_TINT[2], ARROW_RED_TINT[3], ARROW_RED_TINT[4])

local function ArrowSize()
    local size = tonumber(GetSetting("gtmoveArrowSize")) or DEFAULTS.gtmoveArrowSize
    return math.max(ARROW_SIZE_MIN, math.min(ARROW_SIZE_MAX, size))
end

local function LayoutArrow()
    local size = ArrowSize()
    arrowFrame:SetSize(size, size)
    arrowFrame:ClearAllPoints()
    arrowFrame:SetPoint("CENTER", Minimap, "CENTER")
    arrowFrame:SetFrameStrata("HIGH")          -- above the HUD map (FarmHud, or GatherTimes which puts the minimap at BACKGROUND)
    arrowFrame:SetFrameLevel(10)
end

-- With a rotating minimap the arrow always points up; otherwise it has to turn with the player.
local function TurnArrow()
    local rotates = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = (not rotates) and GetPlayerFacing and GetPlayerFacing() or 0
    arrowTexture:SetRotation(facing or 0)
end

-- Turning the arrow needs a per-frame update, so this frame only runs while the red arrow is shown.
local arrowTurner = CreateFrame("Frame")
arrowTurner:Hide()
local turnElapsed = 0
arrowTurner:SetScript("OnUpdate", function(_, delta)
    turnElapsed = turnElapsed + delta
    if turnElapsed < 0.05 then return end
    turnElapsed = 0
    TurnArrow()
end)

-- Our own calls are flagged, so they are never taken for the stock arrow. Calls by other addons are remembered,
-- blanks included: GatherTimes hides the arrow with a blank and expects to restore it. Red is kept while it is wanted.
local settingArrow = false
local function SetArrow(texture)
    settingArrow = true
    Minimap:SetPlayerTexture(texture)
    settingArrow = false
end

if Minimap and Minimap.SetPlayerTexture then
    hooksecurefunc(Minimap, "SetPlayerTexture", function(_, texture)
        if settingArrow then return end
        lastArrow = texture
        if arrowRed then SetArrow(ARROW_BLANK) end     -- another addon changed it while red is wanted: hide it again
    end)
end

-- GatherTimes' HUD is a FarmHud-style map: it moves the minimap to UIParent, so the parent test below cannot see it.
local function GatherTimesHudActive()
    local gt = _G.GatherTimesAddon
    local hud = gt and gt.HUD
    if hud and hud.IsActive then
        local ok, on = pcall(hud.IsActive)
        return ok and on == true
    end
    return false
end

local function FarmHudActive()
    if GatherTimesHudActive() then return true end
    local hud = _G.FarmHud
    if type(hud) == "table" and type(hud.IsShown) == "function" then
        local ok, shown = pcall(hud.IsShown, hud)
        if ok and shown then return true end
    end
    local cluster = _G.FarmHudMapCluster
    if cluster and cluster.IsShown and cluster:IsShown() then return true end
    local parent = Minimap and Minimap:GetParent()
    return parent ~= nil and (parent == _G.FarmHud or parent == cluster)
end

UpdateArrow = function()
    -- the centre-of-screen marker is for looking without a HUD; the red arrow is for looking with one
    local hud = ownLook and FarmHudActive() or false
    if ownLook and not hud and GetSetting("gtmoveCharMarker") == true then
        ShowCharMark()
    else
        HideCharMark()
    end
    if not (Minimap and Minimap.SetPlayerTexture) then return end
    local want = hud and GetSetting("gtmoveFarmArrow") == true
    if want then
        if not arrowRed then
            arrowRed = true
            SetArrow(ARROW_BLANK)
        end
        LayoutArrow()
        TurnArrow()
        arrowFrame:Show()
        arrowTurner:Show()
    elseif arrowRed then
        arrowRed = false
        arrowFrame:Hide()
        arrowTurner:Hide()
        SetArrow(lastArrow or ARROW_DEFAULT)
    end
end

------------------------------------------------------------------------------------------------------------------
-- the one place settings are changed. Both menus call this, so side effects are the same everywhere.
------------------------------------------------------------------------------------------------------------------

local AFTER_CHANGE = {
    gtmoveFarmArrow = function() UpdateArrow() end,
    gtmoveCharMarker = function() UpdateArrow() end,
    gtmoveArrowSize = function() UpdateArrow() end,
}

local api = {
    DEFAULTS = DEFAULTS,
    YAW_MIN = YAW_MIN, YAW_MAX = YAW_MAX, YAW_DEFAULT = YAW_DEFAULT,
    GetSetting = GetSetting,
    IsEnabled = IsEnabled,
    SetEnabled = SetEnabled,
    Toggle = ToggleMouseLooking,                  -- the key binding (Bindings.xml)
    GetSensitivityLevel = GetSensitivityLevel,
    SetSensitivityLevel = SetSensitivityLevel,
    GetYawSpeed = GetYawSpeed,
    SetYawSpeed = SetYawSpeed,
    YawToLevel = YawToLevel,
    GetColor = GetColor,
    GetOpacity = GetOpacity,
    UpdateArrow = UpdateArrow,
}

function api.ChangeSetting(key, value)
    if key == "gtmoveEnabled" then
        SetEnabled(value)
    else
        SetSetting(key, value)
    end
    if AFTER_CHANGE[key] then AFTER_CHANGE[key]() end
end

_G.GTMouse = api

------------------------------------------------------------------------------------------------------------------
-- slash commands
------------------------------------------------------------------------------------------------------------------

local function ShowHelp()
    print("GTMouse commands:")
    print("  /gtmouse - open the GTMouse menu")
    print("  /gtmouse toggle - toggle mouse-look")
    print("  /gtmouse on - start mouse-look")
    print("  /gtmouse off - stop mouse-look")
    print("  /gtmouse status - show whether GTMouse and mouse-look are on")
    print("  /gtmouse sensitivity - show mouse-look sensitivity")
    print("  /gtmouse sensitivity 1-10 - set sensitivity")
    print("  /gtmouse reset - restore default sensitivity")
    print("  The toggle key is set in the GTMouse menu (/gtmouse).")
end

local function Slash(message)
    message = string.lower(strtrim(message or ""))
    local sensitivityArg = message:match("^sensitivity%s+(.+)$")
    if message == "on" or message == "enable" then
        if RequireEnabled() then SetMouseLooking(true) end
    elseif message == "off" or message == "disable" then
        if RequireEnabled() then SetMouseLooking(false) end
    elseif message == "toggle" then
        ToggleMouseLooking()
    elseif message == "" or message == "options" or message == "menu" or message == "config" then
        if api.ToggleOptions then
            api.ToggleOptions()
        else
            print(PREFIX_ERR, "GTMouse options window is unavailable.")
        end
    elseif message == "status" then
        print(PREFIX_OK, "GTMouse is", (IsEnabled() and "on." or "off."), "Mouse-look is", ownLook and "on." or "off.")
        print(string.format("Mouse-look sensitivity: %.1f/10", GetSensitivityLevel()))
    elseif message == "sensitivity" then
        print(PREFIX_OK, string.format("Mouse-look sensitivity is %.1f/10.", GetSensitivityLevel()))
    elseif sensitivityArg then
        SetSensitivityLevel(sensitivityArg)
    elseif message == "reset" then
        SetSensitivityLevel(DEFAULT_LEVEL)
    else
        ShowHelp()
    end
end

SLASH_GTMOUSE1 = "/gtmouse"
SLASH_GTMOUSE2 = "/gtm"
SlashCmdList.GTMOUSE = Slash

------------------------------------------------------------------------------------------------------------------
-- mounting
------------------------------------------------------------------------------------------------------------------

local restoreDone = false
local graceUntil = 0
local function MountCheck()
    if not IsEnabled() or GetSetting("gtmoveMount") ~= true then return end
    if IsMounted and IsMounted() then
        if GetTime() < graceUntil then return end       -- right after login, do not switch look on by itself
        MountOn()
    else
        MountOff()
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(watcher.RegisterEvent, watcher, "PLAYER_MOUNT_DISPLAY_CHANGED")
watcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" and not restoreDone then
        restoreDone = true
        graceUntil = GetTime() + 5
    end
    MountCheck()
end)
