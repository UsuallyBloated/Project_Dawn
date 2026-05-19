# Track 11 Handoff — Server-side Pet System

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Tracks 1–10 closed the server-authoritative loop for movement,
visibility, enemy state, player stats, PvP, buffs / CC, groups,
AOI partitioning, ALLY peer-healing, AOE damage, and the spell
cast-time gate. Track 11 lifts **pets**.

Today the four pet-using classes (Beast Master, Necromancer,
Magician, Enchanter) can't actually use their pets in multiplayer.
Pet summon spells (`PET_SUMMON` target_type) fall through to the
server's `"NONE" | _` fallback. The client-side `PetManager`
spawns a local `pet.tscn` instance attached to the caster, but that
pet is invisible to peers and isn't tracked by the server.

Track 11 lifts the basic loop: pet entity lives on the server,
peers see it walk and fight, server arbitrates its HP and death.
Special behaviors (charm, warder retreat/fury, multi-pet) defer to
Track 12. Estimated 1–2 sessions depending on how deep you go.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | (TBD — Track 10 session notes + this handoff pending commit) |
| Server | `F:\Projects\server\` | `main` | `fe74ec9` (Track 10: server-side cast-time gate on CastSpell) |
| Launcher | `F:\Projects\launcher\` | `main` | `18da871` (protocol.gd: add SW_ENEMY_SPAWN / SW_ENTITY_TARGET tags) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS) |

Run `git -C <each> log --oneline -5` before touching anything.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_19_track10.md` — yesterday's
   close. The cast-time gate now applies to `Summon Skeleton`
   (cast_time 3.0); make sure your pet tests pump the proper cast
   bar flow.
3. `crates/projectdawn-server/src/world/entity.rs` — `Entity` struct
   (hp, pos, ai state, aggro). The pet implementation extends this.
4. `crates/projectdawn-server/src/world/tick.rs` — pivot reading:
   - lines 1020–1070 (enemy spawn fan-out with AOI) — pet spawn
     mirrors this.
   - lines 2280–2300 (enemy AI tick + cell-change tracking) — pet
     AI tick goes alongside.
   - lines 1438+ (`cast_spell_intents` loop) — PET_SUMMON branch
     goes in the `match spell.target_type` arm.
5. `crates/protocol/src/world.rs` — message variants. New `PetSpawn`
   and `PetDespawn` go here; `WORLD_PROTOCOL_ID` bumps from
   `PD_W0005` → `PD_W0006`.
6. `autoloads/pet_manager.gd` — client-side pet lifecycle (today's
   single-player path). Look at `summon` / `dismiss_pet` /
   `_summon_skeleton`. The server-side path makes most of this
   inert in launcher mode (parallels how `EnemySpawner` got
   short-circuited in Track 5).
7. `scripts/pet.gd` + `scenes/pet.tscn` — the client pet node. In
   launcher mode, this becomes the model for `remote_pet.tscn`
   (display only, no AI).
8. `autoloads/remote_enemy_manager.gd` — exact template for
   `RemotePetManager`. Same `_spawn_data` (autoload-scoped) /
   `_by_id` (scene-scoped) / scene-swap-rehydrate pattern.

---

## Scope

### In

- Server-side pet entity. `Entity` extended with
  `owner: Option<u64>` (player char_id, `None` for enemies).
- Pet id partition: `PET_ID_BASE = 3_000_000_000` placed above bags
  (`LOOT_BAG_ID_BASE = 2_000_000_000`). New helper predicates
  `is_pet_id(id) / is_enemy_id(id) / is_bag_id(id) / is_player_id(id)`
  in `protocol::world` (or wherever ENEMY_ID_BASE lives).
- `PET_SUMMON` arm in `tick.rs`'s `match spell.target_type.as_str()`:
  spawn a pet entity at the caster's position, owner = caster id,
  fan `PetSpawn` to AOI peers. Despawn the caster's existing pet
  first if any (one pet per owner for Track 11).
- Pet AI: follow owner when no target; if owner has been attacking
  an enemy recently, inherit that target and chase + attack.
  Server tracks `PerConnection.last_attacked_enemy: Option<EntityId>`
  with a 10 s decay — set when caster sends `Attack` against an
  enemy. The pet reads this on its AI tick.
- Pet auto-attacks server-authoritative via `combat::calc_swing`
  using pet stats (level / dmg from a hardcoded template — same
  pattern as `MobTemplate`).
- Pet HP server-authoritative. `HealthUpdate` fan-out on damage.
  Enemy AI's existing target-selection sees pets as valid targets
  (their id is in a partition that's neither player nor bag).
- Pet death lifecycle: hp ≤ 0 → `EntityDied` fan-out → corpse
  linger 5 s → `EntityDespawn` (reuse the existing enemy death
  path — pets ride the same `enemies` HashMap and the same corpse
  cleanup phase).
- Despawn on owner disconnect: in the disconnect handler, iterate
  `enemies` for entities with `owner == disconnecting char_id`,
  mark as dead, fan `EntityDespawn`. Track Track 5's pattern.
- Client wire-up:
  - `gdext-net` exposes typed signals for `PetSpawn` / `PetDespawn`.
  - `Net.gd` re-emits `world_pet_spawn` / `world_pet_despawn`.
  - New `autoloads/remote_pet_manager.gd` mirroring
    `remote_enemy_manager.gd`. Listens to the new signals plus
    the shared `world_position` / `world_health_update` /
    `world_entity_died` / `world_entity_despawn` (routes by id
    partition, exactly like RemoteEnemyManager does for enemies).
  - New `scripts/remote_pet.gd` + `scenes/remote_pet.tscn` based
    on `remote_enemy.tscn` (CharacterBody3D + capsule + collision
    + NameLabel3D); no AI, no input.

### Out (defer to Track 12)

- **`PET_CHARM` (Enchanter).** Converting an existing enemy into a
  pet on the fly. Changing entity ownership mid-life is more
  invasive than spawning a fresh pet — entity id changes partition,
  AOI bookkeeping has to re-classify it, peers need a "this enemy
  is now a pet" hint. Bracket separately.
- **Beast Master warder retreat/fury.** Today's `WarderAI` autoload
  has special logic that retreats below 25% HP and goes berserk
  on owner low HP. Track 11 uses simple follow-and-attack only;
  Track 12 ports the warder behavior tree.
- **Multiple pets per owner.** Necromancer's design implies
  multiple skeletons. Track 11 caps at one. Track 12 (or 13)
  generalizes.
- **Pet command messages** (`/pet attack`, `/pet stay`, `/pet follow`).
  Pet attacks owner's last-attacked enemy by default. Manual
  commands are a UI/UX layer for later.
- **Pet UI on HUD.** Today's GDScript shows pet HP / mana on the
  HUD via the local `PetManager`. In launcher mode the pet HP
  needs to read from the RemotePet's server-broadcast HP instead.
  Keep the HUD wiring inert in launcher mode for Track 11; UI pass
  comes after the wire layer works.
- **Pet auto-attack weapon proc / crit / armor.** Track 11 uses
  flat pet template damage. The full damage formula port can come
  later.
- **`Summon Elemental` (Magician), `Summon Familiar` (Magician /
  Necromancer / Enchanter).** Only `Summon Skeleton` exists in
  `data/spell_definitions.gd` today (the Necromancer one with
  `pet_type = "skeleton"`). Other pet-summon spells are deferred
  authoring; when they land, just add their template to the new
  `pet_templates` module.

## Sub-tasks

Split this however helps you ship. Suggested order:

### 11.1 — Pet entity + spawn (no AI, no combat)

- `Entity.owner: Option<u64>` field.
- `PET_ID_BASE = 3_000_000_000` constant.
- New `pet_templates` module with `SKELETON: PetTemplate` (hp,
  level, dmg, speed, attack_interval). Mirror `MobTemplate`.
- New `ServerWorldMsg::PetSpawn { id, owner, name, level, pos, yaw }`
  and `ServerWorldMsg::PetDespawn { id }` variants. Protocol bump
  `PD_W0005 → PD_W0006`.
- `tick.rs` `match spell.target_type.as_str() { ... "PET_SUMMON" => { ... } ... }`:
  - Read `spell.pet_type` from `spells.toml` (need to add the
    `pet_type: String` field with `#[serde(default)]`).
  - Despawn caster's existing pet (find `Entity` with
    `owner == Some(caster_id)`, mark dead, fan `EntityDespawn`).
  - Spawn fresh pet entity at caster's position, push into
    `enemies`, register in `aoi`.
  - Fan `PetSpawn` to AOI neighbours of pet's cell.
