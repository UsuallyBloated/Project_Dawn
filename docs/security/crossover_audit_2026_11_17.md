# Cross-over audit, 2026-11-17: findings

The read laid out in `crossover_audit_plan_2026_11_17.md`, run the evening of 2026-11-17 against
the pair the R720 runs (server `87c58fe`, client `a1a154e`) plus the flight client
(`feat/gm-flight` at `231a8ac`). Every claim below was read by hand in the source; two
read-only agents gathered leads for seams E to H and each lead they raised was re-read
before it was recorded.

Status words: **FIXED** (built, tested), **OPEN** (a change is wanted, not built), **NOTED**
(recorded, no action planned), **CLEAN** (the seam was read and the two rules agree).

**The short version:** no code trip was found. Ten pieces of work from parallel sessions meet
in about a dozen server files, and at every seam read the later session had accounted for the
earlier one's rule. What the audit did find is on the records side: the architecture
overview still teaches the compass the wrong way round and describes a world that no longer
exists, and three smaller doc gaps. Those are §3.

## 1. Code seams, read and clean

| Seam | What was asked | What the code says | Status |
|---|---|---|---|
| A. Tick order | Does the roster re-send (step 432) see every level move of the tick? | Every XP award runs earlier: kills in melee (372) and casting (374), DoT kills and the AI's hits in `enemy_ai` (408), quest turn-ins (416), the res refund (414), the death sweep's de-level (430). Steps after 432 (regen, the position fan, upkeep) award none. | CLEAN |
| A. Tick order | Is a wanderer placed this tick stepped this tick? | Spawning (368) runs before the AI (408) and movement (424); a fresh wanderer stands one tick, then walks. | CLEAN |
| B. Ground | Is `obstacles.bin` baked against the ground the server runs? | `check_obstacle_lockstep.gd` rebakes from `world.tscn` and compares bytes (its SCENERY row), so a terrain edit without `export_obstacles.gd` fails `check_all.ps1`. | CLEAN |
| B. Ground | Can a wanderer appear inside scenery, or in a sealed pocket? | `roam_map.rs:144`: a roam spot is one where `obstacles.stands(p, BODY_RADIUS)`, the same test `place` uses; `pick_spot` and `pick_near` take only such spots (`roam.rs:247`). | CLEAN |
| B. Ground | Does an obstacle end a roam leg or feed the stuck clock? | `roam_step` (`entity.rs:1754`): a step held under `DETOUR_BELOW` of its way ends the leg at once; no clock runs on a roam step ("a wanderer on its legs can be hit" is asserted at `entity.rs:3289`). | CLEAN |
| B. Ground | Are the roam regions in world coordinates after the mirror? | The table was written 2026-11-16, after the mirror; the slot test `the_zone_fills_its_roam_slots_and_roaming_off_spawns_only_camps` runs on the compiled ground. | CLEAN |
| C. Mob machine | Does a wanderer far from its spawn leash the moment it fights? | The leash test is mob-to-target (`tick_chase`, `entity.rs:1443`), and `roam_fight_began` moves home to where it stood when the fight began (`enemy_ai.rs:340-342`, after `tick_ai`, on the Idle to Chase edge only). | CLEAN |
| C. Mob machine | Can a mob be handed a GM in the air as its next target? | Fliers are out of `targets` (`enemy_ai.rs:50`), so `best_hater_within_leash` skips them; a takeoff wipes the flier from every hate list (`spawning.rs:205`); a pet's hit puts no owner token for a flier (`enemy_ai.rs:65, 679`). | CLEAN |
| C. Mob machine | Is a pack follower immune when its leader is held at a wall? | `is_evading` reads the mob's own stuck clock (`entity.rs:695`); a follower that is not held is not evading. A follower that cannot reach its leader walks its own legs for `PACK_SOLO_SECS` (`entity.rs:1691`). | CLEAN |
| C. Mob machine | Is a night animal removed mid-fight at dawn? | Only idle, unhurt, unowned and unseen (`spawning.rs:93-102`); "seen" is the AOI's own visibility. | CLEAN |
| D. Pets | Does the charm ledger pay a kill twice? | `charm_mob` moves the mob's damage map onto the pet (`pet_life.rs:156`); `released_from_charm` moves it back (`entity.rs:499`), the same map, not a sum. | CLEAN |
| D. Pets | Is a ported or dead player wiped from a charmed pet's ledger? | `wipe_hate` removes the id from `aggro`, `charm_ledger` and `threat` (`kills.rs:539-543`). | CLEAN |
| D. Pets | Can a dismissed warder arm the respawn timer and churn? | `release_owned_pets` marks a summoned pet Dead and fans the death (`pet_life.rs:222-225`); `warder_respawn_at` is set only on a death by damage (`enemy_ai.rs:555, 763`, `kills.rs:285`, `melee.rs:1271`), never by the dismissal or the corpse sweep; no class has a second warder summon (`spells.toml` has no `pet_type = "warder"`). | CLEAN |
| D. Pets | Does the dead-pet guard hold on every path a charm ends? | The expiry sweep (`spawning.rs:351`), `release_owned_pets` (`pet_life.rs:205`) and `despawn_owned_pets` (`pet_life.rs:272`) each hand back living pets only. | CLEAN |
| E. Wire | Do the two bumps' DLL edits agree? | `check_wire_layer.gd` checks `group_roster`'s seven arguments; the zip's DLL hash is the group-levels build's. | CLEAN |
| E. Flight + movement | Does a flier go through walls on both sides? | The server's flight branch runs before the obstacle step (`movement.rs:136`); the client's `_fly_tick` returns before `player.gd`'s obstacle step. Every server move ends flight through one `teleport_to` / `end_flight` (`connection.rs:1099-1118`); a port places the destination first (`casting.rs:1763`). | CLEAN |
| E. Flight + fighting | Is the flying gate complete? | `handlers.rs:689-709`: Attack dropped, CastStart and CastSpell refused with the true mana, UseSkill refused, `/pet attack` refused; the takeoff stands pets down and stops a song (`spawning.rs:217-226`). | CLEAN |
| F. Wanderer tables | Does every species have a loot rule, a faction and a quest match that is intended? | All 17 slots carry `faction` and `alignment`; every animal matches its table and is a beast (no coin); only the four wolves tick a quest (`Wolf`); the two shades are undead with coin and no animal table, as the file's comment says; both passive species sit at the 35 m floor the loader enforces (`roam.rs:157`). Tests `every_roam_and_camp_name_resolves_to_its_species` and `wolves_count_for_the_wolf_quests_and_nothing_else_ticks_a_quest` hold it. Client and server quest targets match one for one. | CLEAN |
| G. Client | Does any command swallow another? | No `begins_with` without a trailing space except `/loot`; `/con`, `/factions`, `/loc` and `/fly` are exact or space-terminated; the sticky channel parser matches whole words. | CLEAN |
| G. Client | Are the lockstep pairs complete? | Night hours (2), obstacles (13, the design's count), flight (5, on the flight branch), `BODY_RADIUS`. | CLEAN |
| G. Client | Does every invariant holder exist? | `check_invariants.gd` resolves all 71 holder names for A5 to L3 against `tools/` and the server's `fn`s. | CLEAN |

## 2. Noted, no action

| Id | Note |
|---|---|
| N1 | The flight clamp is the plate's rim (`clamp_to_plate`), not the mountains' edge, so a GM can fly past the walkable world and `fly off` onto a 440 m peak. A GM tool; the fall is harmless by design. |
| N2 | A wanderer walking home (a leash, or a charm ending with its charmer gone) walks by `step_on` straight at its home, not by the roam map, so the walk may cross the town's 150 m clearance. In Leash it attacks nothing and takes nothing, heals at home and is idle there; C1 covers where a wanderer appears and where a leg ends, not a walk home. |
| N3 | The client's `cast_spell` has no evade check (the server's "Your target is evading." arrives a round trip late), checks PvP before reach where the server checks reach first, and uses two lines the server words differently ("Your target is too far away." against "That target is too far away or no longer here."; "No valid target." against "You need a target for that spell."). The server decides; a mismatch costs a round trip, never an outcome. |
| N4 | The client holds no protocol id: the DLL takes it from the server's connect token (`gdext-net/src/lib.rs:578`), so there is nothing to pair in `check_constant_lockstep.gd`, and L1's "wire layer" holder is `check_wire_layer.gd`'s names and arities alone. A DLL built from an older protocol crate fails at the bincode shape, which that check catches only where an arity changed. |
| N5 | The server-only knobs (`MOB_STUCK_SECS`, `EVADE_*`, `DETOUR_*`, `STUCK_*`) have no client twin and need none; the client draws what the server says. |
| N6 | `hud.gd`'s `begins_with("/loot")` also takes `/lootx`; nothing collides with it. |

