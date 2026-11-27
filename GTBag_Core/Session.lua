-- Session.lua : what you picked up since you logged in (or since /gtbag session reset), what it is worth and the gold
-- per hour.  Shown in the tooltip of the money at the bottom of the window and with /gtbag session.
--   * It compares the item counts in your bags (per item id, not per slot) after every bag update and adds what went UP.
--   * Moving items between bags, picking one up on the cursor and putting it back, or changing gear is not "gained".
--   * While the bank, mailbox, guild bank, a vendor, a trade or the auction house is open, and while a profession window
--     is open, the counts are only re-read: taking items out of the bank or the mail is not farming.
--   * The running session is kept in GTBagDB.session (it survives /reload; after 30 minutes away a new one starts) and
--     the last 5 finished sessions in GTBagDB.sessionHistory.
local _, ns = ...

local function Say(msg) print("|cffffd100GTBag|r: " .. msg) end

local baseline, resync
local counts, links = {}, {}          -- reused: one scan per bag update, no new tables

local function Session()
    GTBagDB = GTBagDB or {}
    local key = ns.MyKey and ns.MyKey() or "?"
    if type(GTBagDB.sessions) ~= "table" then
        GTBagDB.sessions = {}
        if type(GTBagDB.session) == "table" then GTBagDB.sessions[key] = GTBagDB.session end
        GTBagDB.session = nil
    end
    local s = GTBagDB.sessions[key]
    if type(s) ~= "table" or type(s.gain) ~= "table" then
        s = { start = time(), last = time(), gain = {} }
        GTBagDB.sessions[key] = s
    end
    return s
end

