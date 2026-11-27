-- Panel.lua : window build, open/toggle, events. Part of the Panel window (see PanelState.lua).
local _, ns = ...
local P = ns.panel

local layoutErrorShown = false
local function SafeLayout(tries)
    tries = tries or 0
    P.layoutNote = "not finished"
    local ok, err = xpcall(P.Layout, function(e) return tostring(e) end)
    if ok and P.layoutNote == "drawn" then
        if P.frame then P.frame.gtNeedsDraw = false end
        return
    end
    if not layoutErrorShown then
        layoutErrorShown = true
        print("|cffffd100GTBag|r: could not draw the window yet, trying again. "
            .. (ok and ("Reason: " .. P.layoutNote) or ("Error: " .. tostring(err))))
    end
    if tries < 4 and C_Timer and C_Timer.After then
        C_Timer.After(0.3, function()
            if P.frame and P.frame:IsShown() then SafeLayout(tries + 1) end
        end)
    end
end

-- ---------------------------------------------------------------------------------------------- window
-- Anchors the window by its top-left corner (keeping it exactly where it is on screen), so a new window size grows
-- right and down and the header never jumps.  Saved positions from older versions used another corner.
function P.PinTopLeft()
    local f = P.frame
    if not f then return end
    local left, top = f:GetLeft(), f:GetTop()
    if not (left and top) then return end
    local point = f:GetPoint()
    if point == "TOPLEFT" and f.gtTopLeftPinned then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    f.gtTopLeftPinned = true
end

local function Build()
    P.frame = CreateFrame("Frame", "GTBagFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    P.frame:SetSize(P.WindowWidth(ns.Opt("cols")), 300)
    P.frame:SetFrameStrata("MEDIUM")
    P.frame:SetClampedToScreen(true)
    P.frame:SetMovable(true)
    P.frame:EnableMouse(true)
    P.frame:RegisterForDrag("LeftButton")
    if P.frame.SetBackdrop then
        P.frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        ns.UI.ThemeFrame(P.frame, true)
    end
    local pos = GTBagDB and GTBagDB.pos
    if type(pos) == "table" and pos[1] and pos[2] then P.frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else P.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -200, 150) end
    P.frame:SetScript("OnDragStart", P.frame.StartMoving)
    P.frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.gtTopLeftPinned = false
        P.PinTopLeft()
        local p, _, rp, x, y = self:GetPoint()
        GTBagDB = GTBagDB or {}
        GTBagDB.pos = { p, rp, x, y }
    end)
    P.frame:SetScript("OnShow", function(self)
        self._gtFadeAlpha = 1
        self:SetAlpha(1)
        SafeLayout()
    end)
    P.frame:SetScript("OnHide", function()
        P.showHiddenSlots = false
        ns.HideAllButtons()
        wipe(P.shown)
        if P.menu then P.menu:Hide() end
        if P.HideContainers then P.HideContainers() end
        P.dragSource = nil
        if P.dragGhost then P.dragGhost:SetScript("OnUpdate", nil); P.dragGhost:Hide() end
        ns.view.char, ns.view.tab = nil, "bags"          -- the next B shows your own bags again
    end)
    -- the movement check runs 5 times a second, and the fade options are re-read twice a second (a settings change
    -- shows up within half a second); with the fade switched off nothing else is touched
    local fadeElapsed, optionAge = 0, 1
    local enabled, alpha = false, 0.35
    P.frame:HookScript("OnUpdate", function(self, elapsed)
        fadeElapsed = fadeElapsed + elapsed
        if fadeElapsed < 0.2 then return end
        optionAge = optionAge + fadeElapsed
        fadeElapsed = 0
        if optionAge >= 0.5 then
            optionAge = 0
            local ui = GatherTimesDB and GatherTimesDB._ui
            if type(ui) == "table" then
                enabled = ui.fadeMoving == true
                alpha = tonumber(ui.moveAlpha) or 0.35
            else
                enabled = ns.Opt("fadeMoving") and true or false
                alpha = ns.Opt("moveAlpha")
            end
        end
        if not enabled and (self._gtFadeAlpha or 1) == 1 then return end
        local faded = enabled and GetUnitSpeed and GetUnitSpeed("player") > 0
        if faded then
            local over = self.IsMouseOver and self:IsMouseOver() or (MouseIsOver and MouseIsOver(self))
            if over then faded = false end
        end
        alpha = faded and math.max(0.1, math.min(0.9, alpha)) or 1
        if self._gtFadeAlpha ~= alpha then
            self._gtFadeAlpha = alpha
            self:SetAlpha(alpha)
        end
    end)
    tinsert(UISpecialFrames, "GTBagFrame")

    local close = P.SmallButton(P.frame, "X", 20)
    close:SetPoint("TOPRIGHT", P.frame, "TOPRIGHT", -P.PAD, -8)
    close:SetScript("OnClick", function() P.frame:Hide() end)

    -- Hide / unhide slots and Pin / unpin items: one icon button each, same size as the Opt button, left of X
    local GAP = 6
    local hideBtn = P.IconButton(P.frame, "Interface\\Icons\\INV_Misc_Eye_01", { 0.08, 0.92, 0.08, 0.92 })
    hideBtn:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    hideBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hideBtn:SetScript("OnClick", function(_, mouseButton)
        if InCombatLockdown() then
            print("|cffffd100GTBag|r: slot actions are unavailable during combat.")
            return
        end
        if ns.view.tab ~= "bags" or not ns.ViewingSelf() then return end
        if mouseButton == "RightButton" then
            -- right click: show every hidden item (dimmed); right click again hides them again
            P.showHiddenSlots = not P.showHiddenSlots
            P.Layout()
            return
        end
        P.slotManageMode = not P.slotManageMode
        if P.slotManageMode then P.pinMode = false end
        P.Layout()
    end)
    hideBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(P.slotManageMode and "Stop hiding slots" or "Hide / unhide slots")
        GameTooltip:AddLine(P.slotManageMode and "Click x on a slot to hide it or + to show it again, then click here to finish."
            or "Shows an x on each slot to hide it (the item stays in your bags).", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine(P.showHiddenSlots and "Right-click: hide the hidden items again."
            or "Right-click: show all hidden items.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    hideBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.hideButton = hideBtn

    local pinBtn = P.IconButton(P.frame, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    pinBtn.icon:SetTexCoord(0, 0.25, 0, 0.25)
    pinBtn:SetPoint("RIGHT", hideBtn, "LEFT", -GAP, 0)
    pinBtn:SetScript("OnClick", function() ns.TogglePinMode() end)
    pinBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(P.pinMode and "Stop pinning" or "Pin / unpin items")
        GameTooltip:AddLine(P.pinMode and "Click * on a pinned item to unpin it or + to pin it, then click here to finish."
            or "Shows a + on each item to pin it (pinned items get a gold star).", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    pinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.pinButton = pinBtn

    -- window width: Settings > Columns, or hold Ctrl and turn the mouse wheel over the window (replaces the < and > buttons)
    P.frame:EnableMouseWheel(true)
    P.frame:SetScript("OnMouseWheel", function(_, delta)
        if not (IsControlKeyDown and IsControlKeyDown()) then return end
        local cols = ns.Opt("cols") + (delta > 0 and 1 or -1)
        ns.SetOpt("cols", math.max(P.MIN_COLS, math.min(P.MAX_COLS, cols)))
        P.Layout()
    end)

    local headerRule = P.frame:CreateTexture(nil, "ARTWORK")
    headerRule:SetPoint("TOPLEFT", P.frame, "TOPLEFT", P.PAD, -58)
    headerRule:SetPoint("TOPRIGHT", P.frame, "TOPRIGHT", -P.PAD, -58)
    headerRule:SetHeight(1)
    ns.UI.ThemeTexture(headerRule, "line", 0.8)

    -- View: icon button (the equipped-bags toggle moved into the Opt menu)
    local viewBtn = P.IconButton(P.frame, "Interface\\Icons\\INV_Misc_Bag_08", { 0.08, 0.92, 0.08, 0.92 })
    viewBtn:SetPoint("TOPRIGHT", P.frame, "TOPRIGHT", -P.PAD, -36)
    viewBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    viewBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if ns.ShowCatEditor then ns.ShowCatEditor() end    -- right click: custom categories
            return
        end
        if IsShiftKeyDown and IsShiftKeyDown() then          -- shift-click: next window style
            local cur, nextStyle = ns.Opt("style"), ns.STYLES[1][1]
            for i, s in ipairs(ns.STYLES) do
                if s[1] == cur then nextStyle = (ns.STYLES[i + 1] or ns.STYLES[1])[1] end
            end
            ns.SetOpt("style", nextStyle); P.Layout()
            return
        end
        ns.SetOpt("view", ns.Opt("view") == "bag" and "category" or "bag"); P.Layout()
    end)
    viewBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("View: " .. (ns.Opt("view") == "bag" and "bag slots" or "categories") .. " (click to switch)\nShift-click: window style (" .. tostring(ns.Opt("style")) .. ")\nRight-click: custom categories")
        GameTooltip:Show()
    end)
    viewBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.frame.viewBtn = viewBtn
    -- Sort + Merge: the header button defaults to Priority.
    -- Other rules remain available through Settings and /gtbag sort; they are not offered by this button.
    P.SORT_ICON_CHOICES = {
        { "priority", "Priority (Hearthstone, mounts, buffs, food, potions, gear)" },
    }
    local function SortAndMerge(rule)
        if not ns.ViewingSelf() or ns.view.tab ~= "bags" then
            print("|cffffd100GTBag|r: open your own bags to sort them.")
            return
        end
        if InCombatLockdown() or P.physicalSortRun then
            P.RunPhysicalSort(false)
            return
        end
        -- sort and merge: bag-slot view, all bags in one group, visual auto sort on (auto sort is turned off again
        -- when the physical sort completes); the sort moves the real items
        ns.SetOpt("view", "bag")
        ns.SetOpt("mergeBags", true)
        ns.SetOpt("autoSort", true)
        ns.SetSort(rule or "priority")
        P.RunPhysicalSort(false, true)
    end

    -- One menu for everything that used to sit in the Del / Slots / Badges button row
    local function OptMenu()
        local tab = ns.view.tab
        local E = {}
        local col = 1                       -- left column: Show; right column: Badges + Window
        local function Add(e) e.col = col; E[#E + 1] = e end

        if tab == "bags" or tab == "bank" then
            local shown, total = P.ContainerCounts(tab)
            Add({ text = string.format("Containers (%d/%d shown)...", shown, total), enabled = total > 0,
                func = function() P.ShowContainers() end })
        end

        Add({ text = "Tab row", checked = ns.Opt("toolbar"),
            func = function() ns.SetOpt("toolbar", not ns.Opt("toolbar")); P.Layout() end })
        Add({ text = "Settings...", func = function() if ns.ShowSettings then ns.ShowSettings() end end })
        return E
    end

    -- Sort: same look as the X and icon buttons, top left of the header
    local sortIconBtn = P.IconButton(P.frame, "Interface\\Buttons\\UI-RefreshButton")
    sortIconBtn:SetPoint("TOPLEFT", P.frame, "TOPLEFT", P.PAD, -36)       -- second row, left of the search box
    sortIconBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Sort")
        GameTooltip:Show()
    end)
    sortIconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- click: bank sorts with the saved order; bags sort + merge with Priority directly.
    sortIconBtn:SetScript("OnClick", function(self)
        if ns.view.tab == "bank" then P.RunPhysicalSort(true) return end
        SortAndMerge("priority")
    end)
    P.frame.sortIconBtn = sortIconBtn

    -- Opt (gear icon): left click opens the menu (bags, containers, badge toggles, window); right click opens the settings window
    local toolbarBtn = P.IconButton(P.frame, "Interface\\Icons\\Trade_Engineering", { 0.08, 0.92, 0.08, 0.92 })
    toolbarBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)               -- first row, right side: pin  eye  gear  X
    toolbarBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    toolbarBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if P.menu then P.menu:Hide() end
            if ns.ShowSettings then ns.ShowSettings() end
            return
        end
        P.ShowMenu(self, OptMenu(), true)
    end)
    toolbarBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Options")
        GameTooltip:AddLine("Equipped bags, containers, badge toggles, tab row", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: settings", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Ctrl + mouse wheel over the window: width", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    toolbarBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.frame.toolbarBtn = toolbarBtn
    hideBtn:ClearAllPoints(); hideBtn:SetPoint("RIGHT", toolbarBtn, "LEFT", -6, 0)

    P.search = CreateFrame("EditBox", nil, P.frame, "InputBoxTemplate")
    P.search:SetHeight(20)
    P.search:SetAutoFocus(false)
    P.search:SetPoint("LEFT", sortIconBtn, "RIGHT", 12, 0)
    P.search:SetPoint("RIGHT", viewBtn, "LEFT", -6, 0)
    P.search:SetTextInsets(0, 30, 0, 0)    -- room for the All button inside the box

    -- All: search every character (bags, bank, mail, guild bank)
    local findBtn = P.SmallButton(P.search, "All", 24)
    findBtn:SetHeight(16)
    findBtn:SetPoint("RIGHT", P.search, "RIGHT", -2, 0)
    findBtn:SetScript("OnClick", function() if ns.ShowFind then ns.ShowFind(P.search:GetText()) end end)
    findBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Search all characters (bags, bank, mail, guild bank)")
        GameTooltip:Show()
    end)
    findBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.frame.findBtn = findBtn
    P.hint = P.search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    P.hint:SetPoint("LEFT", 2, 0)
    P.hint:SetText("Search items  (herb & ilvl>5)")
    P.search:SetScript("OnTextChanged", function(self)
        P.query = ((self:GetText() or ""):lower():match("^%s*(.-)%s*$") or "")
        P.hint:SetShown(P.query == "")
        if ns.Opt("searchMode") == "filter" then P.Layout() else P.UpdateContent() end
    end)
    P.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    P.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- tabs and the character switcher
    P.tabBar = CreateFrame("Frame", nil, P.frame)
    P.tabBar:SetHeight(P.TOOL_FULL)
    P.tabBar:SetPoint("TOPLEFT", P.frame, "TOPLEFT", P.PAD, -(P.HEAD_H + 1))
    P.tabBar:SetPoint("TOPRIGHT", P.frame, "TOPRIGHT", -P.PAD, -(P.HEAD_H + 1))
    P.tabBar.bg = P.tabBar:CreateTexture(nil, "BACKGROUND")
    P.tabBar.bg:SetAllPoints()
    ns.UI.ThemeTexture(P.tabBar.bg, "field")
    P.tabBar:SetScript("OnSizeChanged", function() P.LayoutTabs() end)
    for _, t in ipairs(P.TABS) do
        local b = P.SmallButton(P.frame, t[2], t[3])
        b:SetScript("OnClick", function() ns.SetTab(t[1]) end)
        P.tabButtons[t[1]] = b
    end
    local charBtn = P.SmallButton(P.frame, "", 100)
    charBtn:SetPoint("TOPLEFT", P.frame, "TOPLEFT", P.PAD, -8)       -- first row, left
    charBtn:SetScript("OnClick", function(self) P.CharMenu(self) end)
    charBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Switch character (saved bags, bank, guild bank and mail)")
        GameTooltip:Show()
    end)
    charBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.frame.charBtn = charBtn
    -- small chevron on the right of the character name
    local chev = charBtn:CreateTexture(nil, "OVERLAY")
    chev:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    chev:SetSize(10, 10)
    chev:SetRotation(-math.pi / 2)
    chev:SetPoint("RIGHT", charBtn, "RIGHT", -5, 0)
    chev:SetVertexColor(0.55, 0.58, 0.64)
    charBtn.chevron = chev
    if charBtn:GetFontString() then
        charBtn:GetFontString():ClearAllPoints()
        charBtn:GetFontString():SetPoint("LEFT", charBtn, "LEFT", 8, 0)
        charBtn:GetFontString():SetPoint("RIGHT", charBtn, "RIGHT", -18, 0)
        charBtn:GetFontString():SetJustifyH("LEFT")
    end

    P.BuildSlotRow()
    P.BuildGuildRow()

    P.content = CreateFrame("Frame", nil, P.frame)
    P.content:SetPoint("TOPLEFT", P.PAD, -(P.HEAD_H + P.TOOL_FULL))
    P.content:SetSize(380, 40)

    P.frame.notice = P.frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    P.frame.notice:SetJustifyH("CENTER")

    P.frame.money = P.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    P.frame.money:SetPoint("BOTTOMLEFT", P.PAD, 8)
    -- hover the money: what the items in this window are worth, by category (see P.ShowValueTooltip)
    P.frame.moneyHit = CreateFrame("Frame", nil, P.frame)
    P.frame.moneyHit:SetPoint("TOPLEFT", P.frame.money, "TOPLEFT", -2, 3)
    P.frame.moneyHit:SetPoint("BOTTOMRIGHT", P.frame.money, "BOTTOMRIGHT", 2, -3)
    P.frame.moneyHit:EnableMouse(true)
    P.frame.moneyHit:SetScript("OnEnter", function(self) P.ShowValueTooltip(self) end)
    P.frame.moneyHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.frame.free = P.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    P.frame.free:SetPoint("BOTTOMRIGHT", P.frame, "BOTTOMRIGHT", -P.PAD, 8)   -- same line as the money
    P.frame.freeBar = CreateFrame("Frame", nil, P.frame)
    P.frame.freeBar:SetSize(56, 5)
    P.frame.freeBar:SetPoint("RIGHT", P.frame.free, "LEFT", -8, 0)
    P.frame.freeBar.bg = P.frame.freeBar:CreateTexture(nil, "BACKGROUND")
    P.frame.freeBar.bg:SetAllPoints()
    ns.UI.ThemeTexture(P.frame.freeBar.bg, "line")
    P.frame.freeBar.fill = P.frame.freeBar:CreateTexture(nil, "ARTWORK")
    P.frame.freeBar.fill:SetPoint("TOPLEFT")
    P.frame.freeBar.fill:SetPoint("BOTTOMLEFT")
    P.frame.freeBar.fill:SetWidth(1)
    P.frame.ammo = P.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    P.frame.ammo:SetPoint("BOTTOM", P.frame, "BOTTOM", 0, 8)    -- total arrows / bullets of hidden ammo bags
    P.frame.footerRule = P.frame:CreateTexture(nil, "ARTWORK")
    P.frame.footerRule:SetPoint("BOTTOMLEFT", P.frame, "BOTTOMLEFT", P.PAD, P.FOOT_H - 4)
    P.frame.footerRule:SetPoint("BOTTOMRIGHT", P.frame, "BOTTOMRIGHT", -P.PAD, P.FOOT_H - 4)
    P.frame.footerRule:SetHeight(1)
    ns.UI.ThemeTexture(P.frame.footerRule, "line")

    -- guild money
    local function Popup(which)
        if StaticPopupDialogs and StaticPopupDialogs[which] then StaticPopup_Show(which) end
    end
    P.frame.deposit = P.SmallButton(P.frame, "Deposit", 56)
    P.frame.deposit:SetPoint("BOTTOM", P.frame, "BOTTOM", -30, 4)
    P.frame.deposit:SetScript("OnClick", function() Popup("GUILDBANK_DEPOSIT") end)
    P.frame.withdraw = P.SmallButton(P.frame, "Withdraw", 60)
    P.frame.withdraw:SetPoint("LEFT", P.frame.deposit, "RIGHT", 2, 0)
    P.frame.withdraw:SetScript("OnClick", function() Popup("GUILDBANK_WITHDRAW") end)
    P.frame.deposit:Hide(); P.frame.withdraw:Hide()

    -- Safety net: on the first opening after a reload the window's show event did not always reach the drawing code
    -- (/gtbag draw said "never ran").  Whenever the window is on screen and has not been drawn since it was shown,
    -- it is drawn on the next frame.
    P.frame.gtNeedsDraw = true
    P.frame:HookScript("OnShow", function(self) self.gtNeedsDraw = true end)
    P.frame:HookScript("OnUpdate", function(self)
        if self.gtNeedsDraw then
            self.gtNeedsDraw = false
            SafeLayout()
        end
    end)
