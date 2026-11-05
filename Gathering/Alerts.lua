-- Alerts.lua
--   On-screen alerts in several styles (Settings > Display > On-screen alert):
--     text   - big outlined text at the top of the screen (the original look)
--     banner - dark bar with a coloured edge, item icon, title and detail line
--     toast  - small cards stacked on the right edge, newest on top (up to 3 at once)
--     flash  - coloured glow around the screen edges + the text style
--   GT.ShowScreenAlert(title, r, g, b [, icon [, detail]])  draws one alert in the style picked in the settings.
local addonName, GT = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"
local function FONT() return GT.FontFile("Fonts\\FRIZQT__.TTF") end   -- use a script-capable font when needed

-- order = order of the Settings dropdown
GT.ALERT_STYLES = {
    { id = "text",   name = "Text" },
    { id = "banner", name = "Banner" },
    { id = "toast",  name = "Toast stack" },
    { id = "flash",  name = "Screen flash" },
}

-- icon of a node's item (herb / ore) for the banner and toast styles
function GT.NodeIcon(key)
    local def = GT.nodes and GT.nodes[key]
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not (def and def.id and f) then return nil end
    local ok, icon = pcall(function() return select(5, f(def.id)) end)
    return ok and icon or nil
end

-- 0..1 opacity over the life of an alert: quick fade-in, slow fade-out at the end
local function Envelope(t, dur)
    local fade = math.min(1, dur * 0.25)
    if t < 0.15 then return t / 0.15 end
    if t > dur - fade then return math.max(0, (dur - t) / fade) end
    return 1
end

-- ---------------------------------------------------------------- style: text
local textFrame
local function TextStyle(text, r, g, b, icon, sub, dur)
    local f = textFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(700, 40)
        f:SetPoint("TOP", UIParent, "TOP", 0, -170)
        f:SetFrameStrata("HIGH")
        f:Hide()
        f.text = GT.Font(f, nil, "OVERLAY")
        f.text:SetFont(FONT(), GT.FontSize(26), "OUTLINE")
        f.text:SetPoint("CENTER")
        f:SetScript("OnUpdate", function(self)
            local t = GetTime() - (self._start or 0)
            if t >= (self._dur or 4) then self:Hide() else self:SetAlpha(Envelope(t, self._dur or 4)) end
        end)
        textFrame = f
    end
    f.text:SetText(sub and (text .. " (" .. sub .. ")") or text)
    f.text:SetTextColor(r, g, b)
    f._start, f._dur = GetTime(), dur
    f:SetAlpha(0)
    f:Show()
end

-- ---------------------------------------------------------------- cards (banner + toast)
local function NewCard(w, h)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(w, h)
    f:SetFrameStrata("HIGH")
    f:Hide()
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(FLAT)
    bg:SetVertexColor(0.06, 0.06, 0.06, 0.92)
    f.bar = f:CreateTexture(nil, "BORDER")                 -- coloured edge on the left
    f.bar:SetTexture(FLAT)
    f.bar:SetWidth(4)
    f.bar:SetPoint("TOPLEFT")
    f.bar:SetPoint("BOTTOMLEFT")
    f.line = f:CreateTexture(nil, "BORDER")                -- thin coloured line along the bottom
    f.line:SetTexture(FLAT)
    f.line:SetHeight(1)
    f.line:SetPoint("BOTTOMLEFT", 4, 0)
    f.line:SetPoint("BOTTOMRIGHT")
    f.isz = h - 14
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(f.isz, f.isz)
    f.icon:SetPoint("LEFT", f, "LEFT", 12, 0)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = GT.Font(f, nil, "OVERLAY")
    f.title:SetFont(FONT(), GT.FontSize(14), "OUTLINE")
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.sub = GT.Font(f, nil, "OVERLAY", "GameFontHighlightSmall")
    f.sub:SetJustifyH("LEFT")
    f.sub:SetWordWrap(false)
    return f
end

local function FillCard(f, text, r, g, b, icon, sub)
    f.bar:SetVertexColor(r, g, b, 1)
    f.line:SetVertexColor(r, g, b, 0.5)
    local x = 14
    if icon then f.icon:SetTexture(icon); f.icon:Show(); x = 12 + f.isz + 8 else f.icon:Hide() end
    local w = f:GetWidth() - x - 8
    f.title:SetTextColor(r, g, b)
    f.title:SetText(text)
    f.title:SetWidth(w)
    f.title:ClearAllPoints()
    f.sub:ClearAllPoints()
    if sub and sub ~= "" then
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(f:GetHeight() - 30) / 2)
        f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
        f.sub:SetWidth(w)
        f.sub:SetText(sub)
        f.sub:Show()
    else
        f.title:SetPoint("LEFT", f, "LEFT", x, 0)
        f.sub:SetText("")
        f.sub:Hide()
    end
