-- PanelDelete.lua : delete selection and the delete run. Part of the Panel window (see PanelState.lua).
local _, ns = ...
local P = ns.panel

P.IsDeleteSelected = function(entry)
    if not (entry and entry.info) then return false end
    local selected = P.deleteSelection[P.SlotKey(entry.bag, entry.slot)]
    return selected ~= nil and selected.id == entry.info.id and selected.link == entry.info.link
        and selected.count == (entry.info.count or 1)
end

function P.DeleteSelectedStats()
    local stacks, count = 0, 0
    for _, selected in pairs(P.deleteSelection) do
        stacks = stacks + 1
        count = count + (tonumber(selected.count) or 1)
    end
    return stacks, count
end

P.ToggleDeleteSelection = function(entry)
    if not (entry and entry.info and entry.slotVisibility) then return end
    if P.deleteRun or P.deletePending then
        print("|cffffd100GTBag|r: item selection is paused while deletion is being confirmed or processed.")
        return
    end
    if InCombatLockdown() then
        print("|cffffd100GTBag|r: item selection is unavailable during combat.")
        return
    end
    if not ns.ViewingSelf() then
        print("|cffffd100GTBag|r: only your current inventory can be deleted.")
        return
    end
    local scope = tostring(ns.ViewKey())
    if P.deleteSelectionScope ~= scope then
        wipe(P.deleteSelection)
        P.deleteSelectionScope = scope
    end

    local key = P.SlotKey(entry.bag, entry.slot)
    local current = ns.ItemInfo(entry.bag, entry.slot)
    if not current or current.id ~= entry.info.id or current.link ~= entry.info.link
        or (current.count or 1) ~= (entry.info.count or 1) then
        print("|cffffd100GTBag|r: that inventory slot changed; select it again.")
        P.deleteSelection[key] = nil
        P.Layout()
        return
    end
    if current.locked then
        print("|cffffd100GTBag|r: that item is locked; wait and try again.")
        return
    end
    if ns.IsPinned(current.id) and not P.IsDeleteSelected(entry) then
        print("|cffffd100GTBag|r: that item is pinned and cannot be deleted. Unpin it first (Opt > Pin items).")
        return
    end

    if P.IsDeleteSelected(entry) then
        P.deleteSelection[key] = nil
    else
        P.deleteSelection[key] = {
            bag = entry.bag, slot = entry.slot, id = current.id,
            link = current.link, count = current.count or 1,
        }
    end
    P.Layout()
end

function P.PruneDeleteSelection(src)
    local scope = tostring(ns.ViewKey())
    if P.deleteSelectionScope ~= scope then
        wipe(P.deleteSelection)
        P.deleteSelectionScope = scope
        P.deleteSelectMode = false
        P.deletePending = nil
        if P.deleteRun and P.StopDeleteRun then P.StopDeleteRun("deletion stopped because the character changed.") end
    end
    if src.kind ~= "bags" then return end

    local containers = {}
    for _, container in ipairs(src.containers) do containers[container.id] = container end
    for key, selected in pairs(P.deleteSelection) do
        local currentAction = P.deleteRun and P.deleteRun.awaiting and P.deleteRun.queue[P.deleteRun.index]
        local inFlight = currentAction and currentAction.bag == selected.bag and currentAction.slot == selected.slot
        if not inFlight then
            local container = containers[selected.bag]
            local info = container and container.get(selected.slot)
            if not info or info.id ~= selected.id or info.link ~= selected.link
                or (info.count or 1) ~= selected.count or ns.IsPinned(info.id) then
                P.deleteSelection[key] = nil
            end
        end
    end
end

local QueueDeleteStep

local function SameSelectedItem(selected, info)
    return info and info.id == selected.id and info.link == selected.link
        and (info.count or 1) == selected.count
end

local function IsNativeDeletePromptVisible()
    if not StaticPopup_Visible then return false end
    for _, popup in ipairs({ "DELETE_ITEM", "DELETE_GOOD_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_QUEST_ITEM" }) do
        if StaticPopup_Visible(popup) then return true end
    end
    return false
end

