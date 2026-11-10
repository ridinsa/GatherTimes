-- Widgets.lua : flat widgets shared by the panels
local _, GT = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"

-- Flat scroll list (no Blizzard templates).
--   w, h       : size of the list
--   rowH       : height of one row
--   createRow  : function(list, index) -> Button/Frame   (build the row's widgets once)
--   updateRow  : function(row, item)                     (fill the row with one data item)
-- Use list:SetItems(tableOfItems) to (re)fill it.
function GT:CreateScrollList(parent, w, h, rowH, createRow, updateRow)
    local list = CreateFrame("Frame", nil, parent)
    list:SetSize(w, h)
    list.rowH, list.numRows = rowH, math.floor(h / rowH)
    list.rows, list.items, list.offset, list.maxOffset = {}, {}, 0, 0

    for i = 1, list.numRows do
        local r = createRow(list, i)
        r:SetHeight(rowH)
        r:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * rowH)
        r:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -(i - 1) * rowH)
        r:Hide()
        list.rows[i] = r
    end

    -- thin flat scrollbar
    local bar = CreateFrame("Slider", nil, list)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(5)
    bar:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetTexture(FLAT)
    track:SetVertexColor(0.12, 0.12, 0.12, 1)
    bar:SetThumbTexture(FLAT)
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(5, 28)
    thumb:SetVertexColor(0.35, 0.35, 0.35, 1)
    bar:Hide()
    list.bar = bar

    function list:Update()
        for i, r in ipairs(self.rows) do
            local item = self.items[self.offset + i]
            if item then
                r.item = item
                updateRow(r, item)
                r:Show()
            else
                r.item = nil
                r:Hide()
            end
        end
    end

    function list:SetOffset(v)
        self.offset = math.max(0, math.min(self.maxOffset, v))
        self.syncing = true
        bar:SetValue(self.offset)
        self.syncing = false
        self:Update()
    end

    function list:SetItems(items)
        self.items = items or {}
        self.maxOffset = math.max(0, #self.items - self.numRows)
        if self.offset > self.maxOffset then self.offset = self.maxOffset end
        self.syncing = true
        bar:SetMinMaxValues(0, self.maxOffset)
        bar:SetValue(self.offset)
        self.syncing = false
        bar:SetShown(self.maxOffset > 0)
        self:Update()
    end

    bar:SetScript("OnValueChanged", function(_, v)
        if list.syncing then return end
        list.offset = math.floor(v + 0.5)
        list:Update()
    end)

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local v = math.max(0, math.min(list.maxOffset, list.offset - delta * 2))
        list.offset = v
        list.syncing = true
        bar:SetValue(v)
        list.syncing = false
        list:Update()
    end)

    return list
end

-- ------------------------------------------------------------
-- local helper: flat backdrop
local function flatBackdrop(f, role)
    f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    if GT.SkinFrame then
        GT.SkinFrame(f, role)
    else
        f:SetBackdropColor(unpack(GT.colors[role]))
        f:SetBackdropBorderColor(unpack(GT.colors.border))
    end
end

-- Flat checkbox.  cb:SetChecked(bool), cb:GetChecked(), cb.onToggle = function(checked)
function GT:CreateCheck(parent, size)
    local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    b:SetSize(size, size)
    flatBackdrop(b, "button")
    if self.SkinFrame then self.SkinFrame(b, "checkbox") end

    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetTexture(FLAT)
    b.mark:SetPoint("TOPLEFT", 3, -3)
    b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    b.mark:SetVertexColor(unpack(self.colors.active))
    b.mark:Hide()

    function b:SetChecked(v)
        self.checked = v and true or false
        self.mark:SetShown(self.checked)
    end
    function b:GetChecked() return self.checked end

    b:SetScript("OnEnter", function(s) s:SetBackdropColor(unpack(GT.colors.hover)) end)
    b:SetScript("OnLeave", function(s) s:SetBackdropColor(unpack(GT.colors.button)) end)
    b:SetScript("OnClick", function(s)
        s:SetChecked(not s.checked)
        if s.onToggle then s.onToggle(s.checked) end
    end)
    return b
end

-- Flat single-line text box
function GT:CreateEditBox(parent, w, h)
    local e = CreateFrame("EditBox", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    e:SetSize(w, h)
    flatBackdrop(e, "field")
    e:SetFontObject(GameFontHighlightSmall)
    e:SetAutoFocus(false)
    e:SetTextInsets(4, 4, 0, 0)
    e:SetJustifyH("CENTER")
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    e:HookScript("OnEditFocusGained", function(s)
        s:SetBackdropBorderColor(unpack(GT.colors.active))
        s:HighlightText()                                   -- select everything: just type the new value
        C_Timer.After(0, function()                         -- the click places the cursor AFTER focus: select again
            if s:HasFocus() then s:HighlightText() end
        end)
    end)
    e:HookScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(unpack(GT.colors.border)) end)
    return e
end

-- Flat horizontal slider with a caption.  label is a format string, e.g. "Size: %s".
-- fmt (optional): function(value) -> text shown in the caption.
-- Returns a frame; call frame:Refresh() to re-read the value through getter().
function GT:CreateSlider(parent, w, label, minV, maxV, step, getter, setter, fmt)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(w, 32)

    c.text = GT.Font(c, nil, "OVERLAY", "GameFontHighlightSmall")
    c.text:SetPoint("TOPLEFT", 0, 0)
    GT.MakeFitting(c.text, w)              -- long translations shrink instead of running past the slider

    local s = CreateFrame("Slider", nil, c)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(w - 4, 12)
    s:SetPoint("TOPLEFT", 2, -17)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(FLAT)
    track:SetVertexColor(0.2, 0.2, 0.2, 1)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)

    s:SetThumbTexture(FLAT)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(8, 12)
    thumb:SetVertexColor(0.55, 0.55, 0.55, 1)

    local function caption(v) c.text:SetText(string.format(GT.TR(label), fmt and fmt(v) or tostring(v))) end
    function c:Refresh()
        self.syncing = true
        local v = getter()
        s:SetValue(v)
        caption(v)
        self.syncing = false
    end
    s:SetScript("OnValueChanged", function(_, v)
        if c.syncing then return end
        v = math.floor(v / step + 0.5) * step
        setter(v)
        caption(v)
    end)
    c.slider = s
    c:Refresh()
    return c
end

-- Flat checkbox with a caption to its right.
-- getter() -> bool, setter(bool).  cb:Refresh() re-reads the value (also runs on GT.uiRefresh).
-- maxW (optional): widest the caption may be, default 266 px (a 288 px panel minus the box); longer text shrinks to fit.
function GT:CreateCheckLabel(parent, text, getter, setter, maxW)
    local cb = self:CreateCheck(parent, 14)
    cb:SetChecked(getter())
    cb.onToggle = function(v) setter(v and true or false) end

    local fs = GT.Font(parent, nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    GT.MakeFitting(fs, maxW or 266)
    fs:SetText(GT.TR(text))
    -- the caption is part of the check box: clicking it toggles, hovering it shows the tooltip
    cb:SetHitRectInsets(0, -(6 + math.min(fs:GetStringWidth() or 0, maxW or 266)), 0, 0)

    function cb:Refresh() self:SetChecked(getter()) end
    GT.uiRefresh[#GT.uiRefresh + 1] = function() cb:Refresh() end
    return cb, fs
end

-- Two-click safety for a destructive button: the first click turns the caption into "Click again!"
-- for 3 seconds, the second click runs fn().
function GT:SetConfirmClick(btn, text, fn)
    local armed = false
    btn:SetScript("OnClick", function(self)
        if armed then
            armed = false
            self.label:SetText(GT.TR(text))
            fn()
            return
        end
        armed = true
        self.label:SetText(GT.TR("Click again!"))
        C_Timer.After(3, function()
            if armed then armed = false; self.label:SetText(GT.TR(text)) end
        end)
    end)
end
