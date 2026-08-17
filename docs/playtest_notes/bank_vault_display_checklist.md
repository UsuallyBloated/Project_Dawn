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

- [ ] **Open the bank (Thalia Mourne), click the Items tab, right-click an Iron Short Sword in
      your inventory** → it appears in a personal vault slot as a readable **name**, not a blank
      cell. `server.log` shows `bank store item`. notes:
- [ ] **Right-click a stack of Sinew (count > 1)** → the slot shows the name AND the stack count
      in the corner. notes:
- [ ] **Hover a filled vault slot** → tooltip names the item, gives the count when > 1, and says
      "Right-click to withdraw." notes:

## 2 — Round trip

- [ ] **Right-click the deposited item in the vault** → it withdraws back to your bags and the
      vault slot goes empty (no leftover name text ghosting in the cell). notes:
- [ ] **Deposit, then close and reopen the bank** → the item is still shown. notes:
- [ ] **Deposit, log out, log back in, reopen the bank** → still shown. This is the row that
      proves nothing was ever actually lost. notes:

## 3 — Both vaults

- [ ] **Switch "Deposit to:" to Shared, deposit an item** → it lands in a *shared* slot (blue
      border), not a personal one, and renders the same way. notes:
- [ ] **With a second character on the same account**, open the bank → the shared item is
      visible; the personal vault is that character's own and does not show character 1's item.
      notes:

## 4 — Regression: nothing else about the bank changed

- [ ] **Coins tab still deposits / withdraws / exchanges** as before. notes:
- [ ] **A full vault refuses a deposit** with the usual rejection message rather than silently
      dropping the item. notes:

---

## Result

Fill in after the run:

- Client build (`/version` or the login-screen footer):
- Overall:
