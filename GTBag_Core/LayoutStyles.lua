-- LayoutStyles.lua : where the sections of the window go.  Pure arithmetic: no frames, no game calls, so it can be
-- tested outside the game.  Panel.lua decides WHAT is shown (sections of items, grouped by category or by container);
-- this file decides WHERE each header and each item goes for the chosen window style (ns.STYLES, Core.lua):
--
--   stack    sections stacked top to bottom, each with a header and a grid as wide as the window (the original look)
--   columns  sections as compact blocks packed side by side (the shortest column gets the next block), AdiBags-like
--   flat     one continuous grid of every item, no headers
--   list     rows with room for a name and a value instead of icons only; sections stacked, rows filled column by column
--   sidebar  same as stack, but Panel adds a category rail on the left and shows one section at a time
local _, ns = ...

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local LIST_ROW_MIN = 170      -- narrowest useful list row (icon + name), in pixels
local COLUMN_GAP = 10         -- space between blocks (columns style) and between list columns
local MIN_BLOCK_SLOTS = 3     -- a block is never narrower than this many slots, so its header text stays readable

-- sections: array of { label = string or nil, n = item count }
-- p: { step, size, headerH, groupGap, gridW, cols, blocks }
-- returns { height, cellW, headers = { { section, x, y, w } }, cells = { [section] = { [i] = { x, y } } } }
-- one { x, y } table per slot used to be built on every drawing pass; the tables are reused instead.  Panel reads the
-- plan straight away and keeps no reference to it, so the next pass may overwrite them.
local cellPool, cellUsed = {}, 0
local function Cell(x, y)
    cellUsed = cellUsed + 1
    local c = cellPool[cellUsed]
    if c then
        c.x, c.y = x, y
    else
        c = { x = x, y = y }
        cellPool[cellUsed] = c
    end
    return c
end

function ns.PlanLayout(style, sections, p)
    cellUsed = 0
    local STEP, SIZE, HEAD, GAP = p.step, p.size, p.headerH, p.groupGap
    local gridW, cols = p.gridW, max(1, p.cols)
    local plan = { height = 0, headers = {}, cells = {} }

    local function Stack()
        local y = 0
        for i, s in ipairs(sections) do
            local cells = {}
            plan.cells[i] = cells
            if s.n > 0 or s.collapsed then
                if s.label then
                    plan.headers[#plan.headers + 1] = { section = i, x = 0, y = y, w = gridW }
                    y = y + HEAD
                end
                for j = 1, s.n do
                    cells[j] = Cell(((j - 1) % cols) * STEP, y + floor((j - 1) / cols) * STEP)
                end
                y = y + ceil(s.n / cols) * STEP + GAP
            end
        end
        plan.height = y
    end

    local function Flat()
        local g = 0
        for i, s in ipairs(sections) do
            local cells = {}
            plan.cells[i] = cells
            for j = 1, s.n do
                g = g + 1
                cells[j] = Cell(((g - 1) % cols) * STEP, floor((g - 1) / cols) * STEP)
            end
        end
        plan.height = g > 0 and (ceil(g / cols) * STEP + GAP) or 0
    end

    local function Columns()
        local nb = max(1, min(4, floor(tonumber(p.blocks) or 2)))
        -- a narrow window fits fewer blocks than asked for: keep every block at least MIN_BLOCK_SLOTS wide
        local minBlockW = MIN_BLOCK_SLOTS * STEP - (STEP - SIZE)
        nb = max(1, min(nb, floor((gridW + COLUMN_GAP) / (minBlockW + COLUMN_GAP))))
        if nb == 1 then return Stack() end
        -- slots per row inside a block, so that nb blocks (and the gaps) fit in the grid width
        local spr = max(1, floor(((gridW - (nb - 1) * COLUMN_GAP) / nb + (STEP - SIZE)) / STEP))
        local blockW = spr * STEP - (STEP - SIZE)
        local colGap = floor((gridW - nb * blockW) / (nb - 1))
        local heights = {}
        for c = 1, nb do heights[c] = 0 end
        for i, s in ipairs(sections) do
            local cells = {}
            plan.cells[i] = cells
            if s.n > 0 or s.collapsed then
                local c = 1
                for k = 2, nb do if heights[k] < heights[c] then c = k end end
                local x0, y0 = (c - 1) * (blockW + colGap), heights[c]
                local y = y0
                if s.label then
                    plan.headers[#plan.headers + 1] = { section = i, x = x0, y = y0, w = blockW }
                    y = y + HEAD
                end
                for j = 1, s.n do
                    cells[j] = Cell(x0 + ((j - 1) % spr) * STEP, y + floor((j - 1) / spr) * STEP)
                end
                heights[c] = y + ceil(s.n / spr) * STEP + GAP
            end
        end
        local h = 0
        for c = 1, nb do h = max(h, heights[c]) end
        plan.height = h
    end

    local function List()
        local lc = max(1, floor((gridW + COLUMN_GAP) / (LIST_ROW_MIN + COLUMN_GAP)))
        local rowW = floor((gridW - (lc - 1) * COLUMN_GAP) / lc)
        plan.cellW = rowW
        local y = 0
        for i, s in ipairs(sections) do
            local cells = {}
            plan.cells[i] = cells
            if s.n > 0 or s.collapsed then
                if s.label then
                    plan.headers[#plan.headers + 1] = { section = i, x = 0, y = y, w = gridW }
                    y = y + HEAD
                end
                local rows = ceil(s.n / lc)           -- fill the first column from the top, then the next
                for j = 1, s.n do
                    cells[j] = Cell(floor((j - 1) / rows) * (rowW + COLUMN_GAP), y + ((j - 1) % rows) * STEP)
                end
                y = y + rows * STEP + GAP
            end
        end
        plan.height = y
    end

    if style == "columns" then Columns()
    elseif style == "flat" then Flat()
    elseif style == "list" then List()
    else Stack() end               -- "stack" and "sidebar" (the rail is Panel's business)
    return plan
end
