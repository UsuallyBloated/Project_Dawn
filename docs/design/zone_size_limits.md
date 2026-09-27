# Zone Size Limits: How Big Can We Build?

*Research pass, 2026-09-25. User-commissioned: "how big can we make our zones? I want the
world LARGE, with wide open spaces and great verticality." This documents the limits; it
does not build anything. Every code claim below was verified against the real source, not
just reported by recon.*

## The short version

| Question | Answer |
|---|---|
| Does Godot have a size limit? | No hard limit. Practical single-precision comfort zone is roughly **4 to 8 km across** for a third-person game, centered on the origin. Beyond ~16 km across you need engine changes (double-precision build or origin shifting). |
| Does our server have a size limit? | **No.** Positions are unbounded f32, the interest grid is sparse (empty land costs nothing), and f32 precision is fine to tens of km. Server cost scales with **mob and player count**, not with area. |
| So what actually limits us? | **Verticality, not width.** The server has no Y axis: it zeroes Y on every move, mobs keep their spawn height forever, and yet every range check measures distance in 3D. Hills taller than melee range (1.8 m) break combat *today*. |
| Wide open spaces? | Green light. A zone the size of EQ's West Karana (~4.6 x 1.5 km) fits inside Godot's comfort band and costs the server nothing extra per square meter. |
| Great verticality? | Needs one server work item first (see below). Until then, terrain must stay flat where anything lives; visual-only verticality (cliff walls, vistas, skyboxes outside the playable space) is fine now. |

For scale: classic EQ's famously huge West Karana is about 15,000 x 5,000 EQ units
(roughly 4.6 x 1.5 km), and it was not even in EQ's top ten by area. A "significant and
memorable" zone by classic-MMO standards fits comfortably inside our limits.

## 1. Godot's limits (engine)

