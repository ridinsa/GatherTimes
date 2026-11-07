-- Graphics.lua : performance helpers for slow PCs, driven from Settings > Display.
--   * a "Graphics quality" slider: Off / Low / Very low / Minimal (the game's own menu variables, version 2)
--   * screen effects on / off, weather density, maximum camera zoom
-- Everything goes through console variables (CVars). A CVar this client does not have is skipped, never an error.
-- The player's own values are remembered the first time the quality slider leaves "Off" and put back on "Off".
local ADDON, GT = ...
local Gfx = {}
GT.Gfx = Gfx

local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

local function Get(name)
    local ok, v = pcall(getCVar, name)
    if ok then return v end
end

local function Has(name) return Get(name) ~= nil end

local function Set(name, value)
    if not Has(name) then return false end
    return (pcall(setCVar, name, tostring(value)))
end

local function Cfg() return GT.cfg and GT.cfg() or nil end

---------------------------------------------------------------------------
-- Graphics quality: Off(0) / Low(1) / Very low(2) / Minimal(3)
-- Version 2: uses the SAME console variables as the game's own Graphics menu (graphicsQuality, graphicsViewDistance,
-- graphicsShadowQuality ...), so the menu sliders follow. The order matters: the master slider first (the game then
-- rewrites the sub-settings), then every sub-setting on top of it.
---------------------------------------------------------------------------

Gfx.LEVEL_NAMES = { [0] = "Off (my own settings)", "Low", "Very low", "Minimal" }

-- { cvar, { level 1, level 2, level 3 } }, in apply order. A CVar this client does not have is skipped.
local PRESETS = {
    { "graphicsQuality",           { 4, 2, 1 } },     -- master slider, 1..10
    { "graphicsViewDistance",      { 5, 2, 0 } },     -- 0..9
    { "graphicsEnvironmentDetail", { 5, 2, 0 } },     -- 0..9
    { "graphicsGroundClutter",     { 4, 1, 0 } },     -- 0..9
    { "graphicsShadowQuality",     { 0, 0, 0 } },     -- 0 = lowest
    { "graphicsLiquidDetail",      { 1, 0, 0 } },     -- 0..3
    { "graphicsParticleDensity",   { 3, 2, 1 } },     -- 0 = disabled .. 5
    { "graphicsProjectedTextures", { 0, 0, 0 } },
    { "graphicsSSAO",              { 0, 0, 0 } },
    { "graphicsDepthEffects",      { 0, 0, 0 } },
    { "graphicsComputeEffects",    { 0, 0, 0 } },
    { "graphicsSunshafts",         { 0, 0, 0 } },
    { "graphicsTextureFiltering",  { 2, 1, 0 } },     -- 0 = bilinear
    { "graphicsTextureResolution", { 2, 1, 0 } },
    { "RenderScale",               { 1, 0.85, 0.7 } },
}

-- Setting a CVar from a script changes the game, but the Graphics menu may keep showing its old position. When the
-- client has the new Settings API, ask it to set the same value too, so the menu follows. If that did not leave the
-- CVar at the wanted value (a setting with another scale), the CVar is set again.
local function Push(name, value)
    if not Set(name, value) then return false end
    if name ~= "graphicsQuality" and type(Settings) == "table" and type(Settings.SetValue) == "function" then
        pcall(Settings.SetValue, name, value)
        if tonumber(Get(name)) ~= tonumber(value) then Set(name, value) end
    end
    return true
end

local function ApplyLevel(level)
    for _, row in ipairs(PRESETS) do Push(row[1], row[2][level]) end
end

function Gfx.GetLevel()
    local c = Cfg()
    return c and c.gfxLevel or 0
end

