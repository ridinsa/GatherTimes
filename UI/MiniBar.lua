-- MiniBar.lua : the "minimized" bar.  The "-" button in the main window's title bar hides the window and shows
-- this bar instead: one full-width line docked at the top of the screen, like Titan Panel.  While it is shown the
-- game's top frames are moved down under it (UI\BarDock.lua); when the window comes back they return to normal.
-- Design: on the left a dropdown to pick the item (same as the main window), then a chip per group (same data and order as the table):
--   [|Copper G1   Ready ]  [|Copper G2   Waiting 3:41]  [|Tin G1   Idle]
-- a coloured edge in the item's colour, the group, its status and timer, and a thin bar along the bottom that is
-- full while the group is ready and drains as the respawn gets closer.  On the right, aligned to the right edge:
-- the bags (while one item is picked) and the session gold, then the "+" button.  Chips that do not fit are
-- replaced by "+N more".  The chips all have the same fixed width (sized for the current font style and size; no
-- shrinking or clipping of the text).  "+" or a right-click brings the window back.
-- Look options (right-click the "-" button > Minimize settings):
--   * bar size (ui.barScale) and background opacity (cfg miniBgAlpha, percent; the bar and chip backgrounds only, text stays solid)
--   * auto-fade: fade the whole bar while in combat (miniFadeCombat) and / or while the mouse is not over it (miniFadeMouse)
--     down to miniFadeAlpha percent; the mouse over the bar always brings it back to full strength
--   * urgency colours (miniUrgencyColors): the progress bar of a waiting chip goes white, then yellow, then red as the timer drops
-- State (GatherTimesDB._ui): minimized (bool), barDock (bool, push the game frames down).
local ADDON, GT = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"
local BAR_H = 24            -- height of the bar
local CELL_H, GAP = 20, 4   -- chip height, gap between chips
local BAG_BTN_H = 18        -- height of the "<" / ">" button
local ICON_SIZE, ICON_GAP = 16, 4   -- the picked item's icon, before the button
local DD_W, DD_H = 120, 20   -- item dropdown on the left (same choices as the main window)
local XP_BTN_W = 30         -- the "XP" button right after the dropdown (UI\MiniXP.lua)
local LEAD = 6 + DD_W + 4 + XP_BTN_W + 10   -- where the chips start: padding + dropdown + XP button + a little air
local PAD = 6               -- left padding
local BTN_W = 18            -- the restore button
local EDGE_W = 3            -- coloured edge on the left of a chip
local PROG_H = 2            -- progress bar along the bottom of a chip
local TEXT_PAD, MID_GAP = 6, 14
local IN_GAP = 5            -- space between the group name and its status inside a chip (was MID_GAP)
local MAX_ITEMS = 24        -- chips considered; the rest is summed up as "+N more"
local MAX_ITEMS_COMPACT = 48   -- compact chips are narrow, so more of them are considered
local BLINK_SECS = 15        -- a chip starts blinking when its timer is at or below this many seconds (cfg: miniBlinkSecs, 0 = off)
local FAST_SECS = 5          -- ... and blinks faster in the last few seconds
local YELLOW_SECS = 60       -- urgency colours: the progress bar turns yellow at or below this many seconds ...
local RED_SECS = 15          -- ... and red at or below this many (white above)
local FADE_IN, FADE_OUT = 4, 1.5    -- fade speed (alpha units per second) when the bar comes back / goes faint
local GOLD, GREY, WHITE = "|cffffd100", "|cff9a9a9a", "|cffffffff"

-- One reused record per chip (a new table per group per second would be garbage).
local recs = {}
local function Rec(i)
    local r = recs[i]
    if not r then r = {}; recs[i] = r end
    return r
end

-- progress bar colour of a waiting chip by time left: white, then yellow, then red
local function UrgencyColor(left)
    if left <= RED_SECS then return 1, 0.25, 0.25 end
    if left <= YELLOW_SECS then return 1, 0.82, 0 end
    return 1, 1, 1
end

-- reused scratch tables for the urgency sort (no garbage per second)
local sortOrder, sortRank, sortLeft, sortItems, idleItems = {}, {}, {}, {}, {}

