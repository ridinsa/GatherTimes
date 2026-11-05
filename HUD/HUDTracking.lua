-- HUDTracking.lua : the HUD's own tracking button. Part of the HUD module (see HUD.lua).
local addonName, GT = ...
local HUD = GT.HUD

---------------------------------------------------------------------------
-- Tracking button
---------------------------------------------------------------------------

do
    -- The HUD's tracking button.
    --
    -- The HUD draws its OWN tracking button instead of moving Blizzard's. Moving the stock frame cannot be made
    -- reliable next to minimap addons:
    --   * SexyMap fades it ("On Hover") with an alpha animation whose final alpha bypasses SetAlpha, keeps
    --     OnEnter/OnLeave hooks on it, and calls SetParent/SetAlpha through un-hooked method tables.
    --   * BasicMinimap re-parents MiniMapTrackingButton separately from MiniMapTracking.
    --   * ElvUI / Tukui / pfUI / Chinchilla skin, re-anchor or hide it.
    -- Our button is parented to UIParent and nobody else knows it exists, so it works with every minimap addon.
    -- Clicking it opens Blizzard's own tracking dropdown (or an equivalent built from the tracking API).

    local Tracking = {}
    HUD.Tracking = Tracking

    local SIZE     = 31
    local TEX_BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
    local TEX_BG     = "Interface\\Minimap\\UI-Minimap-Background"
    local TEX_HILITE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
    local TEX_NONE   = "Interface\\Icons\\INV_Misc_Map_01"   -- shown (dimmed) while nothing is being tracked

    local button, ownMenu
    local dragging, dragEnd = false, 0

    ---------------------------------------------------------------------------
    -- Tracking API (Classic Era globals first, C_Minimap table API as fallback)
    ---------------------------------------------------------------------------

    local function API()
        local cm = _G.C_Minimap
        return _G.GetNumTrackingTypes or (cm and cm.GetNumTrackingTypes),
               _G.GetTrackingInfo     or (cm and cm.GetTrackingInfo),
               _G.SetTracking         or (cm and cm.SetTracking)
    end

    local function IsOn(v) return v == true or v == 1 end

    -- { { id, name, texture, active }, ... }
    local function ReadTypes()
        local list = {}
        local getNum, getInfo = API()
        if not (getNum and getInfo) then return list end
        local ok, n = pcall(getNum)
        if not ok or type(n) ~= "number" then return list end
        for i = 1, n do
            local ok2, a, b, c = pcall(getInfo, i)
            if ok2 then
                local name, texture, on
                if type(a) == "table" then
                    name, texture, on = a.name, a.texture, a.active
                else
                    name, texture, on = a, b, c
                end
                if name then list[#list + 1] = { id = i, name = name, texture = texture, active = IsOn(on) } end
            end
        end
        return list
    end

    local function ActiveTexture(list)
        if _G.GetTrackingTexture then
            local ok, tex = pcall(_G.GetTrackingTexture)
            if ok and tex then return tex end
        end
        for _, t in ipairs(list) do
            if t.active then return t.texture end
        end
    end

    -- Classic Era has no tracking-type list (GetNumTrackingTypes -> 0 or missing); only the icon of the active
    -- tracking is exposed. The tracking spell is also a buff on the player, so find its name by matching icons.
    -- GetTrackingTexture may return a path ("Interface\\Icons\\Spell_X") while the buff icon is a numeric file ID
    -- (or the other way round), so every icon is reduced to several comparable keys.
    local probe
    local function NormTex(t)
        if t == nil then return nil end
        return (tostring(t):gsub("\\", "/"):lower())
    end

    local function TexKeys(t)
        local keys = {}
        if t == nil then return keys end
        keys[NormTex(t)] = true
        if type(t) == "string" then
            local base = NormTex(t):match("([^/]+)$")
            if base then keys["base:" .. base:gsub("%.blp$", ""):gsub("%.tga$", "")] = true end
            local ct = _G.C_Texture
            if ct and ct.GetFileIDFromPath then
                local ok, id = pcall(ct.GetFileIDFromPath, t)
                if ok and id then keys[tostring(id)] = true end
            end
        end
        -- let the client normalise it: a texture set from a path or an ID reports one consistent value
        if not probe then probe = UIParent:CreateTexture(nil, "BACKGROUND"); probe:Hide() end
        if pcall(probe.SetTexture, probe, t) then
            local got = probe:GetTexture()
            if got ~= nil then
                keys[NormTex(got)] = true
                if type(got) == "string" then
                    local base = NormTex(got):match("([^/]+)$")
                    if base then keys["base:" .. base:gsub("%.blp$", ""):gsub("%.tga$", "")] = true end
                end
            end
        end
        return keys
    end

    local function SameTex(a, b)
        for k in pairs(a) do if b[k] then return true end end
        return false
    end

    -- path-vs-file-ID safe comparison of two icons (used by HUDAutoGather too)
    function HUD.SameTexture(a, b)
        if a == nil or b == nil then return false end
        if a == b then return true end
        return SameTex(TexKeys(a), TexKeys(b))
    end

    -- { { name, icon, spellId }, ... } for the player's buffs
    local function PlayerBuffs()
        local t = {}
        local cu = _G.C_UnitAuras
        for i = 1, 40 do
            local name, icon, spellId
            if cu and cu.GetAuraDataByIndex then
                local ok, d = pcall(cu.GetAuraDataByIndex, "player", i, "HELPFUL")
                if ok and d then name, icon, spellId = d.name, d.icon, d.spellId end
            elseif _G.UnitBuff then
                local ok, n, ic, _, _, _, _, _, _, _, sid = pcall(_G.UnitBuff, "player", i)
                if ok then name, icon, spellId = n, ic, sid end
            end
            if not name then break end
            t[#t + 1] = { name = name, icon = icon, spellId = spellId }
        end
        return t
    end

    -- Tracking abilities are NOT buffs in Classic Era, but the spell is in the spellbook with the same icon.
    -- Calls both the classic globals and the C_SpellBook table API, whichever this client has.
    local spellbookScanned = 0
    local function SpellbookName(want, tex)
        spellbookScanned = 0
        local function visit(name, icon)
            if not (name and icon) then return nil end
            spellbookScanned = spellbookScanned + 1
            if icon == tex or (type(icon) ~= type(tex) and SameTex(want, TexKeys(icon))) then return name end
        end

        -- classic globals
        local getTabs, getTabInfo = _G.GetNumSpellTabs, _G.GetSpellTabInfo
        if getTabs and getTabInfo then
            local nameFn = _G.GetSpellBookItemName or _G.GetSpellName
            local okAll, result = pcall(function()
                for t = 1, getTabs() do
                    local _, _, offset, num = getTabInfo(t)
                    for slot = (offset or 0) + 1, (offset or 0) + (num or 0) do
                        local name = nameFn and nameFn(slot, "spell")
                        local icon = _G.GetSpellTexture and _G.GetSpellTexture(slot, "spell")
                        local h = visit(name, icon)
                        if h then return h end
                    end
                end
            end)
            if okAll and type(result) == "string" then return result end
        end

        -- C_SpellBook table API
        local cs = _G.C_SpellBook
        if cs and cs.GetNumSpellBookSkillLines and cs.GetSpellBookSkillLineInfo
           and cs.GetSpellBookItemName and cs.GetSpellBookItemTexture then
            local bank = (_G.Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
            local okAll, result = pcall(function()
                for line = 1, cs.GetNumSpellBookSkillLines() do
                    local info = cs.GetSpellBookSkillLineInfo(line)
                    if info then
                        local off, num = info.itemIndexOffset or 0, info.numSpellBookItems or 0
                        for i = off + 1, off + num do
                            local h = visit(cs.GetSpellBookItemName(i, bank), cs.GetSpellBookItemTexture(i, bank))
                            if h then return h end
                        end
                    end
                end
            end)
            if okAll and type(result) == "string" then return result end
        end
        return nil
    end

    local nameCache = {}

    local function ActiveName(tex)
        if not tex then return nil end
        local ck = tostring(tex)
        if nameCache[ck] then return nameCache[ck] end
        local want = TexKeys(tex)
        local buffs = PlayerBuffs()
        for _, bf in ipairs(buffs) do
            if bf.icon == tex or SameTex(want, TexKeys(bf.icon)) then nameCache[ck] = bf.name; return bf.name end
        end
        local sb = SpellbookName(want, tex)
        if sb then nameCache[ck] = sb; return sb end
        -- last resort: the one buff that is named like a tracking ability (English client names)
        local found
        for _, bf in ipairs(buffs) do
            if bf.name:find("^Find ") or bf.name:find("^Track ") or bf.name:find("^Sense ") then
                if found then return nil end      -- more than one candidate: don't guess
                found = bf.name
            end
        end
        return found
    end

    -- For /gthud info when the name could not be found: the raw values the client returns
    function Tracking.DebugRaw()
        local tex = _G.GetTrackingTexture and select(2, pcall(_G.GetTrackingTexture))
        HUD.Print(string.format("  tracking texture: %s (%s)", tostring(tex), type(tex)))
        local n = 0
        for _, bf in ipairs(PlayerBuffs()) do
            n = n + 1
            if n <= 12 then
                HUD.Print(string.format("  buff %d: %s  icon=%s (%s)  spell=%s", n, tostring(bf.name), tostring(bf.icon),
                    type(bf.icon), tostring(bf.spellId)))
            end
        end
        if n == 0 then HUD.Print("  (no buffs readable)") end
        if tex then
            nameCache[tostring(tex)] = nil
            local name = ActiveName(tex)
            HUD.Print(string.format("  tracking name: %s  (spellbook entries scanned: %d)", tostring(name), spellbookScanned))
        end
    end

    ---------------------------------------------------------------------------
    -- Menu
    ---------------------------------------------------------------------------

    local function OpenOwnMenu(anchor)
        if not (_G.UIDropDownMenu_Initialize and _G.ToggleDropDownMenu and _G.UIDropDownMenu_AddButton) then return end
        if #ReadTypes() == 0 then return end        -- this client lists no tracking types: an empty menu helps nobody
        if not ownMenu then
            ownMenu = CreateFrame("Frame", "GatherTimesHUDTrackingMenu", UIParent, "UIDropDownMenuTemplate")
        end
        _G.UIDropDownMenu_Initialize(ownMenu, function(_, level)
            for _, t in ipairs(ReadTypes()) do
                local info = _G.UIDropDownMenu_CreateInfo and _G.UIDropDownMenu_CreateInfo() or {}
                info.text = t.name
                info.icon = t.texture
                info.checked = t.active
                info.isNotRadio = true
                info.func = function()
                    local _, _, setTracking = API()
                    if setTracking then pcall(setTracking, t.id, not t.active) end
                    Tracking.Refresh()
                end
                _G.UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")
        _G.ToggleDropDownMenu(1, nil, ownMenu, anchor, 0, -5)
    end

    local function OpenMenu(anchor)
        -- Blizzard's own dropdown is always correct for the running client build
        local dd = _G.MiniMapTrackingDropDown
        if dd and dd.initialize and _G.ToggleDropDownMenu then
            local list = _G.DropDownList1
            local wasOpen = list and list:IsShown() and _G.UIDROPDOWNMENU_OPEN_MENU == dd
            if pcall(_G.ToggleDropDownMenu, 1, nil, dd, anchor, 0, -5) then
                -- closing an already open menu is a success too; otherwise make sure something actually opened
                if wasOpen or not list or list:IsShown() then return end
            end
        end
        OpenOwnMenu(anchor)
    end

    ---------------------------------------------------------------------------
    -- Placement
    ---------------------------------------------------------------------------

    -- Default spot: next to the right edge of the HUD, kept on-screen whatever the HUD size or offset.
    local function DefaultOffset(db)
        local half = math.min(db.size / 2, UIParent:GetWidth() / 2 - db.x)
        return db.x + math.max(0, half - 40), db.y
    end

    local function BtnScale(db)
        return math.max(0.3, (db.trackingSize or 40) / SIZE)
    end

    function Tracking.Place()
        if not button then return end
        local db = HUD.db
        if not db then return end
        local sc = BtnScale(db)
        button:SetScale(sc)
        button:ClearAllPoints()
        -- SetPoint offsets are in the button's own (scaled) units, so divide screen-space offsets by the scale
        if HUD.IsActive() then
            local dx, dy = DefaultOffset(db)
            button:SetPoint("CENTER", UIParent, "CENTER", (dx + (db.trackingX or 0)) / sc, (dy + (db.trackingY or 0)) / sc)
        else
            -- HUD off: default is where Blizzard's button sits (top-left of the minimap); drag it anywhere.
            -- The button stays parented to UIParent, so minimap addons cannot fade or hide it.
            button:SetPoint("CENTER", Minimap, "TOPLEFT", 12 + (db.idleX or 0), -12 + (db.idleY or 0))
        end
    end

    -- Drag. HUD on: only while the HUD is unlocked (/gthud unlock), saved as trackingX/Y.
    --       HUD off: always draggable, saved as idleX/idleY relative to the minimap's top-left.
    local function DragUpdate()
        local db = HUD.db
        if not (db and button) then return end
        local L = HUD.LIMITS
        local cx, cy = GetCursorPosition()
        if HUD.IsActive() then
            local ux, uy = UIParent:GetCenter()
            if not ux then return end
            local scale = UIParent:GetEffectiveScale()
            local dx, dy = DefaultOffset(db)
            db.trackingX = HUD.Clamp(HUD.Round(cx / scale - ux - dx), L.trackingX[1], L.trackingX[2])
            db.trackingY = HUD.Clamp(HUD.Round(cy / scale - uy - dy), L.trackingY[1], L.trackingY[2])
        else
            local left, top = Minimap:GetLeft(), Minimap:GetTop()
            if not left then return end
            local mES, bES = Minimap:GetEffectiveScale(), button:GetEffectiveScale()
            db.idleX = HUD.Clamp(HUD.Round((cx - left * mES) / bES - 12), L.idleX[1], L.idleX[2])
            db.idleY = HUD.Clamp(HUD.Round((cy - top * mES) / bES + 12), L.idleY[1], L.idleY[2])
        end
        Tracking.Place()
    end

    ---------------------------------------------------------------------------
    -- Button
    ---------------------------------------------------------------------------

    local function ShowTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(_G.TRACKING or "Tracking", 1, 1, 1)
        local any = false
        for _, t in ipairs(ReadTypes()) do
            if t.active then GameTooltip:AddLine(t.name, 0.2, 1, 0.2); any = true end
        end
        if not any then
            local tex = ActiveTexture(ReadTypes())
            if tex then
                GameTooltip:AddLine(ActiveName(tex) or "Active", 0.2, 1, 0.2)
            else
                GameTooltip:AddLine(_G.NONE or "None", 0.6, 0.6, 0.6)
            end
        end
        if not HUD.IsActive() then
            GameTooltip:AddLine(GT.TR("Click to choose tracking - drag to move"), 0.8, 0.8, 0.8)
        elseif HUD.IsUnlocked and HUD.IsUnlocked() then
            GameTooltip:AddLine(GT.TR("Drag to move (/gthud lock when done)"), 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(GT.TR("Click to choose tracking"), 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end

    local function EnsureButton()
        if button then return button end
        local b = CreateFrame("Button", "GatherTimesHUDTrackingButton", UIParent)
        b:SetSize(SIZE, SIZE)
        b:SetFrameStrata("HIGH")
        b:SetFrameLevel(50)
        b:SetClampedToScreen(true)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")

        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(TEX_BG)
        bg:SetSize(20, 20)
        bg:SetPoint("TOPLEFT", 7, -5)

        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(17, 17)
        icon:SetPoint("TOPLEFT", 7, -6)
        icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        b.icon = icon

        local border = b:CreateTexture(nil, "OVERLAY")
        border:SetTexture(TEX_BORDER)
        border:SetSize(53, 53)
        border:SetPoint("TOPLEFT")

        b:SetHighlightTexture(TEX_HILITE)

        b:SetScript("OnClick", function(self)
            if dragging or (GetTime() - dragEnd) < 0.15 then return end
            OpenMenu(self)
        end)
        b:SetScript("OnEnter", ShowTooltip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnDragStart", function(self)
            if HUD.IsActive() and not (HUD.IsUnlocked and HUD.IsUnlocked()) then return end
            dragging = true                 -- DragUpdate runs from Tracking.OnUpdate (HUD.OnUpdate)
        end)
        b:SetScript("OnDragStop", function(self)
            if not dragging then return end
            dragging, dragEnd = false, GetTime()
            if HUD.Config then HUD.Config.Refresh() end
        end)
        b:Hide()
        button = b
        return b
    end

    ---------------------------------------------------------------------------
    -- Public
    ---------------------------------------------------------------------------

    function Tracking.Hide()
        if not button then return end
        dragging = false
        button:Hide()
        if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
    end

    -- Show/hide the button and refresh its icon. Safe to call at any time.
    -- HUD on : the HUD's own button.
    -- HUD off: Blizzard's stock button (kept visible, see HUD.ShowStockTracking above), or the HUD's own
    --          button when HUD.UseOwnIdle() says so (SexyMap & co. fade the stock one; /gthud trackmode).
    function Tracking.Update()
        local db = HUD.db
        local wanted = HUD.IsActive() or (HUD.UseOwnIdle and HUD.UseOwnIdle())
        if not (db and db.tracking and wanted) then return Tracking.Hide() end

        local list = ReadTypes()
        local tex = ActiveTexture(list)
        -- Like Blizzard's own button: nothing to show for a character that can't track anything
        if #list == 0 and not tex then return Tracking.Hide() end

        local b = EnsureButton()
        b.icon:SetTexture(tex or TEX_NONE)
        if b.icon.SetDesaturated then b.icon:SetDesaturated(not tex) end
        b.icon:SetAlpha(tex and 1 or 0.55)
        Tracking.Place()
        b:Show()
    end

    -- Tracking changed (MINIMAP_UPDATE_TRACKING etc.)
    function Tracking.Refresh()
        if HUD.IsActive() then return Tracking.Update() end
        if HUD.UseOwnIdle and HUD.UseOwnIdle() then
            return Tracking.Update()      -- the watcher (WatcherTick) keeps the stock button hidden
        end
        Tracking.Hide()
        -- stock button: re-apply a few times because minimap addons change it a moment after we do
        if HUD.ShowStockTracking then
            HUD.ShowStockTracking()
            if C_Timer and C_Timer.After then
                for _, t in ipairs({ 0.1, 0.5, 1.5 }) do C_Timer.After(t, function() HUD.ShowStockTracking() end) end
            end
        end
    end

    -- Called from HUD.OnUpdate (GatherTimes' update loop) on every frame.
    function Tracking.OnUpdate()
        if dragging then DragUpdate() end
    end

    -- For /gthud info
    function Tracking.Describe()
        local list = ReadTypes()
        local tex = ActiveTexture(list)
        local names = {}
        for _, t in ipairs(list) do if t.active then names[#names + 1] = t.name end end
        local x, y = nil, nil
        if button and button:IsShown() then x, y = button:GetCenter() end
        return string.format("own button: %s  types=%d  active=%s  center=%s,%s  strata=%s",
            (button and button:IsShown()) and "shown" or "hidden", #list,
            #names > 0 and table.concat(names, "/") or (tex and (ActiveName(tex) or "?") or "none"),
            tostring(x and HUD.Round(x)), tostring(y and HUD.Round(y)), button and button:GetFrameStrata() or "-")
    end
end
