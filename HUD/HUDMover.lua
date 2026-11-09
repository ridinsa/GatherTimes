-- HUDMover.lua : the /gthud unlock drag handle. Part of the HUD module (see HUD.lua for the file layout).
local _, GT = ...
local HUD = GT.HUD
local Print = HUD.Print

---------------------------------------------------------------------------
-- Drag mover (/gthud unlock): drag the handle to place the HUD, /gthud lock to finish
---------------------------------------------------------------------------

local mover

local function SaveFromMover()
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (mx and ux) then return end
    HUD.db.x = HUD.Round(mx - ux)
    HUD.db.y = HUD.Round(my - uy)
    HUD.ApplyPosition()
end

local function EnsureMover()
    if mover then return end
    mover = GT:CreateFlatFrame("GatherTimesHUDMover", UIParent, 190, 46)
    mover:SetBackdropColor(0.1, 0.5, 1, 0.55)
    mover:SetFrameStrata("DIALOG")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    local fs = GT.Font(mover, nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER")
    fs:SetText(GT.TR("HUD - drag me\n|cffffff00/gthud lock|r when done"))
    mover:SetScript("OnDragStart", function(self) self.moving = true; self:StartMoving() end)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.moving = false
        SaveFromMover()
        -- StartMoving re-anchors to the screen corner; pin it back to the centre offset
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", HUD.db.x, HUD.db.y)
        if HUD.Config then HUD.Config.Refresh() end
    end)
    -- (the live position update while dragging runs from HUD.OnUpdate, see below)
    mover:Hide()
end

function HUD.SetUnlocked(state)
    if state then
        if not HUD.IsActive() then return Print(GT.TR("Turn the HUD on first (/gthud on), then unlock.")) end
        -- the Eagle map is always centred and the mover would move the normal HUD, which is not on screen then
        if HUD.EagleMapUp and HUD.EagleMapUp() then
            return Print(GT.TR("The Eagle Eye map is up and is always centred. Unlock after Eagle Eye ends (or stop the preview)."))
        end
        EnsureMover()
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", UIParent, "CENTER", HUD.db.x, HUD.db.y)
        mover:Show()
        Print(GT.TR("Unlocked: drag the blue handle. /gthud lock when done."))
    elseif mover and mover:IsShown() then
        mover:Hide()
        Print(GT.TRF("Locked at offset %d, %d", math.floor(HUD.db.x + 0.5), math.floor(HUD.db.y + 0.5)))
    end
    if HUD.Config then HUD.Config.Refresh() end
end

function HUD.IsUnlocked() return mover and mover:IsShown() or false end

-- Called every frame by HUD.OnUpdate: while the handle is being dragged the HUD follows it live
function HUD.MoverTick()
    if mover and mover.moving then SaveFromMover() end
end
