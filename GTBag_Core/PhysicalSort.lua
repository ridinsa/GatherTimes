local _, ns = ...

local function PositionKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

local function SameItem(a, b)
    if not a or not b then return a == b end
    return a.info.id == b.info.id and a.info.link == b.info.link
end

-- a slot already holds the planned item only when id, link and stack size all agree (so stacks of one item end up
-- ordered by count); merging and ammo moves keep using SameItem, which ignores the count
local function SamePlacement(a, b)
    if not a or not b then return a == b end
    return a.info.id == b.info.id and a.info.link == b.info.link
        and (tonumber(a.info.count) or 1) == (tonumber(b.info.count) or 1)
end

local function ItemLess(a, b)
    -- ns.ItemCompare is the order on screen (the chosen rule, junk last), so the physical sort matches it.  This used
    -- to put the Hearthstone first whatever rule was chosen.
    if ns.ItemCompare(a, b) then return true end
    if ns.ItemCompare(b, a) then return false end
    local aLink, bLink = a.info.link or "", b.info.link or ""
    if aLink ~= bLink then return aLink < bLink end
    return a.order < b.order
end

local function BagFamily(bag)
    if not ns.GetNumFree then return nil end
    local ok, _, bagType = pcall(ns.GetNumFree, bag)
    local family = bagType
    if ok and tonumber(family) then return tonumber(family) end

    local itemID
    if ContainerIDToInventoryID and GetInventoryItemID then
        itemID = GetInventoryItemID("player", ContainerIDToInventoryID(bag))
    end
    if not itemID then return nil end
    local getFamily = (C_Item and C_Item.GetItemFamily) or GetItemFamily
    if type(getFamily) ~= "function" then return nil end
    local ok2, fallback = pcall(getFamily, itemID)
    if ok2 then return tonumber(fallback) end
    return nil
end

local AMMO_FAMILY_BITS = { 1, 2 }
local ITEM_FAMILY_CACHE_LIMIT = 256
local itemFamilyCache, itemFamilyCacheSize = {}, 0

local function HasFamilyBit(mask, familyBit)
    return type(mask) == "number" and math.floor(mask / familyBit) % 2 == 1
end

local function FamiliesOverlap(first, second)
    if type(first) ~= "number" or type(second) ~= "number" then return false end
    local bitLib = bit or bit32
    if bitLib and bitLib.band then return bitLib.band(first, second) ~= 0 end
    local familyBit = 1
    while familyBit <= math.max(first, second) do
        if HasFamilyBit(first, familyBit) and HasFamilyBit(second, familyBit) then return true end
        familyBit = familyBit * 2
    end
    return false
end

local function ItemFamily(info)
    local id = tonumber(info.id)
    if not id then return nil end
    local cached = itemFamilyCache[id]
    if cached ~= nil then return cached end

    local getItemFamily = (C_Item and C_Item.GetItemFamily) or GetItemFamily
    if type(getItemFamily) ~= "function" then return nil end
    local ok, family = pcall(getItemFamily, info.link or id)
    if not ok or type(family) ~= "number" then return nil end

    if itemFamilyCacheSize >= ITEM_FAMILY_CACHE_LIMIT then
        wipe(itemFamilyCache)
        itemFamilyCacheSize = 0
    end
    itemFamilyCache[id] = family
    itemFamilyCacheSize = itemFamilyCacheSize + 1
    return family
end

local function AmmoFamilyBit(info)
    local family = ItemFamily(info)
    for _, familyBit in ipairs(AMMO_FAMILY_BITS) do
        if HasFamilyBit(family, familyBit) then return familyBit end
    end
end

local stackSizes = {}
local function ItemMaxStack(info)
    local id = tonumber(info.id)
    if not id then return nil end
    if stackSizes[id] then return stackSizes[id] end

    local maxStackFn = C_Item and C_Item.GetItemMaxStackSize
    if maxStackFn then
        local ok, maxStack = pcall(maxStackFn, id)
        if ok and type(maxStack) == "number" and maxStack >= 1 then
            stackSizes[id] = maxStack
            return maxStack
        end
    end

    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getItemInfo then
        local ok, maxStack = pcall(function()
            return select(8, getItemInfo(info.link or id))
        end)
        if ok and type(maxStack) == "number" and maxStack >= 1 then
            stackSizes[id] = maxStack
            return maxStack
        end
    end
end

