# Handoff — Currency & Encumbrance Visibility UI

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client (this
repo), Rust authoritative server (`F:\Projects\server`). Read `CLAUDE.md`
first; it's the contract.

Yesterday (2026-05-21, session note `session_2026_05_21_currency.md`) the
four-tier currency system landed end to end and survived two playtest
rounds: copper/silver/gold/platinum at 100:1, held as **four independent
stacks** (never auto-consolidated — holding raw copper is a player choice
with a weight cost), server-authoritative with make-change, persisted
across logout, plus **encumbrance v1** (coin/item/gear weight vs `10 + STR`
capacity → movement slow + stamina-regen gate) and Test Panel money
buttons. All committed; both worktrees were left clean.

**Your task is the visibility layer.** The tester's own playtest notes
define it:

> "Vendor window is the only location i see wallet. am i missing it?"

No, they weren't missing it. The wallet renders in exactly one place (the
vendor window footer) and encumbrance has *no* numeric readout at all —
just the "You are encumbered!" chat line. The system works; players just
can't see it.

## Repos at handoff

| Repo | Path | Branch | State |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `feature/ally-buff-routing` | clean; 13 commits landed 2026-05-21 evening |
| Server | `F:\Projects\server\` | `feature/ally-buff-routing` | clean; 3 currency commits (`8320533`, `86a6b9b`, `e2facca`) |

No git remotes exist — these are local-only repos. Merging the feature
branch to `main`/`master` is the user's call; ask before doing it.

Run `git -C <each> log --oneline -15` before touching anything and confirm
the worktrees are still clean — other sessions share these checkouts and
have committed mid-day before (see "gotchas").

## Read these in order

1. `CLAUDE.md` — conventions. Note the autoload table now lists `Currency`
   and `Encumbrance` under Items/economy.
2. `docs/concepts/world/currency.md` — the authoritative currency design.
   The "never silently consolidate a wallet" invariant matters for every
   display decision you'll make.
3. `docs/session_notes/session_2026_05_21_currency.md` — what was built and
   the decisions (auto-make-change; flat per-coin weight; encumbrance
   applies even mounted).
4. `docs/playtest_notes/currency_encumbrance_checklist.md` — the playtest
   record. The tester's `notes:` lines are the source of this task.
5. Skim `docs/playtest_notes/` for anything newer than this handoff.

## The task, in order

### 1. Wallet display in the inventory window

The player's money should be visible wherever their stuff is. Add a wallet
line to `scripts/inventory_window.gd` (and the bag windows share patterns —
check whether one display in the inventory window suffices first; it
probably does).

- Render via `Currency.format_coins(PlayerStats.platinum, PlayerStats.gold,
  PlayerStats.silver, PlayerStats.copper)` — **actual stacks, never the
  reduced form**. A 4,000-copper hoard reads "4000c", not "40s". The vendor
  window footer (`vendor_window.gd::_coins_text`) is the reference
  implementation; keep them consistent.
- Subscribe to `PlayerStats.coins_changed(platinum, gold, silver, copper)`
  (4-arg signal).
- House style: prefer `.tscn` over imperative `_build_*` UI for new HUD
  work — but follow whatever the inventory window already does; consistency
  within the file beats the ideal.

### 2. Weight readout in the character window

`scripts/character_window.gd` + its `.tscn`. The STR tooltip already
promises "carry weight capacity" — make it true. Add a row near the
attributes grid:

- `Weight: 12.4 / 60.0` — from `Encumbrance.total_weight` /
  `Encumbrance.capacity`; subscribe to
  `Encumbrance.encumbrance_changed(weight, capacity)`.
- Color it: normal gray; yellow when > capacity; red when ≥ 2× capacity
  (those are the two penalty thresholds — `ENCUMBERED`/`OVERLOADED_RATIO`
  constants at the top of `autoloads/encumbrance.gd`).
- The character window is scene-based (`$MarginContainer/VBox/AttribGrid/…`)
  — this is the `.tscn` edit the encumbrance session deferred. Match the
  existing row pattern in the scene.

### 3. (Stretch) HUD encumbrance indicator

Small persistent cue when over capacity — e.g. the existing HUD stat panel
gains a weight icon/label that only appears while encumbered (yellow) /
overloaded (red). Players shouldn't need the character window open to know
why they're slow. Keep it subtle; follow `hud_*.gd` family patterns.

### 4. (Stretch) Item-weight content pass starter

Every `ItemData.weight` defaults to 0 — coins are the only real weight
source today. If time remains, tag a *representative* set (~15–20 items:
weapons heavy-ish 2–8, armor by class 1–10, potions ~0.3, reagents ~0.1)
in `data/loot/items/*.tres` so the inventory-weight path gets exercised.
Don't attempt all 169 items; that's a dedicated content session with the
user in the loop on values.

## Acceptance

- Open inventory → wallet visible, shows raw stacks, updates live on
  buy/sell/grant (server `CoinsUpdate` round-trip).
- Character window → weight/capacity row, updates live as coins/items/gear
  change, colors at the two thresholds.
- `tools/currency_smoke.gd` still passes headless:
  `godot --headless --path . --script tools/currency_smoke.gd` → expect
  `CURRENCY_SMOKE_PASS`.
- Headless boot clean: `godot --headless --path . --quit` with no
  SCRIPT ERROR lines.
- Append a session note + README index row; update
  `systems_overview.md`'s Encumbrance entry (it currently says "No weight
  readout UI yet" — make that sentence false, then fix it).

## Gotchas (earned the hard way)

- **This is UI-only work — no wire changes — so no DLL rebuild needed.** If
  you DO touch anything in `F:\Projects\server\crates\gdext-net\`, the
  client's `addons/gdext_net/gdext_net.dll` must be rebuilt
  (`addons/gdext_net/build.ps1`) **with the Godot editor closed** (it locks
  the DLL), and `net.gd` won't even parse against a stale DLL if signal
  signatures changed.
- **Coins are server-authoritative in launcher mode.** UI must render from
  `PlayerStats` stacks and trust `coins_changed`; never compute optimistic
  values. The Test Panel money buttons need the server started with
  `$env:PD_DEV_CMDS=1; cargo run --release -p projectdawn-server` — a grant
  that doesn't move the wallet means the gate is off (by design, no
  client-side fake fill).
- **Two `Coins` implementations exist on purpose** — Rust
  `protocol/world.rs` and GDScript `autoloads/currency.gd` are mirrors.
  Display work shouldn't touch either, but if you change one, change both.
- **Concurrent sessions are real here.** Yesterday another session
  committed to the shared checkout mid-day and absorbed in-flight tick.rs
  edits into its commit (`3d5e05e`). Check `git status` before AND after
  long gaps; don't assume the tree is yours alone.
- **Server test suite:** `pet_attacks_owners_target` and
  `pet_pulls_aggro_via_threat_reaggro` are pre-existing flakes under
  parallel load (timing-sensitive summon path). Green in isolation. Don't
  chase them; don't let them scare you off an unrelated change.
- **F2 is no longer the debug console** — it's "target group member 1" now.
  Console is backtick (or `/console`).

## Backlog after this session (ranked, don't start without asking)

1. Item-weight content pass (full 169 items, user in the loop).
2. Moneychanger NPC (town baseline-floor exchange; design in currency.md
   "Moneychangers and Banks" — fee bands already specced).
3. Bank NPC (deposit/withdraw, zero-weight storage; town-anchored).
4. Citizen-class trade-window exchange mode (blocked on the Citizen class
   itself; see `docs/concepts/classes/citizen.md` — four mechanical
   concerns are pre-specced: capital float, atomic trade window, discovery,
   rate caps).
5. Loot drops in coin (mobs dropping tiered coin per the currency.md table
   — wire + loot-table work, gives the economy its faucet).
