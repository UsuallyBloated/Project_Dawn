# The server height model (design, 2026-11-03)

Phase 5, Track D item 1 (`docs/design/phase5_plan.md`; the user, 2026-11-03: "Claude will be
building the height model"). The server learns the ground, so the vertical axis stops being a
fiction it measures distances with. This is the design pass; nothing is built. The calls that
belong to the user are in section 8, each with a recommendation. The brief this answers is
`docs/session_notes/handoff_server_height_model.md`; the research it grows from is
`docs/design/zone_size_limits.md` sections 3 to 6.

Every code claim below was read on 2026-11-03 on `bump/nov` in both repos (server
`a40252b`, client `5bce7a2`), the base the build branches from. Paths are given by file and
function, since the line numbers move.

## 1. What exists today

**The server has no Y, and measures in 3D anyway.**
- The Move handler (`handlers.rs`, the `ClientWorldMsg::Move` arm) builds the stored direction
  with `y: 0.0` ("server does not simulate gravity or jumping") and clamps it to length 1. The
  NaN gate before it drops a non-finite direction or yaw (built 2026-09-27).
- `tick/movement.rs::run_movement` integrates `pos.x` and `pos.z` only. A player's `pos.y` is
  whatever it was loaded with.
- `Vec3f::step_toward` (`connection.rs`) keeps the mover's `y` and moves it in XZ, but takes its
  direction and its arrival test from the **3D** delta. A mob below its target therefore steps
  more slowly the taller the gap, and one directly below its target never arrives.
- `Vec3f::distance_to` is 3D and is what nearly every range check uses: melee, spell reach,
  AOE, resurrection, corpse and bag loot, the group share range, NPC service range, mob aggro,
  leash and melee, pet AI, the say range.
- Camp spawns copy the camp's authored `y` (`spawn_points.rs`); pets spawn at the owner's `y`
  (`tick/pet_life.rs`); corpses and loot bags take the victim's position. Every `y` in
  `zone_camps.toml`, `npcs.toml` and `safe_areas.toml` is 0.0.
- The wire already carries Y everywhere it matters: `Position`, `EntitySpawn` and `Teleport` all
  carry a full vector, and the wire layer hands all three components to Godot
  (`gdext-net/src/lib.rs`, the `position` and `teleport` signals). Nothing about this model
  needs a protocol change.

**The client's ground is exactly two things** (`scenes/world.tscn`, the only scene with
collision):
- `TerrainMesh` (`scripts/terrain_mesh.gd`): a grid of `grid_size` x `grid_size` cells of
  `cell_size` metres (20 x 20 cells of 20 m today, so 400 m across), centred on the node's
  origin, with `(grid_size + 1)²` heights stored in the scene. Each cell is two triangles, always
  split on the same diagonal: `(x0, z0), (x0, z1), (x1, z0)` and `(x1, z0), (x0, z1), (x1, z1)`.
  The collider is a trimesh of exactly those triangles. All heights are 0.0.
- `Floor`: a `WorldBoundaryShape3D` at the default plane, y = 0, under everything and to every
  horizon. Terrain below 0 is unreachable (the plane is solid below); past the terrain's edge the
  floor is the ground.

**The local player** keeps its own Y: gravity 20 m/s², `floor_max_angle` 55°,
`floor_snap_length` 0.5 m (`scripts/player.gd`). Reconciliation blends XZ only. The server's
`Teleport` sets all three axes (`autoloads/net.gd::_on_teleport`). The body's origin is its
feet (the capsule sits at half its height), so a server Y means the ground under the feet.

**Remote players, mobs, pets, corpses and bags** draw at the server's position verbatim,
interpolating between snapshots (`remote_player.gd`, `remote_enemy.gd`, `remote_pet.gd`,
`remote_loot_bag_manager.gd`). On a hill they would sink or float today.

## 2. What other games do

