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
    popup:SetSize(240, 40)
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
    popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.text:SetJustifyH("LEFT")
    popup.details = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.details:SetPoint("BOTTOMLEFT", 10, 8)
    popup.details:SetPoint("RIGHT", -10, 0)
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
    local guild = (guildInfo and guildInfo.guild) or (friendInfo and friendInfo.guild)
    if guild and guild ~= "" then parts[#parts + 1] = guild end
    local zone = guildInfo and guildInfo.zone
    if not zone or zone == "" then zone = friendInfo and friendInfo.zone end
    if zone and zone ~= "" then parts[#parts + 1] = zone end
    if #parts == 0 then return nil end
    return table.concat(parts, " | ")
end

-- shows the pop-up for a name: it slides in, stays for the time set in Settings, then slides out.
-- offline = true shows "is offline" in red; otherwise "is online" in gold.
function GT.ShowGuildPopup(name, offline)
    local p = BuildPopup()
    local details = PopupDetails(name)
    p.text:ClearAllPoints()
    if details then
        p:SetSize(300, 58)
        p.text:SetPoint("TOPLEFT", 10, -8)
        p.text:SetPoint("RIGHT", -10, 0)
        p.details:SetText(details)
        p.details:Show()
    else
        p:SetSize(240, 40)
        p.text:SetPoint("LEFT", 10, 0)
        p.text:SetPoint("RIGHT", -10, 0)
        p.details:Hide()
    end
    if offline then
        p.text:SetText(GT.TRF("%s is offline", name))
        p.text:SetTextColor(1, 0.25, 0.25)
    else
        p.text:SetText(GT.TRF("%s is online", name))
        p.text:SetTextColor(1, 0.82, 0)
    end
    PlayNotifySound(offline and "Windows.ogg" or "Xbox.ogg")
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

-- the Demo button: a pop-up with a made-up name, so the look and the timing can be checked
function GT.GuildPopupDemo()
    local me = (UnitName and UnitName("player")) or "miRidinsa"   -- the character you are playing
    GT.ShowGuildPopup(me)
end

C_Timer.After(5, function() GT.StartGuildRosterTicker() end)
