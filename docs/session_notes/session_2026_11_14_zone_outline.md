# Session 2026-11-14: the zone's outline, its mountains, the roads and the doors

Built on `feat/zone-outline` in both repos (the zone worktrees `F:\Projects\Project_Dawn-zone`
and `F:\Projects\server-zone`): server `9a7e0fa`, client `8c09944`. Its own file because
another session was working in the main checkouts (the concept prompt pack).

## 1. What was asked

The user walked the 4 km zone in the editor and asked for "a more interesting shape for the
zone instead of a square". Two outlines were drawn over the built ground
(https://claude.ai/artifact/HFL7DK4yvDe1SjkGPrXF91, the page's generator in the session's
scratchpad, not in the repo): a mountain valley with arms, and two basins joined by the pass.
The answers, in order: "i prefered the way Greywood Ridge is designed in the B option" (the
ridge mountain to mountain, the pass the only way), "How about making the roads mor
interesting. Winding between and avoiding points of interest. Right now a road runs directly
into the Ossuary and goll war gamp, lets curve to avoid", then "south door: Sounds good",
"ouline: Two basins with arms", "Go ahead!".

Before the build, the same morning: the user reported mobs floating, an invisible wall and
mobs at their old places. All three were a new client against the old server (the R720 had
not been redeployed); the user redeployed and the boot line read `build="162c151"
dev_cmds=false ... hash 35a3f1a15f4f`. The old process's last health line read
`slope_refusals=308`: the old edge, 180 m from the square.

## 2. The edge

- **One home:** `data/zone_layout.gd` `BASINS`, two lists of corners (the town's basin, the
  Greywood), each rounded by three passes of corner cutting with its ends kept, so each closes
  along the ridge's foot at the pass's mouth. `ZoneLayout.inside(p)` is the test scenery uses
  (a basin, or the pass). 8.25 square km inside the two basins (6.91 and 1.32) against the
  14.9 of the old square.
- **The mountains:** `tools/author_terrain.gd::edge_distances` marks every grid vertex inside
  (a basin, the pass, or a ridge's own footprint beside its line, never past its ends) or
  outside, then runs an exact Euclidean distance transform both ways: `outside` (metres to
  the nearest inside vertex) and `depth` (metres to the nearest outside one).
  `mountain_height` raises an outside vertex by `face_rise` x d over `face_depth`
  (`[[mountains]]` in `data/terrain_features.toml`: 3.0 and 20 m, so 30 m in the first 10 and
  a 60 m cliff), then the flank (`flank_height` 230 x a range noise, easing over `flank_run`
  190 m) and crags. Because an outside vertex is never less than a cell from an inside one,
  every triangle with a corner on each side of the edge rises at least 30 m in 10: a face,
  whatever the ground under it does. Nothing behind the foot is walked on, so the rest is
  look only. `[[rim]]` is gone.
- **The report** gained: the edge (FAIL if a camp spawn or NPC has less than 60 m to the
  mountains; the tightest is the Ossuary at 150 m), the roads (length, steepest grade along
  the road, nearest camp spawn, FAIL if a road leaves the edge), and in the walk "no triangle
  wholly outside the edge can be walked to" (0), beside the outer rows (0 reached) and five
  new `[[unreachable]]` points in the mountains.
- **The pass:** `floor = 6.0`. Cut to 0 it dug an 8 m step into the plain at the south mouth
  and left a 16 m bank at 58 degrees facing the north mouth (found while checking the new
  road's grade against the real heights).
- **The look:** the paint texture turns to `COLOR_MOUNTAIN_ROCK` outside the edge over 26 m;
  the shader takes rock above 190 to 250 m whatever the slope and snow above 300 to 360 m on
  anything not sheer. The first profile (a 180 m cliff, then a gentle back) read as a quarry
  wall in the screenshots and was replaced the same hour.

## 3. The roads, the doors, the overlook

`ZoneLayout.ROADS`, measured by the author's report and by the sketch's generator against the
camps' sites:

| Road | Was | Is |
|---|---|---|
| north | through the Broken Crypt (12 m from its middle), over its bowl's wall | east of Bat Hollow, the pass, east round the bowl (204 m), the north door |
| east | clear of the camps already | the same line past the wagon wreck, south of the Spider Copse, under the Wraith Gate cliff, the east door |
| south (was "the mill road") | through Rotfang's Den (2 m), ending inside the war camp (80 m) | by the mill, west of Rotfang's rocks (227 m), round the foot of the war camp's shelf (294 m), a new south door |
| barrow track | through the bone fields, ending on the pit's wall (140 m from the zombies) | the farm lane, north of the bone fields, an overlook 329 m from the pit's middle and 403 m from the Ossuary |

Steepest grades: 9.4, 15.2, 12.8 and 11.6 degrees. `NORTH_DOOR`, `EAST_DOOR` and `SOUTH_DOOR`
stand 10 m in from the edge (on it, the road's last metres climbed the cliff: the report's
59.5 degrees). `zone_landmarks.gd::_build_doors` (fallen trees, a rockslide with a cart, the
gnolls' stake barricade with two totems) and `_build_overlook` (seven waystones and a tall
marker) replace `_build_road_ends`. Milestones use `ZoneLayout.well_inside`.

## 4. The server

- `terrain.toml` re-exported: `hash a9942be36dff`.
- `terrain_content.rs`: `nobody_walks_out_of_the_zone` and
  `a_gap_in_the_mountains_is_a_way_out` (see the To-Do entry). The old test walked a square
  rim; the new one finds the edge from the ground itself, so it holds for any outline and
  also covers the ridge's faces, the plateau's cliff and the pass's walls.
- `terrain.rs`: the compiled-ground test reads the pass's floor at 6.
- Nothing else changed: camps, NPCs and safe areas are where they were. No world test needed
  a new position.
- Suites: 411 unit, 184 world, fmt and clippy clean.

## 5. Found on the way

- **`check_zone_scenery.gd`'s SCATTER rules were vacuous.** `_flora_points` read each
  MultiMesh's instances back; under `--headless` they come back as identity, so every "point"
  was its batch's origin. The rules (nothing in the town, on a road, off the plate, off the
  ground) could not fail. Seen when 6,193 "points" landed outside the new edge, all at
  multiples of 200. `ZoneFlora.planted()` now returns what was really planted and the check
  reads it; all rules pass on the real 16,350 positions.
- **The editor re-compresses the paint.** Opening the scene in the editor switched
  `zone_paint.png` to VRAM compression in the main checkout (uncommitted). The import now has
  `detect_3d/compress_to=0`.
- **Tools on this machine:** a heredoc's `/tmp` path is not one Windows Python can open (use
  `cygpath -w`); the harness refuses an `rm` on a path built from a shell variable.

## 6. Not built, flagged

- The compass (its own To-Do entry): confirmed mirrored, the user's question about z and
  altitude answered, the decision open.
- No server rule moves a character saved where mountains now stand: one SQL statement at the
  redeploy (in the To-Do entry) puts everyone in the square.
- The far fog tints the range tan; the 60 m cliff at the foot is unbroken all the way round.
- `systems_overview.md`'s terrain paragraphs still wait on the zone's tick.

## 7. To ship

Fast-forward `feat/zone-outline` into `fix/xp-leveling-overflow` in both repos, all checks in
the main checkout, a release export, then the R720: `git pull`, build, stop, the SQL
statement, `cp`, start, and a boot line reading `dev_cmds=false` and `hash a9942be36dff`.
Then `zone_4km_checklist.md`, section 7 with the rest.
