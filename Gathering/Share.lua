-- Share.lua : export and import of your own spots, so friends can swap what they have learned.
-- (The GatherMate2 import is in Import.lua; this one reads text that GatherTimes wrote itself.)
--
-- The text is one line of plain ASCII that survives copy / paste, chat clients and line wrapping:
--     GTSPOTS1;<spots>;<check>;<group>;<group>;...
--     <group> = <item key>:<mapID>:<x>,<y>,<x>,<y>,...      x and y are whole numbers 0..10000 (map position * 10000)
--     <check> = 8 hex digits over everything after the third ";", so a cut-off or edited paste is refused
--
-- Exported: the spots you learned yourself, plus imported spots you have gathered at since.  Imported spots
-- nobody has visited stay home (they come from GatherMate2 or from a friend already).  No hit counts, times
-- or timers travel: only item, zone and position.
--
-- Imported: every spot becomes an "imported" spot with no hits, exactly like the GatherMate2 import, so it never
-- pushes out a spot you learned yourself, and the first loot next to it snaps onto it (GT.FindNearestImported).
-- A spot within MERGE_DIST of one you already have counts as known and is left alone.
local addonName, GT = ...
local nodes = GT.nodes
local order = GT.order

local HEADER = "GTSPOTS1"
local MAX_SPOTS = 3000                  -- more than this in one text is refused (GT.MAX_SPAWNS is 3000)
local SCALE = 10000
local MOD = 65521

