# GatherTimes

## 0.26.0 (2026-11-27)

- Change: mouse-look (GTMove, `/gtmove`, Nav > Move) is removed; use the separate GTMouse addon. GatherTimes no longer claims `/gtm`, and the HUD arrow is no longer tinted for it.
- New: a GTMouse button beside the Minimap HUD button opens the GTMouse settings.
- Change: hover key is now Auto (default), Ctrl, Shift or Always. An old "alt" means Auto.
- Fix: HUD map tooltips no longer blink or vanish quickly, and the stock +/- zoom buttons stay hidden while the HUD is on.
- Fix: the HUD Rings tab fits its window, with the options in two aligned columns.
- Fix: the HUD no longer fights GTMouse over the player arrow.
- Change: the Nav tabs and the gold total line up evenly in the main window.

## 0.25.4 (2026-11-25)

- New: nearby gathering pins can cluster by resource, and timer tooltips show a learned likely-ready window with confidence.
- New: whisper sound (`GatherTimes_Whisper`, Settings > Look > Whisper Sound). 
- New: debug reports show retry diagnostics for quarantined timers.
- Change: Settings > Look is tidied; the Notifier box, time button and voice button moved there into "Notifications and sounds".
- Fix: HUD: the cursor and tooltip no longer blink while resting on a herb / ore with "Hover tooltips on map" on.
- Fix: whisper sound no longer plays twice (skips when the standalone Whisper Sound addon is loaded, ignores whispers less than 2 s apart) and touches no game UI.
- Fix: Hardcore characters keep their own session, HUD, XP goal and settings; the low-health warning needs a positive Hardcore result.
- Fix: GTMove "Turn on when mounted" applies at once; mouse-look state follows other mouse-look changes; unbinding the toggle key removes all its keys.
- Fix: same-item loot slots are added before chat deduplication; damaged saved data is cleaned instead of breaking; bag warnings count only herb/ore-capable bags; a failed HUD refresh restores the stock minimap.

## 0.25.3 (2026-11-23)

- Fix: mouse-look no longer turns on by itself after a reload or relog.

## 0.25.2 (2026-11-22)

- New: GTBag is bundled and works with GatherTimes (privacy hides session gold, shared fade and skin, auction prices).
- New: GTMove (the former MouseMove) as a load-on-demand module: mouse-look keys, mount auto-on, remember on login, sensitivity keys, magenta arrow, on-screen notices. `/gtmove`, Nav > Move.

## 0.25.1 (2026-11-19)

- New: competition detector (`/gt compete`), auction "GT Scan" button with prices in tooltips, Help how-tos.
- Change: "Clear timers on zone change" is per character and off by default.
- Fix: yellow goal strip, Goals boxes, Eagle / Far Sight detection, duplicate timers, auction scan timeouts and bad saved numbers.

## 0.25.0 (2026-11-18)

- New: option to clear timers on zone change; towns clear waypoints; fps line can show layer, durability and clocks; buff level and top offset settings.
- New: Random Name, Mini XP, Notifier and Eagle are load-on-demand folders (`/gt module <name> on|off`); GatherMate2 import option.
- Change: less CPU and memory; timers and pins show only the current zone.
- Fix: translated node names were not loading.

## 0.24.9 (2026-11-16)

- New: hover tooltips on HUD and Eagle maps; Notifier voice button and smaller pop-up.

## 0.24.8 (2026-11-15)

- New: Compact map, HUD auto-off in cities, blip size, memory readout.
- Fix: Notifier logins, label shimmer, group dots.

## 0.24.7 (2026-11-13)

- New: Friend / Guild Notifier with pop-up and sound.

## 0.24.6 (2026-11-12)

- New: Performance and Pings tabs, arrow size, XP goals and history.

## 0.24.5 (2026-11-11)

- New: skill ETA, best node (gold/hour), bag space warning, "taken" spot detection, XP line options and alerts.

## 0.24.4 (2026-11-11)

- Fix: no yellow ping circle on the HUD map click.

## 0.24.3 (2026-11-10)

- New: hide target-of-target in combat. Change: language change asks first. Fix: slider ranges and low-health warning (Hardcore only).

## 0.24.2 (2026-11-08)

- New: Eagle map (Eagle Eye, Far Sight, Mind Vision...), HUD rings in yards, LibDataBroker feed.
- Fix: camera turning, HUD displacement and size, saved-data version.

## 0.24.1 (2026-11-07)

- New: Graphics quality slider (`/gt gfx`). Fix: HUD opacity flicker.

## 0.24.0 (2026-11-06)

- New: hero and pet XP merged in from GetXP (XP button, `/gt xp`). Delete the old GetXP folder.