-- Collects what the bar shows from the same source as the table (GT.BuildMainItems).
-- Returns: number of chips (records are in recs), total groups, bags text, gold text, count item id, idle groups hidden.
function GT.BuildMiniBarData()
    local items, _, only = GT.BuildMainItems()
    local n = 0
    local total = #items
    local cfgOpt = (GT.cfg and GT.cfg()) or {}
    local compact = cfgOpt.miniCompact == true
    -- optional: leave out idle groups (no timer running and nothing ready); only running / ready groups remain
    local idleHidden = 0
    if cfgOpt.miniHideIdle == true and total > 0 then
        local k = 0
        for i = 1, total do
            local it = items[i]
            if (it.ready or 0) + (it.waiting or 0) > 0 then
                k = k + 1
                idleItems[k] = it
            end
        end
        for i = k + 1, #idleItems do idleItems[i] = nil end
        idleHidden = total - k
        items, total = idleItems, k
    end
    -- optional: most urgent first (READY, then the shortest timer, then idle), so the chips that matter are never
    -- hidden behind "+N more".  Sorted BEFORE the MAX_ITEMS cut.  Ties keep the table's order.
    if total > 1 and cfgOpt.miniSortUrgency ~= false then
        local order = sortOrder
        for i = 1, total do order[i] = i end
        for i = total + 1, #order do order[i] = nil end
        for i = 1, total do
            local it = items[i]
            local rank, left
            if (it.ready or 0) > 0 then rank, left = 0, 0
            elseif it.minLeft then rank, left = 1, it.minLeft
            else rank, left = 2, 0 end
            sortRank[i], sortLeft[i] = rank, left
        end
        table.sort(order, function(a, b)
            local ra, rb = sortRank[a], sortRank[b]
            if ra ~= rb then return ra < rb end
            local la, lb = sortLeft[a], sortLeft[b]
            if la ~= lb then return la < lb end
            return a < b
        end)
        for i = 1, total do sortItems[i] = items[order[i]] end
        for i = total + 1, #sortItems do sortItems[i] = nil end
        items = sortItems
    end
    if total > 0 then
        n = math.min(total, compact and MAX_ITEMS_COMPACT or MAX_ITEMS)
        for i = 1, n do
            local it, r = items[i], Rec(i)
            local col = GT.Col(it.key)
            local status, sr, sg, sb = GT.MainRowStatus(it)
            -- compact: only the short group label ("G2"); the item is told apart by the coloured edge
            r.label, r.lr, r.lg, r.lb = (compact and it.glabel or it.text), col[1], col[2], col[3]
            r.status = status
            -- compact: "Idle" and "Ready" stay as words; while waiting only the timer is shown (in the status colour);
            -- a mix of ready and waiting nodes shows "ready/total" with the soonest timer
            if it.ready == 0 and it.waiting > 0 then
                r.status = ""
            elseif it.ready > 0 and it.waiting > 0 then
                r.status = it.ready .. "/" .. (it.ready + it.waiting)
            end
            r.sr, r.sg, r.sb = sr, sg, sb
            r.timer = it.minLeft and GT.FormatMmss(it.minLeft) or nil
            -- nearly respawned: the chip blinks (only while a timer is running and has not reached 0)
            local cfg = GT.cfg and GT.cfg()
            local blinkAt = cfg and cfg.miniBlinkSecs
            if blinkAt == nil then blinkAt = BLINK_SECS end
            r.blink = (blinkAt > 0 and it.minLeft and it.minLeft > 0 and it.minLeft <= blinkAt) and true or false
            r.fast = r.blink and it.minLeft <= FAST_SECS
            -- bar along the bottom: full while ready, otherwise the share of the respawn time that is left
            local frac
            if it.ready > 0 and it.waiting == 0 then
                frac = 1
            elseif it.minLeft then
                local def = GT.nodes[it.key]
                local t = def and def.timer
                frac = (t and t > 0) and math.max(0, math.min(1, it.minLeft / t)) or nil
            end
            r.frac = frac
            -- colour tiers for the progress bar (option): only while a timer is running, ready stays green
            if cfg and cfg.miniUrgencyColors ~= false and it.waiting > 0 and it.minLeft then
                r.pr, r.pg, r.pb = UrgencyColor(it.minLeft)
            else
                r.pr, r.pg, r.pb = nil, nil, nil
            end
        end
    end

    local bags
    local def = only and GT.nodes[only]
    local countId = def and (def.countId or def.id)
    if countId and GetItemCount then
        bags = "< |cffffd100" .. (GetItemCount(countId) or 0) .. "|r"     -- "<" opens the strip to the left
    end
    local gold = GT.SessionGoldText and GT.SessionGoldText()
    if gold == "" then gold = nil end
    return n, total, bags, gold, countId, idleHidden      -- countId: the item the bags text counts (its icon is shown)
end

-- ---------------------------------------------------------------- chips
local function BgAlpha()
    local c = GT.cfg and GT.cfg()
    local pct = c and tonumber(c.miniBgAlpha) or 95
    return math.max(0, math.min(100, pct)) / 100
end

local function PaintChipBackgrounds(f)
    local c = GT.colors and GT.colors.button or { 0.16, 0.16, 0.16, 1 }
    local a = BgAlpha()
    -- chips were 0.9 when the bar background was 0.95: scale them with the slider (100 % = 0.95)
    local chipA = math.min(1, 0.9 * a / 0.95)
    for _, chip in ipairs(f.chips or {}) do chip.bg:SetVertexColor(c[1], c[2], c[3], chipA) end
