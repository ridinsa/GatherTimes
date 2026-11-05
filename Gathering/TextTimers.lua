-- TextTimers.lua
local addonName, GT = ...
local HBDPins = GT.HBDPins
local nodes = GT.nodes

-- ============================================================
local function StyleNode(node, key)
    local c = GT.cfg()
    local col = GT.Col(key)
    if node._miniFrame and node._miniFrame.label then
        node._miniFrame.label:SetFont(GT.FontFile("Fonts\\FRIZQT__.TTF"), GT.MapFontSize(c.fontMini), "OUTLINE")
        node._miniFrame.label:SetTextColor(col[1], col[2], col[3])
    end
    if node._worldFrame and node._worldFrame.label then
        node._worldFrame.label:SetFont(GT.FontFile("Fonts\\FRIZQT__.TTF"), GT.MapFontSize(c.fontMini), "OUTLINE")
        node._worldFrame.label:SetTextColor(col[1], col[2], col[3])
    end
end

-- Applies the text size / colours to EVERY node text on both maps: running timers and spot pins.
function GT.RestyleAll()
    for key in pairs(nodes) do
        for _, n in ipairs(GatherTimesDB[key]) do pcall(StyleNode, n, key) end
    end
    if GT.RestylePins then GT.RestylePins() end
end

-- WoW never frees a frame once it has been created, so frames are REUSED: a finished timer hands its
-- two frames (minimap + world map) back to these pools instead of dropping them.  (Creating new ones for
-- every loot made the addon's memory grow all session long.)
local miniPool, worldPool = {}, {}

local function GetMiniFrame()
    local mf = table.remove(miniPool)
    if mf then return mf end
    mf = CreateFrame("Frame", nil, Minimap)
    mf:SetSize(1, 1)
    mf.label = GT.Font(mf, nil, "OVERLAY", "GameFontNormalSmall")
    mf.label:SetPoint("TOP", mf, "CENTER", 0, -8)
    mf:EnableMouse(false)
    return mf
end

local function GetWorldFrame()
    local wf = table.remove(worldPool)
    if wf then return wf end
    wf = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
    wf:SetSize(1, 1)
    wf.label = GT.Font(wf, nil, "OVERLAY", "GameFontNormalSmall")
    wf.label:SetPoint("TOP", wf, "CENTER", 0, -6)
    wf:SetHitRectInsets(-18, -18, -4, -32)
    wf:SetScript("OnEnter", function(self) if self.nodeKey and GT.ShowItemTooltip then GT.ShowItemTooltip(self, self.nodeKey) end end)
    wf:SetScript("OnLeave", function() if GT.HideItemTooltip then GT.HideItemTooltip() end end)
    wf:SetScript("OnMouseUp", function(self, btn)
        if btn == "RightButton" and self.node and GT.OpenSpotMenu then
            GT.OpenSpotMenu(self, self.node, self.nodeKey, true)
        end
    end)
    return wf
end

function GT.CreateTextTimer(node, nodeKey)
    if node._miniFrame then return end
    local c = GT.cfg()
    local mf = GetMiniFrame()
    mf.nodeKey = nodeKey
    mf.label:SetText("")
    mf:Show()
    node._miniFrame = mf
    node._txtMini = nil
    local wf = GetWorldFrame()
    wf.nodeKey, wf.node = nodeKey, node
    wf.label:SetText("")
    wf:EnableMouse(true)
    wf:Show()
    node._worldFrame = wf
    node._txtWorld = nil
    StyleNode(node, nodeKey)
    if HBDPins then
        HBDPins:AddMinimapIconMap(addonName, mf, node.mapID, node.x, node.y, true, true)
        HBDPins:AddWorldMapIconMap(addonName, wf, node.mapID, node.x, node.y, 1)
    end
end

function GT.RemoveTextTimer(node)
    local mf, wf = node._miniFrame, node._worldFrame
    if HBDPins then
        if mf then HBDPins:RemoveMinimapIcon(addonName, mf) end
        if wf then HBDPins:RemoveWorldMapIcon(addonName, wf) end
    end
    if mf then mf:Hide(); mf.nodeKey = nil; miniPool[#miniPool + 1] = mf; node._miniFrame = nil end
    if wf then wf:Hide(); wf.nodeKey, wf.node = nil, nil; worldPool[#worldPool + 1] = wf; node._worldFrame = nil end
    node._txtMini, node._txtWorld = nil, nil
end

function GT.RemoveNodeRef(key, node)
    local list = GatherTimesDB[key]
    for i = #list, 1, -1 do
        if list[i] == node then
            pcall(GT.RemoveTextTimer, node)
            table.remove(list, i)
            return
        end
    end
end

-- ============================================================
-- SPAWN SYSTEM
-- ============================================================
