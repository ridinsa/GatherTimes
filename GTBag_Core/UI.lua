-- UI.lua : the look of the inventory window (dark flat frame, flat buttons, gold header rule) for GTBag's other windows.
local _, ns = ...
local UI = {}
ns.UI = UI

UI.PAD = 12

local FALLBACK = {
    bg = { 0.05, 0.05, 0.06, 0.95 },
    border = { 0.3, 0.3, 0.32, 1 },
    button = { 0.12, 0.14, 0.18, 1 },
    active = { 0.07, 0.09, 0.12, 1 },
    hover = { 1, 1, 1, 0.14 },
    line = { 0.34, 0.31, 0.24, 0.8 },
}
-- "Fresh" theme: ink-blue panel, quiet borders, amber hover.  It is the default; "GatherTimes" follows that addon's skin.
local FRESH = {
    bg = { 0.078, 0.090, 0.110, 0.97 },
    border = { 0.165, 0.192, 0.231, 1 },
    button = { 0.106, 0.125, 0.153, 1 },
    active = { 0.165, 0.192, 0.231, 1 },
    hover = { 0.94, 0.71, 0.29, 0.14 },
    line = { 0.133, 0.161, 0.196, 1 },
    field = { 0.106, 0.125, 0.153, 1 },
}
local themedFrames = setmetatable({}, { __mode = "k" })
local themedTextures = setmetatable({}, { __mode = "k" })

local function Colors()
    if ns.Opt and ns.Opt("theme") == "gathertimes" then
        local addon = _G.GatherTimesAddon
        if addon and addon.colors then return addon.colors end
        return FALLBACK
    end
    return FRESH
end

function UI.ApplyFrameTheme(frame)
    if not frame then return end
    local colors = Colors()
    local bg = colors.bg or FALLBACK.bg
    local border = frame.gtThemeMain and frame.gtViewingOther and (colors.active or FALLBACK.border)
        or (colors.border or FALLBACK.border)
    if frame.SetBackdropColor then frame:SetBackdropColor(unpack(bg)) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(unpack(border)) end
end

function UI.ThemeFrame(frame, main)
    if not frame then return end
    frame.gtThemeMain = main and true or nil
    themedFrames[frame] = true
    UI.ApplyFrameTheme(frame)
end

function UI.ThemeTexture(texture, role, alpha)
    if not texture then return end
    themedTextures[texture] = { role = role, alpha = alpha }
    local color = Colors()[role] or FALLBACK[role] or FALLBACK.border
    local a = alpha or color[4] or 1
    if texture.SetVertexColor then
        texture:SetVertexColor(color[1], color[2], color[3], a)
    elseif texture.SetColorTexture then
        texture:SetColorTexture(color[1], color[2], color[3], a)
    end
end

function UI.ApplyTheme()
    for frame in pairs(themedFrames) do UI.ApplyFrameTheme(frame) end
    for texture, theme in pairs(themedTextures) do UI.ThemeTexture(texture, theme.role, theme.alpha) end
end

local gatherTimes = _G.GatherTimesAddon
if gatherTimes and gatherTimes.RegisterSkinUpdater then
    gatherTimes:RegisterSkinUpdater(UI.ApplyTheme)
end

-- same flat button as the inventory window
function UI.Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h or 20)
    b:SetNormalFontObject("GameFontNormalSmall")      -- plain button: no Blizzard template art on hover / press
    b:SetText(text)
    b:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    b:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local normal = b:GetNormalTexture()
    if normal then UI.ThemeTexture(normal, "button") end
    local pushed = b:GetPushedTexture()
    if pushed then UI.ThemeTexture(pushed, "active") end
    local highlight = b:GetHighlightTexture()
    if highlight then UI.ThemeTexture(highlight, "hover", 0.14) end
    b:SetDisabledTexture("Interface\\Buttons\\WHITE8X8")
    local disabled = b:GetDisabledTexture()
    if disabled then UI.ThemeTexture(disabled, "button", 0.5) end
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    return b
end

-- movable window with the inventory frame's colours, a caption inside the top edge, an X button and the gold rule
function UI.Window(name, w, h, caption)
    local win = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    win:SetSize(w, h)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    win:SetFrameStrata("DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    if win.SetBackdrop then
        win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        UI.ThemeFrame(win)
    end
    win.caption = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    win.caption:SetPoint("TOPLEFT", win, "TOPLEFT", UI.PAD, -12)
    win.caption:SetText(caption or "")
    win.close = UI.Button(win, "X", 20)
    win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -UI.PAD, -8)
    win.close:SetScript("OnClick", function() win:Hide() end)
    local rule = win:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", win, "TOPLEFT", UI.PAD, -34)
    rule:SetPoint("TOPRIGHT", win, "TOPRIGHT", -UI.PAD, -34)
    rule:SetHeight(1)
    UI.ThemeTexture(rule, "line", 0.8)
    if name then tinsert(UISpecialFrames, name) end
    -- Any other GTBag window opened from the settings window (Custom categories, Backup, Find, ...) hides the settings
    -- window while it is open and brings it back when it closes.
    if name ~= "GTBagSettingsFrame" then
        local function HideSettings(self)
            local settings = _G.GTBagSettingsFrame
            if settings and settings ~= self and settings:IsShown() then
                self.gtRestoreSettings = true
                settings:Hide()
            end
        end
        -- Show / Hide are wrapped instead of hooking OnShow / OnHide: Backup, Custom categories and Find replace their own
        -- OnShow with SetScript, which would throw such hooks away.
        local rawShow, rawHide = win.Show, win.Hide
        win.Show = function(self, ...)
            HideSettings(self)
            return rawShow(self, ...)
        end
        win.Hide = function(self, ...)
            local result = rawHide(self, ...)
            if self.gtRestoreSettings then
                self.gtRestoreSettings = nil
                local settings = _G.GTBagSettingsFrame
                if settings and not settings:IsShown() then settings:Show() end
            end
            return result
        end
        HideSettings(win)       -- a new frame is already shown when it is created
    end
    return win
end

-- thin line (the footer rule of the inventory window)
function UI.Rule(win, bottom)
    local r = win:CreateTexture(nil, "ARTWORK")
    r:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", UI.PAD, bottom)
    r:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -UI.PAD, bottom)
    r:SetHeight(1)
    UI.ThemeTexture(r, "line")
    return r
end

-- small grey caption
function UI.Label(parent, text)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f:SetTextColor(0.62, 0.62, 0.62)
    f:SetText(text or "")
    return f
end

-- search-box style edit box with a grey hint that disappears when there is text
function UI.EditBox(parent, hintText, w)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetHeight(20)
    if w then box:SetWidth(w) end
    box:SetAutoFocus(false)
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText(hintText or "")
    box.hint = hint
    local function Sync(self) hint:SetShown((self:GetText() or "") == "") end
    box:HookScript("OnTextChanged", Sync)
    Sync(box)
    return box
end

-- dark list panel with a flat scroll bar.  Returns panel, scroll, child.  Rows are anchored to the child, which is as
-- wide as the visible area; the bar only shows when there is something to scroll.
function UI.ScrollList(parent, rowHeight)
    rowHeight = rowHeight or 20
    local panel = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if panel.SetBackdrop then
        panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        UI.ThemeFrame(panel)
    end
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 2)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(10, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)

    local bar = CreateFrame("Slider", nil, panel)
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
    bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
    bar:SetWidth(8)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    UI.ThemeTexture(track, "field")
    bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(8, 28)
    UI.ThemeTexture(thumb, "line", 0.95)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:Hide()

    local syncing = false
    bar:SetScript("OnValueChanged", function(_, v)
        if not syncing then scroll:SetVerticalScroll(v) end
    end)
    scroll:SetScript("OnScrollRangeChanged", function(self, _, yRange)
        yRange = math.max(0, tonumber(yRange) or 0)
        syncing = true
        bar:SetMinMaxValues(0, yRange)
        if self:GetVerticalScroll() > yRange then self:SetVerticalScroll(yRange) end
        bar:SetValue(self:GetVerticalScroll())
        syncing = false
        bar:SetShown(yRange > 0)
    end)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        syncing = true
        bar:SetValue(offset)
        syncing = false
    end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local v = math.max(0, math.min(range, self:GetVerticalScroll() - delta * rowHeight * 3))
        self:SetVerticalScroll(v)
    end)
    scroll:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then child:SetWidth(w) end end)
    return panel, scroll, child
end
