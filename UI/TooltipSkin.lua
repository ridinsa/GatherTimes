-- TooltipSkin.lua : apply the selected GatherTimes palette to Blizzard tooltips used by the addon.
local ADDON, GT = ...

local TOOLTIP_FRAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "WorldMapTooltip",
    "EmbeddedItemTooltip",
    "NamePlateTooltip",
}

local function Apply(tooltip)
    if not tooltip then return end
    local bg, border = GT.colors.bg, GT.colors.border
    if tooltip.SetBackdropColor then
        tooltip:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    end
    if tooltip.SetBackdropBorderColor then
        tooltip:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    end

    local nineSlice = tooltip.NineSlice
    if nineSlice then
        if nineSlice.SetCenterColor then nineSlice:SetCenterColor(bg[1], bg[2], bg[3], bg[4]) end
        if nineSlice.SetBorderColor then nineSlice:SetBorderColor(border[1], border[2], border[3], border[4]) end
    end
end

function GT.StyleTooltips()
    for _, name in ipairs(TOOLTIP_FRAMES) do
        local tooltip = _G[name]
        if tooltip and not tooltip.gtSkinHooked then
            tooltip.gtSkinHooked = true
            if hooksecurefunc and tooltip.Show then
                hooksecurefunc(tooltip, "Show", function() Apply(tooltip) end)
            else
                tooltip:HookScript("OnShow", Apply)
            end
        end
        Apply(tooltip)
    end
end

GT:RegisterSkinUpdater(GT.StyleTooltips)
GT.StyleTooltips()
