# Hardening Pass Handoff — Audit Followups + Server Per-Tick Fix + GDScript Warning Cleanup

You're picking up Project Dawn — a Godot 4.4 / GDScript MMORPG client,
its companion Rust server (auth WebSocket + world UDP), a Godot
launcher, and a standalone procedural dungeon generator that will be
folded into the game later. Four repos, four branches; Tracks 1 and 2
closed earlier — the server-authoritative movement loop is whole now
(client sends Move intents, server is sole authority on position,
server saves on disconnect, server restores on reconnect, client
honors broadcast as truth via snap-or-lerp).

This is **not** a numbered Track. It's a small focused hardening pass
that closes loose ends Track 2 surfaced before going onto Track 3
(multi-player replication). Five sub-tasks, all mostly independent.
Goal is to leave the codebase in a clean state so Track 3's wider
network surface lands cleanly.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `3f1def3` (Session notes: Track 2 close) |
| Server | `F:\Projects\server\` | `main` | `1aab275` (world/tick.rs: drain pending channel messages before evicting connection) |
| Launcher | `F:\Projects\launcher\` | `main` | `9a0ddb8` (Play flow: RequestWorldToken + temp-file handoff) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS into DEBUG_TORCH_LABELS / DEBUG_COMPASS) |

Run `git -C <each> log --oneline -5` before touching anything to confirm
state.

## Read these in order

1. `F:\Projects\Project_Dawn\CLAUDE.md` — project conventions, autoload
   map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_08.md`
   — the same-day Track 1 + Track 2 narrative. The Track 2 section's
   "Five rounds" table and the per-tick speed-mismatch story are the
   directly upstream context for sub-task 3 of this handoff.
3. `F:\Projects\Project_Dawn\docs\session_notes\audit_2026_05_08.md`
   — the read-only health audit. Findings #1, #2, #3 are this
   handoff's sub-tasks 1 and 2. Findings #6, #8, #10 are bonus
   hygiene; #5 and #7 already closed; #4 and #9 deferred to Track 7.
4. `F:\Projects\Project_Dawn\autoloads\save_manager.gd` — sub-task 1
   work site.
5. `F:\Projects\Project_Dawn\autoloads\net.gd` — sub-task 1 work
   site (the auto_accept_quit ownership transfer).
6. `F:\Projects\Project_Dawn\scripts\lobby.gd` — sub-task 2 work site.
7. `F:\Projects\server\crates\projectdawn-server\src\world\handlers.rs`
   — sub-task 3 work site. The `Move` arm is what needs to stop
   integrating per-message.
8. `F:\Projects\server\crates\projectdawn-server\src\world\tick.rs`
   — sub-task 3 work site. The integration moves into the tick
   loop.
9. `F:\Projects\server\crates\projectdawn-server\src\world\connection.rs`
   — sub-task 3 work site. `PerConnection` gets a new
   `latest_direction` field.

---

## Current reality (as of Track 2 close)

### What works end-to-end

- **Auth WS**: Register / Login / CharList / CharCreate / CharDelete /
  Logout / RequestWorldToken — Argon2id, 256-bit session tokens,
  refuses to start without `PROJECTDAWN_NETCODE_KEY`.
- **World UDP**: renet 2.0 Secure mode, 20 Hz tick, 60 s checkpoint,
  10 s app-layer heartbeat timeout.
- **Game ↔ World**: client connects via `--world-token-path` tempfile
  hand-off, drives `DISCONNECTED → CONNECTING_TRANSPORT →
  CONNECTED_TRANSPORT → CONNECTED_APP` state machine, periodic 4 s
  heartbeats, clean shutdown via `Net.leave_session()` on window
  close + Quit Game button.
- **Server-authoritative movement (Tracks 1+2)**: client sends Move
  intents at 20 Hz with direction scaled by
  `current_speed / SERVER_MAX_MOVE_SPEED`, server integrates per
  accepted message, broadcasts Position back at 20 Hz, client
  reconciles via snap-or-lerp (1.0 m threshold, time-based smoothing
  rate of 17.3 /sec). Walks straight / circles / jumps / sits with
  no rubber-banding. Persistence loop verified end-to-end (walk →
  close → relaunch → return to last logged-off position).

