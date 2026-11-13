-- Skills.lua : skill needed to gather each node
local _, GT = ...

-- Classic skill needed to pick / mine each node.  { min } or { min, max } for nodes that share a loot item:
--   * Swiftthistle has no node of its own: it comes out of Mageroyal (50) and Briarthorn (70) nodes
--   * "Thorium" covers Small (245) and Rich (275) Thorium Veins
GT.SKILLS = {
    -- herbalism
    peacebloom = {1}, silverleaf = {1}, earthroot = {15}, mageroyal = {50}, briarthorn = {70},
    swiftthistle = {50, 70}, stranglekelp = {85}, bruiseweed = {100}, wildsteelbloom = {115},
    gravemoss = {120}, kingsblood = {125}, liferoot = {150}, fadeleaf = {160}, goldthorn = {170},
    khadgarswhisker = {185}, wintersbite = {195}, firebloom = {205}, purplelotus = {210},
    arthastears = {220}, sungrass = {230}, blindweed = {235}, ghostmushroom = {245},
    gromsblood = {250}, goldensansam = {260}, dreamfoil = {270}, mountainsilversage = {280},
    plaguebloom = {285}, icecap = {290}, blacklotus = {300},
    -- mining
    copperore = {1}, tinore = {65}, incendiciteore = {65}, lesserbloodstoneore = {75}, silverore = {75},
    ironore = {125}, induriumore = {150}, goldore = {155}, mithrilore = {175}, truesilverore = {230},
    darkironore = {230}, richthorium = {245, 275},
}

-- "Herbalism 250" / "Mining 245-275"
function GT.SkillText(key)
    local def, s = GT.nodes[key], GT.SKILLS[key]
    if not (def and s) then return nil end
    local prof = GT.TR(def.kind == "ore" and "Mining" or "Herbalism")
    return s[2] and string.format("%s %d-%d", prof, s[1], s[2]) or string.format("%s %d", prof, s[1])
end

-- ---------------------------------------------------------------------------
-- Difficulty colours (the same idea as the game's skill-up colours)
--   red     your skill is below what the node needs (or you do not have the profession)
--   orange  you can gather it - skill-ups guaranteed        yellow  skill-ups likely
--   green   skill-ups only sometimes                        grey    no more skill-ups from it
-- Each node switches colour at  required,  +yellow,  +green,  +grey  skill points.
-- Default offsets are 25 / 50 / 100; nodes listed here use the values checked for them.
local DEFAULT_BAND = { 25, 50, 100 }
local BANDS = {
    peacebloom = { 24, 49, 99 }, silverleaf = { 24, 49, 99 },
    stranglekelp = { 30, 50, 100 }, bruiseweed = { 30, 50, 100 }, wildsteelbloom = { 30, 50, 100 },
    gravemoss = { 30, 50, 100 }, kingsblood = { 30, 50, 100 }, fadeleaf = { 30, 50, 100 },
}
local COLORS = {
    red    = { 1.00, 0.10, 0.10 },
    orange = { 1.00, 0.50, 0.25 },
    yellow = { 1.00, 1.00, 0.00 },
    green  = { 0.25, 0.75, 0.25 },
    grey   = { 0.60, 0.60, 0.60 },
}

-- GetSkillLineInfo returns the skill names in the CLIENT's language, so "Mining" / "Herbalism" only match on an
-- English client.  A skill line counts as the profession when ANY of these is true:
--   * it is the English word,
--   * it is the name of one of the profession's spells (Mining 2575 ..., Herbalism / Herb Gathering 2366 ...),
--   * the game's own text "Requires <profession>" (UNIT_SKINNABLE_HERB / _ROCK, in the client's language)
--     contains the skill name while the "Requires ..." text of the other professions does not.
local PROFESSION_SPELLS = {
    Mining    = { 2575, 2576, 3564, 10248 },
    Herbalism = { 2366, 2368, 3570, 11993 },
}
local PROFESSION_TEXT = {                           -- { own text, texts of the other professions }
    Mining    = { "UNIT_SKINNABLE_ROCK", { "UNIT_SKINNABLE_HERB", "UNIT_SKINNABLE_BOLTS" } },
    Herbalism = { "UNIT_SKINNABLE_HERB", { "UNIT_SKINNABLE_ROCK", "UNIT_SKINNABLE_BOLTS" } },
}

local function GlobalLower(name)
    local s = _G[name]
    return type(s) == "string" and s:lower() or nil
end

