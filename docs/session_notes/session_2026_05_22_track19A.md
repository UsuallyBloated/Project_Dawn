# Track 19A — Server-authoritative cast interrupt on incoming damage

Date: 2026-05-22 (continuation from Track 18).

Closes the Track 18 carry-forward note: channeling skill advance on
cast-interrupt-survived now lives server-side, alongside the
interrupt roll itself. Before this track the server didn't model
cast interrupts at all; the client rolled locally on incoming
damage, but with Track 18's `try_advance` gate the advance side was
silently broken in launcher mode. This track lifts the whole
interrupt decision server-side.

## Server changes

**`world/skills.rs`** — new `channeling_interrupt_chance(score, cap)
-> f32` helper. Mirrors GDScript
`CastingSkills.get_interrupt_chance`:
- `cap == 0` (non-caster) → 1.0 (always interrupted).
- Trained classes: `max(0.10, 0.70 - (score/cap) * 0.60)`.

Plus a 4-case unit test covering 0/0, 0/100, 50/100, 100/100, and
over-cap.

**`world/tick.rs`** — new `roll_cast_interrupt(conn)` helper that
returns an `InterruptOutcome` enum (`NotCasting` / `Interrupted {
spell_name }` / `Survived { advanced_to }`). Mutates the cast cache
+ channeling score in place; the caller handles fan-out. Used from
two sites:

1. **Enemy-on-player damage** (the `enemy_hits` loop, where Track
   18.1e wired armor advance) — after applying HP delta, call the
   helper. Interrupt → `fan_out_cast_fail(...,"interrupted (hit
   during cast)")`. Survive + advance → `send_skill_progress_update`
   for channeling.

2. **PvP attack** (the `target_id < ENEMY_ID_BASE` arm of the
   `AttackIntent` loop) — same call after the damage block exits.
   Re-borrows `target_conn` from `connections.get_mut` since the
   damage block's let-binding has already released it.

## Client changes

**`autoloads/spells.gd::try_interrupt_cast`** early-returns in
launcher mode. The server now owns the roll and fans CastFail on
interrupt; the existing `RemotePlayerManager._on_cast_fail` handler
(self-caster branch) already routes own CastFails through
`Spells.cancel_cast()` + logs the reason. So no other client-side
plumbing is needed.

Solo / Test Room keeps the local roll — both
`Combat.receive_player_damage` (line 343) and
`RemotePlayerManager._on_health_update` (line 247) still call
`try_interrupt_cast`, and in non-launcher mode the function still
rolls.

## Tests

**Lib**: 116/116 pass (+1: `channeling_interrupt_chance_bounds`).

**Integration**: 40/40 pass (+1:
`cast_interrupted_by_incoming_pvp_hit`). The new test uses two
Warriors over PvP to dodge the AI-walks-into-melee flake pattern.
Warrior has `channeling` cap = 0, so the interrupt chance is 1.0
and the test is deterministic. Sequence:
1. Both clients connect + EnterWorld.
2. Both send `PvpToggle { on: true }`.
3. A sends `CastStartBroadcast("Fake Long Cast", 5.0)` — the
   server doesn't validate class on CastStart, so a Warrior can
   "claim" to be casting; validation happens at CastSpell time.
4. B sends `Attack` targeting A. Both spawned at the same
   DB-loaded position so they're in melee range immediately.
5. Test waits for `CastFail { caster: A, reason: "interrupted
   (hit during cast)" }`.

Full-suite re-run had the documented `pet_command_attack_locks_onto_
target` flake under parallel load (passes in isolation). Not a
Track 19A regression — that test is in the AI-walks-into-melee
category the handoff has been calling out since Track 11.

## Files touched

Server (`F:\Projects\server\`):
- `crates/projectdawn-server/src/world/skills.rs`
  (channeling_interrupt_chance + unit test)
- `crates/projectdawn-server/src/world/tick.rs` (InterruptOutcome
  enum + roll_cast_interrupt helper, wired into enemy + PvP paths;
  `use rand::Rng` added)
- `crates/projectdawn-server/tests/world_two_clients.rs`
  (`send_pvp_toggle` helper + new integration test)

Client (`F:\Projects\Project_Dawn\`):
- `autoloads/spells.gd` (launcher-mode gate in
  `try_interrupt_cast`)

## Carry-forward

- **Spell damage during cast** — spell damage (DoT ticks, AOE) on
  a casting player doesn't yet trigger interrupt. The current
  Track 19A path only covers melee Attack intents (enemy + PvP).
  Adding it to the spell damage paths is mechanical — same helper
  call from each `apply_spell_damage_to_*` site that targets a
  player. Probably half a session.
- **PvP-cast-while-stationary edge** — a PvP attacker hitting a
  stationary caster works, but the existing PvP arm requires both
  /pvp on. If duel-acceptance is added later, gate the interrupt
  the same way.
- **Channeling skill cap at L1 still equals starting value** —
  same gotcha as the other casting skills (carry-forward from
  Track 18). Cleric L1 channeling: cap 2, start 2; advances only
  start landing once the character levels up enough for the cap
  to outpace the starting score.
