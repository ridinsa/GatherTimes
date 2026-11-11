-- HUD.lua : the built-in minimap HUD module of GatherTimes.
--
-- Gathering overlay for WoW Classic Era (Interface 11509): minimap takeover + restore, mask selection
-- (Masks\a00.tga, the blank mask), player arrow, rings, compass letters, heading readout, the HUD's own tracking
-- button, and the refresh of the node pins (GatherTimes timers / spawn spots, GatherMate2, TomTom) that
-- live on the Minimap.
--
-- File layout (HUD\, loaded in this order by GatherTimes.toc; all files share one table, GT.HUD):
--   HUD.lua            this file, the core: defaults, saved variables + profiles, minimap mask, minimap
--                      takeover / restore, HUD.Set, lifecycle (Init / OnEvent / OnUpdate)
--   HUDFrames.lua      hiding minimap decorations and addon skins / buttons, and the stock tracking button
--   HUDPins.lua        asks the node pins on the minimap to lay themselves out again
--   HUDAutoGather.lua  switches the HUD on while Find Herbs / Minerals / Treasure is active
--   HUDOverlay.lua     rings, compass letters, heading readout
--   HUDTracking.lua    the HUD's own tracking button
--   HUDSlash.lua       /gthud commands and the status / info output
--   HUDConfig.lua      the HUD settings panel
-- Runtime state that other files need is reached through HUD.* functions (HUD.IsActive(), HUD.OrigWidth(),
-- HUD.WasAutoEnabled() ...), never by sharing locals: a file-level `local` is private to its file.
--
-- Ownership: these files hold the HUD logic only. GatherTimes owns the lifecycle:
--   * Events.lua  - ADDON_LOADED / PLAYER_ENTERING_WORLD / ... and the update loop call
--                   HUD.Init(), HUD.OnEvent(event, ...) and HUD.OnUpdate(elapsed)
--   * Core.lua    - slash commands (/gt hud ..., /gthud ...) call HUD.Slash(msg)
--   * Config.lua  - all settings live in GatherTimesDB.hud
--   * HUDConfig.lua - the HUD settings panel (opened from the HUD button in the main window)
-- No event frames, slash commands or SavedVariables of its own.

local addonName, GT = ...

local HUD = {}
GT.HUD = HUD

-- Keybinding labels (Key Bindings -> AddOns -> GatherTimes). The binding itself is in Bindings.xml.
BINDING_HEADER_GATHERTIMES = "GatherTimes"
BINDING_NAME_GATHERTIMES_HUD_TOGGLE = "Toggle HUD"
BINDING_NAME_GATHERTIMES_EAGLE_ZOOM_IN = "Eagle map: zoom in"
BINDING_NAME_GATHERTIMES_EAGLE_ZOOM_OUT = "Eagle map: zoom out"
BINDING_NAME_GATHERTIMES_EAGLE_SIZE = "Eagle map: next size"

---------------------------------------------------------------------------
-- Constants and defaults
---------------------------------------------------------------------------

local DB_VERSION     = 1                -- GatherTimesDB.hud layout version
local MINIMAP_BASE_SIZE = 140            -- stock minimap diameter (fallback only)
-- Size actually used on screen: the saved value limited to what fits right now. The profile itself keeps the
-- value the player chose, so one login at a small window or high UI scale no longer shrinks it for good.
function HUD.EffectiveSize(db)
    db = db or HUD.db
    local v = db and db.size or HUD.DEFAULTS.size
    return math.max(HUD.LIMITS.size[1], math.min(v, HUD.MaxSize()))
end
-- largest HUD size that fits on the screen: a bigger map is pushed down by the game (ring moves off-centre)
function HUD.MaxSize()
    local screen = UIParent and UIParent:GetHeight() or 0
    return math.max(150, math.min(HUD.LIMITS.size[2], math.floor(screen)))
end
local STOCK_MASK     = "Textures\\MinimapMask"
local STOCK_ARROW    = "Interface\\Minimap\\MinimapArrow"
HUD.MINIMAP_BASE_SIZE = MINIMAP_BASE_SIZE   -- (HUDFrames.lua)

HUD.LIMITS = {
    size = { 150, 1400 },
    eagleSize = { 150, 1400 },
    ring = { 0, 700 },
    ringYd = { 0, 250 },
    zoom = { 0, 5 },
    trackingX = { -1500, 1500 },
    trackingY = { -1000, 1000 },
    trackingSize = { 20, 80 },
    ringDensity  = { 4, 128 },
    idleX = { -1500, 1500 },
    idleY = { -1500, 1500 },
}

-- Per-profile settings
HUD.DEFAULTS = {
    size          = 800,
    alpha         = 0,             -- 0 = fully transparent map, 1 = opaque (10% steps)
    zoom          = 0,
    rotate        = true,
    arrow         = true,          -- show the player arrow
    dirs          = false,         -- N/E/S/W letters
    heading       = false,         -- heading readout (e.g. "NE 45")
    priorityReadout = true,         -- nearest ready node, or nearest respawn timer
    routeReadout  = true,          -- current step of a planned route
    ring          = 179,           -- ring radius in px, 0 = off
    ring2         = 0,             -- optional second ring radius, 0 = off
    ringUnit      = "px",          -- "px": ring radius is in screen pixels, "yd": in yards (follows zoom and size)
    ringYd        = 40,            -- ring radius in yards (ringUnit = "yd"), 0 = off
    ring2Yd       = 0,             -- second ring in yards, 0 = off
    ringColor     = { 1, 1, 1, 0.6 },
    ringColor2    = { 1, 1, 1, 0.6 },   -- colour of the second ring
    ringThickness = 2,
    ringSegments  = 64,
    ringStyle     = "solid",       -- "solid" (line), "stripes" or "dots"
    ringDensity   = 24,            -- stripes or dots around the ring (4-128)
    tracking      = true,          -- show the HUD's own tracking button
    trackingSize  = 50,            -- tracking button size in px (was fixed at 31)
    idleX         = 0,             -- tracking button offset while the HUD is OFF (from the minimap's top-left)
    idleY         = 0,
    trackIdle     = "auto",        -- tracking button while the HUD is OFF: "auto" | "own" | "stock"
    trackingX     = 90,            -- tracking button offset from its default spot (right edge of the HUD)
    trackingY     = 250,
    hideAddons    = true,          -- hide minimap addon skins / button frames (SexyMap, ElvUI, LibDBIcon ...)
    mountFade     = false,         -- hide the HUD while mounted
    autoGather    = false,         -- auto-enable while Find Herbs/Minerals/Treasure is active
    -- Eagle Eye map: while the hunter's Eagle Eye is on, the HUD stays on but the map is drawn centred, at its
    -- own size / mask / zoom, without the compass letters and readouts (the camera is away from the character).
    eagleMap      = true,          -- false = the old behaviour: the HUD is switched off during Eagle Eye
    eagleSize     = 450,           -- map diameter in px
    eagleAlpha    = 1,             -- map opacity (mask a00 ... a10), 1 = opaque
    eagleZoom     = 0,
    eagleRotate   = false,         -- north-up: the camera is not looking where the character looks
    eagleRing     = true,          -- ring around the edge of the Eagle map
    eagleScale    = true,          -- distance scale: the edge of the map and a half-way ring, labelled in yards
    eagleNearest  = true,          -- readout of the nearest known node (name, ready / time left, yards) while it is up
    hideLabelsIdle = true,         -- hide the Gx labels and (G) timers on the normal minimap; they show while the HUD is on
    eagleSync     = true,          -- the Eagle map uses the HUD's zoom and ring sizes (rings scaled to the smaller map)
    eagleHideLabels = true,        -- hide the Gx group labels and the (G) timers on the map while the Eagle map is up
    eagleHover    = true,          -- the Eagle map takes the mouse (clicks pass through) so the game's herb / ore hover tooltips work
}

-- Which setting changes need which kind of refresh
local OVERLAY_KEYS = { ring = true, ring2 = true, ringUnit = true, ringYd = true, ring2Yd = true,
                       ringColor = true, ringColor2 = true,
                       ringThickness = true,
                       ringSegments = true, ringStyle = true, ringDensity = true, dirs = true, heading = true,
                       priorityReadout = true, routeReadout = true }
local MAP_KEYS     = { size = true, alpha = true, zoom = true,
                       rotate = true, arrow = true, mountFade = true }
-- settings of the Eagle Eye map: they only change what is on screen while that map is up
local EAGLE_KEYS   = { eagleSize = true, eagleAlpha = true, eagleZoom = true, eagleRotate = true, eagleRing = true,
                       eagleScale = true, eagleNearest = true, eagleHover = true, eagleHideLabels = true, eagleSync = true }
local TRACK_KEYS   = { trackingX = true, trackingY = true, trackingSize = true, idleX = true, idleY = true }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(msg)
    GT.cprint("|cff33ff99HUD:|r " .. tostring(msg))
end
HUD.Print = Print

local function Debug(msg)
    if HUD.root and HUD.root.debug then Print("|cff888888" .. tostring(msg) .. "|r") end
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function Round(v) return math.floor(v + 0.5) end
HUD.Clamp, HUD.Round = Clamp, Round

local function CopyAny(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyAny(x) end
    return t
end

local function MaskPath(alpha)
    local step = math.floor(Clamp(alpha, 0, 1) * 10 + 0.5)
    return string.format("Interface\\AddOns\\%s\\Masks\\a%02d.tga", addonName, step)
end
local BLANK_TEXTURE = MaskPath(0)   -- a00.tga is fully transparent

---------------------------------------------------------------------------
-- State (runtime only; nothing here is written to SavedVariables)
---------------------------------------------------------------------------

local active = false
local autoEnabled = false           -- HUD was switched on by autoGather
local orig                          -- snapshot of the stock minimap
local lastMask = STOCK_MASK         -- last mask set by anyone else (SexyMap etc.)
local appliedMask                   -- mask we last applied
local settingMask = false
local arrowHidden = false
local lastArrow                      -- last player arrow set by anyone else (SexyMap etc.); nil = stock
local settingArrow = false
local applying = false              -- true while WE move the minimap (ignored by the re-apply hooks)
local eagleMode = false             -- the Eagle Eye map is up (HUD on, drawn with the eagle* settings)
local eaglePreview = false          -- the settings panel's Preview button holds the Eagle map up without Eagle Eye
local EAGLE_SIZE_STEPS = { 1, 1.5, 0.65 }   -- the "next size" key: the saved size, then bigger, then smaller (this view only)
local eagleSizeStep = 1
function HUD.EagleSizeMul() return EAGLE_SIZE_STEPS[eagleSizeStep] or 1 end
local charState                     -- GatherTimesDB.hud.chars[charKey]

function HUD.IsActive() return active end
function HUD.WasAutoEnabled() return autoEnabled end      -- (HUDAutoGather.lua)
function HUD.OrigWidth() return orig and orig.width end   -- stock minimap width while the HUD is up (HUDFrames.lua)

-- The settings the map is drawn with right now: the profile, or - while the Eagle Eye map is up - the profile with
-- the eagle* values laid over it. Everything that draws the map or the overlay reads this, never HUD.db directly;
-- the profile itself is never changed by Eagle Eye.
local eagleView = setmetatable({}, { __index = function(_, k) return HUD.db and HUD.db[k] end })
function HUD.Cfg()
    local db = HUD.db
    if not (eagleMode and db) then return db end
    local v = eagleView
    v.size = math.floor(db.eagleSize * HUD.EagleSizeMul() + 0.5)
    v.alpha, v.rotate, v.arrow = db.eagleAlpha, db.eagleRotate, true
    local edge = math.max(0, math.floor(HUD.EffectiveSize(v) / 2) - 2)
    v.hoverTips = db.eagleHover and true or false   -- (ConfigureMinimapInner)
    if db.eagleSync then
        -- same zoom as the HUD, and the HUD's own rings: the map shows the same yards at any size, so a ring in
        -- pixels is scaled by (Eagle size / HUD size) to stand for the same distance; rings in yards need no change
        v.zoom = db.zoom
        local k = HUD.EffectiveSize(v) / HUD.EffectiveSize(db)
        local on = db.eagleRing
        v.ringUnit = db.ringUnit
        v.ring  = on and math.min(edge, math.floor(db.ring * k + 0.5)) or 0
        v.ring2 = on and math.min(edge, math.floor(db.ring2 * k + 0.5)) or 0
        v.ringYd, v.ring2Yd = on and db.ringYd or 0, on and db.ring2Yd or 0
        v.scaleCaps = db.eagleScale and db.ringUnit == "px" or false   -- px rings are captioned with their yards
    else
        v.zoom = db.eagleZoom
        v.ring = db.eagleRing and edge or 0
        v.ringUnit = "px"                           -- the Eagle rings sit at fixed places on the map, in pixels ...
        v.scaleCaps = db.eagleScale and true or false   -- ... and are captioned with the yards they stand for (HUDOverlay.lua)
        v.ring2 = db.eagleScale and math.floor(edge / 2) or 0      -- half-way ring of the distance scale
        v.ringYd, v.ring2Yd = db.ringYd, db.ring2Yd
    end
    v.dirs, v.heading, v.routeReadout = false, false, false
    v.priorityReadout = db.eagleNearest and true or false      -- nearest node: the same readout the normal HUD has
    return v
end
function HUD.EagleMapUp() return eagleMode end

-- Gx labels and (G) timers on the minimap: hidden (alpha 0, so the pin library's own Show / Hide is not fought)
-- while the Eagle map is up and "eagleHideLabels" is on. Read by Pins.lua / TextTimers.lua when a frame is made or
-- shown; HUD.UpdateEagleLabels() re-applies it to every frame that already exists.
function HUD.MiniLabelAlpha()
    local db = HUD.db
    if not db then return 1 end
    if not active then return db.hideLabelsIdle and 0 or 1 end      -- normal minimap
    return (eagleMode and db.eagleHideLabels) and 0 or 1
end
function HUD.UpdateEagleLabels()
    if GT.RefreshMiniLabelAlpha then pcall(GT.RefreshMiniLabelAlpha) end
end

-- How far the minimap sees right now: the distance from the centre to the edge of the map, in yards. It depends on
-- the zoom level and on being indoors or outdoors (the HUD size does not change it). Newer clients report it
-- directly; older ones use the same size table HereBeDragons uses (diameters in yards, per zoom level).
local MAP_DIAMETER = {
    indoor  = { [0] = 300, 240, 180, 120, 80, 50 },
    outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
}
function HUD.MapRadiusYards()
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, r = pcall(C_Minimap.GetViewRadius)
        if ok and type(r) == "number" and r > 0 then return r end
    end
    local zoom = Minimap:GetZoom() or 0
    local t = MAP_DIAMETER[(IsIndoors and IsIndoors()) and "indoor" or "outdoor"]
    return (t[zoom] or t[0]) / 2
end

---------------------------------------------------------------------------
-- Saved variables: account root -> profiles, per-character profile selection
---------------------------------------------------------------------------

local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function FillDefaults(p)
    -- profiles saved before the second ring had its own colour: start it with the ring 1 colour
    if type(p.ringColor2) ~= "table" and type(p.ringColor) == "table" then p.ringColor2 = CopyAny(p.ringColor) end
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

    if type(root.profiles.Default) ~= "table" then root.profiles.Default = {} end
    for name, p in pairs(root.profiles) do
        if type(p) == "table" then FillDefaults(p) else root.profiles[name] = nil end   -- damaged entry
    end

    local key = CharKey()
    if type(root.chars[key]) ~= "table" then root.chars[key] = { profile = "Default" } end
    charState = root.chars[key]
    if not root.profiles[charState.profile] then charState.profile = "Default" end
    HUD.db = root.profiles[charState.profile]
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

function HUD.ProfileCurrent() return charState and charState.profile or "Default" end

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
    charState.profile = name
    HUD.db = root.profiles[name]
    FillDefaults(HUD.db)
    HUD.UpdateEagleLabels()
    if active then HUD.Refresh() elseif HUD.Tracking then HUD.Tracking.Refresh() end
    if HUD.Config then HUD.Config.Refresh() end
    return created
end

function HUD.ProfileDelete(name)
    local root = HUD.root
    if name == charState.profile then return false, "that profile is in use" end
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
    if active then HUD.Refresh() elseif HUD.Tracking then HUD.Tracking.Refresh() end
    if HUD.Config then HUD.Config.Refresh() end
end

---------------------------------------------------------------------------
-- Minimap mask: remember what other addons set so we can restore it
---------------------------------------------------------------------------

local function SetMask(tex)
    settingMask = true
    Minimap:SetMaskTexture(tex)
    settingMask = false
end

-- Opacity is one of 11 mask textures (a00 ... a10). Changing it must touch NOTHING but the mask: the old code
-- ran the whole HUD apply (re-parent, re-anchor, re-size, zoom, overlay, pin layout) on every slider tick, so the
-- Minimap was rebuilt while its new mask was still loading, which is what made 0 -> max unstable.
local function ApplyMaskOnly()
    if not active or not HUD.db then return end
    local mask = MaskPath(HUD.Cfg().alpha)
    if appliedMask ~= mask then
        SetMask(mask)
        appliedMask = mask
    end
end

-- A slider can fire many times while it is dragged. Swapping the mask makes the Minimap reload its texture, so the
-- swap waits until the slider has been quiet for MASK_QUIET seconds and then applies only the last value.
local MASK_QUIET = 0.08
local maskQueuedAt = 0
local maskDriver = CreateFrame("Frame")
maskDriver:Hide()
maskDriver:SetScript("OnUpdate", function(self)
    if GetTime() - maskQueuedAt < MASK_QUIET then return end
    self:Hide()
    ApplyMaskOnly()
end)
local function QueueMask() maskQueuedAt = GetTime(); maskDriver:Show() end

-- Load every mask file once, up front, so swapping masks later never waits on the disk (a mask that is not
-- loaded yet leaves the Minimap with the wrong mask for a few frames: the "shadow").
local preloadFrame
local function PreloadMasks()
    if preloadFrame then return end
    preloadFrame = CreateFrame("Frame", nil, UIParent)
    preloadFrame:SetSize(1, 1)
    preloadFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    for step = 0, 10 do
        local t = preloadFrame:CreateTexture(nil, "BACKGROUND")
        t:SetSize(1, 1)
        t:SetPoint("BOTTOMLEFT")
        t:SetTexture(MaskPath(step / 10))
        t:SetAlpha(0.01)
    end
end
C_Timer.After(1, PreloadMasks)

-- GatherTimes loads before SexyMap (it is not in OptionalDeps), so this hook sees SexyMap's own mask calls.
hooksecurefunc(Minimap, "SetMaskTexture", function(_, tex)
    if settingMask then return end
    lastMask = tex
    if active and HUD.db then
        -- someone else changed the mask while the HUD is up: keep ours on screen
        local mask = MaskPath(HUD.Cfg().alpha)
        SetMask(mask)
        appliedMask = mask
    end
end)

---------------------------------------------------------------------------
-- Minimap takeover / restore (stock state is kept in memory only)
---------------------------------------------------------------------------

local function Snapshot()
    if orig then return end
    orig = {
        parent = Minimap:GetParent(), strata = Minimap:GetFrameStrata(), level = Minimap:GetFrameLevel(),
        width = Minimap:GetWidth(), height = Minimap:GetHeight(), scale = Minimap:GetScale(),
        alpha = Minimap:GetAlpha(), mouse = Minimap:IsMouseEnabled(), wheel = Minimap:IsMouseWheelEnabled(),
        zoom = Minimap:GetZoom(), rotate = GetCVar("rotateMinimap"), points = {},
    }
    for i = 1, Minimap:GetNumPoints() do orig.points[i] = { Minimap:GetPoint(i) } end
    -- Only the CVar value is persisted (so a crash can't leave rotateMinimap stuck); never frames.
    HUD.root.origRotate = orig.rotate
    if Minimap.GetMaskTexture then
        local m = Minimap:GetMaskTexture()
        if m then lastMask = m end
    end
end

-- Like the mask hook above: calls made while we are not the one setting the arrow come from another addon.
-- Only calls made after GatherTimes loaded are seen; with none seen, the stock arrow is restored as before.
if Minimap.SetPlayerTexture then
    hooksecurefunc(Minimap, "SetPlayerTexture", function(_, tex)
        if settingArrow then return end
        lastArrow = tex
    end)
end

local function SetArrow(tex)
    settingArrow = true
    pcall(Minimap.SetPlayerTexture, Minimap, tex)
    settingArrow = false
end

local function ApplyArrow(show)
    if not Minimap.SetPlayerTexture then return end
    if show and arrowHidden then
        SetArrow(lastArrow or STOCK_ARROW)
        arrowHidden = false
    elseif not show and not arrowHidden then
        SetArrow(BLANK_TEXTURE)
        arrowHidden = true
    end
end

-- While the Eagle map takes the mouse for the hover tooltips, the minimap's click handler (it pings the map and opens
-- the tracking menu) is swapped for a no-op, so a click only reaches the world underneath. Put back afterwards.
local savedMouseUp, mouseUpSwapped
local function NoMouseUp() end
local function SwapMouseUp(on)
    if on and not mouseUpSwapped then
        savedMouseUp = Minimap:GetScript("OnMouseUp")
        Minimap:SetScript("OnMouseUp", NoMouseUp)
        mouseUpSwapped = true
    elseif not on and mouseUpSwapped then
        mouseUpSwapped = false
        if Minimap:GetScript("OnMouseUp") == NoMouseUp then Minimap:SetScript("OnMouseUp", savedMouseUp) end
        savedMouseUp = nil
    end
end

-- The HUD map is as big as the screen, so whatever mouse state it has decides whether a press on the world starts
-- a camera drag. Off (normal HUD): it must not see the mouse at all. Hover (Eagle map): it only watches the mouse
-- MOVE (for the game's herb / ore tooltips) and ignores clicks, so a press always goes to the world. Clients that
-- cannot split the two keep the older "mouse on, clicks passed through" way.
local function CanHover()
    return (Minimap.SetMouseClickEnabled and Minimap.SetMouseMotionEnabled
            or Minimap.SetPropagateMouseClicks) and true or false
end
local function SetMinimapMouse(hover)
    Minimap:EnableMouse(hover)
    if Minimap.SetMouseClickEnabled and Minimap.SetMouseMotionEnabled then
        pcall(Minimap.SetMouseClickEnabled, Minimap, false)          -- never takes a press, in either state
        pcall(Minimap.SetMouseMotionEnabled, Minimap, hover)
    end
    SwapMouseUp(hover)
    if Minimap.SetPropagateMouseClicks then pcall(Minimap.SetPropagateMouseClicks, Minimap, hover) end
end
local function MinimapMouseMatches(hover)
    if Minimap.SetMouseMotionEnabled and Minimap.IsMouseMotionEnabled and Minimap.IsMouseClickEnabled then
        return (Minimap:IsMouseMotionEnabled() and true or false) == hover and not Minimap:IsMouseClickEnabled()
    end
    return (Minimap:IsMouseEnabled() and true or false) == hover
end

local function ConfigureMinimapInner(db)
    -- Mask first: the Minimap is about to become 800 px wide, and with the stock mask still on it for even one
    -- frame the whole stock circle shows (the shadow when the HUD is switched on).
    PreloadMasks()
    local mask = MaskPath(db.alpha)
    if appliedMask ~= mask then SetMask(mask); appliedMask = mask end
    Minimap:SetParent(UIParent)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", UIParent, "CENTER")
    Minimap:SetScale(1)
    local size = HUD.EffectiveSize(db)
    Minimap:SetSize(size, size)
    Minimap:SetFrameStrata("BACKGROUND")
    Minimap:SetFrameLevel(1)
    Minimap:SetAlpha(1)
    -- Mouse off: the full-screen HUD must not catch clicks. The Eagle map (hoverTips) turns it on again for the game's
    -- own hover tooltips on herb / ore blips, with clicks passed through to the world; a client that cannot pass
    -- clicks through keeps it off. Clicks do nothing on the map itself (SwapMouseUp).
    SetMinimapMouse(db.hoverTips and CanHover() and true or false)
    Minimap:EnableMouseWheel(false)
    if Minimap:GetZoom() ~= db.zoom then Minimap:SetZoom(db.zoom) end
    local rot = db.rotate and "1" or "0"
    if GetCVar("rotateMinimap") ~= rot then
        SetCVar("rotateMinimap", rot)
        if Minimap_UpdateRotationSetting then pcall(Minimap_UpdateRotationSetting) end
    end
    ApplyArrow(db.arrow)
end

local QueueReapply     -- defined below, once ApplyHud exists

-- `applying` tells the re-apply hooks (below) that these Minimap changes are ours. If another addon answered
-- one of them by re-anchoring the Minimap right away (its own hook ran inside ours), the hook ignored it, so
-- check the result and ask for another pass.
local function ConfigureMinimapForHUD(db)
    applying = true
    local ok, err = pcall(ConfigureMinimapInner, db)
    applying = false
    if not ok then error(err, 0) end
    local point, rel, relPoint, x, y = Minimap:GetPoint(1)
    if Minimap:GetParent() ~= UIParent or point ~= "CENTER" or rel ~= UIParent or relPoint ~= "CENTER"
       or math.abs(x or 0) > 0.5 or math.abs(y or 0) > 0.5 then
        QueueReapply()
    end
end

local function RestoreMinimapFromOrig()
    Minimap:SetParent(orig.parent)
    Minimap:ClearAllPoints()
    for _, p in ipairs(orig.points) do Minimap:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    Minimap:SetScale(orig.scale)
    Minimap:SetSize(orig.width, orig.height)
    Minimap:SetFrameStrata(orig.strata)
    Minimap:SetFrameLevel(orig.level)
    Minimap:SetAlpha(orig.alpha)
    SetMask(lastMask or STOCK_MASK)
    appliedMask = nil
    SwapMouseUp(false)
    if Minimap.SetPropagateMouseClicks then pcall(Minimap.SetPropagateMouseClicks, Minimap, false) end
    Minimap:EnableMouse(orig.mouse)
    if Minimap.SetMouseClickEnabled and Minimap.SetMouseMotionEnabled then       -- the stock minimap takes clicks and hover
        pcall(Minimap.SetMouseClickEnabled, Minimap, orig.mouse and true or false)
        pcall(Minimap.SetMouseMotionEnabled, Minimap, orig.mouse and true or false)
    end
    Minimap:EnableMouseWheel(orig.wheel)
    Minimap:SetZoom(orig.zoom)
    SetCVar("rotateMinimap", orig.rotate)
    if Minimap_UpdateRotationSetting then pcall(Minimap_UpdateRotationSetting) end
    ApplyArrow(true)
end

---------------------------------------------------------------------------
-- Apply / restore
---------------------------------------------------------------------------

-- Eagle Eye (hunter view): the camera turns away from the character, so the full-screen HUD dots would be drawn
-- in the wrong place. Matched by spell id, or by the localised name.
--   eagleMap on  (default): the HUD stays on and the map is drawn as the Eagle map (HUD.Cfg(): eagle* settings,
--                centred, no compass / readouts). The stock minimap is never restored in between, so nothing flickers.
--   eagleMap off: the old behaviour, the HUD is switched OFF (stock minimap restored) and back ON afterwards.
-- Remote views: Eagle Eye (hunter), Far Sight (shaman), Mind Vision (priest), Eyes of the Beast (hunter pet) and
-- Eye of Kilrogg (warlock) all move the camera away from the character, so they get the same map. Spell ids are
-- checked first, the localised name second (ranks that are not listed).
local VIEW_SPELLS = {
    [6197] = true,                                  -- Eagle Eye
    [6196] = true,                                  -- Far Sight
    [2096] = true, [10909] = true,                  -- Mind Vision
    [1002] = true,                                  -- Eyes of the Beast
    [126]  = true,                                  -- Eye of Kilrogg
}
local VIEW_CLASSES = { HUNTER = true, SHAMAN = true, PRIEST = true, WARLOCK = true }
local viewClass                                     -- nil = not looked up yet; true when the class has a remote view
local viewNames                                     -- localised names of VIEW_SPELLS (filled once the client knows them)
local seenActive = false                            -- a channel / aura check has found a remote view: it works here
local castUntil = 0                                 -- fallback: a cast of a view spell succeeded (see HUD.EagleCast)
local lastT, lastR                                  -- EagleEyeActive is answered once per frame

local function SpellName(id)
    if not GetSpellInfo then return nil end
    local ok, n = pcall(GetSpellInfo, id)
    if not ok then return nil end
    if type(n) == "table" then return n.name end
    return n
end

local function ViewClass()
    if viewClass == nil then
        viewClass = VIEW_CLASSES[select(2, UnitClass("player")) or ""] and true or false
    end
    return viewClass
end
function HUD.EagleClass() return ViewClass() end

local function IsViewSpell(id, name)
    if id and VIEW_SPELLS[id] then return true end
    if not name then return false end
    if not viewNames then
        local t, n = {}, 0
        for sid in pairs(VIEW_SPELLS) do
            local nm = SpellName(sid)
            if nm then t[nm] = true; n = n + 1 end
        end
        if n == 0 then return false end             -- spell info not ready yet: look again next time
        viewNames = t
    end
    return viewNames[name] and true or false
end

-- A buff on the player. One lookup per spell id; clients without the by-id call scan the buffs instead.
local function ViewAura()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for id in pairs(VIEW_SPELLS) do
            local ok, d = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if ok and d then return true end
        end
        return false
    end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
    for i = 1, 40 do
        local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not d then break end
        if IsViewSpell(d.spellId, d.name) then return true end
    end
    return false
end

-- Eagle Eye is a channelled spell on Classic Era, so it is looked for as a channel first and as a buff second.
local function ViewActive(now)
    if not ViewClass() then return false end
    if UnitChannelInfo then
        local ok, cname, _, _, _, _, _, _, cid = pcall(UnitChannelInfo, "player")
        if ok and cname and IsViewSpell(cid, cname) then seenActive = true; return true end
    end
    if ViewAura() then seenActive = true; return true end
    -- Last resort, only on a client where neither check has ever found a remote view: trust the cast for up to 60 s
    return (not seenActive) and castUntil > now
end

function HUD.EagleEyeActive()
    local now = GetTime()
    if lastT == now then return lastR end
    lastT = now
    lastR = ViewActive(now) and true or false
    return lastR
end

-- A cast of a view spell succeeded / the channel ended (UNIT_SPELLCAST_SUCCEEDED, _INTERRUPTED, _CHANNEL_STOP).
function HUD.EagleInvalidate() lastT = nil end
function HUD.EagleCast(spellID)
    lastT = nil
    if spellID and VIEW_SPELLS[spellID] then castUntil = GetTime() + 60 end
end
function HUD.EagleCastIsView(id) return VIEW_SPELLS[id] and true or false end
function HUD.EagleCastEnd() lastT = nil; castUntil = 0 end

-- Legacy mode (eagleMap off): while Eagle Eye is on the HUD is switched OFF and it is switched on again when
-- Eagle Eye ends. A HUD the player turns on/off by hand during Eagle Eye cancels the automatic switch-back.
local eagleSuspended, eagleWasAuto, eagleBusy, eagleAcc = false, false, false, 0
function HUD.EagleSuspended() return eagleSuspended end

function HUD.EagleCheck()
    local db = HUD.db
    if not db then return end
    local eagle = HUD.EagleEyeActive()
    if db.eagleMap then
        if eagleSuspended then
            -- the option was switched on during a legacy suspension: bring the HUD back first
            eagleSuspended = false
            eagleBusy = true
            HUD.SetEnabled(true, eagleWasAuto)
            eagleBusy = false
        end
        local want = (eagle or eaglePreview) and active
        if want ~= eagleMode then
            eagleMode = want
            eagleSizeStep = 1                         -- the "next size" key starts from the saved size each time
            if active then HUD.Refresh(true) end      -- same Minimap, new size / mask / zoom / rotation, in one pass
            HUD.UpdateEagleLabels()
        end
        return
    end
    if eagleMode then                                  -- option switched off while the Eagle map was up
        eagleMode = false
        eagleSizeStep = 1
        if active then HUD.Refresh(true) end
        HUD.UpdateEagleLabels()
    end
    if eagle and active and not eagleSuspended then
        eagleSuspended, eagleWasAuto = true, autoEnabled
        eagleBusy = true
        HUD.SetEnabled(false)
        eagleBusy = false
    elseif not eagle and eagleSuspended then
        eagleSuspended = false
        eagleBusy = true
        HUD.SetEnabled(true, eagleWasAuto)
        eagleBusy = false
    end
end

-- Settings panel / slash: hold the Eagle map up without casting Eagle Eye, to set it up. Needs the HUD on.
function HUD.EaglePreview(state)
    if state == nil then state = not eaglePreview end
    eaglePreview = state and true or false
    if eaglePreview and not (active and HUD.db and HUD.db.eagleMap) then
        eaglePreview = false
        return false
    end
    HUD.EagleCheck()
    return eaglePreview
end
function HUD.EaglePreviewing() return eaglePreview end

-- Zoom in (+1) / out (-1) while the Eagle map is up: the key bindings. This is the
-- Eagle zoom setting itself, so it is kept for the next Eagle Eye.
function HUD.EagleZoom(delta)
    if not (HUD.db and active and eagleMode) then return end
    local key = HUD.db.eagleSync and "zoom" or "eagleZoom"      -- synced: the key changes the HUD's own zoom
    local z = Clamp(HUD.db[key] + delta, HUD.LIMITS.zoom[1], HUD.LIMITS.zoom[2])
    if z == HUD.db[key] then return end
    HUD.Set(key, z)
    if HUD.Config then HUD.Config.Refresh() end
end

-- Next size: the saved size, a bigger one, a smaller one, and round again. Only for this view, nothing is saved.
function HUD.EagleNextSize()
    if not (HUD.db and active and eagleMode) then return end
    eagleSizeStep = eagleSizeStep % #EAGLE_SIZE_STEPS + 1
    HUD.Refresh(true)
end

-- polled while the Eagle map is up (or the HUD is suspended) in case the "channel stopped" event was missed
-- (e.g. a loading screen)
function HUD.EagleTick(dt)
    if not (eagleSuspended or eagleMode) then eagleAcc = 0; return end
    eagleAcc = eagleAcc + (dt or 0)
    if eagleAcc < 0.5 then return end
    eagleAcc = 0
    HUD.EagleCheck()
end

-- hidden while mounted (option); in legacy mode also while Eagle Eye is on, before the HUD is switched off
local function Faded()
    local db = HUD.db
    if db.mountFade and IsMounted and IsMounted() then return true end
    return (not db.eagleMap) and HUD.EagleEyeActive() or false
end
HUD.Faded = Faded

function HUD.UpdateVisibility()
    if not active then return end
    local faded = Faded()
    Minimap:SetAlpha(faded and 0 or 1)
    if HUD.Overlay then HUD.Overlay.SetShown(not faded) end
end

-- light = true skips the (slower) frame hiding and tracking passes; used while dragging sliders.
local function ApplyHudInner(light)
    local db = HUD.Cfg()
    local wasActive = active
    active = true
    if not wasActive then HUD.UpdateEagleLabels() end      -- Gx / (G) labels show while the HUD is on
    Snapshot()
    ConfigureMinimapForHUD(db)
    if light then
        if HUD.HideClockFrames then HUD.HideClockFrames() end
        HUD.Tracking.Place()
    else
        HUD.HideDecorations()
        HUD.HideStockTracking()
        HUD.Tracking.Update()
    end
    HUD.Overlay.Update()
    HUD.UpdateVisibility()
    HUD.RefreshPins()
end

local RestoreHud        -- defined just below

-- The Minimap's mouse state is ours to decide: off for the full-screen HUD, on (clicks passed through) for the Eagle
-- map. Something else (the game, another addon) can switch it back on when the Eagle map goes away, so it is
-- looked at twice a second and put right.
local mouseAcc = 0
function HUD.MouseTick(dt)
    if not (active and orig) then mouseAcc = 0; return end
    mouseAcc = mouseAcc + (dt or 0)
    if mouseAcc < 0.5 then return end
    mouseAcc = 0
    local want = HUD.Cfg().hoverTips and CanHover() and true or false
    if MinimapMouseMatches(want) then return end
    applying = true
    SetMinimapMouse(want)
    applying = false
end

-- Right away, not at the next half-second check: when the game or another addon switches the Minimap's mouse back on
-- (or its clicks) while the HUD is up, a press on the world would be taken by the full-screen map and the camera
-- would not turn until the check ran. The hooks put it right on the next frame.
local mouseFixQueued = false
local function QueueMouseFix()
    if mouseFixQueued or applying or not (active and orig) then return end
    mouseFixQueued = true
    C_Timer.After(0, function()
        mouseFixQueued = false
        if not (active and orig and HUD.db) then return end
        local want = HUD.Cfg().hoverTips and CanHover() and true or false
        if MinimapMouseMatches(want) then return end
        applying = true
        pcall(SetMinimapMouse, want)
        applying = false
    end)
end
for _, fn in ipairs({ "EnableMouse", "SetMouseClickEnabled", "SetMouseMotionEnabled", "SetPropagateMouseClicks" }) do
    if Minimap[fn] then pcall(hooksecurefunc, Minimap, fn, QueueMouseFix) end
end

-- An error half-way through must not leave the HUD half applied and unreported: report it, and if this call was
-- the one switching the HUD on, switch it back off so the stock minimap is restored.
local function ApplyHud(light)
    local wasActive = active
    local ok, err = pcall(ApplyHudInner, light)
    if ok then return end
    GT.ReportError("HUD apply", err)
    if not wasActive then pcall(RestoreHud) end
end

function RestoreHud()
    if not active then return end
    active = false
    eagleMode, eaglePreview, eagleSizeStep = false, false, 1
    HUD.UpdateEagleLabels()
    HUD.Overlay.Hide()
    HUD.Tracking.Hide()
    if orig then RestoreMinimapFromOrig(); orig = nil end
    HUD.ShowDecorations()
    HUD.ReleaseStockTracking()
    HUD.root.origRotate = nil
    -- HUD off: show the HUD's own button or keep Blizzard's visible, depending on /gthud trackmode
    HUD.Tracking.Refresh()
    HUD.RefreshPins()
end

local function Enforce()
    if active then ApplyHud() end
end

---------------------------------------------------------------------------
-- Keep the HUD in place when another minimap addon moves/resizes the Minimap
---------------------------------------------------------------------------

-- SexyMap (shape/preset changes), Chinchilla, ElvUI/Tukui (UI scale, movers), BasicMinimap ... re-anchor or
-- resize the Minimap from their own code. A short debounce re-applies the HUD geometry after they are done.
-- Two addons fighting over the Minimap would loop forever, so after a burst of triggers we back off.
local enforceQueued = false
local burstStart, burstCount, pausedUntil = 0, 0, 0
local warnedFight = false          -- chat notice about a minimap fight is printed once per session

function QueueReapply()
    if not active or applying or enforceQueued then return end
    local now = GetTime()
    if now < pausedUntil then return end
    if now - burstStart > 3 then burstStart, burstCount = now, 0 end
    burstCount = burstCount + 1
    if burstCount > 8 then
        pausedUntil = now + 10
        Debug("another addon keeps moving the Minimap; pausing re-apply for 10s")
        -- one re-apply when the pause ends, so the HUD is not left where the other addon put the Minimap
        C_Timer.After(10.1, function()
            if active and not applying then ApplyHud(true) end
        end)
        if not warnedFight then
            warnedFight = true
            Print("another addon keeps moving the minimap. The HUD will re-apply every 10s; "
                .. "if it looks displaced, check minimap addons (SexyMap, ElvUI, Chinchilla, BasicMinimap).")
        end
        return
    end
    enforceQueued = true
    C_Timer.After(0.1, function()
        enforceQueued = false
        if active then ApplyHud(true) end
    end)
end

for _, method in ipairs({ "SetParent", "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale" }) do
    if Minimap[method] then hooksecurefunc(Minimap, method, QueueReapply) end
end

function HUD.Refresh(light)
    if active then ApplyHud(light) end
end

local autoSuppressed = false         -- the player turned the HUD off by hand: auto-gather stays quiet until tracking changes
function HUD.AutoSuppressed() return autoSuppressed end
function HUD.ClearAutoSuppress() autoSuppressed = false end

-- Preview (the settings panel's "Preview HUD" button): turns the HUD on while the panel is open, even when it is off.
-- Not saved.  The preview only undoes itself: it never switches off a HUD the player turned on.
local hudPreview = false
function HUD.Previewing() return hudPreview end
function HUD.Preview(state)
    state = state and true or false
    if state == hudPreview then return hudPreview end
    if state then
        if HUD.db and not active then
            ApplyHud()
            hudPreview = active and true or false
        end
    else
        hudPreview = false
        if active then RestoreHud() end
    end
    if GT.RefreshHudButton then GT.RefreshHudButton() end
    if HUD.Config then HUD.Config.Refresh() end
    return hudPreview
end

function HUD.SetEnabled(state, auto)
    state = state and true or false
    if not auto then hudPreview = false end          -- the player switched the HUD by hand: the preview is over
    if not eagleBusy then eagleSuspended = false end     -- a manual / auto toggle ends the Eagle Eye suspension
    if not auto and not eagleBusy then
        autoSuppressed = not state                       -- manual off: do not let auto-gather switch it straight back on
        if state and active then autoEnabled = false end -- manual "on" while auto-enabled: the player owns it now
    end
    if state == active then return end
    autoEnabled = (auto and state) and true or false
    if state then ApplyHud() else RestoreHud() end
    -- HUD switched on in the middle of Eagle Eye: go straight to the Eagle map
    if state and active and not eagleBusy and HUD.db.eagleMap then HUD.EagleCheck() end
    if HUD.Config then HUD.Config.Refresh() end
    if GT.RefreshHudButton then GT.RefreshHudButton() end       -- the HUD button in the main window
end

function HUD.Toggle()
    if HUD.db then HUD.SetEnabled(not active) end
end

-- Single entry point for changing a profile setting (slash, options panel)
function HUD.Set(key, value, fromUI)
    HUD.db[key] = value
    if key == "alpha" or (key == "eagleAlpha" and eagleMode) then
        if active then QueueMask() end       -- mask swap only, see ApplyMaskOnly
    elseif key == "eagleMap" then
        if not value and eaglePreview then eaglePreview = false end
        HUD.EagleCheck()
    elseif key == "eagleHideLabels" or key == "hideLabelsIdle" then
        HUD.UpdateEagleLabels()
    elseif EAGLE_KEYS[key] then
        if active and eagleMode then HUD.Refresh(true) end
    elseif OVERLAY_KEYS[key] then
        if active then HUD.Overlay.Update() end
    elseif MAP_KEYS[key] then
        HUD.Refresh(true)       -- ApplyHud runs Overlay.Update in the light path too, so a size change needs nothing more
    elseif TRACK_KEYS[key] then
        HUD.Tracking.Place()
    elseif key == "autoGather" then
        HUD.CheckAutoGather()
    elseif key == "trackIdle" then
        if not active then
            if not HUD.UseOwnIdle() then
                -- handing the button back to Blizzard: let it show itself again
                for _, f in ipairs(HUD.StockTrackingFrames()) do
                    if type(f.UpdateState) == "function" then pcall(f.UpdateState, f) end
                end
                if type(_G.MiniMapTracking_Update) == "function" then pcall(_G.MiniMapTracking_Update) end
            end
            HUD.Tracking.Refresh()
        end
    else
        HUD.Refresh()          -- tracking, hideAddons
        if not active and key == "tracking" then HUD.Tracking.Refresh() end
    end
    if HUD.Config and not fromUI then HUD.Config.Refresh() end
end

function HUD.SetRoot(key, value)
    HUD.root[key] = value
    if key == "deepScan" and active then HUD.Refresh() end
end

---------------------------------------------------------------------------
-- Lifecycle: driven by GatherTimes (Events.lua)
---------------------------------------------------------------------------

local ldbCallbackOwner = {}
local ldbRegistered = false
local function RegisterLDBIconCallback()
    if ldbRegistered then return end
    local ok, ldbi = pcall(LibStub, "LibDBIcon-1.0", true)
    if ok and ldbi and ldbi.RegisterCallback then
        ldbRegistered = pcall(ldbi.RegisterCallback, ldbCallbackOwner, "LibDBIcon_IconCreated", function()
            HUD.InvalidateAddonCache()
            if active then HUD.ScheduleRehide() end
        end)
    end
end

-- Called once by GatherTimes on its own ADDON_LOADED, after GT.SanitizeDB().
function HUD.Init()
    InitDB()
    if HUD.Config and HUD.Config.Init then
        local ok, err = pcall(HUD.Config.Init)
        if not ok then GT.cprint("HUD settings window failed to build: " .. tostring(err)) end
    end
end

-- Forwarded by Events.lua: ADDON_LOADED (other addons only), PLAYER_ENTERING_WORLD, PLAYER_LOGOUT,
-- MINIMAP_UPDATE_TRACKING, PLAYER_MOUNT_DISPLAY_CHANGED, UNIT_AURA, UNIT_SPELLCAST_* (player).
function HUD.OnEvent(event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        -- another addon loaded: it may have created minimap buttons
        HUD.InvalidateAddonCache()
        if active then HUD.ScheduleRehide() end
        return
    end
    if not HUD.db then return end

    if event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = arg1, arg2
        local justEnabled = false
        if isLogin or isReload then
            RegisterLDBIconCallback()
            if HUD.root.restoreOnLogin and charState.wasActive then
                charState.wasActive = false
                HUD.SetEnabled(true)
                justEnabled = true
            end
        end
        if active and not justEnabled then
            ApplyHud()                      -- minimap can be reset by the loading screen
            C_Timer.After(2, Enforce)
        end
        HUD.CheckAutoGather()
        if not active then C_Timer.After(1, HUD.Tracking.Refresh) end

    elseif event == "MINIMAP_UPDATE_TRACKING" then
        HUD.Tracking.Refresh()
        HUD.CheckAutoGather()

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if not (arg3 and HUD.EagleClass() and HUD.EagleCastIsView(arg3)) then return end   -- any other spell: nothing to do
            HUD.EagleCast(arg3)
        elseif event ~= "UNIT_SPELLCAST_CHANNEL_START" then
            HUD.EagleCastEnd()
        else
            HUD.EagleInvalidate()                       -- drop the per-frame answer
        end
        HUD.EagleCheck()
        C_Timer.After(0.2, HUD.EagleCheck)              -- channel info can lag the event by a moment

    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "UNIT_AURA" then
        if event == "UNIT_AURA" and HUD.EagleClass() then HUD.EagleInvalidate(); HUD.EagleCheck() end   -- other classes have no remote view
        if active then HUD.UpdateVisibility() end       -- mounts (if the option is on)

    elseif event == "PLAYER_LOGOUT" then
        if charState then charState.wasActive = active or eagleSuspended end
        if active and orig then
            -- the CVar and zoom outlive the UI session; put them back
            pcall(SetCVar, "rotateMinimap", orig.rotate)
            pcall(Minimap.SetZoom, Minimap, orig.zoom)
            HUD.root.origRotate = nil
        end
    end
end

-- Called by Events.lua from GatherTimes' update loop on every frame. Each part is isolated so one failure
-- is reported once instead of every frame.
-- A part that errors is paused for 5 seconds and then tried again (a transient nil must not disable the compass
-- until /reload). The error is reported once per outage, not on every retry.
local pausedUntil, reported = {}, {}
local function Guard(name, fn, ...)
    local until_ = pausedUntil[name]
    if until_ and GetTime() < until_ then return end
    local ok, err = pcall(fn, ...)
    if ok then
        pausedUntil[name], reported[name] = nil, nil
    else
        pausedUntil[name] = GetTime() + 5
        if not reported[name] then
            reported[name] = true
            GT.ReportError("HUD " .. name, err)
        end
    end
end

function HUD.OnUpdate(dt)
    if not HUD.db then return end
    Guard("eagle", HUD.EagleTick, dt)                      -- switch the HUD back on after Eagle Eye (0.5 s)
    Guard("mouse", HUD.MouseTick, dt)                      -- keeps the Minimap's mouse state right (0.5 s)
    Guard("overlay", HUD.Overlay.OnUpdate, dt)             -- compass letters / heading (every 0.03 s)
    Guard("tracking", HUD.Tracking.OnUpdate)               -- dragging the tracking button
    Guard("watcher", HUD.WatcherTick, dt)                      -- keeps the stock tracking button right (0.1 s)
    Guard("skins", HUD.SkinSweep, dt)                          -- hides minimap skin frames SexyMap adds later (0.5 s)
end
