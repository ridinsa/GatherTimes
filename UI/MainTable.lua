-- MainTable.lua : the Excel-style grid in the main window
-- Columns: Group | Status | Timer.  Rows are groups in the CURRENT zone:
--   * one item picked in the main dropdown -> ALL its groups, G1 .. Gn (no item name), timer or not
--   * "All checked"                        -> ALL groups of ALL checked items with spots here, with the item name
-- The table grows and shrinks with the number of rows up to 9; more than 9 scroll (mouse wheel + thin bar).
local ADDON, GT = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"
local ROW_H, VISIBLE = 20, 9
local COLS = {                       -- title, width, text alignment   (widths add up to 278 = 286 - 8 for the scroll bar)
    { "Group",    104, "LEFT"   },
    { "Status",    88, "CENTER" },
    { "Timer",     86, "CENTER" },
}
local function Mmss(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local rowBackgrounds = {}

-- One header or data row, with color providing separation instead of grid lines.
local function CreateGridRow(parent, isHeader, rowIndex)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(278, ROW_H)

    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(FLAT)
    bg.gtTableHeader = isHeader
    bg.gtTableAlternate = not isHeader and rowIndex and rowIndex % 2 == 0
    rowBackgrounds[#rowBackgrounds + 1] = bg
    bg:SetVertexColor(unpack(isHeader and GT.colors.head or GT.colors.row))

    local x = 0
    r.cells = {}
    for i, col in ipairs(COLS) do
        local fs = GT.Font(r, nil, "OVERLAY", isHeader and "GameFontNormalSmall" or "GameFontHighlightSmall")
        fs:SetPoint("LEFT", r, "LEFT", x + 5, 0)
        fs:SetWidth(col[2] - 10)
        fs:SetJustifyH(col[3])
        fs:SetWordWrap(false)
        r.cells[i] = fs
        x = x + col[2]
    end
    return r
end

local function ApplyRowColors()
    for _, bg in ipairs(rowBackgrounds) do
        local c = bg.gtTableHeader and GT.colors.head or GT.colors.row
        if bg.gtTableAlternate then
            bg:SetVertexColor(math.min(1, c[1] + 0.035), math.min(1, c[2] + 0.035),
                math.min(1, c[3] + 0.035), c[4])
        else
            bg:SetVertexColor(unpack(c))
        end
    end
end

-- Item tables are reused every second (new tables per group per second = garbage).
local pool, poolN, itemsOut = {}, 0, {}
local function NewItem(key, text, glabel)
    poolN = poolN + 1
    local it = pool[poolN]
    if not it then it = {}; pool[poolN] = it end
    it.key, it.text, it.ready, it.waiting, it.minLeft = key, text, 0, 0, nil
    it.glabel = glabel or text         -- short label ("G2") for the compact minimized bar
    return it
end
local function Finish(n) for i = n + 1, #itemsOut do itemsOut[i] = nil end end

-- ONE item picked in the dropdown: every group the zone has for it (G1 .. Gn), whether or not a
-- timer is running.  The number of groups follows "Nodes per group" in the Nodes panel.
local function BuildSingle(key, mapID)
    poolN = 0
    local res = mapID and GT.ComputeGroups(key, mapID)
    if not res then Finish(0); return itemsOut, 0 end
    local spots = 0
    for i, g in ipairs(res.groups) do
        itemsOut[i] = NewItem(key, GT.GroupLabels[i])
        spots = spots + #g
    end
    Finish(#res.groups)
    for _, n in ipairs(GatherTimesDB[key]) do
        if n._left and n.mapID == mapID then
            local sp = GT.SpawnOfNode(key, n)
            local it = sp and itemsOut[res.of[sp] or 0]
            if it then
                if n._left <= 0 then
                    it.ready = it.ready + 1
                else
                    it.waiting = it.waiting + 1
                    if not it.minLeft or n._left < it.minLeft then it.minLeft = n._left end
                end
            end
        end
    end
    return itemsOut, spots      -- already in G1, G2, ... order
end

-- ALL CHECKED: every group of every item ticked in the Nodes panel that has learned spots in this zone,
-- with the item name.  Groups with a running timer first (ready, then soonest), idle groups after.
local checkedBase = {}
local function CheckedCmp(a, b)
    local aRun, bRun = (a.ready + a.waiting) > 0, (b.ready + b.waiting) > 0
    if aRun ~= bRun then return aRun end
    if aRun then
        local ar, br = a.waiting == 0, b.waiting == 0
        if ar ~= br then return ar end
        local am, bm = a.minLeft or 0, b.minLeft or 0
        if am ~= bm then return am < bm end
    end
    return a.ord < b.ord
end
local function BuildChecked(mapID)
    poolN = 0
    wipe(checkedBase)
    local n, nItems, nGroups, spots = 0, 0, 0, 0
    if mapID then
        local present = GT:NodesInZone(mapID)        -- only items with spots here (no empty group data is created)
        for _, key in ipairs(GT.order) do
            if present[key] and GT.IsEnabled(key) then
                local res = GT.ComputeGroups(key, mapID)
                if #res.groups > 0 then
                    nItems = nItems + 1
                    checkedBase[key] = n
                    local label = GT.nodes[key].label
                    for gi, g in ipairs(res.groups) do
                        n = n + 1
                        local it = NewItem(key, label .. " " .. GT.GroupLabels[gi], GT.GroupLabels[gi])
                        it.ord = n
                        itemsOut[n] = it
                        spots = spots + #g
                    end
                    nGroups = nGroups + #res.groups
                end
            end
        end
        for key, base in pairs(checkedBase) do
            local res = GT.ComputeGroups(key, mapID)
            for _, node in ipairs(GatherTimesDB[key]) do
                if node._left and node.mapID == mapID then
                    local sp = GT.SpawnOfNode(key, node)
                    local gi = sp and res.of[sp]
                    local it = gi and itemsOut[base + gi]
                    if it then
                        if node._left <= 0 then
                            it.ready = it.ready + 1
                        else
                            it.waiting = it.waiting + 1
                            if not it.minLeft or node._left < it.minLeft then it.minLeft = node._left end
                        end
                    end
                end
            end
        end
    end
    Finish(n)
    table.sort(itemsOut, CheckedCmp)
    local summary = n > 0 and GT.CountsText(nItems, nGroups, spots) or nil
    return itemsOut, summary
end

-- returns items, now, picked item key (or nil for "all"), summary text
local function BuildItems()
    local mapID = C_Map.GetBestMapForUnit("player")
    local now = GetServerTime()
    local only = GatherTimesDB._ui.mainItem          -- picked in the main-window dropdown ("all" = every checked node)
    if only == "all" or not GT.nodes[only] then only = nil end
    if only then
        local items, spots = BuildSingle(only, mapID)
        local summary = #items > 0 and GT.CountsText(nil, #items, spots) or nil
        return items, now, only, summary
    end
    local items, summary = BuildChecked(mapID)
    return items, now, nil, summary
end

-- status text and colour of one group (shared by the table rows and the minimized bar)
local function RowStatus(it)
    local total = it.ready + it.waiting
    if total == 0 then
        return GT.TR("Idle"), 0.6, 0.6, 0.6        -- known group, no timer running
    elseif it.waiting == 0 then
        return GT.TR("Ready"), 0.2, 1, 0.2
    elseif it.ready == 0 then
        return GT.TR("Waiting"), 1, 0.82, 0
    end
    return it.ready .. "/" .. total .. " " .. GT.TR("up"), 0.6, 1, 0.4
end

-- Used by UI\MiniBar.lua so the minimized bar shows exactly what the table shows.
GT.BuildMainItems = BuildItems
GT.MainRowStatus = RowStatus
GT.FormatMmss = Mmss

-- fills one visible row from one item
local function UpdateGridRow(r, it)
    local col = GT.Col(it.key)
    local status, sr, sg, sb = RowStatus(it)
    r.cells[1]:SetText(it.text)
    r.cells[1]:SetTextColor(col[1], col[2], col[3])
    r.cells[2]:SetText(status)
    r.cells[2]:SetTextColor(sr, sg, sb)
    r.cells[3]:SetText(it.minLeft and Mmss(it.minLeft) or "-")
end

function GT:CreateMainTable(parent)
    local box = CreateFrame("Frame", nil, parent)
    box:SetWidth(288)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -58)   -- under the dropdown

    local head = CreateGridRow(box, true)
    head:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", box, "TOPRIGHT", -1, -1)
    for i, col in ipairs(COLS) do head.cells[i]:SetText(GT.TR(col[1])) end

    -- body: a flat scroll list, 9 rows visible (mouse wheel / thin bar for more)
    local list = GT:CreateScrollList(box, 286, ROW_H * VISIBLE, ROW_H,
        function(l, i) return CreateGridRow(l, false, i) end, UpdateGridRow)
    list:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1 - ROW_H)
    box.list = list

    GT:RegisterSkinUpdater(ApplyRowColors)

    local note = GT.Font(parent, nil, "OVERLAY", "GameFontDisableSmall")
    note:SetWidth(284)

    -- inventory line under the note: only while ONE item is picked in the dropdown
    local inv = GT.Font(parent, nil, "OVERLAY", "GameFontDisableSmall")
    inv:SetWidth(284)
    inv:SetJustifyH("LEFT")

    function box:Update()
        local items, now, only, summary = BuildItems()
        local shown = math.min(#items, VISIBLE)
        list:SetHeight(ROW_H * math.max(1, shown))      -- the bar is as long as the visible rows
        list:SetItems(items)

        self:SetHeight(ROW_H * (shown + 1))

        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 2, -6)
        if #items == 0 then
            note:SetText(only and GT.TRF("No %s spots learned in this zone yet.", GT.nodes[only].label)
                or GT.TR("No spots learned in this zone yet - gather something."))
        elseif #items > VISIBLE then
            note:SetText((summary and (summary .. "  -  ") or "") .. GT.TR("scroll for more"))
        else
            note:SetText(summary or "")
        end

        -- how many of the picked item are in the bags (and bank, when the bank has some);
        -- a node can name another item to count instead (Thorium -> Arcane Crystal)
        local def = only and GT.nodes[only]
        local countId = def and (def.countId or def.id)
        if countId and GetItemCount then
            local bags = GetItemCount(countId) or 0
            local total = GetItemCount(countId, true) or bags
            local text = GT.TRF("In bags: |cffffd100%d|r", bags)
            if total > bags then text = text .. GT.TRF("   In bank: |cffffd100%d|r", total - bags) end
            inv:SetText(text)
            inv:Show()
        else
            inv:SetText("")
            inv:Hide()
        end
        inv:ClearAllPoints()
        inv:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -3)
    end

    box:Update()
    return box
end
