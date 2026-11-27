-- PanelMenus.lua : header tabs, badges, the small menu and the nickname editor. Part of the Panel window (see PanelState.lua).
local _, ns = ...
local P = ns.panel

P.TABS = { { "bags", "Inv", ns.SIZE }, { "bank", "Bank", ns.SIZE }, { "mail", "Mail", ns.SIZE }, { "guild", "Guild", ns.SIZE } }

function P.GetHeader(i)
    local h = P.headers[i]
    if not h then
        h = P.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetJustifyH("LEFT")
        h:SetTextColor(0.72, 0.75, 0.80)
        P.headers[i] = h
    end
    return h
end

function P.GetHeaderButton(i)
    local b = P.headerButtons[i]
    if not b then
        b = CreateFrame("Button", nil, P.content)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
        local hl = b:GetHighlightTexture()
        if hl then hl:SetAlpha(0.10) end
        b:SetScript("OnClick", function(self, button)
            if not self.gtKey then return end
            if button == "RightButton" then
                if ns.TransferMenu then P.ShowMenu(self, ns.TransferMenu(self.gtList, self.gtTab, self.gtTitle)) end
                return
            end
            ns.ToggleCollapsed(self.gtKey)
            ns.Relayout()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(ns.IsCollapsed(self.gtKey) and "Click to show this section" or "Click to fold this section", 1, 1, 1)
            if ns.TransferMenu then GameTooltip:AddLine("Right-click: move to bank / bags, or mail to a character", 0.7, 0.8, 1) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        P.headerButtons[i] = b
    end
    return b
end

function P.GetHeaderRule(i)
    local rule = P.headerRules[i]
    if not rule then
        rule = P.content:CreateTexture(nil, "ARTWORK")
        ns.UI.ThemeTexture(rule, "line", 0.8)
        rule:SetHeight(1)
        P.headerRules[i] = rule
    end
    return rule
end

function P.SmallButton(parent, text, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 20)
    b:SetNormalFontObject("GameFontNormalSmall")      -- plain button: no Blizzard template art on hover / press
    b:SetText(text)
    b:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    b:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local normal = b:GetNormalTexture()
    if normal then ns.UI.ThemeTexture(normal, "button") end
    local pushed = b:GetPushedTexture()
    if pushed then ns.UI.ThemeTexture(pushed, "active") end
    local highlight = b:GetHighlightTexture()
    if highlight then ns.UI.ThemeTexture(highlight, "hover", 0.14) end
    b:SetDisabledTexture("Interface\\Buttons\\WHITE8X8")
    local disabled = b:GetDisabledTexture()
    if disabled then ns.UI.ThemeTexture(disabled, "button", 0.5) end
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    return b
end

-- Small icon-only header button (tooltips are set by the caller).  Same look as the Sort / X buttons.
function P.IconButton(parent, texture, texCoord)
    local b = P.SmallButton(parent, "", 20)
    local icon = b:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("CENTER")
    icon:SetTexture(texture)
    if texCoord then icon:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4]) end
    b.icon = icon
    b:SetScript("OnDisable", function() icon:SetAlpha(0.4) end)
    b:SetScript("OnEnable", function() icon:SetAlpha(1) end)
    return b
end

-- Badge corner and priority choices.  They are set-once options, so they live in the Settings window (Settings.lua
-- builds its cycle buttons from these lists); only the three on/off toggles stay in the Opt menu.
P.BADGE_CORNERS = {
    { "TOPLEFT", "Top left" }, { "TOPRIGHT", "Top right" },
    { "BOTTOMLEFT", "Bottom left" }, { "BOTTOMRIGHT", "Bottom right" },
}
P.BADGE_PRIORITIES = {
    { "pawn,boe,ilvl", "Pawn > BoE > iLvl" }, { "pawn,ilvl,boe", "Pawn > iLvl > BoE" },
    { "boe,pawn,ilvl", "BoE > Pawn > iLvl" }, { "boe,ilvl,pawn", "BoE > iLvl > Pawn" },
    { "ilvl,pawn,boe", "iLvl > Pawn > BoE" }, { "ilvl,boe,pawn", "iLvl > BoE > Pawn" },
}

-- ---------------------------------------------------------------------------------------------- containers popup
-- One "Containers (3/5 shown)..." entry in the Opt menu opens this small window instead of one menu row per bag.
-- It stays open while you tick bags on and off, and follows the tab (Inv / Bank) and the character being viewed.
local cwin
local CONT_ROW, CONT_W = 20, 230

-- how many of the Inv / Bank containers are shown, and how many there are
function P.ContainerCounts(tab)
    local shown, total = 0, 0
    if tab ~= "bags" and tab ~= "bank" then return 0, 0 end
    for _, c in ipairs(ns.Source().containers or {}) do
        total = total + 1
        if not P.IsContainerHidden(tab, c.id) then shown = shown + 1 end
    end
    return shown, total
end

local function ContainerRow(i)
    local row = cwin.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, cwin)
    row:SetSize(CONT_W - 2 * ns.UI.PAD, CONT_ROW - 2)
    local box = row:CreateTexture(nil, "BORDER")
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 0, 0)
    box:SetColorTexture(0.34, 0.31, 0.24, 1)
    local inner = row:CreateTexture(nil, "ARTWORK")
    inner:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(0.06, 0.07, 0.09, 1)
    row.tick = row:CreateTexture(nil, "OVERLAY")
    row.tick:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    row.tick:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    row.tick:SetColorTexture(1, 0.82, 0, 1)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", box, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local hl = row:GetHighlightTexture()
    if hl then hl:SetAlpha(0.08) end
    row:SetScript("OnClick", function(self)
        if not self.gtTab then return end
        P.SetContainerHidden(self.gtTab, self.gtId, self.gtVisible)   -- visible now -> hide it, hidden now -> show it
        P.RefreshContainers()
        P.Layout()
    end)
    cwin.rows[i] = row
    return row
end

function P.RefreshContainers()
    if not (cwin and cwin:IsShown()) then return end
    local tab = ns.view.tab
    if tab ~= "bags" and tab ~= "bank" then cwin:Hide(); return end
    local list = ns.Source().containers or {}
    local PAD = ns.UI.PAD
    local y = -42
    for i, c in ipairs(list) do
        local row = ContainerRow(i)
        local visible = not P.IsContainerHidden(tab, c.id)
        row.gtTab, row.gtId, row.gtVisible = tab, c.id, visible
        row.text:SetText(c.label)
        row.tick:SetShown(visible)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", cwin, "TOPLEFT", PAD, y)
        row:Show()
        y = y - CONT_ROW
    end
    for i = #list + 1, #cwin.rows do cwin.rows[i]:Hide(); cwin.rows[i].gtTab = nil end
    local shown, total = P.ContainerCounts(tab)
    cwin.count:SetText(string.format("%d of %d shown", shown, total))
    cwin.showAll:ClearAllPoints()
    cwin.showAll:SetPoint("TOPLEFT", cwin, "TOPLEFT", PAD, y - 6)
    cwin.showAll:SetEnabled(shown < total)
    cwin:SetHeight(-y + 6 + 20 + PAD)
end

function P.ShowContainers()
    if not cwin then
        cwin = ns.UI.Window("GTBagContainersFrame", CONT_W, 120, "Containers")
        cwin.rows = {}
        cwin.count = ns.UI.Label(cwin, "")
        cwin.count:SetPoint("TOPRIGHT", cwin, "TOPRIGHT", -(ns.UI.PAD + 26), -14)
        cwin.showAll = ns.UI.Button(cwin, "Show all", CONT_W - 2 * ns.UI.PAD, 20)
        cwin.showAll:SetScript("OnClick", function()
            P.ShowAllContainers(ns.view.tab)
            P.RefreshContainers()
            P.Layout()
        end)
        cwin:SetScript("OnShow", function() P.RefreshContainers() end)
        cwin:Show()           -- a new window is already shown; OnShow was not hooked yet when it appeared
        P.RefreshContainers()
        return
    end
    if cwin:IsShown() then cwin:Hide() else cwin:Show() end
end
function P.HideContainers() if cwin then cwin:Hide() end end

-- ---------------------------------------------------------------------------------------------- small menu
-- entries: { text, checked, func, col }.  col = 2 puts an entry in a second column (entries keep their order inside
-- each column); a menu with no col = 2 entry is a single column.  A plain frame, so it behaves the same on every client.
function P.ShowMenu(anchor, entries, openRight)
    if not P.menu then
        P.menu = CreateFrame("Frame", "GTBagMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        P.menu:SetFrameStrata("DIALOG")
        P.menu:SetClampedToScreen(true)
        P.menu:EnableMouse(true)
        if P.menu.SetBackdrop then
            P.menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            ns.UI.ThemeFrame(P.menu)
        end
        P.menu.items = {}
        local catcher = CreateFrame("Button", nil, UIParent)       -- a click anywhere else closes the menu
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("DIALOG")
        catcher:SetFrameLevel(1)
        catcher:RegisterForClicks("AnyUp")
        catcher:SetScript("OnClick", function() P.menu:Hide() end)
        catcher:Hide()
        P.menu.catcher = catcher
        P.menu:SetFrameLevel(10)
        P.menu:SetScript("OnShow", function(self) self.catcher:Show() end)
        P.menu:SetScript("OnHide", function(self) self.catcher:Hide() end)
        P.menu:Hide()
        tinsert(UISpecialFrames, "GTBagMenu")
    end
    if P.menu:IsShown() and P.menu.anchor == anchor then P.menu:Hide(); return end
    P.menu.anchor = anchor
    local w = 150
    local ncols, rows = 1, { 0, 0 }
    for _, e in ipairs(entries) do if e.col == 2 then ncols = 2 end end
    local GAP = 6
    for i, e in ipairs(entries) do
        local b = P.menu.items[i]
        if not b then
            b = CreateFrame("Button", nil, P.menu)
            b:SetHeight(18)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 16, 0)
            b.check = b:CreateTexture(nil, "OVERLAY")
            b.check:SetSize(12, 12)
            b.check:SetPoint("LEFT", 2, 0)
            b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnClick", function(self, button)
                if button == "RightButton" and not self.allowRight then return end   -- right click only where an entry asks for it
                P.menu:Hide()
                if self.func then self.func(button) end
            end)
            P.menu.items[i] = b
        end
        b.func = e.func
        b.allowRight = e.rightClick and true or false
        b.text:SetText(e.text)
        b.check:SetShown(e.checked and true or false)
        b:SetEnabled(e.enabled ~= false)
        b.gtCol = (ncols == 2 and e.col == 2) and 2 or 1
        b.gtRow = rows[b.gtCol]
        rows[b.gtCol] = rows[b.gtCol] + 1
        b:Show()
        w = math.max(w, b.text:GetStringWidth() + 28)
    end
    for i = #entries + 1, #P.menu.items do P.menu.items[i]:Hide() end
    local itemW = w - 8
    for i = 1, #entries do
        local b = P.menu.items[i]
        b:SetWidth(itemW)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", P.menu, "TOPLEFT", 4 + (b.gtCol - 1) * (itemW + GAP), -(4 + b.gtRow * 18))
    end
    P.menu:SetSize(ncols * itemW + (ncols - 1) * GAP + 8, math.max(rows[1], rows[2]) * 18 + 8)
    P.menu:ClearAllPoints()
    if openRight then       -- menus on the left side of the window grow to the right, into the window
        P.menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    else
        P.menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    end
    P.menu:Show()
end

