-- Collapse.lua : collapsible category headers.  Click a header in the category view to fold or unfold its section;
-- the choice is remembered per category (all characters).  Search always shows everything.  /gtbag collapse all|none
local _, ns = ...

local function Store(create)
    if type(GTBagDB) ~= "table" then
        if not create then return nil end
        GTBagDB = {}
    end
    if type(GTBagDB.collapsed) ~= "table" then
        if not create then return nil end
        GTBagDB.collapsed = {}
    end
    return GTBagDB.collapsed
end

function ns.IsCollapsed(key)
    local t = Store(false)
    return t ~= nil and key ~= nil and t[key] == true
end

function ns.SetCollapsed(key, on)
    if key == nil then return end
    local t = Store(on)
    if not t then return end
    t[key] = on and true or nil
end

function ns.ToggleCollapsed(key)
    ns.SetCollapsed(key, not ns.IsCollapsed(key))
end

-- fold or unfold every category (including the New and Empty sections)
function ns.CollapseAll(on)
    for _, c in ipairs(ns.AllCats()) do ns.SetCollapsed(c[1], on) end
    ns.SetCollapsed("_new", on)
    ns.SetCollapsed("_empty", on)
end
