-- PanelSort.lua : physical sort: moving real items between bags. Part of the Panel window (see PanelState.lua).
local _, ns = ...
local P = ns.panel

function P.StopPhysicalSort(message)
    P.physicalSortRun = nil
    if message then print("|cffffd100GTBag|r: " .. message) end
end

local function PhysicalSortStep(run)
    if P.physicalSortRun ~= run then return end
    if InCombatLockdown() then
        P.StopPhysicalSort("physical sorting stopped because combat started.")
        return
    end
    if not ns.ViewingSelf() then
        P.StopPhysicalSort("physical sorting stopped because the character changed.")
        return
    end
    if run.bank and not ns.atBank then
        P.StopPhysicalSort("bank sorting stopped because the bank closed.")
        return
    end
    if run.steps >= run.maxSteps then
        P.StopPhysicalSort("sorting stopped before completion; click Sort again to retry.")
        return
    end
    run.steps = run.steps + 1

    local planned, action, status = pcall(ns.PhysicalSortNext, run.bank)
    if not planned then
        P.StopPhysicalSort("sort planning failed: " .. tostring(action))
        return
    end
    if status == "locked" then
        run.lockWaits = run.lockWaits + 1
        if run.lockWaits > 20 then
            P.StopPhysicalSort("some items remained locked; wait and click Sort again.")
        else
            P.QueuePhysicalSortStep(0.10)
        end
        return
    end
    run.lockWaits = 0
    if status == "item data unavailable" then
        P.StopPhysicalSort("item or stack data is still loading; wait and click Sort again.")
        return
    end
    if not action then
        if status == "done" then
            P.StopPhysicalSort((run.bank and "bank" or "bag") .. " sorting and stack merge complete.")
            if not run.bank then
                if run.fromIcon then
                    -- the sort icon's merge is done: auto sort goes off again.
                    -- Hidden containers stay hidden; never reset container visibility on completion.
                    ns.SetOpt("autoSort", false)
                end
                P.slotManageMode = false
                P.Layout()
            end
        else
            P.StopPhysicalSort("sorting could not continue: " .. tostring(status))
        end
        return
    end

    local pickup = (ns.CONT and ns.CONT.PickupContainerItem) or PickupContainerItem
    if type(pickup) ~= "function" then
        P.StopPhysicalSort("item movement is unavailable on this client.")
        return
    end
    if GetCursorInfo and GetCursorInfo() then
        P.StopPhysicalSort("clear your cursor before sorting.")
        return
    end

    run.awaiting = true
    run.timeoutToken = run.timeoutToken + 1
    local token = run.timeoutToken
    local ok, err = pcall(function()
        pickup(action.sourceBag, action.sourceSlot)
        pickup(action.targetBag, action.targetSlot)
        ClearCursor()
    end)
    if not ok then
        if GetCursorInfo and GetCursorInfo() then ClearCursor() end
        P.StopPhysicalSort((run.bank and "bank" or "bag") .. " sort failed: " .. tostring(err))
        return
    end
    if GetCursorInfo and GetCursorInfo() then
        ClearCursor()
        P.StopPhysicalSort("sorting stopped because the cursor did not clear.")
        return
    end

    C_Timer.After(1.5, function()
        if P.physicalSortRun == run and run.awaiting and run.timeoutToken == token then
            -- No confirmation (laggy server): replan safely after a longer wait.
            -- The move may have happened even if the bag event arrived late.
            run.retries = (run.retries or 0) + 1
            if run.retries > 2 then
                P.StopPhysicalSort("sorting stopped because the game did not confirm an item move.")
            else
                run.awaiting = false
                P.QueuePhysicalSortStep(0.35)
            end
        end
    end)
end

P.QueuePhysicalSortStep = function(delay)
    local run = P.physicalSortRun
    if not run or run.queued or run.awaiting then return end
    run.queued = true
    C_Timer.After(delay or 0.05, function()
        if P.physicalSortRun ~= run then return end
        run.queued = false
        PhysicalSortStep(run)
    end)
end

function P.RunPhysicalSort(bank, fromIcon)
    if InCombatLockdown() then
        print("|cffffd100GTBag|r: physical sorting is unavailable during combat.")
        return
    end
    if not ns.ViewingSelf() then
        print("|cffffd100GTBag|r: physical sorting is only available for your character.")
        return
    end
    if bank and not ns.atBank then
        print("|cffffd100GTBag|r: visit the banker before sorting bank items.")
        return
    end
    if P.physicalSortRun then
        print("|cffffd100GTBag|r: a physical sort is already in progress.")
        return
    end
    if GetCursorInfo and GetCursorInfo() then
        print("|cffffd100GTBag|r: clear your cursor before sorting.")
        return
    end

    local ids = bank and ns.BANK_IDS or ns.BAGS
    local totalSlots = 0
    for _, bag in ipairs(ids) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" and n > 0 then totalSlots = totalSlots + n end
    end
    if totalSlots == 0 then
        print("|cffffd100GTBag|r: no available slots to sort.")
        return
    end

    P.ResetManualOrder()
    P.physicalSortRun = { bank = bank, steps = 0, maxSteps = totalSlots * 2 + 20, lockWaits = 0,
                        awaiting = false, timeoutToken = 0, queued = false, retries = 0,
                        fromIcon = fromIcon and true or false }
    P.QueuePhysicalSortStep()
end
