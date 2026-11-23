-- BagAddons.lua : notices other bag addons (Baganator, Bagnon, AdiBags, ...) and asks which one should handle the bags.
-- Two bag addons that both take over the bag key fight over it, so GTBag shows a window a couple of seconds after login
-- whenever it finds another bag addon that is enabled.
--   * Use GTBag: the other bag addons are switched off in the AddOns list and the game reloads.  GTBag follows the bag
--     key and hides the default bags.
--   * Use another addon: GTBag is switched off in the AddOns list (and any other bag addon that was not picked), and
--     the game reloads.  Enable GTBag again in the AddOns list whenever you want it back.
-- Reopen the window any time with /gtbag bags or Settings > Other bag addons.
local ADDON, ns = ...

local UI = ns.UI
local PAD = UI.PAD

-- The folder names come from GTBag/Loader.lua (GTBagKnownBagAddons).  Here only what differs from the folder name is
-- written: the shown title, and the lower-case starts of the names of the addon's frames (to find and close its windows).
local TITLE = { cargBags_Nivaya = "cargBags Nivaya" }
local FRAMES = {
    ArkInventory = { "arkinventory", "arkinv" }, OneBag3 = { "onebag" }, OneBag4 = { "onebag" },
    cargBags_Nivaya = { "cargbags", "nivaya" },
}
local KNOWN, KNOWN_BY_NAME = {}, {}
for _, folder in ipairs(GTBagKnownBagAddons or {}) do
    local k = { folder, TITLE[folder] or folder, FRAMES[folder] or { folder:lower() } }
    KNOWN[#KNOWN + 1] = k
    KNOWN_BY_NAME[folder:lower()] = k
end

-- addons whose name looks like a bag addon but that are helpers, data stores or modules of one
local NOT_BAG = { "gtbag", "sync", "brother", "config", "option", "setting", "tooltip", "level", "ilvl", "slot", "count",
                  "junk", "sell", "vendor", "broker", "scrap", "track", "search", "filter", "skin", "border", "glow",
                  "quality", "gathertimes", "syndicator", "datastore", "altoholic", "compare", "clean", "sort_" }

local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
local getNum = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
local disableAddOn = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn

local Say = ns.Say

-- 0 = disabled, 1 = disabled for some characters, 2 = enabled; nil when the client cannot say
local function EnableState(name, char)
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, v = pcall(C_AddOns.GetAddOnEnableState, name, char)
        return ok and tonumber(v) or nil
    elseif GetAddOnEnableState then
        local ok, v = pcall(GetAddOnEnableState, char, name)         -- older clients: (character, addon)
        return ok and tonumber(v) or nil
    end
end

-- clients differ in what the character argument is (a name, a GUID, or nothing for the current one), so every reading
-- is tried
local function Variants()
    local me = UnitName and UnitName("player")
    local guid = UnitGUID and UnitGUID("player")
    return { guid or false, me or false, false }
end

-- true when any reading says the addon is on for this character
local function EnabledForMe(folder)
    for _, who in ipairs(Variants()) do
        if EnableState(folder, who or nil) == 2 then return true end
    end
    return false
end

-- true when at least one reading exists and none of them says the addon is still on
local function VerifiedOff(folder)
    local seen = false
    for _, who in ipairs(Variants()) do
        local v = EnableState(folder, who or nil)
        if v ~= nil then
            seen = true
            if v == 2 then return false end
        end
    end
    return seen
end

-- turns an addon off for this character and checks that it worked, then falls back to turning it off for every
-- character.  Returns true when it is now off.
local function DisableVerified(folder)
    if not disableAddOn then return false end
    for _, who in ipairs(Variants()) do
        local arg = who or nil
        local ok = pcall(disableAddOn, folder, arg)
        if ok and (VerifiedOff(folder) or (arg == nil and EnableState(folder) == nil)) then return true end
    end
    return false
end

local function Plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- name, title, notes, loadable of the addon at this position in the AddOns list
local function AddOnAt(i)
    if not getInfo then return end
    local ok, a, b, c, d = pcall(getInfo, i)
    if not ok or a == nil then return end
    if type(a) == "table" then return a.name, Plain(a.title), Plain(a.notes), a.loadable end
    return a, Plain(b), Plain(c), d
end

-- a bag addon that is not in the known list: its name or title has to say bag, and its description has to talk about
-- replacing the bags or the bank
local function LooksLikeBagAddon(folder, title, notes)
    local f, t, n = folder:lower(), (title or ""):lower(), (notes or ""):lower()
    local named = f:find("bag", 1, true) or t:find("bag", 1, true) or f:find("inventory", 1, true) or t:find("inventory", 1, true)
    if not named then return false end
    for _, w in ipairs(NOT_BAG) do
        if f:find(w, 1, true) or t:find(w, 1, true) then return false end
    end
    if not (n:find("bag", 1, true) or n:find("inventory", 1, true)) then return false end
    return (n:find("replac", 1, true) or n:find("all-in-one", 1, true) or n:find("one window", 1, true)
        or n:find("single window", 1, true) or n:find("bank", 1, true)) and true or false
end

-- { { folder, title, framePrefixes }, ... } of the other bag addons that are enabled for this character (running now,
-- or switched on and waiting for the next load).  The AddOns list is scanned, so addons that are not in the known list
-- are found too.
function ns.OtherBagAddons()
    local out, have = {}, {}
    local n = getNum and getNum() or 0
    for i = 1, n do
        local folder, title, notes, loadable = AddOnAt(i)
        if folder and folder ~= "GTBag" and folder ~= "GTBag_Core" and not have[folder] then
            local known = KNOWN_BY_NAME[folder:lower()]
            if known or LooksLikeBagAddon(folder, title, notes) then
                local loaded = false
                if isLoaded then
                    local ok, l = pcall(isLoaded, folder)
                    loaded = ok and l and true or false
                end
                if loaded or (loadable ~= false and EnabledForMe(folder)) then
                    have[folder] = true
                    local shown = (title and title ~= "") and title or (known and known[2]) or folder
                    out[#out + 1] = { folder, shown, known and known[3] or { folder:lower() } }
                end
            end
        end
    end
    -- clients that cannot list addons: fall back to asking about the known folders directly
    if n == 0 and isLoaded then
        for _, k in ipairs(KNOWN) do
            local ok, loaded = pcall(isLoaded, k[1])
            if ok and loaded then out[#out + 1] = { k[1], k[2], k[3] } end
        end
    end
    return out
end

local function Saved()
    local s = GTBagDB and GTBagDB.bagAddon
    return type(s) == "table" and s or nil
end

-- ---------------------------------------------------------------------------------------------- window
local win, intro, note, askCheck, laterBtn
local buttons = {}
local others = {}
local dontAsk = false

local function Check(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    local box = b:CreateTexture(nil, "BORDER")
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 0, 0)
    box:SetColorTexture(0.34, 0.31, 0.24, 1)
    local inner = b:CreateTexture(nil, "ARTWORK")
    inner:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(0.06, 0.07, 0.09, 1)
    b.tick = b:CreateTexture(nil, "OVERLAY")
    b.tick:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    b.tick:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    b.tick:SetColorTexture(1, 0.82, 0, 1)
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", box, "RIGHT", 6, 0)
    label:SetText(text)
    b:SetWidth(14 + 6 + label:GetStringWidth() + 4)
    b:SetScript("OnClick", onClick)
    return b
end

local function TitleOf(folder)
    if folder == "GTBag" then return "GTBag" end
    for _, a in ipairs(others) do if a[1] == folder then return a[2] end end
    return folder
end

-- the addons that get switched off when `pick` is chosen
local function ToDisable(pick)
    local list = {}
    if pick ~= "GTBag" then list[#list + 1] = { "GTBag", "GTBag" } end
    for _, a in ipairs(others) do
        if a[1] ~= pick then list[#list + 1] = { a[1], a[2] } end
    end
    return list
end

local function ButtonText(pick)
    local names = {}
    for _, a in ipairs(ToDisable(pick)) do names[#names + 1] = a[2] end
    return "Use " .. TitleOf(pick) .. "   (turns off " .. table.concat(names, ", ") .. " and reloads)"
end

-- remembers the choice, switches the other addons off in the AddOns list and reloads the game
local function Choose(pick)
    GTBagDB = GTBagDB or {}
    GTBagDB.bagAddon = { pick = pick, ask = not dontAsk }
    ns.SetOpt("replace", pick == "GTBag")
    local pickTitle = TitleOf(pick)
    if pick == "GTBag" then
        Say("GTBag now handles your bags.")
    else
        Say(pickTitle .. " now handles your bags. GTBag stays out of the way; /gtbag opens it.")
    end

    local off, failed = {}, {}
    if disableAddOn then
        for _, a in ipairs(ToDisable(pick)) do
            if DisableVerified(a[1]) then off[#off + 1] = a[2] else failed[#failed + 1] = a[2] end
        end
    else
        for _, a in ipairs(ToDisable(pick)) do failed[#failed + 1] = a[2] end
    end
    if #failed > 0 then
        Say("could not turn off " .. table.concat(failed, ", ") .. " from here; disable it in the AddOns list at the "
            .. "character screen." .. (pick == "GTBag" and " Its bag window is kept closed while GTBag is chosen." or ""))
    end
    win:Hide()
    if #off > 0 then
        Say("turned off " .. table.concat(off, ", ") .. " in the AddOns list; reloading. Enable it there again if you "
            .. "change your mind.")
        ReloadUI()
        return
    end
    if pick == "GTBag" and ns.SuppressOtherBags then ns.SuppressOtherBags() end
    if ns.Relayout then ns.Relayout() end
end

local function Build()
    local W = 480
    win = UI.Window("GTBagBagAddonsFrame", W, 240, "Another bag addon found")
    win:SetFrameStrata("FULLSCREEN_DIALOG")

    intro = UI.Label(win, "")
    intro:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -44)
    intro:SetWidth(W - 2 * PAD)
    intro:SetJustifyH("LEFT")
    if intro.SetWordWrap then intro:SetWordWrap(true) end

    note = UI.Label(win, "The addon you do not pick is switched off in the AddOns list and the game reloads by itself. "
        .. "You can switch it back on there at any time.")
    note:SetWidth(W - 2 * PAD)
    note:SetJustifyH("LEFT")
    if note.SetWordWrap then note:SetWordWrap(true) end

    askCheck = Check(win, "Do not ask again (keep both on)", function(self)
        dontAsk = not dontAsk
        self.tick:SetShown(dontAsk)
    end)
    askCheck:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, 12)

    laterBtn = UI.Button(win, "Ask me later", 110)
    laterBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 10)
    laterBtn:SetScript("OnClick", function()
        if dontAsk then
            GTBagDB = GTBagDB or {}
            local s = Saved()
            GTBagDB.bagAddon = { pick = s and s.pick, ask = false }
        end
        win:Hide()
    end)
end

local function Layout()
    local W = win:GetWidth()
    local y = -44 - math.ceil(intro:GetStringHeight() or 14) - 14
    local choices = { "GTBag" }
    for _, a in ipairs(others) do choices[#choices + 1] = a[1] end
    for i, pick in ipairs(choices) do
        local b = buttons[i]
        if not b then
            b = UI.Button(win, "", W - 2 * PAD, 28)
            b:SetScript("OnClick", function(self) Choose(self.pick) end)
            buttons[i] = b
        end
        b.pick = pick
        b:SetText(ButtonText(pick))
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, y)
        b:Show()
        y = y - 34
    end
    for i = #choices + 1, #buttons do buttons[i]:Hide() end
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, y - 2)
    win:SetHeight(-y + 2 + math.ceil(note:GetStringHeight() or 28) + 14 + 40)
end

-- force: open even when "do not ask again" was ticked (the manual command)
function ns.ShowBagAddons(force)
    others = ns.OtherBagAddons()
    if #others == 0 then
        if force then Say("no other bag addon (Baganator, Bagnon, AdiBags, ...) is enabled.") end
        return
    end
    if not win then Build() end
    local s = Saved()
    dontAsk = s and s.ask == false or false
    askCheck.tick:SetShown(dontAsk)
    local names = {}
    for _, a in ipairs(others) do names[#names + 1] = a[2] end
    intro:SetText("GTBag found " .. table.concat(names, ", ") .. " enabled as well. Bag addons fight over the bag "
        .. "key, so choose which one stays active:")
    Layout()
    win:Show()
end

-- ---------------------------------------------------------------------------------------------- keep their windows closed
-- A bag addon takes over the bag key by itself, so picking GTBag alone does not stop its window from opening.  While
-- GTBag is the chosen addon, any top-level window whose name starts like a detected bag addon (and is not a bank,
-- options, tooltip... window) is closed as soon as it shows.  Frames are found by name, so it needs no knowledge of
-- each addon's internals.
local SKIP = { "bank", "guild", "void", "option", "config", "setting", "tooltip", "vault", "auction", "mail", "menu",
               "dropdown", "popup", "dialog", "editor", "tutorial", "minimap", "broker", "launcher", "button",
               "icon", "toast", "alert" }
local prefixes, hooked, faded = {}, {}, {}

local function Active()
    local s = Saved()
    return s ~= nil and s.pick == "GTBag" and ns.Opt("replace") and #prefixes > 0
end

local function MatchesAddon(name)
    local l = name:lower()
    local hit = false
    for _, p in ipairs(prefixes) do
        if l:sub(1, #p) == p then hit = true; break end
    end
    if not hit then return false end
    for _, w in ipairs(SKIP) do
        if l:find(w, 1, true) then return false end
    end
    return true
end

-- in combat a protected frame cannot be hidden, so it is made transparent and closed afterwards
local function Quiet(f)
    if InCombatLockdown() and f.IsProtected and f:IsProtected() then
        f:SetAlpha(0)
        faded[f] = true
    else
        f:SetAlpha(1)
        f:Hide()
    end
end

local function Visit(f)
    if hooked[f] then return end
    local name = f.GetName and f:GetName()
    if not (name and MatchesAddon(name)) then return end
    if not (f:IsShown() and f:GetParent() == UIParent and f:GetWidth() >= 150 and f:GetHeight() >= 100) then return end
    hooked[f] = name
    f:HookScript("OnShow", function(self) if Active() then Quiet(self) end end)
    Quiet(f)
end

local function Sweep()
    if not Active() or not EnumerateFrames then return end
    local f = EnumerateFrames()
    while f do
        pcall(Visit, f)
        f = EnumerateFrames(f)
    end
end

-- Walking every frame in the UI is the expensive part.  A window that was found once closes itself from its own OnShow
-- hook, so most bag toggles only need to re-check the frames already known; the full walk (which finds windows an
-- addon creates later) runs at most once every few seconds.
local FULL_SWEEP_EVERY = 3
local lastFullSweep
local function Recheck()
    if not Active() then return end
    for f in pairs(hooked) do
        if f.IsShown and f:IsShown() then pcall(Quiet, f) end
    end
end

function ns.SuppressOtherBags()
    if not Active() then return end
    local now = GetTime and GetTime() or 0
    local full = not lastFullSweep or now - lastFullSweep >= FULL_SWEEP_EVERY or now < lastFullSweep
    if full then lastFullSweep = now; Sweep() else Recheck() end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, full and Sweep or Recheck)      -- some addons draw on a later frame
    end
end

-- /gtbag bags frames : lists the frames this looks at, to help when an addon's window is not being closed
function ns.BagFrameDiag()
    if #prefixes == 0 then Say("no other bag addon is loaded."); return end
    local n = 0
    local f = EnumerateFrames()
    while f do
        local ok, name = pcall(f.GetName, f)
        if ok and name then
            local l = name:lower()
            for _, p in ipairs(prefixes) do
                if l:sub(1, #p) == p and f.IsShown and (f:IsShown() or hooked[f]) then
                    n = n + 1
                    if n <= 25 then
                        local parent = f:GetParent()
                        Say(string.format("%s  shown=%s  parent=%s  size=%dx%d%s", name, tostring(f:IsShown()),
                            parent == UIParent and "UIParent" or tostring(parent and parent:GetName() or "?"),
                            f:GetWidth() or 0, f:GetHeight() or 0,
                            hooked[f] and "  (closed by GTBag)" or (MatchesAddon(name) and "" or "  (ignored by name)")))
                    end
                    break
                end
            end
        end
        f = EnumerateFrames(f)
    end
    Say(n == 0 and "no shown frames of those addons right now; open their bags and run this again."
        or (n .. " frame(s) found" .. (n > 25 and ", first 25 shown" or "") .. "."))
end

-- ---------------------------------------------------------------------------------------------- at login
local function Check_AtLogin()
    local list = ns.OtherBagAddons()
    local s = Saved()
    wipe(prefixes)
    for _, a in ipairs(list) do
        for _, p in ipairs(a[3] or {}) do prefixes[#prefixes + 1] = p end
    end
    if #list == 0 then
        -- the addon we handed the bags to is gone: take them back so the bag key does something again
        if s and s.pick and s.pick ~= "GTBag" and not ns.Opt("replace") then
            ns.SetOpt("replace", true)
            GTBagDB.bagAddon = nil
            Say("the bag addon you chose is no longer enabled, so GTBag handles your bags again.")
        end
        return
    end
    if s and s.ask == false then return end        -- "do not ask again" was ticked
    ns.ShowBagAddons(false)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON and ((IsLoggedIn and IsLoggedIn()) or (UnitName and UnitName("player"))) then
            ev:UnregisterEvent("ADDON_LOADED")
            C_Timer.After(2, function()
                if InCombatLockdown() then self.waitingForChoice = true else Check_AtLogin() end
            end)
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        for f in pairs(faded) do
            faded[f] = nil
            if Active() then f:SetAlpha(1); f:Hide() end
        end
        if self.waitingForChoice then
            self.waitingForChoice = false
            Check_AtLogin()
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        wipe(prefixes)
        for _, a in ipairs(ns.OtherBagAddons()) do
            for _, p in ipairs(a[3] or {}) do prefixes[#prefixes + 1] = p end
        end
        if not (C_Timer and C_Timer.After) then return end
        C_Timer.After(2, function()                    -- after the other addons have drawn their first windows
            if InCombatLockdown() then
                self.waitingForChoice = true
            else
                Check_AtLogin()
            end
        end)
    end
end)
