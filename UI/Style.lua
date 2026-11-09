-- Style.lua : flat / minimalist look helpers
local _, GT = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"

GT.colors = {
    bg      = { 0.07, 0.07, 0.07, 0.95 },
    header  = { 0.12, 0.12, 0.12, 1 },
    border  = { 0, 0, 0, 1 },
    button  = { 0.16, 0.16, 0.16, 1 },
    hover   = { 0.26, 0.26, 0.26, 1 },
    active  = { 0.20, 0.45, 0.30, 1 },
    close   = { 0.75, 0.2, 0.2, 1 },
}

local function setBackdrop(f, role)
    f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    if GT.SkinFrame then
        GT.SkinFrame(f, role)
    else
        f:SetBackdropColor(unpack(GT.colors[role]))
        f:SetBackdropBorderColor(unpack(GT.colors.border))
    end
end

function GT:CreateFlatFrame(name, parent, w, h)
    local f = CreateFrame("Frame", name, parent or UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(w, h)
    setBackdrop(f, "bg")
    -- Text created later (rows, lists, panels) is switched to the selected language font the first time it is shown
    f:HookScript("OnShow", function(s) GT.ApplyLangFont(s) end)
    return f
end

-- GT.FitText(fs, maxW): make a caption fit inside maxW pixels.  The font is shrunk in 0.5 pt steps (down to
-- MIN_FONT) until the text fits; if it still does not fit (very long text) it is clipped to maxW instead of
-- running over the edge of its button / label.  Used so translated texts never overlap their neighbours.
-- fs.fitW remembers maxW, so every later fs:SetText() on a fitted caption is re-fitted automatically.
local MIN_FONT = 7
function GT.FitText(fs, maxW)
    if not fs then return end
    if maxW then fs.fitW = maxW end
    maxW = fs.fitW
    if not maxW or maxW <= 0 then return end
    if not fs.fitFont then
        local font, size, flags = fs.gtBaseFont, fs.gtBaseSize, fs.gtBaseFlags   -- the unscaled template font
        if not font then font, size, flags = fs:GetFont() end
        if not font then return end
        fs.fitFont, fs.fitSize, fs.fitFlags = GT.FontFile(font), size, flags
    end
    local font, size, flags = fs.fitFont, fs.fitSize, fs.fitFlags
    local single = fs:GetNumPoints() <= 1
    if single then fs:SetWidth(0) end                 -- natural width, so GetStringWidth is the real text width
    pcall(fs.SetFont, fs, font, GT.FontSize(size), flags) -- a bad font file must not raise an error
    local s = size
    local minFont = GT.LangFontFile() and 8 or MIN_FONT
    while s > minFont and fs:GetStringWidth() > maxW do
        s = s - 0.5
        pcall(fs.SetFont, fs, font, GT.FontSize(s), flags)
    end
    if single and fs:GetStringWidth() > maxW then     -- still too long: clip at the edge
        fs:SetWidth(maxW)
        fs:SetWordWrap(false)
    end
end

-- turn a font string into a self-fitting caption: after every SetText the text is fitted into maxW pixels
function GT.MakeFitting(fs, maxW)
    if fs.fitHooked then fs.fitW = maxW; return end
    fs.fitHooked = true
    local rawSetText = fs.SetText
    fs.SetText = function(self, t)
        rawSetText(self, t)
        GT.FitText(self)
    end
    fs.fitW = maxW
    GT.FitText(fs)
end

function GT:CreateFlatButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    b:SetSize(w, h)
    setBackdrop(b, "button")
    b.label = GT.Font(b, nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("CENTER")
    GT.MakeFitting(b.label, w - 8)                    -- 4 px free on each side of the caption
    b.label:SetText(GT.TR(text))
    b.baseColor = self.colors.button
    b:SetScript("OnEnter", function(s) s:SetBackdropColor(unpack(GT.colors.hover)) end)
    b:SetScript("OnLeave", function(s) s:SetBackdropColor(unpack(s.baseColor)) end)
    return b
end

function GT:SetButtonActive(b, active)
    if not b then return end
    b.gtActive = active and true or false
    if self.SkinFrame then
        self.SkinFrame(b, "button")
    else
        b.baseColor = active and self.colors.active or self.colors.button
        b:SetBackdropColor(unpack(b.baseColor))
    end
end

-- Header bar with title + close button. Returns header frame.
function GT:CreateHeader(parent, title, onClose)
    local h = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    h:SetHeight(22)
    h:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    h:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    setBackdrop(h, "header")

    h.title = GT.Font(h, nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", 8, 0)
    h.title:SetText(title)

    local close = self:CreateFlatButton(h, "x", 18, 18)
    if self.SkinFrame then self.SkinFrame(close, "close") end
    close:SetPoint("RIGHT", -2, 0)
    close:SetScript("OnEnter", function(s) s:SetBackdropColor(unpack(GT.colors.close)) end)
    close:SetScript("OnClick", onClose)
    h.close = close
    return h
end

-- A tidy tooltip for the window's buttons: gold title, a grey one-line description (or a coloured status),
-- then one aligned "key  -  action" row per hint.  hints = { { "Left-click", "Toggle the HUD" }, ... }
function GT.ShowButtonTip(owner, title, subtitle, hints)
    local tooltip = GT.Tip
    tooltip:SetOwner(owner, "ANCHOR_TOP")
    tooltip:AddLine(GT.TR(title), 1, 0.82, 0)
    if subtitle and subtitle ~= "" then tooltip:AddLine(GT.TR(subtitle), 0.75, 0.75, 0.75) end
    if hints and #hints > 0 then
        tooltip:AddLine(" ")
        for _, h in ipairs(hints) do
            tooltip:AddDoubleLine(GT.TR(h[1]), GT.TR(h[2]), 0.55, 0.78, 1, 1, 1, 1)
        end
    end
    tooltip:Show()
end

-- ----------------------------------------------------------------------------- text colour per skin
-- Every label the add-on makes goes through GT.Font. A skin that sets a text colour (colors.text) recolours the
-- labels that are still in their default colour. A label with its own colour (a status, a heading) keeps it.
GT.fontStrings = setmetatable({}, { __mode = "k" })

-- paints a label in the skin's text colour; a skin with textShadow also gets a thin outline (shadow offset)
local function ApplyText(fs, text)
    fs:SetTextColor(text[1], text[2], text[3], text[4] or 1)
    local sh = GT.colors and GT.colors.textShadow
    if sh then
        fs:SetShadowColor(sh[1], sh[2], sh[3], sh[4] or 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local function sameColor(a, b)
    return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end

-- applies the chosen font style and size to one label (a fitted caption is re-fitted instead)
local function RestyleText(fs)
    if not fs.gtBaseFont then return end
    fs.fitFont, fs.fitSize, fs.fitFlags = nil, nil, nil
    if fs.fitW then
        GT.FitText(fs)
    else
        pcall(fs.SetFont, fs, GT.FontFile(fs.gtBaseFont), GT.FontSize(fs.gtBaseSize), fs.gtBaseFlags)
    end
end

-- called when the font style or the text size changes in Settings > Look
function GT.RestyleFonts()
    for fs in pairs(GT.fontStrings) do RestyleText(fs) end
    -- the minimized bar sizes its chips from the text, so it must be laid out again with the new font / size
    if GT.UpdateMiniBar then pcall(GT.UpdateMiniBar, GT) end
end

function GT.Font(parent, name, layer, template)
    local fs = parent:CreateFontString(name, layer, template)
    local ok, r, g, b, a = pcall(fs.GetTextColor, fs)
    fs.gtDefault = (ok and r) and { r, g, b, a or 1 } or nil
    fs.gtOwned = false
    GT.fontStrings[fs] = true
    local okf, bf, bs, bfl = pcall(fs.GetFont, fs)
    if okf and bf then fs.gtBaseFont, fs.gtBaseSize, fs.gtBaseFlags = bf, bs, bfl end
    RestyleText(fs)
    local text = GT.colors and GT.colors.text
    if text and fs.gtDefault then
        ApplyText(fs, text)
        fs.gtOwned = true
    end
    return fs
end

function GT.RepaintText()
    local text = GT.colors and GT.colors.text
    for fs in pairs(GT.fontStrings) do
        if fs.gtDefault then
            if text then
                local okc, cr, cg, cb, ca = pcall(fs.GetTextColor, fs)
                local cur = okc and { cr, cg, cb, ca or 1 } or nil
                if fs.gtOwned or sameColor(cur, fs.gtDefault) then
                    ApplyText(fs, text)
                    fs.gtOwned = true
                end
            elseif fs.gtOwned then
                local d = fs.gtDefault
                fs:SetTextColor(d[1], d[2], d[3], d[4])
                fs:SetShadowOffset(0, 0)
                fs.gtOwned = false
            end
        end
    end
end
