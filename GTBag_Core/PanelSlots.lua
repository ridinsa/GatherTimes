-- PanelSlots.lua : hidden containers and slots, the Slots menu's slot buttons. Part of the Panel window (see PanelState.lua).
local _, ns = ...
local P = ns.panel

function P.WindowWidth(cols)
    -- exactly the slot grid plus the side padding, so the border follows the number of slot columns
    return cols * ns.STEP - (ns.STEP - ns.SIZE) + 2 * P.PAD
end

local function ContainerKey(kind, id)
    return tostring(kind) .. ":" .. tostring(id)
end

-- Hidden containers are saved per character (the one being viewed): hiding a quiver on your hunter no longer hides
-- bag 4 on your other characters.  Old saves had one shared flat list ("bags:5" = true); the first time a character is
-- viewed, that list is copied into its own scope and removed.
local legacyChecked = false
local function HiddenScope(create)
    GTBagDB = GTBagDB or {}
    local all = GTBagDB.hiddenContainers
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        GTBagDB.hiddenContainers = all
    end
    local scopeKey = tostring(ns.ViewKey())
    local legacy
    if not legacyChecked then
        legacyChecked = true            -- the old flat list is looked for once per session, not on every call
        for k, v in pairs(all) do
            if v == true and type(k) == "string" then legacy = legacy or {}; legacy[k] = true end
        end
    end
    if legacy then
        local mine = type(all[scopeKey]) == "table" and all[scopeKey] or {}
        for k in pairs(legacy) do mine[k] = true; all[k] = nil end
        all[scopeKey] = mine
    end
    local scope = all[scopeKey]
    if type(scope) ~= "table" and create then scope = {}; all[scopeKey] = scope end
    return scope, all, scopeKey
end

function P.IsContainerHidden(kind, id)
    local scope = HiddenScope(false)
    return type(scope) == "table" and scope[ContainerKey(kind, id)] == true
end

function P.SetContainerHidden(kind, id, hide)
    local scope, all, scopeKey = HiddenScope(hide)
    if not scope then return end
    if hide then
        scope[ContainerKey(kind, id)] = true
    else
        scope[ContainerKey(kind, id)] = nil
        if next(scope) == nil then all[scopeKey] = nil end
        if next(all) == nil then GTBagDB.hiddenContainers = nil end
    end
end

