-- Items.lua : item buttons. Saved, remote and mail items are read-only. Your own bag and bank items use Blizzard's
-- item buttons only when /gtbag actions is on; those buttons handle their own clicks and drags.
-- A button belongs to one bag slot: its parent frame carries the bag id, the button the slot number.
local _, ns = ...

local SIZE, STEP = 36, 40
ns.SIZE, ns.STEP = SIZE, STEP

local statics = {}
local liveButtons = {}

local function Child(b, key, suffix)
    local c = b[key]
    if c then return c end
    local n = b:GetName()
    return n and _G[n .. suffix] or nil
end

local function Style(b)
    local nt = b:GetNormalTexture(); if nt then nt:SetTexture(nil); nt:SetAlpha(0) end
    local pt = b:GetPushedTexture(); if pt then pt:SetAlpha(0) end
    local ht = b:GetHighlightTexture(); if ht then ht:SetColorTexture(1, 1, 1, 0.25) end
    for _, k in ipairs({ "IconBorder", "NewItemTexture", "BattlepayItemTexture", "IconOverlay", "IconOverlay2", "JunkIcon", "UpgradeIcon" }) do
        if b[k] then b[k]:SetAlpha(0) end
    end
    local border = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    border:SetAllPoints()
    border:SetColorTexture(0.25, 0.25, 0.25, 1)
    b.gtBorder = border
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.06, 0.06, 0.06, 1)
    local icon = Child(b, "icon", "IconTexture")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 2, -2); icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.gtIcon = icon
    end
    -- rounded corners: the quality frame uses one mask, the dark backing and the icon a slightly smaller one
    if b.CreateMaskTexture and border.AddMaskTexture then
        local MASK = "Interface\\AddOns\\GTBag_Core\\Media\\RoundMask.tga"
        local outer = b:CreateMaskTexture()
        outer:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        outer:SetAllPoints(b)
        local inner = b:CreateMaskTexture()
        inner:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)
        border:AddMaskTexture(outer)
        bg:AddMaskTexture(inner)
        if icon then icon:AddMaskTexture(inner) end
        if ht and ht.AddMaskTexture then ht:AddMaskTexture(outer) end
        b.gtMasks = { outer, inner }
    end
    b.gtBadges = {}
    for _, key in ipairs({ "boe", "ilvl" }) do
        local badge = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        badge:SetSize(20, 12)
        badge:SetJustifyH(key == "boe" and "LEFT" or "RIGHT")
        b.gtBadges[key] = badge
    end
    b.gtBadges.pawn = b:CreateTexture(nil, "OVERLAY")
    b.gtBadges.pawn:SetSize(12, 12)
    b.gtBadges.pawn:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    b.gtJunk = b:CreateTexture(nil, "OVERLAY")
    b.gtJunk:SetSize(12, 12)
    b.gtJunk:SetPoint("BOTTOMRIGHT", -2, 2)
    b.gtJunk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    b.gtJunk:Hide()
    -- pinned item = big gold star plus a gold glow around the slot (see Pins.lua); the raid-target sheet's first icon is the star
    b.gtPinGlow = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.gtPinGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.gtPinGlow:SetBlendMode("ADD")
    b.gtPinGlow:SetVertexColor(1, 0.82, 0, 1)
    b.gtPinGlow:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.gtPinGlow:SetSize(SIZE * 1.75, SIZE * 1.75)
    b.gtPinGlow:Hide()
    b.gtPinBack = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.gtPinBack:SetSize(13, 13)
    b.gtPinBack:SetPoint("TOPLEFT", -1, 1)
    b.gtPinBack:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    b.gtPinBack:SetVertexColor(0, 0, 0, 0.75)
    b.gtPinBack:Hide()
    b.gtPin = b:CreateTexture(nil, "OVERLAY", nil, 3)
    b.gtPin:SetSize(11, 11)
    b.gtPin:SetPoint("TOPLEFT", 0, 0)
    b.gtPin:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    b.gtPin:SetTexCoord(0, 0.25, 0, 0.25)
    b.gtPin:Hide()
    -- green glow = arrived in your bags this session (see NewItems.lua)
    b.gtNew = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.gtNew:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.gtNew:SetBlendMode("ADD")
    b.gtNew:SetVertexColor(0.35, 1, 0.35, 0.9)
    b.gtNew:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.gtNew:SetSize(SIZE * 1.75, SIZE * 1.75)
    b.gtNew:Hide()
    local cd = Child(b, "Cooldown", "Cooldown")
    if cd then b.gtCooldown = cd end
end

-- re-check the star on every shown button (after a pin changed)
local function SetPinMark(b, on)
    if b.gtPin then b.gtPin:SetShown(on) end
    if b.gtPinBack then b.gtPinBack:SetShown(on) end
    if b.gtPinGlow then b.gtPinGlow:SetShown(on) end
end

function ns.RefreshPinMarks()
    for _, list in ipairs({ statics, liveButtons }) do
        for _, b in ipairs(list) do
            local info = b.gtEntry and b.gtEntry.info
            SetPinMark(b, info ~= nil and ns.IsPinned(info.id))
        end
    end
end

-- is this button one of your own inventory slots (not the bank, a guild bank, mail or another character)?
local function ShowsNew(b, info)
    local e = b.gtEntry
    if not (info and e and e.live and e.kind ~= "mail" and e.kind ~= "bank" and e.kind ~= "guild") then return false end
    return ns.IsInventoryBag and ns.IsInventoryBag(e.bag) and ns.IsNew and ns.IsNew(info.id) or false
end

function ns.RefreshNewMarks()
    for _, list in ipairs({ statics, liveButtons }) do
        for _, b in ipairs(list) do
            if b.gtNew then b.gtNew:SetShown(b:IsShown() and ShowsNew(b, b.gtEntry and b.gtEntry.info)) end
        end
    end
end

function ns.HideAllButtons()
    for _, b in ipairs(statics) do
        b.gtEntry = nil
        if b.gtSlotVisibilityButton then
            b.gtSlotVisibilityButton.gtEntry = nil
        end
        b:Hide()
    end
    -- live buttons are Blizzard secure templates: they cannot be hidden in combat, so leave them as they are then
    if InCombatLockdown() then return end
    for _, b in ipairs(liveButtons) do
        b.gtEntry = nil
        if b.gtSlotVisibilityButton then
            b.gtSlotVisibilityButton.gtEntry = nil
        end
        b:Hide()
    end
end

function ns.AnyLiveShown()
    for _, b in ipairs(liveButtons) do
        if b:IsShown() then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------------------------- static buttons
-- These buttons display saved or remote items only; they never act on items.
local function DaysText(left)
    if left >= 2 then return string.format("%d days", math.floor(left)) end
    return string.format("%d h", math.max(1, math.floor(left * 24)))
end

local function StaticEnter(self)
    local e = self.gtEntry
    local info = e and e.info
    if not info then return end
    if self.gtNew and self.gtNew:IsShown() and ns.ClearNew then ns.ClearNew(info.id) end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local done = false
    if e.kind == "guild" and e.live and GameTooltip.SetGuildBankItem then
        done = pcall(GameTooltip.SetGuildBankItem, GameTooltip, e.bag, e.slot)
    end
    if not done and info.link then done = pcall(GameTooltip.SetHyperlink, GameTooltip, info.link) end
    if not done then GameTooltip:SetText(ns.Name(info)) end
    local m = info.mail
    if m then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Mail from " .. (m.from or "?") .. (m.sent and " (sent by you)" or ""), 0.7, 0.8, 1)
        if m.left < 3 then GameTooltip:AddLine("Expires in " .. DaysText(m.left), 1, 0.3, 0.3)
        else GameTooltip:AddLine("Expires in " .. DaysText(m.left), 0.7, 0.7, 0.7) end
        if m.cod and m.cod > 0 then
            GameTooltip:AddLine("Cash on delivery " .. ns.Money(m.cod) .. " - open the mail to pay", 1, 0.3, 0.3)
        elseif e.live and m.idx then
            GameTooltip:AddLine("Open the mailbox to collect", 0.5, 1, 0.5)
        end
    end
    GameTooltip:Show()
end