Godot has no maximum scene or map size. The real constraint is 32-bit float precision,
which degrades with distance from the world origin. The official guidance
([Large world coordinates, Godot 4.4 docs](https://docs.godotengine.org/en/4.4/tutorials/physics/large_world_coordinates.html)):

| Distance from origin | Verdict |
|---|---|
| 0 to 2,048 m | Full precision, no issues |
| 2,048 to 4,096 m | Max *recommended* range for a first-person game |
| 4,096 to 8,192 m | Max for third-person games (us) |
| 16,384 to 32,768 m | Max for top-down games |
| 32,768 m and beyond | Visible artifacts; double precision advised |

Symptoms past the comfort band: meshes visibly vibrate, animation jitters, physics
glitches. Note the numbers are radii from the origin, so a zone **centered on (0,0,0)**
gets the full band in every direction: a third-person game is comfortable in roughly an
**8 x 8 km zone**, and conservatively excellent in 4 x 4 km.

Escape hatches if we ever want continent-scale seamless terrain (we should not need
either for a long time):
- **Double-precision build**: recompile the engine and export templates with
  `precision=double`. Costs performance and memory, and every GDExtension (our
  `gdext_net`) must be rebuilt against it.
- **Origin shifting**: periodically re-center the world around the player. Works on a
  stock engine but the docs specifically warn it adds complexity **especially in
  multiplayer**, since every wire position would need translating. Wrong fit for us.

Physics notes (we are on the 4.4 default GodotPhysics; Jolt is opt-in in 4.4 and we do
not set it, confirmed against `project.godot`):
- If we ever switch to [Jolt](https://docs.godotengine.org/en/4.4/tutorials/physics/using_jolt_physics.html),
  its guidance wants static bodies under ~2,000 m long and warns that one giant
  HeightMapShape3D is slow; big terrain should be chunked into multiple collision
  shapes. Chunking is best practice on GodotPhysics too.
- Speeds and object sizes in our game are tiny by physics-engine standards; no concern.

## 2. Our client's limits (as built today)

The current world is a **400 x 400 m flat plate**: `TerrainMesh` in `world.tscn` is a
20x20-cell SurfaceTool heightmap (all 441 heights are 0.0) with a single trimesh
collision shape, plus an infinite `WorldBoundaryShape3D` floor at y=0. Camps reach to
about ±180 m. So today's zone uses about 0.2% of the safe area Godot offers.

What a km-scale zone would need client-side (all standard, none hard):
- **Terrain chunking.** `terrain_mesh.gd` builds one mesh and one ConcavePolygonShape3D
  and rebuilds both in full on any edit. Fine at 400 m, not at 4 km. Km-scale terrain
  wants chunked meshes with per-chunk collision (or the disabled `addons/terrain_editor`
  grown up, or a terrain plugin).
- **Rendering is completely untuned.** No `[rendering]` section in project.godot, no LOD
  distances, no `visibility_range` on anything, no occlusion culling, and the Sun's
  shadow distance is the 100 m engine default. Camera far plane is 4,000 m. None of this
  breaks a big zone; it just means draw cost currently grows linearly with what is in
  view. A big-zone pass would set shadow distance deliberately, add visibility ranges to
  props, and use fog (already present, `fog_density=0.003`) as the distance cue it
  already is.
- **Entity count, not area, is the client cost.** Every remote entity is a full
  CharacterBody3D with a Label3D nameplate, and every 20 Hz Position broadcast fans
  through one shared `Net.world_position` signal to four listeners. The server's
  interest grid (below) caps how many are visible at once, so this is about mob density,
  not zone size.
- **Multi-zone is scaffolding only.** `ZoneLoader` is a scene-swap-with-fade helper;
  `scenes/zones/` has never existed; no `ZoneLine`/`ZoneEntry` node exists in any scene;
  the server has no zone concept on the wire. One big seamless zone is what the code
  wants to be; real multi-zone is a future epic (new wire message, server zone keying).

## 3. Our server's limits (as built today)

The good news, verified in `F:\Projects\server`:
- **No world bounds anywhere.** Nothing clamps x or z, there are no extent constants,
  and DB position columns are plain REAL with no CHECK constraints. A client can walk as
  far as the speed cap lets it.
- **Interest management already scales by area for free.** `aoi.rs` is a sparse 2D grid,
  `HashMap<(i32,i32), HashSet<EntityId>>` with 120 m cells; a player sees the 3x3
  neighborhood (a 360 m square). Empty cells simply do not exist in the map, so a 10x
  bigger zone with the same mob count costs almost nothing extra.
- **f32 precision is a non-issue** at any plausible size (position step between adjacent
  f32 values is ~1 mm even 8 km out). The Godot client jitters long before the server
  would care.
- **Movement is server-capped** (direction clamped to unit length, 7.5 m/s x tick), and
  a client cannot send a position at all, only a direction. So a bigger world does not
  widen the movement-cheat surface.

What actually grows with a bigger world is **mob count**, and there the per-tick costs
are global, not proximity-scoped:
- Every alive enemy runs AI every tick whenever at least one player is online, even
  1,000 m from anyone (`tick.rs` enemy loop; each mob scans all players and pets for
  targets).
- Every alive enemy fans its Position to all AOI-visible players every tick with no
  moved-check. This is the known "idle enemies rebroadcast at 20 Hz" To-Do item; its fix
  (fan on change plus keepalive, the `regen.rs` pattern) matters *more* the bigger the
  world gets.
- 77 fan-out sites (hits, heals, casts, buffs, EntityTarget, resource updates) go to
  **all in-world players**, not the AOI neighborhood. Fine at friends-build scale (64
  client cap), and a known lever to pull later.

None of these limit zone *area*. They limit how many camps we place, and they are all
ordinary optimization work with obvious shapes.

## 4. The real blocker for verticality: the server has no Y

This is the headline finding. The user wants "areas with great verticality", and that is
the one thing the current architecture actively fights:

- The server zeroes Y on every Move (`handlers.rs` ~562: "Y is zeroed — server does not
  simulate gravity or jumping") and the tick integrates XZ only. Gravity is client-side.
- Mobs keep their spawn Y forever: `Vec3f::step_toward` deliberately preserves y
  ("enemies don't fly toward a player who's on a raised mesh").
- **And yet every range check measures 3D distance** (`Vec3f::distance_to` includes y):
  melee, spell range, AOE, res range, loot range, NPC service range, mob aggro, leash,
  and pet AI. The only 2D check in the server is the cast-movement gate.

Consequences on non-flat terrain, before any code changes:
- A mob whose spawn Y differs from a player's Y by more than melee range (1.8 m) chases
  to the player's XZ spot and then **can never attack**: the 3D distance never drops
  below the height gap. Past leash range in Δy it never aggros at all. A 2 m ledge
  breaks combat.
- Remote players, mobs, corpses and loot bags render at the server's Y verbatim (the
  client interpolates the full Vector3 with no ground snap), so on a hill they sink into
  the terrain or float at its base. Only your *own* Y is locally controlled.
- Server `Teleport` (respawn, res) sets all three axes, so respawning onto raised
  terrain drops you to y=0, under the ground, onto the infinite safety floor.
- Mob movement is straight-line XZ with no navmesh, collision or line-of-sight; a cliff
  between mob and player is invisible to the server. The client shows the mob walking
  through rock.

**Verdict:** authoring nonzero Y in `zone_camps.toml` or `npcs.toml` is actively harmful
today. Verticality needs a server work item first. Two viable shapes, roughly in order
of cost:
1. **Server-side terrain height model.** Export the client terrain's heightmap to the
   server (a small grid file next to `zone_camps.toml`); the server samples ground
   height at any XZ and keeps player, mob and corpse Y pinned to it. Range checks stay
   3D and become *correct*. Jumping stays cosmetic. This also fixes remote entities
   rendering at the right height for free, and it is the natural companion of the
   already-planned cosmetic jump relay. Cliffs still need care (aggro through floors in
   caves would need the check to respect the height model), but rolling hills, ridges,
   and valleys all just work.
2. **Switch range checks and mob chase to XZ distance.** Much cheaper, and it unbreaks
   combat on slopes, but it makes height *invisible* to gameplay: a player on a mesa and
   a mob at its base would melee each other through 30 m of vertical rock, remote
   entities still render at the wrong height, and vertical exploit surface opens (attack
   from unreachable perches). Acceptable as a stopgap, wrong as the destination.

Recommendation: option 1 when verticality gets scheduled. Multi-level structures
(dungeons with floors stacked on the same XZ) are a later, harder problem than open
terrain and would need real Y tracking, not just a height sample.

## 5. Security finding (verified, found during this research)

**A forged Move with a NaN or Infinity direction poisons the player's position and then
bypasses most range gates.** `clamp_length` (`connection.rs:43`) tests `len > max`,
which is false for NaN, so a non-finite direction passes through unchanged; the tick
then makes `pos.x` NaN permanently. Every rejection gate written as
`if distance > RANGE { refuse }` (verified: corpse loot at `tick.rs:7898`, loot bags at
`:8123`/`:8406`, res at `:3817`, same shape for attack and spell range) then **passes**,
because any comparison with NaN is false. Net effect: an ordinary client cannot trigger
it, but a modified client could loot any corpse or bag and land attacks, casts, and res
offers from anywhere in the zone. NaN also spreads into mob positions through chase AI,
and SQLite stores NaN as NULL (reloads as 0.0). The fix is a few lines: reject a Move
whose direction components are not finite, the same guard `DevSpawnMob` already has
(`handlers.rs:793` is the only `is_finite` check in the handlers). Fits the audit's
standing frame: magnitudes are validated, eligibility inputs less so.

Two smaller correctness gaps that grow with world size, for the record:
- **Enemy AOI cell crossings never fan EnemySpawn/EntityDespawn** (verified,
  `tick.rs:6934`: only `aoi.update` runs). A mob that chases into your 3x3 neighborhood
  streams Position for an id you never got a spawn for; one that leaves never despawns.
  Player crossings handle both properly. Longer chase distances in a bigger zone hit
  this more often.
- The stale comment at `tick.rs:9174` claims enemies are "not yet in the AoiGrid"; they
  are.

## 6. Practical envelope for level design

What all of this adds up to, as guidance rather than mandate:

- **Center every zone on the origin.** Free precision budget in all directions.
- **Up to ~4 x 4 km per seamless zone: build freely.** That is 100x the current world's
  area and comfortably inside every band above. West Karana scale.
- **4 to 8 km across: fine, with a client polish pass** (terrain chunking, LOD and
  visibility ranges, shadow distance, maybe occlusion for dense areas).
- **Beyond ~8 km across: make it a second zone**, not a bigger one. Multi-zone is the
  honest next epic at that scale (wire message, server zone keying, zone lines), and it
  is also what the lore's plate-based world atlas wants anyway.
- **Verticality: gate on the server height model** (section 4, option 1). Until then,
  playable space stays flat-ish (under ~1.5 m of height variation anywhere mobs or NPCs
  live), and drama comes from visual-only cliffs, canyon walls and vistas outside the
  playable envelope.
- **Mob density, not area, is the budget to watch.** Before multiplying camps by 10,
  land the idle-rebroadcast fix (existing To-Do) and consider AOI-scoping the big
  fan-outs.

## Sources

- [Large world coordinates, Godot 4.4 docs](https://docs.godotengine.org/en/4.4/tutorials/physics/large_world_coordinates.html)
- [Using Jolt Physics, Godot 4.4 docs](https://docs.godotengine.org/en/4.4/tutorials/physics/using_jolt_physics.html)
- [Emulating double precision on the GPU, Godot blog](https://godotengine.org/article/emulating-double-precision-gpu-render-large-worlds/)
- [The Ancient Gaming Noob on West Karana's size](https://tagn.wordpress.com/2024/03/27/everquest-starting-points-west-karana-where-the-scope-of-the-world-begins/)
- [Brewall's EverQuest Maps, "How big is EverQuest?"](https://www.eqmaps.info/2018/04/18/how-big-is-everquest-2/)