end

local function CombatBlocked()
    return InCombatLockdown() and P.frame and P.frame.IsProtected and P.frame:IsProtected()
end
-- turns Pin items mode on or off (opens the window first when it is closed)
function ns.TogglePinMode()
    if InCombatLockdown() then
        print("|cffffd100GTBag|r: pinning is unavailable during combat.")
        return
    end
    if not (P.frame and P.frame:IsShown()) then ns.Open() end
    if not (P.frame and P.frame:IsShown()) then return end
    P.pinMode = not P.pinMode
    if P.pinMode then
        P.slotManageMode = false
        if ns.view.tab ~= "bags" and ns.view.tab ~= "bank" then ns.view.tab = "bags" end
        print("|cffffd100GTBag|r: pin items: click + on an item to pin it (a gold star appears). Click the star button again to finish.")
    end
    P.Layout()
end

-- The first time the window is drawn after a reload it could come up empty (no slots) and only the second opening was
-- right.  The drawing now runs through SafeLayout (it catches an error, prints it once and tries again a moment later),
-- and the first opening is also drawn a second time shortly after.
local firstOpenPending = true
function ns.Open()
    if not P.frame then Build() end
    if not P.frame:IsShown() then
        if CombatBlocked() then
            print("|cffffd100GTBag|r: the window cannot be opened during combat while item actions are on (/gtbag actions off).")
            return
        end
        P.frame:Show()
        if firstOpenPending then
            firstOpenPending = false
            C_Timer.After(0.05, function() if P.frame and P.frame:IsShown() then SafeLayout() end end)
            C_Timer.After(0.4, function() if P.frame and P.frame:IsShown() then SafeLayout() end end)
        end
    end