end

-- ---------------------------------------------------------------- style: banner
local banner
local function BannerStyle(text, r, g, b, icon, sub, dur)
    local f = banner
    if not f then
        f = NewCard(440, 54)
        f:SetScript("OnUpdate", function(self)
            local t = GetTime() - (self._start or 0)
            if t >= (self._dur or 4) then self:Hide(); return end
            self:SetAlpha(Envelope(t, self._dur or 4))
            local slide = 1 - math.min(t / 0.2, 1)               -- slides down 12 px while it fades in
            self:ClearAllPoints()
            self:SetPoint("TOP", UIParent, "TOP", 0, -150 + 12 * slide)
        end)
        banner = f
    end
    FillCard(f, text, r, g, b, icon, sub)
    f._start, f._dur = GetTime(), dur
    f:SetAlpha(0)
    f:Show()
end

-- ---------------------------------------------------------------- style: toast stack
local TOAST_W, TOAST_H, TOAST_GAP, MAX_TOASTS = 270, 46, 6, 3
local toasts, toastActive, toastDriver = {}, {}, nil
local function ToastDrive()
    local now = GetTime()
    for i = #toastActive, 1, -1 do
        local f = toastActive[i]
        if now - f._start >= f._dur then f:Hide(); table.remove(toastActive, i) end
    end
    for i, f in ipairs(toastActive) do
        local t = now - f._start
        local slide = 1 - math.min(t / 0.25, 1)                  -- slides in from the right edge
        f:ClearAllPoints()
        f:SetPoint("TOPRIGHT", UIParent, "RIGHT", -16 + slide * slide * (TOAST_W + 20),
            150 - (i - 1) * (TOAST_H + TOAST_GAP))
        f:SetAlpha(Envelope(t, f._dur))
    end
    if #toastActive == 0 then toastDriver:Hide() end
