# Track 3 Handoff — Multi-player replication

You're picking up Project Dawn — a Godot 4.4 / GDScript MMORPG
client, its companion Rust server (auth WebSocket + world UDP), a
Godot launcher, and a standalone procedural dungeon generator that
will be folded into the game later. Four repos, four branches; the
table below shows state at handoff.

Tracks 1 and 2 closed the server-authoritative loop for **one
player**: client sends Move intents at 20 Hz, server is sole
authority on position, broadcasts Position back, client reconciles
via snap-or-lerp. The 2026-05-09 hardening pass landed the per-tick
movement integration fix (server integrates once per tick, not per
message), gated lobby UI in launcher mode, consolidated quit
ownership, and cleaned 23 of 34 GDScript warnings (the remaining 11
are all in `enemy.gd` on the user's no-modify list).

**Track 3 is multi-player replication.** Today, every connected
client only sees their own Position broadcast — the server has no
fan-out and no spawn/despawn handshake for other entities. Track 3
wires up the wire format, server fan-out, client-side rendering of
remote players, and snapshot interpolation. After Track 3, two
.exe instances connected to the same server should see each other
walk around.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `898e18e` (Session notes: 2026-05-09 hardening pass) |
| Server | `F:\Projects\server\` | `main` | `909fa1b` (Clippy: drop useless String→String .into() and char-pattern split) |
| Launcher | `F:\Projects\launcher\` | `main` | `9a0ddb8` (Play flow: RequestWorldToken + temp-file handoff) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS into DEBUG_TORCH_LABELS / DEBUG_COMPASS) |

Run `git -C <each> log --oneline -5` before touching anything to
confirm the state still matches.

## Read these in order

1. `F:\Projects\Project_Dawn\CLAUDE.md` — project conventions,
   autoload map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_09.md`
   — the hardening pass narrative. Sub-task 3 (server-side per-tick
   movement integration) is the directly upstream context for the
   server-side fan-out work; Track 3 builds on the tick-loop step
   ordering established there.
3. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_08.md`
   — Track 1 + Track 2 narrative. Track 2's "Five rounds" table and
   the snap-or-lerp design (in `player.gd._on_world_position`) is
   the pattern Track 3 extends for remote players (with snapshot
   interpolation instead of snap-or-lerp).
4. `F:\Projects\server\crates\protocol\src\world.rs` — current wire
   format. `EntityDespawn` is already defined; `EntitySpawn` is
   the new variant Track 3 adds. `Position` stays as-is. The
   `WORLD_PROTOCOL_ID` constant gets bumped because the variant set
   changes.
5. `F:\Projects\server\crates\projectdawn-server\src\world\handlers.rs`
   — `broadcast_position` is currently per-client to-self. Track 3
   replaces with fan-out.
6. `F:\Projects\server\crates\projectdawn-server\src\world\tick.rs`
   — step 5 (per-tick integration), step 6 (broadcast position),
   ServerEvent handlers in steps 2 (Connected/Disconnected). Track
   3 modifies step 6 and the two event arms.
7. `F:\Projects\server\crates\projectdawn-server\src\world\connection.rs`
   — `PerConnection` gets two new fields (`race`, `class`) loaded
   from DB for the EntitySpawn payload.
8. `F:\Projects\server\crates\projectdawn-server\src\db\mod.rs` —
   `CharacterSpawn` and `load_character` get extended to SELECT
   race + class.
9. `F:\Projects\server\crates\gdext-net\src\lib.rs` — needs two new
   `#[signal]` declarations (`entity_spawn`, `entity_despawn`) and
   their decode-and-emit branches in the channel-drain loop.
10. `F:\Projects\Project_Dawn\autoloads\net.gd` — re-emits the
    GDExtension signals as Net's coarser autoload-level signals.
11. `F:\Projects\Project_Dawn\scripts\player.gd` — Track 2
    reconciliation lives here. Don't touch the own-player path; do
    confirm that `_on_world_position` continues to filter to
    `id == Net.get_player_id()` so it doesn't try to reconcile
    remote-player broadcasts.
12. `F:\Projects\Project_Dawn\scripts\net\protocol.gd` — must stay
    **1:1** with `F:\Projects\launcher\scripts\net\protocol.gd`.
    Track 3 adds wire-message decoders (`AUTH_*` are unaffected;
    new `WORLD_*` tags and a `decode_entity_spawn` helper).

---

## Current reality (as of hardening-pass close, 2026-05-09)

### What works end-to-end (single client)

- **Auth WS**: Register / Login / CharList / CharCreate / CharDelete
  / Logout / RequestWorldToken. Argon2id, 256-bit session tokens.
- **World UDP**: renet 2.0 Secure mode, 20 Hz tick, 60 s checkpoint,
  10 s app-layer heartbeat timeout.
- **Game ↔ World**: launcher hands off via `--world-token-path`
  tempfile, client drives the four-state machine
  (`DISCONNECTED → CONNECTING_TRANSPORT → CONNECTED_TRANSPORT →
  CONNECTED_APP`), periodic 4 s heartbeats, clean shutdown via
  `Net.leave_session()`.
- **Server-authoritative movement (Tracks 1+2 + hardening sub-task 3)**:
  client sends Move at 20 Hz with direction scaled by
  `current_speed / SERVER_MAX_MOVE_SPEED`, server stores latest
  direction on `PerConnection`, integrates **once per tick** in
  `tick.rs` between the message-drain and broadcast phases.
  Stale-input guard (500 ms) zeroes the integrated direction if
  the client goes silent. Client reconciles via snap-or-lerp
  (1.0 m threshold, time-based smoothing rate of 17.3 /sec).
- **Persistence loop**: server saves on disconnect + 60 s checkpoint
  cadence; client reads position from server on next reconnect via
  first-tick snap.

### What's missing for multi-player

- **No EntitySpawn message in the protocol.** `EntityDespawn`
  exists (despawn id only), but there's no companion spawn message
  that carries identity (name, race, class, level) to remote
  clients. Without this, clients can't render other players —
  Position broadcasts arrive with just an EntityId and no way to
  resolve who that is.
- **No fan-out on the server.** `world/tick.rs` step 6 calls
  `handlers::broadcast_position(&mut server, *client_id, conn)`
  for each ready client, sending each client their own position
  only. Track 3 changes this to fan out every ready client's
  position to every ready client (and including self, because
  Track 2's snap-or-lerp depends on receiving own-player
  broadcasts).
- **No spawn/despawn handshake at the transport boundary.** When
  a new client completes `ConnectOk`, no one tells the other
  connected clients about them. When a client disconnects,
  `ServerEvent::ClientDisconnected` fires in `tick.rs` and the
  `PerConnection` is dropped, but no `EntityDespawn` reaches the
  remaining clients.
- **PerConnection lacks race/class.** `db::load_character` returns
  `CharacterSpawn { char_id, account_id, name, level, hp, mp,
  stamina, zone, pos, yaw }` — no race/class fields. The
  `characters` table has them (`0001_init.sql` lines 34-35), just
  unread. Track 3 extends the query.
- **No remote-player rendering on the client.** There's no
  `remote_player.tscn` and no autoload that listens for
  entity_spawn/despawn. `world.gd` only spawns the local player.
- **No snapshot interpolation.** The own-player reconciliation
  pattern (snap-or-lerp) doesn't work for remote players because
  there's no client-side prediction to lerp from; remote players
  need a position buffer + render-time interpolation between the
  two surrounding snapshots.

### Hard layout invariants you must preserve

- `F:\Projects\Project_Dawn\scripts\net\protocol.gd` is **1:1**
  with `F:\Projects\launcher\scripts\net\protocol.gd`. `diff`
  between them returns zero output. Any new wire-tag constants or
  message helpers must be mirrored into both copies in the same
  session, even though the launcher doesn't decode them yet —
  this keeps the two from drifting.
- `addons/gdext_net/gdext_net.dll` is gitignored. Rebuild via
  `addons/gdext_net/build.ps1`. Track 3 **does** rebuild the
  GDExtension (new signals).
- The Rust `protocol` crate is the source of truth for the wire
  format. `WORLD_PROTOCOL_ID` increments on any variant
  add/remove/reorder — Track 3 bumps it.
- `PROJECTDAWN_NETCODE_KEY` must NEVER appear in any commit, log
  line, error message, or test fixture.
- Token files are read-once-then-deleted on the game side. Track 3
  doesn't touch this path.

---

## Track 3 scope

Five sub-tasks. Order suggested below; can be reordered if you have
a reason. Each is small enough to be its own commit (or two). One
commit per logical change per repo. The whole track is probably
two sessions, possibly three depending on debugging.

### Sub-task 1 — Wire format: EntitySpawn variant + race/class load

Add the EntitySpawn message; load race/class into the server's
runtime state so EntitySpawn payloads carry them.

**Architecture decision.** EntitySpawn carries identity fields the
client needs on first sight; ongoing Position broadcasts stay lean.
Payload:

```rust
EntitySpawn {
    id: EntityId,
    name: String,
    race: String,       // e.g. "Troll" — client renders model from this
    class: String,      // e.g. "Shadow Knight"
    level: u32,         // for con-color / nameplate
    pos: Vec3,
    yaw: f32,
}
```

Channel: **CHANNEL_SYSTEM** (reliable ordered) — these are critical
state changes that must arrive. Position stays on
CHANNEL_POSITION (unreliable). Adding EntitySpawn after
`EntityDespawn` in the `ServerWorldMsg` enum is the cleanest
diff (variant order is the bincode discriminator, so appending
is safe; reordering would break the wire).

**WORLD_PROTOCOL_ID bump.** Add 1 to the constant; the
existing value is `0x5044_5f57_3030_3031` (ASCII "PD_W0001"). Bump
to `0x5044_5f57_3030_3032` ("PD_W0002"). The constant is in
`crates/protocol/src/world.rs` and is read by both the
`ConnectToken::generate` call in `world/mod.rs::mint_connect_token`
and the client's `connection_config_matching_server`. Mismatched
IDs ⇒ renet rejects the handshake before any app message lands.

**Files to touch.**

- `crates/protocol/src/world.rs` — add `EntitySpawn` variant to
  `ServerWorldMsg`. Bump `WORLD_PROTOCOL_ID`.
- `crates/projectdawn-server/src/db/mod.rs` — extend `CharacterSpawn`
  with `pub race: String, pub class: String` fields; extend
  `SpawnRow` similarly; extend the `SELECT` in `load_character`.
- `crates/projectdawn-server/src/world/connection.rs` — add
  `pub race: String, pub class: String` to `PerConnection`,
  populated from spawn in `from_spawn`.
- `F:\Projects\Project_Dawn\scripts\net\protocol.gd` — add a tag
  constant for EntitySpawn (mirror existing `WORLD_POSITION` /
  `WORLD_ENTITY_DESPAWN` pattern). Add `decode_entity_spawn(bytes)
  -> Dictionary` helper if other call sites need direct decode;
  most likely the GDExtension does the bincode decode and the
  signal carries typed args, so this helper may not be needed —
  decide once you see how `entity_despawn` (already in the
  protocol enum) is currently exposed. **Mirror any change to
  `F:\Projects\launcher\scripts\net\protocol.gd` in the same
  commit.** `diff` between the two must remain zero.

**Verification.**

1. `cd F:/Projects/server; cargo test --release` — still 6/6
   passing. `world_smoke.rs` doesn't exercise EntitySpawn yet, so
   the existing assertions stand. Build should succeed.
2. `diff F:/Projects/Project_Dawn/scripts/net/protocol.gd
   F:/Projects/launcher/scripts/net/protocol.gd` returns zero
   output.
3. Token mint via `world::mint_connect_token` still works (test
   covers this implicitly via `RequestWorldToken` in
   `world_smoke.rs`).

### Sub-task 2 — GDExtension: decode EntitySpawn + EntityDespawn signals

Expose the two messages as typed signals on `NetClient`.

**Files to touch.**

- `F:\Projects\server\crates\gdext-net\src\lib.rs`:
  - Add `#[signal] fn entity_spawn(id: i64, name: GString, race: GString, class: GString, level: i64, pos: Vector3, yaw: f32);` near the existing `position` signal.
  - Add `#[signal] fn entity_despawn(id: i64);`.
  - In the channel-drain loop (the `match` on decoded
    `ServerWorldMsg`), add arms for `ServerWorldMsg::EntitySpawn`
    and `::EntityDespawn` that build the variant args and emit.
    Use the existing `Pending`-struct pattern to drop the
    `&mut self.client` borrow before the emit so handlers can
    re-enter (Track D session notes explain why).
- Rebuild: `cd F:\Projects\server; cargo build -p gdext-net --release`.
  Output is `target/release/gdext_net.dll`. Copy/move to
  `F:\Projects\Project_Dawn\addons\gdext_net\gdext_net.dll`
  (gitignored — `addons/gdext_net/build.ps1` automates this if you
  prefer).

**Verification.**

- Launch Godot editor on Project_Dawn → no errors on script reload.
- Existing 6/6 cargo tests still pass.

### Sub-task 3 — Server-side fan-out (EntitySpawn, EntityDespawn, Position)

Wire the connection-lifecycle and per-tick broadcast for
multi-player.

**Architecture decision (AOI).** Start with "everyone in the zone
sees everyone in the zone" — no spatial filter. Pre-Steam alpha is
friends-tier; `MAX_CLIENTS = 64`, so worst-case fan-out per tick
is 64² = 4096 sends/tick = 81,920 sends/sec ≈ 4 MB/s at ~50 B
per Position. Manageable. Spatial AOI (grid hash, octree) is a
future track when populations grow. **Decision to confirm with
user before starting** — see open questions.

**Server-side filtering decision.** Each ready client's Position
goes to every ready client **including themselves**. Track 2's
snap-or-lerp depends on the owner receiving their own broadcasts
to drive reconciliation. EntitySpawn/EntityDespawn skip the
subject (a client doesn't get their own spawn message — that's
what `ConnectOk` is for).

**Connection lifecycle (in `tick.rs` step 2):**

`ServerEvent::ClientConnected` arm (after the existing
`db::load_character` and `connections.insert`):

```rust
// Send EntitySpawn for each existing ready connection to the new client.
let new_id = client_id;
for (&existing_id, existing) in connections.iter() {
    if existing_id == new_id { continue; }
    if !existing.ready { continue; }
    handlers::send_entity_spawn(&mut server, new_id, existing);
}
// EntitySpawn for the *new* client to everyone else fires later, on
// app-Connect (in handlers.rs Connect arm) — that's when `ready`
// flips true. See note below.
```

Wait, there's a subtlety: at `ClientConnected` event time, the new
client's `ready` flag is still false (it flips in the app-layer
Connect arm in `handlers.rs`). So:

- **At transport-level connect**: just insert PerConnection. Don't
  broadcast EntitySpawn yet — the new client isn't authenticated
  at the app layer.
- **In `handlers.rs` Connect arm** (after `conn.ready = true`):
  this is where we know identity is settled. Broadcast EntitySpawn
  for `conn` to all other ready clients here. Also send EntitySpawn
  for each existing ready client *to* the new client here, so the
  new client gets the catch-up snapshot in the same tick as their
  ConnectOk.

`ServerEvent::ClientDisconnected` arm (existing handler in
`tick.rs:86-136`): after the existing drain-pending-channel-messages
defensive block, broadcast `EntityDespawn { id: char_id }` to every
**other** ready client. Then the existing `connections.remove`
block runs unchanged.

**Per-tick broadcast (in `tick.rs` step 6):**

Replace the existing loop:

```rust
for (client_id, conn) in connections.iter_mut() {
    if !conn.ready { continue; }
    handlers::broadcast_position(&mut server, *client_id, conn);
}
```

With a fan-out loop:

```rust
let ready_ids: Vec<ClientId> = connections
    .iter()
    .filter(|(_, c)| c.ready)
    .map(|(id, _)| *id)
    .collect();
for sender_id in &ready_ids {
    let sender = connections.get(sender_id).expect("filtered above");
    let pos_msg = handlers::build_position_msg(sender);  // returns Option<Vec<u8>>
    let Some(bytes) = pos_msg else { continue };
    for recipient_id in &ready_ids {
        server.send_message(*recipient_id, CHANNEL_POSITION, bytes.clone());
    }
}
```

Note: `bytes.clone()` per recipient is N² byte copies. For
MAX_CLIENTS=64 and ~50 B per message, that's 64 × 64 × 50 = 200 KB
per tick = 4 MB/s of memcpy. Trivial. If renet exposes a "send to
many" API that batches, use it; otherwise the clone is fine.

**New helper in `handlers.rs`:**

- `pub fn send_entity_spawn(server: &mut RenetServer, recipient_id: ClientId, conn: &PerConnection)` — encodes an `EntitySpawn` for `conn` and sends to `recipient_id` on CHANNEL_SYSTEM.
- `pub fn send_entity_despawn(server: &mut RenetServer, recipient_id: ClientId, id: u64)` — same shape.
- `pub fn build_position_msg(conn: &PerConnection) -> Option<Vec<u8>>` — extract from existing `send_position` so the fan-out loop can encode once and send to many. Existing `broadcast_position(server, client_id, conn)` can become a thin wrapper or be deleted.

**Files to touch.**

- `crates/projectdawn-server/src/world/handlers.rs` — new helpers above. Add an `EntitySpawn` Connect-arm broadcast (see lifecycle decision).
- `crates/projectdawn-server/src/world/tick.rs` — step 2 ClientDisconnected gets a despawn broadcast; step 6 becomes the fan-out loop.

