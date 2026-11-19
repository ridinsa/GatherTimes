-- AuctionScan.lua : "GT Scan" button on the auction house (Classic-style AuctionFrame) and an own price list for ALL items.
-- One click asks the server for the whole auction list (the game allows that once every 15 minutes), reads the lowest
-- buyout per item and replaces the saved list.  The price is shown in every item tooltip ("Auction (GatherTimes scan)")
-- together with how old the scan is, and it is used first by the herb / ore tooltip and the session summary.
-- Saved in GatherTimesDB.ahPrices[realm] = { t = time of the scan, p = { [itemId] = copper per item } }.
local _, GT = ...

local COOLDOWN = 15 * 60          -- the server's limit for a full scan
local CHUNK = 1500                -- auctions read per frame, so a big realm does not freeze the game
local TIMEOUT = 45                -- seconds to wait for the server before giving up

local function Now() return (GetServerTime and GetServerTime()) or time() end
local function Realm() return (GT.RealmName and GT.RealmName()) or (GetRealmName and GetRealmName()) or "?" end

local function Money(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor((copper % 10000) / 100), math.floor(copper % 100))
end

local function Age(t)
    local d = Now() - (t or 0)
    if d < 90 then return GT.TR("just now") end
    if d < 5400 then return GT.TRF("%d min ago", math.floor(d / 60 + 0.5)) end
    if d < 129600 then return GT.TRF("%d h ago", math.floor(d / 3600 + 0.5)) end
    return GT.TRF("%d d ago", math.floor(d / 86400 + 0.5))
end

-- ---------------------------------------------------------------------------------------------- saved list
local function Saved()
    local all = GatherTimesDB and GatherTimesDB.ahPrices
    return type(all) == "table" and all[Realm()] or nil
end

-- copper per item and the time of the scan, or nil when the item is not in the last scan
function GT.ScanPrice(id)
    local s = Saved()
    local p = s and type(s.p) == "table" and s.p[id]
    if p and p > 0 then return p, s.t end
end

-- adds the scan price to a tooltip once; returns true when a line is there
function GT.AddScanPrice(tt, id)
    if not (tt and id and tt.AddDoubleLine) then return false end
    if tt.gtScanDone == id then return true end
    local p, t = GT.ScanPrice(id)
    if not p then return false end
    tt.gtScanDone = id
    tt:AddDoubleLine(GT.TR("Auction") .. " (" .. GT.TR("GatherTimes scan") .. ")",
        Money(p) .. "  |cff999999" .. Age(t) .. "|r", 0.7, 0.7, 0.7, 1, 1, 1)
    return true
end

-- ---------------------------------------------------------------------------------------------- item tooltips
local function OnItem(tt, id)
    if not tt or (tt ~= GameTooltip and tt ~= ItemRefTooltip) then return end
    if not id and tt.GetItem then
        local _, link = tt:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    if id and GT.AddScanPrice(tt, id) and tt.Show then tt:Show() end       -- Show() resizes to the new line
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) OnItem(tt, data and data.id) end)
else
    GameTooltip:HookScript("OnTooltipSetItem", function(tt) OnItem(tt) end)
    if ItemRefTooltip and ItemRefTooltip.HookScript then
        pcall(ItemRefTooltip.HookScript, ItemRefTooltip, "OnTooltipSetItem", function(tt) OnItem(tt) end)
    end
end
GameTooltip:HookScript("OnTooltipCleared", function(tt) tt.gtScanDone = nil end)
if ItemRefTooltip and ItemRefTooltip.HookScript then
    pcall(ItemRefTooltip.HookScript, ItemRefTooltip, "OnTooltipCleared", function(tt) tt.gtScanDone = nil end)
end

-- ---------------------------------------------------------------------------------------------- the scan
local btn, status
local scanning, processing = false, false
local lastStart = 0                          -- when the last full scan was asked for (this session)
local scanToken = 0

local function PersistedLastStart()
    local all = GatherTimesDB and GatherTimesDB.ahPrices
    local s = type(all) == "table" and all[Realm()]
    local t = s and s.lastFullScan
    return GT.IsFiniteNumber(t) and t or 0
end

local function PersistLastStart(now)
    local all = GatherTimesDB.ahPrices
    if type(all) ~= "table" then all = {}; GatherTimesDB.ahPrices = all end
    local s = all[Realm()]
    if type(s) ~= "table" then s = {}; all[Realm()] = s end
    s.lastFullScan = now
end

local function SetStatus(text)
    if status then status:SetText(text or "") end
end

local function IdleStatus()
    local s = Saved()
    if s and s.t then
        local n = 0
        for _ in pairs(s.p or {}) do n = n + 1 end
        SetStatus(GT.TRF("Last scan: %s (%d items)", Age(s.t), n))
    else
        SetStatus(GT.TR("No scan yet"))
    end
end

local runner = CreateFrame("Frame")
runner:Hide()

-- the button shows the time left until the next full scan is allowed ("GT Scan 12:34"), or just "GT Scan" when it is ready
local function RefreshButton()
    if not btn or scanning then return end
    local started = math.max(lastStart, PersistedLastStart())
    local left = started > 0 and (COOLDOWN - (Now() - started)) or 0
    if left > 0 then
        btn:SetText(string.format("GT Scan %d:%02d", math.floor(left / 60), math.floor(left % 60)))
    else
        btn:SetText("GT Scan")
    end
