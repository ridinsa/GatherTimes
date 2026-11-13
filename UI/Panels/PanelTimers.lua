-- PanelTimers.lua : the "Timers" panel (live list of running node timers)
local _, GT = ...
GT.panelBuilders = GT.panelBuilders or {}

local FLAT = "Interface\\Buttons\\WHITE8X8"
local ROW_H, NUM_ROWS = 18, 12
local COL_NAME, COL_TIME = 28, 152

local function ZoneName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name
end

-- left-click: TomTom waypoint to that node
local function SetWaypoint(key, node)
    if not GT.UI.TomTomAvailable() then
        GT.cprint(GT.TR("TomTom is not installed, or the TomTom option is off."))
        return
    end
    if GT.listWp and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, GT.listWp) end
    if GT.navWp and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, GT.navWp) end
    GT.navWp = nil                                   -- the last click wins: one GatherTimes click waypoint at a time
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, node.mapID, node.x, node.y,
        { title = GT.nodes[key].label, persistent = false, minimap = true, world = true,
          crazy = true, from = "GatherTimes" })
    GT.listWp = ok and uid or nil
end

local function CreateRow(list, i)
    local b = CreateFrame("Button", nil, list)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local hl = b:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetTexture(FLAT)
    hl:SetVertexColor(unpack(GT.colors.hover))
    hl:Hide()

    b.group = GT.Font(b, nil, "OVERLAY", "GameFontHighlightSmall")
    b.group:SetPoint("LEFT", 4, 0)
    b.group:SetTextColor(0.6, 0.6, 0.6)

    b.name = GT.Font(b, nil, "OVERLAY", "GameFontNormalSmall")
    b.name:SetPoint("LEFT", COL_NAME, 0)
    b.name:SetWidth(COL_TIME - COL_NAME - 4)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)

    b.time = GT.Font(b, nil, "OVERLAY", "GameFontHighlightSmall")
    b.time:SetPoint("LEFT", COL_TIME, 0)

    b.dist = GT.Font(b, nil, "OVERLAY", "GameFontHighlightSmall")
    b.dist:SetPoint("RIGHT", -4, 0)

    b:SetScript("OnEnter", function(self)
        hl:Show()
        if not self.key then return end
        GT.Tip:SetOwner(self, "ANCHOR_LEFT")
        GT.Tip:AddLine(GT.nodes[self.key].label)
        local z = ZoneName(self.node.mapID)
        if z then GT.Tip:AddLine(z, 1, 1, 1) end
        if GT.UI.TomTomAvailable() then GT.Tip:AddLine(GT.TR("Left-click: TomTom waypoint"), 0.7, 0.7, 0.7) end
        GT.Tip:AddLine(GT.TR("Shift + right-click: remove this timer"), 0.7, 0.7, 0.7)
        GT.Tip:Show()
    end)
    b:SetScript("OnLeave", function() hl:Hide(); GT.Tip:Hide() end)
    b:SetScript("OnClick", function(self, button)
        if not self.key then return end
        if button == "RightButton" then
            if not IsShiftKeyDown() then return end      -- removing needs Shift: a stray right-click deletes nothing
            GT.RemoveNodeRef(self.key, self.node)
            GT.UpdateList()
        else
            SetWaypoint(self.key, self.node)
        end
    end)
    return b
end

local function AddButtonTip(button, title, description)
    button:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_TOP")
        GT.Tip:AddLine(GT.TR(title))
        GT.Tip:AddLine(GT.TR(description), 0.85, 0.85, 0.85, true)
        GT.Tip:Show()
    end)
    button:HookScript("OnLeave", function() GT.Tip:Hide() end)
end

local function UpdateRow(row, it)
    local col = GT.Col(it.key)
    row.key, row.node = it.key, it.node
    row.group:SetText(it.group or "")
    row.name:SetText(GT.nodes[it.key].label)
    row.name:SetTextColor(col[1], col[2], col[3])
    if it.left <= 0 then
        row.time:SetText("|cff00ff00" .. GT.TR("READY") .. "|r")
    else
        row.time:SetText(string.format("%d:%02d", math.floor(it.left / 60), math.floor(it.left % 60)))
    end
    row.dist:SetText(it.dist and GT.TRF("%d yd", math.floor(it.dist)) or "")
end

-- "Next:" line
local function NextText()
    local rt = GT.routeTarget
    if not rt then return GT.TR("Next: nothing in range") end
    local gsp = rt.kind == "spawn" and rt.ref or (rt.ref.sid and GT.spawnBySid[rt.ref.sid])
    local tag = ""
    if gsp then
        local g = GT.ComputeGroups(rt.key, gsp.mapID).of[gsp]
        if g then tag = " [G" .. g .. "]" end
    end
    local status = rt.kind == "spawn" and GT.TR("no timer yet") or GT.TargetStatus(rt)
    if gsp and GT.ContestedPenalty(gsp) >= 15 then status = status .. " (" .. GT.TR("often taken") .. ")" end   -- 25 % or more found taken
    return GT.TRF("Next: %s%s - %s - %d yd",
        GT.nodes[rt.key].label, tag, status, math.floor(rt.dist or 0))
end

-- keep the stats box short: first lines + the Total line
local function ShortStats()
    local lines = {}
    for l in GT.FormatStats():gmatch("[^\n]+") do lines[#lines + 1] = l end
    if #lines <= 6 then return table.concat(lines, "\n") end
    return table.concat(lines, "\n", 1, 5) .. "\n..." .. "\n" .. lines[#lines]
end

GT.panelBuilders.Timers = function(panel, content)
    local nextFs = GT.Font(content, nil, "OVERLAY", "GameFontNormalSmall")
    nextFs:SetPoint("TOPLEFT", 2, 0)
    nextFs:SetWidth(284)
    nextFs:SetJustifyH("LEFT")
    nextFs:SetWordWrap(false)

    -- column captions
    local function caption(text, x)
        local fs = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", x, -18)
        fs:SetText(GT.TR(text))
    end
    caption("Grp", 4); caption("Node", COL_NAME); caption("Time", COL_TIME)

    local list = GT:CreateScrollList(content, 288, ROW_H * NUM_ROWS, ROW_H, CreateRow, UpdateRow)
    list:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -32)
    panel.list = list

    local empty = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOP", list, "TOP", 0, -8)
    empty:SetText(GT.TR("No active timers - go gather something"))

    local stats = GT.Font(content, nil, "OVERLAY", "GameFontHighlightSmall")
    stats:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 2, -8)
    stats:SetWidth(284)
    stats:SetJustifyH("LEFT")
    stats:SetJustifyV("TOP")
    stats:SetWordWrap(false)
    GT.MakeFitting(stats, 284)               -- shrink long lines instead of wrapping them down into the buttons

    local reset = GT:CreateFlatButton(content, "Reset session", 92, 20)
    reset:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    GT:SetConfirmClick(reset, "Reset session", function() GT.ResetSessionStats() end)
    AddButtonTip(reset, "Reset session", "Print the current session summary, then start a fresh session.")

    local summary = GT:CreateFlatButton(content, "Show summary", 92, 20)
    summary:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 98, 0)
    summary:SetScript("OnClick", function()
        GT:ShowPanel("Summary")
    end)
    AddButtonTip(summary, "Show summary", "Open your session summary: items, gold value and gold per hour, in a box you can copy.")

    local items, pool = {}, {}
    local function SortTimers(a, b)
        local ar, br = a.left <= 0, b.left <= 0
        if ar ~= br then return ar end
        if ar then
            local ad, bd = a.dist or 1e9, b.dist or 1e9
            if ad ~= bd then return ad < bd end
        end
        return a.left < b.left
    end

    -- called once per second by the timer loop (and on show)
    GT.UpdateList = function()
        if not panel:IsShown() then return end
        local c = GT.cfg()
        local curMap = C_Map.GetBestMapForUnit("player")
        -- the same item tables are reused every second (a new table per timer per second is what made
        -- the memory climb)
        local n = 0
        -- every item you have looted (not only the ones checked in the Nodes panel)
        for _, key in ipairs(GT.order) do
            for _, node in ipairs(GatherTimesDB[key]) do
                if node._left and (not c.zoneOnly or node.mapID == curMap) then
                    n = n + 1
                    local it = pool[n]
                    if not it then it = {}; pool[n] = it end
                    it.key, it.node, it.left = key, node, node._left
                    it.dist = node._dist or GT.GetDistance(node)      -- unchecked nodes have no cached distance
                    it.group = GT.GroupLabelForNode(key, node)
                    items[n] = it
                end
            end
        end
        for i = n + 1, #items do items[i] = nil end
        table.sort(items, SortTimers)
        list:SetItems(items)
        empty:SetShown(#items == 0)
        nextFs:SetText(NextText())
        stats:SetText(ShortStats())
    end

    panel:SetScript("OnShow", function() GT.UpdateList() end)
end
