# Handoff, 2026-11-04: building the first hills (height model slice 3)

**Written for:** the Claude session that builds this on Opus 5.5. The user decided all seven
calls of `first_hills_plan.md` §10 on 2026-11-04 ("sounds fuckin awesome", the recommendations)
and asked for a handoff the smaller model can follow at the same standard. Every path, name and
line number here was read in the live source on 2026-11-04 (the two `feat/height-model`
worktrees, the deploy branch for the records); line numbers drift, so grep before editing. The
user's rules in `CLAUDE.md` outrank anything here.

Read in this order before touching code: `CLAUDE.md` (all of it), this file,
`docs/design/first_hills_plan.md` (the plan this builds; §3 is the map, §4 the data format),
`docs/design/handoff_oct_15_next_builds.md` §1 and §3 (the working standard as rules, and the
environment's traps; both still hold), `docs/session_notes/session_2026_10_25.md` §50 to §53
(the four height model sessions of 2026-11-03 and 11-04), then `docs/design/server_height_model.md`
§3.4 and §3.8 and `docs/design/server_fall_damage.md` §3.2.

---

## 1. The decisions (all seven, 2026-11-04)

1. **Resolution:** 10 m cells, a 40 x 40 grid, 1,681 heights (`grid_size = 40`, `cell_size = 10.0`).
2. **The map:** `first_hills_plan.md` §3 as proposed (the table in §4.1 below repeats it with the
   camp coordinates to check against).
3. **The rim:** yes, a wall of high ground round the plate.
4. **The look:** flat shading and a height tint, both on.
5. **The fling tool:** yes, a dev wire command (the DLL rebuild the bump already carries).
6. **Mobs at a face:** the step refused up a face; a mob stuck for 8 s gives up, leashes and
   regenerates; a pet stuck for 8 s warps to its owner. Both knobs named `MOB_STUCK_SECS`.
7. **The harness:** the existing tests move to a flat default ground; the hills are held by their
   own checks and tests.

Nothing is built. The plan's estimate is three days; do the pieces in the order of §4 and commit
each one on its own.

## 2. Where things stand (2026-11-04, night)

| What | Where | State |
|---|---|---|
| Server branch | `feat/height-model`, worktree `F:\Projects\server-height` | `351e732` (falls, slice 2). Branched from `bump/nov`. Pushed. |
| Client branch | `feat/height-model`, worktree `F:\Projects\Project_Dawn-height` | `763a4ab` (the fall constants in lockstep). Branched from `bump/nov`. Pushed. |
| Records | the deploy branch `fix/xp-leveling-overflow`, main checkout `F:\Projects\Project_Dawn` | this file's commit and `cab3e62` (the plan). Merged forward into `feat/facing` and `bump/nov` (`F:\Projects\Project_Dawn-bump`) after every records commit. |
| Server main checkout | `F:\Projects\server` | the deploy branch. Every client check's default path and `addons/gdext_net/build.ps1` point HERE, not at the height worktree (trap, §3). |
| The R720 | `f06e88e`, `dev_cmds=false` | frozen until after the Nov 8 friends evening (user, 2026-11-03). Nothing here deploys or exports before then. |
| The bump | `bump/nov` in both repos | the bump day merges `feat/height-model` into `bump/nov` BEFORE the fast-forward of the deploy branches (memory `project_bump_day_merges`). The hills ride it: they need the export (the scene) and the redeploy (the compiled terrain, the fling, the mob rule) together. |
| Suites on the height branch | server | 396 unit, 177 world tests, clippy `-D warnings` clean under the bump's lints, rustfmt clean. |
| Checks on the height branch | client | 14 `tools/check_*.gd` green with `.\tools\check_all.ps1 -ServerRoot F:\Projects\server-height` (since 4.0, done); `check_wire_layer.gd` green with a DLL built from the height worktree. |

The current build commands, verified:

```powershell
# server, from F:\Projects\server-height
cargo test -p projectdawn-server                       # 60 to 120 s
cargo clippy --locked --all-targets -- -D warnings     # the bump's lints: unwrap/expect denied in live code
cargo fmt --check
# client, from F:\Projects\Project_Dawn-height (the console exe returns an exit code; the plain exe does not)
& "F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe" --headless --path . -s tools/check_terrain_lockstep.gd -- F:/Projects/server-height/crates/projectdawn-server/data
```

## 3. Traps specific to this build (read before the first edit)

- **The DLL must come from the height worktree.** `addons/gdext_net/build.ps1` hardcodes
  `$serverDir = "F:/Projects/server"` (the deploy branch, which will not have `DevFling`). Build
  by hand instead: in `F:\Projects\server-height`, `$env:RUSTFLAGS = "-C target-feature=+crt-static";
  cargo build -p gdext-net --release; Remove-Item Env:RUSTFLAGS`, then copy
  `target\release\gdext_net.dll` into `F:\Projects\Project_Dawn-height\addons\gdext_net\`. Do not
  edit `build.ps1`'s path in a commit. A DLL from another branch breaks `net.gd` at parse time
  and every headless probe then hangs with no verdict (memory `project_facing_branch_dll`); stop
  a hung Godot with `taskkill //F //IM Godot_v4.4.1-stable_win64.exe`. The height branch carries
  PD_W0029's four-argument `send_move`, so the DLL in the worktree today is already a facing-era
  build; after `DevFling` it must be rebuilt once more.
- **Every client check defaults to `F:/Projects/server`.** All eleven lockstep checks and
  `check_invariants.gd` read `OS.get_cmdline_user_args()[0]` as the server path, each in its own
  shape (the `DEFAULT_` constant at the top of each file says which: `check_terrain_lockstep.gd`
  wants the `data` directory, `check_constant_lockstep.gd` the `src` directory,
  `check_invariants.gd` the repo root, the item/spell/vendor/faction/active-skill checks one
  `.toml` file, the character/discipline/skill-table checks one `.rs` file). `check_all.ps1` passes
  no argument, so on the height branch it compares against the WRONG server. **First task
  (§4.0): give `check_all.ps1` a `-ServerRoot` parameter** that appends `-- <the right path>` per
  check (a small table in the script keyed by check name), default `F:\Projects\server`, so
  `.\tools\check_all.ps1 -ServerRoot F:\Projects\server-height` runs the whole set against the
  height worktree. Until then run each check by hand with its argument.
- **The exporter writes to the deploy checkout by default.** `tools/export_terrain.gd`'s
  `DEFAULT_OUTPUT` is `F:/Projects/server/.../terrain.toml`. Always pass the path:
  `-s tools/export_terrain.gd -- F:/Projects/server-height/crates/projectdawn-server/data/terrain.toml`.
- **The protocol variant goes LAST.** The plan's §6 says "appended after `DevDespawnEnemies`";
  that was the insertion point under PD_W0028. The encoding is positional, and `ClientWorldMsg`
  now ends with `Consider` then `DevSetFaction` (`crates/protocol/src/world.rs:1117-1127`), so
  `DevFling` is appended after `DevSetFaction`, the last variant, under the still-unshipped
  PD_W0029 (no new protocol id: PD_W0029 has never reached a build).
- **Records live on the deploy branch, code on the feature branch.** Docs (`CLAUDE.md`, the
  session note, the plan, the checklist, `commands.md`, memory) are committed on
  `fix/xp-leveling-overflow` in `F:\Projects\Project_Dawn` (switch there, commit, switch back to
  `feat/facing`), then merged into `feat/facing` and into `bump/nov` (`F:\Projects\Project_Dawn-bump`),
  all pushed BY NAME. Code is committed on `feat/height-model` in the two worktrees. The new
  checklist is a doc: deploy branch. The probe and the author tool are code: height branch.
- **CRLF.** Server `.rs` and `.toml` are CRLF; client files LF. The `Edit` tool preserves what it
  finds; a Python edit script must normalise and restore (the Oct 15 handoff §3 has the recipe).
- **Godot `.uid` files.** The repo tracks 165 of them and leaves the newest check tools' untracked.
  Commit a new script's `.uid` with the script (Godot writes it on the first `--import` or editor
  open); never commit one on its own.
- **`--import` once** after adding a script or resource before a headless run uses it.
- **Session note numbering.** `docs/session_notes/session_2026_10_25.md` is the running note
  (sections 50 to 54 are the height model); `grep -n "^## "` before adding yours. The README index
  row for 2026-10-25 is one long line: anchor an edit inside it, never on its end.
- **Harness rules** (from the Oct 15 handoff §3, still true in `tests/world/common/mod.rs`): a
  character's start position is seeded BEFORE login with `seed_position(db_url, char_id, x, z)`
  (never walked across the zone); `walk_until_within(c, &mut seq, char_id, from, target, stop_at)`
  walks on the server's own Position fan, 8 s deadline per call; `own_position_now(c, char_id)`
  reads the server's position; `spawn_dummy(c, name, dmg, aggro)` places a 100,000 HP, speed 0
  mob near the requester (use `c.send_dev_spawn(name, level, hp, dmg, speed, aggro)` for a mob
  that moves); a GM is `db::set_account_gm` plus a FRESH token (`request_world_token`); every
  class spell is pre-memorized by the harness; no flaky test exists, a failure is real. The
  terrain tests use `start_with_terrain(Terrain)` and keep the town flat (the NPC and safe-area
  tables stand on the COMPILED ground, process-wide; `tests/world/height.rs::test_ground` asserts
  it). Choose test rows north of every camp (z = 100 is the proven row; the nearest camp, the
  Broken Crypt at (-8, 124), keeps 12 m aggro plus 3 m jitter clear of x < -20 there).
- **Unit tests that read `terrain::compiled()`** (`entity.rs` around lines 1583 to 1802,
  `spawn_points.rs` 120 to 153) will run on the HILLS once `terrain.toml` carries them. Any
  that asserts a distance or a position near a feature may shift. Prefer giving those tests a
  `Terrain::flat(20, 20.0, 0.0)` (the signature is `flat(grid_size, cell_size, floor_y)`) over
  moving their coordinates; the one new test that must read the compiled ground is §4.1's floors test.
- **The look is runtime-made.** `scripts/terrain_mesh.gd::_rebuild` builds the material each
  time (green `Color(0.22, 0.42, 0.12)`); the scene's stored `StandardMaterial3D_r3fl7` (brown)
  is overwritten at `_ready`. Change the look in the script, never in the scene's subresource.
- **The collider check compares triangles in order.** `check_terrain_lockstep.gd::_check_collider`
  (line 122) holds the stored `TerrainCol` triangles against the ones the heights make. Flat
  shading changes the mesh's vertex layout; keep the trimesh's triangle order exactly as today
  (the `(z, x)` loops, each cell split `i, i+row, i+1` then `i+1, i+row, i+row+1`) or update the
  check in the same commit. Read `_check_collider` before changing `_rebuild`.
- **`direct_space_state` from outside `_physics_process`** is fine in this project:
  `autoloads/targeting.gd:92-94` already casts a ray from an input handler. The player's and every
  remote body's `global_position` is the FEET (the capsule is offset +1 m in `scenes/player.tscn:17`),
  the same point the server's `pos` names, so the client raises both ends by `LOS_HEIGHT` exactly.
- **No pathfinding exists.** Every mob and pet step is `step_toward` in a straight line
  (`entity.rs`); the mob rule in §4.3 relies on that (a mob at a face has no way round), and the
  integration tests exploit it.

## 4. The build, in order

Each step: say the plan to the user and wait for the go only where this file leaves a choice;
otherwise the user's go is given ("Go ahead when you're ready", 2026-11-04). Tests that fail on
the old code, proven by disabling the rule; both suites green; the exploit paragraph in the
To-Do entry; one commit per step with the records that step changes.

