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

- [ ] **Drop an item from your bags** (drag out to the world, confirm) → a golden sack appears.
      **Left-click the sack** → chat says "You pick up <item>.", the item's name rides your
      mouse, the sack is gone. notes:
- [ ] **Left-click a kill-loot corpse/bag that has coin or several items** → "There's more than
      one thing there. Right-click to loot." — and right-click looting still works exactly as
      before. notes:
- [ ] **Left-click a ground item while already holding one** → "You're already holding
      something." notes:
- [ ] **From out of range** → "You are too far away.", nothing taken. notes:

## 2 — Placing (the moves law)

- [ ] **Click an empty inventory or bag slot** → the item lands there; your hand empties.
      notes:
- [ ] **Click a slot holding the SAME item** (partial stack) → they merge; if the stack caps,
      the overflow stays in your hand. notes:
- [ ] **Click a slot holding a DIFFERENT item** → they swap: the slot's item is now on your
      cursor. notes:
- [ ] **Click a paperdoll slot with an equippable item held** → it equips straight from the
      hand; if something was already worn there, the old piece pops onto your cursor (classic
      EQ). notes:

## 3 — The held item follows the rules

- [ ] **ESC, closing windows, opening other windows** → the item STAYS in hand (deliberate: no
      accidental toss; you place it, drop it, or trash it). notes:
- [ ] **Click the Drop cell while holding** → confirm dialog → the item lands on the ground as
      a sack. (This is the full-bags escape hatch.) notes:
- [ ] **Click the Trash cell while holding** → confirm dialog → destroyed. notes:
- [ ] **Log out with an item in hand, log back in** → it is still in your hand. notes:
- [ ] **Weight**: encumbrance includes the held item (grab something heavy and watch the
      number). notes:

## 4 — Death does not shelter it

- [ ] **Die while holding an item** → it strips to your corpse with everything else; corpse-run
      and loot it back. Holding something must never dodge the death penalty. notes:

## 5 — Group rules survive the shortcut (needs the second seat)

- [ ] **On a group kill bag assigned to your partner (round robin)**, your left-click pickup is
      refused: "Not your turn to loot." — the shortcut can't dodge the rotation. notes:

---

## Result

- Server build (boot line):
- Client build (`/version`):
- Overall:
