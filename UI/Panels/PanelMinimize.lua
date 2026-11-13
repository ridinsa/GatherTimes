-- PanelMinimize.lua : the "Minimize settings" panel (right-click the "-" button in the main window's title bar).
-- It is a normal side panel (same size, same slot beside the main window, not movable), so Panels.lua already makes
-- sure only one panel is open at a time.  Everything here is about the minimized bar (UI\MiniBar.lua, UI\BarDock.lua).
-- Tabs (same look as Settings):
--   Bar    : always show, summary, bar size and opacity, fading (combat / mouse away)
--   Chips  : group chips, urgency colours, blink and bag warnings
--   XP     : the XP button and what its line shows, level-up alerts
--   Goals  : the goal boxes shown on the bar
--   Pings  : which pings show on the bar, the red-ping sound and its repeat delay
-- Every setting keeps its saved key and default. Options with no effect right now are greyed out.
local _, GT = ...
GT.panelBuilders = GT.panelBuilders or {}

local BLINK_DEFAULT = 15            -- same default as UI\MiniBar.lua

-- Layout: every tab is one column, filled top to bottom by a cursor, so the spacing is always the same:
--   a check box takes CHECK_STEP, a slider takes SLIDER_STEP, a group heading takes HEAD_GAP + HEAD_STEP.
local CHECK_STEP, SLIDER_STEP = 22, 36
local HEAD_GAP, HEAD_STEP = 10, 20
local PANEL_W = 288                 -- the usable width of a panel
local DIMMED = 0.4                  -- alpha of an option that has no effect right now

-- the sounds for the ping alert: the built-in list in Media\SoundList.lua
function GT.SoundList()
    return { unpack(GT.MEDIA_SOUNDS or {}) }
end

GT.panelBuilders.Minimize = function(panel, content)
    local cfg = GT.cfg
    if GatherTimesDB then GatherTimesDB.extraSounds = nil end   -- names added by the old Goals box are no longer used
    local ui = GatherTimesDB._ui
    local subs, tabs = {}, {}
    local deps = {}                 -- { frames = {...}, on = function() -> bool }

    -- Greys out every option whose condition is false. Called after each change and when the panel is shown.
    local function ApplyDeps()
        for _, d in ipairs(deps) do
            local on = d.on() and true or false
            for _, f in ipairs(d.frames) do
                f:SetAlpha(on and 1 or DIMMED)
                if f.Enable and f.Disable then
                    if on then f:Enable() else f:Disable() end
                end
            end
        end
    end

    local function Depend(frames, on)
        deps[#deps + 1] = { frames = frames, on = on }
    end

    -- the one place that redraws the bar after a setting changes
    local function Touch()
        if GT.bar then GT:UpdateMiniBar() end
        ApplyDeps()
    end

    local function ShowSub(id)
        for sid, f in pairs(subs) do f:SetShown(sid == id) end
        for sid, b in pairs(tabs) do GT:SetButtonActive(b, sid == id) end
    end

    local function AddOptionTip(frame, title, description)
        frame:HookScript("OnEnter", function(self)
            GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
            GT.Tip:AddLine(GT.TR(title))
            GT.Tip:AddLine(GT.TR(description), 0.85, 0.85, 0.85, true)
            GT.Tip:Show()
        end)
        frame:HookScript("OnLeave", function() GT.Tip:Hide() end)
    end

    -- five equal tabs that together are exactly as wide as the panel
    local TAB_W, TAB_GAP = 54, 4              -- five tabs across the 288 px panel
    local function AddSub(id, text, index)
        local b = GT:CreateFlatButton(content, text, TAB_W, 20)
        b:SetPoint("TOPLEFT", (index - 1) * (TAB_W + TAB_GAP), 0)
        b:SetScript("OnClick", function() ShowSub(id) end)
        tabs[id] = b
        local f = CreateFrame("Frame", nil, content)
        f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -30)
        f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
        f:Hide()
        subs[id] = f
        f.y = 0                      -- the cursor: where the next row goes
        f.first = true               -- no gap above the first heading
        return f
    end

    local bar   = AddSub("bar",   "Bar",   1)
    local chips = AddSub("chips", "Chips", 2)
    local xp    = AddSub("xp",    "XP",    3)
    local goals = AddSub("goals", "Goals", 4)
    local pings = AddSub("pings", "Pings", 5)

    -- a gold group heading with a thin line under it
    local function Heading(parent, text)
        if not parent.first then parent.y = parent.y - HEAD_GAP end
        parent.first = false
        local fs = GT.Font(parent, nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 2, parent.y)
        GT.MakeFitting(fs, PANEL_W - 4)
        fs:SetText(GT.TR(text))
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetVertexColor(0.35, 0.35, 0.35, 0.8)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 0, parent.y - 13)
        line:SetPoint("TOPRIGHT", parent, "TOPLEFT", PANEL_W, parent.y - 13)
        parent.y = parent.y - HEAD_STEP
    end

    -- dependsOn (optional): function() -> bool; the option is greyed out while it returns false
    local function Check(parent, text, get, set, description, dependsOn)
        local cb, fs = GT:CreateCheckLabel(parent, text, get, set)
        cb:SetPoint("TOPLEFT", 2, parent.y)
        AddOptionTip(cb, text, description)
        parent.y = parent.y - CHECK_STEP
        if dependsOn then Depend({ cb, fs }, dependsOn) end
        return cb
    end

    local function Slider(parent, label, lo, hi, step, get, set, fmt, description, dependsOn)
        local s = GT:CreateSlider(parent, PANEL_W, label, lo, hi, step, get, set, fmt)
        s:SetPoint("TOPLEFT", 0, parent.y)
        AddOptionTip(s.slider, (label:gsub(": %%s.*$", "")), description)
        GT.uiRefresh[#GT.uiRefresh + 1] = function() s:Refresh() end
        parent.y = parent.y - SLIDER_STEP
        if dependsOn then Depend({ s, s.slider }, dependsOn) end
        return s
    end

    ---------------------------------------------------------------- Bar
    Heading(bar, "Behaviour")
    -- showing the bar: on = once the addon is opened, the bar stays on screen; off = only from the "-" button.
    Check(bar, "Always show minimized panel",
        function() return cfg().miniAlwaysShow == true end,
        function(v)
            cfg().miniAlwaysShow = v
            GT:ApplyAlwaysBar()
            -- this panel is open: keep the bar on screen as its preview (ApplyAlwaysBar may have just hidden it)
            if panel:IsShown() then
                GT.barPreviewing = false
                GT:SetBarPreview(true)
            end
            Touch()
        end,
        "On: the minimized bar is on screen as soon as the addon loads, even with the main window closed, and it stays while you open and close the windows. The red x on the bar hides it until you open the addon or use /gt min. Off: the bar appears only when you click the \"-\" button in the main window.")

    Check(bar, "Minimized summary: show all items",
        function() return cfg().miniSummaryAll ~= false end,
        function(v)
            cfg().miniSummaryAll = v
        end,
        "On: the gold tooltip of the minimized bar lists every item. Off: it lists only the items ticked in the Nodes panel. The gold value always counts everything you loot.")

    Heading(bar, "Look")
    Slider(bar, "Bar size: %s", 60, 150, 5,
        function() return math.floor((ui.barScale or 1) * 100 + 0.5) end,
        function(v)
            ui.barScale = v / 100
            if GT.bar then
                GT.bar:SetScale(ui.barScale)
                if GT.BarDock then GT.BarDock.Sync() end      -- the game frames follow the new bar height
                GT:UpdateMiniBar()
            end
        end,
        function(v) return v .. "%" end,
        "Resize the minimized bar. The main window keeps its own size.")

    -- background opacity of the bar (text, buttons and chip contents stay solid)
    Slider(bar, "Bar opacity: %s", 0, 100, 5,
        function() return cfg().miniBgAlpha or 95 end,
        function(v)
            cfg().miniBgAlpha = v
            if GT.bar then GT:ApplyBarBackground() end
        end,
        function(v) return v .. "%" end,
        "How solid the background of the minimized bar is. Lower it to see the game through the bar. The text stays fully readable.")

    Heading(bar, "Fade")
    local function FadeOn() return cfg().miniFadeCombat == true or cfg().miniFadeMouse == true end

    Check(bar, "Fade in combat",
        function() return cfg().miniFadeCombat == true end,
        function(v)
            cfg().miniFadeCombat = v
            if GT.bar then GT:ApplyBarFade() end
            Touch()
        end,
        "On: the minimized bar fades while you are in combat. Hover the mouse over it to see it fully.")

    Check(bar, "Fade when mouse is away",
        function() return cfg().miniFadeMouse == true end,
        function(v)
            cfg().miniFadeMouse = v
            if GT.bar then GT:ApplyBarFade() end
            Touch()
        end,
        "On: the minimized bar fades whenever the mouse is not over it, and comes back when you move the mouse onto it.")

    Slider(bar, "Faded opacity: %s", 0, 100, 5,
        function() return cfg().miniFadeAlpha or 30 end,
        function(v)
            cfg().miniFadeAlpha = v
            if GT.bar then GT:ApplyBarFade() end
        end,
        function(v) return v .. "%" end,
        "How visible the whole bar is while it is faded (see the two fade options above). Only used when one of them is on.",
        FadeOn)

    ---------------------------------------------------------------- Chips
    Heading(chips, "Group chips")
    -- auto width: each chip is sized to its text and shows the node count; off: only Gx and the timer
    Check(chips, "Auto width (show node count)",
        function() return cfg().miniChipAuto ~= false end,
        function(v)
            cfg().miniChipAuto = v
            Touch()
        end,
        "On: each chip is sized to its text and shows the group and how many nodes you took in it, e.g. G1 12:34 /2. Off: each chip shows only Gx and the timer.")

    Check(chips, "Chip tooltip",
        function() return cfg().miniChipTip ~= false end,
        function(v)
            cfg().miniChipTip = v
        end,
        "On: hover a group chip to see the timer of every node you took in that group.")

    Check(chips, "Sort chips by urgency",
        function() return cfg().miniSortUrgency ~= false end,
        function(v)
            cfg().miniSortUrgency = v
            Touch()
        end,
        "On: the chips on the minimized bar are sorted by soonest ready (READY first, then the shortest timer), so the most useful chips are always visible instead of hiding behind \"+N more\". Off: the chips follow the table's order.")

    Check(chips, "Hide idle groups",
        function() return cfg().miniHideIdle == true end,
        function(v)
            cfg().miniHideIdle = v
            Touch()
        end,
        "On: the minimized bar shows only groups that are running or ready. Groups with no timer (Idle) are left out. Off: every known group is shown.")

    Heading(chips, "Warnings")
    Check(chips, "Urgency colors",
        function() return cfg().miniUrgencyColors ~= false end,
        function(v)
            cfg().miniUrgencyColors = v
            Touch()
        end,
        "On: the progress bar under a waiting chip is white, then yellow and red as its timer drops (set the two warning times below). Off: it keeps the status colour.")

    -- blink warning: a chip pulses when its timer is at or below this many seconds
    Slider(chips, "Blink warning: %s", 0, 30, 1,
        function() return cfg().miniBlinkSecs or BLINK_DEFAULT end,
        function(v)
            cfg().miniBlinkSecs = v
            Touch()
        end,
        function(v) return v == 0 and GT.TR("Off") or GT.TRF("%d sec", v) end,
        "A group on the minimized bar blinks when its timer is at or below this many seconds. 0 turns the blinking off.")

    -- urgency thresholds: red can never be above yellow (moving one moves the other)
    local UrgencyOn = function() return cfg().miniUrgencyColors ~= false end
    local redSlider, yellowSlider
    yellowSlider = Slider(chips, "Yellow warning at: %s", 0, 300, 5,
        function() return cfg().miniYellowSecs or 60 end,
        function(v)
            cfg().miniYellowSecs = v
            if (cfg().miniRedSecs or 15) > v then
                cfg().miniRedSecs = v
                if redSlider then redSlider:Refresh() end
            end
            Touch()
        end,
        function(v) return GT.TRF("%d sec", v) end,
        "The progress bar of a waiting group turns yellow when its timer is at or below this many seconds. Needs Urgency colors.",
        UrgencyOn)
    redSlider = Slider(chips, "Red warning at: %s", 0, 300, 5,
        function() return cfg().miniRedSecs or 15 end,
        function(v)
            cfg().miniRedSecs = v
            if (cfg().miniYellowSecs or 60) < v then
                cfg().miniYellowSecs = v
                if yellowSlider then yellowSlider:Refresh() end
            end
            Touch()
        end,
        function(v) return GT.TRF("%d sec", v) end,
        "The progress bar of a waiting group turns red when its timer is at or below this many seconds. Needs Urgency colors.",
        UrgencyOn)

    -- bag space warning (Gathering\BagSpace.lua): an alert and a red chip on the bar
    Check(chips, "Bag space warning",
        function() return cfg().bagWarn ~= false end,
        function(v)
            cfg().bagWarn = v
            if GT.CheckBags then GT.CheckBags() end
            Touch()
        end,
        "On: an alert on screen and a red Bags chip on the minimized bar when your free bag slots drop to the number below. Full bags are the most common way to lose loot.")
    Slider(chips, "Warn at: %s", 1, 30, 1,
        function() return cfg().bagWarnSlots or 5 end,
        function(v)
            cfg().bagWarnSlots = v
            if GT.CheckBags then GT.CheckBags() end
            Touch()
        end,
        function(v) return GT.TRF("%d free slots", v) end,
        "The bag space warning shows when this many bag slots or fewer are free. Needs Bag space warning.",
        function() return cfg().bagWarn ~= false end)

    ---------------------------------------------------------------- XP
    -- one column, full width: no caption has to shrink to fit
    local function Opt(text, key, default, description, after, dependsOn)
        Check(xp, text,
            function()
                if default then return cfg()[key] ~= false end
                return cfg()[key] == true
            end,
            function(v)
                cfg()[key] = v
                if after then after(v) end
                Touch()
            end,
            description,
            dependsOn)
    end

    -- the XP line options only matter while the XP button is on
    local XPButtonOn = function() return cfg().miniShowXP ~= false end

    -- the button, and what the XP line on the bar shows (UI\MiniXP.lua LineText; all on by default, except gold per hour)
    Heading(xp, "XP line")
    Opt("Show XP button", "miniShowXP", true,
        "On: the XP button sits right after the dropdown on the minimized bar. Click it to show the hero and pet XP information in one line instead of the gathering timers. Off: the button is hidden and XP mode is off.",
        function(v) if not v and GT.MiniXP then GT.MiniXP.SetOn(false) end end)    -- hiding it also turns XP mode off
    Opt("Show hero battles", "miniXPHero", true,
        "On: the XP line shows how many battles you need to reach the next level.", nil, XPButtonOn)
    Opt("Show XP per hour", "miniXPRate", true,
        "On: the XP line shows your hero XP per hour over the last 10 minutes, with the session average next to it once the session is longer.", nil, XPButtonOn)
    Opt("Show time to level", "miniXPLevelIn", true,
        "On: the XP line shows how long until the next level at your current XP per hour.", nil, XPButtonOn)
    Opt("Show rested XP", "miniXPRested", true,
        "On: the XP line shows how much rested XP you have, in percent of the level.", nil, XPButtonOn)
    Opt("Show pet capped warning", "miniXPPet", true,
        "On: the XP line warns, and a chat message appears once, when your hunter pet has reached your level and gains no more XP.", nil, XPButtonOn)
    Opt("Show gold per hour", "miniXPGold", false,
        "On: the XP line shows the gold you loot per hour this session, with the same prices as the gold summary.", nil, XPButtonOn)
    Opt("Ignore idle time", "miniXPIdle", true,
        "On: standing still for more than 2 minutes (no moving, fighting, casting, looting or XP) is left out of XP per hour, time to level and the goal pace. Off: the whole session time counts.")

    Heading(xp, "Alerts")
    Opt("Level-up alert", "miniXPLevelAlert", true,
        "On: when you level up, a message appears on screen and a sound plays.")
    Opt("Alert when close to level", "miniXPAlmost", false,
        "On: a message appears once per level when you are only a few battles away from the next level.")
    Slider(xp, "Alert at: %s", 1, 20, 1,
        function() return cfg().miniXPAlmostN or 5 end,
        function(v) cfg().miniXPAlmostN = v end,
        function(v) return GT.TRF("%d battles left", v) end,
        "How many battles from the next level the alert shows. Needs Alert when close to level.",
        function() return cfg().miniXPAlmost == true end)

    ---------------------------------------------------------------- Goals
    -- goals (UI\MiniXP.lua): two boxes per line.  Gold (looted this session) and level, then a skill ("mining 300") and
    -- the hours to reach them (pace colours).  Fill any of them, Enter sets it, empty or "off" clears it.
    -- One goal = the full line on the bar, two or three = the line divided in equal parts.
    local COL2 = 148
    local goalHint = GT.Font(goals, nil, "OVERLAY", "GameFontHighlightSmall")
    goalHint:SetPoint("TOPLEFT", 2, -2)
    goalHint:SetWidth(284)
    goalHint:SetJustifyH("LEFT")
    goalHint:SetWordWrap(true)
    goalHint:SetText(GT.TR("Type a goal and press Enter. Leave a box empty to clear it."))
    local goalBoxes = {}
    local function RefreshGoalBoxes()
        for kind, box in pairs(goalBoxes) do
            if not box:HasFocus() then box:SetText(GT.MiniXP and GT.MiniXP.GoalBoxText(kind) or "") end
        end
    end
    local function GoalBox(kind, caption, y, col, letters, tip)
        -- the caption starts the column, the box ends it: the right edges line up with the panel
        local BOX_W = 76
        local labelX, boxX = 2, 142 - BOX_W
        if col == 2 then labelX, boxX = COL2, 288 - BOX_W end
        local label = GT.Font(goals, nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", labelX, y - 4)
        label:SetText(GT.TR(caption))
        local box = GT:CreateEditBox(goals, BOX_W, 20)
        box:SetPoint("TOPLEFT", boxX, y)
        box:SetJustifyH("LEFT")
        box:SetMaxLetters(letters)
        box:SetText(GT.MiniXP and GT.MiniXP.GoalBoxText(kind) or "")
        AddOptionTip(box, caption, tip)
        box:SetScript("OnEnterPressed", function(self)
            if GT.MiniXP then GT.MiniXP.SetGoalPart(kind, self:GetText()) end
            self:ClearFocus()
            RefreshGoalBoxes()
            if GT.bar then GT:UpdateMiniBar() end
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(GT.MiniXP and GT.MiniXP.GoalBoxText(kind) or "")
            self:ClearFocus()
        end)
        goalBoxes[kind] = box
    end
    GoalBox("gold", "Gold", -34, 1, 7,
        "How much gold to loot this session, for example 500, then press Enter. Leave empty to have no gold goal.")
    GoalBox("level", "Level", -34, 2, 3,
        "The level to reach, for example 40, then press Enter. Leave empty to have no level goal.")
    GoalBox("skill", "Skill", -62, 1, 14,
        "A Mining or Herbalism skill to reach, for example mining 300 or herb 225, then press Enter. Leave empty to have no skill goal. The time estimate starts after your first skill-up.")
    GoalBox("by", "By (h)", -62, 2, 5,
        "Optional: the hours you give yourself to reach the goals above, for example 2 or 1.5. The goal line turns orange when you are tight on time and red when you are behind, and the time left is shown in the goal text. Leave empty for no time limit.")
    local goalNote = GT.Font(goals, nil, "OVERLAY", "GameFontHighlightSmall")
    goalNote:SetPoint("TOPLEFT", 2, -96)
    goalNote:SetWidth(284)
    goalNote:SetJustifyH("LEFT")
    goalNote:SetWordWrap(true)
    goalNote:SetText(GT.TR("One goal fills the whole goal line on the bar; two or three share it in equal parts."))

    goals:HookScript("OnShow", RefreshGoalBoxes)

    ---------------------------------------------------------------- Pings
    -- everything about the ping alert: which pings show on the bar, and the sound that plays when one is red
    Heading(pings, "Show on the bar")
    Check(pings, "Show FPS",
        function() return cfg().miniFps ~= false end,
        function(v)
            cfg().miniFps = v
            Touch()
        end,
        "On: the smaller pings below the main pings shows your frame rate as fps:60.")
    Check(pings, "Show home ping (H)",
        function() return cfg().miniHomePing ~= false end,
        function(v)
            cfg().miniHomePing = v
            Touch()
        end,
        "On: the smaller pings below the main pings shows your home latency in ms as H:45 (the connection to the realm). Green under 300, yellow under 500, and red and blinking at 500 or more.")
    Check(pings, "Show world ping (W)",
        function() return cfg().miniWorldPing ~= false end,
        function(v)
            cfg().miniWorldPing = v
            Touch()
        end,
        "On: the smaller pings below the main pings shows your world latency in ms as W:60 (the connection that carries movement and combat). Green under 300, yellow under 500, and red and blinking at 500 or more.")

    Heading(pings, "Ping sound")
    Check(pings, "Sound when ping is red",
        function() return cfg().miniPingSound == true end,
        function(v)
            cfg().miniPingSound = v
            if not v then GT.StopPingSound() end
            Touch()                                   -- greys or enables the < > buttons and the sound name
        end,
        "On: a sound plays once when your home or world ping turns red (500 ms or more). It waits 20 seconds before it can play again. Only the pings shown on the pings count.",
        function() return cfg().miniHomePing ~= false or cfg().miniWorldPing ~= false end)
    -- sound picker: < and > step through the sounds found in Media\ from GT.SoundList (built-in and added).
    -- Each click plays the sound it lands on. The name is shown below the buttons, in grey.
    local function SoundList()
        return GT.SoundList()
    end
    local function ChosenSound()
        local list = SoundList()
        for _, n in ipairs(list) do if n == cfg().miniPingSoundFile then return n end end
        return list[1] or ""                                  -- a saved file that is no longer listed: the first sound
    end

    -- < and > sit on the same line as the "Sound when ping is red" checkbox above, at the right edge
    local rowY = pings.y + CHECK_STEP
    local prevBtn = GT:CreateFlatButton(pings, "<", 28, 20)
    prevBtn:SetPoint("TOPLEFT", 226, rowY)
    local nextBtn = GT:CreateFlatButton(pings, ">", 28, 20)
    nextBtn:SetPoint("TOPLEFT", 258, rowY)

    -- the name sits on the top line of this tab, on the right; it takes no row
    local nameLabel = GT.Font(pings, nil, "OVERLAY", "GameFontDisableSmall")
    nameLabel:SetPoint("TOPRIGHT", pings, "TOPRIGHT", -4, 0)
    nameLabel:SetWidth(120)
    nameLabel:SetJustifyH("RIGHT")
    GT.MakeFitting(nameLabel, 120)
    nameLabel:SetText(ChosenSound())

    local function StepSound(dir)
        if cfg().miniPingSound ~= true then return end  -- the < > buttons do nothing while the option is off
        local list = SoundList()
        local idx = 1
        for i, name in ipairs(list) do
            if name == ChosenSound() then idx = i end
        end
        idx = ((idx - 1 + dir) % #list) + 1
        cfg().miniPingSoundFile = list[idx]
        nameLabel:SetText(list[idx])
        GT.PlayPingSound("Interface\\AddOns\\GatherTimes\\Media\\" .. list[idx])
    end
    prevBtn:SetScript("OnClick", function() StepSound(-1) end)
    nextBtn:SetScript("OnClick", function() StepSound(1) end)

    for _, pair in ipairs({
        { prevBtn, "Previous sound", "Play the previous sound in the list." },
        { nextBtn, "Next sound", "Play the next sound in the list." },
    }) do
        local b, title, text = pair[1], pair[2], pair[3]
        b:HookScript("OnEnter", function(self)
            GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
            GT.Tip:AddLine(GT.TR(title))
            GT.Tip:AddLine(GT.TR(text), 0.85, 0.85, 0.85, true)
            GT.Tip:Show()
        end)
        b:HookScript("OnLeave", function() GT.Tip:Hide() end)
    end

    GT.uiRefresh[#GT.uiRefresh + 1] = function() nameLabel:SetText(ChosenSound()) end
    Depend({ prevBtn, nextBtn, nameLabel }, function() return cfg().miniPingSound == true end)

    Slider(pings, "Repeat every: %s", 1, 60, 1,
        function() return cfg().miniPingDelay or 10 end,
        function(v) cfg().miniPingDelay = v end,
        function(v) return GT.TRF("%d sec", v) end,
        "While a shown ping is red, the sound plays right away and then repeats after this many seconds. Needs Sound when ping is red.",
        function() return cfg().miniPingSound == true end)

    -- the bar is on screen while these settings are open, so every option can be seen as it is changed
    panel:HookScript("OnShow", function()
        ApplyDeps()
        if GT.SetBarPreview then GT:SetBarPreview(true) end
    end)
    panel:HookScript("OnHide", function()
        if GT.SetBarPreview then GT:SetBarPreview(false) end
        if GT.StopPingSound then GT.StopPingSound() end      -- closing the panel stops any sound it started
        if GT.StopMediaSound then GT.StopMediaSound() end
    end)

    ApplyDeps()
    ShowSub("bar")
end
