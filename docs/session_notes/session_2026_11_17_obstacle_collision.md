# Session 2026-11-17: obstacle collision, planned and built

**Asked for (user):** "Currently players are able to run through structures and trees etc.. We
need something for collision. Can you write a plan for this? or perhaps Godot has something
built in? let me know what you think is the best approach." Then, on the plan's eight calls:
everything solid should block; "can we not just mirror the geometry of the object to create
the boundary for the object?"; "if the tree or rock block visibility, they should prevent the
caster from casting"; yes to mobs, to bodies passing through each other and to the camera;
"build it now, please. I believe in you."

**Outcome:** built on `feat/obstacles` in both repos (worktrees
`F:\Projects\Project_Dawn-obstacles`, `F:\Projects\server-obstacles`), then, on the user's
"lets go for it", **merged into both deploy branches, pushed and exported** (server
`87c58fe`, client `a1a154e`, `builds/ProjectDawn-alpha-a1a154e.zip`; section 8). **Not
deployed on the R720, not playtested.** The design as built is
`docs/design/obstacle_collision.md`; the sheet is `obstacle_collision_checklist.md`.

## 1. The answer on Godot's built-in collision

It exists and cannot be the whole answer: the server moves the body from the direction sent,
so a wall only the client has is walked through on the server and the client snaps after it;
a modified client removes its own walls; and the server's world has no height above the
ground, so a 3D collider's top is somewhere a client body can stand that the server drags it
off. The server holds the obstacles; the client runs the same rule on the same file. Godot's
own collision is used for the camera only.

## 2. What was built

- **Solids record themselves.** `LowPoly` notes the corners of every closed solid (box,
  gable, column, blob) and a sight scale for shapes that taper; `solid = false` for floors.
  `ZoneDressing.add_piece` and `ZoneFlora` hand them over.
- **The bake** (`ZoneObstacleBake`): each solid becomes a prism (convex outline from above on
  a millimetre grid, base, top, WALK and SIGHT flags). A planted thing is at most a foot and
  a crown. 33,199 prisms: 19,580 WALK, 31,012 SIGHT.
- **One file, both sides** (`tools/export_obstacles.gd`): `data/zone_obstacles.bin` and the
  server's `data/obstacles.bin`, the same 2,165,024 bytes, hash `f97d25964ce4`.
- **One rule, both sides** (`world/obstacles.rs`, `scripts/zone/zone_obstacles.gd`):
  `resolve`, `clear_of`, `can_leave`, `stands`, `sight_blocked`.
- **Server:** players (ground and air), placements, sight through `Terrain::can_see`, mobs
  and pets with a way round walls, spawns clear of scenery.
- **Client:** the body, the cast pre-check, camera blockers (630 solids on physics layer 5),
  the Test Panel's Obstacle Outlines, the obstacle hash in `debug.log`.
- **Scenery:** fences in 3 m stretches that follow the ground, a 4 m gateway per field; the
  Ossuary's dais, the Wraith Gate's steps and the crypt's steps marked as floors.

## 3. What the tests found on the way

- **The client's port was wrong in one place.** `check_obstacle_rule.gd` replays the
  server's answers; 27 of 1,150 differed. `resolve` set its "deflected" flag before calling
  `clear_of`, whose trial steps reset it. Fixed; 0 differ.
- **One fenced field was a sealed box** (5,870 m² nobody could enter), and about forty tiny
  gaps between scattered rocks and trunks were free ground with no way out. The first is a
  scenery fix (gateways); the second is why `can_leave` exists: nothing is put where it could
  not walk 3 m away.
- **Only one of the five fields was sealed**, because a 94 m level rail floats over dips and
  was a fence in some places and not others. Fences are now built in stretches on their own
  ground.
- **A trunk met square on its flat face stops a body.** That is the boundary following the
  low-poly shape; it is on the checklist as a feel question.
- **Any deflection started a mob's stuck clock**, so a mob chasing through a wood would have
  turned immune at a tree and given up eight seconds later. Only a held step counts now
  (`a_mob_glancing_along_a_wall_is_not_held`).
- **Clippy** read the ring directions (`0.707107`) as a sloppy constant; the table is
  two-place directions now, written out identically on both sides so no cosine's last bit
  differs between builds.

## 4. Verification

- Server: `cargo test` 481 unit (1 ignored, as before) and 201 world, clippy `-D warnings`
  and fmt clean. 41 tests are new. Run with the rule off, the four player and sight
  integration tests, the house test (detour off) and the spawn test (`place` removed) fail.
