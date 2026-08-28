# Cursor Slot, Slice 1.5 Playtest Checklist — 2026-08-28

The feedback batch from the slice 1 run, plus the death-dupe retest. One system for every
pickup now: online, **every** lift goes through the real cursor, whatever the source.

**Build prerequisite: server `22837b9` (unequip-to-hand) + a fresh client export.** No protocol
bump this time, so the order does not matter and old clients still connect — but the
unequip-to-hand row needs both halves.

---

## 1 — The death dupe is dead (the retest)

- [ ] **Die while holding an item** → after respawn your hand is EMPTY, the item is on the
      corpse (once), and looting the corpse returns exactly one copy. notes:

## 2 — Every pickup rides the cursor

- [ ] **Left-click an item in your main inventory** → it lifts onto the cursor (name rides the
      mouse), exactly like a ground pickup — no more invisible drag. notes:
- [ ] **Left-click an item inside a bag** → same. notes:
- [ ] **Left-click a WORN item on the paperdoll with an empty hand** → it lifts off the doll
      onto your cursor. notes:
- [ ] **Try that with a full hand** → "You're already holding something." (the worn item
      stays put). Then click the doll slot with the held item to equip-from-hand instead —
      the swap pops the worn piece onto your cursor. notes:
- [ ] **Place, merge, swap from any of those lifts** → identical behavior to the ground-pickup
      run (empty moves, same item merges capped, different item swaps). notes:
- [ ] **A non-empty bag still refuses to lift** ("Empty the bag before moving it."). notes:

## 3 — Dropping is clicking the world

- [ ] **The Drop cell is gone** from the inventory window; only Trash remains. notes:
- [ ] **Hold an item, click the ground** → "Drop X on the ground?" confirm; accept → sack
      appears, hand empties. Works with EVERY window closed. notes:
- [ ] **Hold an item, click the sky** → same confirm. notes:
- [ ] **Cancel the confirm** → the item stays in hand. notes:
- [ ] **Hold an item, click an enemy / NPC / another player** → it TARGETS them, no drop
      prompt. (The trade window on entity-click is its own future system.) notes:

## 4 — Left-click targets corpses and fuller bags

- [ ] **Left-click a kill-loot corpse** (has coin or several items) → it becomes your target,
      named "<creature>'s corpse" in the target frame, no hp bar. Right-click still loots.
      notes:
- [ ] **Target a corpse, then press F1 (self-target) and retarget something else** → no
      errors in the backtick console (the old "Nonexistent signal" noise is what this checks).
      notes:
- [ ] **Left-click a lone dropped sack** → still the pickup, as in slice 1. notes:

---

## Result

- Server build (boot line):
- Client build (`/version`):
- Overall:
