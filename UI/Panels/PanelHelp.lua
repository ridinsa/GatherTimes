-- PanelHelp.lua : the "Help" panel  (opened by the "?" button in the title bar of the main window)
--
-- A normal GatherTimes panel (Panels.lua): 300 x 400, right of the main window, not movable, closed by its header
-- button, by opening another panel or by closing the main window. A row of 6 flat topic buttons across the top
-- (same style as the HUD settings), the text below it in a scrollable area (mouse wheel or the thin scroll bar).
local _, GT = ...
GT.panelBuilders = GT.panelBuilders or {}

local FLAT = "Interface\\Buttons\\WHITE8X8"
local H = "|cffffd100"      -- heading colour
local E = "|r"

-- ----------------------------------------------------------------------------------------------- content
local TOPICS = {}

TOPICS[#TOPICS + 1] = { "start", "Start", H .. "Welcome to GatherTimes" .. E .. [[

Tracks when herbs and ore respawn in the zone you are in, remembers where the nodes spawn, and shows it in the main window, on the minimap and on the world map.

]] .. H .. "Quick start" .. E .. [[

1. Open the window with /gt.
2. Click Nodes (bottom) and tick the herbs / ore you gather.
3. Gather. A timer starts as soon as you loot a node.
4. Watch the table in the main window. When a node is ready you get an on-screen alert, a sound, and a chime when you are close.

]] .. H .. "The main window" .. E .. [[

- Dropdown (top): show every ticked node, or just one.
- Inventory counts appear right-aligned in the open item dropdown; the count is hidden on the closed, selected item.
- Table: one row per group of nearby nodes. G1, G2... are the group numbers you also see on the map.
- Status: Waiting = all nodes still counting down. 2/3 up = some are back. Ready = all back. Idle = no timer running.
- A node stays Ready for a while after it respawns, then goes Idle (you choose how long: Settings > General > Ready status lasts).
- Alerts are sent only once per timer. Use Settings > General for minimum / maximum distance, and Nodes > Alert to enable or silence alerts for each resource.
- Minimap HUD On/Off button: left-click turns the HUD on / off, right-click opens the HUD settings. Its text is green while the HUD is on and grey while it is off.
- The server and game-mode label appears below the timer table.
- The 5 buttons at the bottom open the panels. Click the same button again to close its panel.
- The - button in the title bar minimizes the window to a bar along the top of the screen. Right-click it for Minimize settings (tabs Bar, Chips, Fade and XP). In the bar: the item dropdown, the XP button, one chip per group, the session gold, the "+" button, which brings the window back, and a red x, which hides the bar until you open the window again or use /gt min. Right-click the gold twice to reset the session (the summary is printed to chat first).
- XP button (on the bar): shows your hero and pet XP in one line instead of the timers: battles to level, XP per hour, time to level, the battle timer and the latest gain. Click it again, or pick an item in the dropdown, to go back. /gt xp does the same. Minimize settings > XP hides the button. Nothing is saved between sessions.
- Drag the title bar to move the window. The title shows the zone you are in.
- The ? button in the title bar opens this help.]] }