- **EverQuest** keeps zone geometry on the server (EQEmu loads each zone's `.map` file of
  triangles and samples it with `FindBestZ` for mob placement and pathing, plus `.wtr` for water).
  Its movement is client-reported, so the server uses the map to place what it simulates (mobs,
  corpses) and for line-of-sight, not to decide where a player stands.
- **World of Warcraft** servers load height maps extracted from the client data (TrinityCore's
  `.map` files from its extractor, plus `vmaps` for buildings and `mmaps` for navmesh), and use
  them for ground height, line-of-sight and mob pathing. Movement is again client-reported.

Both keep the server's ground as data extracted from the client's own files, which is the shape
here. Unlike both, this project's client never sends a position, so the server can own where
the player stands as well.

## 3. The design

### 3.1 The data: one file, extracted from the scene, compiled into the server

`crates/projectdawn-server/data/terrain.toml`, written by a headless Godot script
(`tools/export_terrain.gd`, run like the checks) and never by hand:

```toml
# Written by tools/export_terrain.gd from scenes/world.tscn. Do not edit.
grid_size = 20
cell_size = 20.0
origin = [0.0, 0.0, 0.0]     # the TerrainMesh node's global position
floor_y = 0.0                # the Floor plane's height
heights = [0.0, 0.0, ...]    # (grid_size + 1)^2 values, row-major by z then x
hash = "..."                 # SHA-256 of the canonical bytes, so a hand edit is refused
```

The hash covers the canonical bytes (the grid size as a u32, then every float's IEEE-754 bits,
little-endian), built the same way on both sides, and the exporter hashes the values it wrote
(the text parsed back), so neither side's float formatting can make the two disagree. The
server refuses a file whose hash does not match its heights at first use, which `main` makes
the boot line. (As built 2026-11-04; the sketch said `sha256` of a line of text.)

It is compiled in with `include_str!`, the pattern every other data file uses (`npcs.rs`,
`items.rs`): the binary the R720 runs carries its own ground, so the server cannot boot with a
terrain file from another build. Today's file is 441 numbers. A text file is fine to a few
hundred thousand heights; the 4 km zone `zone_size_limits.md` allows would be about four
million, which wants a binary sibling (`include_bytes!`, the same header). That is a decision
for the first large zone, not this build.

### 3.2 The sampler: the client's own triangles, exactly

`world/terrain.rs::ground(x, z) -> f32`:
1. A non-finite `x` or `z` returns `floor_y`. (The NaN gate means none reaches it; the sampler
   is total anyway, the handoff's invariant 3.)
2. Outside the grid's extent: `floor_y`, which is what the client stands on there.
3. Inside: find the cell, pick the triangle by which side of the cell's diagonal the point is
   on, and interpolate the plane through its three corners. Return `max(that, floor_y)`.

Because it uses the same corners, the same diagonal and the same floor, it agrees with the
client's collider at every point, up to float rounding. (Bilinear interpolation, the obvious
choice, differs from the triangles inside a twisted cell by up to a quarter of the twist: on
20 m cells with a 4 m twist, a metre. That is the Δy problem again in miniature, so the sampler
does not use it.)

