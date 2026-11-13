-- HUDApply.lua : applying and restoring the HUD, and keeping it in place against other minimap addons. Part of the HUD module (see HUD.lua).
local _, GT = ...
local HUD = GT.HUD
local S = HUD.S
local Print = HUD.Print
local Debug = HUD.Debug

-- hidden while mounted (option); in legacy mode also while Eagle Eye is on, before the HUD is switched off
local function Faded()
    local db = HUD.db
    if db.mountFade and IsMounted and IsMounted() then return true end
    return (not db.eagleMap) and HUD.EagleEyeActive() or false
end
HUD.Faded = Faded

function HUD.UpdateVisibility()
    if not S.active then return end
    local faded = Faded()
    Minimap:SetAlpha(faded and 0 or 1)
    if HUD.Overlay then HUD.Overlay.SetShown(not faded) end
end

-- light = true skips the (slower) frame hiding and tracking passes; used while dragging sliders.
local function ApplyHudInner(light)
    local db = HUD.Cfg()
    local wasActive = S.active
    S.active = true
    if not wasActive then HUD.UpdateEagleLabels() end      -- Gx / (G) labels show while the HUD is on
    HUD.I.Snapshot()
    HUD.I.ConfigureMinimapForHUD(db)
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

-- An error half-way through must not leave the HUD half applied and unreported: report it, and if this call was
-- the one switching the HUD on, switch it back off so the stock minimap is restored.
local function ApplyHud(light)
    local wasActive = S.active
    local ok, err = pcall(ApplyHudInner, light)
    if ok then return end
    GT.ReportError("HUD apply", err)
    if not wasActive then pcall(RestoreHud) end
end

function RestoreHud()
    if not S.active then return end
    S.active = false
    S.eagleMode, S.eaglePreview, S.eagleSizeStep = false, false, 1
    HUD.UpdateEagleLabels()
    HUD.Overlay.Hide()
    HUD.Tracking.Hide()
    if S.orig then HUD.I.RestoreMinimapFromOrig(); S.orig = nil end
    HUD.ShowDecorations()
    HUD.ReleaseStockTracking()
    HUD.root.origRotate = nil
    -- HUD off: show the HUD's own button or keep Blizzard's visible, depending on /gthud trackmode
    HUD.Tracking.Refresh()
    HUD.RefreshPins()
end

local function Enforce()
    if S.active then ApplyHud() end
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

function HUD.I.QueueReapply()
    if not S.active or S.applying or enforceQueued then return end
    local now = GetTime()
    if now < pausedUntil then return end
    if now - burstStart > 3 then burstStart, burstCount = now, 0 end
    burstCount = burstCount + 1
    if burstCount > 8 then
        pausedUntil = now + 10
        Debug("another addon keeps moving the Minimap; pausing re-apply for 10s")
        -- one re-apply when the pause ends, so the HUD is not left where the other addon put the Minimap
        C_Timer.After(10.1, function()
            if S.active and not S.applying then ApplyHud(true) end
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
        if S.active then ApplyHud(true) end
    end)
end

for _, method in ipairs({ "SetParent", "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale" }) do
    if Minimap[method] then hooksecurefunc(Minimap, method, HUD.I.QueueReapply) end
end

function HUD.Refresh(light)
    if S.active then ApplyHud(light) end
end

-- shared with the other HUD files
HUD.I.ApplyHud = ApplyHud
HUD.I.RestoreHud = RestoreHud
HUD.I.Enforce = Enforce