end
function ns.Toggle()
    if P.frame and P.frame:IsShown() then
        if CombatBlocked() then return end
        P.frame:Hide()
    else
        ns.Open()
    end
end
function ns.Relayout() P.Layout() end

-- /gtbag draw : says what state the window is in, draws it once more and reports the result
function ns.DebugDraw()
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local say = function(t) print("|cffffd100GTBag|r: " .. t) end
    say("version " .. tostring(meta and meta("GTBag", "Version") or "?") .. ", window "
        .. (P.frame and ("built, shown=" .. tostring(P.frame:IsShown()) .. ", visible=" .. tostring(P.frame:IsVisible())
            .. ", height=" .. math.floor(P.frame:GetHeight() or 0)) or "not built yet")
        .. ", combat=" .. tostring(InCombatLockdown()))
    say("last drawing pass: " .. P.layoutNote .. " (finished " .. P.layoutCount .. " time(s))")
    if not P.frame then return end
    P.layoutNote = "not finished"
    local ok, err = xpcall(P.Layout, function(e) return tostring(e) end)
    say("drawing now: " .. (ok and P.layoutNote or ("error: " .. tostring(err))) .. ", height=" .. math.floor(P.frame:GetHeight() or 0))
end

-- event-driven refreshes are coalesced: a burst of events (item data loading, bag updates) makes one layout pass
local layoutQueued = false
local pendingSig
function ns.LayoutSoon(sig)
    if sig then pendingSig = sig end
    if layoutQueued then return end
    layoutQueued = true
    C_Timer.After(0, function()
        layoutQueued = false
        local s = pendingSig
        pendingSig = nil
        local before = P.layoutCount
        P.Layout()
        if P.layoutCount ~= before then P.lastSig = s end   -- a skipped pass (combat) must not count as drawn
    end)
