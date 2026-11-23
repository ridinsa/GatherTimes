-- Loader.lua : the only file of the GTBag folder.  It stays tiny: it registers /gtbag, watches the bag keys and
-- loads the real bag window (the GTBag_Core folder, load-on-demand) the first time it is needed.  GTBag works
-- on its own, GatherTimes is not required.
local CORE = "GTBag_Core"

-- Public API for other addons (GatherTimes...).  It exists from login on; the functions that need the bag window work
-- once GTBag_Core has loaded (a couple of seconds after login) and answer "off" / the unchanged name before that.
--   GTBagAPI.version                     the API version (1)
--   GTBagAPI.IsPrivacyOn()               true when GTBag's Privacy mode (scrambled names) is on
--   GTBagAPI.DisplayName(name)           the scrambled name when Privacy mode is on, else the name as given
--   GTBagAPI.RegisterPrivacyCallback(f)  f(isOn) runs when Privacy mode is switched or scrambled again: refresh your text
GTBagAPI = GTBagAPI or {}
do
    local api, callbacks = GTBagAPI, {}
    api.version = 1
    function api.IsPrivacyOn()
        local f = api._isPrivacy
        return f and f() or false
    end
    function api.DisplayName(name)
        local f = api._scramble
        if f and api.IsPrivacyOn() then return f(name) end
        return name
    end
    function api.RegisterPrivacyCallback(fn)
        if type(fn) == "function" then callbacks[#callbacks + 1] = fn end
    end
    function api.Fire(isOn)                  -- called by GTBag_Core
        for _, fn in ipairs(callbacks) do pcall(fn, isOn) end
    end
end

local function IsLoaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return fn and fn(name) or false
end

local gtbagStub
local function LoadCore()
    if IsLoaded(CORE) then return true end
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    local ok, loaded, reason = pcall(load, CORE)
    if not IsLoaded(CORE) then
        print("|cffffd100GTBag|r could not be loaded (" .. tostring(ok and reason or loaded)
            .. "). Check that the GTBag_Core folder is installed and enabled.")
        return false
    end
    return true
end

local function RunCommand(msg)
    if not LoadCore() then return false end
    local command = SlashCmdList and SlashCmdList.GTBAG
    if command and command ~= gtbagStub then
        command(msg or "")
        return true
    end
    print("|cffffd100GTBag|r loaded, but its /gtbag command was not registered.")
    return false
end

-- Key Bindings > AddOns > GTBag > Toggle privacy mode (see Bindings.xml)
BINDING_HEADER_GTBAG = "GTBag"
BINDING_NAME_GTBAG_PRIVACY = "Toggle privacy mode"
function GTBagTogglePrivacy() RunCommand("privacy") end

SLASH_GTBAG1 = "/gtbag"
gtbagStub = function(msg) RunCommand(msg) end
SlashCmdList.GTBAG = gtbagStub

local function BlizzardBagsShown()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined.IsShown and combined:IsShown() then return true end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame.IsShown and frame:IsShown() then return true end
    end
    return false
end

-- Bag addons GTBag knows by folder name.  This is the only list: GTBag_Core reads GTBagKnownBagAddons (BagAddons.lua)
GTBagKnownBagAddons = {
    "Baganator", "Bagnon", "AdiBags", "ArkInventory", "Combuctor", "OneBag3", "OneBag4",
    "Inventorian", "LiteBag", "Bagginses", "Baggins", "BaudBag", "BetterBags", "Bagshui",
    "Sorted", "TBag", "cargBags_Nivaya",
}

local function BagAddonEnabled(folder, character)
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, folder, character)
        return ok and tonumber(state) == 2
    elseif GetAddOnEnableState then
        local ok, state = pcall(GetAddOnEnableState, character, folder)
        return ok and tonumber(state) == 2
    end
    return false
end

-- another bag addon is installed: the real window must load at login, because it asks which addon to keep
local function HasOtherBagAddon()
    local player = UnitName and UnitName("player")
    local guid = UnitGUID and UnitGUID("player")
    for _, folder in ipairs(GTBagKnownBagAddons) do
        if IsLoaded(folder) then return true end
        for _, character in ipairs({ guid or false, player or false, false }) do
            if BagAddonEnabled(folder, character or nil) then return true end
        end
    end
    return false
end

local queued = false
local function LoadFromBagToggle(id)
    if IsLoaded(CORE) or queued then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if id ~= nil then
        local lastBag = NUM_BAG_SLOTS or 4
        local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
        if type(reagentBag) == "number" then lastBag = math.max(lastBag, reagentBag) end
        if type(id) ~= "number" or id < 0 or id > lastBag then return end
    end
    if not BlizzardBagsShown() then return end
    queued = true
    if CloseAllBags then
        CloseAllBags()
    else
        local combined = _G.ContainerFrameCombinedBags
        if combined and combined.IsShown and combined:IsShown() then combined:Hide() end
        for i = 1, (NUM_CONTAINER_FRAMES or 13) do
            local frame = _G["ContainerFrame" .. i]
            if frame and frame.IsShown and frame:IsShown() then frame:Hide() end
        end
    end
    C_Timer.After(0, function()
        queued = false
        if IsLoaded(CORE) or (InCombatLockdown and InCombatLockdown()) then return end
        if not LoadCore() then return end
        RunCommand("")
        -- the game's own bag frames can still be on screen from the key press that triggered this first load:
        -- close them once more a moment later (out of combat only)
        C_Timer.After(0.1, function()
            if InCombatLockdown and InCombatLockdown() then return end
            if BlizzardBagsShown() and CloseAllBags then CloseAllBags() end
        end)
    end)
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack" }) do
        if _G[name] then hooksecurefunc(name, LoadFromBagToggle) end
    end
    if _G.ToggleBag then hooksecurefunc("ToggleBag", LoadFromBagToggle) end
    C_Timer.After(0.5, function()
        if not IsLoaded(CORE) and HasOtherBagAddon() then LoadCore() end
    end)
    -- Load the bag window right after login / reload, so the very first bag key press is already handled by GTBag
    -- (loading it on that first press let the game's own bags appear).  Waits for the end of combat if needed.
    local function Preload()
        if IsLoaded(CORE) then return end
        if InCombatLockdown and InCombatLockdown() then
            local waiter = CreateFrame("Frame")
            waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
            waiter:SetScript("OnEvent", function(w) w:UnregisterAllEvents(); C_Timer.After(1, Preload) end)
            return
        end
        LoadCore()
    end
    C_Timer.After(2, Preload)
end)
