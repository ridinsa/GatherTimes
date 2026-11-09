-- Groups.lua
local _, GT = ...
local MERGE_DIST = GT.MERGE_DIST
local nodes = GT.nodes
local spawnBySid = GT.spawnBySid

local groupCache = {}          -- groupCache[key][mapID] = result   (no string keys: lookups allocate nothing)
local ckCache = {}             -- ckCache[key][mapID] = "key:mapID", built once
GT.groupRebuild = 0

-- "G1", "G2", ... created once, never again (building them on the fly makes garbage every second)
local LABELS = setmetatable({}, { __index = function(t, i) local s = "G" .. i; t[i] = s; return s end })
GT.GroupLabels = LABELS

local function CK(key, mapID)
    local t = ckCache[key]
    if not t then t = {}; ckCache[key] = t end
    local s = t[mapID]
    if not s then s = key .. ":" .. mapID; t[mapID] = s end
    return s
end

function GT.GroupCentroid(group)
    local cx, cy = 0, 0
    for _, m in ipairs(group) do cx, cy = cx + m.x, cy + m.y end
    return cx / #group, cy / #group
end

local function BuildGroups(pts, size, override)
    local sizes
    if override and override >= 1 and #pts > 0 then
        local n = math.min(override, #pts)
        local base, extra = math.floor(#pts / n), #pts % n
        sizes = {}
        for i = 1, n do sizes[i] = base + (i <= extra and 1 or 0) end
    end
    local groups, left, last = {}, {}, nil
    for i, sp in ipairs(pts) do left[i] = sp end
    while #left > 0 do
        local si = 1
        if last then
            local bd
            for i, sp in ipairs(left) do
                local d = (sp.x - last.x)^2 + (sp.y - last.y)^2
                if not bd or d < bd then si, bd = i, d end
            end
        else
            for i, sp in ipairs(left) do
                if sp.x < left[si].x then si = i end
            end
        end
        local group = { table.remove(left, si) }
        local want = sizes and sizes[#groups + 1] or size
        while #group < want and #left > 0 do
            local cx, cy = GT.GroupCentroid(group)
            local bi, bd
            for i, sp in ipairs(left) do
                local d = (sp.x - cx)^2 + (sp.y - cy)^2
                if not bd or d < bd then bi, bd = i, d end
            end
            group[#group + 1] = table.remove(left, bi)
        end
        groups[#groups + 1] = group
        last = group[#group]
    end
    return groups
end

function GT.ComputeGroups(key, mapID)
    local c = GT.cfg()
    local size = math.max(2, (nodes[key].kind == "ore" and c.groupSizeOre or c.groupSize) or 5)
    local ck = CK(key, mapID)
    local override = c.groupCounts and c.groupCounts[ck]
    -- cache hit = only number comparisons, NO allocation (this runs thousands of times per second)
    local byMap = groupCache[key]
    local cached = byMap and byMap[mapID]
    local nsp, nxt = #GT.spawns[key], GatherTimesDB._spawnNext or 0
    if cached and cached.n == nsp and cached.size == size and cached.override == (override or 0)
        and cached.nxt == nxt and cached.rebuild == GT.groupRebuild then
        return cached
    end
    local pts = {}
    for _, sp in ipairs(GT.spawns[key]) do
        if sp.mapID == mapID then pts[#pts + 1] = sp end
    end
    c.groupStore = c.groupStore or {}
    local ssig = size .. ":" .. (override or 0)
    local st = c.groupStore[ck]
    local byG, fresh = {}, {}
    if not st or st.ssig ~= ssig then
        st = { ssig = ssig, of = {}, n = 0 }
        local built = BuildGroups(pts, size, override)
        for gi, g in ipairs(built) do
            byG[gi] = g
            for _, sp in ipairs(g) do st.of[sp.sid] = gi end
        end
        st.n = #built
        c.groupStore[ck] = st
    else
        for _, sp in ipairs(pts) do
            local gi = st.of[sp.sid]
            if gi then
                byG[gi] = byG[gi] or {}
                byG[gi][#byG[gi] + 1] = sp
            else
                fresh[#fresh + 1] = sp
            end
        end
        for _, sp in ipairs(fresh) do
            local bestG
            if override and st.n < override then
                bestG = nil
            else
                local bd
                for gi = 1, st.n do
                    local m = byG[gi]
                    if m and #m > 0 and (override or #m < size) then
                        local cx, cy = GT.GroupCentroid(m)
                        local d = (sp.x - cx)^2 + (sp.y - cy)^2
                        if not bd or d < bd then bestG, bd = gi, d end
                    end
                end
            end
            if not bestG then
                st.n = st.n + 1
                bestG = st.n
                byG[bestG] = {}
            end
            byG[bestG][#byG[bestG] + 1] = sp
            st.of[sp.sid] = bestG
        end
    end
    local groups, of, gid = {}, {}, {}
    for gi = 1, st.n do
        local g = byG[gi]
        if g and #g > 0 then
            groups[#groups + 1] = g
            gid[#groups] = gi
            for _, sp in ipairs(g) do of[sp] = #groups end
        end
    end
    local res = { n = nsp, size = size, override = override or 0, nxt = nxt, rebuild = GT.groupRebuild,
                  groups = groups, of = of, gid = gid }
    if not byMap then byMap = {}; groupCache[key] = byMap end
    byMap[mapID] = res
    return res
end

function GT.GroupCapacity(key, mapID, idx)
    local c = GT.cfg()
    local res = GT.ComputeGroups(key, mapID)
    local st = c.groupStore and c.groupStore[key .. ":" .. mapID]
    local gid = res.gid[idx]
    local learned = (st and st.cap and gid and st.cap[gid]) or 1
    return math.max((nodes[key].kind == "ore" and c.groupCapOre or c.groupCap) or 1, learned)
end

function GT.RaiseGroupCapacity(key, mapID, idx, n)
    local c = GT.cfg()
    local res = GT.ComputeGroups(key, mapID)
    local st = c.groupStore and c.groupStore[key .. ":" .. mapID]
    local gid = res.gid[idx]
    if not (st and gid) then return end
    st.cap = st.cap or {}
    if (st.cap[gid] or 1) < n then
        st.cap[gid] = n
        GT.cprint(GT.TRF("%s G%d: %d nodes were up at once - this group now tracks %d timers.",
            nodes[key].label, idx, n, n))
    end
end

function GT.RegroupMap(key, mapID)
    local c = GT.cfg()
    if c.groupStore then c.groupStore[key .. ":" .. mapID] = nil end
    GT.groupRebuild = GT.groupRebuild + 1
end

function GT.SpawnOfNode(key, node)
    local sp = node.sid and spawnBySid[node.sid]
    if sp then return sp end
    for _, s2 in ipairs(GT.spawns[key]) do
        if s2.mapID == node.mapID
            and math.sqrt((s2.x - node.x)^2 + (s2.y - node.y)^2) < MERGE_DIST then
            node.sid = s2.sid
            return s2
        end
    end
    return nil
end

function GT.GroupLabelForNode(key, node)
    if not GT.cfg().showGroups then return nil end
    local sp = GT.SpawnOfNode(key, node)
    if not sp then return nil end
    local g = GT.ComputeGroups(key, sp.mapID).of[sp]
    return g and LABELS[g] or nil
end

-- ============================================================
-- LEARNING + TIMING
