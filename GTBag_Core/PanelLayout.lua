-- PanelLayout.lua : Layout: places every item button in the window. Part of the Panel window (see PanelState.lua).
local _, ns = ...
local P = ns.panel

P.Layout = function()
    P.lastSig = nil          -- any redraw invalidates the bag-event fingerprint (see Panel.lua)
    if not (P.frame and P.frame:IsShown()) then P.layoutNote = "skipped: the window is not shown"; return end
    -- live item buttons are Blizzard's secure templates: they cannot be re-parented, re-numbered or moved in combat.
    -- Skip the pass; PLAYER_REGEN_ENABLED refreshes the window afterwards.
    -- A window that is already showing live buttons is left alone.  A window opened during combat has no live
    -- buttons, so it is drawn with plain display buttons instead (items show, clicks are off until combat ends).
    local combatStatic = false
    if ns.Opt("liveActions") and InCombatLockdown() then
        if ns.AnyLiveShown() then P.layoutNote = "skipped: in combat with live buttons showing"; return end
        combatStatic = true
    end
    -- frames tied to a secure button cannot be resized or re-anchored in combat
    local geoLocked = InCombatLockdown()
        and ((P.frame.IsProtected and P.frame:IsProtected()) or (P.content.IsProtected and P.content:IsProtected()))
        and true or false
    if not geoLocked then P.frame:SetScale(tonumber(ns.Opt("scale")) or 1) end
    local cols = ns.Opt("cols")
    local view = ns.Opt("view")
    -- the window style is applied out of combat only (the window's size and anchors are locked in combat)
    local style = ns.Opt("style")
    if geoLocked and P.frame.gtStyle then style = P.frame.gtStyle end
    if not geoLocked then P.frame.gtStyle = style end

    P.UpdateChrome()
    P.SyncManualOrder()
    local src = ns.Source()
    P.PruneManualOrder(src)
    local tab = ns.view.tab
    local anyHiddenContainer, anyVisibleContainer = false, false
    for _, container in ipairs(src.containers) do
        if P.IsContainerHidden(tab, container.id) then
            anyHiddenContainer = true
        else
            anyVisibleContainer = true
        end
    end
    local manageSlots = tab == "bags" and P.slotManageMode and not InCombatLockdown()
    if tab ~= "bags" and tab ~= "bank" then P.pinMode = false end
    local pinning = P.pinMode and not InCombatLockdown() and not manageSlots
    local showSlots = tab == "bags" and src.self and ns.Opt("slotsRow")
    local showGuild = tab == "guild" and src.guild ~= nil
    P.frame.slotRow:SetShown(showSlots and true or false)
    P.frame.guildRow:SetShown(showGuild)
    if showSlots then P.UpdateSlotRow() end
    if showGuild then P.UpdateGuildRow(src) end
    P.UpdateModeButtons()
    local top = P.HEAD_H + P.ToolH() + ((showSlots or showGuild) and P.SUB_H or 0)
    for _, row in ipairs({ P.frame.slotRow, P.frame.guildRow }) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", P.frame, "TOPLEFT", P.PAD, -(P.HEAD_H + P.ToolH()))
        row:SetPoint("TOPRIGHT", P.frame, "TOPRIGHT", -P.PAD, -(P.HEAD_H + P.ToolH()))
    end
    local STEP = ns.STEP
    local gridW = cols * STEP - (STEP - ns.SIZE)
    local railW = style == "sidebar" and (P.RAIL_W + P.RAIL_GAP) or 0
    local innerW = gridW + railW
    local W = innerW + 2 * P.PAD
    if not geoLocked then
        P.content:ClearAllPoints()
        P.content:SetPoint("TOPLEFT", P.frame, "TOPLEFT", P.PAD + railW, -top)
    end

    -- every slot (or mail item) of the source
    local entries, hiddenContainerCount = {}, 0
    local function AddEntry(entry)
        if not manageSlots and P.query ~= "" and ns.Opt("searchMode") == "filter"
            and not ns.Matches(entry.info, P.query) then return end
        entries[#entries + 1] = entry
    end
    local hideItems = tab == "bags" and ns.ViewingSelf()      -- "hide this item everywhere" applies to your own bags
    for _, c in ipairs(src.containers) do
        if P.IsContainerHidden(tab, c.id) then
            hiddenContainerCount = hiddenContainerCount + 1
        else
            local isQuiverBag = tab == "bags" and c.isQuiverBag
            for slot = 1, c.n do
                local info = c.get(slot)
                local slotHidden = tab == "bags" and P.IsSlotHidden(tab, c.id, slot)
                local itemHidden = hideItems and info ~= nil and P.IsItemHidden(info.id)
                if slotHidden or itemHidden then
                    if manageSlots then
                        -- a hidden slot shows as an empty "+" cell; an item hidden everywhere shows dimmed, with its "+"
                        AddEntry({ bag = c.id, slot = slot, info = itemHidden and info or nil, kind = src.kind,
                            live = src.live, liveSlot = itemHidden and c.liveSlot or nil,
                            container = c.label, isQuiverBag = isQuiverBag,
                            hiddenSlot = slotHidden and true or nil, hiddenItem = itemHidden or nil,
                            peeked = itemHidden or nil, slotVisibility = true })
                    elseif (P.showHiddenSlots or pinning) and (info or (src.kind ~= "guild" and not ns.Opt("ignoreEmpty"))) then
                        -- right-click on the eye button, or Pin mode: hidden slots are shown again for now, dimmed (peeked)
                        AddEntry({ bag = c.id, slot = slot, info = info, kind = src.kind, live = src.live,
                            liveSlot = c.liveSlot, container = c.label, isQuiverBag = isQuiverBag,
                            slotVisibility = true, peeked = true })
                    end
                elseif info or (src.kind ~= "guild"
                    and (not ns.Opt("ignoreEmpty") or manageSlots)) then
                    AddEntry({ bag = c.id, slot = slot, info = info, kind = src.kind, live = src.live,
                        liveSlot = c.liveSlot, container = c.label, isQuiverBag = isQuiverBag,
                        slotVisibility = tab == "bags" })
                end
            end
        end
    end
    for i, info in ipairs(src.items or {}) do
        AddEntry({ bag = 0, slot = i, info = info, kind = src.kind, live = src.live })
    end

    ns.HideAllButtons()
    for _, h in ipairs(P.headers) do h:Hide() end
    for _, hb in ipairs(P.headerButtons) do hb:Hide(); hb.gtKey = nil end
    wipe(P.shown)

    local nStatic, nLive = 0, 0
    local function Acquire(e)
        local b
        if e.liveSlot and ns.Opt("liveActions") and ns.LiveActions ~= false and not combatStatic then
            local ok, lb = pcall(ns.GetLive, nLive + 1, P.LiveParent(e.bag))
            if ok and lb then
                nLive = nLive + 1
                b = lb
                b:SetBagID(e.bag)
                b:SetID(e.slot)
                P.WireLive(b)
            end
        end
        if not b then
            nStatic = nStatic + 1
            b = ns.GetStatic(nStatic, P.content)
        end
        b.gtEntry = e
        e.button = b
        return b
    end
    local cellW             -- row width of the List style, set after the plan is made
    local function Put(e, x, y)
        if not Acquire(e) then return false end
        ns.SetRowWidth(e.button, cellW)
        P.Place(e.button, x, y)
        if e.slotVisibility and manageSlots then
            local toggle = P.SlotVisibilityButton(e.button)
            toggle.gtEntry = e
            local restore = e.hiddenSlot or e.hiddenItem
            toggle.label:SetText(restore and "+" or "x")
            toggle.label:SetTextColor(restore and 0.5 or 1, restore and 1 or 0.45, 0.5)
            toggle:SetShown(manageSlots)
        elseif pinning and e.info then
            local toggle = P.SlotVisibilityButton(e.button)
            local pinned = ns.IsPinned(e.info.id)
            toggle.gtEntry = e
            toggle.label:SetText(pinned and "*" or "+")
            toggle.label:SetTextColor(1, pinned and 0.82 or 0.85, pinned and 0 or 0.2)
            toggle:SetShown(true)
        elseif e.button.gtSlotVisibilityButton and not InCombatLockdown() then
            e.button.gtSlotVisibilityButton:Hide()
        end
        if e.button.gtLive then
            -- live buttons keep their native item actions (see WireLive)
        elseif not e.info then
            e.button:SetScript("OnDragStart", nil)
            e.button:SetScript("OnDragStop", nil)
            e.button.gtDragWired = nil
            e.button:SetScript("OnReceiveDrag", nil)
        elseif ns.Opt("view") == "category" then
            P.SetManualDrag(e.button)
        else
            e.button:SetScript("OnDragStart", nil)
            e.button:SetScript("OnDragStop", nil)
            e.button.gtDragWired = nil
            e.button:SetScript("OnReceiveDrag", nil)
        end
        P.shown[#P.shown + 1] = e
        return true
    end

    -- ---- 1. sections: the items grouped the way the View option says (categories or containers) ----
    for _, rule in ipairs(P.headerRules) do rule:Hide() end
    local sections = {}                -- { key, name, label (header text), list (entries) }
    if view == "bag" then
        local groups = {}
        local groupOrder = {}
        for _, e in ipairs(entries) do
            local label
            if tab == "bank" then
                label = "Bank + reagent bank"
            elseif tab == "bags" and ns.Opt("mergeBags") and e.isQuiverBag then
                label = "Ammo / arrow bag: " .. e.container
            elseif tab == "bags" and ns.Opt("mergeBags") then
                label = "All bags"
            else
                label = e.container or (e.kind == "mail" and "Mailbox") or "Items"
            end
            if not groups[label] then
                groups[label] = {}
                groupOrder[#groupOrder + 1] = label
            end
            groups[label][#groups[label] + 1] = e
        end
        for _, label in ipairs(groupOrder) do
            local list = groups[label]
            if ns.Opt("autoSort") then
                table.sort(list, function(a, b)
                    if (a.info ~= nil) ~= (b.info ~= nil) then return a.info ~= nil end
                    if not a.info then
                        if a.bag ~= b.bag then return (tonumber(a.bag) or 0) < (tonumber(b.bag) or 0) end
                        return a.slot < b.slot
                    end
                    return ns.ItemCompare(a, b)
                end)
            end
            -- "Backpack  15 / 16": the container name, then how many of its slots hold something
            local used = 0
            for _, e in ipairs(list) do if e.info then used = used + 1 end end
            local text = label
            if src.kind ~= "mail" and src.kind ~= "guild" then
                text = string.format("|cffb7c0cc%s|r |cff8b95a3%d / %d|r", label, used, #list)
            else
                text = "|cffb7c0cc" .. label .. "|r"
            end
            sections[#sections + 1] = { key = label, name = label, label = text, list = list }
        end
    else
        local groups, emptySlots = {}, {}
        local hasHiddenSlotEntries = false
        local newSection = tab == "bags" and ns.Opt("newSection") and ns.Opt("newGlow")
        for _, e in ipairs(entries) do
            if e.info then
                e.name = ns.Name(e.info)
                local cat = ns.Category(e.info)
                if newSection and e.live and e.kind ~= "mail" and e.kind ~= "bank" and e.kind ~= "guild"
                    and ns.IsInventoryBag(e.bag) and ns.IsNew(e.info.id) then
                    cat = "_new"
                end
                groups[cat] = groups[cat] or {}
                table.insert(groups[cat], e)
            else
                hasHiddenSlotEntries = hasHiddenSlotEntries or e.hiddenSlot == true
                emptySlots[#emptySlots + 1] = e
            end
        end
        local newList = groups._new
        if newList and #newList > 0 then
            sections[#sections + 1] = { key = "_new", name = "New", list = newList,
                                        label = string.format("|cffb7c0cc%s|r |cff8b95a3%d|r", "New", #newList) }
        end
        for _, c in ipairs(ns.AllCats()) do
            local list = groups[c[1]]
            if list and #list > 0 then
                P.ApplyManualOrder(c[1], list)
                sections[#sections + 1] = { key = c[1], name = c[2], list = list,
                                            label = string.format("|cffb7c0cc%s|r |cff8b95a3%d|r", c[2], #list) }
            end
        end
        if #emptySlots > 0 then
            table.sort(emptySlots, function(a, b)
                if a.bag ~= b.bag then return (tonumber(a.bag) or 0) < (tonumber(b.bag) or 0) end
                return a.slot < b.slot
            end)
            local name = hasHiddenSlotEntries and "Empty / hidden" or "Empty"
            sections[#sections + 1] = { key = "_empty", name = name, list = emptySlots,
                                        label = string.format("|cffb7c0cc%s|r |cff8b95a3%d|r", name, #emptySlots) }
        end
    end

    -- the List style shows items only: empty slots have no name to put in a row
    if style == "list" and not manageSlots then
        local kept = {}
        for _, s in ipairs(sections) do
            local list = {}
            for _, e in ipairs(s.list) do if e.info then list[#list + 1] = e end end
            if #list > 0 then s.list = list; kept[#kept + 1] = s end
        end
        sections = kept
    end

    -- the Sidebar style shows one section at a time (the rail lists them all)
    local railItems, railSelected
    if style == "sidebar" then
        railSelected = ns.view.side
        local picked
        railItems = { { key = nil, text = "All" } }
        local total = 0
        for _, s in ipairs(sections) do
            railItems[#railItems + 1] = { key = s.key, text = string.format("%s |cff999999(%d)|r", s.name, #s.list) }
            total = total + #s.list
            if s.key == railSelected then picked = s end
        end
        railItems[1].text = string.format("All |cff999999(%d)|r", total)
        if picked then sections = { picked } else railSelected = nil; ns.view.side = nil end
    end
    -- fold / unfold: category view with the stacked, columns or list style; a search always shows everything
    local foldable = view ~= "bag" and (style == "stack" or style == "columns" or style == "list")
        and P.query == "" and not manageSlots
    for _, s in ipairs(sections) do
        s.total = #s.list
        if foldable then
            s.foldable = true
            if ns.IsCollapsed(s.key) then
                s.collapsed = true
                s.list = {}
            end
            s.label = string.format("|cff8b95a3%s|r |cffb7c0cc%s|r |cff8b95a3%d|r", s.collapsed and "+" or "-", s.name, s.total)
        end
    end
    for _, s in ipairs(sections) do s.n = #s.list end

    -- ---- 2. where everything goes (LayoutStyles.lua), 3. put the headers and the item buttons there ----
    local plan = ns.PlanLayout(style, sections, { step = STEP, size = ns.SIZE, headerH = P.HEADER_H, groupGap = P.GROUP_GAP,
                                                  gridW = gridW, cols = cols, blocks = ns.Opt("blocks") })
    cellW = plan.cellW
    for hi, h in ipairs(plan.headers) do
        local fs = P.GetHeader(hi)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", P.content, "TOPLEFT", h.x, -h.y)
        fs:SetWidth(h.w)                       -- a long heading is cut off at its block instead of running into the next
        fs:SetWordWrap(false)
        fs:SetText(sections[h.section].label)
        fs:Show()
        if sections[h.section].foldable then
            local hb = P.GetHeaderButton(hi)
            hb.gtKey = sections[h.section].key
            hb.gtList, hb.gtTab, hb.gtTitle = sections[h.section].list, tab, sections[h.section].name
            hb:ClearAllPoints()
            hb:SetPoint("TOPLEFT", P.content, "TOPLEFT", h.x, -h.y)
            hb:SetSize(math.max(h.w, 1), P.HEADER_H)
            hb:Show()
        end
        local rule = P.GetHeaderRule(hi)
        rule:ClearAllPoints()
        rule:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        rule:SetPoint("RIGHT", P.content, "TOPLEFT", h.x + h.w, -h.y - P.HEADER_H / 2)
        rule:SetShown(h.w > fs:GetStringWidth() + 24)
    end
    for i, s in ipairs(sections) do
        for j, e in ipairs(s.list) do
            local cell = plan.cells[i][j]
            Put(e, cell.x, cell.y)
        end
    end
    local y = plan.height
    if y == 0 and view ~= "bag" then y = STEP end
    if not geoLocked then
        if style == "sidebar" then P.UpdateRail(railItems, railSelected, top) else P.HideRail() end
    end
    local railH = (style == "sidebar" and railItems) and (#railItems * P.RAIL_ROW) or 0

    -- the empty-source message
    P.frame.notice:ClearAllPoints()
    P.frame.notice:SetPoint("TOP", P.frame, "TOP", railW / 2, -(top + 10))
    P.frame.notice:SetWidth(innerW - railW)
    local notice = src.notice
    if not notice and #P.shown == 0 and hiddenContainerCount > 0 and hiddenContainerCount == #src.containers then
        notice = "All containers are hidden.\nUse Opt > Containers > Show all."
    end
    if not notice and #P.shown == 0 and P.query ~= "" and ns.Opt("searchMode") == "filter" then
        notice = "No matching items."
    end
    if not notice and #P.shown == 0 and tab == "bags" and P.HiddenSlotCount(tab) > 0 then
        notice = "Inventory slots are hidden.\nUse the eye button in the header to restore them."
    end
    P.frame.notice:SetText(#P.shown == 0 and (notice or "") or "")
    -- an empty source (no bank data, empty mail...): the window grows to hold the message, so it never runs into the footer
    local noticeH = 0
    if #P.shown == 0 and notice and notice ~= "" then
        noticeH = math.ceil(P.frame.notice:GetStringHeight() or 0) + 24
    end

    if not geoLocked then
        P.content:SetSize(gridW, math.max(y, 1))
        -- The header stays where it is when the window changes size (Inv / Bank / Mail / Guild): the window is anchored
        -- by its top-left corner.  The first time, the new size is applied first so the window keeps the spot it had.
        local newH = top + math.max(y, railH, noticeH, 1) + P.FOOT_H
        if not P.frame.gtTopLeftPinned then P.frame:SetSize(W, newH) end
        P.PinTopLeft()
        P.frame:SetSize(W, newH)
    end
    P.UpdateContent(true)             -- the entries above were read a moment ago: no second read of every live slot
    P.UpdateFooter()
    P.layoutNote = "drawn"
    P.layoutCount = P.layoutCount + 1
end

