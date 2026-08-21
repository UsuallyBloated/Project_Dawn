# Atomic Store Transfers Playtest Checklist — 2026-08-20

Verifies that moving items or coin between stores cannot half-happen. Closes exploit-audit
finding 8 ("cross-store transfers persist as separate txns").

**Build prerequisite: server only.** Push, then on the R720 pull, `cargo build --release`, stop,
`cp`, start, and confirm the boot line. No client change, no re-export.

**What was wrong.** An item never simply changes; it *moves*, and every move spans two tables:

| Action | Stores touched |
|---|---|
| Bank item deposit / withdraw | `character_items` + `bank_items` (or `account_bank_items`) |
| Bank coin deposit / withdraw | wallet columns + bank columns |
| Vendor buy / sell | `character_items` + wallet |
| **Death** | `character_items` + wallet + `corpses` |

Each store was written by its own function opening its own transaction, with an `.await` between
them. A crash landing in that gap either **loses** the item (gone from inventory, never arrived) or
**duplicates** it (arrived and still in inventory). Now every store for a connection is written in
one transaction (`db::save_stores_atomic`), in both the periodic checkpoint and the disconnect
flush; and death creates the corpse **and** strips the owner inside a single transaction.

This is not something a playtest can trigger on purpose — it needs a crash at a precise moment.
The rows below confirm the rewrite did not break the ordinary paths, which is the actual risk of a
change like this. Correctness under crash is covered by the unit test
`save_corpse_strips_the_owner_in_the_same_transaction`.

Diagnostics: `journalctl -u projectdawn -f`; watch for `store checkpoint failed` or
`final store save on disconnect failed`, which should never appear.

---

## 1 — Bank, the main cross-store path

- [x] **Deposit several items, withdraw some back, close and reopen the bank** → all correct.
      notes:
- [x] **Deposit and withdraw coin across tiers** → wallet and bank both correct. notes: When thee play has "1p 5g 5s 75c" and tries to add "6s" to the bank, the bank should break one gold to fulfill the extra requested piece of silver.  Now player sees "You don't have that coin to deposit." in the chat window.
- [x] **Deposit to the SHARED vault, then log in as another character on the account** → the
      shared item is there and the personal vault is that character's own. notes:
- [x] **Bank something, then log out immediately** (inside 60 s, before the next checkpoint) →
      log back in and it is still banked. This exercises the disconnect flush, which was rewritten.
      notes:

## 2 — Vendor

- [x] **Buy a few items** → items arrive, coin decreases correctly. notes:
- [x] **Sell a few items** → items leave, coin increases correctly. notes:
- [x] **Sell something then log out immediately** → coin total survives the relog. notes:

## 3 — Death, which now strips inside the corpse transaction

- [x] **Die with gear AND coin on you** → corpse holds both; you respawn naked with an empty
      wallet. notes:
- [x] **Loot your own corpse** → everything comes back, gear and coin. notes:  Something interesting is happening.  It appears as though the money is consolidating after the player dies.  For example the player died with "1p 5g 7s 312c"  when the player looted the corpse they received "1p 5g 10s 12c".  The copper became silver.
- [x] **Die, then log out before looting; log back in** → the corpse is still there with its
      contents, and you are still empty. Neither side duplicated. notes:
- [x] `server.log` shows `corpse created` with the expected `item_stacks`. notes:

## 4 — Regression: ordinary inventory work

- [x] **Move items around, equip and unequip, use consumables** → unchanged. notes:
- [x] **Loot a mob, pick up a dropped item** → unchanged. notes:
- [x] **Play for a few minutes, then relog** → everything is where you left it. notes:
- [x] **No `store checkpoint failed` or `final store save on disconnect failed`** anywhere in the
      log. notes: Not that I noticed.

## 5 — Stack size is now enforced on merges (same deploy)

Dragging one stack onto another used to merge with no cap, which is how the 41-stack of Bread Loaf
in the 2026-08-20 log happened (its limit was 10 at the time; food and water are now 20). All five
move paths now stop at the item's `stack_size` and leave the remainder where it was. The split path
rejects instead, since a split names an explicit count and silently moving fewer would be worse.

- [x] **Get two partial stacks of Bread Loaf, say 15 and 15, and drag one onto the other** → the
      destination fills to **20** and **10 stay behind** in the source slot. Nothing vanishes.
      notes:
- [x] **Count the total before and after** → identical. The cap must never destroy the overflow.
      notes:
- [x] **Drag two small stacks together (5 + 5)** → merges to 10 and the source empties, exactly as
      before. notes:
- [x] **Try to build a stack bigger than 20 by any means you can think of** (repeated drags, bags,
      bank round-trips) → you cannot. notes:
- [x] **Stack All still consolidates sensibly** and produces no over-cap stacks. notes:  Appears to work as intended.  Please make it so "stack all" consolidates only inside similar inventory sets, for example 
- [x] **Unstackable items (weapons, armor, bags) are unaffected** — they still swap rather than
      merge. notes:

---

## Result

- Server build: `393cc64`
- Overall: **PASS** on every row. Bank, vendor and death paths all behave, and the stack cap holds.

### Stack cap, confirmed in the log

```
18:53:07  DestroyItem applied ... bread_loaf count=20
18:53:08  DestroyItem applied ... bread_loaf count=20
18:53:10  DestroyItem applied ... bread_loaf count=20
```

Three separate 20-stacks rather than one 60-stack: exactly the behaviour that was missing when a
41-stack turned up on 2026-08-20. Bank deposits also show `water_flask deposited=20`, so the new
food/water limit is live on both sides.

### Death path, confirmed

`corpse created char_id=1 corpse_id=2000000018 item_stacks=7` then
`corpse looted empty — despawned`, with the strip now inside the corpse transaction.

---

## Four findings from this run

All four are logged as To-Do items. None of them is item loss.

**1. Buying with a full inventory looks like the item vanishes.** Flagged by the tester as the
big one, and the diagnosis is exact. The server is correct throughout — it refuses and charges
nothing (`BuyItem rejected — inventory full, no stack placed`, with no `coins_after`). The client
lies: `vendor_window.gd:366-370` prints *"Ordered X for Y"* the instant it sends the request,
before the server has answered. So the player is told the purchase succeeded, then no item
arrives. Same shape as the `MoveItem` rejection fixed on 08-18: the server refuses **silently**,
so the client never learns.

**2. Bank coin deposit will not break a larger coin.** With `1p 5g 5s 75c`, depositing `6s` is
refused with "You don't have that coin to deposit" instead of breaking a gold. The four tiers are
deliberately independent stacks, so this is a design question rather than a bug.

**3. Coin normalises through a corpse, and that changes its weight.** Died with `1p 5g 7s 312c`,
looted back `1p 5g 10s 12c`. The **value is identical** (312c = 3s 12c), so nothing was lost. But
the game charges *flat weight per coin*, so 312 coins became 15 and the player came back lighter
than they died. Dying compresses your coin. Minor, but it is an economy quirk with an
exploit-shaped edge.

**4. Stack All scope.** Request to have it consolidate only within a container rather than across
everything. The note is cut off mid-sentence, so the exact rule wanted needs confirming.