Also `slope_ok(from, to) -> bool` for section 3.4, and `ground_vec(pos) -> Vec3f` (the same XZ
with the ground's Y) as the one helper every pinning site calls.

### 3.3 Who is pinned, and when

| What | Today | With the model |
|---|---|---|
| Player, each tick | XZ integrated, Y untouched | After the XZ step, `y = ground(x, z)` (3.4 for the slope rule). |
| Player, entering the world | the saved `pos_y` | Re-pinned: the terrain may have changed since the save. |
| Player, any teleport (respawn, Gate, Succor, Evacuate, resurrection) | the destination's stored Y | Re-pinned at the destination before the `Teleport` is sent. A bind point stores Y too; it is re-pinned at use. |
| Mob, at spawn | the camp's authored `y` | `ground` at the jittered spawn point. |
| Mob, moving (`step_toward`) | Y kept; direction and arrival from the 3D delta | Step in XZ by the XZ delta (so a gap below the target no longer slows or strands it), then `y = ground`. |
| Pet, at summon and on every move | the owner's Y, then `step_toward` | As mobs. |
| Corpse, at creation | the victim's position | Re-pinned. A loot bag takes the position of a body that is pinned already (the dropper, the slain mob) and needs none. |
| Corpse, loaded at boot | the saved `pos_y` | Re-pinned, so a corpse is never left in the air or underground after a terrain edit (the handoff's invariant 5). |
| NPCs, safe areas, the starter spawn | authored `y` in the toml | Derived from `ground` at load (decision 4). |
| GM dev spawn | the GM's Y | Re-pinned like a camp spawn. |

Nothing else changes. The range checks stay 3D and become correct: a mob on a 5 m rise and a
player at its foot close to melee, because both stand on the same slope.

### 3.4 Slopes the client cannot climb

The client's body cannot walk up ground steeper than 55°; the server's integration has no such
limit. On today's flat world that never matters. On hills it means a modified client can walk
up a cliff an honest one is stopped by, and stand where nothing that obeys the client's physics
can follow (a perch). It is the terrain half of the open "no server collision" finding (exploit
audit finding 10b).

The proposal (decision 1): the server refuses a step whose rise is steeper than the client's
limit, with a margin so an honest player is never refused. Per tick a player moves at most
about 0.41 m (5 m/s x 1.65, Selos' Melody at level 50, x 0.05 s); the rule, per tick, is
`rise <= run x tan(SLOPE_LIMIT) x (1 + SLOPE_SLACK)`, with `SLOPE_LIMIT` 60° (the client's 55°
plus five) and `SLOPE_SLACK` a tenth of a percent for float rounding. The slack is a fraction of
the allowed rise, never a fixed height per step: the first cut allowed a centimetre a tick on top,
and the review of 2026-11-04 showed what that buys a forged client, steps too short to measure
against the angle (a direction of length 1e-4, 25 µm a tick) climbing any face at 20 cm/s. An
angle holds whatever the step's length. The client's 0.5 m `floor_snap_length` does not belong
in it either: snapping keeps a body on the ground going down, it does not lift one up, and half
a metre allowed on every tick would let a forged client climb a vertical wall at 10 m/s. A refused step leaves the player where they were for that tick, which
an honest client never sees (its own collider stopped it first), and the existing XZ
reconciliation pulls a forged one back. Each refusal is counted and reported once a minute on
the `world health` line as `slope_refusals` (built 2026-11-04 on the user's go; the line also
prints for a window with a refusal and nobody left online, so a count never goes unreported).
On flat ground none can happen, so a count there is a modified client or a scene edit nobody
exported; on hills a Move carries the player's input, not what their body managed, so a key
held into a cliff counts too, honest or not (the review's point), and there the number is a
curiosity, not evidence. The counter says how many, not who.

**The rule judged a step's own grade, and that was not enough (found 2026-11-04 night while
building the first hills; server `d5de613`).** On a face of gradient g, a step at angle φ to
straight uphill climbs at g·cos φ, so a 45° diagonal went up a 63° face at 55° and a zigzag
climbed any face at all: the Wraith Gate's cliff, the plate's rim. The honest body cannot (it
slides off ground past its floor limit whichever way it faces). The rule now has a second
half: a step that rises is refused when the ground it lands on is steeper than
`SLOPE_LIMIT_DEG`, whatever its direction. Test `a_diagonal_climbs_no_face` (a diagonal step,
and a zigzag walker from a face's foot); `nobody_climbs_out_over_the_rim` walks hasted
zigzags at the real rim all the way round.

**Measured 2026-11-04 (`tools/probe_ramp_speed.gd`, a headless probe that runs the real
player scene on a tilted slab):** straight uphill the body covers exactly `cos²θ` of the flat
distance (15°: 4.665 m/s, 30°: 3.75, 45°: 2.5, 50°: 2.04, of 5), across a slope the full
5 m/s, downhill the full 5 m/s (the floor snap keeps it on the surface), and past the 55°
limit it slides down. That is `move_and_slide` sliding a horizontal motion along the floor
plane: the motion loses `sin²θ` of its part up the slope. So the server takes the same step
(`Terrain::player_step`): the gradient of the triangle under the player, the step's part along
the ascent shrunk by `sin²θ` when it climbs, untouched otherwise, then the slope rule, then
the pin. Without it the server would have led an honest client by a quarter of its speed on
every 30° hill, which the XZ reconciliation would have shown as a pull up the slope.

### 3.5 Mobs on steep ground

Mob pathing stays straight-line (no navmesh; the handoff keeps it out of scope). So a mob
chasing a player up a slope steeper than 60° either climbs it (looks wrong, but nothing is
unreachable) or stops at its foot (looks right, and the player above is safe from melee while
their spells still reach 30 m down). EQ's answer was the second plus a rule: an unreachable mob
regenerates and walks home, so a perch is never a free kill. Decision 2: (a) was built in
slice 1, a mob's step neither shortened nor refused; **(b) is built with the first hills
(2026-11-04, server `8d21d97`).** Every mob and pet step goes through the player's own slope
rule (`Entity::step_on`, so a diagonal onto a face is refused too); a refused step starts a
clock, and after `MOB_STUCK_SECS` (8 s, a knob): a chasing mob forgets everyone and walks
home, where it heals to full (and every watcher is told its HP, which a leash never used to
fan); a mob walking home up a face it came down warps home; a pet following its owner warps
to them; a pet attacking drops a target it cannot reach. Mobs still take a slope at full
speed (no `cos²θ` for them) and still have no way round a face. The review pass of the same
night made the clock a progress clock keyed to its goal (1 m closer, `STUCK_PROGRESS_M`, or a
new goal, stops it; a step taken does not) and made giving up forget only the unreachable
target (`094ec29`). **Open, a decision for the user:** the perch. The Greywood crest is
walkable from the ridge's ends, and from its north edge a crypt champion can sit inside spell
reach; the mob is held at the foot, takes damage for the 8 s and its walk home, and heals only
at home, so a caster with enough damage kills it at no risk. Recommended: an evading mob
(immune while held below a face past a short grace and while it walks home after giving up),
the WoW answer.

### 3.6 What this model does not cover

- **Caves, overhangs, bridges and stacked floors.** One height per XZ. Multi-level spaces need
  real Y tracking and are their own epic (the multi-zone and procedural dungeon work).
- **Buildings and props as ground.** The terrain is the only collision in the world today. A
  walkable building would need its own shape on the server; until then, buildings are drawn on
  flat ground and walked around, not on.
- **Walls, buildings and props as sight blockers.** Terrain line of sight is section 3.8; the
  rest of exploit finding 10b (a modified client casting through a wall) stays open until the
  server has a shape for buildings.
- **Water and swimming.** No water exists.
- **A second ground in one process.** The NPC and safe-area tables are process-wide
  (`OnceLock`), so they stand on the compiled ground, while the world may run the harness's
  (`Config::terrain`). One binary, one terrain, so it never matters on a server; a test ground
  must keep the town flat (the test terrain asserts it), and a per-world table is the day a
  second zone arrives.

### 3.7 Falls

The server-simulated fall is slice 1 of `docs/design/server_fall_damage.md`, all five of its
decisions taken on 2026-10-24. It needs exactly `ground(x, z)` and the grounded-or-airborne
step in its section 3.2: follow the ground down a slope the client follows, go airborne off a
steeper drop, land with damage by its formula. It rides here as slice 2, after the ground is
pinned and proven, so a mistake in one cannot hide in the other.

### 3.8 Line of sight through the terrain

Decision 5, the user's call of 2026-11-03: built now, with heals and buffs needing sight too.
Today a spell, an arrow and a mob's eyes all reach through a hill, because the server has no
hill. With the ground in hand, terrain line of sight is one more sample along a segment, and it
closes the shape of every from-safety exploit the first hills would otherwise open: a nuke from
behind a ridge, an arrow over a crest, a heal out of a hollow nobody can reach.

**The test.** `terrain::can_see(a, b) -> bool`. The segment from `a` to `b`, each raised by
`LOS_HEIGHT` (1.2 m: chest height for a human, head height for a gnome, above a rat entirely;
one constant for everything until creatures carry a height), must stay above the ground the
whole way. Inside one triangle the ground is a plane and the segment is a line, so their
difference is linear there, and it is enough to evaluate the clearance where the segment
enters and leaves each triangle (every cell edge and cell diagonal it crosses) plus the two
ends: if all of those are above the ground, so is everything between. The floor keeps that
true (`ground` is `max(mesh, floor_y)`, so the clearance is the smaller of two linear
functions on each piece, and that is lowest at an end). Exact for the client's collider, no
step size, no thin ridge stepped over. A clearance down to `LOS_TOLERANCE` (1 cm) below the
ground still counts as sight, so a cast along flat ground never fails on rounding. A 30 m
segment crosses at most three 20 m cells each way, about a dozen samples; the aggro scan adds
it only to candidates already inside the aggro radius. The test is total: a non-finite endpoint
is no sight, the safe answer, since a refusal costs nothing. It is symmetric by construction,
the same two raised points either way, so whatever can see you, you can see.

**What needs sight.** EQEmu is the reference, read 2026-11-03 on its master: `Mob::SpellFinished`
refuses a DETRIMENTAL spell whose target fails `CheckLosFN` at the cast's finish
("You cannot see your target."), and beneficial spells are exempt there; `Mob::CheckWillAggro`
lets an idle NPC notice only a target it can see, and an NPC already on a hate list keeps its
target without sight; `Client::RangedAttack` has no sight check while `NPC::RangedAttack` has;
the endpoints are a fraction of each body's height (size 6 by default). Ours is stricter in two
places, by the user's calls and the exploit lens:

| What | Sight | Why |
|---|---|---|
| Every targeted spell: ENEMY, ALLY on another, PET_CHARM, PET_HEAL, CORPSE (resurrection), BIND on a group member | Required, caster to the resolved target, in `cast_target_refusal` once after the target resolves, so one site covers every arm; "You cannot see your target." at no cost | The user: heals and buffs too (EQEmu exempts them). |
| A spell on oneself, a summon, a port, the cast of a point-blank AoE | None | Nothing to look at. |
| An AoE's victims | Each needs sight from the caster; one that fails is skipped, no line | An AoE on a crest hits the near side of the ridge and not the far one. (EQEmu's per-victim rule was not found in the read; this one is ours.) |
| A ranged attack (bow) and a ranged damage skill, on a mob or a player | Required; without it the swing answers as an out-of-reach one does, a Miss fanned, nothing landed | A bow over a crest is the nuke's exploit with a string. Stricter than EQEmu's player archery. |
| Melee, and a melee skill | None | Reach is 2.7 to 4.5 m and cells are 20 m wide, so no crest can stand between two bodies inside melee reach; a check would only cost. |
| An idle mob noticing a player (the proximity scan, `nearest_target_within`) | Required | EQEmu's `CheckWillAggro`. A player in a hollow is unnoticed, and the same test says they cannot cast out of it. |
| A mob turning on whoever damaged it, a mob chasing, a pet following or attacking | None | EQ's rule: on the hate list, sight is not needed. Whoever hit the mob had sight to do it, and the mob chases over the crest (3.5). |
| A song's pulse on its target (Aria of Dismay) | Required at each pulse, skipped out of sight as it is skipped out of reach | A targeted effect, the spell rule. |
| Effects already applied (DoT ticks, HoTs, buffs, slows) | None | They are on the target; EQ's rule. |
| Loot, trade, bank, vendor, inspect, `/con`, Evacuate's gather, the say range | None | Not sight. |

**When.** At the release (`CastSpell`), where the pre-flight runs: EQEmu's timing. The CastStart
carries only the stun, the global cooldown and the fizzle, and gains nothing: a target that
walks behind a crest during the bar breaks the spell at the release, as one that walks out of
reach does. The client's own check comes with the hills (slice 3; it needs the hills to matter
and rides the export that brings them): a Godot ray against the terrain collider between the
same two raised points, before the bar and before a ranged swing, so an honest player gets the
line with no round trip and never starts a bar the server will refuse; the server's refusal
then marks a modified client, as every other pre-check does.

**As built (2026-11-04 night, client `2f97a4a`):** `Spells._target_out_of_sight`, for the
targets the reach check takes (an enemy, a charm, an ally who is someone else), after the
reach refusal and before the bar, with the server's line. The terrain body and the floor sit
on physics layers 1 and 2 (`project.godot` names 2 `terrain`); the ray asks for layer 2 only,
so no body, corpse or bag blocks it. `LOS_HEIGHT` is a lockstep pair. Not built: the check
before a ranged swing (a bow still gets the server's Miss), and the corpse, pet-heal and
bind-on-another cases (the server's line, a round trip later). `tools/check_terrain_sight.gd`
(in `check_all.ps1`) holds the ray to a port of `can_see` in the exporter over 3,000 random
pairs on the real hills: no disagreement.

**On today's world** every clearance is `LOS_HEIGHT` and every test passes: nothing changes
until the first hills.

**Not covered:** walls, buildings and props (3.6); water; a creature's real height (one
constant for all).

## 4. Lockstep: keeping the two grounds the same

A server ground that disagrees with the client's is worse than none, so staleness must be loud.
- `tools/export_terrain.gd` (editor tool) reads `TerrainMesh` and `Floor` from `world.tscn` and
  writes `terrain.toml` into the server repo.
- `tools/check_terrain_lockstep.gd` compares the two and exits 1 on any difference, including a
  moved node and the floor. It joins `tools/check_all.ps1`, so the existing pre-export run catches
  a terrain edit nobody exported.
- The same check places each NPC from `npcs.toml` and confirms its node in `world.tscn` stands on
  the ground (within 5 cm) at the same XZ (within 5 cm). No NPC position check exists today;
  this one comes free with the sampler.
- It also compares the scene's `TerrainCol` triangles with the triangles its heights make, so a
  mesh edited in the editor and never rebuilt (the client drawing and exporting one ground and
  colliding with another) fails the check too.
- The server logs the terrain's size and hash in its boot line, so a deploy shows which ground it
  runs.
- `export_spells.gd`'s lesson (an exporter nobody runs goes stale) is why the check, not the
  exporter, is in the gate.

## 5. Exploit ledger

| # | Attempt | Answer |
|---|---|---|
| 1 | Send a vertical position or velocity | Nothing vertical is read from the client. The Move direction's Y is already zeroed; Y comes only from `ground` at the server's own XZ. The jump flag stays cosmetic. |
| 2 | Feed the sampler NaN or infinity | The NaN gate drops the Move before it touches state; the sampler is total and returns the floor for a non-finite input. |
| 3 | Walk off the terrain's edge to a place with no ground | The floor height, exactly what the client stands on there. No world bounds exist and none are needed for this. |
| 4 | Climb a cliff the client cannot, to a perch | The slope rule (3.4, decision 1). |
| 5 | Hit or cast down from a height | Reach stays 3D, so height now counts against it (it did not before, on authored-Y camps). Through the terrain, nothing reaches: 3.8. |
| 6 | Exploit a server ground that differs from the client's | Exact triangle sampling; the lockstep check in `check_all.ps1`; the boot line's hash. |
| 7 | Get ported into the ground or onto a slope's air | Every teleport destination is re-pinned before it is sent. |
| 8 | Leave a corpse unreachable by editing nothing (an old save after a terrain change) | Corpses and characters are re-pinned at load; the res and loot ranges then measure from the ground. |
| 9 | Strand a mob under its target, or pull one up a slope at half speed | `step_toward` steps by the XZ delta. |
| 10 | Kite a mob up a slope it cannot climb | Decision 2; with the second option, an unreachable mob goes home and nothing is a free kill. |
| 11 | Save a character mid-air | Not possible in slices 0 and 1 (no airborne state). Slice 2 takes the fall design's ledger rows 4 to 6 (logout, crash and teleport mid-fall). |
| 12 | Cast, heal or shoot through a hill | Refused at the release, "You cannot see your target.", nothing spent; a bow's swing misses; an AoE skips what the caster cannot see (3.8). |
| 13 | Hide in a hollow and farm | A mob cannot notice what it cannot see, and the same symmetric test says the player cannot cast or shoot out of the hollow; the first hit puts the attacker on the hate list, and from there the mob chases without sight. |
| 14 | Cast with sight, then step behind the ridge | The DoT ticks on and the mob keeps chasing: sight is for noticing and for a new cast, not for staying engaged, so the far side of a ridge is not a safe side. |
| 15 | Feed the sight test NaN or infinity | Total: no sight, a refusal, nothing spent; positions are the server's anyway (row 1). |
| 16 | A thin ridge the sight test steps over | There is no step: the clearance is checked where the segment crosses every triangle edge, exact for the piecewise-planar ground. |
| 17 | Climb a cliff with steps too short to measure | The slope rule is an angle with a relative slack, so a 25 µm step up a 70° face is refused like a 25 cm one; ten thousand of them go nowhere (`micro_steps_climb_no_face`). The review of 2026-11-04 found the first cut's fixed allowance let them through. |

## 6. Slices

**Slice 0: the ground, read only.** `terrain.toml` (today's flat terrain), `world/terrain.rs`
with the sampler, the boot line, the export tool, the lockstep check in `check_all.ps1`. No
behaviour changes; on today's world `ground` is 0 everywhere. Server and client tooling, no
redeploy needed for players, no export. **BUILT 2026-11-04** (server `9c16f12`, client
`2980120`, both on `feat/height-model` from `bump/nov`).

**Slice 1: everything stands on the ground, and sight is through it.** Section 3.3's table, the
slope rule, the step_toward fix, re-pinning at load, and terrain line of sight (3.8) as its own
commit on the same branch, since it needs the ground and the entities' real Y. Still no visible
change on the flat world, which is the point: the regression playtest is "nothing changed", and the integration tests on a test terrain
carry the proof. Server only, one redeploy, no export, no protocol change. **BUILT 2026-11-04** (server `feat/height-model`; the session note of
that day has the commits; `height_model_checklist.md` is the regression sheet, after the
November bump's redeploy).

**Slice 2: falls.** The fall design's slice 1, on this ground.

**Slice 3: the first hills** (Track D item 4, its own plan when it starts): client terrain
chunking, a heightmap brush or import, the first authored slopes, NPCs placed on them. This is
the first slice testers see, and it needs an export.

## 7. Tests

- **Sampler, unit:** every vertex returns its height exactly; points on the diagonal and inside
  each triangle match the plane through its corners; a brute-force ray test against the same
  triangles agrees on a few thousand random points; edges and corners; outside the extent returns
  the floor; a valley below the floor returns the floor; NaN and infinity return the floor; the
  toml's hash refuses a hand edit.
- **Movement, unit:** the slope rule's boundary (a 59° step taken, a 61° step refused, a
  vertical face refused at every speed); `step_toward` reaches a target directly above it.
- **Integration**, on a test terrain the harness supplies (the terrain becomes part of the world
  state built at boot, defaulting to the compiled one, so a test can hand in a ramp): a mob on a
  5 m rise closes to melee and hits a player at its foot (fails on today's code, which leaves the
  mob at its camp's Y); a player walking up the ramp is fanned rising Y; respawn at a bind point
  on the ramp arrives on the ground; a corpse on the slope is resurrected and looted; a forged
  climb up a 70° face is refused (if decision 1 is yes). The rest of the suite runs on the flat
  compiled terrain unchanged.
- **Sight, unit:** the flat world sees everywhere; a ridge between two points blocks, and the
  same ridge lowered under the line does not; symmetric; a target on the crest is seen from both
  feet; a segment grazing a slope inside the tolerance sees; non-finite is no sight; and a
  brute-force march at 1 cm along a few thousand random segments over a random terrain agrees
  with the edge-crossing method (the proof that the shortcut is exact).
- **Sight, integration** (on a ridge terrain): a Smite across the ridge is refused with the line
  and the mana untouched, a Greater Heal on a group-mate across it too (the user's call), and
  both land once the caster steps onto the crest; a mob 8 m away behind the ridge never notices
  the player and turns the moment they walk over the crest; an AoE on the crest hits the near
  mob and skips the far one; a bow across the ridge fans a Miss and lands nothing; a DoT cast
  with sight keeps ticking after the caster steps behind the ridge.
- **Client:** `check_terrain_lockstep.gd` catches a planted height, a moved node and a moved NPC.
  With the hills (slice 3), a probe asks the client's ray and the server's test the same
  segments over the same ridge and fails on a disagreement.
- **Playtest checklist** for slice 1 (regression only on the flat world: movement, combat,
  camps, death and corpse, ports, pets, NPC services) from `TEMPLATE_checklist.md` when it lands.

## 8. Decisions for the user

**ALL SIX DECIDED 2026-11-03 (user): "Yes to all, 5 in important too."** 1, 2, 3, 4 and 6 as
recommended. **5 changed: terrain line of sight is built now, with slices 0 and 1**, not
later; and **heals and buffs need line of sight too** ("Heals and buffs require line of
sight"), so every spell with a target needs it, friendly or hostile. A spell with no target
(a self buff, a point-blank area spell) has nothing to look at. The line of sight section is
written before the build and the plan said to the user first. The questions as asked:

1. **The slope rule for players.** The server refuses a step up ground steeper than 60° (the
   client's 55° plus a margin). Recommended: yes. It closes the perch for a modified client and
   never touches an honest one.
2. **Mobs on ground too steep to climb.** (a) Climb anything, for now; or (b) stop at the foot,
   and an unreachable mob walks home and regenerates (EQ's rule). Recommended: (a) in slice 1,
   because today's world has no steep ground, and (b) with the first hills (slice 3), when there
   is something to tune it against.
3. **The terrain's edge.** Past the mesh, the ground is the floor (what the client does today).
   Recommended: keep that, and give a future hilly zone a visual edge (cliffs, water, a wall) so
   nobody walks off the terrain into the flat beyond.
4. **Authored Y in `zone_camps.toml`, `npcs.toml` and `safe_areas.toml`.** Derive it from the
   ground and drop the field, or keep it authorable. Recommended: derive it; an authored Y that
   disagrees with the ground is the foot-gun `zone_size_limits.md` warned about. *(Built as:
   the loaders derive it and the files keep their `0.0` placeholder, since three loaders and
   the client's own readers of `npcs.toml` share the three-number shape; the placeholder is
   never read.)*
5. **Terrain line of sight** for spells and ranged attacks. Recommended: not now; a later slice
   once the first hills show whether casting through a ridge matters in play.
6. **Order:** slices 0 and 1 together on one branch from `bump/nov` (server `refactor/tick-split`
   is in it), redeployed after the bump; falls (slice 2) next; the first hills (slice 3) as their
   own plan. Recommended: yes.
