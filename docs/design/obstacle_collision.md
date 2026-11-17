# Obstacle collision: walls, trees and set pieces that stop a body

**Status:** designed 2026-11-17; eight decisions waiting on the user (section 9); nothing built.
**Asked for (user, 2026-11-17):** "Currently players are able to run through structures and
trees etc.. We need something for collision. Can you write a plan for this? or perhaps Godot
has something built in?"

Short answer: Godot does have collision built in, and it is the wrong tool for the main job
here. In this game the server moves every body, so the server has to know what is solid.
The plan is to describe each solid thing as a flat footprint (a circle or a box), give the
same footprints to both sides from one exported file, and run the same small rule on both
sides. Godot's own collision gets one job at the end: keeping the camera out of buildings.

---

## 1. What exists (read in both repos on 2026-11-17)

| Piece | Where | What it means here |
|---|---|---|
| The player's body | `scenes/player.tscn`, `scripts/player.gd` | A `CharacterBody3D`, capsule radius 0.4 m, height 2.0 m, moved by `move_and_slide`. It collides with the terrain and nothing else. |
| Who decides position | `player.gd`, server `world/tick/movement.rs` | The client sends a direction 20 times a second (`Net.send_movement`). The server integrates it (`run_movement`) at its own speed and fans the Position. The client's body is a prediction. |
| Reconciliation | `player.gd::_on_world_position`, `_physics_process` | After `move_and_slide`, X and Z are blended toward the server's last position (17.3 a second); past 1.0 m apart the body snaps. Y is never reconciled. The blend sets the position directly, with no collision test. |
| The server's step | `world/terrain.rs::player_step`, `world/fall.rs` | The step on the ground (shorter uphill, refused onto a face past 60 degrees), a fall branch for a body in the air, a flight branch for a GM. The largest step a player takes in one tick is 0.4125 m (`RUN_SPEED` 5.0, the strongest speed buff 1.65, `TICK_DT` 50 ms; speed buffs do not stack, `buffs::speed_mult` takes the largest). |
| Mobs and pets | `world/entity.rs` | Straight lines to the target, each step through `step_on` (the slope rule, then pinned to the ground). A mob held with no progress gives up after `MOB_STUCK_SECS` (8 s) and is evading while held (`is_evading`: nothing damages it). Wanderers walk legs in `tick_roam`. No pathfinding. |
| Sight | `world/terrain.rs::can_see`; client `Spells` (ray on physics layer 2) | Terrain only. Gates every targeted spell, ranged attack, AoE victim, song pulse and the idle mob's scan. |
| The scenery | `scripts/zone/` (`zone_flora.gd`, `zone_town.gd`, `zone_landmarks.gd`, `zone_props.gd`, `low_poly.gd`) | Built in code at load, placeholder shapes. The flora plants 16,363 things: 13,349 trees (pine 8,323, tall pine 3,517, dead tree 616, dark tree 530, broadleaf 363), 860 boulders, and 2,154 bushes, scrub and bones (counted with a headless build today). The town is a walled square 180 m across with four 9 m gates, five towers, about 35 buildings and the mill; the landmarks are twenty set pieces at the camps. |
| The rule that forbids collision today | `docs/reference/invariants.md` L2, `tools/check_zone_scenery.gd` (COLLIDES) | "What the server does not know never stops a body": no scenery node may be a physics body. The rule's own last line: "When the server learns obstacles, both sides get them together, with their own check." This plan is that. |
| The ground's export | `tools/export_terrain.gd`, server `data/terrain.toml`, `tools/check_terrain_lockstep.gd` | The pattern to copy: the client's scene is the source, an exporter writes the server's file, the file is compiled in with a SHA-256 that refuses a hand edit, the boot line names it, and a check fails when the two sides differ. |
| The open audit finding | To-Do, "Exploit-audit finding 10 residuals", part (b) | "Movement has a speed cap but no server-side collision, so a modified client clips through walls at legal speed." There are no walls on the server to clip through yet; this plan is where that finding closes. |

---

## 2. Does Godot have this built in?

Yes. A `StaticBody3D` with a `CollisionShape3D` on every wall and trunk would stop the
player's body on the client in an afternoon, because the player is already a
`CharacterBody3D` and `move_and_slide` slides along whatever it meets. Three reasons it
cannot be the answer by itself:

1. **The server moves the body.** A Move carries the direction held, not where the body got
   to. With a wall only on the client, the client's body stops at the wall while the server
   walks the player through it; a moment later the two are more than a metre apart and the
   client snaps through the wall to where the server has it. That is exactly what invariant
   L2 describes, and why the scenery was built without bodies.
2. **A modified client deletes its own walls.** Anything only the client enforces is a
   suggestion. Walls matter for sight, for where a mob can reach a player and for where a
   player can hide, so they have to be the server's.
3. **The server's world is flat footprints, and a 3D body has a top.** The server keeps an
   X, a Z and the ground under them; the jump is cosmetic. A real 3D collider on the client
   can be landed on (a boulder on a hillside, a low wall, a tree's collider from a cliff
   above), and a body standing on top of something the server treats as solid is a body the
   server keeps dragging off. Making every client collider "tall enough" fixes that and
   breaks clicking and the camera above every roof.

So the server needs the obstacles, and once it has them the client's half is the same rule
run early so the picture agrees. The rule is about sixty lines; porting it is cheaper and
more exact than making Godot's solver imitate it.

**Where Godot's built-in collision does fit:** the camera. A `SpringArm3D` already pulls the
camera in when the ground is behind the player. True-height box bodies on walls and
buildings, on a layer only the camera reads, keep the camera from looking through a house
(slice 4).

**Also considered, and rejected:** a physics engine on the server (Rapier) fed the scene's
meshes. Two different solvers never agree exactly at a contact, the project has already paid
for that kind of mirroring once (the uphill step was measured off the client's body and
copied), and nothing in a 2D footprint world needs a solver.

---

## 3. The design in one paragraph

Every solid thing in the zone declares a **footprint**: a circle (a trunk, a boulder, a
standing stone, the mill) or a box turned to any angle (a wall run, a house, a tower, a gate
pier, a tent). A footprint is a column of any height: nothing can be stood on or jumped
over. One exporter builds the scene headless and writes all footprints to one file; the
server compiles it in beside the terrain, hash and boot line included, and the client loads
the same data. One rule, written twice (Rust and GDScript) and checked against each other:
after a step, a body whose centre is inside a footprint grown by the body's radius is moved
out the shortest way, which is a slide along the surface. The server applies it to every
player step, so a modified client walks into the server's walls. The client applies it to
its own body so the two agree. Every way a body is placed without walking (login, teleport,
port, summon, spawn, landing) puts it at the nearest free point. Later slices let walls and
buildings block sight, make mobs and pets obey the same rule, and stop the camera at
buildings.

---

## 4. The pieces

### 4.1 Footprints

Two shapes, both in world X and Z:

- **Circle:** centre and radius.
- **Box:** centre, half width, half depth, yaw. Carries a `top` (the world height of its
  highest point) for the sight rule in 4.8; the walk ignores it.

Where they come from: the code that draws a thing also declares its footprint, so the two
cannot drift apart silently.

- `LowPoly` gains two recording calls, `solid_circle(xf, radius)` and
  `solid_box(xf, width, depth, top)`. They draw nothing; they add to a list on the builder.
- `ZoneProps` calls them inside the props that are solid (`house`, `wall`, `tower`, `gate`
  for its two piers and never its opening, `shed`, `tent`, `standing_stone`, `spire`, `arch`
  for its piers), so every house anywhere gets its footprint from the one function.
- `ZoneDressing.add_piece` collects a builder's footprints as it adds the mesh.
- `ZoneFlora` records a circle for each planted tree and each tall boulder, from the kind's
  trunk radius times the instance's scale.

When authored models replace the placeholders, a model's prop function keeps declaring the
footprint. A building with a doorway and a room becomes several thin boxes with a gap; that
works in this model for anything on one floor.

### 4.2 What collides

The test for "solid": taller than a person, so nobody expects to hop onto it.

