# Session 2026-11-17: obstacle collision, planned and built

**Asked for (user):** "Currently players are able to run through structures and trees etc.. We
need something for collision. Can you write a plan for this? or perhaps Godot has something
built in? let me know what you think is the best approach." Then, on the plan's eight calls:
everything solid should block; "can we not just mirror the geometry of the object to create
the boundary for the object?"; "if the tree or rock block visibility, they should prevent the
caster from casting"; yes to mobs, to bodies passing through each other and to the camera;
"build it now, please. I believe in you."

**Outcome:** built on `feat/obstacles` in both repos (worktrees
`F:\Projects\Project_Dawn-obstacles`, `F:\Projects\server-obstacles`), committed locally.
**Not pushed, not merged, not deployed, not playtested.** The design as built is
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

- Server: `cargo test` 476 unit (1 ignored, as before) and 201 world, clippy `-D warnings`
  and fmt clean. 36 tests are new. Run with the rule off, the four player and sight
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

## 5. Commits (local, unpushed)

- Server `feat/obstacles`: `84dcf63` (players, placements, sight, the file and fixtures),
  `2b9e3df` (mobs, pets, spawns), `6343924` (only a held step starts the stuck clock).
- Client `feat/obstacles`: `396b47b` (the bake, the rule, the body, the checks), then the
  camera, the outline view, the probes and the records in the commit after it.

## 6. Not done

- No merge, no push, no export, no redeploy: the user's call (the door is 2026-11-19).
- No planner row in `docs/schedule_detail.toml`; the page was not regenerated.
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
