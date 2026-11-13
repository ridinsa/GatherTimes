-- HUDSlash.lua : the /gthud commands (called by Core.lua through HUD.Slash) and the status / info output.
-- Part of the HUD module (see HUD.lua for the file layout).
local _, GT = ...
local HUD = GT.HUD
local Print, Clamp, Round = HUD.Print, HUD.Clamp, HUD.Round

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function PrintHelp()
    Print("|cffffff00HUD commands|r (/gthud or /gt hud)")
    Print("/gthud [toggle | on | off]   /gthud config")
    Print("/gthud size <150-1400> | alpha <0-1> | zoom <0-5> | rotate")
    Print("/gthud ringunit px | yd | ring <radius in that unit, 0=off> | ring2 <radius> | ringcolor <r> <g> <b> <a> | ringcolor2 <r> <g> <b> <a> | ringthick <1-10> | ringseg <8-256>")
    Print("/gthud dirs | heading | arrow | hover | tracking | trackmode auto/own/stock | tracksize <20-80> | trackpos <x> <y> | addons | scan | mountfade | autogather | restore")
    Print("/gthud eagle [on | off] | preview | size <150-1400> | zoom <0-5> | alpha <0-1> | rotate | scale | nearest | hover   (map shown during Eagle Eye / Far Sight / Mind Vision)")
    Print("/gthud perf [full | balanced | lowest]   (performance level; /gthud lowspec = lowest)")
    Print("/gthud profile [name | delete <name>]   /gthud status | info | frames | skins [hide N | show N | mark | diff] | debug | reset")
end

local function OnOff(b) return b and "on" or "off" end

local function Status()
    local db = HUD.db
    Print(string.format("profile |cffffff00%s|r  HUD %s  size %d  alpha %.1f  zoom %d",
        HUD.ProfileCurrent(), OnOff(HUD.IsActive()), db.size, db.alpha, db.zoom))
    Print(string.format("ring %d  ring2 %d  thick %d  seg %d  rotate %s  dirs %s  heading %s  arrow %s",
        db.ring, db.ring2, db.ringThickness, db.ringSegments, OnOff(db.rotate), OnOff(db.dirs),
        OnOff(db.heading), OnOff(db.arrow)))
    Print(string.format("tracking %s (offset %d,%d)  hide addons %s  deep scan %s  mount fade %s  auto gather %s  restore on login %s",
        OnOff(db.tracking), db.trackingX, db.trackingY, OnOff(db.hideAddons), OnOff(HUD.root.deepScan),
        OnOff(db.mountFade), OnOff(db.autoGather), OnOff(HUD.root.restoreOnLogin)))
    Print("performance level " .. HUD.PERF_LEVELS[HUD.PerfLevel()] .. "  suggest on low FPS " .. OnOff(HUD.root.perfSuggest))
end

