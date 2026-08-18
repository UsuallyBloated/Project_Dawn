# Bag Click Grammar Playtest Checklist — 2026-08-17

Verifies that bags follow the interaction grammar: **left-click lifts, right-click opens**
(`docs/design/inventory_interaction_grammar.md` §3, lines 51 and 55). Repro was
`banker_slice2_checklist.md:57`.

**Build prerequisite: re-export the client only.** No server change, no R720 restart, no gdext
rebuild.

**What was wrong.** `inventory_window.gd` called `_toggle_bag()` from the **left**-click path as
well as the right-click one, so *both* buttons opened a bag and a bag could never be picked up or
rearranged at all. The tester's original guess was that these were stale pre-grammar bag items;
it was not the item data, it was a code branch. Left-click now begins a drag like any other
non-stackable, and right-click still opens.

**Two consequences of bags becoming movable for the first time**, both handled and both worth
testing:
- The server refuses to move a **non-empty** bag (`bag must be emptied before moving`,
  `world/inventory.rs`). The client now mirrors that rule up front with a chat line, so it is an
  explained refusal rather than a silent snap-back.
- Bag windows are keyed by **base slot index**, so a window could outlive the bag that opened it.
  Orphaned windows are now closed on refresh.

Diagnostics: in-game console (backtick) for client errors; `server.log` for `MoveItem` handling.

---

## 1 — The grammar itself

- [x] **Left-click an EMPTY bag in your inventory** → it lifts onto the cursor. It does **not**
      open. notes: Works as intended.  I would like to remove the number that indicates the number of slots the bag has.  Does this make sense?
- [x] **Right-click that bag** → its window opens. Right-click again → it closes. notes:
- [x] **Left-click a normal item (weapon/armor)** → still lifts onto the cursor as before. notes:
- [x] **Right-click a normal item** → still equips/uses it as before. notes:

## 2 — Moving a bag (new capability)

- [x] **Left-click an empty bag, drop it on an empty base slot** → the bag moves there. notes:
- [x] **Right-click the bag in its new slot** → it opens, and shows its own (empty) slots, not
      another bag's. notes:
- [x] **Put an item in a bag, then left-click that bag** → refused with
      "Empty the bag before moving it." in chat, and the bag stays put. notes:
- [x] **Empty that bag again, then left-click it** → now it lifts normally. notes:

## 3 — The orphaned-window case

- [x] **Open a bag's window, leave it open, then move that (empty) bag to a different base slot**
      → the old window closes rather than lingering over an empty slot. notes:
- [x] **Right-click the bag in its new slot** → a window opens showing the correct bag. notes:

## 4 — Regression: nothing else about inventory changed

- [x] **Drag an item from a bag to your base inventory and back** → unchanged. notes:
- [x] **With the BANK open, right-click a normal item in your bags** → still deposits (the
      quick-transfer grammar), rather than equipping it. notes:
- [x] **With the BANK open, right-click a bag** → still rejected with "Bags can't go in the bank
      vault." notes:
- [x] **Log out and back in** → bags are where you left them, with their contents. notes:

---

## Result
notes:
From time to time items seem to get hung up.  Some seem to stick to the cursor while others will stick in the slot.  Some times it appears as thought there is an item stuck on the cursor then right clicking on the bag wont open the bag, but i also cant place the item that might be attached to the cursor. I'm not sure what is going on.  Water Flasks vanished from the inventory then reappeared after i placed the stack of bread loaf on top of what appeared to be an empty slot, then removed the bread loaf and revealed the water flask that had previously vanished.  Are you able to tell from the log what might be happening?

- Client build: `c3ef9f4-dirty`, exported 2026-08-18T15:45:29 UTC, gdext `5918f106`.
- Overall: **PASS — all 14 rows.** The grammar, the new bag-move capability, the non-empty
  refusal, the orphaned-window case and every regression row behave as intended.

### Two things came out of the notes

**1. The slot-count number on bag cells is gone** (requested on §1 row 1). It was a static
capacity badge stamped on every bag cell; the tooltip already reports "N slot bag", so the number
was permanent clutter. Widget removed, not just blanked.

**2. The "items get hung up" report is a real, SEPARATE, pre-existing bug** — an inventory
client/server desync, now tracked in its own To-Do item. It is NOT caused by the bag fix and it is
NOT item loss. Summary of what the attached server log proves:

- Dozens of `MoveItem rejected ... error=source slot empty` across 16:03 to 16:33, repeatedly on
  the same base slots (1, 2, 4, 5). The client believed those slots held items; the server knew
  they were empty.
- The server was correct the whole time. Nothing was lost, and the relog at 16:37 resynced
  everything, after which moves succeeded normally again.
- Both halves of the mechanism are pre-existing (dated 2026-05-19 and 2026-05-22, three months
  before the bag change): the server sends **nothing** on a rejected move, and the client
  **silently discards** a `bag_<i>` delta when it thinks that slot is not a bag. Neither side can
  correct the other, so a divergence is permanent until relog.
- The bag fix did not cause it; it made bags draggable, and this checklist then exercised dragging
  far harder than any previous session, which is what surfaced it.
