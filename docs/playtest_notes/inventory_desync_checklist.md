# Inventory Desync Recovery Playtest Checklist — 2026-08-18

Verifies that the client and server can no longer disagree about inventory indefinitely. Found
2026-08-18 during the bag playtest (`bag_click_grammar_checklist.md`), where items appeared to
stick to the cursor or vanish outright, and the server log showed the same slots refused for half
an hour with no recovery short of a relog.

**Build prerequisite: BOTH.** This is a server change *and* a client change.

1. Push, then on the R720: `git pull && cargo build --release`, `cp` the binary, restart, and
   confirm `dev_cmds=false` on the boot line.
2. Re-export the client and run the new build (check `/version`).

Running only one half is a valid but partial test: the server half alone still fixes recovery,
and the client half alone still stops updates being thrown away.

**What changed.** Two independent "drop it silently" faults, both dating to May 2026, that
compounded so neither side could correct the other:

| Side | Was | Now |
|---|---|---|
| Server (`world/tick.rs`) | a rejected or no-op `MoveItem` logged and returned, sending the client nothing | answers with the true contents of **both** named slots, so a wrong client self-corrects on its next mistake |
| Client (`autoloads/inventory.gd`) | a `bag_<i>` delta was discarded when the client thought that slot held no bag, or when the slot index exceeded its array, trusting a "next snapshot" that only happens at enter-world | makes room and applies it, and logs a warning, since needing that means the view was already stale |

Diagnostics: `journalctl -u projectdawn -f` for `MoveItem rejected`; the in-game console
(backtick) for the new `Inventory: bag_N ...` warnings.

---

## 1 — Normal use is unchanged

- [x] **Move items around your bags and base slots freely for a minute or two** → everything
      behaves as before, no visible change. notes:
- [x] **Right-click to equip, use a consumable, open and close bags** → unchanged. notes:
- [x] **Deposit and withdraw at the bank** → unchanged. notes:

## 2 — The recovery itself (the point of this change)

Repeat what triggered it last time: a long, fast session of dragging items in and out of bags,
including moving bags themselves. The aim is to provoke at least one `MoveItem rejected` line.

- [x] **Drag heavily for several minutes, then check the server log for `MoveItem rejected`** →
      some may appear, which is fine and expected. notes:
- [x] **For any slot that got rejected, look at whether it is rejected again and again** → it
      should NOT repeat indefinitely on the same slot. One rejection, then the client corrects
      itself and stops asking. Repeated identical rejections over minutes = not fixed. notes:
- [x] **After any rejection, does the UI agree with reality?** → the slot the server called empty
      should now render empty on your screen, without a relog. notes:

## 3 — The symptoms that started this

- [x] **Does any item appear to vanish and stay vanished?** → no. If one does, note the item and
      the slot. notes: Items stay vanished until another item is placed into a particular slot.  Not sure how the particular slot is chosen.  The "stack all" button is doing something weird.
- [x] **Does anything stay stuck to the cursor with no way to place it?** → no. notes:  Items do not appear to stick to the cursor.
- [x] **Does a bag ever refuse to open by right-click while nothing is being dragged?** → no.
      notes: 

## 4 — The new client warnings

- [x] **Open the in-game console (backtick) and look for `Inventory: bag_` warnings** → ideally
      none. If they appear, that is the client catching a stale view it would previously have
      hidden, so **copy the lines out** — they say exactly which slot drifted. notes:  Console doesn't show much.  I attached a screenshot from the game.

## 5 — Regression: nothing else about inventory changed

- [x] **Log out and back in** → everything is where you left it. notes:
- [x] **Drop an item on the ground and pick it back up** → unchanged. notes:
- [x] **Non-empty bag still refuses to move** with "Empty the bag before moving it." notes:

---

## 6 — Stack All (added 2026-08-18 after the first run found it)

**The tester's hunch was right, and it was the original cause of the whole desync.** `Stack All`
called `Inventory.stack_all()`, which rewrote `base_slots` and `bag_contents` **entirely locally**
and told the server nothing. One click and the client's whole inventory became fiction while the
server still held the original layout, so every later move from a now-phantom slot was refused.
It also explains "items unstack and move to the main inventory window": the redistribution used
`_first_free_slot()`, which scans base slots **before** bags, so bag contents got dragged out into
the main window.

Now, in hosted play, Stack All asks the **server** to do each merge and mutates nothing locally.
It is also **merge-only** — it no longer relocates anything between containers, which was never
what the button was for.

- [ ] **Fill some bags with partial stacks of the same item (bread, water, arrows), then press
      Stack All** → partial stacks combine. notes:
- [ ] **Nothing jumps out of a bag into the main inventory** → items consolidate *where they
      already are*. notes:
- [ ] **The server log shows `MoveItem applied` lines for the merges**, rather than silence →
      confirms it went through the server rather than being faked client-side. notes:
- [ ] **Press Stack All again with nothing left to combine** → "Nothing left to stack." and no
      log activity. notes:
- [ ] **After Stack All, immediately drag several items around** → no `source slot empty`
      rejections. This is the row that proves the desync source is closed. notes:
- [ ] **No stack ends up larger than the item's normal stack size** → the server's merge does not
      cap, so the client only pairs stacks that fit. notes:
- [ ] **Offline / Test Room: Stack All still works the old way** (there is no server to ask).
      notes:

---

## Result
-  I believe the "Stack All" button in the bags might be fucking something up.  Let me know what you find.

- When Stack All is used in a bag items that are stacked in the bag unstack and move to the main inventory window.  Let me know if that makes sense.
- Client build (`/version`):
- Server build (`build=` on the boot line):
- Overall:
