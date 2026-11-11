# GatherTimes

## 0.24.3 (2026-11-10)

New
- Random Name: "Hide target-of-target in combat" option (on by default)
- Random Name: also replaces your name and pet name on name plates
- Random Name: also turns off guardian/minion name settings while active
- HUD: "Preview HUD" button and a list of key bindings
- Eagle map: "Same zoom and rings as the HUD" option
- Minimize > Chips: yellow/red warning time sliders
- Reset session / Reset learned timings now ask for confirmation

Changes
- Changing language asks for confirmation before reloading
- Clicking the text next to a check box toggles it
- Removing a timer needs Shift + right-click
- Built-in arrow removed; navigation uses TomTom only
- Random Name uses less CPU and memory
- Map pin hover shows the item name only (faster)
- HUD profile Delete acts on the profile selected in the list

Fixes
- Low health warning only shows on Hardcore characters
- Graphics "Off" no longer overwrites settings you changed in the game menu
- Camera dragging sometimes not working while the HUD was on
- Apply/auto-apply learned times now needs 5 samples, as the legend says
- Taken % and misses are correct after resetting learned timings
- Nodes panel: typed times go to the right node, "13,5" accepted
- Slider values stay in range when settings load
- Settings > Tools status text no longer overlaps buttons

## 0.24.2 (2026-11-08)

- New: the Eagle map uses the HUD's zoom and rings (HUD settings > Eagle, "Same zoom and rings as the HUD"; on by default). A ring set in pixels is scaled to the smaller map so it stands for the same distance; a ring set in yards is the same as on the HUD. The Eagle zoom keys then change the HUD's zoom. Off keeps the separate Eagle zoom and the edge / half-way rings.
- Fix: dragging the mouse to turn the camera sometimes did nothing while the HUD was on. The full-screen HUD map never takes mouse clicks now: the normal HUD ignores the mouse completely, and the Eagle map only watches the mouse move (for the herb / ore tooltips). If the game or another addon switches the Minimap's mouse back on, it is put right on the next frame instead of up to half a second later.
- New: the Gx group labels and the (G) timer texts on the minimap are hidden while the HUD is off and shown while it is on (HUD settings > Options, "Hide Gx and (G) timers while the HUD is off"; on by default). The world map keeps its labels.
- New: the same labels are hidden on the Eagle Eye map (HUD settings > Eagle, "Hide Gx and (G) timers on the map"; on by default), and come back when the Eagle map ends.
- Change: HUD settings > Options: "Rotate map with player" and "Show player arrow" share one row to make room for the new checkbox.

- Change: Help panel brought up to date with the addon. The minimized bar entry now lists the XP button, the red x and the Minimize settings tabs (Bar, Chips, Fade, XP); new XP button entry; the command list gains `/gt xp` (`reset`, `session`), `/gathertimes`, `/gt minimize`, `/gthud skins hide | show | mark | diff` and `/gthud eagle debug`; the Credits tab shows 0.24.2.
- Known issue: the translated Help texts (all languages except English) do not cover everything the English Help does yet (Eagle map, graphics quality, yard rings, XP, newer commands). Only their version number was updated; the rest is shown as it was.
- Change: code cleanup, no change in behaviour. The unused `ADDON` / `addonName` local (`local ADDON, GT = ...`) is now `local _, GT = ...` in the 59 files that never used it, including all Panel files and NameDisguiseFrame.
- New: LibDataBroker feed. With a Broker display addon (Titan Panel, ChocolateBar, Bazooka...) a GatherTimes button shows the ready count or the time left on the soonest timer, a tooltip per item, left-click opens the window and right-click turns the HUD on / off. Nothing is added when no Broker display is installed.
- Fix: the saved-data layout number (`_dbVersion`, HUD `ver`) is no longer lowered when an older version of the addon loads data written by a newer one.
- Change: version 0.24.2 in the TOC.

- Change: the HUD is always centred. The Offset X / Y sliders, the Unlock / drag button and handle, and `/gthud unlock`, `/gthud lock` and `/gthud offset` are removed; offsets saved in older profiles are ignored. The tracking button can only be dragged while the HUD is off (while it is on, use the Track tab sliders).
- Fix: the minimap's mouse state is checked twice a second while the HUD is up, so it is switched off again if something turns it back on when the Eagle map ends.
- New: Eagle map hover tooltips (HUD settings > Eagle, `/gthud eagle hover`). The HUD switches the minimap's mouse off, which also removed the game's herb / ore name tooltips; the Eagle map now turns it on with clicks passed through to the world; the map's own click handler (ping, tracking menu) is switched off while it is up.
- New: three Eagle map key bindings (Key Bindings > AddOns): zoom in, zoom out, next size (saved size, bigger, smaller; the size change is not saved).
- New: the Eagle map also appears for Far Sight (shaman), Mind Vision (priest), Eyes of the Beast (hunter) and Eye of Kilrogg (warlock).
- Change: Eagle Eye detection is lighter. Classes without a remote view skip the buff check on every aura change, buffs are looked up by spell id instead of scanning all 40, and the answer is reused within a frame.
- Fix: if a client reports neither a channel nor a buff for the spell, a successful cast now brings the map up for up to 60 s (ended by an interrupt or channel stop). It is only used until a channel or buff has been seen once.
- New: Eagle Eye map distance scale (HUD settings > Eagle, `/gthud eagle scale`). The edge of the map and a ring half-way in are captioned with the yards they stand for, e.g. "233 yd" / "117 yd", and the captions follow the zoom and indoors / outdoors.
- New: Eagle Eye map nearest node readout (HUD settings > Eagle, `/gthud eagle nearest`). Shows the nearest known node with READY or the time left and the distance in yards, the same readout the normal HUD has. Distances are measured from the same point the map pins are placed from.
- New: Eagle Eye map (HUD settings > Eagle, `/gthud eagle`). While a hunter's Eagle Eye is on, the HUD no longer switches off: it stays on and the map is drawn centred at its own size (default 450 px), opacity, zoom and rotation (north-up by default), with an optional ring. Compass letters and readouts are hidden while it is up, and the normal HUD settings come back in one step when Eagle Eye ends. The stock minimap is not restored in between, so there is no flicker. "Show this map during Eagle Eye" off keeps the old behaviour (HUD off during Eagle Eye). "Preview Eagle map" / `/gthud eagle preview` shows it without casting Eagle Eye.
- New: HUD rings can be set in yards (HUD settings > Rings, Unit button; `/gthud ringunit yd`). A yard ring keeps its real distance at any HUD size and zoom (it follows the minimap's reach, indoors and outdoors), shows a "40 yd" caption, and is hidden when it is farther out than the map shows. Pixels stay the default, so existing profiles look the same. `/gthud ring` and `ring2` use whichever unit is set.

- Fix: HUD route-only readout (priority readout off, route readout on) no longer disappears until the next one-second tick when settings change.
- Fix: when another minimap addon keeps moving the Minimap and the HUD pauses its re-apply, it now re-applies once when the pause ends, so the HUD is no longer left displaced. A one-time chat notice names the cause.
- Fix: the saved HUD size is no longer shrunk by one login at a small window or high UI scale. The screen limit is applied only when the HUD is drawn; the profile keeps the size you chose.
- Change: the HUD rings are laid out again only when radius, colour, style, thickness, density or segments change, not on every update (smoother size slider).
- Fix: switching the HUD off restores the player arrow another addon had set (SexyMap etc.), not always the stock arrow. Only arrow changes made after GatherTimes loaded can be seen.
- Fix: switching the HUD off no longer shows minimap frames that another addon hid after the HUD did.
- Fix: the HUD tracking button's tooltip name fallback now also recognises tracking abilities by spell ID, so it no longer shows "Active" on non-English clients when the icon lookups fail.
- Change: `/gthud skins` now lists every shown piece on the Minimap, numbered, including small and thin textures (layer, texture, colour, whether the HUD hid it). `/gthud skins hide <n>` and `/gthud skins show <n>` hide or show one item for testing, to find what draws the white arc seen with SexyMap. Map pins are skipped and only visible pieces are listed. For an arc that comes and goes: `/gthud skins mark` while it is gone, `/gthud skins diff` while it shows.
- Fix: HUD x and y are limited when a profile is loaded, so a hand-edited SavedVariables file can no longer put the HUD off screen.

- New (Settings > Display): Drunken haze on/off is back. It switches the game's full screen glow, which is what draws the drunk blur, so turning it off also removes that glow everywhere.
- Change: the minimized bar is now shown as soon as the addon loads (Always show minimized panel is on by default), and has a red x after the "+" that hides it until the window is opened again or /gt min is used.
- Change: the HUD no longer stops switching on when one Minimap frame refuses method calls, the opacity mask swap waits for the slider to rest, the tracking menu on clients with a tracking list is a flat popup, and the masks are 256 x 256.

## 0.24.1 (2026-11-07)

- New (Settings > Display): Graphics quality slider (Off / Low / Very low / Minimal) for slow PCs, screen effects on/off, weather density and maximum camera zoom. Your own graphics values are saved when you leave "Off" and restored when you go back.
- Change: the Graphics quality slider applies once when you let go (not at every step), the levels now differ clearly from each other (more settings, plus render scale), and `/gt gfx` lists which graphics settings this client has.
- Removed: the Drunken haze option (Settings > Display) and its code. If you had it switched off, the full screen glow is turned back on once at your next login.
- Change: the HUD hides minimap skin textures that are as wide as the stock minimap, even when they have a name, and re-checks the minimap skins twice a second while the HUD is on. Added `/gthud skins`, which lists the minimap frames and textures for a bug report.
- Known issue: with SexyMap enabled, a white arc can still show along the bottom edge of the HUD circle. The source is not identified yet; use `/gthud skins` with the HUD on and report the output.
- Fix: Minimap HUD map opacity. Changing the opacity now swaps only the mask texture (once per frame, last value wins) instead of re-applying the whole HUD on every slider step, so going from 0 to 100% no longer flickers or sticks. The 11 mask files are preloaded, and the mask is set before the Minimap is resized when the HUD is switched on, which removes the stock-mask "shadow" for the first frames.

## [v0.24.0](https://github.com/ridinsa/GatherTimes/tree/v0.24.0) (2026-11-06)
[Full Changelog](https://github.com/ridinsa/GatherTimes/compare/v0.23.2...v0.24.0) [Previous Releases](https://github.com/ridinsa/GatherTimes/releases)

- 0.24.0: XP button, rested XP and minimize settings tabs  
    # Changelog  
    ## 0.24.0  
    - New: hero and pet XP, merged in from the GetXP addon. A small "XP" button after the dropdown on the minimized bar turns XP mode on. In XP mode the bar shows all the XP information in one line in place of the gathering timers: hero battles to the next level, XP/hr, time to level, pet battles, the battle timer, the hunter pet-capped alert and the latest gain. Picking an item in the dropdown turns XP mode off. The XP button can be hidden in Minimize settings > XP. The bar shows hero battles, XP/hr, time to level, rested XP and the pet-capped warning. Hovering the XP button shows the session totals, pet battles, the last battle, rested XP with the battles it covers, the XP to the next level, and the latest five gains. The tracking runs all the time. `/gt xp` toggles XP mode, `/gt xp reset` starts a new XP session and `/gt xp session` prints the totals.  
    - Change: Minimize settings are split into tabs: Bar, Chips, Fade and XP. The options are grouped by what they change.  
    - Removed: the GetXP window and its minimized icon, the Quests and Spots tabs, the transparency and hide-in-battle buttons, and the chat window that GetXP created ("ExpInfo"). Delete the GetXP addon folder after installing this version.  