**Verification.**

1. `cargo test --release` 6/6 passing. The existing `world_smoke.rs`
   has one client and Track 2 own-player reconciliation depends on
   the owner receiving Positions, so the fan-out loop must continue
   to send to self. The test should be untouched.
2. Add a new test `world_two_clients.rs` (optional, recommended) —
   spin up two `RenetClient`s connected to one server, drive both
   through app-Connect, assert each receives an EntitySpawn for the
   other and at least one Position broadcast carrying the other's
   id. ~150 lines, adapted from `world_smoke.rs`. Time investment
   is worth it because manual multi-client testing in step 5 is
   slow.
3. Manual: server log shows `tracing::info!("client connected (transport)")` and a fresh `tracing::info!("broadcasting EntitySpawn for char_id=X to N peers")` debug line (add inline during dev, revert before commit).

### Sub-task 4 — Client: Net signals + remote player manager + remote_player scene

Three pieces. Can land as one commit or split if it gets large.

**Piece A — Net adapter signal re-emit.**

In `autoloads/net.gd`, add two new signals near `world_position`:

```gdscript
signal world_entity_spawn(id: int, name: String, race: String, char_class: String, level: int, pos: Vector3, yaw: float)
signal world_entity_despawn(id: int)
```

(`char_class` to avoid shadowing the GDScript reserved word
`class` — same trick used elsewhere in the codebase.)

In `_ready()`, connect the GDExtension signals:

```gdscript
entity_spawn.connect(_on_entity_spawn)
entity_despawn.connect(_on_entity_despawn)
```

Handlers just re-emit on the autoload-level signals.

**Piece B — `scripts/remote_player.gd` + `scenes/remote_player.tscn`.**

New scene with no input handling, no physics integration. Just a
visual avatar with a name label and a position-interpolation buffer.

Recommended scene tree:

```
RemotePlayer (CharacterBody3D, script)
├── MeshInstance3D (capsule, scaled to race height — start with 1.8 m)
└── Label3D (name, billboard, vertical offset +2.1 m)
```

Why `CharacterBody3D`? Same node type as the local player so
collision behaves consistently if/when remote players need to
push each other or block doorways. No collision processing
required for slice 3; just the visual.

Script outline:

```gdscript
extends CharacterBody3D

# Network identity (set by RemotePlayerManager on spawn).
var char_id: int = -1
var player_name: String = ""
var race: String = ""
var player_class: String = ""
var level: int = 1

# Interpolation buffer: array of { time: float, pos: Vector3, yaw: float }
# ordered by time. Kept short (~5 entries).
const BUFFER_CAPACITY := 5
# Render `INTERP_LAG` seconds behind the latest snapshot so we always
# have two snapshots to lerp between. 100 ms = 2 server ticks at 20 Hz.
const INTERP_LAG := 0.1
var _snapshots: Array[Dictionary] = []
var _last_seq: int = -1

func _ready() -> void:
    # Name label setup, race-based mesh swap if mesh assets exist, etc.
    pass

func on_position_update(pos: Vector3, yaw: float, sequence: int) -> void:
    # Channel 1 is Unreliable; drop reorders and dupes.
    if sequence <= _last_seq:
        return
    _last_seq = sequence
    var now := Time.get_unix_time_from_system()
    _snapshots.append({"time": now, "pos": pos, "yaw": yaw})
    if _snapshots.size() > BUFFER_CAPACITY:
        _snapshots.pop_front()

func _physics_process(_delta: float) -> void:
    if _snapshots.size() < 2:
        # Not enough snapshots yet — sit at the most recent or stay put.
        if _snapshots.size() == 1:
            global_position = _snapshots[0]["pos"]
        return
    var target_time := Time.get_unix_time_from_system() - INTERP_LAG
    # Find the snapshot pair straddling target_time.
    var a := _snapshots[_snapshots.size() - 2]
    var b := _snapshots[_snapshots.size() - 1]
    for i in range(_snapshots.size() - 1):
        if _snapshots[i]["time"] <= target_time and _snapshots[i + 1]["time"] >= target_time:
            a = _snapshots[i]
            b = _snapshots[i + 1]
            break
    var span: float = b["time"] - a["time"]
    if span <= 0.0:
        global_position = b["pos"]
        rotation.y = b["yaw"]
        return
    var t: float = clampf((target_time - a["time"]) / span, 0.0, 1.0)
    global_position = a["pos"].lerp(b["pos"], t)
    rotation.y = lerp_angle(a["yaw"], b["yaw"], t)
```

`Time.get_unix_time_from_system()` returns float seconds — fine
for relative timing within a session. If clock-jump robustness
matters later, switch to `Time.get_ticks_msec() / 1000.0` (need
@warning_ignore for integer_division).

**Piece C — Remote player manager.**

New autoload `autoloads/remote_player_manager.gd`. Listens to
`Net.world_entity_spawn` / `world_entity_despawn` /
`world_position`, owns a `Dictionary[int, RemotePlayer]` keyed by
char_id.

```gdscript
extends Node

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")

var _by_id: Dictionary = {}  # char_id -> RemotePlayer node

func _ready() -> void:
    Net.world_entity_spawn.connect(_on_entity_spawn)
    Net.world_entity_despawn.connect(_on_entity_despawn)
    Net.world_position.connect(_on_position)

func _on_entity_spawn(id: int, n: String, r: String, c: String, lvl: int, pos: Vector3, yaw: float) -> void:
    if id == Net.get_player_id():
        return  # own-player spawn is handled by world.gd; ignore.
    if _by_id.has(id):
        return  # already spawned; defensive.
    var rp := REMOTE_PLAYER_SCENE.instantiate()
    rp.char_id = id
    rp.player_name = n
    rp.race = r
    rp.player_class = c
    rp.level = lvl
    rp.global_position = pos
    rp.rotation.y = yaw
    _add_to_active_scene(rp)
    _by_id[id] = rp

func _on_entity_despawn(id: int) -> void:
    if not _by_id.has(id):
        return
    _by_id[id].queue_free()
    _by_id.erase(id)

func _on_position(id: int, pos: Vector3, _vel: Vector3, yaw: float, sequence: int) -> void:
    if id == Net.get_player_id():
        return  # own-player; handled by player.gd
    var rp = _by_id.get(id)
    if rp == null:
        return  # Position before EntitySpawn — should be rare with reliable spawn channel.
    rp.on_position_update(pos, yaw, sequence)

func _add_to_active_scene(rp: Node) -> void:
    # Add as child of the current scene's root, NOT the autoload. Remote
    # players are scene-scoped; they should be freed on scene change.
    var scene := get_tree().current_scene
    if scene == null:
        push_warning("RemotePlayerManager: no current scene to parent into")
        rp.queue_free()
        return
    scene.add_child(rp)

func clear_all() -> void:
    # Called by world.gd._exit_tree or zone transitions.
    for id in _by_id:
        _by_id[id].queue_free()
    _by_id.clear()
```

