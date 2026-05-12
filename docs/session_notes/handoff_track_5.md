# Track 5 Handoff — Server-authoritative enemies

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
companion Rust server (auth WS + world UDP), Godot launcher,
standalone procedural dungeon generator. Four repos, four branches.

Tracks 1–4 closed the server-authoritative loop for **player state**:
two `.exe` instances on one server now see each other walk, render
HP/MP/Stamina/buffs/casts via target-frame inspection, see hit/miss
floating text, and watch each other die and respawn. The wire format
is stable at `WORLD_PROTOCOL_ID = PD_W0003`. Every ClientWorldMsg /
ServerWorldMsg variant relevant to player visibility is wired
end-to-end.

**Track 5 is server-authoritative enemies.** Today, enemies spawn
**client-local** on each instance with independent RNG. Two clients
in the same zone see *different* enemies in different positions
fighting different fights. Damage dealt to an enemy is local —
peers don't see the swing, the damage, the death, or the loot.
Track 5 lifts authority over enemies to the server: spawn points,
spawn timers, position, HP, AI state, and combat outcomes all live
server-side. Clients render enemy state via broadcasts (same shape
as RemotePlayer for players).

**Deliberate scoping choice — the trust model.** Track 4 left
player HP authority client-local. Track 5 inverts it for enemies:
**the server is authoritative on enemy state.** When a client
swings at a goblin, the client sends an AttackIntent; the server
rolls hit/miss/damage and broadcasts the result. The client renders
the broadcast — it does *not* compute the outcome locally. This is
the first piece of the codebase where the server stops being a
fan-out relay and starts being a simulation owner.

**Track 6 will then lift player HP authority** — once the patterns
are established here for enemies, applying them to PvP combat is
mostly mechanical. Group XP sharing (handoff to-do) also rides on
Track 5/6 because the server has to own who killed what.

After Track 5, two `.exe` instances will:
- See the same enemies in the same positions in the same zone.
- Watch each other engage with mobs (their hit/miss/damage broadcasts
  fan out — sub-task 4 infra already covers this).
- See mobs die when the server decides they die, and respawn when
  the server's spawn timer fires.
- Receive XP only when the server confirms the kill (no client-side
  XP grants for monster kills).

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `9088bf9` (Track 4 sub-task 5: replicate peer death + respawn) |
| Server | `F:\Projects\server\` | `main` | `9e2fd8d` (world: death fan-out) |
| Launcher | `F:\Projects\launcher\` | `main` | `fc17ff1` (protocol.gd: add W_DEATH_BROADCAST tag (mirror)) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS into DEBUG_TORCH_LABELS / DEBUG_COMPASS) |

Run `git -C <each> log --oneline -5` before touching anything to
confirm the state still matches.

## Read these in order

1. `F:\Projects\Project_Dawn\CLAUDE.md` — project conventions,
   autoload map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_12.md`
   — Track 4 close. The fan-out lifecycle pattern (client broadcasts
   on owning state, server caches + fans out via Outcome variants,
   step 4a seeds new joiners) is the pattern Track 5 inverts for
   enemies: server owns the state and pushes it; clients receive
   without sending.
3. `F:\Projects\server\crates\protocol\src\world.rs` — read the
   full `ServerWorldMsg` enum. `EntitySpawn` / `EntityDespawn` /
   `Position` / `HealthUpdate` / `EntityDied` already cover the
   wire for enemies; you mostly *don't* need new ServerWorldMsg
   variants. You probably DO need a new `ClientWorldMsg::Attack`
   intent variant (or repurpose the existing `Attack` no-op). Any
   ClientWorldMsg addition bumps `WORLD_PROTOCOL_ID` (PD_W0003 →
   PD_W0004).
