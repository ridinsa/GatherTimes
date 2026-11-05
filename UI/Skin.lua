-- Skin.lua : colour themes for GatherTimes windows, chosen in Settings > Display.
local ADDON, GT = ...

local function copy(c) return { c[1], c[2], c[3], c[4] } end
local function lift(c, d)
    return { math.min(1, c[1] + d), math.min(1, c[2] + d), math.min(1, c[3] + d), 1 }
end
local function scale(c, k)
    return { math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k), 1 }
end

-- one skin from a frame's background, edge, title bar colour and optional accent (used for "active" buttons)
local function FromFrame(name, bg, edge, title, accent, text, shadow)
    return {
        key = name, name = name,
        colors = {
            bg = bg, header = title, border = edge,
            button = lift(bg, 0.08), hover = lift(bg, 0.20),
            active = accent or { 0.20, 0.45, 0.30, 1 },
            field = scale(bg, 0.6), row = scale(bg, 0.85), head = { title[1], title[2], title[3], 1 },
            line = { edge[1], edge[2], edge[3], 1 },
            text = text,                                  -- nil = the default text colour
            textShadow = shadow,                          -- nil = no outline
        },
    }
end

GT.SKINS = {
    { key = "default", name = "Default", colors = {
        bg = { 0.07, 0.07, 0.07, 0.95 }, header = { 0.12, 0.12, 0.12, 1 }, border = { 0, 0, 0, 1 },
        button = { 0.16, 0.16, 0.16, 1 }, hover = { 0.26, 0.26, 0.26, 1 }, active = { 0.20, 0.45, 0.30, 1 },
        field = { 0.04, 0.04, 0.04, 1 }, row = { 0.06, 0.06, 0.06, 1 }, head = { 0.14, 0.14, 0.14, 1 },
        line = { 0.30, 0.30, 0.30, 1 },
    } },
    FromFrame("Crimson", {0.14, 0.03, 0.04, 0.92}, {0.70, 0.12, 0.15, 1}, {0.30, 0.05, 0.07, 1}, nil),
    FromFrame("Royal Purple", {0.10, 0.05, 0.16, 0.92}, {0.55, 0.30, 0.80, 1}, {0.22, 0.10, 0.34, 1}, {0.75, 0.50, 1.00, 1}),
    FromFrame("Gold Trim", {0.08, 0.07, 0.05, 0.94}, {0.85, 0.68, 0.25, 1}, {0.20, 0.16, 0.07, 1}, {1.00, 0.85, 0.40, 1}),
    FromFrame("Ocean Teal", {0.03, 0.13, 0.14, 0.92}, {0.10, 0.60, 0.62, 1}, {0.06, 0.28, 0.30, 1}, {0.40, 0.95, 0.95, 1}),
    FromFrame("Obsidian", {0.00, 0.00, 0.00, 0.96}, {0.10, 0.10, 0.10, 1}, {0.05, 0.05, 0.05, 1}, {0.25, 0.25, 0.25, 1}),
    FromFrame("Violet Haze", {0.12, 0.06, 0.18, 0.88}, {0.80, 0.40, 1.00, 1}, {0.20, 0.10, 0.28, 0.9}, {1.00, 0.60, 1.00, 1}),
    FromFrame("Bronze Age", {0.14, 0.10, 0.05, 0.94}, {0.62, 0.42, 0.18, 1}, {0.30, 0.20, 0.08, 1}, {0.85, 0.60, 0.30, 1}),
    FromFrame("Deep Sea", {0.01, 0.05, 0.10, 0.94}, {0.05, 0.30, 0.50, 1}, {0.02, 0.14, 0.25, 1}, {0.20, 0.60, 0.85, 1}),
    FromFrame("Frost Steel", {0.20, 0.24, 0.28, 0.90}, {0.75, 0.85, 0.95, 1}, {0.30, 0.36, 0.42, 1}, {0.90, 0.95, 1.00, 1}),
    FromFrame("Emerald Gold", {0.03, 0.10, 0.07, 0.94}, {0.85, 0.70, 0.20, 1}, {0.06, 0.20, 0.14, 1}, {1.00, 0.85, 0.30, 1}),
    FromFrame("Copper Trim", {0.13, 0.07, 0.04, 0.94}, {0.72, 0.40, 0.20, 1}, {0.30, 0.14, 0.07, 1}, {0.90, 0.55, 0.30, 1}),
    FromFrame("Pastel Pink", {0.99, 0.90, 0.94, 0.98}, {0.90, 0.55, 0.70, 1}, {0.97, 0.75, 0.85, 1}, {0.85, 0.40, 0.60, 1}, { 0.08, 0.04, 0.07, 1 }, { 1, 1, 1, 0.8 }),
    FromFrame("Royal Gold", {0.12, 0.05, 0.20, 0.95}, {1.00, 0.80, 0.30, 1}, {0.25, 0.10, 0.40, 1}, {1.00, 0.85, 0.40, 1}),
    FromFrame("Inferno", {0.15, 0.02, 0.00, 0.95}, {1.00, 0.25, 0.00, 1}, {0.40, 0.06, 0.00, 1}, {1.00, 0.50, 0.00, 1}),
    FromFrame("Olive Drab", {0.14, 0.15, 0.08, 0.94}, {0.42, 0.44, 0.20, 1}, {0.22, 0.24, 0.12, 1}, {0.70, 0.72, 0.40, 1}),
    FromFrame("Sakura", {0.98, 0.93, 0.95, 0.98}, {0.85, 0.45, 0.60, 1}, {0.96, 0.78, 0.85, 1}, {0.80, 0.30, 0.50, 1}, { 0.08, 0.04, 0.07, 1 }, { 1, 1, 1, 0.8 }),
    FromFrame("Graphite", {0.10, 0.10, 0.11, 0.96}, {0.50, 0.50, 0.52, 1}, {0.16, 0.16, 0.17, 1}, {0.90, 0.90, 0.90, 1}),
    FromFrame("Vampire", {0.05, 0.00, 0.05, 0.95}, {0.60, 0.00, 0.40, 1}, {0.20, 0.00, 0.15, 1}, {0.90, 0.10, 0.50, 1}),
    FromFrame("Midnight", {0.035, 0.045, 0.085, 0.98}, {0.32, 0.40, 0.72, 1}, {0.10, 0.12, 0.22, 1}, {0.43, 0.55, 1, 1}),
    FromFrame("Ocean", {0.025, 0.10, 0.16, 0.98}, {0.10, 0.58, 0.72, 1}, {0.05, 0.18, 0.26, 1}, {0.24, 0.78, 0.94, 1}),
    FromFrame("Forest", {0.04, 0.12, 0.075, 0.98}, {0.26, 0.58, 0.32, 1}, {0.08, 0.20, 0.12, 1}, {0.44, 0.82, 0.42, 1}),
    FromFrame("Ember", {0.16, 0.055, 0.035, 0.98}, {0.77, 0.31, 0.12, 1}, {0.25, 0.09, 0.05, 1}, {1, 0.48, 0.22, 1}),
    FromFrame("Royal", {0.12, 0.055, 0.16, 0.98}, {0.60, 0.32, 0.76, 1}, {0.20, 0.10, 0.25, 1}, {0.82, 0.52, 1, 1}),
    FromFrame("Gold", {0.13, 0.10, 0.045, 0.98}, {0.78, 0.63, 0.22, 1}, {0.22, 0.17, 0.08, 1}, {1, 0.82, 0.32, 1}),
    FromFrame("Silver", {0.10, 0.11, 0.13, 0.98}, {0.62, 0.66, 0.72, 1}, {0.17, 0.18, 0.21, 1}, {0.84, 0.88, 0.96, 1}),
    FromFrame("Rose", {0.16, 0.065, 0.10, 0.98}, {0.76, 0.32, 0.50, 1}, {0.24, 0.10, 0.16, 1}, {1, 0.52, 0.68, 1}),
    FromFrame("Frost", {0.055, 0.12, 0.17, 0.98}, {0.48, 0.76, 0.88, 1}, {0.10, 0.21, 0.28, 1}, {0.70, 0.92, 1, 1}),
    FromFrame("Desert", {0.17, 0.12, 0.065, 0.98}, {0.74, 0.54, 0.30, 1}, {0.25, 0.19, 0.11, 1}, {0.94, 0.73, 0.42, 1}),
    FromFrame("Void", {0.055, 0.035, 0.09, 0.98}, {0.38, 0.22, 0.64, 1}, {0.12, 0.08, 0.18, 1}, {0.66, 0.40, 0.96, 1}),
    FromFrame("Blood", {0.15, 0.035, 0.045, 0.98}, {0.68, 0.15, 0.18, 1}, {0.24, 0.07, 0.08, 1}, {0.92, 0.28, 0.30, 1}),
    FromFrame("Nature", {0.075, 0.14, 0.09, 0.98}, {0.45, 0.62, 0.28, 1}, {0.14, 0.22, 0.13, 1}, {0.70, 0.88, 0.40, 1}),
    FromFrame("Arcane", {0.075, 0.07, 0.17, 0.98}, {0.34, 0.38, 0.78, 1}, {0.13, 0.12, 0.25, 1}, {0.54, 0.62, 1, 1}),
    FromFrame("Copper", {0.15, 0.085, 0.05, 0.98}, {0.70, 0.40, 0.22, 1}, {0.23, 0.14, 0.09, 1}, {0.92, 0.58, 0.32, 1}),
    FromFrame("Monochrome", {0.075, 0.075, 0.075, 0.98}, {0.48, 0.48, 0.48, 1}, {0.14, 0.14, 0.14, 1}, {0.80, 0.80, 0.80, 1}),
    FromFrame("Azeroth", {0.10, 0.065, 0.035, 0.98}, {0.58, 0.40, 0.19, 1}, {0.18, 0.12, 0.07, 1}, {0.86, 0.65, 0.27, 1}),
    FromFrame("Fel", {0.045, 0.12, 0.055, 0.98}, {0.24, 0.72, 0.20, 1}, {0.09, 0.20, 0.10, 1}, {0.38, 1, 0.24, 1}),
    FromFrame("Light", {0.19, 0.19, 0.18, 0.98}, {0.78, 0.72, 0.55, 1}, {0.26, 0.25, 0.20, 1}, {1, 0.90, 0.62, 1}),
    FromFrame("Storm", {0.065, 0.095, 0.14, 0.98}, {0.34, 0.52, 0.72, 1}, {0.12, 0.16, 0.23, 1}, {0.52, 0.72, 0.94, 1}),
}

