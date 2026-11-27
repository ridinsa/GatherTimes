-- AutoSort.lua : optional automatic sort of your bags (or the bank) when a vendor opens, a bank opens, or combat
-- ends. Each trigger is a setting in Settings > Sort, off by default. It runs the same sort as the sort button,
-- with the sort order you chose, and it stays quiet when it cannot run (no messages in chat).
local _, ns = ...

local function CanSortNow(bank)
    if InCombatLockdown() or not ns.ViewingSelf() or ns.panel.physicalSortRun then return false end
    if GetCursorInfo and GetCursorInfo() then return false end
    if bank and not ns.atBank then return false end
    return true
end

local function AutoSort(bank)
    if CanSortNow(bank) then ns.panel.RunPhysicalSort(bank and true or false) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("BANKFRAME_OPENED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    -- a short delay: the bags and the bank are read after the game has opened them
    if event == "MERCHANT_SHOW" and ns.Opt("autoSortVendor") then
        C_Timer.After(0.5, function() AutoSort(false) end)
    elseif event == "BANKFRAME_OPENED" and ns.Opt("autoSortBank") then
        C_Timer.After(0.5, function() AutoSort(true) end)
    elseif event == "PLAYER_REGEN_ENABLED" and ns.Opt("autoSortCombat") then
        C_Timer.After(0.5, function() AutoSort(false) end)
    end
end)
