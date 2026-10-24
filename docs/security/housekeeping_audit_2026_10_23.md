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
| B1 | `DeathBroadcast` kills any player on demand (a free teleport home below level 5); it exists for client-side fall damage. User decision: model falls on the server, then remove it. **Designed 2026-10-23** (`docs/design/server_fall_damage.md`): online a fall never reached the server for an ordinary player (it goes through the dev-gated `DamageSelf`), so `DeathBroadcast`'s only honest sender is the Test Panel's Trigger Death; the design proposes gating it as a dev command now (slice 0) and the fall model with the height model (slice 1). Five decisions wait on the user. |
| B2 | The swing-rate limit assumes everyone is at maximum haste (`MAX_MODELED_HASTE`); the server tracks Haste now. |
| B3 | Cast relays repeat the client's `duration`, `spell_name` and fail `reason` to every player, unchecked (`duration` not finite-checked). |
| M4 | No per-intent rate budget for chat, trade, inventory, buy/sell, bank, loot, invites, inspect on this branch (`feat/public-hosting` has two budgets). |
| B4 | About 20 client/server pairs of the same data or rule have no lockstep check (stat blocks and level gains, XP curve, res-sickness cut, skill caps, dual-wield levels, day length, encumbrance, hunger threshold, song scaling, spell-bar rules, the spell school map). Many could be sent by the server instead. |
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

About 3,500 lines exist only for the offline/Test Room path (the ENet `Network` layer, local
`Enemy`/`Pet`/`Loot`, `transformations.gd`, `SaveManager`, which also saves to disk during
online play) plus ~95 `is_launcher_mode()` branches. Dependants to repoint first: the Test
Panel, `tools/check_nameplates.gd`, `tools/currency_smoke.gd`.

### Phase 6: observability and security polish (`dist-observability`, `security-software`)
| Id | Finding |
|---|---|
| M9 | No tick timing, metrics or spans; the player id appears under four field names; decode failures log without a client id. |
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
