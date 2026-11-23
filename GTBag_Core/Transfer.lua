-- Transfer.lua : right-click a section header (Herbs, Ore, ...) to move everything in it in one go.
--   * bags tab + bank open      -> "Move to bank"
--   * bank tab + bank open      -> "Move to bags"
--   * bags tab + mailbox open   -> "Mail to <character>" for each of your other saved characters: the Send Mail tab is
--                                  opened, the recipient filled in and up to 12 stacks attached.  You press Send yourself.
-- Items are moved the way a right-click does it (the game decides the target), only out of combat, and never: pinned
-- items, items in hidden slots, hidden items, locked items, or (for mail) soulbound items.
local _, ns = ...

local use = (C_Container and C_Container.UseContainerItem) or UseContainerItem
local function Say(msg) print("|cffffd100GTBag|r: " .. msg) end

-- the stacks of one section that may be moved: { { bag, slot, id, count }, ... }
-- list = the section's entries as the layout built them; tab = "bags" or "bank"
local function Collect(list, tab, forMail)
    local out = {}
    local P = ns.panel
    for _, e in ipairs(list or {}) do
        if e.info and e.live and e.bag ~= nil and e.slot ~= nil then
            local inInventory = ns.IsInventoryBag(e.bag)
            if (tab == "bags") == inInventory then
                local info = ns.ItemInfo(e.bag, e.slot)       -- read again: the layout may be a moment old
                if info and info.id and not info.locked
                    and not (forMail and info.bound)
                    and not (ns.IsPinned and ns.IsPinned(info.id))
                    and not (P and P.IsSlotHidden and P.IsSlotHidden(tab, e.bag, e.slot))
                    and not (P and P.IsItemHidden and P.IsItemHidden(info.id)) then
                    out[#out + 1] = { bag = e.bag, slot = e.slot, id = info.id, count = info.count or 1 }
                end
            end
        end
    end
    return out
end

local function Stacks(n) return n .. " stack" .. (n == 1 and "" or "s") end

-- Free slots in the general-purpose containers of one side (the bank or the bags).  Family bags (herb, quiver...) and the
-- reagent bag / reagent bank are left out: an empty slot there cannot take an arbitrary stack, so counting it could
-- promise room that is not there.  Returns nil when the game gives no answer.
local function FreeGeneralSlots(ids, skip)
    if not (ns.GetNumSlots and ns.GetNumFree and ids) then return nil end
    local free = 0
    for _, bag in ipairs(ids) do
        if not skip[bag] then
            local n = ns.GetNumSlots(bag)
            if type(n) == "number" and n > 0 then
                local ok, f, family = pcall(ns.GetNumFree, bag)
                if ok and type(f) == "number" and (tonumber(family) or 0) == 0 then free = free + f end
            end
        end
    end
    return free
end

-- bank <-> bags: the same call as a right-click, which the game turns into a transfer while the bank is open.  If the
-- other side cannot take a stack, the same right-click would try to USE it (drink a potion, equip a piece of gear), so
-- no more stacks are sent than the other side has free slots.  dest = "bank" or "bags".
local function MoveAll(items, label, dest)
    if InCombatLockdown() then Say("not in combat."); return end
    if not ns.atBank then Say("open the bank first."); return end
    local skip = {}
    local ids
    if dest == "bank" then
        ids = ns.BANK_IDS
        if ns.REAGENT_BANK_ID then skip[ns.REAGENT_BANK_ID] = true end
    else
        ids = ns.BAGS
        local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
        if reagentBag then skip[reagentBag] = true end
    end
    local total, held = #items, 0
    local free = FreeGeneralSlots(ids, skip)
    if free ~= nil then
        if free <= 0 then
            Say(string.format("%s: no free slot in the %s, nothing moved.", label, dest))
            return
        end
        if total > free then held = total - free; total = free end
    end
    local sent = 0
    for i = 1, total do
        local it = items[i]
        if not pcall(use, it.bag, it.slot) then
            Say(string.format("%s: a move failed, stopped after %s.", label, Stacks(sent)))
            return
        end
        sent = sent + 1
    end
    Say(string.format("%s: %s sent.%s", label, Stacks(sent),
        held > 0 and string.format(" %s held back because the %s has only %d free slot%s: free some room and click again.",
            Stacks(held), dest, free, free == 1 and "" or "s") or " Anything left did not fit."))
end

-- ---------------------------------------------------------------------------------------------- mail
local function MailSlotsUsed()
    local used = 0
    if not GetSendMailItem then return used end
    for a = 1, (ATTACHMENTS_MAX_SEND or 12) do
        local name = GetSendMailItem(a)
        if name and name ~= "" then used = used + 1 end
    end
    return used
end

local mailBusy = false
local function MailTo(items, key)
    if InCombatLockdown() then Say("not in combat."); return end
    local rec = ns.Rec(key)
    if not (rec and rec.name) then return end
    if not (ns.atMail and _G.SendMailNameEditBox) then Say("open a mailbox first."); return end
    if mailBusy then return end

    -- the recipient: another realm needs Name-Realm
    local to = rec.name
    if rec.realm and rec.realm ~= GetRealmName() then to = to .. "-" .. rec.realm:gsub("[%s%-]", "") end

    -- switch to the Send Mail tab like a click would
    local tab = _G.MailFrameTab2
    if tab and tab.Click then pcall(tab.Click, tab) end
    _G.SendMailNameEditBox:SetText(to)

    local max = ATTACHMENTS_MAX_SEND or 12
    local startUsed, i = MailSlotsUsed(), 0
    local attached = 0
    mailBusy = true
    local function Finish()
        mailBusy = false
        attached = MailSlotsUsed() - startUsed
        local left = #items - i
        Say(string.format("%s attached for %s. Press Send in the mail window.%s", Stacks(attached),
            ns.ClassName(rec, true, true), left > 0 and (" " .. Stacks(left) .. " left: right-click the header again after sending.") or ""))
    end
    local function Step()
        if InCombatLockdown() or not ns.atMail then mailBusy = false; return end
        if i >= #items or MailSlotsUsed() >= max then return Finish() end
        i = i + 1
        local it = items[i]
        if not pcall(use, it.bag, it.slot) then
            mailBusy = false             -- an error must not leave the mail action stuck busy until /reload
            Say("an attach failed, stopped. Check the mail window.")
            return
        end
        C_Timer.After(0.2, Step)         -- one item at a time: the game locks the stack while it moves
    end
    Step()
end

-- the menu entries for one section header (see PanelMenus: right-click on a header)
function ns.TransferMenu(list, tab, title)
    local entries = {}
    if not (ns.ViewingSelf() and (tab == "bags" or tab == "bank")) then
        return { { text = "Transfer works on your own bags and bank.", enabled = false } }
    end
    local items = Collect(list, tab, false)
    entries[#entries + 1] = { text = string.format("%s: %s", title or "Section", Stacks(#items)), enabled = false }
    if #items == 0 then
        entries[#entries + 1] = { text = "Nothing to move (pinned, hidden or locked items stay).", enabled = false }
        return entries
    end
    if tab == "bags" then
        entries[#entries + 1] = { text = "Move to bank" .. (ns.atBank and "" or "  (open the bank)"), enabled = ns.atBank and true or false,
            func = function() MoveAll(Collect(list, tab, false), "to bank", "bank") end }
        local mailItems = Collect(list, tab, true)
        if ns.atMail then
            local me, any = ns.MyKey(), false
            for _, key in ipairs(ns.CharKeys()) do
                if key ~= me then
                    any = true
                    local rec = ns.Rec(key)
                    entries[#entries + 1] = { text = "Mail to " .. ns.ClassName(rec, rec.realm ~= GetRealmName(), true)
                            .. (#mailItems < #items and string.format("  (%s, soulbound skipped)", Stacks(#mailItems)) or ""),
                        enabled = #mailItems > 0,
                        func = function() MailTo(Collect(list, tab, true), key) end }
                end
            end
            if not any then entries[#entries + 1] = { text = "No other saved character to mail to.", enabled = false } end
        else
            entries[#entries + 1] = { text = "Mail to a character  (open a mailbox)", enabled = false }
        end
    else
        entries[#entries + 1] = { text = "Move to bags" .. (ns.atBank and "" or "  (open the bank)"), enabled = ns.atBank and true or false,
            func = function() MoveAll(Collect(list, tab, false), "to bags", "bags") end }
    end
    return entries
end
