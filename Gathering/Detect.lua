-- Detect.lua
local addonName, GT = ...
local UI = GT.UI
local nodes = GT.nodes
local order = GT.order
local visitedSid = GT.visitedSid

-- How a "taken by someone" message is recognised, most reliable first (none of it depends on English):
--   1. the game's own message name for UI_ERROR_MESSAGE's error number (GetGameMessageInfo), e.g. ERR_NO_LOOT
--   2. the client's own text for those same messages (the global string, already in the player's language)
--   3. the old English phrases, kept as a last resort for client builds that word the message differently
local BUSY_IDS = { ERR_CHEST_IN_USE = true, SPELL_FAILED_CHEST_IN_USE = true }       -- "That is already being used."
local GONE_IDS = { ERR_NO_LOOT = true, ERR_LOOT_CANT_LOOT_THAT_NOW = true }          -- "There is no loot." / "You can't loot that item now."
local BUSY_TEXT = { "already using", "someone is using", "someone else is already" }
local GONE_TEXT = { "there is no loot", "can't loot that item right now", "cannot loot that item right now" }
local lastMsgAt = {}

-- ============================================================
-- GATHER ATTEMPTS + LOOT SOURCE
-- ============================================================
-- Loot and "taken by someone" messages only count when they belong to a node:
--   * UNIT_SPELLCAST_SENT with a Herb Gathering / Mining spell marks a gather attempt (GT.NoteGatherCast)
--   * LOOT_OPENED: GetLootSourceInfo tells whether the loot comes from a GameObject (a node) or from a
--     creature / something else (GT.NoteLootOpened); LOOT_CLOSED ends that window (GT.NoteLootClosed)
-- Without this, mob drops of herbs / ore, trades, mail, vendors and an empty corpse ("There is no loot")
-- looked like a node and created fake timers and false "taken" marks.
local TAKEN_RADIUS_YD = 10       -- a "busy / no loot" message only counts for a spot this close (you gather from a few yards)
local GATHER_WINDOW = 15            -- seconds a gather attempt stays valid
local GATHER_SPELLS = {
    [2366] = true, [2368] = true, [3570] = true, [11993] = true, [28695] = true, [50300] = true, [74519] = true,  -- Herb Gathering
    [2575] = true, [2576] = true, [3564] = true, [10248] = true, [29354] = true, [50310] = true, [74517] = true,  -- Mining
}
local gatherNames                   -- the spell names (client language), filled on first use
local function GatherNames()
    if gatherNames then return gatherNames end
    gatherNames = {}
    for _, id in ipairs({ 2366, 2575 }) do
        local n
        if C_Spell and C_Spell.GetSpellName then n = C_Spell.GetSpellName(id)
        elseif GetSpellInfo then n = GetSpellInfo(id) end
        if type(n) == "string" then gatherNames[n] = true end
    end
    return gatherNames
end

local lastGatherAt = 0
-- spell = the spell id (or name on very old clients) from UNIT_SPELLCAST_SENT
function GT.NoteGatherCast(spell)
    if (type(spell) == "number" and GATHER_SPELLS[spell]) or (type(spell) == "string" and GatherNames()[spell]) then
        lastGatherAt = GetTime()
    end
end
function GT.GatherAttemptRecent(window)
    return lastGatherAt > 0 and (GetTime() - lastGatherAt) <= (window or GATHER_WINDOW)
end

local lootCtx                       -- { open, closedAt, t, node = true (a node) / false (not a node) / nil (unknown) }
function GT.NoteLootOpened()
    local node
    if GetLootSourceInfo and GetNumLootItems then
        for slot = 1, GetNumLootItems() do
            local info = { GetLootSourceInfo(slot) }
            for i = 1, #info, 2 do
                local guid = info[i]
                if type(guid) == "string" then
                    if guid:find("^GameObject") then node = true
                    elseif node == nil then node = false end
                end
            end
        end
    end
    lootCtx = { open = true, t = GetTime(), node = node }
end
function GT.NoteLootClosed()
    if lootCtx then lootCtx.open = false; lootCtx.closedAt = GetTime() end
end

-- Is this item pickup (a chat line or a loot window slot) the result of gathering a node?
-- 1. a loot window of the last moments with a known source decides on its own (node: yes, anything else: no)
-- 2. otherwise (no source info on this client) a gather attempt of the last few seconds is required
function GT.LootFromNode()
    local c = lootCtx
    local live = c and ((c.open and (GetTime() - c.t) < 120) or (c.closedAt and (GetTime() - c.closedAt) < 2))
    if live and c.node ~= nil then return c.node end
    return GT.GatherAttemptRecent()
end