| Collides | Footprint | Notes |
|---|---|---|
| Trees (all five kinds, 13,349) | circle at the trunk's foot radius times scale: 0.24 to 0.75 m | The crown does not collide. A floor on the radius (0.3 m) is a knob. |
| Boulders about 1.5 m and taller | circle, about 1.1 m times scale | Roughly a third of the 860 by the size curve; the exporter's report gives the count. Smaller rocks are stepped through, as now. |
| Town wall runs, corner towers, the watchtower | boxes | The four gate openings (9 m) stay clear. |
| Gate piers | two boxes a gate | |
| Houses, the shop, the bank, the inn, the barn, sheds | one box each | No interiors; a house is solid. |
| The mill, the well | circles | |
| Tents, palisade stakes, standing stones 1.5 m and taller, spires, arch piers, the crypt's wall stubs, the Wraith Gate's piers, the wagon wreck | circles and boxes | The crypt's walls run from 1.6 to 6.5 m: all solid. |

| Does not collide | Why |
|---|---|
| Bushes, scrub, bones, gravestones, milestones, the overlook's small waystones | Low. |
| Fences round the farm strips | Low; a solid fence would be an invisible wall above a rail, and nothing can be jumped (decision 2 can flip this). |
| Barrels, crates, the stall, signposts, banners, campfires | Clutter. |
| The three doors (fallen trees, rockslide, stake barricade) | They stand against the mountains' foot, which already stops a body. |

### 4.3 The file, the export and the checks

- `tools/export_obstacles.gd` (client): builds `world.tscn` headless as
  `check_zone_scenery.gd` does, gathers every footprint, rounds to a millimetre, sorts them
  in a fixed order, and writes two outputs from the same list: the server's
  `data/obstacles.toml` and a packed resource in the client repo that the game loads. It
  takes the server root as a parameter, as `check_all.ps1 -ServerRoot` does, so a worktree
  never writes into the deploy checkout by accident.
- **The client collides from the exported data, not from its own live scatter.** The scatter
  is seeded and has always come out the same, but if one machine ever planted one tree
  differently, colliding from the file means the worst case is a tree drawn a little off its
  collider, never a client and server that disagree about where a body stands.
- The server compiles the file in (`include_str!`, as `terrain.toml`), refuses a file whose
  hash does not match, and the boot line gains
  `obstacles=<circles> circles, <boxes> boxes, hash <12 hex>`.
- **The export's report** (it fails the export, like the terrain author's report): every
  camp spawn and its jitter corners, every NPC, every safe-area arrival point and the
  starter spawn are clear of every footprint by a body's radius; each of the four gates is
  open; no gap between two footprints is wider than zero and narrower than a body (a gap is
  either walkable or closed); nothing solid stands on a road; the counts by kind.
- `tools/check_obstacle_lockstep.gd` (in `check_all.ps1`): the scenery built now equals the
  client's packed data equals the server's file. It is the "own check" L2 promises.
- `tools/check_obstacle_rule.gd` (in `check_all.ps1`): the GDScript rule against the Rust
  rule. A server test writes a fixtures file (a few thousand random steps and sight lines
  with the answers the Rust code gave, regenerated and compared on every `cargo test`); the
  client check runs its port over the same cases and fails on any answer more than a tenth
  of a millimetre off.

### 4.4 The rule

`resolve(from, to, radius)` returns where the step ends and whether anything deflected it.

1. The step is taken in pieces no longer than `OBSTACLE_SUBSTEP` (0.2 m), so no speed
   carries a body across a thin footprint between two looks. A load check holds every
   footprint, grown by the smallest body, thicker than twice that.
2. After each piece, for every footprint near the point (a 10 m grid finds them; a cell of
   the Greywood holds about one tree): if the point is inside the footprint grown by
   `radius`, move it out the shortest way. For a circle that is along the line from the
   centre; for a box, out through the nearest face, or round the nearest corner. Up to four
   passes, so a corner between two walls settles.
3. A point still inside something after the passes goes back to the last free point: the
   step ends there.

Moving out the shortest way removes the part of the step that went into the surface and
keeps the part along it, which is what sliding is. Anything not finite stays where it was.

### 4.5 The server: players (slice 1)

- New `world/obstacles.rs` beside `terrain.rs`: the parsed file, the grid, `resolve`,
  `clear_of` (4.7) and, in slice 2, the sight test.
