# Handoff: the compass mirror, and what is left on the 4 km zone (2026-11-14)

For the session that picks this up. Read `CLAUDE.md` first (the rules there are in force), then
`docs/session_notes/session_2026_11_14_zone_outline.md` and
`docs/session_notes/session_2026_11_13_zone_4km.md`. Everything below was read in the source
on 2026-11-14; verify an anchor again before you edit it.

## 1. Where things stand

| | Server | Client | Terrain hash |
|---|---|---|---|
| On the deploy branches (`fix/xp-leveling-overflow`), pushed | `9a7e0fa` | `7c7a810` (records after it) | `a9942be36dff` |
| The zip for the door | | `builds/ProjectDawn-alpha-7c7a810.zip` | |
| Running on the R720 since 2026-11-14 21:07 UTC | `9a7e0fa` | | `a9942be36dff` |

The outline build (two basins with arms, mountains, winding roads, three doors) is merged and
exported, and the user redeployed the R720 onto it the same evening (boot line read, ledger
clean, their character in the town square). Still read the boot line before assuming a hash
(`journalctl -u projectdawn -n 20 --no-pager`). A client and a server on
different terrain hashes stand people on the wrong ground (floating mobs, steps refused in
open country). The zip and the redeploy always go together.

Nothing on the zone is ticked. The sheet is `docs/playtest_notes/zone_4km_checklist.md`
(section 7 is the outline). Planner rows b59, o25, v62, d12.

## 2. The decision this work waits on

To-Do entry "The compass is mirrored" (World systems), planner row d12. **Do not mirror
anything until the user has answered both:**

1. Mirror the world once so it matches the comp's map (facing the ridge, east on your right)?
   Recommended: yes, with north becoming -Z.
2. Should `/loc` print the EverQuest way (north-south, east-west, height)? Recommended: yes,
   with a raw form kept for authoring.