end
local function ToastStyle(text, r, g, b, icon, sub, dur)
    if not toastDriver then
        toastDriver = CreateFrame("Frame", nil, UIParent)
        toastDriver:Hide()
        toastDriver:SetScript("OnUpdate", ToastDrive)
    end
    local f
    for _, c in ipairs(toasts) do if not c:IsShown() then f = c; break end end
    if not f then
        if #toasts < MAX_TOASTS then
            f = NewCard(TOAST_W, TOAST_H)
            toasts[#toasts + 1] = f
        else
            f = table.remove(toastActive)                        -- all in use: recycle the oldest
        end
    end
    for i = #toastActive, 1, -1 do if toastActive[i] == f then table.remove(toastActive, i) end end
    FillCard(f, text, r, g, b, icon, sub)
    f._start, f._dur = GetTime(), dur
    f:SetAlpha(0)
    f:Show()
    table.insert(toastActive, 1, f)
    toastDriver:Show()
    ToastDrive()
end

-- ---------------------------------------------------------------- style: flash (edge glow + text)
-- The glow is a stack of 48 thin nested frames ("rings", 2 units each) whose opacity falls off smoothly from the
-- screen edge towards the centre.  It needs no gradient API (that call differs between game versions and showed
-- up as flat colour bands); the rings never overlap, so the corners are as even as the sides.
local GLOW_STEPS, GLOW_STEP, GLOW_MAX = 48, 2, 0.6
local flash

local function BuildFlash()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("HIGH")
    f:Hide()
    f.rings = {}
    local function Strip(p1, x1, y1, p2, x2, y2, w, h)
        local t = f:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(FLAT)
        t:SetPoint(p1, f, p1, x1, y1)
        t:SetPoint(p2, f, p2, x2, y2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        return t
    end
    for i = 1, GLOW_STEPS do
        local o, n = (i - 1) * GLOW_STEP, i * GLOW_STEP          -- inset of this ring's outer / inner edge
        f.rings[i] = {
            Strip("TOPLEFT", o, -o, "TOPRIGHT", -o, -o, nil, GLOW_STEP),              -- top
            Strip("BOTTOMLEFT", o, o, "BOTTOMRIGHT", -o, o, nil, GLOW_STEP),          -- bottom
            Strip("TOPLEFT", o, -n, "BOTTOMLEFT", o, n, GLOW_STEP, nil),              -- left, between top and bottom
            Strip("TOPRIGHT", -o, -n, "BOTTOMRIGHT", -o, n, GLOW_STEP, nil),          -- right
        }
    end
    f:SetScript("OnUpdate", function(self)
        local t = GetTime() - (self._start or 0)
        local dur = self._dur or 2.5
        if t >= dur then self:Hide(); return end
        local fadeIn = math.min(t / 0.18, 1)                       -- no sudden start
        local x = 1 - t / dur
        local fadeOut = x * x * (3 - 2 * x)                        -- smoothstep: eases out, no sudden end
        local pulse = 0.75 + 0.25 * math.sin(t * 7)                -- gentle pulse
        self:SetAlpha(fadeIn * fadeOut * pulse)
    end)
    return f
end

-- glow only. peak = opacity at the very screen edge (0..1), dur = seconds
local function StartGlow(r, g, b, peak, dur)
    if not flash then flash = BuildFlash() end
    local f = flash
    for i, ring in ipairs(f.rings) do
        local x = 1 - (i - 0.5) / GLOW_STEPS                       -- 1 at the screen edge .. 0 on the inner side
        local a = peak * x * x                                     -- smooth fall-off
        for _, tex in ipairs(ring) do tex:SetVertexColor(r, g, b, a) end
    end
    f._start, f._dur = GetTime(), dur
    f:SetAlpha(0)
    f:Show()
end

local function FlashStyle(text, r, g, b, icon, sub, dur)
    StartGlow(r, g, b, GLOW_MAX, math.min(dur, 2.5))
    TextStyle(text, r, g, b, icon, sub, dur)
end

-- ---------------------------------------------------------------- public
local STYLE = { text = TextStyle, banner = BannerStyle, toast = ToastStyle, flash = FlashStyle }
local styleError

function GT.ShowScreenAlert(text, r, g, b, icon, sub)
    local c = GT.cfg()
    local ok, err = pcall(STYLE[c.alertStyle] or TextStyle, text, r, g, b, icon, sub, c.alertTime or 4)
    if not ok then
        pcall(TextStyle, text, r, g, b, icon, sub, c.alertTime or 4)        -- never lose the alert itself
        if not styleError then
            styleError = true
            if GT.ReportError then GT.ReportError("alert style", err) end
        end
    end
end

-- Settings > Display > Preview: shows a sample alert in the picked style (the samples rotate)
local previewN = 0
function GT.PreviewScreenAlert()
    previewN = previewN % 3 + 1
    local key = GT.nodes.dreamfoil and "dreamfoil" or GT.order[1]
    local def, col = GT.nodes[key], GT.Col(key)
    if previewN == 1 then
        GT.ShowScreenAlert(def.label .. " " .. GT.TR("READY"), col[1], col[2], col[3], GT.NodeIcon(key), GT.TRF("%d yd", 42))
    elseif previewN == 2 then
        GT.ShowScreenAlert(GT.TRF("Leave now: %s G2 ready in 1:30", def.label), col[1], col[2], col[3],
            GT.NodeIcon(key), GT.TRF("%d yd", 80))
    else
        GT.ShowScreenAlert(GT.TRF("LOW HEALTH %d%%", 30), 1, 0.2, 0.2)
    end
end

-- One alert / chime / warning per GROUP of spots, not one per node or per spot.
-- ref = a timer node or a learned spot (both carry .sid).  kind = "ready" | "leave" | "chime".
-- Returns true (and starts the cool-down) if this group may fire now.
local cool = {}
function GT.CooldownOK(kind, key, ref, secs)
    local sp = ref and ref.sid and GT.spawnBySid[ref.sid]
    local token
    if sp then
        local gi = GT.ComputeGroups(key, sp.mapID).of[sp]
        token = kind .. ":" .. key .. ":" .. sp.mapID .. ":" .. (gi and ("g" .. gi) or ("s" .. sp.sid))
    else
        token = kind .. ":" .. key .. ":" .. tostring(ref)
    end
    local now = GetTime()
    if cool[token] and now - cool[token] < secs then return false end
    cool[token] = now
    return true
end

-- force = true skips the cool-down (used by the "Test alert" button)
function GT.FireReadyAlert(key, def, node, force)
    -- nodes of one group become ready at different moments (you looted them at different times):
    -- that must be ONE alert, not one per node
    if not force and not GT.CooldownOK("ready", key, node, 240) then return end
    -- sound = per-node setting (Nodes tab), independent of the screen alert
    GT.PlayHerbSound(key, true)
    if GT.cfg().screenAlert then
        local col = GT.Col(key)
        GT.ShowScreenAlert(def.label .. " " .. GT.TR("READY"), col[1], col[2], col[3], GT.NodeIcon(key),
            node._dist and GT.TRF("%d yd", math.floor(node._dist)) or nil)
    end
end

-- ---------------------------------------------------------------- server maintenance alert
-- When the system chat announces a restart / shutdown / maintenance, the screen flashes (colour 1..7 from
-- Settings > Display, fixed 50% strength) and the message shows centred, without background, for "Alert time" seconds.
-- Switch: cfg().maintAlert.  Fed by Events.lua (CHAT_MSG_SYSTEM) through GT.OnMaintenanceMessage(text).
-- slider value 1..7 -> colour (all bright)
GT.MAINT_COLORS = {
    { name = "Red",     1.00, 0.10, 0.10 },
    { name = "Blue",    0.20, 0.50, 1.00 },
    { name = "Green",   0.20, 1.00, 0.30 },
    { name = "Yellow",  1.00, 0.90, 0.10 },
    { name = "Magenta", 1.00, 0.20, 0.90 },
    { name = "Cyan",    0.10, 0.95, 1.00 },
    { name = "Orange",  1.00, 0.55, 0.05 },
}
local MAINT_STRENGTH = 0.5       -- flash opacity at the screen edge

local MAINT_WORDS = {            -- lower case, plain-text matches
    "maintenance", "server restart", "server shutdown", "shutdown in", "restart in", "restarting in",
    "shutting down", "reboot", "hotfix", "downtime", "going down",
}
local MAINT_PATTERNS = {}        -- built from the client's own localized strings, when those globals exist
for _, name in ipairs({ "SERVER_SHUTDOWN", "SERVER_RESTART", "SERVER_SHUTDOWN_IN", "SERVER_RESTART_IN" }) do
    local s = _G[name]
    if type(s) == "string" and s ~= "" then
        local p = s:lower():gsub("%%%d?%$?[sd]", "\1"):gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0"):gsub("\1", ".-")
        MAINT_PATTERNS[#MAINT_PATTERNS + 1] = p
    end
end

local function CleanChat(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

function GT.IsMaintenanceMessage(text)
    if type(text) ~= "string" then return false end
    local l = CleanChat(text):lower()
    for _, w in ipairs(MAINT_WORDS) do
        if l:find(w, 1, true) then return true end
    end
    for _, p in ipairs(MAINT_PATTERNS) do
        if l:find(p) then return true end
    end
    return false
end

-- the maintenance text: centred, outlined, no background (title + message line)
local maintText
local function MaintTextShow(title, detail, r, g, b, dur)
    local f = maintText
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(760, 70)
        f:SetPoint("TOP", UIParent, "TOP", 0, -150)
        f:SetFrameStrata("HIGH")
        f:Hide()
        f.title = GT.Font(f, nil, "OVERLAY")
        f.title:SetFont(FONT(), GT.FontSize(26), "OUTLINE")
        f.title:SetPoint("TOP", f, "TOP", 0, 0)
        f.title:SetWidth(760)
        f.title:SetJustifyH("CENTER")
        f.sub = GT.Font(f, nil, "OVERLAY")
        f.sub:SetFont(FONT(), GT.FontSize(15), "OUTLINE")
        f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
        f.sub:SetWidth(760)
        f.sub:SetJustifyH("CENTER")
        f:SetScript("OnUpdate", function(self)
            local t = GetTime() - (self._start or 0)
            if t >= (self._dur or 4) then self:Hide() else self:SetAlpha(Envelope(t, self._dur or 4)) end
        end)
        maintText = f
    end
    f.title:SetText(title)
    f.title:SetTextColor(r, g, b)
    f.sub:SetText(detail or "")
    f.sub:SetTextColor(1, 1, 1)
    f._start, f._dur = GetTime(), dur
    f:SetAlpha(0)
    f:Show()
end

-- shows the maintenance alert now (no switch / throttle check)
function GT.ShowMaintenanceAlert(msg)
    local c = GT.cfg()
    local col = GT.MAINT_COLORS[c.maintColorIdx or 1] or GT.MAINT_COLORS[1]
    local r, g, b = col[1], col[2], col[3]
    local dur = c.alertTime or 4
    local ok, err = pcall(StartGlow, r, g, b, MAINT_STRENGTH, dur)
    if not ok and GT.ReportError then GT.ReportError("maintenance flash", err) end
    local detail = msg and CleanChat(msg) or ""
    if #detail > 70 then detail = detail:sub(1, 67) .. "..." end
    local ok2, err2 = pcall(MaintTextShow, GT.TR("SERVER MAINTENANCE"), detail, r, g, b, dur)
    if not ok2 then
        pcall(TextStyle, GT.TR("SERVER MAINTENANCE"), r, g, b, nil, nil, dur)           -- never lose the alert itself
        if GT.ReportError then GT.ReportError("maintenance banner", err2) end
    end
end

local lastMaint, lastMaintAt = nil, 0
function GT.OnMaintenanceMessage(text)
    local c = GT.cfg()
    if not (c and c.maintAlert) then return end
    if not GT.IsMaintenanceMessage(text) then return end
    local now = GetTime()
    if text == lastMaint and now - lastMaintAt < 10 then return end           -- the same line twice in a row
    lastMaint, lastMaintAt = text, now
    GT.ShowMaintenanceAlert(text)
end

-- Settings > Display: automatic preview when the switch is turned on / the colour slider is moved
function GT.PreviewMaintenanceAlert()
    GT.ShowMaintenanceAlert("[Server]: Server restart for maintenance in 15 minutes.")
end
