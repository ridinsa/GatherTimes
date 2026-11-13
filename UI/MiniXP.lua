-- MiniXP.lua : hero and pet XP for the minimized bar (UI\MiniBar.lua).
-- Merged in from the old GetXP addon.  The "XP" button after the minimized bar's dropdown (UI\MiniBar.lua) turns
-- XP mode on: the bar then shows the XP information in one line in place of the gathering timers.
-- It shows hero and pet battles to level, XP/hr, time to level, battle timer, pet capped, gold/hr and the latest gain.
-- Which items are on the bar line is chosen in Minimize settings > XP (cfg miniXPHero / miniXPRate / miniXPLevelIn /
-- miniXPRested / miniXPPet, all on by default, and miniXPGold, off by default).
-- Alerts (Minimize settings > XP): miniXPLevelAlert (on by default) when you level up, miniXPAlmost (off by default)
-- once per level when only miniXPAlmostN (default 5) battles are left.
-- Goal (Minimize settings > XP boxes, or /gt xp goal 500 gold | level 40 | 500 gold, level 40 | off): per character a gold goal, a level goal,
-- a skill goal (Mining / Herbalism) or any mix, plus optional hours to reach them (pace colours).  A thin strip along the bottom of the bar (UI\MiniBar.lua calls XP.UpdateGoalBar) and an item on the XP line
-- show the progress; a message and sound fire once when it is reached.  The goal is saved.
-- Session history: when an XP session ends (/gt xp reset, or the next login after more than RESUME_SECS) its date, main zone,
-- XP/hr and gold/hr are kept (last MAX_HISTORY per character) and listed in the XP button's tooltip with a "best session" line.
-- A /reload or quick relog continues the XP session, so a reload does not split it in two.
-- Idle time (standing still for more than 2 minutes) is left out of XP/hr, time to level and the goal pace: miniXPIdle (on by default).
-- Tracking runs all the time.  The numbers of the session in progress are saved only in that way (at logout).
local _, GT = ...
local XP = {}
GT.MiniXP = XP

local on = false                                -- XP mode (not saved; picking an item in the dropdown turns it off)
local GOLD, PINK, GREY, RED = "|cffffd700", "|cffff69b4", "|cff888888", "|cffff3333"
local SEP = GREY .. "  ||  |r"                  -- "||" is a literal "|" in WoW text
local FLAT = "Interface\\Buttons\\WHITE8X8"
local GOAL, DONE = "|cff66ccff", "|cff33ff66"      -- goal in progress / goal reached
local MAX_HISTORY, SHOWN_HISTORY = 10, 5           -- sessions kept per character / sessions listed in the tooltip
local MIN_SESSION = 300                            -- a session shorter than this (seconds), or with no XP and no gold, is not kept
local RESUME_SECS = 600                            -- a /reload or relog within this long continues the XP session

local function Secret(v)
    return (issecretvalue and issecretvalue(v)) and true or false
end

-- an option that is on unless the player turned it off
local function Opt(key)
    local c = GT.cfg and GT.cfg()
    return not (c and c[key] == false)
end

-- gold per hour (copper) as text ("12.5" / "130"), nil without a value
local function GoldText(perHour)
    if not perHour then return nil end
    local g = perHour / 10000
    if g >= 100 then return string.format("%d", math.floor(g + 0.5)) end
    return string.format("%.1f", g)
end

-- gold per hour of this session as text, nil during the first minute of the session
local function GoldRateText()
    return GoldText(GT.SessionGoldPerHour and GT.SessionGoldPerHour())
end

-- ---------------------------------------------------------------- state
local st = {
    sessionStart = GetTime(),
    heroSession = 0, petSession = 0, gains = 0,             -- session totals
    heroBattles = 0, heroBattleXP = 0, heroCombatXP = 0,    -- finished battles / XP of the battle now
    petBattles = 0, petBattleXP = 0, petCombatXP = 0,
    oldHero = nil, oldPet = nil, lastHeroMax = 0,           -- last seen values (nil = not read yet)
    combatStart = nil,                                      -- GetTime() of the battle now, nil = not in battle
    lastBattle = nil,                                       -- length of the last battle, seconds
    last = nil,                                             -- text of the latest XP gain (already coloured)
    petCapAlerted = false,
    almostAlerted = false,                                  -- the "close to level" alert fired for this level
    startPos = nil,                                         -- level + XP fraction when the session started (for the goal ETA)
    zone = nil, zoneSince = GetTime(), zoneTime = {},       -- seconds spent per zone, for the session history
    restored = false,                                       -- the saved session was looked at (once per login)
    lastActive = GetTime(),                                 -- last time the player was doing something (see "idle time" below)
    idleFrom = nil,                                         -- GetTime() where the idle stretch now going on began to not count
    idleTotal = 0,                                          -- seconds of finished idle stretches in this session
}

-- ---------------------------------------------------------------- formatting and numbers
local function FormatNumber(n)
    if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
    if n >= 10000 then return string.format("%.1fk", n / 1000) end
    return string.format("%d", math.floor(n))
end

local function FormatDuration(sec)                          -- 2h 03m / 4m 05s / 9s
    if not sec or sec ~= sec or sec == math.huge then return "--" end
    sec = math.floor(sec + 0.5)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, sec % 60) end
    return string.format("%ds", sec)
end

local function FormatClock(sec)                             -- mm:ss.s, the battle timer
    return string.format("%02d:%04.1f", math.floor(sec / 60), sec % 60)
end

-- ---------------------------------------------------------------- idle time
-- Time spent standing still (no moving, fighting, casting, looting or XP) for longer than IDLE_SECS is left out of XP per hour,
-- time to level and the goal pace, so an AFK break in a city does not drag the numbers down.  The first IDLE_SECS of a pause
-- still count (a short rest between pulls is part of the grind).  Minimize settings > XP > "Ignore idle time" (on by default).
local IDLE_SECS = 120
local idleLog = {}                                          -- { from, to } finished idle stretches (GetTime), kept for the rolling rate