local function DeleteSelectedPoll(run)
    if P.deleteRun ~= run or not run.awaiting then return end
    if not (P.frame and P.frame:IsShown()) then
        P.StopDeleteRun("deletion stopped because GTBag was closed; check the current item before continuing.")
        return
    end
    if InCombatLockdown() then
        P.StopDeleteRun("deletion stopped because combat started; check the current item before continuing.")
        return
    end
    local selected = run.queue[run.index]
    if P.IsContainerHidden("bags", selected.bag) or P.IsSlotHidden("bags", selected.bag, selected.slot) then
        P.StopDeleteRun("deletion stopped because the current slot was hidden; check the item before continuing.")
        return
    end
    if GetCursorInfo and GetCursorInfo() or IsNativeDeletePromptVisible() then
        run.waitTicks = run.waitTicks + 1
        if run.waitTicks >= 240 then
            P.StopDeleteRun("deletion paused at the current item; resolve or cancel the game's delete prompt. No further selected items were processed.")
        else
            C_Timer.After(0.25, function() DeleteSelectedPoll(run) end)
        end
        return
    end

    local info = ns.ItemInfo(selected.bag, selected.slot)
    if info then
        if SameSelectedItem(selected, info) then
            run.resultWaitTicks = run.resultWaitTicks + 1
            if run.resultWaitTicks >= 8 then
                P.StopDeleteRun("deletion was canceled; remaining selected items were left untouched.")
            else
                C_Timer.After(0.25, function() DeleteSelectedPoll(run) end)
            end
        else
            P.StopDeleteRun("deletion stopped because the selected slot changed; remaining items were left untouched.")
        end
        return
    end

    run.resultWaitTicks = run.resultWaitTicks + 1
    if run.resultWaitTicks < 2 then
        C_Timer.After(0.15, function() DeleteSelectedPoll(run) end)
        return
    end
    P.deleteSelection[P.SlotKey(selected.bag, selected.slot)] = nil
    run.deletedStacks = run.deletedStacks + 1
    run.deletedItems = run.deletedItems + selected.count
    run.index = run.index + 1
    run.awaiting = false
    if run.index > #run.queue then
        local stacks, count = run.deletedStacks, run.deletedItems
        P.deleteRun = nil
        wipe(P.deleteSelection)
        P.deleteSelectMode = false
        print(string.format("|cffffd100GTBag|r: deleted %d stack(s), %d item(s).", stacks, count))
        P.Layout()
    else
        P.Layout()
        QueueDeleteStep(0.1)
    end
end

local function DeleteSelectedStep(run)
    if P.deleteRun ~= run then return end
    if not (P.frame and P.frame:IsShown()) then
        P.StopDeleteRun("deletion stopped because GTBag was closed.")
        return
    end
    if InCombatLockdown() then
        P.StopDeleteRun("deletion stopped because combat started.")
        return
    end
    if not ns.ViewingSelf() or ns.view.tab ~= "bags" then
        P.StopDeleteRun("deletion stopped because the inventory view changed.")
        return
    end
    if run.awaiting then return end

    local selected = run.queue[run.index]
    if not selected then
        P.deleteRun = nil
        wipe(P.deleteSelection)
        print("|cffffd100GTBag|r: no selected items remained to delete.")
        P.Layout()
        return
    end
    if P.IsContainerHidden("bags", selected.bag) or P.IsSlotHidden("bags", selected.bag, selected.slot) then
        P.StopDeleteRun("deletion stopped because a selected slot was hidden.")
        return
    end

    local info = ns.ItemInfo(selected.bag, selected.slot)
    if not SameSelectedItem(selected, info) then
        P.StopDeleteRun("deletion stopped because a selected slot changed; remaining items were left untouched.")
        return
    end
    if ns.IsPinned(info.id) then
        P.StopDeleteRun("deletion stopped because a selected item is pinned; remaining items were left untouched.")
        return
    end
    if info.locked then
        run.lockWaits = run.lockWaits + 1
        if run.lockWaits >= 20 then
            P.StopDeleteRun("deletion stopped because a selected item stayed locked.")
        else
            QueueDeleteStep(0.25)
        end
        return
    end
    run.lockWaits = 0
    if GetCursorInfo and GetCursorInfo() then
        P.StopDeleteRun("deletion stopped because the cursor is occupied; no further items were touched.")
        return
    end

    local pickup = (ns.CONT and ns.CONT.PickupContainerItem) or PickupContainerItem
    if type(pickup) ~= "function" or type(DeleteCursorItem) ~= "function" then
        P.StopDeleteRun("item deletion is unavailable on this client.")
        return
    end

    run.awaiting = true
    run.waitTicks = 0
    run.resultWaitTicks = 0
    local picked = false
    local ok, err = pcall(function()
        pickup(selected.bag, selected.slot)
        local cursorType = GetCursorInfo and GetCursorInfo()
        if cursorType ~= "item" then error("the selected item did not reach the cursor") end
        picked = true
        DeleteCursorItem()
    end)
    if not ok then
        run.awaiting = false
        -- a failed delete leaves the item on the cursor; ClearCursor returns it to the slot it came from
        if GetCursorInfo and GetCursorInfo() then pcall(ClearCursor) end
        P.StopDeleteRun("item deletion failed: " .. tostring(err))
        return
    end
    C_Timer.After(0.1, function() DeleteSelectedPoll(run) end)
end

QueueDeleteStep = function(delay)
    local run = P.deleteRun
    if not run or run.queued or run.awaiting then return end
    run.queued = true
    C_Timer.After(delay or 0.1, function()
        if P.deleteRun ~= run then return end
        run.queued = false
        DeleteSelectedStep(run)
    end)
end

P.StopDeleteRun = function(message)
    if not P.deleteRun then return end
    P.deleteRun = nil
    if message then print("|cffffd100GTBag|r: " .. message) end
end

P.StartDeleteSelected = function()
    local pending = P.deletePending
    P.deletePending = nil
    if not pending then return end
    if pending.scope ~= tostring(ns.ViewKey()) or not ns.ViewingSelf() or ns.view.tab ~= "bags" then
        print("|cffffd100GTBag|r: deletion canceled because the character or inventory view changed.")
        return
    end
    if InCombatLockdown() then
        print("|cffffd100GTBag|r: deletion is unavailable during combat.")
        return
    end
    if GetCursorInfo and GetCursorInfo() then
        print("|cffffd100GTBag|r: clear your cursor before deleting items.")
        return
    end

    for _, selected in ipairs(pending.queue) do
        local info = ns.ItemInfo(selected.bag, selected.slot)
        if P.IsContainerHidden("bags", selected.bag) or P.IsSlotHidden("bags", selected.bag, selected.slot)
            or not SameSelectedItem(selected, info) or info.locked or ns.IsPinned(info.id) then
            print("|cffffd100GTBag|r: nothing was deleted; a selected slot changed, was hidden, is locked or is pinned.")
            P.Layout()
            return
        end
    end

    P.deleteRun = {
        queue = pending.queue, index = 1, deletedStacks = 0, deletedItems = 0,
        awaiting = false, queued = false, waitTicks = 0, lockWaits = 0,
    }
    P.deleteSelectMode = false
    P.Layout()
    QueueDeleteStep()
end

P.RequestDeleteSelected = function()
    if P.deleteRun or P.deletePending then
        print("|cffffd100GTBag|r: an item deletion is already in progress.")
        return
    end
    if P.physicalSortRun then
        print("|cffffd100GTBag|r: finish physical sorting before deleting items.")
        return
    end
    if InCombatLockdown() or not ns.ViewingSelf() or ns.view.tab ~= "bags" then
        print("|cffffd100GTBag|r: selected items can only be deleted from your own bags out of combat.")
        return
    end
    if GetCursorInfo and GetCursorInfo() then
        print("|cffffd100GTBag|r: clear your cursor before deleting items.")
        return
    end
    if type(DeleteCursorItem) ~= "function" then
        print("|cffffd100GTBag|r: item deletion is unavailable on this client.")
        return
    end

    local queue = {}
    local totalItems = 0
    for _, selected in pairs(P.deleteSelection) do
        local info = ns.ItemInfo(selected.bag, selected.slot)
        if P.IsContainerHidden("bags", selected.bag) or P.IsSlotHidden("bags", selected.bag, selected.slot)
            or not SameSelectedItem(selected, info) or info.locked then
            print("|cffffd100GTBag|r: selection changed, is hidden, or is locked; select items again.")
            P.Layout()
            return
        end
        queue[#queue + 1] = {
            bag = selected.bag, slot = selected.slot, id = selected.id,
            link = selected.link, count = selected.count,
        }
        totalItems = totalItems + selected.count
    end
    table.sort(queue, function(a, b)
        if a.bag ~= b.bag then return (tonumber(a.bag) or 0) < (tonumber(b.bag) or 0) end
        return a.slot < b.slot
    end)
    if #queue == 0 then
        print("|cffffd100GTBag|r: no items are selected for deletion.")
        return
    end
    if not (StaticPopupDialogs and StaticPopup_Show) then
        print("|cffffd100GTBag|r: deletion confirmation is unavailable; nothing was deleted.")
        return
    end

    local popupName = "GTBAG_DELETE_SELECTED"
    if not StaticPopupDialogs[popupName] then
        StaticPopupDialogs[popupName] = {
            text = "Permanently delete %d selected stack(s), containing %d item(s)? This cannot be undone.",
            button1 = DELETE or YES or "Delete",
            button2 = CANCEL or NO or "Cancel",
            OnAccept = function() if P.StartDeleteSelected then P.StartDeleteSelected() end end,
            OnCancel = function() P.deletePending = nil end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
        }
    end
    P.deletePending = {
        scope = tostring(ns.ViewKey()), queue = queue,
        stackCount = #queue, itemCount = totalItems,
    }
    if not StaticPopup_Show(popupName, #queue, totalItems) then
        P.deletePending = nil
        print("|cffffd100GTBag|r: deletion confirmation could not be opened; nothing was deleted.")
    end
end