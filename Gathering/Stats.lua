-- Stats.lua
local addonName, GT = ...
local nodes = GT.nodes
local order = GT.order

local stats = { start = GetTime(), counts = {}, other = {} }   -- other: itemID -> count of every non-gathering item looted
local MAX_MAP_ID = 100000

local yieldItems = {}
for _, key in ipairs(order) do
    yieldItems[nodes[key].id] = key
    for _, itemID in ipairs(nodes[key].extraIds or {}) do yieldItems[itemID] = key end
end

local function CleanCount(value)
    value = tonumber(value)
    if not value or value ~= value or value < 0 then return 0 end
    return math.min(1000000000, math.floor(value))
end

function GT.SanitizeZoneYield(db)
    local zones = type(db._zoneYield) == "table" and db._zoneYield or {}
    for mapID, resources in pairs(zones) do
        if type(mapID) ~= "number" or mapID < 1 or mapID > MAX_MAP_ID
            or mapID ~= math.floor(mapID) or type(resources) ~= "table" then
            zones[mapID] = nil
        else
            for key, data in pairs(resources) do
                if not nodes[key] or type(data) ~= "table" then
                    resources[key] = nil
                else
                    data.gathers = CleanCount(data.gathers)
                    if type(data.items) ~= "table" then data.items = {} end
                    for itemID, item in pairs(data.items) do
                        if type(itemID) ~= "number" or yieldItems[itemID] ~= key or type(item) ~= "table" then
                            data.items[itemID] = nil
                        else
                            item.drops = CleanCount(item.drops)
                            item.quantity = CleanCount(item.quantity)
                            if item.drops == 0 and item.quantity == 0 then data.items[itemID] = nil end
                        end
                    end
                    if data.gathers == 0 and next(data.items) == nil then resources[key] = nil end
                end
            end
            if next(resources) == nil then zones[mapID] = nil end
        end
    end
    db._zoneYield = zones
end

-- A gather visit is counted once (when its timer is first added); each recognized item records
-- its observed quantity and loot-event count. A chat line may correct the loot-window quantity.
function GT.RecordZoneYield(key, mapID, itemID, quantityDelta, newDrop, newGather)
    if not nodes[key] or type(itemID) ~= "number" or yieldItems[itemID] ~= key
        or type(mapID) ~= "number" or mapID < 1 or mapID > MAX_MAP_ID or mapID ~= math.floor(mapID) then return end
    local zones = GatherTimesDB._zoneYield
    if type(zones) ~= "table" then zones = {}; GatherTimesDB._zoneYield = zones end
    local resources = zones[mapID]
    if type(resources) ~= "table" then resources = {}; zones[mapID] = resources end
    local data = resources[key]
    if type(data) ~= "table" then data = { gathers = 0, items = {} }; resources[key] = data end
    data.gathers = math.min(1000000000, CleanCount(data.gathers) + (newGather and 1 or 0))
    if type(data.items) ~= "table" then data.items = {} end
    local item = data.items[itemID]
    if type(item) ~= "table" then item = { drops = 0, quantity = 0 }; data.items[itemID] = item end
    item.drops = math.min(1000000000, CleanCount(item.drops) + (newDrop and 1 or 0))
    quantityDelta = tonumber(quantityDelta)
    if not quantityDelta or quantityDelta ~= quantityDelta then quantityDelta = 0 end
    item.quantity = math.max(0, math.min(1000000000, CleanCount(item.quantity) + quantityDelta))
end

