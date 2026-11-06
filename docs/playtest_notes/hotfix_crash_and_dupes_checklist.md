# Hotfix: Chat Crash, Dupe Windows, Vendor Stock Playtest Checklist — 2026-10-23

The server-only hotfix from the 2026-10-23 housekeeping audit (Phase 0): a chat line that
crashed the server, three ways an item could end up in two places after a crash or restart,
a failed login load that could wipe a character's stores, and vendors that sold any priced
item. **Prerequisite: the R720 redeployed to the hotfix build** (`fix/xp-leveling-overflow`
at `3d938ca` or later; boot line shows `dev_cmds=false` and the new `build=`). No client
export needed: the testers' current build works.

| Fix | What used to happen | What should happen now |
|---|---|---|
| Chat cut | A 512+ byte line with an accented letter at the cut crashed the server | The line is cut cleanly; the server keeps running |
| Drop | Dropped item saved only at the 60 s checkpoint | The drop is saved at once; the picker is saved at once |
| Immediate saves | A quest reward, death, corpse loot or trade could save the bags while a bank withdrawal sat unsaved | Every store is saved together |
| Login load | A failed read played on with empty bags and wiped them at the next save | The login is refused with "The server could not load your character." |
| Vendor stock | Any priced item (named drops too) sold at any vendor | Only what a vendor in reach stocks |

Diagnostics: `server.log` anchors are `DropItem spawned loot bag`, `BuyItem applied` (now
names `seller` and `vendor_type`), `BuyItem rejected — no merchant in reach stocks it`,
`quest completed`, `corpse created`. Any `panicked at` line in the journal is a fail.

## Setup
- [x] R720 redeployed (stop, copy, start), boot line checked: `dev_cmds=false` and the new
  `build=` sha. notes:
- [x] Two players online in town, near each other. notes:

## 1 — The chat crash is gone
- [x] **Paste a long line into /say: about 520 characters with an accented letter (é, ü)
  near the end** → it shows cut short; the server keeps running; both players can still chat
  and move. notes:
- [x] **Check the journal** (`journalctl -u projectdawn -n 50 --no-pager`) → no `panicked at`
  line and no restart. notes:

## 2 — Drops cannot be duplicated across a restart
- [x] **Player A drops a stack; player B picks it up** → B holds it, A does not. notes:
- [x] **Within a minute, restart the server** (`sudo systemctl restart projectdawn`; warn
  both players first) → after both log back in, the item is with B only, not with both.
  notes:
- [x] **A drops a stack and picks it straight back up, then restart within a minute** → A
  still has it after the restart (it is not lost). notes:

## 3 — Saves move items together
> **2026-10-26:** items go into the vault by **right-clicking them in your bags with the bank
> window open**; dragging onto the vault does nothing yet (its own To-Do entry).
>
> **How §3 was proven (2026-10-26).** Since Phase 1, a `systemctl restart` saves everyone
> before it closes, so a restart can no longer show this fix. It was shown with a hard kill
> instead: Fresh Wolf Pelt withdrawn at 16:20:53, `restless_bones` turned in at 16:20:59
> (Leather Cap), `sudo systemctl kill -s KILL projectdawn` at 16:21:14, with the last 60 s
> checkpoint at 16:20:38 (the timer starts at boot). After the relog the pelt was in the bags
> and not in the vault, and the Leather Cap was held: the quest reward's save wrote every
> store together. Nothing else could have saved them.

- [x] **Withdraw an item from the banker, then turn in a quest that pays an item, then
  restart within a minute** → the withdrawn item is in the bags and not back in the vault.
  notes:  Players cannot place items in the bank. (Dragged onto the vault, which is not built; right-click deposits.)
- [x] **Withdraw an item from the banker, die (any way), restart within a minute** → the
  item is on the corpse and not back in the vault. notes:

## 4 — Vendor stock
- [x] **Buy bread from Brom, a sword from Hadrik, a potion from Elara** → each sells as
  before. notes:
- [x] **Buy every item on Brom's list once** (the full Provisioner stock) → each one sells;
  a `BuyItem rejected — no merchant in reach stocks it` line for any of them means the two
  stock lists disagree (run `tools/check_vendor_lockstep.gd`). notes:

> The refusal itself (an unstocked item such as a named drop) is reachable only by a
> modified client, since the vendor window lists nothing else. The integration test
> `a_priced_item_no_merchant_stocks_cannot_be_bought` is its evidence.

## 5 — Regression: ordinary play unchanged
- [x] **Loot several kills, drop and pick up items, bank and withdraw, buy and sell** → no
  refusals, no lag spikes, nothing vanishes. notes: The bank is not allowing the players to deposit items.  I also feel like there is a slight lag, but i could be crazy.
- [x] **Log out and back in** → bags, bank and coins exactly as left. notes:

## Notes / observations

-  Game crashed while i was moving items around the inventory.
-  We need to take a look at the Item Log that Monsters and Memories uses.  

-  Clicking on the bank UI window I'm pretty sure the clicks are going THROUGH the window and effecting the windows/interface below the bank window.  Does this make sense?