TOPICS[#TOPICS + 1] = { "panels", "Panels", H .. "Timers" .. E .. [[

Every running timer, ready ones first (Grp, Node, Time), plus your session totals. Clear waypoint removes the arrow. Show summary opens the session summary (items, gold value and gold per hour) in a box you can copy. Reset session first prints the summary, then restarts the session timer and clears its counts.

]] .. H .. "Nodes" .. E .. [[

Choose what you track and how.
- On: tick to track a herb / ore.
- Min: respawn time in minutes. Type a new number and press Enter.
- Col: colour of the node on the map and in lists. Left click = next colour, right click = previous.
- Alert: enable or silence ready alerts for this resource. The check is independent of whether the resource is currently shown in the main dropdown.
- Sound: alert sound. Click = next (plays a preview), right click = previous.
- Dropdown: All / Herbs / Ore. List all: show every node, not only the ones of your current zone.
- Nodes per group: how many nearby nodes form one group (G1, G2...).
- Nodes up per group: how many must be up before the group counts as ready.
- Select All, Select None, Reset (back to the default times).
- The main window's open item dropdown also shows the number of that resource in your bags; the selected button does not show a count.

]] .. H .. "Nav" .. E .. [[

- Route: choose one enabled herb / ore or all enabled resources, then Build route plans a path through active timers. Next step moves on, Clear route removes it. Options include only-ready nodes, map drawing, auto arrow, max nodes, and time window. Prioritize low-inventory resources to favor resources below the target stock amount (bags only).
- Markers: show spawn pins on the map and minimap, show group labels (G1, G2...), dots for other items, hide spots gathered during this session, right-click a spot for the group menu, node offset while gathering, and Refresh pins. The gathered-spot filter clears when you reset the session.
- Arrow: TomTom integration, arrow to the nearest node, auto-switch to the next node in a route, arrow distance, Waypoint to nearest. Needs the TomTom addon.

]] .. H .. "Timing" .. E .. [[

Per node: Now = the respawn time in use. Learned (n) = the range measured from your own visits, fastest-typical (e.g. 10.5-12.0), n = number of samples (orange under 5, yellow 5-9, green 10+; green learned time means the typical value is quicker than Now; * = item-wide value shown in Per zone mode). Respawns vary, so expect anything in that range. Apply / auto-apply use the typical (right-hand) value. Taken = how often a spot was found empty.
- Learned times: Per item (one learned time per herb / ore, default) or Per zone (the zone you are in once it has 5 samples).
- One shared timer per group, Detect empty nodes, Use game messages, Auto-adjust learned times (shorter or longer, never more than twice the factory time). The zone switch is in Settings > General.
- Apply all faster copies the learned times into Now. Reset learned timings clears them.

]] .. H .. "Settings" .. E .. [[

- General: on-screen alert and Alert time, minimum and maximum ready-alert distance (0 disables that bound), alert when chat announces maintenance (flash colour 1-7), low health warning (Hardcore), Ready status lasts, and Only show timers and pins of the zone I am in.
- Display: map text size, window size, see-through while moving, keep windows visible (ESC does not close them), and item tooltip on hover. Graphics quality (Off / Low / Very low / Minimal) lowers view distance, particles, ground clutter, shadows, water and sky detail for a slow PC; Off puts your own settings back. Screen effects turns off the ghost screen effect and invisibility's edge effect. Drunken haze turns off the blur drunkenness draws over the screen (it is the game's full screen glow, so it also removes that glow everywhere). Weather density (Off / Low / Medium / High) and Max camera zoom (1.0x to 4.0x) are also here. Some graphics changes only fully apply after /console gxrestart. The language dropdown is under Look; it takes effect after a UI reload (shown as "w/reload").
- Look: Language, Frame skin (colour themes for the windows and tooltips; Pastel Pink and Sakura use dark text, and their text has a thin outline), Font (Friz Quadrata, Arial Narrow, Skurri, Morpheus, or Friends when the client has it) and Font size (80% to 130%). Korean, Chinese, Japanese and Russian keep their own font, so the font choice is replaced by a note for them.
- Tools: status of the addon and its helpers, Import GatherMate2, Clear learned spawn points, Export my spots / Import spots (share spots with friends), Copy debug report (one block of text for a bug report), Reset timers, Start a new session at login, and the error log.

]] .. H .. "Inventory and session summary" .. E .. [[

The open resource dropdown shows your bag count beside each item; the selected item button hides its count. The Timers panel shows session totals. Show summary opens the same summary; Reset session prints them first, then clears the counts and restarts the session clock. Only recognized gathering loot counts. Reset session also clears the session-only gathered-spot filter.

]] .. H .. "Random Name" .. E .. [[

Right-click the Settings button in the main window to open it (right-click again closes it). It disguises your own name on your screen, for streaming or screenshots. Other players still see your real name.
- Disguise names: turns the disguise on or off. While it is on, other players' names are hidden too (through the game's name settings, put back when you turn it off).
- Hide party / raid names: separately hides party and raid name labels on your screen.
- Hide target-of-target in combat: while the disguise is on, the target-of-target frame is hidden during combat and comes back when combat ends (on by default).
- Fake player name / Fake pet name: the names shown instead. Type a name and press Enter or Apply. Up to 12 characters.
- Randomize Names: picks new random names and a fake level. The Random level range slider sets the level's maximum. Opacity fades the window background while keeping its text readable.
- Shown on: your unit frames (also when you target yourself or your pet), unit tooltip, character window title and chat. When the disguise is on, matching character names are also hidden in item tooltips.
- Commands: /hun (toggles the disguise), /hun player <name>, /hun pet <name>, /hun random, /hun status, /hun help.
- If the standalone HideUnitNames addon is loaded, Random Name here is switched off. Use that addon instead.]] }

TOPICS[#TOPICS + 1] = { "tips", "Tips", H .. "Groups" .. E .. [[

Nodes close together are treated as one group, so you see when the whole group is back instead of every single node. With One shared timer per group (Timing panel) the group has one timer.

]] .. H .. "Fixing a spot (world map)" .. E .. [[

Right-click a timer text or a spot pin on the world map for a small menu (enable it in Nav > Markers):
- This spot is empty: it was taken by someone else.
- Group taken by someone: the whole group was already gathered.
- Move this spot to group: put it in another group (1, 2, 3... or New).
- Enter a short note and click Save note to attach a reminder to that spot. Hover the spot to see its note. Notes are saved with the spot.
The minimap never opens this menu. You can switch it off in Nav > Markers.

]] .. H .. "How respawn times are learned" .. E .. [[

Each time a node is back and you loot it, the time since the loot it is the respawn of is stored (in a group with several nodes up at once, that is the oldest of the recent loots, not the newest). The addon ignores very short and very long gaps, then shows the fastest-quarter value up to the median (typical) of your samples, rounded to 15 seconds, in Timing. Apply and auto-apply use the median. It needs 3 samples to show a value and 5 to auto-apply it.

]] .. H .. "Sharing spots with friends" .. E .. [[

Settings > Tools > Export my spots (or /gt export) shows your own spots as one line of text. Click the box, press Ctrl+C and send it to a friend. They use Import spots (or /gt import), paste it with Ctrl+V and click Import. Only item, zone and position are shared, no timers or counts. Spots you already have are left alone, and a text that was cut off on the way is refused instead of half imported.

]] .. H .. "Helper addons" .. E .. [[

- HereBeDragons: needed for pins on the map and minimap. Install it.
- GatherMate2: Settings > Tools > Import GatherMate2 adds its known node locations.
- TomTom: lets the arrow and route waypoints show up.
- A Broker display (Titan Panel, ChocolateBar, Bazooka...): shows a GatherTimes button with the ready count. Left-click opens the window, right-click turns the HUD on / off.

]] .. H .. "Something is wrong?" .. E .. [[

- No pins: install HereBeDragons. Settings > Tools shows what was found.
- Timers do not start: type /gt debug and loot a node, it prints what the addon sees.
- Errors are listed in Settings > Tools > Error log (click, Ctrl+A, Ctrl+C to copy).
- Reporting a problem or a conflict with another addon: Settings > Tools > Copy debug report (or /gt report), copy the text and paste it into the report.
- Wrong spot or group: right-click it on the world map.]] }

TOPICS[#TOPICS + 1] = { "hud", "HUD", H .. "Minimap HUD" .. E .. [[

Turns the real minimap into a big see-through map across your screen, with optional rings, compass letters, heading, Ready-first and route-progress readouts. Your gathering pins stay on it.

]] .. H .. "Turn it on / off" .. E .. [[

- Left-click the Minimap HUD button in the main window.
- Type /gt hud (or /gthud).
- Use a key: HUD settings > Map tab > Keybinding (click the key button, press a key; Esc cancels, Clear removes it). It is also in Key Bindings > AddOns > GatherTimes.
- Optional: switch on automatically when gathering tracking is active (HUD settings > Options).

]] .. H .. "HUD settings (right-click the HUD button)" .. E .. [[

- Map: HUD size, map opacity (0% = the map is blank and only the pins show, 100% = opaque; 10 steps), minimap zoom, keybinding.
- Rings: ring radius, second ring (the Unit button at the top right switches them between pixels and yards: in yards a ring keeps its real distance at any HUD size or zoom, is labelled, and is hidden when it is farther than the map shows), thickness, smoothness, ring style (line, stripes or dots: the button cycles them), ring density, ring colours (Ring colour... opens the picker: sliders for each ring, and a Random colour button for the ring whose tab is open), compass letters (N E S W), heading readout, Ready-first gathering readout (nearest ready node, otherwise nearest respawn), and route progress readout (current planned route step). Each readout can be switched on or off.
- Track: the tracking button while the HUD is on (size 20-80 px and position) and what it does while the HUD is off (auto, own or stock).
- Options: rotate map with player, player arrow, hide HUD while mounted, auto-enable with gathering tracking, restore HUD after /reload or login, hide minimap addon skins, diagnostics.
- Eagle: the map shown during a remote view: a hunter's Eagle Eye and Eyes of the Beast, a shaman's Far Sight, a priest's Mind Vision, a warlock's Eye of Kilrogg. The HUD stays on but turns into a smaller map with its own size, opacity, zoom, rotation and an optional ring; compass letters are hidden. Hover tooltips on the map lets the game's own herb / ore tooltips show when you point at a blip (clicks pass through to the world; the map does not ping). Key Bindings > AddOns has keys for zoom in, zoom out and next size (saved size, bigger, smaller). Distance scale labels the edge of the map and a ring half-way in with the yards they stand for (it follows the zoom and indoors / outdoors). Nearest node readout shows the closest known node, READY or time left, and its distance. Preview Eagle map shows it without casting Eagle Eye. Switch it off to have the HUD turn off during Eagle Eye instead.
- Profile: save several looks, switch or delete them. Profiles are shared by all characters; each character remembers its own.
- Reset profile restores the defaults.]] }

