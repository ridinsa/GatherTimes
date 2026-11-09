-- Import.lua
local _, GT = ...
local SNAP_DIST = GT.SNAP_DIST
local nodes = GT.nodes
local order = GT.order
local spawnBySid = GT.spawnBySid

do
    local IMPORT_MATCH = {}
    for key, def in pairs(nodes) do IMPORT_MATCH[key] = def.gm end

    local function FirstTable(...)
        for i = 1, select("#", ...) do
            local t = _G[select(i, ...)]
            if type(t) == "table" and next(t) then return t end
        end
        return nil
    end

    -- The import runs as a coroutine that gives the game back after a few milliseconds, so a big GatherMate2
    -- database (thousands of points, each compared with every known spot) no longer freezes the screen.
    local SLICE_MS = 6
    local clock = debugprofilestop or function() return GetTime() * 1000 end
    local sliceStart = 0
    local running = false
    local function MaybeYield()
        if clock() - sliceStart > SLICE_MS then coroutine.yield() end
    end

    local function Drive(co)
        local driver = CreateFrame("Frame")
        driver:SetScript("OnUpdate", function(self)
            sliceStart = clock()
            local ok, err = coroutine.resume(co)
            if not ok then
                self:SetScript("OnUpdate", nil)
                running = false
                GT.ReportError("GatherMate2 import", err)
            elseif coroutine.status(co) == "dead" then
                self:SetScript("OnUpdate", nil)
                running = false
            end
        end)
    end

    GT.ImportGatherMate2 = function(arg)
        if running then GT.cprint(GT.TR("Import is already running.")); return end
        local all = (arg or ""):lower():find("all", 1, true) ~= nil
        local curMap = C_Map.GetBestMapForUnit("player")
        if not all and not curMap then GT.cprint(GT.TR("no map here")); return end
        local ace = LibStub and LibStub("AceAddon-3.0", true)
        local GM = ace and ace:GetAddon("GatherMate2", true)
        if not GM then
            GT.cprint(GT.TR("GatherMate2 is not loaded. Install and enable GatherMate2 (Classic) and GatherMate2_Data first."))
            return
        end
        pcall(function()
            if C_AddOns and C_AddOns.LoadAddOn then
                C_AddOns.LoadAddOn("GatherMate2_Data")
            elseif LoadAddOn then
                LoadAddOn("GatherMate2_Data")
            end
        end)
        local reverse = {}
        local function NameOf(nodeType, id)
            local ok, name = pcall(function() return GM:GetNameForNode(nodeType, id) end)
            if ok and name then return name end
            if not reverse[nodeType] then
                reverse[nodeType] = {}
                local t = GM.nodeIDs and GM.nodeIDs[nodeType]
                if type(t) == "table" then
                    for n, i in pairs(t) do reverse[nodeType][i] = n end
                end
            end
            return reverse[nodeType][id]
        end
        local sources = {
            { type = "Herb Gathering", db = FirstTable("GatherMate2HerbDB", "GatherMateData2HerbDB") },
            { type = "Mining",         db = FirstTable("GatherMate2MineDB", "GatherMateData2MineDB") },
        }
        running = true
        local co = coroutine.create(function()
            local found, added, skipped, touched = false, {}, {}, {}
            local made = {}                           -- every spot made here: counted at the end only if it is still there
            local evicted0 = GT.spawnEvictions or 0
            local n = 0
            for _, src in ipairs(sources) do
                if src.db then
                    found = true
                    for zoneID, zoneNodes in pairs(src.db) do
                        if type(zoneID) == "number" and type(zoneNodes) == "table" and (all or zoneID == curMap) then
                            for coord, nodeID in pairs(zoneNodes) do
                                n = n + 1
                                if n % 20 == 0 then MaybeYield() end
                                -- GatherMate2 stores a numeric node id per spot: match on that (works in every client
                                -- language).  Only an id we do not know falls back to the English node name.
                                local mkey = GT.GM_NODE_KEY[nodeID]
                                if not mkey then
                                    local name = NameOf(src.type, nodeID)
                                    local lname = type(name) == "string" and name:lower()
                                    if lname then
                                        local mlen = 0
                                        for key, pat in pairs(IMPORT_MATCH) do
                                            if #pat > mlen and lname:find(pat, 1, true) then mkey, mlen = key, #pat end
                                        end
                                    end
                                end
                                if mkey then
                                    local x = math.floor(coord / 1000000) / 10000
                                    local y = (math.floor(coord / 100) % 10000) / 10000
                                    if GT.FindSpawn(mkey, zoneID, x, y) then
                                        skipped[mkey] = (skipped[mkey] or 0) + 1
                                    else
                                        local sp = GT.MergeSpawn(mkey, zoneID, x, y)
                                        sp.hits = 0
                                        sp.imported = true
                                        made[#made + 1] = { mkey, sp }
                                        touched[mkey .. ":" .. zoneID] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not found then
                GT.cprint(GT.TR("No GatherMate2 data found. Install GatherMate2_Data, then open /gathermate, go to Import and import the herb and mining data."))
                return
            end
            -- Merge your own earlier spots into the exact imported positions.  The spots to look at are collected
            -- first and re-checked one by one, because you may gather (and add spots) while the import is paused.
            local merged = 0
            local cands = {}
            for _, key in ipairs(order) do
                for _, sp in ipairs(GT.spawns[key]) do
                    if not sp.imported and (all or sp.mapID == curMap) then cands[#cands + 1] = { key = key, sp = sp } end
                end
            end
            for _, c in ipairs(cands) do
                MaybeYield()
                local key, sp = c.key, c.sp
                local list = GT.spawns[key]
                if spawnBySid[sp.sid] == sp and not sp.imported then
                    local imp, bd
                    for _, o in ipairs(list) do
                        if o.imported and o.mapID == sp.mapID then
                            local d = math.sqrt((o.x - sp.x)^2 + (o.y - sp.y)^2)
                            if d < SNAP_DIST and (not bd or d < bd) then imp, bd = o, d end
                        end
                    end
                    if imp then
                        imp.hits = (imp.hits or 0) + (sp.hits or 0)
                        imp.misses = (imp.misses or 0) + (sp.misses or 0)
                        if sp.lootTime and (not imp.lootTime or sp.lootTime > imp.lootTime) then
                            imp.lootTime = sp.lootTime
                        end
                        for _, nd in ipairs(GatherTimesDB[key]) do
                            if nd.sid == sp.sid then nd.sid = imp.sid end
                        end
                        spawnBySid[sp.sid] = nil
                        for i = #list, 1, -1 do
                            if list[i] == sp then table.remove(list, i); break end
                        end
                        merged = merged + 1
                    end
                end
            end
            for ck in pairs(touched) do GT.cfg().groupStore[ck] = nil end
            GT.groupRebuild = GT.groupRebuild + 1
            -- a spot pushed out again by a later one (list full) is not "added"
            for _, m in ipairs(made) do
                if spawnBySid[m[2].sid] == m[2] then added[m[1]] = (added[m[1]] or 0) + 1 end
            end
            local dropped = (GT.spawnEvictions or 0) - evicted0
            local total = 0
            for _, key in ipairs(order) do
                local a, k = added[key] or 0, skipped[key] or 0
                if a + k > 0 then
                    total = total + a
                    GT.cprint(GT.TRF("%s: %d added, %d already known", nodes[key].label, a, k))
                end
            end
            if total == 0 and next(skipped) == nil then
                GT.cprint(GT.TR(all and "No matching nodes found. Make sure the data is imported in /gathermate."
                    or "No matching nodes found for this zone. Make sure the data is imported in /gathermate."))
            else
                GT.cprint(GT.TRF("Import done: %d new spawn points, %d of your old spots merged into exact positions.", total, merged))
                if dropped > 0 then
                    GT.cprint(GT.TRF("The spot limit (%d) was reached: %d older imported spots you never visited were dropped.",
                        GT.MAX_SPAWNS, dropped))
                end
                pcall(GT.SyncSpawnPins)
            end
        end)
        GT.cprint(GT.TR("Import started... (this runs in the background, the game stays usable)"))
        Drive(co)
    end
end
