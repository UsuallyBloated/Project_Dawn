# The Item Ledger and the RTT Readout — 2026-10-30

Two server-only builds from the morning's calls, run on the R720 after the redeploy; no
export. **The item ledger** (`item_events`, migration 0017; design and calls:
`docs/design/item_log_research.md`): one row per movement of items or coin into or out of a
character's holdings, written by the server inside the transaction that persists the move,
and a nightly check that the books balance (per account and item, the rows sum to what the
stores hold). The operator reads it with `admin_report`. **The RTT readout**: the `player
link` journal line read `rtt_ms=0.0` for everyone because the world loop advanced renet's
clock after handing it the acks; the order is renet's own now, and an RTT reads in whole
ticks (50 ms is the floor).

| Thing | Where | Notes |
|---|---|---|
| The migration | `journalctl -u projectdawn` at the boot | the sqlx migration line for `0017_item_events`, then `ledger swept` and `ledger check mismatches=0` within the first seconds |
| The rows | `cargo run -p projectdawn-server --bin admin_report` from `/opt/projectdawn` | the "Item ledger" card: newest 50 rows; the "Item ledger check" card: BALANCED, or one line per mismatch |
| The RTT | `journalctl -u projectdawn \| grep "player link"` | one line per player a minute; `rtt_ms` a multiple of 50, never 0.0 while a player is connected over a real link |

## Setup
- [ ] Server redeployed at the ledger build; the boot line shows the new `build=` and `dev_cmds=false`. notes:
- [ ] Nobody online at the stop (the migration runs at the next boot, before any login). notes:

## 1 — The migration and the opening balance
- [ ] **Read the boot journal** → one line applying `0017_item_events`, then `ledger swept` (`carried=0 deleted=0` on a fresh table) and `ledger check mismatches=0`. notes:
- [ ] **Run `admin_report` before anyone logs in** → the check card says BALANCED; the rows card holds one `opening` row per character and item it holds (and one per character with coin), nothing else. notes:

## 2 — A session's rows (one seat, a GM character with a few loaves and some coin)
- [ ] **Sell one loaf to Brom, buy a Minor Healing Potion, then log out** → `admin_report` shows a `sell` row (count 1, delta -1, copper +price) and a `buy` row (count 1, delta +1, copper -price) under the character, newest first, each with `npc:<id>` in the detail. notes:
- [ ] **Drop a loaf on the ground and pick it up again** → a `drop` row (delta -1, detail `ground`) and a `pickup` row (delta +1, detail `bag:<id>`); both appear within a minute, logout or not (drops and pickups save at once). notes:
- [ ] **Destroy a loaf (the Trash cell), eat one by hand** → a `destroy` row and an `eat` row (detail `by hand`), each delta -1, after the next checkpoint or the logout. notes:
- [ ] **Deposit a loaf in the vault and withdraw it; deposit and withdraw some coin** → `bank_in` and `bank_out` rows with delta 0 and the vault named; `bank_coin_in` / `bank_coin_out` with copper 0 and the amount in the detail. notes:
- [ ] **`/give` yourself an item and `/givecoins` some copper (GM)** → a `gm_give` row and a `gm_coins` row, beside the `gm_actions` rows the same commands always wrote. notes:
- [ ] **After all of the above, the check card** → BALANCED. notes:

## 3 — Two seats: a trade, a death
- [ ] **Trade a stack and some coin to the partner** → the giver has `trade_out` (delta -n) and `trade_coins` (copper -c), the receiver `trade_in` (+n) and `trade_coins` (+c), every row's detail `char:<the other's id>`; written the moment the trade commits. notes:
- [ ] **Die carrying gear and coin, respawn, loot your corpse** → `death` rows (one per stack, delta -n) and `death_coins` (copper -c) at the death; `corpse_coins` and `corpse_loot` rows (the same stacks, +n) at the loot; the check card BALANCED at both points (gear on a corpse counts as out of the holdings). notes:

## 4 — The RTT
- [ ] **Both seats in the world for two minutes, over the tailnet** → each `player link` line in the journal carries `rtt_ms` of 50 or more (a multiple of 50), never 0.0. notes:
- [ ] **`/ping` on a client** → still a real number (the client's own clock, unchanged by this build). notes:

## 5 — Regression
- [ ] **Everything from §2 and §3 played as before** → no new refusal, no missing delta, nothing lost or doubled; the only visible change is the rows in the report. notes:
- [ ] **The journal after the sitting** → no `ledger sweep failed`, no `ledger check failed`, no `ledger mismatch` line. notes:

## Notes / observations
-
