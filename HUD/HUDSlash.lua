-- HUDSlash.lua : the /gthud commands (called by Core.lua through HUD.Slash) and the status / info output.
-- Part of the HUD module (see HUD.lua for the file layout).
local addonName, GT = ...
local HUD = GT.HUD
local Print, Clamp, Round = HUD.Print, HUD.Clamp, HUD.Round

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function PrintHelp()
    Print("|cffffff00HUD commands|r (/gthud or /gt hud)")
    Print("/gthud [toggle | on | off]   /gthud config   /gthud unlock | lock")
    Print("/gthud size <150-1400> | alpha <0-1> | zoom <0-5> | offset <x> <y> | rotate")
    Print("/gthud ring <px, 0=off> | ring2 <px> | ringcolor <r> <g> <b> <a> | ringcolor2 <r> <g> <b> <a> | ringthick <1-10> | ringseg <8-256>")
    Print("/gthud dirs | heading | arrow | tracking | trackmode auto/own/stock | tracksize <20-80> | trackpos <x> <y> | addons | scan | mountfade | autogather | restore")
    Print("/gthud profile [name | delete <name>]   /gthud status | info | frames | debug | reset")
end

local function OnOff(b) return b and "on" or "off" end

local function Status()
    local db = HUD.db
    Print(string.format("profile |cffffff00%s|r  HUD %s  size %d  alpha %.1f  zoom %d  offset %d,%d",
        HUD.ProfileCurrent(), OnOff(HUD.IsActive()), db.size, db.alpha, db.zoom, db.x, db.y))
    Print(string.format("ring %d  ring2 %d  thick %d  seg %d  rotate %s  dirs %s  heading %s  arrow %s",
        db.ring, db.ring2, db.ringThickness, db.ringSegments, OnOff(db.rotate), OnOff(db.dirs),
        OnOff(db.heading), OnOff(db.arrow)))
    Print(string.format("tracking %s (offset %d,%d)  hide addons %s  deep scan %s  mount fade %s  auto gather %s  restore on login %s",
        OnOff(db.tracking), db.trackingX, db.trackingY, OnOff(db.hideAddons), OnOff(HUD.root.deepScan),
        OnOff(db.mountFade), OnOff(db.autoGather), OnOff(HUD.root.restoreOnLogin)))
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
    elseif cmd == "offset" then
        if not (a and b) then return Print("Usage: /gthud offset <x> <y>") end
        db.x, db.y = Round(a), Round(b); HUD.Set("x", db.x); Print("Offset " .. db.x .. ", " .. db.y)
    elseif cmd == "rotate" then Toggle("rotate", "Rotate")
    elseif cmd == "ring" then SetNumber("ring", a, HUD.LIMITS.ring[1], HUD.LIMITS.ring[2], "/gthud ring <radius px, 0=off>", "Ring")
    elseif cmd == "ring2" then SetNumber("ring2", a, HUD.LIMITS.ring[1], HUD.LIMITS.ring[2], "/gthud ring2 <radius px, 0=off>", "Second ring")
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
    elseif cmd == "mountfade" then Toggle("mountFade", "Hide HUD while mounted")
    elseif cmd == "autogather" then Toggle("autoGather", "Auto-enable while gathering tracking is active")
    elseif cmd == "restore" then
        HUD.SetRoot("restoreOnLogin", not HUD.root.restoreOnLogin)
        Print("Restore HUD after /reload or login: " .. OnOff(HUD.root.restoreOnLogin))
        if HUD.Config then HUD.Config.Refresh() end
    elseif cmd == "unlock" then HUD.SetUnlocked(true)
    elseif cmd == "lock" then HUD.SetUnlocked(false)
    elseif cmd == "config" or cmd == "options" then
        if HUD.Config and HUD.Config.Open then HUD.Config.Open() else Print("Settings window unavailable; use /gthud help") end
    elseif cmd == "profile" then ProfileCommand(args, raw)
    elseif cmd == "status" then Status()
    elseif cmd == "info" then Info()
    elseif cmd == "frames" then ListFrames()
    elseif cmd == "debug" then
        HUD.root.debug = not HUD.root.debug
        Print("Debug messages " .. OnOff(HUD.root.debug))
    elseif cmd == "reset" then HUD.ResetProfile(); Print("Profile '" .. HUD.ProfileCurrent() .. "' reset to defaults.")
    else PrintHelp() end
end
