-- BagSpace.lua : warning when the free bag slots drop to N (Minimize settings > Chips).
-- An alert on screen (once, in the alert style chosen in Settings > Display) and a red chip on the minimized bar.
local _, GT = ...

-- bag types whose slots take a herb or an ore: ordinary bags (0), herb bags (32), mining bags (1024).
-- Quivers, ammo pouches, soul bags and the like cannot hold what a gatherer picks up, so their slots do not count.
local USABLE_TYPE = { [0] = true, [32] = true, [1024] = true }

-- free slots in the bags that can hold herbs and ore, or nil when the client has no bag functions
function GT.FreeBagSlots()
    local fn = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    if not fn then return nil end
    local free = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local ok, n, bagType = pcall(fn, bag)
        if ok and type(n) == "number" and (bagType == nil or USABLE_TYPE[bagType]) then free = free + n end
    end
    return free
end

-- the number of free slots while the warning is active (option on and free slots at or below the limit), else nil.
-- The minimized bar draws its chip from this.
function GT.BagWarning()
    local c = GT.cfg and GT.cfg()
    if not (c and c.bagWarn) then return nil end
    local free = GT.FreeBagSlots()
    if free and free <= (c.bagWarnSlots or 5) then return free end
    return nil
end

local alerted, fullAlerted = false, false      -- one alert per crossing; both are armed again when the bags have room

local function Fire(text, r, g, b)
    GT.ShowScreenAlert(text, r, g, b)
    pcall(PlaySound, 8959, "Master")
end

-- called on BAG_UPDATE_DELAYED, once after login, and when the option or the limit changes
function GT.CheckBags()
    local c = GT.cfg and GT.cfg()
    if not c then return end
    local free = GT.FreeBagSlots()
    if not free then return end
    if not c.bagWarn or free > (c.bagWarnSlots or 5) then
        alerted, fullAlerted = false, false
    elseif free == 0 then
        if not fullAlerted then
            fullAlerted, alerted = true, true
            Fire(GT.TR("BAGS FULL"), 1, 0.2, 0.2)
        end
    elseif not alerted then
        alerted = true
        Fire(GT.TRF("Bags almost full: %d free", free), 1, 0.55, 0.1)
    end
    if free > 0 then fullAlerted = false end
    if GT.bar and GT.bar:IsShown() then GT:UpdateMiniBar() end
end
