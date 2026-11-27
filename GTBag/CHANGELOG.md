# GTBag

## 0.26.0 (2026-11-27)

- Change: the Auction tab is removed from the tab row (Inv / Bank / Mail / Guild). Saved auction listings still count in item tooltips and in search.
- Clean-up: removed the auction view code and a few unused helpers. The other tabs are unchanged.

## 0.25.4 (2026-11-25)

- New: the sort icon opens a menu (Priority, Name, Quality > Category, Number of items) and merges the bags.
- Change: default order is Hearthstone > Mounts > Buffs > Food > Potions > Gear > A-Z, junk last; sorting is faster.
- Fix: no duplicate character in the list (existing twins are merged).
- Fix: sorting and bag routing handle bag families, late bag events, mail attachments and guild-tab restore; hidden arrow, ammo and quiver bags stay hidden.
- Fix: sessions and history are kept per character and Hardcore mode; Blizzard frame names refresh when the privacy salt changes.

## 0.25.3 (2026-11-23)

- New: one-window bag browser (`B` or `/gtbag`) with icon grid, search, category and bag-slot views, five styles.
- New: bank, guild bank, mail and all characters' bags, with saved data; tooltips with counts across characters.
- New: sorting and merging, pinned and hidden items, custom categories, sell junk, privacy mode, backup and restore, `GTBagAPI`.
- New: works with GatherTimes and on its own.
