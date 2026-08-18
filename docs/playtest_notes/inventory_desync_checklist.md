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

- [ ] **Move items around your bags and base slots freely for a minute or two** → everything
      behaves as before, no visible change. notes:
- [ ] **Right-click to equip, use a consumable, open and close bags** → unchanged. notes:
- [ ] **Deposit and withdraw at the bank** → unchanged. notes:

## 2 — The recovery itself (the point of this change)

Repeat what triggered it last time: a long, fast session of dragging items in and out of bags,
including moving bags themselves. The aim is to provoke at least one `MoveItem rejected` line.

- [ ] **Drag heavily for several minutes, then check the server log for `MoveItem rejected`** →
      some may appear, which is fine and expected. notes:
- [ ] **For any slot that got rejected, look at whether it is rejected again and again** → it
      should NOT repeat indefinitely on the same slot. One rejection, then the client corrects
      itself and stops asking. Repeated identical rejections over minutes = not fixed. notes:
- [ ] **After any rejection, does the UI agree with reality?** → the slot the server called empty
      should now render empty on your screen, without a relog. notes:

## 3 — The symptoms that started this

- [ ] **Does any item appear to vanish and stay vanished?** → no. If one does, note the item and
      the slot. notes:
- [ ] **Does anything stay stuck to the cursor with no way to place it?** → no. notes:
- [ ] **Does a bag ever refuse to open by right-click while nothing is being dragged?** → no.
      notes:

## 4 — The new client warnings

- [ ] **Open the in-game console (backtick) and look for `Inventory: bag_` warnings** → ideally
      none. If they appear, that is the client catching a stale view it would previously have
      hidden, so **copy the lines out** — they say exactly which slot drifted. notes:

## 5 — Regression: nothing else about inventory changed

- [ ] **Log out and back in** → everything is where you left it. notes:
- [ ] **Drop an item on the ground and pick it back up** → unchanged. notes:
- [ ] **Non-empty bag still refuses to move** with "Empty the bag before moving it." notes:

---

## Result

- Client build (`/version`):
- Server build (`build=` on the boot line):
- Overall:
