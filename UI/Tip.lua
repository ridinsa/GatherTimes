-- Tip.lua : the add-on's own tooltip, drawn in the skin colours. It has the same small set of calls as
-- GameTooltip (SetOwner, ClearLines, AddLine, AddDoubleLine, Show, Hide), so the callers only change the name.
-- Used by the main window, the Settings / Timers / Nodes / Timing panels and UI\Style.lua (GT.ShowButtonTip).
-- The item tooltip (Gathering\ItemInfo.lua) and the skill tooltip (Gathering\Skills.lua) are NOT changed: they
-- show over the inventory, the world map and the minimap, so they keep the game's own look.
local _, GT = ...

local PAD, LINE_H, WRAP_W = 8, 14, 280
local FLAT = "Interface\\Buttons\\WHITE8X8"

local frame = CreateFrame("Frame", "GatherTimesTip", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetFrameStrata("TOOLTIP")
frame:SetClampedToScreen(true)
frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
frame:Hide()
GT.SkinFrame(frame, "bg")                      -- follows the skin's background and border colours

local Tip = { frame = frame, lines = {}, count = 0, owner = nil, anchor = "ANCHOR_RIGHT" }
GT.Tip = Tip

local function lineAt(i)
    local l = Tip.lines[i]
    if not l then
        l = { left = GT.Font(frame, nil, "OVERLAY", "GameFontHighlightSmall") }
        l.right = GT.Font(frame, nil, "OVERLAY", "GameFontHighlightSmall")
        Tip.lines[i] = l
    end
    return l
end

function Tip:ClearLines()
    for i = 1, #self.lines do
        self.lines[i].left:Hide()
        self.lines[i].right:Hide()
    end
    self.count = 0
    self.height = 0
end

function Tip:SetOwner(owner, anchor)
    self.owner = owner
    self.anchor = anchor or "ANCHOR_RIGHT"
    self:ClearLines()
end

local function DefaultText()
    local t = GT.colors and GT.colors.text
    if t then return t[1], t[2], t[3] end
    return 1, 1, 1
end

-- On a light skin (one that sets a text colour) every line uses that colour, so the colours given by the code
-- and the |cff...|r colour codes in the text are dropped. Other skins keep their colours.
local function LightSkin()
    return GT.colors and GT.colors.text ~= nil
end

local function CleanText(text)
    if not LightSkin() then return text or "" end
    local t = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return t
end

-- change the text of line i in place (the tooltip keeps its shape; the caller calls Show again to re-measure)
function Tip:SetLineTexts(i, left, right)
    local l = self.lines[i]
    if not l then return end
    l.left:SetText(CleanText(left))
    if right ~= nil then l.right:SetText(CleanText(right)) end
end

function Tip:AddLine(text, r, g, b, wrap)
    self.count = self.count + 1
    local l = lineAt(self.count)
    l.y = self.height
    l.left:ClearAllPoints()
    l.left:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + l.y))
    l.left:SetWordWrap(wrap == true)
    l.left:SetWidth(wrap and WRAP_W or 0)
    l.left:SetText(CleanText(text))
    if LightSkin() then
        l.left:SetTextColor(DefaultText())
    else
        l.left:SetTextColor(r or 1, g or 1, b or 1)
    end
    l.left:Show()
    l.right:Hide()
    l.height = wrap and math.max(LINE_H, l.left:GetStringHeight()) or LINE_H
    l.wrapWidth = wrap and WRAP_W or nil
    self.height = self.height + l.height
end

function Tip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
    self:AddLine(left, lr, lg, lb)
    local l = self.lines[self.count]
    l.right:ClearAllPoints()
    l.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(PAD + l.y))
    l.right:SetText(CleanText(right))
    if LightSkin() then
        l.right:SetTextColor(DefaultText())
    else
        l.right:SetTextColor(rr or 1, rg or 1, rb or 1)
    end
    l.right:Show()
end

local function place(self)
    local f, o = self.frame, self.owner
    f:ClearAllPoints()
    if self.anchor == "ANCHOR_CURSOR" or not o then
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 14, y / s + 14)
    elseif self.anchor == "ANCHOR_RIGHT" then
        f:SetPoint("TOPLEFT", o, "TOPRIGHT", 6, 0)
    elseif self.anchor == "ANCHOR_LEFT" then
        f:SetPoint("TOPRIGHT", o, "TOPLEFT", -6, 0)
    elseif self.anchor == "ANCHOR_BOTTOMRIGHT" then
        f:SetPoint("TOPRIGHT", o, "BOTTOMRIGHT", 0, -6)
    elseif self.anchor == "ANCHOR_TOP" then
        f:SetPoint("BOTTOM", o, "TOP", 0, 6)
    else
        f:SetPoint("TOPLEFT", o, "BOTTOMLEFT", 0, -6)
    end
end

function Tip:Show()
    local w = 0
    for i = 1, self.count do
        local l = self.lines[i]
        local lw = l.left:GetStringWidth()
        if l.right:IsShown() then lw = lw + 12 + l.right:GetStringWidth() end
        if l.wrapWidth then lw = l.wrapWidth end
        if lw > w then w = lw end
    end
    self.frame:SetSize(math.max(120, w + 2 * PAD), math.max(1, self.height) + 2 * PAD)
    place(self)
    self.frame:Show()
end

function Tip:Hide()
    self.frame:Hide()
end
