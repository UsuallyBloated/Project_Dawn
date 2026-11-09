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

> **Run through `bump_build_master_checklist.md` (2026-11-06):** this sheet's rows are in the
> master in sitting order, each tagged `B<section>.<row>` (`BS.n` for Setup). Fill the master;
> the marks are copied back here.

## Setup
- [x] Server on the R720 from the merged bump (boot line `build=`, `dev_cmds=false`); the bump export (`/version`). notes: [the R720 at `267065f` (the 11-05 boot line, no restart since); the seat on an export of `df4f29c`, whose game files are byte-identical to the `da83ea8` zip's (11-06).]
- [x] A character with a few loaves, a Small Pouch with something in it, some coin, beside Thalia Mourne (the banker) and Brom. notes: [11-06: the GM seat with the loaves, the pouch and the coin, `/give`n; every §1 and §2 row ran on it.]

## 1 — The bank
- [x] **Open the bank, lift a stack of loaves onto the cursor, click an empty personal vault slot** → the loaves land in the personal vault (any slot; the server picks) and the hand is empty. notes: PASS (11-06). The user: "This does not work the other way around: I cannot lift a stack of loaves onto the cursor if the loaves are in the vault." Filed in the To-Do (a wire change).
- [x] **Lift another stack of the same loaves, click any personal vault cell** → it merges into the vault's stack (up to the stack cap). notes: PASS (11-06), tested with rat meat.
- [x] **Lift an item, click a shared vault slot** → it lands in the shared vault. notes: PASS (11-06).
- [x] **Lift an item, click an OCCUPIED vault cell holding a different item** → it deposits into a free slot of that vault; nothing is swapped. notes: PASS (11-06). The user: "I would prefer the items swapped in this situation." Filed in the To-Do.
- [x] **With the personal vault full (10 slots), lift an item and click a cell** → "Your bank vault is full." and the item stays in hand. notes: PASS (11-06).
- [x] **Lift the pouch (with something in it), click a vault cell** → "Bags can't go in the bank vault." at once, nothing sent (no journal line), the pouch stays in hand. notes: PASS (11-06). The user: "We need to allow bags in the bank." Filed in the To-Do.
- [x] **Right-click a vault item while holding something** → it still withdraws into the bags; the held item stays in hand. notes: PASS (11-06).
- [x] **Walk out of the banker's reach with the window open, lift an item, click a cell** → "There is no banker near you." (the proximity gate, unchanged). notes: PASS (11-06).

## 2 — The merchant
- [x] **Open Brom, SELL tab, with loaves in hand** → the list starts with "In hand: Bread Loaf (N)", then the bags' items. notes: PASS (11-06). The user: "Impressive. This is cool. Nice work."
- [x] **Select it and sell 2** → "Offered Bread Loaf x2 to the merchant.", the coin arrives, the hand keeps the rest and the entry's count updates. notes: PASS (11-06).
- [x] **Sell the rest** → the hand empties and the "In hand" entry leaves the list. notes: PASS (11-06).
- [x] **Lift the pouch (with something in it), select "In hand: Small Pouch", sell** → "Empty the bag before selling it."; nothing sold. notes: PASS (11-06).
- [x] **Open the SELL tab empty-handed, and with a Conjured Bread (no vendor value) in hand** → no "In hand" entry either time. notes: PASS (11-06).
- [x] **Lift an item with the SELL tab already open** → the entry appears without reopening the window. notes: PASS (11-06).

## 3 — Regression
- [x] **Right-click deposit from the bags with the bank open; sell from a bag slot** → as before. notes: PASS (11-06, master O2.5 / B3.1).
- [x] **A click on the inventory, the paperdoll or the world while holding** → places, equips or drops as before; the bank and vendor windows take only their own clicks. notes: PASS (11-06).
- [ ] **`admin_report` after the sitting** → `bank_in`, `bank_out` and `sell` rows for the moves, the check card balanced. notes:

## Notes / observations
-
