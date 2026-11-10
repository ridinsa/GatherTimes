-- HideUnitNames.lua : "Random Name" - disguises your own name (and your pet's) on screen, for streaming / screenshots.
--
-- What it covers (local display only, nobody else sees a different name):
--   * unit frames: Player, Pet, Target, Target-of-target and Focus; party / raid name labels can be hidden
--   * the unit tooltip, the character window title, and chat (your name as author and inside system lines)
--   * floating name plates / names of other players, through the UnitName* CVars.  The values you had are saved
--     when the disguise goes on and put back when it goes off (they were reset to "1" before).
--
-- How it stays correct: it never hooks FontString:SetText (that recursed on Classic). It post-hooks Blizzard's
-- update functions (hooksecurefunc, taint-safe) and periodically checks cached frames as a safety net.
local ADDON_NAME = ...
-- Own saved variable (the standalone HideUnitNames addon uses "HideUnitNamesDB", so the two never share data).
GatherTimesHUNDB = GatherTimesHUNDB or {}

local NAME_CVARS = {
    "UnitNameOwn",
    "UnitNameFriendlyPlayerName",
    "UnitNameEnemyPlayerName",
    "UnitNameFriendlyPetName",
    "UnitNameEnemyPetName",
    "UnitNameFriendlyGuardianName",       -- some pets / minions count as guardians or minions, not pets
    "UnitNameEnemyGuardianName",
    "UnitNameFriendlyMinionName",
    "UnitNameEnemyMinionName",
}
local CVAR_DEFAULT = "1"
local MAX_NAME_LETTERS = 12            -- the longest character name the game allows

local PLAYER_NAMES = {
    "Nightblade", "Moonshadow", "Ashwalker", "Stormborn", "Ravencrest", "Duskwhisper", "Frostwind", "Ironshade", "Emberfall", "Starbreaker", "Shadowmere", "Silverthorn", "Dawnstrider", "Voidwalker", "Thunderhelm", "Mistcaller", "Blackthorn", "Goldenshade", "Winterborn", "Flameheart", "Duskrunner", "Stormcaller", "Brightblade", "Grimshadow", "Oakenshield", "Windrider", "Spellweaver", "Runebreaker", "Moonfire", "Starfall", "Riftwalker", "Frostwhisper", "Sunstrider", "Ironbark", "Nightstorm", "Airini", "Akari", "Aki", "Akira", "Amaya", "Anzu", "Asuka", "Ayaka", "Ayame", "Ayumi", "Chie", "Chisato", "Chiyo", "Etsuko", "Fuyuko", "Hanae", "Hanako", "Haruka", "Haruko", "Harumi", "Hina", "Hinata", "Hiroko", "Hitomi", "Honoka", "Hoshimi", "Hotaru", "Iori", "Itsuki", "Junko", "Kaguya", "Kaede", "Kana", "Kano", "Kanoa", "Kaori", "Kasumi", "Kazue", "Keiko", "Kiko", "Kimi", "Kin", "Kokoa", "Koharu", "Kotone", "Kumi", "Kumiko", "Kyoko", "Maiko", "Maki", "Makoto", "Mami", "Manami", "Mao", "Mariko", "Matsuko", "Mayu", "Mayumi", "Megumi", "Mei", "Michiko", "Midori", "Mieko", "Miho", "Mika", "Miki", "Miku", "Mina", "Minako", "Minori", "Mio", "Misaki", "Mitsuko", "Miu", "Miya", "Miyako", "Miyu", "Miyuki", "Nanami", "Nao", "Naoko", "Naomi", "Natsuki", "Natsuko", "Natsumi", "Nene", "Nozomi", "Nyoko", "Ran", "Rei", "Reika", "Ren", "Rika", "Riko", "Rio", "Risa", "Ritsuko", "Rumi", "Ruri", "影","雷電","龍","風","疾風","健二","月","悪魔","蓮","仁","夜","焔","鋼","氷","桜","狼","牙","雷","暁","零","空","光","闇","神","翼","刀","嵐","幻","滅","天","하늘빛", "유나별", "새벽달", "은하수", "밤하늘", "달빛", "햇살", "이슬", "바다", "구름", "안개", "파도", "봄날", "단풍", "겨울눈", "여름꽃", "소나기", "눈송이", "별똥별", "들꽃","게임왕", "암살자", "유령", "그림자", "폭풍", "불꽃", "검사", "수호자", "저격수", "끝판왕", "절대자", "사냥꾼", "투사", "강철", "독수리", "호랑이", "늑대", "용의눈", "흑기사", "파괴자",
}
local PET_NAMES = {
    "Frostfang", "Shadowpaw", "Emberclaw", "Stormtail", "Nightpelt", "Ashfang", "Dawnhowl", "Ironfang", "Moonfang", "Thundertail", "Snowpaws", "Darkwhisker", "Flamepaw", "Swiftclaw", "Dusktalon", "Brightfang", "Razorhide", "Windfur", "Mistrunner", "Stormpaws", "Coalnose", "Goldfur", "Wildfang", "Thornback", "Nightwhisker", "Ajisai", "Anko", "Aojiru", "Aori", "Arashi", "Banzai", "Bento", "Biki", "Biko", "Bonbon", "Bonsai", "Bunny", "Chacha", "Chamu", "Chiko", "Chiku", "Chikuw", "Chiyo", "Choco", "Cookie", "Daifuku", "Dango", "Donburi", "Dorayaki", "Fuku", "Goma", "Gyoza", "Hachiko", "Hammy", "Ichigo", "Inu", "Jiji", "Kabu", "Kakigori", "Kani", "Kappo", "Karage", "Katsu", "Kiki", "Kiko", "Kimi", "Kinako", "Kini", "Kinka", "Kinto", "Kippie", "Kira", "Koba", "Kobo", "Koji", "Koko", "Komugi", "Kona", "Konbu", "Koneko", "Koni", "Konta", "Kuma", "Kumi", "Kumo", "Kuri", "Kurumi", "Lala", "Lili", "Lilo", "Lulu", "Mamu", "Manju", "Maru", "Meko", "Mimi", "Momo", "Mumu", "Nana", "Neko", "Nini", "Noko", "Nono", "Nori", "Oden", "Onigiri", "Panko", "Peco", "Pippo", "Pochi", "Poko", "Pomi", "Pomu", "Poni", "Popo", "Puku", "Pumi", "Rara", "Riko", "Rimi", "Rini", "Riri", "Romi", "Ruru",	"影","雷電","龍","風","疾風","健二","月","悪魔","蓮","仁","夜","焔","鋼","氷","桜","狼","牙","雷","暁","零","空","光","闇","神","翼","刀","嵐","幻","滅","天","만두", "모찌", "초코", "우유", "딸기", "두부", "푸딩", "아기곰", "야옹이", "댕댕이", "토끼", "꿀벌", "젤리", "설탕", "단팥", "구미호", "체리", "망고", "식빵", "솜사탕","비밀", "마법사", "신화", "악마", "천사", "영혼", "환상", "새벽빛", "기적", "시공", "흑화", "차원", "불멸", "운명", "낙원", "무지개", "심해", "유성", "미로", "심장","메롱", "꿀잠", "초보왕", "일등", "대박", "빵터짐", "고수", "까칠이", "민트초코", "라면먹어", "킹받네", "나야나", "정답", "비켜라", "밥도둑", "운빨", "노빠꾸", "돌진", "물어뜯어", "만렙",
}

-- ---------------------------------------------------------------- saved data
local function PickName(list, avoid)
    local pick = list[math.random(1, #list)]
    for _ = 1, 8 do
        if pick ~= avoid then break end
        pick = list[math.random(1, #list)]
    end
    return pick
end

local function NormalizeLevel(value, fallback)
    local level = tonumber(value)
    if not level or level ~= level or level == math.huge or level == -math.huge then level = fallback end
    return math.max(1, math.min(60, math.floor(level + 0.5)))
end

local function InitDB()
    if type(GatherTimesHUNDB) ~= "table" then GatherTimesHUNDB = {} end
    local db = GatherTimesHUNDB
    if db.hideAll == nil then db.hideAll = false end
    if db.groupNames == nil then db.groupNames = false end
    if db.hideBagTitle == nil then db.hideBagTitle = true end
    if db.hideToTInCombat == nil then db.hideToTInCombat = true end
    db.fakeLevelMax = NormalizeLevel(db.fakeLevelMax, 60)
    local savedLevel = tonumber(db.fakeLevel)
    if not savedLevel or savedLevel ~= savedLevel or savedLevel == math.huge or savedLevel == -math.huge
        or savedLevel < 1 or savedLevel > db.fakeLevelMax then
        db.fakeLevel = math.random(1, db.fakeLevelMax)
    else
        db.fakeLevel = math.floor(savedLevel)
    end
    if type(db.fakePlayerName) ~= "string" or db.fakePlayerName == "" then db.fakePlayerName = PickName(PLAYER_NAMES) end
    if type(db.fakePetName) ~= "string" or db.fakePetName == "" then db.fakePetName = PickName(PET_NAMES) end
    db.groupNameMap = nil
    return db
end

local function Enabled()
    return type(GatherTimesHUNDB) == "table" and GatherTimesHUNDB.hideAll == true
end

local function GroupNamesEnabled()
    return type(GatherTimesHUNDB) == "table" and GatherTimesHUNDB.groupNames == true
end

local function InGroup(unit)
    if type(unit) ~= "string" then return false end
    if UnitInParty and UnitInParty(unit) then return true end
    if UnitInRaid and UnitInRaid(unit) then return true end
    return false
end

-- The standalone HideUnitNames addon has the same /hun command and chat filters. When it is loaded, this embedded copy
-- steps aside (decided at PLAYER_LOGIN, when every addon is loaded).
local standalone = false
local function StandaloneLoaded()
    local f = (type(C_AddOns) == "table" and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if type(f) ~= "function" then return false end
    local ok, loaded = pcall(f, "HideUnitNames")
    return ok and loaded and true or false
end

-- Once: copy the settings from the old saved variable (HideUnitNamesDB, used by GatherTimes up to 0.22.1) into
-- GatherTimesHUNDB. The old variable itself is left alone (the standalone addon may own it).
local function MigrateOldSettings()
    local db = GatherTimesHUNDB
    if db.migrated then return end
    local old = HideUnitNamesDB
    if type(old) == "table" then
        for _, key in ipairs({ "hideAll", "fakePlayerName", "fakePetName", "frameAlpha", "savedCVars" }) do
            local v = old[key]
            if type(v) == "table" then
                local copy = {}
                for k, x in pairs(v) do copy[k] = x end
                db[key] = copy
            elseif v ~= nil then
                db[key] = v
            end
        end
    end
    db.migrated = true
end

-- A typed name: no escape codes ("|"), no control characters, at most MAX_NAME_LETTERS characters (UTF-8 aware).
local function CleanName(s)
    s = tostring(s or "")
    s = s:gsub("|", ""):gsub("%c", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local out, n = {}, 0
    for ch in s:gmatch("[\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > MAX_NAME_LETTERS then break end
        out[n] = ch
    end
    return (table.concat(out):gsub("%s+$", ""))      -- the cut can end on a space
end

local listeners = {}
local function Notify()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

-- ---------------------------------------------------------------- real names (needed to find them in text)
local realPlayer, realPet
local function RememberNames()
    if not UnitName then return end
    local n = UnitName("player")
    if type(n) == "string" and n ~= "" and n ~= UNKNOWNOBJECT then realPlayer = n end
    if UnitExists and UnitExists("pet") then
        local p = UnitName("pet")
        if type(p) == "string" and p ~= "" and p ~= UNKNOWNOBJECT then realPet = p end
    end
end

-- the fake name for a unit token, or nil when the unit is neither you nor your pet (or the disguise is off)
local function FakeForUnit(unit)
    if type(unit) ~= "string" or not UnitExists(unit) then return nil end
    local db = GatherTimesHUNDB
    if UnitIsUnit(unit, "player") then return (Enabled() and db.fakePlayerName) or nil end
    if UnitIsUnit(unit, "pet") then return (Enabled() and db.fakePetName) or nil end
    return nil
end

local function FakeLevelForUnit(unit)
    if Enabled() and unit and UnitIsUnit(unit, "player") then
        return GatherTimesHUNDB.fakeLevel or InitDB().fakeLevel
    end
end

-- ---------------------------------------------------------------- text replacement (chat, tooltip, character window)
-- only ASCII letters, digits and "_" make a word: a name next to Korean / Chinese / Japanese text ("Hero님") is still
-- a whole word and must be hidden. (Bytes 128+ used to count as word characters, so those names leaked.)
local function IsWordByte(b)
    return b ~= nil and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

local function ContainsWholeName(text, name)
    local pos = 1
    while true do
        local first, last = text:find(name, pos, true)
        if not first then return false end
        local before = first - 1
        local colorStart = first - 10
        if colorStart > 0 and text:sub(colorStart, first - 1):match("^|c%x%x%x%x%x%x%x%x$") then
            before = colorStart - 1
        end
        if not IsWordByte(text:byte(before)) and not IsWordByte(text:byte(last + 1)) then return true end
        pos = last + 1
    end
end

-- replace every whole-word `real` in s with `fake` ("Ann" is not found inside "Anna"; the "[Ann]" of a chat link is)
local function ReplaceName(s, real, fake)
    if type(s) ~= "string" or type(real) ~= "string" or real == "" or type(fake) ~= "string" or real == fake then return s end
    if not s:find(real, 1, true) then return s end      -- most texts never hold the name: no table, no loop
    local out, pos, changed = {}, 1, false
    while true do
        local a, b = s:find(real, pos, true)
        if not a then break end
        if not IsWordByte(s:byte(a - 1)) and not IsWordByte(s:byte(b + 1)) then
            out[#out + 1] = s:sub(pos, a - 1)
            out[#out + 1] = fake
            changed = true
        else
            out[#out + 1] = s:sub(pos, b)
        end
        pos = b + 1
    end
    if not changed then return s end
    out[#out + 1] = s:sub(pos)
    return table.concat(out)
end

local function IsFontString(r)
    return r and type(r.GetObjectType) == "function" and type(r.GetText) == "function"
        and type(r.SetText) == "function" and r:GetObjectType() == "FontString"
end

-- ---------------------------------------------------------------- unit frames
local UNIT_FRAMES = {
    { frame = "PlayerFrame",    unit = "player",       globals = { "PlayerName", "PlayerFrameName", "PlayerFrameTextureFrameName" },
      levelGlobals = { "PlayerLevelText", "PlayerFrameLevelText" } },
    { frame = "PetFrame",       unit = "pet",          globals = { "PetName", "PetFrameName" } },
    { frame = "TargetFrame",    unit = "target",       globals = { "TargetName", "TargetFrameTextureFrameName" },
      levelGlobals = { "TargetFrameLevelText" } },
    { frame = "TargetFrameToT", unit = "targettarget", globals = { "TargetFrameToTTextureFrameName" } },
    { frame = "FocusFrame",     unit = "focus",        globals = { "FocusName", "FocusFrameTextureFrameName" },
      levelGlobals = { "FocusFrameLevelText" } },
    { frame = "FocusFrameToT",  unit = "focustarget",  globals = { "FocusFrameToTTextureFrameName" } },
}
for _, entry in ipairs(UNIT_FRAMES) do entry.found = {} end

-- every name FontString this module changed: region -> { fake, frame, unit, realText }
local faked = {}
local fakedLevels = {}
local compactFrames = setmetatable({}, { __mode = "k" })

local function RealNameOf(info)
    local frame = info.frame
    local unit = info.unit
    if frame and frame.unit then unit = frame.unit end
    if not (unit and UnitExists(unit)) then return nil end
    if GetUnitName then return GetUnitName((frame and frame.overrideName) or unit, false) end
    return UnitName(unit)
end

-- put the game's own text back, but only when the region still shows OUR fake (Blizzard may have rewritten it)
local function RestoreRegion(region, info)
    if region:GetText() ~= info.fake then return end
    if info.realText then
        region:SetText(info.realText)
        return
    end
    local real = RealNameOf(info)
    region:SetText(real or "")          -- the unit is gone (pet dismissed, target cleared): never leave the fake behind
end

local function RestoreAll()
    for region, info in pairs(faked) do
        pcall(RestoreRegion, region, info)
        faked[region] = nil
    end
end

local function RestoreLevel(region)
    local info = fakedLevels[region]
    if not info then return end
    if region:GetText() == info.fake then region:SetText(info.realText) end
    fakedLevels[region] = nil
end

local function RestoreAllLevels()
    for region in pairs(fakedLevels) do pcall(RestoreLevel, region) end
end

local function ReplaceLevelText(text, realLevel, fakeLevel)
    if type(text) ~= "string" or not realLevel then return nil end
    local replaced, count = text:gsub("%d+", function(number)
        if tonumber(number) == realLevel then return tostring(fakeLevel) end
        return number
    end, 1)
    return count > 0 and replaced or nil
end

local function ProcessLevelRegion(region, unit)
    if not IsFontString(region) then return end
    local fakeLevel = FakeLevelForUnit(unit)
    if not fakeLevel then RestoreLevel(region); return end

    local realLevel = UnitLevel and UnitLevel(unit)
    if not realLevel then return end
    local info = fakedLevels[region]
    local current = region:GetText()
    if info then
        if current == info.fake then
            if realLevel == info.realLevel and fakeLevel == info.fakeLevel then return end   -- unchanged: no string work
            info.realText = ReplaceLevelText(info.realText, info.realLevel, realLevel) or info.realText
            info.realLevel = realLevel
            if fakeLevel == info.fakeLevel then return end
            current = info.realText
        else
            info.realText = current
        end
    end

    local fakeText = ReplaceLevelText(current, realLevel, fakeLevel)
    if fakeText and fakeText ~= current then
        region:SetText(fakeText)
        fakedLevels[region] = { fake = fakeText, fakeLevel = fakeLevel, realLevel = realLevel, realText = current }
    elseif info then
        fakedLevels[region] = nil
    end
end

local function Track(region, fake, frame, unit, realText)
    local info = faked[region]
    if not info then
        faked[region] = { fake = fake, frame = frame, unit = unit, realText = realText }
    else
        info.fake, info.frame, info.unit = fake, frame, unit
        info.realText = realText or info.realText
    end
end

-- the frame no longer shows you / your pet (target changed, pet dismissed): forget what was changed there
local function DropEntry(entry)
    for region in pairs(entry.found) do
        local info = faked[region]
        if info then
            pcall(RestoreRegion, region, info)
            faked[region] = nil
        end
    end
end

-- Reusable tables and loops. The unit-frame hooks run on every unit update, so these avoid creating new tables each time.
local function wipeTable(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
local function forEachChild(fn, extra, ...)
    for i = 1, select("#", ...) do fn((select(i, ...)), extra) end
end
local entryRegions = {}
local scanSeen = {}

local function scanRegionsInto(found, real, ...)
    for i = 1, select("#", ...) do
        local r = (select(i, ...))
        if IsFontString(r) then
            local text = r:GetText()
            if text == real or ReplaceName(text, real, "GatherTimes") ~= text then found[r] = true end
        end
    end
end

-- name FontStrings of a unit frame: the known ones, the ones found before, and (about once a second) any FontString
-- in the frame or its children that shows the real name - so a different frame layout is still covered
local scanReal, scanFound
local function scanNode(f)
    if not f or scanSeen[f] then return end
    scanSeen[f] = true
    if f.GetRegions then scanRegionsInto(scanFound, scanReal, f:GetRegions()) end
    if f.GetChildren then forEachChild(scanNode, nil, f:GetChildren()) end
end
local function ScanFrame(frame, real, found)
    if type(real) ~= "string" or real == "" then return end
    wipeTable(scanSeen)
    scanReal, scanFound = real, found
    scanNode(frame)
    scanReal, scanFound = nil, nil
    wipeTable(scanSeen)
end

local NO_GLOBALS = {}
local function ProcessEntry(entry)
    local frame = _G[entry.frame]
    if not frame then return end
    local unit = frame.unit or entry.unit
    for _, g in ipairs(entry.levelGlobals or NO_GLOBALS) do ProcessLevelRegion(_G[g], unit) end
    local fake = FakeForUnit(unit)
    if not fake then
        DropEntry(entry)
        return
    end
    local now = GetTime and GetTime() or 0
    if now >= (entry.nextScan or 0) then
        entry.nextScan = now + 1
        ScanFrame(frame, UnitName(unit), entry.found)
    end
    local regions = wipeTable(entryRegions)
    if IsFontString(frame.name) then regions[frame.name] = true end
    for _, g in ipairs(entry.globals) do
        if IsFontString(_G[g]) then regions[_G[g]] = true end
    end
    for region in pairs(entry.found) do regions[region] = true end
    for region in pairs(regions) do
        if region:GetText() ~= fake then region:SetText(fake) end
        entry.found[region] = true
        Track(region, fake, frame, unit)
    end
end

local function FrameUnit(frame)
    local unit = frame.displayedUnit or frame.unit
    if not unit and type(frame.GetAttribute) == "function" then
        local ok, value = pcall(frame.GetAttribute, frame, "unit")
        if ok then unit = value end
    end
    return type(unit) == "string" and unit or nil
end

local hiddenGroupNames = setmetatable({}, { __mode = "k" })

local function HideGroupName(region)
    if not hiddenGroupNames[region] then
        hiddenGroupNames[region] = region:GetAlpha()
    end
    if region:GetAlpha() ~= 0 then region:SetAlpha(0) end
end

local function RestoreGroupNames()
    for region, alpha in pairs(hiddenGroupNames) do
        pcall(region.SetAlpha, region, alpha)
        hiddenGroupNames[region] = nil
    end
end

local groupRegions = {}
local function collectGroupRegions(regions, real, ...)
    for i = 1, select("#", ...) do
        local region = (select(i, ...))
        if IsFontString(region) then
            local text = region:GetText()
            if text == real or ReplaceName(text, real, "GatherTimes") ~= text
                or hiddenGroupNames[region] then
                regions[region] = true
            end
        end
    end
end

local function ProcessGroupFrame(frame)
    if not frame or type(frame.GetObjectType) ~= "function" then return end
    local unit = FrameUnit(frame)
    if not (unit and InGroup(unit) and UnitExists(unit)) then return end
    local real = GetUnitName and GetUnitName(frame.overrideName or unit, true) or UnitName(unit)
    if type(real) ~= "string" or real == "" then return end

    local regions = wipeTable(groupRegions)
    if IsFontString(frame.name) then regions[frame.name] = true end
    if frame.GetRegions then collectGroupRegions(regions, real, frame:GetRegions()) end
    for region in pairs(regions) do HideGroupName(region) end
end

local function ProcessGroupTree(frame, seen)
    if not frame or seen[frame] or type(frame.GetObjectType) ~= "function" then return end
    seen[frame] = true
    ProcessGroupFrame(frame)
    if frame.GetChildren then forEachChild(ProcessGroupTree, seen, frame:GetChildren()) end
end

local GROUP_FRAME_ROOTS = {
    "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer", "RaidFrame", "RaidParentFrame",
}
for i = 1, 8 do
    GROUP_FRAME_ROOTS[#GROUP_FRAME_ROOTS + 1] = "CompactRaidGroup" .. i
    GROUP_FRAME_ROOTS[#GROUP_FRAME_ROOTS + 1] = "RaidGroup" .. i
end

local function DiscoverCompactFrames()
    for i = 1, 4 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then compactFrames[frame] = true end
    end
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then compactFrames[frame] = true end
    end
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then compactFrames[frame] = true end
        end
    end
end

local function DiscoverGlobalGroupFrames()
    for _, frame in pairs(_G) do
        local kind = type(frame)
        if (kind == "table" or kind == "userdata") and type(frame.GetObjectType) == "function" then
            local unit = FrameUnit(frame)
            if unit and (unit:match("^party%d+$") or unit:match("^raid%d+$")) then
                compactFrames[frame] = true
            end
        end
    end
end

-- Name plates (the bar with the name above you or your pet, shown e.g. when you click the pet): the fake name goes
-- into the plate's name text.  Restored by RestoreAll like the other frames.
local function ProcessNamePlate(frame)
    if not Enabled() or type(frame) ~= "table" then return end
    local unit = frame.unit
    if type(unit) ~= "string" or not unit:find("^nameplate") then return end
    local fake = FakeForUnit(unit)
    if not (fake and IsFontString(frame.name)) then return end
    if frame.name:GetText() ~= fake then frame.name:SetText(fake) end
    Track(frame.name, fake, frame, unit)
end

local nextPlateScan = 0
local function RefreshNamePlates()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local now = GetTime and GetTime() or 0
    if now < nextPlateScan then return end
    nextPlateScan = now + 0.2                          -- GetNamePlates builds a new table each call
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if plate.UnitFrame then pcall(ProcessNamePlate, plate.UnitFrame) end
    end
end

local function RefreshFrames()
    if not Enabled() then
        if next(faked) then RestoreAll() end
        RestoreAllLevels()
        return
    end
    for _, entry in ipairs(UNIT_FRAMES) do pcall(ProcessEntry, entry) end
    RefreshNamePlates()
end

-- The unit-frame hooks fire on every unit update (health, power, auras). Instead of a full pass each time,
-- they ask for one pass on the next frame; many events in the same frame share that single pass.
local frameRefreshPending = false
local function RunFrameRefresh()
    frameRefreshPending = false
    if Enabled() then RefreshFrames() end
end
local function ScheduleFrameRefresh()
    if frameRefreshPending or not Enabled() then return end
    if C_Timer and C_Timer.After then
        frameRefreshPending = true
        C_Timer.After(0, RunFrameRefresh)
    else
        RefreshFrames()
    end
end

local lastGlobalScan = -100
local function RefreshGroupNames()
    if not GroupNamesEnabled() then
        RestoreGroupNames()
        return
    end
    DiscoverCompactFrames()
    local now = GetTime and GetTime() or 0
    if now - lastGlobalScan >= 5 then          -- walks every global: not on each roster update
        lastGlobalScan = now
        DiscoverGlobalGroupFrames()
    end
    local seen = {}
    for _, name in ipairs(GROUP_FRAME_ROOTS) do ProcessGroupTree(_G[name], seen) end
    for frame in pairs(compactFrames) do pcall(ProcessGroupTree, frame, seen) end
end

-- ---------------------------------------------------------------- text-only places (character window)
local TEXT_REGIONS = { "CharacterNameText", "CharacterFrameTitleText" }
local LEVEL_TEXT_REGIONS = { "CharacterLevelText", "PaperDollFrameLevelText" }
local textFake                     -- the fake name currently written into those regions

local function RefreshTextRegions()
    local db = GatherTimesHUNDB
    local want = Enabled() and db.fakePlayerName or nil
    for _, g in ipairs(TEXT_REGIONS) do
        local r = _G[g]
        if IsFontString(r) then
            local t = r:GetText()
            if type(t) == "string" and realPlayer then
                if textFake and textFake ~= want then
                    t = ReplaceName(t, textFake, realPlayer)       -- off, or the fake name changed: back to the real one first
                end
                -- a fake name that contains the real one ("Ann" -> "Ann-Marie") must not be replaced again on every refresh
                if want and not t:find(want, 1, true) then t = ReplaceName(t, realPlayer, want) end
                if t ~= r:GetText() then r:SetText(t) end
            end
        end
    end
    textFake = want
end

local function RefreshCharacterLevel()
    for _, g in ipairs(LEVEL_TEXT_REGIONS) do ProcessLevelRegion(_G[g], "player") end
end

-- ---------------------------------------------------------------- name plates / other players: the UnitName* CVars
local function GetCVarSafe(name)
    local f = GetCVar or (C_CVar and C_CVar.GetCVar)
    if not f then return nil end
    local ok, v = pcall(f, name)
    if ok and v ~= nil then return tostring(v) end
    return nil
end

local function SetCVarSafe(name, value)
    local f = SetCVar or (C_CVar and C_CVar.SetCVar)
    if f then pcall(f, name, tostring(value)) end
end

-- remember what the player had, so switching the disguise off puts exactly that back.  useDefaults: the disguise was
-- already on in a saved file of an older version, which never recorded the old values - assume the game default.
local function SaveCVars(useDefaults)
    local db = GatherTimesHUNDB
    db.savedCVars = {}
    for _, cvar in ipairs(NAME_CVARS) do
        db.savedCVars[cvar] = useDefaults and CVAR_DEFAULT or GetCVarSafe(cvar) or CVAR_DEFAULT
    end
end

local function ApplyCVars(hide)
    local db = GatherTimesHUNDB
    if hide then
        if type(db.savedCVars) ~= "table" then db.savedCVars = {} end
        for _, cvar in ipairs(NAME_CVARS) do
            -- a setting added in a newer version (disguise already on): remember the player's value before it is hidden
            if db.savedCVars[cvar] == nil then db.savedCVars[cvar] = GetCVarSafe(cvar) end
            SetCVarSafe(cvar, 0)
        end
    elseif type(db.savedCVars) == "table" then
        for _, cvar in ipairs(NAME_CVARS) do
            local v = db.savedCVars[cvar]
            if v ~= nil then SetCVarSafe(cvar, v) end
        end
        db.savedCVars = nil
    end
    -- nothing saved and the disguise off: the player's own settings are left alone (they used to be forced to 1 at every login)
end

-- ---------------------------------------------------------------- target-of-target hidden in combat
-- While the disguise is on and you are in combat, the target-of-target frame is made fully transparent (option
-- "Hide target-of-target in combat", on by default).  It is the frame's alpha that changes, not Show / Hide: the
-- frame is a secure frame, and showing or hiding it is blocked in combat, while SetAlpha is allowed.
local inCombat = false
local totHidden, totAlpha = false, nil

local function ToTFrame()
    return _G.TargetFrameToT or (_G.TargetFrame and _G.TargetFrame.totFrame)
end

local function ToTWanted()
    return inCombat and Enabled() and not standalone and GatherTimesHUNDB.hideToTInCombat ~= false
end

local function RefreshToT()
    local frame = ToTFrame()
    if not (frame and frame.SetAlpha and frame.GetAlpha) then return end
    if ToTWanted() then
        if not totHidden then totAlpha, totHidden = frame:GetAlpha(), true end
        if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
    elseif totHidden then
        frame:SetAlpha(totAlpha or 1)
        totAlpha, totHidden = nil, false
    end
end

local function SyncCombatState()
    inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false
end

-- ---------------------------------------------------------------- everything at once
local SyncTicker                                       -- set below, next to the event frame

local function CharacterOpen()
    local f = _G.CharacterFrame
    return f and f.IsShown and f:IsShown() or false
end

local function Refresh()
    if not realPlayer then RememberNames() end         -- the names are remembered on login and on the name / pet events
    RefreshFrames()
    -- the character window texts only matter while it is open (its OnShow hook refreshes again); the disguise being off
    -- always runs them, so the real texts come back
    if CharacterOpen() or not Enabled() then
        RefreshTextRegions()
        RefreshCharacterLevel()
    end
    RefreshToT()
end

-- nothing to do and nothing to put back: events then skip the refresh
local function Idle()
    return not Enabled() and not totHidden and not textFake and next(faked) == nil and next(fakedLevels) == nil
end

local function ApplyAll()
    local db = InitDB()
    if db.hideAll and type(db.savedCVars) ~= "table" then SaveCVars(true) end
    ApplyCVars(db.hideAll == true)
    Refresh()
    RefreshGroupNames()
    SyncTicker()
end

local refreshPending = false
local function RunRefresh()
    refreshPending = false
    Refresh()
end
local function RefreshSoon()
    if refreshPending then return end                  -- several events in one frame share one pass
    if C_Timer and C_Timer.After then
        refreshPending = true
        C_Timer.After(0, RunRefresh)
    else
        Refresh()
    end
end

-- ---------------------------------------------------------------- tooltip, chat, Blizzard hooks
local function FixTooltip(tip)
    if not Enabled() or not (tip and tip.GetUnit) then return end
    local _, unit = tip:GetUnit()
    local fake = FakeForUnit(unit)
    if not fake then return end
    local line = _G[((tip.GetName and tip:GetName()) or "GameTooltip") .. "TextLeft1"]
    if not IsFontString(line) then return end
    local text = line:GetText()
    local real = UnitIsUnit(unit, "player") and realPlayer or realPet
    local new = ReplaceName(text, real, fake)
    if new == text then new = fake end
    line:SetText(new)
    if tip.Show then tip:Show() end
end

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT",
}

-- A chat filter returns false (nothing changed) or false plus ALL the arguments from the message on (changed).
local function ChatFilter(_, _, msg, author, ...)
    if not Enabled() or not realPlayer then return false end
    local fake = GatherTimesHUNDB.fakePlayerName
    local newMsg, newAuthor = ReplaceName(msg, realPlayer, fake), ReplaceName(author, realPlayer, fake)
    if newMsg == msg and newAuthor == author then return false end
    return false, newMsg, newAuthor, ...
end

local hooksInstalled
local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    -- Blizzard's own update functions: after they wrote the real name, write the fake one (same frame, no flicker).
    -- Hook individual unit-frame updates so hidden labels stay hidden without rescanning the frame tree.
    if hooksecurefunc then
        for _, fname in ipairs({ "UnitFrame_Update", "UnitFrame_OnEvent", "PlayerFrame_Update", "PetFrame_Update", "TargetFrame_Update" }) do
            if type(_G[fname]) == "function" then
                pcall(hooksecurefunc, fname, function(frame)
                    if GroupNamesEnabled() and frame then
                        local unit = FrameUnit(frame)
                        if unit and InGroup(unit) then pcall(ProcessGroupFrame, frame) end
                    end
                    ScheduleFrameRefresh()
                end)
            end
        end
        if type(_G.CompactUnitFrame_UpdateName) == "function" then
            pcall(hooksecurefunc, "CompactUnitFrame_UpdateName", function(frame)
                if Enabled() then pcall(ProcessNamePlate, frame) end
                if GroupNamesEnabled() then pcall(ProcessGroupFrame, frame) end
            end)
        end
        if type(_G.PaperDollFrame_SetLevel) == "function" then
            pcall(hooksecurefunc, "PaperDollFrame_SetLevel", function()
                if Enabled() then RefreshTextRegions(); RefreshCharacterLevel() end
            end)
        end
    end
    if _G.CharacterFrame and CharacterFrame.HookScript then
        pcall(CharacterFrame.HookScript, CharacterFrame, "OnShow", function() Refresh() end)
    end

    -- tooltip (new tooltip system when the client has it, otherwise the OnTooltipSetUnit script)
    if _G.GameTooltip then
        local done = false
        if _G.TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and _G.Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
            done = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tip)
                if tip == GameTooltip then pcall(FixTooltip, tip) end
            end)
        end
        if not done and GameTooltip.HookScript then
            pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tip) pcall(FixTooltip, tip) end)
        end
    end

    -- chat
    if ChatFrame_AddMessageEventFilter then
        for _, ev in ipairs(CHAT_EVENTS) do pcall(ChatFrame_AddMessageEventFilter, ev, ChatFilter) end
    end
end

-- ---------------------------------------------------------------- actions
local function SetEnabled(on)
    local db = InitDB()
    on = on == true
    if on and type(db.savedCVars) ~= "table" then SaveCVars(false) end
    db.hideAll = on
    ApplyCVars(on)
    Refresh()
    SyncTicker()
    Notify()
end

-- name = nil keeps the current one.  Returns true when something changed.
local function SetNames(playerName, petName)
    local db = InitDB()
    local changed = false
    local p, q = CleanName(playerName), CleanName(petName)
    if p ~= "" and p ~= db.fakePlayerName then db.fakePlayerName = p; changed = true end
    if q ~= "" and q ~= db.fakePetName then db.fakePetName = q; changed = true end
    if changed then Refresh(); Notify() end
    return changed
end

local function RandomizeNames(silent)
    local db = InitDB()
    db.fakePlayerName = PickName(PLAYER_NAMES, db.fakePlayerName)
    db.fakePetName = PickName(PET_NAMES, db.fakePetName)
    db.fakeLevel = math.random(1, db.fakeLevelMax)
    Refresh()
    Notify()
    if not silent then
        print("|cffffd200HideUnitNames: new fake names saved. Player: " .. db.fakePlayerName .. " / Pet: "
            .. db.fakePetName .. " / Level: " .. db.fakeLevel .. "|r")
    end
end

local function SetMaxRandomLevel(value)
    local db = InitDB()
    local maxLevel = NormalizeLevel(value, 60)
    db.fakeLevelMax = maxLevel
    db.fakeLevel = math.min(db.fakeLevel, maxLevel)
    Refresh()
    Notify()
end

-- Public interface used by GatherTimes' Random Name window.
local api = _G.GatherTimesNameDisguise or {}
_G.GatherTimesNameDisguise = api
api.Apply = function() RefreshSoon() end
api.SetEnabled = SetEnabled
api.IsEnabled = function() InitDB(); return Enabled() end
api.SetGroupNames = function(on)
    local db = InitDB()
    db.groupNames = on == true
    RefreshGroupNames()
    Refresh()
    Notify()
end
api.IsGroupNamesEnabled = function() InitDB(); return GroupNamesEnabled() end
api.IsBagTitleHidden = function() return InitDB().hideBagTitle ~= false end
api.SetBagTitleHidden = function(on)
    InitDB().hideBagTitle = on == true
    Notify()
end
api.IsHideToTInCombat = function() return InitDB().hideToTInCombat ~= false end
api.SetHideToTInCombat = function(on)
    InitDB().hideToTInCombat = on == true
    RefreshToT()
    Notify()
end
api.Randomize = function() RandomizeNames(true) end
api.GetMaxRandomLevel = function() return InitDB().fakeLevelMax end
api.SetMaxRandomLevel = SetMaxRandomLevel
local knownPlayerNames
local function KnownPlayerNames()
    if knownPlayerNames then return knownPlayerNames end
    local api = _G.Syndicator and _G.Syndicator.API
    if not (api and type(api.GetAllCharacters) == "function" and type(api.GetCharacter) == "function") then
        return realPlayer and realPlayer ~= "" and { realPlayer } or {}
    end
    local ok, characters = pcall(api.GetAllCharacters)
    if not ok or type(characters) ~= "table" then return realPlayer and realPlayer ~= "" and { realPlayer } or {} end
    knownPlayerNames = {}
    if realPlayer and realPlayer ~= "" then knownPlayerNames[#knownPlayerNames + 1] = realPlayer end
    for _, fullName in ipairs(characters) do
        local got, info = pcall(api.GetCharacter, fullName)
        local details = got and type(info) == "table" and info.details
        local name = type(details) == "table" and details.character
        if type(name) ~= "string" or name == "" then
            name = type(fullName) == "string" and fullName:match("^([^-]+)") or nil
        end
        if type(name) == "string" and name ~= "" then knownPlayerNames[#knownPlayerNames + 1] = name end
    end
    return knownPlayerNames
end

local function HasKnownPlayerName(text)
    if type(text) ~= "string" then return false end
    if not realPlayer then RememberNames() end
    for _, name in ipairs(KnownPlayerNames()) do
        if ContainsWholeName(text, name) then return true end
    end
    return false
end

-- ---------------------------------------------------------------- bag window title (always on)
-- Baganator titles its bag window "<character>'s Bags". That whole title is blanked while Random Name is on, and comes
-- back when it is switched off. Nothing runs on a timer: the window is fixed when it is shown and when Baganator sets its title.
local bagWindows = setmetatable({}, { __mode = "k" })
local bagTexts = setmetatable({}, { __mode = "k" })
local bagOriginal = setmetatable({}, { __mode = "k" })   -- the real text of a blanked title, to give back
local bagStrings = setmetatable({}, { __mode = "k" })   -- the few texts that ever held a character name; re-checked while a bag window is shown
local bagForced = setmetatable({}, { __mode = "k" })   -- title texts that are always blanked while Random Name is on
local bagMixinWrapped, bagFindPending, bagWindowCount, bagOpenHooked = false, false, 0, false
local bagSearchTicks = 0
local ScanBagObject, FindBagWindows, BagTitleText

local function IsBagWindowName(name)
    if type(name) ~= "string" then return false end
    if name:find("^Baganator") then return name:find("BackpackView", 1, true) ~= nil end
    return name:find("^Bagnon") ~= nil or name:find("^AdiBags") ~= nil
end

-- A real bag window, not one of its buttons or slots.  Baganator: the frame with a title text.  Bagnon and AdiBags:
-- a frame sitting directly on the screen (their item slots and bars have other parents).
local function IsBagTopWindow(name, frame)
    if not IsBagWindowName(name) or type(frame) ~= "table" or type(frame.GetObjectType) ~= "function"
        or type(frame.GetChildren) ~= "function" then return false end
    if name:find("^Baganator") then return BagTitleText(frame) ~= nil end
    return frame:GetObjectType() == "Frame" and type(frame.GetParent) == "function" and frame:GetParent() == _G.UIParent
end

-- the bag header is only touched while Random Name is on AND the "Hide name in bag header" box is ticked
local function BagActive()
    return Enabled() and not standalone and GatherTimesHUNDB.hideBagTitle ~= false
end

local function BagTextFixed(text)
    if not BagActive() or type(text) ~= "string" or text == "" then return text end
    if text:find("Bags$") then return "" end
    if not realPlayer then RememberNames() end
    for _, name in ipairs(KnownPlayerNames()) do
        if ContainsWholeName(text, name) then return "" end
    end
    return text
end

local function BagWanted(fs, text)
    if bagForced[fs] and BagActive() then return "" end
    return BagTextFixed(text)
end

local function FixBagFontString(fs, isTitle)
    if isTitle then bagForced[fs] = true end
    local text = fs:GetText()
    local fixed = BagWanted(fs, text)
    if fixed ~= text then
        if type(text) == "string" and text ~= "" then bagOriginal[fs] = text end
        fs:SetText(fixed)
    end
    if (fixed ~= text or isTitle) and not bagTexts[fs] then
        bagTexts[fs] = true
        bagStrings[fs] = true
        if type(_G.hooksecurefunc) == "function" then
            _G.hooksecurefunc(fs, "SetText", function(self, newText)
                local again = BagWanted(self, newText)
                if again ~= newText then
                    if type(newText) == "string" and newText ~= "" then bagOriginal[self] = newText end
                    self:SetText(again)
                end
            end)
        end
    end
end

BagTitleText = function(frame)
    local t = frame.TitleText or frame.titleText or frame.Title
        or (type(frame.GetTitleText) == "function" and frame:GetTitleText()) or nil
    if type(t) == "table" and type(t.GetText) == "function" and type(t.SetText) == "function" then return t end
    return nil
end

-- a text label, or a button that carries a text (Bagnon puts its title on a button)
local function IsBagTextHolder(obj)
    local kind = obj:GetObjectType()
    if kind == "FontString" then return true end
    if (kind == "Button" or kind == "CheckButton") and type(obj.GetText) == "function" and type(obj.SetText) == "function" then
        local text = obj:GetText()
        return type(text) == "string" and text ~= ""
    end
    return false
end

local function ScanBagChildren(depth, ...)
    for i = 1, select("#", ...) do ScanBagObject((select(i, ...)), depth + 1) end
end

ScanBagObject = function(obj, depth)
    if type(obj) ~= "table" or depth > 8 then return end
    if type(obj.GetObjectType) == "function" and IsBagTextHolder(obj) then
        if type(obj.GetText) == "function" and type(obj.SetText) == "function" then
            local text = obj:GetText()
            if type(text) == "string" and BagTextFixed(text) ~= text then FixBagFontString(obj) end
        end
        return
    end
    if type(obj.GetRegions) == "function" then ScanBagChildren(depth, obj:GetRegions()) end
    if type(obj.GetChildren) == "function" then ScanBagChildren(depth, obj:GetChildren()) end
end

local function FixBagTitle(frame)
    local title = BagTitleText(frame)
    if title then FixBagFontString(title, true) end
end

local function FixBagWindow(frame)
    FixBagTitle(frame)
    ScanBagObject(frame, 0)
end

local function HookBagWindow(frame)
    if type(frame) ~= "table" or bagWindows[frame] or type(frame.HookScript) ~= "function" then return end
    bagWindows[frame] = true
    bagWindowCount = bagWindowCount + 1
    frame:HookScript("OnShow", function()
        FixBagWindow(frame)
        if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0.2, function() FixBagWindow(frame) end)
        end
    end)
    if type(frame.SetTitle) == "function" and type(_G.hooksecurefunc) == "function" then
        _G.hooksecurefunc(frame, "SetTitle", function(self) FixBagTitle(self) end)
    end
    -- while shown: re-check the known title texts 5 times a second (only a few objects). The full tree walk runs on
    -- show (FixBagWindow above) and when a title is set (the SetText / SetTitle hooks), not every second.
    local acc = 0
    frame:HookScript("OnUpdate", function(_, dt)
        if not BagActive() then return end
        acc = acc + (dt or 0)
        if acc < 0.2 then return end
        acc = 0
        for fs in pairs(bagStrings) do
            local t = fs:GetText()
            local f = BagWanted(fs, t)
            if f ~= t then
                if type(t) == "string" and t ~= "" then bagOriginal[fs] = t end
                fs:SetText(f)
            end
        end
    end)
    if type(frame.IsShown) == "function" and frame:IsShown() then FixBagWindow(frame) end
end

-- /hun bags: lists what the bag window looks like, so a title that is still showing can be tracked down
local function BagDebug()
    local lines = 0
    local function say(msg)
        if lines < 25 then lines = lines + 1; print("|cffffd200HideUnitNames bags: " .. msg .. "|r") end
    end
    local walk
    local function walkList(prefix, depth, ...)
        for i = 1, select("#", ...) do walk(prefix, (select(i, ...)), depth + 1) end
    end
    walk = function(prefix, obj, depth)
        if type(obj) ~= "table" or depth > 8 then return end
        if type(obj.GetObjectType) == "function" and IsBagTextHolder(obj) then
            local text = type(obj.GetText) == "function" and obj:GetText()
            if type(text) == "string" and text ~= "" and (text:find("Bags") or text:find("Inventory") or BagTextFixed(text) ~= text) then
                say(prefix .. " " .. obj:GetObjectType() .. " depth " .. depth .. " text [" .. text .. "]")
            end
            return
        end
        if type(obj.GetRegions) == "function" then walkList(prefix, depth, obj:GetRegions()) end
        if type(obj.GetChildren) == "function" then walkList(prefix, depth, obj:GetChildren()) end
    end
    local meta = type(_G.GetAddOnMetadata) == "function" and _G.GetAddOnMetadata("GatherTimes", "Version")
        or (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata and _G.C_AddOns.GetAddOnMetadata("GatherTimes", "Version"))
    say("GatherTimes " .. tostring(meta) .. ", standalone=" .. tostring(standalone) .. ", windows hooked before=" .. bagWindowCount)
    say("bagActive=" .. tostring(BagActive()) .. " realPlayer=" .. tostring(realPlayer) .. " knownNames=" .. #KnownPlayerNames())
    local ok, err = pcall(FindBagWindows)
    if not ok then say("ERROR while hooking: " .. tostring(err)) end
    local found = 0
    for name, frame in pairs(_G) do
        if IsBagWindowName(name) and IsBagTopWindow(name, frame) then
            found = found + 1
            say(name .. " shown=" .. tostring(frame.IsShown and frame:IsShown()) .. " titleFound=" .. tostring(BagTitleText(frame) ~= nil)
                .. " hooked=" .. tostring(bagWindows[frame] == true))
            local okFix, errFix = pcall(FixBagWindow, frame)
            say("fix pass ok=" .. tostring(okFix) .. " err=" .. tostring(errFix))
            walk(name, frame, 0)
        end
    end
    if found == 0 then say("no Baganator / Bagnon / AdiBags bag window found (is the bag addon loaded, and the bags opened once?)") end
end

-- The bag windows are created late (when the bags are first opened), so they are looked for again until they exist.
-- Only the windows that have a title text are taken (not their buttons and insets).
FindBagWindows = function()
    for name, frame in pairs(_G) do
        if IsBagWindowName(name) and not bagWindows[frame] and IsBagTopWindow(name, frame) then
            HookBagWindow(frame)
        end
    end
    return bagWindowCount
end

-- Looks for bag windows a few times after the bags or bank are opened (the windows can be created late), then stops.
-- Nothing runs while the bags are closed.
local BAG_SEARCH_DELAYS = { 0, 0.3, 1, 2 }
local function StartBagSearch()
    if not BagActive() then return end
    if type(_G.C_Timer) ~= "table" or type(_G.C_Timer.After) ~= "function" then FindBagWindows(); return end
    for _, delay in ipairs(BAG_SEARCH_DELAYS) do _G.C_Timer.After(delay, FindBagWindows) end
end

-- Random Name switched on: blank the open windows now.  Switched off: give the real titles back.
local function BagNamesChanged()
    if standalone then return end
    if BagActive() then
        bagSearchTicks = 0
        for frame in pairs(bagWindows) do FixBagWindow(frame) end
        if bagWindowCount < 2 then StartBagSearch() end
    else
        for fs in pairs(bagStrings) do
            local original = bagOriginal[fs]
            if original and fs:GetText() ~= original then fs:SetText(original) end
        end
    end
end

-- opening the bags (key, bag button, Baganator) looks for the windows right away
local function BagsOpened()
    if not BagActive() then return end
    StartBagSearch()
end

local function UpdateBagTitles()
    if standalone then return end
    if not bagMixinWrapped and type(_G.hooksecurefunc) == "function" then
        local mixin = _G.BaganatorItemViewCommonBackpackViewMixin
        if type(mixin) == "table" and type(mixin.UpdateForCharacter) == "function" then
            local ok = pcall(_G.hooksecurefunc, mixin, "UpdateForCharacter", function(self)
                if BagActive() then FixBagTitle(self) end
            end)
            bagMixinWrapped = ok
        end
    end
    if not bagOpenHooked and type(_G.hooksecurefunc) == "function" then
        bagOpenHooked = true
        for _, fname in ipairs({ "OpenAllBags", "ToggleAllBags", "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag" }) do
            if type(_G[fname]) == "function" then pcall(_G.hooksecurefunc, fname, BagsOpened) end
        end
    end
    StartBagSearch()
end

api.ContainsCharacterName = function(text)
    if not Enabled() then return false end
    return HasKnownPlayerName(text)
end
api.SetNames = SetNames
api.CleanName = CleanName
api.GetDB = function() return InitDB() end
api.ApplyNow = function() InitDB(); Refresh() end
api.AddListener = function(fn) if type(fn) == "function" then listeners[#listeners + 1] = fn end end
api.AddListener(BagNamesChanged)

-- standalone HideUnitNames is loaded: switch this copy off, give the player's name settings back, and do nothing else
local function StepAside()
    standalone = true
    if type(GatherTimesHUNDB) == "table" and GatherTimesHUNDB.hideAll then
        GatherTimesHUNDB.hideAll = false
        ApplyCVars(false)
    end
    SyncTicker()
    _G.GatherTimesNameDisguise = nil
    print("|cffffd200GatherTimes: the standalone HideUnitNames addon is loaded, so Random Name is off here. Use /hun from that addon.|r")
end

-- ---------------------------------------------------------------- slash command
local function PrintHelp()
    print("|cffffd200HideUnitNames commands:|r")
    print("/hun                 - toggle disguise on/off")
    print("/hun player <name>   - set your fake PlayerFrame name")
    print("/hun pet <name>      - set your fake PetFrame name")
    print("/hun random          - generate new saved fake names")
    print("/hun reset           - generate fresh names from the default list")
    print("/hun status          - show the current state")
    print("/hun help            - show this help")
    print("|cffaaaaaaCovers your unit frames, tooltip, character window and chat. Other players' names are hidden through the game's name settings, which are put back when you switch off.|r")
end

SLASH_GATHERTIMESHUN1 = "/hun"
SlashCmdList.GATHERTIMESHUN = function(message)
    if standalone then
        print("|cffffd200HideUnitNames: the standalone addon is loaded, use /hun from it.|r")
        return
    end
    local db = InitDB()
    message = (message or ""):match("^%s*(.-)%s*$")
    local command, rest = message:match("^(%S+)%s*(.-)$")
    command = command and string.lower(command) or ""

    if command == "" then
        SetEnabled(not Enabled())
        print("|cffffd200HideUnitNames: disguise " .. (Enabled() and "ON." or "OFF.") .. "|r")
    elseif command == "player" or command == "pet" then
        local clean = CleanName(rest)
        if clean == "" then
            print("|cffffd200Usage: /hun " .. command .. " <name>|r")
            return
        end
        if command == "player" then SetNames(clean, nil) else SetNames(nil, clean) end
        print("|cffffd200HideUnitNames: fake " .. command .. " name set to " .. clean .. ".|r")
    elseif command == "random" or command == "reset" then
        RandomizeNames(false)
    elseif command == "bags" then
        BagDebug()
    elseif command == "status" then
        print("|cffffd200HideUnitNames: " .. (Enabled() and "ON" or "OFF") .. ". Player: " .. db.fakePlayerName
            .. " / Pet: " .. db.fakePetName .. " / Level: " .. db.fakeLevel .. "|r")
    else
        PrintHelp()
    end
end

-- ---------------------------------------------------------------- events
local events = CreateFrame("Frame")
for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "UNIT_NAME_UPDATE", "UNIT_PET", "GROUP_ROSTER_UPDATE", "BAG_OPEN", "BANKFRAME_OPENED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, ev)         -- a client without one of these events must not break the others
end
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Baganator" then UpdateBagTitles() end
        if arg1 ~= ADDON_NAME then return end
        InitDB()
        return
    end
    if standalone then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = event == "PLAYER_REGEN_DISABLED"
        RefreshToT()                                -- at once: the frame must not show for even a moment
        return
    end
    if event == "UNIT_NAME_UPDATE" and arg1 ~= "player" and arg1 ~= "pet" and arg1 ~= "target"
        and arg1 ~= "focus" and arg1 ~= "targettarget" then return end   -- fires for every unit: only ours matter
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then SyncCombatState() end   -- /reload in combat
    if event == "BAG_OPEN" or event == "BANKFRAME_OPENED" then
        BagsOpened()
        return
    end
    if event == "PLAYER_LOGIN" then
        InitDB()
        if StandaloneLoaded() then
            StepAside()
            return
        end
        MigrateOldSettings()
        RememberNames()
        InstallHooks()
        UpdateBagTitles()
    end
    if event == "GROUP_ROSTER_UPDATE" then
        RefreshGroupNames()
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ApplyAll()
    end
    if event == "UNIT_PET" or event == "UNIT_NAME_UPDATE" or event == "PLAYER_ENTERING_WORLD" then RememberNames() end
    if not Idle() then RefreshSoon() end
end)

-- safety net for frames that Blizzard updates without one of the hooks below.
local acc = 0
local function OnTick(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 0.2 then return end
    acc = 0
    if Enabled() and not standalone then
        Refresh()
    end
end
-- no OnUpdate at all while the disguise is off: the game then does not call it every frame
SyncTicker = function()
    events:SetScript("OnUpdate", (Enabled() and not standalone) and OnTick or nil)
end
SyncTicker()
