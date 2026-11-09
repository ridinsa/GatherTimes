-- Panels.lua : one sub-frame per button, only one visible at a time
local _, GT = ...

GT.panels = {}
GT.panelBuilders = GT.panelBuilders or {}   -- name -> function(panel, content)
function GT:CreatePanel(name)
    local p = self:CreateFlatFrame("GatherTimesPanel" .. name, self.main, 300, self.frameHeight)
    p:SetPoint("TOPLEFT", self.main, "TOPRIGHT", 2, 0)
    p:Hide()

    p.header = self:CreateHeader(p, GT.TR(name), function() GT:HidePanels() end)

    -- Content area: put your timers / widgets here
    p.content = CreateFrame("Frame", nil, p)
    p.content:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 6, -6)
    p.content:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -6, 6)

    p.text = GT.Font(p.content, nil, "OVERLAY", "GameFontHighlightSmall")
    p.text:SetPoint("TOPLEFT")
    p.text:SetText(name .. " content goes here")

    -- real content, if a builder exists for this panel (see Panel*.lua)
    local build = self.panelBuilders[name]
    if build then
        p.text:Hide()
        local ok, err = pcall(build, p, p.content)
        if not ok then
            -- one broken panel must not take the whole addon down
            p.text:Show()
            p.text:SetWidth(280)
            p.text:SetJustifyH("LEFT")
            p.text:SetText("|cffff5555Panel failed to load:|r\n" .. tostring(err))
            GT.cprint("|cffff5555panel '" .. name .. "' failed:|r " .. tostring(err))
        end
    end

    self.panels[name] = p
    return p
end

function GT:HidePanels()
    for name, p in pairs(self.panels) do p:Hide() end
    for name, b in pairs(self.buttonFrames or {}) do self:SetButtonActive(b, false) end
end

-- Show one panel, close all the others
function GT:ShowPanel(name)
    -- Settings panels share the same slot beside the main frame as Random Name.
    -- Hide Random Name before opening any regular panel so the windows never stack.
    if self.nameDisguiseFrame and self.nameDisguiseFrame:IsShown() then
        self.nameDisguiseFrame:Hide()
    end
    local wasOpen = self.panels[name] and self.panels[name]:IsShown()
    self:HidePanels()
    if wasOpen or not self.panels[name] then return end -- clicking the active button again closes it
    self.panels[name]:Show()
    local button = self.buttonFrames[name]
    if button then self:SetButtonActive(button, true) end
end
