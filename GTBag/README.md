# GTBag 0.25.3

An inventory browser for gatherers, with five window styles (Baganator-like by default). Open with `B` or `/gtbag`. When opened out of combat, GTBag hides the Blizzard bag windows; it defers hiding them during combat to avoid protected-frame errors. Blizzard's native windows handle item transfers.

- Icon grid of bags in one window, quality-coloured borders, item level on gear, BoE labels, optional Pawn upgrade arrows, junk coin and cooldowns. The **Opt** menu toggles each badge; **Settings > Badges** sets their corners and collision priority. Items in your own bags and bank can act like the default bags (click, right-click, shift-click, drag) when you turn on `/gtbag actions on`; other characters' items are read-only. Physical sorting moves items out of combat.
- Search box: hides nonmatches by default; **Settings > Search** switches to dimming them.
- Views (View button): **categories** (Herbs, Ore, Trade goods, Consumables, Quest, Equipment, Gems, Containers, Other, Junk) or **bag slots**.
- Set the window width from **8 to 15 slots per row** with **Settings > Columns**, or hold **Ctrl** and turn the **mouse wheel** over the window; the chosen width is remembered.
- In category view, click and drag an item onto another item in the same category to swap their visual order; this does not move inventory items. The order is saved per character and inventory section.
- Empty inventory and bank slots are shown by default in both views; category view groups them in an **Empty slots** section. Toggle **Ignore empty slots** under the **Slots** button to hide them. The bank view combines bank containers and reagent bank in one sorted section; the guild **All** view stays occupied-items-only.
- Under the **Slots** button, toggle **Show Backpack**, **Show Bag 1**, etc. to hide individual bags or bank containers from the grid. Use **Show all containers** under the **Slots** button to show them again.
- Open the **Slots** button and choose **Manage inventory slots** to show a small control on each inventory slot. Use **x** to hide a slot or **+** to restore it; hidden items remain in your bags. Visibility is saved per character, and **Show all hidden slots** restores every hidden inventory slot. **Shift-click the x** on an item to hide that item everywhere: every stack of it, in any slot or bag, stays hidden (dimmed, with a **+**, while you manage slots; click the **+** to show it again). Right-click the eye button to show all hidden items for a moment, and right-click again to hide them; Pin items mode also shows them. Sell junk never sells hidden items, and sorting leaves hidden slots where they are. Empty slots are exposed while managing, even if **Ignore empty slots** is enabled.
- Click the **sort icon** beside the Sort button and choose **Name (A-Z)**, **Quality > Category** or **Number of items** (largest stacks first) to switch to bag-slot view and sort and merge, combine the backpack and regular bags into one group (quivers/ammo pouches stay separate), enable visual auto-sort, select Quality then Category, and physically sort while merging compatible stacks. On completion, auto sort switches itself off; the combined view remains, hidden bags are revealed, and your **Ignore empty slots** setting is kept.
- Item tooltips include known counts across saved character bags and banks, guild banks, unexpired mail, void storage, and saved active-auction scans. Bank, guild, mail, void-storage, and auction details depend on having visited the corresponding UI with that character.
- Physical sorting moves real items out of combat using GTBag's selected order and combines compatible partial stacks up to each item's stack limit (overflow stays in additional slots). Regular bags are sorted together; family-restricted bags stay separate and are sorted internally. Arrows and bullets are moved into matching equipped quivers or ammo pouches when space permits. Other sort choices include **Type**, **Quality** (highest first), **Expansion** (oldest first), **Item level** (equipped items, highest first), **Name**, **Value**, or **Category**. Quality then Category sorts highest quality first, then follows the category order. Display sorting is optional; turn on **Auto sort items** to sort displayed items, and turn it off to preserve source slot order. Poor-quality items sort last whenever sorting is enabled.
- **Opt > Equipped bags row**: view your equipped bags (shows the free general-slot count).
- Footer: money and free / total slots.

## New in 0.25.14

- **Small public API for other addons** (`GTBagAPI`, always available from login): `IsPrivacyOn()`, `DisplayName(name)` (the scrambled name when Privacy mode is on) and `RegisterPrivacyCallback(fn)` (called when Privacy mode is switched or scrambled again). An addon such as GatherTimes can use it instead of GTBag patching its tooltip text:

  ```lua
  local api = _G.GTBagAPI
  local shown = (api and api.DisplayName) and api.DisplayName(name) or name
  if api and api.RegisterPrivacyCallback then api.RegisterPrivacyCallback(function() MyRefresh() end) end
  ```

  Before the bag window has loaded (the first seconds after login) the functions answer "off" and return the name unchanged. The tooltip name scrambling stays as the fallback for addons that do not use the API.

