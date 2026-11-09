-- Broker.lua : optional LibDataBroker feed ("data source" for Titan Panel, ChocolateBar, Bazooka, ...)
-- LibDataBroker-1.1 is NOT bundled: any Broker display addon brings it.  The object is made at PLAYER_LOGIN, when
-- every addon is loaded, so it does not matter which one loads first.  Without a display addon nothing happens.
-- Text: "N ready" when a timer is up, otherwise the time left on the soonest one.  Left-click opens / closes the
-- main window (same as /gt), right-click turns the minimap HUD on / off.  Everything runs under pcall: a failure
-- here never touches the timers.
local _, GT = ...
local Broker = {}
GT.Broker = Broker

local function TR(text) return GT.TR and GT.TR(text) or text end

-- Same maths as /gt list: seconds left = the item's respawn time minus the time since the loot.
local function Collect()
    local now = GetServerTime()
    local ready, soonest, per = 0, nil, {}
    for _, key in ipairs(GT.order) do
        local def = GT.nodes[key]
        local list = GatherTimesDB and GatherTimesDB[key]
        if def and type(list) == "table" then
            for _, n in ipairs(list) do
                if type(n) == "table" and type(n.time) == "number" then
                    local row = per[key]
                    if not row then row = { label = def.label, ready = 0, waiting = 0 }; per[key] = row end
                    local left = def.timer - (now - n.time)
                    if left <= 0 then
                        ready, row.ready = ready + 1, row.ready + 1
                    else
                        row.waiting = row.waiting + 1
                        if not soonest or left < soonest then soonest = left end
                    end
                end
            end
        end
    end
    return ready, soonest, per
end

local function Text()
    local ready, soonest = Collect()
    if ready > 0 then return string.format("|cff33ff33%d %s|r", ready, TR("ready")) end
    if soonest then return string.format("%d:%02d", math.floor(soonest / 60), math.floor(soonest % 60)) end
    return "|cff888888" .. TR("no timers") .. "|r"
end

local function Setup()
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    if not ldb then return end
    local def = {
        type = "data source",
        label = "GatherTimes",
        text = Text(),
        icon = "Interface\\Icons\\INV_Misc_Herb_15",
        OnClick = function(_, button)
            if button == "RightButton" then
                if GT.HUD and GT.HUD.Toggle then GT.HUD.Toggle() end
            elseif GT.main then
                GT.main:SetShown(not GT.main:IsShown())
            end
        end,
        OnTooltipShow = function(tip)
            tip:AddLine("GatherTimes")
            local _, _, per = Collect()
            local any = false
            for _, key in ipairs(GT.order) do
                local row = per[key]
                if row then
                    any = true
                    tip:AddDoubleLine(row.label, string.format("%d %s, %d %s", row.ready, TR("ready"), row.waiting, TR("waiting")), 1, 1, 1, 0.8, 0.8, 0.8)
                end
            end
            if not any then tip:AddLine(TR("no timers"), 0.6, 0.6, 0.6) end
            tip:AddLine(" ")
            tip:AddLine(TR("Left-click: open / close the window"), 0.6, 0.6, 0.6)
            tip:AddLine(TR("Right-click: HUD on / off"), 0.6, 0.6, 0.6)
        end,
    }
    local obj = ldb:NewDataObject("GatherTimes", def) or ldb:GetDataObjectByName("GatherTimes")
    if not obj then return end
    Broker.object = obj
    C_Timer.NewTicker(2, function() obj.text = Text() end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local ok, err = pcall(Setup)
    if not ok and GT.ReportError then GT.ReportError("Broker", err) end
end)
