-- Core.lua : options, bag reading, categories, prices and the "full in N min" estimate.
local _, ns = ...

-- chat message from GTBag (shared by the other files: ns.Say)
function ns.Say(text) print("|cffffd100GTBag|r: " .. text) end

-- GetItemInfo moved to C_Item.GetItemInfo on newer clients and the old global can be missing: one safe wrapper for every file
function ns.GetItemInfo(...)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(fn) ~= "function" then return nil end
    return fn(...)
end

ns.defaults = { view = "category", cols = 10, scale = 1, replace = true, ilvl = true, slotsRow = false, toolbar = false,
                replaceBank = true, replaceGuild = true, sort = "priority", ignoreEmpty = false,
                boe = true, pawn = true, boeCorner = "TOPLEFT", ilvlCorner = "BOTTOMLEFT",
                pawnCorner = "TOPRIGHT", badgePriority = "pawn,boe,ilvl", searchMode = "filter", warnFree = 5,
                liveActions = false, autoSort = false, mergeBags = false, scrambleNames = false, privacyAtLogin = false,
    autoSortVendor = false, autoSortBank = false, autoSortCombat = false,
                warnAmmo = 100, autoSellJunk = false, routeBags = true, sortSkipHidden = true, theme = "fresh", fadeMoving = false, moveAlpha = 0.35,
                style = "stack", blocks = 2, newGlow = true, newSection = false, hideInCombat = false, reopenAfterCombat = false,
                mailWatch = true, mailWarnDays = 3, mailSkipCOD = true }
-- window layout styles (where the sections go: see LayoutStyles.lua); the first entry is the default
ns.STYLES = {
    { "stack", "Stacked" }, { "columns", "Columns" }, { "flat", "One grid" }, { "list", "List" }, { "sidebar", "Sidebar" },
}
local validStyle = {}
for _, s in ipairs(ns.STYLES) do validStyle[s[1]] = true end
local validSort = { name = true, value = true, category = true, type = true, quality = true, qualitycategory = true,
                    expansion = true, itemlevel = true, count = true, priority = true }
local numericRanges = { cols = { 8, 15 }, scale = { 0.6, 1.6 }, warnFree = { 0, 20 }, warnAmmo = { 0, 2000 },
                        moveAlpha = { 0.1, 0.9 }, blocks = { 1, 4 }, mailWarnDays = { 1, 10 } }
local validCorners = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
local validBadgePriorities = {
    ["pawn,boe,ilvl"] = true, ["pawn,ilvl,boe"] = true, ["boe,pawn,ilvl"] = true,
    ["boe,ilvl,pawn"] = true, ["ilvl,pawn,boe"] = true, ["ilvl,boe,pawn"] = true,
}

function ns.IsHardcore()
    local ok, hc = pcall(function()
        return C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive()
    end)
    return ok and hc == true
end
function ns.CharacterKey(name, realm)
    name, realm = tostring(name or ""), tostring(realm or "")
    if name == "" or realm == "" then return nil end
    if ns.IsHardcore() then realm = realm .. "-Hardcore" end
    return name .. "-" .. realm
end

-- options saved per character instead of for the whole account: GTBagDB.charOpts["Name-Realm"][key]
local perCharacter = { hideInCombat = true, reopenAfterCombat = true }
local function CharOpts(create)
    if type(GTBagDB) ~= "table" then
        if not create then return nil end
        GTBagDB = {}
    end
    local key = ns.MyKey and ns.MyKey()
    if not key then return nil end
    local all = GTBagDB.charOpts
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        GTBagDB.charOpts = all
    end
    local mine = all[key]
    if type(mine) ~= "table" then
        if not create then return nil end
        mine = {}
        all[key] = mine
    end
    return mine
end

function ns.Opt(key)
    local v
    if perCharacter[key] then
        local mine = CharOpts(false)
        v = mine and mine[key]
    else
        v = GTBagDB and GTBagDB[key]
    end
    if v == nil then return ns.defaults[key] end
    local default = ns.defaults[key]
    if type(default) == "boolean" then
        if type(v) ~= "boolean" then return default end
    elseif type(default) == "number" then
        if type(v) ~= "number" then return default end
    elseif type(default) == "string" then
        if type(v) ~= "string" then return default end
    end
    local range = numericRanges[key]
    if range then
        if v < range[1] or v > range[2] then return default end
        if key == "cols" or key == "blocks" or key == "mailWarnDays" then return math.floor(v) end
    end
    if key == "style" and not validStyle[v] then return ns.defaults[key] end
    if key == "view" and v ~= "bag" and v ~= "category" then return ns.defaults[key] end
    if key == "sort" and not validSort[v] then return ns.defaults[key] end
    if key == "theme" and v ~= "fresh" and v ~= "gathertimes" then return ns.defaults[key] end
    if key == "searchMode" and v ~= "filter" and v ~= "dim" then return ns.defaults[key] end
    if (key == "boeCorner" or key == "ilvlCorner" or key == "pawnCorner") and not validCorners[v] then
        return ns.defaults[key]
    end
    if key == "badgePriority" and not validBadgePriorities[v] then return ns.defaults[key] end
    return v
end
function ns.SetOpt(key, value)
    if ns.defaults[key] == nil then return end
    GTBagDB = GTBagDB or {}
    local store = GTBagDB
    if perCharacter[key] then
        store = CharOpts(true)
        if not store then return end
    end
    if value == nil then store[key] = nil; return end
    local kind = type(ns.defaults[key])
    if kind == "boolean" then
        if type(value) ~= "boolean" then return end
    elseif kind == "number" then
        value = tonumber(value)
        if not value then return end
        local range = numericRanges[key]
        if range then value = math.max(range[1], math.min(range[2], value)) end
        if key == "cols" or key == "blocks" or key == "mailWarnDays" then value = math.floor(value) end
    elseif kind == "string" then
        if type(value) ~= "string" then return end
    end
    if key == "style" and not validStyle[value] then return end
    if key == "sort" and not validSort[value] then return end
    if key == "theme" and value ~= "fresh" and value ~= "gathertimes" then return end
    if key == "searchMode" and value ~= "filter" and value ~= "dim" then return end
    if (key == "boeCorner" or key == "ilvlCorner" or key == "pawnCorner") and not validCorners[value] then return end
    if key == "badgePriority" and not validBadgePriorities[value] then return end
    store[key] = value
    if key == "scrambleNames" and ns.NotifyPrivacy then ns.NotifyPrivacy() end
end

