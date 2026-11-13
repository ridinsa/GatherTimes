-- HUDSet.lua : Preview, SetEnabled / Toggle and HUD.Set (the one entry point for settings). Part of the HUD module (see HUD.lua).
local _, GT = ...
local HUD = GT.HUD
local S = HUD.S

-- Which setting changes need which kind of refresh
local OVERLAY_KEYS = { ring = true, ring2 = true, ringUnit = true, ringYd = true, ring2Yd = true,
                       ringColor = true, ringColor2 = true,
                       ringThickness = true,
                       ringSegments = true, ringStyle = true, ringDensity = true, dirs = true, heading = true,
                       priorityReadout = true, routeReadout = true }
local MAP_KEYS     = { size = true, alpha = true, zoom = true,
                       rotate = true, arrow = true, mountFade = true }
-- settings of the Eagle Eye map: they only change what is on screen while that map is up
local EAGLE_KEYS   = { eagleSize = true, eagleAlpha = true, eagleZoom = true, eagleRotate = true,
                       eagleScale = true, eagleNearest = true, eagleHover = true, eagleHideLabels = true }
local TRACK_KEYS   = { trackingX = true, trackingY = true, trackingSize = true, idleX = true, idleY = true }

local autoSuppressed = false         -- the player turned the HUD off by hand: auto-gather stays quiet until tracking changes
function HUD.AutoSuppressed() return autoSuppressed end
function HUD.ClearAutoSuppress() autoSuppressed = false end

-- Preview (the settings panel's "Preview HUD" button): turns the HUD on while the panel is open, even when it is off.
-- Not saved.  The preview only undoes itself: it never switches off a HUD the player turned on.
local hudPreview = false
function HUD.Previewing() return hudPreview end
function HUD.Preview(state)
    state = state and true or false
    if state == hudPreview then return hudPreview end
    if state then
        if HUD.db and not S.active then
            HUD.I.ApplyHud()
            hudPreview = S.active and true or false
        end
    else
        hudPreview = false
        if S.active then HUD.I.RestoreHud() end
    end
    if GT.RefreshHudButton then GT.RefreshHudButton() end
    if HUD.Config then HUD.Config.Refresh() end
    return hudPreview
end

function HUD.SetEnabled(state, auto)
    state = state and true or false
    if not auto then hudPreview = false end          -- the player switched the HUD by hand: the preview is over
    if not S.eagleBusy then S.eagleSuspended = false end     -- a manual / auto toggle ends the Eagle Eye suspension
    if not auto and not S.eagleBusy then
        autoSuppressed = not state                       -- manual off: do not let auto-gather switch it straight back on
        if state and S.active then S.autoEnabled = false end -- manual "on" while auto-enabled: the player owns it now
    end
    if state == S.active then return end
    S.autoEnabled = (auto and state) and true or false
    if state then HUD.I.ApplyHud() else HUD.I.RestoreHud() end
    -- HUD switched on in the middle of Eagle Eye: go straight to the Eagle map
    if state and S.active and not S.eagleBusy and HUD.db.eagleMap then HUD.EagleCheck() end
    if HUD.Config then HUD.Config.Refresh() end
    if GT.RefreshHudButton then GT.RefreshHudButton() end       -- the HUD button in the main window
end

function HUD.Toggle()
    if HUD.db then HUD.SetEnabled(not S.active) end
end

-- Single entry point for changing a profile setting (slash, options panel)
function HUD.Set(key, value, fromUI)
    HUD.db[key] = value
    if key == "alpha" or (key == "eagleAlpha" and S.eagleMode) then
        if S.active then HUD.I.QueueMask() end       -- mask swap only, see ApplyMaskOnly
    elseif key == "eagleMap" then
        if not value and S.eaglePreview then S.eaglePreview = false end
        HUD.EagleCheck()
    elseif key == "eagleHideLabels" or key == "hideLabelsIdle" then
        HUD.UpdateEagleLabels()
    elseif key == "hudHover" then
        -- applies at once while the normal HUD is up (the Eagle map keeps its own "eagleHover" setting)
        if S.active and S.orig and not S.eagleMode then
            S.applying = true
            pcall(HUD.I.SetMinimapMouse, HUD.I.HoverWanted())
            S.applying = false
        end
    elseif EAGLE_KEYS[key] then
        if S.active and S.eagleMode then HUD.Refresh(true) end
    elseif OVERLAY_KEYS[key] then
        if S.active then HUD.Overlay.Update() end
    elseif MAP_KEYS[key] then
        HUD.Refresh(true)       -- ApplyHud runs Overlay.Update in the light path too, so a size change needs nothing more
    elseif TRACK_KEYS[key] then
        HUD.Tracking.Place()
    elseif key == "autoGather" then
        HUD.CheckAutoGather()
    elseif key == "trackIdle" then
        if not S.active then
            if not HUD.UseOwnIdle() then
                -- handing the button back to Blizzard: let it show itself again
                for _, f in ipairs(HUD.StockTrackingFrames()) do
                    if type(f.UpdateState) == "function" then pcall(f.UpdateState, f) end
                end
                if type(_G.MiniMapTracking_Update) == "function" then pcall(_G.MiniMapTracking_Update) end
            end
            HUD.Tracking.Refresh()
        end
    else
        HUD.Refresh()          -- tracking, hideAddons
        if not S.active and key == "tracking" then HUD.Tracking.Refresh() end
    end
    if HUD.Config and not fromUI then HUD.Config.Refresh() end
end

function HUD.SetRoot(key, value)
    HUD.root[key] = value
    if key == "perfSuggest" and value then HUD.root.perfSuggested = false end   -- switching the hint back on re-arms it
    if key == "deepScan" and S.active then HUD.Refresh() end
    if key == "perfLevel" then
        if HUD.InvalidateAddonCache then HUD.InvalidateAddonCache() end
        if S.active then
            HUD.EagleCheck()                -- Lowest: leaves the Eagle map / Full: may bring it back
            HUD.Refresh(true)               -- rings, segments and the update loops follow the new level
        end
        if HUD.Config and HUD.Config.Refresh then HUD.Config.Refresh() end
    end
end

-- Level by name or number (slash command, buttons): "full" / "balanced" / "lowest" / 0 / 1 / 2
function HUD.SetPerfLevel(level)
    if type(level) == "string" then
        level = ({ full = 0, off = 0, balanced = 1, medium = 1, low = 2, lowest = 2 })[level:lower()]
    end
    if level ~= 0 and level ~= 1 and level ~= 2 then return false end
    HUD.SetRoot("perfLevel", level)
    return true
end
