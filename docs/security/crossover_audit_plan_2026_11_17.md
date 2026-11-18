# Cross-over audit plan, 2026-11-17

Since the November bump (2026-11-05, server `267065f`, client `da83ea8`) ten pieces of work
landed on the deploy branches, several of them built by sessions running at the same time in
their own worktrees: the starting kit, the ammo slot, the 4 km zone, its outline, the compass
mirror, GM flight (server half), the rolling hills, wandering wildlife, group levels and
obstacle collision. Every merge was a fast-forward after the branch had taken the deploy tip,
so git reported no conflicts, and both suites and all 19 client checks are green on the pair
the R720 runs (`87c58fe` / `a1a154e`).

That proves the pieces compile and pass their own tests together. It does not prove that
rules written by different sessions agree where they meet. This plan is the read that proves
it, or finds where they do not. Nothing in it is a feature; nothing it finds is ticked.

Status words, as in `housekeeping_audit_2026_10_23.md`: **FIXED**, **OPEN**, **NOTED**.

## 1. What the git history says overlapped

Each feature's segment of the deploy branch was diffed on its own; a file below was changed
by two or more of them. Docs and records are left out.

**Server, four or more segments:**

| File | Changed by |
|---|---|
| `world/terrain.rs` | zone, outline, compass, flight, hills, wildlife, obstacles |
| `data/terrain.toml` | knoll, zone, outline, compass, hills |
| `tests/world/common/mod.rs` (the harness) | ammo, zone, compass, wildlife, obstacles |
| `world/mod.rs` (the knobs) | kit batch, flight, wildlife, obstacles |
| `world/tick/spawning.rs` | kit batch (the charm faucet), flight, wildlife, obstacles |

**Server, three segments:** `world/entity.rs` (flight, wildlife, obstacles), `tick/casting.rs`
(flight, wildlife, obstacles), `tick/enemy_ai.rs` (hate token, flight, wildlife), `tick/mod.rs`
(wildlife, group levels, obstacles), `tick/pet_life.rs` (hate token, wildlife, obstacles),
`tick/state.rs` (flight, wildlife, obstacles), `tests/world/main.rs`.

**Server, two segments worth a look:** `connection.rs` and `handlers.rs` (flight, group
levels), `tick/movement.rs` (flight, obstacles), `tick/binds_and_res.rs` and `tick/intake.rs`
(flight, obstacles), `tick/kills.rs` (flight, wildlife), `tick/session.rs` (group levels,
obstacles), `tick/melee.rs` (hate token, ammo), `config.rs` and `main.rs` (wildlife,
obstacles), `roam.rs`, `roam_map.rs`, `spawn_points.rs` (wildlife, obstacles), `gdext-net`
and `protocol/world.rs` (ammo PD_W0030, group levels PD_W0031).

**Client, four or more segments:** `scenes/world.tscn`, `data/terrain_features.toml`,
`tools/author_terrain.gd` (every terrain pass), `scripts/zone/zone_flora.gd`,
`zone_landmarks.gd`, `tools/check_zone_scenery.gd` (zone, outline, compass, obstacles).

**Client, three segments:** `scripts/player.gd` (login facing, obstacles, flight),
`autoloads/spells.gd` (ammo, obstacle sight, flight), `scripts/hud.gd` (kit batch, `/loc`,
`/fly`), `autoloads/combat.gd` (swing re-time, ammo, flight), `zone_dressing.gd` and
`zone_town.gd` (zone, compass, obstacles), `tools/check_constant_lockstep.gd` (wildlife,
obstacles, flight), `data/zone_layout.gd` (zone, outline, compass).

The flight client (`feat/gm-flight`) took the deploy tip on 2026-11-17 (`231a8ac`) with three
hand-resolved conflicts (`player.gd`, `test_panel.gd`, the session index); it is counted above
as if merged, since it will be at the bump after the door.

## 2. Method

1. **Read the seam, not the file.** For each item in §3, read the merged code at the point
   where the two rules meet and write down what each session assumed about the other. A
   claim about a trip is re-read by hand in the source before it is recorded (the 10-23
   rule); a reviewer agent's read is a lead, never a finding.
2. **Every finding gets a test or a row.** A real trip is fixed with a test that fails on
   the merged code as it stands; a cosmetic or unlikely one gets a row in the matching
   checklist, or a NOTED line here.
3. **Exploit lens on every seam.** The question asked each time: can a client make the two
   rules disagree on purpose, and what does it get (a free kill, an immune mob, a loot drop
   with no consequence, a position the server would not grant)?
4. **No refactors, no knob changes, no ticks.** The fixes are seams, not systems. Anything
   larger is filed as its own To-Do entry.

## 3. The seams, worst first

### A. The tick order (`tick/mod.rs`)

