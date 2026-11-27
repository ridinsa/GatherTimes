-- PanelRows.lua : bag, guild, toolbar, footer and content rows. Part of the Panel window (see PanelState.lua).
local _, ns = ...
local P = ns.panel

-- ---------------------------------------------------------------------------------------------- bag slot row
function P.UpdateSlotRow()
    if not P.frame then return end
    for i, bag in ipairs(ns.BAGS) do
        local b = P.slotButtons[i]
        if b then
            local tex
            if bag == 0 then tex = "Interface\\Buttons\\Button-Backpack-Up"
            else
                local inv = ns.ToInventoryID and ns.ToInventoryID(bag)
                tex = inv and GetInventoryItemTexture("player", inv) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
            end
            b.icon:SetTexture(tex)
        end
    end
end

-- header mode buttons (built in Panel.lua): each is ONE button whose icon changes with its state.
--   pin:  gold star = "Pin items" is off, red cross = pin mode is on (click to stop / unpin)
--   hide: open eye = "Hide slots" is off, closed eye = hide mode is on (click to stop / unhide)
local PIN_STAR = { 0, 0.25, 0, 0.25 }
local PIN_CROSS = { 0.5, 0.75, 0.25, 0.5 }
function P.UpdateModeButtons()
    local tab = ns.view.tab
    local canEdit = ns.ViewingSelf() and not InCombatLockdown()
    local pb, hb = P.pinButton, P.hideButton
    if pb then
        local on = P.pinMode and true or false
        pb.icon:SetTexCoord(unpack(on and PIN_CROSS or PIN_STAR))
        if on then pb:LockHighlight() else pb:UnlockHighlight() end
        pb:SetEnabled(canEdit and (tab == "bags" or tab == "bank"))
    end
    if hb then
        local on = (P.slotManageMode or P.showHiddenSlots) and true or false
        hb.icon:SetTexture(on and "Interface\\Icons\\INV_Misc_Eye_02" or "Interface\\Icons\\INV_Misc_Eye_01")
        if on then hb:LockHighlight() else hb:UnlockHighlight() end
        hb:SetEnabled(canEdit and tab == "bags")
    end
end
P.UpdatePinButton = P.UpdateModeButtons

function P.BuildSlotRow()
    local row = CreateFrame("Frame", nil, P.frame)
    row:SetHeight(P.SUB_H - 4)
    row:SetPoint("TOPLEFT", P.PAD, -(P.HEAD_H + P.TOOL_FULL))
    row:SetPoint("TOPRIGHT", -P.PAD, -(P.HEAD_H + P.TOOL_FULL))
    P.frame.slotRow = row
    local prev
    for i, bag in ipairs(ns.BAGS) do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(28, 28)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", 0, 0) end
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local edge = b:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints(); edge:SetColorTexture(0.25, 0.25, 0.25, 1)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local inv = bag > 0 and ns.ToInventoryID and ns.ToInventoryID(bag)
            if inv and GetInventoryItemTexture("player", inv) then GameTooltip:SetInventoryItem("player", inv)
            else GameTooltip:SetText(bag == 0 and BACKPACK_TOOLTIP or "Empty bag slot") end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        P.slotButtons[i] = b
        prev = b
    end
    row:SetShown(false)
end

-- ---------------------------------------------------------------------------------------------- guild tab row
function P.BuildGuildRow()
    local row = CreateFrame("Frame", nil, P.frame)
    row:SetHeight(P.SUB_H - 4)
    row:SetPoint("TOPLEFT", P.PAD, -(P.HEAD_H + P.TOOL_FULL))
    row:SetPoint("TOPRIGHT", -P.PAD, -(P.HEAD_H + P.TOOL_FULL))
    row.btns = {}
    for i = 0, ns.MAX_TABS do
        local b = P.SmallButton(row, i == 0 and "All" or tostring(i), i == 0 and 34 or 28)
        if i == 0 then b:SetPoint("LEFT", 0, 0) else b:SetPoint("LEFT", row.btns[i - 1], "RIGHT", 2, 0) end
        b:SetScript("OnClick", function() ns.GuildSelect(i) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.tabName or "All tabs")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.btns[i] = b
    end
    row:Hide()
    P.frame.guildRow = row