function P.CharMenu(anchor)
    if ns.MergeHardcoreTwins then pcall(ns.MergeHardcoreTwins) end      -- one character saved under two keys: show it once
    local entries, me, cur = {}, ns.MyKey(), ns.ViewKey()
    local keys, totalMoney, unknownMoney = ns.CharKeys(), 0, 0
    local moneyByKey = {}
    for _, key in ipairs(keys) do
        local rec = ns.Rec(key)
        local money = tonumber(rec and rec.money)
        if not (rec and rec.moneyT) then money = nil end
        if key == me and GetMoney then money = tonumber(GetMoney()) end
        moneyByKey[key] = money
        if money then totalMoney = totalMoney + money else unknownMoney = unknownMoney + 1 end
    end
    local totalLabel = unknownMoney > 0
        and string.format("Known gold (%d not saved)  %s", unknownMoney, ns.Money(totalMoney))
        or ("Total gold  " .. ns.Money(totalMoney))
    entries[#entries + 1] = { text = totalLabel, enabled = false }
    for _, key in ipairs(keys) do
        local rec = ns.Rec(key)
        local text = ns.ClassName(rec, rec.realm ~= (GetRealmName and GetRealmName()), true)
        local moneyText = moneyByKey[key] ~= nil and ns.Money(moneyByKey[key]) or "|cff888888gold not saved|r"
        text = text .. "  " .. moneyText
        if ns.MailMarker then text = text .. ns.MailMarker(rec) end
        entries[#entries + 1] = { text = text, checked = key == cur, func = function() ns.SetChar(key) end }
    end
    -- two explicit entries (no dependence on which mouse button was used): privacy mode scrambles every name and guild
    -- and hides every gold amount, the other shows the real names / nicknames / gold again
    local function SetScramble(on)
        if on then ns.scrambleSalt = ((ns.scrambleSalt or 0) + 1) % 1000000 end   -- new random names on every click
        ns.SetOpt("scrambleNames", on)
        P.Layout()
        if ns.Opt("scrambleNames") ~= on then return end
        local m = _G.GTBagMenu
        if m then m:Hide() end
        P.CharMenu(anchor)      -- reopen so the change is visible
    end
    local scrambled = ns.Opt("scrambleNames") and true or false
    entries[#entries + 1] = { text = "Privacy mode (hide names, gold, guilds)", checked = scrambled,
                              rightClick = true, func = function() SetScramble(true) end }
    entries[#entries + 1] = { text = "Show real info", checked = not scrambled,
                              rightClick = true, func = function() SetScramble(false) end }
    P.ShowMenu(anchor, entries)
end

-- nickname editor for the character selector (empty = no nickname)
function ns.EditNick(key)
    local rec = ns.Rec(key)
    if not (rec and StaticPopupDialogs and StaticPopup_Show) then return end
    if not StaticPopupDialogs["GTBAG_NICKNAME"] then
        local function Box(self) return self.editBox or self.EditBox or (self.GetName and _G[self:GetName() .. "EditBox"]) end
        local function Apply(self, data)
            local box = Box(self)
            local k = data or self.data
            if box and k and ns.SetNick(k, box:GetText()) and ns.Relayout then ns.Relayout() end
        end
        StaticPopupDialogs["GTBAG_NICKNAME"] = {
            text = "Nickname for %s (leave empty for none)",
            button1 = ACCEPT or OKAY or "OK",
            button2 = CANCEL or "Cancel",
            hasEditBox = 1,
            maxLetters = 24,
            OnShow = function(self, data)
                local box = Box(self)
                if box then box:SetText(ns.GetNick(data or self.data) or ""); box:HighlightText(); box:SetFocus() end
            end,
            OnAccept = function(self, data) Apply(self, data) end,
            EditBoxOnEnterPressed = function(box)
                local popup = box:GetParent()
                Apply(popup, popup.data)
                popup:Hide()
            end,
            EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
        }
    end
    -- always the real character name here (never the nickname or a scrambled text), so the dialog is unambiguous
    StaticPopup_Show("GTBAG_NICKNAME", ns.ClassName(rec, false, false), nil, key)
end