end

-- Cheap fingerprint of which item sits in which slot (ids only, no tables created).  A bag update that only changes
-- stack counts, cooldowns or lock state leaves it unchanged, and then the buttons are refreshed in place instead of
-- rebuilding the whole window.
local function ContentSignature()
    local tab = ns.view.tab
    local ids = tab == "bags" and ns.BAGS or (tab == "bank" and ns.BANK_IDS) or nil
    if type(ids) ~= "table" then return nil end
    local sortRule = ns.Opt("sort")
    if sortRule == "count" or sortRule == "value" then return nil end     -- these orders depend on stack sizes
    local h = 7
    for _, bag in ipairs(ids) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" and n > 0 then
            h = (h * 31 + bag + 1000003 * n) % 2147483629
            for slot = 1, n do
                local id = ns.SlotItemID(bag, slot)
                if id then h = (h * 31 + id + slot) % 2147483629 end
            end
        end
    end
    return h
end
function ns.SetSort(rule)
    ns.SetOpt("sort", rule)
    P.ResetManualOrder()
    P.Layout()
end
-- the default window: category view, 10 columns, stacked, empty slots shown, tab row hidden, lower right.  Only layout
-- options are reset; pins, categories, hidden items, sort order and the other settings stay.
function ns.ApplyDefaultLayout()
    for _, key in ipairs({ "view", "cols", "scale", "style", "blocks", "mergeBags", "autoSort", "ignoreEmpty", "slotsRow", "toolbar" }) do
        ns.SetOpt(key, nil)
    end
    ns.ResetPosition()
    if P.frame and P.frame:IsShown() then P.Layout() end
