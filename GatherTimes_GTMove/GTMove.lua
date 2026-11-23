-- GTMove.lua : mouse-look toggle, and mouse-look while a movement key is held (formerly the MouseMove addon).
-- Load-on-demand part of GatherTimes: Core\GTMove.lua (in the main addon) owns the key bindings, their names and
-- the /gtmove command, and loads this folder the first time one of them is used.  Installing it replaces the
-- stand-in GT.GTMove table below with the real one.
local GT = _G.GatherTimesAddon     -- load-on-demand part: it gets its own private table, so take the shared one
if not GT then return end

local PREFIX_OK, PREFIX_ERR = "|cff80ff80GTMove:|r", "|cffff4040GTMove:|r"
local DEFAULT_LEVEL = 5.5

local function IsMouseLooking()
    return IsMouselooking and IsMouselooking() and true or false
end

local function CfgValue(key)
    return GT.CharGet(key, nil)
end
local function SetSensitivityLevel(level, quiet)
    level = tonumber(level)
    if not level or level < 1 or level > 10 then
        print(PREFIX_ERR, "Sensitivity must be a number from 1 to 10.")
        return false
    end
    level = math.floor(level * 2 + 0.5) / 2
    local yawSpeed = 90 + (level - 1) * 20
    SetCVar("cameraYawMoveSpeed", yawSpeed)
    SetCVar("cameraPitchMoveSpeed", yawSpeed / 2)
    if not quiet then print(PREFIX_OK, string.format("Mouse-look sensitivity set to %.1f/10.", level)) end
    return true
end

local function GetSensitivityLevel()
    local yawSpeed = tonumber(GetCVar("cameraYawMoveSpeed")) or 180
    local level = 1 + (yawSpeed - 90) / 20
    return math.max(1, math.min(10, math.floor(level * 2 + 0.5) / 2))
end

-- true only while GTMove itself has mouse-look on. The game's IsMouselooking() also reports true while the player's
-- turn keys steer, so this is what the HUD arrow colour reads (GT.GTMove.IsLooking).
local ownLook = false

-- Move the cursor to the centre of the screen. Called only when mouse-look goes from on to off.
-- The move waits one frame so the game has released the cursor first.
local function CentreCursor()
    if type(SetCursorPosition) ~= "function" or not UIParent then return end
    C_Timer.After(0, function()
        local s = UIParent:GetEffectiveScale()
        pcall(SetCursorPosition, UIParent:GetWidth() * s / 2, UIParent:GetHeight() * s / 2)
    end)
end

local movementKeysDown = {}
local movementStartedMouseLook = false

-- watches for the game ending mouse-look by itself and stops when it is over
local monitor = CreateFrame("Frame")
monitor:Hide()
local monitorElapsed = 0
monitor:SetScript("OnUpdate", function(self, elapsed)
    monitorElapsed = monitorElapsed + elapsed
    if monitorElapsed < 0.1 then return end
    monitorElapsed = 0
    if not IsMouseLooking() then
        if ownLook then CentreCursor() end
        ownLook = false
        self:Hide()
    end
end)


-- on-screen notice: floating text near the top of the screen, shown for the time set in Nav > Move, then hidden
local noteFrame, noteText
local noteToken = 0

local function T(text)
    return GT.TR and GT.TR(text) or text
end

local function ShowNote(text)
    if not noteFrame then
        noteFrame = CreateFrame("Frame", nil, UIParent)
        noteFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        noteFrame:SetSize(800, 40)
        noteText = noteFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        noteText:SetPoint("CENTER")
        noteText:SetTextColor(1, 1, 0)
        noteFrame:Hide()
    end
    noteFrame:ClearAllPoints()
    noteFrame:SetPoint("TOP", UIParent, "TOP", 0, -(CfgValue("gtmoveNoteTop") or 160))
    noteToken = noteToken + 1
    local token = noteToken
    noteText:SetText(text)
    noteFrame:Show()
    C_Timer.After(CfgValue("gtmoveNoteSecs") or 3, function()
        if token == noteToken then noteFrame:Hide() end     -- a newer notice keeps the frame up
    end)
end

local function SetMouseLooking(enabled, quiet)
    if enabled then
        if not IsMouseLooking() and MouselookStart then MouselookStart() end
        ownLook = true
        if not quiet then GT.CharSet("gtmoveWasOn", true) end    -- remembered for login (quiet = not the player's choice)
        monitor:Show()
        if IsMouseLooking() and not quiet then ShowNote(T("Mouse-look enabled, right-click to disable")) end
    else
        local wasOn = ownLook
        if IsMouseLooking() and MouselookStop then MouselookStop() end
        ownLook = false
        if not quiet then GT.CharSet("gtmoveWasOn", false) end
        monitor:Hide()
        if wasOn then CentreCursor() end
        if not quiet then ShowNote(T("Mouse-look disabled")) end
    end
end

local function ToggleMouseLooking()
    SetMouseLooking(not IsMouseLooking())
end

local function StopMouseLookForUI()
    if IsMouseLooking() then SetMouseLooking(false, true) end
end

-- opening the game menu, closing windows, starting to type in chat, or pressing Esc in the chat box ends mouse-look
for _, name in ipairs({ "ToggleGameMenu", "CloseWindows", "ChatEdit_ActivateChat", "ChatEdit_OnEscapePressed" }) do
    if type(_G[name]) == "function" then hooksecurefunc(name, StopMouseLookForUI) end
end

-- a right-click on a chat window ends mouse-look
local function HookChatFrames()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local frame = _G["ChatFrame" .. i]
        if frame and not frame.gtmoveHooked and frame.HookScript then
            frame.gtmoveHooked = true
            frame:HookScript("OnMouseDown", function(_, button)
                if button == "RightButton" and ownLook then SetMouseLooking(false) end    -- shows the notice
            end)
        end
    end
end
HookChatFrames()

-- the movement bindings (Bindings.xml): the first key held starts mouse-look, the last one released ends it, but
-- only when this module started it (a mouse-look the player began by hand is left running)
local function MovementStart(action)
    if movementKeysDown[action] then return end
    local hadMovementKeyDown = next(movementKeysDown) ~= nil
    movementKeysDown[action] = true
    if not IsMouseLooking() then
        movementStartedMouseLook = true
        SetMouseLooking(true, true)
    elseif not hadMovementKeyDown then
        movementStartedMouseLook = false
    end
end

local function MovementStop(action)
    if not movementKeysDown[action] then return end
    movementKeysDown[action] = nil
    if next(movementKeysDown) == nil then
        if movementStartedMouseLook then SetMouseLooking(false, true) end
        movementStartedMouseLook = false
    end
end

-- mount auto-toggle: MountOn starts mouse-look only if it is not already on, and MountOff ends only what MountOn started
local mountStarted = false

local function MountOn()
    if ownLook then return end
    mountStarted = true
    SetMouseLooking(true, true)
end

local function MountOff()
    if not mountStarted then return end
    mountStarted = false
    if ownLook then SetMouseLooking(false, true) end
end

-- "Remember mouse-look on login": called once after login / reload when the last explicit choice was on
local function Restore()
    if CfgValue("gtmoveRemember") == true and CfgValue("gtmoveWasOn") == true then SetMouseLooking(true, true) end
end

-- the sensitivity keys: steps of 0.5 on the 1-10 scale, with an on-screen notice of the new value
local function StepSensitivity(dir)
    local level = math.max(1, math.min(10, GetSensitivityLevel() + dir * 0.5))
    if SetSensitivityLevel(level, true) then
        ShowNote(string.format(T("Mouse-look sensitivity %s/10"), string.format("%.1f", level)))
    end
end

-- Login / reload: mouse-look starts off, unless "Remember mouse-look on login" restores it (see Restore).
local function StopOnLogin()
    mountStarted = false
    if ownLook then
        ownLook = false
        if IsMouseLooking() and MouselookStop then MouselookStop() end
        monitor:Hide()
    end
    GT.CharSet("gtmoveWasOn", false)
end

local function Slash(message)
    message = string.lower(strtrim(message or ""))
    local level = message:match("^sensitivity%s+(.+)$")
    if message == "on" or message == "enable" then
        SetMouseLooking(true)
    elseif message == "off" or message == "disable" then
        SetMouseLooking(false)
    elseif message == "toggle" or message == "" then
        ToggleMouseLooking()
    elseif message == "status" then
        print(PREFIX_OK, IsMouseLooking() and "enabled" or "disabled")
        print(string.format("Mouse-look sensitivity: %.1f/10", GetSensitivityLevel()))
    elseif message == "sensitivity" then
        print(PREFIX_OK, string.format("Mouse-look sensitivity is %.1f/10.", GetSensitivityLevel()))
    elseif level then
        SetSensitivityLevel(level:match("^([%d%.]+)$"))
    elseif message == "reset" then
        SetSensitivityLevel(DEFAULT_LEVEL)
    else
        print("GTMove commands:")
        print("  /gtmove toggle - toggle mouse-look")
        print("  /gtmove on - enable mouse-look")
        print("  /gtmove off - disable mouse-look")
        print("  /gtmove status - show mouse-look status")
        print("  /gtmove sensitivity - show mouse-look sensitivity")
        print("  /gtmove sensitivity 1-10 - set sensitivity")
        print("  /gtmove reset - restore default sensitivity")
        print("  Assign the GTMove movement actions in Key Bindings > AddOns.")
    end
end

-- replace the stand-ins from Core\GTMove.lua
GT.GTMove = {
    Toggle = ToggleMouseLooking, MoveStart = MovementStart, MoveStop = MovementStop, Slash = Slash,
    MountOn = MountOn, MountOff = MountOff, Restore = Restore, StopOnLogin = StopOnLogin, Sensitivity = StepSensitivity,
    IsLooking = function() return ownLook end,      -- GTMove's own mouse-look (not the game's, which steering also sets)
    Stop = function() movementKeysDown, movementStartedMouseLook = {}, false; SetMouseLooking(false, true) end,   -- quietly, for switching GTMove off
}
SlashCmdList["GTMOVE"] = Slash
