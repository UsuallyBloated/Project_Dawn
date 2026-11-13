# Session 2026-11-13: the starting zone at 4 km

Built on `feat/zone-4km` in both repos (client worktree `F:\Projects\Project_Dawn-zone`,
server worktree `F:\Projects\server-zone`; server `d3d83c1`). Not merged, not exported, not
deployed. This note is its own file, not a section of the running one, because another
session was writing to the main checkouts the same afternoon (the ammo slot); see "Two
sessions, one checkout" below.

## 1. The ask and the five calls

The user: "build the updated 3D zone using the comp made by a previous session"
(`docs/design/starting_area_comp_sketches.html`, the 4 km proposal of section 82 in
`session_2026_10_25.md`), then, on the plan: 10 m cells as recommended; **keep the 54 spawns
and tune after**; three painted concept sheets to review (the town from the east road, the
town square, the east road and the gnoll flats, in
`Project_Dawn_Source/concept_art/starting_area/comps/`); **"put it in front of the friends"**
(the Nov 19 zip, not the bump after it); and "go ahead with creative placeholder shapes...
We could also use trees. think you could make trees?"

## 2. What was built

**The ground (both repos).** `data/terrain_features.toml` is the comp's plate: 400 x 400 cells
of 10 m. The western hills to 110 m with the Ossuary's crest at 130 m and the Sunken Barrow
dug 45 m into them (a flat floor 180 m across, walls of 32 to 40 degrees, so its dead climb
out); the Greywood ridge as a wall 62 m high, 220 m through and 2.6 km long whose faces are
64 degrees, with the pass cut through it (a floor 60 m wide between 72 degree walls); the
Wraith Gate plateau at 60 m (its west edge a one-cell cliff, a lethal fall; ramps of 27
degrees north and south); the bandits' knoll, Bat Hollow's ring, the crypt's bowl, the
spiders' rise, the festering mound, the old rocks, the war camp's shelf; rolling ground
everywhere but the town's 150 m; foothills; and mountains round the edge, 160 m over the last
70 m (66 degrees) with peaks. New shapes in `tools/author_terrain.gd`: a hill's flat core, a
ring, a flat-topped ridge with a crown and crest noise, masked noise layers, a cut's sloped
walls, a rim that adds to what is under it and whose peaks vary along the edge only (so no
peak flattens the face).

**The author's report gained a walk.** Every triangle is a place; a walker moves between two
that share a corner, never up onto a face, and from a face only down (the server's rule). From
the town it must reach every camp spawn and must reach neither the plate's outer row nor any
point the features file lists as unreachable (the ridge's crest, three places). Today: 89.4%
of the plate is walkable, 25,667 triangles are faces, 59 are the 55 to 60 degree band. It also
warns when a set piece in `data/zone_layout.gd` has drifted from its camp.

**The ground in chunks.** `TerrainMesh` builds its meshes and trimesh colliders from the
heights at load, in chunks of 40 cells (100 chunks), sharing vertices; the scene stores the
heights alone. Baked into `world.tscn` the way the 400 m plate was, the 4 km mesh was about
55 MB of text; the scene is 1.3 MB. The triangle order and winding are unchanged, so the
server samples the same surface. `assets/materials/terrain.gdshader` draws it: a flat normal
per triangle from screen derivatives, a height tint, bare rock on anything too steep to stand
on (a face reads as a face), and a paint texture over the whole plate
(`assets/textures/environment/zone_paint.png`, 2048 px, written by the author from
`data/zone_layout.gd`: four roads, five farm strips, the forest floor, the dry flats, the bone
fields, the worn ground under the camps).

**The server.** `terrain.toml` re-exported (2.1 MB, hash `35a3f1a15f4f`, compiled in as
before). `zone_camps.toml`: every camp at the comp's position, its spawns in the same pattern
three times wider, 54 as before. `safe_areas.toml`: the town's safe area from 10 m to 60 m (the
nearest camp is 180 m out; the terrain content test holds every point of it to flat ground).
No code changed outside tests.

**Scenery (client only).** Four scripts in `scripts/zone/`, all tool scripts so the editor
shows them, all built at load from `LowPoly` (a builder of flat-shaded, vertex-coloured
solids) with no art files:
- `zone_flora.gd`: 40,908 trees, bushes, boulders and bones scattered from the layout's
  regions as MultiMeshes in 400 m cells (655 batches), a far tree a five-triangle cone until
  450 m; seeded by region name, so every client plants the same wood.
- `zone_town.gd`: the wall with a gate on each road and corner towers, the watchtower with the
  green banner, 28 houses, and behind the NPC row what each NPC keeps (Hadrik's forge, Sister
  Maelis' shrine stone, Aldric's brazier and banner, Elara's stall, Brom's shop, Thalia's
  bank), a well, an inn; outside, fenced fields, a barn and a windmill whose sails turn.
- `zone_landmarks.gd`: the pass's braziers and stones; the barrow's sixteen ward stones (four
  fallen) and its door with the green light; the Ossuary's spires (the tallest 46 m, picked
  out on the skyline from the east road); the Wraith Gate's arch at the cliff's lip, 42 m
  tall, its opening a sheet of cold light; the Broken Crypt; the raiders' camp and the wagon
  wreck; the war camp's stake ring with lookouts, and Greth's tent; the bandits' lookout and
  stakes; bone heaps, graves, burrows, the bats' cave mouth and Sable's crag, Rotfang's
  standing rocks, the mound's swellings, cocoons and web tents, the shut ends of the east and
  north roads, a milestone every 250 m.
