-- Locales.lua : tiny translation engine.
--   GT.TR("English text")          -> the text in the chosen language (falls back to the English text)
--   GT.TRF("fmt %d", ...)          -> string.format(GT.TR("fmt %d"), ...)
--   GT.IsLang("idID")              -> true when that language is selected
-- Translations live in Locales\<code>.lua and fill GT.locales[code] = { ["English text"] = "translation" }.
-- The language is chosen in Settings > Display (saved in GatherTimesDB._cfg.lang) and applied after a /reload.
local ADDON, GT = ...

GT.locales = GT.locales or {}
GT.LANGS = {                      -- { code, name shown in the Settings > Display dropdown }
    { "enUS", "English (default)" },
    { "deDE", "German" },
    { "frFR", "French" },
    { "itIT", "Italian" },
    { "koKR", "Korean" },
    { "jaJP", "Japanese" },
    { "ruRU", "Russian" },
    { "zhCN", "Chinese (Simplified)" },
    { "zhTW", "Chinese (Traditional)" },
    { "ptBR", "Portuguese (Brazil)" },
    { "esMX", "Spanish (Latin America)" },
    { "esES", "Spanish (Spain)" },
    { "idID", "Bahasa Indonesia" },
    { "suID", "Sundanese" },
}

-- true when code is one of the languages in GT.LANGS
function GT.IsValidLang(code)
    for _, l in ipairs(GT.LANGS) do
        if l[1] == code then return true end
    end
    return false
end

-- Safety: a saved language that is not (or no longer) in GT.LANGS, or a damaged saved value, counts as English.
function GT.Lang()
    local db = _G.GatherTimesDB
    local c = type(db) == "table" and type(db._cfg) == "table" and db._cfg.lang
    if type(c) ~= "string" or not GT.IsValidLang(c) then return "enUS" end
    return c
end

function GT.IsLang(code) return GT.Lang() == code end

-- Languages that have no translation file of their own borrow the text (and font) of a close relative:
-- Chinese (Traditional) shows the Simplified Chinese text, Spanish (Latin America) shows the Spanish (Spain) text.
-- GT.Lang() stays the language the player picked (saved as is); GT.TextLang() is the one whose text is used.
GT.LANG_ALIAS = { zhTW = "zhCN", esMX = "esES" }
function GT.TextLang()
    local c = GT.Lang()
    local a = GT.LANG_ALIAS[c]
    if a and type(GT.locales[a]) == "table" then return a end     -- alias only when its text really loaded
    return c
end

-- Fonts: the default Blizzard font of a Western client may lack glyphs for some selected languages. For languages
-- listed here the add-on's own captions use one of the listed Blizzard fonts instead (the first one that loads).
-- Languages not listed keep the font they already have. English stays the default language.
GT.LANG_FONTS = {
    koKR = { "Fonts\\2002.TTF", "Fonts\\2002B.TTF" },
    zhCN = { "Fonts\\ARHei.TTF", "Fonts\\ARKai_T.TTF", "Fonts\\ARKai_C.TTF" },   -- Simplified Chinese (Hei = clear sans)
    jaJP = { "Fonts\\ARHei.TTF", "Fonts\\ARKai_T.TTF", "Fonts\\ARKai_C.TTF", "Fonts\\2002.TTF" }, -- Japanese glyphs before Korean fallback
    ruRU = { "Fonts\\FRIZQT___CYR.TTF", "Fonts\\FRIZQT__.TTF" },                  -- Cyrillic
}
GT.LANG_FONT_SCALES = { jaJP = 0.82 }
local langFonts = {}                            -- resolved file (or false) per selected text language
function GT.LangFontFile()
    local lang = GT.TextLang()
    local list = GT.LANG_FONTS[lang]
    if not list then return nil end
    if langFonts[lang] == nil then
        langFonts[lang] = false
        local probe = GT.Font(UIParent, nil, "OVERLAY")
        for _, file in ipairs(list) do
            local ok, loaded = pcall(probe.SetFont, probe, file, 12, "")
            if ok and loaded then langFonts[lang] = file; break end
        end
        probe:Hide()
    end
    return langFonts[lang] or nil
