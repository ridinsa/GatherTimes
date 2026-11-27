-- Modules.lua : optional features that live in their own load-on-demand folders next to GatherTimes.
--   GatherTimes_Names     Random Name (HideUnitNames + its window)
--   GatherTimes_XP        Mini XP (hero / pet XP line, goals, history)
--   GatherTimes_Notifier  Friend / Guild Notifier
--   GatherTimes_Whisper   whisper sound (Settings > Look; loaded only while a sound is chosen)
--   GatherTimes_Eagle     the Eagle map (remote views)
--   GatherTimes_Share     spot export / import (opened from Settings or /gt export | import)
-- A module that is not wanted is never read from disk and never runs: its files are only executed by LoadAddOn.
-- Wanted at login = not switched off here AND the feature is in use (see WANT).  A switched-off module cannot be
-- loaded at all.  Switch: /gt module <names|xp|notifier|eagle> on|off   (saved account-wide in GatherTimesDB._ui.modules).
-- Switching a loaded module off removes it fully after /reload (Blizzard hooks cannot be taken back).
local _, GT = ...

local MODULES = {
    names    = { addon = "GatherTimes_Names",    label = "Random Name",             stage = "early" },
    xp       = { addon = "GatherTimes_XP",       label = "Mini XP",                 stage = "early" },
    notifier = { addon = "GatherTimes_Notifier", label = "Friend/Guild Notifier",   stage = "early" },
    whisper  = { addon = "GatherTimes_Whisper",   label = "Whisper sound",           stage = "early" },
    eagle    = { addon = "GatherTimes_Eagle",    label = "Eagle map",               stage = "hud"   },
    share    = { addon = "GatherTimes_Share",    label = "Spot sharing",            stage = "late"  },
}
local ORDER = { "names", "xp", "notifier", "whisper", "eagle", "share" }
local REMOTE_VIEW = { HUNTER = true, SHAMAN = true, PRIEST = true, WARLOCK = true }

local function Switches(create)
    local ui = GatherTimesDB and GatherTimesDB._ui
    if type(ui) ~= "table" then return nil end
    if type(ui.modules) ~= "table" then
        if not create then return nil end
        ui.modules = {}
    end
    return ui.modules
end

function GT.ModuleEnabled(key)
    local s = Switches()
    return not s or s[key] ~= false
end

-- ---------------------------------------------------------------- whisper sound (Settings > Look)
-- The list, the saved choice and the player are here (not in GatherTimes_Whisper) so the Look tab can offer and preview a
-- sound without loading the folder; the folder only listens for whispers.  The files are the ones in GatherTimes\Media.
local WHISPER_DEFAULT = "Xbox.ogg"
local whisperList
function GT.WhisperSoundList()
    if not whisperList then
        whisperList = { "Off", "Game default" }
        local seen = {}
        for _, f in ipairs(GT.MEDIA_SOUNDS or {}) do whisperList[#whisperList + 1] = f; seen[f] = true end
        for _, f in ipairs({ "Windows.ogg", "Xbox.ogg" }) do          -- the Notifier's two sounds
            if not seen[f] then whisperList[#whisperList + 1] = f end
        end
    end
    return whisperList
end

function GT.WhisperSoundName()
    local c = GT.cfg and GT.cfg()
    local n = c and c.whisperSound
    for _, v in ipairs(GT.WhisperSoundList()) do
        if v == n then return n end
    end
    return WHISPER_DEFAULT
end

local whisperHandle
local DEFAULT_ATTEMPTS = {
    function() return PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081) end,
    function() return PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081, "Master") end,
    function() return PlaySoundFile("Sound\\Interface\\iTellMessage.ogg", "Master") end,
}
-- plays `name` (a preview), or the saved choice; one sound at a time, so quick whispers do not stack
function GT.PlayWhisperSound(name)
    name = name or GT.WhisperSoundName()
    if name == "Off" then return end
    if whisperHandle then pcall(StopSound, whisperHandle); whisperHandle = nil end
    if name == "Game default" then
        for _, fn in ipairs(DEFAULT_ATTEMPTS) do
            local ok, played = pcall(fn)
            if ok and played then return end
        end
        return
    end
    local ok, willPlay, handle = pcall(PlaySoundFile, GT.MEDIA_DIR .. name, "Master")
    whisperHandle = (ok and willPlay) and handle or nil
end

-- is the feature in use right now (so it must be loaded)?
local WANT = {
    names = function() return type(GatherTimesHUNDB) == "table" and GatherTimesHUNDB.hideAll == true end,
    -- off with "Show XP button": not loaded (turning it on loads it, see PanelMinimize.lua) - unless this character has a saved goal:
    -- the goal strip along the bar is drawn by this module, so it has to be running or the strip is gone until the Goals tab is opened
    xp = function()
        local c = GT.cfg and GT.cfg()
        if not c or c.miniShowXP ~= false then return true end
        local name = UnitName and UnitName("player")
        local realm = GT.RealmName and GT.RealmName() or (GetRealmName and GetRealmName()) or ""
        local goals = c and type(c.xpGoal) == "table" and name and c.xpGoal[name .. "-" .. realm]
        return type(goals) == "table" and next(goals) ~= nil
    end,
    notifier = function() local c = GT.cfg and GT.cfg(); return c and c.guildOnline == true or false end,
    whisper = function() return GT.WhisperSoundName() ~= "Off" end,    -- a sound is chosen (Settings > Look)
    share = function() return false end,                     -- only when it is opened (see GT.OpenShare)
    eagle = function()
        local db = GT.HUD and GT.HUD.db
        if not db or db.eagleMap == false then return false end
        local _, class = UnitClass("player")
        return REMOTE_VIEW[class or ""] and true or false
    end,
}

function GT.ModuleWanted(key)
    local f = WANT[key]
    return GT.ModuleEnabled(key) and f and f() and true or false
end

local function IsLoaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return fn and fn(name) and true or false
end

function GT.ModuleLoaded(key)
    local m = MODULES[key]
    return m and IsLoaded(m.addon) or false
end

-- Diagnostic lifecycle snapshot for /gt report and Settings.
function GT.ModuleDiagnostics()
    local result = {}
    for _, key in ipairs(ORDER) do
        result[#result + 1] = string.format("%s=%s,%s", key,
            GT.ModuleEnabled(key) and "enabled" or "disabled",
            GT.ModuleLoaded(key) and "loaded" or "not-loaded")
    end
    return table.concat(result, " ")
end

-- Loads the module's folder now (once).  Returns true when its code is running.
function GT.LoadModule(key, quiet)
    local m = MODULES[key]
    if not m then return false end
    if IsLoaded(m.addon) then return true end
    if not GT.ModuleEnabled(key) then
        if not quiet then GT.cprint(GT.TRF("%s is switched off. Switch it on with /gt module %s on", GT.TR(m.label), key)) end
        return false
    end
    if m.failed then return false end
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    local ok, loaded, reason = pcall(load, m.addon)
    if IsLoaded(m.addon) then return true end
    m.failed = true                                   -- do not try again every click
    if not quiet then
        GT.cprint(GT.TRF("%s could not be loaded (%s). Is the %s folder installed and enabled?", GT.TR(m.label),
            tostring(ok and reason or loaded), m.addon))
    end
    return false
end

-- stage "early": before the windows are built; stage "hud": after the HUD has read its settings
function GT.LoadWantedModules(stage)
    for _, key in ipairs(ORDER) do
        if MODULES[key].stage == stage and GT.ModuleWanted(key) then
            local ok, err = pcall(GT.LoadModule, key, true)
            if not ok then GT.ReportError("module " .. key, err) end
        end
    end
end

-- opens the spot sharing window (or imports text) and loads its folder first, the first time it is needed
-- mode: "export" | "import" (the window) | "importtext" (import this text straight away)
function GT.OpenShare(mode, text)
    if not GT.LoadModule("share") then return end
    if mode == "export" then
        if GT.ShowExportSpots then GT.ShowExportSpots() end
    elseif mode == "importtext" then
        if GT.ImportSpotsReport then GT.ImportSpotsReport(text) end
    elseif GT.ShowImportSpots then
        GT.ShowImportSpots()
    end
end

function GT.SetModuleEnabled(key, on)
    local m = MODULES[key]
    if not m then return false end
    if not on and key == "names" and WANT.names() then
        GT.cprint(GT.TR("Turn Random Name off first (right-click the Settings button), then switch the module off."))
        return false
    end
    local s = Switches(true)
    if not s then return false end
    if on then s[key] = nil else s[key] = false end
    if on then
        m.failed = nil
        if GT.ModuleWanted(key) then GT.LoadModule(key) end
    elseif IsLoaded(m.addon) then
        GT.cprint(GT.TR(m.label) .. ": " .. GT.TR("switched off. It stops running completely after /reload."))
    end
    return true
end

function GT.ModulesSlash(rest)
    local key, state = (rest or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if key == "" or not MODULES[key] then
        GT.cprint(GT.TR("Optional modules (/gt module <name> on | off):"))
        for _, k in ipairs(ORDER) do
            local st = not GT.ModuleEnabled(k) and GT.TR("off")
                or (GT.ModuleLoaded(k) and GT.TR("on, loaded") or GT.TR("on, not loaded (not in use)"))
            GT.cprint(string.format("  %s (%s): %s", k, GT.TR(MODULES[k].label), st))
        end
        return
    end
    if state == "on" or state == "off" then
        GT.SetModuleEnabled(key, state == "on")
    end
    GT.cprint(string.format("%s: %s", GT.TR(MODULES[key].label), GT.TR(GT.ModuleEnabled(key) and "on" or "off")))
end

-- /hun lives in the Random Name module: this stand-in loads it and hands the command over
SLASH_GATHERTIMESHUN1 = "/hun"
local hunStub
hunStub = function(msg)
    if GT.LoadModule("names") and SlashCmdList.GATHERTIMESHUN ~= hunStub then SlashCmdList.GATHERTIMESHUN(msg) end
end
SlashCmdList.GATHERTIMESHUN = hunStub
