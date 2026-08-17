# Bank Item Vault Display Playtest Checklist — 2026-08-17

Verifies the fix for "deposited items vanish from the bank Items tab"
(`quest_phase2_sliceA_checklist.md:99`), the highest *perceived*-severity item on the
friends-build list.

**Build prerequisite: re-export the client only.** No server change, no R720 restart, no gdext
rebuild. The server was always storing these items correctly.

**What was actually wrong.** Not a refresh bug, despite the old name. The server sends a
`BankItemSnapshot` after every store, the client caches it and repaints the grid every time. The
repaint drew nothing, because a vault cell held only an icon and a count label: `ItemData.icon` is
`null` for all 172 items, and the count label is blank for a stack of 1. A null texture over an
empty label looks exactly like an empty slot. The fix adds the same name-label fallback
`inventory_window.gd` has used all along, which is why bags never showed this.

Diagnostics: `server.log` anchor `bank store item` (proves the server accepted the deposit);
in-game console (backtick) for client-side errors.

---

## 1 — The original repro

- [x] **Open the bank (Thalia Mourne), click the Items tab, right-click an Iron Short Sword in
      your inventory** → it appears in a personal vault slot as a readable **name**, not a blank
      cell. `server.log` shows `bank store item`. notes:
- [x] **Right-click a stack of Sinew (count > 1)** → the slot shows the name AND the stack count
      in the corner. notes:
- [x] **Hover a filled vault slot** → tooltip names the item, gives the count when > 1, and says
      "Right-click to withdraw." notes:

## 2 — Round trip

- [x] **Right-click the deposited item in the vault** → it withdraws back to your bags and the
      vault slot goes empty (no leftover name text ghosting in the cell). notes:
- [x] **Deposit, then close and reopen the bank** → the item is still shown. notes:
- [x] **Deposit, log out, log back in, reopen the bank** → still shown. This is the row that
      proves nothing was ever actually lost. notes:

## 3 — Both vaults

- [x] **Switch "Deposit to:" to Shared, deposit an item** → it lands in a *shared* slot (blue
      border), not a personal one, and renders the same way. notes:
- [x] **With a second character on the same account**, open the bank → the shared item is
      visible; the personal vault is that character's own and does not show character 1's item.
      notes:

## 4 — Regression: nothing else about the bank changed

- [x] **Coins tab still deposits / withdraws / exchanges** as before. notes:
- [x] **A full vault refuses a deposit** with the usual rejection message rather than silently
      dropping the item. notes:

---

## Result

Fill in after the run:

- Client build (`/version` or the login-screen footer):
  ```
  Build 8ad7f39-dirty
  branch fix/xp-leveling-overflow +1 unpushed
  exported 2026-08-17T18:15:19 UTC
  gdext 5918f106 (4368896 bytes)
  ```
- Overall: **PASS — all 11 rows.** Screenshot attached to the Claude session.

Two things this run proved beyond the bank fix itself:

- **The build stamp works in a real exported build.** This was its first in-game use. All four
  fields are correct: the `-dirty` flag, `+1 unpushed` (correctly catching that `8ad7f39` was
  committed but not yet on GitHub), the export timestamp, and the separate `gdext_net.dll`
  fingerprint. A tester build can now identify itself from a screenshot alone.
- **The full-vault rejection path was exercised** (`Your bank vault is full.` twice in chat, after
  filling all 10 personal slots), which is §4 row 2. A full vault refuses the deposit and says so,
  rather than silently swallowing the item.