function ns.GetStatic(i, parent)
    local b = statics[i]
    if b then
        if b:GetParent() ~= parent then b:SetParent(parent) end
        return b
    end
    b = CreateFrame("Button", "GTBagStatic" .. i, parent, "ItemButtonTemplate")
    b:SetSize(SIZE, SIZE)
    Style(b)
    b.gtStatic = true
    b:SetScript("OnClick", nil)
    b:SetScript("OnDragStart", nil)
    b:SetScript("OnReceiveDrag", nil)
    b:SetScript("OnEnter", StaticEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    statics[i] = b
    return b
end

-- Your own bag and bank slots: Blizzard's item button, so click, right-click use, shift-click split and drag/drop
-- moves are the game's own.  Returns nil (and turns live buttons off) on a client that cannot bind a slot.
function ns.GetLive(i, parent)
    if ns.LiveActions == false then return nil end
    local b = liveButtons[i]
    if b then
        if b:GetParent() ~= parent then b:SetParent(parent) end
        return b
    end
    b = CreateFrame("ItemButton", "GTBagLive" .. i, parent, "ContainerFrameItemButtonTemplate")
    if not b.SetBagID then
        ns.LiveActions = false
        return nil
    end
    b:SetSize(SIZE, SIZE)
    Style(b)
    b.gtLive = true
    b:HookScript("OnEnter", function(self)
        local e = self.gtEntry
        if e and e.info and self.gtNew and self.gtNew:IsShown() and ns.ClearNew then ns.ClearNew(e.info.id) end
    end)
    liveButtons[i] = b
    return b
end

local qualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor
local ilvlFn = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
local cooldownFn = (ns.CONT and ns.CONT.GetContainerItemCooldown) or GetContainerItemCooldown
local badgeKeys = { "boe", "ilvl", "pawn" }
local badgeText, occupiedCorners, badgePriority = {}, {}, {}
local cachedBadgePriority

local function BadgePriority()
    local configured = ns.Opt("badgePriority")
    if configured ~= cachedBadgePriority then
        cachedBadgePriority = configured
        wipe(badgePriority)
        for key in (configured .. ","):gmatch("(.-),") do
            badgePriority[#badgePriority + 1] = key
        end
    end
    return badgePriority
end

local function PawnUpgrade(link)
    local check = _G.PawnIsItemAnUpgrade
    if type(check) ~= "function" or not link then return false end
    local ok, upgrade = pcall(check, link)
    return ok and not not upgrade
end

local function SetBadgePoint(badge, corner)
    badge:ClearAllPoints()
    local point = (corner == "TOPLEFT" or corner == "TOPRIGHT"
        or corner == "BOTTOMLEFT" or corner == "BOTTOMRIGHT") and corner or "TOPLEFT"
    local x = point:find("RIGHT", 1, true) and -3 or 3
    local y = point:find("BOTTOM", 1, true) and 3 or -3
    badge:SetPoint(point, x, y)
end

local inventoryLabels = {
    { "bags", "Bags" }, { "bank", "Bank" }, { "guild", "Guild bank" },
    { "void", "Void storage" }, { "mail", "Mail" }, { "auctions", "Active auctions" },
}

-- adds the "GTBag inventory" lines to an item tooltip.  Retail (10.0.2+) uses TooltipDataProcessor; older clients
-- still fire OnTooltipSetItem.
local function AddInventoryLines(tooltip, link)
    if not (tooltip and tooltip.AddLine and ns.InventoryCounts) then return end
    local id = link and tonumber(tostring(link):match("item:(%d+)"))
    if not id or tooltip.gtBagInventoryItem == id then return end
    tooltip.gtBagInventoryItem = id
    if ns.IsPinned(id) then
        tooltip:AddLine("GTBag: pinned (not sold as junk, not deleted, not moved by sorting)", 1, 0.82, 0)
    end
    local counts = ns.InventoryCounts(id)
    if not counts then return end
    local total, lines = 0, {}
    for _, entry in ipairs(inventoryLabels) do
        local count = counts[entry[1]] or 0
        if count > 0 then
            total = total + count
            local label = entry[2]
            local scannedAt = counts[entry[1] .. "T"]
            if scannedAt and ns.Ago then label = label .. " (checked " .. ns.Ago(scannedAt) .. ")" end
            lines[#lines + 1] = label .. ": " .. count
        end
    end
    tooltip:AddLine(" ")
    tooltip:AddLine("GTBag inventory (" .. total .. ")", 1, 0.82, 0)
    if #lines == 0 then
        tooltip:AddLine("No known copies", 0.7, 0.7, 0.7)
    else
        for _, line in ipairs(lines) do tooltip:AddLine(line, 0.8, 0.8, 0.8) end
    end
    -- which character holds the copies (the character count only matters when there is more than one place)
    local chars = ns.InventoryByChar and ns.InventoryByChar(id) or {}
    if #chars > 0 and total > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("By character", 1, 0.82, 0)
        local realm = GetRealmName and GetRealmName()
        for n, e in ipairs(chars) do
            if n > 8 then
                tooltip:AddLine("... and " .. (#chars - 8) .. " more", 0.6, 0.6, 0.6)
                break
            end
            local parts = {}
            for _, p in ipairs({ { "bags", "bags" }, { "bank", "bank" }, { "mail", "mail" },
                                 { "void", "void" }, { "auctions", "auctions" } }) do
                if e[p[1]] > 0 then parts[#parts + 1] = p[2] .. " " .. e[p[1]] end
            end
            tooltip:AddLine(ns.ClassName(e.rec, e.rec.realm ~= realm, true) .. ": |cffcccccc" .. table.concat(parts, ", ") .. "|r")
        end
    end
    if tooltip.Show then tooltip:Show() end
end

-- Privacy mode: other addons (GatherTimes lists your characters under "Inventory") add real character names to the
-- same tooltip.  Replace every known character name in the tooltip text with the scrambled one GTBag shows elsewhere.
-- Display-only, and a no-op unless privacy mode is on.
local tooltipSides = { "TextLeft", "TextRight" }
local tooltipLines = { TextLeft = {}, TextRight = {} }     -- the tooltip's line frames, looked up once (GameTooltip only)
local function TooltipLine(tipName, side, i)
    local cache = tooltipLines[side]
    local fs = cache[i]
    if not fs then
        fs = _G[tipName .. side .. i]
        if fs then cache[i] = fs end
    end
    return fs
end
-- The list of names to replace is kept for a few seconds (or until the salt or a nickname changes): building it for
-- every item tooltip made a pile of short-lived tables and strings.
local nameList, nameListAt, nameListSalt, nameListEpoch
local function NameList()
    local now = GetTime and GetTime() or 0
    local salt, epoch = ns.scrambleSalt or 0, ns.nameEpoch or 0
    if nameList and nameListSalt == salt and nameListEpoch == epoch and now >= nameListAt and now - nameListAt < 5 then
        return nameList
    end
    -- the real name and the nickname of every saved character both become the one scrambled name GTBag shows for it
    -- (the nickname when there is one, like the bag window), longest first so a short name never cuts a longer one
    local names = {}
    local function AddName(text, shown)
        if type(text) == "string" and #text >= 2 then
            names[#names + 1] = { #text, text, (text:gsub("%p", "%%%0")), (shown:gsub("%%", "%%%%")) }
        end
    end
    for _, key in ipairs(ns.CharKeys()) do
        local rec = ns.Rec(key)
        if rec and type(rec.name) == "string" then
            local nick = type(rec.nick) == "string" and rec.nick ~= "" and rec.nick or nil
            local shown = ns.Scramble(nick or rec.name)
            AddName(rec.name, shown)
            if nick then AddName(nick, shown) end
        end
    end
    table.sort(names, function(a, b) return a[1] > b[1] end)
    nameList, nameListAt, nameListSalt, nameListEpoch = names, now, salt, epoch
    return names
end

local function ScrambleTooltipNames(tooltip)
    if not (tooltip and tooltip.NumLines and ns.Privacy and ns.Privacy() and ns.CharKeys and ns.Rec) then return end
    local tipName = tooltip.GetName and tooltip:GetName()
    if not tipName then return end
    local names = NameList()
    if #names == 0 then return end
    for i = 2, tooltip:NumLines() do          -- line 1 is the item name: never touched
        for _, side in ipairs(tooltipSides) do
            local fs = TooltipLine(tipName, side, i)
            local text = fs and fs.GetText and fs:GetText()
            if text and text ~= "" then
                local out = text
                for _, n in ipairs(names) do
                    if out:find(n[2], 1, true) then       -- plain search first: most lines hold no name at all
                        -- a name right after a colour code ("|cff69ccf0Name|r") has a hex digit in front of it, so it needs its own pattern
                        out = out:gsub("(|c%x%x%x%x%x%x%x%x)" .. n[3] .. "%f[%W]", "%1" .. n[4])
                        out = out:gsub("%f[%w]" .. n[3] .. "%f[%W]", n[4])
                    end
                end
                if out ~= text then fs:SetText(out) end
            end
        end
    end
end
-- the other addon may add its lines after this hook ran: one more pass on the next frame (one shared callback, not a
-- new function for every tooltip)
local pendingTip
local function RunPending()
    local tip = pendingTip
    pendingTip = nil
    if tip and tip:IsShown() then ScrambleTooltipNames(tip) end
end
local function AfterTooltip(tooltip)
    if not (ns.Privacy and ns.Privacy()) then return end
    ScrambleTooltipNames(tooltip)
    if C_Timer and C_Timer.After and not pendingTip then
        pendingTip = tooltip
        C_Timer.After(0, RunPending)
    end
end

local modernTooltips = false
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    modernTooltips = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip then return end
        local link = data and data.hyperlink
        if not link and tooltip.GetItem then link = select(2, tooltip:GetItem()) end
        if not link and data and data.id then link = "item:" .. data.id end
        AddInventoryLines(tooltip, link)
        AfterTooltip(tooltip)
    end)
end
if GameTooltip and GameTooltip.HookScript then
    if not modernTooltips then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(tooltip)
            if not tooltip.GetItem then return end
            AddInventoryLines(tooltip, (select(2, tooltip:GetItem())))
            AfterTooltip(tooltip)
        end)
    end
    GameTooltip:HookScript("OnHide", function(tooltip)
        tooltip.gtBagInventoryItem = nil
    end)
end

-- lower-case form of a label / type name, cached (bounded): the search runs for every button on every refresh
local lowerCache, lowerCount = {}, 0
local function Lower(s)
    if not s or s == "" then return "" end
    local l = lowerCache[s]
    if not l then
        if lowerCount >= 256 then wipe(lowerCache); lowerCount = 0 end
        l = s:lower()
        lowerCache[s] = l
        lowerCount = lowerCount + 1
    end
    return l
end

function ns.MatchesPlain(info, query)
    if not query or query == "" then return true end
    if not info then return false end
    if ns.LowerName(info):find(query, 1, true) then return true end
    if Lower(ns.CatLabel(ns.Category(info))):find(query, 1, true) then return true end
    if Lower(ns.CATLABEL[ns.BaseCategory(info)]):find(query, 1, true) then return true end
    -- item type and subtype as the client names them ("cloth", "potion", "plate")
    local facts = ns.ItemFacts(info.id, info.link)
    if facts then
        if facts.type and Lower(facts.type):find(query, 1, true) then return true end
        if facts.sub and Lower(facts.sub):find(query, 1, true) then return true end
    end
    return false
end

-- the search box and the All search: plain words as before, or the query language (Query.lua) when there is an operator
function ns.Matches(info, query)
    if not query or query == "" then return true end
    if not info then return false end
    if ns.QueryHas and ns.QueryHas(query) then return ns.QueryMatch(info, query) end
    return ns.MatchesPlain(info, query)
end

-- List style: a name and a detail line beside the icon.  b.gtRowW is the row width (nil in the other styles).
local function RowText(b, info)
    local row = b.gtRow
    if not b.gtRowW then
        if row then row.name:Hide(); row.detail:Hide() end
        return
    end
    if not row then
        row = { name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
                detail = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") }
        for _, fs in pairs(row) do fs:SetJustifyH("LEFT"); fs:SetWordWrap(false) end
        b.gtRow = row
    end
    local w = math.max(10, b.gtRowW - SIZE - 6)
    row.name:ClearAllPoints(); row.name:SetPoint("TOPLEFT", b, "TOPRIGHT", 6, -3); row.name:SetWidth(w)
    row.detail:ClearAllPoints(); row.detail:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 6, 3); row.detail:SetWidth(w)
    if not info then
        row.name:SetText(""); row.detail:SetText(""); b.gtRowKey = nil
    else
        -- the price is looked up once per item and stack size, not on every refresh (Panel clears the key on a redraw)
        if b.gtRowKey ~= true or b.gtRowId ~= info.id or b.gtRowCount ~= info.count or b.gtRowQuality ~= info.quality then
            b.gtRowKey = true
            b.gtRowId, b.gtRowCount, b.gtRowQuality = info.id, info.count, info.quality
            local r, g, bl = 1, 1, 1
            if info.quality and qualityColor then r, g, bl = qualityColor(info.quality) end
            row.name:SetText(string.format("|cff%02x%02x%02x%s|r", math.floor((r or 1) * 255 + 0.5),
                math.floor((g or 1) * 255 + 0.5), math.floor((bl or 1) * 255 + 0.5), ns.Name(info)))
            local count = tonumber(info.count) or 1
            local value = ns.UnitValue(info.id, info.link) * count
            local parts = {}
            if count > 1 then parts[#parts + 1] = "x" .. count end
            parts[#parts + 1] = ns.CatLabel(ns.Category(info)) or ""
            if value > 0 then parts[#parts + 1] = ns.ShortMoney(value) end
            row.detail:SetText(table.concat(parts, "  "))
        end
    end
    row.name:Show(); row.detail:Show()
end

-- Panel calls this for every placed button: w = row width in the List style, nil otherwise
function ns.SetRowWidth(b, w)
    b.gtRowKey = nil
    if b.gtRowW ~= w then
        b.gtRowW = w
        -- let the whole row react to the mouse, not only the icon (a protected button cannot change in combat)
        if not (b.gtLive and InCombatLockdown()) then
            pcall(b.SetHitRectInsets, b, 0, w and -(w - SIZE) or 0, 0, 0)
        end
    end
end

function ns.UpdateButton(b, bag, slot, info, query)
    wipe(badgeText)
    wipe(occupiedCorners)
    local icon = info and info.icon or nil
    SetItemButtonTexture(b, icon)
    SetItemButtonCount(b, info and info.count or 0)
    SetItemButtonDesaturated(b, info and info.locked and true or false)
    local r, g, bl = 0.25, 0.25, 0.25
    if info and info.quality and info.quality > 1 and qualityColor then
        local qr, qg, qb = qualityColor(info.quality)
        if qr then r, g, bl = qr, qg, qb end
    end
    b.gtBorder:SetColorTexture(r, g, bl, 1)
    b.gtJunk:SetShown(info ~= nil and info.quality == 0)
    SetPinMark(b, info ~= nil and ns.IsPinned(info.id))
    if b.gtNew then b.gtNew:SetShown(ShowsNew(b, info)) end
    -- the item template says BoE even after it is equipped; the slot itself says whether it is bound now
    if info and ns.Opt("boe") and info.link and not info.bound then
        local facts = ns.ItemFacts(info.id, info.link)
        if facts and facts.bind == 2 then badgeText.boe = "|cffffd100BoE|r" end
    end
    if info and info.badge then
        badgeText.ilvl = "|cffff5050" .. info.badge .. "|r"
    elseif info and ns.Opt("ilvl") and ilvlFn and info.link and info.quality and info.quality >= 2 then
        local cat = ns.BaseCategory(info)
        if cat == "equip" then
            local ok, n = pcall(ilvlFn, info.link)
            if ok and type(n) == "number" and n > 1 then badgeText.ilvl = tostring(n) end
        end
    end
    if info and ns.Opt("pawn") and ns.BaseCategory(info) == "equip" and PawnUpgrade(info.link) then
        badgeText.pawn = true
    end
    for _, key in ipairs(BadgePriority()) do
        local text = badgeText[key]
        local texture = b.gtBadges[key]
        if texture then
            local corner = ns.Opt(key .. "Corner")
            SetBadgePoint(texture, corner)
            local show = text and not occupiedCorners[corner]
            if show and key ~= "pawn" then
                texture:SetText(text)
                occupiedCorners[corner] = true
            elseif show and key == "pawn" then
                texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                occupiedCorners[corner] = true
            end
            texture:SetShown(show and true or false)
        end
    end
    for _, key in ipairs(badgeKeys) do
        if not badgeText[key] then b.gtBadges[key]:Hide() end
    end
    local alpha = ns.Matches(info, query) and 1 or 0.2
    if b.gtEntry and b.gtEntry.peeked then alpha = alpha * 0.55 end   -- item from a hidden slot, shown by right-clicking the eye button
    b:SetAlpha(alpha)
    RowText(b, info)
    -- only live bag / bank slots have cooldowns; saved and remote items never show one
    if b.gtCooldown then
        local start, duration, enable
        if info and b.gtEntry and b.gtEntry.liveSlot and cooldownFn then
            local ok, s, d, e = pcall(cooldownFn, bag, slot)
            if ok then start, duration, enable = s, d, e end
        end
        if start and start > 0 and duration and duration > 0 then
            CooldownFrame_Set(b.gtCooldown, start, duration, enable)
        else
            CooldownFrame_Set(b.gtCooldown, 0, 0, 0)
        end
    end
end