- `run_movement`, grounded branch: the terrain step as today, then `resolve` from the old
  position to the terrain's answer with `PLAYER_RADIUS` (0.4, a lockstep pair with the
  client's capsule), then the slope rule once more on the final point. If the deflected
  point breaks the slope rule (a tree at a cliff's foot pushing a body onto the face), the
  player stays. The final position always satisfies both rules.
- Airborne branch: the same `resolve` on the horizontal step, and again after the fall's
  slide down a face. A footprint is a column, so a falling body cannot land on a roof or in
  a trunk.
- Flight (GM, audited): ignores footprints in the air, as it ignores the slope rule; ending
  a flight lands at the nearest free point.
- The dead and the linkdead do not walk; nothing changes for them.

### 4.6 The client: prediction (slice 1)

- A small script holding the packed footprints, the same grid and the GDScript `resolve`.
- `player.gd`, each physics frame: `move_and_slide` (the ground, as today), the blend toward
  the server (as today), then `resolve` on the frame's whole movement. Running it after the
  blend matters: the blend moves the body in a straight line toward the server's slightly
  older position, and a straight line between two points on either side of a trunk passes
  through the trunk.
- No scenery node becomes a physics body for the walk. `check_zone_scenery.gd`'s COLLIDES
  rule stays, reworded in slice 4 to "no scenery body is on a layer the player's body
  reads".
- A dev view (a Test Panel toggle) draws the footprints near the player as outlines, so a GM
  can fly the zone and see every collider against its mesh.
- The client's hash of its obstacle data goes in the `debug.log` header beside the build
  stamp, so a client and a server on different obstacle files can be told apart from a log.

### 4.7 Placement: nothing ever stands inside (slice 1)

`clear_of(x, z, radius)` returns the nearest free point (the point itself when it is free).
It is applied wherever a body is put somewhere without walking there. These are the sites
the height model already pins to the ground: a login's saved position, `teleport_to` (Gate,
Succor, Evacuate, the resurrection summon, a respawn at the bind), the end of a GM's flight
or fling, a pet's summon and its warp to its owner, a mob's spawn and a wanderer's spawn
spot, a charmed mob handed back. A corpse or a bag lies where a body stood, so it is never
inside. This is a general rule, not a fix for old characters: any later scenery edit can
put a footprint where somebody logged out.

### 4.8 Sight (slice 2)

`can_see` gains one test after the terrain's: the line between the two points is blocked
when it crosses a **box** below the box's `top`. A caster on the plateau still sees over a
house; nobody sees through one. Trees and boulders never block (a trunk is thinner than a
body, and EverQuest's did not). Everything that reads `can_see` today follows without
change: targeted spells, heals, ranged attacks, AoE victims, song pulses, the idle mob's
scan. The client's pre-check before a cast gets the same test (the GDScript port, held by
the fixtures), so an honest player is refused before the bar with the server's line.

Sight comes before mobs on purpose. While only players collide, a mob walks through a wall
to reach whoever hit it, so a wall protects nobody. Once mobs collide, a wall that did not
block sight would be a place to cast from.

### 4.9 Mobs and pets (slice 3)

- `Entity::step_on` runs `resolve` with `MOB_RADIUS` before the slope rule. `MOB_RADIUS` is
  never larger than `PLAYER_RADIUS` (a test holds it), so there is no gap a player fits
  through and a mob does not.
- A circle never holds a mob: it slides round a trunk or a rock and carries on.
- A box can: a mob pressed square against a wall with its target straight behind it makes
  no progress. The rule that exists for a mob held below a cliff covers it unchanged in
  shape: a deflected step counts as a refused one for the stuck clock, the mob is evading
  after the 1 s grace (swings are an Evade, hostile spells are refused at no cost, DoTs
  deal nothing), and after 8 s it forgets that target, turns on the next attacker it can
  reach, or walks home and heals. A pet held from its owner warps to them, as now.
- A wanderer's leg ends when a step makes no progress; its spawn spots and its packmates'
  refill spots go through `clear_of`.
- Mob spawns are checked clear by the export's report, and `clear_of` holds at run time.
- **No pathfinder.** Mobs keep walking straight lines and sliding. The town wall is
  therefore a real refuge from anything that does not follow through a gate, and a house
  can shed a chasing mob after 8 s. Outrunning a mob past its leash already does the same,
  and the evade rule means neither pays a kill. Walking round buildings properly is its own
  later item (section 10).

One thing to settle with tests during the build: a mob rounding the largest boulders may go
more than a second without coming a metre closer and would read as evading for a moment.
The progress measure for a slide may need to count distance along the surface.

### 4.10 The camera (slice 4)

True-height `StaticBody3D` boxes for walls and buildings (not trees, which would make the
camera jump in a wood), built from the same footprints, on a new physics layer that the
`SpringArm3D` reads and the player's body does not. Whether left-click targeting should
also stop at a wall is a small follow-up to decide then.

---

## 5. What does not change

- The wire. No protocol bump, no DLL rebuild, no migration, no SQL.
- Players, mobs and pets still pass through each other (decision 6). A body can never block
  a gate.
- The jump stays cosmetic; falls stay the server's.
- The terrain, the slope rule, the roam map and the mountains' edge.
- Range checks. A vendor, a banker and a corpse are still reached by distance alone; a wall
  between does not matter.

Both sides move together: a new server with an old client rubber-bands at every tree, and
the other way round walks through them for a tick and snaps back. One export, one redeploy,
as with every terrain change.

---

## 6. Exploit ledger

| # | Attack | Answer |
|---|---|---|
| 1 | A modified client ignores walls and trees | The server integrates every step and applies `resolve` itself; the client is pulled back. Test: a client holding a direction through a house never has a Position beyond its near face. |
| 2 | Cross a thin footprint in one tick at high speed | The step is the server's (0.41 m at most on foot) and is taken in 0.2 m pieces; a load check holds every grown footprint thicker than that. Flight is a GM's, audited, and lands through `clear_of`. |
| 3 | Get placed inside something (a bind, a port, a summon, a login) | Every placement goes through `clear_of`. A body found inside anyway is moved to the nearest edge on its next step, never left stuck and never let through to the far side by choice of direction. |
| 4 | A pocket: a closed space or a too-narrow gap that traps a body or hides one | The export refuses a gap narrower than a body that is not closed, and refuses a spawn, NPC or arrival point that is not clear. |
| 5 | Stand where a mob cannot fit | `MOB_RADIUS` is at most `PLAYER_RADIUS`, held by a test. |
| 6 | Stand where a mob cannot reach (behind a wall) and kill it | Slice 2 blocks spells and arrows through boxes. What can still be seen and not reached is the cliff case: the mob is evading after 1 s and home after 8. Same residual as the perch, same knob. |
| 7 | Hold a mob on a wall so a group-mate hits it freely | It is evading while held; after 8 s it turns on the next attacker it can reach (the existing give-up rule). |
| 8 | Cast, shoot or sing through a wall; an AoE through a wall | Slice 2: every one of them already asks `can_see`. |
| 9 | Hand-edit the server's obstacle file | Refused at boot by the hash, as the terrain's is. |
| 10 | Edit the client's obstacle data | Only that client's picture changes; the server's answer stands and the client snaps to it. |
| 11 | Land on a roof or a crown from a cliff, or log out mid-fall over one | A footprint is a column: the falling step is resolved too, so the body comes down beside it. |
| 12 | Use a push-out to gain ground (run at a corner to be shot round it) | A push never moves a body further than it was inside, and the slope rule is asked again on the final point; a body cannot be pushed up a face. |
| 13 | Farm a mob that spawned inside its own camp's tent or wall | The export refuses the layout; `clear_of` at spawn holds it at run time. |
| 14 | Shed aggro at a building | Possible after slice 3 (8 s). No reward attached: the mob heals at home, and running past the leash already does it. Flagged for the pathing item. |

---

## 7. Cost

- Server: per mover per tick, a grid lookup and a handful of distance tests. With 100 mobs
  and a few players this is small beside the tick's work (a median of 0.5 to 0.8 ms when
  measured on 2026-11-02, before the wildlife); the `world health` line will show it.
- Client: the same lookup once a physics frame for one body. The camera slice adds a few
  hundred static boxes.
- Data: about 13,700 circles and a few hundred boxes; the TOML is a few hundred KB beside a
  2.3 MB terrain file.

---

## 8. Slices, tests and records

Each slice is its own commit pair with its own tests, each test failing with its rule
disabled, and a row set in `obstacle_collision_checklist.md`.

