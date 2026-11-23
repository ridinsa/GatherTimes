-- GTMove.lua : the always-loaded part of GTMove (mouse-look; formerly the MouseMove addon).  The code itself is the
-- load-on-demand folder GatherTimes_GTMove.  Key binding names and the /gtmove command have to exist before that
-- folder is loaded, so they live here; the first key press or command loads the folder (see Core\Modules.lua) and the
-- real GT.GTMove / slash handler replace the stand-ins below.
local _, GT = ...

BINDING_HEADER_GTMOVE = "GTMove"
BINDING_NAME_GTMOVE_TOGGLE = GT.TR("Toggle mouse-look")
BINDING_NAME_GTMOVE_FORWARD = GT.TR("Move forward (mouse-look while held)")
BINDING_NAME_GTMOVE_BACKWARD = GT.TR("Move backward (mouse-look while held)")
BINDING_NAME_GTMOVE_TURNLEFT = GT.TR("Turn left (mouse-look while held)")
BINDING_NAME_GTMOVE_TURNRIGHT = GT.TR("Turn right (mouse-look while held)")
BINDING_NAME_GTMOVE_STRAFELEFT = GT.TR("Strafe left (mouse-look while held)")
BINDING_NAME_GTMOVE_STRAFERIGHT = GT.TR("Strafe right (mouse-look while held)")
BINDING_NAME_GTMOVE_JUMP = GT.TR("Jump (mouse-look while held)")
BINDING_NAME_GTMOVE_SENSUP = GT.TR("Mouse-look sensitivity up")
BINDING_NAME_GTMOVE_SENSDOWN = GT.TR("Mouse-look sensitivity down")

-- Stand-ins used until the module is loaded.  Releasing a key never loads it: there is nothing to stop yet.
local standIn = {}
local function LoadedFn(name, quiet)
    return function(...)
        if GT.LoadModule("gtmove", quiet) and GT.GTMove ~= standIn then return GT.GTMove[name](...) end
    end
end
standIn.Toggle = LoadedFn("Toggle", false)          -- the player asked for it: say so when GTMove is switched off
standIn.Slash = LoadedFn("Slash", false)
standIn.MoveStart = LoadedFn("MoveStart", true)     -- a movement key must just move
standIn.MoveStop = function() end
standIn.Stop = function() end
standIn.IsLooking = function() return false end     -- GTMove's own mouse-look: read by the HUD player arrow
standIn.MountOn = LoadedFn("MountOn", true)         -- mounted with "Turn on when mounted": loads the module
standIn.MountOff = function() end                   -- nothing to end: the module is not loaded, so it started nothing
standIn.Sensitivity = LoadedFn("Sensitivity", true) -- the sensitivity keys
standIn.Restore = function() end                    -- "Remember mouse-look on login" (see the watcher below)
standIn.StopOnLogin = function() end                -- nothing to stop: the module is not loaded
GT.GTMove = standIn

SLASH_GTMOVE1 = "/gtmove"
SLASH_GTMOVE2 = "/gtm"
SlashCmdList.GTMOVE = function(msg) GT.GTMove.Slash(msg) end

-- Always loaded, so it can load the module when Nav > Move asks for it: mount auto-toggle and remember on login.
local restoreDone = false
local graceUntil = 0        -- after login / reload, a mounted character is not a new mount: no auto-on until this time

local function CfgFlag(key)
    return GT.CharGet(key, false) == true
end

local function MountCheck()
    if not CfgFlag("gtmoveMount") then return end
    if IsMounted and IsMounted() then
        if GetTime() < graceUntil then return end
        GT.GTMove.MountOn()
    else
        GT.GTMove.MountOff()
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(watcher.RegisterEvent, watcher, "PLAYER_MOUNT_DISPLAY_CHANGED")
watcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" and not restoreDone then
        restoreDone = true                                  -- only the first world entry of the session (login / reload)
        graceUntil = GetTime() + 5
        C_Timer.After(1, function()
            if CfgFlag("gtmoveRemember") and CfgFlag("gtmoveWasOn") then
                if GT.LoadModule("gtmove", true) and GT.GTMove ~= standIn then GT.GTMove.Restore() end
            else
                GT.GTMove.StopOnLogin()                     -- default: mouse-look is off after login / reload
            end
        end)
    end
    MountCheck()
end)
