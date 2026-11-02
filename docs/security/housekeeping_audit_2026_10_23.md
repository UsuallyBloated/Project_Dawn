# Housekeeping audit — 2026-10-23

Both repos compared against the kodr-skills standards (installed 2026-10-23 at
`F:\Projects\kodr-skills`, junctioned into `.claude/skills/`): the `rust-*` skills for the
server's code, the `dist-*` and `security-software` skills for reliability and security, and
`dist-consistency` for the client/server line. Three read-only audits ran against
`feat/server-speed` in both repos; every high-severity claim was then re-read by hand in the
source before it was acted on. The plan that sequences the fixes is summarised in §4.

Status words: **FIXED** (built, tested, pending the redeploy and the playtest), **OPEN**
(planned, not built), **NOTED** (recorded, no action planned).

## 1. Phase 0: the hotfix (server only, deploy branch)

Server `6f18a5e` + review fixes `3d938ca` on `fix/xp-leveling-overflow`; merged forward into
`feat/server-speed` as `019bfb3`. Checklist: `docs/playtest_notes/hotfix_crash_and_dupes_checklist.md`.
**Playtested 2026-10-26, every row passing** on `062ca07`; H3 proven with a hard kill (SIGKILL)
15 s after a withdrawal and an item-paying quest turn-in, past the last checkpoint: the item
left the vault, the reward stayed, nothing duplicated.

| Id | Finding | Status |
|---|---|---|
| H1 | **Remote crash.** Chat was cut with `text[..512]`; a multibyte character at byte 512 panicked the tick task, the process exited (`world::serve` awaits the task, `main` `try_join!`s it) and systemd restarted it, costing everyone up to 60 s. Live on the R720 since the chat cap was written. | FIXED: `truncate_at_char_boundary`; the only byte-slice of a `String` in the workspace. |
| H2 | **Dupe across a restart.** A drop only marked the inventory dirty and spawned an in-memory bag; a picker saved at logout plus a restart before the dropper's checkpoint left the item with both. Any routine `systemctl restart` opened it; H1 made it on-demand. | FIXED: the dropper is saved before the bag exists (once per dropper per tick, `MAX_DROPS_PER_TICK` = 4); whoever loots a bag is saved once per tick. |
| H3 | **Partial immediate saves.** The quest reward saved the inventory alone; corpse loot, corpse creation and (on `feat/server-speed`) the trade commit rewrote inventory and wallet but not the vaults. An unsaved bank withdrawal then sat in the bags and the vault after a crash. | FIXED: `persistence::persist_dirty_stores` (one transaction, flags cleared on commit) for the quest reward; a pre-flush before corpse loot, death and the trade commit. |
| H4 | **Wipe on a failed load.** A failed inventory, skill, vault (and on `feat/server-speed` spell-bar or logout-time) read at login defaulted to empty and play went on; the next save wrote the empties over the real rows. | FIXED: any failed load refuses the login with a reliable kick. |
| H5 | **Any priced item for sale.** `BuyItem` sold every item with a `vendor_price` at any vendor in reach (171 of 174 items, named drops included); stock lists existed only on the client. | FIXED (interim): `npcs.toml` carries each vendor's `stock`; only an item a vendor in reach stocks (and, on `feat/server-speed`, who serves the buyer on faction) is for sale. `tools/check_vendor_lockstep.gd` compares the lists. The real `vendor_id` waits on a protocol bump (Phase 4). |
| H6 | A failed `save_corpse` (or the new pre-flush) skipped the corpse for good: no strip, no corpse, the death penalty bypassed. | FIXED: `corpse_pending` is set again, so the corpse retries next tick. |

Tests (each fails on the unfixed code): the server keeps serving after the long line; a drop
leaves the saved inventory at once; a picked-up drop is in the picker's saved inventory at
once; a burst of six drops in one datagram applies four; a death after an unsaved withdrawal
leaves the loaf in one place; a traded withdrawal leaves the giver's vault; an undecodable
row refuses the login and stays untouched; an unstocked named drop is refused while bread
sells. Unit tests for the char-boundary cut and the stock table.

