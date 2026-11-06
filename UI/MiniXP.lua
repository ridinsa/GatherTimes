-- MiniXP.lua : hero and pet XP for the minimized bar (UI\MiniBar.lua).
-- Merged in from the old GetXP addon.  The "XP" button after the minimized bar's dropdown (UI\MiniBar.lua) turns
-- XP mode on: the bar then shows the XP information in one line in place of the gathering timers.
-- It shows hero and pet battles to level, XP/hr, time to level, battle timer, pet capped, and the latest gain.
-- Tracking runs all the time.  Nothing is saved between sessions.
local ADDON, GT = ...
local XP = {}
GT.MiniXP = XP

local on = false                                -- XP mode (not saved; picking an item in the dropdown turns it off)
local GOLD, PINK, GREY, RED = "|cffffd700", "|cffff69b4", "|cff888888", "|cffff3333"
local SEP = GREY .. "  ||  |r"                  -- "||" is a literal "|" in WoW text

local function Secret(v)
    return (issecretvalue and issecretvalue(v)) and true or false
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

local function SessionRate()                                -- hero XP per hour, nil while there is too little data
    local elapsed = GetTime() - st.sessionStart
    if elapsed < 30 or st.heroSession <= 0 then return nil end
    return st.heroSession / (elapsed / 3600)
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
        GT.cprint(RED .. GT.TR("Your pet is at your level and will not gain more XP until you level up.") .. "|r")
        PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959)
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

-- ---------------------------------------------------------------- the one-line text for the bar
-- on the bar: hero battles to level | XP/hr | level in | rested | pet capped.  The rest is in XP.ShowTip.
function XP.LineText()
    local parts = {}
    local rate = SessionRate()
    local cur, max = UnitXP("player"), UnitXPMax("player")

    local h = BattlesLeft(cur, max, st.heroBattles, st.heroBattleXP, st.heroCombatXP)
    parts[#parts + 1] = GOLD .. GT.TR("Hero") .. " " .. (h and (h .. " " .. GT.TR("battles")) or "?") .. "|r"

    if rate then
        parts[#parts + 1] = GOLD .. FormatNumber(rate) .. " " .. GT.TR("XP/hr") .. "|r"
        if cur and max and max > 0 and not Secret(cur) and not Secret(max) then
            parts[#parts + 1] = "|cff00ffff" .. GT.TR("level in") .. " " .. FormatDuration((max - cur) / (rate / 3600)) .. "|r"
        end
    else
        parts[#parts + 1] = GREY .. GT.TR("XP/hr") .. " --|r"
    end

    local _, pct = Rested()
    if pct > 0 then
        parts[#parts + 1] = "|cff00ffff" .. GT.TR("rested") .. " " .. pct .. "%|r"
    else
        parts[#parts + 1] = GREY .. GT.TR("rested") .. " 0%|r"
    end

    if IsPetCapped() then parts[#parts + 1] = RED .. GT.TR("Pet capped") .. "|r" end

    return table.concat(parts, SEP)
end

-- the XP button's tooltip: everything that is not on the bar.  Refreshed while the mouse is on the button.
function XP.ShowTip(owner)
    local tip = GT.Tip
    tip:SetOwner(owner, "ANCHOR_BOTTOM")
    tip:AddLine(GT.TR("XP"), 1, 0.82, 0)

    local rate = SessionRate()
    tip:AddLine(string.format("%s: %s %s, %s %s, %d %s, %s", GT.TR("Session"),
        GT.TR("hero"), FormatNumber(st.heroSession), GT.TR("pet"), FormatNumber(st.petSession),
        st.gains, GT.TR("gains"), FormatDuration(GetTime() - st.sessionStart)), 0.85, 0.85, 0.85)

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

-- ---------------------------------------------------------------- tracking
local function ProcessHeroXP()
    local max = UnitXPMax("player")
    if not max or max == 0 then return end
    local cur = UnitXP("player")
    if Secret(cur) or Secret(max) then return end
    if st.oldHero == nil then st.oldHero = cur; st.lastHeroMax = max; return end
    if cur == st.oldHero then return end

    local level = UnitLevel("player")
    if cur < st.oldHero then
        -- level up: the rest of the old level plus what carried over
        local got = math.max(0, (st.lastHeroMax - st.oldHero) + cur)
        st.heroSession = st.heroSession + got
        st.gains = st.gains + 1
        Note(GOLD .. GT.TR("level up") .. " " .. level .. "|r")
        C_Timer.After(1, CheckPetCap)
    else
        local got = cur - st.oldHero
        st.heroCombatXP = st.heroCombatXP + got
        st.heroSession = st.heroSession + got
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
end

-- ---------------------------------------------------------------- events (always on)
local ev = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UNIT_PET_EXPERIENCE", "UNIT_PET",
                        "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    ev:RegisterEvent(name)
end

local function Handle(event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        st.oldHero = UnitXP("player")
        st.lastHeroMax = UnitXPMax("player") or 0
        if UnitExists("pet") then st.oldPet = GetPetExperience() end
        C_Timer.After(3, CheckPetCap)
    elseif event == "PLAYER_XP_UPDATE" then
        ProcessHeroXP()
    elseif event == "UNIT_PET_EXPERIENCE" then
        ProcessPetXP()
    elseif event == "UNIT_PET" then
        if arg1 == "player" then
            st.oldPet = UnitExists("pet") and GetPetExperience() or nil   -- new pet: start from its current XP
            C_Timer.After(1, CheckPetCap)
        end
    elseif event == "PLAYER_LEVEL_UP" then
        C_Timer.After(1, CheckPetCap)
    elseif event == "PLAYER_REGEN_DISABLED" then
        BattleStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        BattleStop()
    end
end

ev:SetScript("OnEvent", function(_, event, arg1)
    local ok, err = pcall(Handle, event, arg1)
    if not ok then GT.ReportError("XP " .. event, err) end
end)

-- ---------------------------------------------------------------- commands
function XP.Reset()
    st.sessionStart = GetTime()
    st.heroSession, st.petSession, st.gains = 0, 0, 0
    st.heroBattles, st.heroBattleXP, st.heroCombatXP = 0, 0, 0
    st.petBattles, st.petBattleXP, st.petCombatXP = 0, 0, 0
    st.lastBattle, st.last = nil, nil
    for i = #recent, 1, -1 do recent[i] = nil end
    st.oldHero = UnitXP("player")
    st.oldPet = UnitExists("pet") and GetPetExperience() or nil
    GT.cprint(GT.TR("XP session reset."))
end

-- /gt xp             : turn XP mode on or off
-- /gt xp reset       : start a new XP session
-- /gt xp session     : session totals in chat
function XP.Slash(rest)
    rest = string.lower(rest or "")
    if rest == "reset" then
        XP.Reset()
    elseif rest == "session" then
        local rate = SessionRate()
        GT.cprint(string.format("%s %s %d, %s %d, %d %s, %s/hr", GT.TR("XP session:"),
            GT.TR("hero"), st.heroSession, GT.TR("pet"), st.petSession, st.gains, GT.TR("gains"),
            rate and FormatNumber(rate) or "--"))
    else
        XP.SetOn(not XP.IsOn())
        if GT.bar then GT:UpdateMiniBar() end
    end
end
