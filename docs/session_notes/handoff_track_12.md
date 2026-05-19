# Track 12 Handoff — Pet Polish + Threat / Charm / Warder

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Tracks 1–11 closed the server-authoritative loop for movement,
visibility, enemies, player stats, PvP, buffs / CC, groups, AOI,
heals, AOE, cast-time gate, and **pets** (summon, follow, attack
inheritance, enemy ↔ pet combat, HUD wiring). Necromancer's Summon
Skeleton plays end-to-end in multiplayer.

Track 12 fills in the pet-related polish that 11 deferred. Three
roughly independent pieces — pick whichever subset has the most
gameplay value first. Estimated 2–3 sessions if you do all three;
each piece is self-contained.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `3c350f3` (Track 11.5: route the local player's RemotePet through PetManager) |
| Server | `F:\Projects\server\` | `main` | `bf4f5f3` (Track 11.4: enemy ↔ pet mutual combat) |
| Launcher | `F:\Projects\launcher\` | `main` | `1753b2b` (protocol.gd: mirror SW_PET_SPAWN tag) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS) |

Run `git -C <each> log --oneline -5` before touching anything.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_19_track11.md` — full Track 11
   close. Architecture summary (Entity.owner, PET_ID_BASE, tick_pet_ai,
   target inheritance via PerConnection.last_attacked_enemy, kill
   credit routing to owner) is the foundation everything in Track 12
   builds on.
3. `crates/projectdawn-server/src/world/entity.rs` — `Entity` + AI
   methods. Pet AI lives in `tick_pet_ai` (line ~352); enemy AI's
   target acquisition uses `nearest_target_within` (now scans players
   + pets).
4. `crates/projectdawn-server/src/world/tick.rs:2438+` — the AI step
   (`4i`). Pre-AI loop resolves pet inheritance; the per-entity tick
   runs; post-loop dispatches hits in two branches (pet → enemy at
   line ~2559, enemy → player at ~2615, enemy → pet at ~2570).
5. `autoloads/pet_manager.gd` — `register_remote_pet` /
   `dismiss_remote_pet` are the Track 11.5 launcher-mode hooks; pet
   commands (`command_follow`, `command_guard`, etc.) still target
   the local Pet API.
6. `autoloads/warder_ai.gd` — Beast Master's special pet behaviour;
   currently solo-only. Track 12 piece B moves this server-side.
7. `data/spell_definitions.gd` — `target_type = "PET_CHARM"` spells
   (Enchanter Mesmerize, Beguile). Piece C wires these server-side.

---

## Three pieces (pick any subset)

### Piece A — Pet commands + threat / re-aggro

**Today's gap.** PetManager.command_follow / _guard / _attack /
_back / _sit operate on the local Pet's API; they're no-ops on
RemotePet. Players can't direct their pet beyond "follow owner,
attack what owner last hit." Enemies don't switch targets when a
pet hits them mid-fight.

**Scope.**

1. New `ClientWorldMsg::PetCommand { command: u8, target_id: Option<EntityId> }`
   variant. Commands: 0=follow, 1=guard, 2=attack-target, 3=back,
   4=sit. Protocol bump PD_W0007 → PD_W0008.
2. Server intent buffer + dispatch in `tick.rs`. For attack-target,
   set the pet's `target` directly (bypassing the
   `last_attacked_enemy` decay so the player can lock the pet onto
   something they aren't actively hitting).
3. Threat: when a pet damages an enemy that's currently chasing the
   pet's owner, check if the pet's accumulated damage exceeds the
   owner's by a multiplier (e.g. 1.3×). If so, switch enemy.target
   to the pet. Re-evaluate in the enemy AI tick — add a
   `tick_chase_reeval` step that compares aggro entries vs current
   target.
4. Client: PetManager's command methods route through `Net.broadcast_pet_command`
   in launcher mode. Existing hotkeys in `input_map` already exist
   for the local API; just gate them on launcher_mode and send the
   wire message instead.

**Integration test.**

```rust
async fn pet_command_attack_locks_pet_onto_target() {
    // Provision Necromancer. Summon. Walk into camp. Wait for an
    // enemy hit on player. Send PetCommand(attack, enemy_id).
    // Assert: a Hit with attacker=pet_id, target=enemy_id arrives.
}
```

Threat re-aggro is harder to test deterministically (requires
sustained damage delta); manual playtest is acceptable.

### Piece B — Beast Master warder server-side

**Today's gap.** `autoloads/warder_ai.gd` runs in the client's solo
flow only. Beast Masters in launcher mode get a normal pet with no
retreat / fury behaviour.

**Scope.**

1. Server-side warder template. Probably an `is_warder: bool` flag on
   the pet template OR a separate template family.
2. Retreat at low HP — extend `tick_pet_ai` with a `Retreat` branch:
   if `pet.hp / pet.max_hp < 0.25` and pet has a target, run away
   from the target instead of attacking. Returns to attack when HP
   regens above the threshold.
3. Fury when owner is low HP — when `owner.hp / owner.max_hp <
   0.20`, boost pet damage by some multiplier (e.g. 1.5×) for some
   duration.
4. Warder summon at character creation — currently the client does
   this via `WarderAI` auto-summon. Server needs to summon on
   ConnectOk for Beast Master class. Simplest: emit a synthetic
   PET_SUMMON for `pet_type = "warder"` when the client signals
   EnterWorld and the class is Beast Master.

**Carry-over.** Existing `autoloads/warder_ai.gd` becomes a no-op
in launcher mode; keep solo behavior intact.

### Piece C — PET_CHARM (Enchanter / Bard)

**Today's gap.** Charm spells (Mesmerize, Beguile, Charm Animal,
etc.) have `target_type = "PET_CHARM"` and fall through to the
server's `"NONE" | _` arm. In solo mode the client converts an
existing Enemy node into a pet via `PetManager.charm_current_target`;
in launcher mode nothing happens server-side.

