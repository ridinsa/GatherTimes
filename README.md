# GatherTimes

Herb and ore respawn timers for World of Warcraft: learned spawn spots, gathering routes and a full-screen minimap HUD.

- Respawn timers per node and per spot group, with on-screen and sound alerts
- Learns spawn points and timings as you gather
- Routes and map pins (optional TomTom support, GatherMate2 import)
- Full-screen minimap HUD (`/gt hud`)
- Minimized one-line bar docked to the top of the screen
- Per-zone yield statistics (`/gt yield`)
- 11 languages

## Supported clients

| Client | Interface |
|---|---|
| Classic Era / Season of Discovery / Hardcore | 11509 |
| Burning Crusade Classic Anniversary | 20506 |
| Cataclysm Classic | 40402 |
| Mists of Pandaria Classic | 50503, 50504 |
| WoW Forever | 16001 |
| Retail (Midnight) | 120105 |

## Install

1. Download the latest zip from the [Releases](../../releases) page.
2. Extract it so the folder is `World of Warcraft/_<client>_/Interface/AddOns/GatherTimes`.
3. Restart the game or type `/reload`.

If you clone the repository instead, the cloned folder must be named `GatherTimes`.

## Usage

- `/gt` opens the main window
- `/gt hud` toggles the minimap HUD (also bindable under Key Bindings > AddOns)
- `/gt min` toggles the minimized bar
- `/gt yield` shows zone yield totals

The in-game help (`?` button in the title bar) lists the rest.

## Known limits

- Only vanilla nodes are tracked (Peacebloom to Black Lotus, Copper to Thorium). Nodes from later expansions are not tracked yet.
- The minimap HUD and the UI calls on Retail and WoW Forever are untested. Errors in the HUD are caught and reported, and the timers keep working.

## Building a release

The `.pkgmeta` file is for the [BigWigs packager](https://github.com/BigWigsMods/packager). Pushing a tag such as `v0.23.0` runs `.github/workflows/release.yml`, which builds the zips and attaches them to a GitHub release. The libraries stay bundled in `Libs/`.

## Credits and licenses

- GatherTimes is licensed under GPL-3.0-or-later (see `LICENSE`).
- The idea of the full-screen minimap HUD comes from [FarmHud](https://github.com/HizurosWoWAddOns/FarmHud) by Hizuro (GPL-3.0). The code and the HUD mask textures in `Masks/` are original to GatherTimes.
- Bundled libraries keep their own licenses: HereBeDragons (BSD, by Nevcairiel), LibStub and CallbackHandler-1.0 (see their upstream projects).
