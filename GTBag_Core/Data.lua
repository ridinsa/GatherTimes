-- Data.lua : what is remembered about every character (bags, bank, mail) and the guild banks, the "source" the window
-- shows, and the events that keep it current.
--   * Your own bags (and the bank while you stand at the banker) are read live from the game.
--   * Everything else (other characters, the bank away from the banker, mail, guild bank) comes from snapshots in GTBagDB.
local ADDON, ns = ...

ns.view = { char = nil, tab = "bags", gtab = 0 }     -- char nil = the character being played; gtab 0 = all guild tabs
ns.atBank, ns.atGuild, ns.atMail = false, false, false
ns.dataVersion = 0          -- bumped whenever anything that the item tooltip counts can change

local GUILD_SLOTS = _G.MAX_GUILDBANK_SLOTS_PER_TAB or 98
local MAX_TABS = _G.MAX_GUILDBANK_TABS or 8
ns.MAX_TABS = MAX_TABS

local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local function IconOf(id)
    if not (instant and id and id ~= 0) then return nil end
    return (select(5, instant(id)))
end
local function IdOf(link) return link and tonumber(link:match("item:(%d+)")) or nil end

-- ---------------------------------------------------------------------------------------------- records
local function DB()
    GTBagDB = GTBagDB or {}
    if type(GTBagDB.chars) ~= "table" then GTBagDB.chars = {} end
    if type(GTBagDB.guilds) ~= "table" then GTBagDB.guilds = {} end
    if GTBagDB.goldVersion ~= 1 then
        for _, rec in pairs(GTBagDB.chars) do
            if type(rec) == "table" and tonumber(rec.money) == 0 then
                rec.moneyT = nil
            end
        end
        GTBagDB.goldVersion = 1
    end
    return GTBagDB
end

local HC = "-Hardcore"
local FoldTwin                      -- defined below (folds a stale "Name-Realm" record into "Name-Realm-Hardcore")
local myKey
function ns.MyKey()
    if not myKey then
        local name = UnitName("player")
        if not name or name == UNKNOWNOBJECT then return "?-" .. (GetRealmName() or "?") end
        myKey = ns.CharacterKey(name, GetRealmName() or "?") or (name .. "-" .. (GetRealmName() or "?"))
    end
    return myKey
end
function ns.RefreshMyKey()
    local old = myKey
    myKey = nil
    local new = ns.MyKey()
    if old and new and old ~= new then
        local d = DB()
        local function CopyAny(value)
            if type(value) ~= "table" then return value end
            local copy = {}
            for k, v in pairs(value) do copy[k] = CopyAny(v) end
            return copy
        end
        local function CopyKey(tableValue, from, to)
            if type(tableValue) == "table" and tableValue[from] ~= nil and tableValue[to] == nil then
                tableValue[to] = CopyAny(tableValue[from])
                return true
            end
            return false
        end
        CopyKey(d.chars, old, new)
        CopyKey(d.charOpts, old, new)
        CopyKey(d.sessions, old, new)
        CopyKey(d.sessionHistoryByChar, old, new)
        CopyKey(d.pendingNicks, old, new)

        local function CopyPrefixed(tableValue, fromPrefix, toPrefix)
            if type(tableValue) ~= "table" then return end
            for k, v in pairs(tableValue) do
                if type(k) == "string" and k:sub(1, #fromPrefix) == fromPrefix
                    and tableValue[toPrefix .. k:sub(#fromPrefix + 1)] == nil then
                    tableValue[toPrefix .. k:sub(#fromPrefix + 1)] = CopyAny(v)
                end
            end
        end
        CopyPrefixed(d.hiddenContainers, old, new)
        CopyPrefixed(d.hiddenSlots, old .. ":", new .. ":")
        CopyPrefixed(d.manualOrders, old .. ":", new .. ":")
        if new == old .. HC then FoldTwin(d, old, new) end      -- late Hardcore detection: move, do not keep a twin
    end
    return new
end
-- "Name-Realm" and "Name-Realm-Hardcore" are ONE character when the plain record was written before the game reported
-- Hardcore mode (PLAYER_LOGIN comes first), and RefreshMyKey copied it under the Hardcore key.  Both then showed up in
-- the character selector.  This folds the plain record into the Hardcore one and removes the plain key everywhere.
FoldTwin = function(d, from, to)
    local a, b = d.chars[from], d.chars[to]
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do                                   -- fill in what the Hardcore record lacks
        if b[k] == nil then b[k] = v end
    end
    for _, part in ipairs({ { "bags", "bagsT" }, { "bank", "bankT" } }) do    -- newer snapshot wins
        if type(a[part[1]]) == "table" and (tonumber(a[part[2]]) or 0) > (tonumber(b[part[2]]) or 0) then
            b[part[1]], b[part[2]] = a[part[1]], a[part[2]]
        end
    end
    if a.nick and not b.nick then b.nick = a.nick end
    d.chars[from] = nil
    for _, name in ipairs({ "charOpts", "sessions", "sessionHistoryByChar", "pendingNicks", "hiddenContainers" }) do
        local t = d[name]
        if type(t) == "table" then
            if t[to] == nil then t[to] = t[from] end
            t[from] = nil
        end
    end
    for _, name in ipairs({ "hiddenSlots", "manualOrders" }) do          -- scopes look like "Name-Realm:..."
        local t = d[name]
        if type(t) == "table" then
            local prefix, moved = from .. ":", nil
            for k, v in pairs(t) do
                if type(k) == "string" and k:sub(1, #prefix) == prefix then
                    moved = moved or {}
                    moved[#moved + 1] = { k, to .. ":" .. k:sub(#prefix + 1), v }
                end
            end
            for _, m in ipairs(moved or {}) do
                if t[m[2]] == nil then t[m[2]] = m[3] end
                t[m[1]] = nil
            end
        end
    end
    if ns.view and ns.view.char == from then ns.view.char = to end
    return true
end

-- Same character saved under more than one key: "Name-Realm" and "Name-Realm-Hardcore", or a realm written a little
-- differently by an older version.  The key is the identity: it is compared without the Hardcore suffix, case, spaces and
-- punctuation, and the records must not disagree on name or class (an empty field agrees with anything).  Every key of a
-- group is folded into one: the character being played, else the Hardcore key, else the newest record.
local function KeyId(key)
    key = tostring(key):lower()
    if key:sub(-#HC) == HC:lower() then key = key:sub(1, -#HC - 1) end
    return (key:gsub("[%s%p]", ""))
end
local function Agree(a, b)
    local function Same(x, y) return x == nil or y == nil or tostring(x):lower() == tostring(y):lower() end
    return Same(a.name, b.name) and Same(a.class, b.class)
end

function ns.MergeHardcoreTwins()
    local d = DB()
    local groups
    for key, rec in pairs(d.chars) do
        if type(key) == "string" and type(rec) == "table" and key:sub(1, 2) ~= "?-" then
            groups = groups or {}
            local id = KeyId(key)
            groups[id] = groups[id] or {}
            table.insert(groups[id], key)
        end
    end
    local me, merged = ns.MyKey(), 0
    for _, keys in pairs(groups or {}) do
        if #keys > 1 then
            local target
            for _, k in ipairs(keys) do if k == me then target = k end end
            if not target then
                for _, k in ipairs(keys) do
                    if k:sub(-#HC) == HC and (not target or (tonumber(d.chars[k].t) or 0) > (tonumber(d.chars[target].t) or 0)) then target = k end
                end
            end
            if not target then
                for _, k in ipairs(keys) do
                    if not target or (tonumber(d.chars[k].t) or 0) > (tonumber(d.chars[target].t) or 0) then target = k end
                end
            end
            for _, k in ipairs(keys) do
                if k ~= target and Agree(d.chars[k], d.chars[target]) and FoldTwin(d, k, target) then merged = merged + 1 end
            end
        end
    end
    if merged > 0 then ns.dataVersion = (ns.dataVersion or 0) + 1 end
    return merged
end
function ns.ViewKey() return ns.view.char or ns.MyKey() end
function ns.ViewingSelf() return ns.view.char == nil or ns.view.char == ns.MyKey() end

local function MyRec()
    local d, k = DB(), ns.MyKey()
    local r = d.chars[k]
    if not r then
        r = {}
        d.chars[k] = r
        -- a nickname restored from a backup before this character existed here
        local pending = type(d.pendingNicks) == "table" and d.pendingNicks[k]
        if type(pending) == "string" and pending ~= "" then
            r.nick = pending
            d.pendingNicks[k] = nil
            if next(d.pendingNicks) == nil then d.pendingNicks = nil end
        end
    end
    r.name, r.realm = UnitName("player"), GetRealmName()
    return r
end

function ns.Rec(key) return DB().chars[key or ns.ViewKey()] end

-- optional nickname shown in the character selector; empty by default.  It lives beside the saved snapshots and is
-- display-only: it never touches bags, bank, mail or guild bank, so dataVersion (tooltip counts) is left alone.
local NICK_MAX = 24
function ns.GetNick(key)
    local r = DB().chars[key or ns.ViewKey()]
    local n = r and r.nick
    if type(n) == "string" and n ~= "" then return n end
    return nil
end
function ns.SetNick(key, text)
    local r = DB().chars[key or ns.ViewKey()]
    if not r then return false end
    text = tostring(text or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    text = text:sub(1, NICK_MAX)
    r.nick = (text ~= "") and text or nil
    ns.nameEpoch = (ns.nameEpoch or 0) + 1          -- the tooltip name list is rebuilt
    return true
end

-- backup restore: set the nickname now when the character is known, otherwise keep it until that character logs in
-- here.  Returns "set", "pending", or nil for an empty nickname or a bad key.
function ns.ImportNick(key, text)
    if type(key) ~= "string" or key == "" or #key > 64 or not key:find("-", 1, true) then return nil end
    text = tostring(text or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    text = text:sub(1, NICK_MAX)
    if text == "" then return nil end
    local d = DB()
    if d.chars[key] then
        d.chars[key].nick = text
        ns.nameEpoch = (ns.nameEpoch or 0) + 1
        return "set"
    end
    if type(d.pendingNicks) ~= "table" then d.pendingNicks = {} end
    local n = 0
    for _ in pairs(d.pendingNicks) do n = n + 1 end
    if n >= 200 and d.pendingNicks[key] == nil then return nil end
    d.pendingNicks[key] = text
    return "pending"
end

-- known characters: the one being played first, then by realm and name
function ns.CharKeys()
    local keys, me = {}, ns.MyKey()
    for k in pairs(DB().chars) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if a == me then return true elseif b == me then return false end
        return a:lower() < b:lower()
    end)
    return keys
end

function ns.Forget(key)
    ns.dataVersion = ns.dataVersion + 1
    if key == ns.MyKey() then return false end
    local d = DB()
    if not d.chars[key] then return false end
    d.chars[key] = nil
    -- their saved drag-order lists go too; scopes look like "Name-Realm:tab:gtab"
    if type(d.manualOrders) == "table" then
        for scope in pairs(d.manualOrders) do
            if scope:sub(1, #key + 1) == key .. ":" then d.manualOrders[scope] = nil end
        end
    end
    if ns.view.char == key then ns.view.char = nil end
    return true
end

function ns.GuildRec(rec, create)
    if not (rec and rec.guild) then return nil end
    local d = DB()
    local k = rec.guild .. "-" .. (rec.realm or "")
    local g = d.guilds[k]
    if not g and create then
        g = { name = rec.guild, realm = rec.realm, tabs = {} }
        d.guilds[k] = g
    end
    return g
end

-- ---------------------------------------------------------------------------------------------- snapshots
-- a slot is stored as { id, count, link, icon, quality }
local function Unpack(p)
    if not p then return nil end
    local bound
    if p[6] ~= nil then bound = p[6] == 1 end
    return { id = p[1], count = p[2] or 1, link = p[3], icon = p[4] or IconOf(p[1]),
             quality = p[5] or ns.QualityOf(p[3]), bound = bound, cached = true }
end

-- Every bag update used to build a brand-new snapshot: one table per container and two per item, all of the old ones
-- left for the garbage collector.  The snapshot is now updated in place: an unchanged slot keeps its table, a changed
-- one is overwritten, and only a slot that was empty before gets a new table.  `old` is the previous snapshot.
local function PackInto(old, info)
    local bound
    if info.bound ~= nil then bound = info.bound and 1 or 0 end
    if old then
        old[1], old[2], old[3], old[4], old[5], old[6] = info.id, info.count, info.link, info.icon, info.quality, bound
        return old
    end
    return { info.id, info.count, info.link, info.icon, info.quality, bound }
end

local seenBags = {}
local scanInfo = {}          -- reused by the snapshot loop: PackInto copies the fields out before the next slot is read
local function ReadContainers(ids, inventoryBags, old)
    local out, any = old or {}, false
    wipe(seenBags)
    for _, bag in ipairs(ids) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" and n > 0 then
            local c = out[bag]
            if type(c) ~= "table" then c = {}; out[bag] = c end
            local oldN = type(c.n) == "number" and c.n or 0
            c.n = n
            if inventoryBags then c.isQuiverBag = ns.IsQuiverBag(bag) end
            for slot = 1, n do
                local info = ns.ItemInfo(bag, slot, scanInfo)
                if info then c[slot] = PackInto(c[slot], info) else c[slot] = nil end
            end
            for slot = n + 1, oldN do c[slot] = nil end        -- the bag got smaller
            seenBags[bag] = true
            any = true
        end
    end
    if any then
        for bag in pairs(out) do                                -- a bag that is gone (unequipped) is dropped
            if not seenBags[bag] then out[bag] = nil end
        end
    end
    return out, any
end

-- what: "bags" (default) or "bank".  Money is saved separately so a transient logout value cannot overwrite it.
function ns.SaveChar(what)
    ns.dataVersion = ns.dataVersion + 1
    local r = MyRec()
    r.class = select(2, UnitClass("player"))
    r.faction = UnitFactionGroup and (UnitFactionGroup("player")) or r.faction
    if IsInGuild and IsInGuild() then
        local gn = GetGuildInfo("player")
        if gn then r.guild = gn end
    end
    r.t = time()
    if what == nil or what == "bags" then
        local c, any = ReadContainers(ns.BAGS, true, type(r.bags) == "table" and r.bags or nil)
        if any then r.bags, r.bagsT = c, time() end
    elseif what == "bank" and ns.atBank then
        local c, any = ReadContainers(ns.BANK_IDS, nil, type(r.bank) == "table" and r.bank or nil)
        if any then r.bank, r.bankT = c, time() end
    end
    return r
end

local function SaveMoney(allowZero)
    if not GetMoney then return end
    local money = GetMoney()
    if type(money) ~= "number" then return end
    local old = DB().chars[ns.MyKey()]
    if money == 0 and not allowZero and old and tonumber(old.money) and tonumber(old.money) > 0 then
        return
    end
    local r = MyRec()
    r.money, r.moneyT = money, time()
    ns.LogGold(r, money)
end

-- ---------------------------------------------------------------------------------------------- gold history
-- one entry per calendar day (local time): { d = yyyymmdd, t = first reading, s = gold at the first reading,
-- e = gold at the latest reading }.  The last GOLD_DAYS days are kept.  Display-only; nothing else reads it.
local GOLD_DAYS = 35
function ns.LogGold(r, money)
    money = tonumber(money)
    if not (r and money) then return end
    local log = type(r.goldLog) == "table" and r.goldLog or {}
    r.goldLog = log
    local today, now = tonumber(date("%Y%m%d")), time()
    local last = log[#log]
    if last and last.d == today then
        last.e = money
    else
        log[#log + 1] = { d = today, t = now, s = money, e = money }
        while #log > GOLD_DAYS do table.remove(log, 1) end
    end
end

-- change in gold over the last `days` days (1 = since the first reading today).  Returns nil when there is no history.
-- It compares the current gold with the first reading of the oldest day inside the window.
function ns.GoldChange(rec, days)
    local log = rec and type(rec.goldLog) == "table" and rec.goldLog or nil
    local last = log and log[#log]
    if not last then return nil end
    local now = time()
    local limit = now - (math.max(1, days or 1) - 1) * 86400 - (tonumber(date("%H", now)) * 3600
        + tonumber(date("%M", now)) * 60 + tonumber(date("%S", now)))
    local first
    for _, e in ipairs(log) do
        if (e.t or 0) >= limit then first = e; break end
    end
    first = first or last
    return (tonumber(rec.money) or last.e) - first.s
end

-- "+1g 20s" / "-3s" with the coin icons; nil for no change
function ns.SignedMoney(c)
    c = tonumber(c)
    if not c or c == 0 then return nil end
    if c > 0 then return "|cff44dd44+" .. ns.Money(c) .. "|r" end
    return "|cffdd5544-" .. ns.Money(-c) .. "|r"
end

local function CountPackedContainers(containers, id)
    local total = 0
    for _, container in pairs(containers or {}) do
        if type(container) == "table" and type(container.n) == "number" then
            for slot = 1, container.n do
                local packed = container[slot]
                if packed and packed[1] == id then total = total + (tonumber(packed[2]) or 1) end
            end
        end
    end
    return total
end

local function CountLiveContainers(ids, id)
    local total = 0
    if not ns.GetNumSlots then return total end
    for _, bag in ipairs(ids) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" then
            for slot = 1, n do
                if ns.SlotItemID(bag, slot) == id then          -- no table built for the slots that do not match
                    local _, count = ns.SlotCount(bag, slot)
                    total = total + (tonumber(count) or 1)
                end
            end
        end
    end
    return total
end

-- tooltip counts are memoized until the data changes or the bounded cache fills
local memo, memoVersion, memoSize = {}, -1, 0
local MEMO_LIMIT = 512

-- the older of two snapshot times (nil = unknown)
local function Oldest(current, t)
    if type(t) ~= "number" then return current end
    if not current or t < current then return t end
    return current
end

-- Counts current live bags, remembered bank/mail/void/auction data, all saved guild banks, and the saved inventory of
-- every character known to this addon.  Each source also records the age of its oldest contributing snapshot (live
-- contents count as now); the item tooltip shows it.
function ns.InventoryCounts(id)
    id = tonumber(id)
    if not id then return nil end
    if memoVersion ~= ns.dataVersion then
        wipe(memo)
        memoVersion, memoSize = ns.dataVersion, 0
    end
    if memo[id] then return memo[id] end
    local result = { bags = 0, bank = 0, guild = 0, void = 0, mail = 0, auctions = 0 }
    local function Add(kind, n, t)
        if not n or n <= 0 then return end
        result[kind] = result[kind] + n
        result[kind .. "T"] = Oldest(result[kind .. "T"], t)
    end
    local function CountList(list)
        local n = 0
        for _, item in ipairs(type(list) == "table" and list or {}) do
            if item.id == id then n = n + (tonumber(item.count) or 1) end
        end
        return n
    end

    local me = ns.MyKey()
    local chars = DB().chars
    local now = time()
    for key, rec in pairs(chars) do
        if key == me then
            Add("bags", CountLiveContainers(ns.BAGS, id), now)
            if ns.atBank then
                Add("bank", CountLiveContainers(ns.BANK_IDS, id), now)
            else
                Add("bank", CountPackedContainers(rec.bank, id), rec.bankT)
            end
        else
            Add("bags", CountPackedContainers(rec.bags, id), rec.bagsT)
            Add("bank", CountPackedContainers(rec.bank, id), rec.bankT)
        end

        local mail = type(rec.mail) == "table" and rec.mail or nil
        local mailCount = 0
        for _, item in ipairs(mail and type(mail.items) == "table" and mail.items or {}) do
            local left = (tonumber(item.days) or 30) - (now - (tonumber(item.t) or (mail and mail.t) or now)) / 86400
            if item.id == id and left > 0 then mailCount = mailCount + (tonumber(item.count) or 1) end
        end
        Add("mail", mailCount, mail and mail.t)
        Add("void", CountList(rec.void), rec.voidT)
        Add("auctions", CountList(rec.auctions), rec.auctionsT)
    end

    local seenGuilds = {}
    for _, rec in pairs(chars) do
        local guild = ns.GuildRec(rec)
        if guild and not seenGuilds[guild] then
            seenGuilds[guild] = true
            local n = 0
            for _, tab in pairs(guild.tabs or {}) do
                for slot = 1, GUILD_SLOTS do
                    local packed = tab[slot]
                    if packed and packed[1] == id then n = n + (tonumber(packed[2]) or 1) end
                end
            end
            Add("guild", n, guild.t)
        end
    end
    if memoSize >= MEMO_LIMIT then
        wipe(memo)
        memoSize = 0
    end
    memo[id] = result
    memoSize = memoSize + 1
    return result
end

-- Per-character breakdown of one item for the tooltip: { { key, rec, bags, bank, mail, void, auctions, total }, ... },
-- most copies first.  Guild banks are not tied to a character, so they are not included here.
local byCharMemo, byCharVersion = {}, -1
function ns.InventoryByChar(id)
    id = tonumber(id)
    if not id then return {} end
    if byCharVersion ~= ns.dataVersion then
        wipe(byCharMemo)
        byCharVersion = ns.dataVersion
    end
    if byCharMemo[id] then return byCharMemo[id] end
    local list, me, now = {}, ns.MyKey(), time()
    for key, rec in pairs(DB().chars) do
        local e = { key = key, rec = rec, bags = 0, bank = 0, mail = 0, void = 0, auctions = 0 }
        if key == me then
            e.bags = CountLiveContainers(ns.BAGS, id)
            e.bank = ns.atBank and CountLiveContainers(ns.BANK_IDS, id) or CountPackedContainers(rec.bank, id)
        else
            e.bags = CountPackedContainers(rec.bags, id)
            e.bank = CountPackedContainers(rec.bank, id)
        end
        local mail = type(rec.mail) == "table" and rec.mail or nil
        for _, item in ipairs(mail and type(mail.items) == "table" and mail.items or {}) do
            local left = (tonumber(item.days) or 30) - (now - (tonumber(item.t) or tonumber(mail.t) or now)) / 86400
            if item.id == id and left > 0 then e.mail = e.mail + (tonumber(item.count) or 1) end
        end
        for _, item in ipairs(type(rec.void) == "table" and rec.void or {}) do
            if item.id == id then e.void = e.void + (tonumber(item.count) or 1) end
        end
        for _, item in ipairs(type(rec.auctions) == "table" and rec.auctions or {}) do
            if item.id == id then e.auctions = e.auctions + (tonumber(item.count) or 1) end
        end
        e.total = e.bags + e.bank + e.mail + e.void + e.auctions
        if e.total > 0 then list[#list + 1] = e end
    end
    table.sort(list, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.key < b.key
    end)
    byCharMemo[id] = list
    return list
end

-- Gatherer totals per character from the saved bags and bank: herbs, ore and trade goods, plus the value of
-- everything they hold (GatherTimes scan price when available, else vendor).  Returns printable lines.
function ns.Summary()
    local function Tally(t, containers)
        for _, c in pairs(containers or {}) do
            if type(c) == "table" and type(c.n) == "number" then
                for slot = 1, c.n do
                    local p = c[slot]
                    if p and p[1] then
                        local count = tonumber(p[2]) or 1
                        local cat = ns.BaseCategory({ id = p[1], quality = p[5] or ns.QualityOf(p[3]) })
                        if cat == "herbs" or cat == "ore" or cat == "trade" then t[cat] = t[cat] + count end
                        t.value = t.value + ns.UnitValue(p[1], p[3]) * count
                    end
                end
            end
        end
    end
    local function Line(label, t)
        return string.format("%s  herbs %d, ore %d, trade goods %d, value %s",
            label, t.herbs, t.ore, t.trade, ns.Money(t.value))
    end
    local lines, all = {}, { herbs = 0, ore = 0, trade = 0, value = 0 }
    for _, key in ipairs(ns.CharKeys()) do
        local rec = ns.Rec(key)
        local t = { herbs = 0, ore = 0, trade = 0, value = 0 }
        if rec then
            Tally(t, rec.bags)
            Tally(t, rec.bank)
        end
        for k, v in pairs(t) do all[k] = all[k] + v end
        lines[#lines + 1] = Line(ns.ClassName(rec, true, true), t)
    end
    lines[#lines + 1] = Line("All characters", all)
    return lines
end

function ns.RefreshVoidStorage()
    ns.dataVersion = ns.dataVersion + 1
    local getSlots = VoidStorageGetNumSlots or VoidStorageGetNumItems
    if not (getSlots and VoidStorageGetItemInfo) then return end
    local ok, n = pcall(getSlots)
    if not ok or type(n) ~= "number" then return end
    local items = {}
    for slot = 1, n do
        local values = { pcall(VoidStorageGetItemInfo, slot) }
        local itemID = values[1] and tonumber(values[2]) or nil
        itemID = itemID or IdOf(values[7])
        if itemID then items[#items + 1] = { id = itemID, count = 1 } end
    end
    local rec = MyRec()
    rec.void, rec.voidT = items, time()
end

function ns.RefreshAuctions()
    ns.dataVersion = ns.dataVersion + 1
    local items = {}
    local ah = C_AuctionHouse
    if ah and ah.GetOwnedAuctions and ah.GetOwnedAuctionInfo then
        local ok, auctions = pcall(ah.GetOwnedAuctions)
        if ok and type(auctions) == "table" then
            for _, auctionID in ipairs(auctions) do
                local success, info = pcall(ah.GetOwnedAuctionInfo, auctionID)
                if success and type(info) == "table" then
                    local id = IdOf(info.itemLink)
                    if not id and info.itemKey then id = tonumber(info.itemKey.itemID) end
                    if id then
                        items[#items + 1] = { id = id, count = tonumber(info.quantity) or 1, link = info.itemLink,
                            buyout = tonumber(info.buyoutAmount), bid = tonumber(info.bidAmount),
                            unit = tonumber(info.buyoutAmount),          -- retail: unit price for commodities
                            sold = (Enum and Enum.AuctionStatus and info.status == Enum.AuctionStatus.Sold) or nil,
                            left = tonumber(info.timeLeftSeconds),
                            tl = tonumber(info.timeLeft) and (tonumber(info.timeLeft) + 1) or nil }   -- 1 short .. 4 very long
                    end
                end
            end
        end
    elseif GetNumAuctionItems and GetAuctionItemInfo then
        local ok, n = pcall(GetNumAuctionItems, "owner")
        if ok and type(n) == "number" then
            for index = 1, n do
                local values = { pcall(GetAuctionItemInfo, "owner", index) }
                local link
                if GetAuctionItemLink then
                    local linkOK
                    linkOK, link = pcall(GetAuctionItemLink, "owner", index)
                    if not linkOK then link = nil end
                end
                -- values[1] is pcall's status, so return value n of GetAuctionItemInfo is values[n + 1]: count is the 3rd
                -- (values[4]), the item id the 17th (values[18]).  Checked with /dump on a Classic client.
                local itemID = values[1] and tonumber(values[18]) or nil
                if not itemID or itemID <= 0 then itemID = IdOf(link) end
                if itemID then
                    local tl
                    if GetAuctionItemTimeLeft then
                        local okT, v = pcall(GetAuctionItemTimeLeft, "owner", index)
                        if okT then tl = tonumber(v) end
                    end
                    local cnt = tonumber(values[4]) or 1
                    local bo = values[1] and tonumber(values[11]) or nil
                    items[#items + 1] = { id = itemID, count = cnt, link = link, tl = tl,
                        unit = bo and bo > 0 and math.floor(bo / math.max(cnt, 1)) or nil,
                        icon = values[1] and values[3] or nil, q = values[1] and tonumber(values[5]) or nil,
                        buyout = values[1] and tonumber(values[11]) or nil, bid = values[1] and tonumber(values[12]) or nil,
                        sold = (values[1] and tonumber(values[17]) == 1) or nil }
                end
            end
        end
    else
        return
    end
    local rec = MyRec()
    rec.auctions, rec.auctionsT = items, time()
end
-- one debounce timer per kind.  The bank saves quickly because SaveChar("bank") is skipped once the bank window has
-- closed, so a long delay could lose the last deposit or withdrawal.
local SAVE_DELAY = { bags = 1, bank = 0.25 }
local saveTimer = {}
function ns.QueueSave(what)
    local delay = SAVE_DELAY[what]
    if not delay or saveTimer[what] then return end
    saveTimer[what] = true
    C_Timer.After(delay, function()
        saveTimer[what] = false
        ns.SaveChar(what)
    end)
end

-- ---------------------------------------------------------------------------------------------- mail
-- Items waiting in a mailbox: { id, count, link, icon, q, from, days, t, cod, idx, att, sent }.  days is what was left at
-- time t; idx / att locate the attachment while the mailbox is open.
function ns.SaveMail()
    ns.dataVersion = ns.dataVersion + 1
    if not (GetInboxNumItems and GetInboxHeaderInfo and GetInboxItemLink) then return end
    local r = MyRec()
    local n = GetInboxNumItems() or 0
    local items, gold, mails, now = {}, 0, 0, time()
    for i = 1, n do
        local _, _, sender, _, money, cod, days, hasItem = GetInboxHeaderInfo(i)
        mails = mails + 1
        gold = gold + (money or 0)
        if hasItem then
            for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
                local link = GetInboxItemLink(i, a)
                if link then
                    local _, id, tex, count, quality = GetInboxItem(i, a)
                    items[#items + 1] = {
                        id = IdOf(link) or (type(id) == "number" and id) or 0, count = count or 1, link = link,
                        icon = tex, q = quality, from = sender, days = days or 30, t = now, cod = cod, idx = i, att = a,
                    }
                end
            end
        end
    end
    r.mail = { t = now, gold = gold, mails = mails, items = items }
    if ns.view.tab == "mail" then ns.Relayout() end
end

-- mail you send to one of your other characters shows up in their mail right away
local pendingSend
local function CaptureSend(recipient)
    if not recipient or recipient == "" or not (GetSendMailItem and GetSendMailItemLink) then return end
    local items = {}
    for i = 1, (ATTACHMENTS_MAX_SEND or 12) do
        local link = GetSendMailItemLink(i)
        if link then
            local _, id, tex, count, quality = GetSendMailItem(i)
            items[#items + 1] = { id = IdOf(link) or (type(id) == "number" and id) or 0, count = count or 1, link = link,
                                  icon = tex, q = quality }
        end
    end
    pendingSend = { to = recipient, items = items, cod = GetSendMailCOD and GetSendMailCOD() or 0 }
end

local function Norm(s) return ((s or ""):gsub("[%s%-']", ""):lower()) end
local function CommitSend()
    ns.dataVersion = ns.dataVersion + 1
    local p = pendingSend
    pendingSend = nil
    if not (p and #p.items > 0) then return end
    local name, realm = strsplit("-", p.to)
    name = (name or ""):lower()
    local me, myRealm = ns.MyKey(), GetRealmName()
    for key, r in pairs(DB().chars) do
        local sameRealm = (realm == nil or realm == "") and r.realm == myRealm or (realm and Norm(realm) == Norm(r.realm))
        if key ~= me and r.name and r.name:lower() == name and sameRealm then
            r.mail = r.mail or { t = time(), gold = 0, mails = 0, items = {} }
            local now = time()
            for _, it in ipairs(p.items) do
                r.mail.items[#r.mail.items + 1] = { id = it.id, count = it.count, link = it.link, icon = it.icon, q = it.q,
                    from = UnitName("player"), days = 30, t = now, cod = p.cod, sent = true }
            end
            r.mail.mails = (r.mail.mails or 0) + 1
            if ns.view.char == key and ns.view.tab == "mail" then ns.Relayout() end
        end
    end
end

if _G.SendMail then hooksecurefunc("SendMail", CaptureSend) end
if C_Mail and C_Mail.SendMail then hooksecurefunc(C_Mail, "SendMail", CaptureSend) end

-- ---------------------------------------------------------------------------------------------- guild bank
local gq, gcur, gstarted = nil, nil, false
local GUILD_QUERY_TIMEOUT = 10
local guildWatchToken = 0
local guildScanBlocked = false
local gOrigTab                       -- tab the player had open before a scan started

local function RestoreGuildTab()
    local tab = gOrigTab
    gOrigTab = nil
    if tab and SetCurrentGuildBankTab and not InCombatLockdown() then pcall(SetCurrentGuildBankTab, tab) end
end

local function WatchGuildTab(tab)
    guildWatchToken = guildWatchToken + 1
    local token = guildWatchToken
    C_Timer.After(GUILD_QUERY_TIMEOUT, function()
        if token ~= guildWatchToken or gcur ~= tab then return end
        gq, gstarted = nil, false
        guildScanBlocked = true
        print("|cffffd100GTBag|r: guild bank scan paused; tab " .. tostring(tab) ..
            " did not respond. Reopen the guild bank to retry.")
    end)
end

function ns.SaveGuildMeta()
    if not (GetNumGuildBankTabs and GetGuildBankTabInfo) then return end
    local r = MyRec()
    if not r.guild then ns.SaveChar() end
    local g = ns.GuildRec(r, true)
    if not g then return end
    g.numTabs = GetNumGuildBankTabs() or 0
    if GetGuildBankMoney then g.money = GetGuildBankMoney() end
    g.t = g.t or time()
    for t = 1, g.numTabs do
        local name, icon, viewable = GetGuildBankTabInfo(t)
        local td = g.tabs[t] or {}
        td.name, td.icon, td.noView = name, icon, not viewable
        g.tabs[t] = td
    end
    return g
end

function ns.SaveGuildTab(tab)
    ns.dataVersion = ns.dataVersion + 1
    if not (GetGuildBankItemInfo and GetGuildBankItemLink) then return end
    local g = ns.SaveGuildMeta()
    local td = g and g.tabs[tab]
    if not td or td.noView then return end
    for slot = 1, GUILD_SLOTS do td[slot] = nil end
    for slot = 1, GUILD_SLOTS do
        local link = GetGuildBankItemLink(tab, slot)
        if link then
            local tex, count, _, _, quality = GetGuildBankItemInfo(tab, slot)
            td[slot] = { IdOf(link) or 0, count or 1, link, tex, type(quality) == "number" and quality or ns.QualityOf(link) }
        end
    end
    td.t, g.t = time(), time()
end

local function GuildNext()
    if InCombatLockdown() then
        -- interrupted by combat: not "blocked", so PLAYER_REGEN_ENABLED can start the scan again (GuildStartQueue
        -- already does nothing while in combat)
        gcur, gq, gstarted = nil, nil, false
        return
    end
    gcur = gq and table.remove(gq, 1) or nil
    if not gcur then
        gq, gstarted = nil, false
        C_Timer.After(0.25, function()
            if ns.atGuild then RestoreGuildTab() end
        end)
        return
    end
    local mine = gcur
    if SetCurrentGuildBankTab then SetCurrentGuildBankTab(mine) end
    if QueryGuildBankTab then QueryGuildBankTab(mine) end
    WatchGuildTab(mine)
end

local function GuildStartQueue()
    if InCombatLockdown() then
        gcur, gq, gstarted = nil, nil, false
        return
    end
    if gstarted or gcur or guildScanBlocked or not ns.atGuild then return end
    if not (SetCurrentGuildBankTab and QueryGuildBankTab) then
        print("|cffffd100GTBag|r: guild bank tab queries are unavailable on this client.")
        return
    end
    local g = ns.SaveGuildMeta()
    if not (g and g.numTabs and g.numTabs > 0) then return end
    gstarted = true
    gq = {}
    local cur = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
    gOrigTab = gOrigTab or cur           -- keep the tab from before an interrupted scan, so the restore goes to the right tab
    local order = { cur }
    for t = 1, g.numTabs do if t ~= cur then order[#order + 1] = t end end
    for _, t in ipairs(order) do
        if g.tabs[t] and not g.tabs[t].noView then gq[#gq + 1] = t end
    end
    GuildNext()
end

-- tab choice in the window while at the guild bank: ask the server for that tab again
function ns.GuildSelect(tab)
    ns.view.gtab = tab
    if tab > 0 and ns.atGuild and ns.ViewingSelf() and not InCombatLockdown() and not gcur and not guildScanBlocked
        and SetCurrentGuildBankTab and QueryGuildBankTab then
        gq, gstarted, gcur = {}, true, tab
        SetCurrentGuildBankTab(tab)
        QueryGuildBankTab(tab)
        WatchGuildTab(tab)
    end
    ns.Relayout()
end

-- ---------------------------------------------------------------------------------------------- interactions
local function Focus(tab)
    ns.view.char, ns.view.tab = nil, tab
    ns.Open()
    ns.Relayout()
end

function ns.BankOpened()
    if ns.atBank then return end
    ns.atBank = true
    ns.bankOpenedAt = GetTime and GetTime() or 0          -- the game opens the bags along with the bank (see Hooks.lua)
    C_Timer.After(0.5, function() if ns.atBank then ns.SaveChar("bank") end end)
    if ns.Opt("replace") and ns.Opt("replaceBank") then
        Focus("bank")
    end
end

function ns.BankClosed()
    if not ns.atBank then return end
    ns.atBank = false                  -- the last save happened with the last change; slots cannot be read reliably now
    if ns.view.tab == "bank" and ns.ViewingSelf() then ns.view.tab = "bags" end
    ns.Relayout()
end

function ns.GuildOpened()
    if ns.atGuild then return end
    ns.atGuild, gstarted = true, false
    guildScanBlocked = false
    local r = MyRec()
    if not r.guild then ns.SaveChar() end
    if ns.Opt("replace") and ns.Opt("replaceGuild") then
        Focus("guild")
    end
    GuildStartQueue()
end

function ns.GuildClosed()
    if not ns.atGuild then return end
    ns.atGuild, gstarted, gq, gcur, gOrigTab = false, false, nil, nil, nil
    guildScanBlocked = false
    if ns.view.tab == "guild" and ns.ViewingSelf() then ns.view.tab = "bags" end
    ns.Relayout()
end

local function MailOpened()
    ns.atMail = true
    C_Timer.After(0.5, function() if ns.atMail then ns.SaveMail() end end)
end
local function MailClosed()
    ns.atMail = false
    if ns.view.tab == "mail" then ns.Relayout() end
end

-- ---------------------------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
for _, e in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "PLAYER_GUILD_UPDATE",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
    "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_UPDATE_MONEY",
    "GUILDBANK_UPDATE_TABS", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_FAILED",
    "VOID_STORAGE_OPEN", "VOID_STORAGE_CLOSE", "VOID_STORAGE_UPDATE", "VOID_STORAGE_CONTENTS_UPDATE",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED", "AUCTION_OWNED_LIST_UPDATE",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "PLAYER_REGEN_ENABLED",
}) do
    pcall(ev.RegisterEvent, ev, e)          -- an event this client does not have is simply skipped
end

local PIT = Enum and Enum.PlayerInteractionType
ev:SetScript("OnEvent", function(_, event, arg1)
    ns.dataVersion = ns.dataVersion + 1
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            ev:UnregisterEvent("ADDON_LOADED")
            -- the default window layout is applied once per install (first install, and when this layout was introduced):
            -- later changes you make are kept.  /gtbag layout or Settings > Apply default layout does it again.
            GTBagDB = type(GTBagDB) == "table" and GTBagDB or {}
            if GTBagDB.layoutV ~= 1 then
                local hadData = next(GTBagDB.chars or {}) ~= nil
                GTBagDB.layoutV = 1
                if ns.ApplyDefaultLayout then ns.ApplyDefaultLayout() end
                if hadData then
                    C_Timer.After(4, function()
                        print("|cffffd100GTBag|r: window layout set to the new default once (category view, 10 columns, tab row hidden). /gtbag layout applies it again.")
                    end)
                end
            end
            -- privacy starts off after every login / reload, unless "Privacy on at login" is ticked
            ns.SetOpt("scrambleNames", ns.Opt("privacyAtLogin") and true or false)
            if ns.ApplyBlizzardNames then ns.ApplyBlizzardNames() end
            if ns.ApplyNameplateHide then ns.ApplyNameplateHide() end
            if UnitName and UnitName("player") then
                ns.SaveChar("none")
                ns.QueueSave("bags")           -- the core loads after login, so PLAYER_LOGIN never reaches this file: snapshot the bags now
                local key = ns.MyKey()
                C_Timer.After(10, function() if ns.MyKey() == key then SaveMoney(false) end end)
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.atGuild then GuildStartQueue() end
        if ns.Relayout then ns.Relayout() end
    elseif event == "PLAYER_LOGIN" then
        ns.SaveChar("none")                -- the record exists from the first login; bag contents follow with BAG_UPDATE_DELAYED
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ns.RefreshMyKey then ns.RefreshMyKey() end
        if ns.MergeHardcoreTwins then ns.MergeHardcoreTwins() end     -- also clears twins saved by older versions
        local key = ns.MyKey()
        C_Timer.After(10, function()
            if ns.MyKey() == key then SaveMoney(false) end
        end)
    elseif event == "PLAYER_LOGOUT" then
        ns.SaveChar("bags")
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.QueueSave("bags")
        if ns.atBank then ns.QueueSave("bank") end
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        if ns.atBank then ns.QueueSave("bank") end
    elseif event == "PLAYER_MONEY" then
        SaveMoney(true)
    elseif event == "PLAYER_GUILD_UPDATE" then
        if IsInGuild and not IsInGuild() then
            local r = DB().chars[ns.MyKey()]
            if r then r.guild = nil end
        else
            ns.SaveChar("none")
        end
    elseif event == "BANKFRAME_OPENED" then ns.BankOpened()
    elseif event == "BANKFRAME_CLOSED" then ns.BankClosed()
    elseif event == "GUILDBANKFRAME_OPENED" then ns.GuildOpened()
    elseif event == "GUILDBANKFRAME_CLOSED" then ns.GuildClosed()
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        if not ns.atGuild then return end
        local currentTab = GetCurrentGuildBankTab and GetCurrentGuildBankTab()
        if gcur and currentTab and currentTab ~= gcur then
            gq, gcur, gstarted, guildScanBlocked = nil, nil, false, true
            print("|cffffd100GTBag|r: guild bank scan stopped because the active tab changed during a query.")
            return
        end
        local tab = gcur or currentTab
        if tab then ns.SaveGuildTab(tab) end
        if gcur then gcur = nil; GuildNext() end
        ns.Relayout()
    elseif event == "GUILDBANK_UPDATE_TABS" then
        if ns.atGuild then ns.SaveGuildMeta(); GuildStartQueue(); ns.Relayout() end
    elseif event == "GUILDBANK_UPDATE_MONEY" then
        if ns.atGuild then ns.SaveGuildMeta(); ns.Relayout() end
    elseif event == "MAIL_SHOW" then MailOpened()
    elseif event == "MAIL_CLOSED" then MailClosed()
    elseif event == "MAIL_INBOX_UPDATE" then
        if ns.atMail then ns.SaveMail() end
    elseif event == "MAIL_SEND_SUCCESS" then CommitSend()
    elseif event == "MAIL_FAILED" then pendingSend = nil
    elseif event == "VOID_STORAGE_OPEN" or event == "VOID_STORAGE_UPDATE" or event == "VOID_STORAGE_CONTENTS_UPDATE" then
        ns.RefreshVoidStorage()
    elseif event == "AUCTION_HOUSE_SHOW" or event == "OWNED_AUCTIONS_UPDATED" or event == "AUCTION_OWNED_LIST_UPDATE" then
        ns.RefreshAuctions()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and PIT then
        if arg1 == PIT.Banker then ns.BankOpened()
        elseif arg1 == PIT.GuildBanker then ns.GuildOpened()
        elseif arg1 == PIT.MailInfo then MailOpened() end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and PIT then
        if arg1 == PIT.Banker then ns.BankClosed()
        elseif arg1 == PIT.GuildBanker then ns.GuildClosed()
        elseif arg1 == PIT.MailInfo then MailClosed() end
    end
end)

-- ---------------------------------------------------------------------------------------------- sources
-- What the window shows right now.  { kind, rec, self, live, containers = { {id, n, get(slot), secure, label} },
-- items = { info... } (mail), money, updated, notice, guild }
function ns.Source()
    local v = ns.view
    local rec = DB().chars[ns.ViewKey()]
    local isSelf = ns.ViewingSelf()
    local src = { kind = v.tab, rec = rec, self = isSelf, containers = {}, live = false, money = rec and rec.money }
    local who = rec and ns.ClassName(rec, false, true) or "this character"

    if v.tab == "bags" or v.tab == "bank" then
        local bank = v.tab == "bank"
        local ids = bank and ns.BANK_IDS or ns.BAGS
        local cache = rec and (bank and rec.bank or rec.bags)
        src.live = isSelf and (not bank or ns.atBank)
        for _, id in ipairs(ids) do
            if src.live then
                local n = ns.GetNumSlots(id)
                if type(n) == "number" and n > 0 then
                    src.containers[#src.containers + 1] = { id = id, n = n, liveSlot = true,
                        isQuiverBag = not bank and ns.IsQuiverBag(id),
                        label = ns.ContainerLabel(v.tab, id),
                        get = function(slot) return ns.ItemInfo(id, slot) end }
                end
            else
                local c = cache and cache[id]
                if c and c.n and c.n > 0 then
                    src.containers[#src.containers + 1] = { id = id, n = c.n, isQuiverBag = not bank and c.isQuiverBag,
                        label = ns.ContainerLabel(v.tab, id),
                        get = function(slot) return Unpack(c[slot]) end }
                end
            end
        end
        src.updated = rec and (bank and rec.bankT or rec.bagsT)
        if #src.containers == 0 then
            src.notice = bank and ("No bank data for " .. who .. " yet.\nOpen the bank with this character once.")
                              or ("No bag data for " .. who .. " yet.\nLog in with this character once.")
        end

    elseif v.tab == "guild" then
        local g = ns.GuildRec(rec)
        src.guild, src.live = g, isSelf and ns.atGuild
        src.money = g and g.money
        src.updated = g and g.t
        if g then
            for t = 1, (g.numTabs or 0) do
                local td = g.tabs[t]
                if td and not td.noView and (v.gtab == 0 or v.gtab == t) then
                    src.containers[#src.containers + 1] = { id = t, n = GUILD_SLOTS,
                        label = td.name and (tostring(td.name) .. " (Guild tab " .. t .. ")") or ("Guild tab " .. t),
                        get = function(slot) return Unpack(td[slot]) end }
                end
            end
        end
        if #src.containers == 0 then
            src.notice = "No guild bank data yet.\nOpen the guild bank with a member of " .. ns.GuildName((g and g.name) or (rec and rec.guild) or "the guild") .. "."
        end

    elseif v.tab == "mail" then
        local m = rec and rec.mail
        src.live = isSelf and ns.atMail
        src.items = {}
        src.updated = m and m.t
        src.mailGold = m and m.gold or 0
        src.mails = m and m.mails or 0
        if m then
            local now = time()
            for _, it in ipairs(m.items) do
                local left = (it.days or 30) - (now - (it.t or m.t or now)) / 86400
                if left > 0 then
                    src.items[#src.items + 1] = {
                        id = it.id, count = it.count, link = it.link, icon = it.icon or IconOf(it.id),
                        quality = it.q or ns.QualityOf(it.link), cached = true,
                        badge = left < 3 and (math.max(1, math.ceil(left)) .. "d") or nil,
                        mail = { from = it.from, left = left, cod = it.cod, sent = it.sent, idx = it.idx, att = it.att },
                    }
                end
            end
        end
        if #src.items == 0 then
            src.notice = m and ("No items in the mail of " .. who .. ".")
                            or ("No mail data for " .. who .. " yet.\nOpen a mailbox with this character once.")
        end

    end
    return src
end

-- calls fn(info) for every slot (nil for an empty one) and every mail item of a source
function ns.EachSlot(src, fn)
    for _, c in ipairs(src.containers) do
        for slot = 1, c.n do fn(c.get(slot)) end
    end
    if src.items then for _, info in ipairs(src.items) do fn(info) end end
end

-- ---------------------------------------------------------------------------------------------- search all characters
-- Looks through the saved bags, bank, mail, void storage, auctions and guild banks of every known character (your own
-- bags and an open bank are read live).  Every word of the query must match (name, category, item type).  Returns
--   groups = { { key = charKey | nil, rec = rec, guild = guildName | nil, rows = { row, ... } }, ... }, totalItems
-- where row = { loc, tab, id, link, icon, quality, count }.  Same item in the same place is added up.
local FIND_MAX_ROWS = 400
function ns.FindAll(query)
    query = tostring(query or ""):lower():match("^%s*(.-)%s*$") or ""
    if query == "" then return {}, 0 end
    local words = {}
    if ns.QueryHas and ns.QueryHas(query) then words[1] = query        -- a query with operators is one piece
    else for w in query:gmatch("%S+") do words[#words + 1] = w end end

    local function Wanted(info)
        for _, w in ipairs(words) do
            if not ns.Matches(info, w) then return false end
        end
        return true
    end

    local groups, shown, total, trimmed = {}, 0, 0, false
    -- the row budget is shared out: each character or guild gets an equal share of what is left when its turn comes, so
    -- the ones listed first cannot use it all (what a small one leaves unused goes to the ones after it)
    local groupsLeft = 0
    for _, key in ipairs(ns.CharKeys()) do if ns.Rec(key) then groupsLeft = groupsLeft + 1 end end
    for _ in pairs(DB().guilds or {}) do groupsLeft = groupsLeft + 1 end
    local function NewGroup(key, rec, guild)
        local g = { key = key, rec = rec, guild = guild, rows = {}, index = {} }
        g.quota = math.max(1, math.ceil((FIND_MAX_ROWS - shown) / math.max(1, groupsLeft)))
        groupsLeft = groupsLeft - 1
        groups[#groups + 1] = g
        return g
    end
    local function Add(g, loc, tab, info, t)
        if not (info and info.id) then return end
        if not Wanted(info) then return end
        local count = tonumber(info.count) or 1
        total = total + 1
        local k = loc .. ":" .. tostring(info.id)
        local row = g.index[k]
        if row then row.count = row.count + count; return end
        if shown >= FIND_MAX_ROWS or #g.rows >= g.quota then trimmed = true; return end
        shown = shown + 1
        row = { loc = loc, tab = tab, id = info.id, link = info.link, icon = info.icon or IconOf(info.id),
                quality = info.quality or ns.QualityOf(info.link), count = count, t = t }
        g.index[k] = row
        g.rows[#g.rows + 1] = row
    end
    local function AddContainers(g, loc, tab, containers, t)
        for _, c in pairs(type(containers) == "table" and containers or {}) do
            if type(c) == "table" and type(c.n) == "number" then
                for slot = 1, c.n do
                    if c[slot] then Add(g, loc, tab, Unpack(c[slot]), t) end
                end
            end
        end
    end
    local function AddLive(g, loc, tab, ids)  -- live contents: t = now
        if not ns.GetNumSlots then return end
        for _, bag in ipairs(ids) do
            local n = ns.GetNumSlots(bag)
            if type(n) == "number" then
                for slot = 1, n do Add(g, loc, tab, ns.ItemInfo(bag, slot), time()) end
            end
        end
    end
    local function AddList(g, loc, tab, list, t)
        for _, it in ipairs(type(list) == "table" and list or {}) do
            Add(g, loc, tab, { id = it.id, count = it.count, link = it.link, icon = it.icon, quality = it.q or it.quality }, t)
        end
    end

    local me, now = ns.MyKey(), time()
    for _, key in ipairs(ns.CharKeys()) do
        local rec = ns.Rec(key)
        if rec then
            local g = NewGroup(key, rec)
            if key == me then
                AddLive(g, "Bags", "bags", ns.BAGS)
                if ns.atBank then AddLive(g, "Bank", "bank", ns.BANK_IDS) else AddContainers(g, "Bank", "bank", rec.bank, rec.bankT) end
            else
                AddContainers(g, "Bags", "bags", rec.bags, rec.bagsT)
                AddContainers(g, "Bank", "bank", rec.bank, rec.bankT)
            end
            local mail = type(rec.mail) == "table" and rec.mail or nil
            for _, it in ipairs(mail and type(mail.items) == "table" and mail.items or {}) do
                local left = (tonumber(it.days) or 30) - (now - (tonumber(it.t) or tonumber(mail.t) or now)) / 86400
                if left > 0 then
                    Add(g, "Mail", "mail", { id = it.id, count = it.count, link = it.link, icon = it.icon, quality = it.q }, mail.t)
                end
            end
            AddList(g, "Void storage", "bags", rec.void, rec.voidT)
            AddList(g, "Auctions", "bags", rec.auctions, rec.auctionsT)
        end
    end
    -- guild banks (shared by the members, so they are listed by guild)
    local names = {}
    for gk, g in pairs(DB().guilds or {}) do names[#names + 1] = { gk, g } end
    table.sort(names, function(a, b) return tostring(a[1]) < tostring(b[1]) end)
    for _, e in ipairs(names) do
        local gr = e[2]
        local g = NewGroup(nil, nil, gr.name or e[1])
        for t = 1, (gr.numTabs or 0) do
            local td = gr.tabs and gr.tabs[t]
            if type(td) == "table" and not td.noView then
                for slot, p in pairs(td) do
                    if type(slot) == "number" and type(p) == "table" then
                        Add(g, "Guild tab " .. t, "guild", Unpack(p), gr.t)
                    end
                end
            end
        end
    end

    local out = {}
    for _, g in ipairs(groups) do
        if #g.rows > 0 then
            table.sort(g.rows, function(a, b)
                if a.loc ~= b.loc then return a.loc < b.loc end
                local an, bn = ns.Name(a):lower(), ns.Name(b):lower()
                if an ~= bn then return an < bn end
                return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
            end)
            g.index = nil
            out[#out + 1] = g
        end
    end
    return out, total, trimmed
end
