-- Loot.lua
local addonName, GT = ...
local SNAP_DIST = GT.SNAP_DIST
local nodes = GT.nodes
local order = GT.order
local stats = GT.stats
local visitedSid = GT.visitedSid
GT.sessionGatheredSpots = GT.sessionGatheredSpots or {}

-- other items one node can give (Thorium veins: Arcane Crystal, gems...), by item id -> node key
local EXTRA_ID_KEY = {}
for _, key in ipairs(order) do
    for _, id in ipairs(nodes[key].extraIds or {}) do EXTRA_ID_KEY[id] = key end
end

-- the item's name in the client's language (from the game's item cache), lower case; nil while not cached
local function LocalName(id)
    local n
    if C_Item and C_Item.GetItemNameByID then n = C_Item.GetItemNameByID(id)
    elseif GetItemInfo then n = GetItemInfo(id) end
    return type(n) == "string" and n:lower() or nil
end

-- Items a node gives besides its own (Thorium veins: Arcane Crystal, gems ...) still start the timer, but they are not
-- "what you gathered": they stay out of the session count and the per-hour numbers ("Thorium: 14", "Total").
local function CountsAsGathered(key, itemID)
    return not (itemID and itemID ~= nodes[key].id and EXTRA_ID_KEY[itemID] == key)
end

local function MatchNode(itemName, itemID)
    -- 1. by item id: the same in every client language
    if itemID then
        for _, key in ipairs(order) do
            if nodes[key].id == itemID then return key, itemID end
        end
        if EXTRA_ID_KEY[itemID] then return EXTRA_ID_KEY[itemID], itemID end
    end
    if itemName then
        local lname = itemName:lower()
        -- 2. no item id given: by the item name in the client's own language (the names the game gives these ids)
        if not itemID then
            for _, key in ipairs(order) do
                local def = nodes[key]
                if LocalName(def.id) == lname then return key, def.id end
                for _, id in ipairs(def.extraIds or {}) do
                    if LocalName(id) == lname then return key, id end
                end
            end
        end
        -- 3. last resort, English names only - and only when the loot gave NO item id (an id that matched nothing
        --    above is not a gathering item; a loose name match like "ruby" or "arcane" must not claim it)
        if not itemID then
            for _, key in ipairs(order) do
                local def = nodes[key]
                if def.sub then
                    if lname:find(def.match:lower(), 1, true) then return key, def.id end
                elseif lname == def.match:lower() then
                    return key, def.id
                end
                if def.extra then
                    for i, word in ipairs(def.extra) do
                        if lname:find(word:lower(), 1, true) then return key, def.extraIds and def.extraIds[i] end
                    end
                end
            end
        end
    end
    return nil
end

-- The loot position is where YOU stand, a few yards from the node. While gathering the character
-- faces the node, so move the point that many yards along the facing direction.
-- (needs HereBeDragons for the zone size; without it the player position is used as before)
local function NodePosition(mapID, px, py)
    local yd = GT.cfg().nodeOffsetYd or 0
    if yd <= 0 or not (GT.HBD and GT.HBD.GetZoneSize) or not GetPlayerFacing then return px, py end
    local facing = GetPlayerFacing()
    local w, h = GT.HBD:GetZoneSize(mapID)
    if not facing or not w or not h or w <= 0 or h <= 0 then return px, py end
    -- facing: 0 = north, grows counter-clockwise.  map x grows east, map y grows south.
    return px - math.sin(facing) * yd / w, py - math.cos(facing) * yd / h
end

local function AddNode(key, source, qty)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then GT.dprint("no map position here"); return false end
    local px, py = pos:GetXY()
    if not px or not py then GT.dprint("map position is empty"); return false end
    px, py = NodePosition(mapID, px, py)
    px, py = GT.Round5(px), GT.Round5(py)
    local list = GatherTimesDB[key]
    local snap = GT.FindNearestImported(key, mapID, px, py, SNAP_DIST)
    if GT.cfg().groupMode then
        local near = snap or GT.FindSpawn(key, mapID, px, py)
        if near and near.lootTime and (GetServerTime() - near.lootTime) < 45 then
            GT.dprint("duplicate, ignored (" .. source .. ")")
            return false
        end
    else
        for _, existing in ipairs(list) do
            local dist = math.sqrt((existing.x - px)^2 + (existing.y - py)^2)
            if dist < 0.005 and (GetServerTime() - existing.time) < 45 then
                GT.dprint("duplicate, ignored (" .. source .. ")")
                return false
            end
        end
    end
    local sp
    if snap then
        snap.hits = (snap.hits or 0) + 1
        snap.last = GetServerTime()
        sp = snap
    else
        sp = GT.MergeSpawn(key, mapID, px, py)
        -- refine the spot with every visit (running average) instead of keeping the first position forever
        if (sp.hits or 1) > 1 and not sp.imported then
            sp.x = GT.Round5(sp.x + (px - sp.x) / sp.hits)
            sp.y = GT.Round5(sp.y + (py - sp.y) / sp.hits)
        end
    end
    local nowT = GetServerTime()
    local prevLoot = sp.lootTime
    local ex, ey, grp, gidx = sp.x, sp.y, nil, nil
    if GT.cfg().groupMode then
        local res = GT.ComputeGroups(key, mapID)
        local gi = res.of[sp]
        if gi then
            grp = res.groups[gi]
            gidx = gi
            -- Timers of this group that were looted so recently that this loot cannot be their respawn: more than
            -- one node is up at once, so the group tracks more timers.  Done BEFORE the sample is measured, so
            -- the first loot that shows it is not measured against the wrong node.
            local window = math.min(600, nodes[key].timer * 0.4)
            local recent = 0
            for _, n in ipairs(GT.GroupEntries(key, sp)) do
                if not n.est and (nowT - n.time) < window then recent = recent + 1 end
            end
            if recent > 0 then GT.RaiseGroupCapacity(key, mapID, gi, recent + 1) end
            -- the loot this node is the respawn of (see GT.RespawnReference)
            prevLoot = GT.RespawnReference(grp, GT.GroupCapacity(key, mapID, gi))
        end
    end
    sp.lootTime = nowT
    GT.RegisterLoot(sp)
    pcall(GT.RecordInterval, key, prevLoot, nowT, mapID)
    if GT.dwell and GT.dwell.sp == sp then GT.dwell = nil end
    sp.lastQty = qty                                  -- items the last loot at this spot gave
    local entry = { mapID = mapID, x = ex, y = ey, time = GetServerTime(), sid = sp.sid, qty = qty, realm = GT.RealmName() }
    table.insert(list, entry)
    GT.lastLootRec = { key = key, sp = sp, node = entry, t = GetTime() }
    local gathered = GT.sessionGatheredSpots[key]
    if not gathered then gathered = {}; GT.sessionGatheredSpots[key] = gathered end
    gathered[sp.sid] = true
    if grp then
        for _, m in ipairs(grp) do visitedSid[m.sid] = nil end
        pcall(GT.NormalizeGroupTimers)
    end
    GT.dprint("timer added for " .. key .. " via " .. source .. " (spawn #" .. sp.sid .. ")")
    return true
end

-- ============================================================
-- CHAT_MSG_LOOT lines
-- ============================================================
-- Turn one of the game's loot format strings ("You receive loot: %s", "%sx%d" ...) into a Lua pattern.
local function FormatToPattern(s)
    s = s:gsub("%%%d%$", "%%")                        -- "%1$s" -> "%s"
    s = s:gsub("%%[sd]", { ["%s"] = "\1", ["%d"] = "\2" })
    s = s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")  -- escape everything that is special in a pattern
    s = s:gsub("\1", ".+"):gsub("\2", "%%d+")
    return "^" .. s
end

-- The client's own loot lines, as patterns.  Two groups:
--   own  = the player's NODE loot ("You receive loot: %s.", with and without an amount)
--   skip = the player's other item lines: pushed into the bags (quest reward, trade, mail ...), created, bonus roll.
--          None of them is what a gathering node gives.
-- A format string that is the same text in both groups counts as node loot (a language that does not tell them apart).
local OWN_FORMATS = { "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE" }
local SKIP_FORMATS = { "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_BONUS_ROLL_SELF", "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE" }

local lootPatterns
local function LootPatterns()
    if lootPatterns then return lootPatterns end
    local own, skip, ownText = {}, {}, {}
    local function add(list, text)
        local ok, p = pcall(FormatToPattern, text)
        if ok then list[#list + 1] = p end
    end
    for _, name in ipairs(OWN_FORMATS) do
        local s = _G[name]
        if type(s) == "string" and s ~= "" then ownText[s] = true; add(own, s) end
    end
    for _, name in ipairs(SKIP_FORMATS) do
        local s = _G[name]
        if type(s) == "string" and s ~= "" and not ownText[s] then add(skip, s) end
    end
    lootPatterns = { own = own, skip = skip }
    return lootPatterns
end
function GT.ResetLootPatterns() lootPatterns = nil end      -- (the client strings are read once; tests change them)

local function MatchesAny(list, msg)
    for _, p in ipairs(list) do
        if msg:find(p) then return true end
    end
    return false
end

-- A loot line in the chat -> itemName, itemID, qty  (nil when it is not the player's node loot).
-- guid = the looter's GUID (12th CHAT_MSG_LOOT argument): it tells my loot from other players' loot in any language.
-- Without it the client's own "You receive loot: ..." strings decide; only when the client gives none, the English
-- "You receive loot:" is the last resort.  Lines about items pushed into the bags, created or bonus-rolled are
-- never node loot, with or without the GUID.
function GT.ParseLootChat(msg, guid)
    local p = LootPatterns()
    local nodeLine = MatchesAny(p.own, msg)
    local mine
    if type(guid) == "string" and guid ~= "" then
        mine = (guid == UnitGUID("player"))
    elseif #p.own > 0 then
        mine = nodeLine
    else
        mine = msg:find("^You receive loot:") ~= nil
    end
    if not mine then return nil end
    if not nodeLine and MatchesAny(p.skip, msg) then return nil end
    local itemName = msg:match("%[(.-)%]")
    local itemID = tonumber(msg:match("item:(%d+)"))
    if not itemName and not itemID then return nil end
    -- "<link>x5" (a full stop of any kind may follow, e.g. the Chinese / Japanese one)
    local qty = tonumber(msg:match("|h|rx(%d+)")) or tonumber(msg:match("x(%d+)%.?%s*$")) or 1
    return itemName, itemID, qty
end

local lastLootChat = {}
local pendingLoot = {}          -- item -> { t, n }: what the loot window already added to the session stats
local PENDING_WINDOW = 5        -- seconds in which the chat line of that loot is matched to it
function GT.HandleItem(itemName, itemID, source, qty)
    GT.dprint(source .. " item:", itemName or "?", itemID or "?")
    local key, resolvedID = MatchNode(itemName, itemID)
    -- every other item you loot (mob drops, chests, a node's extra items ...) goes in the session summary too.
    -- The chat line is used: it is only the player's own loot and carries the exact amount.
    if source == "chat" and itemID and (not key or not CountsAsGathered(key, itemID)) then
        pcall(GT.AddOtherLoot, itemID, qty)
    end
    if not key then return end
    itemID = itemID or resolvedID
    GT.dprint("matched:", key)
    -- only loot that comes from a node counts (not mob drops, trades, mail, vendors)
    if not GT.LootFromNode() then
        GT.dprint("not from a node (no gather attempt / loot source is not a node), ignored")
        return
    end
    local dedupeKey = tostring(itemID or itemName or "?")
    local now = GetTime()
    if source == "chat" then
        -- LOOT_OPENED comes BEFORE the chat line, so the loot window has usually counted this already:
        -- the chat line then only corrects the difference (it carries the exact amount) instead of adding it again
        local pend = pendingLoot[dedupeKey]
        local already = (pend and (now - pend.t) <= PENDING_WINDOW) and pend.n or 0
        pendingLoot[dedupeKey] = nil
        if CountsAsGathered(key, itemID) then
            stats.counts[key] = math.max(0, (stats.counts[key] or 0) + (qty or 1) - already)
            if GT.SaveSession then pcall(GT.SaveSession) end
        end
        lastLootChat[dedupeKey] = now
        local added = AddNode(key, source, qty)
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        GT.RecordZoneYield(key, mapID, itemID, (qty or 1) - already, already == 0, added)
        -- the loot window may have created the timer a moment earlier (without the exact amount):
        -- the chat line carries the real count, so fix it up
        local rec = GT.lastLootRec
        if not added and qty and rec and rec.key == key and (now - rec.t) < 2 then
            rec.sp.lastQty, rec.node.qty = qty, qty
        end
    elseif source == "loot" then
        if not lastLootChat[dedupeKey] or (now - lastLootChat[dedupeKey]) > 1.0 then
            local n = qty or 1
            if CountsAsGathered(key, itemID) then
                stats.counts[key] = (stats.counts[key] or 0) + n
                if GT.SaveSession then pcall(GT.SaveSession) end
            end
            pendingLoot[dedupeKey] = { t = now, n = n }
            local added = AddNode(key, source, qty)
            local mapID = C_Map.GetBestMapForUnit("player")
            GT.RecordZoneYield(key, mapID, itemID, n, true, added)
        else
            GT.dprint("duplicate loot (chat already handled), ignored")
        end
    end
end

-- ============================================================
-- EVENT FRAME
-- ============================================================