**Scope.**

1. Server's CastSpell match gets a new `"PET_CHARM"` arm.
2. Target must be an enemy id (in the enemy partition). Reject
   otherwise.
3. Effect: flip the target's `owner` from `None` to `Some(caster_id)`.
   The enemy is now a player-owned pet. Set a duration (charm wears
   off after N seconds — drop owner back to None, optionally
   despawn since the pet's lost loyalty).
4. **Hard part: id partition.** Charmed enemies retain their enemy
   id (in the ENEMY_ID_BASE partition) but now behave as pets. The
   client routing (RemoteEnemy vs RemotePet) breaks because the
   manager keys off `id >= PET_ID_BASE`. Two options:
   - **Re-key on charm:** despawn the enemy (EntityDespawn), spawn
     a fresh pet (PetSpawn) at the same pos with the same HP. Two
     fan-outs, but client logic stays clean.
   - **Add a `ServerWorldMsg::EntityRetag { id, new_owner }`** that
     tells the client "this enemy is now a pet, with owner X."
     Client moves it from RemoteEnemyManager to RemotePetManager
     (or just dual-tracks). More efficient but invasive on the
     client.

   Recommend the re-key approach for Track 12 simplicity.
5. Decay: charm has a duration; when it expires, re-key back to
   enemy (PetDespawn + EnemySpawn) OR just despawn the entity
   entirely (charm-broke = mob runs away). GDScript today goes with
   "charm wears off, mob is hostile again" — match that.

**Integration test.**

```rust
async fn charm_converts_enemy_to_pet() {
    // Necromancer (or whatever class gets the charm spell) walks
    // into camp 0. Casts charm on the aggro'd enemy. Asserts:
    // - EntityDespawn for the enemy id arrives.
    // - PetSpawn for a new pet id with the same pos arrives.
    // - The pet's owner = caster's char_id.
}
```

## Cross-cutting cleanups (small wins worth doing along the way)

- **`pet_templates` should be TOML-backed** like `zone_camps.toml` /
  `spells.toml` rather than hardcoded in Rust. Three lines per
  template, regenerated when spell tuning changes. Aligns with the
  existing data-driven pattern.
- **`export_spells.gd` is stale** — its SERVER_FIELDS list doesn't
  include the buff/CC/HoT/pet_type fields, so re-running it strips
  most of `spells.toml`. Fix the tool's field list so future spell
  re-exports round-trip cleanly. This was deferred at Track 9 + Track
  11; the hand-write approach has held but it'll bite eventually.
- **Pet weapon proc / crit / armor** — pets use flat template damage
  today. Port the player damage formula to the pet path. Could
  bundle with Piece A.
- **Lifesteal heal_amount on ENEMY-target spells** — Lifetap, Soul
  Drain (and their Rk. II) carry heal_amount but the server's ENEMY
  arm doesn't apply it. Add a `caster_hp += min(heal_amount,
  damage_done)` step after the damage application. Tiny change,
  high gameplay value.

## After Track 12

After Piece A: every class can play their pet end-to-end.
After Piece B: Beast Master has the right combat feel.
After Piece C: Enchanters / Bards can crowd-control by conversion.

Remaining big-ticket server-auth work:
- **Server-side inventory** — anti-cheat closeout. Currently the
  client is authoritative on its own inventory; loot pickup routes
  through the server for arbitration but the inventory itself is
  local. Probably the next big track.
- **Movement-during-cast interrupt** — server compares caster pos at
  `cast_set_at` vs now in the gate.
- **Cooldown server-auth** — per-player per-spell cooldown map;
  reject CastSpell that arrives before cooldown expires.
- **Server-side zone transitions** — currently the client decides
  zone loads. Once second-zone content lands, this needs to lift.

Pick one and write the next handoff.