Three sessions inserted steps: wildlife's clock-driven spawning (inside `run_spawning`, step
3), group levels' `refan_rosters_on_level_change` (after the death sweep, step 23), and the
obstacle placements (inside spawning, the res summon, ports). Read `run` top to bottom once,
and for each inserted step list what it assumes already ran this tick and what it must run
before. Known facts to confirm: the roster re-send sees a death's de-level because the death
sweep is one step earlier; the spawn step runs BEFORE movement and enemy AI, so a wanderer
placed this tick is not stepped until the next; `award_xp` has no caller after step 23
(upkeep, regen and the position fan award none). A later step that awards XP would be one
tick late, not wrong.

### B. Three readers of the ground: terrain, obstacles, the roam map

`terrain.rs` was touched by seven segments and carries the ground sampler, the slope and
sight rules, the plate clamp (flight) and now `obstacles()`. The roam map (`roam_map.rs`) is
built from the ground alone (floors reachable both ways) and the obstacle file is baked from
the scenery standing on that ground. Questions:

- Is `obstacles.bin` baked against the ground the server runs? `check_obstacle_lockstep.gd`
  rebakes from `world.tscn` and compares bytes (confirmed: its SCENERY row), so a terrain
  edit without `export_obstacles.gd` fails the check. Confirm the check is in the export path
  a session would actually run (`check_all.ps1`, yes) and that `author_terrain.gd`'s own
  report says to run the exporter after it (it may not).
- A roam leg whose end point lies inside a prism: `entity.rs` 1761 resolves the step through
  the obstacles with a detour rule (`DETOUR_BELOW`). Read what ends the leg: a refused slope
  step ends it at once (the wildlife design); does an obstacle deflection, or does the
  wanderer slide along a wall for the leg's length? Harmless if so, but a wanderer that
  spends its legs against the same wall stops wandering.
- Night spawns and the roam map at the Ossuary and the barrow: the camps now sit as high as
  148 m (hills); the roam regions carry a z band and a ring, written AFTER the compass
  mirror, so they are in world coordinates. Confirm by reading one ring against the mirrored
  camp positions in `zone_camps.toml`.
- The flight clamp (`clamp_to_plate`) and the zone's edge: the edge is mountains, not the
  plate's rim, so a flier can cross the mountains and land outside the walkable world; by
  design (a GM), but a `fly off` there puts the GM on a 440 m peak. NOTED unless the user
  wants the clamp at the edge.

### C. The mob state machine, four authors

`entity.rs`, `enemy_ai.rs`, `spawning.rs` and `pet_life.rs` now carry: the hills' stuck clock
and evade (`is_evading`, `MOB_STUCK_SECS`, the grace), the hate list's next-hater rule, the
owner's hate token, wildlife's roam legs and pack following (home is where the fight began),
the flier exclusion from the target list, and the obstacles' wall-follow (only a step that
makes no progress feeds the stuck clock; a second of clean steps clears it). Write the merged
Idle, Chase, Leash and Dead transitions down in one place, then ask of each pair:

- A pack follower whose leader is held at a wall and evading: does it keep following into
  the wall, and is it also immune (it is not held, so it should not be)?
- A roamer that acquired a target while roaming, lost it over a face, and walked "home":
  home is where the fight began (wildlife) but the leash check in Chase uses `leash_range`
  from that home; confirm the roam home reset in `tick_idle`'s acquire path runs before the
  first leash test, or a roamer far from its spawn leashes at once.
- A mob whose only hater is a flier (the token or a swing before takeoff): fliers are out of
  the target list, so `next_hater_or_home` should skip them, or the mob stands waiting under
  a GM in the air forever. Read `next_hater_or_home`'s filter.
- A wanderer at night removed by day "if idle, unhurt and unseen": is a wanderer with a hate
  list (seen) ever removed mid-fight? The rule says idle and unhurt, so no; confirm "unseen"
  reads the same visibility the position fan uses.
- The stuck clock on a wanderer with no target: roam steps must not feed it (a wanderer is
  never evading, the design says); confirm `tick_roam` does not call the progress clock.

### D. Pets, three authors

`pet_life.rs`: `release_owned_pets` (one pet at a time), the charm ledger riding the charm, the
dead-pet hand-back (the Sable faucet), the pet warp to an owner it cannot reach (hills), a pet
summoned on its owner's side of a wall (obstacles), pets stood down at a GM's takeoff
(flight), the owner's hate token (`melee.rs`). Walk the lifecycle summon, fight, warp,
charm-release, death, owner-leaves, owner-flies, and for each check the three maps a pet
appears in (the pet's threat map, the victim's threat and damage maps, the ledger) are left
consistent. The question with teeth: a charmed pet released hostile by `release_owned_pets`
with the charm ledger handed back, then killed by the same caster: does the ledger credit the
caster twice (once from before the charm, once after)? Read `released_from_charm` and
`wipe_hate`.

### E. The wire and the branches behind