TOPICS[#TOPICS + 1] = { "cmds", "Cmds", H .. "Slash commands" .. E .. [[

/gt - open or close the main window
/gt list - active timers in chat
/gt stats - session totals in chat
/gt yield - persistent zone and item yields (top 10 zones)
/gt yield current - yield totals for the current zone
/gt debug - loot detection messages on / off
/gt profile start | stop | report - profile the timer loop
/gt hud - minimap HUD (see below)
/gt min (or /gt minimize) - minimize to the bar, or bring the window back
/gt dock - the bar pushes the game's top frames down (on) or only covers them (off)
/gt xp - XP mode on the minimized bar (also: /gt xp reset, /gt xp session)
/gt export - show your own spots as text to share
/gt import - import spots from a friend's text
/gt report - debug report to copy into a bug report
/gt gfx - graphics quality level and the graphics settings this client has
/gthud - same as /gt hud
/gathertimes - same as /gt
/hun - Random Name (see Panels > Settings > Random Name)

]] .. H .. "HUD commands" .. E .. [[

/gthud - toggle the HUD
/gthud on | off
/gthud config - open the HUD settings
/gthud size 800 - HUD size (150 to 1400)
/gthud alpha 0.5 - map opacity (0 to 1)
/gthud zoom 3 - minimap zoom (0 to 5)
/gthud rotate - rotate with player on / off
/gthud ring 150 - ring radius in px, or in yards when /gthud ringunit yd is set (0 = off)
/gthud ringunit px | yd - ring radius unit
/gthud ring2 300 - second ring
/gthud ringthick 2 - ring thickness (1 to 10)
/gthud ringseg 96 - ring smoothness (8 to 256)
/gthud ringstyle solid | stripes | dots - ring style
/gthud ringdensity 24 - stripes or dots around the ring (4 to 128)
/gthud ringcolor 1 1 1 0.8 - red green blue opacity
/gthud ringcolor2 1 1 1 0.8 - second ring colour
/gthud dirs - compass letters on / off
/gthud heading - heading readout on / off
/gthud tracking - tracking button on / off
/gthud tracksize 50 - tracking button size (20 to 80)
/gthud trackpos 0 0 - tracking button offset for the current HUD state
/gthud trackmode auto | own | stock - tracking button while the HUD is off
/gthud arrow - player arrow on / off
/gthud addons - hide minimap addon skins / buttons on / off
/gthud skins - list the minimap skin frames and textures (for bug reports)
/gthud skins hide <n> | show <n> | mark | diff - hide or show one listed piece; mark, then diff, shows what changed when a skin arc appears
/gthud scan - deep scan for minimap addons on / off
/gthud eagle - Eagle Eye map on / off (also: preview, size, zoom, alpha, rotate, ring, scale, nearest, hover, debug)
/gthud mountfade - hide HUD while mounted on / off
/gthud autogather - auto-enable with gathering tracking on / off
/gthud restore - restore HUD after /reload or login on / off
/gthud profile - list profiles; /gthud profile <name> switches or creates one
/gthud profile delete <name> - delete a profile (Default and the active profile cannot be deleted)
/gthud status | info | frames | debug - status, diagnostics, or debug messages
/gthud reset - reset the current profile
/gthud help - show command help]] }

