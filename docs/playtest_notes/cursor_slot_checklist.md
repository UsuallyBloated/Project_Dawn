# Cursor Slot (Slice 1) Playtest Checklist — 2026-08-27

The EQ-style held item: left-click a lone ground item and it rides your mouse until placed.
Design: `docs/design/cursor_slot_and_reequip.md`. Slice 2 (corpse auto-re-equip) comes after
this passes.

**Build prerequisite: BOTH sides move together (protocol PD_W0027).** Server `73074a8` on the
R720 AND a fresh client export. An old client cannot connect to the new server (version gate),
so restart the R720 and hand out the new export as one step. The gdext DLL is already updated
in the working tree; a normal re-export carries it.

**The grammar, so nobody trips:** corpses (yours and monsters') are still right-click to loot.
Kill-loot bags with coin or several items are still right-click. LEFT-click is only for a lone
item sitting on the ground — a dropped item's golden sack.

---

## 1 — Ground pickup

- [x] **Drop an item from your bags** (drag out to the world, confirm) → a golden sack appears.
      **Left-click the sack** → chat says "You pick up <item>.", the item's name rides your
      mouse, the sack is gone. notes:
- [x] **Left-click a kill-loot corpse/bag that has coin or several items** → "There's more than
      one thing there. Right-click to loot." — and right-click looting still works exactly as
      before. notes:  Left-click needs to target the corpse.  This mechanic is for resurrection purposes.  Does this make sense?
- [x] **Left-click a ground item while already holding one** → "You're already holding
      something." notes:
- [x] **From out of range** → "You are too far away.", nothing taken. notes:

## 2 — Placing (the moves law)

- [x] **Click an empty inventory or bag slot** → the item lands there; your hand empties.
      notes:
- [x] **Click a slot holding the SAME item** (partial stack) → they merge; if the stack caps,
      the overflow stays in your hand. notes:
- [x] **Click a slot holding a DIFFERENT item** → they swap: the slot's item is now on your
      cursor. notes:
- [x] **Click a paperdoll slot with an equippable item held** → it equips straight from the
      hand; if something was already worn there, the old piece pops onto your cursor (classic
      EQ). notes:  We currently cannot left click an item that is already on the paperdoll.  Lets talk about this.

## 3 — The held item follows the rules

- [x] **ESC, closing windows, opening other windows** → the item STAYS in hand (deliberate: no
      accidental toss; you place it, drop it, or trash it). notes:
- [x] **Click the Drop cell while holding** → confirm dialog → the item lands on the ground as
      a sack. (This is the full-bags escape hatch.) notes:  This works.  Right now a player cant put the carried item back on the ground unless they click the "drop" button in the inventory.  I would like to get rid of the drop button completely because a player should click the environment whent hey want to drop an item on the ground.  this is more intuative and will clean up the UI a little.  Please let me know if this doesnt make sense.
- [x] **Click the Trash cell while holding** → confirm dialog → destroyed. notes:
- [x] **Log out with an item in hand, log back in** → it is still in your hand. notes:
- [x] **Weight**: encumbrance includes the held item (grab something heavy and watch the
      number). notes:

## 4 — Death does not shelter it

- [x] **Die while holding an item** → it strips to your corpse with everything else; corpse-run
      and loot it back. Holding something must never dodge the death penalty. notes:  Not currently working as intended: Item stays attached to player's cursor after respawn.  This is also duplicating the item that is held.
      [DIAGNOSED + FIXED 2026-08-28, server `f8c609b`: the DB strip was correct, but the
      in-memory `clear_all()` predated the cursor — it cleared base/equipment/bags and left
      the hand full, so the post-death snapshot re-sent the held item while the corpse
      already carried the copy. One line + a regression test that runs the exact death
      sequence. Server-only redeploy; RETEST this row after it.]

## 5 — Group rules survive the shortcut (needs the second seat)

- [x] **On a group kill bag assigned to your partner (round robin)**, your left-click pickup is
      refused: "Not your turn to loot." — the shortcut can't dodge the rotation. notes:

---

## Result
-  Is the item that is attached to the Player's cursor being held by the player or by the world?
-  Items picked up from the ground now stick to the cursor, Please make it so every time a player picks up an item, regardless of where it is coming from, the item attaches to the cursor.  Please tell me if this is unclear.  


- Server build (boot line): 73074a8 (dupe fix `f8c609b` pending redeploy)
- Client build (`/version`): f538b54-dirty, exported 2026-08-27T23:40 UTC, gdext 127646ee
- Overall: PASS on 13 of 14 rows including the full moves law, persistence, weight, and the
  round-robin refusal. One CRITICAL find: §4's death dupe (fixed same morning, `f8c609b`,
  retest after redeploy). Four design follow-ups from the notes, queued as slice 1.5:
  left-click targets corpse-bags, unequip-to-hand from the paperdoll, click-the-world to
  drop (Drop cell removed), and ALL pickups attaching to the cursor regardless of source.
