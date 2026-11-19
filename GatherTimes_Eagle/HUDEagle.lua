-- HUDEagle.lua : Eagle Eye / remote-view detection, the Eagle map switch, preview, zoom and size keys. Part of the HUD module (see HUD.lua).
local GT = _G.GatherTimesAddon     -- load-on-demand part: it gets its own private table, so take the shared one
local HUD = GT.HUD
HUD.EagleLoaded = true      -- HUD.lua has stand-ins for everything below until this file is loaded (Core\Modules.lua)
local S = HUD.S
local Clamp = HUD.Clamp
local EAGLE_SIZE_STEPS = HUD.EAGLE_SIZE_STEPS

---------------------------------------------------------------------------
-- Eagle Eye / remote views
---------------------------------------------------------------------------

-- Eagle Eye (hunter view): the camera turns away from the character, so the full-screen HUD dots would be drawn
-- in the wrong place. Matched by spell id, or by the localised name.
--   eagleMap on  (default): the HUD stays on and the map is drawn as the Eagle map (HUD.Cfg(): eagle* settings,
--                centred, no compass / readouts). The stock minimap is never restored in between, so nothing flickers.
--   eagleMap off: the old behaviour, the HUD is switched OFF (stock minimap restored) and back ON afterwards.
-- Remote views: Eagle Eye (hunter), Far Sight (shaman), Mind Vision (priest), Eyes of the Beast (hunter pet) and
-- Eye of Kilrogg (warlock) all move the camera away from the character, so they get the same map. Spell ids are
-- checked first, the localised name second (ranks that are not listed).
local VIEW_SPELLS = {
    [6197] = true,                                  -- Eagle Eye
    [6196] = true,                                  -- Far Sight
    [2096] = true, [10909] = true,                  -- Mind Vision
    [1002] = true,                                  -- Eyes of the Beast
    [126]  = true,                                  -- Eye of Kilrogg
}
local VIEW_CLASSES = { HUNTER = true, SHAMAN = true, PRIEST = true, WARLOCK = true }
local viewClass                                     -- nil = not looked up yet; true when the class has a remote view
local viewNames                                     -- localised names of VIEW_SPELLS (filled once the client knows them)
local castUntil = 0                                 -- fallback: a cast of a view spell succeeded (see HUD.EagleCast)
local lastT, lastR                                  -- EagleEyeActive is answered once per frame

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and type(n) == "string" then return n end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok then
            if type(info) == "table" then return info.name end
            if type(info) == "string" then return info end
        end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok then
            if type(n) == "table" then return n.name end
            if type(n) == "string" then return n end
        end
    end
    return nil
end

local function ViewClass()
    if viewClass == nil then
        viewClass = VIEW_CLASSES[select(2, UnitClass("player")) or ""] and true or false
    end
    return viewClass
end
function HUD.EagleClass() return ViewClass() end

local function IsViewSpell(id, name)
    if id and VIEW_SPELLS[id] then return true end
    if not name then return false end
    if not viewNames then
        local t, n = {}, 0
        for sid in pairs(VIEW_SPELLS) do
            local nm = SpellName(sid)
            if nm then t[nm] = true; n = n + 1 end
        end
        if n == 0 then return false end             -- spell info not ready yet: look again next time
        viewNames = t
    end
    return viewNames[name] and true or false
end

-- A buff on the player. One lookup per spell id; clients without the by-id call scan the buffs instead.
local function ViewAura()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for id in pairs(VIEW_SPELLS) do
            local ok, d = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if ok and d then return true end
        end
        return false
    end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
    for i = 1, 40 do
        local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not d then break end
        if IsViewSpell(d.spellId, d.name) then return true end
    end
    return false
end

-- Eagle Eye is a channelled spell on Classic Era, so it is looked for as a channel first and as a buff second.
local function ViewActive(now)
    if not ViewClass() then return false end
    if UnitChannelInfo then
        local ok, cname, _, _, _, _, _, _, cid = pcall(UnitChannelInfo, "player")
        if ok and cname and IsViewSpell(cid, cname) then return true end
    end
    if ViewAura() then return true end
    -- The cast is an independent fallback: channel/aura APIs may be unavailable or may lag an event.
    return castUntil > now
end

function HUD.EagleEyeActive()
    local now = GetTime()
    if lastT == now then return lastR end
    lastT = now
    lastR = ViewActive(now) and true or false
    return lastR
end

-- A cast of a view spell succeeded / the channel ended (UNIT_SPELLCAST_SUCCEEDED, _INTERRUPTED, _CHANNEL_STOP).
function HUD.EagleInvalidate() lastT = nil end
function HUD.EagleCast(spellID)
    lastT = nil
    if spellID and (VIEW_SPELLS[spellID] or IsViewSpell(spellID)) then castUntil = GetTime() + 60 end
end
function HUD.EagleCastIsView(id)
    return (VIEW_SPELLS[id] or IsViewSpell(id)) and true or false
end
function HUD.EagleCastEnd(spellID, force)
    lastT = nil
    if force or (spellID and (VIEW_SPELLS[spellID] or IsViewSpell(spellID))) then castUntil = 0 end
end

-- Legacy mode (eagleMap off): while Eagle Eye is on the HUD is switched OFF and it is switched on again when
-- Eagle Eye ends. A HUD the player turns on/off by hand during Eagle Eye cancels the automatic switch-back.
local eagleWasAuto, eagleAcc = false, 0
function HUD.EagleSuspended() return S.eagleSuspended end

-- Eagle Eye is over: the map hover toggle (HUD.ToggleHover, key / /gthud hovertoggle) goes back to off, so the map does
-- not keep the mouse (and block the game's mob / player tooltips) on the normal HUD.
local function DropHoverLatch()
    if not S.hoverLatched then return end
    S.hoverLatched = false
    HUD.Print(GT.TR("Map hover tooltips: off"))
end

function HUD.EagleCheck()
    local db = HUD.db
    if not db then return end
    local eagle = HUD.EagleEyeActive()
    -- lower-spec mode: the Eagle map is off, but the names still show while Eagle Eye is on. Refresh once when it changes.
    if HUD.LowSpec() and S.active then
        local names = eagle and true or false
        if names ~= (S.lowEagleNames or false) then
            S.lowEagleNames = names
            if not names then DropHoverLatch() end
            HUD.Refresh(true)
        end
    end
    if db.eagleMap then
        if S.eagleSuspended then
            -- the option was switched on during a legacy suspension: bring the HUD back first
            S.eagleSuspended = false
            S.eagleBusy = true
            HUD.SetEnabled(true, eagleWasAuto)
            S.eagleBusy = false
            HUD.CheckAutoGather()
        end
        local want = (eagle or S.eaglePreview) and S.active and not HUD.LowSpec()
        if want ~= S.eagleMode then
            if S.eagleMode and not want then DropHoverLatch() end     -- the Eagle map is going away
            S.eagleMode = want
            S.eagleSizeStep = 1                         -- the "next size" key starts from the saved size each time
            if S.active then HUD.Refresh(true) end      -- same Minimap, new size / mask / zoom / rotation, in one pass
            HUD.UpdateEagleLabels()
        end
        return
    end
    if S.eagleMode then                                  -- option switched off while the Eagle map was up
        DropHoverLatch()
        S.eagleMode = false
        S.eagleSizeStep = 1
        if S.active then HUD.Refresh(true) end
        HUD.UpdateEagleLabels()
    end
    if eagle and S.active and not S.eagleSuspended then
        S.eagleSuspended, eagleWasAuto = true, S.autoEnabled
        S.eagleBusy = true
        HUD.SetEnabled(false)
        S.eagleBusy = false
    elseif not eagle and S.eagleSuspended then
        S.eagleSuspended = false
        S.eagleBusy = true
        HUD.SetEnabled(true, eagleWasAuto)
        S.eagleBusy = false
        HUD.CheckAutoGather()
    end
end

-- Settings panel / slash: hold the Eagle map up without casting Eagle Eye, to set it up. Needs the HUD on.
function HUD.EaglePreview(state)
    if state == nil then state = not S.eaglePreview end
    S.eaglePreview = state and true or false
    if HUD.LowSpec and HUD.LowSpec() then
        S.eaglePreview = false
        if HUD.Print then HUD.Print(GT.TR("Eagle map preview is unavailable in Lowest performance mode.")) end
        return false
    end
    if S.eaglePreview and not (S.active and HUD.db and HUD.db.eagleMap) then
        S.eaglePreview = false
        return false
    end
    HUD.EagleCheck()
    return S.eaglePreview
end
function HUD.EaglePreviewing() return S.eaglePreview end

-- Zoom in (+1) / out (-1) while the Eagle map is up: the key bindings. This is the
-- Eagle zoom setting itself, so it is kept for the next Eagle Eye.
function HUD.EagleZoom(delta)
    if not (HUD.db and S.active and S.eagleMode) then return end
    local z = Clamp(HUD.db.eagleZoom + delta, HUD.LIMITS.zoom[1], HUD.LIMITS.zoom[2])
    if z == HUD.db.eagleZoom then return end
    HUD.Set("eagleZoom", z)
    if HUD.Config then HUD.Config.Refresh() end
end

-- Next size: the saved size, a bigger one, a smaller one, and round again. Only for this view, nothing is saved.
function HUD.EagleNextSize()
    if not (HUD.db and S.active and S.eagleMode) then return end
    S.eagleSizeStep = S.eagleSizeStep % #EAGLE_SIZE_STEPS + 1
    HUD.Refresh(true)
end

-- polled while the Eagle map is up (or the HUD is suspended) in case the "channel stopped" event was missed
-- (e.g. a loading screen)
function HUD.EagleTick(dt)
    if not (S.eagleSuspended or S.eagleMode) then eagleAcc = 0; return end
    eagleAcc = eagleAcc + (dt or 0)
    if eagleAcc < 0.25 then return end
    eagleAcc = 0
    HUD.EagleCheck()
end

-- loaded in the world (Preview, or the option was switched on): look at once whether a remote view is up
if HUD.db then pcall(HUD.EagleCheck) end
