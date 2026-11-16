# GatherTimes

## 0.24.9 (2026-11-16)

- New: automatic map hover tooltips on the HUD and Eagle maps, and a Hover key button on the HUD Options tab.
- New: the Notifier voice button (off, voice, next voice) speaks the name, online or offline, and the zone.
- New: the Notifier pop-up shows Friend, Guild Member or both, the guild name, level, class and zone, in a smaller size.
- Change: the player and target frames sit level with the fps / ping panel.
- Change: the HUD tab descriptions, tracking tooltips, sound buttons and hover tooltips are translated.
- Change: the Help panel covers the Notifier voice, the compact map and the hover options.

## 0.24.8 (2026-11-15)

- New: map hover tooltips are on by default (hold Alt over the map to see node names); change the key with `/gthud hoverkey`.
- New: Compact map option (HUD Options): 75% size, no rings, compass or heading readout.
- New: HUD auto-off in cities, towns and inns; HUD blip size 1.0x to 1.4x.
- New: memory readout on the second bar (Pings tab, off by default).
- Fix: the Notifier shows when someone comes online; the FPS and ping tooltips say "bar"; G1-Gx labels no longer shimmer; group-member dots hover correctly.
- Change: the Show time button is greyed out while the Notifier is off; "Restore HUD after /reload or login" is removed.
- Change: Help covers the Notifier, Pings, arrow size and Performance; all labels and tooltips are translated.

## 0.24.7 (2026-11-13)

- New: Friend/Guild Notifier: a pop-up with a sound when a guild member or friend comes online or goes offline.
- Change: Xbox and Windows are removed from the ping and Nodes sound lists.

## 0.24.6 (2026-11-12)

- New: Performance tab (Full, Balanced, Lowest) and Pings tab, with a red-ping sound that repeats with a set delay.
- New: arrow size slider; XP goals and XP session history.
- Change: the player arrow hides during Eagle Eye; Boom.ogg is removed.
- Change: more space and tooltips in Minimize and HUD settings; options with no effect are greyed out.
- Fix: the minimized bar keeps its fps, H and W switches.

## 0.24.5 (2026-11-11)

- New: skill ETA for Herbalism and Mining in the session summary ("next point in ~4 nodes (~3 min)"). Counts this session only.
- New: "Best node" line in the summary (highest gold per hour this session).
- New: bag space warning (Minimize settings > Chips). Alert at a set number of free slots (default 5) and when full, plus a red "Bags: N" chip.
- New: competition detection. A spot found already looted is marked "taken" on its timer, and the summary shows "Taken by someone else: N". Taken spots no longer teach timers that are too long.
- Change: smarter next spot. Running timers get the "often taken" penalty too; the Next line says "ready on arrival" or "(often taken)".
- New: choose what the XP line shows (Minimize settings > XP), and an optional gold per hour.
- New: level-up alert (on) and "close to level" alert (off), both in Minimize settings > XP.
- Fix: Bar opacity now also fades the buttons on the minimized bar.
- Change: translations in new files `GatherExtra.lua` and `XPExtra.lua`.

## 0.24.4 (2026-11-11)

- Fix: clicking the HUD map no longer shows the game's yellow ping circle over the node pins. Pings from other players are hidden while the HUD is on.

## 0.24.3 (2026-11-10)

- Change: changing the language asks first and can be cancelled. Clicking the text next to a check box toggles it.
- Fix: saved low-health % and map text size stay inside their slider range.
- Fix: the low health warning only shows on Hardcore characters.
- Fix: setting Graphics quality back to Off no longer overwrites graphics settings you changed in the game menu.
- Fix: the status text on Settings > Tools is cut at its box.
- Change: Random Name uses less CPU and memory. No change in what it hides.
- New: Random Name window option "Hide target-of-target in combat" (on by default).

## 0.24.2 (2026-11-08)

- New: Eagle map. While Eagle Eye is on, the HUD stays on and draws its own map (size, opacity, zoom, rotation, rings; HUD settings > Eagle, `/gthud eagle`). Also works for Far Sight, Mind Vision, Eyes of the Beast and Eye of Kilrogg.
- New: Eagle map extras: same zoom and rings as the HUD, hover tooltips for herbs and ore, distance scale, nearest node readout, a Preview button, and 3 key bindings (zoom in, zoom out, next size).
- New: HUD rings can be set in yards (`/gthud ringunit yd`). Pixels stay the default.
- New: Gx labels and (G) timer texts on the minimap are hidden while the HUD is off (on by default), and on the Eagle map.
- New: LibDataBroker feed. Shows the ready count or time left; left-click opens the window, right-click toggles the HUD. Nothing is added without a Broker display addon.
- Change: the HUD is always centred. Offset sliders, Unlock and `/gthud unlock | lock | offset` are removed.
- Change: the minimized bar shows at load by default and has a red x to hide it. Drunken haze option is back (Settings > Display).
- Change: Help panel updated. Translated Help texts do not cover everything yet (Eagle map, graphics quality, yard rings, XP, newer commands).
- Fix: camera turning with the mouse sometimes did nothing while the HUD was on.
- Fix: the HUD no longer stays displaced when another minimap addon keeps moving the Minimap.
- Fix: the saved HUD size is no longer shrunk by one login at a small window or high UI scale.
- Fix: switching the HUD off restores the player arrow and minimap frames set by other addons (SexyMap etc.).
- Fix: route-only readout no longer disappears when settings change; tracking button tooltip works on non-English clients; HUD x / y are limited when a profile loads.
- Change: `/gthud skins` lists every shown minimap piece, with `hide`, `show`, `mark` and `diff` for finding the SexyMap white arc.
- Change: rings redraw only when their settings change (smoother size slider). Eagle Eye detection is lighter.
- Fix: the saved-data version number is no longer lowered by an older addon version.

## 0.24.1 (2026-11-07)

- New: Graphics quality slider (Off / Low / Very low / Minimal) for slow PCs. `/gt gfx` lists the settings your client has.
- Fix: HUD opacity no longer flickers or sticks when going from 0 to 100%. Masks are preloaded.
- Change: the HUD hides minimap skin textures as wide as the stock minimap. `/gthud skins` lists minimap frames for bug reports.
- Removed: Drunken haze option (returned in 0.24.2).
- Known issue: with SexyMap a white arc can show along the bottom of the HUD circle.

## [v0.24.0](https://github.com/ridinsa/GatherTimes/tree/v0.24.0) (2026-11-06)
[Full Changelog](https://github.com/ridinsa/GatherTimes/compare/v0.23.2...v0.24.0) [Previous Releases](https://github.com/ridinsa/GatherTimes/releases)

- New: hero and pet XP, merged in from GetXP. An "XP" button on the minimized bar shows battles to level, XP/hr, time to level, pet battles and latest gain. `/gt xp`, `/gt xp reset`, `/gt xp session`.
- Change: Minimize settings are split into tabs (Bar, Chips, Fade, XP).
- Removed: the GetXP window, its Quests and Spots tabs and its chat window. Delete the GetXP addon folder.
