-- PanelSummary.lua : the "Show summary" panel (button in the Timers panel). It opens beside the main window, like the
-- other panels, and does not move. The text is the session summary (GT.FormatStats) in a box you can copy from:
-- click the box, Ctrl+A, Ctrl+C. The text refreshes every time the panel opens.
local _, GT = ...
GT.panelBuilders = GT.panelBuilders or {}

GT.panelBuilders.Summary = function(panel, content)
    panel.header.title:SetText(GT.TR("Session summary"))

    local scroll = CreateFrame("ScrollFrame", "GatherTimesSummaryScroll", content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -22, 36)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetWidth(250)
    edit:SetTextInsets(4, 4, 2, 2)
    edit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    -- read only: typing changes nothing, the text is only there to copy
    edit:SetScript("OnTextChanged", function(s, userInput)
        if userInput and panel.summaryText then s:SetText(panel.summaryText) end
    end)
    scroll:SetScrollChild(edit)

    local selectAll = GT:CreateFlatButton(content, GT.TR("Select all"), 90, 20)
    selectAll:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 4)
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    local hint = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 10)
    hint:SetText(GT.TR("Ctrl+C copies"))

    local function Refresh()
        local text = GT.FormatStats()
        panel.summaryText = text
        edit:SetText(text)
        local _, breaks = text:gsub("\n", "")
        edit:SetHeight((breaks + 1) * 14 + 8)
        scroll:SetVerticalScroll(0)
    end
    panel:HookScript("OnShow", Refresh)
end