end
-- Font styles the player can choose (Settings > Look). Only the built-in client fonts, so every client has them.
-- Languages that need their own font (LANG_FONTS above) do not use this choice.
GT.FONT_CHOICES = {
    { key = "default",  name = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
    { key = "narrow",   name = "Arial Narrow",  file = "Fonts\\ARIALN.TTF" },
    { key = "skurri",   name = "Skurri",        file = "Fonts\\skurri.ttf" },
    { key = "morpheus", name = "Morpheus",      file = "Fonts\\MORPHEUS.TTF" },
    { key = "friends",  name = "Friends",       file = "Fonts\\FRIENDS.TTF" },
}

-- Removes the styles whose font file this client cannot load (the default one is always kept).
function GT.DropUnavailableFonts()
    local probe = UIParent:CreateFontString(nil, "OVERLAY")
    local keep = {}
    for _, f in ipairs(GT.FONT_CHOICES) do
        local ok, loaded = pcall(probe.SetFont, probe, f.file, 12, "")
        if f.key == "default" or (ok and loaded) then keep[#keep + 1] = f end
    end
    probe:Hide()
    GT.FONT_CHOICES = keep
end
function GT.FontChoiceIndex(key)
    for i, f in ipairs(GT.FONT_CHOICES) do
        if f.key == key then return i end
    end
    return 1
end

-- the saved text size (percent, 80-130); 100 when there is none
local function UserFontScale()
    local ok, c = pcall(GT.cfg)
    return (ok and c and c.fontScale or 100) / 100
end

-- GT.FontFile(default) -> the file for the current language if it needs one, else the chosen style, else `default`
function GT.FontFile(default)
    local lang = GT.LangFontFile()
    if lang then return lang end
    local ok, c = pcall(GT.cfg)
    local choice = ok and c and GT.FONT_CHOICES[GT.FontChoiceIndex(c.font)]
    return choice and choice.file or default
end
function GT.FontSize(size)
    return size * (GT.LANG_FONT_SCALES[GT.TextLang()] or 1) * UserFontScale()
end
-- Size for the text drawn on the minimap / world map (timers, spot pins). It keeps the language correction but
-- ignores Settings > Look > Font size: the map text has its own slider (Settings > Display > Map text size).
function GT.MapFontSize(size)
    return size * (GT.LANG_FONT_SCALES[GT.TextLang()] or 1)
end

-- Switch every font string / edit box in a frame tree (the add-on's own frames) to the language font.
-- Does nothing for languages without a special font. Safe to call again: finished strings are skipped.
function GT.ApplyLangFont(frame)
    local file = GT.LangFontFile()
    if not file or not frame then return end
    local function fix(fs)
        if not fs or fs.langFont == file then return end
        fs.langFont = file
        if fs.fitFont then fs.fitFont = file end          -- GT.FitText keeps its own copy of the font
        pcall(function()                                  -- a font problem must never raise an error
            local _, size, flags = fs:GetFont()
            if fs.fitSize then size = fs.fitSize end
            if size then fs:SetFont(file, GT.FontSize(size), flags) end
        end)
    end
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" then fix(r) end
        end
    end
    if frame.GetFontString then fix(frame:GetFontString()) end
    if frame.GetObjectType and frame:GetObjectType() == "EditBox" then fix(frame) end
    if frame.GetChildren then
        for _, c in ipairs({ frame:GetChildren() }) do GT.ApplyLangFont(c) end
    end
end

-- Safety net: a missing / damaged language table, a non-text translation or a translation whose %s / %d do not
-- match the English text never raises an error - the English text is shown instead.
function GT.TR(s)
    if type(s) ~= "string" then return s end
    local t = GT.locales[GT.TextLang()]
    if type(t) ~= "table" then return s end
    local r = t[s]
    if type(r) == "string" and r ~= "" then return r end
    return s
end

function GT.TRF(fmt, ...)
    local ok, r = pcall(string.format, GT.TR(fmt), ...)
    if ok then return r end
    ok, r = pcall(string.format, fmt, ...)                -- translated format is broken: use the English one
    if ok then return r end
    return tostring(fmt)
end

-- "3 items, 2 groups, 5 spots": English needs singular / plural, Indonesian does not
local function S(n, word) return n == 1 and word or word .. "s" end
function GT.CountsText(nItems, nGroups, spots)
    -- only languages that actually have a translation table use the translated format
    if GT.TextLang() ~= "enUS" and type(GT.locales[GT.TextLang()]) == "table" then
        if nItems then return GT.TRF("%d items, %d groups, %d spots", nItems, nGroups, spots) end
        return GT.TRF("%d groups, %d spots", nGroups, spots)
    end
    if nItems then
        return string.format("%d %s, %d %s, %d %s", nItems, S(nItems, "item"), nGroups, S(nGroups, "group"), spots, S(spots, "spot"))
    end
    return string.format("%d %s, %d %s", nGroups, S(nGroups, "group"), spots, S(spots, "spot"))
end
