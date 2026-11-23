-- PanelOrder.lua : manual order of displayed items and drag to reorder. Part of the Panel window (see PanelState.lua).
local _, ns = ...
local P = ns.panel

function P.SyncManualOrder()
    local scope = tostring(ns.ViewKey()) .. ":" .. tostring(ns.view.tab) .. ":" .. tostring(ns.view.gtab or 0)
    if scope == P.orderScope then return end
    P.orderScope = scope
    local saved = GTBagDB and GTBagDB.manualOrders
    P.manualOrder = type(saved) == "table" and type(saved[scope]) == "table" and saved[scope] or {}
end

local function SaveManualOrder()
    if not P.orderScope then return end
    GTBagDB = GTBagDB or {}
    if type(GTBagDB.manualOrders) ~= "table" then GTBagDB.manualOrders = {} end
    GTBagDB.manualOrders[P.orderScope] = P.manualOrder
end

function P.ResetManualOrder()
    P.SyncManualOrder()
    P.manualOrder = {}
    SaveManualOrder()
end

-- Drops saved drag positions whose item is no longer in the source (moved, sold, mailed, used up).  Built from the
-- whole source, not the search-filtered list, so a filtered-out item keeps its place.  Empty lists are removed.
function P.PruneManualOrder(src)
    if not P.orderScope then return end
    local present, kind = {}, tostring(src.kind or "")
    for _, c in ipairs(src.containers) do
        for slot = 1, c.n do
            local info = c.get(slot)
            if info then present[kind .. ":" .. tostring(c.id or 0) .. ":" .. tostring(slot) .. ":" .. tostring(info.id or 0)] = true end
        end
    end
    for i, info in ipairs(src.items or {}) do
        present[kind .. ":0:" .. tostring(i) .. ":" .. tostring(info.id or 0)] = true
    end
    local changed = false
    for cat, order in pairs(P.manualOrder) do
        local kept = {}
        for _, key in ipairs(order) do
            if present[key] then kept[#kept + 1] = key end
        end
        if #kept ~= #order then
            changed = true
            P.manualOrder[cat] = #kept > 0 and kept or nil
        end
    end
    if changed then
        if next(P.manualOrder) == nil and GTBagDB and type(GTBagDB.manualOrders) == "table" then
            GTBagDB.manualOrders[P.orderScope] = nil
        else
            SaveManualOrder()
        end
    end
end

local function EntryKey(e)
    return tostring(e.kind or "") .. ":" .. tostring(e.bag or 0) .. ":" .. tostring(e.slot or 0) .. ":" ..
        tostring(e.info and e.info.id or 0)
end

function P.ApplyManualOrder(cat, list)
    local order = P.manualOrder[cat]
    if not order and not ns.Opt("autoSort") then return end
    local rank = {}
    if order then for i, key in ipairs(order) do rank[key] = i end end
    local sourceRank = {}
    for i, entry in ipairs(list) do sourceRank[entry] = i end
    table.sort(list, function(a, b)
        local ak = EntryKey(a)
        local bk = EntryKey(b)
        local ar = rank[ak]
        local br = rank[bk]
        if ar and br then return ar < br end
        if ar then return true end
        if br then return false end
        if not ns.Opt("autoSort") then return sourceRank[a] < sourceRank[b] end
        return ns.ItemCompare(a, b)
    end)
end

local function StopManualDrag(sourceButton)
    if not P.dragSource then return end
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    local target
    for _, entry in ipairs(P.shown) do
        local b = entry.button
        if b ~= sourceButton and b:IsShown() and x >= b:GetLeft() and x <= b:GetRight()
            and y >= b:GetBottom() and y <= b:GetTop() then
            target = entry
            break
        end
    end
    local source = P.dragSource
    P.dragSource = nil
    if P.dragGhost then
        P.dragGhost:SetScript("OnUpdate", nil)
        P.dragGhost:Hide()
    end
    if not (source and source.info and target and target.info)
        or ns.Category(source.info) ~= ns.Category(target.info) then return end

    local cat = ns.Category(source.info)
    local order = P.manualOrder[cat]
    if not order then
        order = {}
        P.manualOrder[cat] = order
    end
    if not order[1] then
        local src = ns.Source()
        for _, c in ipairs(src.containers) do
            for slot = 1, c.n do
                local info = c.get(slot)
                if info and ns.Category(info) == cat then
                    order[#order + 1] = tostring(src.kind or "") .. ":" .. tostring(c.id or 0) .. ":" ..
                        tostring(slot) .. ":" .. tostring(info.id or 0)
                end
            end
        end
        for i, info in ipairs(src.items or {}) do
            if ns.Category(info) == cat then
                order[#order + 1] = tostring(src.kind or "") .. ":0:" .. tostring(i) .. ":" .. tostring(info.id or 0)
            end
        end
    end
    local sourceKey, targetKey = EntryKey(source), EntryKey(target)
    local sourceIndex, targetIndex
    for i, key in ipairs(order) do
        if key == sourceKey then sourceIndex = i end
        if key == targetKey then targetIndex = i end
    end
    if sourceIndex and targetIndex and sourceIndex ~= targetIndex then
        order[sourceIndex], order[targetIndex] = order[targetIndex], order[sourceIndex]
        SaveManualOrder()
        P.Layout()
    end
end

local function GhostFollow(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

-- reorder drag: the item follows the cursor as a ghost until it is dropped on another item of its category
local function StartReorder(entry)
    P.dragSource = entry
    if not P.dragGhost then
        P.dragGhost = CreateFrame("Frame", nil, UIParent)
        P.dragGhost:SetSize(ns.SIZE, ns.SIZE)
        P.dragGhost:SetFrameStrata("TOOLTIP")
        P.dragGhost:EnableMouse(false)
        P.dragGhost.icon = P.dragGhost:CreateTexture(nil, "ARTWORK")
        P.dragGhost.icon:SetAllPoints()
        P.dragGhost:SetAlpha(0.75)
    end
    P.dragGhost.icon:SetTexture(entry.info and entry.info.icon)
    P.dragGhost:SetScript("OnUpdate", GhostFollow)
    P.dragGhost:Show()
end

-- static (saved / remote) buttons: drag only reorders
function P.SetManualDrag(b)
    b:RegisterForDrag("LeftButton")
    if not b.gtDragWired then
        b.gtDragWired = true
        b:SetScript("OnDragStart", function(self)
            if self.gtEntry then StartReorder(self.gtEntry) end
        end)
        b:SetScript("OnDragStop", function(self) StopManualDrag(self) end)
    end
    b:SetScript("OnReceiveDrag", nil)
end

local function PickUp(bag, slot)
    local pick = (ns.CONT and ns.CONT.PickupContainerItem) or PickupContainerItem
    if pick then pick(bag, slot) end
end

-- live bag / bank buttons: a drag moves the item (Blizzard's pickup and drop); Alt + drag reorders in category view
function P.WireLive(b)
    if b.gtLiveWired then return end
    b.gtLiveWired = true
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        local entry = self.gtEntry
        if not entry then return end
        if IsAltKeyDown() and ns.Opt("view") == "category" then
            StartReorder(entry)
        else
            PickUp(entry.bag, entry.slot)
        end
    end)
    b:SetScript("OnDragStop", function(self)
        if P.dragSource then StopManualDrag(self) end
    end)
    b:SetScript("OnReceiveDrag", function(self)
        local entry = self.gtEntry
        if entry and not P.dragSource then PickUp(entry.bag, entry.slot) end
    end)
end