- `zone_props.gd` is the prop kit those two place (house, wall, tower, gate, banner, tent,
  campfire, totem, stake, lookout, arch, spire...), built to be replaced by authored models
  one function at a time.

**Light and distance.** The fog went from 0.003 to 0.0004 with aerial perspective (at the old
density nothing past 300 m could be seen), the camera's far plane to 7 km, the sun's shadows
to 320 m. The sun now rises in the east and sets in the west (its authored rotation gained a
quarter turn; `TimeOfDay` only ever set its pitch, and the path ran north to south).

**The whole zone builds in about 440 ms** (ground, colliders, flora, town, landmarks) and the
world scene with HUD and player loads in 1.1 s headless.

## 3. Tests

Server: 408 unit and 183 world tests, clippy and fmt clean. The compiled-ground assertions are
the new plate's; the six camp-walking tests enter beside the Bonepile's isolated spawn
(`CAMP_PULL_START`) instead of walking from the town; the group-bind test's refused member
stands outside the wider safe area; the mob-gives-up-below-a-face test on the shipped ground
moved to the plateau ramp's edge (the ridge and the cliff are more than a spell's reach high
now, so neither is a perch).

Client: all 16 checks (`check_all.ps1 -ServerRoot F:\Projects\server-zone`) and all 21 probes.
- `check_terrain_lockstep.gd` builds the game's own `TerrainMesh` and places every collider
  triangle in its cell (each of the 320,000 exactly once, facing up). Planted: winding the
  lower triangles backwards fails it (and the stand probe); never building one row of chunks
  fails it (and the scenery check).
- `check_terrain_sight.gd` rays against the real chunked colliders: 3,000 pairs, 2,165
  blocked by the server's rule, no disagreement.
- `check_zone_scenery.gd` (new, in `check_all.ps1`): no scenery is a physics body; the scatter
  is the same on a second build, stands on the ground and keeps off the roads, the town and
  the rim; every set piece was built; lights, smoke, triangles and batches inside a budget.
- `probe_zone_world_loads.gd` (new): the real world scene loads, and the player's own body
  stands on the ground in eight places, two of them chunk seams.
- `tools/shoot_zone.gd` (new) renders the zone from 25 viewpoints, the four comps' among
  them; the day's shots are in `Project_Dawn_Source/concept_art/starting_area/built/`.

Rule L2 added to `docs/reference/invariants.md` ("What the server does not know never stops a
body"), held by the scenery check.

## 4. Exploit lens

- **Nothing here is trusted from the client.** The ground the server stands on is its own
  compiled file; a client with different heights is pulled back by the reconciliation, as on
  the 400 m plate.
- **Scenery never collides.** A wall that stopped the client's body and not the server's
  would put the player in two places and be walked through by correction. So the walls are
  walked through, honestly, until the server has obstacles (flagged below).
- **No perch got easier.** The ridge's crest and the plateau's cliff are over 60 m, out of
  every spell's 30 m. The plateau ramp's side wall is the one reachable perch found; the
  existing evade rule covers it and its test now stands there.
- **Nobody leaves the plate.** The rim is a face all round (the server's own walkers test,
  and the author's walk).
- **The wider safe area** only widens where a group member may be bound and where Succor
  lands; no camp's aggro reaches it (the existing unit test).
- **Distance is the new cost.** A corpse run from the war camp is five minutes. Gate, bind
  and resurrection matter more; nothing about them changed.

## 5. Flagged, not built

- **Walls, trees and props do not collide.** The follow-up is server obstacles (boxes and
  circles both sides read, with a lockstep check), not client colliders alone.
- **54 spawns in 16 square km is thin** between camps (the user's call: tune after).
- **The view distance for players and mobs is still 120 to 240 m** (the server's AOI cells);
  in a zone with kilometre sightlines a mob or a friend appears at that range.
- **The world is mirrored against the comp's map**: with +Z north and +X east (the 09-27
  call), facing north puts east on the left. The layout is the comp's; a painting made
  looking west has north on its right and the game has it on the left.
- **No water**, as the comp left it. No audio. No minimap.
- **The dialogue's directions were checked against the layout, not rewritten** (the camps
  kept their bearings from the town).
- **`systems_overview.md`'s terrain paragraphs** still describe the 400 m plate; they move
  with the tick, as the workflow has it.
- **The planner's page was not republished from this branch.** Three rows joined
  `schedule_detail.toml` (b57 the build, o23 the merge, export and redeploy, v62 the sheet)
  and the two outputs were regenerated here (135 rows, no warnings); the other session will
  have regenerated the same files, so they are regenerated once more at the merge and the
  page republished then.

## 6. Two sessions, one checkout

Midway, `git diff --stat` in the server checkout showed files this session never touched
(`items.toml`, `inventory.rs`, the protocol): another session was building the ammo slot in
the same two checkouts, and this session had switched both to a new branch under it. Nothing
was lost (uncommitted work follows a branch switch between identical commits). The zone work
was moved out file by file into two new worktrees and both main checkouts were put back on
`fix/xp-leveling-overflow` with the other session's changes untouched. From then on every
tool was given the zone worktree's server path, since each defaults to the deploy checkout.

## 7. To ship it

Both sides together, after the ammo session's work is committed: fast-forward (or merge)
`feat/zone-4km` into `fix/xp-leveling-overflow` in both repos, rebuild the DLL only if the
ammo slot changed the wire, run `check_all.ps1`, export, redeploy, and confirm the boot line's
`terrain=400x400 cells of 10 m, floor 0, hash 35a3f1a15f4f`. Then `zone_4km_checklist.md`.
