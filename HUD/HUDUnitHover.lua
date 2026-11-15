-- HUDUnitHover.lua : visible unit markers and hover tooltips on the normal HUD map.
local _, GT = ...
local HUD = GT.HUD
local S = HUD.S
local HBD = GT.HBD

local POLL_INTERVAL = 0.1
local HOVER_RADIUS = 12
local MAX_NAMEPLATES = 40
local markers = {}
local elapsed = 0
local hoveredMarker, hoveredGUID

local function HideUnitTooltip()
    if hoveredMarker and GameTooltip and GameTooltip:GetOwner() == hoveredMarker then
        GameTooltip:Hide()
    end
    hoveredMarker, hoveredGUID = nil, nil
end

local function NewMarker()
    local marker = CreateFrame("Frame", nil, Minimap)
    marker:SetSize(14, 14)
    marker:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    marker:EnableMouse(false)
    marker.dot = marker:CreateTexture(nil, "OVERLAY")
    marker.dot:SetAllPoints()
    marker.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    marker:Hide()
    return marker
end

local function AddUnit(units, seen, unit)
    if not UnitExists(unit) or UnitIsUnit(unit, "player") then return end
    local guid = UnitGUID(unit)
    if guid and seen[guid] then return end
    if guid then seen[guid] = true end
    units[#units + 1] = unit
end

local function VisibleUnits()
    local units, seen = {}, {}
    AddUnit(units, seen, "mouseover")
    AddUnit(units, seen, "target")
    AddUnit(units, seen, "focus")
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            AddUnit(units, seen, "raid" .. i)
        end
    else
        local count = GetNumSubgroupMembers and GetNumSubgroupMembers()
            or math.max(0, (GetNumGroupMembers and GetNumGroupMembers() or 1) - 1)
        for i = 1, count do AddUnit(units, seen, "party" .. i) end
    end
    for i = 1, MAX_NAMEPLATES do AddUnit(units, seen, "nameplate" .. i) end
    return units
end

local function UnitColor(unit)
    if UnitCanAttack and UnitCanAttack("player", unit) then
        return 1, 0.2, 0.2, 1
    end
    if unit:match("^nameplate") then
        return 0.3, 1, 0.4, 1
    end
    local _, classFile = UnitClass(unit)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then return color.r, color.g, color.b, 1 end
    return 1, 0.85, 0.1, 1
end

local function PlaceMarker(marker, unit, playerX, playerY, playerInstance, radius, rotate)
    local ok, x, y, instance = pcall(HBD.GetUnitWorldPosition, HBD, unit)
    if not ok or not x or not y or instance ~= playerInstance then
        marker:Hide()
        return nil
    end

    local dx, dy = playerX - x, playerY - y
    if rotate then
        local facing = GetPlayerFacing and GetPlayerFacing()
        if not facing then marker:Hide(); return nil end
        local sinFacing, cosFacing = math.sin(facing), math.cos(facing)
        dx, dy = dx * cosFacing - dy * sinFacing, dx * sinFacing + dy * cosFacing
    end
    local nx, ny = dx / radius, dy / radius
    if nx * nx + ny * ny > 1 then
        marker:Hide()
        return nil
    end

    marker:ClearAllPoints()
    marker:SetPoint("CENTER", Minimap, "CENTER",
        nx * Minimap:GetWidth() / 2, -ny * Minimap:GetHeight() / 2)
    marker.unit = unit
    marker:Show()
    -- GetCenter() is in the marker's own scale (the Minimap is scaled by the blip size, 1.3x by default), but the
    -- cursor is compared in UIParent scale: convert, or the hover point drifts away from the dot.
    local cx, cy = marker:GetCenter()
    if not (cx and cy) then return nil end
    local k = marker:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return cx * k, cy * k
end

local function ShowUnitTooltip(marker, unit)
    local guid = UnitGUID(unit)
    if hoveredMarker == marker and hoveredGUID == guid or not GameTooltip then return end
    HideUnitTooltip()
    GameTooltip:SetOwner(marker, "ANCHOR_CURSOR")
    GameTooltip:SetUnit(unit)
    hoveredMarker, hoveredGUID = marker, guid
end

function HUD.UnitHoverUpdate(dt)
    elapsed = elapsed + (dt or 0)
    if elapsed < POLL_INTERVAL then return end
    elapsed = 0

    local db = HUD.db
    if not (S.active and db and db.hudHover and not S.eagleMode and HBD
        and HBD.GetPlayerWorldPosition and HBD.GetUnitWorldPosition) then
        for _, marker in ipairs(markers) do marker:Hide() end
        HideUnitTooltip()
        return
    end

    local ok, playerX, playerY, playerInstance = pcall(HBD.GetPlayerWorldPosition, HBD)
    local radius = HUD.MapRadiusYards and HUD.MapRadiusYards()
    if not ok or not playerX or not playerY or not radius or radius <= 0 then
        for _, marker in ipairs(markers) do marker:Hide() end
        HideUnitTooltip()
        return
    end

    local units = VisibleUnits()
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local cursorX, cursorY = GetCursorPosition()
    local cursorScale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / cursorScale, cursorY / cursorScale
    local nearest, nearestDistance

    for i, unit in ipairs(units) do
        local marker = markers[i] or NewMarker()
        markers[i] = marker
        local centerX, centerY = PlaceMarker(marker, unit, playerX, playerY, playerInstance, radius, rotate)
        local r, g, b, a = UnitColor(unit)
        marker.dot:SetVertexColor(r, g, b, a)
        if centerX and centerY then
            local dx, dy = cursorX - centerX, cursorY - centerY
            local distance = dx * dx + dy * dy
            if distance <= HOVER_RADIUS * HOVER_RADIUS and (not nearestDistance or distance < nearestDistance) then
                nearest, nearestDistance = marker, distance
            end
        end
    end
    for i = #units + 1, #markers do markers[i]:Hide() end

    if nearest then
        ShowUnitTooltip(nearest, nearest.unit)
    else
        HideUnitTooltip()
    end
end
