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

`crates/projectdawn-server/data/terrain.toml`, written by a Godot editor tool and never by hand:

```toml
# Written by tools/export_terrain.gd from scenes/world.tscn. Do not edit.
grid_size = 20
cell_size = 20.0
origin = [0.0, 0.0, 0.0]     # the TerrainMesh node's global position
floor_y = 0.0                # the Floor plane's height
heights = [0.0, 0.0, ...]    # (grid_size + 1)^2 values, row-major by z then x
sha256 = "..."               # of the line above, so a hand edit is caught at boot
```

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
| Corpse and loot bag, at creation | the victim's position | Re-pinned. |
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
`rise <= run x tan(SLOPE_LIMIT) + SNAP_ALLOWANCE`, with `SLOPE_LIMIT` 60° (the client's 55° plus
five) and `SNAP_ALLOWANCE` a centimetre for float rounding. The client's 0.5 m
`floor_snap_length` does not belong in it: snapping keeps a body on the ground going down, it
does not lift one up, and half a metre allowed on every tick would let a forged client climb a
vertical wall at 10 m/s. A refused step leaves the player where they were for that tick, which
an honest client never sees (its own collider stopped it first), and the existing XZ
reconciliation pulls a forged one back.

**Measured before it is built, not assumed:** how far an honest client moves per second up a
30° and a 50° ramp. Godot's `move_and_slide` projects the velocity onto the floor, so the
client may cover less ground uphill than the server's flat 5 m/s, which the reconciliation
would show as a gentle pull forward on every hill. A headless probe on a ramp settles it; if the
gap is real the server scales the step by the same projection.

### 3.5 Mobs on steep ground

Mob pathing stays straight-line (no navmesh; the handoff keeps it out of scope). So a mob
chasing a player up a slope steeper than 60° either climbs it (looks wrong, but nothing is
unreachable) or stops at its foot (looks right, and the player above is safe from melee while
their spells still reach 30 m down). EQ's answer was the second plus a rule: an unreachable mob
regenerates and walks home, so a perch is never a free kill. Decision 2.

### 3.6 What this model does not cover

- **Caves, overhangs, bridges and stacked floors.** One height per XZ. Multi-level spaces need
  real Y tracking and are their own epic (the multi-zone and procedural dungeon work).
- **Buildings and props as ground.** The terrain is the only collision in the world today. A
  walkable building would need its own shape on the server; until then, buildings are drawn on
  flat ground and walked around, not on.
- **Line of sight.** Spells and arrows still reach through a hill. The heightmap makes a terrain
  line-of-sight test cheap (sample along the segment), so it is a natural later slice
  (decision 5), not this build.
- **Water and swimming.** No water exists.

### 3.7 Falls

The server-simulated fall is slice 1 of `docs/design/server_fall_damage.md`, all five of its
decisions taken on 2026-10-24. It needs exactly `ground(x, z)` and the grounded-or-airborne
step in its section 3.2: follow the ground down a slope the client follows, go airborne off a
steeper drop, land with damage by its formula. It rides here as slice 2, after the ground is
pinned and proven, so a mistake in one cannot hide in the other.

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
| 5 | Hit or cast down from a height | Reach stays 3D, so height now counts against it (it did not before, on authored-Y camps). Through-terrain line of sight is decision 5. |
| 6 | Exploit a server ground that differs from the client's | Exact triangle sampling; the lockstep check in `check_all.ps1`; the boot line's hash. |
| 7 | Get ported into the ground or onto a slope's air | Every teleport destination is re-pinned before it is sent. |
| 8 | Leave a corpse unreachable by editing nothing (an old save after a terrain change) | Corpses and characters are re-pinned at load; the res and loot ranges then measure from the ground. |
| 9 | Strand a mob under its target, or pull one up a slope at half speed | `step_toward` steps by the XZ delta. |
| 10 | Kite a mob up a slope it cannot climb | Decision 2; with the second option, an unreachable mob goes home and nothing is a free kill. |
| 11 | Save a character mid-air | Not possible in slices 0 and 1 (no airborne state). Slice 2 takes the fall design's ledger rows 4 to 6 (logout, crash and teleport mid-fall). |

## 6. Slices

**Slice 0: the ground, read only.** `terrain.toml` (today's flat terrain), `world/terrain.rs`
with the sampler, the boot line, the export tool, the lockstep check in `check_all.ps1`. No
behaviour changes; on today's world `ground` is 0 everywhere. Server and client tooling, no
redeploy needed for players, no export.

**Slice 1: everything stands on the ground.** Section 3.3's table, the slope rule if decided, the
step_toward fix, re-pinning at load. Still no visible change on the flat world, which is the
point: the regression playtest is "nothing changed", and the integration tests on a test terrain
carry the proof. Server only, one redeploy, no export, no protocol change.

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
- **Client:** `check_terrain_lockstep.gd` catches a planted height, a moved node and a moved NPC.
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
   disagrees with the ground is the foot-gun `zone_size_limits.md` warned about.
5. **Terrain line of sight** for spells and ranged attacks. Recommended: not now; a later slice
   once the first hills show whether casting through a ridge matters in play.
6. **Order:** slices 0 and 1 together on one branch from `bump/nov` (server `refactor/tick-split`
   is in it), redeployed after the bump; falls (slice 2) next; the first hills (slice 3) as their
   own plan. Recommended: yes.
