-- Learn.lua
local _, GT = ...
local MERGE_DIST = GT.MERGE_DIST
local nodes = GT.nodes
local order = GT.order
local uiRefresh = GT.uiRefresh

GT.RefreshTimingUI = function() end
GT.dwell = nil
-- "Standing at a spot long enough means it is empty" (GT.CheckDwell below).  It used to count anyone who simply
-- stood within 8 yards for 8 seconds: reading chat, waiting for a group or a mount next to a spot marked it
-- empty and started a timer / skewed the route.  Now it only counts when all of this happened:
--   * you walked TOWARD that spot (the distance to it kept shrinking) shortly before   (APPROACH_*)
--   * then you stopped within DWELL_YARDS and stayed put (moving more than STILL_YARDS starts over)
--   * and stood there DWELL_SECONDS, without casting, in combat, AFK, resting or talking to an NPC
-- The time constant is code, not a saved setting, so every user gets the new value with the update.
local DWELL_SECONDS = 12
local DWELL_YARDS = 8
local STILL_YARDS = 3            -- moving further than this from where the wait began starts it again
local APPROACH_YARDS = 40        -- closing in is only watched inside this distance
local APPROACH_BOX = 0.04        -- cheap map-units test before any distance is worked out
local CLOSING_YARDS = 1.5        -- a tick that gets this much closer counts as "walking toward it"
local APPROACH_MEMORY = 20       -- seconds a "walked toward it" stays valid
local TICK_GAP = 3               -- ticks further apart than this (loading screen, lag) are not compared

local SHOW_MIN_SAMPLES  = 3     -- a learned value is shown in the Timing panel from this many samples
local APPLY_MIN_SAMPLES = 5     -- "Apply all faster" and auto-apply need this many (matches the colour legend)
local ZONE_MIN_SAMPLES  = 5      -- a zone needs this many samples before its own value is used

local function Round15(v) return math.floor(v / 15 + 0.5) * 15 end

-- Estimate of one sample list (nil while there are fewer than minN samples).
--   typical = median of the samples, rounded to 15 s: the respawn time Apply / auto-apply use
--   fast    = fastest-quarter value, rounded to 15 s: only the low end of the range that is DISPLAYED
-- Every sample is one real respawn plus the time it took you to come back, so the fastest quarter is a
-- low-biased view; it was used for Apply before and pulled every timer shorter.  The median is not skewed by
-- either end.  Classic respawns vary, so callers that DISPLAY a value should show fast..typical.
-- Returns fast | nil, sample count, typical | nil
local function Estimate(l, minN)
    if not l or #l < minN then return nil, l and #l or 0 end
    local copy = {}
    for i, v in ipairs(l) do copy[i] = v end
    table.sort(copy)
    local n = #copy
    local idx = math.max(1, math.ceil(n * 0.25))
    local mid = (n % 2 == 1) and copy[(n + 1) / 2] or (copy[n / 2] + copy[n / 2 + 1]) / 2
    local fast, typical = Round15(copy[idx]), Round15(mid)
    if typical < fast then typical = fast end
    return fast, n, typical
end

