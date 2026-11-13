-- Core.lua : namespace, layout settings, slash commands
-- NOTE: the global "GatherTimes" is the main frame, so the addon table is exported under another name.
local ADDON, GT = ...
_G.GatherTimesAddon = GT
GT.addonName = ADDON or "GatherTimes"

-- Height of the main frame and all panels
GT.frameHeight = 400

-- The 5 bottom buttons (each opens its own panel)
GT.buttons = { "Timers", "Nodes", "Nav", "Timing", "Settings" }

-- Dropdown in the Nodes panel: filter by node type. filterKinds[i] is what the entry means (nil = everything)
GT.dropdownItems = { "All", "Herbs", "Ore" }
GT.filterKinds   = { nil, "herb", "ore" }

-- Window settings, saved in GatherTimesDB._ui
GT.defaults = { point = "CENTER", x = 0, y = 0, selected = 1, mainItem = "all", scale = 1, barScale = 1, fadeMoving = false, moveAlpha = 0.35, keepVisible = false, skin = "default",
    minimized = false, barDock = true }

function GT:GetFilterKind()
    local ui = GatherTimesDB and GatherTimesDB._ui
    return ui and self.filterKinds[ui.selected or 1]
end

SLASH_GATHERTIMES1 = "/gt"
SLASH_GATHERTIMES2 = "/gathertimes"
SlashCmdList["GATHERTIMES"] = function(msg)
    local arg = (msg or ""):lower():match("^%s*(%S*)") or ""
    if arg == "" then
        if GT.main then GT.main:SetShown(not GT.main:IsShown()) end
    elseif arg == "hud" then
        -- /gt hud <toggle | on | off | config | size 800 | ...>   (full list: /gt hud help)
        if GT.HUD then GT.HUD.Slash((msg or ""):match("^%s*%S+%s*(.*)$") or "") else GT.cprint(GT.TR("HUD module not loaded")) end
    elseif arg == "min" or arg == "minimize" then
        -- /gt min : shrink the window into the info bar, or bring the window back (UI\MiniBar.lua)
        if GT.ToggleMinimized then GT:ToggleMinimized() end
    elseif arg == "dock" then
        -- /gt dock : the minimized bar pushes the game's top frames down (on) or just covers them (off)
        local ui = GatherTimesDB and GatherTimesDB._ui
        if ui then
            ui.barDock = not (ui.barDock ~= false)
            GT.cprint(GT.TR(ui.barDock and "Bar dock ON" or "Bar dock OFF"))
            if GT.BarDock then GT.BarDock.Sync() end
        end
    elseif arg == "xp" then
        -- /gt xp : turn XP mode on or off (the bar shows the XP line).  /gt xp reset | session | goal ... | history  (UI\MiniXP.lua)
        if GT.MiniXP then GT.MiniXP.Slash((msg or ""):match("^%s*%S+%s*(.*)$") or "") end
    elseif arg == "gfx" then
        -- /gt gfx : list the graphics settings the quality slider uses and their values (Core\\Graphics.lua)
        if GT.Gfx then GT.Gfx.Report() end
    elseif arg == "debug" then
        GT.debugLoot = not GT.debugLoot
        GT.cprint(GT.TR(GT.debugLoot and "Loot debug ON" or "Loot debug OFF"))
    elseif arg == "profile" then
        local action = (msg or ""):match("^%s*%S+%s*(%S*)") or ""
        if GT.ProfileTimerLoop then GT.ProfileTimerLoop(action) else GT.cprint("Timer-loop profiler is unavailable.") end
    elseif arg == "export" then
        -- /gt export : a window with your own spots as text to copy and send to a friend (Gathering\Share.lua)
        if GT.ShowExportSpots then GT.ShowExportSpots() end
    elseif arg == "import" then
        -- /gt import : a window to paste a friend's text into.  /gt import <text> imports it straight away.
        local text = (msg or ""):match("^%s*%S+%s*(.*)$") or ""
        if text ~= "" and GT.ImportSpotsReport then GT.ImportSpotsReport(text)
        elseif GT.ShowImportSpots then GT.ShowImportSpots() end
    elseif arg == "report" then
        -- /gt report : the debug report window (Core\Report.lua), also Settings > Tools > Copy debug report
        if GT.ShowDebugReport then GT.ShowDebugReport() end
    elseif arg == "stats" then
        GT.cprint("\n" .. GT.FormatStats())
    elseif arg == "yield" then
        local scope = (msg or ""):match("^%s*%S+%s*(%S*)") or ""
        local mapID = scope == "current" and C_Map and C_Map.GetBestMapForUnit
            and C_Map.GetBestMapForUnit("player") or nil
        GT.cprint("\n" .. GT.FormatZoneYield(mapID))
    elseif arg == "list" then
        local now, shown = GetServerTime(), 0
        for _, key in ipairs(GT.order) do
            local def = GT.nodes[key]
            for _, n in ipairs(GatherTimesDB[key] or {}) do
                local left = def.timer - (now - n.time)
                shown = shown + 1
                GT.cprint(string.format("%s  %s", def.label,
                    left > 0 and string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60)) or GT.TR("READY")))
            end
        end
        if shown == 0 then GT.cprint(GT.TR("no active timers")) end
    else
        GT.cprint(GT.TR("/gt  (window)   /gt list   /gt stats   /gt debug   /gt profile start|report|stop"))
        GT.cprint(GT.TR("/gt yield  (zone loot totals)   /gt yield current  (current zone only)"))
        GT.cprint(GT.TR("/gt hud  (minimap HUD, /gt hud help)"))
        GT.cprint(GT.TR("/gt xp  (XP mode on the minimized bar)   /gt xp reset   /gt xp session"))
        GT.cprint("/gt xp goal level 40   /gt xp goal 500g   /gt xp goal off   /gt xp history")
        GT.cprint(GT.TR("/gt min  (shrink the window to a top bar, or bring it back)   /gt dock  (bar pushes the game frames down: on / off)"))
        GT.cprint(GT.TR("/gt export   /gt import  (share your own spots with a friend)   /gt report  (debug report)"))
    end
end

-- Shortcut for the minimap HUD: /gthud  (same as /gt hud)
SLASH_GATHERTIMESHUD1 = "/gthud"
SlashCmdList["GATHERTIMESHUD"] = function(msg)
    if GT.HUD then GT.HUD.Slash(msg or "") else GT.cprint(GT.TR("HUD module not loaded")) end
end