local function ZoneName(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
    end
    return "Map " .. mapID
end

local function ItemName(itemID)
    local name
    if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(itemID)
    elseif GetItemInfo then name = GetItemInfo(itemID) end
    return type(name) == "string" and name or ("Item " .. itemID)
end

function GT.FormatZoneYield(mapID)
    local zones = GatherTimesDB and GatherTimesDB._zoneYield or {}
    local ranked, totalZones = {}, 0
    for id, resources in pairs(zones) do
        if not mapID or id == mapID then
            local total = 0
            for _, data in pairs(resources) do total = total + (data.gathers or 0) end
            if total > 0 then
                totalZones = totalZones + 1
                ranked[#ranked + 1] = { id = id, resources = resources, gathers = total }
            end
        end
    end
    table.sort(ranked, function(a, b)
        if a.gathers ~= b.gathers then return a.gathers > b.gathers end
        return a.id < b.id
    end)
    if #ranked == 0 then return GT.TR("No zone yield data yet. Gather some nodes first.") end

    local lines = { GT.TRF("Zone yields: showing %d of %d zones (ranked by recorded gathers)", math.min(10, #ranked), totalZones) }
    for i = 1, math.min(10, #ranked) do
        local zone = ranked[i]
        lines[#lines + 1] = string.format("%s - %d gathers", ZoneName(zone.id), zone.gathers)
        for _, key in ipairs(order) do
            local data = zone.resources[key]
            if data and data.gathers > 0 then
                local items = {}
                for itemID, item in pairs(data.items) do
                    if item.quantity > 0 then
                        items[#items + 1] = {
                            id = itemID, quantity = item.quantity, drops = item.drops,
                            average = item.quantity / data.gathers,
                        }
                    end
                end
                table.sort(items, function(a, b)
                    if a.quantity ~= b.quantity then return a.quantity > b.quantity end
                    return a.id < b.id
                end)
                local yields = {}
                for _, item in ipairs(items) do
                    yields[#yields + 1] = string.format("%s x%d (%d drops, %.2f/gather)",
                        ItemName(item.id), item.quantity, item.drops, item.average)
                end
                lines[#lines + 1] = string.format("  %s: %d gathers%s", nodes[key].label, data.gathers,
                    #yields > 0 and (" | " .. table.concat(yields, ", ")) or "")
            end
        end
    end
    return table.concat(lines, "\n")
end

-- plain text, no colour codes and no coin icons, so the summary can be copied
local function PlainMoney(copper)
    copper = math.floor((copper or 0) + 0.5)
    local g = math.floor(copper / 10000)
    local sv = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, sv, c) end
    if sv > 0 then return string.format("%ds %dc", sv, c) end
    return string.format("%dc", c)
end
GT.PlainMoney = PlainMoney

-- value of one item: the auction price when a price addon knows it, else the vendor price, else nil
local function UnitValue(id)
    if not id then return nil end
    if GT.ItemAuctionPrice then
        local p = GT.ItemAuctionPrice(id)
        if p then return p, "auction" end
    end
    if GetItemInfo then
        local sell = select(11, GetItemInfo(id))
        if sell and sell > 0 then return sell, "vendor" end
    end
    return nil
end

-- the session summary: used by the chat output, the Timers panel and the copy window
-- everything else that was looted this session (mob drops, chests ...): { {id, name, n, unit, value}, ... },
-- most valuable first.  Items without a price come last.
local function OtherLoot()
    local list = {}
    for id, n in pairs(stats.other) do
        if n and n > 0 then
            local unit = UnitValue(id)
            list[#list + 1] = { id = id, name = ItemName(id), n = n, unit = unit, value = unit and unit * n or nil }
        end
    end
    table.sort(list, function(a, b)
        local av, bv = a.value or -1, b.value or -1
        if av ~= bv then return av > bv end
        return a.name < b.name
    end)
    return list
end

-- count one looted item that is not a herb / ore (called from the chat loot line)
function GT.AddOtherLoot(itemID, qty)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return end
    qty = math.max(1, math.min(1000000, math.floor(tonumber(qty) or 1)))
    stats.other[itemID] = math.min(1000000000, (stats.other[itemID] or 0) + qty)
    if GT.SaveSession then pcall(GT.SaveSession) end
end

local OTHER_SHOWN = 10      -- other items listed (the most valuable); the rest is summed up

-- the session summary: used by the chat output, the Timers panel and the copy window.
-- checkedOnly (the minimized bar's tooltip, when its option is off): list only the nodes ticked in the Nodes panel and
-- no "other items"; the Value line still counts everything that was looted.
function GT.FormatStats(checkedOnly)
    local el = GetTime() - stats.start
    local hours = el / 3600
    local function perHour(n) return hours > 0.02 and (n / hours) or 0 end
    local lines = { GT.TRF("Session: %dh %02dm", math.floor(el / 3600), math.floor((el % 3600) / 60)) }
    local total, value, unpriced = 0, 0, 0
    for _, key in ipairs(order) do
        local n = stats.counts[key]
        if n and n > 0 then
            local d = nodes[key]
            local listed = not checkedOnly or GT.IsEnabled(key)
            if listed then total = total + n end
            local line = GT.TRF("%s: %d  (%.0f/hr)", d.label, n, perHour(n))
            local unit = UnitValue(d.id)
            if unit then
                value = value + unit * n
                line = line .. "  " .. PlainMoney(unit * n)
            else
                unpriced = unpriced + 1
            end
            if listed then lines[#lines + 1] = line end
        end
    end
    local other = OtherLoot()
    if #other > 0 then
        local otherCount, otherValue, shownValue = 0, 0, 0
        for _, it in ipairs(other) do
            otherCount = otherCount + it.n
            if it.value then otherValue = otherValue + it.value else unpriced = unpriced + 1 end
        end
        value = value + otherValue
        if not checkedOnly then
            lines[#lines + 1] = GT.TRF("Other items: %d  (%d types)", otherCount, #other)
        end
        for i = 1, checkedOnly and 0 or math.min(OTHER_SHOWN, #other) do
            local it = other[i]
            local line = string.format("  %s: %d", it.name, it.n)
            if it.value then line = line .. "  " .. PlainMoney(it.value) end
            lines[#lines + 1] = line
        end
        if not checkedOnly and #other > OTHER_SHOWN then
            lines[#lines + 1] = GT.TRF("  +%d more item types", #other - OTHER_SHOWN)
        end
    end
    if total > 0 or #other > 0 then
        if total > 0 then
            lines[#lines + 1] = GT.TRF("Total: %d  (%.0f/hr)", total, perHour(total))
        end
        lines[#lines + 1] = GT.TRF("Value: %s  (%s/hr)", PlainMoney(value), PlainMoney(perHour(value)))
        if unpriced > 0 then
            lines[#lines + 1] = GT.TRF("%d item type(s) without a price, not in Value", unpriced)
        end
        if checkedOnly then
            lines[#lines + 1] = GT.TR("Checked items listed; Value counts all loot")
        end
    else
        lines[#lines + 1] = GT.TR("Nothing counted yet. Loot a herb or ore, then type /gt debug to see what the addon detects.")
    end
    return table.concat(lines, "\n")
end

-- total gold value of this session, in copper (the same prices as the summary)
local goldCache = { items = -1, copper = 0, t = 0 }
function GT.SessionGoldText()
    local items = 0
    for _, key in ipairs(order) do items = items + (stats.counts[key] or 0) end
    for _, n in pairs(stats.other) do items = items + (n or 0) end
    local now = GetTime()
    if items ~= goldCache.items or now - goldCache.t > 30 then
        local value = 0
        for _, key in ipairs(order) do
            local n = stats.counts[key]
            if n and n > 0 then
                local unit = UnitValue(nodes[key].id)
                if unit then value = value + unit * n end
            end
        end
        for id, n in pairs(stats.other) do
            local unit = n and n > 0 and UnitValue(id)
            if unit then value = value + unit * n end
        end
        goldCache.items, goldCache.copper, goldCache.t = items, value, now
    end
    -- gold only: silver and copper are not shown
    return string.format("%dg", math.floor(goldCache.copper / 10000))
end

-- the session of this character is kept in GatherTimesDB._session, so a reload or a new login resumes it
local function SessionKey()
    local name = UnitName("player")
    if not name then return nil end
    return name .. "-" .. (GetRealmName() or "")
end

local restored = false
function GT.SaveSession()
    if not restored or not GatherTimesDB then return end       -- never overwrite a session before it was restored
    local key = SessionKey()
    if not key then return end
    local counts = {}
    for k, v in pairs(stats.counts) do
        if v and v > 0 then counts[k] = v end
    end
    GatherTimesDB._session = GatherTimesDB._session or {}
    local other = {}
    for id, n in pairs(stats.other) do
        if n and n > 0 then other[id] = n end
    end
    GatherTimesDB._session[key] = { counts = counts, other = other, elapsed = GetTime() - stats.start }
end

-- called once at login (PLAYER_ENTERING_WORLD with the first login): resume the saved session, or start a new one
function GT.RestoreSession()
    if restored then return end
    restored = true
    wipe(stats.counts)
    wipe(stats.other)
    stats.start = GetTime()
    local key = SessionKey()
    local saved = key and GatherTimesDB and GatherTimesDB._session and GatherTimesDB._session[key]
    if saved and not GT.cfg().newSessionOnLogin then
        for k, v in pairs(saved.counts or {}) do
            if nodes[k] and type(v) == "number" and v > 0 then stats.counts[k] = v end
        end
        if type(saved.other) == "table" then
            for id, v in pairs(saved.other) do
                if type(id) == "number" and type(v) == "number" and v > 0 then stats.other[id] = CleanCount(v) end
            end
        end
        stats.start = GetTime() - math.max(0, tonumber(saved.elapsed) or 0)
    end
    GT.SaveSession()
end

function GT.ResetSessionStats()
    local summary = GT.FormatStats()
    GT.cprint("\n" .. summary)
    stats.start = GetTime()
    wipe(stats.counts)
    wipe(stats.other)
    GT.SaveSession()
    if GT.sessionGatheredSpots then wipe(GT.sessionGatheredSpots) end
    GT.UpdateList()
    if GT.SyncSpawnPins then pcall(GT.SyncSpawnPins) end
    return summary
end

local lowWarned = false; local lowLast = 0
function GT.CheckHealth()
    local c = GT.cfg()
    if not c.lowHP then return end
    if UnitIsDeadOrGhost("player") then return end
    local max = UnitHealthMax("player")
    if not max or max <= 0 then return end
    local pct = UnitHealth("player") / max * 100
    if pct < c.lowHPPct then
        if not lowWarned and (GetTime() - lowLast) > 8 then
            lowWarned = true
            lowLast = GetTime()
            GT.ShowScreenAlert(GT.TRF("LOW HEALTH %d%%", pct), 1, 0.2, 0.2)
            pcall(PlaySound, 8959, "Master")
        end
    elseif pct > c.lowHPPct + 10 then
        lowWarned = false
    end
end

-- ============================================================
-- LOOT HANDLING
-- ============================================================

-- exports
GT.stats = stats
