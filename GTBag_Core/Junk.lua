-- Junk.lua : sell the grey items with one click while a vendor window is open.  Only poor-quality (grey) items are
-- sold, and never the ones on the keep list (/gtbag junk keep [item]).
local _, ns = ...

local atMerchant = false
local btn

local use = (C_Container and C_Container.UseContainerItem) or UseContainerItem

local function Keep()
    GTBagDB = GTBagDB or {}
    if type(GTBagDB.junkKeep) ~= "table" then GTBagDB.junkKeep = {} end
    return GTBagDB.junkKeep
end

-- the keep list as a sorted array of item ids, and a way to add or remove one (used by the backup window)
function ns.JunkKeepList()
    local out = {}
    for id in pairs(Keep()) do
        if tonumber(id) then out[#out + 1] = tonumber(id) end
    end
    table.sort(out)
    return out
end
function ns.JunkSetKeep(id, on)
    id = tonumber(id)
    if not id then return false end
    Keep()[id] = on and true or nil
    return true
end

-- { { bag, slot, link, count, price }, ... } and the total vendor price
function ns.JunkList()
    local list, total = {}, 0
    if not (ns.GetNumSlots and ns.ItemInfo) then return list, total end
    local keep = Keep()
    for _, bag in ipairs(ns.BAGS) do
        local n = ns.GetNumSlots(bag)
        if type(n) == "number" then
            for slot = 1, n do
                local info = ns.ItemInfo(bag, slot)
                if info and info.quality == 0 and info.id and not info.locked and not keep[info.id]
                    and not (ns.IsPinned and ns.IsPinned(info.id))
                    -- items in hidden slots are never sold: you cannot see them, so they stay where they are
                    and not (ns.panel and ns.panel.IsSlotHidden and ns.panel.IsSlotHidden("bags", bag, slot))
                    and not (ns.panel and ns.panel.IsItemHidden and ns.panel.IsItemHidden(info.id)) then
                    local sell = info.link and select(11, ns.GetItemInfo(info.link)) or select(11, ns.GetItemInfo(info.id))
                    local price = (tonumber(sell) or 0) * (tonumber(info.count) or 1)
                    -- grey items the vendor does not buy (no sell price) are left out of the list and the count
                    if price > 0 then
                        list[#list + 1] = { bag = bag, slot = slot, link = info.link, count = info.count, price = price }
                        total = total + price
                    end
                end
            end
        end
    end
    return list, total
end

local function UpdateButton()
    if not btn then return end
    local list, total = ns.JunkList()
    if atMerchant and #list > 0 then
        btn:SetText(string.format("Sell junk (%d)", #list))
        btn.total = total
        btn:Show()
    else
        btn:Hide()
    end
end

-- auto: called by the auto-sell option, so stay quiet when there is nothing to sell
ns.UpdateJunkButton = UpdateButton

-- the vendor's Buyback tab keeps only the last 12 items: a manual sale of more stacks asks first
local BUYBACK_LIMIT = 12
if StaticPopupDialogs then
    StaticPopupDialogs["GTBAG_SELL_MANY_JUNK"] = {
        text = "Sell %s junk stacks?\n\nThe vendor's Buyback tab keeps only the last 12 items, so most of them could not be bought back.",
        button1 = "Sell",
        button2 = CANCEL or "Cancel",
        OnAccept = function() ns.SellJunk(false, true) end,
        timeout = 0, whileDead = false, hideOnEscape = true, preferredIndex = 3,
    }
end

function ns.SellJunk(auto, confirmed)
    if not atMerchant or (_G.MerchantFrame and not _G.MerchantFrame:IsShown()) then
        if not auto then print("|cffffd100GTBag|r: open a vendor window first.") end
        return
    end
    if InCombatLockdown() then return end
    local list, total = ns.JunkList()
    if #list == 0 then
        if not auto then print("|cffffd100GTBag|r: no junk to sell.") end
        return
    end
    if not auto and not confirmed and #list > BUYBACK_LIMIT and StaticPopup_Show then
        StaticPopup_Show("GTBAG_SELL_MANY_JUNK", tostring(#list))
        return
    end
    for _, e in ipairs(list) do use(e.bag, e.slot) end
    print(string.format("|cffffd100GTBag|r: %ssold %d junk stack(s) for about %s. (The vendor's Buyback tab keeps the last 12.)",
        auto and "auto-" or "", #list, ns.Money(total)))
end

-- optional: sell the grey items as soon as a vendor window opens.  Off by default; the keep list still applies.
local function AutoSell()
    if not ns.Opt("autoSellJunk") then return end
    if not C_Timer or not C_Timer.After then return end
    C_Timer.After(0.3, function()          -- let the vendor window and the bag data settle first
        if atMerchant and ns.Opt("autoSellJunk") then ns.SellJunk(true) end
    end)
end

local function Ensure()
    local f = _G.GTBagFrame
    if not f or btn then return end
    btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(96, 20)
    btn:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
    btn:SetText("Sell junk")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.SetOpt("autoSellJunk", not ns.Opt("autoSellJunk"))
            print("|cffffd100GTBag|r: auto-sell junk " .. (ns.Opt("autoSellJunk") and "on (sells grey items when a vendor opens)." or "off."))
        else
            ns.SellJunk()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sell all grey items (not the ones on your keep list)")
        if self.total and self.total > 0 then GameTooltip:AddLine("About " .. ns.Money(self.total), 1, 1, 1) end
        GameTooltip:AddLine("Right-click: auto-sell on vendor open is " .. (ns.Opt("autoSellJunk") and "ON" or "off"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Hide()
    UpdateButton()
end

if hooksecurefunc then pcall(hooksecurefunc, ns, "Open", function() Ensure(); UpdateButton() end) end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then atMerchant = true; AutoSell()
    elseif event == "MERCHANT_CLOSED" then atMerchant = false end
    Ensure()
    UpdateButton()
end)

-- /gtbag junk [keep|unkeep|list|auto on|off] [item]
function ns.JunkCommand(rest)
    rest = rest or ""
    local sub, arg = rest:match("^%s*(%S*)%s*(.-)%s*$")
    sub = (sub or ""):lower()
    local Say = ns.Say
    if sub == "keep" or sub == "unkeep" then
        local id = tonumber(arg:match("item:(%d+)") or arg:match("^#?(%d+)$"))
        if not id then Say("shift-click an item or give its item id: /gtbag junk " .. sub .. " [item]"); return end
        Keep()[id] = (sub == "keep") or nil
        Say((ns.GetItemInfo(id) or ("item " .. id)) .. (sub == "keep" and " will never be sold as junk." or " can be sold as junk again."))
        UpdateButton()
    elseif sub == "list" then
        local any = false
        for id in pairs(Keep()) do
            any = true
            Say((ns.GetItemInfo(id) or "item") .. " (" .. id .. ")")
        end
        if not any then Say("the keep list is empty.") end
    elseif sub == "auto" then
        local a = arg:lower()
        if a == "on" or a == "off" then ns.SetOpt("autoSellJunk", a == "on") end
        Say("auto-sell junk is " .. (ns.Opt("autoSellJunk") and "ON: grey items are sold when a vendor window opens (keep list respected)."
            or "off. Use /gtbag junk auto on to turn it on."))
    else
        ns.SellJunk()
    end
end