The fact, confirmed: the Greywood ridge is at +Z and the gnoll raiders at +X. Godot is
right-handed, so facing +Z puts +X on the left. The 2026-09-27 ruling "+Z is north, +X is
east" (`autoloads/sense_heading.gd`, lines 8 to 16) therefore describes a mirror image of any
real map, including the comp (`docs/design/starting_area_comp_sketches.html`, "North is up
(+Z), east is right (+X)"). The user saw it on 2026-11-14.

## 3. The mirror: the plan

### 3.1 The idea: one mapping, and the authored data does not change

All the authored layout is already in **map coordinates**, a `Vector2(east, north)`:
`data/zone_layout.gd` (its header says so) and `data/terrain_features.toml`. The bug is the
single assumption, repeated inline, that world z = north. The fix is to make that one mapping
explicit and flip it, so world z = -north:

- Add to `ZoneLayout`: `to_world(p: Vector2, height := 0.0) -> Vector3` returning
  `Vector3(p.x, height, -p.y)`; `to_map(v: Vector3) -> Vector2` returning
  `Vector2(v.x, -v.z)`; and `yaw_to_world(yaw: float) -> float` returning `PI - yaw` (derive
  it again before trusting it: a body turned `yaw` about +Y faces `(-sin yaw, 0, -cos yaw)`,
  and its mirror in z faces `(-sin yaw, 0, +cos yaw)`).
- Route every inline conversion through them. **Do not negate the numbers in
  `zone_layout.gd` or `terrain_features.toml`.** Leaving them alone is what makes the result
  an exact mirror and keeps the map the authoring frame from now on.

Do not use a negative scale on a node to fake it: the terrain's collider and the server need
real coordinates.

### 3.2 Client: where the conversion is written inline today

Counted with `grep -c "height_at(\|slope_at(\|Vector3(p\.x\|Vector3(at\.x\|Vector3(mid\.x"`:

| File | Hits | What to do |
|---|---|---|
| `scripts/zone/zone_dressing.gd` | 2 (+ `stand`) | `ground`, `on_ground`, `stand`: the choke point for the town and the landmarks. `stand(p, yaw)` builds its basis from `yaw_to_world(yaw)`. |
| `scripts/zone/zone_flora.gd` | 5 | Scatter stays in map space (`_is_blocked`, `ZoneLayout.inside`, roads, clearings). Convert when sampling the terrain (`slope_at`, `height_at`) and in `_emit` (the cell's origin, each placement, `_planted`). |
| `scripts/zone/zone_landmarks.gd` | 1 | Plus every yaw computed from a map direction (the milestones' `atan2`, `Vector2.from_angle` offsets are map offsets and are fine). |
| `scripts/zone/zone_town.gd`, `zone_props.gd` | 0 direct | They build through `stand`/`on_ground`. Pieces built from two points (`ZoneProps.wall`, `fence`) have a left and a right: the wall's merlons and anything "on its left-hand edge" swap sides, so look at them. |
| `tools/author_terrain.gd` | 6 | See 3.3. |
| `tools/check_zone_scenery.gd` | 1 | `flat := Vector2(p.x, p.z)` becomes `ZoneLayout.to_map(p)`. |
| `tools/shoot_zone.gd`, `tools/probe_zone_world_loads.gd` | 2, 3 | Their hard-coded places are world coordinates: negate z, or write them as map points through `to_world`. |
| `scripts/terrain_mesh.gd`, `tools/export_terrain.gd` | 2, 1 | World API (`height_at(x, z)`): unchanged. The triangle split is world-fixed and stays. |

Other client places that hold a position or a direction:

- `scenes/world.tscn`: the six NPC nodes (from line 96: GeneralMerchant, Provisioner,
  AldricTheGuard, SisterMaelis, ThaliaTheBanker, Blacksmith) carry world transforms: negate z.
  The Sun (line 55): east stays +X, so sunrise is unchanged; check with a screenshot that the
  noon sun leans south (south is +Z afterwards) and flip its tilt if not.
  `autoloads/time_of_day.gd:141` turns the sun about its own x.
- `autoloads/sense_heading.gd`: the ring. After the fix `rotation.y = 0` faces -Z = north and
  the angle grows counter-clockwise from above: North, Northwest, West, Southwest, South,
  Southeast, East, Northeast. Rewrite the header comment (lines 8 to 15); it currently says
  "don't fix it".
- `scripts/hud.gd:1539` (`/loc`) and `:1488` (`/sense`). See section 4.
- Quest and dialogue text names directions by word ("east of town"). The words stay true,
  since the content keeps its compass names. Grep to be sure.

### 3.3 The terrain author (`tools/author_terrain.gd`)

- `compose` and `edge_distances` loop over world vertices. Convert each to a map point
  (`Vector2(x, -z)`) before `height_at`, `Layout.inside` and `_on_ridge_footprint`. Noise is
  then sampled in map space too, which is what makes the new ground the exact mirror of the
  old one, hill for hill.
- The report mixes frames: camps and NPCs come from the server's files (world); roads, sites
  and `[[unreachable]]` points are map. Convert at each comparison (`_report_roads`,
  `_report_sites`, `_report_walk`). Make a drifted site a FAIL for this pass (it is a WARN):
  it is the check that catches a half-mirrored camp.
- The paint: the shader samples it at world `xz / zone_size + 0.5`. Paint the layout in map
  space as now, flip the image once (`Image.flip_y()`), then run `_clear_mountain_paint`
  (which reads the world-indexed `outside` grid) on the flipped image.
- After it writes: `godot --headless --path . --import`, then `tools/export_terrain.gd`, then
  the checks. The hash changes.
- The ground is the same shape mirrored, but the triangle diagonals do not mirror, so a few
  triangles change slope. The report's walk, edge and road sections are what tell you whether
  anything broke. Expect them clean; if a face opens somewhere, fix the feature, never the
  camp.

### 3.4 Server (`F:\Projects\server`, worktree `F:\Projects\server-zone`)

The server has no map frame: its data is world coordinates, so these are edited.

- `data/zone_camps.toml` (every spawn's third number), `data/npcs.toml`,
  `data/safe_areas.toml` (centred on the origin today; check its arrival point): negate z.
  Do it with a script that asserts how many values it changed.
- `data/terrain.toml`: re-exported by the client tool.
- No code changes: yaw maths, the dev spawn "in front" and the height model all work in
  world coordinates and do not care which way is called north.
- Tests that stand on the compiled ground hold world positions. Known ones:
  `tests/world/common/mod.rs` (`BONEPILE_SPAWN (-216, 0, 54)`, `CAMP_PULL_START (-200, 0, 68)`),
  the bind test in `groups_and_quests.rs` (52, 75, 40 m from the square),
  `height.rs::a_mob_below_the_plateau_ramp_gives_up_on_a_player_on_its_edge` (watcher
  (1435, 413), lip (1450.1, 408)), `src/world/terrain.rs::the_compiled_terrain_parses_and_its_hash_matches`
  ((1700, 0), (-700, 900), (0, 900)), and
  `src/world/terrain_content.rs::a_gap_in_the_mountains_is_a_way_out` (a corridor at x >= 1880,
  z -930 to -870, and `ground(1880, -900)`: the east door). Run the suite; a test on a
  mirrored-away position fails and names itself. The camp-walking tests in `melee.rs`,
  `pets.rs` and `spells.rs` seed from the two constants above.
- `nobody_walks_out_of_the_zone` needs no change: it finds the edge from the ground.

### 3.5 A check for the bug itself

Add `tools/check_compass.gd` to `check_all.ps1`, and a rule under L in
`docs/reference/invariants.md` that names it. It should fail on today's code:

- `ZoneLayout.to_world(Vector2(0, 1)).z < 0` (north is -Z).
- From the town, facing the Greywood ridge (`ZoneLayout.PASS_SOUTH_Z` north of it), the Gnoll
  Raider Camp (`ZoneLayout.SITES`) is on the right: the cross product's sign.
- `SenseHeading` reads North for a body facing the ridge and East for one facing the camp.
- The six NPC nodes in `world.tscn` match `npcs.toml` (the lockstep check already does this;
  keep it green).

### 3.6 At the redeploy

During the stop, mirror what is saved, in one statement (run a `.backup` first):

```
sudo -u projectdawn sqlite3 /opt/projectdawn/world.db "UPDATE characters SET pos_z = -pos_z, bind_z = -bind_z; UPDATE corpses SET pos_z = -pos_z;"
```

`characters.yaw` is saved too; mirroring it (`3.14159265 - yaw`) is cosmetic. No server code
for old characters (the user's standing rule); say it in one line.

### 3.7 Order of work

1. Worktrees: `F:\Projects\Project_Dawn-zone` and `F:\Projects\server-zone` (branch
   `feat/zone-outline`, merged). Start a new branch in each from the deploy branch. Another
   session may be live in the main checkouts: never switch their branch.
2. Write `tools/check_compass.gd` first and see it fail.
3. `ZoneLayout` mapping, then the author tool, then author, import, export.
4. Scenery through `stand`/`on_ground`; `tools/shoot_zone.gd` (it needs a window) and look:
   the town's walls and gates, the banner tower by the east gate, the Wraith Gate arch at the
   cliff's lip, the barrow's door, the three doors.
5. Server data and tests; `cargo +1.95.0 fmt`, `clippy --all-targets -- -D warnings`, `test`.
6. `tools\check_all.ps1 -ServerRoot F:\Projects\server-zone`, the zone probes.
7. Records (3.8), fast-forward both deploy branches, push by name, checks again in the main
   checkout, export, zip.

About a day. Both sides and a new zip; one more redeploy.

### 3.8 Records the pass owes

- `CLAUDE.md`: the compass entry (built, pending); the "+Z is north" lines elsewhere are
  history, leave them and state the new ruling in the entry.
- A session note in its own file, and its line in `docs/session_notes/README.md`.
- Every `/loc` number in the sheets: `docs/playtest_notes/zone_4km_checklist.md` (section 7
  and earlier), `CHECKLIST_FOR_TESTERS.md` (rows 6, 20, 24 and the "z grows going north"
  sentence), `pre_door_check_checklist.md` section 9, `README_FOR_TESTERS.md`,
  `docs/reference/commands.md` (`/loc`), `docs/design/location_command.md`.
- `docs/schedule_detail.toml` rows, `python tools/schedule_detail.py`, republish the page at
  the `published_url` in that file.
- Memory: `project_zone_4km.md`.

## 4. `/loc` the EverQuest way (if the user says yes)

EverQuest printed `y, x, z`: north positive, west positive, height
(https://www.project1999.com/forums/showthread.php?p=2101506). After the mirror that is
`-z, -x, y` of the body's position. `/loc` was designed to be paste-ready for the server's toml
files (`docs/design/location_command.md`), so keep a `/loc raw` that prints world `x, y, z`,
and say so in `commands.md`. Client only. If the user answers the mirror and not this, leave
`/loc` printing world `x, y, z` and correct the sentence to "z grows going south".

## 5. Smaller things, none started

- The mountains' foot is one unbroken 60 m cliff (`face_depth = 20`, `face_rise = 3` in
  `[[mountains]]`). Only the first 10 m must be a face (30 m of rise); beyond it the shape is
  free. Varying `face_depth` by noise, or laying talus against the foot, would break the wall.
  Keep the first ring and let `nobody_walks_out_of_the_zone` and the author's report judge.
- The far fog tints the range tan (`fog_light_color` in `scenes/world.tscn`).
- The Greywood is a third of its old size, so the zone has about 16,000 trees, down from
  41,000. The scatter densities are in `ZoneLayout.SCATTER`.
- The user's open calls on the zone: mob count (54 spawns, 6.5 a square km), the 120 to 240 m
  entity view distance, server obstacles (walls and trees are walked through; invariant L2),
  water.
- `docs/concepts/architecture/systems_overview.md`'s terrain paragraphs move when the zone
  ticks, not before.

## 6. Traps met on this work

- Under `--headless` a MultiMesh's instances read back as identity. Keep your own list
  (`ZoneFlora.planted()`); never test scenery by reading a MultiMesh.
- A script that a `-s` tool compiles as a dependency must not name an autoload: use
  `get_node_or_null("/root/DebugLog")`.
- The editor switches a texture used in 3D to VRAM compression unless its import has
  `detect_3d/compress_to=0` (the ground paint has it now).
- Server files are a mix of CRLF and LF: read, normalise, edit, write back as found.
- Git Bash's `/tmp` is not a path Windows Python can open (`cygpath -w`). The harness refuses
  `rm` on a path built from a shell variable.
- The export: `--headless --path . --export-release "Windows Desktop" builds/ProjectDawn.exe`
  passed to `Start-Process` as one string; the log must read `[BuildStamp] stamped <sha>` with
  no `-debug`. The zip holds the exe, the console exe, `gdext_net.dll`,
  `README_FOR_TESTERS.md` and `CHECKLIST_FOR_TESTERS.md`, under `ProjectDawn-alpha\`.
- The user wants short answers, the plan stated before any edit, and nothing ticked without a
  played checklist row.