-- Learned respawn time of one item type: the typical (median) value of its samples.
--   Per item mode (default), or no mapID given: the item-wide list.
--   Per zone mode with a mapID: that zone's list once it has ZONE_MIN_SAMPLES samples; otherwise the item-wide
--   value.   Returns seconds | nil, sample count, fromZone (true when the zone's own list was used)
function GT.LearnedSeconds(key, mapID)
    local c = GT.cfg()
    if mapID and c.learnMode == "zone" then
        local zl = c.learnZone[key] and c.learnZone[key][mapID]
        local _, n, typ = Estimate(zl, ZONE_MIN_SAMPLES)
        if typ then return typ, n, true end
    end
    local _, n, typ = Estimate(c.learn[key], SHOW_MIN_SAMPLES)
    return typ, n, false
end

-- Same lookup as LearnedSeconds, but also gives the typical (median) time, for showing a range.
--   Returns fast | nil, sample count, fromZone, typical | nil
function GT.LearnedRange(key, mapID)
    local c = GT.cfg()
    if mapID and c.learnMode == "zone" then
        local zl = c.learnZone[key] and c.learnZone[key][mapID]
        local est, n, typ = Estimate(zl, ZONE_MIN_SAMPLES)
        if est then return est, n, true, typ end
    end
    local est, n, typ = Estimate(c.learn[key], SHOW_MIN_SAMPLES)
    return est, n, false, typ
end

-- allowLonger (auto-apply only): also take a learned value that is clearly LONGER than the current timer
-- (more than 5 % above it), so a timer that is too short is corrected too.  Never more than twice the factory
-- value.  The "Apply all faster" button does not pass it and stays faster-only.
function GT.ApplyLearned(key, force, mapID, allowLonger)
    local est, n = GT.LearnedSeconds(key, mapID)
    if not est or (n or 0) < APPLY_MIN_SAMPLES then return false end        -- at least 5 samples, as the colour legend says
    local def = nodes[key]
    if not force then
        local faster = est < def.timer * 0.95
        local longer = allowLonger and est > def.timer * 1.05 and est <= (def.defaultTimer or def.timer) * 2
        if not (faster or longer) then return false end
    end
    est = GT.ClampTimer(est, def.timer)
    def.timer = est
    GT.cfg().timers[key] = est
    for _, fn in ipairs(uiRefresh) do pcall(fn) end
    return true
end

-- Which earlier loot is a new loot in this group the respawn of?  A group can hold several nodes at once
-- (`cap`), all with the same respawn time, so the node that comes back first is the one looted first: the
-- reference is the cap-th most recent loot of the group's spots.  The LATEST loot of the group is a different
-- node that was taken a few minutes ago; measuring from it gave samples far too short.
-- nil when fewer than `cap` loots are known: this node was never looted before, so there is nothing to measure.
function GT.RespawnReference(group, cap)
    local times = {}
    for _, m in ipairs(group or {}) do
        if m.lootTime then times[#times + 1] = m.lootTime end
    end
    cap = math.max(1, math.floor(tonumber(cap) or 1))
    if #times < cap then return nil end
    table.sort(times, function(a, b) return a > b end)
    return times[cap]
end

function GT.RecordInterval(key, prev, now, mapID)
    if not prev then return end
    local iv = now - prev
    -- Fixed 2-minute floor.  The upper bound comes from the factory timer (or a longer timer you set yourself),
    -- NOT from the current learned timer: that one gets shorter with every learned value, and a bound that
    -- shrinks with it throws away the longer, normal samples and drives the timer ever shorter.
    local ref = math.max(nodes[key].defaultTimer or 0, nodes[key].timer)
    if iv < 120 or iv > ref * 2 then return end
    local l = GT.cfg().learn[key]
    l[#l + 1] = iv
    if #l > 40 then table.remove(l, 1) end
    -- the same sample also goes into the zone's own list (always, so switching modes never loses data)
    if mapID then
        local zones = GT.cfg().learnZone[key]
        local zl = zones[mapID]
        if not zl then zl = {}; zones[mapID] = zl end
        zl[#zl + 1] = iv
        if #zl > 40 then table.remove(zl, 1) end
    end
    if GT.cfg().autoLearn then
        local est, n = GT.LearnedSeconds(key, mapID)
        if n >= APPLY_MIN_SAMPLES and est and GT.ApplyLearned(key, false, mapID, true) then
            GT.cprint(GT.TRF("%s respawn time updated to %.1f min (learned).",
                nodes[key].label, nodes[key].timer / 60))
        end
    end
    GT.RefreshTimingUI()
end

function GT.ContestedPenalty(sp)
    local m = sp.misses or 0
    if m == 0 then return 0 end
    local h = math.max(0, (sp.hits or 1) - (sp.missBase or 0))   -- same baseline as Taken % (reset)
    return m / math.max(1, h + m) * 60
end

-- out (optional): a table to fill instead of creating a new one (for code that runs every second)
function GT.GroupEntries(key, sp, out)
    local res = GT.ComputeGroups(key, sp.mapID)
    local gi = res.of[sp]
    local list = out or {}
    if out then for i = #out, 1, -1 do out[i] = nil end end
    if gi then
        for _, n in ipairs(GatherTimesDB[key]) do
            local s2 = GT.SpawnOfNode(key, n)
            if s2 and s2.mapID == sp.mapID and res.of[s2] == gi then list[#list + 1] = n end
        end
    end
    return list, gi and GT.GroupCapacity(key, sp.mapID, gi) or 1, gi
end

function GT.TimerNodeAt(key, sp)
    if GT.cfg().groupMode then
        local list, _, gi = GT.GroupEntries(key, sp)
        if gi then
            local pick
            for _, n in ipairs(list) do
                if not pick or n.time < pick.time then pick = n end
            end
            return pick
        end
    end
    for _, n in ipairs(GatherTimesDB[key]) do
        if n.mapID == sp.mapID
            and math.sqrt((n.x - sp.x)^2 + (n.y - sp.y)^2) < MERGE_DIST then
            return n
        end
    end
    return nil
end

local visitedSid = {}

local function NewestFirst(a, b) return a.time > b.time end

function GT.NormalizeGroupTimers()
    for _, key in ipairs(order) do
        local list = GatherTimesDB[key]
        if #list > 0 then                     -- most item types have no timer: nothing to do (and no garbage)
        local byGroup = {}
        for _, n in ipairs(list) do
            local sp = GT.SpawnOfNode(key, n)
            local res = sp and GT.ComputeGroups(key, sp.mapID)
            local gi = res and res.of[sp]
            if gi then
                local gk = sp.mapID * 1000 + gi      -- a number: no string is built for every node
                local e = byGroup[gk]
                if not e then
                    e = { nodes = {}, group = res.groups[gi], idx = gi, mapID = sp.mapID }
                    byGroup[gk] = e
                end
                e.nodes[#e.nodes + 1] = n
            end
        end
        local drop = {}
        local now, timer = GetServerTime(), nodes[key].timer
        for _, e in pairs(byGroup) do
            table.sort(e.nodes, NewestFirst)
            local cap = GT.GroupCapacity(key, e.mapID, e.idx)
            -- Timers beyond the group's capacity are only dropped once they have run out: a running timer is real
            -- data (a regroup or switching group mode on must not delete it).  Extras keep their own position and
            -- stay in the list until they expire; the newest `cap` timers are the group's primary ones.
            for i = cap + 1, #e.nodes do
                local x = e.nodes[i]
                x._primary, x._peers = nil, nil
                if x.time + timer <= now then drop[x] = true end
            end
            for i = 1, math.min(cap, #e.nodes) do
                local n = e.nodes[i]
                n._primary, n._peers = nil, nil
                local own = GT.SpawnOfNode(key, n)
                if own and (math.abs(n.x - own.x) > 0.0001 or math.abs(n.y - own.y) > 0.0001) then
                    pcall(GT.RemoveTextTimer, n)
                    n.x, n.y = own.x, own.y
                end
            end
        end
        for i = #list, 1, -1 do
            if drop[list[i]] then
                pcall(GT.RemoveTextTimer, list[i])
                table.remove(list, i)
            end
        end
        end   -- if #list > 0
    end
end

-- ============================================================
-- DETECTION: EMPTY NODES, GAME MESSAGES, PROXIMITY
-- ============================================================
function GT.MarkEmpty(sp, key, justNow)
    local now = GetServerTime()
    local def = nodes[key]
    local node = GT.TimerNodeAt(key, sp)
    if node and (node.time + def.timer) > now then return false end
    sp.misses = (sp.misses or 0) + 1
    if node then
        if justNow then node.time = now
        else node.time = math.floor((node.time + def.timer + now) / 2) end
        node._hasAlerted, node._soundDone = nil, nil
        node._leaveAlerted = nil
        node.est = not justNow
    else
        table.insert(GatherTimesDB[key], {
            mapID = sp.mapID, x = sp.x, y = sp.y, sid = sp.sid, est = not justNow, realm = GT.RealmName(),
            time = justNow and now or (now - math.floor(def.timer / 2)),
        })
    end
    if justNow then
        GT.cprint(GT.TRF("%s: someone else took the node here - timer started.", def.label))
    else
        GT.cprint(GT.TRF("%s spot looks empty - estimated timer started (~).", def.label))
    end
    GT.RefreshTimingUI()
    return true
end

function GT.SpotChecked(sp, key)
    if not GT.cfg().groupMode then GT.MarkEmpty(sp, key); return end
    local res = GT.ComputeGroups(key, sp.mapID)
    local gi = res.of[sp]
    if not gi then GT.MarkEmpty(sp, key); return end
    local group = res.groups[gi]
    local def = nodes[key]
    local now = GetServerTime()
    visitedSid[sp.sid] = now
    local entry = GT.TimerNodeAt(key, sp)
    local readyAt = entry and (entry.time + def.timer) or (now - def.timer)
    local n = 0
    for _, m in ipairs(group) do
        if visitedSid[m.sid] and visitedSid[m.sid] > readyAt then n = n + 1 end
    end
    if n >= #group then
        for _, m in ipairs(group) do visitedSid[m.sid] = nil end
        GT.MarkEmpty(sp, key)
    else
        GT.cprint(GT.TRF("%s G%d: checked %d/%d spots, no node yet.", def.label, gi, n, #group))
    end
end

-- Standing still is not "looking for a node" while you are AFK, resting in a town, or talking to an NPC
-- (vendor, quest giver, trainer, mail, bank, auction house, trade, flight master).
local INTERACTION_FRAMES = { "GossipFrame", "QuestFrame", "MerchantFrame", "TradeFrame", "BankFrame", "MailFrame",
    "InboxFrame", "AuctionFrame", "AuctionHouseFrame", "ClassTrainerFrame", "TrainerFrame", "TaxiFrame", "PetStableFrame",
    "BarberShopFrame" }
local function Interacting()
    for _, name in ipairs(INTERACTION_FRAMES) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() then return true end
    end
    return false
end

-- Where the player was last tick, per spot (sid -> yards), and when each spot was last walked toward.
local prevD, prevT = {}, 0
local approachAt = {}
local function ForgetApproach()
    GT.dwell = nil
    if next(prevD) then prevD = {} end
    if next(approachAt) then approachAt = {} end
end
GT.ForgetApproach = ForgetApproach

function GT.CheckDwell()
    local c = GT.cfg()
    if not c.detectEmpty or UnitAffectingCombat("player") or UnitIsDeadOrGhost("player")
        or (UnitIsAFK and UnitIsAFK("player")) or (IsResting and IsResting()) or Interacting() then
        ForgetApproach(); return
    end
    local curMap = C_Map.GetBestMapForUnit("player")
    local pos = curMap and C_Map.GetPlayerMapPosition(curMap, "player")
    local px, py
    if pos then px, py = pos:GetXY() end
    if not px then ForgetApproach(); return end
    local now = GetTime()
    local compare = (now - prevT) <= TICK_GAP
    local seen = {}
    local best, bestKey, bestD
    for _, key in ipairs(order) do
        if GT.IsEnabled(key) then
            for _, sp in ipairs(GT.SpawnsOnMap(key, curMap)) do
                if math.abs(sp.x - px) < APPROACH_BOX and math.abs(sp.y - py) < APPROACH_BOX then
                    local d = GT.GetDistance(sp)
                    if d and d <= APPROACH_YARDS then
                        seen[sp.sid] = d
                        local before = compare and prevD[sp.sid]
                        if before and d < before - CLOSING_YARDS then approachAt[sp.sid] = now end
                        if d <= DWELL_YARDS and (not bestD or d < bestD) then
                            best, bestKey, bestD = sp, key, d
                        end
                    end
                end
            end
        end
    end
    prevD, prevT = seen, now
    for sid, t in pairs(approachAt) do
        if now - t > APPROACH_MEMORY then approachAt[sid] = nil end
    end
    if not best then GT.dwell = nil; return end
    local node = GT.TimerNodeAt(bestKey, best)
    if node and (node._left or 1) > 0 then GT.dwell = nil; return end

    local dw = GT.dwell
    if dw and dw.sp ~= best then GT.dwell, dw = nil, nil end          -- another spot is the nearest now
    if dw then
        -- moved away from where the wait began: it does not count as standing still
        local moved = dw.map == curMap and GT.GetDistanceXY(curMap, dw.x, dw.y)
        if not moved or moved > STILL_YARDS then GT.dwell, dw = nil, nil end
    end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then
        -- gathering (or any cast) restarts the wait; a cast alone never starts one
        if dw then dw.since = now end
        return
    end
    if dw then
        if not dw.done and (now - dw.since) >= DWELL_SECONDS then
            dw.done = true
            GT.SpotChecked(best, bestKey)
        end
        return
    end
    local at = approachAt[best.sid]
    if at and (now - at) <= APPROACH_MEMORY then
        GT.dwell = { sp = best, since = now, map = curMap, x = px, y = py }
    end
end

-- exports
GT.visitedSid = visitedSid
