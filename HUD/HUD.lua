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
--   HUDMover.lua       the /gthud unlock drag handle
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

---------------------------------------------------------------------------
-- Constants and defaults
---------------------------------------------------------------------------

local DB_VERSION     = 1                -- GatherTimesDB.hud layout version
local MINIMAP_BASE_SIZE = 140            -- stock minimap diameter (fallback only)
local STOCK_MASK     = "Textures\\MinimapMask"
local STOCK_ARROW    = "Interface\\Minimap\\MinimapArrow"
HUD.MINIMAP_BASE_SIZE = MINIMAP_BASE_SIZE   -- (HUDFrames.lua)

HUD.LIMITS = {
    size = { 150, 1400 },
    ring = { 0, 700 },
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
    x             = 0,
    y             = 0,
    zoom          = 0,
    rotate        = true,
    arrow         = true,          -- show the player arrow
    dirs          = false,         -- N/E/S/W letters
    heading       = false,         -- heading readout (e.g. "NE 45")
    priorityReadout = true,         -- nearest ready node, or nearest respawn timer
    routeReadout  = true,          -- current step of a planned route
    ring          = 179,           -- ring radius in px, 0 = off
    ring2         = 0,             -- optional second ring radius, 0 = off
    ringColor     = { 1, 1, 1, 0.6 },
    ringColor2    = { 1, 1, 1, 0.6 },   -- colour of the second ring
    ringThickness = 2,
    ringSegments  = 96,
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
}

-- Which setting changes need which kind of refresh
local OVERLAY_KEYS = { ring = true, ring2 = true, ringColor = true, ringColor2 = true,
                       ringThickness = true,
                       ringSegments = true, ringStyle = true, ringDensity = true, dirs = true, heading = true,
                       priorityReadout = true, routeReadout = true }
local MAP_KEYS     = { size = true, alpha = true, x = true, y = true, zoom = true,
                       rotate = true, arrow = true, mountFade = true }
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
HUD.Debug = Debug

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function Round(v) return math.floor(v + 0.5) end
HUD.Clamp, HUD.Round = Clamp, Round

