-- SkillEta.lua : how many more gathers (and minutes) until your next Herbalism / Mining skill point.
-- Everything is measured in this session: every gather of a node that can still raise your skill is counted, and every
-- skill point you gain tells how many gathers one point took.  The estimate starts after your first skill-up.
-- Used by the session summary (GT.FormatStats): the minimized bar's gold tooltip, the summary panel and the chat output.
local _, GT = ...
local nodes = GT.nodes

local PROFESSIONS = { "Herbalism", "Mining" }
local PENDING_WINDOW = 3          -- seconds: a skill-up and the gather that caused it arrive within this time of each other

local track = {}                  -- profession -> record, see Entry()

local function Profession(key)
    local def = nodes[key]
    if not def then return nil end
    return def.kind == "ore" and "Mining" or "Herbalism"
end

local function Entry(prof)
    local e = track[prof]
    if not e then
        -- gathers: counted gathers      since: ... since the last skill point
        -- cycles: gathers that were needed for the skill points gained so far      ups: skill points gained
        e = { gathers = 0, since = 0, cycles = 0, ups = 0 }
        track[prof] = e
    end
    return e
end

-- the skill point and the gather that gave it are one cycle: the points are counted at once, the gathers when the cycle ends
local function FinishCycle(e)
    if not e.pendingAt then return end
    e.cycles = e.cycles + e.since
    e.since = 0
    e.pendingAt = nil
end

local function Check(prof)
    local e = track[prof]
    if not e then return end
    local base, max = GT.PlayerSkill(prof, true)         -- trained skill: gear and potions do not count as a skill-up
    if not base then return end
    e.max = max
    if e.base and base > e.base then
        e.ups = e.ups + (base - e.base)
        e.pendingAt = GetTime()
        C_Timer.After(PENDING_WINDOW + 0.1, function()   -- no gather came with it (a quest, a trainer ...): close the cycle anyway
            if e.pendingAt and GetTime() - e.pendingAt >= PENDING_WINDOW then FinishCycle(e) end
        end)
    end
    e.base = base
end

-- called from the events SKILL_LINES_CHANGED / CHAT_MSG_SKILL
function GT.CheckSkillEta()
    for _, prof in ipairs(PROFESSIONS) do Check(prof) end
end

-- once after login: remember the current skill, so the first skill-up of the session is seen
function GT.InitSkillEta()
    for _, prof in ipairs(PROFESSIONS) do
        if GT.PlayerSkill(prof, true) then
            Entry(prof)
            Check(prof)
        end
    end
end

-- one gather visit of node `key` (called from GT.RecordZoneYield)
function GT.NoteSkillGather(key)
    local prof = Profession(key)
    if not prof then return end
    local e = Entry(prof)
    local now = GetTime()
    local causesUp = e.pendingAt and (now - e.pendingAt) < PENDING_WINDOW
    if not causesUp then
        -- grey nodes give no skill points and red ones cannot be gathered: they say nothing about the rate
        local _, _, _, band = GT.SkillColor(key)
        if band == "grey" or band == "red" then return end
    end
    e.gathers = e.gathers + 1
    e.since = e.since + 1
    e.t0 = e.t0 or now
    e.lastT = now
    if causesUp then FinishCycle(e) end
    if not e.base then Check(prof) end
    C_Timer.After(1, function() Check(prof) end)         -- the skill-up message can come a moment after the loot
end

-- Estimate for one profession, or nil when there is nothing to say (no gathers yet, or the skill is at its cap):
--   { skill, nodes, minutes }  nodes / minutes are nil until the first skill-up gives a rate; minutes also needs 3 gathers
function GT.SkillEta(prof)
    local e = track[prof]
    if not (e and e.base and e.gathers > 0) then return nil end
    if e.max and e.max > 0 and e.base >= e.max then return nil end
    local r = { skill = e.base }
    if e.ups > 0 and e.cycles > 0 then
        local perPoint = e.cycles / e.ups
        r.nodes = math.max(1, math.ceil(perPoint - e.since - 0.001))
        if e.gathers >= 3 and e.lastT and e.t0 and e.lastT > e.t0 then
            local secsPerGather = (e.lastT - e.t0) / (e.gathers - 1)    -- time between gathers, idle time after the last one is left out
            r.minutes = math.max(1, math.ceil(r.nodes * secsPerGather / 60))
        end
    end
    return r
end

-- Progress towards a skill goal ("Mining 300", UI\MiniXP.lua): fraction 0..1 from the skill you had when the goal was set,
-- reached (true / false) and the seconds to go at this session's pace (nil until a skill-up gave a rate and 3 gathers were made).
-- nil when the profession is not known (not learned).
local missAt = {}                 -- profession -> GetTime() when it was last not found (not learned): not looked up again at once
function GT.SkillGoalState(prof, target, start)
    local e0 = track[prof]
    local base = e0 and e0.base                          -- kept current by the skill events: no skill list scan each second
    if not base then
        if missAt[prof] and GetTime() - missAt[prof] < 10 then return nil end
        base = GT.PlayerSkill(prof, true)
        if not base then missAt[prof] = GetTime(); return nil end
        missAt[prof] = nil
    end
    if base >= target then return 1, true, nil end
    start = tonumber(start) or (target - 1)
    local span = target - start
    if span <= 0 then return 1, true, nil end
    local partial, eta = 0, nil
    local e = track[prof]
    if e and e.ups > 0 and e.cycles > 0 then
        local perPoint = e.cycles / e.ups
        partial = math.max(0, math.min(0.99, e.since / perPoint))        -- the gathers towards the next point
        if e.gathers >= 3 and e.lastT and e.t0 and e.lastT > e.t0 then
            local secsPerGather = (e.lastT - e.t0) / (e.gathers - 1)
            local gathersLeft = (target - base) * perPoint - e.since
            eta = math.max(0, gathersLeft) * secsPerGather
        end
    end
    return math.max(0, math.min(1, (base - start + partial) / span)), false, eta
end

-- the summary lines, one per profession you gathered this session; nil when there are none
function GT.SkillEtaLines()
    local out
    for _, prof in ipairs(PROFESSIONS) do
        local r = GT.SkillEta(prof)
        if r then
            out = out or {}
            local name = GT.TR(prof)
            if r.nodes and r.minutes then
                out[#out + 1] = GT.TRF("%s %d: next point in ~%d nodes (~%d min)", name, r.skill, r.nodes, r.minutes)
            elseif r.nodes then
                out[#out + 1] = GT.TRF("%s %d: next point in ~%d nodes", name, r.skill, r.nodes)
            else
                out[#out + 1] = GT.TRF("%s %d: gather until a skill-up to get an estimate", name, r.skill)
            end
        end
    end
    return out
end

-- a new session starts counting again; the current skill stays known
function GT.ResetSkillEta()
    for _, e in pairs(track) do
        e.gathers, e.since, e.cycles, e.ups = 0, 0, 0, 0
        e.t0, e.lastT, e.pendingAt = nil, nil, nil
    end
end
