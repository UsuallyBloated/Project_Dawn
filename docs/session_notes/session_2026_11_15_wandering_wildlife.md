# Session 2026-11-15: wandering wildlife, the plan

## 1. What was asked

The user: "We need wandering NPCs to fill the open spaces. Wolves, bears, snakes, rats etc.
Please build a plan."

## 2. What was done

A design, nothing built: `docs/design/wandering_wildlife.md`, eight decisions waiting on the
user (its section 9). A To-Do entry under World systems.

Read in the server before writing it: `zone_camps.toml` (54 spawns, the five rings and their
levels), `spawn_points.rs` (one point per authored spot), `entity.rs` (the Idle scan never
moves a mob; the leash is measured from the mob to its target; `Leash` is evading; the stuck
clock; `leash_range` gives a mob with `aggro = 0` a leash of 0 unless one is written),
`loot.rs` (Snake and Bear tables already there, every item on the client; `is_beast` gives
animals no coin), `quests.toml` (kill objectives match by substring), `safe_areas.toml`,
`terrain_content.rs` (the walkable flood fill, `#[cfg(test)]` only), `clock.rs`. Client:
`remote_enemy.gd` renders any name as the shared capsule, so a moving mob needs no client code;
`zone_layout.gd`'s basins to place the regions.

## 3. The shape, briefly

A `[[roam]]` table in `zone_camps.toml`; the walkable map computed at boot; spawn spots clear of
the town, the camps and every player; roaming inside `Idle` so nothing evades while walking; the
leash home moved to where a fight began; passive animals by data alone with a load check on
their leash. 70 animals proposed in five bands. Server only: a redeploy, no export. Recommended
timing: after the door.

## 4. Decisions and review, 2026-11-16

The user answered all eight decisions (design §9): as recommended, except no camp clearance;
wolves count for the wolf quests and rats do not (the rat quest's target becomes
`"Plague Rat"`); build before the door; night bats and ghosts in scope. The build is planned for
Fable once its credits return; this session reviewed the plan twice against the code first, at
the user's request, and folded every finding into the design (its new §10 lists them).

Read for the review: `loot.rs` (`find_table`, `is_beast`, `BEAST_NAMES`), `quests.toml`'s
targets against every name, `named.rs` (exact names), `spawn_points.rs` (one entity per point,
no player positions), both `on_enemy_died` callers, `released_from_charm` and `turn_on`,
`tick_idle` / `tick_chase` / `tick_leash` / `next_hater_or_home`, `is_evading`, `step_on`,
`stuck_too_long`, `leash_range`, `tick_ai`'s CC returns, `targets_for_enemy_ai` (pets
included), `walk_from_town`, the id partitions, `clock.rs`, the client's `night_factor`,
`factions.toml`, `alignment.rs`'s undead delta, the harness's `Config::terrain`, and the
client for any name-keyed behaviour (none). Three findings would have shipped wrong: adders and
vipers rolled no snake loot and dropped coin; a home reset on every entry to Chase would have
homed a charm-returned mob in town; and the harness would have spawned 70 animals into every
integration test.

A third review pass the same day (the roam data moved to its own `data/zone_roam.toml`, since
the client tools' camp parser would read appended `[[roam]]` entries as part of the last camp;
a pack's head count includes its charmed members; social aggro only to a packmate whose leash
reaches the target), and the user renamed "Night Bat" to "Bat".

**The user's pet rule, 2026-11-16:** "If someone casts charm on a second creature, the charm on
the first creature should drop immediately, and when a creature comes out of charm it should be
aggressive towards the caster", then "same rule covers other combinations". Verified in
`tick/casting.rs` and `tick/pet_life.rs`: a charm ending already hands the mob back hostile
(`return_charmed_mob` calls `turn_on`); the `PET_CHARM` arm never checks for an existing pet,
so a caster can hold any number of charmed mobs today; and `summon_pet_for_owner` kills a
charmed pet instead of handing it back. Designed as step 0 of the build (design §3.10): one
helper, a new pet replaces the old one, a charmed one is handed back angry. A To-Do entry under
Security. Not built.