local professionNames = {}                          -- profession -> { [skill name] = true / false }, filled on demand
local function IsProfessionName(profession, name)
    if type(name) ~= "string" then return false end
    local known = professionNames[profession]
    if not known then
        known = { [profession] = true }
        for _, id in ipairs(PROFESSION_SPELLS[profession] or {}) do
            local spell
            pcall(function()
                if C_Spell and C_Spell.GetSpellName then spell = C_Spell.GetSpellName(id)
                elseif GetSpellInfo then spell = GetSpellInfo(id) end
            end)
            if type(spell) == "string" and spell ~= "" then known[spell] = true end
        end
        professionNames[profession] = known
    end
    if known[name] ~= nil then return known[name] end
    local result = false
    local def = PROFESSION_TEXT[profession]
    local own = def and GlobalLower(def[1])
    if own and type(name) == "string" and #name >= 2 then
        local l = name:lower()
        if own:find(l, 1, true) then
            result = true
            for _, other in ipairs(def[2]) do
                local o = GlobalLower(other)
                if o and o:find(l, 1, true) then result = false; break end
            end
        end
    end
    known[name] = result
    return result
end

-- Your current Herbalism / Mining skill (bonuses from gear and potions included), or nil if you do not
-- have the profession.  The skills window can hide lines inside collapsed headers, so those are opened
-- for a moment and closed again.
-- Retail and Forever have no skill-line list; the two gathering professions are read from the profession list
-- instead (skill line 186 = Mining, 182 = Herbalism).
local PROFESSION_SKILL_LINE = { Mining = 186, Herbalism = 182 }
local function ModernSkill(profession, baseOnly)
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local want = PROFESSION_SKILL_LINE[profession]
    local list = { GetProfessions() }
    for i = 1, 6 do
        local idx = list[i]
        if idx then
            local _, _, rank, maxRank, _, _, skillLine, rankModifier = GetProfessionInfo(idx)
            if skillLine == want then
                if baseOnly then return rank or 0, maxRank end
                return (rank or 0) + (rankModifier or 0), maxRank
            end
        end
    end
    return nil
end

-- baseOnly = true: the trained skill without gear / potion bonuses (the number that goes up by one at a skill-up).
-- Second return value: the skill cap (maxRank), when the client tells it.
local function PlayerSkill(profession, baseOnly)
    if not (GetNumSkillLines and GetSkillLineInfo) then
        local ok, skill, maxRank = pcall(ModernSkill, profession, baseOnly)
        if ok then return skill, maxRank end
        return nil
    end
    local function scan()
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank, temp, mod, maxRank = GetSkillLineInfo(i)
            if not header and IsProfessionName(profession, name) then
                if baseOnly then return rank or 0, maxRank end
                return (rank or 0) + (temp or 0) + (mod or 0), maxRank
            end
        end
    end
    local found, foundMax = scan()
    if found or not (ExpandSkillHeader and CollapseSkillHeader) then return found, foundMax end
    local opened = {}
    for i = GetNumSkillLines(), 1, -1 do
        local _, header, isExpanded = GetSkillLineInfo(i)
        if header and not isExpanded then ExpandSkillHeader(i); opened[#opened + 1] = i end
    end
    found, foundMax = scan()
    for _, i in ipairs(opened) do CollapseSkillHeader(i) end       -- opened[] is highest index first
    return found, foundMax
end

GT.PlayerSkill = PlayerSkill

-- the four skill levels where a node changes colour: orange, yellow, green, grey
function GT.SkillBands(key)
    local s = GT.SKILLS[key]
    local band = BANDS[key] or DEFAULT_BAND
    return s[1], s[1] + band[1], s[1] + band[2], s[1] + band[3]
end

-- returns r, g, b, bandName for a node, using YOUR skill
function GT.SkillColor(key)
    local def, s = GT.nodes[key], GT.SKILLS[key]
    if not (def and s) then return 1, 1, 1, "unknown" end
    local mine = PlayerSkill(def.kind == "ore" and "Mining" or "Herbalism")
    local req = s[1]                                  -- for shared nodes (Thorium, Swiftthistle): the easiest one
    local band = BANDS[key] or DEFAULT_BAND
    local name
    if not mine or mine < req then name = "red"
    elseif mine < req + band[1] then name = "orange"
    elseif mine < req + band[2] then name = "yellow"
    elseif mine < req + band[3] then name = "green"
    else name = "grey" end
    local c = COLORS[name]
    return c[1], c[2], c[3], name
end

-- Simple hover tooltip for a node on the world map: two lines (name + skill) in the difficulty colour.
-- Used when "Item tooltip on hover" (Nodes panel) is OFF; when it is ON the full item tooltip is shown instead.
function GT.ShowNodeTooltip(owner, key)
    local def, txt = GT.nodes[key], GT.SkillText(key)
    if not (def and txt) then return end
    local r, g, b = GT.SkillColor(key)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:AddLine(def.label, r, g, b)
    GameTooltip:AddLine(txt, r, g, b)
    if GT.AddSpotNoteTooltip then GT.AddSpotNoteTooltip(owner, key) end
    GameTooltip:Show()
end