### What doesn't work / what's brittle

- **Audit #1 (broken)**: `SaveManager._notification(NOTIFICATION_WM_CLOSE_REQUEST)`
  doesn't fire on autoloads in Godot 4 — same pitfall Track 1 hit.
  Closing the game with the OS X-button **does not save** locally.
  Bounded by level-up / zone-change / explicit Quit Game autosaves,
  but anything done since the last of those is lost.
- **Audit #2 (latent)**: Both `Net._ready()` and `SaveManager._ready()`
  set `auto_accept_quit = false`. Once #1 is fixed by migrating
  SaveManager to `close_requested`, both autoloads will have handlers
  on the same signal and both will call `get_tree().quit()`.
  Ordering is determined by autoload-declaration order in
  `project.godot` — brittle.
- **Audit #3 (latent, surfaces in launcher mode)**: Lobby UI is
  ungated when `Net.is_launcher_mode()` is true. Clicking Test
  Dungeon while connected to the world server loads
  `dungeon_world.tscn`; the first-tick snap then teleports X/Z to
  whatever world.tscn position the server has saved, putting the
  player off the dungeon's floor mesh. They fall through.
- **Server-side per-tick integration bug**: `world/handlers.rs`
  Move arm integrates a fixed `TICK_DT` per *accepted Move* rather
  than once per tick. Track 2 worked around it client-side via the
  20 Hz throttle. Fragile under variable arrival rates (multi-client
  testing in Track 3 will re-expose it).
- **Pre-existing GDScript warnings**: ~34 warnings shown in the
  editor's Debugger panel during local-save regression testing
  (shadowing local function parameters, integer division, narrowing
  conversions, unused signals on `enemy.gd`, integer-instead-of-enum,
  `lobby.gd:62` invalid UID line). None Track-2-related — all in
  pre-existing files. Make `cargo` editor noisy.

### Hard layout invariants you must preserve

- `scripts/net/protocol.gd` is **1:1** between `Project_Dawn` and
  `launcher`. `diff` reports zero output. No protocol changes
  expected in this hardening pass; if for any reason you find
  yourself touching it, mirror to both copies in the same session.
- `addons/gdext_net/gdext_net.dll` is gitignored. Build via
  `addons/gdext_net/build.ps1`. No GDExtension changes expected here.
- The Rust `protocol` crate is the source of truth for the wire
  format. No protocol changes expected.
- `PROJECTDAWN_NETCODE_KEY` must NEVER appear in any commit, log
  line, error message, or test fixture.

---

## Hardening Pass scope

Five sub-tasks. Order suggested below; can be reordered if you have a
reason. Each is small enough to be its own commit (or two). One commit
per logical change per repo. The whole pass is probably one session.

### Sub-task 1 — SaveManager close hook + single quit owner (audit #1, #2)

Migrate `SaveManager` off `_notification(NOTIFICATION_WM_CLOSE_REQUEST)`
onto the `Window.close_requested` signal pattern Track 1 established.
Then consolidate quit ownership so only one autoload calls
`get_tree().quit()`.

**Architecture decision:** `SaveManager` becomes the single quit owner.
Its close handler calls (in this order):

1. `SaveManager.save()` — flushes character to disk.
2. `Net.leave_session()` — sends app-Disconnect + 4 polls, no
   `disconnect_now()`. Existing path; safe to call in local-save mode
   (early-outs gracefully when `_state != CONNECTED_APP`).
3. `get_tree().quit()`.

Why save first: save reads PlayerStats / Inventory / Equipment which
are local autoloads, untouched by network teardown. Saving before the
~200 ms `leave_session` poll keeps the data flush bounded if anything
goes wrong in the network teardown phase. Same order as
`options_screen.gd._on_quit_pressed` (after this change, all three
quit paths — OS X button, Quit Game, future return-to-lobby —
converge on the same sequence).

`Net._ready()` no longer takes `auto_accept_quit` ownership and no
longer connects to `close_requested`. The `_on_close_requested`
handler in net.gd is removed entirely.

**Files to touch:**

- `autoloads/save_manager.gd`:
  - Remove the `_notification` handler entirely.
  - In `_ready()`, after the existing `auto_accept_quit = false` line
    (which stays — SaveManager is now the owner), connect:
    `get_tree().root.close_requested.connect(_on_close_requested)`.
  - Add `_on_close_requested()` that calls save → `Net.leave_session()`
    → `get_tree().quit()`. Same `_is_loading` guard as the old
    `_notification` had.
- `autoloads/net.gd`:
  - In `_ready()`, remove the `auto_accept_quit = false` line and the
    `close_requested.connect(...)` line.
  - Remove the `_on_close_requested()` function.
  - Update the docstring at the top of the file to reflect that
    SaveManager now owns window-close handling. The current docstring
    says `Net` "takes ownership of window-close so we can flush the
    app-layer Disconnect packet before the tree tears down" — that's
    no longer true.

**Verification:**

1. Re-export game.
2. Launcher → Play → Test Room → walk a few seconds → close window.
3. Server log: `client requested disconnect char_id=N` followed by
   `reason=DisconnectedByServer` (Track 1 path; should still work).
4. Re-launch. Character should be at the position from the close — if
   server restored from its 60s checkpoint, that's slight regression
   from earlier Track 2 testing (server's final-on-disconnect save
   should still fire). If you appear at the exact close position,
   both saves fired (server-side + local).
5. Run game directly via Godot editor F5 (no launcher) → Test Room →
   walk → close. Reload. Character should be at the close position
   (local SaveManager fired). This is the exact regression audit #1
   reports — confirm the fix.

### Sub-task 2 — Lobby UI gating in launcher mode (audit #3)

When `Net.is_launcher_mode()` returns true, the lobby's
Solo / Host Game / Join Game / Test Room / Test Dungeon buttons are
incoherent — they all assume single-player local-save state, but
`Net` is connected to the world server and pumping heartbeats.
Clicking Test Dungeon specifically causes the dungeon fall-through
the user hit during Track 2 testing.

**Architecture decision:** auto-route into `world.tscn` on app
connection. No buttons shown; lobby becomes a single "Connecting to
world..." status display until `Net.app_connected` fires, at which
point the lobby calls `change_scene_to_file("res://scenes/world.tscn")`.

If `Net.app_disconnected` fires before connection (timeout, kicked,
etc.), the lobby shows the error and re-enables the local-mode buttons
as a fallback — the user can still play in local-save mode if the
server is unreachable, which is useful for offline dev iteration.

**Files to touch:**

- `scripts/lobby.gd`:
  - In `_ready()`, branch on `Net.is_launcher_mode()`:
    - If true: hide all the Solo/Host/Join/Test buttons, show a
      "Connecting to world..." label, connect to `Net.app_connected`
      and `Net.app_disconnected`.
    - If false: existing behavior (current button setup) unchanged.
  - On `Net.app_connected`, `change_scene_to_file("res://scenes/world.tscn")`.
    Set `Network.is_online = false; Network.is_test_room = false`
    before scene change — those flags are for the legacy ENet path,
    irrelevant in launcher mode but should be in a known state.
  - On `Net.app_disconnected(reason)`, show "Disconnected: {reason}.
    You can play offline if you wish." and re-show the local buttons.

**Watch out for:**

