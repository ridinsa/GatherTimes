-- Events.lua : event frame + 1-second update loop
local addonName, GT = ...
local order = GT.order
local uiRefresh = GT.uiRefresh
local HUD = GT.HUD          -- minimap HUD module (HUD.lua): GatherTimes drives its events and updates from here

-- A failing HUD handler must not take the loot / timer logic down with it.
local function HUDEvent(event, a, b, c)
    if not HUD then return end
    local ok, err = pcall(HUD.OnEvent, event, a, b, c)
    if not ok then GT.ReportError("HUD " .. event, err) end
end

-- Runs fn under pcall.  The first failure of each named step is reported once; while it keeps failing it stays
-- quiet (no error every second / every loot event), and a later success re-arms the report.
local guardFailed = {}
local function Guard(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then
        guardFailed[name] = nil
    elseif not guardFailed[name] then
        guardFailed[name] = true
        pcall(GT.ReportError, name, err)
    end
    return ok
end

function GT.ClearFrames(node)
    pcall(GT.RemoveTextTimer, node)
    node._miniFrame = nil
    node._worldFrame = nil
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_LOOT")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("LOOT_CLOSED")
pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SENT", "player")      -- gather attempts (Herb Gathering / Mining)
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGOUT")
if not pcall(f.RegisterUnitEvent, f, "UNIT_HEALTH", "player") then f:RegisterEvent("UNIT_HEALTH") end   -- player only
-- HUD events. These may not exist on every client build, so register defensively.
pcall(f.RegisterEvent, f, "MINIMAP_UPDATE_TRACKING")
pcall(f.RegisterEvent, f, "PLAYER_MOUNT_DISPLAY_CHANGED")
pcall(f.RegisterEvent, f, "PLAYER_REGEN_DISABLED")        -- combat start (HUD ring colour)
pcall(f.RegisterEvent, f, "PLAYER_REGEN_ENABLED")         -- combat end (HUD ring colour)
pcall(f.RegisterEvent, f, "PLAYER_UPDATE_RESTING")
pcall(f.RegisterEvent, f, "ZONE_CHANGED")
pcall(f.RegisterEvent, f, "ZONE_CHANGED_INDOORS")
pcall(f.RegisterEvent, f, "ZONE_CHANGED_NEW_AREA")
pcall(f.RegisterUnitEvent, f, "UNIT_AURA", "player")
pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_CHANNEL_START", "player")   -- Eagle Eye (HUD switches off / on)
pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_CHANNEL_STOP", "player")
pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")       -- fallback when the channel / buff is not reported
pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_INTERRUPTED", "player")
pcall(f.RegisterEvent, f, "BAG_UPDATE_DELAYED")        -- bag space warning (Gathering\BagSpace.lua)
pcall(f.RegisterEvent, f, "SKILL_LINES_CHANGED")       -- skill ETA (Gathering\SkillEta.lua); not on every client
pcall(f.RegisterEvent, f, "CHAT_MSG_SKILL")

-- Everything ADDON_LOADED sets up.  Runs under pcall (see below).
-- Part 1 is the saved data: if that fails the addon stays off (GT.ready false), because the timers cannot work
-- on half-checked data.  Part 2 is the windows: a failure there is reported but the timers, alerts and loot
-- detection keep working.
function GT.Startup()
    if type(GatherTimesDB) ~= "table" then GatherTimesDB = {} end       -- a damaged saved file that is not even a table
    GT.SanitizeDB()
    -- Startup self-check: malformed SavedVariables or missing core APIs must fail clearly, not as random Lua errors.
    local startupProblems = {}
    if type(GatherTimesDB) ~= "table" then startupProblems[#startupProblems + 1] = "saved variables" end
    if type(GT.nodes) ~= "table" or type(GT.order) ~= "table" or #GT.order == 0 then
        startupProblems[#startupProblems + 1] = "node catalog"
    end
    if type(GatherTimesDB._cfg) ~= "table" then
        startupProblems[#startupProblems + 1] = "configuration tables"
    end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        startupProblems[#startupProblems + 1] = "C_Map APIs"
    end
    if #startupProblems > 0 then
        error("startup validation failed: " .. table.concat(startupProblems, ", "))
    end
    pcall(GT.TrimLocales)                       -- the saved language is known now: free the other languages' texts (Locales\Locales.lua)
    -- timers that ran out before this moment (while offline / reloading) get no ready alert, see Timers.lua
    GT.loginServerTime = GetServerTime()
    GT.LoadWantedModules("early")               -- Mini XP / Notifier / Random Name, only those that are in use (Core\Modules.lua)

    -- GatherTimes window settings (kept in a reserved key)
    local ui = GatherTimesDB._ui
    if type(ui) ~= "table" then ui = {}; GatherTimesDB._ui = ui end
    for k, v in pairs(GT.defaults) do
        if ui[k] == nil then ui[k] = v end
    end
    if not ui.barDockOn1 then ui.barDockOn1 = true; ui.barDock = true end     -- once: the dock is on by default (it may have been switched off while testing)
    if not GT.SkinExists(ui.skin) then ui.skin = "default" end
    GT.ApplySkin(ui.skin)
    ui.trackSwitch = nil          -- removed feature: drop its old saved value
    GT.cfg().sessions = (GT.cfg().sessions or 0) + 1

    local function Try(what, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then GT.ReportError(what, err) end
    end
    Try("main window", GT.CreateMainFrame, GT)
    if HUD then Try("HUD init", HUD.Init) end        -- GatherTimesDB.hud + the HUD settings window
    GT.LoadWantedModules("hud")                      -- the Eagle map, once the HUD settings are known
    Try("restyle", GT.RestyleAll)
    for _, fn in ipairs(uiRefresh) do pcall(fn) end
    pcall(GT.ApplyLangFont, GT.main)             -- Apply the selected language's font to everything built so far
    for _, p in pairs(GT.panels or {}) do pcall(GT.ApplyLangFont, p) end
end

f:SetScript("OnEvent", function(_, event, msg, msg2, ...)
    if event == "ADDON_LOADED" then
        if msg ~= addonName then HUDEvent(event, msg); return end     -- another addon loaded: the HUD re-scans minimap buttons
        -- If set-up fails (a damaged saved file, say) the addon stays switched off (GT.ready is false) instead of
        -- raising an error every second from half-built code.
        local ok, err = pcall(GT.Startup)
        GT.ready = ok and true or false
        if not ok then
            pcall(GT.ReportError, "start-up (GatherTimes is switched off)", err)
        end
        return
    end
    if not GT.ready then return end            -- not set up (yet, or the start-up failed): ignore every other event

    if event == "PLAYER_ENTERING_WORLD" and GT.CheckZoneClear then pcall(GT.CheckZoneClear, event, msg, msg2) end   -- login / reload: remember the zone; a loading screen: compare it
    if (event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD") and GT.AutoImportGatherMate2 then
        pcall(GT.AutoImportGatherMate2)           -- Settings > Tools: GatherMate2 import "Auto"
    end

    if event == "PLAYER_ENTERING_WORLD" then
        HUDEvent(event, msg, msg2)                -- msg = isInitialLogin, msg2 = isReloadingUi
        pcall(GT.WarnMissingLibs)                 -- once per session: HereBeDragons missing -> distances / pins are off
        if GT.Gfx then pcall(GT.Gfx.Reapply) end  -- saved graphics / screen effect / weather / camera zoom choices
        local rok, changed = pcall(GT.RecheckRealm)   -- the Hardcore flag may only be known now, see Config.lua
        if GT.RestoreSession then pcall(GT.RestoreSession) end               -- resume the last session (once per login)
        -- skills and bags are not ready at the very first moment: look at them a few seconds later
        C_Timer.After(4, function()
            if GT.InitSkillEta then pcall(GT.InitSkillEta) end
            if GT.CheckBags then pcall(GT.CheckBags) end
        end)
        if rok and changed then pcall(GT.RefreshTimingUI) end
        if GT.cfg() and GT.cfg().tomTomAutoNearest then
            C_Timer.After(3, function()
                if GT.cfg().tomTomAutoNearest and GT.UI.UpdateTomTomNearest then
                    GT.UI.UpdateTomTomNearest()
                end
            end)
        end

    elseif event == "UI_ERROR_MESSAGE" or event == "CHAT_MSG_SYSTEM" then
        -- UI_ERROR_MESSAGE is (errorType, message) on current clients and just (message) on old ones;
        -- CHAT_MSG_SYSTEM is (text, playerName, ...), so its second argument is not the message
        local text, errorType
        if event == "UI_ERROR_MESSAGE" and type(msg) == "number" then
            errorType, text = msg, msg2
        else
            text = msg
        end
        if type(text) == "string" then pcall(GT.OnGameMessage, text, errorType) end
        -- server maintenance / restart announcements arrive as system chat lines (the text is the first argument)
        if event == "CHAT_MSG_SYSTEM" and type(msg) == "string" then
            local ok, err = pcall(GT.OnMaintenanceMessage, msg)
            if not ok then GT.ReportError("maintenance alert", err) end
        end
        if event == "CHAT_MSG_SYSTEM" and type(msg) == "string" and GT.OnGuildOnlineMessage then
            pcall(GT.OnGuildOnlineMessage, msg)
        end

    elseif event == "CHAT_MSG_LOOT" then
        if type(msg) ~= "string" then return end
        -- the 12th event argument is the GUID of the looter: that tells "my" loot from other players' loot
        -- in any client language (the old test was the English word "You" at the start of the line)
        local itemName, itemID, qty = GT.ParseLootChat(msg, (select(10, ...)))
        if not itemName and not itemID then return end
        Guard("loot (chat)", GT.HandleItem, itemName, itemID, "chat", qty)

    elseif event == "UNIT_SPELLCAST_SENT" then
        -- (unit, target, castGUID, spellID): the spell id is the 2nd of the remaining arguments
        pcall(GT.NoteGatherCast, (select(2, ...)))

    elseif event == "LOOT_CLOSED" then
        pcall(GT.NoteLootClosed)

    elseif event == "LOOT_OPENED" then
        pcall(GT.NoteLootOpened)                  -- where does this loot come from: a node or something else
        for slot = 1, GetNumLootItems() do
            local link = GetLootSlotLink(slot)
            if link then
                local qty = GetLootSlotInfo and select(3, GetLootSlotInfo(slot))
                Guard("loot (window)", GT.HandleItem, link:match("%[(.-)%]"), tonumber(link:match("item:(%d+)")), "loot", tonumber(qty))
            end
        end

    elseif event == "MINIMAP_UPDATE_TRACKING" or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED"
        or event == "PLAYER_UPDATE_RESTING" or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" or event == "UNIT_AURA"
        or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if (event == "PLAYER_UPDATE_RESTING" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
            or event == "ZONE_CHANGED_NEW_AREA") and GT.UI and GT.UI.ClearWaypointsInCity then
            pcall(GT.UI.ClearWaypointsInCity)          -- entering a town or city: clear the waypoints
        end
        if (event == "PLAYER_UPDATE_RESTING" or event == "ZONE_CHANGED_NEW_AREA") and GT.CheckZoneClear then
            pcall(GT.CheckZoneClear, event)            -- Timing panel option: clear timers + alerts on a zone change
        end
        HUDEvent(event, msg, msg2, (...))              -- SUCCEEDED is (unit, castGUID, spellID)

    elseif event == "UNIT_HEALTH" then
        if msg == "player" then Guard("health check", GT.CheckHealth) end

    elseif event == "BAG_UPDATE_DELAYED" then
        if GT.CheckBags then pcall(GT.CheckBags) end

    elseif event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
        if GT.CheckSkillEta then pcall(GT.CheckSkillEta) end

    elseif event == "PLAYER_LOGOUT" then
        HUDEvent(event)
        if GT.SaveSession then pcall(GT.SaveSession) end
        for _, key in ipairs(order) do
            for _, node in ipairs(GatherTimesDB[key]) do
                GT.ClearFrames(node)
                -- runtime-only fields are cleared; _hasAlerted / _leaveAlerted stay in the file on purpose: after a
                -- quick relog or /reload a timer that already alerted must not alert again (SanitizeDB checks them)
                node._left, node._dist, node._peers, node._primary = nil, nil, nil, nil
            end
        end
    end
end)

local accum = 0
local hudUpdateFailed = false
f:SetScript("OnUpdate", function(_, elap)
    -- every frame: the HUD parts throttle themselves (overlay 0.03 s, watcher 0.1 s, skin sweep 0.5 s)
    if HUD then
        local ok, err = pcall(HUD.OnUpdate, elap)
        if not ok then
            if not hudUpdateFailed then
                pcall(GT.ReportError, "HUD update", err)
                hudUpdateFailed = true
            end
        else
            hudUpdateFailed = false
        end
    end
    accum = accum + elap
    if accum > ((HUD and HUD.PerfTimerStep and HUD.PerfTimerStep()) or 1) then
        accum = 0
        if GT.ready then Guard("timer refresh", GT.RefreshTimers) end
    end
end)
