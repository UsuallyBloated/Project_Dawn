# Obstacle collision: trees, rocks, walls and set pieces that stop a body

**Status:** designed 2026-11-17 and, on the user's answers the same day ("build it now,
please"), **BUILT 2026-11-17 on `feat/obstacles` in both repos** (worktrees
`F:\Projects\Project_Dawn-obstacles` and `F:\Projects\server-obstacles`; committed locally,
not pushed, not merged). Pending the user's call on the merge, then an export and a redeploy
together, then `docs/playtest_notes/obstacle_collision_checklist.md`.
**Asked for (user, 2026-11-17):** "Currently players are able to run through structures and
trees etc.. We need something for collision. Can you write a plan for this? or perhaps Godot
has something built in?"

Everything solid in the zone now stops a body, blocks a line of sight, and (for the big
things) stops the camera. The server decides all of it. This document is the design as it
was built; section 9 has the user's answers and section 10 what differs from the first plan.

---

## 1. Does Godot have this built in?

Yes: a `StaticBody3D` with a `CollisionShape3D` on every wall and trunk would stop the
player's body on the client, since the player is already a `CharacterBody3D`. It cannot be
the answer by itself, for three reasons:

1. **The server moves the body.** A Move carries the direction held, not where the body got
   to. With a wall only on the client, the client's body stops while the server walks the
   player through; a moment later the two are a metre apart and the client snaps through
   the wall to where the server has it.
2. **A modified client deletes its own walls.** Walls matter for sight, for where a mob can
   reach a player and for where a player can hide, so they have to be the server's.
3. **The server's world has no height above the ground.** It keeps an x, a z and the ground
   under them; the jump is cosmetic. A 3D collider on the client has a top a body can land
   on, and a body standing on something the server treats as solid is a body the server
   keeps dragging off.

So the server holds the obstacles and runs the rule, and the client runs the same rule on
the same data so its picture agrees. Godot's own collision has one job: the camera (4.8).

---

## 2. The design in one paragraph

Every solid of the scenery records its own corners as it is built. A bake turns each into a
**prism**: its outline seen from above (the convex hull of its corners), with the height of
its lowest and highest point. One exporter writes all prisms to one file, the same bytes for
the client and the server. One rule, written in Rust and in GDScript and checked against
each other: a step is taken in short pieces, and after each, a body whose centre is inside
a prism's outline grown by the body's radius is moved out the shortest way, which is a
slide along the surface. The server applies it to every step it takes for a player, a mob
or a pet; the client applies it to its own body. Every way a body is put somewhere without
walking goes to the nearest point clear of everything that it can also walk away from. A
line of sight is blocked where it passes through a prism between its base and its top.

---

## 3. What exists (both repos, branch `feat/obstacles`)

| Piece | Where | What it does |
|---|---|---|
| Solids record themselves | client `scripts/zone/low_poly.gd` (`volumes()`) | Every closed solid the builder makes (box, gable, column, blob) notes its corners and how much of its outline blocks sight (1 for a box, less for a shape that tapers). Loose sheets and triangles (banners, webs) record nothing. `solid = false` round a floor (a dais, steps). |
| The scenery hands them over | `zone_dressing.gd` (`add_piece`), `zone_flora.gd` (`placed_kinds`, `placed_transforms`, `kind_volumes`) | The town and the landmarks give every solid of every piece; the flora gives each planted thing's kind and transform. Glows (fire, magic light) are added another way and record nothing. |
| The bake | `scripts/zone/zone_obstacle_bake.gd` | Each solid becomes a prism: outline (convex hull, millimetre grid), base, top, flags. A planted thing is at most two prisms: its foot (trunk, bush, boulder) and its crown. |
| The file | client `data/zone_obstacles.bin`, server `crates/projectdawn-server/data/obstacles.bin` | Header, 32-bit floats, SHA-256 trailer. 33,199 prisms, 2.2 MB: 19,580 stand in a body's way, 31,012 block sight. Hash `f97d25964ce4`. |
| The rule, server | `world/obstacles.rs` | `resolve` (a step), `clear_of` / `place` (a placement), `can_leave` / `stands`, `sight_blocked`. Compiled in (`include_bytes!`), hash checked, on the boot line. |
| The rule, client | `scripts/zone/zone_obstacles.gd` | The same functions on the same file. |
| Players | server `world/tick/movement.rs`; client `scripts/player.gd` | The server resolves the step the terrain allowed, on the ground and in the air. The client resolves each frame's whole movement, after the blend toward the server. |
| Placements | server `Obstacles::place` | Login, respawn, ports, the resurrection summon, camp and dev spawns. A wanderer's spot must `stands` (`RoamMap::spot_ok`). A pet's 1.5 m beside its owner is walked, not jumped. |
| Sight | server `Terrain::can_see`; client `Spells._target_out_of_sight` | The ground carries its obstacles (`Terrain::with_obstacles`), so every existing sight check includes them: targeted spells, heals, ranged attacks, AoE victims, song pulses, the idle mob's scan. |
| Mobs and pets | server `Entity::step_on`, `roam_step` | The same rule at the same radius; a held step is tried turned to one side and the other (4.7). |
| Camera | client `scripts/zone/zone_camera_blockers.gd` | 630 big solids as real shapes on physics layer 5, read by the spring arm only. |
| Dev view | client `scripts/zone/zone_obstacle_outlines.gd`, Test Panel "Obstacle Outlines" | Every prism near the camera drawn over the scenery: red stops a body, blue blocks sight only. |

No wire change, no DLL rebuild, no migration, no SQL.

---

## 4. The pieces

### 4.1 What is solid

A prism **stands in a body's way** (`WALK`) when it comes down to within 1.0 m of the ground
under it and rises at least 0.3 m above it. So a crown, a roof's overhang, a gate's lintel
and an arch's span do not, and anything under shin height is stepped over. Everything else
does: trunks, bushes, scrub, boulders, bones, walls, towers, gate piers, houses, sheds'
posts, tents, palisade stakes, standing stones, spires, fences, barrels, crates, signposts,
banner poles, gravestones (the user's call: everything blocks).

A prism **blocks sight** (`SIGHT`) when it is at least 0.3 m wide at its narrowest and has
0.3 m of itself above the ground: a trunk, a rock, a bush, a wall, a crown, a roof. A
banner's pole and a fence's rail do not. A tapering shape is drawn in for sight (a cone to
half its width, a ball to four fifths), so a crown's thin top does not block what a player
can plainly see past.

For walking a prism is a column of any height: nothing is stood on or jumped over (4.9).

**Floors are not obstacles.** The Ossuary's dais, the Wraith Gate's steps and the crypt's
two steps are built with `solid = false`: the camps' mobs stand on them, and the server has
no floors above the ground. They are drawn and walked through, as before.

### 4.2 The file, the export and the checks

- `tools/export_obstacles.gd` builds the world headless, bakes, reads the result back as the
  game will, and writes the same bytes to both repos. Run it after any change to the
  scenery or the ground; always pass the server path.
- The client collides from the exported file, not from its live scatter: if a machine ever
  planted one tree differently, the worst case is a tree drawn off its collider, never a
  client and a server that disagree about where a body stands.
- `tools/check_obstacle_lockstep.gd` (in `check_all.ps1`): the scenery bakes to the client's
  file; the client's file is the server's; a second bake is the same bytes; the file loads;
  every export preset ships it; the camera's blockers are on a layer the body does not read.
- `tools/check_obstacle_rule.gd` (in `check_all.ps1`): the server's tests write
  `data/obstacle_rule_fixtures.txt` (a small scenery, and the rule's answers for 600 steps,
  150 placements and 400 sight lines); the client replays them through its GDScript rule and
  fails on any that differ. It caught a slip in the port on its first day.
- `tools/check_constant_lockstep.gd` holds the rule's thirteen numbers equal.

### 4.3 The rule

`resolve(from, to, radius)`:

1. With nothing near the step, the step is taken whole (`to` comes back untouched, so open
   ground behaves exactly as it did).
2. Otherwise the step is taken in pieces of at most `SUBSTEP` (0.1 m). After each, every
   nearby prism pushes the point out the shortest way (through the nearest edge, or round
   the nearest corner), up to four passes.
3. A piece ends the step where the body last stood free if the point cannot be settled, or
   if settling moved it more than `PIECE_STRETCH` (1.5) times the piece. That cap is what
   makes crossing a solid impossible whatever the scenery: to stand free on the far side of
   even a sheet of paper a body's centre has to travel twice its radius.

`clear_of(p)` returns the nearest point where a body `stands`: free of every solid **and**
able to walk 3 m away in some direction (`can_leave`). Thousands of scattered rocks and
trunks close a few gaps a body fits in and cannot leave; nothing is ever put in one.

A body run square into a flat face stops until it steers, on a trunk's face as on a wall:
the boundary is the solid's own shape.

### 4.4 Players

Server, on the ground: the terrain's step, then `resolve`, then the slope rule once more on
the result (a rock at a cliff's foot must not push a body up the cliff; such a step is not
taken). In the air: the same `resolve`, so a falling body comes down beside a trunk or a
house, never in one. A standing body found inside a solid is put out. GM flight ignores
obstacles in the air and lands beside them.

Client: `move_and_slide` on the ground, the blend toward the server, then `resolve` on the
frame's whole movement. The blend pulls in a straight line that can cut through a trunk,
which is why the rule runs after it.

### 4.5 Placements

`Obstacles::place` at: a login's saved position, a respawn, a port's destination, the
resurrection summon, a camp spawn (the mob's home becomes where it stands), a dev spawn, a
corpse at load. A point a body can already be put at is never moved; one that must move
goes to the nearest point that is clear, that a body can walk away from, and that is a
floor (moved out of a rock at a cliff's foot, a body is not stood on the cliff). A wanderer
appears only at a spot that `stands`. A pet's 1.5 m east of its owner, at a summon and at a
port, is a walk from the owner, so with a wall at the owner's shoulder the pet is on the
owner's side.

### 4.6 Sight

`Terrain::can_see` asks the terrain and then `Obstacles::sight_blocked`: the line is clipped
to each nearby prism's outline, and is blocked if it is between the prism's base and top
anywhere inside it. A caster on high ground sees over a house; nobody sees through one. A
trunk, a rock and a crown block as a wall does (the user's call).

A line that begins or ends **inside** a prism is not blocked by that prism (every other one
on the line still blocks). A small pine's crown starts about 1.3 m above its own ground, so
a body a step uphill of the trunk has its eye inside it; without this rule that body could
cast at nothing and nothing could notice it (the review found such a spot at 653 trees).
No body is ever inside a prism that stands in its way, so this is crowns, roofs and lintels.

### 4.7 Mobs and pets

`Entity::step_on` runs `resolve` at the players' radius, so a mob fits wherever a player
does. There is no pathfinder; this is what gets a mob round a wall:

- A step held to less than half its way (`DETOUR_BELOW`) is tried turned 45 and 90 degrees
  to each side. Where both sides move, the mob looks up to 24 m along the wall each way
  (`scout_way_round`) and sets off the shorter.
- It then keeps on along the wall, bending with it, until 3 m of the straight line to its
  goal is clear (`DETOUR_LOOKAHEAD`, `Obstacles::run_clear`), and only then turns for the
  goal. Turning back as soon as a step toward the goal slides is what the first version
  did, and it never rounded a wall with its target close behind: the slide always leads
  back to the point nearest the target. The review found that; the house test had passed
  only because its target stood 17 m off.
- A wall that ends in a corner sends it the other way.

Only a step that does not get on with it counts against a mob (the stuck clock and the
evade rule that already existed for a mob below a cliff): a glance off a trunk or a slide
along a shallow wall is the chase going on. A mob that is held, or walking along a wall, is
evading after one second and gives up after eight with no metre gained. A second of steps
all taken as aimed ends the clock (`STUCK_CLEAN_SECS`), so one bump on a tree does not end
a chase eight seconds later. So a wall never gives a free kill, and a wood does not shed a
mob.

Wanderers slide round trunks on their legs; a leg ends at anything that holds it.

### 4.8 The camera

`ZoneCameraBlockers` builds a `ConvexPolygonShape3D` for each walk prism at least 4 m² from
above and 2.5 m tall (630 of them: walls, towers, houses, tents, great rocks; no trees) on
physics layer 5. The spring arm reads that layer. The player's body does not, and click
rays do not, so targeting is unchanged.

### 4.9 What is not built

- **Standing on things, hopping over low ones.** The data carries every solid's real base
  and top, so this is an added rule (the server simulating the jump and treating tops as
  floors), not a rebuild. It changes core movement and every rock becomes somewhere a mob
  cannot follow, so it wants its own design.
- **A pathfinder.** Mobs go round what one wall-follow gets them round.
- **Interiors.** A house is solid.

---

## 5. What does not change

The wire; ranges (a vendor, a banker and a corpse are reached by distance alone); players,
mobs and pets passing through each other; the jump being cosmetic; the terrain, the slope
rule and the mountains' edge; click targeting.

Both sides move together: a new server with an old client is pulled back at every tree, and
the other way round walks through them and snaps. One export, one redeploy.

---

## 6. Exploit ledger

| # | Attack | Answer | Held by |
|---|---|---|---|
| 1 | A modified client ignores walls and trees | The server takes the step and resolves it itself. | `a_direction_held_through_a_house_ends_at_its_face` |
| 2 | Cross a thin solid at speed, or by being squeezed between two | Pieces of 0.1 m and the `PIECE_STRETCH` cap. | `the_largest_step_crosses_nothing`, `a_body_squeezed_between_solids_is_never_squirted_across_one`, `random_walks_never_end_inside_anything` |
| 3 | Get placed inside something | Every placement goes through `place`; a body found inside is put out at the nearest edge. | `a_login_inside_a_solid_lands_beside_it`, `placing_a_body_stands_it_clear_and_on_the_ground` |
| 4 | Be placed in, or spawn a mob in, a gap nothing can leave | `stands` refuses gaps under 3 m across; the zone holds no larger pocket. | `a_body_is_never_put_in_a_gap_it_cannot_leave`, `nothing_in_the_zone_closes_a_pocket_a_body_could_be_put_in` |
| 5 | Stand where a mob cannot fit | One body radius for everything. | `Entity::step_on` uses `BODY_RADIUS` |
| 6 | Stand where a mob cannot reach and kill it | Solids block sight; a held mob evades after 1 s and gives up after 8. | `a_spell_through_a_house_is_refused_and_lands_round_the_corner`, `a_mob_in_a_dead_end_evades_and_gives_up` |
| 7 | Cast, shoot, sing or AoE through a wall | Every sight check asks the ground, which carries the obstacles. | `a_line_through_a_solid_is_blocked_and_one_over_it_is_not` |
| 8 | Send a pet through a wall by summoning beside it | The pet's spot is walked from the owner. | `a_pet_summoned_at_a_wall_appears_on_its_owners_side` |
| 9 | Hand-edit either copy of the file | The server refuses a file that fails its hash at boot; an edited client file changes only that client's picture. | `a_file_round_trips_and_a_damaged_one_is_refused` |
| 10 | Land on a roof from a cliff, or quit mid-fall over one | A prism is a column: the falling step is resolved too. | the airborne branch of `run_movement` (no test of its own) |
| 11 | Wall the town off, or seal a camp, by a scenery mistake | The zone's own tests. | `the_four_gates_are_open_and_the_wall_beside_them_is_not`, `every_camp_spawn_is_on_or_beside_free_ground`, `the_towns_people_and_every_arrival_point_stand_on_free_ground` |

**Known residuals, none a free kill:**
- A mob sliding along a long low fence toward the point nearest its target is damageable
  for that slide plus the one-second grace, then immune. The same size of window as the
  cliff's.
- A building sheds a chasing mob in eight seconds if the mob finds no way round. Running
  past its leash already does that.
- A closed space sealed between solids and a **cliff** is not found by the pocket test (it
  looks only at solids). The three road doors stand against the mountains, and a wanderer
  could in principle be given a spot behind one.
- The airborne branch, GM-flight landing and a ported pet's placement have no integration
  test.
- A body moved out of a solid goes out the nearest way, which can be the far side of a thin
  wall. It happens only when the scenery changed under a saved position or a spawn.
- The rule gathers its nearby prisms afresh on every pass (the review's efficiency note):
  a few dozen small allocations per obstructed step. Unmeasured in play; the `world health`
  line will show it if it matters.

---

## 7. Cost

Server: a grid lookup and a few polygon tests per mover per tick; the suite's world tests
run in the time they did. Client: one lookup a frame. The file is 2.2 MB in each repo and is
rewritten whole on every scenery change, as `terrain.toml` is.

---

## 8. Tests

Server (`cargo test`: 481 unit, 201 world, all passing; clippy and fmt clean):
- `world/obstacles.rs`: 24 tests on the rule, the file, sight, placement and the fixtures.
- `world/obstacles_content.rs`: 5 on the real zone (people and arrival points free, spawns
  near free ground, the four gates open and the wall shut, no pocket, the pocket search
  itself).
- `world/entity.rs`: 6 on mobs (round a house, round a long wall to a target close behind
  it from either side, round a trunk without evading, a glance is not held, a dead end
  evades and gives up, a clean second ends the clock); `world/spawn_points.rs`: 1.
- `tests/world/obstacles.rs`: 5 with a real client (a held direction ends at a house, a
  slide round a trunk, a login inside a solid, a Smite through a house, a pet at a wall).

Run against a server with no obstacles, the four player and sight integration tests fail;
with the detour switched off the house test fails; with the spawn's `place` removed the
spawn test fails.

Client: `check_all.ps1` 19 checks passing (two new); `tools/probe_obstacle_walk.gd` (the
real body rests at 9.600 m against a face at 10, as the server does; slides round a trunk;
the camera's blockers pull the camera in and let the body through);
`tools/probe_cast_sight.gd` gained the obstacle cases.

**Not verified:** nobody has walked the zone with it. The checklist is the evidence.

---

## 9. The user's answers (2026-11-17)

1. The approach (server-held outlines, one rule both sides): taken as yes with "build it
   now".
2. What blocks: "looks good, but the items listed as 'Does not block' should also block."
   Everything solid blocks.
3. Nothing stood on or jumped over: "can we not just mirror the geometry of the object to
   create the boundary for the object?" Done for the outline and for sight (every boundary
   is computed from the solid's own corners, with its real base and top). Standing on and
   hopping over are 4.9.
4. Sight: "if the tree or rock block visibility, they should prevent the caster from
   casting." Everything wide enough blocks, crowns included.
5. Mobs and pets collide: yes.
6. Bodies pass through each other: yes.
7. The camera stops at walls and buildings, not trees: yes.
8. Timing: "build it now, please. I believe in you."

Three calls made in the build, the user's to overrule: things under 0.3 m are stepped over;
fire, magic light, cloth and webs block nothing; each fenced field has a 4 m gateway on its
town side (a fence all the way round is a sealed box).

---

## 10. What changed from the first plan, and in the review

A `/code-review` pass on the server branch (2026-11-17) reported ten findings; all were
checked against the code and nine fixed (server `feat/obstacles`, the commit after
`6343924`): the wall-follow that never rounded a wall with its target close behind it; the
stuck clock that one bump on a tree started for good; a sight line from inside a crown
blocked by that crown; a ported pet dropped past a wall; placement onto a face; corpses
not placed clear at load; two handles for one set of obstacles; a sight scale read back as
1; a comment parted from its module. The tenth (allocations in the rule's lookups) is a
residual above.

- **Prisms from the geometry, not hand-declared circles and boxes** (the user's question 3).
- **Everything blocks**, and trees and rocks block sight (answers 2 and 4).
- **Mobs walk round walls** (a held step is tried to each side). The plan had them push and
  give up.
- **`can_leave`**: found by the zone's own test, which showed one fenced field sealed and
  some forty tiny gaps between scattered rocks and trunks.
- **Fences follow the ground** in 3 m stretches (a 94 m level rail floated over dips and was
  a fence in some places and not others).
- **The file is binary**, with its hash as a trailer.
- **The obstacles ride on the terrain** on the server, so no sight check can forget them.

---

## 11. Before it ships

1. Merge `feat/obstacles` in both repos (the user's call; the deploy branches are untouched).
   On the client, the GM flight branch's flying body must skip the obstacle step when the
   two meet (`player.gd`): flight ignores obstacles on the server.
2. Drop the `(on feat/obstacles)` tags in `docs/reference/invariants.md`.
3. Export the client and redeploy the server together. The boot line must read
   `obstacles=33199 prisms (19580 walk, 31012 sight), hash f97d25964ce4`, and the client's
   `debug.log` the same hash.
4. After any later scenery or terrain change: `export_obstacles.gd`, commit both files,
   `check_all.ps1`.