function P.ShowAllContainers(kind)
    local scope, all, scopeKey = HiddenScope(false)
    if type(scope) ~= "table" then return end
    local prefix = tostring(kind) .. ":"
    for key in pairs(scope) do
        if type(key) == "string" and key:sub(1, #prefix) == prefix then scope[key] = nil end
    end
    if next(scope) == nil then all[scopeKey] = nil end
    if next(all) == nil then GTBagDB.hiddenContainers = nil end
end

local function SlotScope(kind)
    return tostring(ns.ViewKey()) .. ":" .. tostring(kind)
end

function P.SlotKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

function P.IsSlotHidden(kind, bag, slot)
    local all = GTBagDB and GTBagDB.hiddenSlots
    local hidden = type(all) == "table" and all[SlotScope(kind)]
    return type(hidden) == "table" and hidden[P.SlotKey(bag, slot)] == true
end

local function SetSlotHidden(kind, bag, slot, hide)
    GTBagDB = GTBagDB or {}
    local all = GTBagDB.hiddenSlots
    local scope = SlotScope(kind)
    if hide then
        if type(all) ~= "table" then
            all = {}
            GTBagDB.hiddenSlots = all
        end
        if type(all[scope]) ~= "table" then all[scope] = {} end
        all[scope][P.SlotKey(bag, slot)] = true
    elseif type(all) == "table" and type(all[scope]) == "table" then
        all[scope][P.SlotKey(bag, slot)] = nil
        if next(all[scope]) == nil then all[scope] = nil end
        if next(all) == nil then GTBagDB.hiddenSlots = nil end
    end
end

-- "Hide this item everywhere": items hidden by item id (all stacks, any slot, any bag), saved for the account like pins.
-- They are hidden only in your own bags window; the items stay in your bags.
local MAX_HIDDEN_ITEMS = 500

function P.IsItemHidden(id)
    id = tonumber(id)
    if not id then return false end
    local t = GTBagDB and GTBagDB.hiddenItems
    return type(t) == "table" and t[id] == true
end

-- returns false when the item could not be hidden (bad id or the limit is reached)
function P.SetItemHidden(id, hide)
    id = tonumber(id)
    if not id or id < 1 or id > 99999999 then return false end
    GTBagDB = GTBagDB or {}
    local t = GTBagDB.hiddenItems
    if hide then
        if type(t) ~= "table" then t = {}; GTBagDB.hiddenItems = t end
        if t[id] then return true end
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        if n >= MAX_HIDDEN_ITEMS then return false end
        t[id] = true
    elseif type(t) == "table" then
        t[id] = nil
        if next(t) == nil then GTBagDB.hiddenItems = nil end
    end
    return true
end

-- backup export: hidden items { id, ... } and hidden slots { { characterKey, bag, slot }, ... }
function P.HiddenItemList()
    local out = {}
    local t = GTBagDB and GTBagDB.hiddenItems
    if type(t) == "table" then
        for id, v in pairs(t) do
            if v == true and tonumber(id) then out[#out + 1] = tonumber(id) end
        end
    end
    table.sort(out)
    return out
end

function P.HiddenSlotList()
    local out = {}
    local all = GTBagDB and GTBagDB.hiddenSlots
    if type(all) ~= "table" then return out end
    for scope, hidden in pairs(all) do
        local charKey = type(scope) == "string" and scope:match("^(.+):bags$")
        if charKey and type(hidden) == "table" then
            for key, v in pairs(hidden) do
                local bag, slot = tostring(key):match("^(-?%d+):(%d+)$")
                if v == true and bag then out[#out + 1] = { charKey, tonumber(bag), tonumber(slot) } end
            end
        end
    end
    table.sort(out, function(a, b)
        if a[1] ~= b[1] then return a[1] < b[1] end
        if a[2] ~= b[2] then return a[2] < b[2] end
        return a[3] < b[3]
    end)
    return out
end

-- backup import: hides one slot of any character (inventory slots only)
function P.ImportHiddenSlot(charKey, bag, slot)
    bag, slot = tonumber(bag), tonumber(slot)
    if type(charKey) ~= "string" or charKey == "" or #charKey > 80 or charKey:find("[\r\n]") then return false end
    if not bag or not slot or bag ~= math.floor(bag) or slot ~= math.floor(slot) then return false end
    if bag < -3 or bag > 100 or slot < 1 or slot > 500 then return false end
    GTBagDB = GTBagDB or {}
    if type(GTBagDB.hiddenSlots) ~= "table" then GTBagDB.hiddenSlots = {} end
    local scope = charKey .. ":bags"
    if type(GTBagDB.hiddenSlots[scope]) ~= "table" then GTBagDB.hiddenSlots[scope] = {} end
    GTBagDB.hiddenSlots[scope][P.SlotKey(bag, slot)] = true
    return true
end

function P.HiddenSlotCount(kind)
    local all = GTBagDB and GTBagDB.hiddenSlots
    local hidden = type(all) == "table" and all[SlotScope(kind)]
    local count = 0
    if type(hidden) == "table" then
        for _, value in pairs(hidden) do
            if value == true then count = count + 1 end
        end
    end
    if kind == "bags" and type(GTBagDB and GTBagDB.hiddenItems) == "table" then
        for _, value in pairs(GTBagDB.hiddenItems) do
            if value == true then count = count + 1 end
        end
    end
    return count
end

function P.ShowAllHiddenSlots(kind)
    if kind == "bags" and GTBagDB then GTBagDB.hiddenItems = nil end
    local all = GTBagDB and GTBagDB.hiddenSlots
    if type(all) ~= "table" then return end
    all[SlotScope(kind)] = nil
    if next(all) == nil then GTBagDB.hiddenSlots = nil end
end

function P.SlotVisibilityButton(button)
    if button.gtSlotVisibilityButton then return button.gtSlotVisibilityButton end
    local toggle = CreateFrame("Button", nil, button)
    toggle:SetSize(20, 20)
    toggle:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
    toggle:SetFrameLevel(button:GetFrameLevel() + 5)
    toggle:RegisterForClicks("LeftButtonUp")
    local background = toggle:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.03, 0.03, 0.03, 0.95)
    toggle.label = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    toggle.label:SetAllPoints()
    toggle.label:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    toggle:SetScript("OnClick", function(self)
        local entry = self.gtEntry
        if not entry then return end
        if P.pinMode and entry.info then
            if InCombatLockdown() then
                print("|cffffd100GTBag|r: pinning is unavailable during combat.")
                return
            end
            local pinned = ns.TogglePin(entry.info.id)
            if pinned ~= nil then
                self.label:SetText(pinned and "*" or "+")
                self.label:SetTextColor(1, pinned and 0.82 or 0.85, pinned and 0 or 0.2)
            end
            return
        end
        if ns.view.tab ~= "bags" or not entry.slotVisibility then return end
        if InCombatLockdown() then
            print("|cffffd100GTBag|r: slot actions are unavailable during combat.")
            return
        end
        if not P.slotManageMode then return end
        if entry.hiddenSlot or entry.hiddenItem then
            -- "+": show it again (an item hidden everywhere is shown everywhere)
            if entry.hiddenItem and entry.info then P.SetItemHidden(entry.info.id, false) end
            if entry.hiddenSlot then SetSlotHidden(entry.kind, entry.bag, entry.slot, false) end
        elseif IsShiftKeyDown and IsShiftKeyDown() and entry.info then
            -- shift-click on "x": hide this item everywhere
            if not P.SetItemHidden(entry.info.id, true) then
                print("|cffffd100GTBag|r: at most " .. MAX_HIDDEN_ITEMS .. " items can be hidden everywhere.")
                return
            end
        else
            SetSlotHidden(entry.kind, entry.bag, entry.slot, true)
        end
        P.Layout()
    end)
    toggle:SetScript("OnEnter", function(self)
        local entry = self.gtEntry
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if P.pinMode and entry.info then
            GameTooltip:SetText(ns.IsPinned(entry.info.id) and "Unpin this item" or "Pin this item")
            GameTooltip:AddLine("Pinned items are never sold by Sell junk, never deleted, and never moved by sorting.", 0.7, 0.7, 0.7)
        elseif entry.hiddenItem then
            GameTooltip:SetText("Show this item again")
            GameTooltip:AddLine("This item is hidden everywhere in your bags.", 0.7, 0.7, 0.7, true)
        else
            GameTooltip:SetText((entry.hiddenSlot and "Show " or "Hide ") ..
                (entry.container or "Inventory") .. " slot " .. tostring(entry.slot))
            if not entry.hiddenSlot and entry.info then
                GameTooltip:AddLine("The item stays in your bags.", 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Shift-click: hide this item everywhere.", 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    toggle:Hide()
    button.gtSlotVisibilityButton = toggle
    return toggle
end
