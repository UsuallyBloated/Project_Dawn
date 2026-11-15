# Session 2026-11-15: GM flight (Creative-mode movement for geometry tests)

Built on `feat/gm-flight` in both repos (the zone worktrees `F:\Projects\Project_Dawn-zone`
and `F:\Projects\server-zone`, each branched from its deploy tip: client `ea315cc`, server
`27d5ea7`). The plan is `docs/design/handoff_gm_flight.md`, written earlier the same day; the
user answered all eight of its calls as recommended ("sounds good" to 1 to 7, "lets get it
done. i believe in you" to 8).

## 1. What was asked

"I need better movement abilities while working on this. I would like to have the movement
access that Minecraft has with 'Creative Mode': the ability to fly and quickly would be very
helpful in these geometry tests." A dev tool for walking the 4 km zone; GM accounts only.

## 2. No protocol change

The toggle rides the existing `GmCommand` free-text line (`fly <m/s>`, `fly off`), dev-gated
and audited like `give`, one audit row per toggle. The vertical rides `Move.direction.y`,
which the DLL already copied onto the wire and the handler zeroed for everyone; it still
zeroes it for anyone not flying, so an honest client on foot and every old client are
untouched. No bump, no DLL rebuild; the server half can deploy any time and the door zip
`fd17ff1` keeps working against it. The client half reaches only clients that carry it.

The rule that keeps the two sides in step with no confirmation message: a client-requested
toggle is applied on both sides by the client's own request; anything the server does to end
flight comes with a `Teleport` (or a death), and the client ends flight on any Teleport.

## 3. The server

- `PerConnection.flight: Option<Flight { speed, ground_y }>`, never persisted; `is_flying()`,
  `saved_pos()` (a flier is saved on the ground under them) and `teleport_to(pos)` (the one
  way the server moves a body: standing, fall settled, flight ended), used by the respawn,
  the port arm, the resurrection summon.
- `handlers.rs`: `parse_fly_arg` (empty = the default speed, `off`, or a finite number in
  [`MIN_FLY_SPEED`, `MAX_FLY_SPEED`], anything else dropped before the audit row); the `fly`
  branch refuses the dead itself (`GmCommand` is on the dead-state whitelist) and a `fly off`
  with no flight; `Outcome::FlyIntent`. The Move handler keeps a flier's vertical and clamps
  the length to `FLY_BOOST` (2.0). A flying gate before the main match: `Attack` dropped,
  `CastStartBroadcast` / `CastSpell` a private CastFail with the true mana, `UseSkill` a
  SkillFail, all with `FLYING_REFUSAL` ("You cannot do that while flying.").
- `tick/intake.rs`: takeoff (catches a fall in progress), a speed change, and `fly off`
  (`fall::harmless_drop`: the fall is real, the landing costs nothing). `tick/spawning.rs`:
  the takeoff wipes the flier from every mob's hate (`wipe_hate`, fanned as `EntityTarget
  None`) and ends their PvP DoTs, as the port does. `tick/enemy_ai.rs`: fliers are left out
  of `player_snapshots`, so no mob notices, chases or swings at one. `tick/movement.rs`: the
  flight branch, three dimensions at `flight.speed` (the boost is the direction's length),
  untouched by speed buffs, snare or encumbrance, held above the ground
  (`Terrain::clamp_to_plate`, `ground`, `FLY_CEILING`), no slope rule, no slope refusals
  counted; a death clears `flight`. The fling clears `flight` first (its fall costs).
- `fall.rs`: `Vertical.harmless` / `Landing.harmless`; `movement::land` returns early on one.
- Constants in `world/mod.rs`: `DEFAULT_FLY_SPEED` 25, `MIN_FLY_SPEED` 1, `MAX_FLY_SPEED` 100,
  `FLY_BOOST` 2, `FLY_CEILING` 1000, each a lockstep pair with `player.gd`.
- Tests: `tests/world/flight.rs`, five tests; each was run with its rule disabled and failed
  (the save on the ground, mobs ignoring a flier, the harmless landing, the ceiling, the fling
  ending flight). A unit test on the harmless drop. Suite 412 unit, 189 world; fmt and clippy
  clean. Commit `5a0cf7e`.

## 4. The client

- `scripts/fly_reconciler.gd` (`FlyReconciler`, a RefCounted): the body remembers where it
  was as each Move goes out, keyed by the Move's sequence (`Net.send_movement` now returns
  it), advanced one server tick along the direction sent (the echoing Position is fanned after
  the tick that took it); each own Position is compared with the prediction for its sequence.
  Inside a dead band of 1.5 ticks of travel nothing happens; past 8 ticks the error is applied
  whole; between, blended out at 20/s. The walking reconciler (lerp-and-snap at 1 m) is kept
  for walking and would have snapped the body back on every Position at speed.
- `scripts/player.gd`: the five constants plus `FLY_DOUBLE_TAP_SECS` 0.3; `is_flying`,
  `fly_speed`, `flight_changed`; `can_fly` (GM, alive, in the world, past the first
  Position), `start_flight` (sends `fly %.1f`, stands, disengages auto-attack),
  `stop_flight(tell_server)` (sends `fly off` only when the client decided it),
  `toggle_flight`; `_fly_tick`: WASD in the body's basis, Space up, `fly_down` down,
  `fly_boost` for twice the speed, the body moved directly (no gravity, no `move_and_slide`),
  clamped to the `TerrainMesh` (by the new `terrain` group; `height_at` is node-local) and the
  plate and the ceiling, descending into the ground lands; the Move every 50 ms with the
  vertical and the boost as the direction's length, no jump flag. Double-tap Space in
  `_unhandled_input`. `Net.world_teleport` and `PlayerDeath.player_died` end flight without a
  send; the teleport handler also aims the walking reconciler at the new position.
- `autoloads/combat.gd`: `FLYING_LINE`, `is_player_flying`, `refuse_if_flying`,
  `on_flight_started`; `toggle_auto_attack`, `spells.gd::cast_spell` and
  `skills.gd::use_skill` refuse while flying before anything is spent.
- `scripts/hud.gd`: `/fly`, `/fly <m/s>`, `/fly off` (a non-GM is told "Flight is not
  available."); a "Flying N m/s" label at the top while it lasts. `scripts/test_panel.gd`:
  Fly 10 / 25 / 50 / 100 and Land. `autoloads/settings.gd`: `fly_down` (Shift) and
  `fly_boost` (Ctrl), rebindable. `autoloads/net.gd`: `send_movement` returns the sequence;
  a `gm_line_sent` signal for the probes.
- Probes: `tools/probe_fly_reconciler.gd` (a 20 Hz server model with 100 ms each way at
  100 m/s: no snap, the body never corrected through 3 s and settled at 0.00 m after the
  stop; a 100 m divergence applied whole; a 10 m error blended; the dead band; an unknown
  sequence) and `tools/probe_flight_toggle.gd` (17 checks: a non-GM and a bad speed refused
  with nothing sent, the takeoff told once, Moves flowing, the climb, no gravity, the landing
  by descent told, a Teleport and a death ending flight with no second send, stop told once).
  `check_constant_lockstep.gd` gained the five pairs; all 17 checks green against
  `server-zone` (`check_all.ps1 -ServerRoot`); the movement probes (`probe_login_facing`,
  `probe_swing_retime`, `probe_dead_actions`, `probe_cast_sight`, `probe_terrain_stand`,
  `probe_zone_world_loads`, `probe_fall_and_death_online`) still pass.

## 5. Found on the way

- The zone worktree's Godot class cache did not know `FlyReconciler` until
  `godot --headless --path . --import` (the known trap); without it the toggle probe hung
  (the player script failed to parse, the probe never reached `quit`).
- The reconciler probe's first server model was wrong twice: it did not integrate once per
  tick like the real server, and its truth line accumulated `t` in floats and stopped one
  frame late (a constant 1.67 m "error" that was the probe's). The real finding under it: the
  server's Position for sequence k is fanned after the tick that integrated it, so the
  prediction has to be advanced one tick along the direction sent, or every echo sits a
  systematic half-to-one tick ahead and the body is nudged forward.
- The `git checkout --` the mutation runs reached for would have discarded the uncommitted
  edits in the same files; the auto-mode classifier refused it, rightly. The mutations were
  made and undone with Edit instead.

## 6. Exploit lens

Rows 1 to 15 of the handoff's ledger, as built: a plain account's `fly` is silence and no
row (test); a forged vertical on foot is zeroed (unchanged handler); a bad speed is dropped
before the row (test); a forged long direction is clamped to the boost (test); under the
ground, past the plate and over the ceiling are clamped on the server's own terrain (test);
flight never persists and the save is the ground below (test); flying while dead is refused
in the `fly` branch (test); fighting from the air is refused server-side (test); every
server move ends flight with a Teleport (the fling tested; the ports and the summon share
`teleport_to`); a linkdead flier freezes where it is and is saved on the ground below; old
clients and the door zip are untouched (they never send `fly` and always send y = 0).

## 7. Not built, flagged

- A GM who lands outside the walkable edge is stuck behind the mountains until they fly
  again (the server does not hold the walkable area).
- Other players see a flier drawn in the air (nothing to build); no flying pose.
- A rooted or stunned flier hovers (the CC gate zeroes the direction).
- The GM's own pet keeps following on the ground and falls behind.

## 8. Records

CLAUDE.md's To-Do entry (World systems, "GM flight"); `docs/reference/invariants.md` (A5
gained the flight line and a holder; D1 two holders, tagged `(on feat/gm-flight)` until the
merge); `docs/reference/commands.md` (`/fly`, the keys, the Test Panel row);
`docs/playtest_notes/gm_flight_checklist.md` (28 rows); this note and its README row.
