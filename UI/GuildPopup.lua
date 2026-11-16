-- GuildPopup.lua : a small pop-up on the right of the screen when a guild member comes online.
-- Settings > General: "Friend/Guild Notifier" (on/off) and "Show N s" (how long it stays; clicking it shows a demo).
local _, GT = ...

GT.guildRoster = GT.guildRoster or {}
GT.friendRoster = GT.friendRoster or {}
local popup
local showToken = 0                             -- counts the shows, so an old slide-out cannot hide a new pop-up

local function PlayerGuild()
    if not GetGuildInfo then return nil end
    local name = GetGuildInfo("player")
    return name ~= "" and name or nil
end

local function RosterKey(name)
    return name and (name:match("^[^-]+") or name)
end

-- guild member details (without realm names), refreshed by GUILD_ROSTER_UPDATE
function GT.RefreshGuildRoster()
    local roster = {}
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        local guild = PlayerGuild()
        for i = 1, (GetNumGuildMembers() or 0) do
            local name, _, _, level, className, zone, _, _, online = GetGuildRosterInfo(i)
            if name then
                roster[RosterKey(name)] = {
                    level = level,
                    className = className,
                    zone = zone,
                    guild = guild,
                    online = online,
                }
            end
        end
    end
    GT.guildRoster = roster
end

-- friend details (without realm names), refreshed by FRIENDLIST_UPDATE
function GT.RefreshFriendRoster()
    local roster = {}
    local n = (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends())
        or (GetNumFriends and GetNumFriends()) or 0
    for i = 1, n do
        local name, level, className, zone, connected, guild
        if C_FriendList and C_FriendList.GetFriendInfoByIndex then
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info then
                name = info.name
                level = info.level
                className = info.className
                zone = info.area
                connected = info.connected
                guild = info.guildName
            end
        end
        if not name and GetFriendInfo then
            name, level, className, zone, connected = GetFriendInfo(i)
        end
        if name then
            roster[RosterKey(name)] = {
                level = level,
                className = className,
                zone = zone,
                guild = guild,
                online = connected,
            }
        end
    end
    GT.friendRoster = roster
end

-- asks the server for the roster every minute, only while the option is on
function GT.StartGuildRosterTicker()
    if GT.rosterTicker or not (C_GuildInfo and C_GuildInfo.GuildRoster and C_Timer and C_Timer.NewTicker) then return end
    GT.rosterTicker = C_Timer.NewTicker(60, function()
        local cfg = GT.cfg and GT.cfg()
        if cfg and cfg.guildOnline == true and IsInGuild and IsInGuild() then
            pcall(C_GuildInfo.GuildRoster)
        end
    end)
end

-- slide: the pop-up comes in from the right edge and slides back out to it
local SLIDE_TIME = 0.35                          -- seconds for one slide
local FAR_X, REST_X = 300, -16                   -- x offsets from the right edge: off screen, and the resting place
local slide = { active = false, t = 0, from = FAR_X, to = REST_X, onDone = nil }

local function PlaceAt(x)
    popup:ClearAllPoints()
    popup:SetPoint("RIGHT", UIParent, "RIGHT", x, 120)
end

local function SlideTo(from, to, onDone)
    slide.active, slide.t, slide.from, slide.to, slide.onDone = true, 0, from, to, onDone
    PlaceAt(from)
end

-- slides the pop-up out to the right, then hides it
local function HideSlide()
    if not (popup and popup:IsShown()) then return end
    local token = showToken
    SlideTo(REST_X, FAR_X, function()
        if token == showToken then popup:Hide() end
    end)
end

