# Session 2026-11-16: rolling hills

Built on `feat/rolling-hills` in both repos (a new worktree `F:\Projects\Project_Dawn-hills`
from the client deploy tip `39dd53c`; the server branch in `F:\Projects\server-zone` from
the deploy tip `8d1dc67`). Client `dfbda40` + the pass fix `260f42c`, server `86aa72a` + `a3b226d`, all pushed. Not merged, not
exported, not deployed: the timing is the user's call.

## 1. What was asked

"Do you think you could add rolling hills? right now the sight line allows a player to see
across the entire flat land." Offered three sizes; the user: "12, 25, 35. Also have
variation between those or everything will look static." Read as three layers of rolling
ground, about 12, 25 and 35 m high, each varying across the map.

## 2. Why the plate looked flat

The rolling ground was two noise layers, 0 to 3.5 m every 240 m and 0 to 9 m every 700 m.
A standing eye is 1.7 m up; almost nothing dropped out of view. The noise also uses only
about half its 0 to 1 range in practice (measured: 5th to 95th percentile 0.24 to 0.76 at
two octaves), so its real relief was smaller still.

## 3. What changed

- `data/terrain_features.toml`: three `[[noise]]` layers, "the swells" (12 m, every 280 m,
  three octaves), "the rolls" (25 m, every 650 m) and "the broad rises" (35 m, every 1,300
  m), each with `vary` (0.5, 0.5, 0.4) and its own `vary_seed` and `vary_wavelength` (1,100,
  1,700 and 2,500 m): the layer's height is scaled from `1 - vary` to `1 + vary` by that
  broad noise, so its average is the user's number and one stretch is meadow, the next hill
  country. The town's calm radii are as before for the swells (170 to 420 m) and wider for
  the bigger layers (250 to 700, 320 to 900). The foothills layer is unchanged.
- `tools/author_terrain.gd`: the composition order. The plateau (a `max` to its top) and the
  cut (a `min` to its floor) set heights outright, so with tens of metres of rolling ground
  laid after them the Wraith Gate cliff would have shrunk and the pass become a trench again
  (the 11-14 bug). Now the plateau and the cut apply first and `rolling_at` adds the rolling
  ground over everything, so the pass floor follows the swells. `octaves` and the `vary`
  fields are read per layer.
- The pass's cut took two tries, both caught by the server test in section 5: floor 0
  running to z = 1030 reached into the crypt's bowl rim and left a 1.9 m bank at the north
  mouth; floor 6 dropped off the ridge's north foot instead (the base ground between the
  ridge and the rim is level at 0). It now runs from 770 to the ridge's north foot at 1010
  with its floor at 0, so its rounded ends lie on level base ground.
- `scenes/world.tscn`: the new heights. `terrain.toml` re-exported on the server branch:
  `hash f569ade0c331`.

## 4. Measured

- **Sight** (measured on the first export, before the pass fix, which changed only the pass;
  a one-off script, not committed: 60 standing observers spread over the walkable
  ground, 40 targets each per band, eye and target at 1.7 m): within 250 m, 79% of the
  ground in sight (89% on the old ground); 250 to 500 m, 39% (62%); 500 m to 1 km, 30% (44%);
  1 to 2 km, 16% (26%).
- **The author report**: clean. Every camp spawn, jitter corner and NPC on a floor (steepest
  14.6 degrees, at the Bandit Outpost); the roads at most 17.3 degrees; every camp reached,
  the ridge's crest, the plate's edge and the mountains not; 9,433 face triangles (9,423 on
  the compass build). Camps stand higher (the Ossuary at 148 m, the Wraith Gate at 91 to 95
  m, the war camp at 60 m). The two route WARNs, the straight lines to the Broken Crypt and
  the Wraith Gate, run through the ridge and up the cliff as before.
- **The highest walkable ground**: 151 m, under the shader's rock line (`alpine_from` 190 m),
  so no meadow turns to rock.
- **The shapes the server now tests**: the cliff 58 m from lip to foot; no step steeper than
  30 degrees anywhere on the line through the pass; the walls 40 m or more above its floor.

## 5. Tests

- Server: `the_compiled_terrain_parses_and_its_hash_matches` pinned the plateau at 60 m and
  the pass floor at 6 m; it now holds them by shape: the lip 50 m or more over the ground a
  cell past the foot; walked from 130 m before the pass to 130 m after, every 2 m, no step
  steeper than 30 degrees; the walls 40 m or more above the floor. The walk failed on both
  earlier cuts (1.90 m over 2 m at the north mouth, then 1.31 m at the ridge's foot); a first
  version that compared the floor with the ground at the mouths passed on both, since the
  mouths it read sat on the cut's own rounded ends.
  `a_mob_below_the_plateau_ramp_gives_up_on_a_player_on_its_edge` failed at "the Smite turns
  the dummy on the Cleric": the ramp's side wall at the old perch (z = -408) is about 30 m
  now, so the dummy at its foot was 33.6 m from the Cleric, past Smite's 30 m (sight was
  clear). The perch moved to z = -422, where the wall is about 23 m (66 degrees, still a
  face) and the dummy 27 m away. Suite 412 unit and 191 world, fmt and clippy clean.
- Client: all 17 checks against `server-zone` (terrain lockstep and sight among them);
  `probe_zone_world_loads` (bodies on the plateau at 116.6 m, the western hills' crest, the
  barrow's floor, the pass's floor, the war camp's shelf), `probe_terrain_stand`,
  `probe_cast_sight`, `probe_fall_and_death_online`.

## 6. Exploit lens

Nothing new to forge: the ground is the server's compiled file, a modified client walks the
server's hills. No camp or NPC moved off a floor; nobody can walk out (the report and
`nobody_walks_out_of_the_zone`); the cliff is still a lethal fall and the ramp perch still
under the evade rule (the moved test). Sight is the server's rule, so the swells now decide
what a spell, an arrow or an idle mob's scan can reach.

## 7. Deploy shape

Both sides move together, as with the compass: a client on the old ground against this
server would stand on ground up to tens of metres off. No migration and no SQL: a login lands
on the ground as it is now (`tick/session.rs`), a respawn lands grounded, corpses are pinned
at load. The boot line must read `terrain=400x400 cells of 10 m, floor 0, hash
f569ade0c331`. Parts of `zone_4km_checklist.md` section 7 would be walked again on the new
ground.

## 8. Not built, flagged

- The GM flight client is on `feat/gm-flight`, so walking this branch from the editor is on
  foot.
- The wandering wildlife design (`docs/design/wandering_wildlife.md`, not built) builds its
  roam map from the terrain at runtime, so it takes the hills as they are.
- Trees and set pieces stand on the ground at load, so they follow; nothing was re-placed.

## 9. Records

CLAUDE.md's To-Do (the 4 km zone entry); this note and its README row; the planner's b62 and
the tentative o28 (`docs/schedule_detail.toml`), regenerated and republished.

## 10. Review before the merge

The user: "Before we apply anything, please review what you designed for anything that might
have been overlooked." Measured on both terrain files (the compass build's `6bedde1c663e`
against `f569ade0c331`), one-off scripts, not committed:

- **Walkable slopes** (triangles at 55 degrees or less reachable from the town): about 2% more
  of them between 10 and 30 degrees; 40 degrees or more, 8 before and 5 now, all on the
  plateau ramps' sides; the old 48.7 degree bank at the pass's north mouth is gone. The walked
  area is the same to a few triangles.
- **Faces beside walkable ground**: 2,099 before, 2,105 now. The six new ones are on the
  plateau ramps' sides; none elsewhere, so no new perch.
- **Falls**: no crest is a fall (the floor snap allows 0.5 m plus the slope).
- **The plateau**: its west cliff is 58 to 60 m (50 to 54 before), still lethal. The ramps'
  side walls are about 5 m taller: at the very bottom of a ramp the side drop is 8.6 m (2.8),
  about 16% of max HP.
- **Camps**: the ground within 25 m of a camp now varies 0.5 to 9.4 m (0.3 to 8.5).
- **Set pieces** stand at one anchor point (`ZoneDressing.stand`), so on a slope a big piece
  floats or sinks at a corner: the Wraith Gate arch's stone base -1.0 to +0.7 m. Left as it
  is (placeholders); lowering that base a metre is a one-line client change if wanted.
- **Landmarks**: the Ossuary spire and the Wraith Gate arch are seen from the town square and
  24 road corners on both grounds. Points at standing height lost some views (the plateau lip
  24 of 25 to 19; the ridge's crest 21 and 23 to 17 and 16).
- **Spell sight** (both ends 1.2 m up, outside the town): blocked at 20 m 0.4% (0.4%), at
  30 m 1.4% (1.2%), at 40 m 2.4% (2.2%).
- **Fine as they were**: the camera's spring arm hits the ground (layer 1); flight's ceiling
  and the fling are measured from the ground; the mountains rise from the ground beside them.

## 11. Merged and exported for the door

The user: "they will go into the door zip." The server deploy branch fast-forwarded to
`a3b226d` and pushed. The client: the deploy branch's records (`d31527f`) merged into
`feat/rolling-hills` (`397e207`), then the deploy branch fast-forwarded to it; both pushed.
In the main checkout a reimport and all 17 checks against the merged server.

The export: the first one, from the main checkout, was stamped `397e207 DIRTY TREE`, because
another session's uncommitted doc edits sat in that checkout (no game file). It was replaced by
an export from the hills worktree, clean at the same commit: `[BuildStamp] stamped 397e207`,
`--export-release`, booting clean headless (300 frames, exit 0), the hand-copied
`gdext_net.dll` identical to the one in `addons/` (no wire change). The zip
`builds/ProjectDawn-alpha-397e207.zip` (37,826,027 bytes), with the same tester README and
checklist as before; it replaces `fd17ff1`.

The redeploy, by the user: the host commands in CLAUDE.md, no SQL; the boot line must read
`build="a3b226d" dev_cmds=false terrain=400x400 cells of 10 m, floor 0, hash f569ade0c331`.
`zone_4km_checklist.md` (its header, the pass row now "rises and falls with the ground",
sections 7 and 8) and `pre_door_check_checklist.md` §9 name the new pair.
