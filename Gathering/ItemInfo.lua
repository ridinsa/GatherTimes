-- ItemInfo.lua : the info tooltip for a herb / ore: Nodes panel, world map and inventory
--   shows: item id, icon id, bag / bank count, vendor price, auction price (Auctionator or TSM when installed),
--   gathering difficulty with your skill, respawn, spots, session count and what the item is used for.
--   (switch: "Item tooltip" checkbox in the Nodes panel; it covers all three places)
local ADDON, GT = ...

-- What each item is used for.  Alchemy recipes come from the Classic recipe list; ores list what they smelt into.
-- (A herb with no entry is simply not shown in any recipe I could confirm.)
local ALCHEMY = {
    peacebloom   = { "Minor Healing Potion", "Minor Rejuvenation Potion", "Weak Troll's Blood Elixir", "Elixir of Minor Fortitude", "Discolored Healing Potion" },
    silverleaf   = { "Minor Healing Potion", "Elixir of Minor Defense", "Elixir of Lion's Strength", "Minor Mana Potion", "Elixir of Minor Agility" },
    earthroot    = { "Elixir of Lion's Strength", "Weak Troll's Blood Elixir", "Elixir of Minor Fortitude", "Elixir of Giant Growth", "Elixir of Ogre's Strength" },
    mageroyal    = { "Minor Mana Potion", "Minor Rejuvenation Potion", "Elixir of Wisdom", "Lesser Mana Potion" },
    briarthorn   = { "Lesser Healing Potion", "Swiftness Potion", "Elixir of Wisdom", "Healing Potion", "Strong Troll's Blood Elixir" },
    swiftthistle = { "Elixir of Minor Agility", "Swiftness Potion", "Holy Protection Potion", "Swim Speed Potion", "Elixir of Lesser Agility" },
    bruiseweed   = { "Healing Potion", "Holy Protection Potion", "Strong Troll's Blood Elixir", "Major Troll's Blood Elixir", "Potion of Curing", "Elixir of Minor Accuracy" },
    stranglekelp = { "Elixir of Water Breathing", "Lesser Mana Potion", "Mana Potion", "Elixir of Defense", "Nature Protection Potion", "Elixir of Agility", "Free Action Potion" },
    wildsteelbloom = { "Elixir of Defense", "Elixir of Lesser Agility" },
    gravemoss    = { "Shadow Protection Potion", "Oil of Immolation" },
    kingsblood   = { "Greater Healing Potion", "Mana Potion", "Shadow Protection Potion", "Elixir of Firepower", "Elixir of Ogre's Strength", "Great Rage Potion" },
    liferoot     = { "Greater Healing Potion", "Major Troll's Blood Elixir", "Nature Protection Potion" },
    fadeleaf     = { "Elixir of Detect Lesser Invisibility", "Catseye Elixir" },
    goldthorn    = { "Elixir of Agility", "Frost Protection Potion", "Greater Mana Potion", "Catseye Elixir", "Elixir of Greater Agility" },
    khadgarswhisker = { "Elixir of Detect Lesser Invisibility", "Elixir of Frost Power", "Superior Healing Potion", "Greater Mana Potion", "Elixir of Greater Intellect" },
    firebloom    = { "Elixir of Greater Firepower", "Goblin Rocket Fuel" },
    purplelotus  = { "Elixir of Detect Undead", "Elixir of Greater Water Breathing", "Dreamless Sleep Potion", "Elixir of Dream Vision", "Wildvine Potion" },
    sungrass     = { "Superior Healing Potion", "Superior Mana Potion", "Invisibility Potion", "Elixir of Greater Agility", "Elixir of Giants", "Elixir of Superior Defense" },
    blindweed    = { "Elixir of Greater Intellect", "Gift of Arthas", "Superior Mana Potion", "Limited Invulnerability Potion" },
    ghostmushroom = { "Invisibility Potion", "Limited Invulnerability Potion", "Elixir of Demonslaying" },
    gromsblood   = { "Mighty Rage Potion", "Elixir of Giants", "Elixir of Demonslaying", "Elixir of Detect Demon", "Elixir of Brute Force", "Flask of the Titans" },
    goldensansam = { "Major Healing Potion", "Greater Dreamless Sleep Potion", "Major Rejuvenation Potion" },
    dreamfoil    = { "Major Mana Potion", "Greater Arcane Elixir", "Mageblood Elixir", "Elixir of the Sages", "Greater Dreamless Sleep Potion", "Greater Protection Potions", "Flask of Supreme Power" },
    mountainsilversage = { "Elixir of the Mongoose", "Major Healing Potion", "Greater Arcane Elixir", "Living Action Potion", "Flask of Supreme Power" },
    plaguebloom  = { "Elixir of the Mongoose", "Elixir of Brute Force", "Mageblood Elixir", "Elixir of the Sages", "Purification Potion" },
    icecap       = { "Major Mana Potion", "Living Action Potion", "Purification Potion" },
    blacklotus   = { "Flask of the Titans", "Flask of Supreme Power", "other Flasks" },
}
local SMELT = {
    copperore = { "Copper Bar", "Bronze Bar (with Tin)" },
    tinore = { "Tin Bar", "Bronze Bar (with Copper)" },
    silverore = { "Silver Bar" },
    ironore = { "Iron Bar", "Steel Bar (with Coal)" },
    goldore = { "Gold Bar" },
    induriumore = { "Indurium Bar" },
    mithrilore = { "Mithril Bar" },
    truesilverore = { "Truesilver Bar" },
    darkironore = { "Dark Iron Bar" },
    richthorium = { "Thorium Bar", "Greater Stoneshield Potion (Alchemy)" },
}
GT.ALCHEMY_USES, GT.SMELT_USES = ALCHEMY, SMELT

