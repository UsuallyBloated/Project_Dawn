# Track 2 Handoff — Server-Authoritative Movement

You're picking up Project Dawn — a Godot 4.4 / GDScript MMORPG client, its
companion Rust server (auth WebSocket + world UDP), a Godot launcher,
and a standalone procedural dungeon generator that will be folded into
the game later. Four repos, four branches; the table below shows the
state at handoff.

Track 1 closed earlier this session. The slice-1 verification step left
out of Track D is now done: WASD movement reaches the world server as
`Move` intents, and window close produces a clean `client requested
disconnect` line on the server log instead of waiting 10 s for a
heartbeat-timeout kick. Track 2 wires up the **other half** of the
server-authoritative loop — the client honouring the server's
broadcast `Position` as truth.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `08c00c3` (Track 1: WASD-Move plumbing + clean window-close disconnect) |
| Server | `F:\Projects\server\` | `main` | `1aab275` (world/tick.rs: drain pending channel messages before evicting connection) |
| Launcher | `F:\Projects\launcher\` | `main` | `9a0ddb8` (Play flow: RequestWorldToken + temp-file handoff) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `774d73e` (session_notes index) |

Run `git -C <each> log --oneline -5` before touching anything to confirm
the state still matches.

## Read these in order

1. `F:\Projects\Project_Dawn\CLAUDE.md` — project conventions, autoload
   map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_08.md` —
   yesterday's Track 1 session notes. Especially the "Clean window-close
   disconnect — five rounds to find the right shape" section: relevant
   to Track 2 because it explains why `Net.leave_session()` no longer
   calls `disconnect_now()`, and the ordering quirks of renet 2.0's
   `transport.update()` vs. tick.rs event/message phases. Track 2 won't
   touch the disconnect path, but you'll see references to it.
3. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_06.md` —
   covers Track A through Track D (protocol mirror, launcher, world UDP
   server, gdext-net adapter). Comprehensive backstory.
4. `F:\Projects\server\docs\server_design.md` — wire-protocol contract.
   §6 (wire protocol), §8 (tick model & simulation), §9 (persistence
   cadence), §19 (client migration path) are the most relevant for
   Track 2.
5. `F:\Projects\Project_Dawn\autoloads\net.gd` — the live net adapter.
   Signal you'll subscribe to: `world_position(id: int, pos: Vector3,
   vel: Vector3, yaw: float, sequence: int)`. Helpers you'll lean on:
   `is_app_ready()`, `is_launcher_mode()`, `get_player_id()`.
6. `F:\Projects\Project_Dawn\scripts\player.gd` — main work site for
   Track 2.
7. `F:\Projects\server\crates\projectdawn-server\src\world\handlers.rs`
   — see the `Move` arm and `broadcast_position`. This is what's
   already running on the wire; you don't need to change it for slice
   2 but you'll want to understand it.
8. `F:\Projects\server\crates\projectdawn-server\src\world\tick.rs` —
   broadcast loop near the bottom calls `handlers::broadcast_position`
   for each ready client every 50 ms tick.

---

## Current reality (as of Track 1 close)

### Uplink (client → server) is wired

- Client `_physics_process` builds a unit `direction` from WASD input
  (`scripts/player.gd:174-198`).
- After velocity-tween, `Net.send_movement(direction, false)` fires
  every physics tick (~60 Hz) when `Net.is_app_ready()`
  (`scripts/player.gd:200-201`).
- `Net.send_movement` auto-increments a sequence number, calls
  `NetClient.send_move(seq, direction, jumping)` on the GDExtension.
- Server's `handlers::handle_message` Move arm clamps direction to
  unit length, applies `MAX_MOVE_SPEED = 7.5 m/s × TICK_DT = 50 ms`
  per tick, and updates `conn.pos`. Out-of-order sequences are
  dropped via `last_move_seq`.
- Verified in Track 1: 1077 packets in a 17 s test, real-direction
  values from sequence 54 onwards, server processed all of them.

### Downlink (server → client) is broadcasting but ignored

- Server's `broadcast_position` sends `Position { id, pos, vel, yaw,
  sequence }` on channel 1 (Unreliable) every 50 ms tick to each
  ready client. For slice 1 with one player, this is just an echo
  back to the owner.
- The GDExtension decodes incoming `Position` and emits the
  `position(id, pos, vel, yaw, sequence)` signal.
- `autoloads/net.gd` re-emits as `world_position(id, pos, vel, yaw,
  sequence)` (see `_on_position` in net.gd).
- **No subscriber.** The signal fires every 50 ms into the void.
  `player.gd` continues to drive its own position client-
  authoritatively from input.

### Disconnect is clean (Track 1 result)

OS X-button on the game window → `Window.close_requested` signal →
`Net._on_close_requested` → `Net.leave_session()` → app-layer
Disconnect + 4× `poll(0.05)` to flush. **No `disconnect_now()`** —
the OS closes the UDP socket on process exit, and skipping the
netcode-level disconnect avoids racing the app message at the server.
Server logs both `client requested disconnect` and `client
disconnected (transport) reason=DisconnectedByServer`. Don't change
this; just be aware Track 2 happens within the existing connection.

### Local-save mode unchanged

Without launcher CLI args, `Net` autoload sits idle. `Net.is_app_ready()`
returns false. Existing client-authoritative flow drives gameplay
(lobby → Test Room / Test Dungeon / local Host-Game-Join-Game ENet).
Track 2 must not break this — your reconciliation code runs only when
`Net.is_app_ready()` is true.

---

## Track 2 scope

The headline change is short: **subscribe to `Net.world_position`,
reconcile local position toward server truth.** Getting the feel right
takes a few subtleties documented below.

### Architecture: prediction + reconciliation (snap-or-lerp variant)

Every modern MMO uses some form of client-side prediction plus server
reconciliation. The full version stores a ring buffer of `(sequence,
predicted_pos)` and rewinds/replays subsequent inputs when the server's
authoritative position at a given sequence diverges from prediction.

For slice 2, **snap-or-lerp is enough**. Don't build the input-replay
machinery yet. The simpler version:

1. Client predicts movement locally each frame (no input lag —
   `move_and_slide` runs every physics tick exactly as today).
2. Client sends Move intent every physics tick (already wired in
   Track 1).
3. Server processes intent, updates `conn.pos`, broadcasts
   `Position` at 20 Hz.
4. Client receives `Position(id, pos, vel, yaw, sequence)`:
   - If `id != Net.get_player_id()`: ignore (other-player
     replication is Track 3 — for slice 2 this case shouldn't
     arise, but the filter is cheap and future-proofing).
   - Compute horizontal distance between server `pos` and current
     local `global_position` (X/Z only, ignore Y).
   - If distance > `SNAP_THRESHOLD` (start with **1.0 m**): snap
     local position to server pos.
   - Otherwise: lerp local position toward server pos at some
     fraction per frame (start with **0.25** = 25%).
5. Local input keeps driving prediction; the lerp blends two equally
   valid futures — predicted and server-truth.

That's the whole thing. Don't disable local prediction. Don't build
input replay. Don't extrapolate other players' positions yet.

### Y-axis: leave to the client

The server has no physics. `conn.pos.y` integrates `direction.y *
MAX_MOVE_SPEED * dt`, but the client builds `direction` from
`transform.basis.x` and `transform.basis.z` only — Y stays zero. So
server `conn.pos.y` is pinned at the spawn value forever. Meanwhile
the client handles gravity, jumping, and fall damage locally.

**Slice 2 reconciles only X and Z.** Snap threshold and lerp apply on
the horizontal plane only:

```gdscript
var horiz := Vector2(server_pos.x - global_position.x, server_pos.z - global_position.z).length()
```

Leave Y entirely client-side. If the player jumps, server `pos.y` is
"wrong" but slice 2 doesn't care. Server physics is a much later
track. Add a comment in the reconciliation code so the assumption is
visible:

```gdscript
# Slice 2: server has no Y-axis physics (no gravity, no jumping).
# Reconcile X/Z only. Y stays under local control until server-side
# physics lands (out of scope for current track).
```

### Don't break local-save mode

Reconciliation runs only when `Net.is_app_ready()` is true. In
local-save mode `world_position` never fires (autoload sits idle), so
strictly speaking this is automatic. But the new `_on_world_position`
handler should also no-op defensively when not in launcher mode, in
case some future code path emits the signal in error.

`autoloads/save_manager.gd` — there's a separate concern. `SaveManager`
writes `PlayerStats.position` (or whatever the field is named —
confirm with a grep) to the save file. In launcher mode, the server
is the saver: `world/persistence.rs` checkpoints position every 60 s
and on disconnect. If the local SaveManager also writes position,
then on next login the local file's stale position will override the
server's authoritative position when `PlayerStats` reconstitutes.

**Fix:** add a `Net.is_launcher_mode()` gate around the position-write
path in save_manager.gd. Don't disable the entire `SaveManager.save()`
in launcher mode — there are other fields (alignment, quest state,
inventory pre-server-tracks) that aren't yet on the server and should
still save locally. Just the position field(s) — find them with a
grep, gate them individually, leave a comment.

If you find this gating is fiddly because position is bundled with
other state into a single dict that gets dumped wholesale, the
cleanest workaround is to have SaveManager write position but have
PlayerStats _ignore_ the persisted position field at load time when
`Net.is_launcher_mode()` is true. Pick the option that touches the
fewest call sites.

### Files involved

**`scripts/player.gd`** — main work site.
- `_ready()`: connect to `Net.world_position` near the existing setup
  block. Connection is always safe; the signal fires only when the
  autoload is in launcher mode.
- New handler `func _on_world_position(id: int, pos: Vector3, vel: Vector3, yaw: float, sequence: int) -> void`:
  - Filter to own player ID via `Net.get_player_id()`.
  - Track latest server pos in a member var `_server_pos_target: Vector3`.
  - Track sequence to gate against out-of-order broadcasts (channel 1 is Unreliable; reorders happen). If `sequence < _last_server_seq`, ignore.
  - Decide snap vs lerp on horizontal distance vs `SNAP_THRESHOLD`.
- `_physics_process(delta)`: after the existing physics step (after
  `move_and_slide()`), blend horizontal `global_position` toward
  `_server_pos_target` using the lerp factor. Skip if not in launcher
  mode (`if not Net.is_app_ready(): return` early in the lerp block).

**`scripts/net_player_sync.gd`** (optional, new) — extract
reconciliation state into a small `RefCounted` helper if `player.gd`
gets crowded. For slice 2, inline is probably fine. Decision:
threshold is "if it adds more than ~30 lines to player.gd and they
form a cohesive cluster, extract." Otherwise inline.

**`autoloads/save_manager.gd`** — gate position writes (or position
loads) behind `Net.is_launcher_mode()`. Read once with grep first to
find the relevant fields.

**No server changes.** The Position broadcast is already firing every
tick. `cargo test --release` should still report 6/6 passing after
the session.

### Constants to define (in `scripts/player.gd`)

```gdscript
# Track 2 — server-authoritative movement reconciliation.
# Snap if local position diverges from server by more than this
# (horizontal, X/Z plane). Below the threshold, lerp toward server
# truth at SERVER_LERP_FACTOR per physics frame.
const SERVER_SNAP_THRESHOLD := 1.0  # metres
const SERVER_LERP_FACTOR := 0.25    # fraction per frame
```

Tune by feel. 0.25 / frame at 60 fps converges 95% in ~10 frames
(~167 ms), well under one server tick (50 ms × ~3 ticks). 1.0 m snap
catches teleports while letting local prediction breathe.

### Hard things to get right

- **Snap threshold tuning.** Too tight (0.5 m) → visible teleports
  on minor network burps. Too loose (2.0 m) → lets local prediction
  drift far before correction. Start 1.0 m; playtest by walking in
  circles around the spawn area; adjust if you see jitter or
  teleports under normal load.

- **Lerp factor tuning.** Too low (0.05) → sluggish drift correction
  visible as a slow rubber-band. Too high (0.6) → fights local
  prediction every frame, feels like ice. 0.25 is a reasonable
  starting point.

- **Out-of-order broadcasts.** Channel 1 is Unreliable. Two Position
  packets can arrive out of sequence. Track `_last_server_seq` and
  drop older sequences silently — same pattern as `last_move_seq` on
  the server side.

- **First-tick spawn.** When the player connects, `ConnectOk`
  arrives before the first `Position` broadcast (~50 ms gap). The
  client briefly stands at the local spawn point, then snaps/lerps
  to the server's authoritative spawn (loaded from DB at
  `ClientConnected` time). If they differ wildly (different scene,
  different floor — though this shouldn't happen for slice 2's Test
  Room flow), the snap is visible.

  Optional belt-and-suspenders: track `_received_first_pos: bool` and
  snap unconditionally on the first broadcast. Cheap insurance; do
  it if first-spawn jitter is noticeable.

- **Decoupling input from movement.** Today `player.gd` translates
  input directly into velocity → `move_and_slide`. Once
  server-authoritative, input is *intent* (sent to server via
  `Net.send_movement`) and position is *display* (lerps toward
  server). For slice 2, **leave the input-driven physics in place
  AS WELL** — the lerp pulls horizontally toward server-truth
  concurrently with local physics. Both happen each frame; they
  blend. The full decoupling (delete local prediction entirely,
  display only what server says) lands in a much later track when
  server physics are richer (collision, jumping, gravity).

- **Save manager position writes.** Easy to forget; will silently
  break next-login position if missed. Add a regression check: walk
  far from spawn in launcher mode, log out, log back in, expect to
  appear at the last server-checkpointed position (within 60 s of
  the last checkpoint), not the local-save position.

### Out of scope (later tracks)

- **Other-player replication** (`EntitySpawn` / `EntityDespawn` /
  AOI-filtered Position broadcasts to peers within ~100 m) — Track 3.
  Server has no fan-out beyond the owner today. Slice 2 still has
  one player at a time on the world.
- **Server-side jump / gravity / collision physics** — much later.
  Server is a kinematic integrator only.
- **Input replay reconciliation** (rewind to historical sequence,
  replay subsequent inputs) — fancier slice. For Track 2, snap-or-lerp.
- **Position interpolation between server snapshots for smoothing**
  (50–100 ms display buffer, classic snapshot interpolation pattern)
  — Track 3 problem when other-player replication lands. Slice 2 is
  the local player only.

---

## Verification plan

1. **Build / export:**
   - Server: no Rust changes expected. `cd F:/Projects/server && cargo
     test --release` should remain 6/6 passing. Run the server with
     `cargo run -p projectdawn-server 2>&1 | Tee-Object -FilePath
     server.log` (the `.env` file at `F:/Projects/server/.env` provides
     `PROJECTDAWN_NETCODE_KEY` automatically — see Track 1 notes).
   - Game: re-export via Project → Export → Windows Desktop → Export
     Project. Output at `F:/Projects/Project_Dawn/builds/ProjectDawn.exe`.

2. **Smoke test single-client reconciliation:**
   - Launcher → Play → land in lobby → click **Test Room**.
   - Walk in circles, walk in straight lines, jump, walk into walls.
     Player should move smoothly with no visible jitter, rubber-banding,
     or teleports under normal play.
   - You won't see the lerp visually if it's tuned right — that's the
     point. The check is "no rubber-banding, no jitter, no fighting
     between local prediction and server pull."

3. **Force a divergence:**
   - Add a transient `print` in `_on_world_position` after the snap-vs-
     lerp decision: `print("server delta: ", horiz, " action: ",
     "SNAP" if horiz > SERVER_SNAP_THRESHOLD else "lerp")`.
   - Run the test, walk normally — should see "lerp" lines with
     `horiz` < 0.5 m most of the time (local prediction running ahead
     of server, lerp pulling back).
   - Optional: temporarily increase `MAX_MOVE_SPEED` in
     `crates/projectdawn-server/src/world/mod.rs` to something high
     (say 30 m/s), restart server, run client. Server now thinks the
     player can move much faster than the client predicts. After a
     few moves you should see `SNAP` lines (server has run far ahead
     of local prediction). Revert the speed change.

4. **Persistence / next-login regression:**
   - Walk to a clearly-not-spawn location in launcher mode.
   - Wait > 60 s (server checkpoint interval) so server saves position.
     Or trigger a clean disconnect via X button (`world/connection.rs`
     final save runs on `ClientDisconnected`).
   - Quit, re-launch via launcher, observe spawn location. Should be
     the last server-checkpointed position, not local-save's stale
     position. If you appear at local-save's position, the save_manager
     gate isn't working.

5. **Local-save mode regression:**
   - Run the game directly (without launcher) → lobby → Test Room.
     Should behave exactly as before Track 2 — local prediction only,
     no server lerp visible (signal never fires). Save should still
     write position locally.

6. **Disconnect path regression:**
   - Walk → close window with X → check server log for `client
     requested disconnect char_id=N` followed by `reason=DisconnectedByServer`.
     Same as Track 1 close.

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
  `launcher`.** Diff at commit time: zero output. Track 2 doesn't
  touch protocol.gd, but if for any reason you find yourself doing so,
  update both copies in the same session.
- **The Rust `protocol` crate is canonical.** Add a wire type there
  first; mirror to GDScript second. Never the other way around. Track
  2 doesn't add wire types.
- **`PROJECTDAWN_NETCODE_KEY` is sacred.** Never logged, never
  committed, never in a test fixture as a constant. Tests use
  `OsRng::fill_bytes` per-test keys.
- **Token files are read-once-then-deleted on the game side.** Track
  2 doesn't touch this path.
- **The `gdext_net.dll` is gitignored.** Track 2 won't rebuild it.

### Process

- **Match commit-message tone per repo.** Run `git log --oneline -5`
  in each before writing one. HEREDOC body, blank line, Co-Authored-By
  footer.
- **One commit per repo per logical change.** Don't bundle cross-repo
  changes into a single repo's commit. Track 2 should be one commit
  in Project_Dawn (no server changes expected).
- **Pause and ask** before any destructive git operation, before
  pushing to a remote, before touching files outside the agreed scope.
- **User runs Windows / PowerShell.** Use the Bash tool for POSIX
  scripts, PowerShell tool for native Windows ops. Backtick line
  continuation, `$env:NAME` for env vars, `;` not `&&` for chaining.
- **Session notes after a session that touches 3+ files or modifies
  a core system.** Append to `docs/session_notes/session_YYYY_MM_DD.md`
  in `Project_Dawn`, update the index in `docs/session_notes/README.md`.
  Track 2 will hit this threshold; plan to write notes.
- **User wants terse responses; no end-of-task recaps or change
  summaries.** Brief progress updates are fine; long victory laps
  are not. State results, ship the change.

### Build / test workflow

- Server: `cd F:/Projects/server && cargo test --release` should
  remain 6/6 (Track 2 has no server changes). If it drops, you broke
  something unrelated to scope; investigate.
- GDExtension rebuild (Track 2 won't need this):
  `F:/Projects/Project_Dawn/addons/gdext_net/build.ps1`
- Game export: Project → Export → Windows Desktop preset → Export
  Project → `builds/ProjectDawn.exe` (also produces `.console.exe`
  for diagnostics).
- Launcher run: open `F:/Projects/launcher/project.godot` in Godot
  4.4, F5. The launcher's "Play" button spawns whichever exe matches
  `PROJECTDAWN_EXE` env var, then sibling `ProjectDawn.exe`, then
  the dev fallback at `F:/Projects/Project_Dawn/builds/ProjectDawn.exe`.

---

## Open questions to ask the user before writing code

1. **Snap threshold:** start with `SERVER_SNAP_THRESHOLD = 1.0 m` or
   different? Looser (2.0) is more forgiving on flaky networks;
   tighter (0.5) catches drift sooner. Default to 1.0 unless the
   user has a preference.
2. **Lerp factor:** start with `SERVER_LERP_FACTOR = 0.25` per frame
   or different? At 60 fps that's ~167 ms to converge to within 5%
   of server truth, which is roughly invisible. Tighter (0.4)
   converges faster but may fight prediction. Looser (0.15) is
   smoother but slower correction.
3. **First-tick spawn handling:** unconditional snap on the first
   `Position` broadcast (recommended), or use the same threshold as
   subsequent broadcasts? Recommended to snap unconditionally on
   first since the local spawn and server spawn can differ.
4. **save_manager gate strategy:** prefer field-level gating in
   save_manager.gd (write everything except position when in launcher
   mode) or load-time gating in PlayerStats (always write, but ignore
   position field on load when in launcher mode)? User decides; one
   touches more code, the other is more "trust the load path."
5. **Server live during the session?** If the user has the server
   running with `Tee-Object` to a log, you can read
   `F:/Projects/server/server.log` to verify behavior. Otherwise
   restart it together at the start.
6. **Local-save flow must keep working** unless the user explicitly
   greenlights retiring it. Even after the server is fully
   feature-complete, local-save is a useful dev-iteration mode.

---

## Quick reference — key files & autoloads

### Project_Dawn

- `autoloads/net.gd` — Net adapter (extends `NetClient` GDExtension
  class); exposes `world_position` signal, `is_app_ready()`,
  `is_launcher_mode()`, `get_player_id()`, `send_movement(dir, jumping)`.
- `scripts/player.gd` — main work site for Track 2; reconciliation
  logic lands here.
- `scripts/cli_args.gd` — launcher CLI arg parser; you won't touch
  this for Track 2.
- `scripts/net/protocol.gd` — wire-format constants + builders;
  Track 2 doesn't add or change wire types.
- `addons/gdext_net/` — Rust GDExtension bundle; you won't rebuild
  for Track 2.
- `autoloads/save_manager.gd` — local persistence; needs gating in
  launcher mode.
- `autoloads/zone_loader.gd` — zone transitions; out of scope for
  Track 2 (the game has only one zone in Test Room flow).
- `autoloads/player_stats.gd` — holds `level`, `hp/mp/stamina`,
  `position` (or equivalent — grep to confirm field name); may
  participate in the save_manager gate decision.
- `data/spell_definitions.gd`, `data/quest_definitions.gd`,
  `data/dialogue_definitions.gd`, `data/loot_tables.gd`,
  `data/named_mob_definitions.gd` — content data; out of scope for
  Track 2.

### Server

- `crates/protocol/src/auth.rs` — auth WS messages (JSON); no Track 2
  changes.
- `crates/protocol/src/world.rs` — world UDP messages (bincode); no
  Track 2 changes. `Position { id, pos: Vec3f, vel: Vec3f, yaw: f32,
  sequence: u32 }` is what the client receives.
- `crates/projectdawn-server/src/world/handlers.rs` — see
  `broadcast_position` for what server sends. No Track 2 edits.
- `crates/projectdawn-server/src/world/tick.rs` — broadcast loop near
  the bottom. No Track 2 edits.
- `crates/projectdawn-server/src/world/persistence.rs` — 60 s
  position checkpoint loop. Helpful context for understanding what
  "server is the saver" means for the save_manager gate decision.
- `crates/gdext-net/src/lib.rs` — GDExtension; no Track 2 edits. The
  `position` signal already fires correctly.

### Launcher

- `scripts/main.gd` — Login / CharSelect / CharCreate / Play flow;
  no Track 2 changes.
- `autoloads/auth_client.gd` — WebSocket auth wrapper; no Track 2
  changes.
- `scripts/net/protocol.gd` — verbatim mirror of Project_Dawn's; no
  Track 2 changes (since neither side touches protocol.gd).

### Procedural dungeon

Out of scope for Track 2. Integration is Track 7.

---

## Begin by

1. Reading the docs in the "Read these in order" section, especially
   the Track 1 session notes and Net.gd / player.gd.
2. Asking the user the open questions before writing code. The
   thresholds and the save_manager strategy are the user's calls,
   not yours to assume.
3. Confirming the server is running (or restart together) and the
   game can be re-exported when needed.
4. Implementing the snap-or-lerp reconciliation in `player.gd` first,
   then the save_manager gate. Verify each step before moving on.
5. After the session, write notes in `docs/session_notes/
   session_YYYY_MM_DD.md` and update the index in `docs/session_notes/
   README.md`. Track 2 closes when the verification plan above
   passes end-to-end.

**Do not start writing code until the user has answered the open
questions.** Slice 2's small surface area makes the threshold/lerp
decisions disproportionately impactful on feel.
