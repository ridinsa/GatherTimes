-- Whisper.lua : plays the chosen sound when a whisper arrives (Settings > Look > Whisper sound).
-- Only the sound: no window, no toast, no pop-up and no history.  The sound list and the player live in
-- Core\Modules.lua (GT.PlayWhisperSound), so the Look tab can preview a sound without loading this folder.
-- Nothing of the game's own UI is replaced or hooked here (that taints the chat frame: "blocked from an action only
-- available to the Blizzard UI").
local GT = _G.GatherTimesAddon     -- load-on-demand part: it gets its own private table, so take the shared one
if not GT then return end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_WHISPER")
pcall(ev.RegisterEvent, ev, "CHAT_MSG_BN_WHISPER")      -- Battle.net whispers (not on every client)
-- only whispers you receive; the ones you send are silent.  "Off" stays silent for the rest of the session.
local lastWhisperAt = 0
ev:SetScript("OnEvent", function()
    if not GT.ModuleEnabled or not GT.ModuleEnabled("whisper") then return end
    if GT.WhisperSoundName and GT.WhisperSoundName() == "Off" then return end
    -- If the standalone "Whisper Sound" addon is enabled, let it own whisper playback
    -- and suppress the GatherTimes copy to avoid duplicate sounds.
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if loaded and loaded("Whisper Sound") then return end
    local now = GetTime and GetTime() or 0
    if now - lastWhisperAt < 2 then return end
    lastWhisperAt = now
    if GT.PlayWhisperSound then GT.PlayWhisperSound() end
end)
