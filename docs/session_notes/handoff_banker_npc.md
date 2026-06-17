# Handoff — Banker NPC (zero-weight storage + coin tier exchange)

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client (this repo,
`F:\Projects\Project_Dawn`) + a Rust authoritative server (`F:\Projects\server`).
**Read `CLAUDE.md` first** — it's the contract (the server runs a live world sim,
currently wire **PD_W0014**).

This is the **headline next feature** now that coins drop and have weight: the **Banker
NPC**. Coins are deliberately heavy (a hoard of raw copper encumbers you); the Banker is
the relief valve. It's a **bigger, cross-wire feature** than a polish session — build it in
slices, compile/test each, and **do the recommended MVP slice first** (coin banking +
exchange). Item storage is a clean follow-up slice, not part of slice 1.

## Context (read these first)
- `docs/concepts/world/currency.md` → **"Banking & Currency Exchange"** (line ~67) — the
  canonical design. Key rulings: the Banker does **both** storage and exchange (no separate
  moneychanger — decided 2026-06-16); coin in the bank has **zero weight** on the player;
  exchange ratio is fixed **100:1**, fee bands **2–5% up-convert / 0–1% down-convert**;
  storage is **tier-agnostic** (10,000c stays 10,000c until you ask to consolidate); bank
  deposit/withdraw fees are **TBD** (recommend none for MVP — EQ banks were free, the
  friction was the travel). Canonical NPC: **Thalia Mourne, Harrowmere Seventh Dock**
  (Dockmasters' Compact).
- `docs/design/group_loot_and_coin.md` + `docs/session_notes/session_2026_06_15.md` /
  `session_2026_06_16.md` — how coins drop, the wallet, and the `Coins` tier math came to be.
- `docs/concepts/architecture/systems_overview.md` → "Items / economy" + "Group loot rights
  & coin drops" for the current coin/inventory/vendor state.

## Repos at handoff
| Repo | Path | Branch | State |
|---|---|---|---|
| Client | `F:\Projects\Project_Dawn` | `feature/ally-buff-routing` | clean; loot/group polish done |
| Server | `F:\Projects\server` | `feature/ally-buff-routing` | clean (ignore stray `*.exe`/`server.log`); wire PD_W0014 |

No git remotes — local-only. Run `git -C <each> status` / `log --oneline -10` before/after.
Server tests: `cargo test -p projectdawn-server --lib` (130 lib tests pass from the server
dir — it has a pinned 1.95.0 toolchain via `rust-toolchain.toml`, so run cargo **from
`F:\Projects\server`**, not with `--manifest-path` from elsewhere; the `world_two_clients.rs`
pet/AOE failures are **pre-existing flaky** — `server/docs/flaky_integration_tests.md`,
re-run failing tests individually). Client checks: `godot --headless --path . --quit` (no
SCRIPT ERROR; known-ignorable `time_of_day.gd:44` null `add_child` in `--script` mode only)
and `tools/currency_smoke.gd` → `CURRENCY_SMOKE_PASS`.

> **Wire/DLL gotcha (this feature needs it):** the Banker adds **new wire messages**, so
> **bump PD_W0014 → PD_W0015** (`WORLD_PROTOCOL_ID`, `protocol/src/world.rs:31`) — a new
> feature track gets one bump, mirroring PD_W0013→PD_W0014 for the loot/coin track. Append
> every new variant to the **END** of its enum: bincode encodes variants positionally, so
> inserting mid-enum shifts later discriminants (there's a load-bearing comment on the
> `GroupNotice` variant at the end of `ServerWorldMsg` explaining exactly this — I had to fix
> a mid-enum insert in the last session's review). After any wire change, rebuild the
> GDExtension DLL (`addons/gdext_net/build.ps1`, ~45 s — run it **plainly**, no `2>&1`
> redirection, or PowerShell's `ErrorActionPreference=Stop` throws on cargo's stderr
> progress) **and** rebuild the server. The protocol_id signs the renet ConnectToken, so a
> mismatched pair is rejected at connect (clean version error). gdext-net source lives in the
> **server** repo (`crates/gdext-net/src/lib.rs`) and shares the `protocol` crate.

---

## Recommended slice 1 (MVP) — **coin** banking + tier exchange

The highest-value, lowest-complexity increment: deposit/withdraw **coins** (the weight
relief valve) and convert between tiers. **No item storage yet** — items are a bigger UI lift
and a clean second slice. This is shippable and verifiable on its own.

### A. Server foundation — persisted bank balance

A character's bank is **four coin counts** (platinum/gold/silver/copper), zero-weight,
session-loaded + persisted like the wallet.

- **DB:** add `migrations/0005_bank.sql`. sqlx auto-applies all `.sql` in sequence on boot
  (`db/mod.rs` `migrate()` → `sqlx::migrate!("../../migrations")`). Mirror `0004_currency.sql`
  (added the four wallet columns): a `bank_*` set. Simplest for slice 1 — add four columns to
  `characters` (`bank_platinum/gold/silver/copper INTEGER NOT NULL DEFAULT 0`). (A separate
  `bank_items` table is slice 2; don't build it yet.)
- **Server state:** add `bank_coins: protocol::world::Coins` + `bank_dirty: bool` to
  `PerConnection` (`world/connection.rs` — mirror `coins` + `coins_dirty`, ~line 152/286).
  Load in `load_character` (db/mod.rs — mirror how `coins` loads), persist in the checkpoint
  sweep (`world/persistence.rs` ~line 64–87 — mirror the `coins_dirty` gate calling a new
  `db::save_bank`).
- **Coin math is already there:** `Coins` (`protocol/src/world.rs:45`) has `total_copper`,
  `from_copper`, `can_afford`, `spend`, `add_payout`. Deposit = `wallet.spend(amt)` +
  `bank.add_payout(amt)`. Withdraw = reverse. Exchange (within the bank, or on the wallet —
  decide) = `spend(gross)` + `add_payout(net)` where `net = converted`, `fee = gross - net`
  (fee just vanishes — it's the Banker's cut, not held anywhere).

### B. Wire (PD_W0015) — intents + a bank snapshot

Append to the **ends** of the enums in `protocol/src/world.rs`:
- **Client→server** (`ClientWorldMsg`, mirror `BuyItem`/`SetAutosplit` shape ~line 290):
  - `BankDepositCoins { platinum, gold, silver, copper }` (or a single `Coins`)
  - `BankWithdrawCoins { platinum, gold, silver, copper }`
  - `BankExchange { from_tier: u8, to_tier: u8, qty: u32 }` (tiers 0=c…3=p)
- **Server→client** (`ServerWorldMsg`, mirror `CoinsUpdate`/`GroupNotice` ~end of enum):
  - `BankSnapshot { platinum, gold, silver, copper }` — fanned when the player opens the
    bank (and after each mutation), so the client shows the bank balance. The **wallet** side
    reuses the existing `CoinsUpdate` fan (no new message needed for the wallet).
- **gdext bridge** (`crates/gdext-net/src/lib.rs`): add a `send_bank_*` for each client
  intent (mirror `send_autosplit`/`send_buy_item`), and for `BankSnapshot` add a `#[signal]
  fn bank_snapshot(...)` + an `Incoming::BankSnapshot` decode/emit arm (mirror
  `loot_rejected`/`group_notice` end-to-end). **Rebuild the DLL.**
- **Client `net.gd`:** `broadcast_bank_deposit/withdraw/exchange` wrappers (mirror
  `broadcast_autosplit` ~line 460) + a `world_bank_snapshot` signal + `_on_bank_snapshot`
  handler (mirror `world_group_notice`).

### C. Server handlers — apply + fan

Mirror the **vendor Buy/Sell** apply pattern exactly (`world/tick.rs` ~5178–5433; intents
declared in `world/handlers.rs` ~964–989 returning `Outcome::*Intent`, queued + drained in
the tick loop like the autosplit/loot-mode intents you'll see there):
- Validate (player in-world; `wallet.can_afford` for deposit/exchange-from; `bank.can_afford`
  for withdraw). On failure, fan a private notice (reuse `send_group_notice`'s shape or
  `LootRejected`-style — or add a `BankRejected`; your call).
- Mutate wallet + bank, set `coins_dirty` + `bank_dirty`.
- Fan `CoinsUpdate` (wallet, existing helper `send_coins_update`) **and** `BankSnapshot`
  (new helper). Exchange touches only one side (wallet→wallet or bank→bank — **decide**),
  so fan whichever changed.

### D. Client — Banker NPC + bank window

Clone the **Vendor trio** (it's the closest "town NPC with a trade window"; the Banker is
green-field — no existing bank/vault scaffolding to collide with):
- **NPC:** `scenes/vendor_npc.tscn` + `scripts/vendor_npc.gd` → a `BankerNPC` (Area3D +
  `banker_name` export, group `"banker_npcs"`, proximity → register with a new
  `BankerManager` autoload cloned from `autoloads/vendor_manager.gd`). Place a Banker in a
  town zone (use **Thalia Mourne** per lore).
- **Interaction:** `scripts/hud.gd` NPC-targeting (~530–546) checks `vendor_npcs`/
  `dialogue_npcs` groups within 6 m — add `banker_npcs` → `BankerManager.open_for(t)`. Or
  route through a dialogue entry (`data/dialogue_definitions.gd` + an `"open_banker"` action
  in `scripts/dialogue_window.gd` ~158, mirroring `"open_vendor"`).
- **UI:** a `BankWindow` (extend `DraggablePanel`, mirror `scripts/vendor_window.gd`'s
  imperative `_build_*` layout). Slice-1 contents: show wallet (4 tiers) + bank balance
  (from `world_bank_snapshot`); deposit/withdraw amount controls per tier; an exchange
  control (from-tier → to-tier, qty, shows the fee + net using `Currency` math
  `autoloads/currency.gd`). All actions go through the `net.gd` broadcasts; **do not mutate
  `PlayerStats` coins locally** — wait for the server's `CoinsUpdate` + `BankSnapshot`
  (launcher mode is authoritative; mirror how the vendor window stays optimistic-free).

### E. Docs + playtest
- Append a session note + `README.md` index row; move the "what exists" into
  `systems_overview.md` (Items / economy). Update `currency.md`'s open question on bank fees
  if you resolve it.
- Author a checklist from `docs/playtest_notes/TEMPLATE_checklist.md`: deposit coins →
  wallet drops, bank rises, **encumbrance drops** (the whole point); withdraw reverses;
  exchange 100c→1s charges the up-fee; bank balance **survives relog** (persistence);
  exchange/withdraw rejected when short.

**Acceptance (slice 1):** two-client (or solo-launcher) — a player banks coin, sees their
carried weight drop, exchanges tiers at the fee, and the bank balance is intact after a
relog. Headless boot clean; `CURRENCY_SMOKE_PASS`.

---

## Decisions to make at session start (don't start without picking)
1. **Storage schema** — four `bank_*` columns on `characters` (simplest, recommended for the
   coin-only MVP) vs a dedicated table (needed anyway for slice-2 item storage; you could lay
   it down now). *Recommend: columns now, table when items land.*
2. **What slice 1 stores** — **coins only** (recommended — the weight-relief headline, far
   simpler) vs coins+items. *Recommend: coins only; items are slice 2.*
3. **Exchange fees** — implement the currency.md bands (2–5% up / 0–1% down) now, or 0% for
   MVP then tune. *Recommend: implement a flat first cut (e.g. 3% up / 0.5% down) as named
   constants; it's core to the exchange's purpose.*
4. **Bank deposit/withdraw fee** — none (recommended, EQ-style) vs flat/scaled. *Recommend:
   none for MVP; note it in currency.md.*
5. **Where exchange operates** — on the wallet (convert coins you're carrying) vs on the bank
   balance vs either. *Recommend: wallet-side for MVP (you go to the bank to lighten your
   load); simplest single fan (`CoinsUpdate`).*
6. **Reject feedback** — reuse a `LootRejected`-style private string, or add `BankRejected`.
   *Recommend: a small `BankRejected { reason }` for clarity.*
7. **UI** — new `BankWindow` (recommended) vs extend the vendor window with tabs.

## Slice 2+ (note, don't build in slice 1)
- **Item storage** — `bank_items` table + a `BankStorage` struct mirroring
  `PlayerInventory`'s `to_rows`/`from_rows` (`world/inventory.rs` 225–321); dual-pane
  deposit/withdraw UI mirroring the inventory drag/drop + `MoveItem` wire; new
  deposit/withdraw item intents (use the `SlotRef` tagged enum like `SellItem`, not a string
  location). "Effectively unlimited" capacity per the design.
- **Citizen field-exchange** — the player-run exchange (currency.md "Four mechanical
  concerns": capital float, atomic trade window, discovery, rate caps). Blocked on the
  Citizen class; the Banker anchors the rates it competes against.
- **Death & coin loss** — open question (currency.md): stays on player / on corpse / drops.
  Resolve alongside the Corpse Run to-do, not here.