-- the client-language text of the messages above (global strings without %s / %d placeholders), lower case
local function LocalTexts(ids)
    local out = {}
    for name in pairs(ids) do
        local s = _G[name]
        if type(s) == "string" and s ~= "" and not s:find("%%") then out[#out + 1] = s:lower() end
    end
    return out
end
local BUSY_LOCAL, GONE_LOCAL = LocalTexts(BUSY_IDS), LocalTexts(GONE_IDS)

local function AnyFound(l, list)
    for _, p in ipairs(list) do
        if l:find(p, 1, true) then return true end
    end
    return false
end

-- "busy" (someone is using the node), "gone" (nothing left to loot) or nil
local function Classify(text, errorType)
    local id
    if type(errorType) == "number" and GetGameMessageInfo then
        local ok, name = pcall(GetGameMessageInfo, errorType)
        if ok then id = name end
    end
    if id then
        if BUSY_IDS[id] then return "busy", id end
        if GONE_IDS[id] then return "gone", id end
    end
    local l = text:lower()
    if AnyFound(l, BUSY_LOCAL) or AnyFound(l, BUSY_TEXT) then return "busy", id end
    if AnyFound(l, GONE_LOCAL) or AnyFound(l, GONE_TEXT) then return "gone", id end
    return nil, id
end

local function NearestSpotAny(maxD)
    local curMap = C_Map.GetBestMapForUnit("player")
    if not curMap then return nil end
    local best, bestKey, bd
    for _, key in ipairs(order) do
        if GT.IsEnabled(key) then
            for _, sp in ipairs(GT.SpawnsOnMap(key, curMap)) do
                local d = GT.GetDistance(sp)
                if d and d <= maxD and (not bd or d < bd) then best, bestKey, bd = sp, key, d end
            end
        end
    end
    return best, bestKey
end

-- text = the message, errorType = the game's error number (UI_ERROR_MESSAGE only, nil for system chat lines)
function GT.OnGameMessage(text, errorType)
    text = type(text) == "string" and text or ""
    local kind, id = Classify(text, errorType)
    if GT.debugLoot or UI.msgDebug then          -- /gt debug
        GT.cprint("game message: " .. text .. (id and (" [" .. id .. "]") or "") .. (kind and (" -> " .. kind) or ""))
    end
    if not GT.cfg().msgDetect then return end
    if not kind then return end
    -- "someone took it" only makes sense after you tried to gather: an empty corpse, a locked door or a
    -- busy object elsewhere must not mark a node
    if not GT.GatherAttemptRecent() then
        if GT.debugLoot or UI.msgDebug then GT.cprint("  ignored: no gather attempt just before") end
        return
    end
    local sp, key = NearestSpotAny(TAKEN_RADIUS_YD)
    if not sp then return end
    local now = GetServerTime()
    if lastMsgAt[sp.sid] and now - lastMsgAt[sp.sid] < 8 then return end
    lastMsgAt[sp.sid] = now
    local node = GT.TimerNodeAt(key, sp)
    if node and (node.time + nodes[key].timer) > now then return end
    if kind == "gone" then
        GT.MarkEmpty(sp, key, true)
    else
        local mark = sp.lootTime
        C_Timer.After(12, function()
            if sp.lootTime == mark then GT.MarkEmpty(sp, key, true) end
        end)
    end
end

local chimed = {}
function GT.CheckProximity()
    local c = GT.cfg()
    if not c.chime then return end
    if UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") then return end
    local curMap = C_Map.GetBestMapForUnit("player")
    local pos = curMap and C_Map.GetPlayerMapPosition(curMap, "player")
    local px, py
    if pos then px, py = pos:GetXY() end
    if not px then return end
    local now = GetServerTime()
    for _, key in ipairs(order) do
        if GT.IsEnabled(key) then
            local def = nodes[key]
            for _, sp in ipairs(GT.SpawnsOnMap(key, curMap)) do
                if math.abs(sp.x - px) < 0.03 and math.abs(sp.y - py) < 0.03
                    and (not chimed[sp.sid] or now - chimed[sp.sid] > 120) then
                    local d = GT.GetDistance(sp)
                    if d and d <= c.chimeRange and d > 6 then
                        local list = GT.GroupEntries(key, sp)
                        local readyEntry
                        for _, n in ipairs(list) do
                            if def.timer - (now - n.time) <= 0 and (not readyEntry or n.time < readyEntry.time) then
                                readyEntry = n
                            end
                        end
                        if readyEntry then
                            local readyAt = readyEntry.time + def.timer
                            local v = visitedSid[sp.sid]
                            if not (v and v > readyAt) then
                                -- one chime per GROUP: every spot of this group counts as "chimed" now,
                                -- otherwise walking through a field chimes once per spot
                                local res = GT.ComputeGroups(key, sp.mapID)
                                local grp = res.of[sp] and res.groups[res.of[sp]]
                                if grp then
                                    for _, s in ipairs(grp) do chimed[s.sid] = now end
                                else
                                    chimed[sp.sid] = now
                                end
                                GT.PlayHerbSound(key, true)
                                if c.screenAlert then
                                    local gi = res.of[sp]
                                    local col = GT.Col(key)
                                    GT.ShowScreenAlert(GT.TRF("%s%s - spot nearby", def.label,
                                        gi and (" G" .. gi) or ""), col[1], col[2], col[3], GT.NodeIcon(key))
                                end
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end