## 5. The fourth review and the build, 2026-11-16 (night, unattended)

The user, after the model was switched to Fable: "Have a look at the plan made by Opus", then
"i need to go to bed. what can you run tonight? go ahead." So: the review's findings folded
into the plan, then the whole build, committed locally on side branches. Nothing pushed, merged
or deployed.

### 5.1 What the review found (the plan's section 10 has the table)

Read in full before reporting: `entity.rs` (the state machine, `transition`, `step_on`,
`stuck_too_long`, `tick_leash`, `released_from_charm`), `spawn_points.rs`, `tick/pet_life.rs`,
the charm arm and the port path in `tick/casting.rs`, `tick/spawning.rs`, `tick/enemy_ai.rs`,
`tick/kills.rs`, `terrain.rs`, `terrain_content.rs`, `fall.rs`, `loot.rs`, `quests.rs`,
`clock.rs`, `config.rs`, the harness, and on the client the quest table, `quest_manager.gd` and
`time_of_day.gd`.

- **Would have shipped wrong:** the shared release helper would have handed back a charmed pet
  that had already died (the Sable loot faucet of 11-09 again); packs came apart after their
  first fight (a member that joined through social aggro kept its old home, and a separated
  follower never rejoined).
- **Simpler than planned:** the stray rule was unnecessary (every fight ends with the walk home,
  and home is ground the roamer stood on in its region); the roam stuck clock was unnecessary (a
  refused step is refused identically every tick, and `transition` already clears the clock).
