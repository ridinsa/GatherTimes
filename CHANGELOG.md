# GatherTimes

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
