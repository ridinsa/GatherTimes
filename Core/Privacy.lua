-- Privacy.lua : follows GTBag's privacy switch (Key Bindings > AddOns > GTBag > Toggle privacy mode).
-- While privacy is on: session gold shows as stars, and GatherTimes_Names' name disguise is turned on (its
-- previous state is saved and put back when privacy is turned off).  Only active when GTBag is installed.
local _, GT = ...

function GT.PrivacyOn()
    local api = _G.GTBagAPI
    return (api and api.IsPrivacyOn and api.IsPrivacyOn()) and true or false
end

local function Follow(on)
    local db = GatherTimesDB
    local names = _G.GatherTimesNameDisguise
    if db and names and names.SetEnabled and names.IsEnabled then
        if on then
            if db.privacyNamesPrev == nil then db.privacyNamesPrev = names.IsEnabled() and 1 or 0 end
            if not names.IsEnabled() then names.SetEnabled(true) end
        elseif db.privacyNamesPrev ~= nil then
            local prev = db.privacyNamesPrev == 1
            db.privacyNamesPrev = nil
            if names.IsEnabled() ~= prev then names.SetEnabled(prev) end
        end
    end
    if GT.UpdateMiniBar then pcall(GT.UpdateMiniBar, GT) end
end

-- GTBag may load after GatherTimes: keep trying for a few seconds, then register and sync once.
local function Register(tries)
    local api = _G.GTBagAPI
    if api and api.RegisterPrivacyCallback then
        api.RegisterPrivacyCallback(function(on) Follow(on and true or false) end)
        Follow(GT.PrivacyOn())
        return
    end
    if tries > 0 and C_Timer and C_Timer.After then
        C_Timer.After(1, function() Register(tries - 1) end)
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function() Register(15) end)