Register in `project.godot` autoloads. Naming: `RemotePlayerManager`
to match the existing convention (PlayerStats, BuffManager, etc.).

**Files to touch.**

- `F:\Projects\Project_Dawn\autoloads\net.gd` — two new signals + handlers.
- `F:\Projects\Project_Dawn\scenes\remote_player.tscn` — new scene.
- `F:\Projects\Project_Dawn\scripts\remote_player.gd` — new script.
- `F:\Projects\Project_Dawn\autoloads\remote_player_manager.gd` — new autoload.
- `F:\Projects\Project_Dawn\project.godot` — register autoload.

**Verification (manual, no smoke test yet):**

1. F5 from Godot editor (no launcher mode) → Test Room. Console
   should be quiet — no remote players, no errors. The new manager
   listens for Net signals but Net stays idle in local-save mode,
   so nothing fires.
2. Launch via launcher → Enter World. Same single-player feel as
   Track 2. RemotePlayerManager is wired but has no events to
   react to with one client. Console shows no warnings.

### Sub-task 5 — Multi-client verification (two .exe instances)

The end-to-end test. No code changes — just running and observing.

**Setup.**

1. Server running in one PowerShell window:
   ```
   cd F:/Projects/server; cargo run -p projectdawn-server 2>&1 | Tee-Object -FilePath server.log
   ```
2. Two PowerShell windows for two game instances. In each, set the
   console exe so stdout is visible:
   ```
   $env:PROJECTDAWN_EXE = "F:/Projects/Project_Dawn/builds/ProjectDawn.console.exe"
   ```
3. Open `F:/Projects/launcher/project.godot` in Godot editor. F5
   the launcher.
4. In the launcher, create two test accounts (or use one account
   with two characters). For each:
   - Log in.
   - Pick the character.
   - Click Play.
   - The game .exe spawns — switch to it.
5. With both game windows open and connected, walk one with WASD.

**Expected behavior.**

- Both clients see each other render as a capsule with a name
  label.
- Walking one client moves their avatar smoothly on the other
  client's screen (no rubber-banding, no teleporting, ~100 ms of
  interpolation lag is fine and feels MMO-typical).
- Closing one window: the other window should drop the remote
  player node within ~50 ms (one server tick) — server processes
  the app-layer Disconnect, broadcasts EntityDespawn, the other
  client's `RemotePlayerManager._on_entity_despawn` fires and
  frees the node.
- Server log (`server.log`) shows two `client connected (transport)`
  lines, two `client requested disconnect` lines on closes, and
  no `app-layer heartbeat timeout` lines (would indicate a stuck
  client).

**Failure modes to watch for.**

- **Remote player appears, then drifts off in a straight line.**
  Means snapshot interpolation is using stale snapshots — likely
  a bug in `on_position_update` not advancing `_last_seq`, or the
  buffer growing without bound.
- **Remote player teleports on every server tick.**
  INTERP_LAG too small (interpolating into the future). Should
  always have two snapshots in the past.
- **Position broadcasts arrive before EntitySpawn.**
  Race condition between unreliable-channel Position (channel 1)
  and reliable-ordered EntitySpawn (channel 0). EntitySpawn
  reliable-ordered should arrive first, but Unreliable can
  occasionally beat it across channels. Mitigation: spawn a
  placeholder on first Position with no matching EntitySpawn,
  fill in identity when the spawn arrives. Or: just log-and-drop
  the Position; the next tick's Position will find the spawned
  node. Recommend log-and-drop for slice 3.
- **Remote player despawned but Positions still arrive for them.**
  Server-side race between `connections.remove` and the broadcast
  loop. Should be fine because both are in the same tick task on
  the same thread, but watch the log.

---

## Verification plan summary

End of Track 3, all of these should be true:

- [ ] `cargo test --release` 6/6 (or 7/7 if you add `world_two_clients.rs`).
- [ ] Two .exe instances connected to one server render each other.
- [ ] Walking one moves the other client's view of them smoothly.
- [ ] Closing one cleanly despawns it on the other.
- [ ] Server log shows clean lifecycle (connect → spawn-broadcast →
      position fan-out → despawn-broadcast → disconnect) for both
      clients.
