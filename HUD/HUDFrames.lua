-- HUDFrames.lua : hiding the stock minimap decorations, addon skins / buttons and the stock tracking button
-- while the HUD is up. Part of the HUD module (see HUD.lua for the file layout).
local addonName, GT = ...
local HUD = GT.HUD

-- State private to this file
local hidden = {}                   -- frame -> true when WE hid it
local managed = {}                  -- frame -> "deco" | "addon" | "tracking"
local hookedShow = {}
local cachedAddonFrames = {}
local addonCacheStale = true

---------------------------------------------------------------------------
-- Frame hiding (decorations, SexyMap, minimap buttons)
---------------------------------------------------------------------------

local DECORATIONS = {
    "MinimapCluster", "MinimapBackdrop", "MinimapBorder", "MinimapBorderTop",
    "MinimapZoomIn", "MinimapZoomOut", "MinimapZoneTextButton", "MinimapZoneText",
    "TimeManagerClockButton", "TimeManagerClockTicker", "TimeManagerClockButtonTicker",
    "GameTimeFrame", "MinimapClock", "MinimapClockFrame", "MiniMapWorldMapButton",
    "MiniMapMailFrame", "MiniMapBattlefieldFrame", "MiniMapInstanceDifficulty",
    "MinimapToggleButton", "MinimapNorthTag", "MinimapCompassTexture",
}
local ADDON_EXCLUDE   = { "^GatherTimes", "^MiniMapTracking" }   -- never treated as addon frames (our own frames)

-- Minimap skinning / re-anchoring addons. When one of these is loaded we also look at the frames and
-- textures it parents to the Minimap (borders, backdrops, panels, coordinate text ...), not just named buttons.
-- /gthud scan forces this for addons that are not on the list.
local SKIN_ADDONS = { "SexyMap", "Chinchilla", "ElvUI", "Tukui", "pfUI", "BasicMinimap", "SpartanUI", "Leatrix_Plus" }

local function IsAddonLoadedByName(n)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return f and f(n)
end

