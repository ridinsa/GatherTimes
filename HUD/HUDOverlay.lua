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
            rings[i] = { segs = {} }
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

    -- Everything LayoutRing draws from, as one string. If it matches the last layout, the pieces are already right.
    local function RingKey(radius, seg, thick, colors, style, density)
        local parts = { radius, seg, thick, style or "solid", density or 24, hasLine and 1 or 0, #colors }
        for _, c in ipairs(colors) do
            parts[#parts + 1] = string.format("%.3f,%.3f,%.3f,%.3f", c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0)
        end
        return table.concat(parts, "|")
    end

    local function LayoutRing(ring, radius, seg, thick, colors, style, density)
        if radius <= 0 then HideSegs(ring, 1); ring.key = nil; return end
        local key = RingKey(radius, seg, thick, colors, style, density)
        if ring.key == key then return end
        ring.key = key
        local step = TWO_PI / seg
        style = style or "solid"
        local n = math.max(1, math.min(seg, density or 24))

        if hasLine then
            -- seg straight pieces joining points on the circle; a dot is a short piece (0.3 of a step)
            while #ring.segs < seg do ring.segs[#ring.segs + 1] = frame:CreateLine(nil, "OVERLAY") end
            for i = 1, seg do
                local l = ring.segs[i]
                local a1, a2 = (i - 1) * step, i * step
                if style == "dots" then a2 = a1 + step * 0.3 end
                if Drawn(style, i, seg, n) then
                    local color = colors[math.min(#colors, math.floor((i - 1) * #colors / seg) + 1)]
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
                    local color = colors[math.min(#colors, math.floor((i - 1) * #colors / seg) + 1)]
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
            LayoutRing(rings[i], px, seg, thick, Overlay.RingColors(i), db.ringStyle, db.ringDensity)
            local lb = ringLabels[i]
            if yards and px > 0 then
                local c = Overlay.RingColor(i)
                lb:SetText(GT.TRF("%d yd", math.floor((i == 1 and db.ringYd or db.ring2Yd) + 0.5)))
                lb:SetTextColor(c[1], c[2], c[3], 1)
                lb:ClearAllPoints()
                lb:SetPoint("CENTER", frame, "CENTER", px * 0.7071, px * 0.7071)    -- upper right of the ring
                lb:Show()
            elseif caps and (i == 2 or half > 2) and (i == 1 or px > 0) then
                -- ring 1 is the edge of the map (captioned even when its line is switched off), ring 2 the half-way ring
                local capPx = i == 1 and (half - 2) or px
                local c = Overlay.RingColor(i)
                lb:SetText(GT.TRF("%d yd", math.floor(capPx / half * radiusYd + 0.5)))
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
            letters[i]:ClearAllPoints()
            letters[i]:SetPoint("CENTER", frame, "CENTER", r * math.cos(a), r * math.sin(a))
        end
    end

    local function UpdateHeading(db, facing)
        local deg = (TWO_PI - facing) % TWO_PI * 180 / math.pi          -- compass bearing, clockwise from north
        local idx = math.floor((deg + 22.5) / 45) % 8 + 1
        headingText:SetText(string.format("%s %d\194\176", CARDINALS[idx], math.floor(deg + 0.5) % 360))
    end

    local function Tick()
        local db = HUD.Cfg()
        local real = (GetPlayerFacing and GetPlayerFacing()) or 0
        if lastFacing and math.abs(real - lastFacing) < 0.002 then return end
        lastFacing = real
        if db.dirs then PlaceLetters(db, db.rotate and real or 0) end
        if db.heading then UpdateHeading(db, real) end
    end

    local function FindPriorityTimer(now, mapID)
        local c = GT.cfg()
        local ready, waiting
        local readyLinger = c.readyLinger or GT.READY_LINGER or 120
        local function IsCloser(candidate, best)
            if not best then return true end
            return (candidate.distance or math.huge) < (best.distance or math.huge)
        end
        for _, key in ipairs(GT.order) do
            if GT.IsShown(key) then
                local def = GT.nodes[key]
                for _, node in ipairs(GatherTimesDB[key] or {}) do
                    if node.mapID == mapID and not (c.groupMode and node._primary == false) then
                        local left = def.timer - (now - node.time)
                        if left > -readyLinger then
                            local distance = GT.GetDistance(node)
                            if distance and distance < 0 then distance = nil end
                            local candidate = { key = key, left = left, distance = distance }
                            if left <= 0 then
                                if IsCloser(candidate, ready) then ready = candidate end
                            elseif IsCloser(candidate, waiting) then
                                waiting = candidate
                            end
                        end
                    end
                end
            end
        end
        return ready or waiting
    end

    local function UpdatePriorityText()
        local lines = {}
        local route = GT.UI and GT.UI.RouteOptimizer
        local cfg = HUD.Cfg()
        local routeInfo = cfg.routeReadout and route and route.GetGuidanceInfo and route:GetGuidanceInfo()
        if routeInfo then
            local routeDef = GT.nodes[routeInfo.key]
            local label = routeDef and routeDef.label or tostring(routeInfo.key)
            local distance = routeInfo.distance and (" - " .. GT.TRF("%d yd", math.floor(routeInfo.distance))) or ""
            lines[#lines + 1] = GT.TR("Route:") .. " " .. routeInfo.step .. "/" .. routeInfo.total
                .. ": " .. label .. distance
        end
        if cfg.priorityReadout then
            local mapID = C_Map.GetBestMapForUnit("player")
            local candidate = mapID and FindPriorityTimer(GetServerTime(), mapID)
            if candidate then
                local def = GT.nodes[candidate.key]
                local distance = candidate.distance and (" - " .. GT.TRF("%d yd", math.floor(candidate.distance))) or ""
                if candidate.left <= 0 then
                    lines[#lines + 1] = "|cff00ff00" .. GT.TR("READY") .. "|r: " .. def.label .. distance
                else
                    local left = math.floor(candidate.left)
                    lines[#lines + 1] = string.format("%s %d:%02d%s", def.label, math.floor(left / 60), left % 60, distance)
                end
            end
        end
        if #lines == 0 then priorityText:Hide(); return end
        priorityText:SetText(table.concat(lines, "\n"))
        priorityText:Show()
    end

    -- Called from HUD.OnUpdate (GatherTimes' update loop) on every frame.
    function Overlay.OnUpdate(dt)
        if not (frame and frame:IsShown()) then return end
        local cfg = HUD.Cfg()
        if cfg.ringUnit == "yd" or cfg.scaleCaps then
            -- the map's reach changes with zoom and indoors / outdoors: re-lay the rings when it does
            radiusAcc = radiusAcc + dt
            if radiusAcc >= 0.25 then
                radiusAcc = 0
                if HUD.MapRadiusYards() ~= lastRadius then LayoutRings(cfg) end
            end
        end
        if cfg.priorityReadout or cfg.routeReadout then
            priorityElapsed = priorityElapsed + dt
            if priorityElapsed >= 1 then
                priorityElapsed = priorityElapsed % 1
                UpdatePriorityText()
            end
        elseif priorityText:IsShown() then
            priorityText:Hide()
        end
        if needsTick then
            elapsedSince = elapsedSince + dt
            if elapsedSince >= 0.03 then
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
        lastFacing = nil
        priorityElapsed = 1
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
        if priorityText then priorityText:Hide() end
        if frame then frame:Hide() end
    end

    function Overlay.SetShown(shown)
        if frame then frame:SetShown(shown and true or false) end
    end
end
