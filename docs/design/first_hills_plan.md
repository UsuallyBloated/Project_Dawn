# The first hills: height model slice 3 (plan, 2026-11-04)

The first terrain that is not flat. Slices 0 to 2 of the server height model
(`server_height_model.md`, `server_fall_damage.md`) gave the server the ground, the slope rule,
line of sight through the terrain and falls, all proven on test terrains of their own and all
invisible on today's flat 400 m plate. This slice is where testers first see any of it, so it
is the one with content in it. Written on the user's go ("go on 1!"). **All seven decisions
were made the same evening (§10), and the build is handed to the next session on a smaller
model: `handoff_first_hills_build.md` has every anchor verified, the order, the tests and the
traps. Build from that file; this one is the design it follows.**

**In scope:** the starter zone's plate gains rises, a ridge, a cliff, a rim, authored as data
and exported by the tools that exist; the client's own line-of-sight check before a cast; the
GM fling tool for testing falls; mobs at a face they cannot climb (the height design's decision
2(b)); the playtest sheet. **Not in scope:** terrain chunking (one mesh is right at 400 m), a
kilometre zone, a second zone, water, caves, roads as geometry, textures and grass (art), a
navmesh.

## 1. What exists (verified 2026-11-04 in both repos)

- **The terrain node.** `scripts/terrain_mesh.gd` is a `@tool` `Node3D`: `grid_size` 20,
  `cell_size` 20.0, `heights` a `PackedFloat32Array` of 441 zeros stored on one line of
  `scenes/world.tscn` (line 82). `_rebuild()` makes the mesh (shared vertices, smooth normals,
  one flat green material) and a trimesh collider from the heights, in the editor and at
  runtime. The scene also stores the built mesh and collider as subresources, which
  `tools/check_terrain_lockstep.gd` compares against the heights (a collider never rebuilt
  fails the check). `tools/export_terrain.gd` writes the server's `terrain.toml` from the
  scene; the server compiles it in and refuses a hand edit by its hash.
- **The server** samples the client's own triangles (`world/terrain.rs`), refuses a step up
  ground past 60°, checks sight through the terrain for every targeted spell, each AoE victim,
  ranged attacks and the idle mob's scan, and runs a player's fall off an edge (`world/fall.rs`:
  a body follows the ground only onto a floor of 55° or less; a face is a wall it slides down;
  the landing costs 2.5% of max HP a metre past 2 m, all of it at 42 m). Mobs and pets are
  pinned to the ground as they move and climb anything (decision 2(a), "for now"). NPCs and
  safe areas derive their height from the ground at load; the files keep a `0.0`.
- **The world.** The town square at the origin (a 10 m safe area; the NPC row on z = 5 from
  x = -5 to 11), six rings of camps out to 185 m (`zone_camps.toml`), the compass +Z north and
  +X east. The docs give the camps compass words and nothing else: "the east road" with wolves
  south of it, "the rocky flats" east with the gnoll raiders, "old rocks south of the mill"
  (Rotfang), the graves north-east, Bat Hollow and the Broken Crypt north at "the Greywood
  edge", the Bandit Outpost north-west, the Spider Copse east, the Gnoll War Camp south, "the
  Sunken Barrow, barrow zombies below the western hills", the Ossuary far west, the Wraith Gate
  "patrolling the far eastern edge". No doc has ever described the zone's relief, named it, or
  placed it in the cartographers' atlas; the "visual-only cliffs outside the playable envelope"
  rule in `zone_size_limits.md` §6 predates the height model and is retired by it.
- **The client.** Remote players, mobs, pets, corpses and bags already draw at the server's
  full position, so hills cost them nothing. Every body sits on physics layer 1 (the terrain,
  the floor, the player, the remote entities); corpses and bags use layer 3 (`collision_layer = 4`, a bitmask) for the click ray;
  NPCs are on no layer. `Targeting` casts the only rays today. `addons/terrain_editor` is a
  disabled click-drag vertex sculpting plugin (`plugin.gd`, 3 KB), never used; the
  `scripts/dunes.gd` generator of April is gone.
- **The tests.** The integration harness runs every test but the terrain ones on the compiled
  terrain; characters are seeded at the origin, at (200, 200), at x = 40 and 60 on the z = 0
  line, and the camp-walking tests aim at the Bonepile's (-16, -14). Hills under those spots
  would change walking times and break assertions written for flat ground.