local function BuildPopup()
    if popup then return popup end
    popup = CreateFrame("Button", "GatherTimesGuildPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetSize(200, 24)
    popup:SetPoint("RIGHT", UIParent, "RIGHT", FAR_X, 120)
    popup:SetFrameStrata("HIGH")
    -- rounded corners and a border (Blizzard's tooltip border), a little see-through. The colours come from the
    -- skin (GT.SkinFrame), so they follow the main frame's style and are repainted when the style is changed.
    popup:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popup.gtSkinAlpha = 0.85        -- the background is a little see-through
    popup.gtBorderAlpha = 0.95      -- the border is almost solid
    if GT.SkinFrame then GT.SkinFrame(popup, "bg") end
    popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.text:SetJustifyH("LEFT")
    popup.role = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")   -- "Friend" / "Guild Member" under the name
    popup.role:SetJustifyH("LEFT")
    popup.role:Hide()
    popup.guild = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")   -- the guild name, under the role
    popup.guild:SetJustifyH("LEFT")
    popup.guild:Hide()
    popup.details = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.details:SetPoint("BOTTOMLEFT", 7, 4)
    popup.details:SetPoint("RIGHT", -7, 0)
    popup.details:SetJustifyH("LEFT")
    popup.details:SetWordWrap(false)
    popup.details:Hide()
    popup:SetScript("OnClick", function() HideSlide() end)
    popup:SetScript("OnUpdate", function(self, dt)
        if not slide.active then return end
        slide.t = slide.t + (dt or 0)
        local f = math.min(slide.t / SLIDE_TIME, 1)
        local eased = 1 - (1 - f) * (1 - f)       -- ease-out: it slows down as it arrives
        PlaceAt(slide.from + (slide.to - slide.from) * eased)
        if f >= 1 then
            slide.active = false
            if slide.onDone then slide.onDone() end
        end
    end)
    popup:Hide()
    return popup
end

-- the notifier sounds (Media folder): one at a time, so they do not stack
local notifyHandle
local function PlayNotifySound(file)
    if notifyHandle then pcall(StopSound, notifyHandle) end
    local ok, willPlay, handle = pcall(PlaySoundFile, GT.MEDIA_DIR .. file, "Master")
    notifyHandle = (ok and willPlay) and handle or nil
end

-- The voices the computer has (the game's text-to-speech): a list of { voiceID, name }.
function GT.GuildVoices()
    local out = {}
    local api = C_VoiceChat
    if api and api.GetTtsVoices then
        local ok, voices = pcall(api.GetTtsVoices)
        if ok and type(voices) == "table" then
            for _, v in ipairs(voices) do
                if type(v) == "table" and v.voiceID ~= nil then out[#out + 1] = { id = v.voiceID, name = v.name or "" } end
            end
        end
    end
    return out
end

-- first names of common female voices, to pick a woman's voice by default (the game gives no gender)
local FEMALE_HINTS = {
    "zira", "hazel", "susan", "linda", "catherine", "heera", "aria", "jenny", "eva", "helen", "helena", "huihui",
    "yaoyao", "hanhan", "xiaoxiao", "sayaka", "haruka", "ayumi", "heami", "irina", "katja", "hedda", "julie",
    "paulina", "laura", "lucia", "sabina", "maria", "elsa", "michelle", "emily", "female", "woman",
}
local function LooksFemale(name)
    name = (name or ""):lower()
    for _, hint in ipairs(FEMALE_HINTS) do
        if name:find(hint, 1, true) then return true end
    end
    return false
end

-- the voices in the order the Settings button goes through them: the default one first (a female voice if the computer
-- has one, else the first), then the others
local function VoiceOrder()
    local voices = GT.GuildVoices()
    local first
    for i, v in ipairs(voices) do
        if LooksFemale(v.name) then first = i; break end
    end
    local out = {}
    if first then out[1] = voices[first] end
    for i, v in ipairs(voices) do
        if i ~= first then out[#out + 1] = v end
    end
    return out
end

-- the voice in use: the one picked in Settings, else the default one
local function PickedVoice()
    local order = VoiceOrder()
    local cfg = GT.cfg and GT.cfg()
    local saved = cfg and cfg.guildSpeakVoice
    for _, v in ipairs(order) do
        if saved ~= nil and v.id == saved then return v end
    end
    return order[1]
end

function GT.GuildVoiceID()
    local v = PickedVoice()
    return v and v.id or 0
end

-- the text of the Settings button: "Voice off", or a short voice name: "Microsoft Zira Desktop - English (United
-- States)" -> "Zira"
function GT.GuildVoiceName()
    local cfg = GT.cfg and GT.cfg()
    local v = PickedVoice()
    if not (cfg and cfg.guildSpeak == true and v) then return GT.TR("Voice off") end
    if v.name == "" then return GT.TR("Voice") end
    local short = v.name:gsub("^Microsoft%s+", "")
    return short:match("^(%S+)") or short
end

-- Settings button: one control for the voice. Goes off -> the default voice -> the next voice ... -> off (step = 1), or
-- the other way (step = -1). Returns true when it ends up speaking.
function GT.GuildVoiceStep(step)
    local cfg = GT.cfg()
    local order = VoiceOrder()
    if #order == 0 then cfg.guildSpeak = false; return false end
    local cur = 0                                   -- 0 = off, 1..#order = that voice
    if cfg.guildSpeak == true then
        local v = PickedVoice()
        for i, x in ipairs(order) do
            if v and x.id == v.id then cur = i end
        end
    end
    local nxt = (cur + (step or 1)) % (#order + 1)
    if nxt == 0 then
        cfg.guildSpeak = false
        return false
    end
    cfg.guildSpeak = true
    cfg.guildSpeakVoice = order[nxt].id
    return true
end

-- Speaks a line with the game's text-to-speech (Settings > General: the voice button next to the notifier). Newer clients take
-- (voice, text, rate, volume); older ones also take where to play it (the VoiceTtsDestination enum), so that argument
-- is only added when the client has the enum. A new line cuts off one still being spoken.
local speakToken = 0
local function SpeakLine(text)
    local api = C_VoiceChat
    if not (api and api.SpeakText) or type(text) ~= "string" or text == "" then return end
    -- Only the newest request speaks (clicking through the voices quickly must not queue several), and the new line
    -- starts a moment after the stop: a stop and a speak in the same instant can cancel the new speech.
    speakToken = speakToken + 1
    local token = speakToken
    if api.StopSpeakingText then pcall(api.StopSpeakingText) end
    C_Timer.After(0.3, function()
        if token ~= speakToken then return end
        local voice = GT.GuildVoiceID()
        local dest = Enum and Enum.VoiceTtsDestination
        if dest and dest.LocalPlayback then
            pcall(api.SpeakText, voice, text, dest.LocalPlayback, 0, 100)
        else
            pcall(api.SpeakText, voice, text, 0, 100)             -- speed 0 = normal, volume 100
        end
    end)
end

local function ZoneOf(name)
    local guildInfo = GT.guildRoster and GT.guildRoster[name]
    local friendInfo = GT.friendRoster and GT.friendRoster[name]
    local zone = guildInfo and guildInfo.zone
    if not zone or zone == "" then zone = friendInfo and friendInfo.zone end
    if type(zone) == "string" and zone ~= "" then return zone end
    return nil
end

local function PopupDetails(name)
    local guildInfo = GT.guildRoster and GT.guildRoster[name]
    local friendInfo = GT.friendRoster and GT.friendRoster[name]
    if not guildInfo and not friendInfo then return nil end

    local parts = {}
    local level = guildInfo and guildInfo.level
    if type(level) ~= "number" or level <= 0 then level = friendInfo and friendInfo.level end
    if type(level) == "number" and level > 0 then parts[#parts + 1] = GT.TRF("Level %d", level) end
    local className = guildInfo and guildInfo.className
    if not className or className == "" then className = friendInfo and friendInfo.className end
    if className and className ~= "" then parts[#parts + 1] = className end
    local zone = guildInfo and guildInfo.zone
    if not zone or zone == "" then zone = friendInfo and friendInfo.zone end
    if zone and zone ~= "" then parts[#parts + 1] = zone end
    if #parts == 0 then return nil end
    return table.concat(parts, " | ")
end

-- how this person is known: "friend", "guild" or "both" (nil when neither list has them)
local function RoleOf(name)
    local isGuild = GT.guildRoster and GT.guildRoster[name] and true or false
    local isFriend = GT.friendRoster and GT.friendRoster[name] and true or false
    if isGuild and isFriend then return "both" end
    return (isFriend and "friend") or (isGuild and "guild") or nil
end

local ROLE_TEXT = { friend = "Friend", guild = "Guild Member", both = "Friend & Guild Member" }
local ROLE_COLOR = { friend = { 0.4, 0.8, 1 }, guild = { 0.3, 1, 0.3 }, both = { 0.6, 1, 0.85 } }

-- the guild name of a person from either list (nil when there is none)
local function GuildNameOf(name)
    local g = GT.guildRoster and GT.guildRoster[name]
    local f = GT.friendRoster and GT.friendRoster[name]
    local guild = (g and g.guild) or (f and f.guild)
    if guild and guild ~= "" then return guild end
    return nil
end

-- shows the pop-up for a name: it slides in, stays for the time set in Settings, then slides out.
-- offline = true shows "is offline" in red; otherwise "is online" in gold. A line under the name says if the person is
-- a Friend, a Guild Member or both (role is only given by the demo, which cycles through the three).
function GT.ShowGuildPopup(name, offline, role)
    local p = BuildPopup()
    local details = PopupDetails(name)
    role = role or RoleOf(name)
    p.text:ClearAllPoints()
    p.role:ClearAllPoints()
    p.guild:ClearAllPoints()
    p.details:ClearAllPoints()
    local guildName = GuildNameOf(name)
    p.text:SetPoint("TOPLEFT", 7, -4)
    p.text:SetPoint("RIGHT", -7, 0)
    local last, height = p.text, 21
    if role then
        p.role:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -1)
        p.role:SetPoint("RIGHT", -7, 0)
        p.role:SetText(GT.TR(ROLE_TEXT[role]))
        p.role:SetTextColor(unpack(ROLE_COLOR[role]))
        p.role:Show()
        last, height = p.role, height + 12
    else
        p.role:Hide()
    end
    if guildName then
        p.guild:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -1)
        p.guild:SetPoint("RIGHT", -7, 0)
        p.guild:SetText(guildName)
        p.guild:Show()
        last, height = p.guild, height + 12
    else
        p.guild:Hide()
    end
    if details then
        p.details:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -1)
        p.details:SetPoint("RIGHT", -7, 0)
        p.details:SetText(details)
        p.details:Show()
        height = height + 12
    else
        p.details:Hide()
    end
    p:SetSize(details and 230 or 200, math.max(height, 24))
    if offline then
        p.text:SetText(GT.TRF("%s is offline", name))
        p.text:SetTextColor(1, 0.25, 0.25)
    else
        p.text:SetText(GT.TRF("%s is online", name))
        p.text:SetTextColor(1, 0.82, 0)
    end
    PlayNotifySound(offline and "Windows.ogg" or "Xbox.ogg")
    local cfgNow = GT.cfg and GT.cfg()
    if cfgNow and cfgNow.guildSpeak == true then
        local text = p.text:GetText()
        local zoneAtShow = ZoneOf(name)                            -- before the lists are refreshed
        if not offline and C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end   -- fresh location
        C_Timer.After(0.8, function()                              -- after the short notification sound
            -- "Name is online at Zone" / "Name is offline at Zone" when the location is known. Online: read when it is
            -- spoken, so a fresher list counts. Offline: where they were last seen, read before the lists change.
            local zone
            if offline then zone = zoneAtShow or ZoneOf(name) else zone = ZoneOf(name) or zoneAtShow end
            local line = text
            if zone then
                line = GT.TRF(offline and "%s is offline at %s" or "%s is online at %s", name, zone)
            end
            SpeakLine(line)
        end)
    end
    showToken = showToken + 1
    local token = showToken
    p:Show()
    SlideTo(FAR_X, REST_X)
    local cfg = GT.cfg and GT.cfg()
    local secs = (cfg and cfg.guildOnlineSecs) or 6
    C_Timer.After(secs, function()
        if token == showToken then HideSlide() end
    end)
end

-- the tail of a game line in this client's language, e.g. " has come online." or " has gone offline."
local function LineTail(globalName, fallback)
    local fmt = _G[globalName] or ""
    -- online: "|Hplayer:%s|h[%s]|h has come online."  -> text after the LAST |h (greedy ".*")
    -- offline: "%s has gone offline."                  -> text after the last %s
    local tail = fmt:match("^.*|h(.*)$") or fmt:match("^.*%%s(.*)$")
    if tail and tail ~= "" then return tail end
    return fallback
end

local COOLDOWN = 10                       -- seconds before the same person and state can show again
local lastShown = {}

-- called for every system chat line. A guild member or friend coming online shows the pop-up (gold text);
-- going offline shows it in red. The Settings option "Friend/Guild Notifier" switches both.
function GT.OnGuildOnlineMessage(text)
    local cfg = GT.cfg and GT.cfg()
    if not (cfg and cfg.guildOnline == true) then return end
    if type(text) ~= "string" then return end
    local online  = LineTail("ERR_FRIEND_ONLINE_SS", " has come online.")
    local offline = LineTail("ERR_FRIEND_OFFLINE_S", " has gone offline.")
    local isOnline = online ~= "" and text:find(online, 1, true) ~= nil
    local isOffline = (not isOnline) and offline ~= "" and text:find(offline, 1, true) ~= nil
    if not (isOnline or isOffline) then return end
    local name = text:match("|Hplayer:([^:|]+)") or text:match("^%[?([^%s%]|]+)")
    if not name then return end
    name = name:match("^[^-]+") or name
    local known = (GT.guildRoster and GT.guildRoster[name]) or (GT.friendRoster and GT.friendRoster[name])
    if not known then return end
    -- no spam: the same person and the same state (online / offline) shows at most once per COOLDOWN seconds
    local key = name .. (isOffline and "|off" or "|on")
    local now = GetTime and GetTime() or 0
    if lastShown[key] and now - lastShown[key] < COOLDOWN then return end
    lastShown[key] = now
    GT.ShowGuildPopup(name, isOffline)
end

-- the Demo button: a pop-up with your own name, so the look and the timing can be checked. Each click shows the next
-- kind: Friend, then Guild Member, then both.
local demoRole = 0
local DEMO_ROLES = { "friend", "guild", "both" }
function GT.GuildPopupDemo()
    local me = (UnitName and UnitName("player")) or "miRidinsa"   -- the character you are playing
    demoRole = demoRole % #DEMO_ROLES + 1
    GT.ShowGuildPopup(me, false, DEMO_ROLES[demoRole])
end

C_Timer.After(5, function() GT.StartGuildRosterTicker() end)
