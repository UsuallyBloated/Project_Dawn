# Session 2026-05-19 — Track 10: Server-side Cast-time Gate

## What was done

### The hole

Cast-time enforcement was deferred when Track 6 sub-task 3b landed the
server-side `CastSpell` handler. Server applied damage / heal
immediately on receipt regardless of whether the cast bar had
actually run. A modified client (or replay) could fire
`CastStartBroadcast` + `CastSpell` back-to-back to instant-cast every
long-cast spell — Inferno 2.5s, Meteor 3.5s, Complete Heal 8s, etc.

### Server (`world/tick.rs` + `world/handlers.rs`)

The `PerConnection` cast cache (`cast_spell_name`,
`cast_total_duration`, `cast_set_at`) has been populated by
`CastStartBroadcast` since Track 4; the gate just needs to read it.

**Ordering wrinkle.** `CastSpell` and `CastCompleteBroadcast` arrive
in the same incoming batch from the client. `CastCompleteBroadcast`
clears the cache. If the gate runs in the post-dispatch intent loop
(after all messages process), the cache is already cleared by the
time it fires → 100% false-positive rejection of legitimate casts.

**Fix.** Snapshot the cache state into `CastSpellIntent` at
`handle_message` time, plumb through `Outcome::CastSpellIntent` via
two new fields (`cast_name_at_dispatch: String`,
`cast_set_at_at_dispatch: Option<Instant>`). The gate reads the
snapshot, not the live cache.

**Gate logic** in the intent loop, before mana deduction:
- `spell.cast_time == 0` → skip (instant casts pass).
- `spell.cast_time > 0` → require:
  - `cast_name_at_dispatch == spell.name`, AND
  - `now.duration_since(cast_set_at_at_dispatch) + 100ms >= cast_time × 1000ms`.
- Reject path: `tracing::info!`, `fan_out_cast_fail(caster, "cast not ready")`,
  `continue` (no mana deduction, no effect).

100 ms tolerance absorbs network jitter; legitimate clients are well
clear, forged same-tick CastStart+CastSpell falls ~1500 ms short for
the typical 1.5 s cast.

**Cache clear on success.** Added to the same mutable borrow that
deducts mana, so a `CastSpell` arriving without a follow-up
`CastCompleteBroadcast` (or before it) doesn't leave stale cache
state that would gate the *next* timed cast. `CastCompleteBroadcast`
still clears too — they're idempotent.

### Tests (`tests/world_two_clients.rs`)

**Two existing tests broke and got fixed.**
- `two_clients_buff_snapshot_fanout` sent `CastSpell("Healing Wave")`
  directly. Healing Wave has `cast_time = 1.0`, so the gate now
  rejects it. Fix: prepend `CastStart`, pump three ticks to push
  the packet out, sleep 1100 ms, then send `CastSpell`.
- `aoe_spell_damages_nearby_enemies` (Track 9) sent `CastSpell("Inferno")`
  similarly. Same fix with a 2600 ms sleep for the 2.5 s cast.

**Test-only gotcha caught in the process.** `tokio::time::sleep`
doesn't advance the renet transport — packets sit in the send
buffer until the next `tick_one`. The naive order
"send_cast_start → sleep → send_cast_spell → pump" doesn't actually
wait the cast time on the server; the CastStart packet only goes
out *after* the sleep, so `cast_set_at` is recorded right before
CastSpell arrives. Correct order: "send_cast_start → pump → sleep
→ send_cast_spell → pump". All four affected tests use the new
pattern.

**Two new gate tests.**
- `cast_spell_rejected_before_cast_time`: queue `CastStart("Fireball", 1.5)`
  and `CastSpell("Fireball", Some(stub_id))` back-to-back, pump 4
  ticks. Assert: `CastFail { reason: "cast not ready" }` arrives;
  no `Hit` for the caster fires in the next 500 ms.
- `cast_spell_accepted_after_cast_time`: queue `CastStart("Healing Wave", 1.0)`,
  pump, sleep 1100 ms, queue `CastSpell("Healing Wave", None)`,
  pump. Assert: `BuffSnapshot { target: caster, buffs }` arrives
  containing `"Healing Wave"`; no `CastFail` fires. (BuffSnapshot is
  a cleaner "cast applied" signal than HealthUpdate here because
  HealthUpdate races against regen ticks.)

## Test results

72 tests pass (was 70):
- 52 unit
- 3 auth integration
- 1 world_smoke
- 14 world_two_clients (+2: `cast_spell_rejected_before_cast_time`,
  `cast_spell_accepted_after_cast_time`)
- 2 protocol

## Commits

- Server `fe74ec9` — "Track 10: server-side cast-time gate on CastSpell"

## Notes

- The server-authoritative spell pipeline is now feature-complete:
  caster auth (Track 4), mana cost (Track 6 sub-task 3b), silence/mez
  gate (Track 6 sub-task 4d), target validation (Track 6 + Track 8
  ALLY arm), damage / heal / CC application (Track 6 + Track 8 +
  Track 9), AOI fan-out (Track 7 + Track 9), and cast-time gate
  (Track 10).
- Movement-during-cast interruption is still client-side. A modified
  client could ignore its own self-cancel and the server would
  happily accept the cast. Closing that is a separate track (server
  tracks caster position at `cast_set_at`, compares to current pos
  in the gate). Not urgent — the cast-time floor is the bigger
  cheat vector.
- Cooldown gating is still client-side. Less critical because
  client-side cooldowns are part of the spell's authoring (an
  attacker bypassing cooldown gets at most a per-spell rate boost,
  not free infinite damage like cast-time bypass would). Could
  bundle into a "spell trust closeout" track later.
- Pre-existing dead-code warning on `BuffSnapshotFanOut` remains; it
  was deprecated when sub-task 4a moved buff fan-out to server
  origination, and removing it would be a protocol churn we're not
  taking on yet.

## Track 6 deferred follow-ups still outstanding

Refreshed list after Track 10:
- Pet system (Track 11 — handoff written this session).
- Server-side inventory (anti-cheat).
- Movement-during-cast interrupt (server-side enforcement).
- Cooldown server-auth (smaller scope; could bundle with another
  spell-trust track).
- Lifesteal mechanic for `heal_amount` on ENEMY-target spells
  (Lifetap, Soul Drain, Lifetap Rk. II, Soul Drain Rk. II — already
  in spells.toml but heal_amount field is ignored server-side).