end

-- Bar background: the skin paints the frame with colour alpha * gtSkinAlpha, so only that factor is changed here.
-- The border follows it, so a see-through bar does not keep a hard outline.
local function PaintBarBackground(f)
    if not f then return end
    local a = BgAlpha()
    f.gtSkinAlpha = a / 0.95                     -- skin bg alpha is ~0.95 (0.98 on some skins): 100 % = the skin's own look
    if GT.SkinFrame then GT.SkinFrame(f, "bg") end
    local br, bg, bb = unpack((GT.colors and GT.colors.border) or { 0, 0, 0, 1 })
    f:SetBackdropBorderColor(br, bg, bb, math.min(1, a))
    PaintChipBackgrounds(f)
end

function GT:ApplyBarBackground() PaintBarBackground(self.bar) end

-- target alpha of the whole bar for the auto-fade options (1 = fully visible)
local function FadeTarget(f)
    local c = GT.cfg and GT.cfg()
    if not c or not (c.miniFadeCombat or c.miniFadeMouse) then return 1 end
    -- the mouse over the bar (or its open dropdown / bags strip) always shows it fully
    if f:IsMouseOver() or f.bagsOpen or (f.dropdown and f.dropdown.list and f.dropdown.list:IsShown()) then return 1 end
    local faded = false
    if c.miniFadeCombat and (InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))) then faded = true end
    if c.miniFadeMouse then faded = true end       -- (the mouse is not over it: checked above)
    if not faded then return 1 end
    return math.max(0, math.min(100, tonumber(c.miniFadeAlpha) or 30)) / 100
end

local function StepFade(f, elapsed)
    local target = FadeTarget(f)
    local cur = f.curAlpha or 1
    if cur == target then return end
    local d = target - cur
    local step = (d > 0 and FADE_IN or FADE_OUT) * elapsed
    if math.abs(d) <= step then cur = target else cur = cur + (d > 0 and step or -step) end
    f.curAlpha = cur
    f:SetAlpha(cur)
end

function GT:ApplyBarFade()
    local f = self.bar
    if not f then return end
    local t = FadeTarget(f)
    f.curAlpha = t
    f:SetAlpha(t)
end