## 2. The shape of the build

Five pieces, in this order, all on `feat/height-model` in both repos, riding the November bump
(the hills need an export, which the bump carries; the server half needs the redeploy):

1. **Heights as data, and the hills.** A features file and a generator (§4), the first terrain
   authored from it (§3), exported and in lockstep. The harness moves its default ground to a
   flat terrain so the suite's existing tests keep the ground they were written for (one line
   in `start_both`); the compiled hills get their own guarantees (§8).
2. **The fling tool** (§6): a dev command that lifts a GM straight up so they fall, the way to
   see a landing anywhere, including the flat world.
3. **Mobs at a face** (§7): the mob's step refused up ground it cannot climb, and a mob that
   cannot reach its target gives up, walks home and regenerates (EQ's rule).
4. **The client's own sight check** before a cast (§5), with the probe that holds it against
   the server's rule over the real hills.
5. **The sheet** (§9) and the records.

About three days of work: a day for the generator and the terrain, half a day each for the
fling tool, the mob rule and the sight check, the rest for the sheet and the records.

## 3. The hills (a proposal; decision 2)

Principles. The town and the first two rings (everything within about 60 m) stay flat: the NPC
row, the safe area, the harness's walks and a new player's first hour. The relief begins at ring
3 and grows outward, so the ground gets rougher as the mobs get harder. Every camp's spawns
stand on a floor (55° or less; mobs stand and fight as before). The routes from town to each
camp climb at 30° or less (uphill a body covers `cos²θ` of the flat distance, so 30° costs a
quarter of the speed, 45° half). A cliff goes where a name already promises one, and a cliff's
foot is a place a mob can be stuck below a player, which §7 answers. Nothing dips below the
floor at y = 0 (the floor is solid under the mesh).

The proposal, at 10 m cells (§10, decision 1), coordinates x east and z north:

| Feature | Where | Shape | Why |
|---|---|---|---|
| **The western hills** | centred (-160, 0), radius 70 | a broad rise to 25 m | The Sunken Barrow's own description. The Ossuary (-168, 8) and (-174, -14) stands on the rise at about 20 m. |
| **The Sunken Barrow** | centred (-150, -6), radius 18 | a hollow 12 m deep in the rise | "Below the western hills": the barrow zombies (-142 to -156) in a pit whose rim is 10 m above them; the Undying at its bottom. Walls at about 45°, a floor, so the zombies climb out after a player. |
| **The bandit knoll** | centred (-58, 60), radius 25 | a rise of 8 m | A lookout for an outpost; the three spawns (-50 to -64, 52 to 66) on its top. |
| **The Greywood ridge** | from (-120, 85) to (120, 85), half-width 15 | a ridge 16 m high | "The Greywood edge" made real: a wall between the bats' side and the crypt's side, with its slopes past 55° (a face: no walking over it, no casting through it, a slide down it). |
| **The pass** | along x = 0 from z = 60 to 110, 12 m wide | a notch through the ridge to ground level | The way north. Mobs and players both go through it; the crypt's champions leash back through it. |
| **Bat Hollow** | centred (3, 48), radius 14 | a dip of 4 m | The name. Gentle (24° at most), inside ring 2 but shallow enough that nothing changes for a new player. |
| **The crypt's bowl** | centred (2, 118), radius 20 | a dip of 5 m north of the ridge | The Broken Crypt (-8 to 10, 112 to 124) sits in it: out of sight from the south until the pass. |
| **The spiders' rise** | centred (110, 2), radius 30 | a rise of 6 m | The copse on a low hill; the flats between it and the gnoll raiders stay flat ("the rocky flats"). |
| **The Wraith Gate plateau** | x from 150 to 200, z from -40 to 30 | a plateau at 18 m; its west edge a face (18 m over one cell, 61°), its south and north edges ramps of 30 m (31°) | The far eastern edge on high ground, the one real cliff: an 18 m fall from its lip costs 40% of max HP, the first place the fall rule shows. The wraiths (178, 5) and (175, -20) patrol its top. |
| **The old rocks** | centred (3, -72), radius 22 | a rise of 6 m | Rotfang's den on a rocky hump south of town. |
| **The war camp's shelf** | centred (2, -150), radius 40 | a rise of 8 m | The gnoll war camp and Greth's tent on a shelf above the plain. |
| **The rim** (decision 3) | the outer 20 m on every side | from 0 at 180 m out to 30 m at the edge, raised only where the ground is lower | A wall of high ground all round, so nobody walks off the plate into the flat beyond (the height design's decision 3, the visual edge, now a real one). Its slope is 56°: a face, not a climb. |

The Ossuary's spawns are 6 to 12 m from the west rim's foot and the wraiths 2 to 5 m from the
east rim's, both on floors; the generator's report (§4) will say so or fail. Everything else
in rings 1 and 2 (the Bonepile, Wolf Run, the Rat Warrens, the Shallow Graves, the gnoll
raiders, the Boar Thicket) stays on flat ground.

## 4. Authoring: features as data (decision 4 is the look)

**`data/terrain_features.toml`** holds the hills as a list of features, each a few numbers:

```toml
grid_size = 40          # 40 x 40 cells of 10 m: the 400 m plate at twice today's detail
cell_size = 10.0

[[hill]]       # a round rise (or a hollow, with a negative height), smoothstep profile
name = "the western hills"
center = [-160.0, 0.0]
radius = 70.0
height = 25.0

[[ridge]]      # a rise along a segment, the same profile across it
name = "the Greywood ridge"
from = [-120.0, 85.0]
to = [120.0, 85.0]
half_width = 15.0
height = 16.0

[[plateau]]    # a flat top; each edge a ramp width, 0 for a sheer face
name = "the Wraith Gate plateau"
rect = [150.0, -40.0, 200.0, 30.0]
height = 18.0
ramps = { west = 0.0, south = 30.0, north = 30.0, east = 0.0 }

[[cut]]        # a band forced down to a height: a pass, a road through a ridge
name = "the pass"
from = [0.0, 60.0]
to = [0.0, 110.0]
half_width = 6.0
floor = 0.0

[[rim]]
start_at = 180.0        # metres from the centre where the rise begins
height = 30.0
```

**`tools/author_terrain.gd`** (headless, like the exporter) reads it, composes the heights
(hills and ridges summed, plateaus raised to their height, cuts clamped down, the rim raised
to its profile, every height clamped at the floor), and writes them into `world.tscn`'s one
`heights` line, leaving every other byte of the scene alone. It then prints a report and fails
on a violation: the steepest slope under every camp spawn and NPC (from `zone_camps.toml` and
`npcs.toml`; a spawn on a face fails), the town square flat, the steepest grade on the straight
line from the town to each camp (a warning past 30°), and the plate's rim. Opening the scene in
the editor rebuilds the mesh and the collider from the new heights (the `@tool` does that on
load) and saving it writes them; `check_terrain_lockstep.gd` then holds the scene, the collider
and `terrain.toml` together, and `export_terrain.gd` writes the server's file. A headless
round trip through `PackedScene.pack` could do the editor's step too; the build tries it on a
copy and keeps it only if the scene comes back byte-identical apart from the terrain.

Why data and not a brush: the hills can be read, reviewed, tuned by a number and regenerated at
any resolution, and the same file will author the next zone. The disabled `terrain_editor`
addon stays the touch-up brush if one is ever wanted (re-enabled only after its script is
checked to load, since a failing addon script silently rewrites `project.godot`); the lockstep
check and the exporter make a touch-up as safe as a generated height.

**The look.** The mesh shades smoothly today (shared vertices). The low-poly direction
(`project_low_poly_direction`) reads better flat-shaded: a `flat_shaded` toggle on the node
emits three vertices a triangle, and a height tint (greener low, grey-brown high) by vertex
colour costs nothing. Both are the user's call (decision 4); neither touches the server.

## 5. The client's own sight check

`Spells.cast_spell` refuses a targeted cast the server would refuse as unseen, before the bar
and the mana, the way it already refuses a target out of reach: a physics ray from the
caster's chest to the target's chest (both 1.2 m up, the server's `LOS_HEIGHT`) against the
terrain alone. The terrain body and the floor gain a second physics layer, named `terrain` in
the project settings, beside layer 1 (so bodies still stand on them); the ray masks that layer
only, so no body or corpse blocks it. The line is the server's, "You cannot see your target."
Bows keep relying on the server's Miss for now (the client shows "You miss"); a later pass can
stop a ranged auto-attack on a sight failure.

**The probe** (`tools/probe_terrain_sight.gd`, in `check_all.ps1`): over the real hills, a few
thousand random segments between points on the ground, the physics ray against a GDScript port
of the server's crossing rule (`can_see_at` beside the `ground_at` the lockstep check already
carries); it fails on a disagreement beyond the server's tolerance. The server's own unit test
already proves the rule against a brute-force march, so the probe closes the loop: the client's
ray agrees with the rule, the rule agrees with the march.

The slope needs no client check: the body's own `floor_max_angle` is it, and the server's
refusal is silent. The `slope_refusals` counter will count honest players holding a key into
the Greywood ridge; the docs say so since the falls review.

## 6. The fling tool

`ClientWorldMsg::DevFling { height }`, appended LAST, after `DevSetFaction` (the encoding is
positional; `DevDespawnEnemies` was the last variant only under PD_W0028), under the unshipped
PD_W0029, dev-gated and audited exactly like `DevDespawnEnemies`: a plain account's request is ignored and writes nothing. The server lifts the
GM's body `height` metres straight up and sets it falling from there (`Vertical { airborne,
vy: 0, from_y: the new height }`), so the landing goes through the ordinary rules: a 20 m fling
on flat ground is a 20 m fall, 45% of max HP, the line and the HP drop, anywhere. The Test
Panel gets "Fling 5 m" and "Fling 20 m"; the DLL gains `send_dev_fling`; `check_wire_layer.gd`
lists it. Integration test: a GM flung 20 m lands for the formula's damage and one audit row; a
plain account's fling does nothing. This also gives the height sheet a fall row that runs on the
flat world.

## 7. Mobs at a face (decision 6)

Today a mob chasing or walking home steps straight at its target and is pinned to the ground
whatever the slope: it walks up the Wraith Gate's sheer face. Decision 2 of the height design
left (b) for the first hills: the mob's step is refused up ground steeper than the slope limit,
by the same rule as a player's (`slope_ok` on its own step), so it stops at the foot; and a mob
that has not closed to melee for `MOB_STUCK_SECS` (8 s to start, a knob) while its target is
beyond reach gives up: hate wiped, Leash home, full health at home (what `tick_leash` already
does). Exploit lens: a player on the plateau's lip nuking a mob at its foot gets no kill (the
mob walks home and heals; the player spent the mana), and the sight rule already stops casting
through the face itself; this closes the perch from the mob's side. Pets: a pet that cannot
reach its owner for the same 8 s warps to the owner's side (EQ's pets did); no exploit, the pet
fights only where the owner already is.

## 8. Tests

- **Server, unit:** on the compiled terrain, every camp spawn and NPC stands on a floor and the
  town square is flat (the generator's report, held on the server side too, so a hand edit of
  either file fails a test); the mob step refused up a face; the stuck give-up and the pet warp.
- **Server, integration** (test terrains): a mob at the foot of a cliff with its target on top
  gives up, walks home and is at full health there; the fling (§6); a pet warps to an owner on a
  ledge.
- **Client:** `check_terrain_lockstep.gd` green on the new heights; the sight probe (§5);
  `check_wire_layer.gd` with the fling; `check_all.ps1` green.
- **The harness** runs its old tests on a flat terrain; only the terrain tests opt into a ground.

## 9. The playtest (`first_hills_checklist.md`, written with the build)

One seat for most of it, two for the last section. Walk every route from the town to a ring 3+
camp (the uphill feel, no rubber-banding, the pass through the ridge); fight at each hill camp
(mobs stand on the slope, chase up and down it, leash home); the Wraith Gate plateau: climb the
south ramp, step off the lip, the line and the HP drop, a death from it and the corpse run back
up; a Smite through the ridge refused by the client before the bar, landing from the pass; a mob
pulled to the plateau's foot giving up and walking home at full health; the fling tool at 5 and
20 m; the Sunken Barrow from its rim; the rim of the plate; two seats: a partner seen walking
up a hill, standing on it, jumping on it and falling off the lip; the journal: no `cannot see`
for a cast the client let through, `slope_refusals` on the health line (a curiosity on hills),
`fall damage` lines for the falls taken and none else.

## 10. Decisions for the user

**ALL SEVEN DECIDED 2026-11-04 (user: "sounds fuckin awesome"), each as recommended.** The
build order and the verified anchors are in `handoff_first_hills_build.md`.

1. **The resolution.** 10 m cells (40 x 40, 1,681 heights; a cliff is a 15 to 18 m face per
   cell row) or 5 m (80 x 80, 6,561 heights; finer cliffs and paths, a bigger file). Recommended:
   10 m now; the features file regenerates at any resolution later. **DECIDED: 10 m.**
2. **The map.** §3 as proposed, or say what goes where. **DECIDED: §3 as proposed.**
3. **The rim.** A wall of high ground round the plate so nobody walks off it. Recommended: yes.
   **DECIDED: yes.**
4. **The look.** Flat shading and a height tint for the low-poly direction, or the material
   left alone. Recommended: both; they cost nothing and touch no rule. **DECIDED: both.**
5. **The fling tool** as a wire command (a DLL rebuild the bump already carries), or no tool
   and falls tested only on the hills. Recommended: the tool. **DECIDED: the tool.**
6. **Mobs at a face.** Give up after 8 s stuck, leash and regenerate; pets warp to the owner
   after the same 8 s. Recommended: yes to both. **DECIDED: yes to both (`MOB_STUCK_SECS`, 8 s,
   a knob).**
7. **The harness.** The existing tests move to a flat terrain and the hills are held by their
   own checks and tests, or the suite runs on the real hills and the tests the hills break are
   rewritten. Recommended: the flat default. **DECIDED: the flat default.**

## 11. As built (2026-11-04, night)

Built on `feat/height-model` in both repos by the Opus 5.5 session from
`handoff_first_hills_build.md`, all five pieces, each its own commit; it rides the November
bump (the export and the redeploy together). The sheet is
`docs/playtest_notes/first_hills_checklist.md`. What differed from this plan:

- **Four features changed their numbers so the shapes exist at 10 m cells** (the camps were
  not moved; the generator's report is clean). The ridge's height is 24, not 16: its line
  z = 85 falls between two grid rows, which sample it a quarter in from its crest, so 16 gave
  a 12 m crest with 50° sides anyone could walk over; 24 gives a 17.8 m crest with 61° faces.
  The pass's half width is 12, not 6: at 6 only the x = 0 column was cut and the pass was a
  notch of 50° walls with no floor; at 12 the columns at x = -10, 0 and 10 are cut and the pass
  has a floor 20 m wide. Bat Hollow and the crypt's bowl are each a low rise with the hollow
  dug back out of it: a hollow on flat ground is clamped to the floor by the composition, so
  as drafted both vanished. The rim is 40 m, not 30: 30 over 20 m is 56°, which the server's
  60° climb limit lets a modified client climb, and 36 still left the cells where the war
  camp's shelf lifts the rim's foot at 59°.
- **The slope rule had a hole the hills exposed** (server `d5de613`): it judged a step's own
  grade, so a diagonal or a zigzag climbed any face. Fixed: a rising step onto ground steeper
  than the limit is refused whatever its direction (`server_height_model.md` §3.4).
- **Heights are rounded to 0.0001 m** by the generator: Godot's `create_trimesh_shape` snaps
  every collider vertex to that, so the server now samples exactly the triangles the client
  collides with (the lockstep check caught 588 vertices a hair off).
- **The scene's mesh and collider are refreshed headless** by splicing the bodies Godot's own
  text saver writes for a TerrainMesh built from the new heights into the scene's three terrain
  subresources; the full repack of the instanced world was not needed. Re-running the
  generator leaves the scene byte-identical.
- **A mob healed at home is now told to every player** (the AI loop fans its HealthUpdate): a
  leash never fanned it, so a watcher's bar kept the HP the mob left the fight with, which
  the give-up rule would have made obvious.
- **The sight check is a `check_`, not a probe** (`tools/check_terrain_sight.gd`, about 2 s,
  in `check_all.ps1`), and a probe drives `cast_spell` itself (`tools/probe_cast_sight.gd`).
- **The pet-warp integration test was not built**: its route (a bind, a fall, a summon, a
  guard, a 5 s Gate, then the 8 s window) runs past 25 s; the unit test
  `a_pet_that_cannot_reach_its_owner_warps_to_them` holds the rule.
- **The ridge is no place to test sight from flat ground**: its flanks are faces and its 30 m
  base puts a target out of reach, so the sheet tests sight at the Wraith Gate's cliff, from
  its foot to its top.