## 3. Records: the trips the audit did find

| Id | Finding | Status |
|---|---|---|
| H1 | `docs/concepts/architecture/systems_overview.md:833` says "**+Z is north, +X is east**" and that `/loc` prints `x, y, z`. Rule L3 and `hud.gd` say north is -Z and `/loc` prints north, west, height (the compass mirror of 2026-11-14). The overview also has no paragraph for the 4 km zone, the outline, the rolling hills, wandering wildlife, obstacle collision or group levels (zero hits for wander, roam, obstacle, prism, rolling, 4 km); its hills paragraph (718-753) still describes a 40 by 40 plate with a rim. Its last commit is 2026-11-09. The To-Do's rule is that "what exists" moves with the tick, but a reader today is taught the wrong compass. | OPEN: correct the compass line now (a doc edit, no playtest surface); the paragraphs land with their ticks. |
| H2 | `docs/deployment/server_operations.md:104-106`: the sample boot line reads `min_client=0.1.0 dev_cmds=false` and shows none of `terrain=`, `obstacles=`, `roamers=`, which the real line prints (`main.rs:50-53`) and which the runbook tells the operator to confirm. The one-time compass SQL of 2026-11-15 is not recorded as done. | OPEN: one sample line and one sentence. |
| H3 | `docs/reference/commands.md:176`: the Test Panel's button list is the old one (Full Heal, Level Up, give-coins); Fling, Despawn All Enemies, Obstacle Outlines and (on the flight branch) Fly and Land are missing. `/fly` is on the flight branch's copy only, as it should be. | OPEN: one list. |
| H4 | `tools/author_terrain.gd`'s report does not say to run `export_obstacles.gd` after a re-author, though every scenery or terrain edit needs it (the obstacle session's own note); `check_all.ps1` catches the omission, after the fact. | OPEN: one line in the tool's report. |
| H5 | `feat/public-hosting` (server) is 19 commits behind the deploy branch and 17 ahead; its `intent_class` match is exhaustive, so the merge-forward is where the post-bump intents meet the budgets. The branch's convention is to merge the deploy tip in; nothing has since 2026-11-10. | OPEN: the merge-forward, before cutover work resumes. |
| H6 | Fourteen client worktrees exist; eleven sit at tips already merged (`bump`, `height`, `hills`, `hunger`, `jump`, `levels`, `obstacles`, `speed`, `trade`, `wildlife`, the agent worktree). Five checkouts carry an untracked `.uid` stray. | OPEN: prune and commit or drop the strays; keep `-zone` (flight) and `-hosting`. |
| H7 | The planner page has not been republished since the obstacle records (`45d19db`). | OPEN. |

