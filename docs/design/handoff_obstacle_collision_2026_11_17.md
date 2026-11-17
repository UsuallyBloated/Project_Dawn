# Handoff: obstacle collision, merged and exported, records and redeploy left

**Written 2026-11-17 by the session that built it, which ran out of budget mid-records.**
Read this, then `docs/design/obstacle_collision.md` (the design as built) and
`docs/session_notes/session_2026_11_17_obstacle_collision.md`.

## 1. Where things stand (all verified before this was written)

| Thing | State |
|---|---|
| Server deploy branch `fix/xp-leveling-overflow` | **Pushed at `87c58fe`** (obstacles merged, a fast-forward from `7e0095f`). |
| Client deploy branch `fix/xp-leveling-overflow` | **Pushed at `a1a154e`** (obstacles merged from `063f3f5`, then the tester README and checklist). This handoff and the records are one commit after it. |
| `feat/obstacles` in both repos | Pushed. Worktrees `F:\Projects\Project_Dawn-obstacles` and `F:\Projects\server-obstacles` still exist; nothing unmerged lives there. |
| Checks on the merged main checkouts | `tools/check_all.ps1`: 19 of 19. Server suite on the same commit: 481 unit, 201 world, clippy and fmt clean. |
| The export | `builds/ProjectDawn-alpha-a1a154e.zip` (39,425,944 bytes: exe, console exe, DLL, tester README, tester checklist). `[BuildStamp] stamped a1a154e`, a release export, clean stamp. The exported build boots headless (300 frames, exit 0) and passes `tools/probe_obstacle_walk.gd` from inside the export, so the obstacle data is in the pack. DLL md5 `097ace2a...` (the group-levels DLL, PD_W0031; no wire change in this work). |
| The R720 | **NOT redeployed.** It is on whatever the user last deployed (`f388b96` unless the group-levels redeploy was done). |
| Playtest | Not run. `docs/playtest_notes/obstacle_collision_checklist.md`. |

**The user said "lets go for it" to the merge.** The merge, push and export are done on that
word. Nothing else outward-facing was done.

## 2. What the user has to do (tell them; nobody else can)

Redeploy the R720, and send the new zip. **Both together**: this zip against the old server
pulls a body through every tree, and the old zip against the new server pulls it back at
every tree. The zip also carries group levels (PD_W0031), so it needs a server at `7e0095f`
or later anyway.

```
sudo -u projectdawn -H bash
cd /opt/projectdawn/src && git pull && cargo build --release
exit
sudo systemctl stop projectdawn
sudo -u projectdawn cp /opt/projectdawn/src/target/release/projectdawn-server /opt/projectdawn/projectdawn-server
sudo systemctl start projectdawn
journalctl -u projectdawn -n 30 --no-pager
```

No migration, no SQL. The boot line must read `build="87c58fe" dev_cmds=false roamers=on`,
`terrain=400x400 cells of 10 m, floor 0, hash f569ade0c331`, and
`obstacles=33199 prisms (19580 walk, 31012 sight), hash f97d25964ce4`. Then a line
`what stands on the ground` with the same hash. A client's `debug.log` prints
`ZoneObstacles: 33199 prisms, hash f97d25964ce4` on entering the world.

The zip to send is `builds/ProjectDawn-alpha-a1a154e.zip`; it replaces `54ca951` and
`397e207`.

## 3. What is left for the next session, in order

1. **Records not yet updated for the merge** (they still say "not pushed, not merged"):
   - `CLAUDE.md`, the To-Do entry "Obstacle collision: trees, rocks, walls and set pieces
     that stop a body": say MERGED AND PUSHED 2026-11-17 (server `87c58fe`, client `a1a154e`),
     EXPORTED (`ProjectDawn-alpha-a1a154e.zip`), pending the redeploy and the playtest; drop
     "the `(on feat/obstacles)` tags come off" (done, client `00f5c5d`); note the tester
     README and checklist now say scenery is solid.
   - `docs/design/obstacle_collision.md`: the Status line and section 11 (items 1 and 2 are
     done).
   - `docs/session_notes/session_2026_11_17_obstacle_collision.md`: sections 5 and 6 and the
     Outcome line; `docs/session_notes/README.md`'s row.
   - `docs/playtest_notes/obstacle_collision_checklist.md`: the prerequisite paragraph names
     the branches as unmerged; name the zip and the boot line instead.
2. **The planner.** Add rows to `docs/schedule_detail.toml` (the redeploy with the new zip;
   the `obstacle_collision_checklist.md` sitting; the zip for the door is now `a1a154e`), run
   `python tools/schedule_detail.py`, commit the plan file with both outputs, and republish
   the page at the link recorded in the plan file (read the artifact first; a publish to one
   this conversation has not read is refused).
3. **Memory** (`C:\Users\tyler\.claude\projects\f--Projects-Project-Dawn\memory\`):
   `project_obstacle_collision.md` says unmerged; `project_monday_zip_nov_16.md` and
   `MEMORY.md` name `397e207` as the zip to send. Both are stale now.
4. **After the user's redeploy:** record the boot line in the To-Do entry and the session
   note, as every deploy has been.
5. **After the playtest:** triage the checklist against the journal. Nothing ticks before
   that.

## 4. Traps

- **Any scenery or terrain change now needs `tools/export_obstacles.gd`** (always pass the
  server's `obstacles.bin` path) and both `.bin` files committed, or
  `check_obstacle_lockstep.gd` fails. This includes `author_terrain.gd` runs: a prism's WALK
  and SIGHT flags depend on the ground under it.
- **The rule exists twice** (`world/obstacles.rs`, `scripts/zone/zone_obstacles.gd`). Change
  both, run the server tests once with `PD_WRITE_FIXTURES=1`, commit
  `data/obstacle_rule_fixtures.txt`; `check_obstacle_rule.gd` replays it on the client.
- **GM flight** (client, `feat/gm-flight`, `Project_Dawn-zone`) is not merged. When it is,
  the flying body in `player.gd` must skip the obstacle step (the block after the blend
  toward the server): the server's flight ignores obstacles, so a flying client that
  resolved them would be pulled back at every tree it flew through.
- `tools/probe_group_levels.gd.uid` is untracked in the main checkout. It belongs to the
  group-levels session's probe and was left alone.
- One full server run during the build had
  `roam::a_wanderer_goes_home_to_where_its_fight_began` fail while another build was
  compiling beside it. It passed alone three times and in three later full runs. Its 40 s
  deadline is close to the slowest honest case (a 25 s pause, then 15 m at 1.2 m/s). Not
  this work's, but worth a look if it shows again.

## 5. What to watch in the first sitting

The things most likely to come back from play, from the builder's own doubts:

- A body run square into a trunk's flat face stops dead (the trunks have five or six flat
  faces). If it feels bad, the lever is the bake: give trunks more sides or round them.
- Bushes, bones and small rocks block as walls do, at the user's call. If the wood feels
  like an obstacle course, the levers are `WALK_MIN_HEIGHT` (0.3 m) in
  `zone_obstacle_bake.gd` and which flora kinds get a foot prism.
- Crowns block casts from high ground. Lever: the crown group in `flora_groups`, or its
  sight scale.
- Mobs among their own camp's tents and walls: they walk round, but a camp where they hang
  is a scenery fix (move the piece) or a `DETOUR_*` knob in `world/mod.rs`.
- `world health` tick times in the journal: the rule allocates on every lookup (the
  review's one unfixed finding).
