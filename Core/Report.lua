-- Report.lua : "Copy debug report" (Settings > Tools, or /gt report).
-- One block of plain text with what is needed to tell whether something is a conflict: the addon version, the
-- client build, which libraries and helper addons were found, the other addons that are loaded, a few numbers
-- about the saved data, the HUD state and the error log.  It holds no character name, no realm name and no
-- positions, so it is safe to paste into a bug report.
local addonName, GT = ...

-- Addons that touch the minimap, which is where a HUD / pin conflict usually comes from.  Listed with their state
-- even when they are not installed, so a report that says "not installed" rules them out.
local MINIMAP_ADDONS = { "SexyMap", "Chinchilla", "ElvUI", "Tukui", "BasicMinimap", "MinimapButtonButton",
    "MBB", "Leatrix_Plus", "Questie", "Cartographer", "GatherMate2", "GatherMate2_Data", "TomTom", "HereBeDragons",
    "Routes", "MinimapRange" }

local function Safe(fn, ...)
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end

local function AddOnApi()
    local ns = _G.C_AddOns
    local api = {}
    api.isLoaded = (type(ns) == "table" and ns.IsAddOnLoaded) or _G.IsAddOnLoaded
    api.count    = (type(ns) == "table" and ns.GetNumAddOns) or _G.GetNumAddOns
    api.info     = (type(ns) == "table" and ns.GetAddOnInfo) or _G.GetAddOnInfo
    api.meta     = (type(ns) == "table" and ns.GetAddOnMetadata) or _G.GetAddOnMetadata
    return api
end

-- name of entry i, as a string (newer clients return a table from GetAddOnInfo)
local function InfoName(api, i)
    local a = Safe(api.info, i)
    if type(a) == "table" then return a.name end
    return type(a) == "string" and a or nil
end