4. `F:\Projects\Project_Dawn\scripts\enemy.gd` — **DO NOT MODIFY.**
   This is on the no-modify list; the user iterates on it directly
   between sessions. You'll need to read it to understand the
   current client-local enemy AI (IDLE → CHASE → ATTACK → FLEE /
   LEASH; caster kiting; healer flee), then mirror the state
   machine on the server side. The client's enemy.gd becomes a
   *render*-only consumer of server state in Track 5; the AI logic
   relocates to Rust.
5. `F:\Projects\Project_Dawn\scenes\enemy.tscn` and
   `F:\Projects\Project_Dawn\scripts\enemy_spawner.gd` — spawn-
   point semantics (respawn_time, named_mob_id, night_only,
   override groups). Server replicates this configuration so
   spawn-point placement stays scene-authored.
6. `F:\Projects\Project_Dawn\autoloads\combat.gd` —
   `_on_auto_attack`, `_on_offhand_attack`. Today these call
   `current_target.take_damage(amount)` locally. In Track 5 they
   send `Attack` intents to the server when the target is an
   enemy; the server resolves and broadcasts. RemotePlayer-target
   path (Track 4) stays as visual fan-out for now (PvP HP is
   Track 6).
7. `F:\Projects\server\crates\projectdawn-server\src\world\tick.rs`
   — 20 Hz tick loop. Track 5 adds an enemy-AI tick phase before
   the position fan-out step (or inside it). The big lift is
   spawning + AI state machine + broadcasting.
8. `F:\Projects\server\crates\projectdawn-server\src\world\connection.rs`
   — `PerConnection` is for players. Enemies need a parallel
   `PerEntity` or just generic `Entity` storage. Decision in Track
   5 sub-task 1.
9. `F:\Projects\Project_Dawn\autoloads\loot.gd` — loot drops on
   enemy death. Currently fires client-local. In Track 5 the
   server announces death; loot generation either stays client-
   local (cheaty but simple for early alpha) or also moves
   server-side (more work but cleaner).
10. `F:\Projects\Project_Dawn\autoloads\player_stats.gd` —
    `gain_xp` path. When an enemy dies, who awards XP today is
    client-local. Server needs to own it (so two clients don't
    each get full XP for the same kill).

---

## Current reality (as of Track 4 close, 2026-05-12)

### What works end-to-end

- **Player movement + identity** — Tracks 1–3. Two clients see each
  other walk, with snapshot interpolation, EntitySpawn carrying
  name/race/class/level.
- **Player visibility** — Track 4. HP/MP/Stamina/buffs/casts in
  target frame; hit/miss/evade floating text; death/respawn
  fall-over animation.
- **Test panel in launcher mode** — Take 20 dmg, Hit/Miss/Evade
  Target buttons usable for verification without needing PvP
  combat or mob targets.
- **Lobby identity init** — `ConnectOk` carries name/race/class/level
  so launcher-mode characters spawn with the right class.

### What's missing for server-authoritative enemies

- **Enemy state lives client-local.** Each `.exe` runs its own
  `EnemySpawner`, picks RNG-driven spawn positions, runs AI in
  `enemy.gd._physics_process`, applies damage in `take_damage`.
  Two clients in "the same zone" see different mobs.
- **No wire format for enemy entities.** The existing
  `EntitySpawn` / `EntityDespawn` / `Position` / `HealthUpdate` /
  `EntityDied` variants are usable as-is but currently only fire
  for players (filtered by `conn.in_world`). Track 5 either
  reuses them by extending the meaning of EntityId to include
  mobs, or adds parallel `EnemySpawn` / `EnemyDespawn` / etc.
- **No client `Attack` intent.** Today `Combat._on_auto_attack`
  computes outcome locally. The wire has a stubbed
  `ClientWorldMsg::Attack` variant but no handler.
- **AI lives in GDScript.** `enemy.gd` is on the no-modify list.
  Track 5 mirrors the state machine in Rust: IDLE / CHASE /
  ATTACK / FLEE / LEASH, with caster kiting and healer flee.
- **XP / loot grants are client-local.** Two clients killing the
  same mob would each grant full XP. Server needs to own the
  kill-credit.

### Hard layout invariants you must preserve

- `F:\Projects\Project_Dawn\scripts\net\protocol.gd` stays 1:1
  with `F:\Projects\launcher\scripts\net\protocol.gd`. SHA256-
  equality is the contract. Any new tag constants are mirrored
  in the same session.
- `addons/gdext_net/gdext_net.dll` is gitignored. Rebuild via
  `cargo build -p gdext-net --release` + Copy-Item (or
  `addons/gdext_net/build.ps1` once its PowerShell 5.1 em-dash
  issue is fixed — Track 3 deferred).
- The Rust `protocol` crate is canonical. `WORLD_PROTOCOL_ID`
  bumps on any wire-format break. Track 5 bumps it once
  (sub-task 1's batch).
- `PROJECTDAWN_NETCODE_KEY` is sacred. Never logged, committed,
  or in test fixtures.
- **Re-export the game** after any GDScript / scene / DLL change
  before multi-instance testing. The protocol-id check is
  server-side only.
- **`scripts/enemy.gd` is on the no-modify list.** Track 5 needs
  to refactor it (or rather, gut its AI logic and replace with a
  render-only consumer of server state). Coordinate with the user
  before any non-trivial change.

---

## Track 5 scope

Five sub-tasks. Order matters more here than in Track 4 — sub-task 1
defines the spawn/AI architecture; everything else builds on it.

### Sub-task 1 — Enemy state on the server

The foundation. Server owns enemy spawn points, instance state, and
AI ticks.

**Architecture decision: zone-loaded vs hard-coded spawn points.**
The client currently authors spawn points in `world.tscn` via
`EnemySpawner` nodes (export properties for mob_id, respawn_time,
named_mob_id, override groups, night_only). Track 5 must replicate
this so the same spawn points fire server-side. Two options:

(a) **Server reads zone data files directly.** Parse `world.tscn`
    (or a dedicated `zones/<name>.json` extracted from it) and
    instantiate spawn points server-side. Decouples server from
    Godot scene format but adds a build step.

(b) **Client uploads spawn point definitions on `EnterWorld`.**
    First-mover client tells the server "here are the spawn
    points in this zone." Easy server, fragile (malicious client
    could lie about spawns).

Recommend (a). The dedicated JSON form is a small build script;
the server stays decoupled from Godot internals. Discuss with the
user in open question 1.

**Server data model.** New `Entity` struct (or rename
`PerConnection` to `PerPlayer` and add `PerEnemy`) carrying:
- entity_id (u64; mob ids should NOT collide with char ids —
  partition the namespace, e.g. mobs start at 1_000_000_000)
- mob_type_id (Wolf, Skeleton, Goblin, etc.) — references the
  data table that lives in `data/loot_tables.gd` etc. on the
  client; server needs its own mob definitions table or a shared
  data crate.
- pos / yaw / vel
- hp / max_hp
- state (Idle / Chase / Attack / Flee / Leash)
- target (Option<EntityId>)
- aggro_table (HashMap<EntityId, f32>)
- last_attack_at / last_state_change_at

`HashMap<EntityId, Entity>` alongside `connections:
HashMap<ClientId, PerConnection>`.

**AI tick.** Run inside the main 20 Hz tick loop. Each enemy:
- Re-evaluate target (current aggro_table top entry, falloff
  with distance).
- Drive state machine (closest player in aggro range → Chase;
  in melee/cast range → Attack; HP < flee_threshold for healers
  → Flee).
- Integrate position (clamped to max_speed; same shape as the
  player Move integration in step 5 of tick.rs).

**Fan-out.** Server broadcasts:
- `EntitySpawn` for each enemy when first in AOI (currently
  "everyone in zone sees everything"; spatial AOI is a future
  track when populations grow).
- `Position` per enemy per tick (or only when it moves — bandwidth
  optimization).
- `HealthUpdate` when HP changes.
- `EntityDied` on death.
- `EntityDespawn` after a delay (corpse linger), or on respawn
  timer expiry.

Same wire format as players. The client's `RemotePlayerManager`
pattern could be lifted into a generic `RemoteEntityManager` that
handles both players and enemies, OR a parallel
`RemoteEnemyManager` keeps the concerns separate. Discuss in
open question 2.

### Sub-task 2 — Client renders server enemies

Replace `EnemySpawner` + `enemy.gd._physics_process` AI with
server-driven rendering. The client's `enemy.gd` becomes a
visual stand-in (same role as `remote_player.gd` for players):
no AI ticking, no local HP, just snapshot-interpolated position
and state from broadcasts.

**Critical: `enemy.gd` is on the no-modify list.** You'll need
to either get user approval to modify it, OR create a separate
`scripts/remote_enemy.gd` that's used in launcher mode while
`enemy.gd` continues to drive the legacy single-player test
flow. Recommend the latter — surgical separation. The Test Room
flow still uses `enemy.gd` with full AI; launcher-mode world.tscn
uses `remote_enemy.gd` driven by server broadcasts.

Wire signal: `Net.world_entity_spawn` already exists from Track
3 but currently filters to player ids. Either extend the manager
to dispatch enemy ids to a new manager, or split the GDExt signal
into `player_spawn` / `enemy_spawn`. Discuss in open question 2.

### Sub-task 3 — Attack intent → server-resolved hits

Replace `Combat._on_auto_attack` direct mutation of enemy HP with
an `Attack` intent sent to the server. Server validates (player in
range, target alive, not stunned, etc.), rolls hit/miss/damage,
applies to enemy HP, broadcasts `Hit` / `Miss` to all in_world
peers (sub-task 4 from Track 4 fan-out infra), broadcasts
`HealthUpdate` for the new enemy HP.

**Wire.** Reuse `ClientWorldMsg::Attack` (currently stubbed,
no-op handler) or add new `Attack { target_id }`. Server's
response uses existing `Hit` / `Miss` / `HealthUpdate` /
`EntityDied`.

**Damage formula port.** `Combat.calc_damage()` lives in GDScript
(STR bonus, weapon damage_min/max, skill multipliers, crit roll).
This logic moves to Rust. The client's `WeaponSkills` /
`ArmorSkills` / `CastingSkills` state needs to be visible to the
server — for now, the simplest is the server *re-runs* the same
calculation with the same inputs (STR, weapon damage range, skill
levels) sent in the Attack intent. Cheaty but matches Track 4's
trust model for a transitional period.

Better: server tracks player stats authoritatively too (loaded
from DB at CharacterSpawn), and the client doesn't send stats
with attacks. Bigger lift; could be Track 6 paired with PvP HP
authority.

### Sub-task 4 — Loot drops on enemy death

When the server announces `EntityDied { id }` for an enemy, who
generates the loot? Two options:

(a) **Client-side loot from a known mob table.** The enemy id maps
    to a mob_type, which maps to a `loot_table` in `data/loot_tables.gd`.
    Client rolls locally. Other clients also roll — they might see
    *different* loot bags. Cheaty.

(b) **Server-side loot roll + LootBag broadcast.** Server rolls
    based on the mob's death event; broadcasts `LootBagSpawn` (new
    variant) with the bag's contents. All clients see the same bag.
    Cleaner but requires extending the wire and moving the loot
    table to a shared crate.

Recommend (b) for the long-term correctness, but Track 5 can land
(a) as a stepping stone if (b) is too much. Discuss in open
question 3.

### Sub-task 5 — XP / kill credit

The server announces death. The client(s) who damaged the enemy
receive XP. Today `enemy.gd._die()` calls
`GroupManager.distribute_kill_xp(base_xp)` which uses the legacy
enet path. Track 5 needs to:

- Server tracks `aggro_table` per enemy: who damaged it, total
  damage per attacker.
- On death, server determines kill credit (top damager, or
  party-wide split among all damagers).
- Server broadcasts an `XpGained` / `LevelUp` variant (already
  defined in `ServerWorldMsg`, currently unused) to the kill
  credit recipient(s).
- Client receives, applies via `PlayerStats.gain_xp`.

Group XP sharing (`GroupManager.distribute_kill_xp` with the 20%
group bonus) needs to migrate from the legacy enet path onto the
renet world channel. That's a bigger refactor — could land here
or be deferred to a follow-up.

---

## Verification plan summary

End of Track 5, all of these should be true:

- [ ] `cargo test --release` 14+/14+ (add at least one new
      integration test for enemy spawn + AI tick + death).
- [ ] Two `.exe` instances see the same enemies in the same
      positions when entering the same zone.
- [ ] Each client's attacks (server-resolved) produce visible
      Hit/Miss broadcasts to peers, with HealthUpdate driving the
      enemy's target-frame HP bar in real time.
- [ ] When an enemy dies, both clients see it die at the same
      instant.
- [ ] When the spawn timer fires, both clients see the respawn.
- [ ] Kill credit goes to the damaging client(s); XP only granted
      after server confirmation (no double-XP for same kill).
- [ ] Loot bags spawn at consistent locations across clients
      (option b) or at least don't crash (option a).
- [ ] No new GDScript warnings introduced.
- [ ] No new clippy warnings on server.

**Commits expected:** ~15 across 3 repos. Sub-task 1 is the largest
and may itself span multiple commits (data model, AI state machine,
fan-out wiring, integration test).

---

## Hard rules (carry forward, do not relax)

### Project_Dawn — files you must NOT modify

- `CLAUDE.md`
- `addons/procedural_dungeon/` (the embedded copy)
- `scripts/enemy.gd` (user iterates on it directly between
  sessions — for Track 5 propose a parallel
  `scripts/remote_enemy.gd` rather than gutting enemy.gd)
- `docs/concepts/world/maps/`
- `docs/reference/`
- `docs/playtest_notes/testing_notes_2026_05_02.md`
- `docs/playtest_notes/testing_notes_2026_05_05.md`
- `docs/playtest_notes/testing_notes_2026_05_06.md`

### Cross-repo invariants

- `scripts/net/protocol.gd` MUST stay 1:1 between Project_Dawn
  and launcher. SHA256-equality is the contract.
- The Rust `protocol` crate is canonical. `WORLD_PROTOCOL_ID`
  bumps on any wire-format break. Track 5 bumps once for the
  whole batch (`PD_W0003 → PD_W0004`).
- `PROJECTDAWN_NETCODE_KEY` is sacred. Never logged, committed,
  or in test fixtures.
- The `gdext_net.dll` is gitignored. Track 5 rebuilds it once
  per sub-task that adds signals; don't commit the binary.
- **Re-export the game** after any GDScript / scene / DLL change
  before multi-instance testing.

### Process

- Match commit-message tone per repo. `git log --oneline -5`
  before writing one. HEREDOC body, blank line, Co-Authored-By
  footer.
- One commit per repo per logical change. Don't bundle the
  five sub-tasks.
- Pause and ask before any destructive git operation, before
  pushing to a remote, before touching files outside the agreed
  scope.
- User runs Windows / PowerShell. Use the Bash tool for POSIX
  scripts, PowerShell tool for native Windows ops. PowerShell 5.1
  quirks documented in CLAUDE.md.
- Session notes after the session: write
  `docs/session_notes/session_YYYY_MM_DD.md`; update
  `docs/session_notes/README.md` index.
- User wants terse responses; no end-of-task recaps or change
  summaries. Brief progress updates fine.

### Build / test workflow

- Server: `cd F:/Projects/server; cargo test --release`. Should
  be 12/12 at handoff start (auth 3 + protocol 2 + world_smoke 1
  + world_two_clients 6). Track 5 adds at least one enemy
  integration test.
- Server runtime: `cargo run -p projectdawn-server --release 2>&1
  | Tee-Object -FilePath server.log`. User runs this; you read
  the log.
- GDExtension rebuild: `cd F:/Projects/server; $env:RUSTFLAGS =
  "-C target-feature=+crt-static"; cargo build -p gdext-net
  --release`. Output at `target/release/gdext_net.dll`. Copy to
  `addons/gdext_net/gdext_net.dll`.
- Game export: Project → Export → Windows Desktop preset →
  Export Project → `builds/ProjectDawn.exe` (and `.console.exe`).
  **Re-export between client-code changes and multi-instance
  testing.**
- Launcher run: open `F:/Projects/launcher/project.godot` in
  Godot 4.4, F5.

---

## Open questions to ask the user before writing code

1. **Zone data source for server-side spawn points.** Option (a)
   server reads a zone JSON file extracted at build-time from
   `world.tscn`, vs option (b) first client uploads spawn data on
   `EnterWorld`. Recommend (a) — server stays decoupled from
   Godot internals, no trust dependency on a client. Requires a
   small build script or manual extraction step.

2. **One entity manager or two?** RemotePlayerManager handles
   players today. Enemies could be:
   (a) Folded into the same manager (rename
       `RemotePlayerManager` → `RemoteEntityManager`, dispatch
       by entity-id namespace or a tag in EntitySpawn).
   (b) Parallel `RemoteEnemyManager` keeping concerns separate.
   Recommend (b) for clarity — players and enemies have different
   target-frame surfaces, different signals, different lifetime
   semantics (corpse vs disconnect).

3. **Loot drop authority.** Option (a) client-side roll from mob
   table (cheaty, simple, may diverge between clients), vs
   option (b) server-side roll + `LootBagSpawn` wire variant
   (cleaner, requires moving the loot table to a shared crate or
   re-defining it server-side). Recommend (b) — but (a) is an
   acceptable stepping stone if Track 5 is already too big.

4. **Damage formula authority.** The client's `Combat.calc_damage`
   uses STR / weapon damage range / skill levels. Three options:
   (a) Client sends Attack with stats embedded; server trusts
       and applies. (Cheaty, simple.)
   (b) Server tracks player stats authoritatively (loaded from
       DB at spawn, updated on level-up). Client sends just the
       intent. (Clean, bigger lift.)
   (c) Hybrid: server has authoritative max/base stats, client
       adds gear bonuses in the intent.
   Recommend (a) for Track 5, then (b) in Track 6 paired with PvP
   HP authority.

5. **enemy.gd modification policy.** It's on the no-modify list,
   but Track 5 needs to either gut it or work around it. Propose
   creating `scripts/remote_enemy.gd` as a parallel render-only
   class for launcher-mode world.tscn; `enemy.gd` continues to
   drive the legacy Test Room single-player flow unchanged.
   Explicit user signoff before any non-trivial change to
   enemy.gd.

6. **Aggro table replication.** Does the client need to see who
   the enemy is targeting? Useful for tank gameplay ("the mob
   turned on the healer!"). Adds wire traffic. Could be deferred
   to a polish track. Recommend: server tracks aggro internally,
   broadcasts only the enemy's CURRENT target (one EntityId or
   None), not the full table.

7. **Spawn-point density and AI tick cost.** The current test
   world has ~5–10 spawn points. A real zone could have 50+ mobs
   active. AI ticks at 20 Hz; 50 mobs × 20 Hz = 1000 AI evaluations
   per second. Each does a target-pick + state-machine step
   + position integration — cheap. No concern at this scale.
   Document the budget; revisit if zones grow past 200 mobs.

8. **Server live during the session.** Sub-tasks 1–5 all need
   the server running. Same `Tee-Object` workflow as Track 4.

---

