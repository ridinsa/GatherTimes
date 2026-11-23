-- NewItems.lua : marks items that arrived in your bags during this session.  An item is "new" when the total count
-- of its id in your bags goes up after the first snapshot; moving it between bags does not count.  It stays marked
-- until you hover it (or /gtbag new clear).  The mark is a green glow on the icon and, if you turn it on, a "New"
-- section at the top of the category view.  Nothing is saved: the marks are for this session only.
-- Items picked up before the window was first opened this session are not marked (the snapshot is taken when this
-- part of GTBag loads, which is when you first open your bags or type /gtbag).
local _, ns = ...

local cur, prev, fresh = {}, {}, {}
local ready, baselineAt = false, 0
local SETTLE = 5            -- seconds after the first snapshot in which login loading is still going on

local function Snapshot(into)
    wipe(into)
    for _, bag in ipairs(ns.BAGS) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" then
            for slot = 1, n do
                local id, count = ns.SlotCount(bag, slot)
                if tonumber(id) then
                    into[id] = (into[id] or 0) + (tonumber(count) or 1)
                end
            end
        end
    end
end

function ns.IsInventoryBag(bag)
    for _, b in ipairs(ns.BAGS) do if b == bag then return true end end
    return false
end

function ns.IsNew(id)
    return fresh[tonumber(id) or -1] == true and ns.Opt("newGlow")
end

function ns.AnyNew()
    return next(fresh) ~= nil
end

function ns.ClearNew(id)
    id = tonumber(id)
    if id then
        if fresh[id] then
            fresh[id] = nil
            if ns.RefreshNewMarks then ns.RefreshNewMarks() end
        end
    else
        wipe(fresh)
        if ns.RefreshNewMarks then ns.RefreshNewMarks() end
        if ns.Relayout then ns.Relayout() end
    end
end

local function Check()
    if not ns.BAGS or #ns.BAGS == 0 or not ns.ItemInfo then return end
    Snapshot(cur)
    if not ready then
        if next(cur) == nil then return end            -- bag data not loaded yet: wait for a snapshot with items
        ready, baselineAt = true, GetTime()
    elseif GetTime() - baselineAt >= SETTLE then       -- inside the settle window nothing is marked, the snapshot just updates
        local changed = false
        for id, count in pairs(cur) do
            if count > (prev[id] or 0) and not fresh[id] then
                fresh[id] = true
                changed = true
            end
        end
        if changed then
            if ns.RefreshNewMarks then ns.RefreshNewMarks() end
            if ns.Opt("newSection") and ns.Relayout then ns.Relayout() end
        end
    end
    prev, cur = cur, prev
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", Check)
if C_Timer and C_Timer.After then C_Timer.After(0.2, Check) end