local function Section(lines, title, fn)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "== " .. title
    local ok, err = pcall(fn, lines)
    if not ok then lines[#lines + 1] = "(could not read this part: " .. tostring(err):sub(1, 120) .. ")" end
end

function GT.BuildDebugReport()
    local api = AddOnApi()
    local L = { "GatherTimes debug report" }

    Section(L, "Versions", function(out)
        local ver = Safe(api.meta, GT.addonName or "GatherTimes", "Version") or "?"
        local gv, build, bdate, toc = Safe(_G.GetBuildInfo)
        out[#out + 1] = "GatherTimes: " .. tostring(ver)
        out[#out + 1] = string.format("Client: %s (build %s, %s), interface %s", tostring(gv or "?"), tostring(build or "?"),
            tostring(bdate or "?"), tostring(toc or "?"))
        out[#out + 1] = "Client locale: " .. tostring(Safe(_G.GetLocale) or "?") .. ",  addon language: " .. tostring(GT.Lang and GT.Lang() or "?")
        out[#out + 1] = "Hardcore: " .. tostring(GT.IsHardcore and GT.IsHardcore() or false)
        out[#out + 1] = "Saved-data layout: " .. tostring(GatherTimesDB and GatherTimesDB._dbVersion or "?")
    end)

    Section(L, "Libraries", function(out)
        local ls = _G.LibStub
        local function lib(name)
            local obj, minor
            if type(ls) == "table" or type(ls) == "function" then
                obj, minor = Safe(function() return ls:GetLibrary(name, true) end)
            end
            out[#out + 1] = string.format("%s: %s", name, obj and ("found" .. (minor and (" (minor " .. tostring(minor) .. ")") or "")) or "MISSING")
        end
        out[#out + 1] = "LibStub: " .. ((type(ls) == "table" or type(ls) == "function") and "found" or "MISSING")
        lib("CallbackHandler-1.0")
        lib("HereBeDragons-2.0")
        lib("HereBeDragons-Pins-2.0")
        out[#out + 1] = "Used by GatherTimes: distances " .. (GT.HBD and "OK" or "MISSING") .. ", map pins " .. (GT.HBDPins and "OK" or "MISSING")
        local _, late = GT.MissingLibs()
        if #late > 0 then out[#out + 1] = "Loaded after GatherTimes (needs /reload): " .. table.concat(late, ", ") end
    end)

    Section(L, "Helper and minimap addons", function(out)
        local loaded = api.isLoaded
        for _, name in ipairs(MINIMAP_ADDONS) do
            local on = Safe(loaded, name)
            local ver = on and Safe(api.meta, name, "Version")
            if on then out[#out + 1] = name .. ": loaded" .. (ver and (" " .. tostring(ver)) or "") end
        end
        local none = true
        for _, name in ipairs(MINIMAP_ADDONS) do if Safe(loaded, name) then none = false end end
        if none then out[#out + 1] = "(none of them is loaded)" end
        out[#out + 1] = "TomTom global: " .. (_G.TomTom and "found" or "not found")
    end)

    Section(L, "Other loaded addons", function(out)
        local n = tonumber(Safe(api.count)) or 0
        local names, skip = {}, {}
        for _, name in ipairs(MINIMAP_ADDONS) do skip[name] = true end
        skip[GT.addonName or "GatherTimes"] = true
        for i = 1, n do
            local name = InfoName(api, i)
            if name and not skip[name] and Safe(api.isLoaded, name) then names[#names + 1] = name end
        end
        table.sort(names)
        out[#out + 1] = (#names > 0) and (#names .. ": " .. table.concat(names, ", ")) or "(none, or the client does not list them)"
    end)

    Section(L, "Data", function(out)
        local total, imported = 0, 0
        for key in pairs(GT.nodes) do
            for _, sp in ipairs(GT.spawns[key] or {}) do
                total = total + 1
                if sp.imported then imported = imported + 1 end
            end
        end
        local running, ready = 0, 0
        for key in pairs(GT.nodes) do
            for _, node in ipairs(GatherTimesDB[key] or {}) do
                if (node._left or 1) > 0 then running = running + 1 else ready = ready + 1 end
            end
        end
        out[#out + 1] = string.format("Spots: %d (%d imported)   Timers: %d running, %d ready", total, imported, running, ready)
        local q = GT.QuarantinedTimers and GT.QuarantinedTimers()
        if type(q) == "table" then out[#out + 1] = "Timers set aside after an error: " .. tostring(#q) end
        local c = GT.cfg()
        out[#out + 1] = string.format("Settings: detectEmpty=%s groupMode=%s zoneOnly=%s showSpawns=%s tomtom=%s", tostring(c.detectEmpty),
            tostring(c.groupMode), tostring(c.zoneOnly), tostring(c.showSpawns), tostring(c.tomtom))
    end)

    Section(L, "HUD", function(out)
        local HUD = GT.HUD
        if not (HUD and HUD.db) then out[#out + 1] = "(not loaded)"; return end
        local db = HUD.db
        out[#out + 1] = string.format("On: %s   profile: %s   size: %s   zoom: %s   rotate: %s   hideAddons: %s",
            tostring(HUD.IsActive()), tostring(HUD.ProfileCurrent()), tostring(db.size), tostring(db.zoom),
            tostring(db.rotate), tostring(db.hideAddons))
        local mm = _G.Minimap
        if type(mm) == "table" and mm.GetWidth then
            local w, s = Safe(mm.GetWidth, mm), Safe(mm.GetScale, mm)
            out[#out + 1] = string.format("Minimap frame: width %s, scale %s, rotateMinimap CVar %s", tostring(w), tostring(s),
                tostring(Safe(_G.GetCVar, "rotateMinimap")))
        end
    end)

    Section(L, "Errors (newest last)", function(out)
        local log = GT.errLog or {}
        if #log == 0 then out[#out + 1] = "(no errors)"; return end
        for _, line in ipairs(log) do out[#out + 1] = line end
    end)

    return table.concat(L, "\n")
end

-- ============================================================
-- DIALOG
-- ============================================================
local dialog

local function BuildDialog()
    local f = GT:CreateFlatFrame("GatherTimesReport", UIParent, 360, 300)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.header = GT:CreateHeader(f, GT.TR("Debug report"), function() f:Hide() end)

    local hint = GT.Font(f, nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 10, -30)
    hint:SetWidth(340)
    hint:SetJustifyH("LEFT")
    hint:SetText(GT.TR("Click in the text, press Ctrl+A, then Ctrl+C, and paste it into your bug report."))

    local sf = CreateFrame("ScrollFrame", "GatherTimesReportScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, -54)
    sf:SetPoint("BOTTOMRIGHT", -30, 38)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetWidth(318)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self, byUser)
        if byUser and f.text and self:GetText() ~= f.text then      -- read-only: typing puts the report back
            self:SetText(f.text)
            self:HighlightText()
        end
    end)
    sf:SetScrollChild(eb)
    f.edit = eb

    local close = GT:CreateFlatButton(f, "Close", 100, 20)
    close:SetPoint("BOTTOMRIGHT", -10, 10)
    close:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    tinsert(UISpecialFrames, "GatherTimesReport")                    -- ESC closes it
    return f
end

function GT.ShowDebugReport()
    if not dialog then dialog = BuildDialog() end
    dialog.text = GT.BuildDebugReport()
    dialog.edit:SetText(dialog.text)
    dialog:Show()
    dialog.edit:SetFocus()
    dialog.edit:HighlightText()
end
