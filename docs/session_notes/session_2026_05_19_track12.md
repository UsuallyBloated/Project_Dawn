# Session 2026-05-19 — Track 12: Pet Polish (Commands, Threat, Warder, Charm)

Three pieces shipped in order per the Track 12 handoff: pet commands +
threat (Piece A), Beast Master warder server-side (Piece B), and
PET_CHARM via id-partition re-key (Piece C). Six commits across server,
client, and launcher. Server tests went 80 → 84.

After today, every pet-using class plays end-to-end in multiplayer:
Necromancer (Summon Skeleton + /pet attack), Beast Master (auto-summon
Wolf + death-respawn), Magician / Enchanter / Bard (Charm-style pet
acquisition). Pets follow, attack on inheritance OR explicit command,
tank via threat re-aggro, die and respawn (warder) or fade ("mob runs
away" — charm), and clean up on owner disconnect.

## Piece A1 — Pet commands (server `61178b8`, client `f1cbc5f`, launcher `e38f89e`)

**Protocol bump** PD_W0007 → PD_W0008.

New `ClientWorldMsg::PetCommand { command: u8, target_id: Option<EntityId> }`
variant + a `pet_command` constants module on the protocol crate
(FOLLOW=0, GUARD=1, ATTACK=2, BACK=3, SIT=4 — Follow aliases to Back
today; Guard / Sit reserved for future behaviours and are no-ops).

**Server:**
- `Entity` gains `command_at: Option<Instant>` — sticky timestamp set
  when an Attack or Back command lands. Pre-AI inheritance pass
  (Track 11.3) now skips re-targeting from `last_attacked_enemy` while
  `command_at` is within `PET_COMMAND_STICKY_SECS = 30.0` s.
- New phase 4hc in `tick.rs` runs before the AI tick: resolves each
  owner's pet, validates target is an alive non-pet enemy for ATTACK,
  sets `pet.target` + `pet.command_at`. BACK/FOLLOW clear
  `pet.target`. Unknown commands log and drop.
- Expired stickiness clears at the start of the AI tick so a forgotten
  command doesn't pin the pet to a dead target indefinitely.
- `PetCommandIntent` outcome + handler arm; intent buffer + dispatch
  loop in tick.rs.

**Client:**
- `gdext-net::send_pet_command(command: i64, target_id: i64)` — target
  ≤ 0 maps to `Option::None` on the wire (GDScript can't pass typed
  nullables through GDExtension cleanly).
- `Net.broadcast_pet_command` wrapper with the usual CONNECTED_APP gate.
- `scripts/net/protocol.gd` (and launcher mirror) gain a `PetCommand`
  class mirroring the constants.
- `PetManager.command_attack(target=null)` routes through Net in
  launcher mode; pulls `Combat.current_target` if no arg, extracts
  `enemy_id` (RemoteEnemy) or `char_id` (RemotePlayer). Solo mode
  keeps the legacy local Pet path.
- `PetManager.command_back()` routes through Net in launcher mode.
- `command_guard` / `command_passive` print a "not yet implemented
  in multiplayer" hint rather than crash on RemotePet (which lacks
  `set_guard_target` / `set_mode`).
- `scripts/hud.gd` adds `/pet attack` and `/pet back` chat commands.

**Tests:** `pet_command_attack_locks_onto_target` — Necromancer summons
without first attacking the target, sends PetCommand::ATTACK, asserts
a Hit with attacker=pet, target=enemy. Proves the command bypasses
last_attacked_enemy inheritance.

## Piece A2 — Threat re-aggro on pet damage (server `23b6528`)

Pets that out-damage their owner now redirect enemy attacks onto
themselves. Closes the Track 11.4 "tank-by-out-positioning only" gap.

- `Entity` gains `threat: HashMap<EntityId, f32>` — separate from
  `aggro` (which still keys pet contributions under the owner so kill
  credit / XP routes correctly).
- Populated on three damage paths into enemies: player melee, player
  spell (helper), pet swing. Pets contribute under their own id;
  players under their char_id.
- `Entity::maybe_switch_target_by_threat` scans threat for an attacker
  exceeding the current target's threat by `THREAT_SWITCH_MULT = 1.3`
  AND still present in the AI's targets slice (alive + visible).
  Called at the top of `tick_chase` and `tick_attack`. No-op when
  target is `None`.
- `tick_leash` clears threat AND aggro on leash-home (fight reset
  semantics — existing attackers shouldn't carry residual threat into
  the next engagement).

**Test:** `pet_pulls_aggro_via_threat_reaggro` — walk player into camp,
get aggro'd, summon skel + send ATTACK command, send one bare-handed
Attack to seed player threat. Asserts an `EntityTarget` broadcast
switches the enemy from player to pet once skel swings (8 dmg × 2.2 s)
clear the 1.3× threshold. Timeout bumped to 35 s for parallel-suite
CPU contention.

## Piece B — Beast Master warder server-side (server `41f1004`)

Beast Masters auto-summon a Wolf warder on EnterWorld. Warder death
schedules a 15 s retreat-respawn at 30 % HP. Matches GDScript
`WarderAI` model — the original handoff's "in-combat retreat at 25% HP"
and "owner-low-HP fury" turned out to be speculative additions not
present in solo gameplay; followed GDScript instead.

- `pet_templates::lookup("warder")` returns a Wolf template (lvl 5,
  hp 60, dmg 6, speed 3.5, attack_interval 2.0). Faster than the
  skeleton, hits slightly less; differentiated via
  `pet_templates::is_warder_template(mob_name)`.