-- item id -> number carried in the inventory bags (and one link per id, for its name and price)
local function Scan()
    wipe(counts); wipe(links)
    if not (ns.BAGS and #ns.BAGS > 0 and ns.GetNumSlots and ns.ItemInfo) then return false end
    for _, bag in ipairs(ns.BAGS) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" then
            for slot = 1, n do
                local info = ns.ItemInfo(bag, slot)
                if info and info.id then
                    counts[info.id] = (counts[info.id] or 0) + (tonumber(info.count) or 1)
                    if not links[info.id] then links[info.id] = info.link end
                end
            end
        end
    end
    return true
end

local function Shown(name)
    local f = _G[name]
    return f ~= nil and f.IsShown ~= nil and f:IsShown()
end
local function Blocked()
    return ns.atBank or ns.atMail or ns.atGuild or Shown("MerchantFrame") or Shown("TradeFrame")
        or Shown("AuctionFrame") or Shown("AuctionHouseFrame") or Shown("TradeSkillFrame") or Shown("CraftFrame")
        or Shown("ProfessionsFrame")
end

local function Remember()
    baseline = baseline or {}
    wipe(baseline)
    for id, n in pairs(counts) do baseline[id] = n end
end

local function Update()
    if not baseline then return end
    if GetCursorInfo and GetCursorInfo() then return end          -- an item is on the cursor: wait until it is put down
    if not Scan() then return end
    if resync or Blocked() then
        resync = false
        Remember()
        return
    end
    local s = Session()
    for id, n in pairs(counts) do
        local old = baseline[id] or 0
        if n > old then
            local g = s.gain[id]
            if not g then g = { n = 0 }; s.gain[id] = g end
            g.n = g.n + (n - old)
            g.link = g.link or links[id]
            s.last = time()
        end
    end
    Remember()
end

-- ---------------------------------------------------------------------------------------------- numbers
local function Duration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if h > 0 then return string.format("%dh %02dm", h, m) end
    return string.format("%dm", m)
end

-- { items = { { id, link, n, value }, ... best first }, total, count, elapsed, perHour }
function ns.SessionSummary(s)
    s = s or Session()
    local out = { items = {}, total = 0, count = 0, elapsed = time() - (s.start or time()) }
    for id, g in pairs(s.gain or {}) do
        local unit = ns.UnitValue(id, g.link) or 0
        local value = unit * (g.n or 0)
        out.items[#out.items + 1] = { id = id, link = g.link, n = g.n or 0, value = value }
        out.total = out.total + value
        out.count = out.count + (g.n or 0)
    end
    table.sort(out.items, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return (a.n or 0) > (b.n or 0)
    end)
    out.perHour = out.total / math.max(out.elapsed, 60) * 3600
    return out
end

-- finished sessions: newest first, at most 5
local function Archive(s)
    if not (s and next(s.gain or {})) then return end
    local sum = ns.SessionSummary(s)
    local key = ns.MyKey and ns.MyKey() or "?"
    GTBagDB.sessionHistoryByChar = GTBagDB.sessionHistoryByChar or {}
    if type(GTBagDB.sessionHistoryByChar[key]) ~= "table" then GTBagDB.sessionHistoryByChar[key] = {} end
    GTBagDB.sessionHistory = GTBagDB.sessionHistory or {}
    local entry = { start = s.start, stop = s.last or time(), value = sum.total,
        count = sum.count, perHour = sum.perHour }
    table.insert(GTBagDB.sessionHistoryByChar[key], 1, entry)
    while #GTBagDB.sessionHistoryByChar[key] > 5 do table.remove(GTBagDB.sessionHistoryByChar[key]) end
    table.insert(GTBagDB.sessionHistory, 1, entry)
    while #GTBagDB.sessionHistory > 5 do table.remove(GTBagDB.sessionHistory) end
end

function ns.SessionReset()
    Archive(Session())
    local key = ns.MyKey and ns.MyKey() or "?"
    if type(GTBagDB.sessions) == "table" then GTBagDB.sessions[key] = nil end
    GTBagDB.session = nil
    Session()
    if Scan() then Remember() end
end

-- ---------------------------------------------------------------------------------------------- output
-- extra lines for the tooltip of the money at the bottom of the window
function ns.SessionTooltip(tt)
    if not ns.ViewingSelf() then return end
    local sum = ns.SessionSummary()
    tt:AddLine(" ")
    tt:AddDoubleLine("This session", Duration(sum.elapsed), 1, 0.82, 0, 0.7, 0.7, 0.7)
    if sum.count == 0 then
        tt:AddLine("Nothing picked up yet.", 0.7, 0.7, 0.7)
        return
    end
    tt:AddDoubleLine("Picked up  x" .. sum.count, ns.Money(sum.total), 1, 1, 1, 1, 1, 1)
    tt:AddDoubleLine("Per hour", ns.Money(sum.perHour), 0.8, 0.8, 0.8, 1, 1, 1)
    for i = 1, math.min(5, #sum.items) do
        local it = sum.items[i]
        if it.value > 0 then
            tt:AddDoubleLine(ns.Name({ id = it.id, link = it.link }) .. "  x" .. it.n, ns.Money(it.value),
                0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
        end
    end
    tt:AddLine("/gtbag session reset starts a new one.", 0.5, 0.5, 0.5)
end

function ns.SessionPrint(history)
    if history then
        local key = ns.MyKey and ns.MyKey() or "?"
        local list = GTBagDB and type(GTBagDB.sessionHistoryByChar) == "table"
            and GTBagDB.sessionHistoryByChar[key]
        if type(list) ~= "table" then list = GTBagDB and GTBagDB.sessionHistory end
        if type(list) ~= "table" or #list == 0 then Say("no finished sessions yet."); return end
        for i, h in ipairs(list) do
            Say(string.format("%d. %s  %s  %d items, worth %s (%s per hour)", i, date("%d %b %H:%M", h.start or 0),
                Duration((h.stop or 0) - (h.start or 0)), h.count or 0, ns.Money(h.value or 0), ns.Money(h.perHour or 0)))
        end
        return
    end
    local sum = ns.SessionSummary()
    Say(string.format("this session: %s, %d items picked up, worth %s, %s per hour.", Duration(sum.elapsed), sum.count,
        ns.Money(sum.total), ns.Money(sum.perHour)))
    for i = 1, math.min(8, #sum.items) do
        local it = sum.items[i]
        print(string.format("   %s x%d  %s", ns.Name({ id = it.id, link = it.link }), it.n, ns.Money(it.value)))
    end
end

-- ---------------------------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE_DELAYED" then
        Update()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        resync = true                       -- gear coming out of the bags or going into them is not farming
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- a few seconds after the loading screen, when the bag contents are known
        if ns.RefreshMyKey then ns.RefreshMyKey() end
        C_Timer.After(3, function()
            local key = ns.MyKey and ns.MyKey() or "?"
            local s = GTBagDB and type(GTBagDB.sessions) == "table" and GTBagDB.sessions[key]
            if type(s) == "table" and time() - (s.last or s.start or 0) > 1800 then
                Archive(s)
                GTBagDB.sessions[key] = nil
            end
            Session()
            if Scan() then Remember() end
        end)
    end
end)
