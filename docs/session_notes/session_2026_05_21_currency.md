# Session 2026-05-21 — Four-tier currency + encumbrance v1

Built the currency plumbing designed in `docs/concepts/world/currency.md`: four
independent coin stacks (copper/silver/gold/platinum at 100:1) replacing the single
`coins` int end to end, plus encumbrance v1 (coin weight vs STR capacity). Three
stages, each gated before the next.

## Stage 1 — server (Rust) coin model

- New `Coins` struct in `crates/protocol/src/world.rs` — the **single home** for tier
  math: `total_copper`, `from_copper`, `can_afford`, `spend` (make-change: low coins
  first, break one higher coin only when short — a copper hoard survives unrelated
  purchases), `add_payout` (payouts arrive reduced on top of stacks, never
  re-reducing them). 6 unit tests.
- Wire break: `CoinsUpdate { coins: i64 }` → `CoinsUpdate { coins: Coins }`;
  `WORLD_PROTOCOL_ID` bumped PD_W0012 → **PD_W0013**.
- DB migration `0004_currency.sql`: four new columns; legacy `coins` carries into
  `copper` (column left in place, unread).
- `conn.coins: i64` → `Coins`; vendor Buy/Sell in `tick.rs` use
  `can_afford`/`spend`/`add_payout`; logs emit `total_copper()`.
- gdext-net: `coins_update` signal now four i64 args; decode/classify updated.
- Gate: full `cargo test` — coin tests green (3 integration + 6 unit). Two pet tests
  (`pet_attacks_owners_target`, `pet_pulls_aggro_via_threat_reaggro`) are flaky
  pre-existing (pass/fail across runs with no change; summon-timing path, no coin
  involvement).

## Stage 2 — client data + display

- New `autoloads/currency.gd` — GDScript mirror of Rust `Coins` (cross-referenced
  comments both sides; keep in sync). `total_copper` / `from_copper` /
  `format_coins` ("2g 5s 30c"; raw hoard shows raw: 350 copper = "350c") / `spend`.
- `PlayerStats`: `coins` → `platinum/gold/silver/copper`; `coins_changed` now 4-arg;
  `add_coins` = reduced payout, `spend_coins` = make-change, `apply_remote_coins` =
  4-arg server overwrite. Save schema: four keys; **legacy `"coins"` loads into
  copper** (no save wipe).
- `net.gd` 4-arg signal path; `vendor_window.gd` price tags reduced, wallet footer
  raw stacks, affordability via `total_copper()`.
- `gdext_net.dll` rebuilt + copied (editor reload required). Fixed
  `addons/gdext_net/build.ps1` — BOM-less UTF-8 em-dash broke stock Windows
  PowerShell parsing; re-saved with BOM, verified.
- Gate: headless project load clean + `tools/currency_smoke.gd` (12 assertions,
  PASS — includes legacy-save migration and hoard-stays-raw).

## Stage 3 — encumbrance v1 (client)

- `ItemData.weight` (`@export`, default 0 = untagged; snapshot round-trip).
- New `autoloads/encumbrance.gd`: weight = coins (0.02/coin flat across tiers — the
  designed pressure to convert) + inventory + equipped gear; capacity = `10 + STR`;
  recomputes on inventory/equipment/coins/stats signals. Speed mult linear past
  capacity, floor ×0.25 (applied after mount mult in `player.gd`); stamina regen
  ×0.5 encumbered / ×0 at 2× capacity (`regen.gd`); CombatLog lines on threshold
  crossings.
- Gate: headless boot clean (full autoload stack incl. Encumbrance `_ready` +
  initial recompute).

## Decisions

- **Auto-make-change on spend** (EQ-style refusal rejected) — the encumbrance choice
  lives in *holding* coin, not vendor friction. Recorded in currency.md.
- Encumbrance applies **even mounted** (an overloaded mount is still overloaded).
- Coin weight client-side only for now; remote viewers still see the slowdown
  because the server integrates the client's scaled direction vector.

## Post-playtest round (same day)

First playtest pass (checklist) surfaced one bug and one missing tool:

- **Coin persistence bug (fixed):** coins were written to the DB only at character
  creation — vendor buys/sells and dev grants mutated the in-memory wallet, and the
  EnterWorld `CoinsUpdate` seed re-read the stale row on next login (wallet wiped).
  Pre-existing gap, newly visible. Fix: `coins_dirty` flag on `PerConnection`, new
  `db::save_coins`, flushed by the 60 s checkpoint sweep (`persistence.rs`) *and* a
  disconnect flush in `tick.rs` (logout right after a vendor run shouldn't roll back).
  Regression test: `coins_save_and_load_roundtrip` in `tests/inventory_persistence.rs`.
- **Test Panel money buttons (new):** `GiveCoins` dev intent (gated on `PD_DEV_CMDS`
  like HealSelf; exact per-tier credit, no reduction — raw copper stays raw for
  encumbrance testing; negative grants floor at 0). Buttons: **Give 1,000 Copper**,
  **Give 1p 5g 5s**, **Clear Money**. Launcher mode deliberately does no optimistic
  local fill — a silently-ignored grant *looks* ignored (the Full Heal lesson).
  New `PlayerStats.add_coin_stacks(p,g,s,c)` is the solo-path/exact-tier credit API.

## Follow-ups

- Weight readout UI (character-window "Weight: X / Y" line is the natural spot —
  STR tooltip already promises carry capacity).
- Item-weight content pass (`ItemData.weight` defaults 0 on all existing `.tres`).
- Moneychanger NPCs, banks, Citizen trade-window exchange mode (design in
  currency.md).
- Playtest: `docs/playtest_notes/currency_encumbrance_checklist.md`.

Files: server `protocol/world.rs`, `db/mod.rs`, `connection.rs`, `combat.rs`,
`inventory.rs`, `handlers.rs`, `tick.rs`, `gdext-net/lib.rs`, `migrations/0004`,
tests; client `currency.gd` (new), `encumbrance.gd` (new), `player_stats.gd`,
`net.gd`, `vendor_window.gd`, `player.gd`, `regen.gd`, `item_data.gd`,
`project.godot`, `tools/currency_smoke.gd` (new), `build.ps1`, docs.
