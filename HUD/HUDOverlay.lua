-- HUDOverlay.lua : rings, compass letters and the heading readout. Part of the HUD module (see HUD.lua).
local addonName, GT = ...
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

        for i = 1, 2 do rings[i] = { segs = {} } end

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

    local function LayoutRing(ring, radius, seg, thick, colors, style, density)
        if radius <= 0 then HideSegs(ring, 1); return end
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

    local function LetterRadius(db)
        local half = db.size / 2
        local r = (db.ring > 0) and (db.ring + 16) or (db.size * 0.3)
        return math.min(r, half - 12)
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
        local db = HUD.db
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
    Overlay.FindPriorityTimer = FindPriorityTimer

    local function UpdatePriorityText()
        local lines = {}
        local route = GT.UI and GT.UI.RouteOptimizer
        local routeInfo = HUD.db.routeReadout and route and route.GetGuidanceInfo and route:GetGuidanceInfo()
        if routeInfo then
            local label = GT.nodes[routeInfo.key].label
            local distance = routeInfo.distance and (" - " .. GT.TRF("%d yd", math.floor(routeInfo.distance))) or ""
            lines[#lines + 1] = GT.TR("Route:") .. " " .. routeInfo.step .. "/" .. routeInfo.total
                .. ": " .. label .. distance
        end
        if HUD.db.priorityReadout then
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
        if HUD.db.priorityReadout or HUD.db.routeReadout then
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
        local db = HUD.db
        if not db then return end
        EnsureFrame()
        frame:SetSize(db.size, db.size)
        priorityText:SetWidth(math.max(80, db.size - 24))
        priorityText:ClearAllPoints()
        priorityText:SetPoint("CENTER", frame, "CENTER", 0,
            -math.min(LetterRadius(db) + 26, db.size / 2 - 20))

        local half = db.size / 2
        local seg = math.max(8, math.min(256, db.ringSegments))
        local thick = math.max(1, db.ringThickness)
        LayoutRing(rings[1], math.min(db.ring, half), seg, thick, Overlay.RingColors(1), db.ringStyle, db.ringDensity)
        LayoutRing(rings[2], math.min(db.ring2, half), seg, thick, Overlay.RingColors(2), db.ringStyle, db.ringDensity)

        for i = 1, 4 do letters[i]:SetShown(db.dirs and true or false) end
        headingText:SetShown(db.heading and true or false)
        headingText:ClearAllPoints()
        headingText:SetPoint("CENTER", frame, "CENTER", 0, math.min(LetterRadius(db) + 30, half - 12))
        if db.priorityReadout then
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
        local faded = db.mountFade and IsMounted and IsMounted()
        frame:SetShown(not faded)
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
