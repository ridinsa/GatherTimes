-- Competition.lua : how heavily other players farm each zone, by hour of day.
--   Every gather of yours is a "find"; every node found already taken (Learn.lua MarkEmpty) is a "taken".
--   Saved account-wide in GatherTimesDB._cfg.compete[mapID][hour] = { f = finds, t = taken }  (hour = your local clock, 0-23).
--   - On entering a zone (and while you farm it) a warning appears when the zone is heavily farmed at this hour,
--     with a better zone to try when the data has one.   Turn the warning off: /gt compete alert
--   - /gt compete          zones ranked by taken %, with the best and worst hour of each
--   - /gt compete reset    forget the data
local _, GT = ...

local MIN_SAMPLES   = 8       -- finds + taken needed before a zone / hour is judged
local HIGH_PCT      = 35      -- taken % that counts as "heavily farmed"
local MEDIUM_PCT    = 20
local HALVE_AT      = 400     -- counts are halved above this per zone/hour so old data fades
local LIVE_WINDOW   = 6       -- the last N gather attempts of this session
local LIVE_TAKEN    = 4       -- this many of them taken -> live warning
local ALERT_GAP     = 600     -- seconds between warnings for the same zone

local recent = {}             -- this session: last attempts, true = taken
local alertedAt = {}          -- mapID -> GetTime() of the last warning

local function Store()
    local c = GatherTimesDB and GT.cfg and GT.cfg()
    if type(c) ~= "table" then return nil end
    if type(c.compete) ~= "table" then c.compete = {} end
    return c.compete
end

local function Hour(t) return tonumber(date("%H", t or time())) or 0 end

local function ZoneName(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
    end
    return "Map " .. tostring(mapID)
end

local function CurrentMap()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
end

local function Num(v) v = tonumber(v); if v and v == v and v >= 0 and v < 1e9 then return v end return 0 end

-- totals of one zone: all hours, or one hour
local function Totals(zone, hour)
    local f, t = 0, 0
    if type(zone) ~= "table" then return 0, 0 end
    for h = 0, 23 do
        local e = zone[h]
        if type(e) == "table" and (not hour or h == hour) then f, t = f + Num(e.f), t + Num(e.t) end
    end
    return f, t
end

local function Pct(f, t)
    local n = f + t
    if n < MIN_SAMPLES then return nil end
    return t / n * 100
end

local function Note(mapID, taken)
    local s = Store()
    if not (s and type(mapID) == "number") then return end
    local zone = s[mapID]
    if type(zone) ~= "table" then zone = {}; s[mapID] = zone end
    local h = Hour()
    local e = zone[h]
    if type(e) ~= "table" then e = { f = 0, t = 0 }; zone[h] = e end
    if taken then e.t = Num(e.t) + 1 else e.f = Num(e.f) + 1 end
    if Num(e.f) + Num(e.t) > HALVE_AT then e.f, e.t = math.floor(Num(e.f) / 2), math.floor(Num(e.t) / 2) end
end

-- a zone with plenty of data and a clearly lower taken % than this one (at this hour when there is data for it)
local function BetterZone(excludeMap, hour)
    local s = Store()
    if not s then return nil end
    local best, bestPct
    for mapID, zone in pairs(s) do
        if mapID ~= excludeMap and type(zone) == "table" then
            local f, t = Totals(zone, hour)
            local p = Pct(f, t)
            if not p then f, t = Totals(zone); p = Pct(f, t) end
            if p and p < MEDIUM_PCT and (not bestPct or p < bestPct) then best, bestPct = mapID, p end
        end
    end
    return best, bestPct
end

local function Warn(mapID, pct, live)
    local now = GetTime()
    if alertedAt[mapID] and now - alertedAt[mapID] < ALERT_GAP then return end
    alertedAt[mapID] = now
    local name = ZoneName(mapID)
    local text = GT.TRF("%s is heavily farmed right now (%d%% of nodes already taken).", name, math.floor(pct + 0.5))
    local alt, altPct = BetterZone(mapID, Hour())
    local detail
    if alt then detail = GT.TRF("Try %s (%d%% taken).", ZoneName(alt), math.floor(altPct + 0.5)) end
    GT.cprint("|cffff9933" .. text .. "|r" .. (detail and (" " .. detail) or ""))
    if GT.ShowScreenAlert then pcall(GT.ShowScreenAlert, text, 1, 0.55, 0, nil, detail) end
end

local function Enabled()
    local c = GT.cfg and GT.cfg()
    return not (c and c.competeAlert == false)
end

-- zone entry: judge from the history of this zone at this hour
local function CheckZone()
    if not Enabled() then return end
    local mapID = CurrentMap()
    local s = Store()
    local zone = mapID and s and s[mapID]
    if type(zone) ~= "table" then return end
    local f, t = Totals(zone, Hour())
    local p = Pct(f, t)
    if p and p >= HIGH_PCT then Warn(mapID, p) end
end

-- while farming: several of the last attempts were taken
local function CheckLive(mapID)
    if not Enabled() then return end
    local n, taken = #recent, 0
    for _, v in ipairs(recent) do if v then taken = taken + 1 end end
    if n >= LIVE_WINDOW and taken >= LIVE_TAKEN then Warn(mapID, taken / n * 100, true) end
end

local function Push(taken)
    recent[#recent + 1] = taken and true or false
    while #recent > LIVE_WINDOW do table.remove(recent, 1) end
end

-- called by Loot.lua (a successful gather) and Learn.lua (a node found taken)
function GT.CompetitionNote(mapID, taken)
    local ok, err = pcall(function()
        Note(mapID, taken)
        Push(taken)
        if taken then CheckLive(mapID) end
    end)
    if not ok and GT.ReportError then GT.ReportError("competition", err) end
end

-- ---------------------------------------------------------------- /gt compete
function GT.CompetitionSlash(rest)
    rest = (rest or ""):lower():match("^%s*(%S*)") or ""
    local c = GT.cfg()
    if rest == "alert" then
        c.competeAlert = not Enabled()
        GT.cprint(GT.TR(Enabled() and "Competition warning ON" or "Competition warning OFF"))
        return
    elseif rest == "reset" then
        c.compete = {}
        wipe(recent); wipe(alertedAt)
        GT.cprint(GT.TR("Competition data cleared."))
        return
    end
    local s, rows = Store() or {}, {}
    for mapID, zone in pairs(s) do
        local f, t = Totals(zone)
        if f + t > 0 then
            local bestH, bestP, worstH, worstP
            for h = 0, 23 do
                local hf, ht = Totals(zone, h)
                local p = Pct(hf, ht)
                if p then
                    if not bestP or p < bestP then bestH, bestP = h, p end
                    if not worstP or p > worstP then worstH, worstP = h, p end
                end
            end
            rows[#rows + 1] = { map = mapID, f = f, t = t, pct = Pct(f, t), bestH = bestH, bestP = bestP, worstH = worstH, worstP = worstP }
        end
    end
    if #rows == 0 then
        GT.cprint(GT.TR("No competition data yet. It builds up as you gather and find nodes already taken."))
        return
    end
    table.sort(rows, function(a, b) return (a.pct or -1) > (b.pct or -1) end)
    GT.cprint(GT.TR("Competition (nodes found already taken, by zone):"))
    for _, r in ipairs(rows) do
        local line = string.format("  %s: %s (%d/%d)", ZoneName(r.map),
            r.pct and (math.floor(r.pct + 0.5) .. "%") or "?", r.t, r.f + r.t)
        if r.bestH and r.worstH and r.bestH ~= r.worstH then
            line = line .. string.format("  %s %02d:00 %d%%, %s %02d:00 %d%%", GT.TR("quietest"), r.bestH, math.floor(r.bestP + 0.5),
                GT.TR("busiest"), r.worstH, math.floor(r.worstP + 0.5))
        end
        GT.cprint(line)
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function()
    wipe(recent)                                             -- a new zone starts a new run of attempts
    C_Timer.After(3, function() pcall(CheckZone) end)        -- the map is known a moment after the event
end)