## New in 0.25.13

- **Less memory churn in privacy mode**: scrambled names are kept (bounded) until you scramble again, class colours are built once per class, and the tooltip name replacement keeps its name list for a few seconds, searches each line before replacing and reuses one callback instead of building a new one for every tooltip.

## New in 0.25.12

- **Privacy mode in item tooltips**: fixed names that were not scrambled when the other addon draws them in a class colour (the name sits right after a colour code).

## New in 0.25.11

- **Privacy mode in item tooltips** now also scrambles a character's **nickname**, not only its real name, and a character with a nickname shows the same scrambled name in the tooltip as in the bag window.

## New in 0.25.10

- **Privacy mode in item tooltips**: with Privacy mode on, character names that other addons add to an item tooltip (for example GatherTimes' Inventory list) are scrambled the same way as in the bag window. Display-only; off means real names again.

## New in 0.25.9

- **Lighter on the CPU**, no change to what you see:
  - Counting loops (ammo, tooltip counts, the new-item snapshot, the bag snapshot) no longer build a table for every slot.
  - The low-ammo check now runs only for characters that can use ammo (Hunter, Rogue, Warrior on a client that has ammo); before, every character scanned its bags on each bag update. The footer still shows ammo you carry.
  - Closing another bag addon's window walks every UI frame at most once every 3 seconds; in between it re-checks the windows it already found.
  - The window's fade-while-moving check runs 5 times a second instead of 10, and reads its options twice a second.
  - The item-name and item-class caches replace their older half when full instead of emptying everything.
  - **Find in all characters** shares its 400-row limit between characters, so the ones listed first cannot use it all.

## New in 0.25.8

- **Merge all bags into one group**: **Settings > Sort > Merge all bags into one group** (or `/gtbag merge on|off`) shows the backpack and your bags as one **All bags** group in the bag-slots view, without sorting or moving anything. Turning it on switches to the bag-slots view. Quivers and ammo pouches stay separate. Previously only the sort icon could switch this on.

## New in 0.25.7

- **Default layout**: category view, 10 columns, stacked style, empty slots shown, the tab row (Inv / Bank / Mail / Guild) hidden, window in the lower right. It is applied once on a first install and once on an existing install the first time this version runs (only layout options: pins, categories, hidden items and sort order stay). Settings you change afterwards are kept. `/gtbag layout` or **Settings > Apply default layout** applies it again; turn the tab row on from **Opt > Window > Tab row**.

## New in 0.25.5

- **Search language**: the search box (and **All**) understands operators; a plain word still works as before.
  - `herb & !bound` AND (`&`), OR (`|`), NOT (`!`) and parentheses: `(herb | ore) & value>50s`
  - Fields: `name:` `type:` `sub:` `cat:` `bind:` (`bop`, `boe`, `bou`, `quest`, `none`) `is:` (`bound`, `boe`, `junk`)
  - Numbers: `ilvl` `count` `quality` (a number or `poor`...`legendary`) `value` (the stack) `price` (one item) `id`, with `>` `>=` `<` `<=` `=`. Money reads `1g50s`, `20s`, `5c` or copper. `value` uses the GatherTimes scan price when installed, else the vendor price.
  - A query that cannot be read, and a field name it does not know, fall back to the plain word search.
- **Saved searches as categories**: start a rule with `?` and it is a search: `/gtbag cat add Cheap herbs = ?herb & value<50s`, or type `?herb & value<50s` as a rule in the category editor. Earlier categories win, then the built-in ones. Do not use commas in a saved search (they separate rules). Right-click the section header to move or mail everything the search found.

## New in 0.25.4

- **Section transfer**: right-click a section header in the Inv or Bank tab (Herbs, Ore, Gems...). With the **bank open** the menu offers **Move to bank** (from Inv) or **Move to bags** (from Bank), done the same way as a right-click on each item, so the game picks the target. With a **mailbox open** it lists your other saved characters: **Mail to <character>** opens the Send Mail tab, fills in the recipient and attaches up to 12 stacks; press **Send** yourself, then right-click the header again for the rest. Pinned items, hidden slots and items, locked items and (for mail) soulbound items are never moved. Out of combat only. Mail sent this way appears in the other character's Mail tab at once.

## New in 0.25.3

- **Mail expiry watch**: a few seconds after login GTBag prints which of your characters have saved mail that expires within 3 days, with the item count and value at risk. The character list marks those characters with a red `! mail 2d`, and the Mail tab shows **new mail - open a mailbox** when the game reports new mail since your last visit (the saved snapshot is older). `/gtbag mail` prints the list at any time. **Settings > Alerts** has the on/off switch, the warning days (1-10) and a switch to skip cash-on-delivery mail. It only reads the mail snapshots GTBag already saves, so a mailbox visit is still needed to refresh them.

## New in 0.25.2

- **Bag value tooltip**: hover the money at the bottom of the window to see what the items in it are worth, split by category (the GatherTimes auction scan price when GatherTimes is installed and higher than the vendor price, otherwise the vendor price). It follows the tab and character you are viewing and includes hidden items.

## New in 0.25.1

- **Hide this item everywhere**: in Hide slots mode, shift-click the **x** on an item to hide every stack of it, in any slot or bag. Click its **+** to show it again.
- **Show hidden items**: right-click the eye button (or run `/gtbag hidden`) to show all hidden items, dimmed; do it again to hide them. Pin items mode shows them too. Hidden items are closed again when the window closes.
- **Close in combat**: **Settings > Close the window when combat starts** (off by default) closes the window as soon as you enter combat. **Reopen the window after combat** (off by default) opens it again when combat ends. Both are saved for each character separately.
- **Sell junk is safer**: it never sells items in hidden slots or hidden items, leaves out grey items the vendor does not buy, and asks first when you sell more than 12 stacks by hand (the vendor's Buyback tab keeps only 12). Auto-sell does not ask.
- **Sorting** leaves hidden slots where they are and retries a move up to 2 times when the game is slow to confirm it.
- **Backup / restore** now also covers hidden items, hidden slots and the per-character settings.
- **Fix**: item names and prices no longer fail on game versions where the old `GetItemInfo` is gone.

## Compact header (unreleased)

The window now has one row of tabs instead of two button rows.

- **Opt menu** (gear icon; right-click it for settings): *Edit mode* (Hide slots, Pin items), *Show* (Ignore empty slots, Equipped bags row, and one **Containers (3/5 shown)...** entry that opens a small window with a checkbox per bag or bank container and a Show all button), *Badges* (the three on/off toggles only), and *Window* (Tab row, Settings). It replaces the old **Del**, **Slots** and **Badges** buttons, so wherever this README says "Slots button", "Slots > Pin items" or "Delete button", use the Opt menu.
- **Settings > Badges** now holds the badge corners and priority (they were rows in the Opt menu).
- The **<** and **>** buttons are gone (see Columns above), and so is the **Bags** button (now in the Opt menu). **Opt** and **View** are icon buttons with tooltips, which leaves the search box wider.
- **Filter / Dim** moved to **Settings > Search**. **All** (search all characters) stays inside the search box.
- The **Tab row** (Inv / Bank / Mail / Guild) can be hidden from the Opt menu or the settings window.

## New in 0.5.34

- **Item deletion removed**: GTBag no longer has its own Delete items mode, Delete selected or Clear selection. Deleting an item is done only with the game's own prompt.
- **Pins fixed**: a pinned item can no longer be destroyed with the game's delete prompt. Dragging it out of the bag and dropping it closes the prompt, puts the item back in its slot and prints a message. Other addons that call the delete function directly are not covered.

## New in 0.5.33

- **Fold category sections**: click a category header (`[-]` / `[+]`) in the category view to fold or unfold it. It is remembered per category. Searching always shows everything. `/gtbag collapse all` and `/gtbag collapse none` change all at once. Works in the Stacked, Columns and List styles.
- **New items**: items that arrive in your bags during the session glow green until you hover them (Opt > Glow on new items; `/gtbag new clear` clears the marks). Turn on **Show a New section** to also list them together at the top of the category view. Items picked up before you first opened the window this session are not marked.

## Install layout (0.5.32)

GTBag is two folders that ship together: `GTBag` (a tiny always-loaded loader that registers `/gtbag` and the bag keys) and `GTBag_Core` (the bag window, load-on-demand). Copy both into `Interface\AddOns`. GatherTimes is not needed. The core loads the first time you open your bags or type `/gtbag`, or at login when another bag addon is installed.

## New in 0.5.32

- **Lower memory use**: less garbage is created, so the addon's memory figure stays lower and the game's garbage collector runs less often. Nothing about how the window looks or behaves changes.
  - Sorting no longer builds new name strings for every comparison; item names and their lower-case forms are cached (bounded).
  - A drawing pass reads each live slot once instead of twice, and its position tables are reused.
  - The saved bag and bank snapshot is updated in place on a bag update instead of being rebuilt from scratch.
  - With the window closed, cooldown, item-lock and item-info events no longer run the low-space and low-ammo check. The low-ammo count reuses its tables.
  - Item-info events (they arrive in bursts, for every item any addon asks about) now cause at most one redraw per second.
  - The search no longer builds lower-case copies of category and type names on every refresh.

## New in 0.5.31

- **Window styles**: the window can now be laid out in five ways. Change it in **Settings > Window style**, with `/gtbag style stack|columns|flat|list|sidebar`, or **shift-click the View button** to step through them. The style works with both views (categories and bag slots), every tab (Inv, Bank, Mail, Guild) and every character, and is remembered.
  - **Stacked** (default): sections one under the other, each with a heading and a grid as wide as the window.
  - **Columns**: sections as compact blocks side by side, the shortest column getting the next block, so a bag with many small categories is much shorter. **Settings > Columns style: blocks** sets how many (2 to 4; a narrow window uses fewer so a block is never narrower than 3 slots).
  - **One grid**: every item in one continuous grid with no headings.
  - **List**: a row per item with its quality-coloured name, stack size, category and stack value (GatherTimes scan price when installed, else vendor); the whole row reacts to the mouse. Shows items only, no empty slots. The window width (Columns option) decides how many list columns fit.
  - **Sidebar**: a category list on the left (All, then each section with its count); click one to show only that section.
- The number of slots per row (**<** / **>** or Settings) still sets the window width in every style. Click, drag, pins, slot management and drag-reorder all work in every style. During combat the window keeps the style it already had; the new style applies afterwards.

## New in 0.5.30

- **Less memory churn**: the low-ammo check and the tooltip item counts no longer build a full item record for every bag slot on every bag update or tooltip; they read the item id first and build a record only for a match (arrows and bullets, or the item being counted). The mount / food tooltip scan now remembers two yes/no values per item instead of the whole tooltip text. Cooldown and item-lock events refresh the window at most once per 0.1 s instead of once per event.
- **Removed unused code**: the old "full in N min" estimate and its sample list (no longer shown since 0.5.18), `ns.ToggleFind`, an unused header button builder, an unused container helper and an unused layout constant. The README footer line and the addon description no longer mention the removed footer lines.

## New in 0.5.29

- **Profession-bag routing**: Sort + Merge now moves herbs, ore, gems and other profession items into a matching herb, mining, gem, enchanting, engineering, leatherworking, inscription, cooking or fishing bag, and soul shards into soul bags, using the item's own bag-family data instead of a fixed list. It fills empty slots in the bag first, then partial stacks of the same item. Arrows and bullets still go to quivers and ammo pouches as before. Turn it off with **Settings > Route profession bags** or `/gtbag route off`; ammo routing always stays on. Pinned items are never moved.

## New in 0.5.28

- **Empty window on the first opening after a reload, fixed at the cause**: `/gtbag draw` showed that the first drawing pass never ran at all, because the window's show event did not reach the drawing code that first time. The window now checks itself every frame while it is on screen and is drawn at once if it has not been drawn since it was shown.

## New in 0.5.27

- A drawing pass that is skipped without an error is now noticed too: GTBag prints the reason once and tries again.
- `/gtbag draw` prints the version and the state of the window (built, shown, height, what the last drawing pass did), draws it once more and reports the result. Use it when the window comes up empty.

## New in 0.5.26

- **No more window popping open by itself after a reload**: the invisible warm-up added in 0.5.25 is gone.
- **Empty window on the first opening after a reload**: the drawing now catches an error, prints it once in chat and tries again a moment later (up to four times), and the first opening is drawn a second time shortly after. If the window still comes up empty, the chat line shows what failed.

## New in 0.5.24

- **Better detection of other bag addons**: GTBag now scans the AddOns list instead of only checking a fixed list of loaded addons. It finds every bag addon that is enabled for your character, including ones that are switched on but not loaded yet, and bag addons it has never heard of (the name has to say bag and the description has to talk about replacing the bags or the bank). BaudBag, Baggins, OneBag4 and cargBags Nivaya were added to the known list. Helper modules such as Baganator_Config, BagSync and addons that are disabled or cannot load are ignored.
- **One click to choose, then it switches the other addon off and reloads**: whenever another bag addon is enabled next to GTBag, a window appears a couple of seconds after login with one button per addon, for example **Use GTBag (turns off Baganator and reloads)** and **Use Baganator (turns off GTBag and reloads)**. The addon you do not pick is turned off in the AddOns list and the game reloads by itself. If an addon cannot be turned off from the game, GTBag says so and does not reload for nothing. Enable GTBag again in the AddOns list to get it back; the window will ask again if another bag addon is on.
- The window is shown on every login while two bag addons are enabled. **Ask me later** closes it; tick **Do not ask again (keep both on)** first to stop it from appearing. `/gtbag bags` or **Settings > Other bag addons** open it again.

## New in 0.5.23

- **Other bag addons stay closed when you pick GTBag**: choosing GTBag used to hide only the default bags, so Bagnon, Baganator, AdiBags and the others still opened their own window beside it. While GTBag is the chosen addon, their bag windows are now closed the moment they open (found by frame name, so no addon-specific code; bank, guild, options and tooltip windows are left alone). Out of combat they are hidden; in combat a protected window is made transparent and closed afterwards.
- **Disabling the other addons is now verified**: the chooser tries your character name, then your character GUID, then every character, and checks the AddOns state after each try. If an addon could not be turned off from the game it says so instead of reloading for nothing; disable it in the AddOns list at the character screen.
- `/gtbag bags frames` lists the windows of the detected addons (shown or not, size, parent and whether GTBag closes them) to help when one window is not being closed.

## New in 0.5.22

- **Other bag addons**: when GTBag finds Baganator, Bagnon, AdiBags, ArkInventory, Combuctor, OneBag3, Inventorian, LiteBag, Bagginses, BetterBags, Bagshui, Sorted or TBag loaded alongside it, a window opens a couple of seconds after login and asks which addon should handle your bags. Pick **GTBag** and it follows the bag key and hides the default bags; pick another addon and GTBag stays loaded but steps aside (the Replace option turns off, so the bag key, bank and guild bank are left to the other addon, and `/gtbag` still opens GTBag). Tick **Disable the bag addons I did not pick** to turn the others off for this character, which reloads the UI. Your choice is remembered for that set of addons and is only asked again if the set changes, unless you tick **Do not ask again**. If the addon you handed the bags to is later removed, GTBag takes them back. Reopen the window with `/gtbag bags` or **Settings > Other bag addons**.

## New in 0.5.21

- **Pinned items**: protect items you never want to lose. Open **Slots > Pin items** (or `/gtbag pin mode`) and click the **+** that appears on an item to pin it; a gold star marks pinned items, and the same click unpins. `/gtbag pin [shift-click an item]` toggles one item, `/gtbag pin list` lists them and `/gtbag pin clear` unpins everything. Pins are by item id and shared by all your characters. A pinned item is never sold by Sell junk or auto-sell, cannot be deleted with the game's own delete prompt (drag it out of the bag: the prompt is cancelled and the item returns to its slot), and stays in its slot when you Sort + Merge: it is left out of the sort, so nothing moves it, merges into it or shuffles around it. Its tooltip says "pinned". Pins are included in Backup and restore (up to 500).
- **Settings window**: `/gtbag settings`, or right-click the **Opt** button. It is one compact window with six tabs: **Look** (view, theme, window style, columns, scale, tab row, search mode, see-through while moving), **Bags** (replacing the Blizzard bags, bank and guild bank, click and drag, close and reopen around combat), **Sort** (sort order, auto sort, merge bags, ignore empty slots, profession-bag routing, new-item glow), **Badges** (labels, corners, priority), **Alerts** (low-bag and low-ammo warnings, mail expiry watch) and **Tools** (privacy mode, auto-sell junk, and buttons for the category editor, backup / restore, other bag addons, the default layout and resetting the window position). It reads and writes the same options as the slash commands, so the two always agree. Hover a control for a short explanation; on a choice button, click for the next value and right-click for the previous.

## New in 0.5.20

- **Free-slot count on the Bags button**: the button shows how many general bag slots are free, in green, yellow (up to twice your warning limit) or red (at or below it). Quivers and ammo pouches are not counted, because an empty arrow slot cannot take loot; the same rule now applies to the "bags are full" chat warning. Hover the button for the exact numbers.
- **Low-ammo warning**: when your arrows or bullets (bags plus the equipped ammo slot) drop to the limit, GTBag prints a chat line and shows a red message on screen, once, and again after you have restocked above the limit. Default limit is 100. `/gtbag ammo N` changes it, `/gtbag ammo off` disables it. A type is only watched after you have carried some this session, so non-hunters never see it.
- **Privacy mode**: the old Scramble names option now also hides every gold amount and scrambles guild names (guild bank headings, search-all results, `/gtbag chars`, notices), and scrambles the realm shown beside a character. Use **Privacy mode** in the character selector, or `/gtbag privacy on|off` (`/gtbag scramble` still works). Display-only, like before.
- **Backup and restore**: `/gtbag backup` opens a window with your nicknames, custom categories, junk keep list and pinned items as plain text. Press **Export** and copy it; on another install (or after a reinstall) paste it into the same window and press **Import**. Importing only adds, it never deletes. A nickname for a character that has not logged in on that install yet waits and is applied when it does.
- **Auto-sell junk (optional, off by default)**: `/gtbag junk auto on` sells grey items when a vendor window opens, still skipping everything on the keep list. `/gtbag junk auto off` turns it off, and right-clicking the **Sell junk** button toggles it. The vendor's Buyback tab holds the last 12 stacks, so an accidental sale of a few items can be undone.

## New in 0.5.19

- **Search all characters**: click **All** next to the search box (or type `/gtbag find linen`) to list every match in the saved bags, bank, mail, void storage, auctions and guild banks of all your characters. Several words must all match. Each row shows how old its saved data is (orange after 7 days). Hover a row for the item tooltip; click a row to open that character's bags, bank, mail or guild bank with the item name already in the search box (clear it to see everything). Item tooltips also list which characters hold the item.
- **Gold history**: the addon keeps a daily gold log per character (last 35 days). The character selector shows each character's gold change today and the total at the top; `/gtbag gold` prints today's and the last 7 days' change for every character. History starts from the first time you log in with this version.
- **Custom categories**: make your own groups in the category view. `/gtbag cat add Alchemy = silverleaf, 2447, [shift-click an item]` creates the group (or adds rules to it). A rule is an item id, a shift-clicked item, or part of an item name. Your groups show first and win over the built-in ones. `/gtbag cat` lists them, `/gtbag cat remove Alchemy = silverleaf` removes rules and `/gtbag cat delete Alchemy` deletes a group. Item level badges, Pawn and the Gatherer totals still use the built-in category.
- **Category editor**: right-click the **View** button (or `/gtbag cat edit`) to open a window where you make groups, add rules (part of a name, an item id, or shift-click an item into the box) and delete groups or single rules. The slash commands still work too.
- **Sell junk**: with a vendor window open, a **Sell junk** button appears at the bottom of the bag window (or use `/gtbag junk`). It sells only grey items. `/gtbag junk keep [item]` protects an item so it is never sold, `/gtbag junk unkeep [item]` removes the protection and `/gtbag junk list` shows the keep list.
- **Character nicknames**: every character has an optional nickname, empty by default. Type `/gtbag nick` to set the nickname of the character shown in the window (leave it empty to clear it). `/gtbag nick clear` removes the nickname of the character shown, and `/gtbag nick clear all` removes every nickname. The nickname replaces the character's name (still in class colour) in the selector list and on the header button. In the character selector, click **Scramble names** to scramble every name shown there and on the header button (`/gtbag scramble on|off` also works) and click **Show real names** to bring the real names and nicknames back. All of it is display-only: bags, bank, mail, guild bank and tooltip counts are not changed.

## New in 0.5.18

- **Compact window**: the character button now sits in the header after **Opt**. The footer is one line, with money on the left and free slots on the right; the bag value and *full in N min* lines are gone, so the window is shorter.
- **Bags show in combat**: with `/gtbag actions on`, a window opened during combat used to stay empty. It now draws your items with display buttons (clicks and drags return when combat ends).
- **No Blizzard bags in combat**: the game's own bag windows can't be hidden during combat, so GTBag makes them transparent and closes them when combat ends. A window that was already open keeps its live buttons.

## New in 0.5.13

- **One sort button, no menu**: the Sort button and the sort icon menu are gone. The sort icon sorts and merges in the fixed order Hearthstone > Mounts > Chronoboon Displacer > Potions > Buffs > Food > Gear > A-Z (on the Bank tab at the banker it sorts the bank).
- **Chronoboon Displacer added to the priority sort**: the order is now Hearthstone > Mounts > Chronoboon Displacer > Potions > Buffs > Food and drink > Gear > A-Z. `/gtbag tiers` now numbers the tiers 1 Hearthstone, 2 mount, 3 Chronoboon Displacer, 4 potion, 5 buff, 6 food, 7 gear, 8 other.

## New in 0.5.12

- **Buffs and food added to the priority sort**: the order is now Hearthstone > Mounts > Potions > Buffs (elixirs, flasks, scrolls, oils, stones) > Food and drink > Gear > A-Z. `/gtbag tiers` shows the tier of each item (1 Hearthstone, 2 mount, 3 potion, 4 buff, 5 food, 6 gear, 7 other).

## New in 0.5.11

- **Mounts and potions are found more reliably** in the Hearthstone > Mounts > Potions > Gear > A-Z sort: besides the item type, GTBag now also checks the tooltip (mounts) and the item name (potions), because Classic does not always file them under Mount / Potion. `/gtbag tiers` lists how each bag item is classified (1 Hearthstone, 2 mount, 3 potion, 4 gear, 5 other).

## New in 0.5.10

- **Hearthstone > Mounts > Potions > Gear > A-Z**: a new sort order, first entry in the sort icon menu and in the Sort menu (`/gtbag sort priority`), and the default for new installs. Order: Hearthstone, then mounts, then potions, then weapons and armor, each highest quality first (then A-Z); everything else A-Z by name, with the larger stack first for the same item. Poor-quality items still sort last.

## New in 0.5.9

- **Sort + Merge by name**: the sort icon now offers **Name (A-Z)** first. It sorts and merges the real items by name.
- **Auto sort turns itself off** when Sort + Merge finishes. The items are then physically in order, so the grid shows them as they are in your bags.

## New in 0.5.8

- **Item tooltips work on current Retail**: the *GTBag inventory* lines now use `TooltipDataProcessor`; older clients keep the previous hook.
- **No secure-button errors in combat**: with `/gtbag actions on`, window refreshes wait until combat ends.
- **Sort by number of items** now also orders stacks of the same item by size.
- **Sort + Merge keeps your Ignore empty slots setting** instead of switching it off.
- **Guild bank scan puts your open tab back** when it finishes.

## New in 0.5.7

- **Grid follows the chosen sort**: after Sort + Merge, auto sort stays on, so the grid shows Quality > Category or Number of items order instead of raw slot order.

## New in 0.5.6

- **Sort icon offers two orders**: Quality > Category, or **Number of items** (largest stacks first). The same order is in the Sort menu and `/gtbag sort count`.

## New in 0.5.5

- **Removed the header + and − buttons** (show or hide all containers). Use the **Slots** button instead; the search box now uses the space they took.

## New in 0.5.4

- **Header split into function buttons**, in one toolbar row under the header: **Sort** (sort order, auto sort, bank sort), **sort icon** (Sort + Merge), **Delete**, **Slots** (manage slots, hidden slots, ignore empty, containers), **Badges** (BoE, item level, Pawn, corners, priority), and **Filter** (one click switches hide / dim for search).

## New in 0.5.3

- **Sort + Merge moved to the sort icon**: click the sort icon beside the Sort button. It is no longer in the Sort menu.

## New in 0.5.2

- **Clearer docs**: item clicks and drags need `/gtbag actions on`, and the code comments say so.

## New in 0.5.1

- **Safe display by default**: the 0.5.0 item buttons were showing wrong icons for some items, so they are now off. Your bags display as in 0.4.3. Turn them on with `/gtbag actions on` to test click and drag, and `/gtbag actions off` to go back.

## New in 0.5.0

- **Items you can act on** (needs `/gtbag actions on`): items in your own bags and bank are now real item buttons. Click, right-click (use or equip; with a bank open, the game moves the item as it does in the default bags), shift-click to split, and drag to move an item to another slot or bag.
- **Alt + drag** reorders items in the category view. Plain drag moves the item.
- Items of other characters, guild banks and mail stay read-only.

## New in 0.4.3

- **No more flash of the default bags**: Blizzard's bag windows are hidden in the same frame they open, so they are never drawn.
- **Lower memory use**: item facts (vendor price, bind type, type names, classes) are cached, window refreshes from item-data events are combined into one, drag handlers are no longer rebuilt on every refresh, and tooltip counts are remembered until the data changes.

## New in 0.4.2

- **Drag-order cleanup**: saved drag positions for items that are gone (moved, sold, mailed or used up) are removed automatically. Forgetting a character removes its drag orders, and an upgrade clears orders left by unknown characters.

## New in 0.4.1

- **Compact window**: smaller slot buttons, tighter group spacing and a shorter footer, so more of the grid fits on screen.
- **All empty slots**: empty bag, bank and guild slots are shown in every view, including the guild **All** view. Use **Ignore empty slots** under the **Slots** button to hide them.

## New in 0.4.0

- **Cooldowns** on bag and bank items are drawn again. Saved, mail and guild items never show one.
- **BoE badge** hides once an item is bound (soulbound), so equipped BoE gear no longer shows BoE.
- **Tooltip ages**: every line of *GTBag inventory* shows how old its data is, for bags, bank, guild bank, mail, void storage and auctions. Live bag contents count as now.
- **Search by type**: the search box also matches item type and subtype (try `cloth`, `potion`, `plate`).
- **Low-bag warning**: a single chat line when free bag slots drop to the limit (default 5). It comes back once you have freed space. `/gtbag warn N` changes the limit; `/gtbag warn off` disables it.
- **Gatherer summary**: `/gtbag summary` prints herbs, ore and trade goods per character, with their value, and a total across all characters. It reads saved bag and bank data.

## New in 0.3.0

Tabs under the search box: **Inv, Bank, Mail, Guild**, in a second row under Del, Slots, Badges, Filter. The **Opt** button next to Sort in the header hides or shows both button rows; the window shrinks when they are hidden. The character button at the right switches the whole window to any character you have played.

- **Bank**: GTBag opens alongside the bank when you visit it, showing live contents. Away from the banker the Bank tab shows the last saved contents and age. Choose the character from anywhere to browse saved bank data.
- **Guild bank**: when visited, GTBag remembers accessible tabs; number buttons pick a tab and **All** combines them for search. The native guild-bank window remains available for withdrawals and deposits. Saved guild contents can be browsed from anywhere and while viewing another character.
- **Mail**: every item waiting in the mailbox, remembered from your last visit, with the days left (items under 3 days show a red number). Use Blizzard's mailbox to collect items. Mail you send to one of your other characters appears in their Mail tab straight away.
- **Character switching**: bags, bank, mail and guild bank of every character, class coloured; the border turns gold while you look at someone else. The selector shows each character's saved gold and the combined total; gold saved before this update is marked unknown until that character logs in again. Search, views and categories work the same. Data is saved as you play, so log each character in once (and visit their bank / mailbox / guild bank) to fill it. `/gtbag chars` lists what is saved, `/gtbag forget Name-Realm` removes a character.

Commands: `/gtbag`, `settings`, `bags`, `pin [item]|list|clear|mode`, `ammo N|off`, `privacy on|off`, `backup`, `junk auto on|off`, `view bag|category`, `sort type|quality|qualitycategory|expansion|itemlevel|name|value|category`, `autosort on|off`, `cols 8-15`, `scale 0.6-1.6`, `ilvl on|off`, `replace on|off`, `bank on|off`, `guild on|off`, `warn N|off`, `summary`, `chars`, `forget Name-Realm`, `reset`. Use `/gtbag replace off` to use Blizzard's bags instead.

Not in this version: Warband / account bank, bank slot purchase, guild bank log and tab management, selling or auction functions.
