# GatherTimes

## 0.25.0 (2026-11-18)

- New: Timing option "Clear timers and alerts when I change zone" (off by default). Works on zone changes, loading screens (boat, portal, instance) and entering a town or inn. Learned times are kept.
- New: entering a town or city clears GatherTimes waypoints; route and nearest-node arrows stay off there.
- New: fps / ping line can show layer (L:1/2), durability (D:87%) and game / local clocks (Pings tab).
- New: "Buffs level with the bar" (on) and "Top offset" slider (Minimize > Bar, for Titan Panel etc.).
- Change: timers and pins always show only your current zone; the zone-only option is removed.
- Change: less CPU and memory: lighter dock, Broker, labels, blink loop and HUD updates. Spot export / import load on demand (GatherTimes_Share). Mini XP loads only while "Show XP button" is on.
- Change: item dropdowns no longer show bag counts; narrower minimized-bar dropdown; tighter chip spacing.
- Fix: `Locales\Nodes.lua` (translated herb / ore names) was missing from the .toc and never loaded.
- Fix: zone-cleared message is translated in every language; Help no longer mentions the removed zone switch; first chip no longer keeps "/88" sample text.
- New: Random Name, Mini XP, Notifier and Eagle map are load-on-demand folders. `/gt module <name> on|off` and `/gt modules`.
- New: Tools option to import GatherMate2 data on zone change; "Hide layer info" on the HUD.
- Change: less memory and garbage; only your language stays loaded; Notifier keeps no roster copy.
- Fix: buff frame level with player, target and fps / ping panel.

## 0.24.9 (2026-11-16)

- New: automatic hover tooltips on HUD and Eagle maps, with a Hover key button (HUD Options).
- New: Notifier voice button (name, online / offline, zone) and a smaller pop-up showing Friend / Guild Member, guild, level, class, zone.
- Change: player and target frames level with the fps / ping panel; HUD tab text, tooltips and sound buttons translated; Help covers Notifier voice, compact map and hover.

## 0.24.8 (2026-11-15)

- New: hover tooltips on by default (hold Alt; `/gthud hoverkey`), Compact map (75%, no rings / compass / heading), HUD auto-off in cities and inns, HUD blip size 1.0x–1.4x, memory readout (Pings tab).
- Fix: Notifier shows logins; FPS / ping tooltips say "bar"; G1–Gx labels no longer shimmer; group-member dots hover correctly.
- Change: Show time greyed out while Notifier is off; "Restore HUD after /reload or login" removed; Help and labels updated and translated.

## 0.24.7 (2026-11-13)

- New: Friend / Guild Notifier: pop-up with sound when a guild member or friend goes online or offline.
- Change: Xbox and Windows removed from the ping and Nodes sound lists.

## 0.24.6 (2026-11-12)

- New: Performance tab (Full / Balanced / Lowest), Pings tab with a repeating red-ping sound, arrow size slider, XP goals and session history.
- Change: player arrow hides during Eagle Eye; Boom.ogg removed; more space and tooltips in Minimize and HUD settings; no-effect options greyed out.
- Fix: minimized bar keeps its fps, H and W switches.

## 0.24.5 (2026-11-11)

- New: skill ETA (Herbalism / Mining) and "Best node" (gold per hour) in the session summary.
- New: bag space warning (Minimize > Chips) with a red "Bags: N" chip.
- New: competition detection: spots found looted are marked "taken", counted in the summary, and no longer teach too-long timers.
- New: choose what the XP line shows, optional gold per hour, level-up and "close to level" alerts (Minimize > XP).
- Change: smarter next spot ("ready on arrival" / "(often taken)"); translations in `GatherExtra.lua` and `XPExtra.lua`.
- Fix: Bar opacity also fades the minimized-bar buttons.

## 0.24.4 (2026-11-11)

- Fix: clicking the HUD map no longer shows the yellow ping circle; other players' pings are hidden while the HUD is on.

## 0.24.3 (2026-11-10)

- New: Random Name option "Hide target-of-target in combat" (on).
- Change: changing language asks first and can be cancelled; clicking text next to a check box toggles it; Random Name uses less CPU and memory.
- Fix: saved low-health % and map text size stay in slider range; low-health warning only on Hardcore; Graphics quality Off no longer overwrites game-menu settings; Tools status text cut at its box.

## 0.24.2 (2026-11-08)

- New: Eagle map while Eagle Eye is on (size, opacity, zoom, rotation, rings; `/gthud eagle`). Also Far Sight, Mind Vision, Eyes of the Beast, Eye of Kilrogg. Hover tooltips, distance scale, nearest-node readout, Preview button, 3 key bindings.
- New: HUD rings in yards (`/gthud ringunit yd`); Gx labels and (G) timer texts hidden while the HUD is off (and on the Eagle map).
- New: LibDataBroker feed (ready count / time left; left-click opens, right-click toggles HUD).
- Change: HUD always centred (offset sliders, Unlock and `/gthud unlock|lock|offset` removed); minimized bar shows at load with a red x; Drunken haze is back (Settings > Display); `/gthud skins` gets `hide`, `show`, `mark`, `diff`; rings redraw only on change; lighter Eagle Eye detection; Help updated (some translations incomplete).
- Fix: camera turning with the mouse; HUD displaced by other minimap addons; HUD size shrunk by small window / high UI scale; switching HUD off restores arrow and frames from SexyMap etc.; route-only readout vanishing; tracking tooltip on non-English clients; HUD x / y limits on profile load; saved-data version lowered by older versions.

## 0.24.1 (2026-11-07)

- New: Graphics quality slider (Off / Low / Very low / Minimal); `/gt gfx`.
- Change: HUD hides minimap skin textures as wide as the stock minimap; `/gthud skins` lists minimap frames. Drunken haze removed (returned in 0.24.2).
- Fix: HUD opacity flicker / sticking from 0 to 100%; masks preloaded.
- Known issue: with SexyMap a white arc can show along the bottom of the HUD circle.

## [v0.24.0](https://github.com/ridinsa/GatherTimes/tree/v0.24.0) (2026-11-06)
[Full Changelog](https://github.com/ridinsa/GatherTimes/compare/v0.23.2...v0.24.0) [Previous Releases](https://github.com/ridinsa/GatherTimes/releases)

- New: hero and pet XP merged in from GetXP: "XP" button on the minimized bar (battles to level, XP/hr, time to level, pet battles, latest gain). `/gt xp`, `/gt xp reset`, `/gt xp session`.
- Change: Minimize settings split into tabs (Bar, Chips, Fade, XP).
- Removed: the GetXP window, Quests and Spots tabs and chat window. Delete the GetXP addon folder.
