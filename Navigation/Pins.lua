-- Pins.lua
local addonName, GT = ...
local HBDPins = GT.HBDPins
local order = GT.order
local routeState = GT.routeState
local spawnBySid = GT.spawnBySid
local uiRefresh = GT.uiRefresh

local RefreshMenuMouse -- (SyncSpawnPins, ClearSpawns live on GT)

do
    local SPAWN_REF = addonName .. " spawns"
    local spawnPins, pinPool = {}, {}
    local MAX_PINS = 1200
    GT.MAX_SPAWN_PINS = MAX_PINS
    local DOT_SIZE, DOT_ALPHA = 6, 0.5          -- the small dot on world-map pins that have no label
    local DOT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
    local DOT_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"   -- round corners; if the client lacks it the dot stays square

    -- 0 while the HUD's Eagle map hides the Gx labels, else 1 (HUD.lua: HUD.MiniLabelAlpha)
    local function MiniAlpha()
        local h = GT.HUD
        return h and h.MiniLabelAlpha and h.MiniLabelAlpha() or 1
    end

    local function NewPin(parent, size, yoff)
        local fr = CreateFrame("Frame", nil, parent)
        fr:SetSize(size, size)
        fr.tex = fr:CreateTexture(nil, "OVERLAY")
        if parent == Minimap then
            fr.tex:SetAllPoints()                    -- (never shown on the minimap)
        else
            fr.tex:SetTexture(DOT_TEXTURE)
            if fr.tex.SetMask then pcall(fr.tex.SetMask, fr.tex, DOT_MASK) end
            fr.tex:ClearAllPoints()
            fr.tex:SetPoint("CENTER", fr, "CENTER", 0, 0)
            fr.tex:SetSize(DOT_SIZE, DOT_SIZE)
        end
        fr.tex:Hide()
        fr.num = fr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fr.num:SetPoint("TOP", fr, "CENTER", 0, yoff)
        fr.num:SetFont(GT.FontFile("Fonts\\FRIZQT__.TTF"), GT.MapFontSize(GT.cfg().fontMini), "OUTLINE")
        fr.num:Hide()
        if parent == Minimap then
            fr:EnableMouse(false)
        else
            fr:EnableMouse(true)
            fr:SetHitRectInsets(-10, -10, -4, -24)
            -- hover: just the item name, in the resource's colour (right-click still opens the spot menu).
            -- No item link: that needs the item cached and a server request, the name is there at once.
            fr:SetScript("OnEnter", function(self)
                local def = self.key and GT.nodes[self.key]
                if not (def and GameTooltip) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local col = GT.Col(self.key)
                GameTooltip:AddLine(GT.TR(def.label), col[1], col[2], col[3])
                GameTooltip:Show()
            end)
            fr:SetScript("OnLeave", function() GameTooltip:Hide() end)
            fr:SetScript("OnMouseUp", function(self, btn)
                if btn == "RightButton" and self.spot and GT.OpenSpotMenu then
                    GT.OpenSpotMenu(self, self.spot, self.key)
                end
            end)
        end
        return fr
    end

    local function RemoveSpawnPin(sp)
        local p = spawnPins[sp]
        if not p then return end
        if HBDPins then
            if p.miniOn and p.mini then HBDPins:RemoveMinimapIcon(SPAWN_REF, p.mini) end
            HBDPins:RemoveWorldMapIcon(SPAWN_REF, p.world)
        end
        p.miniOn, p.lbl, p.lblMini, p.dot = false, nil, nil, nil
        p.world.num:Hide()                           -- a reused pin must not start with the old label showing
        if p.mini then p.mini.num:Hide(); p.mini:Hide() end
        p.world:Hide()
        spawnPins[sp] = nil
        pinPool[#pinPool + 1] = p
    end

    local function CreateSpawnPin(sp, key)
        local p = table.remove(pinPool)
        if not p then
            p = { world = NewPin(WorldMapFrame:GetCanvas(), 10, -5) }       -- p.mini is created later, only if the minimap needs it
        end
        p.world:Show()                 -- the minimap half is added by SyncSpawnPins (only for the picked / checked nodes)
        p.miniOn = false
        HBDPins:AddWorldMapIconMap(SPAWN_REF, p.world, sp.mapID, sp.x, sp.y, 1)
        spawnPins[sp] = p
    end

    -- short item name for the pin label when "All checked" is picked: "(Pea)" -> "Pea G1"
    local shortName = {}
    local function ShortName(key)
        local s = shortName[key]
        if not s then s = (GT.nodes[key].prefix or key):gsub("[()]", ""); shortName[key] = s end
        return s
    end

    -- Spawn dots are limited to MAX_PINS.  When there are more spots than that, the spots on the map you are on
    -- come first and, inside each group, the nearest ones (GT.PinBefore).  Distance alone was not enough: a spot
    -- on another map can be closer in yards than one on yours.
    -- The tables below are reused: this runs every few seconds.
    local candSp, candKey, candD, candIdx, candOwn = {}, {}, {}, {}, {}
    local PinBefore = GT.PinBefore
    local function ByRank(a, b) return PinBefore(candOwn[a], candD[a], a, candOwn[b], candD[b], b) end

    -- Is a timer running at this spot?  One index per item per sync (see GT.BuildTimerIndex) and one answer per
    -- spot: the question is asked twice per pin below.  Both tables are emptied at the start of every sync.
    local timerIdx, activeAt = {}, {}
    local function TimerAt(key, sp)
        local a = activeAt[sp]
        if a == nil then
            local ix = timerIdx[key]
            if ix == nil then ix = GT.BuildTimerIndex(key) or false; timerIdx[key] = ix end
            a = GT.HasActiveTimerAt(key, sp, ix) and true or false
            activeAt[sp] = a
        end
        return a
    end

    GT.SyncSpawnPins = function()
        if not HBDPins then return end
        for k in pairs(timerIdx) do timerIdx[k] = nil end
        for k in pairs(activeAt) do activeAt[k] = nil end
        local c = GT.cfg()
        local curMap = C_Map.GetBestMapForUnit("player")
        local want, count = {}, 0
        local groupRes = {}
        local multi = GT.ViewMode() == "checked"         -- "All checked": several items on the map, so name them
        if c.showSpawns then
            local nc, old = 0, #candIdx
            for _, key in ipairs(order) do
                -- the WORLD MAP gets every herb / ore; the minimap follows the main-window dropdown (below)
                for _, sp in ipairs(c.zoneOnly and GT.SpawnsOnMap(key, curMap) or GT.spawns[key]) do
                    local gathered = GT.sessionGatheredSpots and GT.sessionGatheredSpots[key]
                    if not (c.hideGatheredSpots and gathered and gathered[sp.sid]) then
                        nc = nc + 1
                        candSp[nc], candKey[nc], candIdx[nc] = sp, key, nc
                    end
                end
            end
            for i = nc + 1, old do candSp[i], candKey[i], candIdx[i], candD[i], candOwn[i] = nil, nil, nil, nil, nil end
            if nc > MAX_PINS then
                -- too many: current map first, then by distance (a spot with no known distance goes last)
                for i = 1, nc do
                    candD[i] = GT.GetDistance(candSp[i]) or math.huge
                    candOwn[i] = (candSp[i].mapID == curMap) and 0 or 1
                end
                table.sort(candIdx, ByRank)
            end
            for j = 1, nc do
                if count >= MAX_PINS then break end
                local i = candIdx[j]
                -- a running timer draws its own text, but only for nodes the dropdown shows
                if not (GT.IsShown(candKey[i]) and TimerAt(candKey[i], candSp[i])) then
                    want[candSp[i]] = candKey[i]
                    count = count + 1
                end
            end
        end
        for sp in pairs(spawnPins) do
            if not want[sp] then RemoveSpawnPin(sp) end
        end
        for sp, key in pairs(want) do
            if not spawnPins[sp] then CreateSpawnPin(sp, key) end
            local p = spawnPins[sp]
            p.world.spot, p.world.key = sp, key
            -- minimap half: only for what the dropdown shows
            local showMini = GT.IsShown(key) and not TimerAt(key, sp)
            if showMini ~= (p.miniOn or false) then
                p.miniOn = showMini
                if showMini then
                    if not p.mini then
                        p.mini = NewPin(Minimap, 8, -10)     -- first time this pin is on the minimap: build the frame now
                        p.styled = nil                       -- so the colour loop below styles the new frame
                    end
                    p.mini:Show()
                    p.mini:SetAlpha(MiniAlpha())
                    HBDPins:AddMinimapIconMap(SPAWN_REF, p.mini, sp.mapID, sp.x, sp.y, false, false)
                elseif p.mini then
                    HBDPins:RemoveMinimapIcon(SPAWN_REF, p.mini)
                    p.mini:Hide()
                end
            end
            if p.mini then p.mini.spot, p.mini.key = sp, key end
            local label, labelMini
            if c.showGroups and GT.IsShown(key) then        -- labels only for what the dropdown shows; the other pins stay hoverable
                local gk = key .. ":" .. sp.mapID
                local g = groupRes[gk] or GT.ComputeGroups(key, sp.mapID)
                groupRes[gk] = g
                if g.of[sp] then
                    label = ShortName(key) .. " G" .. g.of[sp]          -- world map: several items, so always name them
                    labelMini = multi and label or ("G" .. g.of[sp])
                end
            end
            if p.lbl ~= label then
                p.lbl = label
                if label then p.world.num:SetText(label); p.world.num:Show() else p.world.num:Hide() end
            end
            if p.mini and p.lblMini ~= labelMini then
                p.lblMini = labelMini
                if labelMini then p.mini.num:SetText(labelMini); p.mini.num:Show() else p.mini.num:Hide() end
            end
            -- a small see-through dot in the item's colour on every world-map pin that shows no label (the items
            -- you did not pick), so there is something to point at and hover.  Off with cfg.otherDots == false.
            local dot = (c.otherDots ~= false) and not label
            if p.dot ~= dot then
                p.dot = dot
                if dot then p.world.tex:Show() else p.world.tex:Hide() end
            end
            local styled = tostring(GT.cfg().colors[key])
            if p.styled ~= styled then
                p.styled = styled
                local col = GT.Col(key)
                p.world.num:SetTextColor(col[1], col[2], col[3])
                p.world.tex:SetVertexColor(col[1], col[2], col[3], DOT_ALPHA)
                if p.mini then
                    p.mini.tex:Hide()
                    p.mini.num:SetTextColor(col[1], col[2], col[3])
                end
            end
        end
    end

    RefreshMenuMouse = function()
        local map = true   -- world map frames always take the mouse (tooltip + right-click menu); the minimap never does
        for _, key in ipairs(order) do
            for _, n in ipairs(GatherTimesDB[key]) do
                if n._worldFrame then n._worldFrame:EnableMouse(map) end
            end
        end
        for _, p in pairs(spawnPins) do p.world:EnableMouse(map) end
        for _, p in ipairs(pinPool) do p.world:EnableMouse(map) end
    end
    uiRefresh[#uiRefresh + 1] = function() RefreshMenuMouse() end
    GT.RefreshMenuMouse = RefreshMenuMouse      -- called when the Settings checkbox changes

    -- Eagle map: hide / show every Gx label and every (G) timer text on the minimap (see HUD.MiniLabelAlpha)
    function GT.RefreshMiniLabelAlpha()
        local a = MiniAlpha()
        for _, p in pairs(spawnPins) do if p.mini then p.mini:SetAlpha(a) end end
        for _, key in ipairs(order) do
            for _, n in ipairs(GatherTimesDB[key]) do
                if n._miniFrame then n._miniFrame:SetAlpha(a) end
            end
        end
    end

    -- same text size on every pin label (minimap and world map), used pins and pooled ones alike
    function GT.RestylePins()
        local size = GT.cfg().fontMini
        local function style(p)
            if p.mini then p.mini.num:SetFont(GT.FontFile("Fonts\\FRIZQT__.TTF"), GT.MapFontSize(size), "OUTLINE") end
            p.world.num:SetFont(GT.FontFile("Fonts\\FRIZQT__.TTF"), GT.MapFontSize(size), "OUTLINE")
        end
        for _, p in pairs(spawnPins) do style(p) end
        for _, p in ipairs(pinPool) do style(p) end
    end

    GT.ClearSpawns = function()
        for sp in pairs(spawnPins) do RemoveSpawnPin(sp) end
        for _, key in ipairs(order) do wipe(GT.spawns[key]) end
        wipe(spawnBySid)
        GT.cfg().groupStore = {}
        GT.groupRebuild = GT.groupRebuild + 1
        routeState.lastSid = nil
        GT.routeTarget = nil
    end
end

-- ============================================================
-- TOMTOM INTEGRATION
-- ============================================================