- Client side: `RemotePetManager` parses spawn, instantiates
  `RemotePet`, parents to current scene. Listens to Position /
  HealthUpdate / EntityDespawn already in flight, routes by id
  partition.

**Verify by**: cast Summon Skeleton in launcher mode, see the
skeleton appear in the world for both the caster and a peer.
Skeleton stands still at the spawn position (no AI yet).

### 11.2 — Pet AI: follow owner

- In `tick_ai`, branch on `entity.owner`:
  - `None`: existing enemy AI (idle / chase / attack / leash).
  - `Some(owner_id)`: pet AI. Default state: follow owner.
- Follow logic: read owner's position from
  `connections[owner_cid].pos`, move toward it at pet's speed if
  distance > 3 m, else idle. Standard `tick_chase` style.
- Pet cell changes get tracked in `enemy_cell_changes` same as
  enemy cell changes (no separate phase needed — `enemies`
  HashMap holds both).
- Position fan-out for pets uses the same step 6b enemy position
  broadcast — no special-casing.

**Verify by**: pet follows owner across the world for both client
windows.

### 11.3 — Pet combat: attack owner's last target

- Add `PerConnection.last_attacked_enemy: Option<EntityId>` and
  `last_attacked_at: Option<Instant>`. Set on `Attack` intent
  processing when the target is an enemy id (sub-task 11.3 only
  cares about enemy targets; PvP-pet-targeting is a follow-up).
- Pet AI state machine adds Attack state alongside Follow:
  - If owner has a fresh enemy target (`last_attacked_at` within
    10 s) and that enemy is alive, switch to Attack: chase that
    enemy id.
  - In Attack state, when in melee range, swing.
  - When target dies or expires, return to Follow.
- Pet swings: reuse `combat::calc_swing` with pet stats from
  `PetTemplate`. Apply damage to enemy via the existing
  apply-attack-to-enemy path (the helper from Track 9). Hit
  fan-out carries pet's id as attacker.
- Enemies aggro on pets that hit them — the enemy AI's existing
  aggro logic already triggers on any attacker; pet id qualifies.
  Pets take damage from enemy swings the same way players do
  (enemy's existing attack apply path branches on target id
  partition — add the pet branch).

**Verify by**: pet engages the enemy the owner clicked, both
clients see the pet's swings fan out as Hit broadcasts, the enemy
dies if the fight goes long enough, the pet returns to follow.

### 11.4 — Despawn on owner disconnect / zone change

- In the `ServerEvent::ClientDisconnected` arm (after the existing
  player despawn logic), iterate `enemies` for entities with
  `owner == Some(leaver_char_id)`. Mark dead, fan `EntityDespawn`,
  remove from `enemies` and `aoi`.
- Zone change (when zones land — currently single zone) follows
  the same pattern. Out of scope for Track 11; flag in the code
  with a TODO if you encounter the natural place to add it.

### 11.5 — Client polish (optional but valuable)

- HUD's `PetPanel` (already exists for solo mode) needs to read
  pet HP from `RemotePet` instead of local `PetManager` when in
  launcher mode. Subscribe to `RemotePet`'s `hp_changed` signal.
