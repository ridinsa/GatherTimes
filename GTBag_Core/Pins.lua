-- Pins.lua : pinned items.  A pinned item (by item id, for all your characters) is protected: Sell junk and auto-sell
-- skip it, Blizzard's delete prompts are cancelled for it, and physical sorting leaves it where it is.  Pinned items wear a gold star in the grid.
-- Toggle pins with the star button in the window header (click the + / * on each item), or /gtbag pin [item].
local _, ns = ...

local MAX_PINS = 500

local Say = ns.Say

local function Pins()
    GTBagDB = GTBagDB or {}
    if type(GTBagDB.pinned) ~= "table" then GTBagDB.pinned = {} end
    return GTBagDB.pinned
end

function ns.IsPinned(id)
    id = tonumber(id)
    if not id then return false end
    local p = GTBagDB and GTBagDB.pinned
    return type(p) == "table" and p[id] == true
end

-- returns true when the change was made (false when the pin limit is reached or the id is bad)
function ns.SetPinned(id, on)
    id = tonumber(id)
    if not id or id < 1 or id > 99999999 then return false end
    local p = Pins()
    if on then
        if p[id] then return true end
        local n = 0
        for _ in pairs(p) do n = n + 1 end
        if n >= MAX_PINS then return false end
        p[id] = true
    else
        p[id] = nil
    end
    return true
end

function ns.PinList()
    local out = {}
    local p = GTBagDB and GTBagDB.pinned
    if type(p) == "table" then
        for id, v in pairs(p) do
            if v == true and tonumber(id) then out[#out + 1] = tonumber(id) end
        end
    end
    table.sort(out)
    return out
end

-- redraw the stars and the Sell junk count after a pin changed
function ns.RefreshPins()
    if ns.RefreshPinMarks then ns.RefreshPinMarks() end
    if ns.UpdateJunkButton then ns.UpdateJunkButton() end
end

-- flips one item; returns the new state, or nil when it could not be changed
function ns.TogglePin(id)
    id = tonumber(id)
    if not id then return nil end
    local want = not ns.IsPinned(id)
    if not ns.SetPinned(id, want) then
        Say("at most " .. MAX_PINS .. " pinned items.")
        return nil
    end
    ns.RefreshPins()
    return want
end

local function ItemName(id)
    return ns.GetItemInfo(id) or ("item " .. id)
end

-- /gtbag pin [item]  (toggle) | list | clear | mode
function ns.PinCommand(rest)
    rest = rest or ""
    local sub = rest:match("^%s*(%S*)"):lower()
    if sub == "list" then
        local list = ns.PinList()
        if #list == 0 then Say("no pinned items. Shift-click an item after /gtbag pin, or use the star button in the bag window header.") end
        for _, id in ipairs(list) do Say(ItemName(id) .. " (" .. id .. ")") end
    elseif sub == "clear" then
        local n = #ns.PinList()
        if GTBagDB then GTBagDB.pinned = nil end
        ns.RefreshPins()
        Say("unpinned " .. n .. " item" .. (n == 1 and "" or "s") .. ".")
    elseif sub == "mode" or (sub == "" and not rest:find("item:", 1, true)) then
        if ns.TogglePinMode then ns.TogglePinMode() end
    else
        local id = tonumber(rest:match("item:(%d+)") or rest:match("^%s*#?(%d+)%s*$"))
        if not id then Say("usage: /gtbag pin [shift-click an item or give its id]   |   pin list   |   pin clear   |   pin mode"); return end
        local state = ns.TogglePin(id)
        if state ~= nil then
            Say(ItemName(id) .. (state and " is pinned: it will not be sold as junk, deleted or moved by sorting."
                or " is no longer pinned."))
        end
    end
end

-- Delete protection.  GTBag has no delete feature of its own; the only way to destroy an item is the game's own
-- prompt (drag the item out of the bag and drop it).  When that prompt opens while a pinned item is on the cursor,
-- the prompt is closed and the item goes back to its slot.
local DELETE_POPUPS = {
    DELETE_ITEM = true, DELETE_GOOD_ITEM = true,
    DELETE_QUEST_ITEM = true, DELETE_GOOD_QUEST_ITEM = true,
}

local function CancelIfPinned(which)
    if not DELETE_POPUPS[which] then return end
    local kind, id = GetCursorInfo()
    if kind == "item" and ns.IsPinned(id) then
        StaticPopup_Hide(which)
        ClearCursor()
        Say("that item is pinned and cannot be deleted. Unpin it first (star button in the bag window header).")
    end
end

if hooksecurefunc and StaticPopup_Show and StaticPopup_Hide then
    hooksecurefunc("StaticPopup_Show", CancelIfPinned)
end