local function CopyAny(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyAny(x) end
    return t
end
HUD.CopyAny = CopyAny

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
local applying = false              -- true while WE move the minimap (ignored by the re-apply hooks)
local charState                     -- GatherTimesDB.hud.chars[charKey]

function HUD.IsActive() return active end
function HUD.WasAutoEnabled() return autoEnabled end      -- (HUDAutoGather.lua)
function HUD.OrigWidth() return orig and orig.width end   -- stock minimap width while the HUD is up (HUDFrames.lua)

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
    p.size = Clamp(p.size, L.size[1], L.size[2])
    p.alpha = Clamp(p.alpha, 0, 1)
    p.zoom = Clamp(Round(p.zoom), L.zoom[1], L.zoom[2])
    p.ring = Clamp(p.ring, L.ring[1], L.ring[2])
    p.ring2 = Clamp(p.ring2, L.ring[1], L.ring[2])
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
    root.ver = DB_VERSION

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
    local mask = MaskPath(HUD.db.alpha)
    if appliedMask ~= mask then
        SetMask(mask)
        appliedMask = mask
    end
end

-- A slider can fire several times in one frame while it is dragged: apply only the last value, once per frame.
local maskDriver = CreateFrame("Frame")
maskDriver:Hide()
maskDriver:SetScript("OnUpdate", function(self)
    self:Hide()
    ApplyMaskOnly()
end)
local function QueueMask() maskDriver:Show() end

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
        local mask = MaskPath(HUD.db.alpha)
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

local function ApplyArrow(show)
    if not Minimap.SetPlayerTexture then return end
    if show and arrowHidden then
        pcall(Minimap.SetPlayerTexture, Minimap, STOCK_ARROW)
        arrowHidden = false
    elseif not show and not arrowHidden then
        pcall(Minimap.SetPlayerTexture, Minimap, BLANK_TEXTURE)
        arrowHidden = true
    end
end

local function ConfigureMinimapInner(db)
    -- Mask first: the Minimap is about to become 800 px wide, and with the stock mask still on it for even one
    -- frame the whole stock circle shows (the shadow when the HUD is switched on).
    PreloadMasks()
    local mask = MaskPath(db.alpha)
    if appliedMask ~= mask then SetMask(mask); appliedMask = mask end
    Minimap:SetParent(UIParent)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    Minimap:SetScale(1)
    Minimap:SetSize(db.size, db.size)
    Minimap:SetFrameStrata("BACKGROUND")
    Minimap:SetFrameLevel(1)
    Minimap:SetAlpha(1)
    Minimap:EnableMouse(false)
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
       or math.abs((x or 0) - db.x) > 0.5 or math.abs((y or 0) - db.y) > 0.5 then
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
    Minimap:EnableMouse(orig.mouse)
    Minimap:EnableMouseWheel(orig.wheel)
    Minimap:SetZoom(orig.zoom)
    SetCVar("rotateMinimap", orig.rotate)
    if Minimap_UpdateRotationSetting then pcall(Minimap_UpdateRotationSetting) end
    ApplyArrow(true)
end

---------------------------------------------------------------------------
-- Apply / restore
---------------------------------------------------------------------------

function HUD.UpdateVisibility()
    if not active then return end
    local faded = HUD.db.mountFade and IsMounted and IsMounted()
    Minimap:SetAlpha(faded and 0 or 1)
    if HUD.Overlay then HUD.Overlay.SetShown(not faded) end
end

-- light = true skips the (slower) frame hiding and tracking passes; used while dragging sliders.
local function ApplyHud(light)
    local db = HUD.db
    active = true
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

local function RestoreHud()
    if not active then return end
    active = false
    HUD.Overlay.Hide()
    if HUD.SetUnlocked then HUD.SetUnlocked(false) end
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

function QueueReapply()
    if not active or applying or enforceQueued then return end
    local now = GetTime()
    if now < pausedUntil then return end
    if now - burstStart > 3 then burstStart, burstCount = now, 0 end
    burstCount = burstCount + 1
    if burstCount > 8 then
        pausedUntil = now + 10
        Debug("another addon keeps moving the Minimap; pausing re-apply for 10s")
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

-- Re-anchor only (used live while dragging the mover)
function HUD.ApplyPosition()
    if not active then return end
    applying = true
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", UIParent, "CENTER", HUD.db.x, HUD.db.y)
    applying = false
    HUD.Tracking.Place()
end

function HUD.SetEnabled(state, auto)
    state = state and true or false
    if state == active then return end
    autoEnabled = (auto and state) and true or false
    if state then ApplyHud() else RestoreHud() end
    if HUD.Config then HUD.Config.Refresh() end
    if GT.RefreshHudButton then GT.RefreshHudButton() end       -- the HUD button in the main window
end

function HUD.Toggle()
    if HUD.db then HUD.SetEnabled(not active) end
end

-- Single entry point for changing a profile setting (slash, options panel)
function HUD.Set(key, value, fromUI)
    HUD.db[key] = value
    if key == "alpha" then
        if active then QueueMask() end       -- mask swap only, see ApplyMaskOnly
    elseif OVERLAY_KEYS[key] then
        if active then HUD.Overlay.Update() end
    elseif MAP_KEYS[key] then
        HUD.Refresh(true)
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
-- MINIMAP_UPDATE_TRACKING, PLAYER_MOUNT_DISPLAY_CHANGED, UNIT_AURA (player).
function HUD.OnEvent(event, arg1, arg2)
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

    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "UNIT_AURA" then
        if active and HUD.db.mountFade then HUD.UpdateVisibility() end

    elseif event == "PLAYER_LOGOUT" then
        if charState then charState.wasActive = active end
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
local broken = {}
local function Guard(name, fn, ...)
    if broken[name] then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        broken[name] = true
        GT.ReportError("HUD " .. name, err)
    end
end

function HUD.OnUpdate(dt)
    if not HUD.db then return end
    Guard("overlay", HUD.Overlay.OnUpdate, dt)             -- compass letters / heading (every 0.03 s)
    Guard("tracking", HUD.Tracking.OnUpdate)               -- dragging the tracking button
    Guard("mover", HUD.MoverTick)                          -- live position while dragging the mover
    Guard("watcher", HUD.WatcherTick, dt)                      -- keeps the stock tracking button right (0.1 s)
    Guard("skins", HUD.SkinSweep, dt)                          -- hides minimap skin frames SexyMap adds later (0.5 s)
end