- [ ] No new GDScript warnings introduced (count stays at 11, all
      in enemy.gd).
- [ ] No new clippy warnings on server.

**Commits expected** (rough plan, adjust as you go):

- 1 commit in server for sub-task 1 (protocol + race/class load).
- 1 commit in Project_Dawn + launcher for sub-task 1 (protocol.gd mirror).
- 1 commit in server for sub-task 2 (gdext-net signals).
- 1 commit in server for sub-task 3 (fan-out + lifecycle broadcasts).
- 1 commit in Project_Dawn for sub-task 4A (Net signal re-emit).
- 1 commit in Project_Dawn for sub-task 4B+C (remote_player scene + manager).
- 1 commit in Project_Dawn for session notes.

~7 commits across 2-3 repos. Don't bundle. Track 3 is bigger than
the hardening pass (about 2× the surface area) but each sub-task
is well-contained.

---

## Hard rules (carry forward, do not relax)

### Project_Dawn — files you must NOT modify

- `CLAUDE.md`
- `addons/procedural_dungeon/` (the embedded copy)
- `scripts/enemy.gd` (user iterates on it directly between sessions)
- `docs/concepts/world/maps/`
- `docs/reference/`
- `docs/playtest_notes/testing_notes_2026_05_02.md`
- `docs/playtest_notes/testing_notes_2026_05_05.md`
- `docs/playtest_notes/testing_notes_2026_05_06.md`

### Cross-repo invariants

- **`scripts/net/protocol.gd` MUST stay 1:1** between `Project_Dawn`
  and `launcher`. Track 3 adds new tag constants and possibly
  helpers; mirror to both copies in the same session. `diff`
  reports zero output is the contract.
- **The Rust `protocol` crate is canonical.** `WORLD_PROTOCOL_ID`
  bumps on any wire-format break. Track 3 bumps it once.
- **`PROJECTDAWN_NETCODE_KEY` is sacred.** Never logged, committed,
  or in test fixtures as a constant.
- **Token files are read-once-then-deleted on the game side.**
  Track 3 doesn't touch this path.
- **The `gdext_net.dll` is gitignored.** Track 3 rebuilds it once
  (new signals); don't commit the binary.

### Process

- **Match commit-message tone per repo.** Run `git log --oneline -5`
  in each before writing one. HEREDOC body, blank line,
  Co-Authored-By footer.
- **One commit per repo per logical change.** Don't bundle the
  five sub-tasks into one giant commit.
- **Pause and ask** before any destructive git operation, before
  pushing to a remote, before touching files outside the agreed
  scope.
- **User runs Windows / PowerShell.** Use the Bash tool for POSIX
  scripts, PowerShell tool for native Windows ops.
- **Session notes after the session.** Append to
  `docs/session_notes/session_YYYY_MM_DD.md` and update
  `docs/session_notes/README.md` index. Five sub-tasks across two
  repos clears the threshold.
- **User wants terse responses; no end-of-task recaps or change
  summaries.** Brief progress updates are fine; long victory laps
  are not.

### Build / test workflow

- Server: `cd F:/Projects/server; cargo test --release` should be
  6/6 (7/7 if you add the two-client integration test).
- Server runtime: `cargo run -p projectdawn-server 2>&1 |
  Tee-Object -FilePath server.log` — the user runs this; you read
  the log.
- GDExtension rebuild: `cd F:\Projects\server; cargo build -p
  gdext-net --release`. Output at
  `target/release/gdext_net.dll`. Project_Dawn loads it from
  `addons/gdext_net/gdext_net.dll` — copy or move after build.
  `addons/gdext_net/build.ps1` automates this.
- Game export: Project → Export → Windows Desktop preset → Export
  Project → `builds/ProjectDawn.exe` (also produces `.console.exe`
  for diagnostics).
- Launcher run: open `F:/Projects/launcher/project.godot` in Godot
  4.4, F5.
- Console build: `$env:PROJECTDAWN_EXE =
  "F:/Projects/Project_Dawn/builds/ProjectDawn.console.exe"` in the
  PowerShell window where the launcher's Godot editor runs, so the
  game's stdout is visible.

---

## Open questions to ask the user before writing code

1. **AOI strategy** — start with "everyone in the zone sees
   everyone in the zone" (no spatial filter, fan-out is O(N²))? At
   MAX_CLIENTS=64 worst case this is ~4 MB/s outbound — fine for
   pre-Steam alpha. Spatial AOI (grid hash) is a future track.
   Confirm the simple approach is OK for slice 3.
2. **Interpolation lag** — handoff recommends 100 ms (2 server
   ticks at 20 Hz). 50 ms is more responsive but riskier (a single
   dropped Position empties the buffer); 150 ms is smoother but
   feels more sluggish. Confirm 100 ms or pick another.
