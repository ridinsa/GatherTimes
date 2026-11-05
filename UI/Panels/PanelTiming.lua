-- PanelTiming.lua : the "Timing" panel (learned respawn times, taken %, detection options)
local ADDON, GT = ...
GT.panelBuilders = GT.panelBuilders or {}

local ROW_H, NUM_ROWS = 18, 9
local curMap                                   -- the zone the player is in (set by Refresh), used by UpdateRow
function GT.SampleConfidenceColor(n)
    if n >= 10 then return 0.2, 1, 0.2 end
    if n >= 5 then return 1, 0.82, 0 end
    if n > 0 then return 1, 0.45, 0.1 end
    return 0.55, 0.55, 0.55
end
-- Fixed-width columns. Number columns are right-aligned so the decimals line up.
-- (the list is 288 wide, the last 8px are the scrollbar)
local COL = {
    name  = { x = 2,   w = 74, j = "LEFT"  },
    now   = { x = 78,  w = 30, j = "RIGHT" },
    learn = { x = 112, w = 74, j = "RIGHT" },   -- "fast-typical" range, e.g. *10.5-12.0
    n     = { x = 190, w = 28, j = "RIGHT" },
    taken = { x = 222, w = 42, j = "RIGHT" },
}
local DIM = { 0.55, 0.55, 0.55 }

local function CreateRow(list, i)
    local r = CreateFrame("Frame", nil, list)
    -- faint zebra stripe on every second row
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0)
    local function fs(c, template)
        local f = GT.Font(r, nil, "OVERLAY", template or "GameFontHighlightSmall")
        f:SetPoint("LEFT", c.x, 0)
        f:SetWidth(c.w)
        f:SetJustifyH(c.j)
        f:SetWordWrap(false)
        return f
    end
    r.name    = fs(COL.name, "GameFontNormalSmall")
    r.now     = fs(COL.now)
    r.learned = fs(COL.learn)
    r.n       = fs(COL.n)
    r.taken   = fs(COL.taken)
    return r
end

-- "taken" colour: grey at 0 %, white when low, yellow, then orange when a spot is often found empty
local function TakenColor(pct)
    if pct <= 0 then return DIM[1], DIM[2], DIM[3] end
    if pct < 25 then return 1, 1, 1 end
    if pct < 50 then return 1, 0.82, 0 end
    return 1, 0.45, 0.1
end

local function UpdateRow(r, key)
    local def = GT.nodes[key]
    local col = GT.Col(key)
    r.key = key
    r.name:SetText(def.label)
    r.name:SetTextColor(col[1], col[2], col[3])

    -- Now: the baseline, kept quiet (unit "min" is explained in the note below the list)
    r.now:SetText(string.format("%.1f", def.timer / 60))
    r.now:SetTextColor(DIM[1], DIM[2], DIM[3])

    local est, n, fromZone, typ = GT.LearnedRange(key, curMap)
    local hasData = est ~= nil
    if est then
        local faster = (typ or est) < def.timer * 0.95      -- the value Apply / auto-apply use is the typical one
        -- Per zone mode: "*" in front = this zone has too few samples yet, the item-wide value is shown
        local star = (GT.cfg().learnMode == "zone" and not fromZone) and "*" or ""
        -- Respawns vary, so show fastest-to-typical (median) as a range; one number only when they coincide.
        -- Apply / auto-apply use the typical (right-hand) value.
        if typ and typ > est then
            r.learned:SetText(string.format("%s%.1f-%.1f", star, est / 60, typ / 60))
        else
            r.learned:SetText(string.format("%s%.1f", star, est / 60))
        end
        if faster then r.learned:SetTextColor(0, 1, 0) else r.learned:SetTextColor(1, 1, 1) end
    else
        r.learned:SetText("-")
        r.learned:SetTextColor(DIM[1], DIM[2], DIM[3])
    end
    r.n:SetText("(" .. n .. ")")
    r.n:SetTextColor(GT.SampleConfidenceColor(n))

    local hits, misses = 0, 0
    for _, sp in ipairs(GT.spawns[key]) do
        hits = hits + (sp.hits or 0)
        misses = misses + (sp.misses or 0)
    end
    if (hits + misses) > 0 then
        local pct = misses / (hits + misses) * 100
        r.taken:SetText(string.format("%d%%", pct))
        r.taken:SetTextColor(TakenColor(pct))
        hasData = true
    else
        r.taken:SetText("-")
        r.taken:SetTextColor(DIM[1], DIM[2], DIM[3])
    end

    -- rows with nothing measured yet fade back so the rows with real data stand out
    r:SetAlpha(hasData and 1 or 0.5)
end