-- ---------------------------------------------------------------------------------------------
local function Color(r, g, b, text) return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text) end
local function Money(copper)
    if not copper or copper <= 0 then return nil end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor((copper % 10000) / 100), math.floor(copper % 100))
end
local function Mmss(sec) return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60)) end

-- auction prices from whichever price addons are installed: { {source, copper}, ... }
local function AuctionPrices(id)
    local out = {}
    pcall(function()
        local A = Auctionator and Auctionator.API and Auctionator.API.v1
        if A and A.GetAuctionPriceByItemID then
            local p = A.GetAuctionPriceByItemID("GatherTimes", id)
            if p and p > 0 then out[#out + 1] = { "Auctionator", p } end
        end
    end)
    pcall(function()
        if TSM_API and TSM_API.GetCustomPriceValue then
            local p = TSM_API.GetCustomPriceValue("DBMarket", "i:" .. id)
            if p and p > 0 then out[#out + 1] = { "TSM market", p } end
        end
    end)
    return out
end

-- the first auction price found: copper and the name of the price addon, or nil (used by the session summary)
function GT.ItemAuctionPrice(id)
    local t = AuctionPrices(id)
    if t[1] then return t[1][2], t[1][1] end
end

local current          -- { owner, key } of the tooltip that is showing (to redraw when item data arrives)
local hiddenNameLines = setmetatable({}, { __mode = "k" })

local function HideCharacterNames(tt)
    local disguise = _G.GatherTimesNameDisguise
    if not (disguise and disguise.IsEnabled and disguise.IsEnabled() and disguise.ContainsCharacterName
        and tt and tt.GetName and tt.NumLines) then return end
    local name = tt:GetName()
    if not name then return end
    for i = 1, tt:NumLines() do
        local left, right = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
        if left and left.GetText and left.SetAlpha and left.GetAlpha then
            if disguise.ContainsCharacterName(left:GetText()) then
                if hiddenNameLines[left] == nil then hiddenNameLines[left] = left:GetAlpha() end
                left:SetAlpha(0)
            end
        end
        if right and right.GetText and right.SetAlpha and right.GetAlpha then
            if disguise.ContainsCharacterName(right:GetText()) then
                if hiddenNameLines[right] == nil then hiddenNameLines[right] = right:GetAlpha() end
                right:SetAlpha(0)
            end
        end
    end
end

local function RestoreHiddenNameLines()
    for line, alpha in pairs(hiddenNameLines) do
        if line.SetAlpha then line:SetAlpha(alpha) end
        hiddenNameLines[line] = nil
    end
end

local function HideLastCharacterName(tt)
    local disguise = _G.GatherTimesNameDisguise
    if not (disguise and disguise.IsEnabled and disguise.IsEnabled()
        and disguise.ContainsCharacterName and tt and tt.GetName and tt.NumLines) then return end
    local _, itemLink = tt:GetItem()
    if not itemLink then return end
    local name, line = tt:GetName(), tt:NumLines()
    if not name or line < 1 then return end
    local left, right = _G[name .. "TextLeft" .. line], _G[name .. "TextRight" .. line]
    if left and left.GetText and left.SetAlpha and left.GetAlpha and disguise.ContainsCharacterName(left:GetText()) then
        if hiddenNameLines[left] == nil then hiddenNameLines[left] = left:GetAlpha() end
        left:SetAlpha(0)
    end
    if right and right.GetText and right.SetAlpha and right.GetAlpha and disguise.ContainsCharacterName(right:GetText()) then
        if hiddenNameLines[right] == nil then hiddenNameLines[right] = right:GetAlpha() end
        right:SetAlpha(0)
    end
end

function GT.AddSpotNoteTooltip(owner, key)
    local sp = owner.spot
    if not sp and owner.node and GT.SpawnOfNode then sp = GT.SpawnOfNode(key, owner.node) end
    if sp and sp.note then
        GameTooltip:AddLine(GT.TR("Spot note") .. ": " .. sp.note, 1, 0.82, 0, true)
    end
end

function GT.HideItemTooltip()
    current = nil
    GameTooltip:Hide()
end

-- Fills tooltip `tt` with the node info.  append = true when the game already drew the item itself
-- (inventory / bank / chat link): then the name, icon, stack size and vendor price lines are skipped.
local function Fill(tt, key, append)
    local def = GT.nodes[key]
    local id = def.id
    local name, _, quality, _, _, _, _, maxStack, _, icon, sellPrice
    if GetItemInfo then name, _, quality, _, _, _, _, maxStack, _, icon, sellPrice = GetItemInfo(id) end
    local instantIcon
    if GetItemInfoInstant then instantIcon = select(5, GetItemInfoInstant(id)) end
    icon = instantIcon or icon

    if append then
        tt:AddLine(" ")
        tt:AddLine("GatherTimes", 1, 0.82, 0)
        tt:AddDoubleLine(GT.TR("Item ID"), tostring(id), 0.7, 0.7, 0.7, 1, 1, 1)
    else
        local qr, qg, qb = 1, 1, 1
        if quality and GetItemQualityColor then qr, qg, qb = GetItemQualityColor(quality) end
        tt:AddLine((icon and ("|T" .. icon .. ":16|t ") or "") .. (name or def.label), qr, qg, qb)
        tt:AddDoubleLine(GT.TR("Item ID"), tostring(id), 0.7, 0.7, 0.7, 1, 1, 1)
        tt:AddDoubleLine(GT.TR("Icon ID"), icon and tostring(icon) or GT.TR("loading..."), 0.7, 0.7, 0.7, 1, 1, 1)
        if maxStack and maxStack > 1 then tt:AddDoubleLine(GT.TR("Stack size"), tostring(maxStack), 0.7, 0.7, 0.7, 1, 1, 1) end
    end

    -- inventory
    if GetItemCount then
        local bags = GetItemCount(id) or 0
        local total = GetItemCount(id, true) or bags
        tt:AddDoubleLine(GT.TR("In bags"), tostring(bags), 0.7, 0.7, 0.7, 1, 1, 1)
        if total > bags then tt:AddDoubleLine(GT.TR("In bank"), tostring(total - bags), 0.7, 0.7, 0.7, 1, 1, 1) end
    end

    -- prices
    if not append then
        tt:AddLine(" ")
        tt:AddDoubleLine(GT.TR("Vendor price"), sellPrice and (Money(sellPrice) or GT.TR("none")) or GT.TR("loading..."), 0.7, 0.7, 0.7, 1, 1, 1)
    end
    local ah = AuctionPrices(id)
    if #ah == 0 then
        if not append then tt:AddDoubleLine(GT.TR("Auction price"), GT.TR("no price addon"), 0.7, 0.7, 0.7, 0.5, 0.5, 0.5) end
    else
        for _, p in ipairs(ah) do tt:AddDoubleLine(GT.TR("Auction") .. " (" .. p[1] .. ")", Money(p[2]), 0.7, 0.7, 0.7, 1, 1, 1) end
    end

    -- gathering difficulty
    local skillText = GT.SkillText and GT.SkillText(key)
    if skillText then
        tt:AddLine(" ")
        local r, g, b, band = GT.SkillColor(key)
        tt:AddDoubleLine(GT.TR("Gathering"), skillText, 0.7, 0.7, 0.7, r, g, b)
        local o, y, gr, grey = GT.SkillBands(key)
        tt:AddDoubleLine(GT.TR("Skill-ups"), string.format("%s  %s  %s  %s",
            Color(1, 0.5, 0.25, o), Color(1, 1, 0, y), Color(0.25, 0.75, 0.25, gr), Color(0.6, 0.6, 0.6, grey)),
            0.7, 0.7, 0.7, 1, 1, 1)
        local mine = GT.PlayerSkill(def.kind == "ore" and "Mining" or "Herbalism")
        tt:AddDoubleLine(GT.TR("Your skill"), mine and (tostring(mine) .. " (" .. GT.TR(band) .. ")") or GT.TR("not learned"), 0.7, 0.7, 0.7, r, g, b)
    end

    -- the addon's own knowledge about this item
    tt:AddLine(" ")
    local respawn = Mmss(def.timer)
    local learned, _, _, typical
    if GT.LearnedRange then learned, _, _, typical = GT.LearnedRange(key) end
    if learned then
        local shown = Mmss(learned)
        if typical and typical > learned then shown = shown .. " - " .. Mmss(typical) end
        respawn = respawn .. "  (" .. GT.TR("learned") .. " " .. shown .. ")"
    end
    tt:AddDoubleLine(GT.TR("Respawn"), respawn, 0.7, 0.7, 0.7, 1, 1, 1)
    local total, here, groups = #GT.spawns[key], 0, 0
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        here = #GT.SpawnsOnMap(key, mapID)
        if here > 0 then groups = #GT.ComputeGroups(key, mapID).groups end
    end
    tt:AddDoubleLine(GT.TR("Spots known"), GT.TRF("%d  (%d here, %d groups)", total, here, groups), 0.7, 0.7, 0.7, 1, 1, 1)
    tt:AddDoubleLine(GT.TR("Gathered this session"), tostring((GT.stats.counts[key]) or 0), 0.7, 0.7, 0.7, 1, 1, 1)

    -- used for
    local uses, heading = ALCHEMY[key], "Alchemy"
    if SMELT[key] then uses, heading = SMELT[key], "Smelts into" end
    if uses then
        tt:AddLine(" ")
        tt:AddLine(GT.TR(heading) .. ":", 1, 0.82, 0)
        for i, u in ipairs(uses) do
            if i > 10 then tt:AddLine(GT.TRF("  +%d more", #uses - 10), 0.6, 0.6, 0.6); break end
            tt:AddLine("  " .. u, 1, 1, 1)
        end
    end
end

function GT.ShowItemTooltip(owner, key)
    local c = GT.cfg()
    local def = GT.nodes[key]
    if not def then return end
    if not c.nodeTips then                       -- switch off: the simple default tooltip (name + skill needed)
        current = nil
        if GT.ShowNodeTooltip then
            GT.ShowNodeTooltip(owner, key)
            HideCharacterNames(GameTooltip)
            GameTooltip:Show()
        end
        return
    end
    current = { owner = owner, key = key }
    local id = def.id
    if GetItemInfo and not GetItemInfo(id) and Item and Item.CreateFromItemID then   -- not cached yet: ask the server, redraw when it arrives
        pcall(function()
            Item:CreateFromItemID(id):ContinueOnItemLoad(function()
                if current and current.key == key and current.owner == owner then
                    GT.ShowItemTooltip(owner, key)
                end
            end)
        end)
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    Fill(GameTooltip, key, false)
    GT.AddSpotNoteTooltip(owner, key)
    HideCharacterNames(GameTooltip)
    GameTooltip:Show()
end

-- Inventory / bank / chat links / anything else that shows a herb or ore through the normal game tooltip:
-- the same info is added underneath the game's own item text.  (same switch as the hover tooltip)
local idToKey
local function KeyForItem(id)
    if not idToKey then
        idToKey = {}
        for k, d in pairs(GT.nodes) do if d.id then idToKey[d.id] = k end end
    end
    return idToKey[id]
end

local function OnGameItem(tt, id)
    if tt ~= GameTooltip or tt.gtItemDone then return end
    if not GT.cfg().nodeTips then return end
    if not id then
        local _, link = tt:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    local key = id and KeyForItem(id)
    if not key then return end
    tt.gtItemDone = true
    Fill(tt, key, true)
    tt:Show()                                     -- resize to the new lines
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        OnGameItem(tt, data and data.id)
        HideCharacterNames(tt)
    end)
else
    GameTooltip:HookScript("OnTooltipSetItem", function(tt)
        OnGameItem(tt)
        HideCharacterNames(tt)
    end)
end
if hooksecurefunc and GameTooltip.AddLine and GameTooltip.AddDoubleLine then
    hooksecurefunc(GameTooltip, "AddLine", HideLastCharacterName)
    hooksecurefunc(GameTooltip, "AddDoubleLine", HideLastCharacterName)
end
GameTooltip:HookScript("OnTooltipCleared", function(tt)
    tt.gtItemDone = nil
    RestoreHiddenNameLines()
end)
