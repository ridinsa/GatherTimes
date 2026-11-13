-- HUDLifecycle.lua : Init, OnEvent and OnUpdate (called by Events.lua). Part of the HUD module (see HUD.lua).
local _, GT = ...
local HUD = GT.HUD
local S = HUD.S

---------------------------------------------------------------------------
-- Lifecycle: driven by GatherTimes (Events.lua)
---------------------------------------------------------------------------

local ldbCallbackOwner = {}
local ldbRegistered = false
local function RegisterLDBIconCallback()
    if ldbRegistered then return end
    local ok, ldbi = pcall(LibStub, "LibDBIcon-1.0", true)
    if ok and ldbi and ldbi.RegisterCallback then
        ldbRegistered = pcall(ldbi.RegisterCallback, ldbCallbackOwner, "LibDBIcon_IconCreated", function()
            HUD.InvalidateAddonCache()
            if S.active then HUD.ScheduleRehide() end
        end)
    end
end

-- Called once by GatherTimes on its own ADDON_LOADED, after GT.SanitizeDB().
function HUD.Init()
    HUD.I.InitDB()
    if HUD.Config and HUD.Config.Init then
        local ok, err = pcall(HUD.Config.Init)
        if not ok then GT.cprint("HUD settings window failed to build: " .. tostring(err)) end
    end
end

-- Forwarded by Events.lua: ADDON_LOADED (other addons only), PLAYER_ENTERING_WORLD, PLAYER_LOGOUT,
-- MINIMAP_UPDATE_TRACKING, PLAYER_MOUNT_DISPLAY_CHANGED, UNIT_AURA, UNIT_SPELLCAST_* (player).
function HUD.OnEvent(event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        -- another addon loaded: it may have created minimap buttons
        HUD.InvalidateAddonCache()
        if S.active then HUD.ScheduleRehide() end
        return
    end
    if not HUD.db then return end

    if event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = arg1, arg2
        local justEnabled = false
        if isLogin or isReload then
            RegisterLDBIconCallback()
            if HUD.root.restoreOnLogin and S.charState.wasActive then
                S.charState.wasActive = false
                HUD.SetEnabled(true)
                justEnabled = true
            end
        end
        if S.active and not justEnabled then
            HUD.I.ApplyHud()                      -- minimap can be reset by the loading screen
            C_Timer.After(2, HUD.I.Enforce)
        end
        HUD.CheckAutoGather()
        if not S.active then C_Timer.After(1, HUD.Tracking.Refresh) end

    elseif event == "MINIMAP_UPDATE_TRACKING" then
        HUD.Tracking.Refresh()
        HUD.CheckAutoGather()

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if not (arg3 and HUD.EagleClass() and HUD.EagleCastIsView(arg3)) then return end   -- any other spell: nothing to do
            HUD.EagleCast(arg3)
        elseif event ~= "UNIT_SPELLCAST_CHANNEL_START" then
            HUD.EagleCastEnd()
        else
            HUD.EagleInvalidate()                       -- drop the per-frame answer
        end
        HUD.EagleCheck()
        C_Timer.After(0.2, HUD.EagleCheck)              -- channel info can lag the event by a moment

    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "UNIT_AURA" then
        if event == "UNIT_AURA" and HUD.EagleClass() then HUD.EagleInvalidate(); HUD.EagleCheck() end   -- other classes have no remote view
        if S.active then HUD.UpdateVisibility() end       -- mounts (if the option is on)

    elseif event == "PLAYER_LOGOUT" then
        if S.charState then S.charState.wasActive = S.active or S.eagleSuspended end
        if S.active and S.orig then
            -- the CVar and zoom outlive the UI session; put them back
            pcall(SetCVar, "rotateMinimap", S.orig.rotate)
            pcall(Minimap.SetZoom, Minimap, S.orig.zoom)
            HUD.root.origRotate = nil
        end
    end
end

-- Called by Events.lua from GatherTimes' update loop on every frame. Each part is isolated so one failure
-- is reported once instead of every frame.
-- A part that errors is paused for 5 seconds and then tried again (a transient nil must not disable the compass
-- until /reload). The error is reported once per outage, not on every retry.
local pausedUntil, reported = {}, {}
local function Guard(name, fn, ...)
    local until_ = pausedUntil[name]
    if until_ and GetTime() < until_ then return end
    local ok, err = pcall(fn, ...)
    if ok then
        pausedUntil[name], reported[name] = nil, nil
    else
        pausedUntil[name] = GetTime() + 5
        if not reported[name] then
            reported[name] = true
            GT.ReportError("HUD " .. name, err)
        end
    end
end

-- Low-FPS hint: with the HUD on at "Full", the frame rate is sampled once a second for 30 s. If the average is under
-- PERF_FPS the player gets ONE chat line pointing at the Performance option (never repeated: perfSuggested is saved).
local PERF_FPS, PERF_SAMPLES = 25, 30
local perfAcc, perfSum, perfN = 0, 0, 0
function HUD.PerfWatch(dt)
    local root = HUD.root
    if not (root and root.perfSuggest and not root.perfSuggested and S.active and HUD.PerfLevel() == 0) then
        perfAcc, perfSum, perfN = 0, 0, 0
        return
    end
    perfAcc = perfAcc + (dt or 0)
    if perfAcc < 1 then return end
    perfAcc = 0
    perfSum, perfN = perfSum + (GetFramerate and GetFramerate() or 60), perfN + 1
    if perfN < PERF_SAMPLES then return end
    local avg = perfSum / perfN
    perfSum, perfN = 0, 0
    if avg < PERF_FPS then
        root.perfSuggested = true
        HUD.Print(GT.TRF("Your frame rate is low (%d FPS). Try Performance: Balanced in the HUD options (Perf tab), or /gthud perf balanced.", math.floor(avg + 0.5)))
    end
end

function HUD.OnUpdate(dt)
    if not HUD.db then return end
    Guard("eagle", HUD.EagleTick, dt)                      -- switch the HUD back on after Eagle Eye (0.5 s)
    Guard("mouse", HUD.MouseTick, dt)                      -- keeps the Minimap's mouse state right (0.5 s)
    Guard("overlay", HUD.Overlay.OnUpdate, dt)             -- compass letters / heading (every 0.03 s)
    Guard("tracking", HUD.Tracking.OnUpdate)               -- dragging the tracking button
    Guard("watcher", HUD.WatcherTick, dt)                      -- keeps the stock tracking button right (0.1 s)
    Guard("perf", HUD.PerfWatch, dt)                           -- one-time low-FPS hint (30 s average)
    Guard("skins", HUD.SkinSweep, dt)                          -- hides minimap skin frames SexyMap adds later (0.5 s)
end
