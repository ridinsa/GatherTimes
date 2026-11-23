-- Query.lua : the search language.  A plain word still works as before (part of the name, category or item type).
-- Anything with an operator is compiled once into a test function:
--     herb & !bound            AND (&), OR (|), NOT (!), parentheses
--     name:bloom   type:armor   sub:cloth   cat:herbs   bind:boe   is:bound   is:junk
--     ilvl>300   count>=20   quality>=epic   value>50s   price<1g   id=2447        (> >= < <= =)
-- A query that cannot be parsed, and a field name it does not know, fall back to the plain word search, so a mistake
-- never hides everything.  The same text works in a custom category rule when it starts with "?" (see Core.lua), e.g.
--     /gtbag cat add Cheap herbs = ?herb & value<50s
local _, ns = ...

local ilvlFn = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

-- true when the text has anything the plain search would not understand
function ns.QueryHas(query)
    return query ~= nil and query:find("[&|!()<>=:]") ~= nil
end

-- ---------------------------------------------------------------------------------------------- values
local QUALITY = { poor = 0, grey = 0, gray = 0, common = 1, white = 1, uncommon = 2, green = 2, rare = 3, blue = 3,
                  epic = 4, purple = 4, legendary = 5, orange = 5 }
local BIND = { none = 0, bop = 1, pickup = 1, boe = 2, equip = 2, bou = 3, use = 3, quest = 4 }

-- "1g50s", "20s", "5c", "1.5g" or a plain number of copper
local function Money(text)
    text = (text or ""):gsub("%s", "")
    if text:match("^%d+%.?%d*$") then return tonumber(text) end
    local total, any = 0, false
    for num, unit in text:gmatch("(%d+%.?%d*)([gsc])") do
        num = tonumber(num)
        total = total + num * (unit == "g" and 10000 or unit == "s" and 100 or 1)
        any = true
    end
    return any and total or nil
end

local ilvlCache, ilvlCount = {}, 0
local function ItemLevel(info)
    local link = info.link
    if not (link and ilvlFn) then return 0 end
    local v = ilvlCache[link]
    if v == nil then
        if ilvlCount >= 512 then wipe(ilvlCache); ilvlCount = 0 end
        local ok, n = pcall(ilvlFn, link)
        v = (ok and type(n) == "number") and n or 0
        ilvlCache[link] = v
        ilvlCount = ilvlCount + 1
    end
    return v
end

-- numeric fields: function(info) -> number, and how the right-hand side is read
local NUMERIC = {
    ilvl    = { get = ItemLevel, parse = tonumber },
    level   = { get = ItemLevel, parse = tonumber },
    count   = { get = function(info) return tonumber(info.count) or 1 end, parse = tonumber },
    stack   = { get = function(info) return tonumber(info.count) or 1 end, parse = tonumber },
    id      = { get = function(info) return tonumber(info.id) or 0 end, parse = tonumber },
    quality = { get = function(info) return tonumber(info.quality) or 0 end,
                parse = function(s) return QUALITY[s] or tonumber(s) end },
    rarity  = { get = function(info) return tonumber(info.quality) or 0 end,
                parse = function(s) return QUALITY[s] or tonumber(s) end },
    price   = { get = function(info) return (ns.UnitValue(info.id, info.link)) or 0 end, parse = Money },
    value   = { get = function(info) return ((ns.UnitValue(info.id, info.link)) or 0) * (tonumber(info.count) or 1) end,
                parse = Money },
}

local function Facts(info) return ns.ItemFacts(info.id, info.link) end
local function Has(text, part) return text ~= nil and text ~= "" and text:lower():find(part, 1, true) ~= nil end

-- the item's category including custom ones, so operator searches and plain words see the same names.  A custom category
-- rule may itself be a query: while ns.Category evaluates one it marks the item (catBusy) and no category is asked for
-- again, so there is no loop.
local function CustomCat(info)
    if info.cat then return info.cat end
    if info.catBusy or not ns.Category then return nil end
    return (ns.Category(info))
end

-- the plain word search
local function Plain(info, word)
    if ns.LowerName(info):find(word, 1, true) then return true end
    local base = ns.CATLABEL[ns.BaseCategory(info)]
    if Has(base, word) then return true end
    local cat = CustomCat(info)
    if cat and Has(ns.CatLabel(cat), word) then return true end
    local f = Facts(info)
    return f ~= nil and (Has(f.type, word) or Has(f.sub, word))
end

