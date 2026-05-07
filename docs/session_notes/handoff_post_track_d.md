# Project Dawn Handoff — End of Track D

> **For pasting into a fresh Claude Code conversation.** Copy the entire
> contents of this file (between this line and the bottom of the file)
> as the next session's opening prompt.

---

You're picking up Project Dawn — a Godot 4.4 / GDScript MMORPG client,
its companion Rust server (auth WebSocket + world UDP), a Godot
launcher, and a standalone procedural dungeon generator that will be
folded into the game later.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `b5f4533` (gdext_net build.ps1: link CRT statically) |
| Server | `F:\Projects\server\` | `main` | `6d0584e` (gdext-net Rust GDExtension) |
| Launcher | `F:\Projects\launcher\` | `main` | `9a0ddb8` (Play flow: RequestWorldToken handoff) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `774d73e` (session_notes index) |

Run `git -C <each> log --oneline -5` before touching anything to confirm
the state still matches.

## Read these in order

1. `F:\Projects\Project_Dawn\CLAUDE.md` — game-client conventions, autoload
   map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_06.md` —
   covers tracks A (GDScript protocol mirror), B (launcher), C (world UDP
   server), and D (game ↔ world net adapter). The "Track D" section at
   the end is the directly upstream context for everything below.
3. `F:\Projects\server\docs\server_design.md` — wire-protocol contract,
   especially §3 (transport channels), §6 (wire protocol), §10
   (connection lifecycle), §17 (launcher protocol), §19 (client
   migration path).
4. `F:\Projects\Project_Dawn\autoloads\net.gd` — the live net adapter you
   will extend. Wraps the gdext_net `NetClient` GDExtension class.
5. `F:\Projects\Project_Dawn\scripts\net\protocol.gd` — GDScript mirror
   of the Rust `protocol` crate. Stays 1:1 with the launcher's copy.
6. `F:\Projects\ProceduralDungeon\README.md` and `todo_list.md` —
   the standalone dungeon project, planned for Project_Dawn integration.

---

## Current reality (what works end-to-end)

### Auth WebSocket service (server)

Shipping. Register / Login / CharList / CharCreate / CharDelete / Logout /
**RequestWorldToken**. Argon2id password hashing, 256-bit session tokens
with 30-min TTL. Refuses to start without `PROJECTDAWN_NETCODE_KEY`.

### World UDP service (server, slice 1)

Shipping. renet 2.0 + renet_netcode 2.0 in Secure mode (32-byte private
key). 20 Hz tick. Two channels (0 = ReliableOrdered system, 1 = Unreliable
position). Server-authoritative speed cap of 7.5 m/s. 60 s position
checkpoint. App-layer 10 s heartbeat timeout.

**Single player at a time, no AOI fan-out, no combat / inventory / chat /
quests on the wire yet.** End-to-end smoke test passes
(`tests/world_smoke.rs`).

### Launcher

Shipping. Register → CharCreate → CharDelete → Logout → Play. Play sends
`RequestWorldToken`, writes the returned `ConnectToken` bytes to a
tempfile under `OS.get_cache_dir()`, and spawns the game `.exe` with
`--auth-token` / `--char-id` / `--world-token-path` / `--world-endpoint` /
`--client-version`.

### Game client — net adapter (track D)

Shipping. `addons/gdext_net/` contains a Rust GDExtension (`gdext-net`
crate in the server workspace) that wraps a renet 2.0 client. The
`Net` autoload (`autoloads/net.gd`) extends `NetClient`, parses launcher
CLI args, reads + deletes the token tempfile, drives the state machine
(`DISCONNECTED → CONNECTING_TRANSPORT → CONNECTED_TRANSPORT →
CONNECTED_APP`), and pumps `poll(delta)` every frame. Periodic 4 s
heartbeats keep the session alive indefinitely.

**Verified end-to-end on 2026-05-07:** launcher → game spawn → renet
handshake → app `Connect` → server logs `client connected (transport)
client_id=N char_id=N account_id=N`. Heartbeats arrive every 4 s for as
long as the game window is open. Closing the window times out cleanly
on the server after 10 s (kicked-by-server, no clean `Disconnect`
emitted yet — see Track 1 below).

### Game client — local-save mode

Unchanged. When the game `.exe` is run without launcher CLI args, `Net`
autoload sits idle and the existing client-authoritative flow drives
gameplay: lobby → Test Room / Test Dungeon / local Host-Game-Join-Game
ENet flow. This is the dev-iteration path until enough server-side
features land that local-save can be retired.

### Procedural dungeon (standalone)

Shipping as a separate Godot 4.4 project. Seed-based BSP generator with
multi-floor stacking, stair shafts, mesh build, and torch placement.
Deterministic for a given seed — every peer regenerates locally, no
mesh data over the network. **Not yet integrated into Project_Dawn.**

### Hard layout invariants you must preserve

- `scripts/net/protocol.gd` is **1:1** between `Project_Dawn` and
  `launcher`. `diff` reports zero output. Updates to one are an
  immediate update to the other in the same session.
- `addons/gdext_net/gdext_net.dll` is gitignored. Build via
  `addons/gdext_net/build.ps1` on a fresh clone (uses
  `RUSTFLAGS="-C target-feature=+crt-static"` so the .dll is
  self-contained and doesn't need MSVC redist on the user's box).
- The Rust `protocol` crate (`F:/Projects/server/crates/protocol/`) is
  the source of truth for the wire format. The GDScript mirror
  follows it.
- `PROJECTDAWN_NETCODE_KEY` must NEVER appear in any commit, log line,
  error message, or test fixture.
- Token files are short-lived: launcher writes → game reads → game
  immediately deletes. The 30 s server TTL is a backstop, not the
  primary defense.

---

## Recommended forward plan

The roadmap below is ordered by **dependency + value**. Each track is
self-contained enough to be a single-session piece of work. When the
user picks one, ask the open questions at the end of that track's
section before writing code.

### Track 1 — Finish the slice-1 verification

**Why first:** Track D's verification plan called for "WASD updates
server position." Slice 1 is one line short of being complete because
`Net.send_movement()` is plumbed but never called. Easiest possible
client change; useful smoke for everything that follows.

**Scope:**
- Find the function in `scripts/player.gd` that handles WASD input (most
  likely `_physics_process(delta)`). Identify the local variable holding
  the unit input vector.
- Add, after that vector is computed:
  ```gdscript
  if Net.is_app_ready():
      Net.send_movement(direction, false)
  ```
- Re-export `builds/ProjectDawn.exe` (Project → Export → Windows Desktop
  → Export Project).
- Run launcher → Play, walk around, watch the server log for incoming
  `Move` packets. (You may want to add a one-line `tracing::debug!` to
  `world/handlers.rs` Move arm during testing, then revert.)

**Bonus polish (same session):** add
`_notification(NOTIFICATION_WM_CLOSE_REQUEST)` in `net.gd` that calls
`leave_session()` (already implemented; sends app `Disconnect` then
tears down) before quitting. Server log gets a clean
`client requested disconnect` instead of a 10 s heartbeat-timeout kick.

**Out of scope:** server-authoritative movement (server doesn't yet
mirror the player's position back into the local game scene — that's
Track 2). For Track 1, the client still drives its own position; the
server just receives Move intents.

---

### Track 2 — Server-authoritative movement (slice 2)

**Why next:** the server is currently receiving Move and broadcasting
Position back, but the client ignores the broadcast. Wiring this gives
us the first cycle of "server is the only source of truth."

**Scope:**
- `Net.world_position(id, pos, vel, yaw, sequence)` signal already
  fires on every server Position broadcast. Subscribe in `player.gd`:
  if `id == Net.get_player_id()`, reconcile local position against the
  authoritative one (snap if diff > epsilon, otherwise interpolate).
- Add client-side prediction: continue moving locally each frame, but
  blend toward the latest server position when one arrives.
- Stop letting the local client decide where it is. `PlayerStats` and
  `player.gd` accept the server's position as truth.
- Server side: nothing changes for slice 2. The Position broadcast is
  already in `world/handlers.rs::broadcast_position`.

**Files involved:**
- `scripts/player.gd` (subscribe to `Net.world_position`, reconciliation)
- maybe a small `scripts/net_player_sync.gd` helper if `player.gd` gets
  too crowded
- `autoloads/save_manager.gd` — flag that local position-saves should
  be skipped when in launcher mode (server is saving)

**Hard things to get right:**
- Reconciliation feel. Snap thresholds usually 0.5–1.0 m. Below that,
  interpolate. Tune by feel.
- Decoupling input from movement. Today `player.gd` directly translates
  input into position. Once server-authoritative, input becomes
  *intent* (sent to server) and position becomes *display* (driven by
  server replies).
- Don't break local-save mode. The reconcile path runs only when
  `Net.is_app_ready()`.

---

### Track 3 — Multi-player replication (other players visible)

**Why next:** server has no fan-out beyond the owner. Only one player
at a time can do anything meaningful.

**Scope (server, in `F:/Projects/server/`):**
- Area-of-interest manager: each connection holds a position; tick loop
  iterates connections and emits `EntitySpawn` / `EntityDespawn` /
  `Position` to peers within ~100 m.
- New `protocol::world::ServerWorldMsg::EntitySpawn { id, kind, name,
  race, class, pos, yaw, ... }`.
- Position broadcasts on channel 1 fan out to in-AOI peers, not just
  the owner.

**Scope (client):**
- `Net.entity_spawn` / `Net.entity_despawn` / `Net.world_position`
  routed to a new `RemotePlayerManager` autoload that spawns/despawns
  visual proxies (CharacterBody3D + Label3D nameplate).
- Lerp other-player positions between server snapshots (~50–100 ms
  buffer) for smooth motion despite 20 Hz tick.

**Verification:** two game clients (two launcher logins, two characters)
should see each other walking around in real time.

**Out of scope:** combat between players, group invites, chat — those
are later tracks. Just visual presence + position.

---

### Track 4 — Combat events on the wire

Server fans out the existing combat events as protocol messages. Client
displays them but doesn't compute damage.

**Scope (server):** when combat resolves, emit `Hit` / `Miss` / `Evade`
/ `BuffApplied` / `BuffRemoved` / `HotTick` / `DotTick` / `EntityDied`
on channel 2 (ReliableUnordered). Implement enemy AI tick (idle / chase
/ attack / flee) server-side. Spell casting state machine moves to the
server.

**Scope (client):** `Combat` autoload becomes a *reactor* — receives
events from `Net`, plays VFX/SFX/numbers, doesn't decide outcomes.
`Spells` becomes a UI-only spell book that emits `Net.cast_spell(id,
target_id)` intents.

**This is a big track.** Probably 2–3 sessions. Recommend slicing it:
- 4a: melee auto-attack only (Hit/Miss events).
- 4b: spell casting (CastStart/CastComplete + Hit).
- 4c: buffs / DoTs / HoTs.

---

### Track 5 — Inventory & equipment on the wire

Client sends `MoveItem` / `EquipItem` / `UnequipItem` / `DropItem` /
`UseConsumable` intents; server runs each as one atomic SQL
transaction (the entire dupe-prevention strategy from
`server_design.md` §6) and replies with `InventoryUpdate` /
`EquipmentUpdate` snapshots.

**Important:** every inventory mutation is one transaction. No split
state, no client-side pending. Vendor buy/sell, looting, crafting all
flow through this.

**Out of scope this track:** trade window between players (escrow
protocol), bank/shared storage.

---

### Track 6 — Chat, quests, world interaction

- `ChatMessage` routing on channel 0 (Say/OOC/Group/Tell/Guild/Raid/
  Auction/System), with the existing `Languages` autoload's garble
  cipher applied at the speaker side.
- Once chat ships, `Languages.hear_language()` passive gain wires up
  on receive — finishes the language system that's been scaffolded.
- `QuestUpdate` / `QuestRewards` from server. `QuestManager` becomes a
  read-only mirror.
- `OpenVendor` / `OpenDialogue` / `LootBagOpened` for world
  interactions.

---

### Track 7 — Procedural dungeon integration

Bring `F:/Projects/ProceduralDungeon/` into Project_Dawn as a dungeon
zone backend. The dungeon generator is already deterministic from a
seed — perfect fit for the "all peers regenerate locally" pattern.

**Scope:**
- Move `dungeon_gen/` into `F:/Projects/Project_Dawn/addons/
  procedural_dungeon/` (or git submodule). Decide ownership: keep the
  standalone repo as the upstream dev environment, or fold it in.
- Wire `DungeonSpawner.dungeon_ready` to `ZoneLoader` so the
  zone-transition system can load a seed-based dungeon.
- Server-side: dungeon zones get a `dungeon_seed` field. Server
  broadcasts the seed in `EntitySpawn` for any player entering the
  dungeon zone; clients regenerate locally. No mesh data on the wire.
- Loot chests + enemy spawns inside the dungeon plug into Project_Dawn's
  `Loot` and `EnemySpawner` systems.

**Pre-work in the dungeon repo (can happen in parallel):**
- Replace fly camera with a real `CharacterBody3D` controller (line
  item in `ProceduralDungeon/todo_list.md` "High Priority").
- Stone wall / floor / ceiling textures.
- Torch mesh (sconce + flame) at each light position.
- Enemy spawning via Project_Dawn's `EnemySpawner` once zones are
  wired through.

---

### Track 8 — Production hardening

These are non-blocking for gameplay but become important before public
hosting:

- **Mid-session reconnect** (`server_design.md` §11) — 60 s grace
  window where server keeps the entity in the world frozen.
- **Auto-update for the launcher** (`server_design.md` §13) —
  `update_manifest.json` endpoint, hash verify, swap-and-restart.
- **TLS for the auth WS** — Tailscale handles encryption inside the
  tailnet, but going public needs `wss://` + cert.
- **Cross-platform GDExtension builds** — Linux `.so`, macOS `.dylib`
  alongside the existing Windows `.dll`. Update
  `addons/gdext_net/gdext_net.gdextension` with linux/macos library
  paths.
- **Login rate limiting** (server side) — bounded by argon2 cost
  today; cheap to add a sliding window.
- **Backup verification drill** — actually restore one of the nightly
  SQLite backups and log in to a recovered character.

---

### Tracks 9+ — Client-only feature work

Independent of the server, can be slotted in any session as a break
from network plumbing. Pulled from `CLAUDE.md`'s open To-Do list:

| Track | Notes |
|---|---|
| **Sound system** | Combat hits, spell audio, ambient zone, music. Big undertaking — slice it: combat hits → spell audio → ambient → music. |
| **Target-of-target frame** | Essential for group play. Reads `Net` (or local for now) target chain. |
| **Player portrait** | Race/class portrait in HUD. Mostly art. |
| **Map / minimap** | Per-zone overhead map; doubles as the dungeon minimap. |
| **EQ-style multi-window chat** | Three sub-pieces: framework, per-window filters, per-window display settings. Big — split across sessions. |
| **Doors & locks** | Rogue lockpick skill, key items. |
| **Water & swimming** | Breath meter, drowning, Enduring Breath. |
| **Weather system** | Rain/fog/storm; some mobs stronger/weaker. |
| **Mount system** | Needs design call before implementation (see CLAUDE.md note). |
| **PvP flagging** | Needs design call. Alignment kill deltas already defined. |
| **Faction system** | Race/class affects NPC standing. |
| **Corpse run + Resurrection** | Pair: corpse system blocks Cleric Resurrection. |
| **Consumables system** | Food/drink buff slots, meditation regen loop. |
| **LFG flag, player inspect, guild, dueling, auction** | All multiplayer-facing — needs Tracks 3–6 done first to feel right. |
| **Bookbinding, Clockwork Engineering** | Tradeskill expansions. |
| **Weapon item table gaps** | Populate as new weapons are added. |

---

## Hard rules (carry forward, do not relax)

### Project_Dawn — files you must NOT modify

- `CLAUDE.md`
- `addons/procedural_dungeon/` (the embedded copy, if you make one)
- `scripts/enemy.gd` (user iterates on it directly between sessions)
- `docs/concepts/world/maps/`
- `docs/reference/`
- `docs/playtest_notes/testing_notes_2026_05_02.md`
- `docs/playtest_notes/testing_notes_2026_05_05.md`
- `docs/playtest_notes/testing_notes_2026_05_06.md`

### Cross-repo invariants

- **`scripts/net/protocol.gd` MUST stay 1:1 between `Project_Dawn` and
  `launcher`.** Diff at commit time: zero output. Update to one is an
  update to both in the same session.
- **The Rust `protocol` crate is canonical.** Add a wire type there
  first; mirror to GDScript second. Never the other way around.
- **`PROJECTDAWN_NETCODE_KEY` is sacred.** Never logged, never
  committed, never in a test fixture as a constant. Tests use
  `OsRng::fill_bytes` per-test keys.
- **Token files are read-once-then-deleted on the game side.**
  Launcher writes; game reads + immediately calls
  `DirAccess.remove_absolute(path)`.
- **The `gdext_net.dll` is gitignored.** Rebuilt from source via
  `addons/gdext_net/build.ps1` (uses `+crt-static` so it's self-
  contained — required for the exported game to load it).

### Process

- **Match commit-message tone per repo.** Run `git log --oneline -5` in
  each before writing one. HEREDOC body, blank line, Co-Authored-By
  footer.
