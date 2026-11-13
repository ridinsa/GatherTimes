-- PanelNodes.lua : the "Nodes" panel (enable, minutes, colour, sound per herb / ore + group settings)
-- Layout: [title / zone | list-all switch + type dropdown], group sliders, node list, select buttons.
local _, GT = ...
GT.panelBuilders = GT.panelBuilders or {}

local FLAT = "Interface\\Buttons\\WHITE8X8"
local ROW_H, NUM_ROWS = 22, 8
local X_CHECK, X_NAME, X_MIN, X_COL, X_ALERT, X_SND = 4, 24, 118, 180, 201, 220
local MIN_W = 56                      -- width of the minutes box (about 8 characters, e.g. "13.4" / "123.33")
local SND_W = 60                      -- width of the sound button (row ends at 280 of 280)

-- short sound names for the narrow button (display only; the real names are unchanged elsewhere)
local SHORT_SOUND = { ["Raid Warning"] = "Raid W", ["Ready Check"] = "Ready C" }
local function SoundText(idx)
    local snd = GT.SoundEntry(idx)
    return snd and GT.TR(SHORT_SOUND[snd.name] or snd.name) or ""
end

-- seconds -> minutes text, at most 2 decimals, no trailing zeros: 804 -> "13.4", 600 -> "10", 800 -> "13.33"
local function MinText(sec)
    local t = string.format("%.2f", sec / 60)
    t = t:gsub("0+$", ""):gsub("%.$", "")
    return t
end

local function ZoneName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name
end

local function Cycle(idx, count, back)
    idx = back and (idx - 1) or (idx + 1)
    if idx > count then idx = 1 elseif idx < 1 then idx = count end
    return idx
end

-- order the sound button cycles through (display only: saved settings keep the GT.SOUNDS index,
-- so "None" stays index 7 and old saves / Reset keep working). Gentle sounds first, loud ones last.
local SOUND_ORDER = { "None", "Default", "Whisper", "Toast", "Popup", "Invite", "Map Ping",
    "Auction", "Queue", "Level Up", "Ready Check", "Raid Warning", "Alarm", "Alarm 2" }
-- built-in sounds in SOUND_ORDER, then the Media sounds ("file:<name>"); rebuilt each time, so an added sound shows up
local function SoundCycle()
    local order, used = {}, {}
    for _, name in ipairs(SOUND_ORDER) do
        for i, snd in ipairs(GT.SOUNDS) do
            if snd.name == name and not used[i] then used[i] = true; order[#order + 1] = i end
        end
    end
    for i in ipairs(GT.SOUNDS) do            -- anything not listed above goes at the end
        if not used[i] then order[#order + 1] = i end
    end
    for _, file in ipairs(GT.SoundList and GT.SoundList() or {}) do
        order[#order + 1] = "file:" .. file
    end
    return order
end
local function CycleSound(idx, back)
    local order = SoundCycle()
    local pos = 1
    for p, i in ipairs(order) do if i == idx then pos = p break end end
    return order[Cycle(pos, #order, back)]
end

local function CreateRow(list, i)
    local r = CreateFrame("Frame", nil, list)

    -- show / hide this node
    r.check = GT:CreateCheck(r, 14)
    r.check:SetPoint("LEFT", X_CHECK, 0)
    r.check.onToggle = function(v)
        if not r.key then return end
        GT.cfg().enabled[r.key] = v
        GT.RefreshTimers()
        GT:OnNodesChanged()
    end

    r.name = GT.Font(r, nil, "OVERLAY", "GameFontNormalSmall")
    r.name:SetPoint("LEFT", X_NAME, 0)
    r.name:SetWidth(X_MIN - X_NAME - 4)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    -- hover zone over the item name: item tooltip (the other controls on the row keep their own mouse)
    local hover = CreateFrame("Frame", nil, r)
    hover:SetPoint("TOPLEFT", r, "TOPLEFT", X_NAME - 2, 0)
    hover:SetSize(X_MIN - X_NAME - 2, ROW_H)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self) if r.key then GT.ShowItemTooltip(self, r.key) end end)
    hover:SetScript("OnLeave", function() GT.HideItemTooltip() end)

    -- respawn time in minutes
    local eb = GT:CreateEditBox(r, MIN_W, 16)
    eb:SetPoint("LEFT", X_MIN, 0)
    eb:SetTextInsets(3, 3, 0, 0)          -- 50 px of text room (was 22)
    local function resetText(key)
        local def = key and GT.nodes[key]
        if def then eb:SetText(MinText(def.timer)) end
    end
    -- remember the node the value is typed for: a scrolled list can move this row to another node
    eb:HookScript("OnEditFocusGained", function(self) self.editKey = r.key end)
    local function apply(self)
        local key = self.editKey or r.key
        local def = key and GT.nodes[key]
        if not def then return end
        local n = tonumber((self:GetText():gsub(",", ".")))   -- "13,5" (comma locales) = 13.5
        if n and n > 0 then
            def.timer = GT.ClampTimer(n * 60, def.timer)         -- 0.5 .. 120 minutes
            GT.cfg().timers[key] = def.timer
        end
        self.editKey = nil
        resetText(key)                                           -- show the value that was really taken
    end
    eb:SetScript("OnEnterPressed", function(self) apply(self); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", apply)
    eb:SetScript("OnEscapePressed", function(self) resetText(self.editKey or r.key); self:ClearFocus() end)
    r.minutes = eb

    -- colour swatch (left / right click cycles)
    local sw = CreateFrame("Button", nil, r)
    sw:SetSize(18, 14)
    sw:SetPoint("LEFT", X_COL, 0)
    sw:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local border = sw:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetTexture(FLAT)
    border:SetVertexColor(0, 0, 0, 1)
    r.swatch = sw:CreateTexture(nil, "ARTWORK")
    r.swatch:SetAllPoints()
    r.swatch:SetTexture(FLAT)
    sw:SetScript("OnClick", function(_, btn)
        if not r.key then return end
        local c = GT.cfg()
        c.colors[r.key] = Cycle(c.colors[r.key] or 1, #GT.COLORS, btn == "RightButton")
        local col = GT.Col(r.key)
        r.swatch:SetVertexColor(col[1], col[2], col[3], 1)
        r.name:SetTextColor(col[1], col[2], col[3])
        GT.RestyleAll()
        GT.UpdateList()
    end)
    sw:SetScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
        GT.Tip:AddLine(GT.TR("Left / right click to change colour"))
        GT.Tip:Show()
    end)
    sw:SetScript("OnLeave", function() GT.Tip:Hide() end)

    r.alertCheck = GT:CreateCheck(r, 14)
    r.alertCheck:SetPoint("LEFT", X_ALERT, 0)
    r.alertCheck.onToggle = function(v)
        if not r.key then return end
        if v then
            GT.cfg().alertItems[r.key] = nil
        else
            GT.cfg().alertItems[r.key] = false
        end
    end
    r.alertCheck:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
        GT.Tip:AddLine(GT.TR("Ready alerts enabled for this resource"))
        GT.Tip:Show()
    end)
    r.alertCheck:HookScript("OnLeave", function() GT.Tip:Hide() end)

    -- alert sound (left / right click cycles, plays a preview)
    r.sound = GT:CreateFlatButton(r, "", SND_W, 16)
    r.sound:SetPoint("LEFT", X_SND, 0)
    r.sound:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.sound:SetScript("OnClick", function(self, btn)
        if not r.key then return end
        local c = GT.cfg()
        local idx = CycleSound(c.sounds[r.key] or 1, btn == "RightButton")
        c.sounds[r.key] = idx
        self.label:SetText(SoundText(idx))
        GT.PlayHerbSound(r.key)
    end)
    return r
end

local function UpdateRow(r, key)
    local def, c = GT.nodes[key], GT.cfg()
    local col = GT.Col(key)
    -- stop editing if this row now shows another node: the typed value belongs to the node it was typed for
    if r.minutes:HasFocus() and r.minutes.editKey ~= key then r.minutes:ClearFocus() end
    r.key = key
    r.check:SetChecked(GT.IsEnabled(key))
    r.name:SetText(def.label)
    r.name:SetTextColor(col[1], col[2], col[3])
    if not r.minutes:HasFocus() then r.minutes:SetText(MinText(def.timer)) end
    r.swatch:SetVertexColor(col[1], col[2], col[3], 1)
    r.alertCheck:SetChecked(c.alertItems[key] ~= false)
    r.sound.label:SetText(SoundText(c.sounds[key] or 1))
end

GT.panelBuilders.Nodes = function(panel, content)
    local ui = GatherTimesDB._ui
    local Refresh   -- forward declaration (the dropdown callback needs it)

    local function Line(y)
        local t = content:CreateTexture(nil, "ARTWORK")
        t:SetTexture(FLAT)
        t:SetVertexColor(0.2, 0.2, 0.2, 1)
        t:SetHeight(1)
        t:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        t:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
    end

    ---------------------------------------------------------------- top bar
    -- left: what is listed, right: "this zone / all" switch with the type dropdown under it
    local title = GT.Font(content, nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 2, 0)
    title:SetWidth(180)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local where = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
    where:SetPoint("TOPLEFT", 2, -18)
    where:SetWidth(180)
    where:SetJustifyH("LEFT")
    where:SetWordWrap(false)

    local toggle = GT:CreateFlatButton(content, "List all", 100, 18)
    toggle:SetPoint("TOPRIGHT", 0, 0)

    local dd = GT:CreateDropdown(content, 100, 18, { GT.TR("All"), GT.TR("Herbs"), GT.TR("Ore") }, function(index)
        ui.selected = index
        Refresh(true)
    end)
    dd:SetPoint("TOPRIGHT", 0, -22)
    dd:SetSelected(ui.selected or 1)
    Line(-46)

    ------------------------------------------------------- group settings
    -- apply to the type chosen in the dropdown
    local function isOre() return GT:GetFilterKind() == "ore" end
    local s1 = GT:CreateSlider(content, 288, "Nodes per group: %s", 3, 10, 1,
        function() local c = GT.cfg(); return isOre() and c.groupSizeOre or c.groupSize end,
        function(v)
            local c = GT.cfg()
            if isOre() then c.groupSizeOre = v else c.groupSize = v end
            pcall(GT.SyncSpawnPins)
        end)
    s1:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -54)
    local s2 = GT:CreateSlider(content, 288, "Nodes up per group (at least): %s", 1, 3, 1,
        function() local c = GT.cfg(); return isOre() and c.groupCapOre or c.groupCap end,
        function(v)
            local c = GT.cfg()
            if isOre() then c.groupCapOre = v else c.groupCap = v end
            pcall(GT.NormalizeGroupTimers)
        end)
    s2:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -88)

    local hint = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 2, -68)
    hint:SetWidth(284)
    hint:SetJustifyH("LEFT")
    hint:SetText(GT.TR("Choose Herbs or Ore in the dropdown above to edit the group settings."))
    Line(-124)

    ------------------------------------------------------------- node list
    local function caption(text, x, centre)
        local fs = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
        if centre then
            fs:SetPoint("TOP", content, "TOPLEFT", centre, -130)      -- centred over its column
        else
            fs:SetPoint("TOPLEFT", x, -130)
        end
        fs:SetText(GT.TR(text))
    end
    caption("On", X_CHECK); caption("Node", X_NAME); caption("Min", X_MIN)
    caption("Col", X_COL)
    -- one caption over the alert checkbox + sound button
    do
        local fs = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOP", content, "TOPLEFT", (X_ALERT + X_SND + SND_W) / 2, -130)
        fs:SetText(GT.TR("Sound"))
    end

    local list = GT:CreateScrollList(content, 288, ROW_H * NUM_ROWS, ROW_H, CreateRow, UpdateRow)
    list:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -144)

    -- ready sound even when out of the alert range (the sound checks this; the on-screen alert does not)
    local soundOut = GT:CreateCheckLabel(content, "Out of range sound",
        function() return GT.cfg().soundOutOfRange ~= false end,
        function(v) GT.cfg().soundOutOfRange = v end, 270)
    soundOut:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -6)
    soundOut:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
        GT.Tip:AddLine(GT.TR("Out of range sound"))
        GT.Tip:AddLine(GT.TR("On: a node's sound plays when its timer ends, even if you are outside the Alert range."), 1, 1, 1, true)
        GT.Tip:AddLine(GT.TR("Off: the sound waits until you are back inside the Alert range."), 1, 1, 1, true)
        GT.Tip:Show()
    end)
    soundOut:HookScript("OnLeave", function() GT.Tip:Hide() end)

    local listed, lastSig = {}, nil

    Refresh = function(force)
        local kind, c = GT:GetFilterKind(), GT.cfg()
        local mapID = C_Map.GetBestMapForUnit("player")
        local sig = (mapID or 0) .. ":" .. (GatherTimesDB._spawnNext or 0) .. ":"
            .. tostring(c.nodeShowAll) .. ":" .. tostring(kind)
        dd:SetSelected(ui.selected or 1)
        if not force and sig == lastSig then return end
        lastSig = sig

        local present, known = {}, 0
        if mapID then
            for _, key in ipairs(GT.order) do
                if not kind or GT.nodes[key].kind == kind then
                    for _, sp in ipairs(GT.spawns[key]) do
                        if sp.mapID == mapID then present[key] = true; known = known + 1; break end
                    end
                end
            end
        end
        local showAll = c.nodeShowAll or known == 0
        listed = {}
        for _, key in ipairs(GT.order) do
            if (not kind or GT.nodes[key].kind == kind) and (showAll or present[key]) then
                listed[#listed + 1] = key
            end
        end
        list:SetItems(listed)
        GT.nodesListed = listed          -- the rows the Nodes frame shows now (the minimized bar's strip uses them)

        local what = GT.TR((kind == "ore" and "Ores") or (kind == "herb" and "Herbs") or "All nodes")
        title:SetText(string.format("%s (%d)", what, #listed))
        if c.nodeShowAll then
            where:SetText(GT.TR("all zones"))
        elseif known == 0 then
            where:SetText(GT.TR("all zones (no data here yet)"))
        else
            where:SetText(ZoneName(mapID) or GT.TR("this zone"))
        end
        toggle.label:SetText(GT.TR(c.nodeShowAll and "This zone only" or "List all"))

        if kind then
            s1:Show(); s2:Show(); hint:Hide()
            s1:Refresh(); s2:Refresh()
        else
            s1:Hide(); s2:Hide(); hint:Show()
        end
    end

    toggle:SetScript("OnClick", function()
        GT.cfg().nodeShowAll = not GT.cfg().nodeShowAll
        Refresh(true)
    end)

    ------------------------------------------------------- bottom buttons
    local function setAll(value)
        for _, key in ipairs(listed) do GT.cfg().enabled[key] = value end
        list:Update()
        GT.RefreshTimers()
        GT:OnNodesChanged()
    end
    local all = GT:CreateFlatButton(content, "Select All", 92, 20)
    all:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    all:SetScript("OnClick", function() setAll(true) end)
    local none = GT:CreateFlatButton(content, "Select None", 92, 20)
    none:SetPoint("BOTTOM", content, "BOTTOM", 0, 0)
    none:SetScript("OnClick", function() setAll(false) end)

    -- Reset: respawn time, colour and sound of the LISTED nodes back to the defaults
    -- (time = factory minutes, colour = factory colour, sound = None)
    local reset = GT:CreateFlatButton(content, "Reset", 92, 20)
    reset:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    GT:SetConfirmClick(reset, "Reset", function()
        local c = GT.cfg()
        for _, key in ipairs(listed) do
            local def = GT.nodes[key]
            def.timer = def.defaultTimer or def.timer
            c.timers[key] = nil
            c.colors[key] = GT.DEFAULT_COLOR[key] or 1
            c.sounds[key] = 7                          -- "None"
        end
        GT.RestyleAll()
        GT.UpdateList()
        list:Update()
        GT:OnNodesChanged()
        GT.cprint(GT.TRF("%d node(s) reset: time, colour and sound back to default (sound = None).", #listed))
    end)
    reset:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_TOP")
        GT.Tip:AddLine(GT.TR("Reset"))
        GT.Tip:AddLine(GT.TR("Set the listed nodes back to default time, colour and sound. Running timers switch to the new default right away."), 0.85, 0.85, 0.85, true)
        GT.Tip:Show()
    end)
    reset:HookScript("OnLeave", function() GT.Tip:Hide() end)

    -- keep in sync: on show, every second (zone changes), external refresh
    panel:SetScript("OnShow", function() Refresh(true) end)
    panel:HookScript("OnHide", function()
        dd.list:Hide()
        if GT.StopMediaSound then GT.StopMediaSound() end   -- closing the panel stops any sound it started
    end)
    local t = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        if t >= 1 then t = 0; Refresh(false) end
    end)
    GT.uiRefresh[#GT.uiRefresh + 1] = function() Refresh(true) end
    Refresh(true)
end