GT.panelBuilders.Timing = function(panel, content)
    local cfg = GT.cfg

    -- column captions (same x / width / alignment as the row columns)
    local function caption(text, c)
        local fs = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", c.x, 0)
        fs:SetWidth(c.w)
        fs:SetJustifyH(c.j)
        fs:SetWordWrap(false)
        fs:SetText(GT.TR(text))
    end
    caption("Node", COL.name); caption("Now", COL.now); caption("Learned", COL.learn)
    caption("n", COL.n); caption("Taken", COL.taken)

    local list = GT:CreateScrollList(content, 288, ROW_H * NUM_ROWS, ROW_H, CreateRow, UpdateRow)
    list:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -14)

    local lastSig
    local function Refresh(force)
        local mapID = C_Map.GetBestMapForUnit("player")
        curMap = mapID
        local zoneOnly = cfg().zoneOnly
        local sig = tostring(zoneOnly) .. ":" .. tostring(zoneOnly and mapID)
        if force or sig ~= lastSig then
            lastSig = sig
            local keys = {}
            for _, key in ipairs(GT.order) do
                if not zoneOnly or (mapID and #GT.ComputeGroups(key, mapID).groups > 0) then
                    keys[#keys + 1] = key
                end
            end
            list:SetItems(keys)
        else
            list:Update()
        end
    end

    local function Check(y, text, get, set, description)
        local cb = GT:CreateCheckLabel(content, text, get, set)
        cb:SetPoint("TOPLEFT", 2, y)
        cb:HookScript("OnEnter", function(self)
            GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
            GT.Tip:AddLine(GT.TR(text))
            GT.Tip:AddLine(GT.TR(description), 0.85, 0.85, 0.85, true)
            GT.Tip:Show()
        end)
        cb:HookScript("OnLeave", function() GT.Tip:Hide() end)
        return cb
    end

    Check(-182, "One shared timer per group",
        function() return cfg().groupMode end,
        function(v)
            cfg().groupMode = v
            if v then pcall(GT.NormalizeGroupTimers) end
            pcall(GT.SyncSpawnPins)
        end,
        "Treat nearby spawn spots in the same group as one resource with a shared respawn timer.")
    Check(-208, "Detect empty nodes (taken by someone)",
        function() return cfg().detectEmpty end,
        function(v) cfg().detectEmpty = v end,
        "Learn when a node is already depleted by detecting when you approach and wait near it.")
    Check(-230, "Use game messages (\"someone is using that\")",
        function() return cfg().msgDetect end,
        function(v) cfg().msgDetect = v end,
        "Use the game's gathering messages after an attempt to detect when another player took the node.")
    Check(-252, "Auto-adjust learned times",
        function() return cfg().autoLearn end,
        function(v) cfg().autoLearn = v end,
        "Automatically update a resource's respawn timer from learned data once enough samples are available.")

    -- learned-times mode: one learned time per item type (default) or per zone
    local modeLabel = GT.Font(content, nil, "OVERLAY", "GameFontHighlightSmall")
    modeLabel:SetPoint("TOPLEFT", 2, -300)
    modeLabel:SetText(GT.TR("Learned times:"))
    local modeButtons = {}
    local function SyncMode()
        local m = cfg().learnMode
        GT:SetButtonActive(modeButtons.item, m ~= "zone")
        GT:SetButtonActive(modeButtons.zone, m == "zone")
    end
    local function ModeButton(id, text, x)
        local b = GT:CreateFlatButton(content, text, 92, 20)
        b:SetPoint("TOPLEFT", x, -296)
        b:SetScript("OnClick", function()
            cfg().learnMode = id
            SyncMode()
            list:Update()
        end)
        b:SetScript("OnEnter", function(s)
            s:SetBackdropColor(unpack(GT.colors.hover))
            GT.Tip:SetOwner(s, "ANCHOR_RIGHT")
            GT.Tip:AddLine(GT.TR(text))
            GT.Tip:AddLine(GT.TR(id == "zone"
                and "Use samples from your current zone when at least 5 are available; otherwise fall back to the item-wide estimate."
                or "Combine samples for this resource type across all zones."), 0.85, 0.85, 0.85, true)
            GT.Tip:Show()
        end)
        b:SetScript("OnLeave", function(s) s:SetBackdropColor(unpack(s.baseColor)); GT.Tip:Hide() end)
        modeButtons[id] = b
    end
    ModeButton("item", "Per item", 96)
    ModeButton("zone", "Per zone", 192)
    SyncMode()
    GT.uiRefresh[#GT.uiRefresh + 1] = SyncMode

    local note = GT.Font(content, nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 2, -324)
    note:SetWidth(284)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(false)
    note:SetText(GT.TR("Minutes. Sample count: orange <5, yellow 5-9, green 10+. Green learned time = faster."))

    local apply = GT:CreateFlatButton(content, "Apply all faster", 138, 20)
    apply:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    apply:SetScript("OnClick", function()
        local n = 0
        for _, key in ipairs(GT.order) do
            if GT.ApplyLearned(key, false, curMap) then n = n + 1 end
        end
        GT.cprint(GT.TRF("%d respawn time(s) updated.", n))
        list:Update()
    end)
    apply:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_TOP")
        GT.Tip:AddLine(GT.TR("Apply all faster"))
        GT.Tip:AddLine(GT.TR("Update resource respawn timers when their learned estimate is at least 5% faster than the current timer."), 0.85, 0.85, 0.85, true)
        GT.Tip:Show()
    end)
    apply:HookScript("OnLeave", function() GT.Tip:Hide() end)

    local reset = GT:CreateFlatButton(content, "Reset learned timings", 138, 20)
    reset:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    reset:SetScript("OnClick", function()
        for _, key in ipairs(GT.order) do
            wipe(cfg().learn[key])
            wipe(cfg().learnZone[key])
            for _, sp in ipairs(GT.spawns[key]) do sp.misses = 0 end
        end
        GT.cprint(GT.TR("Learned timing data cleared."))
        list:Update()
    end)
    reset:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_TOP")
        GT.Tip:AddLine(GT.TR("Reset learned data"))
        GT.Tip:AddLine(GT.TR("Erase learned respawn samples and empty-node counts for all resources. This does not change your current timer settings."), 0.85, 0.85, 0.85, true)
        GT.Tip:Show()
    end)
    reset:HookScript("OnLeave", function() GT.Tip:Hide() end)

    -- the logic files call this after every learned sample
    GT.RefreshTimingUI = function()
        if panel:IsShown() then list:Update() end
    end

    panel:SetScript("OnShow", function() Refresh(true) end)
    local t = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        if t >= 2 then t = 0; Refresh(false) end
    end)
    GT.uiRefresh[#GT.uiRefresh + 1] = function() Refresh(true) end
    Refresh(true)
end
