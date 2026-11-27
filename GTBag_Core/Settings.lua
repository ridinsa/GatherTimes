-- Settings.lua : one window for the options that used to be slash commands only.  Open with /gtbag settings or by
-- right-clicking the Opt button in the inventory window.  Every control reads and writes the same saved options the
-- slash commands use, so the two stay in step (the window refreshes itself when it is shown).
local _, ns = ...

local UI = ns.UI
local PAD = UI.PAD
local WIN_W = 360                       -- one narrow column: the options are split over tabs instead of two long columns
local COLW, ROW = WIN_W - PAD * 2, 22
local TAB_TOP = -40                     -- tab row, just under the header rule
local CONTENT_TOP = -72                 -- first control of a tab

local win
local host                              -- the page of the tab being built: every control is created on it
local tabs, activeTab = {}, "look"
local controls = {}

local function Changed()
    if ns.Relayout then ns.Relayout() end
    for _, c in ipairs(controls) do c.Refresh() end
end

local function Tip(frame, title, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ---------------------------------------------------------------------------------------------- controls
-- Each builder puts a control at (col.x, col.y), moves col.y down and registers a Refresh function.
-- on/off: get() -> boolean, set(boolean)
local function Check(col, label, get, set, tip)
    local b = CreateFrame("Button", nil, host)
    b:SetSize(COLW, ROW - 4)
    b:SetPoint("TOPLEFT", host, "TOPLEFT", col.x, col.y)
    local box = b:CreateTexture(nil, "BORDER")
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 0, 0)
    box:SetColorTexture(0.34, 0.31, 0.24, 1)
    local inner = b:CreateTexture(nil, "ARTWORK")
    inner:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(0.06, 0.07, 0.09, 1)
    local tick = b:CreateTexture(nil, "OVERLAY")
    tick:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    tick:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    tick:SetColorTexture(1, 0.82, 0, 1)
    local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", box, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local h = b:GetHighlightTexture()
    if h then h:SetAlpha(0.08) end
    b:SetScript("OnClick", function() set(not get()); Changed() end)
    Tip(b, label, tip)
    controls[#controls + 1] = { Refresh = function() tick:SetShown(get() and true or false) end }
    col.y = col.y - ROW
end

-- number: get() -> number, set(number); lo / hi / step; fmt(value) -> text
local function Stepper(col, label, get, set, lo, hi, step, fmt, tip)
    local text = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", host, "TOPLEFT", col.x, col.y - 4)
    text:SetWidth(COLW - 100)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    local plus = UI.Button(host, "+", 20)
    plus:SetPoint("TOPRIGHT", host, "TOPLEFT", col.x + COLW, col.y)
    local value = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    value:SetPoint("RIGHT", plus, "LEFT", -2, 0)
    value:SetWidth(46)
    value:SetJustifyH("CENTER")
    local minus = UI.Button(host, "-", 20)
    minus:SetPoint("RIGHT", value, "LEFT", -2, 0)
    local function Bump(dir)
        local v = (tonumber(get()) or lo) + dir * step
        v = tonumber(string.format("%.4f", math.floor(v / step + 0.5) * step))   -- stay on the grid (no 0.7000001)
        set(math.max(lo, math.min(hi, v)))
        Changed()
    end
    minus:SetScript("OnClick", function() Bump(-1) end)
    plus:SetScript("OnClick", function() Bump(1) end)
    Tip(minus, label, tip)
    Tip(plus, label, tip)
    controls[#controls + 1] = { Refresh = function()
        local v = tonumber(get()) or lo
        value:SetText(fmt and fmt(v) or tostring(v))
        minus:SetEnabled(v > lo)
        plus:SetEnabled(v < hi)
    end }
    col.y = col.y - ROW
end

-- choice: values = { { value, text }, ... }; click = next, right-click = previous
local function Cycle(col, label, values, get, set, tip)
    local text = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", host, "TOPLEFT", col.x, col.y - 4)
    text:SetWidth(COLW - 130)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    local b = UI.Button(host, "", 124)
    b:SetPoint("TOPRIGHT", host, "TOPLEFT", col.x + COLW, col.y)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function Index()
        local cur = get()
        for i, v in ipairs(values) do if v[1] == cur then return i end end
        return 1
    end
    b:SetScript("OnClick", function(_, button)
        local i = Index() + (button == "RightButton" and -1 or 1)
        if i < 1 then i = #values elseif i > #values then i = 1 end
        set(values[i][1])
        Changed()
    end)
    Tip(b, label, (tip and (tip .. " ") or "") .. "Click for the next choice, right-click for the previous.")
    controls[#controls + 1] = { Refresh = function() b:SetText(values[Index()][2]) end }
    col.y = col.y - ROW
end

local function Action(col, label, func, tip)
    local b = UI.Button(host, label, COLW - 4, 20)
    b:SetPoint("TOPLEFT", host, "TOPLEFT", col.x, col.y)
    b:SetScript("OnClick", func)
    Tip(b, label, tip)
    col.y = col.y - ROW
end

-- ---------------------------------------------------------------------------------------------- window
local function OptCheck(col, label, key, tip, after)
    Check(col, label, function() return ns.Opt(key) end, function(v)
        ns.SetOpt(key, v)
        if after then after(v) end
    end, tip)
end
local function OptStepper(col, label, key, lo, hi, step, fmt, tip)
    Stepper(col, label, function() return ns.Opt(key) end, function(v) ns.SetOpt(key, v) end, lo, hi, step, fmt, tip)
end

local function GatherTimesUI()
    local ui = GatherTimesDB and GatherTimesDB._ui
    return type(ui) == "table" and ui or nil
end
local function FadeMoving()
    local ui = GatherTimesUI()
    return ui and ui.fadeMoving == true or (not ui and ns.Opt("fadeMoving"))
end
local function SetFadeMoving(value)
    local ui = GatherTimesUI()
    if ui then ui.fadeMoving = value else ns.SetOpt("fadeMoving", value) end
end
local function MoveAlpha()
    local ui = GatherTimesUI()
    return math.max(0.1, math.min(0.9, tonumber(ui and ui.moveAlpha) or ns.Opt("moveAlpha")))
end
local function SetMoveAlpha(value)
    local ui = GatherTimesUI()
    if ui then ui.moveAlpha = value else ns.SetOpt("moveAlpha", value) end
end

local SORTS = {
    { "priority", "Priority" }, { "name", "Name" }, { "quality", "Quality" },
    { "qualitycategory", "Quality > Category" }, { "type", "Type" }, { "expansion", "Expansion" },
    { "itemlevel", "Item level" }, { "value", "Value" }, { "category", "Category" }, { "count", "Number of items" },
}

-- a new tab page: a frame over the whole window that is only shown while its tab is selected.  Returns the column the
-- builders write into (they create their controls on `host`, which is set here).
local function Page(key, label)
    local page = CreateFrame("Frame", nil, win)
    page:SetAllPoints(win)
    page:Hide()
    host = page
    local col = { x = PAD, y = CONTENT_TOP }
    tabs[#tabs + 1] = { key = key, label = label, page = page, col = col }
    return col
end

local function SelectTab(key)
    local found = false
    for _, t in ipairs(tabs) do if t.key == key then found = true end end
    if not found then key = tabs[1].key end
    activeTab = key
    for _, t in ipairs(tabs) do
        local on = t.key == key
        t.page:SetShown(on)
        t.button.mark:SetShown(on)
        local normal = t.button:GetNormalTexture()
        if normal then UI.ThemeTexture(normal, on and "active" or "button") end
        t.button:SetNormalFontObject(on and "GameFontHighlightSmall" or "GameFontNormalSmall")
    end
end

local function BuildTabBar()
    local n, gap = #tabs, 2
    local w = math.floor((WIN_W - PAD * 2 - gap * (n - 1)) / n)
    for i, t in ipairs(tabs) do
        local b = UI.Button(win, t.label, w, 22)
        b:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + (i - 1) * (w + gap), TAB_TOP)
        local mark = b:CreateTexture(nil, "OVERLAY")          -- amber underline of the selected tab
        mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        mark:SetHeight(2)
        mark:SetColorTexture(0.94, 0.71, 0.29, 1)
        mark:Hide()
        b.mark = mark
        b:SetScript("OnClick", function() SelectTab(t.key) end)
        t.button = b
    end
end

local function Build()
    win = UI.Window("GTBagSettingsFrame", WIN_W, 300, "GTBag settings")

    -- ------------------------------------------------------------------------------------ Look: how the window looks
    local col = Page("look", "Look")
    Cycle(col, "View", { { "category", "Categories" }, { "bag", "Bag slots" } },
        function() return ns.Opt("view") end, function(v) ns.SetOpt("view", v) end)
    Cycle(col, "Theme", { { "fresh", "Fresh" }, { "gathertimes", "GatherTimes" } },
        function() return ns.Opt("theme") end,
        function(v) ns.SetOpt("theme", v); UI.ApplyTheme() end,
        "Fresh: ink-blue panel with amber accents. GatherTimes: follows the GatherTimes skin when that addon is installed.")
    Cycle(col, "Window style", ns.STYLES, function() return ns.Opt("style") end,
        function(v) ns.SetOpt("style", v) end,
        "Stacked: sections one under the other. Columns: sections side by side. One grid: every item in one grid, no headings. List: a row per item with its name and value. Sidebar: a category list on the left.")
    OptStepper(col, "Columns style: blocks", "blocks", 1, 4, 1, nil,
        "How many sections sit side by side in the Columns style (1 looks like Stacked).")
    OptStepper(col, "Columns", "cols", 8, 15, 1, nil, "Slots per row in the window (it also sets the window width in every style). Ctrl + mouse wheel over the window changes it too.")
    OptStepper(col, "Scale", "scale", 0.6, 1.6, 0.1, function(v) return string.format("%.1f", v) end)
    OptCheck(col, "Show the tab row", "toolbar", "Inv / Bank / Mail / Guild tabs under the search box. Also in the Opt menu.")
    Cycle(col, "Search", { { "filter", "Hide non-matches" }, { "dim", "Dim non-matches" } },
        function() return ns.Opt("searchMode") end, function(v) ns.SetOpt("searchMode", v) end)
    Check(col, "See-through while moving", FadeMoving, SetFadeMoving,
        "Shares the fade setting with GatherTimes. GTBag becomes solid again when you hover over it.")
    Stepper(col, "Moving opacity", function() return math.floor(MoveAlpha() * 100 + 0.5) end,
        function(v) SetMoveAlpha(v / 100) end, 10, 90, 5, function(v) return v .. "%" end,
        "Shared with GatherTimes > Settings > Display.")

    -- ------------------------------------------------------------------------------------ Bags: what GTBag takes over
    col = Page("bags", "Bags")
    OptCheck(col, "Replace the Blizzard bags", "replace",
        "GTBag opens with your bag key and hides the default bag windows out of combat. Turn off to use the default bags.")
    OptCheck(col, "Show the bank in GTBag", "replaceBank", "Takes effect the next time you visit the banker.")
    OptCheck(col, "Show the guild bank in GTBag", "replaceGuild", "Takes effect the next time you open the guild bank.")
    OptCheck(col, "Click and drag items (actions)", "liveActions",
        "Items in your own bags and bank act like the default bags: click, right-click, shift-click, drag. Off shows a safe display only.")
    OptCheck(col, "Close the window when combat starts", "hideInCombat",
        "GTBag closes by itself as soon as you enter combat. It does not reopen afterwards; open it again with your bag key. Saved for this character only.")
    OptCheck(col, "Reopen the window after combat", "reopenAfterCombat",
        "Needs Close the window when combat starts. The window it closed opens again when combat ends. Saved for this character only.")

    -- ------------------------------------------------------------------------------------ Sort: order and slots
    col = Page("sort", "Sort")
    Cycle(col, "Sort order", SORTS, function() return ns.Opt("sort") end, function(v) ns.SetSort(v) end,
        "Priority is Hearthstone > Mounts > Buffs > Food > Potions > Gear > A-Z, junk last. Used by Auto sort and Sort + Merge.")
    OptCheck(col, "Auto sort the displayed items", "autoSort", "Sorts what you see; it does not move items.")
    OptCheck(col, "Sort bags when a vendor opens", "autoSortVendor",
        "Runs the sort (with your sort order) when you open a vendor. Pinned, locked and hidden items stay where they are. Off by default.")
    OptCheck(col, "Sort the bank when it opens", "autoSortBank",
        "Runs the bank sort when you visit a banker. Off by default.")
    OptCheck(col, "Sort bags after combat", "autoSortCombat",
        "Runs the sort when combat ends, so the bags are tidy again after a fight. Off by default.")
    Check(col, "Merge all bags into one group", function() return ns.Opt("mergeBags") end,
        function(on)
            ns.SetOpt("mergeBags", on and true or false)
            if on then ns.SetOpt("view", "bag") end        -- the merged group is part of the bag-slots view
            if ns.Relayout then ns.Relayout() end
        end,
        "Bag-slots view shows the backpack and your bags as one group, \"All bags\", instead of one group per bag. Turning it on switches to the bag-slots view. Items are not moved. Quivers and ammo pouches stay separate.")
    OptCheck(col, "Ignore empty slots", "ignoreEmpty")
    OptCheck(col, "Route profession bags", "routeBags",
        "Sort + Merge moves herbs, ore, gems and other profession items into a matching herb, mining, gem, enchanting, engineering... bag when it has room. Arrows and bullets always go to quivers and ammo pouches.")
    OptCheck(col, "Sort skips hidden containers", "sortSkipHidden",
        "Sorting leaves bags and bank containers you hid under Opt > Containers alone: nothing is moved into or out of them.")
    OptCheck(col, "Glow on new items", "newGlow",
        "Items that arrived in your bags this session glow green until you hover them. Items picked up before you first opened the window this session are not marked.",
        function() if ns.RefreshNewMarks then ns.RefreshNewMarks() end; if ns.Relayout then ns.Relayout() end end)
    OptCheck(col, "Show a New section", "newSection",
        "Category view: new items are also listed together in a New section at the top. Needs Glow on new items.",
        function() if ns.Relayout then ns.Relayout() end end)

    -- ------------------------------------------------------------------------------------ Badges
    col = Page("badges", "Badges")
    OptCheck(col, "BoE label", "boe")
    OptCheck(col, "Item level on gear", "ilvl")
    OptCheck(col, "Pawn upgrade arrow", "pawn", "Needs the Pawn addon.")
    -- the on/off toggles are also in the Opt menu; the set-once corner and priority choices live only here
    local P = ns.panel
    local function OptCycle(label, key, values, tip)
        Cycle(col, label, values, function() return ns.Opt(key) end, function(v) ns.SetOpt(key, v) end, tip)
    end
    OptCycle("BoE corner", "boeCorner", P.BADGE_CORNERS)
    OptCycle("Item level corner", "ilvlCorner", P.BADGE_CORNERS)
    OptCycle("Pawn corner", "pawnCorner", P.BADGE_CORNERS)
    OptCycle("Priority", "badgePriority", P.BADGE_PRIORITIES,
        "Which badge wins when two of them want the same corner.")

    -- ------------------------------------------------------------------------------------ Alerts: warnings and mail
    col = Page("alerts", "Alerts")
    OptStepper(col, "Low bag slots", "warnFree", 0, 20, 1, function(v) return v == 0 and "off" or tostring(v) end,
        "Chat warning when this many general bag slots or fewer are free. It also sets the colours of the free-slot count in the Opt menu.")
    OptStepper(col, "Low ammo", "warnAmmo", 0, 2000, 25, function(v) return v == 0 and "off" or tostring(v) end,
        "Warning when your arrows or bullets drop to this number or fewer.")
    OptCheck(col, "Mail expiry watch", "mailWatch",
        "After login, a chat line lists characters whose saved mail is about to expire, the character list marks them, and the Mail tab says when new mail is waiting. Needs a mailbox visit to refresh. /gtbag mail shows the list.")
    OptStepper(col, "Mail warning (days)", "mailWarnDays", 1, 10, 1, function(v) return v .. "d" end,
        "Warn about saved mail that expires in fewer days than this.")
    OptCheck(col, "Skip cash-on-delivery mail", "mailSkipCOD",
        "COD mail is not counted as at risk, because you may not want to pay for it.")

    -- ------------------------------------------------------------------------------------ Tools: privacy, junk, windows
    col = Page("tools", "Tools")
    OptCheck(col, "Privacy mode", "scrambleNames",
        "Scrambles character and guild names and hides gold amounts, so screenshots are safe to share.",
        function(v) if v then ns.scrambleSalt = ((ns.scrambleSalt or 0) + 1) % 1000000 end end)
    OptCheck(col, "Privacy on at login", "privacyAtLogin",
        "Turns privacy mode on every time you log in. Toggle it any time with the key set in Key Bindings > AddOns > GTBag.")
    OptCheck(col, "Auto-sell junk at vendors", "autoSellJunk",
        "Sells grey items when a vendor window opens. Items on the keep list and pinned items are never sold.")
    col.y = col.y - 6
    Action(col, "Custom categories...", function() if ns.ShowCatEditor then ns.ShowCatEditor() end end)
    Action(col, "Backup / restore...", function() if ns.ShowBackup then ns.ShowBackup() end end,
        "Export or import nicknames, categories, the keep list, pinned items, hidden items and slots, and per-character settings.")
    Action(col, "Other bag addons...", function() if ns.ShowBagAddons then ns.ShowBagAddons(true) end end,
        "Choose which bag addon stays on when Baganator, Bagnon, AdiBags or similar are enabled too. The other one is turned off and the game reloads.")
    Action(col, "Apply default layout", function() ns.ApplyDefaultLayout() end,
        "Category view, 10 columns, stacked style, scale 1, empty slots shown, tab row hidden, window in the lower right. Pins, categories, hidden items and sort order are kept.")
    Action(col, "Reset window position", function() if ns.ResetPosition then ns.ResetPosition() end end)

    BuildTabBar()

    -- one height for every tab (the window does not jump when you switch): the longest page decides
    local lowest = CONTENT_TOP
    for _, t in ipairs(tabs) do lowest = math.min(lowest, t.col.y) end
    win:SetHeight(PAD - (lowest + 4))           -- the last row ends 4 px below its y

    win:SetScript("OnShow", function() for _, c in ipairs(controls) do c.Refresh() end end)
    for _, c in ipairs(controls) do c.Refresh() end
    SelectTab(activeTab)
end

-- /gtbag settings, or right-click Opt: toggles the window.  ns.ShowSettings("badges") opens it on that tab
-- (look, bags, sort, badges, alerts, tools).
function ns.ShowSettings(tab)
    if not win then
        if tab then activeTab = tab end
        Build()                                   -- a new window is already shown; Build refreshes its controls
    elseif tab then
        SelectTab(tab)
        win:Show()
    elseif win:IsShown() then
        win:Hide()
    else
        win:Show()
    end
end