## 4. Runs

| Run | Result |
|---|---|
| The whole server suite ten times in a row on `87c58fe` | Eight runs fully green (481 unit, 201 world each). Run 4: `flight::a_fling_or_a_death_ends_flight` failed at `flight.rs:387`; run 6: `flight::a_flier_is_held_above_the_ground_on_the_plate_and_under_the_ceiling` at `flight.rs:208` and `roam::a_wanderer_walks_its_region_on_its_own` at `roam.rs:154`. Read against the source: both flight assertions want the server's "You take to the air" line inside `gm_line`'s fixed 400 ms `collect_for`, the shape of the ledger sleep that misfired under load on 11-10 (`cef31f0`); the roam test's 30 m region makes a 20 to 80 m leg draw (`pick_leg`, eight tries) fail often, and a failed draw costs the rat a 5 to 25 s pause against the test's 12 s window. Neither is a server fault on the read; the isolation runs (the row below) decide. |
| The three failing tests alone, five times | The two flight tests passed five of five alone: load sensitivity, the test's fixed window. The roam test failed once in five alone ("got 0.0 m"): the rat stood its whole watch, so the construction cause is real (a 30 m test region against 20 to 80 m legs), not load. The real regions are 400 to 2,000 m across (`zone_roam.toml`), so play never sees it. **FIXED, test code only** (server deploy branch, the commit after `87c58fe`): `gm_line_says` polls up to 3 s for the server's line, the ledger fix's shape; the roam test's region is 60 m and its watch ends the moment the rat has walked 5 m (40 s at most). The four touched tests five of five, then the world suite 201 of 201, fmt clean. Nothing to redeploy: tests do not ship. |
| A fuzz hour on `87c58fe` | not run (WSL, an hour; the user's call). |
| The real binary with roamers on, one GM flying over the camps for an hour | not run (needs a seat; the user's call). |

## 4b. The records fixed the same night

H1 (the overview's compass line, now north = -Z and `/loc` the EQ way, pointing at L3), H2
(the runbook's sample boot line with `build=`, `roamers=`, `terrain=`, `obstacles=`, three
table rows for what each must read, and the compass SQL recorded as a one-time step already
run), H3 (the Test Panel list in `commands.md`), H4 (`author_terrain.gd` prints the two
exports to run after a clean write) were edited the same night; the overview's missing
paragraphs still land with their ticks. H5 to H7 stay OPEN.

## 5. What this audit did not do

No refactor, no knob moved, no tick. The client's cosmetic order differences (N3) are left as
they are. The two playtest sheets that exercise these seams in play, `wandering_wildlife_checklist.md`
and `obstacle_collision_checklist.md`, remain the evidence for what the code reads cannot show.
