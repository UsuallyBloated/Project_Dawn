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

- [ ] **Left-click an EMPTY bag in your inventory** → it lifts onto the cursor. It does **not**
      open. notes:
- [ ] **Right-click that bag** → its window opens. Right-click again → it closes. notes:
- [ ] **Left-click a normal item (weapon/armor)** → still lifts onto the cursor as before. notes:
- [ ] **Right-click a normal item** → still equips/uses it as before. notes:

## 2 — Moving a bag (new capability)

- [ ] **Left-click an empty bag, drop it on an empty base slot** → the bag moves there. notes:
- [ ] **Right-click the bag in its new slot** → it opens, and shows its own (empty) slots, not
      another bag's. notes:
- [ ] **Put an item in a bag, then left-click that bag** → refused with
      "Empty the bag before moving it." in chat, and the bag stays put. notes:
- [ ] **Empty that bag again, then left-click it** → now it lifts normally. notes:

## 3 — The orphaned-window case

- [ ] **Open a bag's window, leave it open, then move that (empty) bag to a different base slot**
      → the old window closes rather than lingering over an empty slot. notes:
- [ ] **Right-click the bag in its new slot** → a window opens showing the correct bag. notes:

## 4 — Regression: nothing else about inventory changed

- [ ] **Drag an item from a bag to your base inventory and back** → unchanged. notes:
- [ ] **With the BANK open, right-click a normal item in your bags** → still deposits (the
      quick-transfer grammar), rather than equipping it. notes:
- [ ] **With the BANK open, right-click a bag** → still rejected with "Bags can't go in the bank
      vault." notes:
- [ ] **Log out and back in** → bags are where you left them, with their contents. notes:

---

## Result

- Client build (`/version` or the login-screen footer):
- Overall:
