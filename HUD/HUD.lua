-- HUD.lua : the built-in minimap HUD module of GatherTimes.
--
-- Gathering overlay for WoW Classic Era (Interface 11509): minimap takeover + restore, mask selection
-- (Masks\a00.tga, the blank mask), player arrow, rings, compass letters, heading readout, the HUD's own tracking
-- button, and the refresh of the node pins (GatherTimes timers / spawn spots, GatherMate2, TomTom) that
-- live on the Minimap.
--
-- File layout (HUD\, loaded in this order by GatherTimes.toc; all files share one table, GT.HUD):
--   HUD.lua            this file, the core: constants, defaults, helpers, the shared state table HUD.S, HUD.Cfg
--   HUDProfiles.lua    saved variables (GatherTimesDB.hud) and the profiles
--   HUDMinimap.lua     minimap mask, takeover / restore, player arrow, mouse state, ping marker
--   HUDEagle.lua       Eagle Eye / remote-view detection, the Eagle map switch, preview, zoom and size keys
--   HUDApply.lua       applying and restoring the HUD, keeping it in place against other minimap addons
--   HUDSet.lua         Preview, SetEnabled / Toggle and HUD.Set (the one entry point for settings)
--   HUDLifecycle.lua   HUD.Init / OnEvent / OnUpdate (called by Events.lua)
--   HUDFrames.lua      hiding minimap decorations and addon skins / buttons, and the stock tracking button
--   HUDPins.lua        asks the node pins on the minimap to lay themselves out again
--   HUDAutoGather.lua  switches the HUD on while Find Herbs / Minerals / Treasure is active
--   HUDOverlay.lua     rings, compass letters, heading readout
--   HUDTracking.lua    the HUD's own tracking button
--   HUDSlash.lua       /gthud commands and the status / info output
--   HUDConfig.lua      the HUD settings panel
-- Runtime state that other files need is reached through HUD.* functions (HUD.IsActive(), HUD.OrigWidth(),
-- HUD.WasAutoEnabled() ...), never by sharing locals: a file-level `local` is private to its file.
-- The files split out of this one share their runtime values in the table HUD.S (local S = HUD.S) and their
-- internal functions in HUD.I; neither is part of the public HUD.* API.
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
BINDING_NAME_GATHERTIMES_HUD_TOGGLE = GT.TR("Toggle HUD")
BINDING_NAME_GATHERTIMES_EAGLE_ZOOM_IN = GT.TR("Eagle map: zoom in")
BINDING_NAME_GATHERTIMES_EAGLE_ZOOM_OUT = GT.TR("Eagle map: zoom out")
BINDING_NAME_GATHERTIMES_EAGLE_SIZE = GT.TR("Eagle map: next size")

---------------------------------------------------------------------------
-- Constants and defaults
---------------------------------------------------------------------------

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
    arrowScale    = 100,           -- player arrow size in %; 100 = the game's own arrow, anything else = the addon's arrow
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
    eagleScale    = true,          -- distance scale: the edge of the map and a half-way ring, labelled in yards
    eagleNearest  = true,          -- readout of the nearest known node (name, ready / time left, yards) while it is up
    hideLabelsIdle = true,         -- hide the Gx labels and (G) timers on the normal minimap; they show while the HUD is on
    eagleHideLabels = true,        -- hide the Gx group labels and the (G) timers on the map while the Eagle map is up
    eagleHideLayer = false,        -- hide the layer info (e.g. NovaWorldBuffs "Layer 1") on the Eagle map
    eagleHover    = true,          -- the Eagle map takes the mouse (clicks pass through) so the game's herb / ore hover tooltips work
    hudHover      = false,         -- the normal HUD map also shows the game's herb / ore hover tooltips (off: it ignores the mouse)
}


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

local S = {
    active = false,                  -- the HUD is on
    autoEnabled = false,             -- HUD was switched on by autoGather
    orig = nil,                      -- snapshot of the stock minimap
    applying = false,                -- true while WE move the minimap (ignored by the re-apply hooks)
    eagleMode = false,               -- the Eagle Eye map is up (HUD on, drawn with the eagle* settings)
    eaglePreview = false,            -- the settings panel's Preview button holds the Eagle map up without Eagle Eye
    eagleSizeStep = 1,               -- which of EAGLE_SIZE_STEPS the "next size" key is on
    charState = nil,                 -- GatherTimesDB.hud.chars[charKey]
    eagleSuspended = false,          -- legacy Eagle Eye mode: the HUD is switched off for now
    eagleBusy = false,               -- HUD.SetEnabled is being called by the Eagle code itself
}
HUD.S = S          -- the runtime state shared by all HUD files (never saved)
HUD.I = {}         -- internal functions shared between the HUD files (not part of the public HUD.* API)
local EAGLE_SIZE_STEPS = { 1, 1.5, 0.65 }   -- the "next size" key: the saved size, then bigger, then smaller (this view only)
HUD.EAGLE_SIZE_STEPS = EAGLE_SIZE_STEPS
function HUD.EagleSizeMul() return EAGLE_SIZE_STEPS[S.eagleSizeStep] or 1 end


function HUD.IsActive() return S.active end
function HUD.WasAutoEnabled() return S.autoEnabled end      -- (HUDAutoGather.lua)
function HUD.OrigWidth() return S.orig and S.orig.width end   -- stock minimap width while the HUD is up (HUDFrames.lua)

-- The settings the map is drawn with right now: the profile, or - while the Eagle Eye map is up - the profile with
-- the eagle* values laid over it. Everything that draws the map or the overlay reads this, never HUD.db directly;
-- the profile itself is never changed by Eagle Eye.
local eagleView = setmetatable({}, { __index = function(_, k) return HUD.db and HUD.db[k] end })
-- Performance level (account-wide, HUD options, "Performance" tab):
--   0 Full      normal speed and saved ring detail; while the active HUD shows Eagle Eye, use HUD rings on the Eagle map
--   1 Balanced  the Eagle map stays, its own rings are hidden and the HUD's rings are used instead; rings are capped at PERF_MAX_SEGMENTS pieces;
--               the update loops run slower; deep scan is off
--   2 Lowest    no rings, no Eagle map (the names still show during Eagle Eye); slowest loops; deep scan is off
-- The levels are views over the profile, so the saved ring values are never changed: back on Full they return.
local PERF_MAX_SEGMENTS = 48
local PERF_TICK  = { [0] = 1, 3, 4 }      -- compass letters / heading (base 0.03 s) and the player arrow (Lowest 0.12 s: still smooth enough to read)
local PERF_SLOW  = { [0] = 1, 2, 3 }      -- readouts, ring radius check, watcher, skin sweep (their own base times)
local PERF_TIMER = { [0] = 1, 1, 2 }      -- the once-a-second timer refresh
HUD.PERF_LEVELS = { [0] = "Full", "Balanced", "Lowest" }

function HUD.PerfLevel()
    local l = HUD.root and tonumber(HUD.root.perfLevel) or 0
    return (l == 1 or l == 2) and l or 0
end
function HUD.PerfTick() return PERF_TICK[HUD.PerfLevel()] end
function HUD.PerfSlow() return PERF_SLOW[HUD.PerfLevel()] end
function HUD.PerfTimerStep()
    if not S.active then return 1 end            -- HUD off: the main timer window keeps its normal speed
    return PERF_TIMER[HUD.PerfLevel()]
end
function HUD.LowSpec() return HUD.PerfLevel() == 2 end          -- Lowest (kept for the Eagle / mouse code)

local lowView = setmetatable({ ring = 0, ring2 = 0, ringYd = 0, ring2Yd = 0 }, {
    __index = function(_, k) return HUD.db and HUD.db[k] end,
})
local balView = setmetatable({}, {
    __index = function(_, k)
        local db = HUD.db
        if not db then return nil end
        if k == "ringSegments" then return math.min(db.ringSegments or PERF_MAX_SEGMENTS, PERF_MAX_SEGMENTS) end
        return db[k]
    end,
})

