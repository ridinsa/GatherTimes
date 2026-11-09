-- Data.lua
local _, GT = ...

local READY_LINGER = 120
local MERGE_DIST = 0.006
local MAX_SPAWNS = 3000
local UNCHECKED_PENALTY = 20
local MAX_ROUTE_COST = 900

local nodes = {}; local order = {}

local function MakePrefix(label)
    local words = {}
    for w in label:gmatch("%a+") do words[#words + 1] = w end
    if #words > 1 then
        local s = ""
        for i = 1, math.min(#words, 3) do s = s .. words[i]:sub(1, 1):upper() end
        return "(" .. s .. ")"
    end
    return "(" .. label:sub(1, 3) .. ")"
end

local function Def(kind, key, label, id, minutes, o)
    local d = { kind = kind, match = label, id = id, label = label, timer = (minutes or 10) * 60,
        gm = label:lower() }
    if o then for k, v in pairs(o) do d[k] = v end end
    d.prefix = d.prefix or MakePrefix(d.label)
    d.defaultTimer = d.timer          -- factory value, used by the Nodes panel "Reset" button
    nodes[key] = d
    order[#order + 1] = key
end

Def("herb", "peacebloom", "Peacebloom", 2447)
Def("herb", "silverleaf", "Silverleaf", 765)
Def("herb", "earthroot", "Earthroot", 2449)
Def("herb", "mageroyal", "Mageroyal", 785)
Def("herb", "briarthorn", "Briarthorn", 2450)
Def("herb", "swiftthistle", "Swiftthistle", 2452)
Def("herb", "bruiseweed", "Bruiseweed", 2453)
Def("herb", "stranglekelp", "Stranglekelp", 3820)
Def("herb", "wildsteelbloom", "Wild Steelbloom", 3355)
Def("herb", "gravemoss", "Grave Moss", 3369)
Def("herb", "kingsblood", "Kingsblood", 3356)
Def("herb", "liferoot", "Liferoot", 3357)
Def("herb", "fadeleaf", "Fadeleaf", 3818)
Def("herb", "goldthorn", "Goldthorn", 3821)
Def("herb", "khadgarswhisker", "Khadgar's Whisker", 3358)
Def("herb", "wintersbite", "Wintersbite", 3819)
Def("herb", "firebloom", "Firebloom", 4625)
Def("herb", "purplelotus", "Purple Lotus", 8831)
Def("herb", "arthastears", "Arthas' Tears", 8836)
Def("herb", "sungrass", "Sungrass", 8838)
Def("herb", "blindweed", "Blindweed", 8839)
Def("herb", "ghostmushroom", "Ghost Mushroom", 8845, nil, { prefix = "(Gho)" })
Def("herb", "gromsblood", "Gromsblood", 8846, 15, { prefix = "(G)" })
Def("herb", "goldensansam", "Golden Sansam", 13464)
Def("herb", "dreamfoil", "Dreamfoil", 13463, 15, { prefix = "(D)" })
Def("herb", "mountainsilversage", "Mountain Silversage", 13465, 15,
    { label = "Mt. Silversage", gm = "mountain silversage", prefix = "(S)" })
Def("herb", "plaguebloom", "Plaguebloom", 13466, 10, { prefix = "(P)" })
Def("herb", "icecap", "Icecap", 13467)
Def("herb", "blacklotus", "Black Lotus", 13468, 55, { prefix = "(L)" })

Def("ore", "copperore", "Copper Ore", 2770, 10, { gm = "copper vein" })
Def("ore", "tinore", "Tin Ore", 2771, 10, { gm = "tin vein", prefix = "(Tin)" })
Def("ore", "incendiciteore", "Incendicite Ore", 3340, 10, { gm = "incendicite mineral vein", prefix = "(Inc)" })
Def("ore", "lesserbloodstoneore", "Lesser Bloodstone Ore", 4278, 10, { gm = "lesser bloodstone deposit" })
Def("ore", "silverore", "Silver Ore", 2775, 10, { gm = "silver vein" })
Def("ore", "ironore", "Iron Ore", 2772, 10, { gm = "iron deposit", prefix = "(Ir)" })
Def("ore", "induriumore", "Indurium Ore", 5833, 10, { gm = "indurium mineral vein", prefix = "(Ind)" })
Def("ore", "goldore", "Gold Ore", 2776, 10, { gm = "gold vein" })
Def("ore", "mithrilore", "Mithril Ore", 3858, 10, { gm = "mithril deposit" })
Def("ore", "truesilverore", "Truesilver Ore", 7911, 10, { gm = "truesilver deposit", prefix = "(TS)" })
Def("ore", "darkironore", "Dark Iron Ore", 11370, 10, { gm = "dark iron deposit" })
Def("ore", "richthorium", "Thorium", 10620, 25,
    { match = "Thorium", sub = true, gm = "thorium vein", prefix = "(T)",
      extra = { "Arcane", "Dense", "Ruby", "Sapphire", "Emerald", "Opal", "Diamond" },
      -- the same extra loot by item id (language independent; `extra` above is only the English-name fallback):
      -- Arcane Crystal, Dense Stone, Star Ruby, Blue Sapphire, Huge Emerald, Large Opal, Azerothian Diamond
      extraIds = { 12363, 12365, 7910, 12361, 12364, 12799, 12800 },
      -- main window "In bags" line counts this item instead of the node's own item (Arcane Crystal)
      countId = 12363 })

-- GatherMate2 node ids (GatherMate2\Constants.lua, "Herb Gathering" 4xx / "Mining" 2xx).  The GatherMate2
-- database stores these numbers, so the import does not depend on the client language.  Swiftthistle has no
-- node of its own (it comes out of Briarthorn nodes) and is not in GatherMate2.
local GM_IDS = {
    peacebloom = { 401 }, silverleaf = { 402 }, earthroot = { 403 }, mageroyal = { 404 }, briarthorn = { 405 },
    stranglekelp = { 407 }, bruiseweed = { 408 }, wildsteelbloom = { 409 }, gravemoss = { 410 },
    kingsblood = { 411 }, liferoot = { 412 }, fadeleaf = { 413 }, goldthorn = { 414 }, khadgarswhisker = { 415 },
    wintersbite = { 416 }, firebloom = { 417 }, purplelotus = { 418 }, arthastears = { 420 }, sungrass = { 421 },
    blindweed = { 422 }, ghostmushroom = { 423 }, gromsblood = { 424 }, goldensansam = { 425 },
    dreamfoil = { 426 }, mountainsilversage = { 427 }, plaguebloom = { 428 }, icecap = { 429 },
    blacklotus = { 431 },
    copperore = { 201 }, tinore = { 202 }, ironore = { 203 },
    silverore = { 204, 209 },                 -- 209 = Ooze Covered Silver Vein
    goldore = { 205, 210 },                   -- 210 = Ooze Covered Gold Vein
    mithrilore = { 206, 207 },                -- 207 = Ooze Covered Mithril Deposit
    truesilverore = { 208, 211 },             -- 211 = Ooze Covered Truesilver Deposit
    richthorium = { 212, 213, 214, 215 },     -- (Ooze Covered) Small / Rich Thorium Vein
    darkironore = { 217 }, lesserbloodstoneore = { 218 }, incendiciteore = { 219 }, induriumore = { 220 },
}
local GM_NODE_KEY = {}                        -- GatherMate2 node id -> our node key
for key, ids in pairs(GM_IDS) do
    if nodes[key] then
        nodes[key].gmIds = ids
        for _, id in ipairs(ids) do GM_NODE_KEY[id] = key end
    end
end

local COLORS = {
    {1.00, 1.00, 1.00}, {1.00, 0.30, 0.30}, {1.00, 0.60, 0.10},
    {1.00, 0.90, 0.20}, {0.40, 1.00, 0.40}, {0.30, 1.00, 1.00},
    {0.40, 0.60, 1.00}, {0.80, 0.50, 1.00}, {1.00, 0.50, 0.90},
}
local DEFAULT_COLOR = {
    gromsblood = 5, richthorium = 3, dreamfoil = 6, mountainsilversage = 7,
    plaguebloom = 4, blacklotus = 8,
}
for i, key in ipairs(order) do
    if not DEFAULT_COLOR[key] then DEFAULT_COLOR[key] = (i - 1) % #COLORS + 1 end
end

local function SK(key, fallback) return (SOUNDKIT and SOUNDKIT[key]) or fallback end

local SOUNDS = {
    { name = "Default",      id = 120 },
    { name = "Raid Warning", id = 8959 },
    { name = "Ready Check",  id = 8960 },
    { name = "Alarm",        id = 12867 },
    { name = "Level Up",     id = 888 },
    { name = "Map Ping",     id = 3175 },
    { name = "None",         id = 0 },
    -- added after "None" so "None" stays index 7 (saved settings / Reset rely on it).
    -- Official WoW sounds, looked up by SOUNDKIT name first, numeric id as fallback.
    { name = "Whisper",      id = SK("TELL_MESSAGE", 3081) },
    { name = "Toast",        id = SK("UI_BNET_TOAST", 18019) },
    { name = "Queue",        id = SK("PVP_THROUGH_QUEUE", 8459) },
    { name = "Alarm 2",      id = SK("ALARM_CLOCK_WARNING_3", 18871) },
    { name = "Auction",      id = SK("AUCTION_WINDOW_OPEN", 5274) },
    { name = "Invite",       id = SK("IG_PLAYER_INVITE", 880) },
    { name = "Popup",        id = SK("TUTORIAL_POPUP", 7355) },
}

-- exports
GT.COLORS = COLORS
GT.DEFAULT_COLOR = DEFAULT_COLOR
GT.GM_NODE_KEY = GM_NODE_KEY
GT.MAX_ROUTE_COST = MAX_ROUTE_COST
GT.MAX_SPAWNS = MAX_SPAWNS
GT.MERGE_DIST = MERGE_DIST
GT.READY_LINGER = READY_LINGER
GT.SOUNDS = SOUNDS
GT.UNCHECKED_PENALTY = UNCHECKED_PENALTY
GT.nodes = nodes
GT.order = order