TOPICS[#TOPICS + 1] = { "credits", "Credits", H .. "GatherTimes 0.24.3" .. E .. [[

Author: miRidinsa
Website: https://github.com/ridinsa/
License: GNU GPL v3 or later (see the LICENSE file in the addon folder).

]] .. H .. "Libraries" .. E .. [[

- HereBeDragons-2.0 and HereBeDragons-Pins-2.0 by Nevcairiel: the positions of the pins on the minimap and the world map.
- LibStub and CallbackHandler-1.0 (WoW Ace libraries): library loading and callbacks.

]] .. H .. "Random Name" .. E .. [[

An embedded copy of the HideUnitNames module (the standalone addon of the same name is also supported: when it is loaded, this copy steps aside).

]] .. H .. "Helper addons" .. E .. [[

- HereBeDragons: needed for pins.
- GatherMate2: its node data can be imported.
- TomTom: waypoints for the arrow and routes.

]] .. H .. "Translations" .. E .. [[

The language files in the Locales folder. Thanks to everyone who helped with them and to everyone who sent a debug report.]] }

-- ----------------------------------------------------------------------------------------------- scroll text
-- Flat scrolling text box: a ScrollFrame whose child holds one wrapped font string, with a thin scroll bar.
local function CreateTextScroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -28)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 0)

    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(280, 10)
    sf:SetScrollChild(child)

    local fs = GT.Font(child, nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 2, 0)
    fs:SetWidth(272)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(2)

    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(5)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -28)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetValue(0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetTexture(FLAT)
    track:SetVertexColor(0.12, 0.12, 0.12, 1)
    bar:SetThumbTexture(FLAT)
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(5, 28)
    thumb:SetVertexColor(0.35, 0.35, 0.35, 1)
    bar:Hide()

    local syncing = false
    bar:SetScript("OnValueChanged", function(_, v)
        if syncing then return end
        sf:SetVerticalScroll(v)
    end)
    sf:SetScript("OnVerticalScroll", function(_, offset)
        syncing = true
        bar:SetValue(offset)
        syncing = false
    end)
    sf:SetScript("OnScrollRangeChanged", function(_, _, yRange)
        yRange = math.max(0, yRange or 0)
        bar:SetMinMaxValues(0, yRange)
        bar:SetShown(yRange > 0)
    end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(_, delta)
        local v = sf:GetVerticalScroll() - delta * 36
        v = math.max(0, math.min(sf:GetVerticalScrollRange(), v))
        sf:SetVerticalScroll(v)
    end)

    local box = { frame = sf }
    function box:SetText(text)
        fs:SetText(text)
        child:SetHeight(fs:GetStringHeight() + 8)
        sf:SetVerticalScroll(0)
    end
    function box:Fit()                    -- text height is only reliable once the panel is shown
        child:SetHeight(fs:GetStringHeight() + 8)
    end
    return box
end

-- ----------------------------------------------------------------------------------------------- panel
GT.panelBuilders.Help = function(panel, content)
    panel.header.title:SetText(GT.TR("Help"))

    local box = CreateTextScroll(content)
    local tabButtons = {}
    local current = TOPICS[1][1]

    local function ShowTopic(id)
        current = id
        for _, t in ipairs(TOPICS) do
            GT:SetButtonActive(tabButtons[t[1]], t[1] == id)
            if t[1] == id then
                local alt = type(GT.helpText) == "table" and GT.helpText[GT.TextLang()]
                local txt = type(alt) == "table" and alt[id]
                box:SetText((type(txt) == "string" and txt ~= "") and txt or t[3])   -- English if the translation is missing
            end
        end
    end

    -- tab row: one flat button per topic, 4 px apart, sharing the 288 px content width
    local TAB_GAP = 4
    local TAB_W = math.floor((288 - TAB_GAP * (#TOPICS - 1)) / #TOPICS)
    for i, t in ipairs(TOPICS) do
        local b = GT:CreateFlatButton(content, t[2], TAB_W, 20)
        b:SetPoint("TOPLEFT", (i - 1) * (TAB_W + TAB_GAP), 0)
        b:SetScript("OnClick", function() ShowTopic(t[1]) end)
        tabButtons[t[1]] = b
    end

    panel:SetScript("OnShow", function()
        box:Fit()
        C_Timer.After(0, function() box:Fit() end)
    end)
    ShowTopic(current)
end
