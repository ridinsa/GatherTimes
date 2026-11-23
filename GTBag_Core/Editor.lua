-- Editor.lua : window for custom categories.  Left: your groups.  Right: the rules of the selected group.
-- A rule is an item id, a shift-clicked item or part of an item name.  Opened with the right mouse button on View, or
-- /gtbag cat edit.
local _, ns = ...

local UI = ns.UI
local PAD = UI.PAD
local W, H, ROW, LEFT_W = 520, 380, 20, 160
local win, nameBox, ruleBox, status, rulesLabel, delBtn, addBtn
local selected            -- category id
local leftRows, rightRows = {}, {}
local leftChild, rightChild

local function Pool(rows, parent, i, kind)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * ROW)
    r:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    r:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local hl = r:GetHighlightTexture()
    if hl then hl:SetAlpha(0.12) end
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints()
    r.sel:SetColorTexture(0.2, 0.3, 0.45, 0.55)
    r.sel:Hide()
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", 6, 0)
    r.text:SetPoint("RIGHT", kind == "rule" and -26 or -4, 0)
    r.text:SetJustifyH("LEFT")
    if kind == "rule" then
        r.del = UI.Button(r, "x", 18, 16)
        r.del:SetPoint("RIGHT", -3, 0)
    end
    rows[i] = r
    return r
end

local function Say(text) if status then status:SetText(text or "") end end

local function Selected()
    for _, c in ipairs(ns.CustomCats()) do
        if c.id == selected then return c end
    end
end

local function RuleText(rule)
    if type(rule) == "number" then
        local name = ns.GetItemInfo(rule)
        return name and string.format("%s |cff888888(item %d)|r", name, rule) or ("item " .. rule)
    end
    return "name contains \"" .. tostring(rule) .. "\""
end

local function Changed()
    if ns.Relayout then ns.Relayout() end
    ns.RefreshCatEditor()
end

function ns.RefreshCatEditor()
    if not (win and win:IsShown()) then return end
    local cats = ns.CustomCats()
    if not Selected() then selected = cats[1] and cats[1].id or nil end
    for i, c in ipairs(cats) do
        local r = Pool(leftRows, leftChild, i, "cat")
        r.text:SetText(string.format("%s |cff888888(%d)|r", c.name, #c.rules))
        r.sel:SetShown(c.id == selected)
        r:SetScript("OnClick", function() selected = c.id; Say(""); ns.RefreshCatEditor() end)
        r:Show()
    end
    for i = #cats + 1, #leftRows do leftRows[i]:Hide() end
    leftChild:SetHeight(math.max(1, #cats * ROW))

    local cur = Selected()
    rulesLabel:SetText(cur and ("Rules of \"" .. cur.name .. "\"") or "Rules")
    if cur then delBtn:Enable(); addBtn:Enable() else delBtn:Disable(); addBtn:Disable() end
    local rules = cur and cur.rules or {}
    for i, rule in ipairs(rules) do
        local r = Pool(rightRows, rightChild, i, "rule")
        r.text:SetText(RuleText(rule))
        r.del:SetScript("OnClick", function()
            local _, msg = ns.CatRemoveRules(cur.name, tostring(rule))
            Say(msg)
            Changed()
        end)
        r:Show()
    end
    for i = #rules + 1, #rightRows do rightRows[i]:Hide() end
    rightChild:SetHeight(math.max(1, #rules * ROW))
end

local function AddRule()
    local cur = Selected()
    if not cur then return end
    local ok, msg = ns.CatSave(cur.name, ruleBox:GetText())
    Say(msg)
    if ok then ruleBox:SetText("") end
    Changed()
end

local function Build()
    win = UI.Window("GTBagCatEditor", W, H, "Custom categories")

    -- the two lists
    local leftPanel, _, lchild = UI.ScrollList(win, ROW)
    leftChild = lchild
    leftPanel:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -62)
    leftPanel:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, 62)
    leftPanel:SetWidth(LEFT_W)
    local rightPanel, _, rchild = UI.ScrollList(win, ROW)
    rightChild = rchild
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 62)

    -- captions above the lists (inside the window, below the header rule)
    local groupsLabel = UI.Label(win, "Groups")
    groupsLabel:SetPoint("BOTTOMLEFT", leftPanel, "TOPLEFT", 2, 6)
    rulesLabel = UI.Label(win, "Rules")
    rulesLabel:SetPoint("BOTTOMLEFT", rightPanel, "TOPLEFT", 2, 6)
    rulesLabel:SetWidth(W - (PAD + LEFT_W + 10) - PAD - 96)
    rulesLabel:SetJustifyH("LEFT")
    delBtn = UI.Button(win, "Delete group", 88)
    delBtn:SetPoint("BOTTOMRIGHT", rightPanel, "TOPRIGHT", 0, 2)
    delBtn:SetScript("OnClick", function()
        local cur = Selected()
        if not cur then return end
        local _, msg = ns.CatDelete(cur.name)
        selected = nil
        Say(msg)
        Changed()
    end)

    -- inputs under the lists
    nameBox = UI.EditBox(win, "New group name", LEFT_W - 52)
    nameBox:SetMaxLetters(24)
    nameBox:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD + 6, 32)
    local newBtn = UI.Button(win, "New", 44)
    newBtn:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", 0, -30)
    local function NewGroup()
        local ok, msg, c = ns.CatCreate(nameBox:GetText())
        Say(msg)
        if ok and c then selected = c.id; nameBox:SetText(""); nameBox:ClearFocus() end
        Changed()
    end
    newBtn:SetScript("OnClick", NewGroup)
    nameBox:SetScript("OnEnterPressed", NewGroup)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    addBtn = UI.Button(win, "Add", 50)
    addBtn:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", 0, -30)
    addBtn:SetScript("OnClick", AddRule)
    ruleBox = UI.EditBox(win, "Part of a name, item id, or shift-click an item")
    ruleBox:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 6, -30)
    ruleBox:SetPoint("RIGHT", addBtn, "LEFT", -6, 0)
    ruleBox:SetScript("OnEnterPressed", AddRule)
    ruleBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    UI.Rule(win, 28)
    status = UI.Label(win, "")
    status:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, 9)
    status:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 9)
    status:SetJustifyH("LEFT")

    win:SetScript("OnShow", function() ns.RefreshCatEditor() end)
    win:Hide()

    -- shift-clicking an item while the rule box has the cursor puts its link there (after the game's own handling)
    local function Insert(text)
        if ruleBox and ruleBox:HasFocus() and type(text) == "string" then ruleBox:Insert(text) end
    end
    if hooksecurefunc then
        if type(_G.ChatEdit_InsertLink) == "function" then pcall(hooksecurefunc, "ChatEdit_InsertLink", Insert) end
        if _G.ChatFrameUtil and type(_G.ChatFrameUtil.InsertLink) == "function" then
            pcall(hooksecurefunc, _G.ChatFrameUtil, "InsertLink", Insert)
        end
    end
end

function ns.ShowCatEditor()
    if not win then Build() end
    if win:IsShown() then win:Hide() else win:Show() end
end