3. **Remote player scene complexity** — capsule + name label is
   the minimum and matches the current player look. Should remote
   players use the same `player.tscn` (full character with
   collision) just with input disabled, or a stripped-down
   `remote_player.tscn`? Stripped-down is cleaner; using
   player.tscn means future model-swap work happens once instead
   of twice. Recommend stripped-down for slice 3; revisit when
   character models replace capsules.
4. **Two-client integration test (`world_two_clients.rs`)** —
   recommended (cleaner verification + caught regressions early)
   but adds ~150 lines of test code. Manual two-window testing is
   the alternative. Confirm whether to invest in the integration
   test.
5. **Server live during the session?** Sub-tasks 3-5 need the
   server running. Same `Tee-Object` log workflow as the
   hardening pass.
6. **`enemy.gd` warnings** — still on the no-modify list, still
   11 outstanding. Track 3 doesn't touch them. Confirm.

---

## Quick reference — key files & autoloads

### Project_Dawn (game client)

- `autoloads/net.gd` — Net adapter. Add `world_entity_spawn` and
  `world_entity_despawn` signals; wire them from GDExtension
  signals. (Sub-task 4A.)
- `autoloads/remote_player_manager.gd` — NEW autoload. Listens for
  spawn/despawn/position, manages a Dictionary[char_id → node].
  (Sub-task 4C.)
- `scenes/remote_player.tscn` — NEW scene. CharacterBody3D +
  capsule + name label, no input, no physics integration.
  (Sub-task 4B.)
- `scripts/remote_player.gd` — NEW. Position interpolation buffer,
  `_physics_process` renders at `now - INTERP_LAG`. (Sub-task 4B.)
- `scripts/net/protocol.gd` — MUST stay 1:1 with launcher copy.
  Add EntitySpawn tag constant + decode helper if needed.
  (Sub-task 1, mirror to launcher in same commit.)
- `scripts/player.gd` — DO NOT modify. Track 2's
  `_on_world_position` already filters to own player; confirm
  this still works after server fan-out (it should — server now
  sends Positions for all players, and the existing
  `if id != Net.get_player_id(): return` guard drops the
  non-self ones).
- `project.godot` — register the new RemotePlayerManager autoload.
- `addons/gdext_net/gdext_net.dll` — rebuilt artifact. Gitignored.
  Replace from `F:/Projects/server/target/release/gdext_net.dll`.

### Server

- `crates/protocol/src/world.rs` — add `EntitySpawn` variant to
  `ServerWorldMsg`; bump `WORLD_PROTOCOL_ID`. (Sub-task 1.)
- `crates/projectdawn-server/src/db/mod.rs` — extend `CharacterSpawn`
  + `SpawnRow` + `load_character` query to include race / class.
  (Sub-task 1.)
- `crates/projectdawn-server/src/world/connection.rs` — add
  `race` / `class` fields to `PerConnection`. (Sub-task 1.)
- `crates/gdext-net/src/lib.rs` — new `entity_spawn` /
  `entity_despawn` signals; decode arms in the channel-drain
  match. (Sub-task 2.)
- `crates/projectdawn-server/src/world/handlers.rs` — new
  `send_entity_spawn` / `send_entity_despawn` / `build_position_msg`
  helpers; EntitySpawn broadcast in the Connect arm. (Sub-task 3.)
- `crates/projectdawn-server/src/world/tick.rs` — ClientDisconnected
  arm broadcasts EntityDespawn; step 6 (broadcast) becomes the
  fan-out loop. (Sub-task 3.)
- `crates/projectdawn-server/tests/world_smoke.rs` — DON'T modify.
  (Sub-task 3 adds optional `world_two_clients.rs` alongside.)

### Launcher

- `scripts/net/protocol.gd` — MUST stay 1:1 with game copy.
  Mirror the protocol additions in the same commit. (Sub-task 1.)

### Procedural dungeon

No changes expected. Track 7 is the integration milestone for
dungeons-in-world.

---

## Begin by

1. Read the 11 files in the "Read these in order" section.
2. Run `git -C <each repo> log --oneline -5` to confirm state
   matches the table at the top.
3. Read the open questions and ask the user. The AOI strategy and
   the interpolation lag in particular need user input before code
   lands.
4. Confirm the server is running. If not, restart together at the
   start of the session.
5. Implement sub-task by sub-task. After each, run its
   verification. **Don't stack multiple unverified changes** — the
   wire-format bump in sub-task 1 alone can break everything if
   the GDScript mirror drifts, and you want to catch that before
   the fan-out work piles on top.
6. After the session, write notes in
   `docs/session_notes/session_YYYY_MM_DD.md` and update the index
   in `docs/session_notes/README.md`.

**Do not start writing code until the user has answered the open
questions specific to whichever sub-task you start with.** The
protocol bump is small but irreversible-feeling once it's been
committed; AOI strategy bakes assumptions into the tick loop;
interpolation lag is a feel decision that's hard to retune later.
Ask first.