- **Factual corrections:** `move_speed` carries no snare; the AI step sleeps while nobody is
  online, so the clock-driven work belongs to the spawn step; a ring round the town crosses the
  ridge into the Greywood, so regions take a z band; the plan's claim that a caster could hold
  several charmed mobs "today, in the live game" was wrong (each charm's cooldown is at least
  its duration: Charm 60 s and 60 s, Siren's Song 45 s against 30 s), so only the data
  prevented it.
- **An older hole, closed on the way:** a charm wiped the mob's damage record and kept its
  wounds, so charming a nearly dead mob and letting it go took the kill from whoever did the
  work. The ledger now rides the charm.

### 5.2 What was built

**Server**, worktree `F:\Projects\server-wildlife`, branch `feat/wandering-wildlife` from
`a3b226d`:

- `c1758f0` **One pet at a time.** `pet_life::release_owned_pets` (living pets only),
  `pet_life::charm_mob` (the charm arm's body, beside `summon_pet_for_owner`),
  `Entity::charm_ledger`, `wipe_hate` clearing it.
- `f388b96` **Wandering wildlife.** `world/roam_map.rs`, `world/roam.rs`,
  `data/zone_roam.toml` (66 slots: 70 animals by day, 14 at night), the spawner's roam slots,
  `Entity::roam` / `tick_roam` / `roam_fight_began` / `join_pack_fight`, the AI step's pack
  pre-pass and hooks, the night gate and the daylight sweep, `clock::is_night`, adders and
  vipers in `loot.rs`, the rat quest's target, `Config::roamers` (`PD_NO_ROAMERS=1`) and
  `Config::roam_table`.

**Client**, worktree `F:\Projects\Project_Dawn-wildlife`, branch `feat/wandering-wildlife`:
the rat quest's target and objective text ("Kill plague rats at the Rat Warrens"), the night
hours named in `time_of_day.gd` with their pair in `check_constant_lockstep.gd`, rules C1 to C4
in `invariants.md`, `PD_NO_ROAMERS` in `commands.md` and `server_operations.md`, and
`wandering_wildlife_checklist.md` (39 rows).

No wire change, no migration, no DLL rebuild. The server half works with the door zip.

### 5.3 Tests

445 unit (33 new) and 195 world tests (4 new) green, fmt and clippy clean; the real binary
booted on a throwaway database with roaming on (`roamers=on`, `wandering wildlife slots=66
animals=84 roam_map_share=51.1%`) and off (`roamers=off slots=0`).

Nineteen faults planted one at a time, each caught by a named test: the walk disabled; the home
hook disabled; the body clearance removed; the social join removed; the face check removed from
the roam step; charmed heads not counted; the town clearance removed from the region; a leg's
line allowed through the town; the night gate removed; the refill waiting for the last member;
home set by a charm ending; a hidden target passed on; the leash not checked on a join; a dead
charmed pet handed back; the ledger not carried; a follower allowed through the town; snare
ignored while roaming; the release removed from `charm_mob`. (Two were missed on the first
pass: the pack test watched only the target message, which the fault left in place, and now
waits for both wolves to reach the caster; the town test's region was drawn round the town, so
its sampling never tried the town, and now uses a region beside it as well.)

### 5.4 Calls made in the build, the user's to overrule

- Field Rats stay aggressive (decision 2) with a 6 m aggro radius, so they add to a newcomer's
  fight only when it drifts onto them. One line of data makes them passive.
- The damage ledger rides a charm (the kill-steal fix).
- The rat quest's client text names the Rat Warrens.
- The far reaches (the war camp's vale, the barrow hills, the east arm) are one ring region
  past 1,350 m, so their animals split between the three by area.
- A follower regathers on its leader at a run when it has fallen 12 m behind.

### 5.5 Not done, and what the user does next

- Nothing is pushed, merged or deployed. The server half reaches players with: push the
  branch, merge it into the deploy branch, the usual redeploy, and the boot line reading
  `roamers=on`. No SQL, no zip. The client branch merges with it (its lockstep pair names
  server constants the deploy branch lacks until then).
- `wandering_wildlife_checklist.md` is unrun; nothing is ticked.
- The design doc, this note, the session index and the To-Do edits are uncommitted in the main
  client checkout (another session was committing there overnight).
- The planner: rows b63 (the build), d12 (the user's call on going live before the door), o29
  (the merge and redeploy, tentative) and v64 (the checklist sitting, tentative) are in
  `docs/schedule_detail.toml` and the two generated files, uncommitted. **The published page
  was not republished** (it still shows the 11-16 rolling hills state): the publish needs the
  whole 150 KB page read back first, and it was left for the user's word.
- Not built, flagged in the plan's section 11: a stunned leader's followers, no positions
  saved across a restart, a pack split by a cliff, no species shape on the client.

## 6. The merge, 2026-11-17

The user, on the morning's report ("say the word and I'll push, merge both branches together
and hand you the redeploy"): "go ahead".

- Both remotes fetched first: neither deploy branch had moved since the wildlife branches were
  cut (server `a3b226d`, client `1f293e4`), so both merges are fast-forwards and the merged
  server is, commit for commit, the one the suite ran on last night.
- Server deploy branch `fix/xp-leveling-overflow` fast-forwarded to `f388b96`; client to
  `b73a6a9`. `tools/check_all.ps1` run in the main client checkout against the main server
  checkout: all 17 checks pass.
- With the tests on the deploy branch, the "(on feat/wandering-wildlife)" tags came off rules
  C1 to C4 in `invariants.md`, so `check_invariants.gd` now holds those test names against the
  deploy server. The checklist's header names the build (`f388b96`, `roamers=on`).
- Checked before saying the door zip is unaffected: `quest_manager.gd` never matches a kill
  against an objective's `target` (progress is the server's), so a `397e207` client shows the
  rat quest's old objective text and nothing else differs.
- The records committed on the client deploy branch (the design doc, this note, the index, the
  To-Do, the planner files) and both deploy branches pushed by name.
- The planner: row d12 (the go-live call) answered and removed, o29 (the merge; the redeploy
  is the user's) and v64 (the sitting) no longer tentative; the page republished.

**Not done:** the redeploy (the user's, over SSH) and `wandering_wildlife_checklist.md`.
Nothing is ticked.
