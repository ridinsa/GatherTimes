-- SpotMenu.lua : right-click menu for a spot on the WORLD MAP (flat style)
--   * right-click a timer text or a spot pin on the world map  ->  small menu:
--       "This spot is empty" / "Group taken by someone" / "Move this spot to group: 1 2 3 ... New"
--   * switched on/off with  Settings > General > World map  (cfg().menuMap)
--   * the minimap never opens it (only world-map frames take mouse clicks)
local _, GT = ...

local MAX_GROUP_BUTTONS = 12          -- group buttons 1..12, plus "New" (id 13)

-- Move one learned spot to another group of the same item (targetIdx = group number shown as G<n>)
function GT.MoveSpotToGroup(sp, key, targetIdx)
    local mapID = sp.mapID
    local res = GT.ComputeGroups(key, mapID)
    local st = GT.cfg().groupStore[key .. ":" .. mapID]
    if not st then return false end
    local from = res.of[sp]
    local gid = res.gid[targetIdx]
    if not gid then                    -- "New": start a brand-new group
        st.n = st.n + 1
        gid = st.n
    end
    st.of[sp.sid] = gid
    GT.groupRebuild = GT.groupRebuild + 1
    pcall(GT.NormalizeGroupTimers)
    GT.cprint(GT.TRF("%s spot moved from G%s to G%d.", GT.nodes[key].label, tostring(from or "?"), targetIdx))
    return true
end

local menu, cur, gbtns

local function Over(frame)
    if frame.IsMouseOver then return frame:IsMouseOver() end
    return MouseIsOver and MouseIsOver(frame) or false
end

local function Build()
    cur, gbtns = {}, {}
    menu = GT:CreateFlatFrame("GatherTimesSpotMenu", UIParent, 188, 120)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:Hide()
    tinsert(UISpecialFrames, "GatherTimesSpotMenu")        -- ESC closes it

    menu.title = GT.Font(menu, nil, "OVERLAY", "GameFontNormal")
    menu.title:SetPoint("TOPLEFT", 8, -6)
    menu.title:SetWidth(172)
    menu.title:SetJustifyH("LEFT")
    menu.title:SetWordWrap(false)

    local function Btn(text, w) return GT:CreateFlatButton(menu, text, w, 20) end

    local empty = Btn("This spot is empty", 172)
    empty:SetPoint("TOPLEFT", 8, -26)
    empty:SetScript("OnClick", function()
        if cur.sp then GT.SpotChecked(cur.sp, cur.key) end
        menu:Hide()
    end)

    local taken = Btn("Group taken by someone", 172)
    taken:SetPoint("TOPLEFT", 8, -48)
    taken:SetScript("OnClick", function()
        if cur.sp and not GT.MarkEmpty(cur.sp, cur.key) then
            GT.cprint(GT.TR("This group already has a running timer."))
        end
        menu:Hide()
    end)

    menu.note = GT:CreateEditBox(menu, 120, 18)
    menu.note:SetPoint("TOPLEFT", 8, -74)
    menu.note:SetTextInsets(4, 4, 0, 0)
    if menu.note.SetMaxLetters then menu.note:SetMaxLetters(80) end
    menu.note:SetScript("OnEscapePressed", function(self) self:ClearFocus(); menu:Hide() end)
    local saveNote = Btn("Save note", 48)
    saveNote:SetPoint("TOPLEFT", 132, -74)
    saveNote:SetScript("OnClick", function()
        if cur.sp then cur.sp.note = GT.SanitizeSpotNote(menu.note:GetText()) end
        menu:Hide()
    end)

    local label = GT.Font(menu, nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 8, -100)
    label:SetText(GT.TR("Move this spot to group:"))

    for i = 1, MAX_GROUP_BUTTONS + 1 do
        local isNew = (i == MAX_GROUP_BUTTONS + 1)
        local b = Btn(isNew and GT.TR("New") or tostring(i), isNew and 32 or 24)
        b:SetScript("OnClick", function()
            if cur.sp then
                local res = GT.ComputeGroups(cur.key, cur.sp.mapID)
                GT.MoveSpotToGroup(cur.sp, cur.key, isNew and (#res.groups + 1) or i)
            end
            menu:Hide()
        end)
        gbtns[i] = b
    end

    -- close when you click anywhere else
    menu:SetScript("OnUpdate", function(self)
        if GetTime() - (self.openedAt or 0) < 0.2 then return end     -- the opening click is still down
        if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and not Over(self) then
            self:Hide()
        end
    end)
end

-- target = a timer node (isNode = true) or a learned spot (world-map pin)
function GT.OpenSpotMenu(_, target, key, isNode)
    if not GT.cfg().menuMap then return end
    local sp = isNode and GT.SpawnOfNode(key, target) or target
    if not sp then GT.cprint(GT.TR("No learned spot here to edit.")); return end
    if not menu then Build() end

    cur.sp, cur.key = sp, key
    local res = GT.ComputeGroups(key, sp.mapID)
    local gi = res.of[sp]
    menu.title:SetText(GT.nodes[key].label .. (gi and (" - G" .. gi) or ""))

    for i = 1, MAX_GROUP_BUTTONS + 1 do gbtns[i]:Hide() end
    local list = {}
    for i = 1, math.min(#res.groups, MAX_GROUP_BUTTONS) do list[#list + 1] = i end
    list[#list + 1] = MAX_GROUP_BUTTONS + 1                   -- "New"
    for pos, i in ipairs(list) do
        local b = gbtns[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 8 + ((pos - 1) % 6) * 28, -118 - math.floor((pos - 1) / 6) * 22)
        if i == gi then                                       -- its own group: not selectable
            b:Disable()
            b.label:SetTextColor(0.45, 0.45, 0.45)
        else
            b:Enable()
            b.label:SetTextColor(1, 0.82, 0)
        end
        b:Show()
    end
    menu.note:SetText(sp.note or "")
    menu:SetSize(188, 118 + math.ceil(#list / 6) * 22 + 10)

    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    menu.openedAt = GetTime()
    menu:Show()
    menu:Raise()
end