Accepted trade-off: a crash with a dropped bag still on the ground loses that item (a loss,
never a copy), as unsaved kill loot always could.

## 2. Open findings, by plan phase

### Phase 1: durability (`dist-failure-resilience`, `dist-transactions`): FIXED, deployed and playtested 2026-10-23
Server `b36904e` + review fixes `6c2bc45` on the deploy branch, merged into `feat/server-speed`
as `a7a318f`. Checklist: `docs/playtest_notes/phase1_durability_checklist.md`.

| Id | Finding | Status |
|---|---|---|
| M1 | No SIGTERM/Ctrl-C handling; `KickCode::Restart` never sent; a restart lost up to 60 s for everyone. | FIXED: a stop signal saves everyone first (12 s retry budget), then tells each player the true line, then closes; non-zero exit if anyone was not saved; a second signal quits at once; Windows console close and shutdown included. |
| M2 | The logout save removed the connection first and dropped a failed save. | FIXED: a retry queue (every second), relogin refused until it lands, given up after 2 minutes to the last saved state. |
| M3 | XP outside its transactions (death, quest turn-in; the resurrection refund too, found while fixing). | FIXED: `db::XpProgress` written inside the corpse, quest-completion and resurrected-flag transactions. |
| M8 | A `tick::run` error was logged and auth kept running. | FIXED: the error returns through `world::serve` and ends the process. |

One save path now: `persistence::flush_connection` (position, resources, stores, skills,
faction standings on `feat/server-speed`, quests), used by the checkpoint, logout, the retry
queue and shutdown. Accepted residual: a character whose corpse save failed and who leaves
before the retry is saved without its corpse (reachable only while the database fails writes).

### Phase 2: structure (`rust-traits-api`, `rust-testing`)
| Id | Finding |
|---|---|
| F5 | `tick.rs` is ~12,900 lines; `tick::run` is one ~10,400-line function routing ~59 `Outcome` variants into ~34 local queues. Seams: a `World` struct, one module per phase. |
| F6 | Duplicated helpers: 17 hand-rolled `peek_at` delta fans, the in-world recipient list built three times a tick, buff-snapshot fans that hand-roll bincode, auth `serve_bound` duplicating `serve`'s accept loop. |
| F7 | Ids are raw integers whose kind is a numeric range; 34 ad hoc range tests in `tick.rs`, two of which disagree; 128 `as ClientId` / `as u64` casts. |
| F8 | `Coins` with public signed fields is decoded straight from client messages; three hand checks stand between a forged negative and theft. |
| F9 | `AuthError` is the error type for world persistence; inventory and trade errors are `&'static str`. |
| F12 | `world_two_clients.rs` holds the harness and 140+ tests in one file; `world_smoke.rs` copies the harness. |

