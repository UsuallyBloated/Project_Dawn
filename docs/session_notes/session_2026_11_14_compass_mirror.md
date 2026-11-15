# Session 2026-11-14 (night): the compass mirror and `/loc` the EverQuest way

Built on `feat/compass-mirror` in both repos (the zone worktrees `F:\Projects\Project_Dawn-zone`
and `F:\Projects\server-zone`), each branched from its deploy tip (client `55b493a`, server
`9a7e0fa`). The plan was `docs/design/handoff_compass_mirror_2026_11_14.md`, written by the
Fable session before it ran out; this session ran on Opus 5.5.

## 1. What was asked

The handoff's two questions, answered "yes, please" to both, then "go ahead": mirror the world
once so it matches the comp's map (north becoming -Z), and print `/loc` the EverQuest way
(north, west, height) with a raw form kept for authoring.

The fact, from the earlier session: the Greywood ridge stood at +Z and the gnoll raiders at +X.
Godot is right-handed, so facing +Z puts +X on the left: the 2026-09-27 ruling "+Z is north,
+X is east" made the world a mirror image of every map of it, the comp included.

## 2. The check first

`tools/check_compass.gd` was written before any change and run against the deploy tip: it
failed at the one row it should (`FAIL EAST the Gnoll Raider Camp (560, 70) is on the right
facing the ridge`). What it holds, from the built world and the server's files rather than
from the mapping: the ridge, read from the scene's ground along four lines either side of the
town, is where `/sense` says North; from the town, facing it, the server's Gnoll Raider Camp is
on the right, and `/sense` says East facing it. Then the mapping's own rows (map north towards
the ridge, map east on the right, a round trip, a map facing turning the same way on the
ground at sixteen headings) and one cross-check: the raiders' set piece stands within 80 m of
the server's camp.

That last row earned its place on the first `check_all.ps1` run: the script did not pass the
check a server path, so it read the deploy checkout's unmirrored camps, and the chirality rows
passed (x does not change under the mirror) while the set piece was 140 m from its camp. The
check now takes the server's data directory like the other lockstep checks.

## 3. One mapping; the authored data does not change

`ZoneLayout` gained `to_world(p, height)`, `to_world_xz(p)`, `to_map(v)`, `to_map_xz(q)`
(north is -Z, east +X) and `yaw_to_world(yaw) = PI - yaw`. Derived before use: a body turned
`yaw` faces `(-sin yaw, -cos yaw)` in (x, z); the authoring code's map yaw (`_facing`'s
`atan2(-d.x, -d.y)`) faces the map direction `d`; under the new mapping that direction is
`(d.x, -d.y)` in the world, which `PI - yaw` faces. The check's sixteen headings hold it.

`data/zone_layout.gd` and `data/terrain_features.toml` keep every number. Rewriting them
would not have mirrored: the noise is sampled at the map point (negated coordinates give
different hills), and the plateau's ramps are keyed `north` / `south`. Reading each vertex at
its map point makes the ground the exact mirror, hill for hill.

## 4. The client

- `ZoneDressing.ground` / `on_ground` / `stand`: the choke point; every set piece goes through
  them, so the town and the landmarks needed almost nothing else.
- `zone_landmarks.gd`: the graves' wall boxes (built with `LowPoly.at` and a map yaw) through
  `yaw_to_world`; the crypt's walls drawn the other way round.
- `zone_town.gd`: the town's wall runs reversed (clockwise on the map) so the merlons, which
  `ZoneProps.wall` puts on a run's left, stay outside. In the old world a counter-clockwise run
  on the map was clockwise on the ground.
- `zone_flora.gd`: the scatter stays on the map (roads, clearings, the edge); the ground is
  sampled at the world point, and the batches are keyed by world cells.
- `scenes/world.tscn`: the six NPC nodes at z = -5. The sun needed nothing: its arc lies in the
  east-west plane (the light's direction has no z component at any hour), so a mirror in z
  leaves it alone.
- `autoloads/sense_heading.gd`: the ring now starts at North (rotation.y = 0 faces -Z).
- `scripts/hud.gd`: `/loc` prints `Your location is N, W, H (north, west, height).`, that is
  `-z, -x, y`; `/loc raw` prints `Your world position is x, y, z (x, y, z).`
- `tools/author_terrain.gd`: the composition and the edge read each vertex at its map point;
  the report converts every map point (roads, sites, unreachable points) to the world and
  prints world coordinates; a set piece more than 80 m from its camp is now a FAIL (it was a
  WARN; it is the row that catches a half-mirrored pair); the paint is painted on the map,
  flipped top to bottom once, and the mountains' rock laid on after (it reads the
  world-indexed edge grid).
- `tools/check_zone_scenery.gd`, `tools/probe_zone_world_loads.gd` (its drops now map points),
  `tools/shoot_zone.gd` (every viewpoint's z negated; a straight-down view now has north at the
  top, where it had +z at the top and so showed the new world south-up).

## 5. The server