-- the player does something: an idle stretch that was going on ends and is added to the total
local function Touch()
    local now = GetTime()
    if st.idleFrom then
        if now > st.idleFrom then
            st.idleTotal = st.idleTotal + (now - st.idleFrom)
            idleLog[#idleLog + 1] = { st.idleFrom, now }
        end
        st.idleFrom = nil
    end
    st.lastActive = now
end

-- moving (also mounted or on a flight path), in combat, casting or channelling (gathering is a cast)
local function PlayerBusy()
    local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
    if Secret(speed) or (type(speed) == "number" and speed > 0) then return true end
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return true end
    if UnitCastingInfo and UnitCastingInfo("player") then return true end
    if UnitChannelInfo and UnitChannelInfo("player") then return true end
    return false
end

local function IdleSample()
    if PlayerBusy() then
        Touch()
    elseif not st.idleFrom then
        local now = GetTime()
        if now - st.lastActive >= IDLE_SECS then st.idleFrom = st.lastActive + IDLE_SECS end
    end
end

-- session seconds without the idle time (the whole elapsed time when the option is off)
local function ActiveElapsed()
    local now = GetTime()
    local e = now - st.sessionStart
    local c = GT.cfg and GT.cfg()
    if c and c.miniXPIdle == false then return e end
    e = e - st.idleTotal
    if st.idleFrom and now > st.idleFrom then e = e - (now - st.idleFrom) end
    return math.max(0, e)
end

-- idle seconds inside the last `span` seconds (for the rolling rate)
local function IdleWithin(span)
    local c = GT.cfg and GT.cfg()
    if c and c.miniXPIdle == false then return 0 end
    local now = GetTime()
    local from, sum = now - span, 0
    local keep = 1
    for i = 1, #idleLog do
        local a, b = idleLog[i][1], idleLog[i][2]
        if b > from then
            sum = sum + (b - math.max(a, from))
            idleLog[keep] = idleLog[i]
            keep = keep + 1
        end
    end
    for i = keep, #idleLog do idleLog[i] = nil end
    if st.idleFrom and now > st.idleFrom then sum = sum + (now - math.max(st.idleFrom, from)) end
    return sum
end

local function SessionRate()                                -- hero XP per hour, nil while there is too little data
    local elapsed = ActiveElapsed()
    if elapsed < 30 or st.heroSession <= 0 then return nil end
    return st.heroSession / (elapsed / 3600)
end

-- XP per hour over the last ROLL_SECS (10 minutes), so a slow start or a long break does not drag the number for hours.
-- While the session (or the log, after a /reload) is younger than that, it is the same as the session average.
local ROLL_SECS = 600
local gainLog, logStart = {}, GetTime()                     -- { time, xp } per gain, oldest first
local function LogGain(xp)
    if xp and xp > 0 then gainLog[#gainLog + 1] = { GetTime(), xp } end
end

local function RollingRate()
    local now = GetTime()
    local drop, n = 0, #gainLog
    while drop < n and gainLog[drop + 1][1] < now - ROLL_SECS do drop = drop + 1 end
    if drop > 0 then
        for i = 1, n - drop do gainLog[i] = gainLog[i + drop] end
        for i = n - drop + 1, n do gainLog[i] = nil end
    end
    local span = math.min(ROLL_SECS, now - math.max(st.sessionStart, logStart))
    span = span - IdleWithin(span)
    if span < 30 or st.heroSession <= 0 then return nil end
    local sum = 0
    for i = 1, #gainLog do sum = sum + gainLog[i][2] end
    return sum / (span / 3600)
end

-- battles until the next level, from the average of the battles so far (or the battle now)
local function BattlesLeft(cur, max, battles, battleXP, combatXP)
    if not cur or not max or max <= 0 or Secret(cur) or Secret(max) then return nil end
    local avg = 0
    if battles > 0 and battleXP > 0 then avg = battleXP / battles
    elseif combatXP > 0 then avg = combatXP end
    if avg <= 0 then return nil end
    return math.max(1, math.ceil((max - cur) / avg))
end

-- hunter pets stop gaining XP once they reach the level of their owner
local function IsPetCapped()
    local _, classFile = UnitClass("player")
    if classFile ~= "HUNTER" then return false end
    if not UnitExists("pet") or UnitIsDead("pet") then return false end
    local petLevel, heroLevel = UnitLevel("pet"), UnitLevel("player")
    return (petLevel and heroLevel and petLevel >= heroLevel) and true or false
end

local recent = {}                                           -- the last 5 gains, newest first (coloured text)
local function Note(text)
    st.last = text
    table.insert(recent, 1, text)
    if #recent > 5 then recent[#recent] = nil end
end

local function CheckPetCap()
    local capped = IsPetCapped()
    if capped and not st.petCapAlerted then
        st.petCapAlerted = true
        -- chat message (no sound), once per cap; follows "Show pet capped warning", not the XP button
        if Opt("miniXPPet") then
            GT.cprint(RED .. GT.TR("Your pet is at your level and will not gain more XP until you level up.") .. "|r")
        end
    elseif not capped then
        st.petCapAlerted = false
    end
end

-- rested XP (the pool that doubles kills while it lasts): amount and percent of the level
local function Rested()
    local amt = GetXPExhaustion and GetXPExhaustion() or nil
    local max = UnitXPMax("player")
    if not amt or Secret(amt) or not max or max <= 0 then return 0, 0 end
    return amt, math.floor(amt / max * 100 + 0.5)
end

-- average hero XP per finished battle (about one kill), nil until there is one
local function AvgPerBattle()
    if st.heroBattles <= 0 or st.heroBattleXP <= 0 then return nil end
    return st.heroBattleXP / st.heroBattles
end

-- ---------------------------------------------------------------- saved data per character (goal, history, live session)
local function Num(v)
    return (type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge) and v or 0
end

local function CharKey()
    local name = UnitName("player")
    if not name then return nil end
    return name .. "-" .. (GetRealmName() or "")
end

-- GatherTimesDB._cfg[field][character]: returns the table of that field and this character's key, nil while the saved data is not ready
local function Slot(field)
    local c = GatherTimesDB and GT.cfg and GT.cfg()
    local key = CharKey()
    if type(c) ~= "table" or not key then return nil end
    if type(c[field]) ~= "table" then c[field] = {} end
    return c[field], key
end

-- level plus the fraction of the level (39.5 = half way from 39 to 40), nil when the game hides the numbers
local function LevelPos()
    local level = UnitLevel("player")
    if not level or level <= 0 then return nil end
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if Secret(cur) or Secret(max) then return nil end
    if cur and max and max > 0 then return level + cur / max end
    return level
end

-- ---------------------------------------------------------------- zones (the main zone of a session)
local function ZoneName()
    local z = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText())
    if type(z) ~= "string" or z == "" then return nil end
    return z
end

-- credit the time since the last call to the zone we were in, then note the zone we are in now
local function ZoneTick()
    local now = GetTime()
    if st.zone then st.zoneTime[st.zone] = (st.zoneTime[st.zone] or 0) + (now - st.zoneSince) end
    st.zoneSince = now
    st.zone = ZoneName() or st.zone
end

local function MainZone()
    local zone, best = st.zone, -1
    for z, secs in pairs(st.zoneTime) do
        if secs > best then zone, best = z, secs end
    end
    return zone
end

-- ---------------------------------------------------------------- session history
local function History()
    local t, key = Slot("xpHistory")
    if not t then return nil end
    if type(t[key]) ~= "table" then t[key] = {} end
    return t[key]
end

-- the numbers of the session now (gold/hr is the one the gold summary shows: copper per hour, nil in the first minute)
local function SessionEntry()
    ZoneTick()
    return { t = time(), dur = ActiveElapsed(), xp = st.heroSession, zone = MainZone(),
             gold = GT.SessionGoldPerHour and GT.SessionGoldPerHour() or nil }
end

-- keep a finished session (newest first, MAX_HISTORY of them); too short or empty ones are dropped
local function AddHistory(e)
    if type(e) ~= "table" then return end
    local dur, xp, gold = Num(e.dur), Num(e.xp), Num(e.gold)
    if dur < MIN_SESSION or (xp <= 0 and gold <= 0) then return end
    local list = History()
    if not list then return end
    table.insert(list, 1, { t = math.floor(Num(e.t)), dur = math.floor(dur), xp = math.floor(xp),
        gold = gold > 0 and math.floor(gold) or nil, zone = type(e.zone) == "string" and e.zone or nil })
    while #list > MAX_HISTORY do table.remove(list) end
end

-- XP per hour and gold per hour (copper) of a kept session
local function Rates(e)
    local hours = Num(e.dur) / 3600
    if hours <= 0 then return 0, 0 end
    return Num(e.xp) / hours, Num(e.gold)
end

-- "11 Nov  Elwynn Forest  41.2k XP/hr  12.5 g/hr  1h 05m"
local function HistoryLine(e)
    local xph, gph = Rates(e)
    local when = "--"
    if Num(e.t) > 0 then
        local ok, text = pcall(date, "%d %b", e.t)
        if ok and text then when = text end
    end
    return string.format("%s  %s  %s %s  %s g/hr  %s", when, type(e.zone) == "string" and e.zone or "?",
        xph > 0 and FormatNumber(xph) or "--", GT.TR("XP/hr"), gph > 0 and GoldText(gph) or "--", FormatDuration(Num(e.dur)))
end

-- the best kept session: the highest XP per hour, or the highest gold per hour when none of them has XP
local function BestSession(list)
    local bestX, bestXv, bestG, bestGv = nil, 0, nil, 0
    for _, e in ipairs(list) do
        if type(e) == "table" then
            local x, g = Rates(e)
            if x > bestXv then bestX, bestXv = e, x end
            if g > bestGv then bestG, bestGv = e, g end
        end
    end
    return bestX or bestG
end

-- ---------------------------------------------------------------- the session in progress survives a /reload
-- At logout (a reload is a logout too) the numbers are saved.  At the next login a save younger than RESUME_SECS is picked
-- up again; an older one is the end of the last session and goes into the history.
local function SaveLive()
    local t, key = Slot("xpLive")
    if not t then return end
    local e = SessionEntry()
    e.pet, e.gains = st.petSession, st.gains
    e.heroBattles, e.heroBattleXP = st.heroBattles, st.heroBattleXP
    e.petBattles, e.petBattleXP = st.petBattles, st.petBattleXP
    e.startPos = st.startPos
    e.zones = {}
    for z, secs in pairs(st.zoneTime) do e.zones[z] = math.floor(secs) end
    t[key] = e
end

local GetGoals, SetGoals, DropReachedGoals                  -- defined in the goal section below

local function RestoreLive()
    if st.restored then return end
    local t, key = Slot("xpLive")
    if not t then return end                                -- saved data not ready: try again at the next event
    st.restored = true
    DropReachedGoals()                                       -- goals reached last session do not carry over
    local live = t[key]
    t[key] = nil
    if type(live) ~= "table" then return end
    local gap = time() - Num(live.t)
    local c = GT.cfg()
    if gap >= -60 and gap <= RESUME_SECS and not c.newSessionOnLogin then
        st.sessionStart = GetTime() - math.max(0, Num(live.dur))   -- dur is already without idle time
        st.idleTotal, st.idleFrom, st.lastActive = 0, nil, GetTime()
        wipe(idleLog)
        st.heroSession, st.petSession, st.gains = Num(live.xp), Num(live.pet), Num(live.gains)
        st.heroBattles, st.heroBattleXP = Num(live.heroBattles), Num(live.heroBattleXP)
        st.petBattles, st.petBattleXP = Num(live.petBattles), Num(live.petBattleXP)
        st.startPos = type(live.startPos) == "number" and live.startPos or nil
        if type(live.zones) == "table" then
            for z, secs in pairs(live.zones) do
                if type(z) == "string" and type(secs) == "number" then st.zoneTime[z] = secs end
            end
        end
    else
        AddHistory(live)
    end
end

-- ---------------------------------------------------------------- goal
-- one saved record per character, with any of these parts:
--   gold  = { target = 500 }                                        gold looted this session (the gold summary's numbers)
--   level = { target = 40, startPos = <LevelPos when set> }         reach a level
--   skill = { prof = "Mining", target = 300, startSkill = 212 }     reach a Mining / Herbalism skill
--   by    = <time() of the deadline>                                optional: finish all of them within so many hours
-- every goal gets done = true once its "goal reached" message was shown.  Older saves ({ kind = "level" | "gold",
-- target = N }) are converted when they are read.  The goals share the one line along the bottom of the bar: one goal
-- is the full line, two or three divide it in equal parts (gold, level, skill from the left).
local KIND_COLOR = { gold = { 1, 0.82, 0 }, level = { 0.4, 0.8, 1 }, skill = { 0.75, 0.5, 1 } }
local PACE_TIGHT = 1.25          -- needs up to 25 % more time than is left: orange; more than that: red
local PROFS = { "Mining", "Herbalism" }

local function GoalStore()
    local t, key = Slot("xpGoal")
    local g = t and t[key]
    if type(g) ~= "table" then return nil end
    if g.kind then
        local n = {}
        if g.kind == "level" then n.level = { target = g.target, startPos = g.startPos, done = g.done }
        elseif g.kind == "gold" then n.gold = { target = g.target, done = g.done } end
        t[key] = n
        g = n
    end
    return g, t, key
end

-- the goals in drawing order: gold, level, skill
function GetGoals()
    local list = {}
    local store = GoalStore()
    if not store then return list end
    local gd, lv, sk = store.gold, store.level, store.skill
    if type(gd) == "table" and type(gd.target) == "number" and gd.target > 0 then
        gd.kind = "gold"
        list[#list + 1] = gd
    end
    if type(lv) == "table" and type(lv.target) == "number" and lv.target > 0 then
        lv.kind = "level"
        if type(lv.startPos) ~= "number" then lv.startPos = LevelPos() or (UnitLevel("player") or 1) end
        list[#list + 1] = lv
    end
    if type(sk) == "table" and type(sk.target) == "number" and sk.target > 0
        and (sk.prof == "Mining" or sk.prof == "Herbalism") then
        sk.kind = "skill"
        if type(sk.startSkill) ~= "number" then
            sk.startSkill = (GT.PlayerSkill and GT.PlayerSkill(sk.prof, true)) or (sk.target - 1)
        end
        list[#list + 1] = sk
    end
    return list
end

-- the deadline (time() value) while there is a goal, else nil
local function GoalBy()
    local store = GoalStore()
    if store and type(store.by) == "number" and (store.gold or store.level or store.skill) then return store.by end
    return nil
end

local function GoalLabel(g)
    if g.kind == "level" then return GT.TRF("Level %d", g.target) end
    if g.kind == "skill" then return GT.TR(g.prof) .. " " .. g.target end
    return string.format("%dg", g.target)
end

-- progress 0..1, reached (true / false), seconds to go at the pace of this session (nil while unknown); nil when not readable now
local function GoalState(g)
    if g.kind == "skill" then
        if not GT.SkillGoalState then return nil end
        return GT.SkillGoalState(g.prof, g.target, g.startSkill)
    end
    if g.kind == "level" then
        if (UnitLevel("player") or 0) >= g.target then return 1, true, nil end
        local pos = LevelPos()
        if not pos then return nil end
        local span = g.target - g.startPos
        if span <= 0 then return 1, true, nil end
        local frac = math.max(0, math.min(1, (pos - g.startPos) / span))
        local eta
        local roll, max = RollingRate(), UnitXPMax("player")
        if roll and roll > 0 and max and not Secret(max) and max > 0 then
            eta = (g.target - pos) / (roll / max) * 3600              -- levels per hour from the last 10 minutes
        else
            local elapsed = ActiveElapsed()
            if st.startPos and elapsed >= 60 and pos > st.startPos then
                eta = (g.target - pos) / ((pos - st.startPos) / elapsed)
            end
        end
        return frac, false, eta
    end
    local copper = GT.SessionGoldCopper and GT.SessionGoldCopper() or 0
    local need = g.target * 10000
    if copper >= need then return 1, true, nil end
    local rate = GT.SessionGoldPerHour and GT.SessionGoldPerHour()
    local eta = (rate and rate > 0) and ((need - copper) / (rate / 3600)) or nil
    return copper / need, false, eta
end

-- with a deadline: "ok" (the time to go fits in the time left), "tight", "late"; nil without a deadline, when reached, or
-- while the pace is unknown (and the time is not up yet)
local function Pace(done, eta)
    local by = GoalBy()
    if not by or done then return nil end
    local left = by - time()
    if left <= 0 then return "late" end
    if not eta then return nil end
    local ratio = eta / left
    if ratio <= 1 then return "ok" end
    if ratio <= PACE_TIGHT then return "tight" end
    return "late"
end
local PACE_TEXT = {
    ok    = { "|cff33ff66", "on pace" },
    tight = { "|cffffa500", "tight" },
    late  = { "|cffff4040", "behind" },
}

-- the goals as one coloured piece of text for the XP line, the tooltips and the chat; nil without a goal
local function GoalPart()
    local pending, reached = {}, {}
    for _, g in ipairs(GetGoals()) do
        local frac, done, eta = GoalState(g)
        if frac then
            if done then
                reached[#reached + 1] = DONE .. GT.TRF("Goal reached: %s", GoalLabel(g)) .. "|r"
            else
                local text = GoalLabel(g) .. " " .. math.floor(frac * 100) .. "%"
                if eta then text = text .. " ~" .. FormatDuration(eta) end
                local pace = PACE_TEXT[Pace(false, eta) or ""]
                if pace then text = text .. " " .. pace[1] .. GT.TR(pace[2]) .. GOAL end
                pending[#pending + 1] = text
            end
        end
    end
    local out = {}
    if #pending > 0 then
        local line = GOAL .. GT.TR("Goal") .. " " .. table.concat(pending, "  ")
        local by = GoalBy()
        if by then
            local left = by - time()
            line = line .. "  " .. (left > 0 and (FormatDuration(left) .. " " .. GT.TR("left")) or GT.TR("time is up"))
        end
        out[1] = line .. "|r"
    end
    for _, r in ipairs(reached) do out[#out + 1] = r end
    if #out == 0 then return nil end
    return table.concat(out, "  ")
end

-- the goals that are still running, as the numbers the boxes show: { gold, level, skill = { prof, target }, by }
local function CurrentState()
    local cur = {}
    for _, g in ipairs(GetGoals()) do
        if not g.done then
            if g.kind == "gold" then cur.gold = g.target
            elseif g.kind == "level" then cur.level = g.target
            else cur.skill = { prof = g.prof, target = g.target } end
        end
    end
    cur.by = GoalBy()
    return cur
end

-- sets the goals from { gold, level, skill = { prof, target }, by }; nothing in it clears the goal
function SetGoals(s)
    local t, key = Slot("xpGoal")
    if not t then return false end
    s = s or {}
    if not (s.gold or s.level or s.skill) then
        t[key] = nil
    else
        local old = GoalStore()
        local n = {}
        if s.gold then n.gold = { target = s.gold } end
        if s.level then
            local keep = old and old.level and old.level.target == s.level and not old.level.done and old.level.startPos
            n.level = { target = s.level, startPos = keep or LevelPos() or (UnitLevel("player") or 1) }
        end
        if s.skill then
            local o = old and old.skill
            local keep = o and o.prof == s.skill.prof and o.target == s.skill.target and not o.done and o.startSkill
            local base = GT.PlayerSkill and GT.PlayerSkill(s.skill.prof, true)
            n.skill = { prof = s.skill.prof, target = s.skill.target, startSkill = keep or base or (s.skill.target - 1) }
        end
        if s.by then n.by = s.by end
        t[key] = n
    end
    if GT.bar then GT:UpdateMiniBar() end
    return true
end

-- at the start of the next session: parts that were reached are dropped, the others carry on
function DropReachedGoals()
    local store, t, key = GoalStore()
    if not store then return end
    for _, part in ipairs({ "gold", "level", "skill" }) do
        if type(store[part]) == "table" and store[part].done then store[part] = nil end
    end
    if not store.gold and not store.level and not store.skill then t[key] = nil end
end

-- the message, the sound and the chat line once per goal, when it is reached
local function CheckGoal()
    for _, g in ipairs(GetGoals()) do
        local frac, done = GoalState(g)
        if frac then
            if done then
                if not g.done then
                    g.done = true
                    local msg = GT.TRF("Goal reached: %s", GoalLabel(g))
                    GT.cprint(DONE .. msg .. "|r")
                    pcall(GT.ShowScreenAlert, msg, 0.2, 1, 0.4)
                    -- a level goal already has the level-up sound, unless that alert is off
                    if g.kind ~= "level" or not Opt("miniXPLevelAlert") then pcall(PlaySound, 888, "Master") end
                end
            elseif g.done and g.kind == "gold" then
                g.done = nil                                    -- the gold session was reset: the goal counts again
            end
        end
    end
end

-- the Settings boxes (UI\Panels\PanelMinimize.lua): gold and level are plain numbers, skill is "mining 300",
-- "by" is the hours left to reach the goals
function XP.GoalBoxText(kind)
    if kind == "by" then
        local by = GoalBy()
        if not by then return "" end
        local left = (by - time()) / 3600
        if left <= 0 then return "0" end
        return (string.format("%.1f", left):gsub("%.0$", ""))
    end
    for _, g in ipairs(GetGoals()) do
        if g.kind == kind then
            if kind == "skill" then return g.prof:lower() .. " " .. g.target end
            return tostring(g.target)
        end
    end
    return ""
end

-- sets (or, with empty text / "off" / 0, clears) one part of the goal and keeps the others as they are
function XP.SetGoalPart(kind, text)
    text = (text or ""):lower()
    local cur = CurrentState()
    local clear = text:match("^%s*$") or text:find("off", 1, true)
    local n = tonumber((text:gsub(",", "."):match("%d+%.?%d*")))
    if n == 0 then clear = true end

    if kind == "by" then
        if clear then
            cur.by = nil
        else
            if not n or n > 240 then
                GT.cprint(GT.TR("Type the hours you have, for example 2 or 1.5."))
                return false
            end
            if not (cur.gold or cur.level or cur.skill) then
                GT.cprint(GT.TR("Set a goal first, then the hours."))
                return false
            end
            cur.by = time() + n * 3600
        end
    elseif kind == "skill" then
        if clear then
            cur.skill = nil
        else
            local letters = text:gsub("[^%a]", "")
            local prof = letters:find("^m") and "Mining" or (letters:find("^h") and "Herbalism") or nil
            if not prof or not n then
                GT.cprint(GT.TR("Type a profession and a skill, for example mining 300 or herb 225."))
                return false
            end
            n = math.floor(n)
            local base, max
            if GT.PlayerSkill then base, max = GT.PlayerSkill(prof, true) end
            if not base then
                GT.cprint(GT.TRF("You do not have %s.", GT.TR(prof)))
                return false
            end
            if n <= base or (max and max > 0 and n > max) then
                GT.cprint(GT.TRF("Goal skill must be above your skill (%d) and at most %d.", base, (max and max > 0) and max or 300))
                return false
            end
            cur.skill = { prof = prof, target = n }
        end
    elseif kind == "level" then
        if clear then
            cur.level = nil
        else
            if not n then
                GT.cprint(GT.TR("Type a level number, for example 40."))
                return false
            end
            n = math.floor(n)
            local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL or 100
            if n <= (UnitLevel("player") or 0) or n > maxLevel then
                GT.cprint(GT.TRF("Goal level must be above your level and at most %d.", maxLevel))
                return false
            end
            cur.level = n
        end
    else
        if clear then
            cur.gold = nil
        else
            if not n then
                GT.cprint(GT.TR("Type an amount of gold, for example 500."))
                return false
            end
            n = math.floor(n)
            if n < 1 or n > 1000000 then
                GT.cprint(GT.TR("Goal gold must be a whole number from 1 to 1000000."))
                return false
            end
            cur.gold = n
        end
    end
    return SetGoals(cur)
end

-- reads "500 gold", "500g", "level 40", "500 gold, level 40" ...  Returns gold, level (either may be nil), or nil, nil when the text is not a goal
local GOLD_PATS = { "(%d+)%s*gold", "gold%s*(%d+)", "(%d+)%s*g%f[%A]", "%f[%a]g%s*(%d+)" }
local LEVEL_PATS = { "level%s*(%d+)", "lvl%s*(%d+)", "lv%s*(%d+)", "(%d+)%s*level", "(%d+)%s*lvl", "%f[%a]l%s*(%d+)" }
local function ParseGoal(arg)
    local s = arg:lower()
    local gold, level
    for _, pat in ipairs(GOLD_PATS) do
        local v = s:match(pat)
        if v then gold = tonumber(v); s = s:gsub(pat, " ", 1); break end
    end
    for _, pat in ipairs(LEVEL_PATS) do
        local v = s:match(pat)
        if v then level = tonumber(v); s = s:gsub(pat, " ", 1); break end
    end
    s = s:gsub("%f[%a]and%f[%A]", " ")
    if not (gold or level) or not s:match("^[%s,;+&]*$") then return nil, nil end    -- nothing left over but separators
    return gold, level
end

-- /gt xp goal <500 gold | level 40 | 500 gold, level 40 | off>   (the skill goal and the hours are set in the Settings)
local function GoalCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local USAGE = "No goal set. Try /gt xp goal 500 gold, /gt xp goal level 40 or /gt xp goal 500 gold, level 40."
    if arg == "" then
        local text = GoalPart()
        GT.cprint(text and (GT.TR("Goal") .. ": " .. text) or GT.TR(USAGE))
        return
    end
    if arg == "off" or arg == "clear" or arg == "none" or arg == "0" then
        if SetGoals(nil) then GT.cprint(GT.TR("Goal cleared.")) end
        return
    end
    local gold, level = ParseGoal(arg)
    if not gold and not level then
        GT.cprint(GT.TR(USAGE))
        return
    end
    if gold then
        if not XP.SetGoalPart("gold", tostring(gold)) then return end
    end
    if level then
        if not XP.SetGoalPart("level", tostring(level)) then return end
    end
    local labels = {}
    for _, g in ipairs(GetGoals()) do labels[#labels + 1] = GoalLabel(g) end
    GT.cprint(GT.TRF("Goal set: %s.", table.concat(labels, ", ")))
end

-- the progress strip along the bottom edge of the bar (called by UI\MiniBar.lua on every refresh, in both modes).
-- One goal: the strip is one full-width line.  Two or three goals: the same strip is divided into parts of the same width
-- (gold, level, skill from the left), each filling in its own colour.  With a deadline a part turns orange when it is
-- tight and red when it is behind; reached goals are green.
function XP.UpdateGoalBar(f)
    local bars = {}
    for _, g in ipairs(GetGoals()) do
        local frac, done, eta = GoalState(g)
        if frac then bars[#bars + 1] = { frac = frac, done = done, kind = g.kind, pace = Pace(done, eta) } end
    end
    f.goalLines = f.goalLines or {}
    local n = #bars
    local gap = (n > 1) and 2 or 0                          -- a small gap between the parts
    local segW = n > 0 and math.max(1, (f:GetWidth() - gap * (n - 1)) / n) or 0
    for i = 1, math.max(n, #f.goalLines) do
        local line, bar = f.goalLines[i], bars[i]
        if bar and not line then
            line = {}
            line.bg = f:CreateTexture(nil, "ARTWORK")
            line.bg:SetTexture(FLAT)
            line.bg:SetVertexColor(1, 1, 1, 0.12)
            line.fill = f:CreateTexture(nil, "OVERLAY")
            line.fill:SetTexture(FLAT)
            f.goalLines[i] = line
        end
        if bar then
            local x = (i - 1) * (segW + gap)
            line.bg:ClearAllPoints()
            line.bg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 0)
            line.bg:SetSize(segW, 2)                        -- the chips start 2 px above the bottom edge: nothing is covered
            line.fill:ClearAllPoints()
            line.fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 0)
            line.fill:SetSize(math.max(1, segW * bar.frac), 2)
            if bar.done then line.fill:SetVertexColor(0.2, 1, 0.4, 1)
            elseif bar.pace == "late" then line.fill:SetVertexColor(1, 0.25, 0.25, 1)
            elseif bar.pace == "tight" then line.fill:SetVertexColor(1, 0.55, 0, 1)
            else
                local c = KIND_COLOR[bar.kind] or KIND_COLOR.level
                line.fill:SetVertexColor(c[1], c[2], c[3], 1)
            end
            line.bg:Show()
            line.fill:Show()
        elseif line then
            line.bg:Hide()
            line.fill:Hide()
        end
    end
end

-- the goal for the tooltip of the gold text (UI\MiniBar.lua)
function XP.GoalSummary() return GoalPart() end

-- ---------------------------------------------------------------- the one-line text for the bar
-- on the bar: hero battles to level | XP/hr | level in | rested | pet capped.  The rest is in XP.ShowTip.
function XP.LineText()
    local parts = {}
    local rate = SessionRate()
    local roll = rate and RollingRate()                      -- last 10 minutes; the session average stays next to it
    local cur, max = UnitXP("player"), UnitXPMax("player")

    if Opt("miniXPHero") then
        local h = BattlesLeft(cur, max, st.heroBattles, st.heroBattleXP, st.heroCombatXP)
        parts[#parts + 1] = GOLD .. GT.TR("Hero") .. " " .. (h and (h .. " " .. GT.TR("battles")) or "?") .. "|r"
    end

    if rate then
        if Opt("miniXPRate") then
            local text = GOLD .. FormatNumber(roll or rate) .. " " .. GT.TR("XP/hr") .. "|r"
            if roll and ActiveElapsed() > ROLL_SECS + 30 then      -- shorter sessions: both numbers are the same
                text = text .. GREY .. " (" .. GT.TR("avg") .. " " .. FormatNumber(rate) .. ")|r"
            end
            parts[#parts + 1] = text
        end
        local levelRate = (roll and roll > 0) and roll or rate
        if Opt("miniXPLevelIn") and cur and max and max > 0 and not Secret(cur) and not Secret(max) then
            parts[#parts + 1] = "|cff00ffff" .. GT.TR("level in") .. " " .. FormatDuration((max - cur) / (levelRate / 3600)) .. "|r"
        end
    elseif Opt("miniXPRate") then
        parts[#parts + 1] = GREY .. GT.TR("XP/hr") .. " --|r"
    end

    local c = GT.cfg and GT.cfg()
    if c and c.miniXPGold == true then
        local g = GoldRateText()
        parts[#parts + 1] = g and (GOLD .. g .. " g/hr|r") or (GREY .. "g/hr --|r")
    end

    if Opt("miniXPRested") then
        local _, pct = Rested()
        if pct > 0 then
            parts[#parts + 1] = "|cff00ffff" .. GT.TR("rested") .. " " .. pct .. "%|r"
        else
            parts[#parts + 1] = GREY .. GT.TR("rested") .. " 0%|r"
        end
    end

    local goalText = GoalPart()
    if goalText then parts[#parts + 1] = goalText end

    if Opt("miniXPPet") and IsPetCapped() then parts[#parts + 1] = RED .. GT.TR("Pet capped") .. "|r" end

    if #parts == 0 then parts[1] = GREY .. GT.TR("XP") .. "|r" end     -- every item turned off: keep the line from going empty
    return table.concat(parts, SEP)
end

-- the XP button's tooltip: everything that is not on the bar.  Refreshed while the mouse is on the button.
function XP.ShowTip(owner)
    local tip = GT.Tip
    tip:SetOwner(owner, "ANCHOR_BOTTOM")
    tip:AddLine(GT.TR("XP"), 1, 0.82, 0)

    tip:AddLine(string.format("%s: %s %s, %s %s, %d %s, %s", GT.TR("Session"),
        GT.TR("hero"), FormatNumber(st.heroSession), GT.TR("pet"), FormatNumber(st.petSession),
        st.gains, GT.TR("gains"), FormatDuration(ActiveElapsed())), 0.85, 0.85, 0.85)
    do
        local c = GT.cfg and GT.cfg()
        local idle = (GetTime() - st.sessionStart) - ActiveElapsed()
        if not (c and c.miniXPIdle == false) and idle >= 60 then
            tip:AddLine(string.format("%s: %s", GT.TR("Idle time not counted"), FormatDuration(idle)), 0.6, 0.6, 0.6)
        end
    end

    local avgRate, rollRate = SessionRate(), RollingRate()
    if avgRate then
        tip:AddLine(string.format("%s: %s %s, %s %s", GT.TR("XP/hr"), FormatNumber(rollRate or avgRate), GT.TR("last 10 min"),
            FormatNumber(avgRate), GT.TR("session average")), 0.85, 0.85, 0.85)
    end

    if GT.SessionGoldText then
        local g = GoldRateText()
        tip:AddLine(string.format("%s: %s%s", GT.TR("Gold"), GT.SessionGoldText(true),
            g and string.format(" (%s g/hr)", g) or ""), 1, 0.82, 0)
    end

    if UnitExists("pet") then
        local pc, pm = GetPetExperience()
        local p = BattlesLeft(pc, pm, st.petBattles, st.petBattleXP, st.petCombatXP)
        tip:AddLine(string.format("%s: %s %s", GT.TR("Pet"), p and tostring(p) or "?", GT.TR("battles to level")), 0.85, 0.85, 0.85)
    end

    if st.combatStart then
        tip:AddLine(string.format("%s %s", GT.TR("In battle:"), FormatClock(GetTime() - st.combatStart)), 0.85, 0.85, 0.85)
    elseif st.lastBattle then
        tip:AddLine(string.format("%s %s", GT.TR("Last battle:"), FormatClock(st.lastBattle)), 0.85, 0.85, 0.85)
    end

    local amt, pct = Rested()
    if pct > 0 then
        local avg = AvgPerBattle()
        local text = string.format("%s: %s (%d%%)", GT.TR("Rested"), FormatNumber(amt), pct)
        if avg then
            text = text .. string.format(", %s %d %s", GT.TR("about"), math.max(1, math.floor(amt / avg)), GT.TR("battles left"))
        end
        tip:AddLine(text, 0.4, 0.9, 1)
    else
        tip:AddLine(GT.TR("Rested: none"), 0.6, 0.6, 0.6)
    end

    local cur, max = UnitXP("player"), UnitXPMax("player")
    if cur and max and max > 0 and not Secret(cur) and not Secret(max) then
        tip:AddLine(string.format("%s: %s %s", GT.TR("To next level"), FormatNumber(max - cur), GT.TR("exp")), 0.85, 0.85, 0.85)
    end

    local goalText = GoalPart()
    if goalText then tip:AddLine(goalText) end

    local list = History()
    if list and #list > 0 then
        tip:AddLine(GT.TR("Session history"), 1, 0.82, 0)
        for i = 1, math.min(#list, SHOWN_HISTORY) do
            if type(list[i]) == "table" then tip:AddLine(HistoryLine(list[i]), 0.85, 0.85, 0.85) end
        end
        local best = #list > 1 and BestSession(list)
        if best then tip:AddLine(GT.TR("Best session") .. ": " .. HistoryLine(best), 0.4, 1, 0.4) end
    end

    if #recent > 0 then
        tip:AddLine(GT.TR("Latest gains"), 1, 0.82, 0)
        for _, text in ipairs(recent) do tip:AddLine(text) end
    end
    tip:Show()
end

function XP.IsOn() return on end
-- "Show XP button" (Minimize settings > XP): the button after the dropdown is shown unless this is off
function XP.ButtonShown()
    local c = GT.cfg and GT.cfg()
    return not (c and c.miniShowXP == false)
end
function XP.SetOn(v) on = v and true or false end

-- ---------------------------------------------------------------- alerts
-- level up: a message on screen and the level-up sound (Minimize settings > XP > "Level-up alert", on by default)
local function FireLevelUp(level)
    st.almostAlerted = false                                -- a new level starts: the "close to level" alert can fire again
    if not Opt("miniXPLevelAlert") then return end
    pcall(GT.ShowScreenAlert, GT.TRF("Level %d!", tonumber(level) or UnitLevel("player")), 1, 0.82, 0)
    pcall(PlaySound, 888, "Master")
end

-- close to level: once per level, when the battles left (from the average of the battles so far) drop to the chosen number
local function CheckAlmost()
    local c = GT.cfg and GT.cfg()
    if not (c and c.miniXPAlmost == true) or st.almostAlerted then return end
    if IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel() then return end
    if GT.AfterLoginOK and not GT.AfterLoginOK() then return end
    local left = BattlesLeft(UnitXP("player"), UnitXPMax("player"), st.heroBattles, st.heroBattleXP, st.heroCombatXP)
    local limit = tonumber(c.miniXPAlmostN) or 5
    if left and left <= limit then
        st.almostAlerted = true
        pcall(GT.ShowScreenAlert, GT.TRF("About %d battles to the next level", left), 0, 1, 1)
        pcall(PlaySound, 3175, "Master")
    end
end

-- ---------------------------------------------------------------- tracking
local function ProcessHeroXP()
    local max = UnitXPMax("player")
    if not max or max == 0 then return end
    local cur = UnitXP("player")
    if Secret(cur) or Secret(max) then return end
    if st.oldHero == nil then st.oldHero = cur; st.lastHeroMax = max; return end
    if cur == st.oldHero and max == st.lastHeroMax then return end

    local level = UnitLevel("player")
    -- a new level: the XP went down, or the level's XP total changed (a big gain can leave more XP than before in the new level)
    if cur < st.oldHero or max ~= st.lastHeroMax then
        -- level up: the rest of the old level plus what carried over
        local got = math.max(0, (st.lastHeroMax - st.oldHero) + cur)
        st.heroSession = st.heroSession + got
        LogGain(got)
        st.gains = st.gains + 1
        Note(GOLD .. GT.TR("level up") .. " " .. level .. "|r")
        C_Timer.After(1, CheckPetCap)
    else
        local got = cur - st.oldHero
        st.heroCombatXP = st.heroCombatXP + got
        st.heroSession = st.heroSession + got
        LogGain(got)
        st.gains = st.gains + 1
        Note(string.format("|cff00ffff+%d %s|r (%d%%)", got, GT.TR("exp"), math.floor(cur / max * 100 + 0.5)))
    end
    st.oldHero = cur
    st.lastHeroMax = max
end

local function ProcessPetXP()
    if not UnitExists("pet") then return end
    local cur, max = GetPetExperience()
    if not cur or not max or max == 0 then return end
    if Secret(cur) or Secret(max) then return end
    if st.oldPet == nil then st.oldPet = cur; return end
    if cur == st.oldPet then return end

    if cur < st.oldPet then
        Note(PINK .. GT.TR("pet level up") .. "|r")
    else
        local got = cur - st.oldPet
        st.petCombatXP = st.petCombatXP + got
        st.petSession = st.petSession + got
        Note(string.format("%s+%d %s|r (%d%%)", PINK, got, GT.TR("pet exp"), math.floor(cur / max * 100 + 0.5)))
    end
    st.oldPet = cur
end

local function BattleStart()
    if st.combatStart then return end
    st.combatStart = GetTime()
    st.heroCombatXP, st.petCombatXP = 0, 0
end

local function BattleStop()
    if not st.combatStart then return end
    st.lastBattle = GetTime() - st.combatStart
    st.combatStart = nil
    if st.heroCombatXP > 0 then
        st.heroBattles = st.heroBattles + 1
        st.heroBattleXP = st.heroBattleXP + st.heroCombatXP
    end
    if st.petCombatXP > 0 then
        st.petBattles = st.petBattles + 1
        st.petBattleXP = st.petBattleXP + st.petCombatXP
    end
    CheckAlmost()
end

-- ---------------------------------------------------------------- events (always on)
local ev = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UNIT_PET_EXPERIENCE", "UNIT_PET",
                        "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                        "ZONE_CHANGED_NEW_AREA", "PLAYER_LOGOUT", "LOOT_OPENED" }) do
    ev:RegisterEvent(name)
end

local function Handle(event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        RestoreLive()                                       -- first time after login: continue or close the saved session
        if not st.startPos then st.startPos = LevelPos() end
        ZoneTick()
        st.oldHero = UnitXP("player")
        st.lastHeroMax = UnitXPMax("player") or 0
        if UnitExists("pet") then st.oldPet = GetPetExperience() end
        C_Timer.After(3, CheckPetCap)
    elseif event == "PLAYER_XP_UPDATE" then
        Touch()
        ProcessHeroXP()
    elseif event == "UNIT_PET_EXPERIENCE" then
        Touch()
        ProcessPetXP()
    elseif event == "LOOT_OPENED" then
        Touch()
    elseif event == "UNIT_PET" then
        if arg1 == "player" then
            st.oldPet = UnitExists("pet") and GetPetExperience() or nil   -- new pet: start from its current XP
            C_Timer.After(1, CheckPetCap)
        end
    elseif event == "PLAYER_LEVEL_UP" then
        FireLevelUp(arg1)
        C_Timer.After(1, CheckPetCap)
        C_Timer.After(1, function() pcall(CheckGoal) end)   -- the level has changed by then
    elseif event == "PLAYER_REGEN_DISABLED" then
        Touch()
        BattleStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Touch()
        BattleStop()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        ZoneTick()
    elseif event == "PLAYER_LOGOUT" then
        SaveLive()
    end
end

ev:SetScript("OnEvent", function(_, event, arg1)
    local ok, err = pcall(Handle, event, arg1)
    if not ok then GT.ReportError("XP " .. event, err) end
end)

-- idle check every 2 seconds (cheap: a few API calls)
local idleErrored = false
C_Timer.NewTicker(2, function()
    local ok, err = pcall(IdleSample)
    if not ok and not idleErrored then idleErrored = true; GT.ReportError("XP idle", err) end
end)

-- a gold goal is reached by looting, not by an XP event: look every few seconds (cheap: one comparison)
local goalErrored = false
C_Timer.NewTicker(3, function()
    if not st.restored then return end                      -- the gold session is not back yet right after login
    local ok, err = pcall(CheckGoal)
    if not ok and not goalErrored then goalErrored = true; GT.ReportError("XP goal", err) end
end)

-- ---------------------------------------------------------------- commands
function XP.Reset()
    AddHistory(SessionEntry())                              -- the session that ends here goes into the history
    st.sessionStart = GetTime()
    st.idleTotal, st.idleFrom, st.lastActive = 0, nil, GetTime()
    wipe(idleLog)
    st.heroSession, st.petSession, st.gains = 0, 0, 0
    wipe(gainLog); logStart = GetTime()
    st.heroBattles, st.heroBattleXP, st.heroCombatXP = 0, 0, 0
    st.petBattles, st.petBattleXP, st.petCombatXP = 0, 0, 0
    st.lastBattle, st.last = nil, nil
    st.almostAlerted = false
    st.startPos = LevelPos()
    wipe(st.zoneTime)
    st.zone = nil
    ZoneTick()
    for i = #recent, 1, -1 do recent[i] = nil end
    st.oldHero = UnitXP("player")
    st.oldPet = UnitExists("pet") and GetPetExperience() or nil
    GT.cprint(GT.TR("XP session reset."))
end

-- /gt xp             : turn XP mode on or off
-- /gt xp reset       : start a new XP session
-- /gt xp session     : session totals in chat
-- /gt xp goal level 40 | 500g | off   : set, show or clear the goal
-- /gt xp history     : the kept sessions in chat
function XP.Slash(rest)
    rest = string.lower(rest or "")
    local cmd, arg = rest:match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "reset" then
        XP.Reset()
    elseif cmd == "goal" then
        GoalCommand(arg)
    elseif cmd == "history" then
        local list = History()
        if not list or #list == 0 then
            GT.cprint(GT.TR("No finished sessions yet."))
        else
            GT.cprint(GT.TR("Session history"))
            for _, e in ipairs(list) do
                if type(e) == "table" then GT.cprint(HistoryLine(e)) end
            end
            local best = #list > 1 and BestSession(list)
            if best then GT.cprint(GT.TR("Best session") .. ": " .. HistoryLine(best)) end
        end
    elseif cmd == "session" then
        local rate = SessionRate()
        GT.cprint(string.format("%s %s %d, %s %d, %d %s, %s/hr", GT.TR("XP session:"),
            GT.TR("hero"), st.heroSession, GT.TR("pet"), st.petSession, st.gains, GT.TR("gains"),
            rate and FormatNumber(rate) or "--"))
    else
        if not XP.ButtonShown() then                        -- the bar turns XP mode off again while the button is hidden
            GT.cprint(GT.TRF("The XP button is hidden. Turn on %s in the Minimize settings.", GT.TR("Show XP button")))
            return
        end
        XP.SetOn(not XP.IsOn())
        if GT.bar then GT:UpdateMiniBar() end
    end
end
