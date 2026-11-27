-- Hooks.lua : mirrors Blizzard bag toggles in GTBag and registers /gtbag.
-- Blizzard-owned toggle functions are post-hooked only; native frames are hidden out of combat.
local ADDON, ns = ...

local function Replacing() return ns.Opt("replace") end
local lastBag = (ns.BAGS and ns.BAGS[#ns.BAGS]) or 4

local function IsOurBag(id) return type(id) == "number" and id >= 0 and id <= lastBag end

local function BlizzardBagFrames()
    local list = {}
    if _G.ContainerFrameCombinedBags then list[#list + 1] = _G.ContainerFrameCombinedBags end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame then list[#list + 1] = frame end
    end
    return list
end

-- In combat the game does not let addons hide its bag frames, but making them fully transparent is allowed.
local function FadeBlizzardBags()
    for _, frame in ipairs(BlizzardBagFrames()) do
        if frame.IsShown and frame:IsShown() and frame.SetAlpha then frame:SetAlpha(0) end
    end
end

local function HideBlizzardBags()
    if InCombatLockdown() then FadeBlizzardBags(); return false end
    for _, frame in ipairs(BlizzardBagFrames()) do
        if frame.IsShown and frame:IsShown() then frame:Hide() end
        if frame.SetAlpha then frame:SetAlpha(1) end     -- undo the combat fade so the frame is normal when shown later
    end
    return true
end

local hideAfterCombat = false

-- Blizzard's bag frames are hidden the moment they are shown, inside the same frame, so they are never drawn.
-- (Hiding them on a timer, as before, let them flash for one frame.)
local hookedBags = {}
local function HookBlizzardBags()
    local list = {}
    if _G.ContainerFrameCombinedBags then list[#list + 1] = _G.ContainerFrameCombinedBags end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame then list[#list + 1] = frame end
    end
    for _, frame in ipairs(list) do
        if not hookedBags[frame] and frame.HookScript then
            hookedBags[frame] = true
            frame:HookScript("OnShow", function(self)
                if not Replacing() then self:SetAlpha(1); return end
                if InCombatLockdown() then
                    hideAfterCombat = true
                    self:SetAlpha(0)
                else
                    self:SetAlpha(1)
                    self:Hide()
                end
            end)
        end
    end
end

local function Apply()
    local syncQueued = false
    local function QueueToggle(id)
        if not Replacing() or (id ~= nil and not IsOurBag(id)) or syncQueued then return end
        syncQueued = true
        C_Timer.After(0, function()
            syncQueued = false
            if not Replacing() then return end
            -- visiting the banker makes the game open the bags too: that must not close the window GTBag just opened
            local justOpened = ns.bankOpenedAt and GetTime and (GetTime() - ns.bankOpenedAt) < 1
            if justOpened then ns.Open() else ns.Toggle() end
            if not HideBlizzardBags() then hideAfterCombat = true end
            if ns.SuppressOtherBags then ns.SuppressOtherBags() end
        end)
    end
    local function OnBagToggle(id)
        QueueToggle(id)
    end
    for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack" }) do
        if _G[name] then hooksecurefunc(name, OnBagToggle) end
    end
    -- other ways the bags get opened (vendor, mailbox...): GTBag does not follow those, but another bag addon's
    -- window should still stay closed when GTBag was chosen
    for _, name in ipairs({ "OpenAllBags", "OpenBackpack", "OpenBag" }) do
        if _G[name] then hooksecurefunc(name, function()
            if ns.SuppressOtherBags and Replacing() then ns.SuppressOtherBags() end
        end) end
    end
    if _G.ToggleBag then
        hooksecurefunc("ToggleBag", OnBagToggle)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        if not hideAfterCombat then return end
        hideAfterCombat = false
        if Replacing() then HideBlizzardBags() end
    end)
end

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" then HookBlizzardBags(); return end
    if name ~= ADDON then return end
    GTBagDB = GTBagDB or {}
    if (tonumber(GTBagDB.schemaVersion) or 0) < 1 then
        GTBagDB.ignoreEmpty = false
        GTBagDB.schemaVersion = 1
    end
    if (tonumber(GTBagDB.schemaVersion) or 0) < 2 then
        -- drop drag-order lists left behind by characters that are no longer known
        local chars = type(GTBagDB.chars) == "table" and GTBagDB.chars or {}
        if type(GTBagDB.manualOrders) == "table" then
            for scope in pairs(GTBagDB.manualOrders) do
                local owner = type(scope) == "string" and scope:match("^(.+):%a+:%d+$")
                if not owner or not chars[owner] then GTBagDB.manualOrders[scope] = nil end
            end
        end
        GTBagDB.schemaVersion = 2
    end
    self:UnregisterEvent("ADDON_LOADED")
    HookBlizzardBags()
    Apply()
end)

local Say = ns.Say

SLASH_GTBAG1 = "/gtbag"
SlashCmdList["GTBAG"] = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if cmd == "" then
        ns.Toggle()
    elseif cmd == "view" then
        ns.SetOpt("view", arg == "bag" and "bag" or "category")
        ns.Relayout(); Say("view: " .. ns.Opt("view"))
    elseif cmd == "cols" then
        local n = tonumber(arg)
        if n then ns.SetOpt("cols", math.max(8, math.min(15, math.floor(n)))); ns.Relayout() end
        Say("columns: " .. ns.Opt("cols"))
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n then ns.SetOpt("scale", math.max(0.6, math.min(1.6, n))); ns.Relayout() end
        Say("scale: " .. ns.Opt("scale"))
    elseif cmd == "replace" then
        ns.SetOpt("replace", arg ~= "off")
        Say(ns.Opt("replace") and "GTBag follows bag toggles; Blizzard bags hide out of combat."
            or "automatic GTBag opening is disabled; Blizzard bags remain available.")
    elseif cmd == "hidden" then
        -- same as right-clicking the eye button: show every hidden item for now, run it again to hide them
        local P = ns.panel
        if InCombatLockdown() then Say("hidden items cannot be shown during combat."); return end
        if not ns.ViewingSelf() then Say("hidden items can only be shown for your own character."); return end
        ns.Open()
        if not (P.frame and P.frame:IsShown()) then return end
        ns.view.tab = "bags"
        P.showHiddenSlots = not P.showHiddenSlots
        P.Layout()
        Say(P.showHiddenSlots and "hidden items are shown (dimmed). Run /gtbag hidden again to hide them."
            or "hidden items are hidden again.")
    elseif cmd == "collapse" then
        if arg == "all" or arg == "none" then
            ns.CollapseAll(arg == "all")
            ns.Relayout()
            Say(arg == "all" and "all category sections folded (click a header to open one)." or "all category sections shown.")
        else
            Say("usage: /gtbag collapse all|none  (or click a category header in the category view)")
        end
    elseif cmd == "new" then
        if arg == "clear" then
            ns.ClearNew()
            Say("new-item marks cleared.")
        else
            Say("usage: /gtbag new clear")
        end
    elseif cmd == "ilvl" then
        ns.SetOpt("ilvl", arg ~= "off"); ns.Relayout()
        Say("item level " .. (ns.Opt("ilvl") and "on" or "off"))
    elseif cmd == "tiers" then
        -- debug: how the priority sort classifies each item in your bags (1 Hearthstone, 2 mount, 3 Chronoboon Displacer, 4 buff, 5 food, 6 potion, 7 gear, 8 other)
        for _, bag in ipairs(ns.BAGS) do
            local n = ns.GetNumSlots(bag)
            if type(n) == "number" then
                for slot = 1, n do
                    local info = ns.ItemInfo(bag, slot)
                    if info and tonumber(info.id) then
                        local m = ns.ItemMeta(info.id)
                        Say(ns.Name(info) .. "  class " .. tostring(m.class) .. "/" .. tostring(m.sub)
                            .. "  quality " .. tostring(info.quality) .. "  tier " .. ns.PriorityTier(info))
                    end
                end
            end
        end
    elseif cmd == "sort" then
        local rules = { type = true, quality = true, qualitycategory = true, expansion = true,
                        itemlevel = true, name = true, value = true, category = true, count = true, priority = true }
        if rules[arg] then
            ns.SetSort(arg)
            Say("item sort: " .. arg)
        else
            Say("usage: /gtbag sort priority|type|quality|qualitycategory|expansion|itemlevel|name|value|category|count")
        end
    elseif cmd == "merge" then
        if arg == "on" or arg == "off" then
            ns.SetOpt("mergeBags", arg == "on")
            if arg == "on" then ns.SetOpt("view", "bag") end
            ns.Relayout()
            Say("merge all bags into one group: " .. arg .. ".")
        else
            Say("usage: /gtbag merge on|off")
        end
    elseif cmd == "autosort" then
        if arg == "on" or arg == "off" then
            ns.SetOpt("autoSort", arg == "on")
            ns.Relayout()
            Say("visual auto sort " .. arg .. ".")
        else
            Say("usage: /gtbag autosort on|off")
        end
    elseif cmd == "bank" then
        ns.SetOpt("replaceBank", arg ~= "off")
        Say(ns.Opt("replaceBank") and "the bank is shown in GTBag." or "the game's bank window is used (visit the banker again).")
    elseif cmd == "guild" then
        ns.SetOpt("replaceGuild", arg ~= "off")
        Say(ns.Opt("replaceGuild") and "the guild bank is shown in GTBag." or "the game's guild bank window is used (visit the guild bank again).")
    elseif cmd == "nick" then
        local _, a1, a2 = (msg or ""):lower():match("^%s*(%S+)%s*(%S*)%s*(%S*)")
        if a1 == "clear" and a2 == "all" then
            for _, k in ipairs(ns.CharKeys()) do ns.SetNick(k, "") end
            Say("all nicknames cleared; real names are shown.")
            if ns.Relayout then ns.Relayout() end
        elseif a1 == "clear" then
            ns.SetNick(ns.ViewKey(), "")
            Say("nickname cleared for the character shown; its real name is shown.")
            if ns.Relayout then ns.Relayout() end
        else
            ns.EditNick(ns.ViewKey())  -- opens the nickname box for the character shown in the window
        end
    elseif cmd == "cat" or cmd == "category" then
        -- /gtbag cat                          list
        -- /gtbag cat add Name = rule, rule    make a category / add rules (ids, shift-clicked items, parts of a name)
        -- /gtbag cat remove Name = rule       take rules out;   /gtbag cat delete Name
        local sub, rest = (msg or ""):match("^%s*%S+%s*(%S*)%s*(.-)%s*$")
        sub = (sub or ""):lower()
        local name, rules = (rest or ""):match("^(.-)%s*=%s*(.*)$")
        local ok, text
        if sub == "edit" or sub == "editor" then
            if ns.ShowCatEditor then ns.ShowCatEditor() end
            return
        elseif sub == "add" or sub == "rule" then
            ok, text = ns.CatSave(name or rest, rules or "")
        elseif sub == "remove" or sub == "unrule" then
            ok, text = ns.CatRemoveRules(name or rest, rules or "")
        elseif sub == "delete" or sub == "del" then
            ok, text = ns.CatDelete(rest)
        else
            local list = ns.CustomCats()
            if #list == 0 then
                Say("no custom categories. Example: /gtbag cat add Alchemy = peacebloom, silverleaf, [shift-click an item]")
            end
            for _, c in ipairs(list) do
                local shown = {}
                for _, r in ipairs(c.rules) do shown[#shown + 1] = tostring(r) end
                Say(c.name .. " = " .. table.concat(shown, ", "))
            end
            return
        end
        Say(text)
        if ok and ns.Relayout then ns.Relayout() end
    elseif cmd == "bags" or cmd == "addons" then
        if arg == "frames" then
            if ns.BagFrameDiag then ns.BagFrameDiag() end
        elseif ns.ShowBagAddons then
            ns.ShowBagAddons(true)
        end
    elseif cmd == "draw" then
        if ns.DebugDraw then ns.DebugDraw() end
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        if ns.ShowSettings then ns.ShowSettings() end
    elseif cmd == "pin" or cmd == "lock" then
        if ns.PinCommand then ns.PinCommand((msg or ""):match("^%s*%S+%s*(.-)%s*$")) end
    elseif cmd == "junk" then
        if ns.JunkCommand then ns.JunkCommand((msg or ""):match("^%s*%S+%s*(.-)%s*$")) end
    elseif cmd == "gold" then
        local total1, total7 = 0, 0
        for _, key in ipairs(ns.CharKeys()) do
            local r = ns.Rec(key)
            local d1, d7 = ns.GoldChange(r, 1), ns.GoldChange(r, 7)
            total1, total7 = total1 + (d1 or 0), total7 + (d7 or 0)
            Say(string.format("%s  today %s, 7 days %s", ns.ClassName(r, true, true),
                ns.SignedMoney(d1) or "no change", ns.SignedMoney(d7) or "no change"))
        end
        Say(string.format("all characters  today %s, 7 days %s", ns.SignedMoney(total1) or "no change", ns.SignedMoney(total7) or "no change"))
    elseif cmd == "find" or cmd == "search" then
        local text = (msg or ""):match("^%s*%S+%s*(.-)%s*$") or ""
        if ns.ShowFind then ns.ShowFind(text) end
    elseif cmd == "scramble" or cmd == "privacy" then
        -- privacy mode: scrambles character names and guild names and hides gold amounts (display only)
        if arg == "on" or arg == "off" then ns.SetOpt("scrambleNames", arg == "on") else ns.SetOpt("scrambleNames", not ns.Opt("scrambleNames")) end
        if ns.Privacy() then ns.scrambleSalt = ((ns.scrambleSalt or 0) + 1) % 1000000 end
        Say(ns.Privacy() and "privacy mode on: character names, guild names and gold amounts are hidden."
            or "privacy mode off: names, guilds and gold are shown normally.")
        if ns.Relayout then ns.Relayout() end
    elseif cmd == "style" then
        local found
        for _, s in ipairs(ns.STYLES) do if s[1] == arg then found = true end end
        if found then
            ns.SetOpt("style", arg); ns.Relayout()
            Say("window style: " .. arg)
        else
            local names = {}
            for _, s in ipairs(ns.STYLES) do names[#names + 1] = s[1] end
            Say("usage: /gtbag style " .. table.concat(names, "|") .. "   (now: " .. ns.Opt("style") .. ")")
        end
    elseif cmd == "route" then
        if arg == "on" or arg == "off" then ns.SetOpt("routeBags", arg == "on") end
        Say("profession bag routing is " .. (ns.Opt("routeBags") and "on" or "off")
            .. " (Sort + Merge moves herbs, ore, gems... into matching profession bags).")
    elseif cmd == "ammo" then
        if arg == "off" then ns.SetOpt("warnAmmo", 0)
        else
            local n = tonumber(arg)
            if n then ns.SetOpt("warnAmmo", math.floor(n)) end
        end
        local n = ns.Opt("warnAmmo")
        Say(n > 0 and ("warning when arrows or bullets drop to " .. n .. " or fewer.") or "low-ammo warning is off.")
        if n > 0 and ns.AmmoCounts then
            local a = ns.AmmoCounts()
            Say(string.format("you carry %d arrows and %d bullets.", a.arrows, a.bullets))
        end
    elseif cmd == "backup" or cmd == "restore" then
        if ns.ShowBackup then ns.ShowBackup() end
    elseif cmd == "chars" then
        for _, key in ipairs(ns.CharKeys()) do
            local r = ns.Rec(key)
            Say(string.format("%s  bags %s, bank %s, mail %s%s", ns.ClassName(r, true, true), ns.Ago(r.bagsT), ns.Ago(r.bankT),
                ns.Ago(r.mail and r.mail.t), r.guild and ("  <" .. ns.GuildName(r.guild) .. ">") or ""))
        end
    elseif cmd == "forget" then
        local key
        local want = arg:lower()
        if want ~= "" and not want:find("-", 1, true) then want = want .. "-" .. (GetRealmName() or ""):lower() end
        for _, k in ipairs(ns.CharKeys()) do if k:lower() == want then key = k end end
        if key and ns.Forget(key) then Say("forgot " .. key .. ".")
        else Say("usage: /gtbag forget Name-Realm  (a character other than the one you play; /gtbag chars lists them)") end
        if ns.Relayout then ns.Relayout() end
    elseif cmd == "warn" then
        if arg == "off" then ns.SetOpt("warnFree", 0)
        else
            local n = tonumber(arg)
            if n then ns.SetOpt("warnFree", math.floor(n)) end
        end
        local n = ns.Opt("warnFree")
        Say(n > 0 and ("warning when " .. n .. " or fewer bag slots are free.") or "free-slot warning is off.")
    elseif cmd == "mail" then
        if ns.MailWatchReport then ns.MailWatchReport(false) end
    elseif cmd == "summary" then
        for _, line in ipairs(ns.Summary()) do Say(line) end
    elseif cmd == "actions" then
        ns.SetOpt("liveActions", arg == "on")
        Say("click and drag on your own bags: " .. (ns.Opt("liveActions") and "on" or "off (safe display)"))
        ns.Relayout()
    elseif cmd == "reset" then
        ns.ResetPosition(); Say("position reset.")
    elseif cmd == "layout" then
        ns.ApplyDefaultLayout(); Say("default layout applied (category view, 10 columns, tab row hidden, lower right).")
    else
        Say("/gtbag  (open / close)   settings (or right-click Opt)   bags (choose between bag addons)   view bag|category   sort priority|type|quality|qualitycategory|expansion|itemlevel|name|value|category|count   autosort on|off")
        Say("cols 8-15   scale 0.6-1.6   ilvl on|off   replace on|off")
        Say("bank on|off   guild on|off   warn N|off   ammo N|off   summary   chars   forget Name-Realm   reset")
        Say("style stack|columns|flat|list|sidebar   route on|off   privacy on|off   backup (export / import nicknames, categories, keep list)   junk [keep|unkeep|list|auto on|off]   pin [item]|list|clear|mode   hidden (show / hide the hidden items)")
    end
end