GT.skinFrames = setmetatable({}, { __mode = "k" })
GT.skinUpdaters = {}

local function PaintFrame(frame)
    local role = frame.gtSkinRole
    local colors = GT.colors
    local key = (role == "close" or role == "checkbox") and "button" or role
    local color = role == "button" and (frame.gtActive and colors.active or colors.button) or colors[key]
    if color and frame.SetBackdropColor then
        frame:SetBackdropColor(color[1], color[2], color[3], color[4] * (frame.gtSkinAlpha or 1))
    end
    if colors.border and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(unpack(colors.border))
    end
    if frame.mark and colors.active then frame.mark:SetVertexColor(unpack(colors.active)) end
    -- what the button goes back to after a hover: the same colour it was painted with (active stays active)
    if (role == "button" or role == "close") and color then
        frame.baseColor = { color[1], color[2], color[3], color[4] * (frame.gtSkinAlpha or 1) }
    end
end

function GT.SkinFrame(frame, role)
    frame.gtSkinRole = role
    GT.skinFrames[frame] = true
    PaintFrame(frame)
end

function GT:RegisterSkinUpdater(update)
    self.skinUpdaters[#self.skinUpdaters + 1] = update
end

function GT.RepaintSkin()
    for frame in pairs(GT.skinFrames) do PaintFrame(frame) end
    GT.RepaintText()
    for _, update in ipairs(GT.skinUpdaters) do update() end
end

function GT.SkinExists(key)
    for _, s in ipairs(GT.SKINS) do
        if s.key == key then return true end
    end
    return false
end

function GT.SkinIndex(key)
    for i, s in ipairs(GT.SKINS) do
        if s.key == key then return i end
    end
    return 1
end

-- Copies the skin's colours into GT.colors and repaints every window that is already built.
function GT.ApplySkin(key)
    local skin = GT.SKINS[GT.SkinIndex(key)]
    for k, v in pairs(skin.colors) do GT.colors[k] = copy(v) end
    GT.colors.text = skin.colors.text and copy(skin.colors.text) or nil   -- only some skins set a text colour
    GT.colors.textShadow = skin.colors.textShadow and copy(skin.colors.textShadow) or nil
    GT.RepaintSkin()
    return skin.key
end
