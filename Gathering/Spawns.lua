-- Spawns.lua
local _, GT = ...
local MAX_SPAWNS = GT.MAX_SPAWNS
local MERGE_DIST = GT.MERGE_DIST
local nodes = GT.nodes
local spawnBySid = GT.spawnBySid

GT.routeTick = 0
local routeState = { lastSid = nil, lastTime = 0 }
GT.routeTarget = nil

-- Index of the spawns by [key][mapID], so the 1 Hz checks only walk the spots of the map you are on instead of every
-- spot of every node.  Rebuilt when the list changes (its length or the spawn counter changes); callers must not
-- modify the returned table.
local EMPTY = {}
local spawnIndex = {}
GT.spawnIndexRebuilds = 0      -- how often an index was built from scratch (Tests\run.lua checks that adding a spot does not)
GT.spawnEvictions = 0          -- spots dropped to make room (imports report it)
function GT.SpawnsOnMap(key, mapID)
    local list = GT.spawns[key]
    local idx = spawnIndex[key]
    local nxt = GatherTimesDB._spawnNext or 0
    if not idx or idx.n ~= #list or idx.nxt ~= nxt or idx.list ~= list then
        GT.spawnIndexRebuilds = GT.spawnIndexRebuilds + 1
        idx = { n = #list, nxt = nxt, list = list, maps = {} }
        for _, sp in ipairs(list) do
            local m = idx.maps[sp.mapID]
            if not m then m = {}; idx.maps[sp.mapID] = m end
            m[#m + 1] = sp
        end
        spawnIndex[key] = idx
    end
    return idx.maps[mapID] or EMPTY
end

function GT.FindSpawn(key, mapID, x, y)
    local best, bd
    for _, sp in ipairs(GT.SpawnsOnMap(key, mapID)) do
        local dx, dy = sp.x - x, sp.y - y
        if dx < MERGE_DIST and dx > -MERGE_DIST and dy < MERGE_DIST and dy > -MERGE_DIST then   -- cheap box test first
            local d = math.sqrt(dx * dx + dy * dy)
            if d < MERGE_DIST and (not bd or d < bd) then best, bd = sp, d end
        end
    end
    return best
end

-- A loot spot snaps to an imported spot this close (map units, 0-1).  It was 0.05 (about 8 times the merge
-- radius), which let neighbouring nodes collapse into one; 0.015 is roughly 15-20 yards in a normal zone.
local SNAP_DIST = 0.015
function GT.FindNearestImported(key, mapID, x, y, maxD)
    local best, bd
    for _, sp in ipairs(GT.SpawnsOnMap(key, mapID)) do
        if sp.imported then
            local d = math.sqrt((sp.x - x)^2 + (sp.y - y)^2)
            if d < maxD and (not bd or d < bd) then best, bd = sp, d end
        end
    end
    return best
end

function GT.MergeSpawn(key, mapID, x, y)
    local list = GT.spawns[key]
    local best, bd
    for _, sp in ipairs(GT.SpawnsOnMap(key, mapID)) do
        local dx, dy = sp.x - x, sp.y - y
        if dx < MERGE_DIST and dx > -MERGE_DIST and dy < MERGE_DIST and dy > -MERGE_DIST then
            local d = math.sqrt(dx * dx + dy * dy)
            if d < MERGE_DIST and (not bd or d < bd) then best, bd = sp, d end
        end
    end
    local now = GetServerTime()
    if best then
        best.hits = (best.hits or 1) + 1
        best.last = now
        return best
    end
    local id = GatherTimesDB._spawnNext or 1
    -- Is the index of this item up to date right now?  Then the new spot is added to it below instead of
    -- throwing the index away: a big import used to rebuild it for every single spot (quadratic).
    local idx0 = spawnIndex[key]
    local live = idx0 and idx0.list == list and idx0.n == #list and idx0.nxt == (GatherTimesDB._spawnNext or 0)
    GatherTimesDB._spawnNext = id + 1
    local sp = { sid = id, mapID = mapID, x = x, y = y, hits = 1, last = now }     -- sp.nexts is created by RegisterLoot when it is first needed
    list[#list + 1] = sp
    spawnBySid[id] = sp
    if live then
        local m = idx0.maps[mapID]
        if not m then m = {}; idx0.maps[mapID] = m end
        m[#m + 1] = sp
        idx0.n, idx0.nxt = #list, id + 1
    end
    if #list > MAX_SPAWNS then
        -- Over the limit: only imported spots nobody has looted at yet may go (oldest first).  A spot you
        -- learned, or an imported one you gathered at, is never evicted; if nothing can go, the list just grows.
        local oi, ot
        for i = 1, #list do
            local c = list[i]
            if c ~= sp and c.imported and (c.hits or 0) == 0 and not c.lootTime and (not ot or (c.last or 0) < ot) then
                oi, ot = i, (c.last or 0)
            end
        end
        if oi then
            local old = table.remove(list, oi)
            spawnBySid[old.sid] = nil
            GT.spawnEvictions = GT.spawnEvictions + 1
            if live then
                local m = idx0.maps[old.mapID]
                if m then
                    for i = 1, #m do
                        if m[i] == old then table.remove(m, i); break end
                    end
                end
                idx0.n = #list
            end
            local gs = GT.cfg().groupStore
            local st = gs and gs[key .. ":" .. old.mapID]
            if st and st.of then st.of[old.sid] = nil end
        end
    end
    return sp
end

function GT.RegisterLoot(sp)
    local now = GetServerTime()
    local last = routeState.lastSid and spawnBySid[routeState.lastSid]
    if last and last ~= sp and (now - routeState.lastTime) < 900 then
        last.nexts = last.nexts or {}
        last.nexts[sp.sid] = (last.nexts[sp.sid] or 0) + 1
        GT.TrimNexts(last.nexts, sp.sid)                  -- at most GT.NEXTS_MAX followers per spot
    end
    routeState.lastSid, routeState.lastTime = sp.sid, now
end

-- A running timer within MERGE_DIST of a spot (same map).  Called for every spot, so callers that ask about many
-- spots in one go (the map pins, every 3 s) build a one-off index first and pass it in:
--   local idx = GT.BuildTimerIndex(key)               -- nil when the item has no timer at all
--   GT.HasActiveTimerAt(key, sp, idx or false)         -- false = "no timers": answers without a scan
-- The index is a grid of MERGE_DIST-sized cells, so a spot only looks at the 9 cells around it instead of every
-- timer.  It is a snapshot: build it, use it, drop it (never keep it across ticks).  Without the third
-- argument the function scans the list as before.
local function Cell(mapID, x, y)
    return (mapID * 512 + math.floor(x / MERGE_DIST)) * 512 + math.floor(y / MERGE_DIST)
end
function GT.BuildTimerIndex(key)
    local list = GatherTimesDB[key]
    if not list or #list == 0 then return nil end
    local first, more = {}, {}                    -- first timer of a cell; a table only when a cell holds more
    for _, n in ipairs(list) do
        local k = Cell(n.mapID, n.x, n.y)
        local f = first[k]
        if f == nil then first[k] = n
        else
            local m = more[k]
            if not m then m = {}; more[k] = m end
            m[#m + 1] = n
        end
    end
    return { first = first, more = more }
end

local function Near(n, sp)
    return n.mapID == sp.mapID and math.sqrt((n.x - sp.x)^2 + (n.y - sp.y)^2) < MERGE_DIST
end

function GT.HasActiveTimerAt(key, sp, idx)
    if idx == false then return false end
    if idx then
        local base = sp.mapID * 512
        local cx, cy = math.floor(sp.x / MERGE_DIST), math.floor(sp.y / MERGE_DIST)
        local first, more = idx.first, idx.more
        for dx = -1, 1 do
            for dy = -1, 1 do
                local k = (base + cx + dx) * 512 + cy + dy
                local f = first[k]
                if f then
                    if Near(f, sp) then return true end
                    local m = more[k]
                    if m then
                        for i = 1, #m do if Near(m[i], sp) then return true end end
                    end
                end
            end
        end
        return false
    end
    for _, n in ipairs(GatherTimesDB[key]) do
        if n.mapID == sp.mapID
            and math.sqrt((n.x - sp.x)^2 + (n.y - sp.y)^2) < MERGE_DIST then
            return true
        end
    end
    return false
end

function GT.TransitionBonus(sid)
    if not (sid and routeState.lastSid) then return 0 end
    if (GetServerTime() - routeState.lastTime) > 900 then return 0 end
    local last = spawnBySid[routeState.lastSid]
    local n = last and last.nexts and last.nexts[sid]
    return n and math.min(n * 5, 30) or 0
end

function GT.TargetStatus(t)
    if t.kind == "spawn" then return GT.TR("unchecked") end
    local left = nodes[t.key].timer - (GetServerTime() - t.ref.time)
    if left <= 0 then return "|cff00ff00" .. GT.TR("READY") .. "|r" end
    local text = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
    -- the timer runs out before you get there: it is the better pick than a spot that is ready but further away
    if t.eta and left <= t.eta then text = text .. " |cff00ff00" .. GT.TR("ready on arrival") .. "|r" end
    return text
end

-- ============================================================
-- GROUP SYSTEM

-- exports
GT.SNAP_DIST = SNAP_DIST
GT.routeState = routeState