- **One commit per repo per logical change.** Don't bundle
  cross-repo changes into a single repo's commit.
- **Pause and ask** before any destructive git operation, before
  pushing to a remote, before touching files outside the agreed scope.
- **User runs Windows / PowerShell.** Use the Bash tool for POSIX
  scripts, PowerShell tool for native Windows ops. Backtick line
  continuation, `$env:NAME` for env vars, `;` not `&&` for chaining.
- **Session notes after every session that touches 3+ files or modifies
  a core system.** Append to `docs/session_notes/session_YYYY_MM_DD.md`
  in `Project_Dawn`, update the index in `docs/session_notes/README.md`.

### Build / test workflow

- Server: `cd F:/Projects/server && cargo test --release` should pass
  (currently 6/6). Adding tests for new wire messages is encouraged.
- GDExtension rebuild: `F:/Projects/Project_Dawn/addons/gdext_net/build.ps1`
- Game export: Project → Export → Windows Desktop preset → Export
  Project → `builds/ProjectDawn.exe` (also produces `.console.exe` for
  diagnostics).
- Launcher run: open `F:/Projects/launcher/project.godot` in Godot 4.4,
  F5. The launcher's "Play" button spawns whichever exe matches
  `PROJECTDAWN_EXE` env var, then sibling `ProjectDawn.exe`, then the
  dev fallback at `F:/Projects/Project_Dawn/builds/ProjectDawn.exe`.

---

## Open questions to ask the user before starting any track

1. **Which track first?** The natural order is 1 → 2 → 3, but the user
   may want to slot in client-only feature work (Tracks 9+) any time.
   Confirm scope before writing code.
2. **Server live during the session?** If the user has the server
   running in a `Tee-Object` log, you can read `F:/Projects/server/server.log`
   to verify behavior. Otherwise restart it together at the start.
3. **Local-save flow must keep working** unless the user explicitly
   greenlights retiring it. Even after the server is fully feature-
   complete, `--local-save` is a useful dev-iteration mode.
4. **Console wrapper for diagnostics:** the game exports as
   `ProjectDawn.exe` (no console) + `ProjectDawn.console.exe` (with
   console). For any session that needs to see the game's stdout
   (heartbeat traces, Net warnings), have the user point
   `$env:PROJECTDAWN_EXE` at the console version, or temporarily
   rename so the launcher picks it up.

---

## Quick reference — key files & autoloads

### Project_Dawn

- `autoloads/net.gd` — Net adapter (extends `NetClient` GDExtension class)
- `scripts/cli_args.gd` — launcher CLI arg parser
- `scripts/net/protocol.gd` — wire-format constants + builders
- `addons/gdext_net/` — Rust GDExtension bundle
- `autoloads/save_manager.gd` — local persistence (becomes no-op in launcher mode)
- `autoloads/zone_loader.gd` — zone transitions; will gain dungeon-seed entries (Track 7)
- `data/spell_definitions.gd`, `data/quest_definitions.gd`, `data/dialogue_definitions.gd`,
  `data/loot_tables.gd`, `data/named_mob_definitions.gd` — content data

### Server

- `crates/protocol/src/auth.rs` — auth WS messages (JSON)
- `crates/protocol/src/world.rs` — world UDP messages (bincode)
- `crates/projectdawn-server/src/auth/mod.rs` — auth handler
- `crates/projectdawn-server/src/world/{mod,connection,handlers,tick,persistence}.rs` —
  world tick loop
- `crates/projectdawn-server/src/db/mod.rs` — sqlx queries
- `crates/projectdawn-server/tests/world_smoke.rs` — full handshake test
- `crates/gdext-net/src/lib.rs` — GDExtension wrapping renet client

### Launcher

- `scripts/main.gd` — Login / CharSelect / CharCreate / Play flow
- `autoloads/auth_client.gd` — WebSocket auth wrapper
- `scripts/net/protocol.gd` — verbatim mirror of Project_Dawn's

### Procedural dungeon

- `dungeon_gen/dungeon_generator.gd` — BSP layout
- `dungeon_gen/multi_floor_generator.gd` — stacking + stair shafts
- `dungeon_gen/dungeon_spawner.gd` — orchestrator with `dungeon_ready` signal

---

Begin by reading the six docs in the "Read these in order" section,
then ask the user which track to take. **Do not start writing code
until the user has picked a track and answered any open questions
specific to it.**
