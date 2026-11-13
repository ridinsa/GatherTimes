-- HUDProfiles.lua : saved variables (GatherTimesDB.hud) and the profiles. Part of the HUD module (see HUD.lua).
local _, GT = ...
local HUD = GT.HUD
local S = HUD.S
local Clamp = HUD.Clamp
local Round = HUD.Round
local CopyAny = HUD.CopyAny

local DB_VERSION     = 1                -- GatherTimesDB.hud layout version

---------------------------------------------------------------------------
-- Saved variables: account root -> profiles, per-character profile selection
---------------------------------------------------------------------------

local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function FillDefaults(p)
    -- profiles saved before the second ring had its own colour: start it with the ring 1 colour
    if type(p.ringColor2) ~= "table" and type(p.ringColor) == "table" then p.ringColor2 = CopyAny(p.ringColor) end
    p.eagleRing, p.eagleSync = nil, nil       -- remove deleted Eagle ring and HUD-sync settings from existing profiles
    for k, v in pairs(HUD.DEFAULTS) do
        -- a missing value, or one of the wrong type (hand-edited SavedVariables), falls back to the default
        if type(p[k]) ~= type(v) then p[k] = CopyAny(v) end
    end
    local L = HUD.LIMITS
    p.size = Clamp(p.size, L.size[1], L.size[2])      -- screen limit is applied in HUD.EffectiveSize, not saved
    p.alpha = Clamp(p.alpha, 0, 1)
    p.eagleSize = Clamp(p.eagleSize, L.eagleSize[1], L.eagleSize[2])
    p.eagleAlpha = Clamp(p.eagleAlpha, 0, 1)
    p.eagleZoom = Clamp(Round(p.eagleZoom), L.zoom[1], L.zoom[2])
    p.x, p.y = nil, nil                               -- (the HUD position offset is gone: the map is always centred)
    p.zoom = Clamp(Round(p.zoom), L.zoom[1], L.zoom[2])
    p.ring = Clamp(p.ring, L.ring[1], L.ring[2])
    p.ring2 = Clamp(p.ring2, L.ring[1], L.ring[2])
    p.ringYd = Clamp(p.ringYd, L.ringYd[1], L.ringYd[2])
    p.ring2Yd = Clamp(p.ring2Yd, L.ringYd[1], L.ringYd[2])
    if p.ringUnit ~= "px" and p.ringUnit ~= "yd" then p.ringUnit = "px" end
    p.ringThickness = Clamp(p.ringThickness, 1, 10)
    p.ringSegments = Clamp(p.ringSegments, 8, 256)
    if p.ringStyle ~= "solid" and p.ringStyle ~= "stripes" and p.ringStyle ~= "dots" then p.ringStyle = "solid" end
    p.ringDensity = Clamp(Round(p.ringDensity), L.ringDensity[1], L.ringDensity[2])
    for i = 1, 4 do
        local c = p.ringColor[i]
        p.ringColor[i] = Clamp(type(c) == "number" and c or HUD.DEFAULTS.ringColor[i], 0, 1)
        local c2 = p.ringColor2[i]
        p.ringColor2[i] = Clamp(type(c2) == "number" and c2 or HUD.DEFAULTS.ringColor2[i], 0, 1)
    end
    if p.trackIdle ~= "auto" and p.trackIdle ~= "own" and p.trackIdle ~= "stock" then p.trackIdle = "auto" end
    p.trackingX = Clamp(p.trackingX, L.trackingX[1], L.trackingX[2])
    p.trackingY = Clamp(p.trackingY, L.trackingY[1], L.trackingY[2])
    p.trackingSize = Clamp(p.trackingSize, L.trackingSize[1], L.trackingSize[2])
    p.idleX = Clamp(p.idleX, L.idleX[1], L.idleX[2])
    p.idleY = Clamp(p.idleY, L.idleY[1], L.idleY[2])
end

-- GatherTimesDB.hud layout:
--   ver, restoreOnLogin, deepScan, debug, origRotate   account-wide switches / crash-recovery value
--   perfLevel (0 Full / 1 Balanced / 2 Lowest), perfSuggest, perfSuggested   performance (was: lowSpec)
--   profiles  = { [name] = { size, alpha, x, y, ... } } every HUD setting (see HUD.DEFAULTS)
--   chars     = { ["Name-Realm"] = { profile, wasActive } }
-- GT.SanitizeDB (Config.lua) keeps the "hud" key; this function fills in whatever is missing.
local function InitDB()
    GatherTimesDB = GatherTimesDB or {}
    if type(GatherTimesDB.hud) ~= "table" then GatherTimesDB.hud = {} end
    local root = GatherTimesDB.hud
    HUD.root = root
    root.ver = math.max(tonumber(root.ver) or 0, DB_VERSION)   -- an older version never lowers the stamp

    if type(root.profiles) ~= "table" then root.profiles = {} end
    if type(root.chars) ~= "table" then root.chars = {} end
    root.ui = nil                       -- (the settings are a fixed panel now; no window position to keep)
    if type(root.restoreOnLogin) ~= "boolean" then root.restoreOnLogin = false end
    if type(root.deepScan) ~= "boolean" then root.deepScan = false end
    if type(root.debug) ~= "boolean" then root.debug = false end
    -- performance level; the old Lower-spec checkbox (lowSpec) becomes "Lowest"
    if root.lowSpec == true and root.perfLevel == nil then root.perfLevel = 2 end
    root.lowSpec = nil
    if root.perfLevel ~= 0 and root.perfLevel ~= 1 and root.perfLevel ~= 2 then root.perfLevel = 0 end
    if type(root.perfSuggest) ~= "boolean" then root.perfSuggest = true end
    if type(root.perfSuggested) ~= "boolean" then root.perfSuggested = false end

    if type(root.profiles.Default) ~= "table" then root.profiles.Default = {} end
    for name, p in pairs(root.profiles) do
        if type(p) == "table" then FillDefaults(p) else root.profiles[name] = nil end   -- damaged entry
    end

    local key = CharKey()
    if type(root.chars[key]) ~= "table" then root.chars[key] = { profile = "Default" } end
    S.charState = root.chars[key]
    if not root.profiles[S.charState.profile] then S.charState.profile = "Default" end
    HUD.db = root.profiles[S.charState.profile]
    HUD.UpdateEagleLabels()                -- frames made before the profile was loaded

    -- Crash recovery: a previous session died with the HUD on, leaving rotateMinimap changed
    if root.origRotate ~= nil then
        pcall(SetCVar, "rotateMinimap", root.origRotate)
        root.origRotate = nil
    end
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------

function HUD.ProfileCurrent() return S.charState and S.charState.profile or "Default" end

function HUD.ProfileList()
    local t = {}
    for name in pairs(HUD.root.profiles) do t[#t + 1] = name end
    table.sort(t)
    return t
end

-- Switch to a profile; a new name creates it as a copy of the current profile.
function HUD.ProfileSwitch(name)
    local root = HUD.root
    local created = false
    if not root.profiles[name] then
        root.profiles[name] = CopyAny(HUD.db)
        created = true
    end
    S.charState.profile = name
    HUD.db = root.profiles[name]
    FillDefaults(HUD.db)
    HUD.UpdateEagleLabels()
    if S.active then HUD.Refresh() elseif HUD.Tracking then HUD.Tracking.Refresh() end
    if HUD.Config then HUD.Config.Refresh() end
    return created
end

function HUD.ProfileDelete(name)
    local root = HUD.root
    if name == S.charState.profile then return false, "that profile is in use" end
    if name == "Default" then return false, "the Default profile cannot be deleted" end
    if not root.profiles[name] then return false, "no such profile" end
    root.profiles[name] = nil
    for _, c in pairs(root.chars) do
        if c.profile == name then c.profile = "Default" end
    end
    return true
end

function HUD.ResetProfile()
    local db = HUD.db
    for k in pairs(db) do db[k] = nil end
    FillDefaults(db)
    if S.active then HUD.Refresh() elseif HUD.Tracking then HUD.Tracking.Refresh() end
    if HUD.Config then HUD.Config.Refresh() end
end

-- shared with the other HUD files
HUD.I.InitDB = InitDB
