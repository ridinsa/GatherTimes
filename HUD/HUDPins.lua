-- HUDPins.lua : keeps the node pins right after the HUD resizes / zooms / rotates the Minimap.
-- Part of the HUD module (see HUD.lua for the file layout).
local _, GT = ...
local HUD = GT.HUD

---------------------------------------------------------------------------
-- Node pins on the HUD
---------------------------------------------------------------------------

-- GatherTimes' timers and spawn spots, GatherMate2 nodes and TomTom waypoints are all HereBeDragons pins that
-- hang on the Minimap frame. HereBeDragons positions them from the Minimap's size, zoom and rotation, but
-- only re-reads those while the player moves or turns. Standing still after the HUD was resized, the pins
-- therefore stayed where the old size had put them until the next step.
--
-- The library keeps its own "lay out everything again" routine private. The one public way to run it is
-- pins:SetMinimapObject(): it ends in a forced full update, in the same call. It is handed the Minimap object
-- the library already uses (another addon may have swapped it), so nothing about the library changes.
-- Library revisions that have no SetMinimapObject get the old guesses, any that exist are called.
--
-- This runs at once, not after a delay: the Minimap already has its new size when HUD.RefreshPins is called, and
-- the layout is only a loop over the pins. A slider that fires several times in one frame is answered once
-- per frame (GetTime() does not change inside a frame); the rest is caught by one run on the next frame.
-- The text restyle is the slow part (a SetFont on every pin label), it is not needed for a resize and stays on
-- the old 0.2 s debounce.
local PIN_REFRESH_CALLS = { "UpdateMinimapIconPositions", "UpdateMinimapPins", "UpdateMinimap" }
local RESTYLE_DELAY = 0.2

local lastRun = -1
local laterQueued, restyleQueued = false, false

-- Lays the pins out again. Returns true when the library accepted one of the calls.
local function LayoutPins()
    local lib = GT.HBDPins
    if not lib then return false end
    if type(lib.SetMinimapObject) == "function" then
        if pcall(lib.SetMinimapObject, lib, lib.Minimap or Minimap) then return true end
    end
    for _, name in ipairs(PIN_REFRESH_CALLS) do
        if type(lib[name]) == "function" and pcall(lib[name], lib) then return true end
    end
    return false
end

local function QueueRestyle()
    if restyleQueued then return end
    restyleQueued = true
    C_Timer.After(RESTYLE_DELAY, function()
        restyleQueued = false
        if GT.RestylePins then pcall(GT.RestylePins) end
    end)
end

local function RunNow()
    laterQueued = false
    lastRun = GetTime()
    LayoutPins()
    QueueRestyle()
end

function HUD.RefreshPins()
    if GetTime() ~= lastRun then
        RunNow()
    elseif not laterQueued then
        laterQueued = true                       -- a second call inside the same frame: once more next frame
        C_Timer.After(0, RunNow)
    end
end
