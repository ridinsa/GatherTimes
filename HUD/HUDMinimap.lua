-- HUDMinimap.lua : minimap mask, takeover / restore, mouse state, ping marker. Part of the HUD module (see HUD.lua).
local _, GT = ...
local HUD = GT.HUD
local S = HUD.S
local MaskPath = HUD.MaskPath
local BLANK_TEXTURE = HUD.BLANK_TEXTURE
local STOCK_MASK = HUD.STOCK_MASK
local STOCK_ARROW = HUD.STOCK_ARROW

---------------------------------------------------------------------------
-- Minimap mask: remember what other addons set so we can restore it
---------------------------------------------------------------------------

local lastMask = STOCK_MASK         -- last mask set by anyone else (SexyMap etc.)
local appliedMask                   -- mask we last applied
local settingMask = false
local arrowHidden = false
local lastArrow                      -- last player arrow set by anyone else (SexyMap etc.); nil = stock
local settingArrow = false

local function SetMask(tex)
    settingMask = true
    Minimap:SetMaskTexture(tex)
    settingMask = false
end

-- Opacity is one of 11 mask textures (a00 ... a10). Changing it must touch NOTHING but the mask: the old code
-- ran the whole HUD apply (re-parent, re-anchor, re-size, zoom, overlay, pin layout) on every slider tick, so the
-- Minimap was rebuilt while its new mask was still loading, which is what made 0 -> max unstable.
local function ApplyMaskOnly()
    if not S.active or not HUD.db then return end
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
    if S.active and HUD.db then
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
    if S.orig then return end
    S.orig = {
        parent = Minimap:GetParent(), strata = Minimap:GetFrameStrata(), level = Minimap:GetFrameLevel(),
        width = Minimap:GetWidth(), height = Minimap:GetHeight(), scale = Minimap:GetScale(),
        alpha = Minimap:GetAlpha(), mouse = Minimap:IsMouseEnabled(), wheel = Minimap:IsMouseWheelEnabled(),
        zoom = Minimap:GetZoom(), rotate = GetCVar("rotateMinimap"), points = {},
    }
    for i = 1, Minimap:GetNumPoints() do S.orig.points[i] = { Minimap:GetPoint(i) } end
    -- Only the CVar value is persisted (so a crash can't leave rotateMinimap stuck); never frames.
    HUD.root.origRotate = S.orig.rotate
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

-- Our own player arrow, used when "Arrow size" is not 100%. The game's arrow is blanked while it shows.
-- Base size 32 px at 100%. It points up while the map rotates, and turns with your facing when it does not.
local customArrow
local ARROW_BASE = 32
local function ArrowFrame()
    if not customArrow then
        customArrow = CreateFrame("Frame", nil, Minimap)
        customArrow.tex = customArrow:CreateTexture(nil, "OVERLAY")
        customArrow.tex:SetTexture(STOCK_ARROW)
        customArrow.tex:SetAllPoints()
        local acc, lastRot = 0, nil
        customArrow:SetScript("OnUpdate", function(self, dt)
            acc = acc + (dt or 0)
            if acc < 0.02 * HUD.PerfTick() then return end         -- Full: every ~frame, lower levels: less often
            acc = 0
            local cfg = HUD.Cfg()
            local rot = (cfg and cfg.rotate) and 0 or -(GetPlayerFacing() or 0)
            if rot ~= lastRot then                                   -- nothing to do while the facing does not change
                lastRot = rot
                self.tex:SetRotation(rot)
            end
        end)
        customArrow:HookScript("OnShow", function() lastRot = nil end)
        customArrow:Hide()
    end
    return customArrow
end

local function ShowCustomArrow(scale)
    local a = ArrowFrame()
    local size = ARROW_BASE * scale / 100
    a:SetSize(size, size)
    a:ClearAllPoints()
    a:SetPoint("CENTER", Minimap, "CENTER")
    a:Show()
end

local function HideCustomArrow()
    if customArrow then customArrow:Hide() end
end

-- show: the arrow setting; scale: "Arrow size" (nil = the game's arrow, as before)
local function ApplyArrow(show, scale)
    if not Minimap.SetPlayerTexture then return end
    local custom = show and scale ~= nil and scale ~= 100
    local stockShow = show and not custom
    if stockShow and arrowHidden then
        SetArrow(lastArrow or STOCK_ARROW)
        arrowHidden = false
    elseif not stockShow and not arrowHidden then
        SetArrow(BLANK_TEXTURE)
        arrowHidden = true
    end
    if custom then ShowCustomArrow(scale) else HideCustomArrow() end
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
    SwapMouseUp(true)                                           -- the stock click handler (map ping) is never wanted on the HUD
    if Minimap.SetPropagateMouseClicks then pcall(Minimap.SetPropagateMouseClicks, Minimap, hover) end
end
local function MinimapMouseMatches(hover)
    if Minimap.SetMouseMotionEnabled and Minimap.IsMouseMotionEnabled and Minimap.IsMouseClickEnabled then
        return (Minimap:IsMouseMotionEnabled() and true or false) == hover and not Minimap:IsMouseClickEnabled()
    end
    return (Minimap:IsMouseEnabled() and true or false) == hover
end
-- Does the map want the mouse (hover tooltips only, never clicks) right now?  The Eagle map follows "eagleHover"
-- (HUD.Cfg().hoverTips); the normal HUD follows "hudHover", off by default.
local function HoverWanted()
    local db = HUD.db
    if not db then return false end
    local on
    if S.eagleMode then
        on = HUD.Cfg().hoverTips
    elseif HUD.LowSpec() and HUD.EagleEyeActive() then
        on = db.eagleHover and true or false             -- lower-spec: no Eagle map, but Eagle Eye still shows the names
    else
        on = db.hudHover
    end
    return (on and CanHover()) and true or false
end

-- Safety net for the tooltip of a node under the mouse (the game shows it with the Minimap as owner): while the normal
-- HUD is up and "Hover tooltips on nodes" (hudHover) is off, it is hidden again as soon as it shows, even if the game
-- or another addon turned the Minimap's mouse back on.  Not while the Eagle map is up (it has "eagleHover").
local function TooltipSuppressed()
    local db = HUD.db
    if not (S.active and db) or S.eagleMode then return false end
    -- lower-spec mode during Eagle Eye: the names are shown on the normal HUD, under the Eagle hover setting
    if HUD.LowSpec() and HUD.EagleEyeActive() then return not db.eagleHover end
    return not db.hudHover
end
if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnShow", function(self)
        if not TooltipSuppressed() then return end
        local ok, owner = pcall(self.GetOwner, self)
        if not (ok and owner) then return end
        local isMap = owner == Minimap
        if not isMap and owner.GetParent then
            local ok2, parent = pcall(owner.GetParent, owner)
            isMap = ok2 and parent == Minimap
        end
        if isMap then self:Hide() end
    end)
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
    SetMinimapMouse(HoverWanted())
    Minimap:EnableMouseWheel(false)
    if Minimap:GetZoom() ~= db.zoom then Minimap:SetZoom(db.zoom) end
    local rot = db.rotate and "1" or "0"
    if GetCVar("rotateMinimap") ~= rot then
        SetCVar("rotateMinimap", rot)
        if Minimap_UpdateRotationSetting then pcall(Minimap_UpdateRotationSetting) end
    end
    ApplyArrow(db.arrow, db.arrowScale)
end


-- `applying` tells the re-apply hooks (below) that these Minimap changes are ours. If another addon answered
-- one of them by re-anchoring the Minimap right away (its own hook ran inside ours), the hook ignored it, so
-- check the result and ask for another pass.
local function ConfigureMinimapForHUD(db)
    S.applying = true
    local ok, err = pcall(ConfigureMinimapInner, db)
    S.applying = false
    if not ok then error(err, 0) end
    local point, rel, relPoint, x, y = Minimap:GetPoint(1)
    if Minimap:GetParent() ~= UIParent or point ~= "CENTER" or rel ~= UIParent or relPoint ~= "CENTER"
       or math.abs(x or 0) > 0.5 or math.abs(y or 0) > 0.5 then
        HUD.I.QueueReapply()
    end
end

local function RestoreMinimapFromOrig()
    Minimap:SetParent(S.orig.parent)
    Minimap:ClearAllPoints()
    for _, p in ipairs(S.orig.points) do Minimap:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    Minimap:SetScale(S.orig.scale)
    Minimap:SetSize(S.orig.width, S.orig.height)
    Minimap:SetFrameStrata(S.orig.strata)
    Minimap:SetFrameLevel(S.orig.level)
    Minimap:SetAlpha(S.orig.alpha)
    SetMask(lastMask or STOCK_MASK)
    appliedMask = nil
    SwapMouseUp(false)
    if Minimap.SetPropagateMouseClicks then pcall(Minimap.SetPropagateMouseClicks, Minimap, false) end
    Minimap:EnableMouse(S.orig.mouse)
    if Minimap.SetMouseClickEnabled and Minimap.SetMouseMotionEnabled then       -- the stock minimap takes clicks and hover
        pcall(Minimap.SetMouseClickEnabled, Minimap, S.orig.mouse and true or false)
        pcall(Minimap.SetMouseMotionEnabled, Minimap, S.orig.mouse and true or false)
    end
    Minimap:EnableMouseWheel(S.orig.wheel)
    Minimap:SetZoom(S.orig.zoom)
    SetCVar("rotateMinimap", S.orig.rotate)
    if Minimap_UpdateRotationSetting then pcall(Minimap_UpdateRotationSetting) end
    ApplyArrow(true)
end

-- The Minimap's mouse state is ours to decide: off for the full-screen HUD, on (clicks passed through) for the Eagle
-- map. Something else (the game, another addon) can switch it back on when the Eagle map goes away, so it is
-- looked at twice a second and put right.
local mouseAcc = 0
function HUD.MouseTick(dt)
    if not (S.active and S.orig) then mouseAcc = 0; return end
    mouseAcc = mouseAcc + (dt or 0)
    if mouseAcc < 0.5 then return end
    mouseAcc = 0
    local want = HoverWanted()
    if MinimapMouseMatches(want) then return end
    S.applying = true
    SetMinimapMouse(want)
    S.applying = false
end

-- Right away, not at the next half-second check: when the game or another addon switches the Minimap's mouse back on
-- (or its clicks) while the HUD is up, a press on the world would be taken by the full-screen map and the camera
-- would not turn until the check ran. The hooks put it right on the next frame.
local mouseFixQueued = false
local function QueueMouseFix()
    if mouseFixQueued or S.applying or not (S.active and S.orig) then return end
    mouseFixQueued = true
    C_Timer.After(0, function()
        mouseFixQueued = false
        if not (S.active and S.orig and HUD.db) then return end
        local want = HoverWanted()
        if MinimapMouseMatches(want) then return end
        S.applying = true
        pcall(SetMinimapMouse, want)
        S.applying = false
    end)
end
for _, fn in ipairs({ "EnableMouse", "SetMouseClickEnabled", "SetMouseMotionEnabled", "SetPropagateMouseClicks" }) do
    if Minimap[fn] then pcall(hooksecurefunc, Minimap, fn, QueueMouseFix) end
end

-- Minimap ping marker: clicking the map (or a party member pinging it) makes the game flash a blinking yellow ring
-- (the MiniMapPing frame) at that spot. On the full-screen HUD that ring sits on top of the node pins, so while
-- the HUD is up the frame is hidden again the moment the game shows it. The stock minimap is not touched.
local function HideHudPing(self)
    if S.active then self:Hide() end
end
-- Some clients draw the ping inside the Minimap itself (no frame to hide): the call that starts it is swallowed
-- while the HUD is up. Pings from other players arrive as an event and still show.
do
    local origPing = Minimap.PingLocation
    if type(origPing) == "function" then
        Minimap.PingLocation = function(self, ...)
            if S.active then return end
            return origPing(self, ...)
        end
    end
end
do
    local pingFrames = { MiniMapPing, Minimap and Minimap.PingFrame }
    for i = 1, 2 do
        local f = pingFrames[i]
        if f and f.HookScript then pcall(f.HookScript, f, "OnShow", HideHudPing) end
    end
end

-- shared with the other HUD files
HUD.I.QueueMask = QueueMask
HUD.I.Snapshot = Snapshot
HUD.I.SetMinimapMouse = SetMinimapMouse
HUD.I.MinimapMouseMatches = MinimapMouseMatches
HUD.I.HoverWanted = HoverWanted
HUD.I.ConfigureMinimapForHUD = ConfigureMinimapForHUD
HUD.I.RestoreMinimapFromOrig = RestoreMinimapFromOrig