No code change. `zone_camps.toml` (54 spawns) and `npcs.toml` (6) had every z negated by a
script that refused to write unless it changed exactly that many; `safe_areas.toml` sits on
the origin and did not change. `terrain.toml` re-exported: **hash `6bedde1c663e`**. Tests: the
camp-pull constants (`BONEPILE_SPAWN` (-216, 0, -54), `CAMP_PULL_START` (-200, 0, -68)), the
plateau ramp perch (the GM at (1435, -407) so the dev spawn, 3 m in front at yaw 0, lands at
the mirrored (1435, -410)), the compiled terrain's ridge and pass at z = -900, the gap test's
corridor behind the east door at z 870 to 930. One test walked from the camp-pull start in a
hard-coded direction (`charm_converts_a_camp_mob_that_is_fighting_someone_else`) and failed
until the direction was derived from the two constants.

## 6. Results

- The author's report: clean. 8.81 square km inside the edge both before and after; a walk
  from the town reaches 51.1% of the triangles (51.2% before); 9,423 faces (9,335 before); the
  steepest road 15.2 degrees both times. The difference is the triangle diagonals, which are
  fixed in the world and so do not mirror.
- Server: fmt and clippy clean; 411 unit, 184 world, and every other binary green.
- Client: all 17 checks (the new compass check among them) against `server-zone`; the zone
  probes (`probe_zone_world_loads`, `probe_terrain_stand`, `probe_cast_sight`,
  `probe_login_facing`) green.
- Looked at with `tools/shoot_zone.gd`: the top view north-up matches the comp (the pass at the
  top, the barrow to the west, the Wraith Gate's cliff to the east, the war camp's vale to the
  south); the town from the south-west with the tower on the east wall north of the gate; the
  Wraith Gate's arch lit at its lip; the barrow door glowing in the pit's west wall.

## 7. The review pass

`/code-review` on the branch, 13 findings. Fixed: the redeploy SQL now mirrors the saved
facing too (`yaw` becomes PI - yaw; the client seeds the body's facing from it since 11-09)
and leaves a one-row `compass_mirrored` table so running it twice changes nothing (tested
twice on a copy of the dev database); the six NPC nodes turned to face the square again (an
identity basis at z = -5 faced away from it); two server unit tests in `npcs.rs` and two
flat-town assertions in `height.rs` still stood on the old NPC row; `/loc` printed `-0.0` on
an axis; `/location raw` did not work; `commands.md` still said the author only warns on a
drifted set piece; the town's signposts (half pointed back at the town before the mirror and
the other half after it) all point out along their roads now; the compass check's ridge
search takes the clearly higher side instead of failing when both sides have high ground;
`PASS_SOUTH_Z` / `PASS_NORTH_Z` renamed `PASS_SOUTH` / `PASS_NORTH` (they hold map north
values); the vertex-to-map expression the heights and the edge both read is one helper.
Not changed: `ZoneProps.wall` still puts merlons on a run's left, so a new wall's winding
decides its side (both callers say so in a comment); the smoke's drift direction is a world
vector (it now drifts south-east, which nobody authored either way); the mill's sails sit on
the east-west axis, which the mirror leaves alone.

## 8. Merged and exported

Both deploy branches fast-forwarded to `feat/compass-mirror` and pushed by name, with the
feature branches (server `27d5ea7`, client `fd17ff1`); the main checkouts were clean at the
deploy tips first. In the main client checkout: a reimport, then all 17 checks against the
merged server. The export: `[BuildStamp] stamped fd17ff1`, `--export-release`, the exported
build booting clean headless, the hand-copied `gdext_net.dll` identical to the source build (no
wire change); `builds/ProjectDawn-alpha-fd17ff1.zip` (37,804,837 bytes), which replaces
`7c7a810`.

**Left for the user:** the R720: everyone logged out; `git pull` and `cargo build --release`
as `projectdawn`; `systemctl stop`; a `.backup` of `world.db`; the guarded SQL from the To-Do
entry; the `cp`; `systemctl start`; the boot line must read `dev_cmds=false` and
`terrain=400x400 cells of 10 m, floor 0, hash 6bedde1c663e`. Then sending `fd17ff1`, and
`zone_4km_checklist.md` section 8 (and section 7, still unplayed).

## 9. Flagged, not changed

- Pieces turn but never mirror: an asymmetric piece keeps its own handedness.
- The pass's west mouth shows one long dark facet where a diagonal now runs across the corner.
- The redeploy needs the SQL in the To-Do entry during the stop, after a `.backup`: every
  saved position, bind and facing mirrored with the world, and every corpse. No server code
  for older characters (the standing rule).

## 10. Records

CLAUDE.md's compass entry; `docs/reference/invariants.md` rule L3; `commands.md` (`/loc`,
`/loc raw`, the compass check); `docs/design/location_command.md` revised; the tester sheets'
positions as the new `/loc` prints them (`CHECKLIST_FOR_TESTERS.md` rows 6, 20 and 24,
`README_FOR_TESTERS.md`, `pre_door_check_checklist.md` section 9, `zone_4km_checklist.md`'s
table and section 7) and `zone_4km_checklist.md` section 8, the compass rows.