## Quick reference — key files & autoloads

### Project_Dawn (game client)

- `autoloads/net.gd` — add `world_enemy_spawn` /
  `world_enemy_position` / etc. signals if the player/enemy
  split goes that way (open question 2).
- `autoloads/remote_player_manager.gd` — pattern source for the
  new `RemoteEnemyManager`. Same _spawn_data / _by_id /
  _needs_rehydrate shape.
- `autoloads/combat.gd` — `_on_auto_attack` / `_on_offhand_attack`:
  send `Attack` intent when target is an enemy instead of calling
  `take_damage` directly.
- `scripts/enemy.gd` — **DO NOT MODIFY directly.** Either negotiate
  with the user or create a parallel `remote_enemy.gd` for
  launcher mode.
- `scripts/enemy_spawner.gd` — server replicates this behavior;
  the client's spawner may become a no-op in launcher mode.
- `autoloads/loot.gd` — server-driven loot bag spawn if option
  (b).
- `autoloads/player_stats.gd` — `gain_xp` triggered by server's
  `XpGained` broadcast.

### Server

- `crates/protocol/src/world.rs` — likely additions:
  `ClientWorldMsg::Attack { target_id }` (or repurpose existing
  no-op); possibly `LootBagSpawn` / `LootBagDespawn` if option
  (b). No new ServerWorldMsg variants strictly required for sub-
  tasks 1–3; reuses existing EntitySpawn / EntityDespawn /
  Position / HealthUpdate / EntityDied / Hit / Miss / XpGained.
  Bump `WORLD_PROTOCOL_ID` to PD_W0004.
- `crates/projectdawn-server/src/world/entity.rs` (new) — Entity
  struct + AI state machine + tick.
- `crates/projectdawn-server/src/world/spawn_points.rs` (new) —
  spawn-point definitions + respawn timers. Loaded from a zone
  data file (open question 1).
- `crates/projectdawn-server/src/world/handlers.rs` — `Attack`
  handler arm: validate, resolve, broadcast Hit/Miss/HealthUpdate.
- `crates/projectdawn-server/src/world/tick.rs` — enemy AI tick
  phase, enemy position fan-out, spawn timer phase.
- `crates/projectdawn-server/tests/` — at least one new
  integration test for enemy lifecycle.
- `crates/gdext-net/src/lib.rs` — likely signal additions for
  enemy-specific signals if the player/enemy split goes that way.
  The `#![allow(clippy::too_many_arguments)]` from Track 3
  covers any new wide signals.

### Launcher

- `scripts/net/protocol.gd` — mirror new tag constants.

### Procedural dungeon

No changes expected. (Long-term: server-authoritative dungeons
would need to share the seed; out of Track 5 scope.)

---

## Begin by

1. Read the 10 files in the "Read these in order" section.
2. Run `git -C <each repo> log --oneline -5` to confirm state
   matches the table at the top.
3. Read the open questions and ask the user. Questions 1
   (zone data source), 2 (manager split), 3 (loot authority),
   4 (damage formula authority), and 5 (enemy.gd policy) all
   change the architecture. Get answers before sub-task 1's
   protocol commit lands.
4. Confirm the server is running. If not, restart together at
   the start of the session.
5. Implement sub-task by sub-task. After each, run its
   verification (cargo test + manual two-instance check).
6. After the session, write
   `docs/session_notes/session_YYYY_MM_DD.md` and update the
   index.

**Do not start writing code until the user has answered the open
questions specific to the sub-task you start with.** Sub-task 1
locks in the entity data model, manager split, and zone-data
source — getting it wrong means rewriting later sub-tasks.

When Track 5 closes, write `handoff_track_6.md` for the next
session — server-authoritative player combat (PvP) and full DB-
authoritative player stats, the second-to-last big multiplayer
piece. After that, only zone-aware AOI and the auction/social
systems remain before the netcode is "feature complete" for an
alpha-quality MMO.
