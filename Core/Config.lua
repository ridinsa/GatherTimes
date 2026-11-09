-- Config.lua
local _, GT = ...
local COLORS = GT.COLORS
local DEFAULT_COLOR = GT.DEFAULT_COLOR
local SOUNDS = GT.SOUNDS
local nodes = GT.nodes
local spawnBySid = GT.spawnBySid

-- hud = the minimap HUD module's settings (HUD.lua); without this entry SanitizeDB would wipe them
-- _otherRealms = timers of your other realms, parked while you play this one (GT.MigrateRealm)
-- _dbVersion   = layout of the saved data (see DB_VERSION)
local RESERVED = { _cfg = true, _enabled = true, _spawns = true, _spawnNext = true, _ui = true, hud = true,
    _otherRealms = true, _dbVersion = true, _zoneYield = true }
local DB_VERSION = 3          -- 1 = before realm tagging, 2 = timers carry their realm, 3 = the realm tag also carries Hardcore
local STASH_MAX_AGE = 6 * 3600   -- parked timers older than this are long expired: dropped

function GT.cfg() return GatherTimesDB._cfg end

local function InitCfg()
    local db = GatherTimesDB
    if type(db._cfg) ~= "table" then db._cfg = {} end
    local c = db._cfg
    if type(c.enabled) ~= "table" then
        c.enabled = type(db._enabled) == "table" and db._enabled or {}
    end

    function GT.SanitizeSpotNote(note)
        if type(note) ~= "string" then return nil end
        note = note:sub(1, 960)
            :gsub("|[cC]%x%x%x%x%x%x%x%x", "")
            :gsub("|[rR]", "")
            :gsub("|", "")
            :gsub("[%c]", " "):gsub("%s+", " ")
            :gsub("^%s+", ""):gsub("%s+$", "")
        if #note > 240 then
            note = note:sub(1, 240)
            while note:byte(-1) and note:byte(-1) >= 128 and note:byte(-1) < 192 do
                note = note:sub(1, -2)
            end
            local lead = note:byte(-1)
            if lead and lead >= 192 and lead <= 244 then note = note:sub(1, -2) end
        end
        return note ~= "" and note or nil
    end
    db._enabled = nil
    if type(c.timers) ~= "table" then c.timers = {} end
    if type(c.colors) ~= "table" then c.colors = {} end
    if type(c.sounds) ~= "table" then c.sounds = {} end
    if type(c.alertItems) ~= "table" then c.alertItems = {} end
    if type(c.learn) ~= "table" then c.learn = {} end
    if type(c.learnZone) ~= "table" then c.learnZone = {} end       -- learnZone[key][mapID] = { samples }
    if c.learnMode ~= "zone" then c.learnMode = "item" end          -- "item" (default) | "zone"
    if c.autoLearn == nil then c.autoLearn = false end
    if c.detectEmpty == nil then c.detectEmpty = true end
    if c.otherDots == nil then c.otherDots = true end         -- small dots on world-map pins that have no label (Pins.lua)
    if c.groupMode == nil then c.groupMode = true end
    if type(c.groupCounts) ~= "table" then c.groupCounts = {} end
    c.mmAngle = GT.Clamp(c.mmAngle, 0, 360, 225)
    if c.showMinimapButton == nil then c.showMinimapButton = true end
    if c.fadeMoving == nil then c.fadeMoving = true end
    c.uiScale = tonumber(c.uiScale) or 0.85
    c.moveAlpha = math.max(0.1, math.min(0.9, tonumber(c.moveAlpha) or 0.35))
    if c.chime == nil then c.chime = true end
    if c.soundOutOfRange == nil then c.soundOutOfRange = true end   -- ready sound even outside the alert range
    if not GT.IsValidLang(c.lang) then c.lang = "enUS" end        -- interface language (Locales\)
    c.chimeRange = tonumber(c.chimeRange) or 35
    if c.msgDetect == nil then c.msgDetect = true end
    if c.leaveAlert == nil then c.leaveAlert = true end
    c.leaveEarly = GT.Clamp(c.leaveEarly, 0, 300, 10)      -- seconds
    if c.menuMap == nil then c.menuMap = true end
    if c.nodeTips == nil then c.nodeTips = true end       -- item tooltip on hover: Nodes panel, world map and inventory
    if type(c.groupStore) ~= "table" then c.groupStore = {} end
    c.groupCap = math.max(1, math.min(3, tonumber(c.groupCap) or 1))
    if c.screenAlert == nil then c.screenAlert = true end
    if type(c.alertStyle) ~= "string" then c.alertStyle = "text" end       -- text | banner | toast | flash (Alerts.lua)
    c.alertTime = math.max(2, math.min(10, tonumber(c.alertTime) or 4))     -- seconds an on-screen alert stays
    -- server maintenance alert (Alerts.lua): flash + banner when the system chat announces a restart / maintenance
    if c.maintAlert == nil then c.maintAlert = true end
    c.maintColorIdx = math.max(1, math.min(7, math.floor(tonumber(c.maintColorIdx) or 1)))   -- 1..7, see GT.MAINT_COLORS
    c.maintColor, c.maintStrength, c.maintAutoPreview = nil, nil, nil                       -- removed settings
    if c.zoneOnly == nil then c.zoneOnly = false end
    if c.lowHP == nil then c.lowHP = true end
    c.alertRange = GT.Clamp(c.alertRange, 0, 500, 0)
    c.alertMinRange = GT.Clamp(c.alertMinRange, 0, 500, 0)
    for key, enabled in pairs(c.alertItems) do
        if not nodes[key] or type(enabled) ~= "boolean" then c.alertItems[key] = nil end
    end
    c.nodeOffsetYd = tonumber(c.nodeOffsetYd) or 3   -- yards from you to the node while gathering
    c.fontMini = tonumber(c.fontMini) or 11
    c.fontWorld = c.fontMini          -- one text size for everything on both maps (fontWorld only mirrors it)
    if type(c.font) ~= "string" then c.font = "default" end          -- font style (Locales.lua GT.FONT_CHOICES)
    if type(c.newSessionOnLogin) ~= "boolean" then c.newSessionOnLogin = false end   -- false = resume the last session
    c.fontScale = math.max(80, math.min(130, tonumber(c.fontScale) or 100))   -- text size, percent
    c.lowHPPct = tonumber(c.lowHPPct) or 35
    -- performance helpers (Graphics.lua): quality level 0..3 with a backup of the player's own CVars, and the
    -- last choices for screen effects / weather / camera zoom (nil = never touched, the game's value stays)
    c.gfxLevel = GT.Clamp(c.gfxLevel, 0, 3, 0)
    if type(c.gfxBackup) ~= "table" then c.gfxBackup = {} end
    if type(c.fxScreen) ~= "boolean" then c.fxScreen = nil end
    if type(c.fxHaze) ~= "boolean" then c.fxHaze = nil end
    c.fxWeather = tonumber(c.fxWeather) and GT.Clamp(c.fxWeather, 0, 3, 3) or nil
    c.fxZoom = tonumber(c.fxZoom) and GT.Clamp(c.fxZoom, 10, 40, 10) or nil
    c.sessions = (tonumber(c.sessions) or 0)
    if c.showArrow == nil then c.showArrow = true end
    if c.includeUnchecked == nil then c.includeUnchecked = false end
    if type(c.miniSummaryAll) ~= "boolean" then c.miniSummaryAll = true end     -- minimized bar tooltip: all items / checked items only
    if type(c.miniSortUrgency) ~= "boolean" then c.miniSortUrgency = true end     -- minimized bar chips: soonest-ready first
    if type(c.miniHideIdle) ~= "boolean" then c.miniHideIdle = false end           -- minimized bar: only running / ready groups
    c.miniBlinkSecs = GT.Clamp(c.miniBlinkSecs, 0, 30, 15)         -- minimized bar: blink at or below this many seconds (0 = off)
    c.miniBgAlpha = GT.Clamp(c.miniBgAlpha, 0, 100, 95)            -- minimized bar: background opacity, percent
    if type(c.miniFadeCombat) ~= "boolean" then c.miniFadeCombat = false end      -- minimized bar: fade while in combat
    if type(c.miniFadeMouse) ~= "boolean" then c.miniFadeMouse = false end        -- minimized bar: fade while the mouse is not over it
    c.miniFadeAlpha = GT.Clamp(c.miniFadeAlpha, 0, 100, 30)        -- minimized bar: opacity while faded, percent
    if type(c.miniUrgencyColors) ~= "boolean" then c.miniUrgencyColors = true end -- minimized bar: white / yellow / red progress bar
    if type(c.miniAlwaysShow) ~= "boolean" then c.miniAlwaysShow = true end        -- minimized bar: open by itself when the addon loads
    if c.showSpawns == nil then c.showSpawns = false end
    -- speed is a divisor ("Leave now" = distance / speed, route costs): 0 or less would make every alert fire at once
    c.speed = GT.Clamp(c.speed, 1, 40, 11)                 -- yards per second
    c.routeRange = GT.Clamp(c.routeRange, 10, 1000, 500)   -- yards (the slider goes 10..500)
    if c.showGroups == nil then c.showGroups = true end
    c.groupSize = tonumber(c.groupSize) or 5
    c.groupSizeOre = tonumber(c.groupSizeOre) or c.groupSize
    if c.nodeShowAll == nil then c.nodeShowAll = false end
    if c.tomtom == nil then c.tomtom = true end
    if c.tomtomHideArrow == nil then c.tomtomHideArrow = false end
    if c.logTomTom == nil then c.logTomTom = true end
    if c.tomTomAutoNearest == nil then c.tomTomAutoNearest = false end
    c.groupCapOre = math.max(1, math.min(3, tonumber(c.groupCapOre) or 1))
    if c.routeMaxNodes == nil then c.routeMaxNodes = 50 end
    if c.routeOnlyReady == nil then c.routeOnlyReady = true end
    if c.routeTimeWindow == nil then c.routeTimeWindow = 600 end
    if c.routeLowStock == nil then c.routeLowStock = false end
    c.routeStockTarget = math.floor(GT.Clamp(c.routeStockTarget, 1, 200, 20) + 0.5)
    if type(c.routeItem) ~= "string" or (c.routeItem ~= "all" and not nodes[c.routeItem]) then c.routeItem = "all" end
    if c.routeAutoArrow == nil then c.routeAutoArrow = true end
    if c.routeDrawMap == nil then c.routeDrawMap = true end
    if c.timingZoneOnly == nil then c.timingZoneOnly = false end
    if c.showMapPins == nil then c.showMapPins = true end
    if c.showGroupPins == nil then c.showGroupPins = true end
    if c.showMiniPins == nil then c.showMiniPins = true end
    c.readyLinger = math.max(30, math.min(1800, tonumber(c.readyLinger) or GT.READY_LINGER or 120))  -- seconds a node stays READY before it goes Idle
    c.pinSize = tonumber(c.pinSize) or 16
    for key, def in pairs(nodes) do
        local t = tonumber(c.timers[key])
        if t and t > 0 then
            t = GT.ClampTimer(t, def.defaultTimer)          -- a hand-edited / damaged value stays in 30 s .. 2 h
            c.timers[key] = t
            def.timer = t
        elseif c.timers[key] ~= nil then
            c.timers[key] = nil                              -- zero, negative, NaN or text: back to the default
        end
        if not COLORS[c.colors[key] or 0] then c.colors[key] = DEFAULT_COLOR[key] or 1 end
        if not SOUNDS[c.sounds[key] or 0] then c.sounds[key] = 7 end
        if type(c.learn[key]) ~= "table" then c.learn[key] = {} end
        if type(c.learnZone[key]) ~= "table" then c.learnZone[key] = {} end
    end
end

-- ============================================================
-- SAVED DATA: realm tagging + cleanup  (plain Lua on a table: also run by Tests\run.lua)
-- ============================================================
-- Respawn timers belong to one realm AND one game mode: the same herb spot is a different node on another realm,
-- and on a Hardcore character.  Every timer carries .realm ("Realm" or "Realm-Hardcore", GT.RealmName).  At load,
-- timers of other realms / modes are parked in db._otherRealms[realm][key] and the ones parked for this realm
-- come back.  Timers saved before realm tagging (no .realm) are assumed to belong to the realm you log in on now:
-- they are at most a few minutes old, so this cannot do much harm.
-- Layout 3 (Hardcore stamp): timers and parked timers tagged with the bare realm name by layout 2 get the same
-- assumption once, for the same reason.
-- Returns the number of timers parked.
function GT.MigrateRealm(db, realm, now)
    if type(realm) ~= "string" or realm == "" then return 0 end      -- realm unknown yet: change nothing
    now = tonumber(now) or 0
    local other = db._otherRealms
    if type(other) ~= "table" then other = {}; db._otherRealms = other end
    local bare = (realm:gsub("%-Hardcore$", ""))
    local upgrade = (tonumber(db._dbVersion) or 0) < 3 and bare ~= realm     -- only a Hardcore login has something to adopt
    local parked = 0
    for key in pairs(nodes) do
        local list = db[key]
        if type(list) == "table" then
            for i = #list, 1, -1 do
                local n = list[i]
                if n.realm == nil or (upgrade and n.realm == bare) then
                    n.realm = realm
                elseif n.realm ~= realm then
                    local r = other[n.realm]
                    if type(r) ~= "table" then r = {}; other[n.realm] = r end
                    local rl = r[key]
                    if type(rl) ~= "table" then rl = {}; r[key] = rl end
                    rl[#rl + 1] = n
                    if GT.RemoveTextTimer then pcall(GT.RemoveTextTimer, n) end     -- no label for a parked timer
                    table.remove(list, i)
                    parked = parked + 1
                end
            end
            for _, name in ipairs(upgrade and { realm, bare } or { realm }) do
                local mine = type(other[name]) == "table" and other[name][key]
                if type(mine) == "table" then
                    for _, n in ipairs(mine) do
                        if type(n) == "table" then n.realm = realm; list[#list + 1] = n end
                    end
                    other[name][key] = nil
                end
            end
        end
    end
    -- tidy the parking lot: drop long-expired or malformed timers and empty realms
    for rname, r in pairs(other) do
        if type(rname) ~= "string" or type(r) ~= "table" then
            other[rname] = nil
        else
            for key, rl in pairs(r) do
                if type(key) ~= "string" or type(rl) ~= "table" then
                    r[key] = nil
                else
                    for i = #rl, 1, -1 do
                        local n = rl[i]
                        if type(n) ~= "table" or type(n.time) ~= "number" or (now > 0 and n.time < now - STASH_MAX_AGE) then
                            table.remove(rl, i)
                        end
                    end
                    if #rl == 0 then r[key] = nil end
                end
            end
            if next(r) == nil then other[rname] = nil end
        end
    end
    db._dbVersion = math.max(tonumber(db._dbVersion) or 0, DB_VERSION)   -- an older version never lowers the stamp
    return parked
end

-- Saved settings that no longer mean anything.  Everything is removed by NAME or by shape, never by a
-- "not in my list" rule, so settings of other modules (the HUD keeps its own in db.hud) and of newer
-- versions are never touched.
local OBSOLETE_CFG = { "maintColor", "maintStrength", "maintAutoPreview", "trackSwitch" }
local OBSOLETE_UI = { "trackSwitch" }
local PER_NODE_CFG = { "enabled", "timers", "colors", "sounds", "learn", "learnZone" }   -- c[name][nodeKey]

local function CleanSamples(l)
    if type(l) ~= "table" then return {} end
    for i = #l, 1, -1 do
        if type(l[i]) ~= "number" or l[i] <= 0 then table.remove(l, i) end
    end
    return l
end

function GT.CleanSavedKeys(db)
    local c = db._cfg
    if type(c) ~= "table" then return end
    for _, k in ipairs(OBSOLETE_CFG) do c[k] = nil end
    if type(db._ui) == "table" then
        for _, k in ipairs(OBSOLETE_UI) do db._ui[k] = nil end
    end
    -- settings of item types this version does not know are KEPT (a newer version may use them);
    -- only entries that are not even the right shape are dropped
    for _, name in ipairs(PER_NODE_CFG) do
        local t = c[name]
        if type(t) == "table" then
            for k in pairs(t) do
                if type(k) ~= "string" then t[k] = nil end
            end
        end
    end
    -- respawn samples: numbers only
    if type(c.learn) == "table" then
        for k, l in pairs(c.learn) do
            if type(l) == "table" then CleanSamples(l) elseif nodes[k] then c.learn[k] = {} else c.learn[k] = nil end
        end
    end
    if type(c.learnZone) == "table" then
        for _, zones in pairs(c.learnZone) do
            if type(zones) == "table" then
                for mapID, l in pairs(zones) do
                    if type(mapID) ~= "number" or type(l) ~= "table" then zones[mapID] = nil
                    else zones[mapID] = CleanSamples(l) end
                end
            end
        end
    end
    -- group data is keyed "<item key>:<mapID>": drop entries whose key is not in that form
    for _, name in ipairs({ "groupStore", "groupCounts" }) do
        local t = c[name]
        if type(t) == "table" then
            for k in pairs(t) do
                if not (type(k) == "string" and k:match("^.-:%d+$")) then t[k] = nil end
            end
        end
    end
end

function GT.SanitizeDB()
    local db = GatherTimesDB
    -- Unknown top-level keys are LEFT ALONE (they may belong to a newer version or another module: deleting
    -- them made a downgrade wipe data).  Only the keys this version knows are checked below.
    InitCfg()
    for k in pairs(nodes) do
        if type(db[k]) ~= "table" then db[k] = {} end
        local list = db[k]
        for i = #list, 1, -1 do
            local n = list[i]
            if type(n) ~= "table"
                or type(n.mapID) ~= "number" or type(n.x) ~= "number"
                or type(n.y) ~= "number" or type(n.time) ~= "number" then
                table.remove(list, i)
            else
                n.x, n.y = GT.Round5(n.x), GT.Round5(n.y)        -- smaller saved file
                -- _hasAlerted / _leaveAlerted are SAVED ON PURPOSE (see Events.lua, PLAYER_LOGOUT): after a quick relog
                -- or /reload a timer that already alerted must not alert again.  Only `true` is a valid value.
                if n._hasAlerted ~= true then n._hasAlerted = nil end
                if n._leaveAlerted ~= true then n._leaveAlerted = nil end
                if n._soundDone ~= true then n._soundDone = nil end
            end
        end
    end
    if type(db._spawns) ~= "table" then db._spawns = {} end
    GT.spawns = db._spawns
    wipe(spawnBySid)
    local maxSid = 0
    -- spots of item types this version does not know stay in the file, but their ids still count so that a
    -- new spot never gets the same id
    for k, list in pairs(GT.spawns) do
        if not nodes[k] and type(list) == "table" then
            for _, sp in ipairs(list) do
                if type(sp) == "table" and type(sp.sid) == "number" and sp.sid > maxSid then maxSid = sp.sid end
            end
        end
    end
    for k in pairs(nodes) do
        if type(GT.spawns[k]) ~= "table" then GT.spawns[k] = {} end
        local list = GT.spawns[k]
        for i = #list, 1, -1 do
            local sp = list[i]
            if type(sp) ~= "table" or type(sp.sid) ~= "number" or type(sp.mapID) ~= "number"
                or type(sp.x) ~= "number" or type(sp.y) ~= "number" or spawnBySid[sp.sid] then
                table.remove(list, i)
            else
                -- sp.nexts (spot -> how often you went there next) is created by RegisterLoot when first needed;
                -- an empty or damaged one is dropped here, which also cleans files saved by older versions
                if type(sp.nexts) ~= "table" or next(sp.nexts) == nil then sp.nexts = nil end
                sp.x, sp.y = GT.Round5(sp.x), GT.Round5(sp.y)        -- smaller saved file
                sp.hits = tonumber(sp.hits) or 1
                sp.last = tonumber(sp.last) or 0
                sp.misses = tonumber(sp.misses) or 0
                sp.lootTime = tonumber(sp.lootTime)
                sp.note = GT.SanitizeSpotNote(sp.note)
                spawnBySid[sp.sid] = sp
                if sp.sid > maxSid then maxSid = sp.sid end
            end
        end
    end
    db._spawnNext = math.max(tonumber(db._spawnNext) or 1, maxSid + 1)
    GT.CleanSavedKeys(db)
    GT.PruneSpotRefs(db)
    local realm = GT.RealmName()
    GT.MigrateRealm(db, realm, GetServerTime and GetServerTime() or 0)
    GT.realmAtLoad = realm
    if GT.SanitizeZoneYield then GT.SanitizeZoneYield(db) end
end
-- (SanitizeDB() is now called from Events.lua on ADDON_LOADED)

-- The Hardcore stamp comes from C_GameRules.IsHardcoreActive(), which may not answer yet while the addon loads
-- (ADDON_LOADED).  On a Hardcore character the timers would then be tagged / sorted as "Realm" instead of
-- "Realm-Hardcore" and parked.  PLAYER_ENTERING_WORLD calls this: when the realm tag is different from the one used at
-- load, the timers are sorted again with the right tag (timers parked under it come back).  Returns true when it did.
function GT.RecheckRealm()
    local realm = GT.RealmName()
    if not realm or realm == GT.realmAtLoad then return false end
    GT.MigrateRealm(GatherTimesDB, realm, GetServerTime and GetServerTime() or 0)
    GT.realmAtLoad = realm
    return true
end

-- Spot ids that no longer exist (an imported spot that was evicted, a damaged one dropped above) must not stay in the
-- file: neither in the saved group membership (cfg.groupStore[<item>:<map>].of) nor in other spots' "went there
-- next" counts (sp.nexts).  Runs after spawnBySid is rebuilt.  Item types this version does not know are left alone.
function GT.PruneSpotRefs(db)
    local c = db._cfg
    if type(c) == "table" and type(c.groupStore) == "table" then
        for ck, st in pairs(c.groupStore) do
            local key = type(ck) == "string" and ck:match("^(.-):%d+$")
            if key and nodes[key] and type(st) == "table" and type(st.of) == "table" then
                for sid in pairs(st.of) do
                    if not spawnBySid[sid] then st.of[sid] = nil end
                end
            end
        end
    end
    for key in pairs(nodes) do
        for _, sp in ipairs(GT.spawns[key] or {}) do
            local nx = sp.nexts
            if nx then
                for sid, cnt in pairs(nx) do
                    if not spawnBySid[sid] or type(cnt) ~= "number" or cnt ~= cnt or cnt <= 0 then nx[sid] = nil end
                end
                GT.TrimNexts(nx)                      -- files from older versions: keep the strongest GT.NEXTS_MAX
                if next(nx) == nil then sp.nexts = nil end
            end
        end
    end
end

function GT.IsEnabled(key)
    return GT.cfg().enabled[key] ~= false
end
function GT.Col(key)
    return COLORS[GT.cfg().colors[key]] or COLORS[1]
end

-- What the main-window dropdown is set to (GatherTimesDB._ui.mainItem):
--   "checked" = "All checked" -> every node ticked in the Nodes panel
--   "item"    = one of those items picked
function GT.ViewMode()
    local ui = GatherTimesDB and GatherTimesDB._ui
    local sel = ui and ui.mainItem
    if sel and sel ~= "all" and nodes[sel] then return "item" end
    return "checked"
end

-- DISPLAY filter (main table, map / minimap pins and labels).  IsEnabled stays the TRACKING switch
-- (alerts, learning, routes, TomTom); this one only decides what is drawn: the picked item, or every
-- ticked node when "All checked" is picked.
function GT.IsShown(key)
    local ui = GatherTimesDB and GatherTimesDB._ui
    local sel = ui and ui.mainItem
    if sel and sel ~= "all" and nodes[sel] then return key == sel and GT.IsEnabled(key) end
    return GT.IsEnabled(key)
end

function GT.CanReadyAlert(key, node)
    local c = GT.cfg()
    if c.alertItems[key] == false then return false end
    local dist = node._dist
    if c.alertMinRange > 0 or c.alertRange > 0 then
        if not dist then dist = GT.GetDistance(node) end
        if not dist then return c.alertMinRange <= 0 and c.alertRange <= 0 end
        if c.alertMinRange > 0 and dist < c.alertMinRange then return false end
        if c.alertRange > 0 and dist > c.alertRange then return false end
    end
    return true
end
-- Plays the sound chosen for this node type in the Nodes panel ("None" = silent).
-- throttle = true: at most one sound per node type every 20 seconds, so several nodes of the same
-- type becoming ready together (or spots passed one after another) do not stack up as a "loop".
local soundAt = {}
function GT.PlayHerbSound(key, throttle)
    local s = SOUNDS[GT.cfg().sounds[key] or 1]
    if not (s and s.id ~= 0) then return false end
    if throttle then
        local t = GetTime()
        if t - (soundAt[key] or -999) < 20 then return false end
        soundAt[key] = t
    end
    pcall(PlaySound, s.id, "Master")
    return true
end

-- ============================================================
-- ALERT SYSTEM

-- Like the original: build a valid default DB at load time so cfg() works for code that
-- runs while files load. WoW replaces the global with the real saved data afterwards,
-- and Events.lua sanitizes again on ADDON_LOADED.
GatherTimesDB = GatherTimesDB or {}
GT.SanitizeDB()
