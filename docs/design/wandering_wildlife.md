# Wandering wildlife

**Status:** designed 2026-11-15; all eight decisions answered 2026-11-16 (section 9); reviewed
three times against the code by Opus and a fourth time by Fable (section 10); **BUILT 2026-11-16
(night, unattended) on `feat/wandering-wildlife` in both repos; MERGED AND PUSHED 2026-11-17
(user: "go ahead"): both deploy branches fast-forwarded, server `f388b96`, client `b73a6a9`**
(section 11 is the as-built summary; where it differs from the body the body has been
corrected in place). Pending the redeploy and `wandering_wildlife_checklist.md`.
**Asked for (user, 2026-11-15):** "We need wandering NPCs to fill the open spaces. Wolves,
bears, snakes, rats etc."

The 4 km zone has 54 camp spawns on about 8.8 square km of walkable ground, and every one of
them stands on its spot until something comes within its aggro radius. The comp said so before
the zone was built (`starting_area_comp_sketches.html`: "Each camp wants several times its
spawns, with roaming wildlife between camps"). This plan adds animals that move through the
ground between the camps: they spawn in a region rather than at a point, walk short legs and
pause, notice players on the way, and fight with the AI every mob already has. Night adds bats
and ghosts.

---

## 1. What exists (read in both repos on 2026-11-15 and 2026-11-16)

| Piece | Where | What it means for wanderers |
|---|---|---|
| Spawns | `server/.../data/zone_camps.toml`, `world/spawn_points.rs` | One `SpawnPoint` per authored position, a jitter radius, a respawn timer, **one entity per point**. `Spawner::tick(now, terrain)` is given **no player positions**. Nothing spawns anywhere else. |
| Slot freeing | `spawner.on_enemy_died(idx)` | Called from the corpse sweep (`tick/enemy_ai.rs`) and from the GM's Despawn All (`tick/spawning.rs`); arms the point's timer. A charm keeps the slot (the pet carries `spawn_point_idx` and `spawn_pos`); `Entity::released_from_charm` rebuilds the mob through `from_spawn` from those two alone. |
| Mob AI | `world/entity.rs`, `EnemyState` Idle / Chase / Attack / Leash / Dead | Every mob's `tick_ai` runs every tick. Mez and stun return before the state machine. An Idle mob never moves: `tick_idle` only scans for targets (distance first, then `terrain.can_see`) and for attackers on its threat list. It enters Chase from exactly those two places (plus `turn_on`, the charm return). |
| Mob targets | `tick/enemy_ai.rs`, `targets_for_enemy_ai` | Every in-world player **and every living pet**. A pet parked on guard or sit is a target for any mob that walks past it. |
| Leash | `Entity::leash_range`, `tick_chase` | Measured from the **mob to its target**, not from home. `spawn_pos` is only where `tick_leash` walks back to. With `aggro = 0` the leash is the written `leash`, or 0 (no `MIN_LEASH_RANGE` floor). |
| Evade | `Entity::is_evading` | True in `Leash`, and in `Chase` while held below a face. False in `Idle`. So a wanderer must not walk its legs in the `Leash` state, or it is immune while roaming. |
| Slope and stuck | `step_on`, `stuck_too_long`, `MOB_STUCK_SECS` (8 s) | `step_on` refuses only a step that **rises** onto a face (`slope_ok`); a step **down** a face is allowed, and mobs never fall, so a mob can walk down a cliff pinned to it. `stuck_too_long` hard-codes the 8 s and resets only on a new goal or 1 m of progress; roam legs and the leash walk both have no goal (`None`), so a clock can carry from one into the other. |
| Walkable map | `world/terrain_content.rs::walk_from_town` | A flood fill from the town by the slope rule. **Test-only today.** It reaches face triangles (from above) and pockets reachable only downhill, which is right for "can a player leave the zone" and wrong for "where may an animal live". |
| Safe area | `data/safe_areas.toml` | The town square, 60 m, centred on the origin. Used for binds and ports; mobs ignore it. |
| Loot and coin | `world/loot.rs` | `find_table`: an exact name, then a case-insensitive substring **in either direction**, tables tried in order (Wolf, Skeleton, Gnoll, Rat, Boar, Snake, Bear, Spider, Bat, Zombie, Bandit, ...). `is_beast`: the name contains one of `wolf rat boar snake bear spider bat crawler wasp beetle lion tiger scorpion drake`; a beast drops no coin, anything else drops coin by level. **A name with no table word rolls no items, and a name with no beast word drops coin.** Snake, Bear, Bat, Wolf and Rat tables exist, every item on the client already. |
| Faction and alignment | `data/factions.toml`, `world/alignment.rs` | `wildlife` has no links (killing an animal moves no standing). `restless_dead` is the town's and the Watch's enemy, so each undead kill raises both; an undead kill moves alignment +20 toward good. |
| Quests | `data/quests.toml`, `quests::kill_matches` | Kill objectives match by substring in either direction. `wolf_threat` and its sequel target `"Wolf"`; `rat_infestation` targets `"Rat"` (changes to `"Plague Rat"`, decision 6). No quest targets Bat, Bear, Snake or a ghost. |
| Night | `world/clock.rs`; client `autoloads/time_of_day.gd` | The server knows the hour (`current_hour()`, a 1200 s day) and has **no idea of night**. The client's sky is fully dark from 21:00 to 05:00 (`night_factor`): 400 real seconds, under seven minutes. |
| Camp file readers | `zones.rs::load_camps`; client `tools/author_terrain.gd::parse_camps` (also used by `check_compass.gd`) | The server's parser ignores unknown keys. The client tools' parser splits the text on `[[camp]]`, so the last camp's block would swallow anything appended after it, and a top-level `radius =` line in it would be read as that camp's radius. |
| Slope counter | `world/health.rs`, fed only by `tick/movement.rs` | `slope_refusals` in the `world health` line counts **player** steps refused; on flat ground any count means a modified client. Mob refusals are not counted, and must stay that way. |
| Test harness | `tests/world/common` | Runs the real `zone_camps.toml` on a flat ground of its own (`Config::terrain`). **Anything added to that file appears in every integration test.** `Config::fizzles` is the precedent for a switch the harness turns off. |
| Dev spawn faction | `zones::faction_of_camp_mob` | A Test Panel spawn takes the faction of the camp mob with its name. Roam names must be found there too. |
| Ids | `ENEMY_ID_BASE`..`LOOT_BAG_ID_BASE` | A billion enemy ids, never reused; respawn churn is no concern. |
| Position stream | `tick/position_fan.rs` | A mob is sent only when it moved (or every 500 ms keepalive), and only to players whose cell can see it. A walking mob costs 20 Position messages a second per viewer; an unseen one costs nothing. |
| AOI crossings | built 2026-09-30 | A mob that walks across a cell boundary is spawned and despawned on the right clients already (the enemy AI loop updates the cell for any move). |
| Client | `scripts/remote_enemy.gd` | Renders any mob name with the shared capsule and interpolates its position. Nothing on the client keys behaviour off a mob's name. **No client change is needed** beyond the rat quest's target string. |

Nothing in either repo mentions roaming mobs, patrols or social aggro before today.

---

## 2. The design in one paragraph

A new `data/zone_roam.toml` names, per entry, a species, a region (a circle in world
coordinates), a head count, a respawn time, a temperament and optionally night only. At boot
the server computes a roam map once: the floors a body can walk to from the town without ever
crossing a face. A roam slot spawns its animal at a random spot of that map in its region,
clear of the town and of every player. Once spawned it stays in `Idle` and, while idle, walks:
pause a few seconds, pick a point 20 to 80 m away inside its region, amble there at part of its
speed, never stepping onto a face, pause again. It scans for players every tick exactly as an
idle mob does, so it notices you on its way. When it starts a fight, its leash home becomes the
spot where the fight began, so after a leash it walks a short way back and resumes roaming. An
animal left outside its region, idle and unseen, is quietly put back. Wolves travel as packs
that follow a leader and join its fights. Bats and ghosts come out at night.

---

## 3. The pieces

### 3.1 Data: `data/zone_roam.toml`

A file of its own beside `zone_camps.toml`, embedded the same way (`include_str!`). Not appended
to the camp file: the client tools' camp parser would read the roam entries as part of the last
camp (section 1). A roam entry:

```toml
[[roam]]
desc = "Timber wolves running the outer basin in threes"
mob = { name = "Timber Wolf", level = 7, hp = 104.0, dmg = 15, speed = 4.2, aggro = 14.0, faction = "wildlife", alignment = "neutral" }
region = { center = [0.0, 0.0], radius = 1300.0, min_from_town = 800.0, z_min = -760.0 }
count = 3          # slots (for a pack: packs)
pack = 3           # members per slot, default 1
respawn = 180.0    # seconds, rolled +-25% per death
time = "night"     # optional: "night" spawns only at night (section 3.9); default any time
```

A region is a circle (`center = [x, z]`, `radius`), optionally cut to a ring round the town
(`min_from_town`, so the level bands can follow the camp rings, section 6) and to a band of z
(`z_min` / `z_max`, so a region stays on one side of the ridge: a ring 800 to 1,300 m round the
town would otherwise take in a slice of the Greywood, which is on the roam map through the
pass). The town clearance (3.3) is part of every region. The `mob` block is the camp table's
own `MobTemplate`, so named ids, faction hits, leash and attack interval all work unchanged
(`xp` is not needed: a kill pays by level). Unknown keys are refused, so a typo fails the
build's tests. Server only: the client needs no mirror, as for camps. **Coordinates are world
coordinates** (x east, z south, north is -z since the compass mirror of 2026-11-14), not the
client's map coordinates. To see the ground when placing a region:
`cargo test -p projectdawn-server --lib print_the_roam_map -- --ignored --nocapture` prints the
roam map (north up, 40 m a character) and each region's room.

**Load checks** (a unit test over the real file, as the camps have):
- the faction exists and the alignment tier is one `alignment.rs` knows;
- a mob with `aggro = 0` has an explicit `leash` of at least `MIN_LEASH_RANGE` (35 m), camps
  included, so no passive mob can be nuked from beyond its own reach;
- the roam map holds enough of every region for its count (at least 5,000 square metres per
  animal; the shipped regions hold 0.4 to 2.4 square km each), and a region with a z band holds
  no ground on the far side of the ridge by construction;
- **every roam name resolves the way its species should**: an animal is a beast
  (`is_beast`) and finds its item table (`find_table`); a ghost is not a beast and finds no
  animal table. The same test runs over the camps' names, so a future camp cannot slip either.
- `zones::faction_of_camp_mob` finds roam names as well as camp names (a Test Panel spawn of a
  Timber Wolf carries `wildlife`).
- `safe_areas.rs`'s test that no camp's aggro reaches into a safe area covers the roam regions
  too (the 150 m town clearance clears the 60 m square plus any aggro radius here; the test
  keeps it so).

### 3.2 The roam map

`world/roam_map.rs`, built once at boot from the server's terrain (`Config::terrain`, so the
harness's flat ground and a test's own ground get their own map, never the compiled zone's):
the client collider's own triangles, flooded from the town over **floor triangles only, across
shared edges, never entering or leaving a face in either direction**. A floor is ground no
steeper than the client's floor angle (`fall::is_floor`, 55 degrees): one predicate for the map,
stricter than the slope rule's 60, so a walk between two neighbouring floors is always a step
the slope rule takes. That map is exactly the ground an animal can walk to and walk back from.
It exposes `roamable(x, z)`, the one answer to three questions: where a wanderer may appear,
where a leg may end, and whether a roam step may be taken. The boot line reports its share of
the plate (51.1% on the zone as built).

`walk_from_town` stays as it is, test-only, for `nobody_walks_out_of_the_zone`: that test asks
a different question (where can a player get to, falls included).

### 3.3 Where a wanderer appears

`Spawner::tick` gains the positions of every in-world body, players and linkdead bodies alike
(a linkdead body is still in the world and still attackable). A spot is drawn at random in the
region and kept only if all hold, else redrawn (up to 32 tries; with none found, the slot
retries next second):

- roamable (section 3.2);
- at least `ROAM_TOWN_CLEARANCE` from the origin (150 m: the flat town's edge);
- at least `ROAM_POP_CLEARANCE` from every in-world body (60 m: past every aggro radius and
  beyond the evade grace), so nothing pops onto someone mid-fight or onto a corpse run.

No camp clearance (decision 5): wanderers may be born in a camp and walk through camps.

A pack's members appear within 5 m of the leader's spot (`PACK_SPREAD`), each spot checked the
same way. The clearance is measured on the ground (XZ), and a dead player's body counts for as
long as it lies in the world.

### 3.4 The roaming itself

No new `EnemyState`: roaming is part of `Idle`, so every rule that reads Idle (the scan, CC,
the evade rule, which is false in Idle) stays right. A roamer carries a small `Roam` record
(`Entity::roam`): its region, its pause deadline, its current leg goal. A charm carries the
record on the pet (which never walks: it is a pet) and `released_from_charm` gives it back with
the walk forgotten.

`Entity::tick_roam` runs in the AI step right after `tick_ai`, for a mob that was idle and
still is (so it has already looked for a target this tick, exactly as a standing mob does):

1. If pausing and the pause has not run out, stand still.
2. If no goal, pick one (`roam::pick_leg`): a point 20 to 80 m away (`ROAM_LEG_MIN` /
   `ROAM_LEG_MAX`), inside the region, roamable, and whose straight line does not cross the
   town circle. Up to 8 tries; none found means pause again.
3. Step toward the goal at `enraged_speed() x (1 - snare) x ROAM_SPEED_MULT` (0.4: a wolf trots
   at 1.7 m/s, a snake creeps at 1 m/s; snare is applied here by hand, as the chase does,
   since `move_speed` does not carry it), not at all while `is_rooted()`. **A roam step is
   taken only onto the roam map** (`roam_step`: the triangle under the new position, every
   tick, so a face is refused going down as well as up). A refused step ends the leg at once
   and starts a pause: the same step would be refused next tick too, so no stuck clock runs
   (and `transition` already clears the clock on every state change, so nothing carries into a
   chase). A roamer's refused steps never feed the `slope_refusals` counter (section 1). Each
   step faces the goal (`face_toward`), so the capsule faces the way it walks.
4. Within 1 m of the goal, drop it and pause 5 to 25 s (`ROAM_PAUSE_MIN` / `_MAX`).

A roamer found idle off the roam map (the walk home stops within a metre of home, which can be
the wrong side of a face's edge) steps onto its home, which is always on the map.

The AI step runs only while a player is in the world, so on an empty server the animals stand
where they are; nobody is there to see it.

### 3.5 Leash home

For a roamer, `spawn_pos` (the leash target) is rewritten to its current position the moment it
picks a target while idle (`Entity::roam_fight_began`), and only when that position is on the
roam map, so home is always ground it can walk on from. The hook sits in the AI step after
`tick_ai`: a mob that was Idle and is now in Chase acquired its target in `tick_idle` (its two
acquire paths are the only way from Idle to Chase inside `tick_ai`). A pack member joining a
packmate's fight (3.8) rewrites its home the same way. Never in `transition` and never by
`turn_on` (a charm ending), which enters Chase elsewhere, often in town where the charmer took
the pet: a home there would put an aggressive mob at the vendors for good. After a leash it
walks back to where the fight began, which is short and inside or near its region, heals there
as every mob does, and resumes roaming. A camp mob keeps its fixed home.

### 3.6 Strays (cut in the fourth review)

The earlier draft removed a roamer found idle outside its region and respawned it. It cannot
happen: every way out of a fight is the `Leash` state (`next_hater_or_home`, the stuck
give-up, `go_home`), `tick_leash` walks the mob to its home and warps it there after 8 s held
by a face, and home is only ever a spot it stood on while roaming inside its region (3.5); a
charm return carries the home it had when charmed. So an idle roamer is always in its region,
and the rule, its timer and its tests were dropped. As a backstop that costs nothing, a leg
picked by a roamer that does find itself outside its region heads for the region's middle.

### 3.7 Temperament

| Temperament | Data | Behaviour |
|---|---|---|
| Aggressive | `aggro > 0` | Attacks a player or a pet that comes within its aggro radius, as every camp mob does. |
| Passive | `aggro = 0`, `leash >= 35` | Never starts a fight; fights back when hit (the threat scan already does this). |

No code for either; the load check of section 3.1 holds the passive leash.

### 3.8 Packs

A slot with `pack > 1` spawns a leader and followers.

- **Membership is the slot.** The pack is the living, unowned enemies with that slot index
  (ids change on a charm, so an id list would lose them). A charmed member is owned and so
  leaves the pack while charmed; handed back, it rejoins by its slot.
- **The spawner counts heads per slot** by looking at the world each time the slot is due
  (every living enemy carrying its index), not by keeping a counter: a member's death arms the
  slot's timer (a second death never pushes a running timer back), and when the timer is due
  the slot **refills the missing heads** beside its leader, if no player is within 60 m of it
  (else it tries again a second later), or spawns a whole new pack somewhere in the region if
  none lives. Waiting for the last member to die would let anyone block the pack by keeping
  one alive (mezzed, rooted, or stranded behind a hill).
- **The head count includes charmed members.** The pack's behaviour (following, social aggro,
  the lead) leaves a charmed member out, but the count that decides a refill does not: every
  living enemy carrying the slot's index, owned or not. Otherwise charm a wolf, wait for the
  refill, let the charm end, and the pack has one more; repeated, a charm-and-wait farm. This
  is the same rule the charm return of 2026-10-06 keeps for camps (the slot stays occupied for
  the charm's life). It holds for single slots too.
- **The lead** is the member with the lowest entity id, read fresh every tick: no stored
  state, so a leader that dies or is charmed hands the lead on by not being there.
- **Followers** keep to the leader, whatever either is doing, while idle themselves: within
  4 m they stand, further they amble after it, past 12 m they run (`PACK_FOLLOW_DISTANCE`,
  `PACK_CATCHUP_DISTANCE`). So a pack separated by a fight regathers. A follower whose straight
  line to the leader would cut the town, or whose next step leaves the roam map, does not take
  it: it walks legs of its own for 30 s (`PACK_SOLO_SECS`) and tries again.
- **Social aggro,** asked every tick (`roam::pack_fight_to_join`): an idle member within 30 m
  of a packmate that is fighting takes that packmate's target, puts it on its own threat list
  (so the hate list, the faction hits and the evade rules all see it) and its fight begins
  where it stands (3.5), **when its own leash reaches the target**: the first social aggro on
  the server, scoped to a pack. The leash condition matters: a packmate 30 m behind a member
  that aggroed at 14 m can be 44 m from the target, past the 35 m leash floor, and
  `tick_chase` drops such a target on its first tick, so it would walk home evading for
  nothing. Because the question is asked every tick, a member that arrives later (following
  its leader toward the fight) joins then. A hidden or feigning target is never passed on (the
  `hidden` list the idle scan already reads), nor one that has left the world.

### 3.9 Night

`time = "night"` slots are alive only at night.

- **Night** is `hour >= NIGHT_START_HOUR || hour < NIGHT_END_HOUR`, 21.0 and 5.0, the hours
  the client's sky is fully dark (`time_of_day.gd`'s `night_factor`). The pair is kept in
  lockstep (`check_constant_lockstep.gd`), as the day length is. Night lasts 400 real seconds,
  so night respawns are short (about 60 s, section 6).
- **At dusk** every night slot is due; each spawns by the ordinary placement rules.
- **A night slot's respawn that falls due in daylight** waits until the next dusk.
- **In daylight**, a night animal that is Idle, at full HP and seen by no player is removed
  (no loot, no XP, no corpse), whenever that becomes true, not only at the moment of dawn. One
  fighting at dawn stays until it dies or leashes home and heals; a charmed one is a pet and
  is left alone until it is handed back.
- **Where it runs:** the night gate and the daylight removal are in the spawn step
  (`tick/spawning.rs`), which runs every tick whether or not anyone is online; the AI step
  sleeps on an empty server and dawn comes regardless.

### 3.10 One charm at a time (user, 2026-11-16)

The user's rule: "If someone casts charm on a second creature, the charm on the first creature
should drop immediately, and when a creature comes out of charm it should be aggressive towards
the caster."

- **The second half already holds.** Every way a charm ends (the expiry sweep, the charmer
  leaving) goes through `pet_life::return_charmed_mob`, which rebuilds the mob and calls
  `Entity::turn_on(charmer)`: threat on the charmer, Chase, an `EntityTarget` fanned (built
  2026-10-06).
- **The first half did not hold in the code.** The `PET_CHARM` arm of `tick/casting.rs` never
  looked for a pet the caster already had. (Summoning did keep one pet per owner, in
  `summon_pet_for_owner`, but by marking the first owned pet it found Dead: a summon cast with
  a charm up killed the charmed mob instead of handing it back.) **Corrected in the fourth
  review:** in play nothing could reach it, because each charm spell's cooldown is at least as
  long as its charm (Charm 60 s and 60 s, Siren's Song 45 s against 30 s), so only the data
  kept a caster to one charmed mob, and a longer charm or a shorter cooldown would have let
  them stack. The rule now holds whatever the data says.
- **Build:** the charm arm, once its victim is resolved and before the new pet is made, hands
  back every charmed pet the caster owns through `return_charmed_mob` with `turn_on =
  Some(caster)`, so the first creature is released at once and comes straight for the caster
  while the second becomes the pet. The released mob returns to its own slot (its head count
  never left it, 3.8). For roamers the released mob is an ordinary handed-back mob: its home is
  not rewritten (3.5) and the stray rule (3.6) covers it.
- **The other pairings, DECIDED 2026-11-16 (user: "same rule covers other combinations").**
  One rule for every pet a player can have: **a new pet replaces the old one, and a charmed one
  is handed back angry.** A charm cast with a **summoned** pet out dismisses the summoned pet
  (the existing dismissal: marked Dead, `EntityDied` fanned, no loot, as a pet's death always
  is); a summon cast with a **charmed** pet out hands the charmed mob back hostile through
  `return_charmed_mob(..., Some(owner), ...)` instead of killing it, as `summon_pet_for_owner`
  does now.
- **One home for the rule (as built):** `pet_life::release_owned_pets(owner)` dismisses every
  living summoned pet the owner has and hands back every living charmed one, hostile to the
  owner. `pet_life::charm_mob` (the charm arm's body, moved beside `summon_pet_for_owner`) and
  `summon_pet_for_owner` both call it before making their pet, so a second pet can never
  coexist with the first.
- **Only living pets** (fourth review): a charmed pet that has died is a body the corpse sweep
  owns. Handed back at 0 HP it would be killed by the stray sweep next tick and drop the mob's
  loot for a fight nobody fought, the Sable faucet of 2026-11-09 again; the two older release
  paths already filter the same way.
- **The damage ledger rides the charm** (fourth review, built): `Entity::charm_ledger` keeps
  the mob's `aggro` map on the pet and `released_from_charm` gives it back, so charming a
  nearly dead mob and letting it go no longer takes the kill from whoever did the work (a hole
  older than this rule, which the instant release would have made a two-cast trick);
  `wipe_hate` clears a player from it as from the live ledger.
- **Reach today, checked in `spells.toml`:** the charmers are the Enchanter (Charm) and the Bard
  (Siren's Song); the only summoned pets are the Necromancer's Summon Skeleton and the Beast
  Master's warder. No class has both a charm and a summon, so the cross pairings cannot happen
  in play yet; the helper makes them right before any class gains both. **Flagged for that
  day:** a Beast Master's warder respawns on its own (`warder_respawn_at`), so a Beast Master
  who could charm would have the charmed mob handed back angry by its own warder's respawn
  ~15 s later; that class's design decides whether the warder waits while a charm holds.
- **Tests (as built, `tick/pet_life.rs`):** (1) `a_second_charm_drops_the_first_which_turns_on_the_caster`:
  a caster charms mob A, then mob B through `charm_mob`: A is an enemy again in its own slot,
  with its HP and its damage ledger, targeting the caster; B is the pet; the caster owns
  exactly one; a refused charm releases nothing. It fails with the release taken out. At the
  helper, not through a cast, because no cast can reach it today (the cooldowns above).
  (2) `a_new_pet_replaces_the_old_and_a_charmed_one_comes_back_angry`: a planted owner holding
  a summoned pet, a living charmed pet and a dead charmed one: the first is dismissed, the
  second comes back hostile with its ledger, the third stays a body. (3) The 18 existing pet
  integration tests stay green.

---

## 4. What does not change

No wire change, no protocol bump, no DLL rebuild, no migration, no client export. A roamer is
an ordinary enemy entity: the client already spawns, moves, despawns and loots it. The whole
feature ships with a server redeploy. The client's copy of the rat quest target
(`data/quest_definitions.gd`) changes to match the server; it is display data, so it can ride a
zip or wait. The client could later give species their own shape or tint (today every mob is
the same capsule); that belongs to the art pipeline.

### 4.1 The off switch

`Config::roamers`, true unless `PD_NO_ROAMERS=1` is set (the `PD_NO_RATE_LIMIT` pattern; on
the R720 a line in `/opt/projectdawn/.env` and a restart). Off, the roam table is not loaded and
nothing spawns from it; camps are untouched. `Config::roam_table` lets the integration harness
run a table of its own. This ships a day or two before the door with
no friends' playtest behind it, so there must be a way back without a rebuild. The integration
harness turns it off (section 8). The boot line reports `roamers=on|off`, and a `wandering wildlife` line at world start gives
the slots, the animals and the roam map's share of the plate.
`docs/reference/commands.md` and `docs/deployment/server_operations.md` gain the variable.

---

## 5. Exploit ledger

| # | Risk | Rule |
|---|---|---|
| 1 | A wanderer drifts into town and kills players standing at the vendors. | The town clearance is part of every region, so spawn spots and leg goals never fall within `ROAM_TOWN_CLEARANCE` of the town; a leg's line never crosses that circle, nor does a follower's line to its leader; the leash home is never set by a charm return (3.5). A chase can still bring one in, as it can a camp mob (no guards exist yet), and it walks home afterwards. Test. |
| 2 | Pop-in: a respawn appears on top of a player or a corpse run. | `ROAM_POP_CLEARANCE` from every in-world body at spawn time, linkdead included. Test. |
| 3 | A roamer walking its legs is immune (the evade rule covers `Leash`). | Roaming is `Idle`, never `Leash`. Test: a roamer mid-leg takes a swing. |
| 4 | A passive animal is nuked from beyond its reach (aggro 0 makes leash 0). | Load check: aggro 0 needs an explicit leash of at least 35 m. Test. |
| 5 | A roamer walks off the zone, onto a perch, or down a cliff into a pocket it cannot leave. | The roam map is floors reachable both ways (3.2); a roam step onto a face is refused either way (3.4); nothing reachable lies outside the edge (`nobody_walks_out_of_the_zone`). Test. |
| 6 | Farming a respawn: kill, wait, it appears beside you again. | The respawn spot is redrawn each time and kept 60 m from every player, so a camper cannot hold a spawn point. Respawn timers are rolled +-25%. |
| 7 | Leash abuse: pull a roamer far, let it walk home, repeat for free damage. | Unchanged: the evade rule makes the walk home immune, and home is where the fight began, so the walk is short. |
| 8 | A pack trains a newcomer. | Packs only roam the outer bands (section 6), never the level 1 to 2 meadows. (The camp clearance this row also named is void: decision 5.) |
| 9 | Loot or coin faucet. | Same tables and the `is_beast` no-coin rule; kills pay by level as now. **`adder` and `viper` join the beast list and the Snake table** (section 6), and the load check of 3.1 proves every roam name resolves, so no animal drops coin by accident of its name. Test. |
| 10 | Load: a modified client cannot touch any of this. | Everything is server-side; the client only renders. Section 7 covers cost. |
| 11 | A pack is denied to everyone by keeping one member alive. | The slot refills missing members once its timer is due (3.8). Test. |
| 12 | A night farm next to town (undead kills raise town standing and good alignment, ghosts drop coin). | Ghosts only in the outer bands at level 7 and up (section 6), and only for the 400 s of a night. Kills pay by the existing rules; nothing new. |
| 13 | A roamer left where a player put it (in town, in the wrong basin) as a trap or a private farm. | It cannot be left: every fight ends with the walk home (3.6), and home is ground it roamed on, never where a charm ended (3.5). Test. |
| 14 | Charm-and-wait: charm a roamer, let its slot refill, end the charm; the slot now holds one more, and repeated the area fills. | A slot's head count includes its charmed members (3.8). Test. |

| 15 | A new pet's release hands back a charmed pet that already died: a 0 HP mob the stray sweep kills, dropping loot for no fight. | `release_owned_pets` takes living pets only (3.10). Test. |
| 16 | Kill-steal by charm: charm a nearly dead mob (its damage record was wiped, its wounds kept), release it, finish it. | The damage ledger rides the charm and comes back with the mob (3.10). Test. |

`docs/reference/invariants.md` gains a rule for row 1 (a wanderer never chooses ground inside
the town ring) with its test name, held by `tools/check_invariants.gd`.

---

## 6. Population (decision 3, as recommended; as built in `data/zone_roam.toml`; tuned after the first walk)

Bands follow the camp rings in `zone_camps.toml` (distance from town: 200 to 350 m level 1 to
2, 450 to 700 m level 3 to 4, 800 to 900 m level 5 to 6, 1.1 to 1.25 km level 7 to 9, 1.5 to
1.6 km level 10 to 12). World coordinates: x east, z south (north is -z). Hit points and damage
come off the camp ladder at the same level; bears get a quarter more hit points and swing
slower (2.8 s), snakes a quarter fewer hit points and a short 6 m aggro.

| Region | Ground (as authored) | Roam map in it | Species (level, temperament, count) |
|---|---|---|---|
| Town meadows | ring 150 to 420 m | 0.48 km2 | Field Rat (1, aggressive at 6 m, 6); Grass Snake (2, passive, 6) |
| The near basin | ring 450 to 750 m, `z_min = -760` (south of the ridge) | 1.13 km2 | Prairie Wolf (3, aggressive, 3 packs of 2); Prairie Adder (4, aggressive at 6 m, 5); Black Bear (5, passive, 2) |
| The outer basin | ring 800 to 1,300 m, `z_min = -760` | 2.41 km2 | Timber Wolf (7, aggressive, 3 packs of 3); Brown Bear (8, aggressive, 3); Rock Adder (6, aggressive at 6 m, 4) |
| The Greywood | circle (0, -1300) radius 1,100, `z_max = -1030` (north of the ridge) | 1.13 km2 | Greywood Wolf (8, aggressive, 3 packs of 3); Greywood Bear (9, aggressive, 3); Forest Viper (7, aggressive at 6 m, 4) |
| The far reaches | ring past 1,350 m, `z_min = -760`: the war camp's vale, the barrow hills, the east arm | 2.13 km2 | Grizzly Bear (11, aggressive, 4); Hill Wolf (11, aggressive, 3 packs of 2); Rock Viper (12, aggressive at 6 m, 3) |

**Night only** (`time = "night"`, respawn 60 s):

| Region | Species (level, temperament, count) |
|---|---|
| The near basin | Bat (4, aggressive, 6): a beast, the Bat table (an exact match), no coin |
| The outer basin | Wandering Shade (7, aggressive, 5): undead, `restless_dead`, alignment `undead`, coin, no item table |
| The barrow hills, circle (-1650, 0) radius 400 | Barrow Shade (10, aggressive, 3): as the Wandering Shade |

70 animals by day (30 of them wolves, in 12 packs) take the zone from 54 mobs to 124, about one
wanderer per eighth of a square km; 14 more at night. 66 slots in all. Day respawns are 180 s
(bears 240 s). Speeds: wolves 4.0 to 4.4 and rats 4.0 (a player runs at 5.0), bears 3.6, snakes
2.4 (outrun easily, which is what makes their ambush fair), bats 4.5, shades 3.0.

**Field Rats, flagged in the fourth review:** a level 1 character has 17 to 28 hit points and
the rats' ring holds the three starter camps, so an aggressive rat with a camp mob's 12 m sight
would add itself to a newcomer's first fights. They stay aggressive (decision 2) with a 6 m
aggro radius, the snakes' ambush distance, so one joins only a fight that drifts onto it. If
the first camps still feel too hard, `aggro = 0.0, leash = 35.0` on that one line makes them
passive.

**Names, checked against every name rule** (`find_table`, `is_beast`, `kill_matches`, each a
substring match in either direction):
- **Adders and vipers** contain no word the server knew, so as first written they would roll
  no items and drop coin like a humanoid. `loot.rs` gains `"adder"` and `"viper"` in
  `BEAST_NAMES` and `("Adder", T_SNAKE)`, `("Viper", T_SNAKE)` at the end of `TABLES`. (The
  snake is not called "Rattlesnake": "rat" would make it a rat for loot and for the old rat
  quest.)
- Field Rat rolls the Rat table and, with the quest target `"Plague Rat"`, ticks no quest
  (decision 6). Every wolf here contains "Wolf" and counts for the wolf quests (decision 6).
- Bat matches the Bat table exactly and is a beast; no quest target contains "bat" (not even
  "Bandit"), and the dev-spawn faction lookup matches names exactly, so the Cave Bat camp is not
  confused with it. Wandering Shade and Barrow Shade collide with nothing ("barrow" contains
  neither "rat" nor "bat"); the shades are not beasts, so they drop coin as undead do.
- Unit tests in `roam.rs` run these rules over every roam and camp name, so a later rename is
  caught (`every_roam_and_camp_name_resolves_to_its_species`,
  `wolves_count_for_the_wolf_quests_and_nothing_else_ticks_a_quest`).

---

## 7. Cost

- **Tick work.** The idle scan checks distance before sight, and a leg pick is a handful of
  samples every 10 to 30 s per animal. The 2026-11-02 health line read a median tick of 0.5 to
  0.8 ms against the 50 ms budget with 54 mobs; doubling the mob count is far inside it. The
  boot-time roam map runs once (a breadth-first fill over 320,000 triangles).
- **Bandwidth.** A walking animal costs 20 Position messages a second to each player who can
  see it, and it walks about half the time. A player who sees four roamers adds about 2,400
  messages a minute to the 5,000 the 54 idle camp mobs cost today (the
  `scale_readiness_checklist.md` measurement). The once-a-minute `enemy position fan` line
  measures it after the redeploy; `world health` measures the tick.

---

## 8. Build order, tests and records (as built)

Server work in the worktree `F:\Projects\server-wildlife` (branch `feat/wandering-wildlife`
from the server deploy branch); the client's small changes in `F:\Projects\Project_Dawn-wildlife`
(same branch name, from the client deploy branch).

0. **One pet at a time** (3.10): `release_owned_pets`, `charm_mob`, the charm ledger; its own
   commit, before the roamers.
1. **The roamers, packs and night**, one commit: `Config::roamers` / `roam_table` and
   `PD_NO_ROAMERS`; `world/roam_map.rs`; `world/roam.rs` and `data/zone_roam.toml` with the
   load checks; `loot.rs`'s adder and viper; the spawner's roam slots, head counts and region
   placement; `Entity::roam`, `tick_roam`, `roam_fight_began`, `join_pack_fight`; the AI
   step's pack pre-pass and hooks; the night gate and the daylight sweep; `clock::is_night`;
   the rat quest target; the population.

**The harness.** `Config::roamers` is false in `tests/world/common` (the `fizzles` precedent),
or every integration test would get 70 animals. `start_with_roamers(terrain, table)` turns it
on with a table of the test's own (`Config::roam_table`). The default harness plate is 400 m
across, inside the 150 m town clearance almost everywhere, so the roam tests bring an 800 m
plate and regions 330 m south of the town, 290 m from the nearest camp spawn; night slots stay
out of harness tables (the hour is the wall clock; the spawner takes the hour as an argument so
its unit tests can set it).

**Tests** (19 planted faults, one per rule, each caught by a test; the list is in the session
note):
- `roam_map.rs`: a flat plate is roamable and nothing off it; a face is never roamable and the
  ground behind it is not reached; a pit reachable only downhill is not roamable; a start on a
  face roams nowhere; edge neighbours are mutual; the point lookup uses the terrain's triangles.
- `roam.rs`: a region is its circle less the town and outside its band; a wanderer never
  chooses ground inside the town ring (thousands of spots and legs); a line through the town is
  refused; a leg from outside the region heads for it; a pack member appears beside its leader;
  a packmate joins a fight its own leash reaches and no other (hidden, out of earshot, past the
  leash, gone); the shipped table parses and counts (70 and 14); a table that would misbehave
  is refused (a passive mob without a leash, a typo'd key, a bad time); every roam and camp
  name resolves to its species; wolves count for the wolf quests and nothing else ticks one;
  the table's factions exist, a dev spawn takes them, and the town is out of every aggro's
  reach; every region has room on the compiled ground.
- `spawn_points.rs`: the zone fills its roam slots (54 + 70 by day, 14 more at night) and
  roaming off spawns only camps; a wanderer appears in its region clear of every body; a pack
  is refilled beside its leader while one member lives; a charmed member holds its head; a
  night slot waits for dusk; a slot's timer is rolled once and only its own.
- `entity.rs`: a wanderer walks a leg at an amble then stands a while (and is never evading);
  a roam step onto a face is refused going down as well as up; root holds a wanderer, snare
  slows it, and only an idle mob walks; a wanderer's home is where its fight began and never
  where a charm ended; an idle wanderer off the map steps onto its home; a follower keeps to
  its leader and never cuts through the town.
- `clock.rs`: night is nine in the evening to five in the morning.
- `tick/pet_life.rs`: the two of 3.10.
- integration (`tests/world/roam.rs`): a wanderer walks its region on its own (seen by a
  watcher in view, beyond its aggro); a wanderer goes home to where its fight began (pulled by
  a GM who then takes off; it heals at the fight's start, not at its first spawn); a respawn
  never lands beside a player (six in a row past 60 m); a packmate joins its packmate's fight
  (two passive wolves, one smitten, both come).
- `first_tick_spawns_everything` and `zones.rs`'s camp counts stay at 54.

**Playtest:** `docs/playtest_notes/wandering_wildlife_checklist.md`, 39
rows.

**Records:** this file, the session note, the To-Do entries, the planner's row; on the client
branch `commands.md` and `server_operations.md` for the switch and `invariants.md` rules C1 to
C4.

---

## 9. Decisions for the user

**Answered 2026-11-16 (user):**

1. As described.
2. As recommended.
3. As recommended.
4. Yes: wolf packs with pack social aggro.
5. Town clearance 150 m kept; **no camp clearance** ("i dont care if they roam through
   camps"), for spawn spots and legs alike. The player clearance at spawn stays.
6. **Wolves count, rats do not.** The rat quest is Brom's cellar rats (`rat_infestation`,
   "Rats have gotten into my storage cellar"; the Plague Rats of the Rat Warrens camp, "out
   the back of Brom's cellar"). Its target becomes `"Plague Rat"` on both sides
   (`quests.toml` and `quest_definitions.gd`), so a Field Rat ticks nothing. Found with it:
   the bidirectional substring rule (`quests::kill_matches`) and the loot lookup
   (`loot::find_table`, tables tried in order, Rat before Snake) would both have read
   "Rattlesnake" as a rat (rat quest credit, rat meat), so no snake carries that name.
7. **Now** ("i want it now"): all three parts build before the door. Server only, so the
   door zip is unaffected; it reaches players with a redeploy.
8. **Night animals, yes: bats and ghosts.** New species such as deer are not in scope.

**Made in the reviews and the build (2026-11-16), the user's to overrule:** the night numbers
of section 6; refilling a pack rather than waiting for its last member; `adder` and `viper`
added to the loot rules rather than renaming the snakes; the off switch; Field Rats aggressive
at a 6 m aggro radius (section 6); the damage ledger carried through a charm (3.10); the rat
quest's objective text on the client ("Kill plague rats at the Rat Warrens"); the stray rule
cut (3.6); a follower regathering on its leader (3.8).

The original questions, for the record:

1. **Go on the shape?** Roaming inside Idle, region spawns, short legs and pauses, home reset
   at aggro (sections 3.3 to 3.5). Recommended.
2. **Temperaments.** Recommended: rats, wolves and vipers aggressive; Grass Snake and Black Bear
   passive near town; the bears further out aggressive.
3. **The population.** Section 6's 70 animals and their levels, or a different count.
   Recommended as written, tuned after the first walk.
4. **Packs.** Wolves in packs from the near basin outward, with pack social aggro.
   Recommended.
5. **Clearances.** Town 150 m, camps 60 m, players 60 m at spawn. Recommended.
6. **Quest credit.** A wandering wolf or rat counts toward the wolf and rat quests (the
   substring match does it today with no change). Recommended to keep. The alternative is
   exact-name matching for those quests.
7. **Timing.** Recommended right after the door (11-19), not before. It can go before if
   wanted, since it needs no zip.
8. **Night spawns and new species**: now, later or never.

---

## 10. Review, 2026-11-16

Three passes against the code after the decisions, each finding corrected in the body above.
The first two:

| Finding | Corrected in |
|---|---|
| Adders and vipers matched no loot table and no beast word: no snake loot, and coin like a humanoid. | 3.1 load check, 5 row 9, 6 names |
| A home reset in `transition` would fire on a charm ending, often in town. | 3.5 |
| The harness runs the real camp file: 70 animals in every integration test, rats over the Bonepile walk. | 4.1, 8 harness |
| `Spawner::tick` has no player positions; linkdead bodies count. | 3.3 |
| One entity per spawn point: a pack member's death would spawn a second pack. Membership must follow the slot (ids change on charm). | 3.8 |
| Waiting for a pack's last member lets anyone block the pack. | 3.8, 5 row 11 |
| Night had no numbers and the server has no idea of night (400 s of dark a day); a daylight respawn; a hurt animal at dawn. | 3.9, 6 |
| Ghosts raise town standing and good alignment per kill. | 5 row 12, 6 |
| The stuck clock carries between goal-less walks; 8 s is hard-coded. | 3.4 |
| Roam/camp load checks; dev-spawn faction for roam names; hidden players in social aggro. | 3.1, 3.8 |
| Mobs may walk down faces (only rising onto one is refused), and leg sampling can miss a face. | 3.4, 5 row 5 |
| The player walk map holds faces and one-way pockets. | 3.2 |
| Animals stranded outside their region (the ridge refuses the straight leg home). | 3.6, 5 row 13 |
| No way back without a rebuild if it misbehaves at the door. | 4.1 |
| Parked pets are targets for every mob, so roamers will find them. | 8 playtest |
| Roaming must obey root and snare. | 3.4 |
| A moving mob is seen only by viewers; the region centres came from map coordinates. | 8 tests, 3.1 |

A third pass the same day:

| Finding | Corrected in |
|---|---|
| A slot's head count that left out charmed members would refill during a charm and overfill after it: a charm-and-wait farm. | 3.8, 5 row 14 |
| Social aggro could hand a packmate a target past its own leash, which `tick_chase` drops at once (a flap into an evading walk home). | 3.8 |
| The client tools' camp parser splits on `[[camp]]`, so roam entries appended to `zone_camps.toml` would be read as part of the last camp. The roam data moves to its own file. | 1, 2, 3.1 |
| Roam refusals must not feed `slope_refusals` (a modified-client signal); a roamer must face the way it walks. | 1, 3.4 |
| The stray and daylight removals need the despawn path without the death timer. | 3.6 |
| Roam regions belong in the safe-area aggro test; the integration tests need small regions and short respawns to be deterministic. | 3.1, 8 tests |
| (User rule, verified after it) The charm arm lets a caster hold any number of charmed mobs; a summon with a charm up kills the charmed mob. Decided: one rule for every pairing (a new pet replaces the old; a charmed one is handed back angry), one helper. | 3.10, 8 step 0 |

A fourth pass (Fable, 2026-11-16, before and during the build):

| Finding | Corrected in |
|---|---|
| The shared release helper would have handed back a charmed pet that had already died (its body lingers 5 s): a 0 HP mob the stray sweep kills, dropping loot for no fight (the Sable faucet of 2026-11-09). | 3.10, 5 row 15 |
| Packs came apart after a fight: a member that joined through social aggro kept its old home and walked back to it alone, and a separated follower never rejoined. Social aggro now moves the joiner's home, is asked every tick, and a follower regathers on its leader. | 3.8, 3.5 |
| The stray rule was unnecessary: every fight ends with the walk home, and home is ground the roamer stood on in its region. | 3.6, 5 row 13 |
| The stuck-clock worry was unfounded (`transition` clears it on every state change), and a refused roam step is refused identically every tick, so the leg ends at once with no clock. | 3.4 |
| `move_speed` does not carry snare; the roam step applies it by hand, as the chase does. | 3.4 |
| The AI step sleeps while nobody is online; the night gate, the daylight removal and pack refills belong to the spawn step, which always runs. | 3.9 |
| The head count is read from the world when a slot is due, not kept as a counter. | 3.8 |
| Two floor angles (the slope rule's 60, the body's 55): the roam map uses the 55 for everything, with edge-sharing neighbours. | 3.2 |
| A ring round the town crosses the ridge into the Greywood (reachable through the pass); regions take a z band. | 3.1, 6 |
| The claim that a caster could hold several charmed mobs "today, in the live game" was wrong: each charm's cooldown is at least its duration, so only the data prevented it. | 3.10 |
| A charm wiped the mob's damage record and kept its wounds: charm a nearly dead mob, release it, take the kill. Older than this work; the instant release would have made it a two-cast trick. | 3.10, 5 row 16 |
| Aggressive level 1 rats with a 12 m sight in the starter ring would add to a newcomer's first fights. | 6 |
| The harness's default plate (400 m) lies almost wholly inside the town clearance; a watcher within 60 m blocks a respawn; the wall clock decides night. | 8 |
| The rat quest's client text said "in the cellar" while Field Rats would roam beside the Rat Warrens. | 4, 9 |
| A follower's straight line to a far leader could cut through the town. | 3.8, 5 row 1 |

---

## 11. As built (2026-11-16, night)

**Where:** server `feat/wandering-wildlife` in `F:\Projects\server-wildlife` (two commits on
`a3b226d`: `c1758f0` one pet at a time; `f388b96` the roamers, packs and night); client
`feat/wandering-wildlife` in `F:\Projects\Project_Dawn-wildlife` (`b73a6a9`: the rat quest's
target and text, the night hours named in `time_of_day.gd` with their lockstep pair, the docs
and the checklist). **Merged 2026-11-17:** both deploy branches fast-forwarded to those commits
and pushed, all 17 client checks green on the merged pair; not yet deployed.

**Deploy shape:** the server half needs no client change, no wire change and no migration: it
reaches players with a redeploy and works with the door zip. The client half is cosmetic (a
quest line's text) plus tooling; it can ride any zip. `tools/check_constant_lockstep.gd` gains
the night hours, so the two branches merge together (the client check would report the server
constants MISSING against a server without them).

**Not built, flagged:**
- A stunned or mezzed leader's followers still follow (they stand within 4 m of it).
- Wanderers stand still while nobody is online (the AI step sleeps); positions are not saved,
  so a restart places everyone afresh.
- A follower separated by a cliff with no straight way round roams alone in 30 s spells until
  its leader comes back within a straight walk; a pack can stay split for a while on hills.
- Night animals removed at dawn simply vanish when unseen; one watched through dawn stays
  until the watcher leaves.
- No species tint or shape on the client: every animal is the shared capsule.
- The far reaches' three places share one region, so the grizzlies, hill wolves and rock
  vipers split between them by area and by chance.
- Charm stacking and the cross pairings (a charm with a summoned pet out) cannot be reached by
  a cast today, so they are held by unit tests on the helpers, not by a cast in an integration
  test.
