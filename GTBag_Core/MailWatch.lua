-- MailWatch.lua : watches the saved mail of every character.
--   * a chat line after login lists characters whose saved mail expires soon (with the value at risk)
--   * the character selector marks those characters
--   * the Mail tab says when the game reports new mail since your last mailbox visit (the saved snapshot is older)
-- It only reads the snapshots that Data.lua saves; it needs no new events and saves nothing new.
local _, ns = ...

local function Say(msg) print("|cffffd100GTBag|r: " .. msg) end

-- Items of one character's saved mail that expire within `days` days (default: the Settings value).
-- Returns count, copper value, days left of the soonest item (nil when nothing is at risk).
function ns.MailRisk(rec, days)
    local mail = rec and type(rec.mail) == "table" and rec.mail or nil
    if not (mail and type(mail.items) == "table") then return 0, 0, nil end
    days = days or ns.Opt("mailWarnDays")
    local skipCOD = ns.Opt("mailSkipCOD")
    local now = time()
    local count, value, soonest = 0, 0, nil
    for _, it in ipairs(mail.items) do
        local left = (tonumber(it.days) or 30) - (now - (tonumber(it.t) or tonumber(mail.t) or now)) / 86400
        local cod = tonumber(it.cod) or 0
        if left > 0 and left < days and not (skipCOD and cod > 0) then
            local n = tonumber(it.count) or 1
            count = count + n
            local unit = ns.UnitValue and ns.UnitValue(it.id, it.link) or 0
            value = value + (unit or 0) * n
            if not soonest or left < soonest then soonest = left end
        end
    end
    return count, value, soonest
end

-- true when the game says new mail is waiting for the character you are playing (the saved snapshot is then out of date)
function ns.MailStale()
    return HasNewMail and HasNewMail() and true or false
end

local function DaysLabel(left)
    if not left then return "" end
    if left < 1 then return "<1d" end
    return math.max(1, math.ceil(left)) .. "d"
end

-- the characters with expiring mail: { { key, rec, count, value, soonest }, ... }, soonest first
function ns.MailExpiring(days)
    local list = {}
    for _, key in ipairs(ns.CharKeys()) do
        local rec = ns.Rec(key)
        local count, value, soonest = ns.MailRisk(rec, days)
        if count > 0 then list[#list + 1] = { key = key, rec = rec, count = count, value = value, soonest = soonest } end
    end
    table.sort(list, function(a, b) return a.soonest < b.soonest end)
    return list
end

-- prints the report; quiet = true prints nothing when everything is fine (the login check)
function ns.MailWatchReport(quiet)
    local list = ns.MailExpiring()
    if #list == 0 then
        if not quiet then Say("no saved mail expires within " .. ns.Opt("mailWarnDays") .. " days.") end
        return
    end
    Say("mail expiring within " .. ns.Opt("mailWarnDays") .. " days:")
    for _, e in ipairs(list) do
        local worth = (e.value > 0 and not ns.Privacy()) and ("  (worth " .. ns.Money(e.value) .. ")") or ""
        print(string.format("   %s  %d item%s, soonest %s%s", ns.ClassName(e.rec, true, true), e.count,
            e.count == 1 and "" or "s", "|cffff4040" .. DaysLabel(e.soonest) .. "|r", worth))
    end
end

-- short marker for the character selector, "" when nothing is at risk
function ns.MailMarker(rec)
    if not ns.Opt("mailWatch") then return "" end
    local count, _, soonest = ns.MailRisk(rec)
    if count == 0 then return "" end
    return "  |cffff4040! mail " .. DaysLabel(soonest) .. "|r"
end

-- login check: once per session, a few seconds after the game has settled (saved variables are loaded by then)
local done = false
C_Timer.After(6, function()
    if done then return end
    done = true
    if ns.Opt("mailWatch") then ns.MailWatchReport(true) end
end)
