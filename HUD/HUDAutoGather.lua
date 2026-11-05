-- HUDAutoGather.lua : switches the HUD on while a gathering tracking spell is active, off again afterwards.
-- Part of the HUD module (see HUD.lua for the file layout).
local addonName, GT = ...
local HUD = GT.HUD

---------------------------------------------------------------------------
-- Auto-enable while a gathering tracking spell is active
---------------------------------------------------------------------------

local GATHER_SPELLS = { 2383, 2580, 2481 }   -- Find Herbs, Find Minerals, Find Treasure
local gatherNames

local function GetGatherNames()
    if gatherNames then return gatherNames end
    gatherNames = {}
    for _, id in ipairs(GATHER_SPELLS) do
        local name
        if GetSpellInfo then name = GetSpellInfo(id)
        elseif C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id) end
        if name then gatherNames[name] = true end
    end
    return gatherNames
end

local function SpellIcon(id)
    if _G.GetSpellTexture then
        local ok, t = pcall(_G.GetSpellTexture, id)
        if ok and t then return t end
    end
    if _G.C_Spell and _G.C_Spell.GetSpellTexture then
        local ok, t = pcall(_G.C_Spell.GetSpellTexture, id)
        if ok and t then return t end
    end
end

local function GatheringTrackingActive()
    -- clients that list tracking types
    if GetNumTrackingTypes and GetTrackingInfo then
        local n = GetNumTrackingTypes()
        if type(n) == "number" and n > 0 then
            local names = GetGatherNames()
            for i = 1, n do
                local name, _, isActive = GetTrackingInfo(i)
                if isActive and names[name] then return true end
            end
            return false
        end
    end
    -- Classic Era: no type list, only the icon of the active tracking. Compare it with the gathering spells' icons.
    local tex = _G.GetTrackingTexture and _G.GetTrackingTexture()
    if not tex then return false end
    for _, id in ipairs(GATHER_SPELLS) do
        local icon = SpellIcon(id)
        if icon and (tostring(icon):lower() == tostring(tex):lower()
            or (HUD.SameTexture and HUD.SameTexture(tex, icon))) then return true end   -- a path and a file ID match too
    end
    return false
end

function HUD.CheckAutoGather()
    if not (HUD.db and HUD.db.autoGather) then return end
    local ok, gathering = pcall(GatheringTrackingActive)
    if not ok then return end
    if gathering and not HUD.IsActive() then
        HUD.SetEnabled(true, true)
    elseif not gathering and HUD.IsActive() and HUD.WasAutoEnabled() then
        HUD.SetEnabled(false, true)
    end
end