- `Net` may already be in `CONNECTED_APP` state by the time `_ready`
  runs (the autoload starts connecting before the lobby loads). Check
  `Net.is_app_ready()` at lobby `_ready` and call the connection
  handler directly if true. Otherwise just connecting to the signal
  works (it'll fire eventually).
- Don't break local-save mode. The `if Net.is_launcher_mode()` branch
  must be the only thing changed; the else-branch (local-save) must
  keep working exactly as today.
- The world.tscn scene path is `res://scenes/world.tscn` per the
  current `lobby.gd` `GAME_SCENE` constant. Reuse the constant rather
  than hard-coding.

**Verification:**

1. Launcher → Play → game spawns. Should land on the lobby briefly
   (showing "Connecting to world..."), then auto-route to world.tscn.
   No clicks needed.
2. The Test Dungeon fall-through bug is now unreachable in launcher
   mode (because the Test Dungeon button isn't shown).
3. Run game directly via editor F5 (no launcher) → lobby shows the
   buttons as before. Click Test Room — should work. Click Test
   Dungeon — should work.

### Sub-task 3 — Server-side per-tick integration

Server currently integrates `pos += dir × MAX_MOVE_SPEED × TICK_DT`
inside the `Move` arm of `handlers.rs`, every time a Move message is
accepted. With multiple Moves per tick (the audit's "harmless"
move-rate that turned out to be 3× speedup), pos advances faster than
intended. Track 2 worked around this client-side via 20 Hz throttle,
but it's a server-side bug and should be fixed there too.

**Architecture decision:** server stores the latest direction intent
on `PerConnection` and integrates exactly once per tick.

```rust
// In connection.rs PerConnection:
pub latest_direction: Vec3f,  // unit vector or zero; updated on Move
pub last_move_received: Option<Instant>,  // for stale-input guard

// In handlers.rs Move arm — replace the pos integration with:
conn.latest_direction = dir.clamp_length(1.0);
conn.last_move_received = Some(now);

// In tick.rs, before broadcast_position (i.e., after message-drain
// phase, before send phase), iterate ready connections and integrate:
const STALE_MOVE_THRESHOLD: Duration = Duration::from_millis(500);

for conn in connections.values_mut().filter(|c| c.ready) {
    let dir = match conn.last_move_received {
        Some(t) if now.duration_since(t) < STALE_MOVE_THRESHOLD => conn.latest_direction,
        _ => Vec3f::ZERO,  // no recent input — stop integrating
    };
    let dt = TICK_DT.as_secs_f32();
    conn.pos.x += dir.x * MAX_MOVE_SPEED * dt;
    conn.pos.y += dir.y * MAX_MOVE_SPEED * dt;
    conn.pos.z += dir.z * MAX_MOVE_SPEED * dt;
}
```

Why the stale-move guard: if the client crashes mid-walk, the server
keeps `latest_direction = forward` until heartbeat timeout (10s).
Without the guard, the player would visually run forward for 10
seconds on the server before dropping. With a 500 ms guard, a single
missed Move tick stops integration — clean stop within ~3 ticks of
client silence.

**Important: re-test Track 2 after this change.** The client is still
sending direction scaled by `current_speed / SERVER_MAX_MOVE_SPEED`.
After this fix, the math is unchanged (one integration per tick × the
scaled magnitude), so behavior should be identical. If it isn't, the
client's 20 Hz throttle was masking the bug differently than expected.

**Files to touch:**

- `crates/projectdawn-server/src/world/connection.rs`:
  - Add `pub latest_direction: Vec3f` to `PerConnection`. Default to
    zero in the constructor / `Default` impl.
  - Add `pub last_move_received: Option<Instant>`. Default to `None`.
- `crates/projectdawn-server/src/world/handlers.rs`:
  - In the Move arm: drop the inline `conn.pos.x += ...` block.
    Replace with `conn.latest_direction = dir.clamp_length(1.0);
    conn.last_move_received = Some(now);`. Keep the out-of-order
    sequence drop and the existing `last_move_seq` update.
- `crates/projectdawn-server/src/world/tick.rs`:
  - Add the per-tick integration step described above. Place it
    after the message-drain phase, before `broadcast_position`. Add
    a `STALE_MOVE_THRESHOLD` const at the top of the file or in
    `world/mod.rs` next to `TICK_DT` and `MAX_MOVE_SPEED`.

**Verification:**

1. `cargo test --release` — should remain 6/6 passing. The
   `world_smoke.rs` test sends a single Move and waits for a Position
   with `pos.x > 0`. After the change, the Position from the *next
   tick* (not the tick where the Move was received) will be the one
   with `pos.x > 0`. If the test was tight on timing, it may need a
   slightly longer wait. Adjust the timeout if so but DO NOT relax
   the `pos.x > 0` assertion.
2. Re-run Track 2 verification: launcher → Test Room → walk for 15 s
   → close → relaunch → land at last position. Should be identical
   feel to before (same effective speed, same lerp).
3. (Optional) Set `RUST_LOG=projectdawn_server=debug` and add a
   one-off `tracing::debug!` inside the per-tick integration loop
   to log `(client_id, dir, new_pos)` once per tick. Confirm exactly
   one log line per client per 50 ms tick. Revert the debug! before
   committing.

### Sub-task 4 — GDScript warning cleanup

The user reported ~34 warnings in the Godot editor's Debugger panel
during the local-save regression test. None are tied to Track 2; all
are pre-existing. Triage:

**Categories observed (from the user's screenshot):**

- "The local function parameter 'race' is shadowing an already-declared
  variable" — `character_creation.gd:29`
- "Integer division, decimal part will be discarded" — multiple files
- "Narrowing conversion (float is converted to int and loses
  precision)" — multiple
- "Integer used when an enum value is expected" — at least one
- "The variable 'dist' is declared below in the parent block" —
  twice
- "The signal 'enemy_stunned' / 'enemy_stun_wore_off' /
  'enemy_rooted' / 'enemy_snared' / 'enemy_slowed' / 'enemy_mez_applied'
  / 'enemy_mez_broke' / 'enemy_charmed_attacked' / 'enemy_silenced' is
  declared but never explicitly used in the class" — `enemy.gd`
- "The local function parameter 'name' is shadowing an already-declared
  property in the base class 'Node'" — twice
- "The local 'for' iterator variable 'name' is shadowing an
  already-declared property in the base class 'Node'"
- "lobby.gd:62 @ _on_test_room_pressed(): res://scenes/hud.tscn:3 -
  ext_resource, invalid UID: uid://c8nt3vhqw6y1 - using text path
  instead: res://scripts/hud.gd" — runtime UID resolution log,
  unrelated to script warnings.

**Approach:**

1. **Don't touch `enemy.gd`** — it's on the user's no-modify list.
   The 9 unused-signal warnings on enemy.gd should be addressed by
   the user, not in this pass. Flag them in the session notes and
   move on. (The `@warning_ignore("unused_signal")` annotation is
   the standard fix; user can apply.)
2. **For everything else**: fix in-place. Rename shadowing
   parameters (`race` → `race_arg` or `_race`, `name` → `npc_name`
   etc.). Replace `int / int` with explicit `int(int / int)` or
   `floori(...)`. Add `int(...)` casts at narrowing boundaries.
   Reorder declarations so `dist` is declared above its first use.
   Replace `int_value` passed where enum expected with
   `EnumType.VARIANT`.
3. **The lobby.gd:62 invalid-UID line** is a Godot 4.4 sidecar
   regen issue. Check if `res://scripts/hud.gd.uid` exists; if not,
   open `res://scenes/hud.tscn` once in the editor and resave —
   Godot will regenerate. (This isn't a script warning per se;
   it's a runtime info-level log. May not actually need fixing.)

**Files likely touched** (grep to confirm):

- `scripts/character_creation.gd` (line 29, race shadowing)
- Multiple scripts with integer-division / narrowing-conversion
  warnings — let `Grep "Integer division\|Narrowing"` against the
  Output panel's actual line numbers find them.
- The two "name" shadowing instances likely in dialog/quest UI code.

**Verification:**

- Run Project_Dawn from editor F5. Open Debugger → Errors tab. Count
  should drop from 34 to ~9 (the enemy.gd unused-signals which
  you're leaving). No new warnings introduced.

### Sub-task 5 (bonus) — Minor audit hygiene

Three small fixes if time permits:

- **Audit #6**: Update CLAUDE.md line 6 from "Godot 4.3 (or whatever
  version you're on)" to "Godot 4.4". One-line edit. **This is on
  the no-modify list — flag in session notes and let the user
  do it.** Don't touch.
- **Audit #8**: Delete `scripts/terrain_zone.gd` (239 lines, dead
  code — `class_name TerrainZone` is referenced nowhere). Confirm
  with `Grep TerrainZone` before deleting.
- **Audit #10**: Server has 5 trivial clippy warnings — all
  `serde_json::to_string(&...)?.into()` and `payload.to_string().into()`
  where `.into()` is a no-op. Drop the `.into()` calls. `cargo clippy
  --workspace --all-targets` should be clean afterward.

---

## Verification plan summary

End of session, all of these should be true:

- [ ] **Sub-task 1 verified**: window close in local-save mode (no
      launcher) saves the character. Reload restores the close-time
      position.
- [ ] **Sub-task 1 verified**: window close in launcher mode produces
      `client requested disconnect` + `reason=DisconnectedByServer`
      on the server log (Track 1 disconnect path still working).
- [ ] **Sub-task 2 verified**: launcher mode auto-routes to
      world.tscn after `Net.app_connected`. Local-save mode shows
      lobby buttons unchanged.
- [ ] **Sub-task 3 verified**: `cargo test --release` 6/6 passing.
      Track 2 walk feel unchanged after server-side integration moved
      to tick loop.
- [ ] **Sub-task 4 verified**: editor warning count drops from 34 to
      ~9 (the enemy.gd signals left for the user).
- [ ] **Sub-task 5 verified**: `cargo clippy --workspace --all-targets`
      clean. `terrain_zone.gd` deleted, no TerrainZone references
      remain.

**Commits expected** (rough plan, adjust as you go):

- 1 commit in Project_Dawn for sub-task 1 (SaveManager + Net split)
- 1 commit in Project_Dawn for sub-task 2 (lobby gating)
- 1 commit in server for sub-task 3 (per-tick integration)
- 1 commit in Project_Dawn for sub-task 4 (warning cleanup)
- 1 commit in Project_Dawn for sub-task 5 hygiene (delete dead code)
- 1 commit in server for sub-task 5 hygiene (clippy fixes)
- 1 commit in Project_Dawn for session notes

That's ~7 commits across 2 repos. Don't bundle.

---

## Hard rules (carry forward, do not relax)

### Project_Dawn — files you must NOT modify

- `CLAUDE.md`
- `addons/procedural_dungeon/` (the embedded copy)
- `scripts/enemy.gd` (user iterates on it directly between sessions
  — this matters specifically for sub-task 4)
- `docs/concepts/world/maps/`
- `docs/reference/`
- `docs/playtest_notes/testing_notes_2026_05_02.md`
- `docs/playtest_notes/testing_notes_2026_05_05.md`
- `docs/playtest_notes/testing_notes_2026_05_06.md`

### Cross-repo invariants

- **`scripts/net/protocol.gd` MUST stay 1:1** between `Project_Dawn`
  and `launcher`. Hardening pass doesn't touch protocol.gd, but if
  for any reason you find yourself doing so, mirror to both.
- **The Rust `protocol` crate is canonical.** Hardening pass doesn't
  add wire types.
- **`PROJECTDAWN_NETCODE_KEY` is sacred.** Never logged, committed,
  or in test fixtures as a constant.
- **Token files are read-once-then-deleted on the game side.**
  Hardening pass doesn't touch this path.
- **The `gdext_net.dll` is gitignored.** Hardening pass won't
  rebuild it.

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
  6/6 (sub-task 3 may require a small test-timeout adjustment but
  must keep all assertions).
- Server runtime: `cargo run -p projectdawn-server 2>&1 |
  Tee-Object -FilePath server.log` — the user runs this; you read
  the log.
- GDExtension rebuild: not expected for this pass.
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

1. **Sub-task ordering** — the suggested order is 1, 2, 3, 4, 5. The
   user may want to skip sub-task 5 entirely (it's bonus hygiene) or
   reorder to do server-side first. Confirm before starting.
2. **Sub-task 2 design** — auto-route to `world.tscn` on connect is
   the cleanest option but an explicit "Enter World" button is also
   reasonable. Default to auto-route unless the user prefers explicit.
3. **Server live during the session?** Confirm the server is running
   with the `Tee-Object` log so you can read
   `F:/Projects/server/server.log` for verification.
4. **Console wrapper** — point `$env:PROJECTDAWN_EXE` at the
   `.console.exe` build for the session, so Net warnings during
   reconnect testing are visible.
5. **`enemy.gd` unused-signal warnings (sub-task 4)** — the cleanest
   fix is `@warning_ignore("unused_signal")` annotations on the 9
   signal declarations. The user iterates on enemy.gd directly, so
   this handoff says don't touch. Confirm whether the user wants you
   to skip those entirely (recommended) or apply the annotations
   (asks the user to merge later).
6. **`world_smoke.rs` test timeout (sub-task 3)** — if the existing
   test relies on the next-Position-broadcast arriving within tight
   timing, the per-tick refactor may push it one tick later. Confirm
   the user is OK with a one-line timeout extension if needed (the
   actual `pos.x > 0` assertion stays).

---

## Quick reference — key files & autoloads

### Project_Dawn

- `autoloads/net.gd` — Net adapter; sub-task 1 removes its
  `auto_accept_quit` ownership and `_on_close_requested` handler.
- `autoloads/save_manager.gd` — sub-task 1 work site; close-hook
  migration + becoming the single quit owner.
- `scripts/lobby.gd` — sub-task 2 work site; gate UI on
  `Net.is_launcher_mode()`, auto-route on `Net.app_connected`.
- `scripts/player.gd` — Track 2 reconciliation lives here. Don't
  touch in this pass; just re-verify behavior is unchanged after
  sub-task 3's server-side fix.
- `autoloads/zone_loader.gd` — out of scope.
- `autoloads/player_stats.gd` — `save_state()` doesn't persist
  position; relevant context for sub-task 1's verification.
- `scripts/options_screen.gd` — `_on_quit_pressed` already does
  `SaveManager.save() → Net.leave_session() → get_tree().quit()`
  in that order; sub-task 1's close-handler should mirror it.
- `scripts/terrain_zone.gd` — sub-task 5 deletes this.
- `scripts/character_creation.gd`, `scripts/lobby.gd`, others —
  sub-task 4 cleanup targets.

### Server

- `crates/projectdawn-server/src/world/handlers.rs` — sub-task 3:
  Move arm stops integrating per-message.
- `crates/projectdawn-server/src/world/tick.rs` — sub-task 3: new
  per-tick integration step before `broadcast_position`.
- `crates/projectdawn-server/src/world/connection.rs` — sub-task 3:
  `PerConnection` gets `latest_direction` + `last_move_received`.
- `crates/projectdawn-server/src/world/mod.rs` — sub-task 3 may add
  `STALE_MOVE_THRESHOLD` constant near `TICK_DT` and
  `MAX_MOVE_SPEED`.
- `crates/projectdawn-server/tests/world_smoke.rs` — sub-task 3 may
  need a small timeout adjustment (assertion stays).
- Other crates with `serde_json::to_string(&...)?.into()` and
  `payload.to_string().into()` patterns — sub-task 5 clippy cleanup.

### Launcher

No changes expected. Hardening pass is Project_Dawn + server only.

### Procedural dungeon

No changes expected. Track 7 is the integration milestone.

---

## Begin by

1. Read the seven docs in the "Read these in order" section.
2. Run `git -C <each repo> log --oneline -5` to confirm state matches
   the table at the top.
3. Read the open questions and ask the user. The sub-task ordering
   and the `enemy.gd` decision in particular need user input before
   you write code.
4. Confirm the server is running. If not, restart together at the
   start of the session.
5. Implement sub-task by sub-task. After each, run its verification.
   Don't stack multiple unverified changes.
6. After the session, write notes in
   `docs/session_notes/session_YYYY_MM_DD.md` (use today's date —
   probably append to an existing same-day file if the session falls
   on a previously-active date) and update the index in
   `docs/session_notes/README.md`. The session-notes pattern after
   Tracks 1 and 2 is to use a "five rounds" table or analogous
   chronological structure if the work hit any debugging dead ends —
   useful for the next session to learn from.

**Do not start writing code until the user has answered the open
questions specific to whichever sub-task you start with.** The
SaveManager change is small but the auto_accept_quit ownership swap
is the kind of thing that's easy to get wrong if rushed.