end

function P.UpdateGuildRow(src)
    local g = src.guild
    for i = 0, ns.MAX_TABS do
        local b = P.frame.guildRow.btns[i]
        local td = g and g.tabs[i]
        b.tabName = i == 0 and "All tabs" or (td and td.name) or ("Tab " .. i)
        b:SetShown(i == 0 or (g ~= nil and i <= (g.numTabs or 0)))
        b:SetEnabled(i == 0 or (td ~= nil and not td.noView))
        if ns.view.gtab == i then b:LockHighlight() else b:UnlockHighlight() end
    end
end

-- ---------------------------------------------------------------------------------------------- chrome (tabs, buttons, borders)
-- The tabs share the bar's width equally; the active one is amber on a lighter segment.
function P.LayoutTabs()
    local bar = P.tabBar
    if not bar then return end
    local show = ns.Opt("toolbar") and true or false
    bar:SetShown(show)
    if not show then return end
    local list = {}
    for _, t in ipairs(P.TABS) do
        local b = P.tabButtons[t[1]]
        if t[1] ~= "guild" or P.tabHasGuild then list[#list + 1] = { t = t, b = b } else b:Hide() end
    end
    local inner = (bar:GetWidth() or 0) - 6
    if inner <= 0 or #list == 0 then return end
    local gap = 2
    local w = (inner - gap * (#list - 1)) / #list
    for i, e in ipairs(list) do
        local b = e.b
        b:SetParent(bar)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", 3 + (i - 1) * (w + gap), -3)
        b:SetSize(w, P.TOOL_FULL - 6)
        b:Show()
        local active = e.t[1] == P.tabCurrent
        local fs = b:GetFontString()
        if fs then
            if active then fs:SetTextColor(0.94, 0.71, 0.29) else fs:SetTextColor(0.72, 0.75, 0.80) end
        end
        local normal = b:GetNormalTexture()
        if normal then
            normal:SetAlpha(active and 1 or 0)
            ns.UI.ThemeTexture(normal, active and "active" or "button")
        end
        b.gtActive = active
    end
end

function P.UpdateChrome()
    local rec = ns.Rec(ns.ViewKey())
    local hasGuild = rec and rec.guild ~= nil
    if ns.view.tab == "auctions" or (ns.view.tab == "guild" and not hasGuild) then ns.view.tab = "bags" end
    local tab, mine = ns.view.tab, ns.ViewingSelf()

    -- tab row: Inv, Bank, Mail, Guild as one segmented bar (see P.LayoutTabs)
    P.tabHasGuild = hasGuild
    P.tabCurrent = tab
    P.LayoutTabs()

    P.frame.charBtn:SetText(ns.ClassName(rec, false, true))
    P.frame.charBtn:SetWidth(math.min(150, math.max(80, P.frame.charBtn:GetFontString():GetStringWidth() + 34)))

    P.frame.sortIconBtn:SetEnabled(mine and not InCombatLockdown()
        and not P.physicalSortRun and (tab == "bags" or (tab == "bank" and ns.atBank and true or false)))

    local liveGuild = tab == "guild" and mine and ns.atGuild
    P.frame.deposit:SetShown(liveGuild and true or false)
    P.frame.withdraw:SetShown(liveGuild and true or false)

    if P.frame.SetBackdropBorderColor then
        P.frame.gtViewingOther = not mine
        ns.UI.ApplyFrameTheme(P.frame)
    end
    if P.RefreshContainers then P.RefreshContainers() end    -- the containers popup follows the tab and character
end

-- ---------------------------------------------------------------------------------------------- footer
-- tooltip on the money: the value of every item in the window (every tab and character), split by category.
-- Price per item = ns.UnitValue: the GatherTimes auction scan when it is installed and higher than the vendor price.
function P.ShowValueTooltip(anchor)
    local src = ns.Source()
    local totals, order, grand, stacks = {}, {}, 0, 0
    ns.EachSlot(src, function(info)
        if info and info.id then
            local count = tonumber(info.count) or 1
            local unit = ns.UnitValue(info.id, info.link) or 0
            local label = ns.CatLabel(ns.Category(info)) or "Other"
            local t = totals[label]
            if not t then
                t = { label = label, value = 0, items = 0 }
                totals[label] = t
                order[#order + 1] = t
            end
            t.items = t.items + count
            t.value = t.value + unit * count
            grand = grand + unit * count
            stacks = stacks + 1
        end
    end)
    table.sort(order, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.label < b.label
    end)
    GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
    GameTooltip:SetText("Value of the items in this window")
    if stacks == 0 then
        GameTooltip:AddLine("No items.", 0.7, 0.7, 0.7)
    else
        GameTooltip:AddDoubleLine("Total", ns.Money(grand), 1, 1, 1, 1, 1, 1)
        local shown = 0
        for _, t in ipairs(order) do
            if t.value > 0 and shown < 10 then
                shown = shown + 1
                GameTooltip:AddDoubleLine(t.label .. "  x" .. t.items, ns.Money(t.value), 0.8, 0.8, 0.8, 1, 1, 1)
            end
        end
        if shown == 0 then GameTooltip:AddLine("None of these items has a price.", 0.7, 0.7, 0.7) end
        local gt = _G.GatherTimesAddon
        GameTooltip:AddLine((gt and gt.ScanPrice)
            and "Prices: GatherTimes auction scan when higher than the vendor price, else vendor."
            or "Prices: vendor sell price.", 0.55, 0.55, 0.55, true)
    end
    GameTooltip:Show()
end

function P.UpdateFooter()
    if not P.frame then return end
    local src = ns.Source()
    local tab = ns.view.tab

    local money
    if tab == "guild" then money = "Guild  " .. ns.MoneyDots(src.money or 0)
    elseif tab == "mail" and (src.mailGold or 0) > 0 then money = "In mail  " .. ns.MoneyDots(src.mailGold)
    elseif src.self and GetMoney then money = ns.MoneyDots(GetMoney())
    else money = ns.MoneyDots(src.money or 0) end
    P.frame.money:SetText(money)

    local free, total, count = 0, 0, 0
    ns.EachSlot(src, function(info)
        total = total + 1
        if info then
            count = count + 1
        else
            free = free + 1
        end
    end)
    if src.items then total = 0 end

    local text = ""
    if src.items then
        text = string.format("%d item%s", count, count == 1 and "" or "s")
        if src.mails and src.mails > 0 then text = text .. string.format(" in %d mail%s", src.mails, src.mails == 1 and "" or "s") end
        -- the game says new mail is waiting: this saved snapshot is older than the mailbox
        if tab == "mail" and ns.Opt("mailWatch") and src.self and not ns.atMail and ns.MailStale and ns.MailStale() then
            text = "|cffff8040new mail - open a mailbox|r  " .. text
        end
    else
        local r = total > 0 and (total - free) / total or 0
        local col = r < 0.7 and "ffffffff" or (r < 0.9 and "ffffd100" or "ffff4040")
        text = total > 0 and string.format("|c%s%d / %d|r free", col, free, total) or ""   -- nothing to count yet
    end
    P.frame.free:SetText(text)

    -- slim fill bar left of the free-slot text (amber, then orange, then red as the bags fill up)
    local bar = P.frame.freeBar
    if bar then
        if not src.items and total > 0 then
            local r = (total - free) / total
            local c = r < 0.7 and { 0.94, 0.71, 0.29 } or (r < 0.9 and { 1, 0.55, 0.2 } or { 1, 0.42, 0.37 })
            bar.fill:SetColorTexture(c[1], c[2], c[3], 1)
            bar.fill:SetWidth(math.max(1, math.floor(bar:GetWidth() * r + 0.5)))
            bar:Show()
        else
            bar:Hide()
        end
    end

    -- arrows / bullets sitting in hidden quivers and ammo pouches: show the total with an icon
    local ammoText = ""
    if tab == "bags" and not src.items then
        local arrows, bullets, hiddenAmmo = 0, 0, false
        for _, c in ipairs(src.containers) do
            if c.isQuiverBag and P.IsContainerHidden(tab, c.id) then
                hiddenAmmo = true
                for slot = 1, c.n do
                    local info = c.get(slot)
                    if info and info.id then
                        local m = ns.ItemMeta(info.id)
                        if m and m.class == 6 then
                            local n = tonumber(info.count) or 1
                            if m.sub == 2 then arrows = arrows + n elseif m.sub == 3 then bullets = bullets + n end
                        end
                    end
                end
            end
        end
        -- low ammo: also shown (in red) when the bag is not hidden, using what you carry in total
        local limit = ns.Opt("warnAmmo") or 0
        local total = (src.self and ns.AmmoCounts) and ns.AmmoCounts() or nil
        local function Part(icon, shownN, totalN)
            local n = hiddenAmmo and shownN or totalN
            if not n then return "" end
            local low = limit > 0 and totalN and totalN > 0 and totalN <= limit
            if not (hiddenAmmo and shownN > 0) and not low then return "" end
            local col = low and "|cffff4040" or "|cffffffff"
            return "|TInterface\\Icons\\" .. icon .. ":14:14|t " .. col .. n .. "|r"
        end
        local a = Part("INV_Ammo_Arrow_02", arrows, total and total.arrows)
        local b = Part("INV_Ammo_Bullet_01", bullets, total and total.bullets)
        if hiddenAmmo and a == "" and b == "" then a = "|TInterface\\Icons\\INV_Ammo_Arrow_02:14:14|t 0" end
        ammoText = a .. ((a ~= "" and b ~= "") and "   " or "") .. b
    end
    P.frame.ammo:SetText(ammoText)
end

-- ---------------------------------------------------------------------------------------------- content / layout
function P.UpdateContent(fresh)
    local displayQuery = ns.view.tab == "bags" and P.slotManageMode and not InCombatLockdown() and "" or P.query
    for _, e in ipairs(P.shown) do
        if e.liveSlot and not fresh then e.info = ns.ItemInfo(e.bag, e.slot) end
        ns.UpdateButton(e.button, e.bag, e.slot, e.info, displayQuery)
    end
end

function P.Place(b, x, y)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", P.content, "TOPLEFT", x, -y)
    b:Show()
end

function P.LiveParent(bag)
    local parent = P.liveParents[bag]
    if not parent then
        parent = CreateFrame("Frame", nil, P.content)
        parent:SetAllPoints(P.content)
        P.liveParents[bag] = parent
    end
    parent:SetID(bag)
    return parent
end

-- Sidebar style: a list of the sections on the left; click one to show only that section (All shows everything).
-- ns.view.side holds the chosen section key (nil = All).  Plain buttons, so they are only touched out of combat.
P.RAIL_W, P.RAIL_GAP, P.RAIL_ROW = 118, 8, 20
local railButtons = {}
function P.HideRail()
    for _, b in ipairs(railButtons) do b:Hide() end
end
function P.UpdateRail(items, selected, top)
    for i, item in ipairs(items) do
        local b = railButtons[i]
        if not b then
            b = CreateFrame("Button", nil, P.frame)
            b:SetSize(P.RAIL_W, P.RAIL_ROW - 2)
            b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
            local hl = b:GetHighlightTexture()
            if hl then hl:SetAlpha(0.1) end
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints()
            b.bg:SetColorTexture(0.34, 0.31, 0.24, 0.35)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 6, 0)
            b.text:SetPoint("RIGHT", -4, 0)
            b.text:SetJustifyH("LEFT")
            b.text:SetWordWrap(false)
            b:SetScript("OnClick", function(self)
                if InCombatLockdown() and P.frame:IsProtected() then
                    print("|cffffd100GTBag|r: the category list cannot change during combat while item actions are on.")
                    return
                end
                ns.view.side = self.gtKey
                P.Layout()
            end)
            railButtons[i] = b
        end
        local on = item.key == selected
        b.gtKey = item.key
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", P.frame, "TOPLEFT", P.PAD, -(top + (i - 1) * P.RAIL_ROW))
        b.text:SetText(item.text)
        if on then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(0.85, 0.85, 0.85) end
        b.bg:SetShown(on)
        b:Show()
    end
    for i = #items + 1, #railButtons do railButtons[i]:Hide() end
end

-- called when privacy mode is switched: the footer tag and the amounts follow at once
function ns.RefreshPrivacyTag() if P.frame then P.UpdateFooter() end end