local function FindStackMerge(groups)
    local byID, stackGroups = {}, {}
    for _, group in ipairs(groups) do
        for _, item in ipairs(group.items) do
            local id = tonumber(item.info.id)
            local link = item.info.link or ""
            byID[id] = byID[id] or {}
            local stacks = byID[id][link]
            if not stacks then
                stacks = {}
                byID[id][link] = stacks
                stackGroups[#stackGroups + 1] = stacks
            end
            stacks[#stacks + 1] = item
        end
    end

    for _, stacks in ipairs(stackGroups) do
        if #stacks > 1 then
            local maxStack = ItemMaxStack(stacks[1].info)
            if not maxStack then return nil, "item data unavailable" end
            if maxStack > 1 then
                local partials = {}
                for _, item in ipairs(stacks) do
                    if (tonumber(item.info.count) or 1) < maxStack then
                        partials[#partials + 1] = item
                    end
                end
                table.sort(partials, function(a, b)
                    return (tonumber(a.info.count) or 1) < (tonumber(b.info.count) or 1)
                end)
                for _, source in ipairs(partials) do
                    for targetIndex = #partials, 1, -1 do
                        local target = partials[targetIndex]
                        if source ~= target
                            and (tonumber(target.info.count) or 1) >= (tonumber(source.info.count) or 1)
                            and (source.group == target.group
                                or target.group.family == 0
                                or FamiliesOverlap(target.group.family, ItemFamily(target.info))) then
                            return {
                                sourceBag = source.bag,
                                sourceSlot = source.slot,
                                targetBag = target.bag,
                                targetSlot = target.slot,
                            }
                        end
                    end
                end
            end
        end
    end
end

-- Moves one item out of the regular bags into a family-restricted bag that accepts it: a quiver or ammo pouch for
-- arrows and bullets, and (when "Route profession bags" is on) an herb, mining, gem, enchanting, engineering,
-- leatherworking, inscription, cooking or fishing bag, a soul bag, and so on.  The item's family mask (GetItemFamily)
-- is matched against each bag's family mask, so no per-profession table is needed.  It moves into an empty slot of the
-- bag first, then into a partial stack of the same item.
local function FindFamilyMove(groups, regularGroup, current)
    if not regularGroup then return nil end
    local routeAll = ns.Opt("routeBags")
    local specialGroups = {}
    for _, group in ipairs(groups) do
        if group ~= regularGroup and type(group.family) == "number" and group.family ~= 0 then
            specialGroups[#specialGroups + 1] = group
        end
    end
    if #specialGroups == 0 then return nil end

    for _, item in ipairs(regularGroup.items) do
        local itemFamily = ItemFamily(item.info)
        if type(itemFamily) == "number" and itemFamily ~= 0
            and (routeAll or AmmoFamilyBit(item.info)) then
            local targets = {}
            for _, group in ipairs(specialGroups) do
                if FamiliesOverlap(group.family, itemFamily) then
                    targets[#targets + 1] = group
                    for _, position in ipairs(group.positions) do
                        if not current[position.key] then
                            return {
                                sourceBag = item.bag,
                                sourceSlot = item.slot,
                                targetBag = position.bag,
                                targetSlot = position.slot,
                            }
                        end
                    end
                end
            end

            local maxStack = ItemMaxStack(item.info)
            if maxStack then
                for _, group in ipairs(targets) do
                    for _, target in ipairs(group.items) do
                        local targetCount = tonumber(target.info.count) or 1
                        local sourceCount = tonumber(item.info.count) or 1
                        if SameItem(item, target) and targetCount < maxStack
                            and targetCount + sourceCount <= maxStack then
                            return {
                                sourceBag = item.bag,
                                sourceSlot = item.slot,
                                targetBag = target.bag,
                                targetSlot = target.slot,
                            }
                        end
                    end
                end
            end
        end
    end
end

local function NewGroup()
    return { positions = {}, items = {}, family = 0 }
end

function ns.PhysicalSortNext(bank)
    local ids = bank and ns.BANK_IDS or ns.BAGS
    if type(ids) ~= "table" then return nil, "container list unavailable" end

    local groups, current = {}, {}
    local regularGroup
    local totalSlots = 0

    for _, bag in ipairs(ids) do
        local count = ns.GetNumSlots and ns.GetNumSlots(bag)
        local skipHidden = ns.Opt("sortSkipHidden") and ns.panel and ns.panel.IsContainerHidden
            and ns.panel.IsContainerHidden(bank and "bank" or "bags", bag)
        if type(count) == "number" and count > 0 and not skipHidden then
            local family = BagFamily(bag)
            local special = family == nil or family ~= 0 or
                (bank and ns.REAGENT_BANK_ID == bag) or
                (not bank and ns.IsQuiverBag and ns.IsQuiverBag(bag))
            local group
            if special then
                group = NewGroup()
                group.family = family
                groups[#groups + 1] = group
            else
                if not regularGroup then regularGroup = NewGroup() end
                group = regularGroup
            end

            for slot = 1, count do
                local info = ns.ItemInfo(bag, slot)
                if info and info.locked then return nil, "locked" end
                if info and not tonumber(info.id) then return nil, "item data unavailable" end
                -- a pinned item keeps its slot: it is left out of the plan, so nothing moves it, merges into it or
                -- sorts around its position
                local slotHidden = not bank and ns.panel and ns.panel.IsSlotHidden and ns.panel.IsSlotHidden("bags", bag, slot)
                -- a hidden slot keeps its slot too, so sorting never drops an item into a slot you cannot see
                if not slotHidden and not (info and ns.IsPinned and ns.IsPinned(info.id)) then
                    local position = { bag = bag, slot = slot, key = PositionKey(bag, slot) }
                    group.positions[#group.positions + 1] = position
                    totalSlots = totalSlots + 1
                    if info then
                        local item = { bag = bag, slot = slot, info = info, order = #group.items + 1, group = group }
                        group.items[#group.items + 1] = item
                        current[position.key] = item
                    end
                end
            end
        end
    end

    if regularGroup then groups[#groups + 1] = regularGroup end
    if totalSlots == 0 then return nil, "no available slots" end

    local merge, mergeStatus = FindStackMerge(groups)
    if merge or mergeStatus then return merge, mergeStatus end

    if not bank then
        local familyMove = FindFamilyMove(groups, regularGroup, current)
        if familyMove then return familyMove end
    end

    for _, group in ipairs(groups) do
        table.sort(group.items, ItemLess)
        for index, position in ipairs(group.positions) do
            local wanted = group.items[index]
            local found = current[position.key]
            if not SamePlacement(found, wanted) then
                if not wanted then return nil, "slot plan changed unexpectedly" end
                for sourceIndex = index + 1, #group.positions do
                    local sourcePosition = group.positions[sourceIndex]
                    if SamePlacement(current[sourcePosition.key], wanted) then
                        return {
                            sourceBag = sourcePosition.bag,
                            sourceSlot = sourcePosition.slot,
                            targetBag = position.bag,
                            targetSlot = position.slot,
                        }
                    end
                end
                return nil, "could not find a safe item move"
            end
        end
    end

    return nil, "done"
end
