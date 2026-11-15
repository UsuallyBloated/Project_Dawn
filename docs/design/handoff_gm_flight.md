# Handoff: GM flight (Creative-mode movement for geometry tests)

Written 2026-11-15 for the session that builds it. **All eight calls in section 9 DECIDED the
same day (user: "sounds good" to 1 to 7, "lets get it done" to 8), each as recommended.** Every
anchor below was read on
the deploy tips (server `27d5ea7`, client `f58395a`) when this was written; re-read before
editing, line numbers drift.

## 1. What was asked

The user, 2026-11-15: "I need better movement abilities while working on this. I would like to
have the movement access that Minecraft has with 'Creative Mode': the ability to fly and
quickly would be very helpful in these geometry tests."

A dev tool for the 4 km zone (walking across the plate at 5 m/s takes over 13 minutes, and
nothing today lifts a body except `DevFling`, which drops it again). GM accounts only, like
every dev tool (invariant D1).

**Minecraft's Creative flight, as its wiki describes it:** double-tapping jump toggles flight,
at any altitude; holding jump climbs and holding sneak descends; sprinting while flying is
faster (about 11 m/s, about 22 m/s sprinting); in Java Edition touching the ground ends flight,
and double-tapping jump again ends it in the air. Sources: the Minecraft wiki's Flight article
(<https://minecraft-archive.fandom.com/wiki/Flight>) and its Transportation table
(<https://fandom.reallyaweso.me/minecraft/wiki/Transportation>). That is the feel to copy.

## 2. Why the client cannot just fly

The server owns position, and three things pin a body to the ground today:

- **The Move handler throws the vertical away.** `handlers.rs`, `ClientWorldMsg::Move` (~line
  714): after the NaN guard and the CC gate it builds `Vec3f { x, y: 0.0, z }` and clamps the
  length to 1. Nothing vertical a client sends ever reaches `pos`.
- **The movement step puts every player on the ground.** `tick/movement.rs::run_movement`:
  speed is `RUN_SPEED * speed_buff * snare_mult * load_mult`; a grounded player steps through
  `terrain.player_step` (the slope rule, a refused rise counted as a `slope_refusal`) and
  `fall::vertical_step` (anything that leaves the ground falls and lands for damage).
- **The client snaps to the server's X/Z.** `scripts/player.gd`: `_on_world_position` snaps
  when the horizontal gap passes `SERVER_SNAP_THRESHOLD` (1 m) and otherwise lerps at
  `SERVER_LERP_RATE`; Y is never reconciled (the body's own gravity draws it). At 50 m/s the
  server is always more than 1 m behind the prediction (one tick alone is 2.5 m), so the
  current reconciler would snap the body back on every Position: rubber-banding.

So flight is a server state that a GM turns on, with a client half that predicts it and a
reconciler that copes with speed.

## 3. The shape, and why it needs no protocol change

- **The toggle rides `GmCommand`**, the free-text dev line (`ClientWorldMsg::GmCommand { line }`,
  handled at `handlers.rs` ~2346, today parsing only `give <item> [qty]`). A new `fly` sub-command
  needs no new message, no protocol bump and no DLL rebuild. The client already has
  `Net.broadcast_gm_command(line)` (`net.gd` ~868).
- **The vertical rides the existing `Move.direction.y`.** The DLL's `send_move` already copies
  `direction.y` onto the wire (`gdext-net/src/lib.rs` ~717). An honest client today always sends
  y = 0 (the body only yaws, so `transform.basis` has no vertical part), and the handler zeroes y
  for anyone not flying, so old clients and plain accounts are untouched.
- **Consequence:** the server half is wire-compatible with every client in the field, including
  the door zip `fd17ff1`. It can deploy whenever it is ready. The client half reaches only the
  clients that carry it.

No confirmation message is needed, by one rule held on both sides: **a client-requested toggle
is applied on both sides by the client's own request; anything the server does to end flight
comes with a `Teleport` (or a death).** Every server path that moves a player already sends a
`Teleport` (respawn, Gate and the other ports, the resurrection summon, `DevFling`), and the
client ends flight on any `Teleport` (`Net._on_teleport`, `net.gd` ~1318, emits
`world_teleport`). A new server path that ends flight without a `Teleport` would desync the
two; the tests in section 7 pin it.

## 4. The server half (`F:\Projects\server`)

**S1. The state.** `PerConnection` gains `flight: Option<Flight>` (`Flight { speed: f32,
ground_y: f32 }`), never persisted, `None` at every spawn. A helper `is_flying()`.

**S2. The command.** In the `GmCommand` arm, after the existing `can_use_dev_cmds` gate:
`fly <m/s>` turns flight on (or changes speed), `fly off` turns it off. Before the audit row:
the speed is finite and inside [`MIN_FLY_SPEED`, `MAX_FLY_SPEED`] (rule A3, a bad one dropped
silently), and the character is alive. **Careful: `GmCommand` is on the dead-state whitelist**
(`handlers.rs` ~628, so dev tools can unstick a dead test character), so the `fly` branch must
refuse the dead itself. Then `dev_cmd_allowed(.., "fly", "speed=25.0" or "off")`, one audit row
per toggle, never per Move. The arm returns an `Outcome::FlyIntent { requester, speed:
Option<f32> }` and the tick applies it (invariant S4: the takeoff wipes mob hate, which is not
the sender's own state). Model it on `Outcome::DevFlingIntent` (`tick/intake.rs` ~622).

**S3. Takeoff** (in intake): set `flight`; clear `vertical` (flight catches a fall already in
progress, a GM power, consistent with D1); wipe the flier from every mob's hate with
`kills::wipe_hate` and fan the cleared mobs as `EntityTarget None`, exactly as the port arm does
(`wipe_hate`'s own comment says a wipe is invisible to clients unless the caller fans it).
Tell the GM: "You take to the air (25 m/s). /fly off to land." Log `fly on` with char_id, speed
and position.

**S4. The Move handler.** When `conn.is_flying()`, keep `direction.y` and clamp the length to
`FLY_BOOST` (2.0, the sprint) instead of 1.0. Everything else unchanged: the NaN guard runs
first, and the CC gate still zeroes a rooted or stunned flier (it hovers).

**S5. The movement step.** A flight branch ahead of the airborne branch in `run_movement`:
`pos += dir * flight.speed * dt` in three dimensions; X and Z clamped inside the plate (the
terrain's extent; `Terrain::half` and `extent` are private today, so add a public
`clamp_to_plate`); Y clamped to `[terrain.ground(x, z), FLY_CEILING]`; `flight.ground_y =
terrain.ground(x, z)`; `vertical` stays default. Not touched by speed buffs, snare or
encumbrance (Minecraft's Speed effect does not affect flight either). No `player_step`, so no
slope refusals are counted. A vertical-only input stands a seated flier too (the existing stand
test looks at x and z only).

**S6. Landing and every other end.** One helper, `end_flight(conn, how)`:
- **`fly off`** starts a fall from where the body is, marked harmless: `fall::Vertical` gains
  `harmless: bool`, set only here; `movement::land` returns early on a harmless landing. Every
  other way into the air (a walk-off, `DevFling`) builds a fresh `Vertical`, so it is never
  harmless. (Section 9, call 4.)
- **Server-ended flight**: the death sweep, `RespawnTeleport`, the port arms (`binds_and_res.rs`),
  the resurrection summon (`casting.rs`), `DevFlingIntent` (ends flight, then flings; that fall
  costs as before) and the reap. Each of these already sends a `Teleport` or is a death; grep
  `send_teleport(` (33 hits for it and `ground_vec(` across 14 files when this was written) and
  cover every caller.

**S7. Saving.** `flush_connection` (`persistence.rs` ~67) writes `conn.pos`; a flier's would be
in the air, and the next login would read it as a walk-off and fall, lethally from above 42 m
(`fall::LETHAL_DROP`). Add `PerConnection::saved_pos()` returning `(x, flight.ground_y, z)`
while flying, and use it there. `is_dirty_for_persist` / `mark_persisted` compare `conn.pos`
and can stay as they are.

**S8. Mobs ignore a flier.** In `tick/enemy_ai.rs`, `player_snapshots` (~line 44) is the list
mobs pick targets from; leave fliers out of it (next to the dead), so no mob notices or chases
one. Together with S3's wipe, mobs simply do not see a GM in the air. Pets: a GM's own pet keeps
following on the ground and falls behind; nothing special.

**S9. No fighting from the air.** Refuse `Attack`, `CastStartBroadcast`, `CastSpell` and
`UseSkill` while flying with a private "You cannot do that while flying." Casts go through the
existing cast refusal (the caster's true mana goes with it, rule A2). Placed beside the
dead-state gate. Why: a body no mob can reach must not deal damage (A5's "it cannot answer"),
and kill credit, loot and XP earned from the air would enter the GM's ledger and stats.
(Section 9, call 5.)

**S10. Constants**, in `world/mod.rs` beside `RUN_SPEED`, each with a lockstep pair in
`tools/check_constant_lockstep.gd`: `DEFAULT_FLY_SPEED`, `MIN_FLY_SPEED`, `MAX_FLY_SPEED`,
`FLY_BOOST`, `FLY_CEILING`. Proposed values in section 9, call 1.

## 5. The client half (`F:\Projects\Project_Dawn`)

**C1. A flight branch in `scripts/player.gd::_physics_process`**, after the death lock and
before the sitting block (flying stands you). While flying:
- Direction: WASD in the body's yaw basis as now, plus `jump` held for up and a new `fly_down`
  held for down; normalized; times `FLY_BOOST` while `fly_boost` is held.
- The body moves itself: `global_position += dir * fly_speed * delta`, then the same clamps as
  the server (the plate, the ceiling, the ground from `TerrainMesh.height_at`). No
  `move_and_slide`, so nothing but the ground clamp stops it; scenery is never a body anyway
  (L2). Note `height_at` takes coordinates local to the TerrainMesh node (see
  `get_vertex_world_pos`); `ZoneDressing` finds the node by `terrain_path`
  (`"../TerrainMesh"`), and the player should find it the same way or by a group.
- Every 50 ms the Move goes out as now, carrying the vertical. No jump flag while flying (Space
  is climb, not a jump).
- Gravity, floor snap and the jump are skipped.

**C2. Reconciliation in flight.** The current lerp-and-snap cannot work at speed (section 2).
Use the sequence the server already echoes: `Net.send_movement` numbers each Move
(`_move_sequence`, `net.gd` ~530; make it return the number or add a getter) and every own
`Position` carries the last one the server took. Keep a short ring of predicted positions keyed
by sequence; on a Position, compare the server's position with the prediction for that sequence
(advanced by the one tick the server integrated it for), and blend out the difference in all
three axes. A dead band of about one tick of travel at the current speed absorbs the server's
one-tick jitter (it integrates once per tick whatever arrives); snap only past several ticks of
travel. Put it in its own `scripts/fly_reconciler.gd` (a `RefCounted` with no scene
dependencies) so a headless probe can drive it. Walking keeps the current reconciler, untouched.
If the reconciler fights, the fallback is to stop predicting in flight and draw the server's
position interpolated, as `remote_player.gd` does (costs about one round trip of input lag on
the R720, near nothing locally).

**C3. Toggles.** All gated on `Net.is_gm()` (display only; the server's gate is the rule) and
on being alive:
- Double-tap `jump` within `FLY_DOUBLE_TAP_SECS` (0.3 s, a knob), Minecraft's gesture.
- `/fly`, `/fly 50`, `/fly off` in chat (`hud.gd`'s command dispatch, beside `/give`).
- Test Panel: a FLIGHT row next to the Fling buttons (`test_panel.gd` ~189): Fly 10 / 25 / 50 /
  100 m/s and Land.
- Landing by descent: holding `fly_down` into the ground ends flight (Minecraft Java). The
  client decides and sends `fly off`; the server does not auto-land, so the two never disagree
  about it.
Turning on: send `fly <speed>`, then fly. Turning off: send `fly off`, then hand the body back
to its own gravity where it is (the server's harmless fall matches what the body draws).

**C4. Ending from outside.** Connect `Net.world_teleport` and `PlayerDeath` to `end_flight()`
on the client. After a relog the client starts on the ground, as the server does.

**C5. Keybinds.** Two rebindable actions in `autoloads/settings.gd`'s `REBINDABLE_ACTIONS`,
category Movement: `fly_down` (default Shift, Minecraft's sneak; our crouch is a toggle on X, so
it cannot be held) and `fly_boost` (default Ctrl, the sprint). Neither key is bound or read
anywhere in `autoloads/` or `scripts/` today (checked 2026-11-15).

**C6. On screen.** A small "Flying 25 m/s" line in the HUD while it lasts, so the state is
never a guess. `/loc` already prints the height.

**C7. Refuse locally first.** The client refuses auto-attack, a cast start and a skill while
flying, with the server's own line and nothing spent (A2), so the server's refusal is only the
backstop for a modified client.

## 6. Exploit ledger (each row is a test or names one)

1. **A plain account sends `fly 50`.** Silence (no oracle for whether dev commands are on), no
   audit row, and its Moves keep y zeroed. Test.
2. **A forged Move with a vertical, not flying.** Zeroed by the handler, as today. Test.
3. **A non-finite, zero, negative or huge speed.** Dropped before the audit row (A3). Test.
4. **A direction longer than the boost.** Clamped to `FLY_BOOST`; a forged length of 10 moves
   no further than 2. Test.
5. **Flying under the ground.** Y clamped to the ground every tick, on the server's own
   terrain. Test.
6. **Flying off the plate or out of sight upward.** X/Z clamped to the plate, Y to the ceiling.
   Test.
7. **Flight surviving a relog or a restart.** Never persisted; the saved position is the ground
   under the flier. Test (fly 40 m up, log out, log in: standing, unhurt, not flying).
8. **Flying to escape a fall.** Allowed for a GM (D1); impossible for anyone else (row 1).
9. **Flying while dead** (`GmCommand` is whitelisted for the dead). Refused in the `fly` branch.
   Test.
10. **Fighting from the air.** Refused server-side (S9). Test.
11. **A server move leaving a flier flying** (a port, a summon, a respawn, a fling). Each ends
    flight and sends a `Teleport`. Test at least the fling and a Gate.
12. **Linkdead in the air.** The body freezes where it is (linkdead bodies read no direction),
    no mob sees it (S8), and the reap saves the ground under it.
13. **A GM lands outside the walkable edge.** Stuck behind the mountains until they fly again.
    If GM is taken away while the character is out there, the operator moves it by SQL. Noted,
    not built (the server does not hold the walkable area; the reachability test computes it at
    test time).
14. **Old clients and the door zip.** They never send `fly` and always send y = 0: no change.
15. **Speed and AOI.** At the top speed (200 m/s, 10 m a tick) a flier crosses a 120 m AOI cell
    every 12 ticks; `aoi.update` already handles any old-to-new cell pair.

## 7. Tests

Server, in a new `tests/world/flight.rs` on the shared harness (a GM account via the harness's
`is_gm` grant, as the fling tests in `falls.rs` do):
- `a_gm_flies_up_and_the_server_follows`: `fly 20`, Moves straight up for 1 s; the own Position
  rises about 20 m and the walk speed no longer applies.
- `a_plain_accounts_fly_does_nothing`: no audit row, Moves with y keep it on the ground.
- `fly_off_falls_without_damage`, and `a_fling_while_flying_ends_flight_and_costs`.
- `a_flier_is_saved_on_the_ground`: logout at 40 m, relog, standing and full HP.
- `a_flier_cannot_attack_or_cast`: refusal lines, no Hit, mana unchanged.
- `mobs_ignore_a_flier`: a mob on the GM's hate list drops it at takeoff (EntityTarget None) and
  an idle mob passed over at 5 m does not notice.
- `flight_is_bounded`: under the ground, past the ceiling, past the plate, a forged long
  direction.
- Each fails with its rule disabled (the project's standard). Unit tests for the clamps and the
  harmless landing in `fall.rs`.

Client:
- `tools/probe_fly_reconciler.gd`: replays a scripted server stream (100 ms of latency, a
  tick of jitter, 100 m/s, a stop) and asserts no snap and a bounded error that settles after the
  stop. Fails on the walking reconciler.
- `tools/probe_flight_toggle.gd`: the double tap, the descent landing, end on a Teleport, end on
  death, no toggle for a non-GM.
- `check_constant_lockstep.gd` gains the five pairs; all `check_all.ps1` checks green.

## 8. Records pass

`docs/reference/invariants.md`: D1's holders gain the plain-account test; A5 gains one line
("a GM's flight stays above the server's ground and inside the plate"). `docs/reference/commands.md`:
`/fly`, the Test Panel row, the two keybinds. CLAUDE.md's To-Do entry ("GM flight", under World
systems) updated with what was built. A session note and its README row. If it is built after
the door, regenerate the planner (`tools/schedule_detail.py`) only if a row moves.

## 9. The user's calls (DECIDED 2026-11-15: the recommendation, the first option, in all eight)

1. **Speeds.** Default 25 m/s, Ctrl doubles it (Minecraft's sprint doubles), `/fly <m/s>` from 1
   to 100, so the top is 200 m/s. Boosted at the default, the 4 km plate is 80 s across.
   Ceiling 1,000 m (the highest mountains stand about 440 m).
2. **Controls.** Minecraft's: double-tap Space toggles, Space climbs, Shift descends, Ctrl
   boosts; plus `/fly` and the Test Panel row.
3. **Landing.** Descending into the ground ends flight (Minecraft Java). Alternative: only
   `/fly off` or the double tap ends it, so you can skim the ground.
4. **Fall after `fly off` in the air.** Harmless (Minecraft-like; the fling stays the tool for
   testing real falls). Alternative: the ordinary fall, damage and all.
5. **Mobs and fighting.** Mobs ignore a flier, and a flier cannot attack, cast or use skills.
   Alternative: fighting allowed (it would need its own rules for a body nothing can reach).
6. **Collision.** Over the ground, never through it: no noclip. A noclip (Minecraft's Spectator
   mode) would let the server hold a body under its own terrain; not proposed.
7. **Visible to other players.** Yes, drawn in the air (nothing to build). Alternative: hidden
   while flying.
8. **When.** Build on `feat/gm-flight` in both repos, in new worktrees (another session may be
   using the main checkouts). The server half can merge and redeploy any time: no wire change,
   the door zip unaffected. The client half stays out of the door zip (cut by Tue Nov 17; it
   touches `player.gd`, the core of movement) and reaches the user through the editor or a
   personal export until the bump after the door.

## 10. Order of work

1. Server S1 to S10 with the tests, suite green (`cargo test --no-fail-fast`, fmt, clippy).
2. Client C1 to C7 with the probes, every check green against the branch's server
   (`check_all.ps1 -ServerRoot <server worktree>`).
3. A run against a local server with `PD_DEV_CMDS=1` and a GM account: fly the plate, land on
   the plateau, `/fly off` from 100 m, log out in the air.
4. `/code-review` (it touches movement and networking, a core system).
5. A short checklist from `docs/playtest_notes/TEMPLATE_checklist.md`
   (`gm_flight_checklist.md`): the toggles, the speeds, landing, a relog in the air, a Gate in
   the air, mobs ignoring a flier, a second seat watching the GM fly.
6. Records (section 8). Nothing is ticked until the checklist is filled.

## 11. Traps

- **`GmCommand` is allowed while dead.** The `fly` branch checks alive itself (row 9).
- **Handlers touch only the sender (S4).** The hate wipe belongs in the tick, not the handler.
- **The client never reconciles Y today.** Flight is the first time it must; walking must keep
  its current behaviour exactly (falls depend on it).
- **`Net._on_teleport` writes `global_position` directly** without updating the player's
  `_server_pos_target`; end flight before the position is written, or the reconciler's ring
  pulls the body back toward the pre-teleport track.
- **`TerrainMesh.height_at` is local to its node** and returns 0 past the grid's edge (the
  server's `ground` returns the floor there; both are 0 on this plate, keep it that way).
- **The Move sequence is GDScript's**, not the DLL's; reset to 0 on every connect
  (`net.gd` ~1061), so the ring must clear on reconnect.
- Build tooling defaults to `F:\Projects\server` (the deploy checkout): pass `-ServerRoot` to
  `check_all.ps1` when working in a server worktree.
