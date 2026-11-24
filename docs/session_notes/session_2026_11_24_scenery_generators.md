# Sessions 2026-11-20 to 11-24: our own scenery generators, and the zone wired to them

Every tree, bush, boulder and bone in the zone was a code placeholder (`LowPoly`, built in
`ZoneFlora._build`). The user's three Blender generators came from a tutorial, so they are not
used (user, 2026-11-20); we wrote our own. The plan, approved 2026-11-20:
`C:\Users\tyler\.claude\plans\cosmic-marinating-prism.md` (its "Decided while building"
section has the calls made on the way). Built on `feat/scenery-generators` in a worktree of
each repo (`F:\Projects\Project_Dawn-scenery`, `F:\Projects\server-scenery`), local commits,
nothing pushed, merged, exported or deployed.

## The generators (11-20 to 11-24)

Python scripts in `tools/blender/` that build Geometry Nodes groups headless in Blender 5.3,
each with sliders and a Seed that stay tweakable in Blender; every variant's seed and sliders
are one row of `tools/blender/scenery_variants.toml`, so a variant rebuilds exactly (built
twice, identical; checked after every change). Shared helpers in `scenery_nodes.py`, bone
pieces in `bone_kit.py`; previews by `preview_scenery.py`, rendered and sent for each kind.

| Kind | Script | Variants | Notes |
|---|---|---|---|
| pine | `gen_trees.py` | 6 | 8 to 26 m, larger than life (user); a segmented trunk, kept segmented (user) |
| broadleaf | `gen_trees.py` | 6 | 9.6 to 20.7 m; forked trunk, two-segment limbs, jagged clumps |
| dark tree | `gen_trees.py` | 6 | one-piece twisted, flared trunk; sagging limbs, drooping clumps, a web |
| dead tree | `gen_trees.py` | 6 | one-piece twisted trunk, branches and twigs, some snapped |
| boulder | `gen_rocks.py` | 12 | a fractured block |
| bush | `gen_shrubs.py` | 8 | blobs in a mound, berries on some |
| scrub | `gen_shrubs.py` | 8 | stiff twigs over a low mound |
| bones | `gen_bones.py` | 6 | a curved spine of vertebrae with fins, ribs, a beast skull (horns on one, antlers on one), long bones |
| skeleton | `gen_skeleton.py` | 16 | humanoid, one per playable race at its height, each in its own pose |
| grass | `gen_grass.py` | 9 | tufts 0.3 to 0.8 m across, one wide and very dense |

Every tree's crown starts at 2.2 m or higher. Every solid piece has its own `part`; part -1 is
drawn with no solid (web, berries, grass, eye sockets, teeth, brow, the drawn one-piece trunk).
A one-piece trunk's solids are straight proxy columns along its steps, emitted when the
generator's Solids slider is on, never drawn.

`tools/blender/export_scenery.py` (commit `f42c5ec`) writes each variant as a `.glb` (the mesh,
its placeholder colour as the vertex colour, its UVs, no material) and a `.solids.json` (each
solid piece's convex hull in Godot's space, to the millimetre, and its sight scale) into
`assets/models/scenery/<kind>/`; 83 variants, 3.7 MB, byte-identical on a second export, a
triangle limit per kind refusing any variant over it. Godot 4.4 imports them with colours, UVs
and triangle counts intact.

## The wiring (11-24)

The user's three calls: the regular pine draws pine variants 1 to 3 (8 to 14 m), the tall pine
4 to 6 (18 to 26 m); skeletons where bone piles go, thick round the undead camps and now and
then beside a road; grass everywhere it makes sense, thick on meadows, thin under the woods, out
to about 60 m ("I'll let you know if we can adjust after I see it").

- **`scripts/zone/scenery_models.gd`** (`SceneryModels`): loads a variant's mesh (from its
  `.glb`) and solids (from its `.solids.json`) once and keeps them.
- **`ZoneFlora`**: every kind names its model folder and the variants it draws. The variant
  comes from a hash of the planted spot (`spot_hash`), never a new throw of the scatter's dice,
  so no tree moved. A 400 m cell draws at most 3 of a kind's variants (`cell_variants`, picked
  by the cell); every variant grows somewhere. Trees narrow to scale 0.85 to 1.15 (the variants
  carry the sizes now), except about one in 40 (the size throw above 0.975) at 1.5 to 2.0, the
  colossal ones; skeletons keep their proportions (no squash), scale 0.95 to 1.05. The far
  stand-ins are built unit-sized and fitted per variant to what it has above 2 m, so a far tree
  is the size of the near one; skeletons got one (a pale lump, 150 to 450 m). A region may now
  run along the roads (`per_km`, `offset` past the verge). `placed_kinds` reads `pine#2` (the
  kind, then the model's variant). The near `LowPoly` builders are gone; the far ones stay.
- **Skeleton and bone regions** in `ZoneLayout.SCATTER`: among the bone fields, rings round the
  Bonepile, the Sunken Barrow, the Broken Crypt and the Ossuary (their clearings keep the
  middles bare), and beside the roads. Each region throws its own dice, so none of it moved
  anything else. 163 skeletons and 225 bone piles in all.
- **The bake** (`ZoneObstacleBake.flora_groups`) by kind: **trunk** for trees (every piece
  starting under 2 m on its own, the rest one crown that blocks sight only), **merge** for
  bushes, scrub and boulders (foot and crown, as before), **pieces** for bones and skeletons
  (every piece on its own, so a body steps over the low ones; user). The trunk rule fixes what
  the old rule would have done to a dark tree: its middle trunk lengths (1 to 2 m up) would have
  joined the crown, bringing the crown's base under the 1 m reach on a small tree, and the whole
  canopy outline would have stopped a body.
- **Grass**, `scripts/zone/zone_grass.gd` (`ZoneGrass`, a new `Grass` node in `world.tscn`):
  grown only round the camera in 32 m squares (2 a frame), each from its own dice seeded by
  where it is, so every client sees the same grass; dropped past range; each tuft faded out
  between 48 and 60 m by a dithered distance fade (no transparency). Up to 0.6 tufts a square
  metre (`ZoneLayout.GRASS_PER_M2`), kept by ground patch (`GRASS_PATCHES`: the Greywood a
  fifth, the steppe and the flats dry and straw-tinted, the festering mound none), on no ground
  the flora keeps off (`ZoneFlora.is_blocked`, now public), drier and up to half as thick as it
  climbs to 110 m and thinning to nothing where a slope turns to rock (both the terrain
  shader's numbers), nearly bare on each camp's worn ground. No shadows, no solids, not in the
  obstacle data; grows nothing without a camera.

## Numbers

- 16,554 things planted (16,363 before; the difference is the new skeleton and bone regions),
  in 1,021 flora batches (445 before; the cap is 3,500).
- The obstacle file: 45,620 prisms (33,199 before), 30,512 stopping a body (19,580), 32,976
  blocking sight (31,012); hash `c4df3370b3ca` (was `f97d25964ce4`). By source: pine 16,646,
  tall pine 7,034, skeleton 6,711, bones 4,020, Town 2,672, dark tree 1,825, dead tree 1,766,
  bush 1,609, Landmarks 1,431, boulder 772, broadleaf 726, scrub 408. A skeleton averages 41
  prisms: the big races' ribcages stand above the 0.3 m step, so each rib is its own small
  post, while a Fae's or a Gnome's skeleton is stepped over nearly whole.
- Near-range triangles in the zone: 2.2 million in all (only what is inside each kind's draw
  distance is on screen). A frame reading on the dev machine, 1600 x 900, vsync off: the
  Greywood 156k to 293k triangles on screen, the Bonepile's ring 355k, the Spider Copse 221k,
  about 200 to 270 draw calls, 0.9 to 1.2 ms a frame everywhere.

## Checks

- `tools/check_zone_scenery.gd` gained **VARIANTS** (every planted thing is one of its kind's
  models, no cell over 3 variants of a kind, every variant grows) and **GRASS** (a square
  grows the same tufts twice, on the ground, never where the flora may not, no thicker than
  allowed, the Greywood thinner than the plain, no physics body, at most 3 batches); Grass is
  in its DRESSING_NODES, so rule L2's no-physics-body check covers it.
- All 21 checks of `check_all.ps1` pass against the server worktree.
- Server suite on the new `obstacles.bin` (`F:\Projects\server-scenery`, no code change): 481
  unit and 201 world tests green, the real zone's spawns, pockets and gates among them.

## Merged and exported (11-24, evening)

The user: "go ahead!". Both deploy branches were at this branch's cut points (the client's
had been merged in), so both merges were fast-forwards: server `94d755a` to `9a7c3ba`, client
`59c0532` to `074ab5b`. Pushed, with `feat/scenery-generators` in both repos.

- `check_all.ps1` on the merged main checkouts: 21 of 21.
- The export, `--export-release` from the main checkout clean at `074ab5b`:
  `[BuildStamp] stamped 074ab5b`, not a debug export, the DLL unchanged (md5 `097ace2a`,
  PD_W0031; nothing here touches the wire). The exe grew by 3.4 MB (the models and the larger
  obstacle file).
- Run from inside the exported build: `check_zone_scenery.gd` passes whole (the models are in
  the pack and nothing at runtime reads a `.solids.json`), and `check_obstacle_lockstep.gd`
  finds the packed obstacle file byte-identical to the server's; its EXPORT row fails there
  only because `export_presets.cfg` is not in a pack (it passes in the checkout).
- `README_FOR_TESTERS.md` gained a sentence: grass blocks nothing; small bones and skeletons are
  stepped over, a big skeleton's ribs are not.
- The zip `builds/ProjectDawn-alpha-074ab5b.zip` (41,778,413 bytes: the exe, the console exe,
  the DLL, the tester README and the players' checklist) replaces `a1a154e`.

Both sides together: the redeploy and the new zip. No migration, no SQL. The boot line must
read `build="9a7c3ba" dev_cmds=false roamers=on`, the terrain hash unchanged
(`f569ade0c331`), and `obstacles=45620 prisms (30512 walk, 32976 sight), hash c4df3370b3ca`.

## Not done

- The R720 redeploy (the user's), then the walk: `scenery_models_checklist.md`.
- Hand-placed poses (a skeleton against a wall or a tree).
