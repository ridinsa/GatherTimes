-- Find.lua : "search all characters" window.  Lists every match in the saved bags, bank, mail, void storage, auctions
-- and guild banks of all known characters.  Click a row to open that character's bags / bank / mail / guild bank.
local _, ns = ...

local ROW_H, WIDTH, HEIGHT = 20, 420, 380
local win, box, scroll, child, empty
local rows = {}
local STALE_DAYS = 7   -- saved data older than this is greyed and its age shown in orange

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, child)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("RIGHT", child, "RIGHT", 0, 0)
    r:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local hl = r:GetHighlightTexture()
    if hl then hl:SetAlpha(0.12) end
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", 14, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.text:SetJustifyH("LEFT")
    r.where = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.where:SetPoint("RIGHT", -4, 0)
    r.where:SetJustifyH("RIGHT")
    r.text:SetPoint("RIGHT", r.where, "LEFT", -6, 0)
    r:RegisterForClicks("LeftButtonUp")
    r:SetScript("OnClick", function(self)
        if not self.key then return end
        ns.Open()
        ns.SetChar(self.key)
        if self.tab then ns.SetTab(self.tab) end
        -- show only this item in the window (clear the search box to see everything again)
        if self.name and ns.SetSearch then ns.SetSearch(self.name) end
    end)
    r:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        if ok then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function QualityHex(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c and c.hex then return c.hex end
    return "|cffffffff"
end

function ns.RefreshFind()
    if not (win and win:IsShown()) then return end
    local text = box:GetText() or ""
    local groups, total, capped = ns.FindAll(text)
    local n = 0
    for _, g in ipairs(groups) do
        n = n + 1
        local h = Row(n)
        h.key, h.tab, h.link, h.name = nil, nil, nil, nil
        h.icon:Hide()
        h.where:SetText("")
        h.text:ClearAllPoints()
        h.text:SetPoint("LEFT", 4, 0)
        h.text:SetPoint("RIGHT", -4, 0)
        if g.rec then
            h.text:SetText(ns.ClassName(g.rec, g.rec.realm ~= (GetRealmName and GetRealmName()), true))
        else
            h.text:SetText("|cff66ccff" .. ns.GuildName(g.guild or "Guild") .. " (guild bank)|r")
        end
        h:Show()
        for _, it in ipairs(g.rows) do
            n = n + 1
            local r = Row(n)
            r.key, r.tab, r.link, r.name = g.key, it.tab, it.link, ns.Name(it)
            r.icon:Show()
            r.icon:SetTexture(it.icon)
            r.text:ClearAllPoints()
            r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
            r.text:SetPoint("RIGHT", r.where, "LEFT", -6, 0)
            r.text:SetText(QualityHex(it.quality) .. ns.Name(it) .. "|r  x" .. tostring(it.count))
            local old = it.t and (time() - it.t) > STALE_DAYS * 86400
            local age = ""
            if it.t and ns.Ago then age = "  |cff" .. (old and "cc8844" or "888888") .. ns.Ago(it.t) .. "|r" end
            r.where:SetText(it.loc .. age)
            r.icon:SetDesaturated(old and true or false)
            r:Show()
        end
    end
    for i = n + 1, #rows do rows[i]:Hide() end
    child:SetHeight(math.max(1, n * ROW_H))
    if text:match("%S") then
        if n == 0 then
            empty:SetText("Nothing found.")
        elseif capped then
            empty:SetText("Showing the first matches only; type more to narrow the search.")
        else
            empty:SetText(string.format("%d match%s", total, total == 1 and "" or "es"))
        end
    else
        empty:SetText("")
    end
end

local function Build()
    local UI, PAD = ns.UI, ns.UI.PAD
    win = UI.Window("GTBagFind", WIDTH, HEIGHT, "Search all characters")
    box = UI.EditBox(win, "Item name, type or category (for example: linen, potion, arrow)")
    box:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + 6, -44)
    box:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -44)
    box:HookScript("OnTextChanged", function() ns.RefreshFind() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); win:Hide() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local panel
    panel, scroll, child = UI.ScrollList(win, ROW_H)
    panel:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -72)
    panel:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 34)

    UI.Rule(win, 28)
    empty = UI.Label(win, "")
    empty:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, 9)
    empty:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 9)
    empty:SetJustifyH("LEFT")

    win:SetScript("OnShow", function() ns.RefreshFind() end)
    win:Hide()
end

-- opens the window; text (optional) is put into the search box
function ns.ShowFind(text)
    if not win then Build() end
    win:Show()
    if text ~= nil then box:SetText(tostring(text)) end
    if box:GetText() == "" then box:SetFocus() end
    ns.RefreshFind()
end

-- keep the list current when saved data changes while the window is open
local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_CLOSED", "MAIL_INBOX_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function() if win and win:IsShown() then ns.RefreshFind() end end)
