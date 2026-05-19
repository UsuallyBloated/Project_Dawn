# Session 2026-05-19 — Track 11: Server-side Pet System (full)

Track 11 lifts pets server-side. Necromancer / Beast Master / Magician
/ Enchanter were the pet-using classes that couldn't play in
multiplayer; Necromancer's Summon Skeleton is now end-to-end
authoritative, and the architecture generalises to the other three
once their summon spells get pet templates and the special behaviours
(charm, warder retreat/fury, multi-pet) land in Track 12.

Five sub-tasks, six commits (server 4, client 2).

## 11.1 — Server-side pet entity + spawn (Server `628f42e`, Client `8391bf6`)

**Protocol bump** PD_W0006 → PD_W0007.

- New `PET_ID_BASE = 3_000_000_000` constant + `ServerWorldMsg::PetSpawn
  { id, owner, pet_name, level, max_hp, hp, pos, yaw }` variant.
- `Entity` extended with `owner: Option<EntityId>`. New
  `from_pet_summon` constructor + `mint_pet_id` atomic counter.
  `spawn_point_idx` set to `usize::MAX` (pets aren't tied to a
  respawn point; `spawner.on_enemy_died(usize::MAX)` is a silent
  no-op via `get_mut`'s out-of-range behaviour).
- New `pet_templates` module — currently a single Skeleton template
  (lvl 6, hp 80, dmg 8, speed 3.0, melee_range 1.8, attack_interval
  2.2). Spells whose `pet_type` misses the lookup are dropped at the
  dispatch site.
- `Spell` gains `pet_type: String` (with `#[serde(default)]`). Summon
  Skeleton added to `spells.toml`.
- `tick.rs`'s `PET_SUMMON` arm: despawn caster's existing pet first
  (one-pet-per-owner cap), spawn fresh entity at caster_pos + 1.5 m
  east offset (so it doesn't clip into the player capsule), register
  in `aoi`, fan `PetSpawn` to AOI peers.
- Disconnect cleanup: in `ServerEvent::ClientDisconnected`, iterate
  `enemies` for entries with `owner == leaver_char_id`, fan
  AOI-filtered `EntityDespawn`, remove from `enemies` and `aoi`.

**Client side:**
- `gdext-net` exposes new `pet_spawn` typed signal + `Incoming`
  variant + classify arm. DLL rebuilt and copied to
  `addons/gdext_net/gdext_net.dll` (gitignored per convention).
- `autoloads/net.gd` connects `pet_spawn`, re-emits as
  `world_pet_spawn(id, owner, pet_name, level, max_hp, hp, pos, yaw)`.
- `scripts/net/protocol.gd` adds `SW_PET_SPAWN` tag (mirrored to the
  launcher copy as well in commit `1753b2b`).
- `scenes/remote_pet.tscn` + `scripts/remote_pet.gd`: CharacterBody3D
  with a capsule mesh, billboarded Label3D, snapshot-interp buffer
  matching RemoteEnemy (BUFFER_CAPACITY 5, INTERP_LAG 100 ms). No
  AI, no physics, no local HP.
- `autoloads/remote_pet_manager.gd`: mirrors RemoteEnemyManager —
  `_spawn_data` (autoload-scoped) + `_by_id` (scene-scoped) +
  scene-swap rehydrate. Routes shared signals (Position /
  HealthUpdate / EntityDied / EntityDespawn) by `id >= PET_ID_BASE`.
- `project.godot` registers `RemotePetManager` autoload.

**Tests:** 75 pass (was 72; +2 pet_templates unit tests + 1
integration test `pet_summon_visible_to_peer` asserting B receives
PetSpawn with A's char_id as owner and a pet id in the partition).

## 11.2 + 11.3 — Pet AI: follow owner + combat inheritance (`1c0068e`)

**11.2 follow:**
- `tick_ai` branches on `entity.is_pet()`. Pets run a distinct
  `tick_pet_ai` that follows their owner (PET_FOLLOW_DISTANCE 3 m).
- Pets share the `enemies` HashMap; cell-change tracking, AOI
  updates, position broadcasts (step 6b), and corpse cleanup all
  work uniformly.
- `tick_ai` signature extended to take both `targets` (players, used
  by enemy AI for aggro acquisition) and `enemy_targets` (alive
  non-pet enemies, used by pet AI to chase its inherited target).

**11.3 combat target inheritance:**
- `PerConnection` gains `last_attacked_enemy: Option<EntityId>` +
  `last_attacked_at: Option<Instant>`. Set on every successful
  player→enemy Attack intent and every ENEMY-target spell hit, with
  `PET_TARGET_DECAY_SECS = 10.0`.
- AI loop's pre-pass resolves each pet's target from its owner's
  last attack: alive enemy → set `pet.target`; dead or stale → clear.
- `tick_pet_ai` chases the resolved target into melee range and
  swings on cadence using the pet's `MobTemplate.dmg`.
- New pet→enemy branch in the `enemy_hits` dispatch loop (attacker
  `>= PET_ID_BASE`, target in enemy partition): applies damage, fans
  Hit + HealthUpdate, handles death + EntityDied + AOI-filtered
  LootBag.
- **Kill credit / aggro accrue under the OWNER's id**, not the pet's,
  so XP and top-damager logic naturally routes to the owner. Credit
  is also gated on `credit_id < ENEMY_ID_BASE` defensively so a pet
  that out-damages the owner doesn't get XP charged to its own id.

**Tests:** 77 pass (was 75): `pet_follows_owner` asserts pet position
moves east as owner does (`max_pet_x > 3.0`); `pet_attacks_owners_target`
asserts pet swings register as `Hit { attacker=pet_id, target=enemy_id,
amount=8 }`.

Also bumped the AI-walks-into-melee test timeouts from 20 s → 35 s
across five tests: the suite is bigger now (17 world_two_clients
tests) and the historical CPU-contention flakiness was hitting the
20 s budget.

## 11.4 — Enemy ↔ pet mutual combat (`bf4f5f3`)

Closes the gap where pets damaged enemies (11.3) but enemies never
hit back. Pets now tank.

- `tick_ai`'s player slice renamed to `targets` and extended to
  include alive pets so enemy `tick_idle` aggros on the nearest
  player or pet. Helper fns renamed `nearest_player_within →
  nearest_target_within` and `player_pos → target_pos`.
- New enemy → pet branch in the enemy_hits dispatch: apply HP, fan
  Hit + HealthUpdate, fan EntityDied on lethal. No armor / absorb /
  shield (pets have no buff plumbing); no XP awarded.
- Pet corpse cleanup rides the existing step-4j path.

**Known limitation.** No re-aggro on damage — an enemy locked on the
player won't switch when a pet hits it. Tank-by-out-positioning
works (pet ahead of player on approach pulls aggro first), but
mid-fight summoning doesn't pull. Threat/taunt is Track 12.

**Tests:** 78 pass (was 77): `enemy_aggros_on_pet_when_no_player_nearby`
unit test proves the aggro pool extension end-to-end through tick_ai.

## 11.5 — HUD wiring (`3c350f3`)

`scripts/hud_pet_panel.gd` subscribes to `PetManager.pet_summoned /
pet_dismissed / pet_died / pet_hp_changed`. Without 11.5 those only
fired in solo mode where `PetManager.summon` instantiated a local
Pet; launcher-mode players would see no pet panel because the local
Pet was never made.

- `PetManager.summon()` early-returns in launcher mode (the server
  spawns the pet; local Pet would be a duplicate visual).
- `PetManager.register_remote_pet(rp)` / `dismiss_remote_pet()` —
  the former wires `hp_changed` + `died` forwarding to PetManager's
  signal contract and emits `pet_summoned`; the latter clears
  `active_pet` and emits `pet_dismissed`.
- `RemotePetManager` calls `register_remote_pet` on PetSpawn for
  `owner == Net.get_player_id()`, and `dismiss_remote_pet` on the
  matching EntityDespawn.
- `RemotePet` gains a `died` signal emitted in `apply_death()` so
  PetManager.pet_died fires when an enemy kills the local pet.

Pet commands (`command_follow` / `command_guard` / etc.) still
target the local Pet's API and no-op on RemotePet — Track 12 wires
pet command intents over the wire.

## Test results

- 78 server tests pass (started Track 11 at 72).
- Manual playtest deferred to user — Necromancer summon flow needs
  two-instance verification.

## Commits

- Server `628f42e` — Track 11.1
- Server `1c0068e` — Track 11.2 + 11.3
- Server `bf4f5f3` — Track 11.4
- Client `8391bf6` — Track 11.1 client (RemotePet rendering)
- Launcher `1753b2b` — protocol.gd SW_PET_SPAWN mirror
- Client `3c350f3` — Track 11.5 (HUD wiring via PetManager)

## Notes / deferred items

- **PET_CHARM** (Enchanter) — converting an existing enemy mid-life
  is more invasive than spawning fresh. Track 12.
- **Beast Master warder** — `WarderAI` autoload has retreat/fury
  behaviour that pets in 11.x don't run. Track 12 ports it.
- **Multi-pet** — Necromancer design implies multiple skeletons;
  current cap is one per owner.
- **Pet commands over the wire** — follow/guard/attack/back/sit
  intents need a `ClientWorldMsg::PetCommand` variant + server
  acknowledgment. Track 12.
- **Re-aggro on damage** — enemy stays locked until leashed; doesn't
  switch when pet hits it mid-fight. Tank-by-out-positioning works,
  but threat/taunt mechanic is a Track 12+ item.
- **Pet weapon proc / crit / armor** — pets use flat template damage;
  full damage formula port can come later.
- **Lifetap / Soul Drain heal on pet kills** — still ignored
  server-side; same waiting room as the base ranks.
