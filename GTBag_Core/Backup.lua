-- Backup.lua : export your nicknames, custom categories and junk keep list as plain text, and import such text on
-- another install or after a reinstall.  Open with /gtbag backup.  Importing only adds; nothing is deleted.
--
--   # GTBag backup v1
--   nick Name-Realm = Nickname
--   cat Alchemy = silverleaf, 2447
--   keep 2589  # Linen Cloth
--   pin 2447  # Peacebloom
--   hide 2589  # Linen Cloth           (hidden everywhere)
--   hideslot 0:5 Name-Realm            (hidden inventory slot: bag:slot)
--   charopt hideInCombat on Name-Realm
local _, ns = ...

local UI = ns.UI
local MAX_TEXT, MAX_LINES = 200000, 5000

-- ---------------------------------------------------------------------------------------------- export
function ns.BackupExport()
    local out = {
        "# GTBag backup v1",
        "# Paste this into /gtbag backup on another install (or after a reinstall) and press Import.",
        "",
    }

    -- nicknames: known characters first, then ones still waiting for their character to log in here
    local seen = {}
    for _, key in ipairs(ns.CharKeys()) do
        local nick = ns.GetNick(key)
        if nick then
            out[#out + 1] = "nick " .. key .. " = " .. nick
            seen[key] = true
        end
    end
    local pending = GTBagDB and GTBagDB.pendingNicks
    if type(pending) == "table" then
        local keys = {}
        for key, nick in pairs(pending) do
            if not seen[key] and type(key) == "string" and type(nick) == "string" then keys[#keys + 1] = key end
        end
        table.sort(keys)
        for _, key in ipairs(keys) do out[#out + 1] = "nick " .. key .. " = " .. pending[key] end
    end

    out[#out + 1] = ""
    for _, c in ipairs(ns.CustomCats()) do
        local parts = {}
        for _, rule in ipairs(type(c.rules) == "table" and c.rules or {}) do parts[#parts + 1] = tostring(rule) end
        out[#out + 1] = "cat " .. tostring(c.name) .. " =" .. (#parts > 0 and (" " .. table.concat(parts, ", ")) or "")
    end

    out[#out + 1] = ""
    for _, id in ipairs(ns.JunkKeepList()) do
        local name = ns.GetItemInfo(id)
        out[#out + 1] = "keep " .. id .. (name and ("  # " .. name) or "")
    end
    out[#out + 1] = ""
    for _, id in ipairs(ns.PinList()) do
        local name = ns.GetItemInfo(id)
        out[#out + 1] = "pin " .. id .. (name and ("  # " .. name) or "")
    end
    -- items hidden everywhere, hidden inventory slots (per character) and per-character options
    out[#out + 1] = ""
    for _, id in ipairs(ns.panel.HiddenItemList()) do
        local name = ns.GetItemInfo(id)
        out[#out + 1] = "hide " .. id .. (name and ("  # " .. name) or "")
    end
    out[#out + 1] = ""
    for _, e in ipairs(ns.panel.HiddenSlotList()) do
        out[#out + 1] = "hideslot " .. e[2] .. ":" .. e[3] .. " " .. e[1]
    end
    out[#out + 1] = ""
    for _, e in ipairs(ns.CharOptList()) do
        out[#out + 1] = "charopt " .. e[2] .. " " .. (e[3] and "on" or "off") .. " " .. e[1]
    end
    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------------------------- import
-- returns ok, message
function ns.BackupImport(text)
    text = tostring(text or "")
    if #text > MAX_TEXT then return false, "that text is too long to be a GTBag backup." end
    local flat = text:gsub("\r", "\n")
    local n = { nick = 0, pending = 0, cat = 0, keep = 0, pin = 0, hide = 0, hideslot = 0, charopt = 0, bad = 0 }
    local problems, lineCount = {}, 0
    local function Bad(why)
        n.bad = n.bad + 1
        if #problems < 3 then problems[#problems + 1] = why end
    end

    for line in flat:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            lineCount = lineCount + 1
            if lineCount > MAX_LINES then Bad("too many lines; the rest was ignored."); break end
            local kind, rest = line:match("^(%a+)%s*(.*)$")
            kind = kind and kind:lower()
            if kind == "nick" then
                local key, nick = rest:match("^(.-)%s+=%s+(.*)$")
                if not key then
                    Bad('could not read "' .. line:sub(1, 30) .. '"')
                elseif nick ~= "" then
                    local result = ns.ImportNick(key, nick)
                    if result == "set" then n.nick = n.nick + 1
                    elseif result == "pending" then n.nick = n.nick + 1; n.pending = n.pending + 1
                    else Bad('bad nickname line "' .. line:sub(1, 30) .. '"') end
                end
            elseif kind == "cat" then
                local name, rules = rest:match("^(.-)%s+=%s+(.*)$")
                if not name then
                    name = rest:match("^(.-)%s+=$")
                    rules = ""
                end
                if not name then
                    Bad('could not read "' .. line:sub(1, 30) .. '"')
                else
                    local ok, msg
                    if rules == "" then ok, msg = ns.CatCreate(name) else ok, msg = ns.CatSave(name, rules) end
                    if ok then n.cat = n.cat + 1 else Bad(name:sub(1, 24) .. ": " .. tostring(msg)) end
                end
            elseif kind == "keep" then
                local id = tonumber(rest:match("^(%d+)"))
                if id and id >= 1 and id <= 99999999 then
                    ns.JunkSetKeep(id, true)
                    n.keep = n.keep + 1
                else
                    Bad('bad item id in "' .. line:sub(1, 30) .. '"')
                end
            elseif kind == "pin" then
                local id = tonumber(rest:match("^(%d+)"))
                if id and ns.SetPinned(id, true) then
                    n.pin = n.pin + 1
                else
                    Bad('bad pin line "' .. line:sub(1, 30) .. '"')
                end
            elseif kind == "hide" then
                local id = tonumber(rest:match("^(%d+)"))
                if id and ns.panel.SetItemHidden(id, true) then
                    n.hide = n.hide + 1
                else
                    Bad('bad hide line "' .. line:sub(1, 30) .. '"')
                end
            elseif kind == "hideslot" then
                local bag, slot, key = rest:match("^(-?%d+):(%d+)%s+(.+)$")
                if bag and ns.panel.ImportHiddenSlot(key, bag, slot) then
                    n.hideslot = n.hideslot + 1
                else
                    Bad('bad hideslot line "' .. line:sub(1, 30) .. '"')
                end
            elseif kind == "charopt" then
                local opt, state, key = rest:match("^(%S+)%s+(%S+)%s+(.+)$")
                state = state and state:lower()
                if opt and (state == "on" or state == "off") and ns.ImportCharOpt(key, opt, state == "on") then
                    n.charopt = n.charopt + 1
                else
                    Bad('bad charopt line "' .. line:sub(1, 30) .. '"')
                end
            else
                Bad('unknown line "' .. line:sub(1, 30) .. '"')
            end
        end
    end

    if ns.Relayout then ns.Relayout() end
    if ns.RefreshCatEditor then pcall(ns.RefreshCatEditor) end

    local done = {}
    if n.nick > 0 then
        local t = n.nick .. " nickname" .. (n.nick == 1 and "" or "s")
        if n.pending > 0 then t = t .. " (" .. n.pending .. " waiting for that character to log in here)" end
        done[#done + 1] = t
    end
    if n.cat > 0 then done[#done + 1] = n.cat .. " categor" .. (n.cat == 1 and "y" or "ies") end
    if n.keep > 0 then done[#done + 1] = n.keep .. " keep-list item" .. (n.keep == 1 and "" or "s") end
    if n.pin > 0 then done[#done + 1] = n.pin .. " pinned item" .. (n.pin == 1 and "" or "s") end
    if n.hide > 0 then done[#done + 1] = n.hide .. " hidden item" .. (n.hide == 1 and "" or "s") end
    if n.hideslot > 0 then done[#done + 1] = n.hideslot .. " hidden slot" .. (n.hideslot == 1 and "" or "s") end
    if n.charopt > 0 then done[#done + 1] = n.charopt .. " character setting" .. (n.charopt == 1 and "" or "s") end
    if n.pin > 0 and ns.RefreshPins then ns.RefreshPins() end
    local msg
    if #done > 0 then msg = "imported " .. table.concat(done, ", ") .. "."
    else msg = "nothing imported. Paste text made by Export first." end
    if n.bad > 0 then
        msg = msg .. " Skipped " .. n.bad .. " line" .. (n.bad == 1 and "" or "s") .. ": " .. table.concat(problems, "; ")
    end
    return #done > 0, msg
end

-- ---------------------------------------------------------------------------------------------- window
local win, edit, status

local function Fill()
    edit:SetText(ns.BackupExport())
    edit:SetCursorPosition(0)
end

local function Build()
    local PAD = UI.PAD
    local W, H = 540, 400
    win = UI.Window("GTBagBackupFrame", W, H, "GTBag backup / restore")

    local help = UI.Label(win, "Export lists your nicknames, custom categories, junk keep list, pinned items, hidden items and slots, and per-character settings. To restore them on "
        .. "another install or after a reinstall, paste the text here and press Import. Importing only adds; "
        .. "nothing is deleted.")
    help:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -42)
    help:SetWidth(W - 2 * PAD)
    help:SetJustifyH("LEFT")
    if help.SetWordWrap then help:SetWordWrap(true) end

    local panel = CreateFrame("Frame", nil, win, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -8)     -- below the help text, however many lines it wraps to
    panel:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 62)
    if panel.SetBackdrop then
        panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        panel:SetBackdropColor(0.03, 0.03, 0.03, 0.95)
        panel:SetBackdropBorderColor(0.24, 0.25, 0.28, 1)
    end

    local scroll = CreateFrame("ScrollFrame", "GTBagBackupScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)

    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetMaxLetters(MAX_TEXT)
    edit:SetWidth(W - 2 * PAD - 36)
    edit:SetHeight(260)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnTextChanged", function(self)
        local _, lines = (self:GetText() or ""):gsub("\n", "\n")
        self:SetHeight(math.max(260, (lines + 1) * 14 + 10))
    end)
    scroll:SetScrollChild(edit)
    scroll:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then edit:SetWidth(w) end end)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)

    status = UI.Label(win, "")
    status:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, 38)
    status:SetWidth(W - 2 * PAD)
    status:SetJustifyH("LEFT")
    if status.SetWordWrap then status:SetWordWrap(true) end

    local exportBtn = UI.Button(win, "Export", 80)
    exportBtn:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, 10)
    exportBtn:SetScript("OnClick", function()
        Fill()
        edit:SetFocus()
        edit:HighlightText()
        status:SetText("Press Ctrl+C to copy the selected text.")
    end)
    local importBtn = UI.Button(win, "Import", 80)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
    importBtn:SetScript("OnClick", function()
        local ok, msg = ns.BackupImport(edit:GetText())
        status:SetText((ok and "|cff44dd44" or "|cffffd100") .. msg .. "|r")
        print("|cffffd100GTBag|r: " .. msg)
    end)

    win:SetScript("OnShow", function() Fill(); status:SetText("") end)
end

function ns.ShowBackup()
    if not win then Build() end
    if win:IsShown() then win:Hide() end     -- OnShow refills, so a second command refreshes the text
    win:Show()
end