end

function ns.ResetPosition()
    if GTBagDB then GTBagDB.pos = nil end
    if P.frame then
        P.frame:ClearAllPoints(); P.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -200, 150)
        P.frame.gtTopLeftPinned = false
    end
end

-- show another character's saved bags / bank / mail / guild bank (nil or your own key = back to yourself)
function ns.SetChar(key)
    ns.view.char = (key and key ~= ns.MyKey()) and key or nil
    ns.view.gtab = 0
    P.Layout()
end
-- puts text into the window's search box (opens the window first)
function ns.SetSearch(text)
    ns.Open()
    if P.search then P.search:SetText(tostring(text or "")) end
end
function ns.SetTab(tab)
    ns.view.tab = tab
    ns.view.gtab = 0
    P.Layout()
end

-- ---------------------------------------------------------------------------------------------- events
local contentQueued = false
local itemInfoQueued = false
-- events after which the low-space and low-ammo check can have a different answer
local sampleEvents = { PLAYER_ENTERING_WORLD = true, BAG_UPDATE_DELAYED = true, PLAYER_EQUIPMENT_CHANGED = true }
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED", "PLAYER_MONEY",
                     "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "BANKFRAME_CLOSED",
                     "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED",
                     "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    -- Settings > "Close the window when combat starts": the window closes the moment combat begins (it does not reopen by itself)
    if event == "PLAYER_REGEN_DISABLED" and ns.Opt("hideInCombat") and P.frame and P.frame:IsShown() then
        P.frame:Hide()
        P.closedByCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" and P.closedByCombat then
        -- Settings > "Reopen the window after combat" (needs the close-in-combat setting)
        P.closedByCombat = false
        if ns.Opt("hideInCombat") and ns.Opt("reopenAfterCombat") and not (P.frame and P.frame:IsShown()) then
            ns.Open()
        end
    end
    if event == "PLAYER_REGEN_DISABLED" and P.physicalSortRun then
        P.StopPhysicalSort("physical sorting stopped because combat started.")
        return
    end
    if event == "BANKFRAME_CLOSED" and P.physicalSortRun and P.physicalSortRun.bank then
        P.StopPhysicalSort("bank sorting stopped because the bank closed.")
        return
    end
    if P.physicalSortRun then
        local run = P.physicalSortRun
        if run.awaiting and (event == "BAG_UPDATE_DELAYED" or event:find("^PLAYERBANK")) then
            run.awaiting = false
            run.timeoutToken = run.timeoutToken + 1
            P.QueuePhysicalSortStep(0.05)
        elseif not run.awaiting and event == "ITEM_LOCK_CHANGED" then
            P.QueuePhysicalSortStep(0.05)
        end
    end
    local open = P.frame and P.frame:IsShown()
    if not open then
        -- cooldown, item lock and item-info events can fire many times a second: they never change free slots or ammo
        if sampleEvents[event] or event:find("^PLAYERBANK") then ns.Sample() end
        return
    end
    local tab = ns.view.tab
    local liveSlots = ns.ViewingSelf() and (tab == "bags" or (tab == "bank" and ns.atBank))
    if event == "BAG_UPDATE_COOLDOWN" or event == "ITEM_LOCK_CHANGED" then
        -- these can fire many times a second (every potion, every global cooldown): refresh the slots once per 0.1 s
        if liveSlots and not contentQueued then
            contentQueued = true
            C_Timer.After(0.1, function()
                contentQueued = false
                if P.frame and P.frame:IsShown() then P.UpdateContent() end
            end)
        end
    elseif event == "PLAYER_MONEY" then P.UpdateFooter()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- arrives in bursts (every item another addon asks for): one redraw per second instead of one per frame
        if not itemInfoQueued then
            itemInfoQueued = true
            C_Timer.After(1, function()
                itemInfoQueued = false
                if P.frame and P.frame:IsShown() then ns.LayoutSoon() end
            end)
        end
    elseif event == "BAG_UPDATE_DELAYED" or event:find("^PLAYERBANK") then
        ns.Sample()
        if liveSlots then
            if not (P.frame and P.frame:IsShown()) then return end
            local sig = ContentSignature()
            if sig and sig == P.lastSig and not layoutQueued and ns.Opt("style") ~= "list" then
                P.UpdateContent()       -- same items in the same slots: counts / locks only
                P.UpdateFooter()
            else
                ns.LayoutSoon(sig)
            end
        else P.UpdateFooter() end
    else ns.LayoutSoon() end
end)