- One earlier full run had `roam::a_wanderer_goes_home_to_where_its_fight_began` fail ("the
  wolf never walked 15 m" inside its 40 s). I was compiling in the same directory at the
  time. It passed three times alone and in the two full runs made with nothing else running.
  Recorded here because the standing rule is that any failure is real: this one looks like a
  deadline close to the slowest honest case (a 25 s pause, then 15 m at 1.2 m/s), not
  something this branch changed (its harness runs with no obstacles).
- Client: `check_all.ps1 -ServerRoot F:\Projects\server-obstacles` 19 of 19;
  `probe_obstacle_walk.gd` 12 checks (the real body rests at 9.600 m against a face at 10);
  `probe_cast_sight.gd` 8 checks; the other player and world probes pass.
- The real server binary was booted on spare ports with a throwaway database: boot line
  `obstacles=33199 prisms (19580 walk, 31012 sight), hash f97d25964ce4`, 66 roam slots, 84
  animals, no error.
- **Not verified:** nobody has walked the zone. No screenshot was looked at.

## 4b. The review pass

`/code-review high` on the server branch: ten findings, each checked against the code.

1. **The wall-follow never rounded a wall with its target close behind it.** A step toward
   the target that slides always slides back to the point nearest the target, so the mob
   dithered at the 30 degree line, evaded and gave up: anyone could shed any mob at a fence.
   Fixed: a held mob scouts both ways along the wall and takes the shorter, and keeps to the
   wall until 3 m of its run at the goal is clear.
2. **One bump on a tree started the stuck clock for good** (only a metre gained ended it), so
   a chase through a wood ended 8 s later. Fixed: a second of steps taken as aimed ends it.
   I had flagged this as a residual; the reviewer was right that it was a defect.
3. **A sight line from inside a crown was blocked by that crown.** A small pine's crown
   starts about 1.3 m up, so on any upslope beside the trunk the eye is inside it: 653 trees
   had such a spot, where nothing could be cast and no mob would notice. Fixed on both
   sides: a line that begins or ends inside a prism is not blocked by it.
4. A ported pet was dropped 1.5 m east with no check. Fixed (walked, as at a summon).
5. `place` could stand a moved body on a face. Fixed: it prefers a floor.
6. Corpses were not placed clear at load. Fixed.
7. The rule's lookups allocate on every pass. Not fixed; a residual in the design.
8. Two handles for one set of obstacles. Fixed: the ground's is the only one.
9. `prism()` read the sight scale back as 1. Fixed.
10. A comment parted from its module by rustfmt's reordering. Fixed.

After the fixes: 481 unit and 201 world tests, clippy clean, the client's replay of the
regenerated fixtures 0 differ.

## 5. Commits

- Server `feat/obstacles`: `84dcf63` (players, placements, sight, the file and fixtures),
  `2b9e3df` (mobs, pets, spawns), `6343924` (only a held step starts the stuck clock), then
  the review pass.
- Client `feat/obstacles`: `396b47b` (the bake, the rule, the body, the checks), then the
  camera, the outline view, the probes and the records in the commit after it.

## 6. Not done

- The R720 redeploy (the user's, with the zip, together) and the playtest.
- `systems_overview.md` is untouched until the playtest ticks.
- Standing on things and hopping over low ones; a pathfinder; interiors (design 4.9).
- The GM flight client branch is not merged here: its flying body must skip the obstacle
  step when the two meet.

## 7. Other sessions

`project-dawn-5b` built group-mate levels on `feat/group-levels` and fast-forwarded the
client deploy branch to `1a8e898`, then `063f3f5`, during this session. This branch was cut
from `063f3f5` (client) and `7e0095f` (server), so it carries that work. My first plan and
its records were uncommitted in the main checkout; they were moved onto this branch and the
main checkout left clean.

## 8. Merged, exported, and the deploy shape

On the user's "lets go for it" (to the question of when to merge):

- Both deploy branches were at this branch's cut points, so both merges were fast-forwards:
  server `7e0095f` to `87c58fe`, client `063f3f5` to `00f5c5d` (the branch with its
  `(on feat/obstacles)` tags dropped from the rules), then `a1a154e` (the tester README and
  checklist: they told testers that walking through walls and trees was not a bug). Pushed,
  with `feat/obstacles` in both repos.
- `check_all.ps1` on the merged main checkouts: 19 of 19.
- The export, `--export-release` from the main checkout clean at `a1a154e`:
  `[BuildStamp] stamped a1a154e`, not a debug export, the DLL the group-levels one (md5
  `097ace2a`, PD_W0031; this work changes nothing on the wire). The first export was made
  before the push and its stamp read "+5 unpushed"; it was made again after the push.
- The exported build boots headless (300 frames, exit 0, no error line) and passes
  `tools/probe_obstacle_walk.gd` run from inside the export: the obstacle data is in the pack
  (the export preset's include filter is what ships it; the exe grew by 2.2 MB).
- The zip `builds/ProjectDawn-alpha-a1a154e.zip` (39,425,944 bytes: the exe, the console exe,
  the DLL, the tester README and the players' checklist) replaces `54ca951` and `397e207`.

Both sides together: the redeploy and the new zip. No migration, no SQL. The boot line must
read `build="87c58fe" dev_cmds=false roamers=on`, the terrain hash unchanged
(`f569ade0c331`), and `obstacles=33199 prisms (19580 walk, 31012 sight), hash f97d25964ce4`.

The session ran out of budget between the export and the records;
`docs/design/handoff_obstacle_collision_2026_11_17.md` was written for the next session, and
this session then finished what it lists itself: the records, the memory, and planner rows
b64, o30, v65 and v66 (the last for `group_levels_checklist.md`, which the generator reported
as unscheduled), with both planner files regenerated. The published planner page was not
republished: the publish step needs the live page and the new one read in full, about 320 KB,
and that spend was left for the user's word.