- `PerConnection` gains `warder_respawn_at: Option<Instant>`.
- New free function `summon_pet_for_owner(server, recipients,
  enemies, aoi, owner_id, spawn_pos, template, hp_fraction, now)`
  extracts despawn-existing + AOI register + AOI-filtered PetSpawn
  fan-out + map insert. Used by:
  - PET_SUMMON CastSpell arm (refactored to one-liner)
  - Beast Master auto-summon (phase 4g2)
  - Warder respawn sweep (phase 4g3)
- Phase 4g2: for each newly-EnterWorld'd connection with
  `class.eq_ignore_ascii_case("Beast Master")`, call the helper with
  `hp_fraction = 1.0`. Runs after the EntitySpawn fan-out so peers
  see player and warder land in the same tick.
- Phase 4g3: each tick, sweep connections for due `warder_respawn_at`;
  spawn at `hp_fraction = 0.3` and clear the timer.
- Enemy → pet hit dispatch: if dying pet matches `is_warder_template`,
  schedule `warder_respawn_at = now + WARDER_RETREAT_SECS (15.0)` on
  the owner. Non-warder pets just die.

**Tests:**
- `beast_master_auto_summons_warder` — class=Beast Master receives a
  PetSpawn with `pet_name=Wolf, level=5, max_hp=hp=60` immediately on
  EnterWorld.
- `non_beast_master_gets_no_auto_warder` — Warrior receives no
  PetSpawn for 2 s.
- `pet_templates::warder_resolves_and_is_classified` unit test.

## Piece C — PET_CHARM via id-partition re-key (server `65979de`)

Enchanter Charm (lvl 20, 60 s) and Bard Siren's Song (lvl 14, 30 s)
convert a targeted enemy into a player-owned pet by re-keying the id
partition: EntityDespawn the old enemy id, PetSpawn a fresh pet id at
the same pos with copied hp/max_hp/yaw, owner = caster. Charm decay
is "mob runs away" — silent EntityDespawn (no EntityDied / corpse
linger).

- `Spell` gains generic `duration: f32` (`#[serde(default)]`). Charm
  60 s, Siren's Song 30 s. Future single-duration mechanics share.
- `spells.toml` adds Charm + Siren's Song entries.
- `Entity` gains `charm_expires_at: Option<Instant>`. Set by the
  PET_CHARM arm at spawn time.
- PET_CHARM arm in CastSpell match:
  - Validates target_id is in enemy partition (`>= ENEMY_ID_BASE
    && < LOOT_BAG_ID_BASE`).
  - Extracts mob template + hp + max_hp + pos + yaw from target.
  - Fans AOI-filtered EntityDespawn for the old enemy id; removes
    from `enemies` + AOI.
  - Calls `spawner.on_enemy_died(old_idx)` so the camp's respawn
    timer arms (charmed mob doesn't permanently block the spawn slot).
  - Builds a fresh `Entity::from_pet_summon` with copied stats, sets
    `charm_expires_at`, inserts into `enemies` + AOI, fans
    AOI-filtered PetSpawn.
- Phase 4g4 charm decay sweep — scans enemies for pets with expired
  `charm_expires_at`, fans EntityDespawn, drops from enemies + AOI.

**Pet commands + threat re-aggro both just work on charmed pets** —
they're real Entity instances with `owner` set; the existing pipelines
don't care how they came into being.

**Test:** `charm_converts_enemy_to_pet` — Enchanter walks into camp,
casts Charm through the cast-bar flow, asserts EntityDespawn for the
enemy id and PetSpawn for a fresh pet id with `owner=caster` and
`pet_name` preserved from the mob template (charmed Decrepit Skeleton
stays named "Decrepit Skeleton").

## Test results

84 server tests pass (started Track 12 at 80; +4 new integration tests
and +1 unit test).

The two AI-walks-into-melee tests
(`enemy_aggros_chases_and_attacks_player`,
`player_attack_kills_enemy_and_corpse_despawns`) plus
`pet_pulls_aggro_via_threat_reaggro` continue to be intermittently
flaky under sustained parallel-binary CPU contention; pass in
isolation and stably with `--test-threads=1` in a fresh run. The
existing 35 s budget covers the typical worst case but a hot machine
can still tip them over. Same well-documented flakiness from Track 5
notes — not a new regression.

## Commits

- Server `61178b8` — Track 12 Piece A1 (PetCommand wire variant)
- Client `f1cbc5f` — Track 12 Piece A1 client (Net.broadcast_pet_command + /pet attack/back)
- Launcher `e38f89e` — protocol mirror
- Server `23b6528` — Track 12 Piece A2 (threat re-aggro)
- Server `41f1004` — Track 12 Piece B (Beast Master warder)
- Server `65979de` — Track 12 Piece C (PET_CHARM)

## Notes

- The Track 12 deferred items from the original handoff:
  - GUARD / SIT pet commands — reserved in wire format, no-op.
  - Multi-pet — Necromancer design implies multiple skeletons.
  - Pet weapon proc / crit / armor — pets still use flat template
    damage.
  - In-combat retreat at low HP / owner-low-HP fury — handoff
    speculated; not present in GDScript. Skipped.
- The lifesteal `heal_amount` on ENEMY-target spells (Lifetap, Soul
  Drain) is still unimplemented server-side — same waiting room as
  the base ranks. Carried to Track 13+.
- `export_spells.gd` remains stale (its SERVER_FIELDS list still
  predates the buff/CC/HoT/pet_type/duration fields). Hand-write
  approach is still holding; tool fix is a maintenance follow-up.
- Pet templates are still hard-coded in Rust rather than TOML-backed
  (zone_camps.toml / spells.toml pattern). Two templates is the
  current set; if a third lands, time to refactor.