- `PetManager.has_pet()` returns true if `RemotePet` exists for the
  local player in launcher mode. Keep the API surface stable so
  the rest of the codebase (auto-attack target selection, etc.)
  doesn't need to know about launcher vs solo.

## Integration test (one is enough for Track 11)

In `tests/world_two_clients.rs`:

```rust
async fn pet_summon_visible_to_peer_and_follows_owner() {
    // Provision a Necromancer (A) and a Cleric (B).
    // Both enter world. Wait for mutual EntitySpawn.
    //
    // A sends CastStart("Summon Skeleton", 3.0), pump, sleep 3100 ms,
    // send CastSpell("Summon Skeleton", None), pump.
    //
    // Assert: B receives PetSpawn { owner: a_char_id, ... } with
    // an id in the pet partition (>= PET_ID_BASE).
    //
    // A walks 5 m east. Pump 1 s.
    // Assert: B receives Position updates for the pet id, with
    // the pet's x increasing alongside A's.
}
```

Pet combat test (the enemy-aggro path) can land in Track 12 or
later — it requires a real enemy nearby and adds an additional
~15 s of test runtime.

## Implementation notes

### Why extend `Entity` rather than add a separate `Pet` struct?

Pets share ~80% of Entity's surface: hp, max_hp, pos, ai_state,
aggro, mob template (or pet template), attack_interval, cc state.
The differences are AI logic and ownership. Cleaner to extend with
`owner: Option<u64>` and branch the AI tick than to maintain two
parallel maps with parallel fan-out paths.

If `Entity` already feels overloaded, `MobTemplate` is the natural
abstraction point — split it into `MobTemplate` vs `PetTemplate`
sharing a trait or keep them as separate types referenced by an
enum in `Entity.template`. Either works.

### Aggro on pets

Enemy AI's `tick_ai` selects targets from its aggro table. Pets that
hit enemies will be in their aggro tables; enemies will chase and
attack them. The melee swing apply path in tick.rs needs to handle
pet targets — add a branch alongside the existing player target
branch:

```rust
if target_id_is_pet(target_id) {
    if let Some(pet) = enemies.get_mut(&target_id) {
        pet.hp = (pet.hp - dmg).max(0.0);
        fan_out_hit(...);
        fan_out_health_update(...);
        if pet.hp <= 0.0 {
            pet.transition(EnemyState::Dead, now);
            fan_out_entity_died(...);
            // Pet death — no XP credit, no loot.
        }
    }
}
```

### Pet position broadcasts

The existing step 6b enemy position fan-out iterates `enemies` and
broadcasts position for any entity whose cell intersects the AOI
of each in-world recipient. Pets are in the same `enemies` map
once you extend Entity; no extra code needed.

### Pet vs. player attack-target id-partition logic

`Attack` intent's target_id today is one of: player (PvP), enemy.
Pets becoming a third target class needs the dispatch branches in
the Attack intent processing to add a `is_pet_id(target_id)` case
that routes to the pet-damage apply path. Mirror the existing
"player target" branch in shape (look for `target_id < ENEMY_ID_BASE`).

## After Track 11

The four pet classes can play in multiplayer with their basic pet:
- **Necromancer** — Summon Skeleton works end-to-end.
- **Beast Master** — warder works as a basic follow-and-attack pet
  (lacks retreat/fury — Track 12).
- **Magician** — elementals spawn and fight (lacks the four
  elemental variants — Track 12 or content pass).
- **Enchanter** — beguiled charm targets need PET_CHARM which is
  deferred (Track 12).

Remaining big-ticket server-auth work:
- **Server-side inventory** — anti-cheat closeout. Currently the
  client is authoritative on its own inventory; loot pickup routes
  through the server for arbitration but the inventory itself is
  local. Probably the next big track.
- **Movement-during-cast interrupt** — small. Server compares
  caster pos at `cast_set_at` vs now in the gate.
- **Cooldown server-auth** — small. Add a per-player per-spell
  cooldown map; reject CastSpell that arrives before cooldown
  expires.

Pick one and write the next handoff.