end

local function Stop(text)
    scanToken = scanToken + 1
    scanning, processing = false, false
    if runner then
        runner:Hide()
        runner:SetScript("OnUpdate", nil)
    end
    if btn then btn:Enable() end
    RefreshButton()
    if text then SetStatus(text) else IdleStatus() end
end

local function Finish(best)
    local all = GatherTimesDB.ahPrices
    if type(all) ~= "table" then all = {}; GatherTimesDB.ahPrices = all end
    all[Realm()] = { t = Now(), p = best, lastFullScan = lastStart }
    local n = 0
    for _ in pairs(best) do n = n + 1 end
    runner:Hide()
    runner:SetScript("OnUpdate", nil)
    Stop()
    GT.cprint(GT.TRF("Auction scan done: %d items with a price.", n))
end

local function Process()
    local batch = GetNumAuctionItems and GetNumAuctionItems("list") or 0
    if not GT.IsFiniteNumber(batch) or batch <= 0 then return false end
    batch = math.floor(batch)
    processing = true
    local best, i = {}, 1
    runner:SetScript("OnUpdate", function()
        local last = math.min(i + CHUNK - 1, batch)
        for k = i, last do
            local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = GetAuctionItemInfo("list", k)
            if (not id or id == 0) and GetAuctionItemLink then
                local link = GetAuctionItemLink("list", k)
                id = link and tonumber(link:match("item:(%d+)"))
            end
            if GT.IsFiniteNumber(id) and GT.IsFiniteNumber(count) and GT.IsFiniteNumber(buyout)
                and id > 0 and count > 0 and buyout > 0 then
                id, count, buyout = math.floor(id), math.floor(count), math.floor(buyout)
                local unit = math.floor(buyout / count)
                if unit > 0 and (not best[id] or unit < best[id]) then best[id] = unit end
            end
        end
        i = last + 1
        SetStatus(GT.TRF("Reading... %d%%", math.floor(100 * math.min(i - 1, batch) / batch)))
        if i > batch then Finish(best) end
    end)
    runner:Show()
    return true
end

local function StartScan()
    if scanning then return end
    if not (QueryAuctionItems and GetNumAuctionItems and GetAuctionItemInfo) then
        GT.cprint(GT.TR("This game version has no full auction scan."))
        return
    end
    local canQuery, canMass = true, true
    if CanSendAuctionQuery then canQuery, canMass = CanSendAuctionQuery() end
    if not (canQuery and canMass) then
        local persisted = PersistedLastStart()
        if persisted > lastStart then lastStart = persisted end
        local left = COOLDOWN - (Now() - lastStart)
        if lastStart > 0 and left > 0 then
            GT.cprint(GT.TRF("Full scan is not ready yet. Try again in about %d min.", math.ceil(left / 60)))
        else
            GT.cprint(GT.TR("Full scan is not ready yet (the game allows one every 15 minutes, another addon may have used it)."))
        end
        return
    end
    scanning = true
    lastStart = Now()
    scanToken = scanToken + 1
    local token = scanToken
    btn:Disable()
    btn:SetText("GT Scan")
    SetStatus(GT.TR("Asking the server..."))
    -- text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData
    local ok, err = pcall(QueryAuctionItems, "", nil, nil, 0, false, 0, true, false, nil)
    if not ok then
        Stop()
        GT.ReportError("auction scan", err)
        return
    end
    PersistLastStart(lastStart)
    if C_Timer and C_Timer.After then
        C_Timer.After(TIMEOUT, function()
            if scanning and scanToken == token then
                Stop(GT.TR(processing and "Auction scan timed out." or "No answer from the server."))
            end
        end)
    end
end

local function CreateButton()
    if btn or not AuctionFrame then return end
    btn = CreateFrame("Button", "GatherTimesScanButton", AuctionFrame, "UIPanelButtonTemplate")
    btn:SetSize(104, 22)                                    -- wide enough for the cooldown ("GT Scan 12:34")
    local close = _G.AuctionFrameCloseButton
    if close then
        btn:SetPoint("RIGHT", close, "LEFT", 2, -1)        -- right beside the X button
    else
        btn:SetPoint("TOPRIGHT", AuctionFrame, "TOPRIGHT", -40, -14)
    end
    btn:SetText("GT Scan")
    btn:SetScript("OnClick", StartScan)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("GatherTimes", 1, 0.82, 0)
        GameTooltip:AddLine(GT.TR("Scans every auction and saves the lowest price of each item. It shows in all item tooltips. The game allows one full scan every 15 minutes."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    status = AuctionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("RIGHT", btn, "LEFT", -6, 0)            -- the caption (status text) sits right before the button
    status:SetJustifyH("RIGHT")
    btn:SetScript("OnShow", function() if not scanning then IdleStatus() end; RefreshButton() end)
    local acc = 0
    btn:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc >= 1 then acc = 0; RefreshButton() end
    end)
    IdleStatus()
    RefreshButton()
end

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")
f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        CreateButton()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if scanning then
            runner:Hide()
            runner:SetScript("OnUpdate", nil)
            Stop(GT.TR("Scan stopped: the auction house was closed."))
        end
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        if scanning and not processing then
            local ok, started = pcall(Process)
            if not ok then
                Stop()
                GT.ReportError("auction scan", started)
            end
        end
    end
end)