local TEXT = {
    name = function(info, v) return ns.LowerName(info):find(v, 1, true) ~= nil end,
    type = function(info, v) local f = Facts(info); return f ~= nil and Has(f.type, v) end,
    sub = function(info, v) local f = Facts(info); return f ~= nil and Has(f.sub, v) end,
    cat = function(info, v)
        if Has(ns.CATLABEL[ns.BaseCategory(info)], v) then return true end
        local cat = CustomCat(info)
        return cat ~= nil and Has(ns.CatLabel(cat), v)
    end,
    bind = function(info, v)
        local f = Facts(info)
        local want = BIND[v]
        if want == nil or not f then return false end
        return (f.bind or 0) == want
    end,
    is = function(info, v)
        if v == "bound" or v == "soulbound" then return info.bound == true end
        if v == "junk" or v == "grey" or v == "gray" then return (tonumber(info.quality) or 0) == 0 end
        if v == "boe" then
            local f = Facts(info)
            return f ~= nil and f.bind == 2 and not info.bound
        end
        return false
    end,
}
TEXT.subtype, TEXT.category = TEXT.sub, TEXT.cat

local function Compare(a, op, b)
    if op == ">" then return a > b elseif op == ">=" then return a >= b
    elseif op == "<" then return a < b elseif op == "<=" then return a <= b end
    return a == b
end

-- one term: field:text, field>number, or a plain word
local function Term(text)
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    local field, op, rhs = text:match("^(%a+)%s*([<>]=?)%s*(.+)$")
    if not field then field, op, rhs = text:match("^(%a+)%s*(==?)%s*(.+)$") end
    local num = field and NUMERIC[field]
    if num then
        local want = num.parse(rhs:match("^%s*(.-)%s*$"))
        if want == nil then return nil end          -- "ilvl>abc": not a query
        local get = num.get
        return function(info) return Compare(get(info), op, want) end
    end
    local f, v = text:match("^(%a+)%s*:%s*(.+)$")
    local test = f and TEXT[f]
    if test then
        v = v:match("^%s*(.-)%s*$")
        return function(info) return test(info, v) end
    end
    return function(info) return Plain(info, text) end   -- a plain word, or a field name nobody knows
end

-- ---------------------------------------------------------------------------------------------- parser
-- expr = and { "|" and }    and = unary { "&" unary }    unary = "!" unary | "(" expr ")" | term
local function Compile(query)
    local pos, len = 1, #query
    local expr

    local function SkipSpace() while pos <= len and query:sub(pos, pos):match("%s") do pos = pos + 1 end end

    local function Unary()
        SkipSpace()
        local c = query:sub(pos, pos)
        if c == "!" then
            pos = pos + 1
            local inner = Unary()
            if not inner then return nil end
            return function(info) return not inner(info) end
        elseif c == "(" then
            pos = pos + 1
            local inner = expr()
            SkipSpace()
            if not inner or query:sub(pos, pos) ~= ")" then return nil end
            pos = pos + 1
            return inner
        end
        local start = pos
        while pos <= len and not query:sub(pos, pos):match("[&|)]") do pos = pos + 1 end
        return Term(query:sub(start, pos - 1))
    end

    local function And()
        local list = { Unary() }
        if not list[1] then return nil end
        SkipSpace()
        while query:sub(pos, pos) == "&" do
            pos = pos + 1
            local nextTerm = Unary()
            if not nextTerm then return nil end
            list[#list + 1] = nextTerm
            SkipSpace()
        end
        if #list == 1 then return list[1] end
        return function(info)
            for i = 1, #list do if not list[i](info) then return false end end
            return true
        end
    end

    expr = function()
        local list = { And() }
        if not list[1] then return nil end
        SkipSpace()
        while query:sub(pos, pos) == "|" do
            pos = pos + 1
            local nextTerm = And()
            if not nextTerm then return nil end
            list[#list + 1] = nextTerm
            SkipSpace()
        end
        if #list == 1 then return list[1] end
        return function(info)
            for i = 1, #list do if list[i](info) then return true end end
            return false
        end
    end

    local fn = expr()
    SkipSpace()
    if not fn or pos <= len then return nil end        -- nothing left over: a stray ")" or "&" is a mistake
    return fn
end

local compiled, compiledCount = {}, 0
local function Get(query)
    local fn = compiled[query]
    if fn == nil then
        if compiledCount >= 64 then wipe(compiled); compiledCount = 0 end
        local ok, result = pcall(Compile, query)
        fn = (ok and result) or false
        compiled[query] = fn
        compiledCount = compiledCount + 1
    end
    return fn
end

-- true when this item matches the query (the plain word search when the text is not a valid query)
function ns.QueryMatch(info, query)
    if not info then return false end
    query = (query or ""):lower():match("^%s*(.-)%s*$")
    if query == "" then return true end
    local fn = Get(query)
    if fn then
        local ok, result = pcall(fn, info)
        if ok then return result and true or false end
    end
    return Plain(info, query)
end