local function NewChip(f)
    local chip = CreateFrame("Frame", nil, f)       -- no mouse: right-click goes to the bar itself
    chip:SetHeight(CELL_H)

    chip.bg = chip:CreateTexture(nil, "BACKGROUND")
    chip.bg:SetAllPoints()
    chip.bg:SetTexture(FLAT)

    chip.glow = chip:CreateTexture(nil, "BACKGROUND", nil, 1)    -- pulses in the status colour when the timer is nearly 0
    chip.glow:SetAllPoints()
    chip.glow:SetTexture(FLAT)
    chip.glow:SetAlpha(0)
    chip.glow:Hide()

    chip.edge = chip:CreateTexture(nil, "ARTWORK")
    chip.edge:SetTexture(FLAT)
    chip.edge:SetPoint("TOPLEFT"); chip.edge:SetPoint("BOTTOMLEFT")
    chip.edge:SetWidth(EDGE_W)

    chip.prog = chip:CreateTexture(nil, "ARTWORK")
    chip.prog:SetTexture(FLAT)
    chip.prog:SetPoint("BOTTOMLEFT", chip, "BOTTOMLEFT", EDGE_W, 0)
    chip.prog:SetHeight(PROG_H)

    chip.label = GT.Font(chip, nil, "OVERLAY", "GameFontHighlightSmall")
    chip.label:SetPoint("LEFT", chip, "LEFT", EDGE_W + TEXT_PAD, 1)
    chip.label:SetJustifyH("LEFT")
    chip.label:SetWordWrap(false)

    chip.status = GT.Font(chip, nil, "OVERLAY", "GameFontHighlightSmall")
    chip.status:SetPoint("LEFT", chip, "LEFT", EDGE_W + TEXT_PAD + 40, 1)   -- Layout moves it to the status column
    chip.status:SetJustifyH("LEFT")                 -- left-aligned: the text grows to the right, the start never moves
    chip.status:SetWordWrap(false)

    pcall(GT.ApplyLangFont, chip)                   -- chips are made on demand, after the start-up font pass
    f.chips[#f.chips + 1] = chip
    PaintChipBackgrounds(f)
    return chip
end

-- natural width of a label (the width is cleared first, so the measure is the text itself)
local function Measure(fs, text)
    -- back to the full-size font first: an earlier fit may have shrunk it, and a measure taken at the shrunk size
    -- would make the chip too narrow for the full-size text, so it would stay shrunk (or cut) for good
    pcall(GT.FitText, fs, 10000)
    fs:SetWidth(0)
    fs:SetText(text)
    return fs:GetStringWidth() or 0
end

local function StatusText(r)
    if r.status == "" then return r.timer or "" end          -- waiting: just the timer
    return r.status .. (r.timer and (" " .. WHITE .. r.timer .. "|r") or "")
end

-- Session summary tooltip on the gold text (same text as the Show summary panel / chat summary). Right-click resets the session.
-- It is the add-on's own tooltip (GT.Tip), which is shared: when the mouse goes back onto the bar, the bar's own
-- OnEnter shows its tip in its place, so the summary goes away by itself; OnLeave hides it as well.
-- Reset needs two right-clicks: the first arms it (GetTime of that click), the second within RESET_CONFIRM seconds resets.
local RESET_CONFIRM = 3
local resetArmed = -math.huge

local function ShowSummaryTip(owner)
    local tip = GT.Tip
    tip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
    tip:AddLine(GT.TR("Session summary"), 1, 0.82, 0)
    -- option (Settings > Display): off = list only the items ticked in the Nodes panel; the Value still counts all loot
    local text = GT.FormatStats and GT.FormatStats(GT.cfg().miniSummaryAll == false) or ""
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            tip:AddLine(line, 1, 1, 1, #line > 48)
        end
    end
    if GetTime() - resetArmed <= RESET_CONFIRM then
        tip:AddLine(GT.TR("Right-click again to reset session"), 1, 0.3, 0.3)
    else
        tip:AddLine(GT.TR("Right-click: reset session"), 0.6, 0.6, 0.6)
    end
    tip:Show()
end

-- ---------------------------------------------------------------- bags strip
-- Click the "In bags" text (shown while one item is picked) to open a strip to its LEFT: for every item ticked in
-- the Nodes panel, its icon and the number in the bags.  Click the text again to close it.  No tooltips here.
local STRIP_ICON, STRIP_GAP, ITEM_GAP = 14, 3, 8
local stripItems = {}

local function ItemIcon(id)
    local icon
    if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(id) end
    if not icon and GetItemInfoInstant then icon = select(5, GetItemInfoInstant(id)) end
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function StripItem(f, i)
    local it = stripItems[i]
    if not it then
        it = CreateFrame("Frame", nil, f)
        it.icon = it:CreateTexture(nil, "ARTWORK")
        it.icon:SetSize(STRIP_ICON, STRIP_ICON)
        it.icon:SetPoint("LEFT", it, "LEFT", 0, 0)
        it.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        it.count = GT.Font(it, nil, "OVERLAY", "GameFontHighlightSmall")
        it.count:SetPoint("LEFT", it.icon, "RIGHT", STRIP_GAP, 0)
        it.count:SetJustifyH("LEFT")
        it.count:SetWordWrap(false)
        pcall(GT.ApplyLangFont, it)
        stripItems[i] = it
    end
    return it
end

local function HideStrip(f)
    for i = 1, #stripItems do stripItems[i]:Hide() end
    f.stripN = 0
end

-- Fills the strip with every ticked item.  Returns the strip's width (0 when there is nothing to show).
local function BuildStrip(f)
    local n, width = 0, 0
    -- only the rows the Nodes frame is showing (its herb / ore filter and this-zone view), and only the ticked ones.
    -- Before the Nodes frame has been built, every ticked node is used.
    local shownIn
    if GT.nodesListed then
        shownIn = {}
        for _, k in ipairs(GT.nodesListed) do shownIn[k] = true end
    end
    for _, key in ipairs(GT.order) do
        if GT.IsEnabled(key) and (not shownIn or shownIn[key]) then
            local def = GT.nodes[key]
            local id = def.countId or def.id                  -- Thorium counts Arcane Crystal
            local have = GetItemCount and (GetItemCount(id) or 0) or 0
            if have > 0 then                                  -- items with none in the bags are left out
            n = n + 1
            local it = StripItem(f, n)
            it.icon:SetTexture(ItemIcon(id))
            local count = tostring(have)
            it.count:SetText(count)
            it.w = STRIP_ICON + STRIP_GAP + Measure(it.count, count)
            it:SetSize(it.w, BAR_H)
            it:Show()
            width = width + it.w + (n > 1 and ITEM_GAP or 0)
            end
        end
    end
    for i = n + 1, #stripItems do stripItems[i]:Hide() end
    f.stripN = n
    return n > 0 and width or 0
end

-- lays the strip out so that it ends `edge` pixels in from the bar's right edge
local function PlaceStrip(f, stripW, edge)
    local x = 0
    for i = 1, f.stripN or 0 do
        local it = stripItems[i]
        it:ClearAllPoints()
        it:SetPoint("LEFT", f, "RIGHT", -(edge + stripW) + x, 0)
        x = x + it.w + ITEM_GAP
    end
end

function GT:ToggleBagsStrip()
    local f = self.bar
    if not f then return end
    f.bagsOpen = not f.bagsOpen
    self:UpdateMiniBar()
end

local function Layout(f, n, total, bags, gold, iconId, idleHidden)
    -- the usable width in the bar's own units (the bar is anchored edge to edge of the screen)
    local availW = UIParent:GetWidth() * UIParent:GetEffectiveScale() / f:GetEffectiveScale()

    -- while the strip is open the arrow turns to ">" (click to close); the numbers are in the strip
    if bags and f.bagsOpen then bags = ">" end

    -- right side, from the right edge: "+" button, gold, bags, then the strip (when open)
    local right = 3 + BTN_W + 8
    local goldW = gold and Measure(f.gold, GOLD .. gold .. "|r") or 0
    f.gold:SetShown(gold ~= nil)
    if gold then
        f.gold:ClearAllPoints()
        f.gold:SetPoint("RIGHT", f, "RIGHT", -right, 0)
        right = right + goldW
        f.goldHit:ClearAllPoints()
        f.goldHit:SetPoint("TOPLEFT", f.gold, "TOPLEFT", -4, 3)
        f.goldHit:SetPoint("BOTTOMRIGHT", f.gold, "BOTTOMRIGHT", 4, -3)
        f.goldHit:Show()
    else
        f.goldHit:Hide()
    end
    local btn = f.bagsBtn
    if bags then
        btn.label:SetText(bags)
        local bw = math.ceil(Measure(btn.label, bags) + 16)
        btn:SetSize(bw, BAG_BTN_H)
        GT.FitText(btn.label, bw - 8)
        if gold then right = right + MID_GAP end
        btn:ClearAllPoints()
        btn:SetPoint("RIGHT", f, "RIGHT", -right, 0)
        right = right + bw
        GT:SetButtonActive(btn, f.bagsOpen)               -- lit while the strip is open
        btn:Show()

        -- the picked item's icon, just before the button
        if iconId and not f.bagsOpen then                  -- not while the strip is open
            f.itemIcon:SetTexture(ItemIcon(iconId))
            f.itemIcon:ClearAllPoints()
            f.itemIcon:SetPoint("RIGHT", f, "RIGHT", -right - ICON_GAP, 0)
            f.itemIcon:Show()
            right = right + ICON_GAP + ICON_SIZE
        else
            f.itemIcon:Hide()
        end
    else
        btn:Hide()
        f.itemIcon:Hide()
        f.bagsOpen = false
    end

    -- the strip sits to the left of the bags text
    local stripW = 0
    if bags and f.bagsOpen then stripW = BuildStrip(f) else HideStrip(f) end
    local stripEdge = right + MID_GAP
    if stripW > 0 then
        PlaceStrip(f, stripW, stripEdge)
        right = stripEdge + stripW
    end

    -- the XP button shows whether XP mode is on; XP mode replaces the chips with one line of XP information
    -- the XP button: shown or hidden by "Show XP button" (Minimize settings > XP); hiding it also turns XP mode off
    local btnOn = (not GT.MiniXP) or GT.MiniXP.ButtonShown()
    if f.xpBtn then f.xpBtn:SetShown(btnOn) end
    if not btnOn and GT.MiniXP then GT.MiniXP.SetOn(false) end
    local xpOn = (btnOn and GT.MiniXP and GT.MiniXP.IsOn()) or false
    if f.xpBtn then GT:SetButtonActive(f.xpBtn, xpOn) end
    -- where the chips start: after the XP button when it is shown, right after the dropdown when it is hidden
    local lead = btnOn and LEAD or (LEAD - XP_BTN_W - 4)
    if xpOn then
        for _, chip in ipairs(f.chips) do chip.blink = nil; chip:Hide() end
        f.note:Hide()
        local lineW = availW - lead - right - MID_GAP
        f.xpLine:ClearAllPoints()
        f.xpLine:SetPoint("LEFT", f, "LEFT", lead + 2, 0)
        f.xpLine:SetWidth(math.max(20, lineW))
        pcall(GT.FitText, f.xpLine, math.max(20, lineW))   -- shrinks the font when the line is too long
        f.xpLine:SetText(GT.MiniXP.LineText())
        f.xpLine:Show()
        return
    end
    f.xpLine:Hide()


    -- chips: ONE fixed width for all of them (not adaptive).  It is wide enough for the widest group name plus the
    -- widest status / timer at the CURRENT font style and size.  Nothing is shrunk or clipped, so a timer is never
    -- cut off; when the chips do not fit on the bar, fewer of them are shown and the rest goes into "+N more".
    local labelW, statusW = 0, 0
    for i = 1, n do
        local chip = f.chips[i] or NewChip(f)
        local lw = Measure(chip.label, recs[i].label)
        if lw > labelW then labelW = lw end
    end
    if n > 0 then
        -- sized for the status words that are on the bar right now plus the longest timer in use.  Digits are not
        -- all equally wide in every font, so the sample is measured with 8 and with 0 and the wider one is kept.
        -- It only changes when a new status word or a longer timer shows up, not while the timers tick.
        local fs = f.chips[1].status
        local longest = 4                                    -- "8:88" at least
        for i = 1, n do
            local t = recs[i].timer
            if t and #t > longest then longest = #t end
        end
        local seen = {}
        for i = 1, n do
            local r = recs[i]
            local key = r.status .. (r.timer and "+t" or "")
            if not seen[key] then
                seen[key] = true
                for _, d in ipairs({ "8", "0" }) do
                    local text = r.status
                    if r.timer then
                        local sample = string.rep(d, longest - 3) .. ":" .. d .. d
                        text = (text ~= "" and (text .. " ") or "") .. sample
                    end
                    local sw = Measure(fs, text)
                    if sw > statusW then statusW = sw end
                end
            end
        end
        statusW = math.ceil(statusW) + 2                     -- a little slack against rounding
    end
    local cellW = math.ceil(EDGE_W + TEXT_PAD + labelW + IN_GAP + statusW + TEXT_PAD)

    -- how many chips fit left of the right-hand info (all chips are cellW wide, GAP apart)
    local room = availW - lead - right - MID_GAP
    local noteW = Measure(f.note, "+99 more")
    local shown = 0
    for k = n, 1, -1 do
        local noteRoom = (k < total) and (GAP + noteW + 4) or 0
        if k * cellW + (k - 1) * GAP + noteRoom <= room then shown = k; break end
    end
    if shown == 0 and n > 0 and cellW <= room then shown = 1 end   -- always keep one chip when it fits at all

    local y = -(BAR_H - CELL_H) / 2
    local statusX = cellW - TEXT_PAD - statusW        -- left edge of the status column: the same in every chip
    for i, chip in ipairs(f.chips) do
        if i <= shown then
            local r = recs[i]
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", f, "TOPLEFT", lead + (i - 1) * (cellW + GAP), y)
            chip:SetSize(cellW, CELL_H)
            chip.label:SetTextColor(r.lr, r.lg, r.lb)
            chip.status:SetTextColor(r.sr, r.sg, r.sb)
            chip.status:ClearAllPoints()
            chip.status:SetPoint("LEFT", chip, "LEFT", statusX, 1)
            chip.blink, chip.fast = r.blink, r.fast
            if r.blink then
                chip.glow:SetVertexColor(r.sr, r.sg, r.sb)
                chip.glow:Show()
            else
                chip.glow:Hide()
                chip.glow:SetAlpha(0)
                chip.status:SetAlpha(1)
            end
            chip.edge:SetVertexColor(r.lr, r.lg, r.lb, 1)
            if r.frac then
                if r.pr then chip.prog:SetVertexColor(r.pr, r.pg, r.pb, 1)      -- urgency tier
                else chip.prog:SetVertexColor(r.sr, r.sg, r.sb, 0.9) end
                chip.prog:SetWidth(math.max(1, (cellW - EDGE_W) * r.frac))
                chip.prog:Show()
            else
                chip.prog:Hide()
            end
            -- fixed size: full-size font (chosen style and size), natural width, never shrunk or clipped
            pcall(GT.FitText, chip.label, 10000)
            chip.label:SetText(r.label)
            pcall(GT.FitText, chip.status, 10000)
            chip.status:SetText(StatusText(r))
            chip:Show()
        else
            chip.blink = nil
            chip:Hide()
        end
    end

    -- the note: nothing learned here, or the groups that did not fit
    f.note:ClearAllPoints()
    if total == 0 then
        f.note:SetPoint("LEFT", f, "LEFT", lead + 2, 0)
        f.note:SetWidth(math.max(20, room))
        -- groups exist but "hide idle groups" left none: say so instead of "no spots learned"
        local msg = (idleHidden or 0) > 0 and "No groups running or ready." or "No spots learned in this zone yet - gather something."
        f.note:SetText(GREY .. GT.TR(msg) .. "|r")
        f.note:Show()
    elseif shown < total then
        local x = lead + (shown > 0 and (shown * cellW + (shown - 1) * GAP + GAP) or 0) + 2
        f.note:SetPoint("LEFT", f, "LEFT", x, 0)
        f.note:SetWidth(0)
        f.note:SetText(GREY .. GT.TRF("+%d more", total - shown) .. "|r")
        f.note:Show()
    else
        f.note:Hide()
    end
end

-- The bar's dropdown shows the main window's entries (the nodes checked in the Nodes panel that have spots in this
-- zone) and the same pick (_ui.mainItem), so the two always agree.
function GT:SyncBarDropdown()
    local f, m = self.bar, self.main
    if not (f and f.dropdown and m and m.dropdown) then return end
    local items, index = m.dropdown.items, m._ddIndex
    if f.dropdown._src ~= items then
        f.dropdown._src = items
        f.dropdown:SetItems(items)
        f.dropdown.selected = nil
    end
    if index and f.dropdown.selected ~= index then f.dropdown:SetSelected(index) end
end


function GT:UpdateMiniBar()
    local f = self.bar
    if not (f and f:IsShown()) then return end
    pcall(self.RefreshMainDropdown, self)       -- keeps the list and the pick current while the window is hidden
    pcall(self.SyncBarDropdown, self)
    local ok, n, total, bags, gold, iconId, idleHidden = pcall(GT.BuildMiniBarData)
    if ok then
        ok, n = pcall(Layout, f, n, total, bags, gold, iconId, idleHidden)      -- (n carries the error text when this fails)
    end
    if not ok then
        if not f._errored then f._errored = true; GT.ReportError("mini bar", n) end
    else
        f._errored = nil
    end
end

function GT:CreateMiniBar()
    if self.bar then return self.bar end
    local ui = GatherTimesDB._ui
    local f = self:CreateFlatFrame("GatherTimesBar", UIParent, 200, BAR_H)
    -- DIALOG sits above the character frame, buffs, the minimap and its buttons (all MEDIUM / HIGH), and below
    -- tooltips.
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetScale(ui.barScale or 1)      -- independent of the main window size (ui.scale)
    f.chips = {}

    -- docked: edge to edge along the top of the screen
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    f:SetHeight(BAR_H)

    -- item dropdown, before the first group
    f.dropdown = self:CreateDropdown(f, DD_W, DD_H, { GT.TR("All checked") }, function(index)
        GT:PickMainItem(index)
    end, 12)
    f.dropdown:SetPoint("LEFT", f, "LEFT", PAD, 0)
    f.dropdown:HookScript("OnClick", function() GT:RefreshMainDropdown(); GT:SyncBarDropdown() end)

    -- "XP" button, right after the dropdown: turns XP mode on and off (UI\MiniXP.lua).  Picking an item turns it off.
    local xpBtn = self:CreateFlatButton(f, "XP", XP_BTN_W, DD_H)
    xpBtn:SetPoint("LEFT", f.dropdown, "RIGHT", 4, 0)
    xpBtn:SetScript("OnClick", function()
        if GT.MiniXP then GT.MiniXP.SetOn(not GT.MiniXP.IsOn()) end
        GT:UpdateMiniBar()
    end)
    xpBtn:HookScript("OnEnter", function(b)
        if GT.MiniXP then GT.MiniXP.ShowTip(b) end
    end)
    xpBtn:HookScript("OnLeave", function() GT.Tip:Hide() end)
    f.xpBtn = xpBtn

    f.note = GT.Font(f, nil, "OVERLAY", "GameFontDisableSmall")
    f.note:SetJustifyH("LEFT")
    f.note:SetWordWrap(false)
    f.gold = GT.Font(f, nil, "OVERLAY", "GameFontNormalSmall")
    -- XP mode: all the hero / pet XP information in one line, in place of the chips (UI\MiniXP.lua)
    f.xpLine = GT.Font(f, nil, "OVERLAY", "GameFontHighlightSmall")
    f.xpLine:SetJustifyH("LEFT")
    f.xpLine:SetWordWrap(false)
    f.xpLine:Hide()
    f.gold:SetJustifyH("RIGHT")
    f.gold:SetWordWrap(false)

    -- the "<" / ">" button: opens / closes the strip of every ticked item.  Right-click restores the window.
    f.bagsBtn = self:CreateFlatButton(f, "<", 30, BAG_BTN_H)
    f.bagsBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.bagsBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then GT:SetMinimized(false) else GT:ToggleBagsStrip() end
    end)
    f.bagsBtn:Hide()

    -- icon of the item picked in the dropdown, shown before the "<" / ">" button (Layout places it)
    f.itemIcon = f:CreateTexture(nil, "ARTWORK")
    f.itemIcon:SetSize(ICON_SIZE, ICON_SIZE)
    f.itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.itemIcon:Hide()

    -- hover area over the gold text: shows the session summary tooltip
    local hit = CreateFrame("Frame", nil, f)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(s) ShowSummaryTip(s) end)
    hit:SetScript("OnLeave", function() GT.Tip:Hide() end)
    hit:SetScript("OnMouseUp", function(s, button)      -- right-click twice here resets the session (the summary is printed first)
        if button ~= "RightButton" then return end
        if GetTime() - resetArmed <= RESET_CONFIRM then
            resetArmed = 0
            GT.ResetSessionStats()
        else
            resetArmed = GetTime()                       -- first click: ask for the second one
        end
        ShowSummaryTip(s)                                -- show the confirm / reset line straight away
    end)
    hit:Hide()
    f.goldHit = hit
    GT:RegisterSkinUpdater(function() PaintBarBackground(f) end)
    PaintBarBackground(f)

    local restore = self:CreateFlatButton(f, "+", BTN_W, BTN_W)
    restore:SetPoint("RIGHT", f, "RIGHT", -3, 0)
    restore:SetScript("OnClick", function() GT:SetMinimized(false) end)
    f.restore = restore

    -- right-click anywhere on the bar restores the window
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then GT:SetMinimized(false) end
    end)

    -- refresh once a second (the main window is hidden, so its own update loop is not running)
    local acc = 0
    f:SetScript("OnUpdate", function(s, elapsed)
        -- blink: smooth pulse every frame for the chips whose timer is nearly 0
        local t = GetTime()
        for _, chip in ipairs(s.chips) do
            if chip.blink and chip:IsShown() then
                local pulse = 0.5 + 0.5 * math.sin(t * (chip.fast and 12 or 6))   -- ~2 Hz, ~4 Hz in the last seconds
                chip.glow:SetAlpha(0.12 + 0.38 * pulse)
                chip.status:SetAlpha(0.4 + 0.6 * pulse)
            end
        end
        StepFade(s, elapsed)                            -- auto-fade (combat / mouse away), smooth every frame
        acc = acc + elapsed
        if acc < 1 then return end
        acc = 0
        GT:UpdateMiniBar()
        if GT.MiniXP and s.xpBtn and s.xpBtn:IsShown() and s.xpBtn:IsMouseOver() and GT.Tip.owner == s.xpBtn then
            GT.MiniXP.ShowTip(s.xpBtn)                  -- keep the XP tooltip live while it is open
        end
        if s.goldHit and s.goldHit:IsShown() and s.goldHit:IsMouseOver() and GT.Tip.owner == s.goldHit then
            ShowSummaryTip(s.goldHit)                   -- keep the numbers live while it is open
        end
    end)
    -- the game frames make room while the bar is shown and return when it goes away (UI\BarDock.lua)
    f:SetScript("OnShow", function()
        acc = 0
        GT:ApplyBarFade()
        GT:UpdateMiniBar()
        if GT.BarDock then GT.BarDock.Sync() end
    end)
    f:SetScript("OnHide", function()
        f.bagsOpen = false                              -- the strip closes with the bar
        if GT.BarDock then GT.BarDock.Sync() end
    end)
    f:Hide()
    self.bar = f
    return f
