# Held Items at the Bank and the Merchant — 2026-10-30

With an item on the cursor, a click on a vault slot deposits it (into the personal or the shared
vault, whichever was clicked), and a merchant's SELL list leads with it as "In hand", sold from
the cursor. The ask from the 10-26 sitting, where items dragged onto the vault did nothing.
**Rides the next bump day (PD_W0029, with the facing)**: the server from the merged
`feat/facing` AND the export with the rebuilt `gdext_net.dll`. One seat.

| Thing | Where | Notes |
|---|---|---|
| A deposit from the hand | journal: `bank store item ... deposited=N` | the same line as a right-click deposit; the cursor delta empties the hand |
| A sale from the hand | journal: `SellItem applied ... qty=N` | `SellItem rejected — bag has contents` for a held bag with something in it |
| The ledger | `admin_report` | `bank_in` and `sell` rows, as from a bag slot |

## Setup
- [ ] Server on the R720 from the merged bump (boot line `build=`, `dev_cmds=false`); the bump export (`/version`). notes:
- [ ] A character with a few loaves, a Small Pouch with something in it, some coin, beside Thalia Mourne (the banker) and Brom. notes:

## 1 — The bank
- [ ] **Open the bank, lift a stack of loaves onto the cursor, click an empty personal vault slot** → the loaves land in the personal vault (any slot; the server picks) and the hand is empty. notes:
- [ ] **Lift another stack of the same loaves, click any personal vault cell** → it merges into the vault's stack (up to the stack cap). notes:
- [ ] **Lift an item, click a shared vault slot** → it lands in the shared vault. notes:
- [ ] **Lift an item, click an OCCUPIED vault cell holding a different item** → it deposits into a free slot of that vault; nothing is swapped. notes:
- [ ] **With the personal vault full (10 slots), lift an item and click a cell** → "Your bank vault is full." and the item stays in hand. notes:
- [ ] **Lift the pouch (with something in it), click a vault cell** → "Bags can't go in the bank vault." at once, nothing sent (no journal line), the pouch stays in hand. notes:
- [ ] **Right-click a vault item while holding something** → it still withdraws into the bags; the held item stays in hand. notes:
- [ ] **Walk out of the banker's reach with the window open, lift an item, click a cell** → "There is no banker near you." (the proximity gate, unchanged). notes:

## 2 — The merchant
- [ ] **Open Brom, SELL tab, with loaves in hand** → the list starts with "In hand: Bread Loaf (N)", then the bags' items. notes:
- [ ] **Select it and sell 2** → "Offered Bread Loaf x2 to the merchant.", the coin arrives, the hand keeps the rest and the entry's count updates. notes:
- [ ] **Sell the rest** → the hand empties and the "In hand" entry leaves the list. notes:
- [ ] **Lift the pouch (with something in it), select "In hand: Small Pouch", sell** → "Empty the bag before selling it."; nothing sold. notes:
- [ ] **Open the SELL tab empty-handed, and with a Conjured Bread (no vendor value) in hand** → no "In hand" entry either time. notes:
- [ ] **Lift an item with the SELL tab already open** → the entry appears without reopening the window. notes:

## 3 — Regression
- [ ] **Right-click deposit from the bags with the bank open; sell from a bag slot** → as before. notes:
- [ ] **A click on the inventory, the paperdoll or the world while holding** → places, equips or drops as before; the bank and vendor windows take only their own clicks. notes:
- [ ] **`admin_report` after the sitting** → `bank_in`, `bank_out` and `sell` rows for the moves, the check card balanced. notes:

## Notes / observations
-
