-- Util.lua
local _, GT = ...

local HBDPins = (LibStub and LibStub("HereBeDragons-Pins-2.0", true))
local HBD = (LibStub and LibStub("HereBeDragons-2.0", true))

GT.debugLoot = false
function GT.dprint(...)
    if GT.debugLoot then print("|cff1eff00[GatherTimes]|r", ...) end
end
function GT.cprint(...)
    print("|cff1eff00[GatherTimes]|r", ...)
end

local errLog = {}
local function LogError(where, err)
    errLog[#errLog + 1] = date("%H:%M:%S") .. "  " .. where .. ":  " .. tostring(err):sub(1, 160)
    if #errLog > 20 then table.remove(errLog, 1) end
end
function GT.ReportError(where, err)
    LogError(where, err)
    GT.cprint(GT.TRF("ERROR in %s (details: Settings > Tools)", where))
end

do
    local previous = geterrorhandler()
    seterrorhandler(function(msg)
        if type(msg) == "string" and msg:find("GatherTimes", 1, true) then
            pcall(LogError, "lua", msg)          -- a failure in here must never raise inside the error handler
        end
        if previous then return previous(msg) end
    end)
end

-- Hardcore is a game mode of the client, not a different realm name, so the same realm name can carry
-- Hardcore and non-Hardcore characters.  Their timers must not mix: the stamp is part of the realm tag.
GT.HC_SUFFIX = "-Hardcore"

-- true only when the client says so explicitly (an API that is missing, or answers anything but true, is "no")
function GT.IsHardcore()
    local ok, hc = pcall(function()
        return C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive()
    end)
    return ok and hc == true
end

-- The realm this character plays on, plus the Hardcore stamp ("Doomhowl-Hardcore").  Timers are tagged with
-- it (see Config.lua) and the main window shows it.  nil while the client does not know the realm yet.
function GT.RealmName()
    local r = (GetRealmName and GetRealmName()) or (GetNormalizedRealmName and GetNormalizedRealmName())
    if type(r) ~= "string" or r == "" then return nil end
    if GT.IsHardcore() then r = r .. GT.HC_SUFFIX end
    return r
end

-- Libraries the addon cannot do without for distances and map pins.  They are looked up when the files
-- load; an addon that bundles them and loads AFTER GatherTimes is only seen at PLAYER_ENTERING_WORLD.
-- Returns the names of the libraries that are missing, and those that exist now but were not there at load.
function GT.MissingLibs()
    local missing, late = {}, {}
    local libs = { { "HereBeDragons-2.0", GT.HBD }, { "HereBeDragons-Pins-2.0", GT.HBDPins } }
    for _, l in ipairs(libs) do
        if not l[2] then
            if LibStub and LibStub(l[1], true) then late[#late + 1] = l[1] else missing[#missing + 1] = l[1] end
        end
    end
    return missing, late
end

local libsWarned = false
function GT.WarnMissingLibs()
    if libsWarned then return end
    libsWarned = true
    local missing, late = GT.MissingLibs()
    if #missing > 0 then
        GT.cprint(GT.TRF("Missing library: %s. Without it distances, route suggestions, \"leave now\" alerts and map pins do not work. Install the HereBeDragons addon (or any addon that bundles it) and /reload.",
            table.concat(missing, ", ")))
    end
    if #late > 0 then
        GT.cprint(GT.TRF("Library %s loaded after GatherTimes. Type /reload so distances and map pins work.",
            table.concat(late, ", ")))
    end
end

-- ============================================================
-- CORE DATA + CONFIG
-- ============================================================
GT.spawns = {}; local spawnBySid = {}
local uiRefresh = {}
local UI = { W = 320, M = 12 }

-- Distance in yards from you to a point.  No closure or table is created per call: this runs hundreds
-- of times per second (every node, every spot), and a new function object each time was the biggest
-- source of garbage in the addon.
local playerX, playerY, playerInstance, playerPositionAt
local PLAYER_POSITION_CACHE = 0.1
local function PlayerWorldPosition()
    local now = GetTime()
    if playerPositionAt and now - playerPositionAt < PLAYER_POSITION_CACHE then
        return playerX, playerY, playerInstance
    end
    playerPositionAt = now
    playerX, playerY, playerInstance = HBD:GetPlayerWorldPosition()
    return playerX, playerY, playerInstance
end

local function RawDistance(mapID, x, y)
    local px, py, pInst = PlayerWorldPosition()
    local nx, ny, nInst = HBD:GetWorldCoordinatesFromZone(x, y, mapID)
    if not px or not nx or pInst ~= nInst then return nil end
    local dx, dy = px - nx, py - ny
    return math.sqrt(dx * dx + dy * dy)
end

function GT.GetDistanceXY(mapID, x, y)
    if not HBD then return nil end
    local ok, d = pcall(RawDistance, mapID, x, y)
    if ok then return d end
    return nil
end

-- Which of two spots gets a map dot first when there are more spots than dots: spots on the map you are on
-- (own = 0, other map = 1) come first, then the nearest; an unknown distance counts as the farthest, and the
-- list position breaks ties so the order is stable.  Pure function, so Tests\run.lua covers it.
function GT.PinBefore(ownA, distA, idxA, ownB, distB, idxB)
    if ownA ~= ownB then return ownA < ownB end
    if distA ~= distB then return distA < distB end
    return idxA < idxB
end

function GT.GetDistance(node)
    return GT.GetDistanceXY(node.mapID, node.x, node.y)
end

-- ============================================================
-- TEXT TIMERS ON MAP

-- Map positions are fractions 0..1; 5 decimals is ~0.05 yd on a big zone map, far finer than anything the addon
-- compares (merge 0.006, snap 0.015).  Saved as full floats they cost ~10 extra characters each.
function GT.Round5(v)
    if type(v) ~= "number" then return v end
    return math.floor(v * 100000 + 0.5) / 100000
end

-- Number clamp for saved settings: a missing, non-numeric or NaN value becomes def, then lo..hi is enforced.
function GT.Clamp(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then v = def end
    if not v then return lo end
    return math.max(lo, math.min(hi, v))
end

-- Respawn time of one item type, in seconds.  Hand-edited, learned or damaged values stay inside this range.
GT.TIMER_MIN, GT.TIMER_MAX = 30, 7200
function GT.ClampTimer(t, def)
    return GT.Clamp(t, GT.TIMER_MIN, GT.TIMER_MAX, def)
end

-- sp.nexts (spot -> how often you went there next) keeps the NEXTS_MAX strongest followers of a spot; the weakest
-- are dropped (equal counts: the lower spot id goes first, so the result does not depend on table order).
-- keep = the follower that was just counted: it is never the one dropped, otherwise a new follower (count 1)
-- could never get into a full table.
GT.NEXTS_MAX = 8
function GT.TrimNexts(nx, keep)
    local n = 0
    for _ in pairs(nx) do n = n + 1 end
    if n <= GT.NEXTS_MAX then return end
    local list = {}
    for sid in pairs(nx) do
        if sid ~= keep then list[#list + 1] = sid end
    end
    table.sort(list, function(a, b)
        local ca, cb = nx[a], nx[b]
        if ca ~= cb then return ca > cb end
        return a < b
    end)
    local room = GT.NEXTS_MAX - ((keep ~= nil and nx[keep] ~= nil) and 1 or 0)
    for i = room + 1, #list do nx[list[i]] = nil end
end

-- exports
GT.HBD = HBD
GT.HBDPins = HBDPins
GT.UI = UI
GT.errLog = errLog
GT.spawnBySid = spawnBySid
GT.uiRefresh = uiRefresh
