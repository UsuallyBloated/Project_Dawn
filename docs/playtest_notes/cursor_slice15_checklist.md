# Cursor Slot, Slice 1.5 Playtest Checklist — 2026-08-28

The feedback batch from the slice 1 run, plus the death-dupe retest. One system for every
pickup now: online, **every** lift goes through the real cursor, whatever the source.

**Build prerequisite: server `22837b9` (unequip-to-hand) + a fresh client export.** No protocol
bump this time, so the order does not matter and old clients still connect — but the
unequip-to-hand row needs both halves.

---

## 1 — The death dupe is dead (the retest)

- [x] **Die while holding an item** → after respawn your hand is EMPTY, the item is on the
      corpse (once), and looting the corpse returns exactly one copy. notes:

## 2 — Every pickup rides the cursor

- [x] **Left-click an item in your main inventory** → it lifts onto the cursor (name rides the
      mouse), exactly like a ground pickup — no more invisible drag. notes:
- [x] **Left-click an item inside a bag** → same. notes:
- [x] **Left-click a WORN item on the paperdoll with an empty hand** → it lifts off the doll
      onto your cursor. notes:
- [x] **Try that with a full hand** → "You're already holding something." (the worn item
      stays put). Then click the doll slot with the held item to equip-from-hand instead —
      the swap pops the worn piece onto your cursor. notes: "You're already holding something" properly displays but somethinb breaks with the item on the cursor.  The item stops displaying, then the only way to put the item down is to swap it with another item in the inventory.
      [DIAGNOSED + FIXED 2026-09-09: the EquipItem handler's delta fan knew base/equip/bag but
      not "cursor", so an equip-from-hand SWAP fanned an EMPTY cursor delta — the client's hand
      went blank while the server still held the swapped-out item, and the later "already
      holding" refusal was the desync's symptom, not its cause. The lift-click recovery worked
      because the server resolved it as a swap and fanned true deltas. All five hand-rolled
      delta readers now go through peek_at (three more were latent versions of the same bug:
      partial drop / partial destroy from the hand would have zeroed the client's remainder,
      and eat-from-hand was refused at the peek). Server-only; RETEST after redeploy.]
- [x] **Place, merge, swap from any of those lifts** → identical behavior to the ground-pickup
      run (empty moves, same item merges capped, different item swaps). notes:
- [x] **A non-empty bag still refuses to lift** ("Empty the bag before moving it."). notes:  We plan on changing this, correct?
      [Answered 2026-09-09: it was not planned — the rule exists because a bag's contents are
      keyed to the bag's slot server-side, so moving a full bag means re-keying its contents.
      EQ lets you move full bags, so the ask is legitimate; now recorded as its own design
      item ("Full bags should move with their contents"), discuss-first.]

## 3 — Dropping is clicking the world

- [x] **The Drop cell is gone** from the inventory window; only Trash remains. notes:
- [x] **Hold an item, click the ground** → "Drop X on the ground?" confirm; accept → sack
      appears, hand empties. Works with EVERY window closed. notes:
- [x] **Hold an item, click the sky** → same confirm. notes:
- [x] **Cancel the confirm** → the item stays in hand. notes:  This is having a problem because when a player clicks on the drop window, the click passes through  to the world and the player is instantly prompted to drop the item again.  Clicks pass through the window.
      [DIAGNOSED + FIXED 2026-09-09: the confirm dialogs are native popup Windows, invisible to
      the main viewport's hovered-control check, and player.gd polls hardware button state — so
      the click answering the dialog also registered as a world tap and re-opened the prompt.
      Fix: the dialogs report their closes to Inventory, and request_ground_drop ignores taps
      inside a 400 ms echo window (covers the cancelled-DELETE case too). Client-only; RETEST
      after re-export.]
- [x] **Hold an item, click an enemy / NPC / another player** → it TARGETS them, no drop
      prompt. (The trade window on entity-click is its own future system.) notes:

## 4 — Left-click targets corpses and fuller bags

- [x] **Left-click a kill-loot corpse** (has coin or several items) → it becomes your target,
      named "<creature>'s corpse" in the target frame, no hp bar. Right-click still loots.
      notes:
- [x] **Target a corpse, then press F1 (self-target) and retarget something else** → no
      errors in the backtick console (the old "Nonexistent signal" noise is what this checks).
      notes:
- [x] **Left-click a lone dropped sack** → still the pickup, as in slice 1. notes:

---

## Result

- Server build (boot line): 22837b9, dev_cmds=false
- Client build (`/version`): 7400081-dirty, exported 2026-08-28T21:20 UTC, gdext 127646ee
- Overall: PASS, all 14 rows marked by the tester (marks recovered 2026-09-09 after an
  unsaved-tab delay; the 08-28 server log independently corroborates the lifts, the worn-item
  lift, the cursor-occupied refusal, the world drops, and a capped 8+7=15 merge). The §1
  death-dupe retest passed on the fixed build. §4's F1-retarget row passed with a clean
  console, ticking the long-standing hud.gd guard item. Three findings from the notes, all
  actioned 2026-09-09: the equip-from-hand cursor-delta desync (server, FIXED, retest), the
  drop-confirm click pass-through (client, FIXED, retest), and movable-full-bags recorded as a
  design item. The "You target @Area3D" cosmetic was fixed 08-28 (`c3d4eed`).
