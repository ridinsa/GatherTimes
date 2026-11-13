-- Dropdown.lua : flat dropdown box (no Blizzard dropdown template)
--   dd = GT:CreateDropdown(parent, w, h, items, onSelect [, maxRows])
--   items    : strings or { text = string, count = number, tooltip = string }; optional counts are right-aligned
--              onSelect(index, text) runs when the user picks one
--   maxRows  : rows shown before the list scrolls (default 10)
--   dd:SetItems(list)  replace the entries at any time      dd:SetSelected(index)  set the shown entry
local _, GT = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"
local ROW_H = 18

function GT:CreateDropdown(parent, w, h, items, onSelect, maxRows)
    maxRows = maxRows or 10
    local dd = self:CreateFlatButton(parent, "", w, h)
    dd.items = items

    dd.label:ClearAllPoints()
    dd.label:SetPoint("LEFT", 8, 0)
    dd.label:SetPoint("RIGHT", -18, 0)
    dd.label:SetJustifyH("LEFT")
    dd.label:SetWordWrap(false)
    GT.MakeFitting(dd.label, w - 26)          -- room for the left margin and arrow

    dd.arrow = GT.Font(dd, nil, "OVERLAY", "GameFontNormalSmall")
    dd.arrow:SetPoint("RIGHT", -6, 0)
    dd.arrow:SetText("v")

    dd.countLabel = GT.Font(dd, nil, "OVERLAY", "GameFontDisableSmall")
    dd.countLabel:SetPoint("RIGHT", dd.arrow, "LEFT", -5, 0)
    dd.countLabel:SetWidth(34)
    dd.countLabel:SetJustifyH("RIGHT")

    -- popup list
    local list = self:CreateFlatFrame(nil, dd, w, 2 + ROW_H)
    list:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -1)
    list:SetFrameStrata("DIALOG")
    list:SetFrameLevel(50)
    list:Hide()
    dd.list = list

    -- invisible full-screen catcher: click anywhere else to close the list
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(49)
    catcher:Hide()
    catcher:SetScript("OnClick", function() list:Hide() end)
    list:SetScript("OnShow", function() catcher:Show() end)
    list:SetScript("OnHide", function() catcher:Hide() end)

    local function createRow(parentList)
        local row = CreateFrame("Button", nil, parentList)
        local hl = row:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetTexture(FLAT)
        hl:SetVertexColor(unpack(GT.colors.hover))
        hl:Hide()
        row.text = GT.Font(row, nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 7, 0)
        row.text:SetPoint("RIGHT", -43, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.count = GT.Font(row, nil, "OVERLAY", "GameFontDisableSmall")
        row.count:SetPoint("RIGHT", -8, 0)
        row.count:SetWidth(34)
        row.count:SetJustifyH("RIGHT")
        row:SetScript("OnEnter", function(self)
            hl:SetVertexColor(unpack(GT.colors.hover))
            hl:Show()
            local item = self.item
            if item and item.tooltip then
                GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
                GT.Tip:AddLine(item.text)
                GT.Tip:AddLine(GT.TR(item.tooltip), 0.85, 0.85, 0.85, true)
                GT.Tip:Show()
            end
        end)
        row:SetScript("OnLeave", function() hl:Hide(); GT.Tip:Hide() end)
        row:SetScript("OnClick", function(self)
            local it = self.item
            if not it then return end
            dd:SetSelected(it.index)
            list:Hide()
            if onSelect then onSelect(it.index, it.text) end
        end)
        return row
    end
    local function updateRow(row, it)
        row.text:SetText(it.text)
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", 7, 0)
        if it.count ~= nil then
            row.text:SetPoint("RIGHT", -43, 0)
            row.count:SetText(tostring(it.count))
        else
            row.text:SetPoint("RIGHT", -2, 0)
            row.count:SetText("")
        end
        -- list text: the skin's text colour when the skin sets one (light skins); otherwise white, and gold when selected
        local tc = GT.colors and GT.colors.text
        if it.index == dd.selected then
            if tc then
                local a = GT.colors.active
                row.text:SetTextColor(a[1], a[2], a[3])
            else
                row.text:SetTextColor(1, 0.82, 0)
            end
        elseif tc then
            row.text:SetTextColor(tc[1], tc[2], tc[3])
        else
            row.text:SetTextColor(1, 1, 1)
        end
    end

    local scroll = self:CreateScrollList(list, w - 2, ROW_H * maxRows, ROW_H, createRow, updateRow)
    scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1)
    dd.scroll = scroll

    function dd:SetItems(newItems)
        self.items = newItems
        local data = {}
        for i, item in ipairs(newItems) do
            if type(item) == "table" then
                data[i] = { index = i, text = item.text, count = item.count, tooltip = item.tooltip }
            else
                data[i] = { index = i, text = item }
            end
        end
        scroll:SetItems(data)
        list:SetHeight(2 + ROW_H * math.max(1, math.min(#newItems, maxRows)))
    end

    function dd:SetSelected(index)
        self.selected = index
        local item = self.items[index]
        self.label:SetText(type(item) == "table" and (item.text or "") or item or "")
        self.label:SetPoint("RIGHT", -18, 0)
        GT.MakeFitting(self.label, w - 26)
        self.countLabel:SetText("")
        scroll:Update()
    end

    dd:SetScript("OnClick", function()
        if list:IsShown() then list:Hide(); return end
        -- open with the selected entry in view
        scroll:SetOffset(math.max(0, (dd.selected or 1) - 1))
        list:Show()
    end)

    dd:SetItems(items)
    return dd
end