local function Info()
    local m = Minimap
    Print(string.format("Minimap %.0fx%.0f scale %.2f alpha %.2f zoom %s strata %s lvl %d shown %s",
        m:GetWidth(), m:GetHeight(), m:GetScale(), m:GetAlpha(), tostring(m:GetZoom()),
        m:GetFrameStrata(), m:GetFrameLevel(), tostring(m:IsShown())))
    local parent = m:GetParent()
    Print("parent=" .. tostring(parent and parent:GetName()) .. " rotateMinimap=" .. tostring(GetCVar("rotateMinimap"))
        .. " facing=" .. tostring(GetPlayerFacing and GetPlayerFacing()))
    local skins = HUD.LoadedSkinAddons()
    Print("GatherMate2=" .. tostring(HUD.IsAddonLoadedByName("GatherMate2")) .. " TomTom=" .. tostring(HUD.IsAddonLoadedByName("TomTom"))
        .. "  minimap addons: " .. (#skins > 0 and table.concat(skins, ", ") or "none")
        .. "  deep scan " .. OnOff(HUD.root.deepScan))
    Print("HUD tracking button (" .. OnOff(HUD.db.tracking) .. "): " .. HUD.Tracking.Describe())
    if HUD.Tracking.DebugRaw then HUD.Tracking.DebugRaw() end
    for _, f in ipairs(HUD.StockTrackingFrames()) do
        local p = f:GetParent()
        Print(string.format("  stock %s: shown=%s visible=%s alpha=%.2f effective=%.2f parent=%s (hidden while the HUD is up)",
            tostring(f:GetName() or "<anon>"), tostring(f:IsShown()), tostring(f:IsVisible()), f:GetAlpha(),
            f.GetEffectiveAlpha and f:GetEffectiveAlpha() or -1, tostring(p and p:GetName())))
        local q, chain = p, {}
        while q and #chain < 6 do
            chain[#chain + 1] = string.format("%s(%.2f)", tostring(q.GetName and q:GetName() or "<anon>"), q.GetAlpha and q:GetAlpha() or -1)
            q = q.GetParent and q:GetParent() or nil
        end
        Print("    parent chain: " .. table.concat(chain, " > "))
        local parts = {}
        for _, c in ipairs({ f:GetChildren() }) do
            parts[#parts + 1] = string.format("%s(%.2f%s)", tostring(c.GetName and c:GetName() or "<child>"), c:GetAlpha(), c:IsShown() and "" or ",hidden")
        end
        for _, r in ipairs({ f:GetRegions() }) do
            parts[#parts + 1] = string.format("%s(%.2f%s)", tostring(r.GetName and r:GetName() or "<region>"), r:GetAlpha(), r:IsShown() and "" or ",hidden")
        end
        Print("    contents: " .. (#parts > 0 and table.concat(parts, " ") or "none"))
    end
    local ok, hbd = pcall(LibStub, "HereBeDragons-Pins-2.0", true)
    if ok and hbd then
        Print("HBD-Pins: rotate=" .. tostring(hbd.rotateMinimap) .. " indoors=" .. tostring(hbd.indoors)
            .. " shape=" .. tostring(hbd.minimapShape))
    else
        Print("HBD-Pins-2.0 not found")
    end
end

local function ListFrames()
    local i = 0
    for _, ch in ipairs({ Minimap:GetChildren() }) do
        i = i + 1
        if i <= 40 then
            Print(string.format("child %d: %s %.0fx%.0f pts=%d shown=%s hidden=%s", i, tostring(ch:GetName() or "<anon>"),
                ch:GetWidth(), ch:GetHeight(), ch:GetNumPoints(), tostring(ch:IsShown()), tostring(HUD.IsHiddenByHud(ch))))
        end
    end
    Print("Minimap children total: " .. i)
end

-- /gthud skins : what is drawn on or around the Minimap, to find the piece that draws a stray arc.
--   /gthud skins            numbered list of everything visible (and everything the HUD hid)
--   /gthud skins hide <n>   hide item n for now, to see if it is the culprit (/gthud skins show <n> or /reload undoes it)
--   /gthud skins mark       remember how everything looks right now (do this while the arc is NOT showing)
--   /gthud skins diff       list what is new or changed since the mark (do this while the arc IS showing)
local skinList = {}
local skinMark                          -- [object] = { key, info }, saved by /gthud skins mark

-- Some frames refuse method calls from addons ("calling 'GetName' on bad self"). Every call that touches an
-- arbitrary frame goes through pcall, so one such frame is skipped instead of ending the scan.
local function SafeName(obj)
    local ok, n = pcall(obj.GetName, obj)
    if ok and type(n) == "string" then return n end
    return nil
end

local function IsPin(obj)
    local n = SafeName(obj)
    return (n and (n:find("^GatherMatePin") or n:find("^HBD") or n:find("Pin%d+$"))) and true or false
end

local function AnchoredToMinimap(f)
    local ok, num = pcall(f.GetNumPoints, f)
    if not (ok and num) then return false end
    for i = 1, num do
        local ok2, _, rel = pcall(f.GetPoint, f, i)
        if ok2 and rel == Minimap then return true end
    end
    return false
end

-- Calls userFn(obj, where) for every texture, text and frame that can draw on or around the Minimap: its own
-- regions, its child frames (with their regions and sub-frames), other frames anchored to it, and the HUD's own
-- overlay. Map pins (GatherMate, HereBeDragons) are skipped, there can be hundreds.
local walkSkipped, walkFirstError = 0, nil
local function WalkSkins(userFn)
    local seen = {}
    walkSkipped, walkFirstError = 0, nil
    local function try(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then walkSkipped = walkSkipped + 1; walkFirstError = walkFirstError or tostring(err) end
    end
    local function fn(obj, where) try(userFn, obj, where) end

    local visit
    local function visitInner(f, where, depth)
        if seen[f] or f == Minimap or IsPin(f) then return end
        seen[f] = true
        fn(f, where)
        local label = "   in " .. (SafeName(f) or "<anon>")
        if f.GetRegions then
            for _, r in ipairs({ f:GetRegions() }) do fn(r, label) end
        end
        if depth < 3 and f.GetChildren then
            for _, c in ipairs({ f:GetChildren() }) do visit(c, label, depth + 1) end
        end
    end
    visit = function(f, where, depth) try(visitInner, f, where, depth) end

    try(function()
        for _, r in ipairs({ Minimap:GetRegions() }) do fn(r, "Minimap.region") end
    end)
    try(function()
        for _, c in ipairs({ Minimap:GetChildren() }) do
            try(function()
                local tiny = (c:GetWidth() or 0) < 40 and not SafeName(c) and not HUD.IsHiddenByHud(c)
                if not tiny then visit(c, "Minimap.child", 1) end     -- tiny anonymous frames are map pins
            end)
        end
    end)
    try(function()
        for _, c in ipairs({ UIParent:GetChildren() }) do
            try(function()
                local n = SafeName(c) or ""
                if AnchoredToMinimap(c) or n:find("Sexy") or n:find("Minimap") or n == "GatherTimesHUDOverlay" then
                    visit(c, "UIParent.child", 1)
                end
            end)
        end
    end)
end

-- Method call on an arbitrary object that never raises: Line regions (and some secure frames) throw
-- "Wrong object type for function" on methods such as GetNumPoints, which used to drop the whole piece.
local function Call(obj, method, ...)
    local fnc = obj[method]
    if type(fnc) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fnc, obj, ...)
    if ok then return a, b, c, d, e end
    return nil
end

local function ParentName(obj)
    local p = Call(obj, "GetParent")
    if not p then return "<none>" end
    return SafeName(p) or "<anon>"
end

local function SkinInfo(obj)
    local name = SafeName(obj) or "<anon>"
    local kind = Call(obj, "GetObjectType") or "?"
    local w, h = Call(obj, "GetWidth") or 0, Call(obj, "GetHeight") or 0
    local extra = ""
    if kind == "Line" then
        -- a Line has a start and an end point instead of anchors
        local _, _, _, sx, sy = Call(obj, "GetStartPoint")
        local _, _, _, ex, ey = Call(obj, "GetEndPoint")
        local layer = Call(obj, "GetDrawLayer") or "-"
        local okc, r, g, b, a = pcall(obj.GetVertexColor, obj)
        extra = string.format(" layer=%s tex=%s from=%.0f,%.0f to=%.0f,%.0f thick=%.1f", tostring(layer),
            tostring(Call(obj, "GetTexture")), sx or 0, sy or 0, ex or 0, ey or 0, Call(obj, "GetThickness") or 0)
        if okc and r then extra = extra .. string.format(" rgba=%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1) end
    elseif obj.GetTexture then
        local okc, r, g, b, a = pcall(obj.GetVertexColor, obj)
        local layer = Call(obj, "GetDrawLayer") or "-"
        extra = string.format(" layer=%s tex=%s", tostring(layer), tostring(Call(obj, "GetTexture")))
        if okc and r then extra = extra .. string.format(" rgba=%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1) end
    elseif obj.GetText then
        extra = " text=" .. tostring(Call(obj, "GetText"))
    end
    local pts = kind == "Line" and 0 or (Call(obj, "GetNumPoints") or 0)
    return string.format("%s %s parent=%s %.0fx%.0f shown=%s visible=%s hudHid=%s pts=%d alpha=%.2f%s", kind, name,
        ParentName(obj), w, h, tostring(Call(obj, "IsShown")), tostring(Call(obj, "IsVisible")),
        tostring(HUD.IsHiddenByHud(obj)), pts, Call(obj, "GetAlpha") or -1, extra)
end

-- what /gthud skins diff compares (text is left out on purpose: clocks and coordinates change all the time)
local function SkinKey(obj)
    local r, g, b, a = -1, -1, -1, -1
    local ok, r1, g1, b1, a1 = pcall(obj.GetVertexColor or error, obj)
    if ok and r1 then r, g, b, a = r1, g1, b1, a1 or 1 end
    return string.format("%s|%.2f|%.0f|%.0f|%.2f,%.2f,%.2f,%.2f", tostring(Call(obj, "IsVisible")),
        Call(obj, "GetAlpha") or 0, Call(obj, "GetWidth") or 0, Call(obj, "GetHeight") or 0, r, g, b, a)
end

local function SkinsReport()
    if walkSkipped > 0 then
        Print(string.format("%d pieces could not be read and were skipped. First error: %s", walkSkipped, tostring(walkFirstError)))
    end
end

local function Skins(args)
    local sub, n = args[2], tonumber(args[3])
    Print("skins tool v4 (list | hide N | show N | mark | diff)")
    if sub == "hide" or sub == "show" then
        local entry = n and skinList[n]
        if not entry then return Print("Run /gthud skins first, then /gthud skins " .. sub .. " <number>") end
        entry.obj[sub == "hide" and "Hide" or "Show"](entry.obj)
        return Print(string.format("#%d %s (the HUD or another addon may undo this; /reload clears it)", n,
            sub == "hide" and "hidden" or "shown"))
    elseif sub == "mark" then
        skinMark = setmetatable({}, { __mode = "k" })
        local count = 0
        WalkSkins(function(obj) skinMark[obj] = { key = SkinKey(obj), info = SkinInfo(obj) }; count = count + 1 end)
        SkinsReport()
        return Print(string.format("Marked %d pieces. When the arc shows, run /gthud skins diff", count))
    elseif sub == "diff" then
        if not skinMark then return Print("Run /gthud skins mark first (while the arc is NOT showing)") end
        local found, lineGroups, lineOrder = 0, {}, {}
        WalkSkins(function(obj, where)
            local key = SkinKey(obj)
            local m = skinMark[obj]
            local changed
            if not m then
                changed = Call(obj, "IsVisible") and "NEW" or nil
            elseif m.key ~= key then
                changed = "CHANGED"
            end
            if changed then
                found = found + 1
                local isLine = Call(obj, "GetObjectType") == "Line"
                local pn = isLine and ParentName(obj)
                if isLine then
                    if not lineGroups[pn] then lineGroups[pn] = { n = 0, state = changed }; lineOrder[#lineOrder + 1] = pn end
                    local gr = lineGroups[pn]
                    gr.n = gr.n + 1
                    if gr.n <= 3 then Print(string.format("%s %s %s", changed, where, SkinInfo(obj))) end   -- 3 samples per parent
                elseif found <= 40 then
                    Print(string.format("%s %s %s", changed, where, SkinInfo(obj)))
                    if m then Print("      was: " .. m.info) end
                end
            end
        end)
        for _, pn in ipairs(lineOrder) do
            Print(string.format("   %d Line pieces under parent '%s' (%s)", lineGroups[pn].n, pn, lineGroups[pn].state))
        end
        SkinsReport()
        return Print(found == 0 and "Nothing new or changed since the mark." or
            string.format("%d new or changed since the mark%s", found, found > 40 and " (first 40 non-Line shown, Lines grouped above)" or ""))
    end

    wipe(skinList)
    local extra = 0
    WalkSkins(function(obj, where)
        if obj.IsVisible and (obj:IsVisible() or HUD.IsHiddenByHud(obj)) then
            if #skinList < 80 then
                skinList[#skinList + 1] = { obj = obj, where = where, info = SkinInfo(obj) }
            else
                extra = extra + 1
            end
        end
    end)
    for i, entry in ipairs(skinList) do Print(string.format("#%d %s %s", i, entry.where, entry.info)) end
    if extra > 0 then Print(string.format("%d more not listed (list stops at 80)", extra)) end
    SkinsReport()
    for k, v in pairs(_G) do
        if type(k) == "string" and k:find("SexyMap") and type(v) == "table" and v.GetObjectType then
            local ok, info = pcall(SkinInfo, v)
            if ok then Print(string.format("_G %s %s", k, info)) end
        end
    end
    Print("skins scan done. Arc comes and goes: /gthud skins mark without it, /gthud skins diff with it.")
end

HUD.Status, HUD.Info, HUD.ListFrames = Status, Info, ListFrames

local function Toggle(key, label)
    HUD.Set(key, not HUD.db[key])
    Print(label .. " " .. OnOff(HUD.db[key]))
end

local function SetNumber(key, a, lo, hi, usage, label)
    if not a then return Print("Usage: " .. usage) end
    HUD.Set(key, Round(Clamp(a, lo, hi)))
    Print(label .. " " .. HUD.db[key])
end

local function ProfileCommand(args, raw)
    local sub = args[2]
    if not sub then
        Print(GT.TRF("Current profile: |cffffff00%s|r. Available: %s", HUD.ProfileCurrent(), table.concat(HUD.ProfileList(), ", ")))
        return Print(GT.TR("/gthud profile <name> switches (a new name copies the current profile); /gthud profile delete <name>"))
    end
    if sub == "delete" then
        if not raw[3] then return Print(GT.TR("Usage: /gthud profile delete <name>")) end
        local ok, err = HUD.ProfileDelete(raw[3])
        return Print(ok and GT.TRF("Deleted profile %s", raw[3]) or GT.TRF("Cannot delete: %s", tostring(err)))
    end
    local created = HUD.ProfileSwitch(raw[2])
    Print(GT.TRF(created and "Created and switched to profile %s" or "Switched to profile %s", raw[2]))
end

-- Called by GatherTimes' slash handlers in Core.lua: /gt hud <msg>  and  /gthud <msg>
function HUD.Slash(msg)
    local args, raw = {}, {}
    for w in (msg or ""):gmatch("%S+") do raw[#raw + 1] = w; args[#args + 1] = w:lower() end
    local cmd = args[1] or ""
    local a, b, c, d = tonumber(args[2]), tonumber(args[3]), tonumber(args[4]), tonumber(args[5])
    local db = HUD.db
    if not db then return end

    if cmd == "" or cmd == "toggle" then HUD.SetEnabled(not HUD.IsActive())
    elseif cmd == "on" then HUD.SetEnabled(true)
    elseif cmd == "off" then HUD.SetEnabled(false)
    elseif cmd == "size" then SetNumber("size", a, HUD.LIMITS.size[1], HUD.LIMITS.size[2], "/gthud size <150-1400>", "Size")
    elseif cmd == "alpha" then
        if not a then return Print("Usage: /gthud alpha <0-1>") end
        HUD.Set("alpha", Clamp(a, 0, 1)); Print(string.format("Alpha %.2f (applied in 0.1 steps)", db.alpha))
    elseif cmd == "zoom" then SetNumber("zoom", a, HUD.LIMITS.zoom[1], HUD.LIMITS.zoom[2], "/gthud zoom <0-5>", "Zoom")
    elseif cmd == "rotate" then Toggle("rotate", "Rotate")
    elseif cmd == "ring" or cmd == "ring2" then
        -- the radius is in yards or pixels, whichever ring unit is set (/gthud ringunit)
        local second = cmd == "ring2"
        if db.ringUnit == "yd" then
            SetNumber(second and "ring2Yd" or "ringYd", a, HUD.LIMITS.ringYd[1], HUD.LIMITS.ringYd[2],
                "/gthud " .. cmd .. " <radius yd, 0=off>", (second and "Second ring" or "Ring") .. " (yards)")
        else
            SetNumber(second and "ring2" or "ring", a, HUD.LIMITS.ring[1], HUD.LIMITS.ring[2],
                "/gthud " .. cmd .. " <radius px, 0=off>", second and "Second ring" or "Ring")
        end
    elseif cmd == "ringunit" then
        local u = args[2] or ""
        if u == "yards" then u = "yd" elseif u == "pixels" then u = "px" end
        if u ~= "px" and u ~= "yd" then
            return Print("Usage: /gthud ringunit px | yd   (now: " .. tostring(db.ringUnit) .. ")")
        end
        HUD.Set("ringUnit", u)
        Print("Ring radius unit: " .. (u == "yd" and "yards" or "pixels"))
    elseif cmd == "ringcolor" then
        if not (a and b and c and d) then return Print("Usage: /gthud ringcolor <r> <g> <b> <a>  (values 0-1)") end
        HUD.Set("ringColor", { Clamp(a, 0, 1), Clamp(b, 0, 1), Clamp(c, 0, 1), Clamp(d, 0, 1) })
        Print(string.format("Ring color %.2f %.2f %.2f %.2f", unpack(db.ringColor)))
    elseif cmd == "ringcolor2" then
        if not (a and b and c and d) then return Print("Usage: /gthud ringcolor2 <r> <g> <b> <a>  (values 0-1)") end
        HUD.Set("ringColor2", { Clamp(a, 0, 1), Clamp(b, 0, 1), Clamp(c, 0, 1), Clamp(d, 0, 1) })
        Print(string.format("Second ring color %.2f %.2f %.2f %.2f", unpack(db.ringColor2)))
    elseif cmd == "ringthick" then SetNumber("ringThickness", a, 1, 10, "/gthud ringthick <1-10>", "Ring thickness")
    elseif cmd == "ringstyle" then
        local s = args[2] or ""
        if s ~= "solid" and s ~= "stripes" and s ~= "dots" then
            return Print("Usage: /gthud ringstyle solid | stripes | dots   (now: " .. tostring(db.ringStyle) .. ")")
        end
        HUD.Set("ringStyle", s)
        Print("Ring style: " .. s)
    elseif cmd == "ringdensity" then SetNumber("ringDensity", a, HUD.LIMITS.ringDensity[1], HUD.LIMITS.ringDensity[2], "/gthud ringdensity <4-128>", "Ring density")
    elseif cmd == "ringseg" then SetNumber("ringSegments", a, 8, 256, "/gthud ringseg <8-256>", "Ring segments")
    elseif cmd == "dirs" then Toggle("dirs", "Compass letters")
    elseif cmd == "heading" then Toggle("heading", "Heading readout")
    elseif cmd == "arrow" then Toggle("arrow", "Player arrow")
    elseif cmd == "hover" then Toggle("hudHover", "Hover tooltips on the HUD map")
    elseif cmd == "tracking" then Toggle("tracking", "Tracking button on HUD")
    elseif cmd == "trackmode" then
        local m = args[2] or ""
        if m ~= "auto" and m ~= "own" and m ~= "stock" then
            return Print("Usage: /gthud trackmode auto | own | stock   (tracking button while the HUD is OFF; now: "
                .. tostring(db.trackIdle) .. ")")
        end
        HUD.Set("trackIdle", m)
        Print("Tracking button with the HUD off: " .. m .. (m == "auto" and (HUD.UseOwnIdle() and " (using the HUD's own button)" or " (using Blizzard's button)") or ""))
    elseif cmd == "tracksize" then SetNumber("trackingSize", a, HUD.LIMITS.trackingSize[1], HUD.LIMITS.trackingSize[2], "/gthud tracksize <20-80>", "Tracking button size")
    elseif cmd == "trackpos" then
        if not (a and b) then return Print("Usage: /gthud trackpos <x> <y>   (offset from the default spot, for the current HUD state; 0 0 resets)") end
        local kx, ky = "trackingX", "trackingY"
        local active = HUD.IsActive()
        if not active then kx, ky = "idleX", "idleY" end
        HUD.Set(kx, Round(Clamp(a, HUD.LIMITS[kx][1], HUD.LIMITS[kx][2])))
        HUD.Set(ky, Round(Clamp(b, HUD.LIMITS[ky][1], HUD.LIMITS[ky][2])))
        Print("Tracking button offset (" .. (active and "HUD on" or "HUD off") .. ") " .. db[kx] .. ", " .. db[ky])
    elseif cmd == "addons" then Toggle("hideAddons", "Hide minimap addon skins / button frames")
    elseif cmd == "scan" then
        HUD.SetRoot("deepScan", not HUD.root.deepScan)
        Print("Deep scan of Minimap children (for minimap addons not on the HUD's list) " .. OnOff(HUD.root.deepScan))
        if HUD.IsActive() then HUD.Refresh() end
        if HUD.Config then HUD.Config.Refresh() end
    elseif cmd == "eagle" then
        local sub = args[2] or ""
        if sub == "preview" then
            if not HUD.IsActive() then return Print("Turn the HUD on first (/gthud on).") end
            local on = HUD.EaglePreview()
            Print("Eagle map preview " .. OnOff(on) .. (on and "  (/gthud eagle preview again to stop)" or ""))
            if HUD.Config then HUD.Config.Refresh() end
        elseif sub == "size" then
            SetNumber("eagleSize", tonumber(args[3]), HUD.LIMITS.eagleSize[1], HUD.LIMITS.eagleSize[2], "/gthud eagle size <150-1400>", "Eagle map size")
        elseif sub == "zoom" then
            SetNumber("eagleZoom", tonumber(args[3]), HUD.LIMITS.zoom[1], HUD.LIMITS.zoom[2], "/gthud eagle zoom <0-5>", "Eagle map zoom")
        elseif sub == "alpha" then
            local v = tonumber(args[3])
            if not v then return Print("Usage: /gthud eagle alpha <0-1>") end
            HUD.Set("eagleAlpha", Clamp(v, 0, 1)); Print(string.format("Eagle map alpha %.2f", db.eagleAlpha))
        elseif sub == "rotate" then Toggle("eagleRotate", "Eagle map rotates with the camera")
        elseif sub == "scale" then Toggle("eagleScale", "Distance scale (yards) on the Eagle map")
        elseif sub == "nearest" then Toggle("eagleNearest", "Nearest node readout on the Eagle map")
        elseif sub == "hover" then Toggle("eagleHover", "Hover tooltips on the Eagle map")
        elseif sub == "debug" then
            -- positions the game reports right now (cast it during Eagle Eye, and again with no Eagle Eye): where the
            -- map is centred, where the addon thinks you are, and the scale it draws pins with
            local function unit(u)
                if not UnitPosition then return u .. ": no UnitPosition" end
                local ok, y, x = pcall(UnitPosition, u)
                if ok and x then return string.format("%s %.1f,%.1f", u, x, y) end
                return u .. " -"
            end
            local hx, hy
            if GT.HBD and GT.HBD.GetPlayerWorldPosition then
                local ok, x, y = pcall(GT.HBD.GetPlayerWorldPosition, GT.HBD)
                if ok then hx, hy = x, y end
            end
            local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
            Print(string.format("Eagle debug: eagleMap=%s viewActive=%s mapUp=%s", tostring(db.eagleMap),
                tostring(HUD.EagleEyeActive()), tostring(HUD.EagleMapUp())))
            Print("units (world x,y): " .. unit("player") .. " | " .. unit("pet") .. " | " .. unit("vehicle") .. " | " .. unit("target"))
            Print(string.format("addon position: world %s,%s  zone map %s %s,%s", hx and string.format("%.1f", hx) or "-",
                hy and string.format("%.1f", hy) or "-", tostring(map), pos and string.format("%.4f", pos.x) or "-",
                pos and string.format("%.4f", pos.y) or "-"))
            local vr = C_Minimap and C_Minimap.GetViewRadius and select(2, pcall(C_Minimap.GetViewRadius))
            Print(string.format("minimap: size %.0f px, zoom %s, view radius %s yd, HUD table radius %.1f yd, indoors %s",
                Minimap:GetWidth(), tostring(Minimap:GetZoom()), tostring(vr), HUD.MapRadiusYards(), tostring(IsIndoors and IsIndoors())))
        elseif sub == "" or sub == "toggle" or sub == "on" or sub == "off" then
            local v = (sub == "on") or (sub == "" or sub == "toggle") and not db.eagleMap
            HUD.Set("eagleMap", v and true or false)
            Print("Eagle Eye map " .. OnOff(db.eagleMap))
        else
            Print("Usage: /gthud eagle [on|off] | preview | size <px> | zoom <0-5> | alpha <0-1> | rotate | scale | nearest | hover | debug")
        end
        if HUD.Config then HUD.Config.Refresh() end
    elseif cmd == "mountfade" then Toggle("mountFade", "Hide HUD while mounted")
    elseif cmd == "autogather" then Toggle("autoGather", "Auto-enable while gathering tracking is active")
    elseif cmd == "restore" then
        HUD.SetRoot("restoreOnLogin", not HUD.root.restoreOnLogin)
        Print("Restore HUD after /reload or login: " .. OnOff(HUD.root.restoreOnLogin))
        if HUD.Config then HUD.Config.Refresh() end
    elseif cmd == "perf" or cmd == "lowspec" then
        local want = cmd == "lowspec" and "lowest" or a
        if want and want ~= "" then
            if not HUD.SetPerfLevel(tostring(want)) then return Print("Usage: /gthud perf full | balanced | lowest") end
        end
        Print("Performance level: " .. HUD.PERF_LEVELS[HUD.PerfLevel()])
    elseif cmd == "config" or cmd == "options" then
        if HUD.Config and HUD.Config.Open then HUD.Config.Open() else Print("Settings window unavailable; use /gthud help") end
    elseif cmd == "profile" then ProfileCommand(args, raw)
    elseif cmd == "status" then Status()
    elseif cmd == "info" then Info()
    elseif cmd == "frames" then ListFrames()
    elseif cmd == "skins" then
        local ok, err = pcall(Skins, args)
        if not ok then Print("skins failed: " .. tostring(err)) end
    elseif cmd == "debug" then
        HUD.root.debug = not HUD.root.debug
        Print("Debug messages " .. OnOff(HUD.root.debug))
    elseif cmd == "reset" then HUD.ResetProfile(); Print("Profile '" .. HUD.ProfileCurrent() .. "' reset to defaults.")
    else PrintHelp() end
end
