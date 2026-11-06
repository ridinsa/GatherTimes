-- PanelMinimize.lua : the "Minimize settings" panel (right-click the "-" button in the main window's title bar).
-- It is a normal side panel (same size, same slot beside the main window, not movable), so Panels.lua already makes
-- sure only one panel is open at a time: opening any other panel / Random Name closes it, and it closes the others.
-- Everything here is about the minimized bar (UI\MiniBar.lua, UI\BarDock.lua).  Sub-tabs (same look as Settings):
--   Bar   : showing the bar, its size and opacity, the gold summary
--   Chips : how the group chips look and which of them are shown, the urgency colours and the blink warning
--   Fade  : fading the bar in combat or when the mouse is away
--   XP    : the "XP" button after the dropdown
local ADDON, GT = ...
GT.panelBuilders = GT.panelBuilders or {}

local BLINK_DEFAULT = 15            -- same default as UI\MiniBar.lua

GT.panelBuilders.Minimize = function(panel, content)
    local cfg = GT.cfg
    local ui = GatherTimesDB._ui
    local subs, tabs = {}, {}

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

    local function AddSub(id, text, x)
        local b = GT:CreateFlatButton(content, text, 68, 20)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetScript("OnClick", function() ShowSub(id) end)
        tabs[id] = b
        local f = CreateFrame("Frame", nil, content)
        f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -30)
        f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
        f:Hide()
        subs[id] = f
        return f
    end

    local bar   = AddSub("bar",   "Bar",   0)
    local chips = AddSub("chips", "Chips", 70)
    local fade  = AddSub("fade",  "Fade",  140)
    local xp    = AddSub("xp",    "XP",    210)

    local function Check(parent, y, text, get, set, description)
        local cb = GT:CreateCheckLabel(parent, text, get, set)
        cb:SetPoint("TOPLEFT", 2, y)
        AddOptionTip(cb, text, description)
        return cb
    end
    local function Slider(parent, y, label, lo, hi, step, get, set, fmt, description)
        local s = GT:CreateSlider(parent, 288, label, lo, hi, step, get, set, fmt)
        s:SetPoint("TOPLEFT", 0, y)
        AddOptionTip(s.slider, label:gsub(": %%s.*$", ""), description)
        GT.uiRefresh[#GT.uiRefresh + 1] = function() s:Refresh() end
        return s
    end

    ---------------------------------------------------------------- Bar
    -- showing the bar: on = once the addon is opened, the bar stays on screen; off = only from the "-" button.
    Check(bar, 0, "Always show minimized panel",
        function() return cfg().miniAlwaysShow == true end,
        function(v)
            cfg().miniAlwaysShow = v
            GT:ApplyAlwaysBar()
        end,
        "On: after you open the addon (minimap button or /gt), the minimized bar stays on screen: while the main window and the other windows are open, and after you close them. Nothing is shown after a reload until you open the addon. Off: the bar appears only when you click the \"-\" button in the main window.")

    Slider(bar, -26, "Bar size: %s", 60, 150, 5,
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
    Slider(bar, -64, "Bar opacity: %s", 0, 100, 5,
        function() return cfg().miniBgAlpha or 95 end,
        function(v)
            cfg().miniBgAlpha = v
            if GT.bar then GT:ApplyBarBackground() end
        end,
        function(v) return v .. "%" end,
        "How solid the background of the minimized bar is. Lower it to see the game through the bar. The text stays fully readable.")

    Check(bar, -102, "Minimized summary: show all items",
        function() return cfg().miniSummaryAll ~= false end,
        function(v) cfg().miniSummaryAll = v end,
        "On: the gold tooltip of the minimized bar lists every item. Off: it lists only the items ticked in the Nodes panel. The gold value always counts everything you loot.")

    ---------------------------------------------------------------- Chips
    Check(chips, 0, "Compact chips",
        function() return cfg().miniCompact == true end,
        function(v)
            cfg().miniCompact = v
            if GT.bar then GT:UpdateMiniBar() end
        end,
        "On: each chip on the minimized bar shows only the coloured edge, the short group label (G2) and the timer, so many more chips fit before \"+N more\". The colour tells you which item it is. Off: the full group name.")

    Check(chips, -26, "Sort chips by urgency",
        function() return cfg().miniSortUrgency ~= false end,
        function(v)
            cfg().miniSortUrgency = v
            if GT.bar then GT:UpdateMiniBar() end
        end,
        "On: the chips on the minimized bar are sorted by soonest ready (READY first, then the shortest timer), so the most useful chips are always visible instead of hiding behind \"+N more\". Off: the chips follow the table's order.")

    Check(chips, -52, "Hide idle groups",
        function() return cfg().miniHideIdle == true end,
        function(v)
            cfg().miniHideIdle = v
            if GT.bar then GT:UpdateMiniBar() end
        end,
        "On: the minimized bar shows only groups that are running or ready. Groups with no timer (Idle) are left out. Off: every known group is shown.")

    Check(chips, -78, "Urgency colors",
        function() return cfg().miniUrgencyColors ~= false end,
        function(v)
            cfg().miniUrgencyColors = v
            if GT.bar then GT:UpdateMiniBar() end
        end,
        "On: the progress bar under a waiting chip is white, turns yellow at 60 seconds and red at 15 seconds. Off: it keeps the status colour.")

    -- blink warning: a chip pulses when its timer is at or below this many seconds
    Slider(chips, -104, "Blink warning: %s", 0, 30, 1,
        function() return cfg().miniBlinkSecs or BLINK_DEFAULT end,
        function(v)
            cfg().miniBlinkSecs = v
            if GT.bar then GT:UpdateMiniBar() end
        end,
        function(v) return v == 0 and GT.TR("Off") or GT.TRF("%d sec", v) end,
        "A group on the minimized bar blinks when its timer is at or below this many seconds. 0 turns the blinking off.")

    ---------------------------------------------------------------- Fade
    Check(fade, 0, "Fade in combat",
        function() return cfg().miniFadeCombat == true end,
        function(v)
            cfg().miniFadeCombat = v
            if GT.bar then GT:ApplyBarFade() end
        end,
        "On: the minimized bar fades while you are in combat. Hover the mouse over it to see it fully.")

    Check(fade, -26, "Fade when mouse is away",
        function() return cfg().miniFadeMouse == true end,
        function(v)
            cfg().miniFadeMouse = v
            if GT.bar then GT:ApplyBarFade() end
        end,
        "On: the minimized bar fades whenever the mouse is not over it, and comes back when you move the mouse onto it.")

    Slider(fade, -52, "Faded opacity: %s", 0, 100, 5,
        function() return cfg().miniFadeAlpha or 30 end,
        function(v)
            cfg().miniFadeAlpha = v
            if GT.bar then GT:ApplyBarFade() end
        end,
        function(v) return v .. "%" end,
        "How visible the whole bar is while it is faded (see the two fade options above). Only used when one of them is on.")

    ---------------------------------------------------------------- XP
    Check(xp, 0, "Show XP button",
        function() return cfg().miniShowXP ~= false end,
        function(v)
            cfg().miniShowXP = v
            if not v and GT.MiniXP then GT.MiniXP.SetOn(false) end   -- hiding it also turns XP mode off
            if GT.bar then GT:UpdateMiniBar() end
        end,
        "On: the XP button sits right after the dropdown on the minimized bar. Click it to show the hero and pet XP information in one line instead of the gathering timers. Off: the button is hidden and XP mode is off.")

    ShowSub("bar")
end