-- per-character options as a list { { characterKey, option, value }, ... } (used by the backup export)
function ns.CharOptList()
    local out = {}
    local all = GTBagDB and GTBagDB.charOpts
    if type(all) ~= "table" then return out end
    for charKey, mine in pairs(all) do
        if type(charKey) == "string" and type(mine) == "table" then
            for optKey in pairs(perCharacter) do
                if type(mine[optKey]) == "boolean" then out[#out + 1] = { charKey, optKey, mine[optKey] } end
            end
        end
    end
    table.sort(out, function(a, b)
        if a[1] ~= b[1] then return a[1] < b[1] end
        return a[2] < b[2]
    end)
    return out
end

-- backup import: sets one per-character option of any character; only known per-character options are accepted
function ns.ImportCharOpt(charKey, optKey, value)
    if type(charKey) ~= "string" or charKey == "" or #charKey > 80 or charKey:find("[\r\n]") then return false end
    if not perCharacter[optKey] or type(value) ~= "boolean" then return false end
    GTBagDB = GTBagDB or {}
    if type(GTBagDB.charOpts) ~= "table" then GTBagDB.charOpts = {} end
    if type(GTBagDB.charOpts[charKey]) ~= "table" then GTBagDB.charOpts[charKey] = {} end
    GTBagDB.charOpts[charKey][optKey] = value
    return true
end

local CONT = C_Container
ns.CONT = CONT
ns.GetNumSlots = (CONT and CONT.GetContainerNumSlots) or GetContainerNumSlots
ns.GetNumFree = (CONT and CONT.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
ns.ToInventoryID = (CONT and CONT.ContainerIDToInventoryID) or ContainerIDToInventoryID

-- the bags: backpack, the 4 bag slots and (retail) the reagent bag
ns.BAGS = {}
for b = 0, (NUM_BAG_SLOTS or 4) do ns.BAGS[#ns.BAGS + 1] = b end
local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
if reagent then ns.BAGS[#ns.BAGS + 1] = reagent end

-- the bank.  Older clients: the main bank (-1) and the bank bags that follow the bag slots.  Retail's new bank: only
-- the character bank tabs.  Which of these really exist is decided by their slot count when they are read.
ns.BANK_IDS = {}
do
    local tabs = {}
    local reagentBank = (Enum and Enum.BagIndex and (Enum.BagIndex.Reagentbank or Enum.BagIndex.ReagentBank))
        or REAGENTBANK_CONTAINER
    ns.REAGENT_BANK_ID = reagentBank
    local seen = {}
    if Enum and Enum.BagIndex then
        for name, id in pairs(Enum.BagIndex) do
            if type(name) == "string" and type(id) == "number" and name:lower():find("characterbanktab", 1, true) then
                tabs[#tabs + 1] = id
                seen[id] = true
            end
        end
    end
    table.sort(tabs)
    if #tabs > 0 then
        ns.BANK_IDS = tabs
    else
        ns.BANK_IDS[1] = (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or BANK_CONTAINER or -1
        local first = ns.BAGS[#ns.BAGS] + 1
        for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do ns.BANK_IDS[#ns.BANK_IDS + 1] = b end
        for _, id in ipairs(ns.BANK_IDS) do seen[id] = true end
    end
    if reagentBank and not seen[reagentBank] then ns.BANK_IDS[#ns.BANK_IDS + 1] = reagentBank end
end


-- the character bank tab ids, read from the game's enum once
local bankTabCache
function ns.BankTabIDs()
    if not bankTabCache then
        bankTabCache = {}
        if Enum and Enum.BagIndex then
            for name, tabID in pairs(Enum.BagIndex) do
                if type(name) == "string" and type(tabID) == "number" and name:lower():find("characterbanktab", 1, true) then
                    bankTabCache[#bankTabCache + 1] = tabID
                end
            end
        end
        table.sort(bankTabCache)
    end
    return bankTabCache
end

function ns.ContainerLabel(kind, id)
    if kind == "guild" then return "Guild tab " .. tostring(id) end
    if kind == "mail" then return "Mailbox" end
    if kind == "bags" then
        if id == 0 then return "Backpack" end
        local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
        if reagent and id == reagent then return "Reagent bag" end
        for i, bag in ipairs(ns.BAGS) do
            if bag == id then
                if i > 1 then return "Bag " .. (i - 1) end
            end
        end
        return "Bag"
    end
    if kind == "bank" then
        if Enum and Enum.BagIndex and Enum.BagIndex.Bank and id == Enum.BagIndex.Bank then return "Main bank" end
        if ns.REAGENT_BANK_ID and id == ns.REAGENT_BANK_ID then return "Reagent bank" end
        local tabs = ns.BankTabIDs()
        for i, tabID in ipairs(tabs) do
            if tabID == id then return "Bank tab " .. i end
        end
        for i, bag in ipairs(ns.BANK_IDS) do
            if bag == id then
                if i == 1 then return "Main bank" end
                return "Bank bag " .. (i - 1)
            end
        end
        return "Bank"
    end
    return tostring(id)
end

-- ---------------------------------------------------------------------------------------------- items
local qualityByLink = function(link)
    local q = link and select(3, ns.GetItemInfo(link))
    return type(q) == "number" and q or 1
end
ns.QualityOf = qualityByLink

-- item id of one slot without building a table (ItemInfo allocates one per call); nil when empty
local slotItemID = (CONT and CONT.GetContainerItemID) or GetContainerItemID
function ns.SlotItemID(bag, slot)
    if slotItemID then return slotItemID(bag, slot) end
    local i = ns.ItemInfo(bag, slot)
    return i and i.id
end

-- id and stack count of one slot without building a table (for loops that only add up counts); nil when empty
function ns.SlotCount(bag, slot)
    if CONT and CONT.GetContainerItemInfo then
        local i = CONT.GetContainerItemInfo(bag, slot)
        if i then return i.itemID, i.stackCount or 1 end
    elseif GetContainerItemInfo then
        local _, count, _, _, _, _, _, _, _, id = GetContainerItemInfo(bag, slot)
        if id then return id, count or 1 end
    end
end

-- { id, count, link, icon, quality, locked, bound } of one slot, or nil when it is empty.  Pass a table as `into` to
-- have it filled and returned instead of a new one: only for a caller that copies the fields out before the next call
-- (a scan loop); anything that keeps the record must not pass one.
function ns.ItemInfo(bag, slot, into)
    if CONT and CONT.GetContainerItemInfo then
        local i = CONT.GetContainerItemInfo(bag, slot)
        if not i then return nil end
        local quality = i.quality or qualityByLink(i.hyperlink)
        if into then
            into.id, into.count, into.link, into.icon = i.itemID, i.stackCount or 1, i.hyperlink, i.iconFileID
            into.quality, into.locked, into.bound = quality, i.isLocked, i.isBound
            return into
        end
        return { id = i.itemID, count = i.stackCount or 1, link = i.hyperlink, icon = i.iconFileID,
                 quality = quality, locked = i.isLocked, bound = i.isBound }
    elseif GetContainerItemInfo then
        local icon, count, locked, quality, _, _, link, _, _, id, bound = GetContainerItemInfo(bag, slot)
        if not id then return nil end
        if type(quality) ~= "number" or quality < 0 then quality = qualityByLink(link) end
        if into then
            into.id, into.count, into.link, into.icon = id, count or 1, link, icon
            into.quality, into.locked, into.bound = quality, locked, bound
            return into
        end
        return { id = id, count = count or 1, link = link, icon = icon, quality = quality, locked = locked, bound = bound }
    end
end

ns.CATS = {
    { "herbs", "Herbs" }, { "ore", "Ore" }, { "trade", "Trade goods" }, { "consumable", "Consumables" },
    { "quest", "Quest" }, { "equip", "Equipment" }, { "gem", "Gems" }, { "container", "Containers" },
    { "other", "Other" }, { "junk", "Junk" },
}
ns.CATLABEL = {}
for _, c in ipairs(ns.CATS) do ns.CATLABEL[c[1]] = c[2] end

local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local detailedItemLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
function ns.ItemLevel(info)
    if not (info and info.link and detailedItemLevel) then return nil end
    if type(info.sortItemLevel) == "number" then return info.sortItemLevel end
    local ok, level = pcall(detailedItemLevel, info.link)
    if ok and type(level) == "number" then
        info.sortItemLevel = level
        return level
    end
end

function ns.IsQuiverBag(bag)
    if bag == 0 or not (ns.ToInventoryID and GetInventoryItemID and instant) then return false end
    local inventoryID = ns.ToInventoryID(bag)
    local itemID = inventoryID and GetInventoryItemID("player", inventoryID)
    if not itemID then return false end
    local _, _, _, _, _, classID = instant(itemID)
    local quiverClass = Enum and Enum.ItemClass and Enum.ItemClass.Quiver or 11
    return classID == quiverClass
end

-- class / subclass by item id, kept in a bounded cache.  (GetItemInfoInstant has no expansion value: see ns.ItemExpansion.)
-- two generations: when the current one is full it becomes the old one and the old one is dropped, so a full cache
-- never empties all at once in the middle of a sort or a layout
local metaCache, metaOld = {}, {}
local metaCacheSize = 0
local ITEM_CACHE_LIMIT = 2048
function ns.ItemMeta(id)
    id = tonumber(id)
    if not id or not instant then return {} end
    local m = metaCache[id]
    if m then return m end
    m = metaOld[id]
    if not m then
        local _, _, _, _, _, class, sub = instant(id)
        m = { class = class, sub = sub }
    end
    if metaCacheSize >= ITEM_CACHE_LIMIT then
        metaOld, metaCache = metaCache, metaOld
        wipe(metaCache)
        metaCacheSize = 0
    end
    metaCache[id] = m
    metaCacheSize = metaCacheSize + 1
    return m
end

-- expansion id of an item: the 15th return value of GetItemInfo, which only has a value once the item is in the client
-- cache.  A found value is kept in a bounded cache; nil means "not known yet" (the item data is requested so a later
-- sort can use it) and is never cached.
local expCache, expCacheSize, expRequested, expRequestedSize = {}, 0, {}, 0
function ns.ItemExpansion(id)
    id = tonumber(id)
    if not id then return nil end
    local v = expCache[id]
    if v ~= nil then return v end
    v = select(16, pcall(ns.GetItemInfo, id))         -- 16 = pcall's status + the 15th return value
    if type(v) == "number" then
        if expCacheSize >= ITEM_CACHE_LIMIT then
            wipe(expCache)
            expCacheSize = 0
        end
        expCache[id] = v
        expCacheSize = expCacheSize + 1
        return v
    end
    if not expRequested[id] then
        if expRequestedSize >= 512 then
            wipe(expRequested)
            expRequestedSize = 0
        end
        expRequested[id] = true
        expRequestedSize = expRequestedSize + 1
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    return nil
end
-- the built-in category (what the game says the item is); badges, sorting by item level and the Gatherer totals use this
function ns.BaseCategory(info)
    if info.baseCat then return info.baseCat end
    local cat = "other"
    if info.quality == 0 then
        cat = "junk"
    else
        local m = ns.ItemMeta(info.id)
        local classID, subID = m.class, m.sub
        if classID == 7 then
            cat = subID == 9 and "herbs" or (subID == 7 and "ore" or "trade")
        elseif classID == 0 then cat = "consumable"
        elseif classID == 12 then cat = "quest"
        elseif classID == 2 or classID == 4 then cat = "equip"
        elseif classID == 3 then cat = "gem"
        elseif classID == 1 or classID == 11 then cat = "container" end
    end
    info.baseCat = cat
    return cat
end

-- ---------------------------------------------------------------------------------------------- custom categories
-- GTBagDB.customCats = { { id = 1, name = "Alchemy", rules = { 2447, "silverleaf" } }, ... }
-- a rule is an item id (number) or text that must be part of the item's name (lower case).  The first custom category
-- with a matching rule wins; everything else keeps its built-in category.  Custom keys look like "c:1".
local function CustomList()
    local l = GTBagDB and GTBagDB.customCats
    if type(l) ~= "table" then return nil end
    return l
end
function ns.CustomCats() return CustomList() or {} end

function ns.Category(info)
    if info.cat then return info.cat end
    local list = CustomList()
    if list and #list > 0 then
        local lname
        for _, c in ipairs(list) do
            for _, rule in ipairs(type(c.rules) == "table" and c.rules or {}) do
                if type(rule) == "number" then
                    if tonumber(info.id) == rule then info.cat = "c:" .. c.id; return info.cat end
                elseif type(rule) == "string" and rule:sub(1, 1) == "?" then
                    -- a saved search (Query.lua): "?herb & value<50s"
                    if ns.QueryMatch then
                        -- catBusy: Query.lua must not ask for this item's category while the rule is being evaluated
                        info.catBusy = true
                        local ok, hit = pcall(ns.QueryMatch, info, rule:sub(2))
                        info.catBusy = nil
                        if not ok then error(hit, 0) end
                        if hit then info.cat = "c:" .. c.id; return info.cat end
                    end
                elseif type(rule) == "string" and rule ~= "" then
                    lname = lname or ns.LowerName(info)
                    if lname:find(rule, 1, true) then info.cat = "c:" .. c.id; return info.cat end
                end
            end
        end
    end
    info.cat = ns.BaseCategory(info)
    return info.cat
end

function ns.CatLabel(key)
    if type(key) == "string" and key:sub(1, 2) == "c:" then
        local id = tonumber(key:sub(3))
        for _, c in ipairs(ns.CustomCats()) do
            if c.id == id then return c.name end
        end
        return "Custom"
    end
    return ns.CATLABEL[key]
end

-- custom categories first (in the order they were made), then the built-in ones: { { key, label }, ... }
function ns.AllCats()
    local out = {}
    for _, c in ipairs(ns.CustomCats()) do out[#out + 1] = { "c:" .. c.id, c.name } end
    for _, c in ipairs(ns.CATS) do out[#out + 1] = c end
    return out
end

-- "peacebloom, 2447, [shift-clicked link]" -> { "peacebloom", 2447, ... }
function ns.ParseCatRules(text)
    local rules = {}
    for token in tostring(text or ""):gmatch("[^,]+") do
        token = token:match("^%s*(.-)%s*$")
        local id = token:match("item:(%d+)") or token:match("^#?(%d+)$")
        if id then
            rules[#rules + 1] = tonumber(id)
        elseif token ~= "" then
            rules[#rules + 1] = token:lower():sub(1, token:sub(1, 1) == "?" and 120 or 40)
        end
    end
    return rules
end

local function FindCustom(name)
    name = tostring(name or ""):lower()
    for i, c in ipairs(ns.CustomCats()) do
        if c.name:lower() == name then return c, i end
    end
end
local function AddRules(c, rules)
    local have = {}
    for _, r in ipairs(c.rules) do have[tostring(r)] = true end
    for _, r in ipairs(rules) do
        if not have[tostring(r)] then c.rules[#c.rules + 1] = r; have[tostring(r)] = true end
    end
end

-- these return true or false, message
function ns.CatSave(name, rulesText)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then return false, "give the category a name." end
    name = name:gsub("|", ""):sub(1, 24)
    local rules = ns.ParseCatRules(rulesText)
    if #rules == 0 then return false, "give at least one rule: an item id, a shift-clicked item or part of a name." end
    GTBagDB = GTBagDB or {}
    GTBagDB.customCats = CustomList() or {}
    local c = FindCustom(name)
    if not c then
        local nextId = 0
        for _, e in ipairs(GTBagDB.customCats) do nextId = math.max(nextId, tonumber(e.id) or 0) end
        if #GTBagDB.customCats >= 20 then return false, "at most 20 custom categories." end
        c = { id = nextId + 1, name = name, rules = {} }
        GTBagDB.customCats[#GTBagDB.customCats + 1] = c
    end
    AddRules(c, rules)
    return true, string.format('category "%s" now has %d rule(s).', c.name, #c.rules)
end
function ns.CatCreate(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    name = name:gsub("|", ""):sub(1, 24)
    if name == "" then return false, "give the category a name." end
    if FindCustom(name) then return true, "that category already exists.", FindCustom(name) end
    GTBagDB = GTBagDB or {}
    GTBagDB.customCats = CustomList() or {}
    if #GTBagDB.customCats >= 20 then return false, "at most 20 custom categories." end
    local nextId = 0
    for _, e in ipairs(GTBagDB.customCats) do nextId = math.max(nextId, tonumber(e.id) or 0) end
    local c = { id = nextId + 1, name = name, rules = {} }
    GTBagDB.customCats[#GTBagDB.customCats + 1] = c
    return true, string.format('category "%s" created.', name), c
end
function ns.CatRemoveRules(name, rulesText)
    local c = FindCustom(name)
    if not c then return false, "no such category." end
    local drop = {}
    for _, r in ipairs(ns.ParseCatRules(rulesText)) do drop[tostring(r)] = true end
    local kept = {}
    for _, r in ipairs(c.rules) do if not drop[tostring(r)] then kept[#kept + 1] = r end end
    c.rules = kept
    return true, string.format('category "%s" has %d rule(s).', c.name, #kept)
end
function ns.CatDelete(name)
    local c, i = FindCustom(name)
    if not c then return false, "no such category." end
    table.remove(GTBagDB.customCats, i)
    return true, string.format('category "%s" deleted.', c.name)
end

local categoryRank = {}
for i, category in ipairs(ns.CATS) do categoryRank[category[1]] = i end
local function CatRank(cat)
    if categoryRank[cat] then return categoryRank[cat] end
    if type(cat) == "string" and cat:sub(1, 2) == "c:" then return 0 end   -- custom categories sort first
    return categoryRank.other
end

local function SortMetadata(info)
    if info.sortClass then return info.sortClass, info.sortSubclass, info.expansion end
    local m = ns.ItemMeta(info.id)
    local classID, subID = m.class, m.sub
    info.sortClass = tonumber(classID) or 99
    info.sortSubclass = tonumber(subID) or 99
    info.expansion = ns.ItemExpansion(info.id)         -- fixed for this info table, so one sort pass stays consistent
    return info.sortClass, info.sortSubclass, info.expansion
end

-- "priority" sort tiers: 1 Hearthstone, 2 mounts, 3 Chronoboon Displacer, 4 buffs (elixirs, flasks, scrolls...),
-- 5 food and drink, 6 potions, 7 gear (weapons + armor), 8 everything else. Poor-quality (junk) items sort last under every rule.
local HEARTHSTONE_ID = 6948
local CHRONOBOON_ID = 184937
local TIER_OTHER = 8

-- Classic item data is not always filed under the right type, so some checks also look at the tooltip text and name.
local scanTip
local tipCache, tipCacheSize = {}, 0
local TIP_CACHE_LIMIT = 512
local tipPending = false        -- set when a tooltip read came back empty (item data not loaded yet), so the answer is provisional
-- Only two facts are kept per item (mount? food?), not the tooltip text itself: that is a few bytes per item instead of
-- a few hundred.
local function TooltipFlags(info)
    local id = tonumber(info.id)
    if not id or not CreateFrame then return nil end
    local cached = tipCache[id]
    if cached then return cached end
    scanTip = scanTip or CreateFrame("GameTooltip", "GTBagScanTooltip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    local ok = pcall(scanTip.SetHyperlink, scanTip, "item:" .. id)
    local lines = ok and scanTip:NumLines() or 0
    local mount, food = false, false
    for i = 2, lines do
        local fontString = _G["GTBagScanTooltipTextLeft" .. i]
        local text = fontString and fontString:GetText()
        if text then
            text = text:lower()
            if text:find("this mount", 1, true) or text:find("how to ride", 1, true) or text:find("rideable", 1, true) then
                mount = true
            end
            if text:find("while eating", 1, true) or text:find("while drinking", 1, true)
                or text:find("must remain seated", 1, true) then
                food = true
            end
        end
    end
    scanTip:Hide()
    local flags = { mount = mount, food = food }
    if lines > 0 then
        if tipCacheSize >= TIP_CACHE_LIMIT then wipe(tipCache); tipCacheSize = 0 end
        tipCache[id] = flags
        tipCacheSize = tipCacheSize + 1
    else                        -- tooltip data not loaded yet: do not remember an empty answer, and mark it provisional
        tipPending = true
    end
    return flags
end

local function IsMount(info)
    local f = TooltipFlags(info)
    return f and f.mount
end

local potionWord
local function IsPotionByName(info)
    if potionWord == nil then
        potionWord = (GetItemSubClassInfo and GetItemSubClassInfo(0, 1)) or "Potion"
    end
    local name = ns.Name(info)
    return name:find(potionWord, 1, true) ~= nil or name:find("Potion", 1, true) ~= nil
end

local buffNames = { "Elixir", "Flask", "Scroll of", "Juju", "Firewater", "Sharpening Stone", "Weightstone",
                    "Oil", "Blessed Sunfruit", "Mageblood", "Greater Arcane", "Spirit of Zanza", "Sheen of Zanza",
                    "Swiftness of Zanza" }
local function IsBuffByName(info)
    local name = ns.Name(info)
    for _, word in ipairs(buffNames) do
        if name:find(word, 1, true) then return true end
    end
    return false
end

local function IsFood(info)
    local f = TooltipFlags(info)
    return f and f.food
end

local function IsChronoboon(info)
    if tonumber(info.id) == CHRONOBOON_ID then return true end
    local name = ns.Name(info)
    return type(name) == "string" and name:find("Chronoboon Displacer", 1, true) ~= nil
end

local function ComputeTier(info)
    if tonumber(info.id) == HEARTHSTONE_ID then return 1 end
    local m = ns.ItemMeta(info.id)
    local classID, subID = m.class, m.sub
    if classID == 15 and (subID == 5 or IsMount(info)) then return 2 end -- Miscellaneous > Mount
    if IsChronoboon(info) then return 3 end                                -- Chronoboon Displacer
    if classID == 0 then
        if subID == 2 or subID == 3 or subID == 4 or IsBuffByName(info) then return 4 end -- Elixir, Flask, Scroll, buff
        if subID == 5 or IsFood(info) then return 5 end                     -- Food & Drink
        if subID == 1 or IsPotionByName(info) then return 6 end            -- Potion
    end
    if classID == 2 or classID == 4 then return 7 end                       -- Weapon / Armor
    return TIER_OTHER
end

-- The tier is worked out once per item, not once per comparison: table.sort calls the comparator many times and the
-- answer must not change in the middle of a sort (an inconsistent comparator can raise "invalid order function" or make the
-- physical sort plan oscillate).
--   info.sortTier   a settled tier, kept on the info table (like sortClass / sortItemLevel)
--   tierCache       settled tiers by item id, bounded
--   tierTemp        provisional tiers (a mount / food check needed a tooltip that was not loaded yet), by item id, for
--                   the current frame only: every comparison inside one sort sees the same value, and the next frame
--                   looks again.
local tierCache, tierCacheSize = {}, 0
local tierTemp, tierTempClearing = {}, false
local TIER_CACHE_LIMIT = 2048
local function ClearTierTemp()
    wipe(tierTemp)
    tierTempClearing = false
end

local function PriorityTier(info)
    local tier = info.sortTier
    if tier then return tier end
    local id = tonumber(info.id)
    if id then
        tier = tierCache[id]
        if tier then
            info.sortTier = tier
            return tier
        end
        tier = tierTemp[id]
        if tier then return tier end
    end
    tipPending = false
    tier = ComputeTier(info)
    if not id then return tier end
    if tipPending then
        tipPending = false
        tierTemp[id] = tier
        if not tierTempClearing then
            tierTempClearing = true
            C_Timer.After(0, ClearTierTemp)
        end
    else
        if tierCacheSize >= TIER_CACHE_LIMIT then
            wipe(tierCache)
            tierCacheSize = 0
        end
        tierCache[id] = tier
        tierCacheSize = tierCacheSize + 1
        info.sortTier = tier
    end
    return tier
end
ns.PriorityTier = PriorityTier

-- This comparator drives GTBag's display and physical sort order.
function ns.ItemCompare(a, b, rule)
    local aJunk, bJunk = tonumber(a.info.quality) == 0, tonumber(b.info.quality) == 0
    if aJunk ~= bJunk then return not aJunk end

    rule = rule or ns.Opt("sort")
    if rule == "priority" then
        -- Hearthstone, mounts, potions, buffs, food, gear: highest quality first inside each tier.
        -- Everything else: A-Z by name, then the larger stack first (the tail below).
        local at, bt = PriorityTier(a.info), PriorityTier(b.info)
        if at ~= bt then return at < bt end
        if at < TIER_OTHER then
            local aq, bq = tonumber(a.info.quality) or 1, tonumber(b.info.quality) or 1
            if aq ~= bq then return aq > bq end
        end
    elseif rule == "quality" then
        local aq, bq = tonumber(a.info.quality) or 1, tonumber(b.info.quality) or 1
        if aq ~= bq then return aq > bq end
    elseif rule == "qualitycategory" then
        local aq, bq = tonumber(a.info.quality) or 1, tonumber(b.info.quality) or 1
        if aq ~= bq then return aq > bq end
        local ac = CatRank(ns.Category(a.info))
        local bc = CatRank(ns.Category(b.info))
        if ac ~= bc then return ac < bc end
    elseif rule == "count" then
        local ac, bc = tonumber(a.info.count) or 1, tonumber(b.info.count) or 1
        if ac ~= bc then return ac > bc end
    elseif rule == "value" then
        if a.info.sortValue == nil then a.info.sortValue = ns.UnitValue(a.info.id, a.info.link) * (a.info.count or 1) end
        if b.info.sortValue == nil then b.info.sortValue = ns.UnitValue(b.info.id, b.info.link) * (b.info.count or 1) end
        if a.info.sortValue ~= b.info.sortValue then return a.info.sortValue > b.info.sortValue end
    elseif rule == "category" then
        local ac = CatRank(ns.Category(a.info))
        local bc = CatRank(ns.Category(b.info))
        if ac ~= bc then return ac < bc end
    elseif rule == "itemlevel" then
        local ae, be = ns.BaseCategory(a.info) == "equip", ns.BaseCategory(b.info) == "equip"
        if ae ~= be then return ae end
        if ae then
            local al, bl = ns.ItemLevel(a.info) or 0, ns.ItemLevel(b.info) or 0
            if al ~= bl then return al > bl end
        end
    elseif rule == "type" then
        local ac, as = SortMetadata(a.info)
        local bc, bs = SortMetadata(b.info)
        if ac ~= bc then return ac < bc end
        if as ~= bs then return as < bs end
    elseif rule == "expansion" then
        local _, _, ae = SortMetadata(a.info)
        local _, _, be = SortMetadata(b.info)
        ae, be = ae or math.huge, be or math.huge
        if ae ~= be then return ae < be end
    end
    local an, bn = ns.LowerName(a.info), ns.LowerName(b.info)
    if an ~= bn then return an < bn end
    local ai, bi = tonumber(a.info.id) or 0, tonumber(b.info.id) or 0
    if ai ~= bi then return ai < bi end
    return (a.info.count or 1) > (b.info.count or 1)
end

-- item name from the link.  The name and its lower-case form are cached per link in a bounded table: the sort
-- comparator and the search used to build new strings for every comparison and every button refresh.
-- Two generations each: a full cache is kept as the "old" one and only dropped at the next rollover, so the names in
-- use stay cached instead of everything being thrown away at once.
local nameCache, nameOld, lowerNameCache, lowerNameOld, nameCacheSize = {}, {}, {}, {}, 0
local NAME_CACHE_LIMIT = 1024
function ns.Name(info)
    local link = info.link
    if link then
        local n = nameCache[link]
        if n then return n end
        n = nameOld[link] or link:match("%[(.-)%]")
        if n then
            if nameCacheSize >= NAME_CACHE_LIMIT then
                nameOld, nameCache = nameCache, nameOld
                lowerNameOld, lowerNameCache = lowerNameCache, lowerNameOld
                wipe(nameCache); wipe(lowerNameCache); nameCacheSize = 0
            end
            nameCache[link] = n
            nameCacheSize = nameCacheSize + 1
            return n
        end
    end
    return "Item " .. tostring(info.id)
end

function ns.LowerName(info)
    local link = info.link
    local n = ns.Name(info)
    if not link then return n:lower() end
    local l = lowerNameCache[link]
    if not l then
        l = lowerNameOld[link] or n:lower()
        lowerNameCache[link] = l        -- rolled over together with nameCache, so it stays bounded
    end
    return l
end

-- ---------------------------------------------------------------------------------------------- slots and value
function ns.Slots()
    local free, total = 0, 0
    if not (ns.GetNumSlots and ns.GetNumFree) then return 0, 0 end
    for _, bag in ipairs(ns.BAGS) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" and n > 0 then
            total = total + n
            local f = ns.GetNumFree(bag)
            if type(f) == "number" then free = free + f end
        end
    end
    return free, total
end

-- free / total slots in the general-purpose bags only: quivers, ammo pouches and other family bags are left out
-- because an empty arrow slot cannot take loot
function ns.GeneralSlots()
    local free, total = 0, 0
    if not (ns.GetNumSlots and ns.GetNumFree) then return 0, 0 end
    for _, bag in ipairs(ns.BAGS) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" and n > 0 then
            local ok, f, bagType = pcall(ns.GetNumFree, bag)
            local family = bagType
            if ok and (tonumber(family) or 0) == 0 then
                total = total + n
                if type(f) == "number" then free = free + f end
            end
        end
    end
    return free, total
end

-- arrows and bullets: bags plus the equipped ammo slot (Classic).  Returns { arrows = n, bullets = n }
local PROJECTILE = (Enum and Enum.ItemClass and Enum.ItemClass.Projectile) or 6
local ammoCounts = { arrows = 0, bullets = 0 }          -- reused: this runs on every bag update
local ammoKind = { [2] = "arrows", [3] = "bullets" }      -- projectile subclasses
function ns.AmmoCounts()
    local counts, kind = ammoCounts, ammoKind
    counts.arrows, counts.bullets = 0, 0
    if ns.GetNumSlots and ns.ItemInfo then
        for _, bag in ipairs(ns.BAGS) do
            local n = ns.GetNumSlots(bag)
            if type(n) == "number" then
                for slot = 1, n do
                    -- the id is read without allocating; a full item record is built only for arrows and bullets
                    local id = ns.SlotItemID(bag, slot)
                    if id then
                        local m = ns.ItemMeta(id)
                        local k = m.class == PROJECTILE and kind[m.sub]
                        if k then
                            local _, count = ns.SlotCount(bag, slot)
                            counts[k] = counts[k] + (tonumber(count) or 1)
                        end
                    end
                end
            end
        end
    end
    if GetInventoryItemID and GetInventoryItemCount then
        local ok, id = pcall(GetInventoryItemID, "player", 0)      -- 0 = ammo slot (only exists on older clients)
        if ok and id then
            local m = ns.ItemMeta(id)
            local k = m.class == PROJECTILE and kind[m.sub]
            local okc, c = pcall(GetInventoryItemCount, "player", 0)
            if k and okc and tonumber(c) then counts[k] = counts[k] + c end
        end
    end
    return counts
end

-- one warning per type when your arrows or bullets run low; it comes back once you are above the limit again.  A type
-- is only watched after you have carried some this session, so non-hunters never see it.
local ammoSeen, ammoWarned = {}, {}
local AMMO_ORDER = { "arrows", "bullets" }
-- Ammo only exists on the older clients, and only these classes use it.  Everyone else never gets the check, so the
-- bags are not scanned on every bag update just to count nothing.  (The window still shows ammo you carry.)
local AMMO_CLASSES = { HUNTER = true, ROGUE = true, WARRIOR = true }
local ammoPossible
local function AmmoPossible()
    if ammoPossible == nil then
        local toc = select(4, GetBuildInfo())
        local _, class = UnitClass("player")
        ammoPossible = (type(toc) ~= "number" or toc < 50000) and AMMO_CLASSES[class] == true
    end
    return ammoPossible
end
function ns.CheckAmmo()
    local limit = ns.Opt("warnAmmo")
    if limit <= 0 then return end
    if not AmmoPossible() then return end
    if GetCursorInfo and GetCursorInfo() then return end      -- a stack in your hand (sorting) would look like a shortage
    local counts = ns.AmmoCounts()
    for _, k in ipairs(AMMO_ORDER) do
        local n = counts[k]
        if n > 0 then ammoSeen[k] = true end
        if ammoSeen[k] and n <= limit then
            if not ammoWarned[k] then
                ammoWarned[k] = true
                local text = n == 0 and ("you are out of " .. k .. ".") or string.format("low on %s: only %d left.", k, n)
                print("|cffffd100GTBag|r: |cffff4040" .. text .. "|r")
                if UIErrorsFrame and UIErrorsFrame.AddMessage then
                    pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, "GTBag: " .. text, 1, 0.25, 0.25)
                end
            end
        elseif n > limit then
            ammoWarned[k] = nil
        end
    end
end

-- name-independent item facts (vendor price, bind type, type / subtype names), kept in a bounded cache
local factCache = {}
local factCacheSize = 0
function ns.ItemFacts(id, link)
    id = tonumber(id)
    if not id then return nil end
    local f = factCache[id]
    if f then return f end
    local name, _, _, _, _, typeName, subType, _, _, _, vendor, _, _, bindType = ns.GetItemInfo(link or id)
    if not name then return nil end
    if factCacheSize >= ITEM_CACHE_LIMIT then
        wipe(factCache)
        factCacheSize = 0
    end
    f = { vendor = tonumber(vendor) or 0, bind = tonumber(bindType), type = typeName, sub = subType }
    factCache[id] = f
    factCacheSize = factCacheSize + 1
    return f
end

-- copper per item: the GatherTimes auction scan when it is installed and higher than the vendor price
function ns.UnitValue(id, link)
    local ah
    local gt = _G.GatherTimesAddon
    if gt and gt.ScanPrice then
        local ok, p = pcall(gt.ScanPrice, id)
        if ok and type(p) == "number" and p > 0 then ah = p end
    end
    local facts = ns.ItemFacts(id, link)
    local vendor = facts and facts.vendor or 0
    if ah and ah >= vendor then return ah, "AH" end
    if vendor > 0 then return vendor, "vendor" end
    return 0, nil
end

-- "3 d ago" style age of a time() stamp
function ns.Ago(t)
    if not t then return "never" end
    local d = math.max(0, time() - t)
    if d < 90 then return "just now" end
    if d < 5400 then return string.format("%d min ago", math.floor(d / 60 + 0.5)) end
    if d < 86400 then return string.format("%d h ago", math.floor(d / 3600 + 0.5)) end
    return string.format("%d d ago", math.floor(d / 86400 + 0.5))
end

-- display-only scrambling of a name: the same name always gives the same scrambled text (so redraws do not flicker),
-- and nothing saved is changed.  The result is random letters a-z with a capital first letter.
local function ComputeScramble(name)
    local chars = {}
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    local n = #chars
    if n < 1 then return name end
    local seed = 7 + (ns.scrambleSalt or 0) * 7919   -- the salt changes on every Scramble click
    for i = 1, #name do seed = (seed * 31 + name:byte(i)) % 2147483629 end
    local function Rand(m)
        seed = (seed * 16807) % 2147483647
        return seed % m + 1
    end
    -- random letters a-z, same length as the name, first letter capital (the same name always gives the same text)
    local out = {}
    for i = 1, n do
        local c = string.char(96 + Rand(26))
        out[i] = (i == 1) and c:upper() or c
    end
    local s = table.concat(out)
    if s == name then s = (s:sub(1, 1) == "Z" and "A" or string.char(s:byte(1) + 1)) .. s:sub(2) end   -- never unchanged
    return s
end

-- The scrambled text of a name is kept (bounded) until the salt changes: the selector, the tooltips and the search
-- window ask for the same few names over and over, and building one allocates several tables and strings.
local scrambleCache, scrambleCacheSalt, scrambleCacheSize = {}, nil, 0
function ns.Scramble(name)
    name = tostring(name or "")
    if name == "" then return name end
    local salt = ns.scrambleSalt or 0
    if scrambleCacheSalt ~= salt then
        wipe(scrambleCache); scrambleCacheSalt = salt; scrambleCacheSize = 0
    end
    local s = scrambleCache[name]
    if s then return s end
    s = ComputeScramble(name)
    if scrambleCacheSize >= 256 then wipe(scrambleCache); scrambleCacheSize = 0 end
    scrambleCache[name] = s
    scrambleCacheSize = scrambleCacheSize + 1
    return s
end

-- a character record's name in its class colour
-- useNick: show the nickname (if any) instead of the real name, scrambled when the Scramble names option is on
local classPrefix = {}          -- "|cffrrggbb" per class token, built once
local function ClassPrefix(class)
    local p = classPrefix[class]
    if p == nil then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            p = string.format("|cff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
        else
            p = false
        end
        classPrefix[class] = p
    end
    return p
end
function ns.ClassName(rec, withRealm, useNick)
    if not rec then return "?" end
    local prefix = rec.class and ClassPrefix(rec.class)
    local name = rec.name or "?"
    if useNick then
        if type(rec.nick) == "string" and rec.nick ~= "" then name = rec.nick end
        if ns.Opt("scrambleNames") then name = ns.Scramble(name) end
    end
    if withRealm and rec.realm then
        local realm = rec.realm
        if useNick and ns.Privacy() then realm = ns.Scramble(realm) end
        name = name .. " - " .. realm
    end
    if prefix then return prefix .. name .. "|r" end
    return name
end

-- privacy mode (the old "Scramble names" option, saved as scrambleNames): hides character names, gold amounts and
-- guild names everywhere GTBag shows them, so a screenshot is safe to share.  Display-only; nothing saved changes.
function ns.Privacy() return ns.Opt("scrambleNames") and true or false end

-- the public API (GTBagAPI, defined by the loader) answers from here once the core is loaded, and other addons are told
-- when Privacy mode changes.  The call is deferred one frame so the new scramble salt is already in place.
if _G.GTBagAPI then
    _G.GTBagAPI._isPrivacy = ns.Privacy
    _G.GTBagAPI._scramble = ns.Scramble
end
local privacyNotifyQueued = false
-- Blizzard's own character and pet names (under the portraits) are scrambled too, with the same scrambled
-- name the GTBag windows show. Both text setters are watched, because Blizzard sets the character name in more
-- than one way; the real name is replaced wherever it appears in the text. Turning privacy off restores the names.
local BLIZZ_NAME_SOURCES = {
    { path = "PlayerName", unit = "player" },
    { path = "PlayerFrameName", unit = "player" },
    { path = "PlayerFrameTextureFrameName", unit = "player" },
    { path = "CharacterNameText", unit = "player" },
    { path = "CharacterFrameTitleText", unit = "player" },
    { path = "CharacterFrame.TitleContainer.TitleText", unit = "player" },
    { path = "PetName", unit = "pet" },
    { path = "PetFrameName", unit = "pet" },
}
local blizzApplying = false
local blizzHooked = {}

local function PlainReplace(text, from, to)
    if not text or not from or from == "" then return text end
    local out, pos = {}, 1
    local i, j = text:find(from, 1, true)
    while i do
        out[#out + 1] = text:sub(pos, i - 1)
        out[#out + 1] = to
        pos = j + 1
        i, j = text:find(from, pos, true)
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out)
end

local function BlizzRegion(path)
    local obj = _G
    for part in path:gmatch("[^%.]+") do
        if type(obj) ~= "table" and type(obj) ~= "userdata" then return nil end
        obj = obj[part]
    end
    return obj
end

-- the text of a region with the real name scrambled, or nil when nothing needs to change
local function ScrambledText(text, unit)
    if not ns.Privacy() or not text or text == "" then return nil end
    if unit == "pet" and not UnitExists("pet") then return nil end
    local real = UnitName(unit)
    if not real or real == "" or not text:find(real, 1, true) then return nil end
    return PlainReplace(text, real, ns.Scramble(real)), real
end

local function ScrambleRegion(fs)
    local cur = fs:GetText()
    if fs.gtPair and ns.Privacy() and cur and cur:find(fs.gtPair.scr, 1, true) then
        local oldScr, real = fs.gtPair.scr, fs.gtPair.real
        local newScr = ns.Scramble(real)
        blizzApplying = true
        fs:SetText(PlainReplace(cur, oldScr, newScr))
        blizzApplying = false
        fs.gtPair.scr = newScr
        return
    end
    local new, real = ScrambledText(cur, fs.gtUnit)
    if not new or new == cur then return end
    fs.gtPair = { real = real, scr = ns.Scramble(real) }
    blizzApplying = true
    fs:SetText(new)
    blizzApplying = false
end

function ns.ApplyBlizzardNames()
    for _, src in ipairs(BLIZZ_NAME_SOURCES) do
        local fs = BlizzRegion(src.path)
        if fs and fs.SetText then
            fs.gtUnit = src.unit
            if not blizzHooked[fs] then
                blizzHooked[fs] = true
                local function watch(self)
                    if blizzApplying or not self.gtUnit then return end
                    ScrambleRegion(self)
                end
                hooksecurefunc(fs, "SetText", watch)
                if fs.SetFormattedText then hooksecurefunc(fs, "SetFormattedText", watch) end
            end
            if ns.Privacy() then
                ScrambleRegion(fs)
            elseif fs.gtPair then
                local cur = fs:GetText()
                blizzApplying = true
                fs:SetText(PlainReplace(cur, fs.gtPair.scr, fs.gtPair.real))
                blizzApplying = false
                fs.gtPair = nil
            end
        end
    end
    -- the character frame may set its names when it opens
    local cf = _G.CharacterFrame
    if cf and cf.HookScript and not blizzHooked[cf] then
        blizzHooked[cf] = true
        cf:HookScript("OnShow", function() ns.ApplyBlizzardNames() end)
    end
end

-- Privacy on: the player's own name and the pet's name above their heads are hidden (nameplate CVars).
-- The values the player had are saved first and put back when privacy is turned off.
local NAMEPLATE_CVARS = { "UnitNameOwn", "UnitNameFriendlyPetName" }

function ns.ApplyNameplateHide()
    if not GTBagDB then return end
    local saved = type(GTBagDB.nameCVars) == "table" and GTBagDB.nameCVars or {}
    GTBagDB.nameCVars = saved
    for _, cvar in ipairs(NAMEPLATE_CVARS) do
        if ns.Privacy() then
            if saved[cvar] == nil and GetCVar then
                local cur = GetCVar(cvar)
                if cur ~= nil then saved[cvar] = tostring(cur) end
            end
            if saved[cvar] ~= nil then pcall(SetCVar, cvar, "0") end
        elseif saved[cvar] ~= nil then
            pcall(SetCVar, cvar, saved[cvar])
            saved[cvar] = nil
        end
    end
end

function ns.NotifyPrivacy()
    if ns.RefreshPrivacyTag then ns.RefreshPrivacyTag() end
    if ns.ApplyBlizzardNames then ns.ApplyBlizzardNames() end
    if ns.ApplyNameplateHide then ns.ApplyNameplateHide() end
    local api = _G.GTBagAPI
    if not (api and api.Fire) or privacyNotifyQueued then return end
    if not (C_Timer and C_Timer.After) then api.Fire(ns.Privacy()); return end
    privacyNotifyQueued = true
    C_Timer.After(0, function()
        privacyNotifyQueued = false
        api.Fire(ns.Privacy())
    end)
end

-- a guild name as it should be shown (scrambled in privacy mode)
function ns.GuildName(name)
    name = tostring(name or "")
    if name ~= "" and ns.Privacy() then return ns.Scramble(name) end
    return name
end

-- "12g 40s" / "40s 5c" / "5c" for list rows (hidden in privacy mode)
function ns.ShortMoney(c)
    if ns.Privacy() then return "|cff888888*****|r" end
    c = math.floor(tonumber(c) or 0)
    local g, s, k = math.floor(c / 10000), math.floor(c % 10000 / 100), c % 100
    if g > 0 then return string.format("|cffffd100%d|rg |cffc7c7cf%d|rs", g, s) end
    if s > 0 then return string.format("|cffc7c7cf%d|rs |cffeda55f%d|rc", s, k) end
    return string.format("|cffeda55f%d|rc", k)
end

function ns.Money(c)
    if ns.Privacy() then return "|cff888888*****|r" end
    c = tonumber(c) or 0
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return string.format("%dg %ds %dc", math.floor(c / 10000), math.floor(c % 10000 / 100), math.floor(c % 100))
end

-- footer style money: 1090 70 98 with the gold, silver and copper coin icon after each amount
function ns.MoneyDots(c)
    if ns.Privacy() then return "|cff888888*****|r" end
    c = math.max(0, math.floor(tonumber(c) or 0))
    local g, s, cp = math.floor(c / 10000), math.floor(c % 10000 / 100), c % 100
    local parts = {}
    -- the game's coin icons, 14 px, after each amount (the footer text is about that tall)
    local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:14:14:2:0|t"
    if g > 0 then parts[#parts + 1] = g .. string.format(COIN, "Gold") end
    if g > 0 or s > 0 then parts[#parts + 1] = s .. string.format(COIN, "Silver") end
    parts[#parts + 1] = cp .. string.format(COIN, "Copper")
    return table.concat(parts, " ")
end

-- ---------------------------------------------------------------------------------------------- low-space warnings
local warned = false

-- After a loading screen (teleport, zone change) the bags are read while the game is still loading them, so the
-- free-slot count can read 0 for a moment. Bag updates are ignored for a few seconds after each loading screen, and a
-- low count is checked again before the warning is printed.
local settleUntil = 0
local settleFrame = CreateFrame("Frame")
settleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
settleFrame:SetScript("OnEvent", function() settleUntil = GetTime() + 4 end)

local function FreeNow()
    local free, total = ns.GeneralSlots()          -- ammo pouch slots do not count as room for loot
    if total <= 0 then free, total = ns.Slots() end
    return free, total
end

-- called on every bag update: one chat line when the general bag slots run low (it comes back only after they have
-- been freed above the limit), and the low-ammo check
local checkQueued = false
function ns.Sample()
    if GetTime() >= settleUntil then
        local free, total = FreeNow()
        local limit = ns.Opt("warnFree")
        if total > 0 and limit > 0 and free <= limit then
            if not warned and not checkQueued then
                checkQueued = true
                C_Timer.After(1.5, function()
                    checkQueued = false
                    if GetTime() < settleUntil or warned then return end
                    local f2, t2 = FreeNow()
                    local lim2 = ns.Opt("warnFree")
                    if t2 > 0 and lim2 > 0 and f2 <= lim2 then
                        warned = true
                        if f2 == 0 then print("|cffffd100GTBag|r: your bags are full.")
                        else print(string.format("|cffffd100GTBag|r: only %d free bag slot%s left.", f2, f2 == 1 and "" or "s")) end
                    end
                end)
            end
        elseif free > limit then
            warned = false
        end
    end
    if ns.CheckAmmo then ns.CheckAmmo() end
end
