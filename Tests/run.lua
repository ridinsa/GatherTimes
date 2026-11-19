-- Standalone Lua 5.1 regression checks. Run with: C:\lua51\lua5.1.exe Tests\run.lua
local _, GT = nil, {}
package.path = package.path .. ";?.lua;Core\\?.lua;Gathering\\?.lua"

_G.LibStub = nil
_G.geterrorhandler = _G.geterrorhandler or function() return nil end
_G.seterrorhandler = _G.seterrorhandler or function() end
_G.date = os.date

local passed = 0
local function check(name, ok)
    if not ok then error("FAIL: " .. name, 2) end
    passed = passed + 1
end

local utilChunk = assert(loadfile("Core\\Util.lua"))
utilChunk(nil, GT)

check("finite numbers reject NaN", not GT.IsFiniteNumber(0/0))
check("finite numbers reject infinity", not GT.IsFiniteNumber(math.huge))
check("Round5 rejects infinity", GT.Round5(math.huge) == nil)
check("Clamp rejects NaN", GT.Clamp(0/0, 1, 10, 5) == 5)
check("Pin rank prefers current map", GT.PinBefore(0, 100, 1, 1, 1, 2))

GT.MERGE_DIST = 0.006
GatherTimesDB = { peacebloom = {} }
_G.GetServerTime = function() return 1000 end
_G.time = _G.time or function() return 1000 end
_G.GetRealmName = function() return "TestRealm" end
_G.UnitName = function() return "Tester" end
_G.C_GameRules = nil

local timersChunk = assert(loadfile("Gathering\\Timers.lua"))
timersChunk(nil, GT)

local sp = { sid = 1, mapID = 1421, x = 0.25, y = 0.5 }
local entry = GT.UpsertTimer("peacebloom", sp, { time = 1000, taken = true, est = false })
check("central timer transition creates timer", entry and entry.sid == 1)
check("central timer transition stores realm", entry and entry.realm == "TestRealm")
check("central timer transition prevents duplicate entry", #GatherTimesDB.peacebloom == 1)

print(string.format("GatherTimes Lua regression checks passed: %d", passed))