function Gfx.SetLevel(level)
    local c = Cfg()
    if not c then return end
    level = math.max(0, math.min(3, math.floor(tonumber(level) or 0)))
    if level == 0 then
        -- back to what the player had before: master first, then the sub-settings
        local backup = c.gfxBackup or {}
        for _, row in ipairs(PRESETS) do
            local v = backup[row[1]]
            if v ~= nil then Push(row[1], v) end
        end
        c.gfxBackup = {}
    else
        if next(c.gfxBackup or {}) == nil then
            c.gfxBackup = {}
            for _, row in ipairs(PRESETS) do
                local v = Get(row[1])
                if v ~= nil then c.gfxBackup[row[1]] = v end
            end
        end
        ApplyLevel(level)
    end
    c.gfxLevel = level
end

---------------------------------------------------------------------------
-- Screen effects
---------------------------------------------------------------------------

-- Death (ghost) effect and the edge effect of invisibility. The second one is ffxNetherWorld on Classic Era,
-- ffxNether on newer clients; whichever exists is set.
function Gfx.GetScreenFx() return Get("ffxDeath") ~= "0" end
function Gfx.SetScreenFx(on)
    local c = Cfg()
    if c then c.fxScreen = on and true or false end
    local v = on and 1 or 0
    Set("ffxDeath", v)
    Set("ffxNetherWorld", v)
    Set("ffxNether", v)
end

---------------------------------------------------------------------------
-- Weather density (0 = none .. 3 = full) and maximum camera zoom (tenths: 10 = 1.0x .. 40 = 4.0x)
---------------------------------------------------------------------------

function Gfx.GetWeather()
    return math.max(0, math.min(3, math.floor(tonumber(Get("weatherDensity")) or 3)))
end
function Gfx.SetWeather(v)
    v = math.max(0, math.min(3, math.floor(tonumber(v) or 0)))
    local c = Cfg()
    if c then c.fxWeather = v end
    Set("weatherDensity", v)
end

function Gfx.GetZoom()
    return math.max(10, math.min(40, math.floor((tonumber(Get("cameraDistanceMaxZoomFactor")) or 1) * 10 + 0.5)))
end
function Gfx.SetZoom(tenths)
    tenths = math.max(10, math.min(40, math.floor(tonumber(tenths) or 10)))
    local c = Cfg()
    if c then c.fxZoom = tenths end
    Set("cameraDistanceMaxZoomFactor", tenths / 10)
end

---------------------------------------------------------------------------
-- Put the saved choices back after login / reload (only settings the player actually changed)
---------------------------------------------------------------------------

function Gfx.Reapply()
    local c = Cfg()
    if not c then return end
    if (c.gfxLevel or 0) > 0 then ApplyLevel(c.gfxLevel) end
    -- Drunken haze was removed. If it had been switched off here, give the game's full screen glow back once.
    if c.fxHaze == false then Set("ffxGlow", 1) end
    c.fxHaze = nil
    if c.fxScreen ~= nil then Gfx.SetScreenFx(c.fxScreen) end
    if c.fxWeather ~= nil then Gfx.SetWeather(c.fxWeather) end
    if c.fxZoom ~= nil then Gfx.SetZoom(c.fxZoom) end
end

---------------------------------------------------------------------------
-- /gt gfx : shows, for every graphics CVar the slider uses, whether this client has it and its current value
---------------------------------------------------------------------------

function Gfx.Report()
    local lvl = Gfx.GetLevel()
    GT.cprint(string.format("Graphics quality level: %d (%s). Settings API: %s", lvl,
        tostring(Gfx.LEVEL_NAMES[lvl]), (type(Settings) == "table" and Settings.SetValue) and "yes" or "no"))
    local missing = 0
    for _, row in ipairs(PRESETS) do
        local v = Get(row[1])
        if v == nil then
            missing = missing + 1
            GT.cprint("  " .. row[1] .. ": |cffff5555not in this client|r")
        else
            local want = lvl > 0 and row[2][lvl]
            if type(want) == "table" then want = "pct " .. want.pct end
            GT.cprint("  " .. row[1] .. " = " .. tostring(v) .. (want and ("   (slider wants " .. tostring(want) .. ")") or ""))
        end
    end
    GT.cprint(string.format("%d of %d settings are missing in this client.", missing, #PRESETS))
end