end

-- true: hide the main window and show the bar.  false: hide the bar and show the main window.
-- "Always show minimized panel" (PanelMinimize.lua).  On: the bar stays up whatever the main window and the other
-- windows do.  Off: the bar appears only when the "-" button is clicked, and goes away when the window comes back.
function GT:AlwaysShowBar()
    local c = GT.cfg and GT.cfg()
    return c and c.miniAlwaysShow == true or false
end

function GT:ShowBarAlways()
    if not self.main then return end
    local ok, bar = pcall(self.CreateMiniBar, self)
    if not ok then GT.ReportError("mini bar", bar); return end
    bar:Show()
end

-- called when the option is switched: on shows the bar, off hides it unless the window is minimized
function GT:ApplyAlwaysBar()
    if self:AlwaysShowBar() then
        self:ShowBarAlways()
    else
        local ui = GatherTimesDB and GatherTimesDB._ui
        if self.bar and not (ui and ui.minimized) then self.bar:Hide() end
    end
end

function GT:SetMinimized(on)
    local ui = GatherTimesDB and GatherTimesDB._ui
    if not (ui and self.main) then return end
    if on then
        local ok, bar = pcall(self.CreateMiniBar, self)
        if not ok then GT.ReportError("mini bar", bar); return end      -- main window stays as it is
        ui.minimized = true
        self._minimizing = true            -- the main window's OnHide must not count this as "closed"
        self.main:Hide()
        self._minimizing = nil
        bar:Show()
    else
        ui.minimized = false
        if self.bar and not self:AlwaysShowBar() then self.bar:Hide() end
        self.main:Show()
    end
end

function GT:ToggleMinimized()
    local ui = GatherTimesDB and GatherTimesDB._ui
    self:SetMinimized(not (ui and ui.minimized))
end