| Slice | What | Ships | Rough size |
|---|---|---|---|
| 0 | Footprints declared on the scenery, the exporter and its report, the server's file with hash and boot line, the lockstep check, the dev outline view. **Nothing collides.** | No behaviour change; could merge any time. | a day |
| 1 | The rule on both sides, players stop, placement through `clear_of`, the fixtures check, L2 rewritten, a new invariant ("nothing stands inside an obstacle; a body's position is the server's"). | Export and redeploy together. | a day or two |
| 2 | Boxes block sight on both sides. | Export and redeploy together. | a day |
| 3 | Mobs and pets collide; the stuck and evade rules read a deflection; wanderers. | Server only. | a day or two |
| 4 | The camera stops at walls and buildings. | Client only. | half a day |

Tests, by kind:

- **Unit (server):** circle and box push-out; a slide keeps the part along the surface; a
  corner between two boxes settles; the largest step crosses nothing; a point inside goes to
  the nearest edge; a non-finite step stays; the same input gives the same output.
- **Compiled content (server, beside `terrain_content.rs`):** every spawn, NPC and arrival
  point clear; a walker with the real `player_step` passes each of the four gates both
  ways; a walker held at any heading into the town wall never ends inside it; every camp is
  still reached from the town.
- **Integration:** a player run at a trunk stops at it and slides round; a direction held
  through a house ends at its face; a port landing on a footprint lands beside it; (slice 2)
  a Smite through a house is refused at no cost and lands from the open side; (slice 3) a
  mob slides round a trunk to its target, and a mob held on a wall is evading, then gives
  up.
- **Client:** `check_obstacle_lockstep.gd`, `check_obstacle_rule.gd`, and a probe that walks
  the real body headless into a trunk and a wall and compares where it rests with the
  server's rule.

Records with the build: `invariants.md` (L2 reworded, the new rule, L1's holders),
`commands.md` (the two tools and the outline toggle), the session note, this To-Do entry;
`systems_overview.md` on the tick.

---

## 9. Decisions for the user

1. **The approach:** footprints the server holds, one rule on both sides, Godot's physics
   bodies not used for walking. *Recommended: yes.*
2. **What collides:** the two tables in 4.2 (trees, tall boulders, walls, towers, gate
   piers, buildings, tents, tall stones; not bushes, bones, fences or clutter).
   *Recommended: as the tables; say which rows to flip.*
3. **Nothing can be stood on or jumped over:** every obstacle is a column, so no roofs, no
   wall walks, no hopping onto a rock. *Recommended: yes for now.* Real height is the same
   later work as caves and stacked floors.
4. **Walls and buildings block spells, arrows and a mob's sight** unless the line passes
   over the top; trees and rocks never do. *Recommended: yes.*
5. **Mobs and pets collide too,** by the same rule, with the existing give-up and evade
   rules for a mob a wall holds, and no pathfinder yet. *Recommended: yes, as slice 3.* The
   cheaper alternative is that mobs keep walking through everything, which is safe and
   looks wrong.
6. **Players, mobs and pets still pass through each other.** *Recommended: yes*, unchanged;
   a body that blocks is a griefing tool at every gate.
7. **The camera stops at walls and buildings, not at trees.** *Recommended: yes, last.*
8. **Timing:** after the door. The zip closes today and this changes how every body moves
   on both sides. Slice 0 changes no behaviour and can be built at any point; slice 1 rides
   the first bump after Nov 19. *Recommended: yes.*

---

## 10. Flagged, not in this plan

- **Pathing round buildings.** A mob that walks round a house instead of giving up at it.
  The boxes are few (hundreds), so steering by box corners is tractable; it wants its own
  design with the dungeons, where it stops being optional.
- **Interiors, upper floors, bridges, wall walks.** Need real height on the server.
- **Per-creature body sizes.** One `MOB_RADIUS` for now; a bear and a rat are the same
  width to a tree.
- **Players blocking players.** Not planned (decision 6).
- **The server telling the client its ground and obstacle hashes at connect,** so a
  mismatched pair is reported on screen instead of found in a log. A wire addition; it
  could ride any later bump.
- **Left-click targeting through walls.** With slice 4.