function HUD.Cfg()
    local db = HUD.db
    if not (S.eagleMode and db) then
        if db and HUD.LowSpec() then return lowView end
        if db and HUD.PerfLevel() == 1 then return balView end
        return db
    end
    local v = eagleView
    v.size = math.floor(db.eagleSize * HUD.EagleSizeMul() + 0.5)
    v.alpha, v.rotate = db.eagleAlpha, db.eagleRotate
    v.arrow = false                             -- the player arrow is hidden while the Eagle map is up; the normal setting returns after
    local edge = math.max(0, math.floor(HUD.EffectiveSize(v) / 2) - 2)
    v.hoverTips = db.eagleHover and true or false   -- (ConfigureMinimapInner)
    v.zoom = db.eagleZoom
    v.ring = 0                                      -- no standalone Eagle-edge ring; scale labels still mark the map edge
    v.ringUnit = "px"                               -- the Eagle distance scale uses fixed map positions, in pixels ...
    v.scaleCaps = db.eagleScale and true or false   -- ... and are captioned with the yards they stand for (HUDOverlay.lua)
    v.ring2 = db.eagleScale and math.floor(edge / 2) or 0      -- half-way ring of the distance scale
    v.ringYd, v.ring2Yd = db.ringYd, db.ring2Yd
    -- Full and Balanced use the HUD's rings on the active Eagle map, hiding Eagle-specific rings and scale rings.
    -- Balanced additionally caps ring segments and slows the update loops.
    local perf = HUD.PerfLevel()
    local bal = perf == 1
    local useHudRings = bal or (perf == 0 and S.active)
    v.ringSegments = math.min(db.ringSegments or PERF_MAX_SEGMENTS, bal and PERF_MAX_SEGMENTS or 256)
    if useHudRings then
        local k = HUD.EffectiveSize(v) / HUD.EffectiveSize(db)
        v.ringUnit = db.ringUnit
        v.ring  = math.min(edge, math.floor(db.ring * k + 0.5))
        v.ring2 = math.min(edge, math.floor(db.ring2 * k + 0.5))
        v.ringYd, v.ring2Yd = db.ringYd, db.ring2Yd
        v.scaleCaps = false
    end
    v.dirs, v.heading, v.routeReadout = false, false, false
    v.priorityReadout = db.eagleNearest and true or false      -- nearest node: the same readout the normal HUD has
    return v
end
function HUD.EagleMapUp() return S.eagleMode end

-- Gx labels and (G) timers on the minimap: hidden (alpha 0, so the pin library's own Show / Hide is not fought)
-- while the Eagle map is up and "eagleHideLabels" is on. Read by Pins.lua / TextTimers.lua when a frame is made or
-- shown; HUD.UpdateEagleLabels() re-applies it to every frame that already exists.
function HUD.MiniLabelAlpha()
    local db = HUD.db
    if not db then return 1 end
    if not S.active then return db.hideLabelsIdle and 0 or 1 end      -- normal minimap
    return (S.eagleMode and db.eagleHideLabels) and 0 or 1
end
function HUD.UpdateEagleLabels()
    if GT.RefreshMiniLabelAlpha then pcall(GT.RefreshMiniLabelAlpha) end
    if HUD.HideLayerText then pcall(HUD.HideLayerText, true) end      -- layer text: hidden / restored with the Eagle map
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


-- shared with the other HUD files (they load after this one)
HUD.Debug, HUD.CopyAny, HUD.MaskPath = Debug, CopyAny, MaskPath
HUD.BLANK_TEXTURE, HUD.STOCK_MASK, HUD.STOCK_ARROW = BLANK_TEXTURE, STOCK_MASK, STOCK_ARROW