-- The list only changes when another addon loads, so it is built once and rebuilt after InvalidateAddonCache()
-- (this is asked every 0.1 s by the watcher: no IsAddOnLoaded calls and no new tables per tick).  Read-only for callers.
local skinCache
local function LoadedSkinAddons()
    if skinCache then return skinCache end
    local t = {}
    for _, n in ipairs(SKIN_ADDONS) do
        if IsAddonLoadedByName(n) then t[#t + 1] = n end
    end
    skinCache = t
    return t
end

local function SkinScanEnabled()
    return (HUD.root and HUD.root.deepScan) or #LoadedSkinAddons() > 0
end

-- Re-hide anything we manage if another addon shows it while the HUD is up.
-- (Stock tracking frames are always kept hidden: the HUD has its own tracking button.)
local function ManagedShowHook(self)
    local kind = managed[self]
    if not kind then return end
    if not HUD.IsActive() then
        -- HUD off: only the stock tracking frames matter, and only while the HUD's own button replaces them
        if kind == "tracking" and HUD.db and HUD.db.tracking and HUD.UseOwnIdle and HUD.UseOwnIdle() then self:Hide() end
        return
    end
    if kind == "deco" or kind == "tracking"
       or (kind == "addon" and HUD.db.hideAddons) then
        self:Hide()
    end
end

local function HookShow(f)
    if f.Show and not hookedShow[f] then
        hookedShow[f] = true
        hooksecurefunc(f, "Show", ManagedShowHook)
    end
end

local function HideFrame(f, kind)
    if not (f and f.IsShown) then return end
    managed[f] = managed[f] or kind
    HookShow(f)
    if f:IsShown() then f:Hide(); hidden[f] = true end
end

-- Finding the addon minimap buttons means looking through _G. On setups with many addons that is tens of
-- thousands of keys, and doing it in one go trips the client's "script ran too long" watchdog. So the scan is
-- time-sliced (about 3 ms per frame) and uses a cheap string prefilter instead of 7 pattern matches per key.
local cachedSet = {}
local scanKey, scanning, scanRestarts = nil, false, 0
local HideAddonFrames

local function MatchesAddonName(name)
    if name:sub(1, 11) == "GatherTimes" or name:sub(1, 15) == "MiniMapTracking" then return false end
    local c = name:byte(1)
    -- first letters of SexyMap / LibDBIcon10_ / MBB_ / MinimapButtonCollect, or the "...MinimapButton" suffix
    if c == 83 or c == 76 or c == 77 then            -- S, L, M
        if name:sub(1, 7) == "SexyMap" or name:sub(1, 12) == "LibDBIcon10_"
           or name:sub(1, 4) == "MBB_" or name:sub(1, 20) == "MinimapButtonCollect" then
            return true
        end
    end
    if name:byte(-1) == 110 and name:sub(-5) == "utton" then   -- ends in "n": "...utton"
        return name:find("[Mm]ini[Mm]ap[Bb]utton$") ~= nil
    end
    return false
end

local function CacheIfFrame(name)
    local f = rawget(_G, name)
    if type(f) == "table" and not cachedSet[f] and type(f.Hide) == "function" and type(f.IsShown) == "function" then
        cachedSet[f] = true
        cachedAddonFrames[#cachedAddonFrames + 1] = f
    end
end

local function ScanSlice()
    local started = debugprofilestop and debugprofilestop() or 0
    local count = 0
    local ok = pcall(function()
        local k = scanKey
        while true do
            k = next(_G, k)
            if k == nil then scanning = false; scanKey = nil; return end
            scanKey = k
            if type(k) == "string" and MatchesAddonName(k) then CacheIfFrame(k) end
            count = count + 1
            if count % 250 == 0 and debugprofilestop and debugprofilestop() - started > 3 then return end
        end
    end)
    if not ok then
        -- _G changed under the iterator ("invalid key to next"): start over, but not forever
        scanKey = nil
        scanRestarts = scanRestarts + 1
        if scanRestarts > 5 then scanning = false end
    end
    if scanning then
        C_Timer.After(0, ScanSlice)
    elseif HUD.IsActive() then
        HideAddonFrames()       -- scan finished: hide whatever it found
    end
end

local function RefreshAddonFrameCache()
    addonCacheStale = false
    wipe(cachedAddonFrames)
    wipe(cachedSet)
    -- quick, cheap sources first so the HUD is clean immediately
    local lib = _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)
    if lib and lib.GetButtonList then
        for _, n in ipairs(lib:GetButtonList()) do CacheIfFrame("LibDBIcon10_" .. n) end
    end
    for _, c in ipairs({ Minimap:GetChildren() }) do
        local n = c.GetName and c:GetName()
        if n and MatchesAddonName(n) then CacheIfFrame(n) end
    end
    if scanning then
        -- a scan is already running but the cache was just wiped: restart it so nothing it already passed is lost
        scanKey, scanRestarts = nil, 0
    else
        scanning, scanKey, scanRestarts = true, nil, 0
        C_Timer.After(0, ScanSlice)
    end
end

function HideAddonFrames()
    if not HUD.db.hideAddons then
        -- setting turned off while the HUD is up: give the addon frames back
        for f in pairs(hidden) do
            if managed[f] == "addon" then f:Show(); hidden[f] = nil end
        end
        return
    end
    if addonCacheStale then RefreshAddonFrameCache() end
    for _, f in ipairs(cachedAddonFrames) do HideFrame(f, "addon") end

    if SkinScanEnabled() then
        -- Skins/borders/panels that an addon hung on the Minimap. Map pins (HereBeDragons, GatherMate2, TomTom)
        -- are small single-anchor frames, so they never match: anonymous frames need 2+ anchors or to be as
        -- wide as the stock minimap, named frames only the latter.
        local limit = (HUD.OrigWidth() or HUD.MINIMAP_BASE_SIZE) * 0.9
        for _, c in ipairs({ Minimap:GetChildren() }) do
            local name = c:GetName()
            if name then
                local skip = false
                for _, pat in ipairs(ADDON_EXCLUDE) do
                    if name:find(pat) then skip = true; break end
                end
                if not skip and c:GetWidth() >= limit then HideFrame(c, "addon") end
            elseif c:GetNumPoints() >= 2 or c:GetWidth() >= limit then
                HideFrame(c, "addon")
            end
        end
        for _, r in ipairs({ Minimap:GetRegions() }) do
            if r.IsObjectType and not r:GetName()
               and (r:IsObjectType("Texture") or r:IsObjectType("FontString")) then
                HideFrame(r, "addon")
            end
        end
    end
end

local function HideDecorations()
    for _, name in ipairs(DECORATIONS) do HideFrame(_G[name], "deco") end
    if HUD.HideClockFrames then HUD.HideClockFrames() end
    HideAddonFrames()
end

function HUD.HideClockFrames()
    local function HideTree(frame)
        if not frame then return end
        HideFrame(frame, "deco")
        if frame.GetRegions then
            for _, region in ipairs({ frame:GetRegions() }) do HideFrame(region, "deco") end
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do HideTree(child) end
        end
    end
    for _, name in ipairs({
        "TimeManagerClockButton", "TimeManagerClockTicker", "TimeManagerClockButtonTicker",
        "GameTimeFrame", "MinimapClock", "MinimapClockFrame",
    }) do
        HideTree(_G[name])
    end
end

-- Frames whose visibility is driven by game state: what was true when the HUD hid them may be stale by now, so ask
-- the game again instead of blindly showing them (a mail icon must not come back after the mail was taken).
local function StillWanted(f)
    local mail = _G.MiniMapMailFrame
    if mail and (f == mail or f == _G.MiniMapMailIcon) and HasNewMail then
        return HasNewMail() and true or false
    end
    return true
end

local function ShowDecorations()
    for f in pairs(hidden) do
        if StillWanted(f) then f:Show() end
        hidden[f] = nil
    end
end

local rehidePending = false
local function ScheduleRehide()
    if rehidePending then return end
    rehidePending = true
    C_Timer.After(1, function()
        rehidePending = false
        if HUD.IsActive() then HideDecorations() end
    end)
end

---------------------------------------------------------------------------
-- Stock tracking button: kept out of the way while the HUD is up
---------------------------------------------------------------------------

-- The HUD has its own tracking button (Tracking.lua). The stock frames are only hidden here, never moved,
-- skinned or restyled, so SexyMap / BasicMinimap / ElvUI etc. can do whatever they like with them.
-- With SexyMap the stock button is a child of the Minimap, so without this it would follow the Minimap onto
-- the HUD (invisible at alpha 0 until the mouse happens to touch it).

local trackingShown = {}                -- stock tracking frame -> was it shown before we hid it

local function StockTrackingFrames()
    local t = {}
    local function add(f)
        if type(f) == "table" and type(f.IsShown) == "function" and type(f.Hide) == "function" then
            t[#t + 1] = f
        end
    end
    add(_G.MiniMapTracking)
    add(_G.MiniMapTrackingButton)           -- child of MiniMapTracking; BasicMinimap re-parents it separately
    add(_G.MiniMapTrackingFrame)
    local cluster = _G.MinimapCluster
    if type(cluster) == "table" and type(cluster.Tracking) == "table" then
        add(cluster.Tracking)               -- newer client layouts
        add(cluster.Tracking.Button)
    end
    return t
end

local function HideStockTracking()
    for _, f in ipairs(StockTrackingFrames()) do
        if trackingShown[f] == nil then trackingShown[f] = f:IsShown() and true or false end
        managed[f] = "tracking"
        HookShow(f)
        if f:IsShown() then f:Hide() end
    end
end

-- Classic Era only shows MiniMapTracking while a tracking ability is active, and Blizzard decides that itself.
-- Tracking may have changed while the HUD was up, so ask Blizzard first and only then fall back to our memory.
local function RestoreStockFrame(f, wasShown)
    if type(f.UpdateState) == "function" and pcall(f.UpdateState, f) then return end
    if f == _G.MiniMapTracking then
        if type(_G.MiniMapTracking_Update) == "function" and pcall(_G.MiniMapTracking_Update) then return end
        local tex = _G.GetTrackingTexture and _G.GetTrackingTexture()
        if tex then f:Show() else f:Hide() end
        return
    end
    if wasShown then f:Show() end
end

local function ReleaseStockTracking()
    for f, wasShown in pairs(trackingShown) do
        trackingShown[f] = nil
        managed[f] = nil
        RestoreStockFrame(f, wasShown)
    end
end

-- HUD off: which tracking button is the one the player sees?
--   "stock" Blizzard's button, kept visible by the polling below: minimap addons (SexyMap "On Hover", ...) fade
--           it through animations, un-hooked method tables or a fade on a parent frame, none of which a
--           hooksecurefunc can see, so every 0.1 s we undo the fade on the button and its fading parents
--   "own"   the HUD's button (parented to UIParent, so no minimap addon can fade it); the stock one is hidden
--   "auto"  "own" when a minimap skin addon (SexyMap, ElvUI, ...) is loaded, otherwise "stock"
function HUD.UseOwnIdle()
    local mode = HUD.db and HUD.db.trackIdle or "auto"
    if mode == "own" then return true end
    if mode == "stock" then return false end
    return #LoadedSkinAddons() > 0
end

local function StockWanted()
    return not HUD.IsActive() and HUD.db and HUD.db.tracking and not HUD.UseOwnIdle()
end

-- Can this character track anything right now? Classic Era lists no tracking types (count 0 or missing) and
-- only exposes the active tracking icon, so that counts too.
local function CanTrack()
    local cm = _G.C_Minimap
    local getNum = _G.GetNumTrackingTypes or (cm and cm.GetNumTrackingTypes)
    if getNum then
        local ok, n = pcall(getNum)
        if ok and type(n) == "number" and n > 0 then return true end
    end
    if _G.GetTrackingTexture then
        local ok, tex = pcall(_G.GetTrackingTexture)
        if ok and tex then return true end
    end
    return false
end

-- Parents we never touch: they carry the user's own minimap opacity / the whole UI.
local function IsProtected(fr)
    return fr == _G.UIParent or fr == _G.WorldFrame or fr == _G.Minimap or fr == _G.MinimapCluster
end

local function StopAnims(fr)
    if fr.GetAnimationGroups then
        for _, g in ipairs({ fr:GetAnimationGroups() }) do
            if g.IsPlaying and g:IsPlaying() and g.Stop then pcall(g.Stop, g) end
        end
    end
end

local function Unfade(fr, onlyIfInvisible)
    StopAnims(fr)
    if fr.GetAlpha and fr.SetAlpha then
        local al = fr:GetAlpha()
        if al < (onlyIfInvisible and 0.05 or 1) then fr:SetAlpha(1) end
    end
end

-- Button, its child frames and its icon/border textures, plus every container above it, are forced
-- visible on each tick. Nothing here is skipped because it "looks fine": the fade may sit on any of them,
-- and a hidden parent still reports alpha 1.
local function ForceStock(f)
    if not f:IsShown() then f:Show() end
    Unfade(f)
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Unfade(c, true) end
    end
    if f.GetRegions then
        for _, r in ipairs({ f:GetRegions() }) do Unfade(r, true) end
    end
    local p = f:GetParent()
    local guard = 0
    while p and not IsProtected(p) and guard < 8 do
        Unfade(p)
        if p.IsShown and not p:IsShown() and p.Show then p:Show() end
        p = p.GetParent and p:GetParent() or nil
        guard = guard + 1
    end
end

-- light = true: periodic check only (no call into Blizzard's own update)
function HUD.ShowStockTracking(light)
    if not StockWanted() or not CanTrack() then return end
    if not light and type(_G.MiniMapTracking_Update) == "function" then pcall(_G.MiniMapTracking_Update) end
    for _, f in ipairs(StockTrackingFrames()) do
        if f.SetAlpha and f.Show then ForceStock(f) end
    end
end

-- Called from HUD.OnUpdate (GatherTimes' update loop) every frame.  It checks every 0.1 s while something is off
-- (a minimap addon fading the stock button), and only every 0.5 s while all is fine.  The frame list is cached
-- for a few seconds instead of being rebuilt on every tick.
local watcherAcc, watcherWait = 0, 0.1
local stockCache, stockCacheAt = nil, 0

local function CachedStockFrames()
    local now = GetTime()
    if not stockCache or now - stockCacheAt > 5 then
        stockCache, stockCacheAt = StockTrackingFrames(), now
    end
    return stockCache
end

-- is every stock tracking frame really visible?  (effective alpha / visibility include ALL parents: the fade may
-- sit on any container above the button)
local function StockLooksFine()
    for _, f in ipairs(CachedStockFrames()) do
        if not (f:IsVisible() and f:GetEffectiveAlpha() >= 0.99) then return false end
    end
    return true
end

local function WatcherTick(dt)
    watcherAcc = watcherAcc + dt
    if watcherAcc < watcherWait then return end
    watcherAcc = 0
    if HUD.IsActive() or not (HUD.db and HUD.db.tracking) then watcherWait = 0.5; return end
    if HUD.UseOwnIdle() then
        -- our own button replaces Blizzard's: keep the stock one out of sight (no duplicate)
        watcherWait = 0.1
        for _, f in ipairs(CachedStockFrames()) do
            managed[f] = "tracking"
            HookShow(f)             -- hide it the instant Blizzard shows it again, no flicker
            if f:IsShown() then f:Hide() end
        end
        local btn = _G.GatherTimesHUDTrackingButton
        if not (btn and btn:IsShown()) then HUD.Tracking.Update() end
    elseif not CanTrack() or StockLooksFine() then       -- nothing to track, or all fine: check less often
        watcherWait = 0.5
    else
        watcherWait = 0.1
        HUD.ShowStockTracking(true)
    end
end

---------------------------------------------------------------------------
-- What the other HUD files use
---------------------------------------------------------------------------

HUD.IsAddonLoadedByName = IsAddonLoadedByName
HUD.LoadedSkinAddons = LoadedSkinAddons
HUD.StockTrackingFrames = StockTrackingFrames
HUD.HideDecorations = HideDecorations
HUD.ShowDecorations = ShowDecorations
HUD.HideStockTracking = HideStockTracking
HUD.ReleaseStockTracking = ReleaseStockTracking
HUD.ScheduleRehide = ScheduleRehide
HUD.WatcherTick = WatcherTick
function HUD.InvalidateAddonCache() addonCacheStale = true; skinCache = nil end
function HUD.IsHiddenByHud(f) return hidden[f] or false end