-- Fletcher-style check over a string: 8 hex digits.  Plain arithmetic, no bit library (the game runs Lua 5.1).
local function Check(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % MOD
        b = (b + a) % MOD
    end
    return string.format("%04x%04x", b, a)
end
GT.SpotTextCheck = Check

-- One of your own spots?  Imported spots count once you have gathered at them.
local function IsOwn(sp)
    return not sp.imported or (sp.hits or 0) > 0 or sp.lootTime ~= nil
end

-- A map the client knows.  When the map API is not there at all the answer is "yes", the text was checked already.
local function MapKnown(mapID)
    if type(C_Map) ~= "table" or type(C_Map.GetMapInfo) ~= "function" then return true end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    return ok and info ~= nil and info ~= false
end

local function ToInt(s)
    if type(s) ~= "string" or not s:match("^%d+$") or #s > 9 then return nil end
    return tonumber(s)
end

-- ============================================================
-- EXPORT
-- ============================================================

-- Returns the text and the number of spots in it (the text is "" when you have none).
function GT.ExportSpots()
    local groups, total = {}, 0
    for _, key in ipairs(order) do
        local byMap, maps = {}, {}
        for _, sp in ipairs(GT.spawns[key] or {}) do
            if IsOwn(sp) and type(sp.mapID) == "number" and sp.x >= 0 and sp.x <= 1 and sp.y >= 0 and sp.y <= 1 then
                local list = byMap[sp.mapID]
                if not list then list = {}; byMap[sp.mapID] = list; maps[#maps + 1] = sp.mapID end
                list[#list + 1] = string.format("%d,%d", math.floor(sp.x * SCALE + 0.5), math.floor(sp.y * SCALE + 0.5))
                total = total + 1
            end
        end
        table.sort(maps)                                      -- same spots, same text
        for _, mapID in ipairs(maps) do
            groups[#groups + 1] = string.format("%s:%d:%s", key, mapID, table.concat(byMap[mapID], ","))
        end
    end
    if total == 0 then return "", 0 end
    local body = table.concat(groups, ";")
    return string.format("%s;%d;%s;%s", HEADER, total, Check(body), body), total
end

-- ============================================================
-- IMPORT
-- ============================================================

-- Reads the text.  Returns list, nil   (list = { { key, mapID, x, y }, ... }, x / y 0..1, plus list.unknown / list.invalid)
-- or nil, "reason".  Nothing is changed in the saved data here.
function GT.ParseSpotText(text)
    if type(text) ~= "string" then return nil, "empty" end
    text = text:gsub("%s+", "")                               -- a paste that was wrapped into several lines still works
    if text == "" then return nil, "empty" end
    local head, count, check, body = text:match("^([^;]*);(%d+);(%x+);(.*)$")
    if head ~= HEADER then return nil, "format" end
    count = tonumber(count)
    if #check ~= 8 or body == "" then return nil, "damaged" end
    if count > MAX_SPOTS then return nil, "toomany", count end
    if Check(body) ~= check:lower() then return nil, "damaged" end

    local list = { unknown = 0, invalid = 0 }
    local seen = 0
    for group in body:gmatch("[^;]+") do
        local key, map, coords = group:match("^([%w_]+):(%d+):([%d,]+)$")
        local mapID = ToInt(map)
        if not (key and mapID and coords) then return nil, "damaged" end
        local nums = {}
        for n in coords:gmatch("[^,]+") do nums[#nums + 1] = ToInt(n) or -1 end
        if #nums % 2 ~= 0 then return nil, "damaged" end
        local known = nodes[key] ~= nil
        local mapOK = known and MapKnown(mapID)
        for i = 1, #nums, 2 do
            seen = seen + 1
            local x, y = nums[i], nums[i + 1]
            if not known then
                list.unknown = list.unknown + 1
            elseif not mapOK or x < 0 or y < 0 or x > SCALE or y > SCALE then
                list.invalid = list.invalid + 1
            else
                list[#list + 1] = { key = key, mapID = mapID, x = x / SCALE, y = y / SCALE }
            end
        end
    end
    if seen ~= count then return nil, "damaged" end           -- the declared number must match what the text holds
    return list
end

-- Adds the spots.  Returns a result table { added, known, unknown, invalid, dropped } or nil, "reason".
-- pause (optional) is called after every few spots: GT.ImportSpotsReport passes a function that gives the game
-- back after a few milliseconds when it runs inside a coroutine, so a big list does not freeze the screen.
-- dropped = spots that did not fit under GT.MAX_SPAWNS and pushed out older unvisited imported ones.
function GT.ImportSpots(text, pause)
    local list, why, n = GT.ParseSpotText(text)
    if not list then return nil, why, n end
    local made, known, touched = {}, 0, {}
    local evicted0 = GT.spawnEvictions or 0
    for i, s in ipairs(list) do
        if pause and i % 25 == 0 then pause() end
        if GT.FindSpawn(s.key, s.mapID, s.x, s.y) then
            known = known + 1
        else
            local sp = GT.MergeSpawn(s.key, s.mapID, s.x, s.y)
            sp.hits = 0
            sp.imported = true
            made[#made + 1] = sp
            touched[s.key .. ":" .. s.mapID] = true
        end
    end
    -- MergeSpawn makes room by dropping old unvisited imported spots once the list is full; a spot of this very
    -- text can be one of them, so count only the ones that are still there
    local added = 0
    for _, sp in ipairs(made) do
        if GT.spawnBySid[sp.sid] == sp then added = added + 1 end
    end
    local store = GT.cfg().groupStore
    for ck in pairs(touched) do store[ck] = nil end            -- the groups of those maps are worked out again
    GT.groupRebuild = GT.groupRebuild + 1
    pcall(GT.SyncSpawnPins)
    return { added = added, known = known, unknown = list.unknown, invalid = list.invalid,
             dropped = (GT.spawnEvictions or 0) - evicted0 }
end

-- A list longer than this is imported a few milliseconds per frame instead of all at once.
local SLICE_AT = 300
local SLICE_MS = 6
local importRunning = false

-- Chat feedback for the dialog and the slash command.
local REASON = {
    empty   = "Nothing to import: paste the text from /gt export first.",
    format  = "That is not a GatherTimes spot list (it should start with GTSPOTS1).",
    damaged = "The spot list is damaged or incomplete (copied only in part?). Nothing was imported.",
}
local function PrintResult(res)
    GT.cprint(GT.TRF("Spots imported: %d new, %d already known.", res.added, res.known))
    if res.unknown + res.invalid > 0 then
        GT.cprint(GT.TRF("%d spots skipped (item or zone this version does not know).", res.unknown + res.invalid))
    end
    if (res.dropped or 0) > 0 then
        GT.cprint(GT.TRF("The spot limit (%d) was reached: %d older imported spots you never visited were dropped.",
            GT.MAX_SPAWNS, res.dropped))
    end
end

function GT.ImportSpotsReport(text)
    local list, why, n = GT.ParseSpotText(text)
    if not list then
        if why == "toomany" then
            GT.cprint(GT.TRF("That spot list has %d spots, more than the limit of %d. Nothing was imported.", n, MAX_SPOTS))
        else
            GT.cprint(GT.TR(REASON[why] or REASON.damaged))
        end
        return false
    end
    if #list <= SLICE_AT or not (coroutine and coroutine.create and CreateFrame) then
        local res = GT.ImportSpots(text)
        if not res then GT.cprint(GT.TR(REASON.damaged)); return false end
        PrintResult(res)
        return true, res
    end
    -- long list: run it as a coroutine that gives the game back every few milliseconds
    if importRunning then GT.cprint(GT.TR("Import is already running.")); return false end
    importRunning = true
    local clock = debugprofilestop or function() return GetTime() * 1000 end
    local sliceStart = clock()
    local co = coroutine.create(function()
        return GT.ImportSpots(text, function()
            if clock() - sliceStart > SLICE_MS then coroutine.yield() end
        end)
    end)
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(self)
        sliceStart = clock()
        local ok, res = coroutine.resume(co)
        if not ok then
            self:SetScript("OnUpdate", nil); importRunning = false
            GT.ReportError("spot import", res)
        elseif coroutine.status(co) == "dead" then
            self:SetScript("OnUpdate", nil); importRunning = false
            if res then PrintResult(res) else GT.cprint(GT.TR(REASON.damaged)) end
        end
    end)
    GT.cprint(GT.TR("Import started... (this runs in the background, the game stays usable)"))
    return true
end
GT.MAX_SHARE_SPOTS = MAX_SPOTS

-- ============================================================
-- DIALOG: one small window for both directions
-- ============================================================
local dialog

local function BuildDialog()
    local f = GT:CreateFlatFrame("GatherTimesShare", UIParent, 330, 128)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.header = GT:CreateHeader(f, "", function() f:Hide() end)

    f.hint = GT.Font(f, nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", 10, -30)
    f.hint:SetWidth(310)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetJustifyV("TOP")

    f.edit = GT:CreateEditBox(f, 310, 22)
    f.edit:SetPoint("TOPLEFT", 10, -62)
    f.edit:SetJustifyH("LEFT")
    f.edit:SetMaxLetters(0)                                  -- the text can be long
    f.edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if f.mode == "import" then f.go:Click() end
    end)

    f.go = GT:CreateFlatButton(f, "Import", 100, 20)
    f.go:SetPoint("BOTTOMLEFT", 10, 10)
    f.go:SetScript("OnClick", function()
        if f.mode ~= "import" then return end
        if GT.ImportSpotsReport(f.edit:GetText()) then f:Hide() end
    end)

    f.close = GT:CreateFlatButton(f, "Close", 100, 20)
    f.close:SetPoint("BOTTOMRIGHT", -10, 10)
    f.close:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    tinsert(UISpecialFrames, "GatherTimesShare")             -- ESC closes it
    return f
end

local function Show(mode)
    if not dialog then dialog = BuildDialog() end
    local f = dialog
    f.mode = mode
    if mode == "export" then
        local text, n = GT.ExportSpots()
        f.header.title:SetText(GT.TR("Export spots"))
        f.go:Hide()
        if n == 0 then
            f.hint:SetText(GT.TR("You have no spots of your own to share yet. Gather some herbs or ore first."))
            f.edit:SetText("")
        else
            f.hint:SetText(GT.TRF("%d spots. Click the box, press Ctrl+C and send the text to your friend.", n))
            f.edit:SetText(text)
        end
        f:Show()
        f.edit:SetFocus()
        f.edit:HighlightText()
    else
        f.header.title:SetText(GT.TR("Import spots"))
        f.hint:SetText(GT.TR("Paste the text your friend sent (Ctrl+V), then click Import."))
        f.go:Show()
        f.edit:SetText("")
        f:Show()
        f.edit:SetFocus()
    end
end

function GT.ShowExportSpots() Show("export") end
function GT.ShowImportSpots() Show("import") end