**F5 and F12 BUILT 2026-11-01 (night)** on the server branch `refactor/tick-split` (from
`feat/facing`, so it merges after the bump; eight commits, the suite green after each, 350
unit and 161 world tests). F5: `tick.rs` (13,820 lines, one 10,400-line function) is now
`tick/`: `mod.rs` holds `run` (about 330 lines), whose loop is the stop check, the transport
update, one call per step in the order they always ran, and the packet send; `state.rs` holds
`WorldState` (everything kept across ticks) and `Intents` (one tick's queues and their types);
23 step modules and 5 modules of shared rules hold the code. Every step moved unchanged into a
function that destructures the two structs into the names it always used; a line-by-line
comparison of the old file with the new ones finds only the deliberate edits (the queue
declarations turned into fields, timers read through their reference, `super::` paths now
`crate::world::`, `pub(super)`, rewritten comments). F12: `tests/world/` is one test binary,
the harness in `common/` and a module per domain; `world_smoke.rs`'s copy of the harness is
gone (it is the `smoke` module). **F6 to F9 stay OPEN**; §4 has the recommendation.

### Phase 3: guardrails (`rust-build-cargo`, `devops-github-workflows`, `rust-testing`): PART BUILT 2026-10-23
Server `01fd0ae` + review fixes `3f7c23a` on the deploy branch, merged into `feat/server-speed`.

| Id | Finding | Status |
|---|---|---|
| F13 | No CI, `deny.toml` or `cargo audit`. | FIXED: on-demand CI (suite and cargo-deny blocking; rustfmt and clippy report only), actions pinned by SHA. The first advisory match found tokio, anyhow and event-listener advisories, fixed by updates; bincode (unmaintained) and rsa (never compiled) accepted with reasons. |
| F13 | No `[workspace.lints]`; 981 rustfmt diffs. | OPEN: after the `tick.rs` split, with the one-time reformat. |
| F2 / C1 | No panic containment. | OPEN: after the split. |
| F10 / L3 | `set_var` ran inside the runtime. | FIXED: `.env` loads in a synchronous `main` before the runtime. `#![forbid(unsafe_code)]` on protocol, shared and the server library. |
| L1 | `Config` printed the netcode key in `Debug`. | FIXED: `NetcodeKey` newtype with a redacting `Debug`. |
| F11 | No fuzzing or property tests; the decoder had no size limit. | FIXED in part: a 16 KiB decode limit and a throttled decode warning; property tests on the decoder (random and mutated bytes), coin arithmetic and inventory moves. `cargo-fuzz` not added (needs a nightly toolchain installed outside `F:\Projects`). |

### Phase 4: the client/server line (`dist-consistency`, `security-software`)
| Id | Finding |
|---|---|
| B1 | `DeathBroadcast` kills any player on demand (a free teleport home below level 5); it exists for client-side fall damage. User decision: model falls on the server, then remove it. **Designed 2026-10-23** (`docs/design/server_fall_damage.md`): online a fall never reached the server for an ordinary player (it goes through the dev-gated `DamageSelf`), so `DeathBroadcast`'s only honest sender is the Test Panel's Trigger Death; the design proposes gating it as a dev command now (slice 0) and the fall model with the height model (slice 1). All five DECIDED 2026-10-24 (the recommendations). **Slice 0 FIXED 2026-10-24**: server `779a033` (deploy branch; merged into `feat/server-speed` as `062ca07`), `DeathBroadcast` a dev command, a plain account's forged death ignored (test fails on the old handler); client `99f649b` (`feat/server-speed`): online falls compute nothing, Trigger Death sends a dev `DamageSelf`, no `DeathBroadcast` after a death. `fall_damage_slice0_checklist.md`, **playtested 2026-10-26**. Slice 1 waits on the height model. |
| B2 | The swing-rate limit assumes everyone is at maximum haste (`MAX_MODELED_HASTE`); the server tracks Haste now. **FIXED** 2026-10-30 (`3c10935` + `e8810db`, deployed 10-31), refined 2026-11-01 (`d40e505`, deployed 11-02: the last two swings' haste carry, the client's timer lags by two); `haste_limiter_and_cast_relay_checklist.md`, every row passed but the row 6 replay. |
| B3 | Cast relays repeat the client's `duration`, `spell_name` and fail `reason` to every player, unchecked (`duration` not finite-checked). **FIXED** 2026-10-30 (same commits): only a spell the server knows is relayed, at its own cast time, and a cancel carries one fixed word; playtested 2026-11-01, the late-joiner seed settled by a test. |
| M4 | No per-intent rate budget for chat, trade, inventory, buy/sell, bank, loot, invites, inspect on this branch (`feat/public-hosting` has two budgets). |
| B4 | About 20 client/server pairs of the same data or rule have no lockstep check (stat blocks and level gains, XP curve, res-sickness cut, skill caps, dual-wield levels, day length, encumbrance, hunger threshold, song scaling, spell-bar rules, the spell school map). Many could be sent by the server instead. **Mostly FIXED 2026-10-25** (`bump/oct22`, `bf2d1bf`): four checks cover 25 single values, the skill caps and dual wield levels, race and class tables, level gains, the hell modifier, and the spell schools; all pass, each catches planted faults. Left: the hit point and mana formula and the res-sickness cut (formulas, anchor-tested on each side), and the stats message that would retire most of these. |
| B5 | `PvpToggle` is ungated (needs the user's call with the PvP flagging design). |
| B6 | Wire hygiene: 8 client intents with no sender and no handler, 9 server messages never sent, fields the server ignores (`Attack.weapon_path`, `AcceptQuest.giver_id`, `EquipUpdate`). |

### Phase 5: the offline client code (user decision: remove)
**Step 1 FIXED 2026-10-23** (client `95354b3` on `feat/server-speed`, rides the Oct 22 export;
`offline_save_online_checklist.md`): `SaveManager.save()` refuses online, so an online
character is no longer written to the Test Room's `character.save` on level-up, zone load, Quit
Game or a finished camp. The dev box's save held "Splenda", a level 10 Shadow Knight written at
16:25 that day, where the Test Room's default is Chortle; that is consistent with the leak
(not proven: a headless run could also have written it). Probe
`tools/probe_save_manager_online.gd` fails on the previous code.

**The rest BUILT 2026-11-01 (night)** on the client branch `refactor/remove-offline-code` (from
`feat/facing`; 15 commits, 102 files, about 6,400 lines out, 740 in): the `Network`,
`SaveManager`, `Transformations` and `WarderAI` autoloads, the local enemy, pet, loot rolling
and character creation, the offline lobby and the login's Offline button, the client's own
regen, buff and song ticks, the local inventory and wallet mutators, and every
`is_launcher_mode()` branch (the online side kept; the function itself renamed
`has_world_session`). Test Panel buttons that only changed client state went (the character
and stats overrides, zone travel, God Mode, No Cooldowns, Clear All Buffs); its server-routed
tools stay. All 12 checks, all 11 probes and a headless boot pass. Two online bugs fell out:
the group panel found your own row by `multiplayer.get_unique_id()` (1 for everyone online),
and the pet's local assist errored on every mob hit online. The dungeon scene and the
procedural dungeon addon are kept (the canonical-copy decision is open) but unreachable.

About 3,500 lines exist only for the offline/Test Room path (the ENet `Network` layer, local
`Enemy`/`Pet`/`Loot`, `transformations.gd`, `SaveManager`, which also saves to disk during
online play) plus ~95 `is_launcher_mode()` branches. Dependants to repoint first: the Test
Panel, `tools/check_nameplates.gd`, `tools/currency_smoke.gd`.

### Phase 6: observability and security polish (`dist-observability`, `security-software`)
| Id | Finding |
|---|---|
| M9 | No tick timing, metrics or spans; the player id appears under four field names; decode failures log without a client id. **Tick timing FIXED 2026-11-01** (`d4f1a2a`, deploy branch): a once-a-minute `world health` line (each tick's work at the median, the 99th percentile and worst, the ticks over the 50 ms budget, the checkpoint's time), logged while anyone is in the world or when a tick overran. The spans, the one field name and the decode client id stay OPEN. |
| M7 / F3 | The 20 Hz loop awaits SQLite inline (about eight reads per connect, the checkpoint writes connections one after another). |
| M6 / F4 | Argon2 runs on runtime threads; no WebSocket handshake timeout, connection cap or size limit; no password maximum (part of this is on `feat/public-hosting`). |
| L2 | Session tokens stored raw; expired sessions never purged; the ban check runs before the password check. |
| L6 / L7 | Auth listens on `0.0.0.0` over `ws://`; backups are nightly and on the same host. |
| L8 | No characters-per-account cap. |

## 3. Already matching the standards (do not redo)
Single-connection saves atomic with flags cleared on commit; trade and corpse loot committed in
one transaction with in-memory rollback and deferred client messages; repeated intents
(quest turn-in, res accept, memorize finish, spell-bar seed, loot, respawn) cannot apply twice;
negative coin amounts rejected; non-finite Move and spawn floats rejected; dev/GM commands
gated, budgeted and refused if they cannot be audited; session tokens from `OsRng`; Argon2id;
login timing equalised for unknown users; per-IP login and register limits; no string-built
SQL; netcode in Secure mode with signed account and GM flags; `Cargo.lock` committed and the
wire crates pinned; coin and XP arithmetic saturating; good unit coverage in inventory, entity,
AOI and protocol.

## 4. The plan
Phase 0 (the hotfix, deployed 2026-10-23), then Phase 1 durability (built 2026-10-23), then the Phase 2 split right after the Oct 22
bump merges (user decision, 2026-10-23), with Phase 3's CI and fuzzing alongside, then Phases
4 to 6. Running alongside other work: Phase 0 and Phase 6's auth items are independent; Phases
1, 2 and most of 4 and 5 touch the same files as feature branches and wait for them.

## 5. Where it stands, and how to finish (2026-11-01)

**Done or built:** Phases 0 and 1 (playtested); Phase 2's split and test split (F5, F12, on
`refactor/tick-split`); Phase 3's CI, `cargo-deny`, decode limit, key redaction,
`forbid(unsafe_code)` and property tests; Phase 4's B1 slice 0, B2, B3 and most of B4; Phase 5
(on `refactor/remove-offline-code`); Phase 6's tick timing.

**Left, and where each belongs.** *(User, 2026-11-02: finish the audit rather than fold its
leftovers into the To-Do. The homes below say where each piece gets built; the audit stays
open until they are done, except where a row says the user handed it elsewhere.)*

| Item | Proposed home |
|---|---|
| Merge the two branches after `feat/facing` on the next bump day, playtest both | the bump day (`overnight_2026_11_01_checklist.md`) |
| F13 rest: the one-time `rustfmt` and the `[workspace.lints]` turn-on | the same bump day, after the merges (a reformat now would conflict with every open branch) |
| F2 / C1 panic containment | a decision first (see below), then a small build |
| F6 duplicated helpers, F8 a validated coin type, F9 error types, F7 an id-kind enum | one tech-debt To-Do entry, done when the code is next touched (F7 found no live disagreement: the one loose range check is a test assertion) |
| M4 intent budgets, M6 / F4 auth limits, L2 sessions, L8 a characters-per-account cap | `feat/public-hosting`, rebased across the split (several are already there) |
| L6 / L7 bind auth to the tailnet address, an off-host backup | **deferred 2026-11-02 (user: "we can wait")**; R720 jobs for the user, steps to be written when picked up |
| B6 wire hygiene and the real `vendor_id` | the next protocol bump |
| B4's stats message | its own To-Do entry |
| B5 `PvpToggle` | **decided 2026-11-02 (user): stays a player toggle** until the PvP flagging design tightens it; closed for the audit |
| B1 slice 1 (falls simulated on the server) | **handed to the fall damage design 2026-11-02 (user)**; closed for the audit. Noted in `docs/session_notes/handoff_server_height_model.md` (invariant 4) so the height model work picks it up |
| M7 / F3 the database off the loop | measure first: the `world health` line now shows whether the checkpoint or a login stalls a tick |
| M9 rest (spans, one field name, the decode client id) | the tech-debt entry |
| `cargo-fuzz` | needs a nightly toolchain installed outside `F:\Projects`; the property tests cover the decoder meanwhile |

**Panic containment, the decision.** Today a panic anywhere in the tick ends the process, and
systemd restarts it: everyone loses what was not yet saved (since Phase 1, at most the last
checkpoint's minute; drops, trades, loot and turn-ins are saved at once). Containing a panic
inside a step that touches several players is not safe: the step may have half-applied a move,
and saving or carrying on after it could keep a copy (a dupe) or lose an item. The narrow
version is safe: a panic while handling one client's message (`intake`, which touches only
that client) kicks that client without saving it, so its last saved state stands, and the
world carries on for everyone else. Recommended: the narrow version only.
