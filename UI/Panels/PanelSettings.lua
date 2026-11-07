-- PanelSettings.lua : the "Settings" panel (sub-tabs: General / Display / Tools / Look)
local ADDON, GT = ...
GT.panelBuilders = GT.panelBuilders or {}

local function ZoneName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name
end

local function Confirm(btn, text, fn) GT:SetConfirmClick(btn, text, fn) end

GT.panelBuilders.Settings = function(panel, content)
    local cfg = GT.cfg
    local ui = GatherTimesDB._ui
    local subs, tabs, active = {}, {}, "general"
    local refreshTools = function() end

    local function ShowSub(id)
        active = id
        for sid, f in pairs(subs) do f:SetShown(sid == id) end
        for sid, b in pairs(tabs) do GT:SetButtonActive(b, sid == id) end
        if id == "tools" then refreshTools() end
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
    local general = AddSub("general", "General", 0)
    local display = AddSub("display", "Display", 70)
    local look    = AddSub("look",    "Look",    140)
    local tools   = AddSub("tools",   "Tools",   210)

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
    local function Button(parent, text, w, x, y)
        local b = GT:CreateFlatButton(parent, text, w, 20)
        b:SetPoint("TOPLEFT", x, y)
        return b
    end

    ----------------------------------------------------------------- General
    -- alerts, then the Hardcore health warning, then the timers (in that order, so each group is together)
    -- turning it on shows a sample alert right away (same idea as the maintenance preview)
    Check(general, 0, "On-screen alert when ready",
        function() return cfg().screenAlert end,
        function(v)
            cfg().screenAlert = v
            if v then GT.FireReadyAlert("dreamfoil", GT.nodes.dreamfoil, { _dist = 42 }, true) end
        end,
        "Show an on-screen alert when a resource respawn timer finishes. Turning it on shows a sample alert.")
    Slider(general, -22, "Alert time: %s", 2, 10, 1,
        function() return cfg().alertTime end, function(v) cfg().alertTime = v end,
        function(v) return GT.TRF("%d sec", v) end,
        "Choose how long on-screen alerts remain visible.")
    local alertRangeSlider, alertMinRangeSlider
    alertRangeSlider = Slider(general, -58, "Alert range: %s", 0, 500, 25,
        function() return cfg().alertRange end, function(v)
            cfg().alertRange = v
            if v > 0 and cfg().alertMinRange > v then
                cfg().alertMinRange = v
                if alertMinRangeSlider then alertMinRangeSlider:Refresh() end
            end
        end,
        function(v) return v == 0 and GT.TR("any distance") or GT.TRF("%d yd", v) end,
        "Maximum distance from a node for its ready alert. Zero allows any distance.")
    alertMinRangeSlider = Slider(general, -94, "Minimum alert distance: %s", 0, 500, 25,
        function() return cfg().alertMinRange end, function(v)
            cfg().alertMinRange = v
            if v > 0 and cfg().alertRange > 0 and cfg().alertRange < v then
                cfg().alertRange = v
                if alertRangeSlider then alertRangeSlider:Refresh() end
            end
        end,
        function(v) return v == 0 and GT.TR("off") or GT.TRF("%d yd", v) end,
        "Ignore ready alerts for nodes closer than this distance. Zero disables the minimum.")

    -- server maintenance alert (Alerts.lua): same flat checkbox, colour slider 1..7, preview plays by itself
    local previewToken = 0
    local function AutoPreview()           -- debounced: one flash shortly after the last change
        previewToken = previewToken + 1
        local mine = previewToken
        C_Timer.After(0.35, function()
            if mine == previewToken and GT.PreviewMaintenanceAlert then GT.PreviewMaintenanceAlert() end
        end)
    end
    Check(general, -130, "Alert when chat announces maintenance",
        function() return cfg().maintAlert end,
        function(v)
            cfg().maintAlert = v
            if v then AutoPreview() end    -- turning it on shows the alert right away
        end,
        "Show a visual warning when a game chat message announces server maintenance.")
    Slider(general, -152, "Maintenance flash colour: %s", 1, 7, 1,
        function() return cfg().maintColorIdx end,
        function(v)
            cfg().maintColorIdx = v
            if cfg().maintAlert then AutoPreview() end
        end,
        function(v)
            local c = GT.MAINT_COLORS and GT.MAINT_COLORS[v]
            if not c then return tostring(v) end
            local function hex(x) return math.floor(x * 255 + 0.5) end
            return string.format("%d |cff%02x%02x%02x%s|r", v, hex(c[1]), hex(c[2]), hex(c[3]), GT.TR(c.name))
        end,
        "Choose the flash color used by the maintenance warning.")
    Check(general, -188, "Low health warning (Hardcore)",
        function() return cfg().lowHP end, function(v) cfg().lowHP = v end,
        "Show a warning when your health drops below the selected threshold on Hardcore characters.")
    Slider(general, -210, "Warn below: %s", 10, 80, 5,
        function() return cfg().lowHPPct end, function(v) cfg().lowHPPct = v end,
        function(v) return v .. "% HP" end,
        "Set the health percentage that triggers the Hardcore low-health warning.")

    Check(general, -246, "Only show timers and pins of the zone I am in",
        function() return cfg().zoneOnly end,
        function(v) cfg().zoneOnly = v; GT.RefreshTimers() end,
        "Hide timers and map pins for resources outside your current zone. The Timing panel follows this too.")
    Slider(general, -268, "Ready status lasts: %s", 30, 1800, 30,
        function() return cfg().readyLinger end,
        function(v) cfg().readyLinger = v; GT.RefreshTimers() end,
        function(v)
            if v < 60 then return GT.TRF("%d sec", v) end
            return (v % 60 == 0) and GT.TRF("%d min", math.floor(v / 60)) or GT.TRF("%d min %d sec", math.floor(v / 60), v % 60)
        end,
        "Choose how long a timer stays marked READY before it returns to idle.")

    ----------------------------------------------------------------- Display
    -- ONE size for all node text: running timers AND spot pins, on the minimap AND the world map
    Slider(display, 0, "Map text size (all nodes, minimap + world map): %s", 8, 24, 1,
        function() return cfg().fontMini end,
        function(v) cfg().fontMini = v; cfg().fontWorld = v; GT.RestyleAll() end,
        nil, "Set the text size for node labels on both the minimap and world map.")
    -- The slider lives INSIDE the window it resizes, so rescaling while dragging makes it jump under
    -- the cursor. The caption follows the drag; the window is rescaled when the mouse is released.
    local sizeSlider = Slider(display, -36, "Window size: %s", 60, 120, 5,
        function() return math.floor((ui.scale or 1) * 100 + 0.5) end,
        function(v) ui.scale = v / 100 end,
        function(v) return v .. "%" end,
        "Resize the GatherTimes window.")
    sizeSlider.slider:HookScript("OnMouseUp", function() GT:SetWindowScale(ui.scale) end)
    Check(display, -72, "See-through while moving",
        function() return ui.fadeMoving end, function(v) ui.fadeMoving = v end,
        "Make the window semi-transparent while you drag it; it becomes solid when you hover over it.")
    Slider(display, -94, "Window visibility while moving: %s", 10, 90, 5,
        function() return math.floor((ui.moveAlpha or 0.35) * 100 + 0.5) end,
        function(v) ui.moveAlpha = v / 100 end,
        function(v) return v .. "%" end,
        "Set the window opacity while moving when see-through mode is enabled.")
    Check(display, -130, "Keep windows visible",
        function() return ui.keepVisible == true end,
        function(v)
            ui.keepVisible = v
            GT:ApplyKeepVisible()          -- off = ESC closes the window again
        end,
        "Keep the GatherTimes window open when pressing Escape.")
    Check(display, -152, "Item tooltip on hover",
        function() return cfg().nodeTips end,
        function(v)
            cfg().nodeTips = v
            if not v then GT.HideItemTooltip() end
            if GT.RefreshMenuMouse then GT.RefreshMenuMouse() end   -- world-map frames only take the mouse when needed
        end,
        "When enabled, hovering a resource name shows its full item details. Turn it off to show only the name and required gathering skill.")

    -- Performance (Core\Graphics.lua): everything here is a console variable, so it also lives on after the addon is off
    local gfx = GT.Gfx
    -- Changing graphics reloads textures and terrain, which stalls a slow PC. So the caption follows the drag and the
    -- level is applied when the mouse is released (or half a second after the last change), once, not at every step.
    local pendingGfx, gfxToken = nil, 0
    local function ApplyGfx()
        if pendingGfx ~= nil and pendingGfx ~= gfx.GetLevel() then gfx.SetLevel(pendingGfx) end
        pendingGfx = nil
    end
    local gfxSlider = Slider(display, -170, "Graphics quality: %s", 0, 3, 1,
        function() return gfx.GetLevel() end,
        function(v)
            pendingGfx = v
            gfxToken = gfxToken + 1
            local mine = gfxToken
            C_Timer.After(0.5, function()
                if mine == gfxToken and not IsMouseButtonDown("LeftButton") then ApplyGfx() end
            end)
        end,
        function(v) return GT.TR(gfx.LEVEL_NAMES[v] or tostring(v)) end,
        "Lowers view distance, particles, ground clutter, shadows, water and sky detail for a slow PC. Off puts your own settings back. Some changes only fully apply after /console gxrestart.")
    gfxSlider.slider:HookScript("OnMouseUp", ApplyGfx)
    Check(display, -206, "Screen effects (death, invisibility)",
        function() return gfx.GetScreenFx() end, function(v) gfx.SetScreenFx(v) end,
        "Untick to turn off the ghost screen effect and the edge effect of invisibility.")
    Slider(display, -230, "Weather density: %s", 0, 3, 1,
        function() return gfx.GetWeather() end,
        function(v) gfx.SetWeather(v) end,
        function(v) return GT.TR(({ [0] = "off", "Low", "Medium", "High" })[v] or tostring(v)) end,
        "How much rain, snow and dust is drawn. Off removes it.")
    Slider(display, -264, "Max camera zoom: %s", 10, 40, 1,
        function() return gfx.GetZoom() end,
        function(v) gfx.SetZoom(v) end,
        function(v) return string.format("%.1fx", v / 10) end,
        "How far the camera can zoom out. 1.0x is the Classic default; the game never zooms past 50 yards.")

    --------------------------------------------------------------------- Look
    local lookOffset = -20
    local langLabel = GT.Font(look, nil, "OVERLAY", "GameFontHighlightSmall")
    langLabel:SetPoint("TOPLEFT", 2, lookOffset)
    GT.MakeFitting(langLabel, 64)
    langLabel:SetText(GT.TR("Language:"))
    local langNames, langIndex = {}, 1
    for i, l in ipairs(GT.LANGS) do
        langNames[i] = l[2]
        if l[1] == (cfg().lang or "enUS") then langIndex = i end
    end
    local langDD = GT:CreateDropdown(look, 190, 18, langNames, function(index)
        local code = GT.LANGS[index][1]
        if cfg().lang == code then return end
        cfg().lang = code
        ReloadUI()
    end, 6)
    langDD:SetPoint("TOPLEFT", 70, 2 + lookOffset)
    langDD:SetSelected(langIndex)
    AddOptionTip(langDD, "Language", "Change GatherTimes' interface language. The UI reloads to apply the change.")
    langDD.list:ClearAllPoints()
    langDD.list:SetPoint("TOPLEFT", langDD, "BOTTOMLEFT", 0, -3)
    look:HookScript("OnHide", function() langDD.list:Hide() end)

    local langNote = GT.Font(look, nil, "OVERLAY", "GameFontDisableSmall")
    langNote:SetPoint("TOPLEFT", 2, -28 + lookOffset)
    GT.MakeFitting(langNote, 280)
    langNote:SetText(GT.TR("Changing the interface language reloads the UI."))

    local skinLabel = GT.Font(look, nil, "OVERLAY", "GameFontHighlightSmall")
    skinLabel:SetPoint("TOPLEFT", 2, -62 + lookOffset)
    GT.MakeFitting(skinLabel, 64)
    skinLabel:SetText(GT.TR("Frame skin:"))
    local skinNames = {}
    for i, skin in ipairs(GT.SKINS) do skinNames[i] = skin.name end
    local skinDD = GT:CreateDropdown(look, 190, 18, skinNames, function(index)
        ui.skin = GT.ApplySkin(GT.SKINS[index].key)
    end, 4)
    skinDD:SetPoint("TOPLEFT", 70, -60 + lookOffset)
    skinDD:SetSelected(GT.SkinIndex(ui.skin))
    AddOptionTip(skinDD, "Frame skin", "Choose the color theme used by GatherTimes windows and themed tooltips.")
    skinDD.list:ClearAllPoints()
    skinDD.list:SetPoint("TOPLEFT", skinDD, "BOTTOMLEFT", 0, -1)
    look:HookScript("OnHide", function() skinDD.list:Hide() end)

    -- font style and size. Languages that need their own font (Korean, Chinese, Japanese, Russian) keep it.
    local fontLabel = GT.Font(look, nil, "OVERLAY", "GameFontHighlightSmall")
    fontLabel:SetPoint("TOPLEFT", 2, -98 + lookOffset)
    GT.MakeFitting(fontLabel, 64)
    fontLabel:SetText(GT.TR("Font:"))
    GT.DropUnavailableFonts()
    local fontNames = {}
    for i, f in ipairs(GT.FONT_CHOICES) do fontNames[i] = f.name end
    local langFont = GT.LangFontFile() ~= nil
    local fontDD = GT:CreateDropdown(look, 190, 18, fontNames, function(index)
        if langFont then return end
        cfg().font = GT.FONT_CHOICES[index].key
        GT.RestyleFonts()
        GT.RestyleAll()
    end, 4)
    fontDD:SetPoint("TOPLEFT", 70, -96 + lookOffset)
    fontDD:SetSelected(GT.FontChoiceIndex(cfg().font))
    fontDD:SetEnabled(not langFont)
    AddOptionTip(fontDD, "Font", "Choose the font used for GatherTimes text.")
    fontDD.list:ClearAllPoints()
    fontDD.list:SetPoint("TOPLEFT", fontDD, "BOTTOMLEFT", 0, -1)
    look:HookScript("OnHide", function() fontDD.list:Hide() end)

    if langFont then
        local fixed = GT.Font(look, nil, "OVERLAY", "GameFontDisableSmall")
        fixed:SetPoint("TOPLEFT", 2, -116 + lookOffset)
        GT.MakeFitting(fixed, 280)
        fixed:SetText(GT.TR("Font style is fixed for this language."))
    end

    Slider(look, -134 + lookOffset, "Font size: %s", 80, 130, 5,
        function() return cfg().fontScale or 100 end,
        function(v)
            cfg().fontScale = v
            GT.RestyleFonts()
            GT.RestyleAll()
        end,
        function(v) return v .. "%" end,
        "Scale the text of the GatherTimes windows. Map and minimap text has its own size (Display tab).")

    ------------------------------------------------------------------- Tools
    local status = GT.Font(tools, nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 2, 0)
    status:SetWidth(284)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")
    status:SetWordWrap(true)

    local imp = Button(tools, "Import GatherMate2", 138, 0, -140)
    imp:SetScript("OnClick", function() GT.ImportGatherMate2("") end)
    local clr = Button(tools, "Clear learned spawns", 138, 150, -140)
    Confirm(clr, "Clear learned spawns", function()
        GT.ClearSpawns()
        GT.cprint(GT.TR("Learned spawn points cleared."))
        refreshTools()
    end)

    -- share your own spots with friends as text (Gathering\Share.lua; also /gt export, /gt import)
    local exp = Button(tools, "Export my spots", 138, 0, -164)
    exp:SetScript("OnClick", function() GT.ShowExportSpots() end)
    local shr = Button(tools, "Import spots", 138, 150, -164)
    shr:SetScript("OnClick", function() GT.ShowImportSpots() end)

    -- Random Name is opened from the main Settings button's right-click action.
    -- Keep Tools focused on its existing maintenance actions.
    local rep = Button(tools, "Copy debug report", 138, 150, -188)
    rep:SetScript("OnClick", function() GT.ShowDebugReport() end)

    -- reset all timer data (the settings stay); moved here from General, it is a maintenance action
    local resetTimers = Button(tools, "Reset timers", 138, 0, -188)
    Confirm(resetTimers, "Reset timers", function()
        for key in pairs(GT.nodes) do
            local list = GatherTimesDB[key]
            for _, n in ipairs(list) do pcall(GT.RemoveTextTimer, n) end
            wipe(list)
        end
        GT.UpdateList()
        GT.cprint(GT.TR("Timer data wiped (your settings are kept)."))
    end)

    -- whether a login / reload starts a new session (moved here from General; Reset session is on the Timers panel)
    Check(tools, -212, "Start a new session at login",
        function() return cfg().newSessionOnLogin end, function(v) cfg().newSessionOnLogin = v end,
        "Off: a reload or new login continues the session you were in. On: every login starts a fresh session. Reset session (Timers panel) always starts a new one.")

    -- one block with versions, libraries, addons and the error log, to paste into a bug report (Core\Report.lua)

    local logCap = GT.Font(tools, nil, "OVERLAY", "GameFontDisableSmall")
    logCap:SetPoint("TOPLEFT", 2, -240)
    GT.MakeFitting(logCap, 284)
    logCap:SetText(GT.TR("Error log (click, Ctrl+A, Ctrl+C to copy)"))

    local log = GT:CreateEditBox(tools, 288, 74)
    log:SetPoint("TOPLEFT", 0, -256)
    log:SetMultiLine(true)
    log:SetJustifyH("LEFT")
    log:SetTextInsets(4, 4, 4, 4)
    local function logText()
        local lines = {}
        for i = math.max(1, #GT.errLog - 4), #GT.errLog do lines[#lines + 1] = GT.errLog[i]:sub(1, 90) end
        return #lines > 0 and table.concat(lines, "\n") or GT.TR("(no errors)")
    end
    log:SetScript("OnTextChanged", function(self, byUser)
        if byUser then self:SetText(logText()) end   -- read-only
    end)

    local function StatusLines()
        local L = {}
        local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local ver = get and get(GT.addonName or "GatherTimes", "Version") or "?"
        L[#L + 1] = GT.TRF("GatherTimes v%s   (loaded %d times)", ver, cfg().sessions or 0)
        L[#L + 1] = GT.TRF("Map pins: %s   Distance lib: %s",
            GT.HBDPins and "OK" or GT.TR("MISSING"), GT.HBD and "OK" or GT.TR("MISSING"))
        local ace = LibStub and LibStub("AceAddon-3.0", true)
        L[#L + 1] = "GatherMate2: " .. GT.TR((ace and ace:GetAddon("GatherMate2", true)) and "found" or "not found")
        L[#L + 1] = "TomTom: " .. GT.TR(TomTom and "found" or "not found")

        local total, imported = 0, 0
        for k in pairs(GT.nodes) do
            for _, sp in ipairs(GT.spawns[k]) do
                total = total + 1
                if sp.imported then imported = imported + 1 end
            end
        end
        L[#L + 1] = GT.TRF("Spawn points: %d (%d imported)", total, imported)

        local running, ready = 0, 0
        for k in pairs(GT.nodes) do
            for _, n in ipairs(GatherTimesDB[k]) do
                if (n._left or 1) > 0 then running = running + 1 else ready = ready + 1 end
            end
        end
        L[#L + 1] = GT.TRF("Timers: %d running, %d ready", running, ready)

        local mapID = C_Map.GetBestMapForUnit("player")
        L[#L + 1] = GT.TR("This zone:") .. " " .. (mapID and (ZoneName(mapID) or ("map " .. mapID)) or GT.TR("unknown"))
        local shown, extra = 0, 0
        if mapID then
            for _, k in ipairs(GT.order) do
                local res = GT.ComputeGroups(k, mapID)
                if #res.groups > 0 then
                    shown = shown + 1
                    if shown <= 3 then
                        local n = 0
                        for _, g in ipairs(res.groups) do n = n + #g end
                        L[#L + 1] = GT.TRF("  %s: %d spots, %d groups", GT.nodes[k].label, n, #res.groups)
                    else
                        extra = extra + 1
                    end
                end
            end
        end
        if extra > 0 then L[#L + 1] = GT.TRF("  ... and %d more", extra) end
        if shown == 0 then L[#L + 1] = GT.TR("  no learned spots here yet") end
        return L
    end

    refreshTools = function()
        status:SetText(table.concat(StatusLines(), "\n"))
        if not log:HasFocus() then log:SetText(logText()) end
    end

    ----------------------------------------------------------------- wiring
    panel:SetScript("OnShow", function() ShowSub(active) end)
    local t = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        if t >= 1 then
            t = 0
            if active == "tools" then pcall(refreshTools) end
        end
    end)
    ShowSub("general")
end