### 4.0 Tooling first (an hour)

**DONE 2026-11-04 (the Fable session, on the user's go; the Opus session verifies it once
and starts at 4.1).** `tools/check_all.ps1 -ServerRoot <server repo>` (default
`F:\Projects\server`) passes each lockstep check the path it wants from a table keyed by check
name; it refuses a root with no `Cargo.toml` and prints the root it compares against. Run
against `F:\Projects\server-height` from the height worktree: **all 14 checks PASS** (the
count is 14, not 12: `check_nameplates.gd` and `check_window_click_blocking.gd` take no
server path). Server baseline on `351e732`: **396 unit, 177 world tests green**, clippy
`-D warnings` and `cargo fmt --check` clean. `docs/reference/commands.md` gained the
`-ServerRoot` sentence and the three terrain tool rows. Committed on the deploy branch and
merged forward into `feat/facing`, `bump/nov` and from there into `feat/height-model`
(client), so the height worktree carries the runner. The height worktree is clean at the
merge commit; the server worktree is unchanged at `351e732`.

1. `check_all.ps1 -ServerRoot` (trap 2 above). Table: `check_terrain_lockstep.gd` and the vendor,
   item, spell, faction, active-skill checks under `crates/projectdawn-server/data` (the file
   each wants), `check_constant_lockstep.gd` the `src` dir, `check_character_lockstep.gd`
   `src/char_data.rs`, `check_discipline_lockstep.gd` and `check_skill_table_lockstep.gd`
   `src/world/skills.rs`, `check_invariants.gd` the root. Checks not in the table get no argument.
2. Run it against `F:\Projects\server-height`: all 14 PASS before anything changes. Run
   `cargo test` in the height worktree: 396 unit, 177 world. These are the baselines.
3. Add the undocumented terrain tools to `docs/reference/commands.md` §2's table (the checks are
   listed there from line 55; `export_terrain.gd`, `check_terrain_lockstep.gd` and
   `probe_ramp_speed.gd` were never added on 11-04): one row each, with the `--` argument.

### 4.1 Heights as data, and the hills (a day)

**Files.** Client: `data/terrain_features.toml` (new), `tools/author_terrain.gd` (new),
`scripts/terrain_mesh.gd` (the look), `scenes/world.tscn` (written by the tool), `project.godot`
(nothing here yet). Server: `data/terrain.toml` (written by the exporter), one new unit test.

**The features file** is the plan's §4 format, exactly: top-level `grid_size = 40`,
`cell_size = 10.0`; arrays of tables `[[hill]]` (`name`, `center = [x, z]`, `radius`, `height`;
a negative height is a hollow), `[[ridge]]` (`name`, `from`, `to`, `half_width`, `height`),
`[[plateau]]` (`name`, `rect = [x0, z0, x1, z1]`, `height`, `ramps = { west, south, north, east }`
in metres, 0 for a sheer face), `[[cut]]` (`name`, `from`, `to`, `half_width`, `floor`), and one
`[[rim]]` (`start_at`, `height`). Godot's `TOML` has no parser; write a small one in the tool
(numbers, strings, arrays of numbers, inline tables; `check_spell_lockstep.gd` and
`check_terrain_lockstep.gd::_parse_terrain_toml` show the idiom).

**Composition**, in this order, at every vertex `(x, z) = (-200 + ix * 10, -200 + iz * 10)`
for `ix, iz in 0..=40` (the grid is centred on the TerrainMesh's origin, which is `(0, 0, 0)`):

1. `h = 0`.
2. For each hill: `d = distance((x, z), center)`; if `d < radius`, `h += height * s(1 - d / radius)`
   where `s(t) = t * t * (3 - 2 t)` (smoothstep). Hollows subtract.
3. For each ridge: `d = distance from (x, z) to the segment from..to` (clamped to the segment, so
   the ends are rounded); if `d < half_width`, `h += height * s(1 - d / half_width)`.
4. For each plateau: inside `rect`, `h = max(h, height)`; in the ramp band outside an edge
   (within `ramps.<side>` metres of that edge, measured perpendicular), `h = max(h, height * (1 - dist / ramp))`;
   a side with ramp 0 gets nothing (the face is the one-cell drop between the last inside vertex
   and the first outside one: 18 m over 10 m is 61°, past the 60° slope limit, a face).
5. For each cut: within `half_width` of the segment, `h = min(h, floor)`.
6. The rim: `r = max(|x|, |z|)` (the plate is square); if `r > start_at`,
   `h = max(h, height * (r - start_at) / (200 - start_at))`.
7. `h = max(h, 0)` (nothing below the floor at y = 0).

The tool prints the composed heights as the scene line and writes them INTO `scenes/world.tscn`
in place: in the `[node name="TerrainMesh" type="Node3D" parent="."]` block (line 80 today;
`script = ExtResource("4_terrain")` then `heights = PackedFloat32Array(...)` on line 82), it
replaces the `heights = ...` line and inserts or replaces `grid_size = 40` and `cell_size = 10.0`
lines before it (the scene stores an exported property only when it differs from the script's
default; the exporter's `read_scene` falls back to the script defaults, 20 and 20.0, when the
property is absent, so the two lines MUST be in the scene). Every other byte of the scene is
left alone; a Python-style edit on the one block, written to the scratchpad and diffed on a copy
first, is the safe way (Oct 15 handoff §3).

**The mesh and collider subresources.** The scene also stores `ArrayMesh_jka67` (lines 47 to
60) and `ConcavePolygonShape3D_i5arm` (line 61), which the `@tool` rebuilds from the heights on
load and the editor writes on save; `check_terrain_lockstep.gd` fails on a collider not rebuilt.
Two ways to refresh them after the tool writes the heights, in order of preference:

1. The tool does it headless: load `world.tscn` as a `PackedScene`, `instantiate()` it (the
   `@tool` `_ready` runs `_rebuild`, which sets `TerrainVisual.mesh` and `TerrainCol.shape`),
   `PackedScene.new().pack(root)` and `ResourceSaver.save` to a SCRATCH path, then compare the
   scratch file with the real one: if they differ only inside the three terrain subresources and
   the `TerrainMesh` block, copy the scratch file over the scene; if anything else moved (node
   order, ids, a property Godot normalised), print the first differing line and exit 3 without
   writing. Instancing `world.tscn` pulls in the HUD and the NPC scenes, so this runs with the
   project's autoloads (a `SceneTree` script has them after `await process_frame`); if that
   proves heavy or flaky, fall back to 2.
2. The user opens `world.tscn` in the editor and saves (one manual step, which also gives them
   the first look at the hills); you then run the lockstep check. Say which way it went in the
   session note.

**The report** (printed, and the exit code): for every camp spawn in the server's
`zone_camps.toml` (parse `spawns = [[x, y, z], ...]` under each `[[camp]]`; the file is CRLF; the
`radius` key when present, default 3.0) and every NPC in `npcs.toml`: the steepest gradient at
the spawn and at the four corners of its jitter square (`±radius` on x and z), as an angle;
FAIL if any is past 55° (the floor limit, `fall.rs::FLOOR_MAX_ANGLE_DEG`: a mob must stand). The
town square (radius 10 at the origin) and the NPC row (z = 5, x from -5 to 11): FAIL if any
height inside is not 0. The straight line from the origin to each camp's first spawn, sampled
every metre: the steepest grade along it, WARN past 30°. The rim: the height at the four plate
edges. Read the gradient the way the server does (`terrain.rs::gradient`, the triangle's plane,
the same split as `export_terrain.gd::ground_at`); add a `gradient_at` static beside `ground_at`.

**The hills**, from the plan's §3, with the camp spawns they must respect (read from
`zone_camps.toml` on 2026-11-04; x east, z north):

| Feature | Feature parameters | The spawns on or near it |
|---|---|---|
| The western hills | hill, center (-160, 0), radius 70, height 25 | Ossuary (-168, 8), (-174, -14): on the rise, about 20 m up, each 6 to 12 m from the west rim's foot |
| The Sunken Barrow | hill, center (-150, -6), radius 18, height -12 (a hollow in the rise) | Barrow zombies (-146, -8), (-152, 2), (-142, -18); the Undying (-156, -6). Every spawn and its jitter square on a floor (the hollow's walls about 45°) |
| The bandit knoll | hill, center (-58, 60), radius 25, height 8 | Bandit Outpost (-56, 52), (-64, 60), (-50, 66) on its top |
| The Greywood ridge | ridge, (-120, 85) to (120, 85), half_width 15, height 16 | nothing spawns on it; Bat Hollow (4, 44), (-6, 48), (10, 50), Sable (0, 54) south of its foot; the Broken Crypt north |
| The pass | cut, (0, 60) to (0, 110), half_width 6, floor 0 | the way through the ridge at x = 0 |
| Bat Hollow | hill, center (3, 48), radius 14, height -4 | the three bats and Sable: a gentle dip, at most 24° |
| The crypt's bowl | hill, center (2, 118), radius 20, height -5 | the Broken Crypt (10, 118), (-8, 124), (2, 112) in it |
| The spiders' rise | hill, center (110, 2), radius 30, height 6 | Spider Copse (104, 10), (112, 2), (108, -8); the Crawler (116, 4) |
| The Wraith Gate plateau | plateau, rect (150, -40, 200, 30), height 18, ramps west 0, south 30, north 30, east 0 | Wraith Gate (178, 5), (175, -20) on its top; the west edge is the one real cliff (an 18 m fall, 40% of max HP) |
| The old rocks | hill, center (3, -72), radius 22, height 6 | Rotfang's Den (8, -68), (-2, -72); Rotfang (4, -76) |
| The war camp's shelf | hill, center (2, -150), radius 40, height 8 | Gnoll War Camp (2, -148), (16, -144), (-12, -152); Greth (4, -158) |
| The rim | rim, start_at 180, height 30 | nothing spawns past 180 m but the wraiths at (178, 5) and (175, -20), 2 to 5 m from the east rim's foot |

Rings 1 and 2 stay flat by the composition (no feature reaches them): the Bonepile (-18, 12),
(-24, 14), (-16, -14), (-12, 20); Wolf Run (24, -16), (30, -20), (22, -24), (28, -18); the Rat
Warrens (24, 18), (29, 18), (26, 22), (31, 19); the Shallow Graves (36, 28), (44, 22), (30, 40);
the gnoll raiders (46, 4), (52, -2), (48, 10), (54, 6); the Boar Thicket (-38, -30), (-30, -42),
(-44, -24); the Festering Mound (58, -56), (70, -52), (55, -70). The report must say they are at
0. If the report fails on a spawn (a Barrow zombie's jitter corner on the hollow's wall is the
likely one), move the FEATURE by a few metres or soften it, never the camp; say what moved.

**The export and the lockstep.** Run the exporter with the height worktree's path (trap 3), then
`check_terrain_lockstep.gd -- F:/Projects/server-height/crates/projectdawn-server/data`: it must
print 1,681 heights, 40 x 40 cells of 10 m, the collider rebuilt, 6 NPCs on the ground. Boot the
server once (`cargo run -p projectdawn-server` in the worktree, any env) and read the boot line's
`terrain="40x40 cells of 10 m, floor 0, hash <12 hex>"`; stop it. The hash in `terrain.toml` is
what `terrain.rs::compiled()` checks; a hand edit of either file fails the parse.

**The server test** (unit, in `spawn_points.rs` or a new `terrain_content.rs` test module):
for every `load_camps()` spawn and its jitter corners and for every NPC (`npcs.rs` has no
public iterator today: add `pub fn all() -> &'static [Npc]` over its `table()`),
`fall::is_floor(compiled().gradient(x, z))` holds, and the town square is flat. This is the
author tool's report held on the server side, so a hand edit of either file fails a test.

**The harness default** (`tests/world/common/mod.rs:44-46`): `start_both_opts` passes
`Some(Arc::new(Terrain::flat(20, 20.0, 0.0)))` instead of `None` (`start_with` already takes an
`Option<Arc<Terrain>>`; `None` means the compiled terrain, `tick/mod.rs:171-174`). Run the full
suite after the export: every old test must stay green on the flat default; the terrain tests
bring their own grounds already.

**The look** (`scripts/terrain_mesh.gd::_rebuild`): two exports, `flat_shaded := true` and
`height_tint := true`. Flat: emit three vertices per triangle (no index array), `generate_normals`
then gives face normals; the tint: `mat.vertex_color_use_as_albedo = true` and
`st.set_color(tint(h))` before each vertex, `tint` lerping the low green `(0.22, 0.42, 0.12)` to
a high grey-brown such as `(0.45, 0.40, 0.32)` over 0 to 30 m (two constants at the top, knobs).
Keep the trimesh's triangle order (trap 11). Ask the user to "look" once the scene is saved
(memory `reference_view_window`: read `F:\Projects\view_window\captures\latest.png`).

**Commit** (height branches): the features file, the tool, the script, the scene, the server
`terrain.toml`, the test, the harness line, the `commands.md` rows. Exploit paragraph for the
To-Do: a modified client with a different scene walks the server's hills, not its own (the
reconciliation pulls it back; the slope rule refuses a climb its own collider would allow; the
sight rule reads the server's ground); the hash refuses a hand-edited `terrain.toml`; the rim is
a 56° face, no climb.

### 4.2 The fling tool (half a day)

**Server.**
1. `crates/protocol/src/world.rs`: append `DevFling { height: f32 }` after `DevSetFaction`
   (the last `ClientWorldMsg` variant, line 1124), with a doc comment in the style of
   `DevDespawnEnemies` (line 1083); extend the PD_W0029 paragraph (line 153) with one sentence.
2. `src/world/handlers.rs`: a new arm beside `ClientWorldMsg::DevDespawnEnemies` (line 1329),
   same shape: `if !conn.in_world || !conn.can_use_dev_cmds() { return Outcome::Continue; }`,
   then REFUSE silently (`Outcome::Continue`, no audit row) a height that is not finite or not in
   `0.0 < height <= MAX_FLING_HEIGHT` (a const, 100.0: rule A3 of `invariants.md`, a non-finite
   number never reaches a position), then `dev_cmd_allowed(server, conn, client_id, now,
   "dev_fling", format!("height={height:.1}"))`, then `Outcome::DevFlingIntent { requester:
   client_id, height }` (add the variant to the `Outcome` enum near `DevDespawnEnemiesIntent`,
   line 407).
3. `src/world/tick/intake.rs::route_outcome` (the `DevDespawnEnemiesIntent` arm is at line 619;
   the function has `connections: &mut HashMap` since the respawn grounding): apply the fling
   right there, no intent vec: `let Some(conn) = connections.get_mut(&requester)`; if
   `conn.hp <= 0.0 || conn.death_processed` do nothing; else `conn.pos.y += height;
   conn.vertical = fall::Vertical { airborne: true, vy: 0.0, from_y: conn.pos.y };
   handlers::send_teleport(&mut *server, requester, conn.pos)` (the Teleport puts the client's own
   body in the air; it then falls under its own gravity as the server's body does). The movement
   step (`tick/movement.rs:127`) runs every ready connection each tick, Move or no Move, so the
   body falls from the next tick and `land` charges the landing with the line and the
   `fall damage` log line. Nothing else to add.
4. `crates/gdext-net/src/lib.rs`: `#[func] fn send_dev_fling(&mut self, height: f64) -> bool`
   beside `send_dev_set_faction` (line 1002), sending `ClientWorldMsg::DevFling { height: height as f32 }`
   on `CHANNEL_SYSTEM`.
5. Harness: `pub fn send_dev_fling(&mut self, height: f32)` beside `send_dev_despawn_enemies`
   (`tests/world/common/mod.rs:879`).
6. Test `tests/world/falls.rs::a_flung_gm_lands_for_the_formulas_damage`: `start_both()` (flat);
   a GM (`gm_at`-style helper, or `provision_client` + `set_account_gm` + a fresh token) reads its
   `max_hp` from the first HealthUpdate (the `walker_on_the_plateau` idiom, line 36); sends
   `send_dev_fling(20.0)`; within 3 s receives `Teleport` with `y` about 20, then the line
   `You hit the ground hard for N damage.` with `N = fall::damage(20.0, max_hp) as i64` (45% of
   max HP) and a HealthUpdate at `max_hp - N`; `own_position_now` ends at y = 0; and one row
   `SELECT COUNT(*) FROM gm_actions WHERE command = 'dev_fling'` (the `admin.rs:25` idiom). A
   plain second account sends `send_dev_fling(20.0)`: no Teleport, no line, no row (the
   `dev_despawn_removes_enemies_on_the_server` idiom at `admin.rs:402`, with its `PD_DEV_CMDS`
   guard). A forged `send_dev_fling(f32::NAN)` from the GM: no Teleport, no row, position finite.
   Prove it fails with the fling arm returning `Continue`.
7. Rebuild the DLL (trap 1).

**Client.**
1. `tools/check_wire_layer.gd` `METHODS`: add `"send_dev_fling"`.
2. `scripts/test_panel.gd::_build_resources_section` (line 177, beside `Trigger Death` at 182):
   two buttons, `_make_btn("Fling 5 m", C_DIE)` and `_make_btn("Fling 20 m", C_DIE)`, each
   `_require_connection()` then `if Net.has_method("send_dev_fling"): Net.call("send_dev_fling",
   h) else: CombatLog.add_line("TestPanel: this build's wire layer cannot fling.", CombatLog.MsgType.INFO)`
   (the `_despawn_all_enemies` idiom, line 408; `Net` extends `NetClient`, so the DLL's funcs are
   its own methods).
3. A probe is optional; the headless `check_wire_layer.gd` plus the sheet's row cover it.

**Exploit paragraph:** dev-gated and audited like every dev command (a plain account's send is
ignored silently: no reply, so no oracle for the gate); the height is bounded and finite before
anything moves; the landing goes through the same `land` as a real fall (a GM's fall costs the
GM); nothing a client sends sets a position directly.

### 4.3 Mobs at a face (half a day)

**The rule, in `src/world/entity.rs`.** Add `pub stuck_since: Option<Instant>` to `Entity`
(initialised `None` where every other field is, and reset to `None` in `transition`). Add one
step helper:

```rust
/// One step toward `to`, standing on the ground, refused up a face the slope rule
/// forbids (the player's own rule, `Terrain::slope_ok`). Returns whether it moved.
fn step_on(&mut self, terrain: &Terrain, to: Vec3f) -> bool {
    if !terrain.slope_ok(self.pos, to) { return false; }
    self.pos = terrain.ground_vec(to);
    true
}
```

and route the four `self.pos = terrain.ground_vec(self.pos.step_toward(...))` sites through it:
`tick_chase` (line 1163), `tick_leash` (1216), and the pet's attack and follow steps (1052, 1077).
Then the clocks, all against `MOB_STUCK_SECS` (`pub const MOB_STUCK_SECS: f32 = 8.0;` in
`src/world/mod.rs` beside `MIN_LEASH_RANGE` at line 194, documented as a knob):

- `tick_chase`: when the step was refused, `self.stuck_since.get_or_insert(now)`; when it moved,
  `self.stuck_since = None`; when stuck for `MOB_STUCK_SECS` or more: `self.target = None;
  self.threat.clear(); self.aggro.clear(); self.transition(EnemyState::Leash, now)`.
  (`tick_leash` heals to full and clears the lists again at home; `transition` to Leash or Dead
  already clears `active_dots`, line 618.)
- `tick_leash`: a refused step on the way home for `MOB_STUCK_SECS` warps the mob to
  `terrain.ground_vec(self.spawn_pos)` (EQ's mobs warp home when stuck), which the home check
  then handles next tick.
- `tick_pet_ai`, follow branch: a refused step for `MOB_STUCK_SECS` warps the pet to
  `terrain.ground_vec(owner_pos)` and clears the clock. Attack branch: a refused step for
  `MOB_STUCK_SECS` drops the target (`self.target = None`) and clears the clock; the follow
  branch then handles the owner (no warp onto an enemy).
- The AI loop (`tick/enemy_ai.rs:265-300`) already detects the AOI cell change after `tick_ai`,
  so a warp fans like any move.

**Unit tests** (in `entity.rs`'s test module, which already builds entities against a terrain;
use `Terrain::from_heights` with a one-cell 70° face as `tests/world/height.rs::test_ground` does,
never `compiled()`):
- `a_mob_at_a_face_stops_and_gives_up`: a chasing mob at the foot with its target on top
  (`threat` holding the target); 20 Hz ticks for 8.5 s; `pos` never on the face; then `Leash`,
  no target, empty lists. A control on flat ground reaches `Attack`.
- `a_pet_that_cannot_reach_its_owner_warps_to_them`: a pet (`owner` set, no target) at the
  foot, the owner on top; after 8.5 s of ticks `pos` within 1 m of the owner's.
- `a_pet_drops_a_target_it_cannot_reach`.

**Integration test** (`tests/world/height.rs` or a new `tests/world/faces.rs`), the plateau
with a ramp: `Terrain::from_heights(30, 5.0, [-90.0, 0.0, 100.0], 0.0, heights)` (a 150 m grid
centred at (-90, 100), 5 m cells: x from -165 to -15, z from 25 to 175; clear of the town and,
on the plateau's rows, of every camp: the Bandit Outpost's nearest spawn (-50, 66) is 34 m from
the bait at (-61, 100), past 14 m aggro plus 3 m jitter). The plateau at 15 m for x in [-100, -60]
and z in [85, 115]; the west side a ramp from 0 at x = -130 to 15 at x = -100 (26.6°, a floor);
the east, north and south sides one-cell faces (15 m over 5 m, 71.6°). Then:

`a_mob_at_a_face_gives_up_and_walks_home`: A, a GM, seeded at (-45, 100) at the east foot,
sends `send_dev_spawn("Face Dummy", 1, 500.0, 0, 3.0, 0.0)` (passive, speed 3, 500 HP) and reads
its id and spawn position from `EnemySpawn`. B, a plain Cleric (level 5 via `set_char_level`),
seeded at (-60.5, 100): on the plateau half a metre from the lip (from there the sight line to the
foot clears the lip by 0.6 m and the ground by 10 m; from further back the lip blocks it, so
keep B at -60.5). B casts Smite at the dummy (read Smite's `cast_time` in `data/spells.toml`:
instant means `send_cast_spell` alone, otherwise `send_cast_start(name, secs)`, pump, then
`send_cast_spell`; reach 30 m, the distance is about 20 m). A waits for
`EntityTarget { id: dummy, target: Some(B) }`. For the next 6 s every Position of the dummy at
A has `x > -56` (the face spans x from -60 to -55; the mob reaches the foot and stops). Then
within 10 s more A sees `EntityTarget { id: dummy, target: None }`, and within 6 s after that
the dummy's Position within 1.5 m of its spawn and a HealthUpdate for it at 500. B receives no
hit from the dummy throughout. On the previous server the mob climbs the face pinned to the
ground and reaches B in about 3 s: the `x > -56` assertion fails.

`a_pet_warps_to_an_owner_it_cannot_reach` (build it only if it runs under 25 s; otherwise the
unit test stands and the session note says so): a Necromancer at level 8 (Bind Affinity, Gate
and Summon Skeleton; check `spells.toml` for the three levels) seeded at (-61, 100) on the
plateau: casts Bind Affinity (a self-bind, anywhere), walks east off the lip and falls to the
foot (a 15 m fall, 32.5% of max HP; it survives), summons the skeleton there, `PetCommand`
guard, casts Gate (5 s): it lands at the bind on top while the parked pet stays (verify in
`tick/casting.rs`'s port arm that only a pet in Follow comes along: grep `PetStance` there;
if every pet comes, use the respawn-at-bind route instead: a dev `send_damage_self` and
`Respawn`, which takes the owner to the bind). Then `PetCommand` follow: the pet's Positions
stay at the foot (`x > -56`) for 7 s, then one lands within 3 m of the owner on top. On the
previous server the pet walks up the face at once.

**Exploit paragraph:** a player on a lip nuking a mob at its foot gets no kill: the mob walks
home at the 8 s mark and heals to full (the mana is spent for nothing), and the sight rule
already refuses a cast THROUGH the face; the pet warp moves a pet only to where its owner
already stands. Nothing here reads client input.

### 4.4 The client's own sight check (half a day)

1. `project.godot`: a `[layer_names]` section (none exists today) with
   `3d_physics/layer_1="bodies"` and `3d_physics/layer_2="terrain"`.
2. `scenes/world.tscn`: `collision_layer = 3` on `TerrainBody` (line 87) and on `Floor` (line 92):
   layers 1 and 2, so every body still stands on them (their masks are the default 1) and the
   sight ray can ask for layer 2 alone. The exporter and the lockstep check read these nodes by
   name and ignore the property; `check_terrain_lockstep.gd` must stay green.
3. `autoloads/spells.gd`: a `const LOS_HEIGHT := 1.2` and `const TERRAIN_LAYER_MASK := 2` at the
   top (beside the reach comment, line 21), and after the reach refusal (lines 185 to 187):

   ```gdscript
   if _target_out_of_sight(spell):
       spell_failed.emit("You cannot see your target.")
       return false
   ```

   `_target_out_of_sight` takes the same cases as `_target_out_of_reach` (line 448: ENEMY,
   PET_CHARM, an ALLY on another; the corpse, pet-heal and bind-other cases get the server's
   line a round trip late, as today), raises both feet positions by `LOS_HEIGHT`, and returns
   `not space.intersect_ray(params).is_empty()` with
   `PhysicsRayQueryParameters3D.create(a, b, TERRAIN_LAYER_MASK)` and `collide_with_areas = false`
   (the `targeting.gd:92` idiom; `me.get_world_3d().direct_space_state`).
4. `tools/check_constant_lockstep.gd`: a pair `LOS_HEIGHT` (server `world/terrain.rs`, client
   `autoloads/spells.gd`, relation eq). Read the file's pair table and the `magnitude` relation
   added on 11-04 for the format.
5. `tools/export_terrain.gd`: a static `can_see_at(terrain: Dictionary, a: Vector3, b: Vector3) -> bool`
   beside `ground_at`, a line-for-line port of `terrain.rs::can_see` and `min_clearance` with
   `push_crossings` (the Rust is quoted below), using the same raised endpoints and
   `LOS_TOLERANCE` 0.01, so the check tools and the probe share one port.
6. `tools/probe_terrain_sight.gd` (headless; NOT a `check_` so `check_all.ps1` does not run it,
   or make it a `check_` if it finishes in under 20 s): read the scene with
   `Exporter.read_scene` (its `collider` is the stored `TerrainCol` triangles); build a
   `StaticBody3D` with a `ConcavePolygonShape3D` from that data on layer 2, and a `Floor` with a
   `WorldBoundaryShape3D` at `floor_y`, in a bare `SceneTree`; `await process_frame` twice; then
   for 3,000 seeded-random pairs of points on the ground inside the grid (seed the RNG,
   `RandomNumberGenerator.seed`), compare the ray's answer with `can_see_at`'s over the TOML the
   exporter would write (`render_toml` then `_parse_terrain_toml`, or the scene dictionary
   itself). Count disagreements where the port's own minimum clearance is beyond ±0.05 m of the
   ground (a graze within that band may go either way on float rounding); require zero; print
   the counts and the worst case. It must fail with the port's `LOS_HEIGHT` set to 0.
7. Mention in the sheet that the bow keeps the server's Miss (no client check for ranged
   auto-attack); a later pass may stop the swing on a sight failure.

The Rust the port mirrors (`terrain.rs:432-485` and `505-521`), so the GDScript carries the same
decisions (the crossings of every cell edge along x, along z, and the diagonals `lx + lz = k * cell`;
the clearance at both ends and at each crossing; the minimum compared with `-LOS_TOLERANCE`):

```rust
pub fn can_see(&self, a: Vec3f, b: Vec3f) -> bool {
    // both ends finite, else false
    let a = Vec3f { y: a.y + LOS_HEIGHT, ..a };
    let b = Vec3f { y: b.y + LOS_HEIGHT, ..b };
    self.min_clearance(a, b) >= -LOS_TOLERANCE
}
fn min_clearance(&self, a: Vec3f, b: Vec3f) -> f32 {
    let (ax, az) = self.local(a.x, a.z);      // x - origin.x + half, z - origin.z + half
    let (bx, bz) = self.local(b.x, b.z);
    let mut ts: Vec<f32> = vec![0.0, 1.0];
    push_crossings(&mut ts, ax, bx, self.cell_size, self.grid_size);
    push_crossings(&mut ts, az, bz, self.cell_size, self.grid_size);
    push_crossings(&mut ts, ax + az, bx + bz, self.cell_size, 2 * self.grid_size);
    ts.into_iter().map(|t| {
        let p = a + (b - a) * t;              // componentwise
        p.y - self.ground_snapped(p.x, p.z)   // ground(): max(mesh, floor), the floor outside the grid
    }).fold(f32::INFINITY, f32::min)
}
fn push_crossings(ts: &mut Vec<f32>, s0: f32, s1: f32, cell: f32, kmax: usize) {
    if s0 == s1 { return; }
    let (lo, hi) = if s0 < s1 { (s0, s1) } else { (s1, s0) };
    let k0 = ((lo / cell).ceil().max(0.0)) as usize;
    let k1 = (hi / cell).floor();
    if k1 < 0.0 { return; }
    let k1 = (k1 as usize).min(kmax);
    for k in k0..=k1 {
        let t = (k as f32 * cell - s0) / (s1 - s0);
        if t > 0.0 && t < 1.0 { ts.push(t); }
    }
}
```

**Exploit paragraph:** the client check is a courtesy; the server's `can_see` at the release is
the rule, so a client that skips it gets the refusal a round trip late and nothing else.

### 4.5 The sheet and the records (the rest)

`docs/playtest_notes/first_hills_checklist.md` from `TEMPLATE_checklist.md`, the plan's §9 as
rows: Setup (the boot line's `terrain="40x40 cells of 10 m ..."`, `check_all.ps1 -ServerRoot`,
the start time); the routes from town to each ring 3+ camp (the uphill feel, no rubber-banding,
the pass); a fight at each hill camp (mobs on the slope, chasing up and down, leashing); the
Wraith Gate plateau (the south ramp, the lip, the line and the HP drop, a death from it and the
corpse run back up); a Smite through the ridge refused by the client before the bar, and landing
from the pass; a mob pulled to the plateau's foot giving up and walking home at full health
(watch its HP bar); the fling at 5 and 20 m (5 m costs 7.5% of max HP, 20 m 45%); the Sunken
Barrow from its rim; the rim of the plate (a 56° face, no climb, the slide down); two seats (a
partner walking up a hill, standing on it, jumping on it, falling off the lip); the journal
(`grep -E "ERROR|WARN|cannot see|fall damage|slope_refusals=[1-9]|dev despawn|dev_fling"`): no
`cannot see` for a cast the client let through, `slope_refusals` a curiosity on hills, a
`fall damage` line per fall taken and none else. Build prerequisite up front: the November
bump's redeploy AND export, both from the merged `feat/height-model`.

Add the sheet to `docs/playtest_notes/CHECKLIST_RUN_ORDER.md` (after `height_model_checklist.md`).

## 5. The records pass (every step; the full list at the end)

- `CLAUDE.md`, the To-Do entry "The server height model" (under World systems; the paragraph
  beginning `**Slice 3, the first hills, PLANNED 2026-11-04` is the anchor): add
  `**Slice 3 BUILT <date>** (...)` with the shas, what exists, the knobs (`MOB_STUCK_SECS`,
  `MAX_FLING_HEIGHT`, the tint colours), the flagged list, the exploit paragraphs. Never tick.
- `docs/design/first_hills_plan.md` §10: each decision marked DECIDED 2026-11-04 (done in this
  commit); add a "§11 As built" with what differed from the plan.
- `docs/design/server_height_model.md` §3.4/§3.5: the "mobs climb anything, for now" sentences
  gain the (b) rule; §3.8 gains the client check as built.
- `docs/reference/commands.md`: the author tool and the sight probe rows; the fling in the
  in-game commands section if one lists Test Panel buttons (grep `Despawn All`).
- `docs/reference/invariants.md`: grep `dev command` and `DevDespawnEnemies`; if a rule names
  the dev commands, add `DevFling` and its test.
- `docs/session_notes/session_2026_10_25.md`: a section per step (§55 onward; §54 is this
  handoff), and the README index row's text extended inside the row.
- The planner: `docs/schedule_detail.toml` rows `b55` (the build) and `v59` (the sheet; the
  last ids today are `b54`, `v58`, `o19`, so the redeploy row would be `o20` when the bump day
  is planned), then `python tools/schedule_detail.py` and the republish at the plan file's
  `published_url` (read it with the Artifact tool first, or the publish is refused).
- Memory: update `project_bump_day_merges.md` (the hills are on `feat/height-model` too; the
  bump day takes the rebuilt DLL from the height worktree) and `project_handoff_first_hills.md`
  (progress lines, as the Oct 15 handoff kept them).
- Commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` only if that is
  the line the harness gives you; otherwise the harness's own attribution line. Push every
  branch by name: `git push origin feat/height-model` in each worktree, `git push origin
  fix/xp-leveling-overflow`, `feat/facing` and `bump/nov` in the client.

## 6. Done means

- Server: the suite green (expect about 400 unit, 180 world), clippy `-D warnings` and
  `cargo fmt --check` clean, every new test proven to fail with its rule disabled, the boot line
  naming the 40 x 40 ground.
- Client: `.\tools\check_all.ps1 -ServerRoot F:\Projects\server-height` all PASS (14 today, 15
  with any new `check_`), `check_wire_layer.gd` listing `send_dev_fling` OK against the rebuilt DLL, the
  sight probe at zero disagreements, the author tool's report clean (every spawn on a floor, the
  square flat, no route past 30° or the warning noted).
- The user has looked at the hills in the editor once.
- The sheet exists; nothing is ticked.
- The records pass done, both repos pushed by name, the memory updated.
- Flagged, not built, written in the To-Do entry: the bow's client sight check; a client-side
  slope pre-check (the body's own `floor_max_angle` is it); terrain chunking; a navmesh; the
  per-creature `LOS_HEIGHT`; `addons/terrain_editor` left disabled.

## 7. If something here is wrong

The anchors were read on 2026-11-04. If a grep finds a name or line moved, trust the source,
fix the anchor in this file in the same commit, and say so in the session note. If a decision
turns out to need the user (a camp that cannot sit on its feature without moving, the pet warp
test's route, the look), ask in one line with a recommendation and keep building everything
that does not depend on the answer.
