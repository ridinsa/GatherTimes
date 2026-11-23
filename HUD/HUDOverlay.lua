-- HUDOverlay.lua : rings, compass letters and the heading readout. Part of the HUD module (see HUD.lua).
local _, GT = ...
local HUD = GT.HUD

---------------------------------------------------------------------------
-- Overlay: ring(s), compass letters, heading readout
---------------------------------------------------------------------------

do
    local Overlay = {}
    HUD.Overlay = Overlay

    local frame
    local hasLine = false
    local rings = {}                    -- rings[i] = { segs = {...} }
    local letters = {}                  -- { N, E, S, W } FontStrings
    local ringLabels = {}               -- "40 yd" captions on the rings (yard mode only)
    local lastRadius                    -- map radius in yards the rings were last laid out for (yard mode)
    local radiusAcc = 0
    local headingText
    local priorityText
    local lastFacing
    local lastHeading                    -- whole degree currently shown in headingText
    local elapsedSince = 0
    local priorityElapsed = 0
    local needsTick = false              -- something rotates: HUD.OnUpdate calls Overlay.OnUpdate

    local LETTER_DEFS = {
        { "N", 0,             1.0, 0.25, 0.25 },
        { "E", -math.pi / 2,  1.0, 1.0,  1.0 },
        { "S", math.pi,       1.0, 1.0,  1.0 },
        { "W", math.pi / 2,   1.0, 1.0,  1.0 },
    }
    local CARDINALS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
    local TWO_PI = 2 * math.pi

    local function EnsureFrame()
        if frame then return end
        frame = CreateFrame("Frame", "GatherTimesHUDOverlay", UIParent)
        frame:SetFrameStrata("BACKGROUND")
        frame:SetFrameLevel(5)
        frame:SetPoint("CENTER", Minimap, "CENTER")
        frame:EnableMouse(false)
        hasLine = frame.CreateLine ~= nil

        for i = 1, 2 do
            rings[i] = { segs = {}, k = {} }       -- k: what the pieces were last laid out from (see LayoutRing)
            local lb = GT.Font(frame, nil, "OVERLAY", "GameFontHighlightSmall")
            lb:SetFont(GT.FontFile("Fonts\\FRIZQT__.TTF"), GT.FontSize(11), "OUTLINE")
            lb:Hide()
            ringLabels[i] = lb
        end

        for i, def in ipairs(LETTER_DEFS) do
            local fs = GT.Font(frame, nil, "OVERLAY", "GameFontNormalLarge")
            fs:SetText(def[1])
            fs:SetTextColor(def[3], def[4], def[5], 1)
            letters[i] = fs
        end
        headingText = GT.Font(frame, nil, "OVERLAY", "GameFontNormal")
        headingText:SetTextColor(1, 1, 1, 1)
        priorityText = GT.Font(frame, nil, "OVERLAY", "GameFontNormal")
        priorityText:SetFont(GT.FontFile("Fonts\\FRIZQT__.TTF"), GT.FontSize(14), "OUTLINE")
        priorityText:SetWidth(760)
        priorityText:SetJustifyH("CENTER")
        priorityText:SetWordWrap(false)
        priorityText:SetTextColor(1, 1, 1, 1)
        priorityText:Hide()
    end

    ---------------------------------------------------------------------------
    -- Rings
    ---------------------------------------------------------------------------

    local function HideSegs(ring, from)
        for i = from, #ring.segs do ring.segs[i]:Hide() end
    end

    -- which of the seg pieces are drawn. n = density: the number of stripe blocks (on and off alternate, so half
    -- of them are drawn) or the number of dots, spread evenly around the ring. "solid" draws every piece.
    local function Drawn(style, i, seg, n)
        if style == "stripes" then return math.floor((i - 1) * n / seg) % 2 == 0 end
        if style == "dots" then return ((i - 1) * n) % seg < n end
        return true
    end

    -- Everything LayoutRing draws from is kept in ring.k and compared field by field. If nothing differs, the
    -- pieces are already right. (This used to build a key string with string.format + table.concat on every call.)
    local function SameLayout(k, radius, seg, thick, color, style, density)
        return k.radius == radius and k.seg == seg and k.thick == thick and k.style == style
            and k.density == density and k.hasLine == hasLine
            and k.r == (color[1] or 0) and k.g == (color[2] or 0) and k.b == (color[3] or 0) and k.a == (color[4] or 0)
    end

    -- color: one {r, g, b, a}. Both rings are drawn in a single colour (the old colour list only ever had one entry).
    local function LayoutRing(ring, radius, seg, thick, color, style, density)
        local k = ring.k
        if radius <= 0 then HideSegs(ring, 1); k.radius = nil; return end
        style = style or "solid"
        density = density or 24
        if SameLayout(k, radius, seg, thick, color, style, density) then return end
        k.radius, k.seg, k.thick, k.style, k.density, k.hasLine = radius, seg, thick, style, density, hasLine
        k.r, k.g, k.b, k.a = color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0
        local step = TWO_PI / seg
        local n = math.max(1, math.min(seg, density))

        if hasLine then
            -- seg straight pieces joining points on the circle; a dot is a short piece (0.3 of a step)
            while #ring.segs < seg do ring.segs[#ring.segs + 1] = frame:CreateLine(nil, "OVERLAY") end
            for i = 1, seg do
                local l = ring.segs[i]
                local a1, a2 = (i - 1) * step, i * step
                if style == "dots" then a2 = a1 + step * 0.3 end
                if Drawn(style, i, seg, n) then
                    l:SetThickness(thick)
                    l:SetColorTexture(color[1], color[2], color[3], color[4])
                    l:SetStartPoint("CENTER", frame, radius * math.cos(a1), radius * math.sin(a1))
                    l:SetEndPoint("CENTER", frame, radius * math.cos(a2), radius * math.sin(a2))
                    l:Show()
                else
                    l:Hide()
                end
            end
        else
            -- fallback for clients without Line objects: one small square per drawn piece
            while #ring.segs < seg do ring.segs[#ring.segs + 1] = frame:CreateTexture(nil, "OVERLAY") end
            for i = 1, seg do
                local t = ring.segs[i]
                local a = (i - 1) * step
                if Drawn(style, i, seg, n) then
                    t:SetSize(thick, thick)
                    t:SetColorTexture(color[1], color[2], color[3], color[4])
                    t:ClearAllPoints()
                    t:SetPoint("CENTER", frame, "CENTER", radius * math.cos(a), radius * math.sin(a))
                    t:Show()
                else
                    t:Hide()
                end
            end
        end
        HideSegs(ring, seg + 1)
    end

    ---------------------------------------------------------------------------
    -- Compass letters + heading
    ---------------------------------------------------------------------------

    -- Ring radius on screen, in pixels. In pixel mode it is the saved value. In yard mode it is the saved yards
    -- scaled by what the map shows right now (yards from centre to edge = half the HUD), so the ring keeps its real
    -- distance at any HUD size or zoom. A ring farther out than the map sees is not drawn (returns 0).
    local function RingPx(db, index, radiusYd)
        if db.ringUnit ~= "yd" then return index == 1 and db.ring or db.ring2 end
        local yd = index == 1 and db.ringYd or db.ring2Yd
        if not yd or yd <= 0 then return 0 end
        local half = HUD.EffectiveSize(db) / 2
        local px = yd / (radiusYd or HUD.MapRadiusYards()) * half
        if px > half then return 0 end
        return px
    end

    local function LetterRadius(db)
        local size = HUD.EffectiveSize(db)
        local half = size / 2
        local ring = RingPx(db, 1)
        local r = (ring > 0) and (ring + 16) or (size * 0.3)
        return math.min(r, half - 12)
    end

    local function RingColorOf(index)
        return index == 1 and HUD.db.ringColor or HUD.db.ringColor2
    end

    -- "40 yd" caption: SetText (and the translation + format behind it) only when the number changed.
    local function SetCaption(lb, yd)
        if lb.yd ~= yd then
            lb.yd = yd
            lb:SetText(GT.TRF("%d yd", yd))
        end
    end

    -- Both rings (and their yard captions). Cheap when nothing changed: LayoutRing skips an unchanged ring.
    local function LayoutRings(db)
        local half = HUD.EffectiveSize(db) / 2
        local seg = math.max(8, math.min(256, db.ringSegments))
        local thick = math.max(1, db.ringThickness)
        local yards = db.ringUnit == "yd"
        local caps = db.scaleCaps                -- Eagle map: pixel rings captioned with the yards they stand for
        local radiusYd = (yards or caps) and HUD.MapRadiusYards() or nil
        lastRadius = radiusYd
        for i = 1, 2 do
            local px = math.min(RingPx(db, i, radiusYd), half)
            local c = RingColorOf(i)
            LayoutRing(rings[i], px, seg, thick, c, db.ringStyle, db.ringDensity)
            local lb = ringLabels[i]
            if yards and px > 0 then
                SetCaption(lb, math.floor((i == 1 and db.ringYd or db.ring2Yd) + 0.5))
                lb:SetTextColor(c[1], c[2], c[3], 1)
                lb:ClearAllPoints()
                lb:SetPoint("CENTER", frame, "CENTER", px * 0.7071, px * 0.7071)    -- upper right of the ring
                lb:Show()
            elseif caps and (i == 2 or half > 2) and (i == 1 or px > 0) then
                -- ring 1 is the edge of the map (captioned even when its line is switched off), ring 2 the half-way ring
                local capPx = i == 1 and (half - 2) or px
                SetCaption(lb, math.floor(capPx / half * radiusYd + 0.5))
                lb:SetTextColor(c[1], c[2], c[3], 1)
                lb:ClearAllPoints()
                lb:SetPoint("CENTER", frame, "CENTER", capPx * 0.7071, capPx * 0.7071)
                lb:Show()
            else
                lb:Hide()
            end
        end
    end

    -- facing: radians, 0 = north, increasing counter-clockwise (GetPlayerFacing)
    local function PlaceLetters(db, facing)
        local r = LetterRadius(db)
        -- North sits at screen angle (pi/2 - facing) when the map rotates with the player.
        local north = math.pi / 2 - facing
        for i, def in ipairs(LETTER_DEFS) do
            local a = north + def[2]
            -- same anchor point every time, so SetPoint replaces it: no ClearAllPoints per letter per tick
            letters[i]:SetPoint("CENTER", frame, "CENTER", r * math.cos(a), r * math.sin(a))
        end
    end

    -- The readout only ever shows a whole degree (0..359), so each text is built once, the first time that degree is
    -- shown, and kept (at most 360 short strings, filled in as you turn). The cardinal letter depends on the
    -- rounded degree alone: the 45-degree borders fall on half degrees, exactly where the rounding flips.
    local headingStrings = {}

    local function HeadingString(r)
        local text = headingStrings[r]
        if not text then
            text = string.format("%s %d\194\176", CARDINALS[math.floor((r + 22.5) / 45) % 8 + 1], r)
            headingStrings[r] = text
        end
        return text
    end

    local function UpdateHeading(db, facing)
        local deg = (TWO_PI - facing) % TWO_PI * 180 / math.pi          -- compass bearing, clockwise from north
        local r = math.floor(deg + 0.5) % 360
        if r ~= lastHeading then
            lastHeading = r
            headingText:SetText(HeadingString(r))
        end
    end

    local function Tick()
        local db = HUD.Cfg()
        local real = (GetPlayerFacing and GetPlayerFacing()) or 0
        if lastFacing and math.abs(real - lastFacing) < 0.002 then return end
        lastFacing = real
        if db.dirs then PlaceLetters(db, db.rotate and real or 0) end
        if db.heading then UpdateHeading(db, real) end
    end

    -- The closest ready node and the closest waiting node on this map. The two result tables are reused, so
    -- scanning every saved node allocates nothing (it used to build a candidate table per node plus a closure).
    local readyBest, waitBest = {}, {}

    local function FindPriorityTimer(now, mapID)
        local c = GT.cfg()
        local haveReady, haveWait = false, false
        local readyDist, waitDist = math.huge, math.huge
        local readyLinger = c.readyLinger or GT.READY_LINGER or 120
        for _, key in ipairs(GT.order) do
            if GT.IsShown(key) then
                local def = GT.nodes[key]
                local list = GatherTimesDB[key]
                if list then
                    for i = 1, #list do
                        local node = list[i]
                        if node.mapID == mapID and (not c.groupMode or node._primary ~= false) then
                            local left = def.timer - (now - node.time)
                            if left > -readyLinger then
                                local distance = GT.GetDistance(node)
                                if distance and distance < 0 then distance = nil end
                                local d = distance or math.huge
                                if left <= 0 then
                                    if not haveReady or d < readyDist then
                                        haveReady, readyDist = true, d
                                        readyBest.key, readyBest.left, readyBest.distance = key, left, distance
                                    end
                                elseif not haveWait or d < waitDist then
                                    haveWait, waitDist = true, d
                                    waitBest.key, waitBest.left, waitBest.distance = key, left, distance
                                end
                            end
                        end
                    end
                end
            end
        end
        if haveReady then return readyBest end
        if haveWait then return waitBest end
        return nil
    end

    -- What the readout was last built from. Every number is compared first; the text (translation lookups,
    -- concatenation, string.format) is only built, and SetText only called, when one of them is different.
    -- Standing still next to a READY node therefore costs nothing; a countdown rebuilds once a second.
    local sig = { valid = false }

    local function UpdatePriorityText()
        local cfg = HUD.Cfg()
        local route = GT.UI and GT.UI.RouteOptimizer
        local routeInfo = cfg.routeReadout and route and route.GetGuidanceInfo and route:GetGuidanceInfo()
        local rKey, rStep, rTotal, rDist
        if routeInfo then
            rKey, rStep, rTotal = routeInfo.key, routeInfo.step, routeInfo.total
            rDist = routeInfo.distance and math.floor(routeInfo.distance) or nil
        end

        local pKey, pLeft, pDist            -- pLeft: whole seconds to go, nil = ready
        if cfg.priorityReadout then
            local mapID = C_Map.GetBestMapForUnit("player")
            local candidate = mapID and FindPriorityTimer(GetServerTime(), mapID)
            if candidate then
                pKey = candidate.key
                pDist = candidate.distance and math.floor(candidate.distance) or nil
                if candidate.left > 0 then pLeft = math.floor(candidate.left) end
            end
        end

        if sig.valid and sig.rKey == rKey and sig.rStep == rStep and sig.rTotal == rTotal and sig.rDist == rDist
           and sig.pKey == pKey and sig.pLeft == pLeft and sig.pDist == pDist then
            return
        end
        sig.valid = true
        sig.rKey, sig.rStep, sig.rTotal, sig.rDist = rKey, rStep, rTotal, rDist
        sig.pKey, sig.pLeft, sig.pDist = pKey, pLeft, pDist

        local text
        if rKey then
            local routeDef = GT.nodes[rKey]
            local label = routeDef and routeDef.label or tostring(rKey)
            local distance = rDist and (" - " .. GT.TRF("%d yd", rDist)) or ""
            text = GT.TR("Route:") .. " " .. rStep .. "/" .. rTotal .. ": " .. label .. distance
        end
        if pKey then
            local def = GT.nodes[pKey]
            local distance = pDist and (" - " .. GT.TRF("%d yd", pDist)) or ""
            local line
            if not pLeft then
                line = "|cff00ff00" .. GT.TR("READY") .. "|r: " .. def.label .. distance
            else
                line = string.format("%s %d:%02d%s", def.label, math.floor(pLeft / 60), pLeft % 60, distance)
            end
            text = text and (text .. "\n" .. line) or line
        end
        if not text then priorityText:Hide(); return end
        priorityText:SetText(text)
        priorityText:Show()
    end

    -- Called from HUD.OnUpdate (GatherTimes' update loop) on every frame.
    function Overlay.OnUpdate(dt)
        if not (frame and frame:IsShown()) then return end
        local cfg = HUD.Cfg()
        if cfg.ringUnit == "yd" or cfg.scaleCaps then
            -- the map's reach changes with zoom and indoors / outdoors: re-lay the rings when it does
            radiusAcc = radiusAcc + dt
            if radiusAcc >= 0.25 * HUD.PerfSlow() then
                radiusAcc = 0
                if HUD.MapRadiusYards() ~= lastRadius then LayoutRings(cfg) end
            end
        end
        if cfg.priorityReadout or cfg.routeReadout then
            priorityElapsed = priorityElapsed + dt
            local every = HUD.PerfSlow()
            if priorityElapsed >= every then
                priorityElapsed = priorityElapsed % every
                UpdatePriorityText()
            end
        elseif priorityText:IsShown() then
            priorityText:Hide()
        end
        if needsTick then
            elapsedSince = elapsedSince + dt
            if elapsedSince >= 0.03 * HUD.PerfTick() then
                elapsedSince = 0
                Tick()
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Public API
    ---------------------------------------------------------------------------

    function Overlay.RingColors(index)
        return { index == 1 and HUD.db.ringColor or HUD.db.ringColor2 }
    end

    function Overlay.RingColor(index)
        return Overlay.RingColors(index)[1]
    end

    function Overlay.Update()
        local db = HUD.Cfg()
        if not db then return end
        EnsureFrame()
        local size = HUD.EffectiveSize(db)
        frame:SetSize(size, size)
        priorityText:SetWidth(math.max(80, size - 24))
        priorityText:ClearAllPoints()
        priorityText:SetPoint("CENTER", frame, "CENTER", 0,
            -math.min(LetterRadius(db) + 26, size / 2 - 20))

        local half = size / 2
        -- settings, language or fonts may have changed: let the captions and the readout rebuild their text once
        for i = 1, 2 do ringLabels[i].yd = nil end
        sig.valid = false
        LayoutRings(db)

        for i = 1, 4 do letters[i]:SetShown(db.dirs and true or false) end
        headingText:SetShown(db.heading and true or false)
        headingText:ClearAllPoints()
        headingText:SetPoint("CENTER", frame, "CENTER", 0, math.min(LetterRadius(db) + 30, half - 12))
        if db.priorityReadout or db.routeReadout then
            UpdatePriorityText()
        else
            priorityText:Hide()
        end

        -- Only tick when something actually rotates
        lastFacing, lastHeading = nil, nil
        priorityElapsed = HUD.PerfSlow()
        needsTick = ((db.dirs and db.rotate) or db.heading) and true or false
        if needsTick then
            Tick()
        elseif db.dirs then
            PlaceLetters(db, 0)                         -- static north-up letters
        end
        frame:SetShown(not HUD.Faded())
    end

    function Overlay.Hide()
        needsTick = false
        sig.valid = false
        if priorityText then priorityText:Hide() end
        if frame then frame:Hide() end
    end

    function Overlay.SetShown(shown)
        if frame then frame:SetShown(shown and true or false) end
    end
end