Two protocol ids in one fortnight (PD_W0030 ammo, PD_W0031 group levels) and the DLL edited
by both. `check_wire_layer.gd` passes and the zip's DLL hash matches the group-levels build.
Confirm `scripts/net/protocol.gd`'s id matches `protocol/src/world.rs` by a check, not by eye
(if no check holds the id, add the pair to `check_constant_lockstep.gd`). Then the branches
behind the line: `feat/public-hosting` is 19 commits behind the server deploy branch and 17
ahead; its `intent_class` match is exhaustive, so it needs the merge-forward (the branch's
convention) before cutover work resumes, and the merge is where `Consider`, `UseSkill` and the
flight `GmCommand` meet the intent budgets. `feat/gm-flight` (client) is current as of
`231a8ac`. Every other worktree in `git worktree list` (12 on the client side) is at a merged
tip and can be pruned, which is in §4.

### F. The wanderers' tables

Every roam slot carries `faction` and `alignment` (confirmed, 17 slots). Still to read: each
species against `loot.rs`'s name rules (adder and viper were added; a species whose name
matches nothing rolls humanoid coin); each against the quest substring rules on both sides
(`"Plague Rat"` changed, Rattlesnake became Prairie Adder; a wandering Wolf counts for the wolf
quests by decision); each against `named_mobs.toml` (no wanderer is named); and the con line
for a level 1 Field Rat. A species that pays no faction hit is a consequence-free farm.

### G. The client's seams

- `player.gd`: the login facing seed (first Position only), the obstacle step (after the
  blend), flight (returns before both). Confirm the facing seed still runs when the first
  Position arrives while flying is impossible (it is: flight needs the first Position).
- `spells.gd`: three refusals before a cast, the terrain sight (hills), the obstacle sight,
  the flying refusal, and the ammo-slot refusal in `combat.gd`: their order against the
  server's pre-flight order, so an honest client's line matches the server's line (the server
  decides; a mismatch costs a round trip and a confusing message, not an exploit).
- `check_constant_lockstep.gd`: the night hours, `BODY_RADIUS` and the flight pairs are
  present; count the obstacle pairs against the design's thirteen and the flight pairs
  against its five.
- `hud.gd`: `/loc`, `/fly`, `/factions`, `/con` and the sticky channel parser: a command
  added by one session must not be swallowed by another's `begins_with`.
- The Test Panel: Fling, Fly, Land and Obstacle Outlines all in `_sec_resources`; every
  server-routed button still names a GM gate on the server (`D1`).

### H. Records, tools and hygiene

- `systems_overview.md`: the "what exists" paragraphs for the 4 km zone, the outline, the
  compass, the hills, wildlife, obstacles and group levels (none written; the To-Do says they
  move with the tick, but a reader today finds the flat world described).
- `docs/reference/commands.md`: `author_terrain.gd`, `export_obstacles.gd`, `/fly`, `/loc raw`,
  `PD_NO_ROAMERS`, the Test Panel's new buttons.
- `docs/deployment/server_operations.md`: the boot line's new fields (`terrain=`,
  `obstacles=`, `roamers=`), the `PD_NO_ROAMERS=1` switch, the compass SQL as a one-time step
  already run.
- `docs/reference/invariants.md`: every rule from A5 to L3 names a holder (confirmed); check
  `check_invariants.gd` lists each named test so a deleted test fails it.
- The planner page: regenerate `schedule_detail` and republish (outstanding since `45d19db`).
- Worktrees: prune the eleven at merged tips; keep `Project_Dawn-zone` (flight) and
  `Project_Dawn-hosting` / the hosting server worktree. Commit or drop the `.uid` strays.

### I. Running the merged whole

The harness runs every test with an empty obstacle set and roaming off except in their own
files, so no automated test has ever had wanderers walk the real hills among the real
scenery. Three runs, overnight:

1. The real binary with `PD_NO_ROAMERS` unset for an hour on the dev box with one GM client
   flying over the camps, the `world health` line read for `over_budget` and
   `slope_refusals`, and a log scan for any wanderer stuck (a mob that logs the give-up
   repeatedly in one place) or a pack that never regathers.
2. A fuzz hour on `87c58fe` (the last was on the split branch, before any of this).
3. The suite ten times in a row (the flaky rule: any failure is real).

## 4. Deliverable and cost

A findings doc beside this one (`crossover_audit_2026_11_17.md`), one row per seam with its
status and, for a FIXED row, the test's name; server fixes on the deploy branch with a
redeploy; client fixes held for the bump after the door unless one would trip the friends on
Thursday. The read (§3 A to G) is about a day; H is an hour of writing and a prune; I is a
night. Nothing is ticked by this audit; the sheets stay the evidence.

## 5. Timing

The door is Thursday 2026-11-19. Recommended: the read starts now and runs read-only; a
server-side trip found before Thursday is fixed and redeployed only if it would show in play
(a stuck wanderer, a mob immune where it should not be, a pet credit paid twice); anything
client-side waits for the bump after the door, since the zip `a1a154e` is already in the
friends' hands. The records (§H) can land any time without a redeploy.
