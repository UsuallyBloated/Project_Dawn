# Track 10 Handoff — Server-side Cast-time Gating

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator. Four repos.

Tracks 1–9 closed the server-authoritative loop for movement,
visibility, enemy state, player stats, PvP, buffs / CC, groups,
AOI partitioning, ALLY peer-healing, and AOE damage. Track 10 closes
one last anti-cheat hole in the spell pipeline: **server-side
cast-time gating.**

Estimated half-session work — most infrastructure is already in place.

## The hole

Today the client decides when a cast completes. Flow:
1. Player presses spell key. `Spells.cast_spell()` starts the cast bar
   and broadcasts `CastStartBroadcast { spell_name, duration }`.
2. After `duration` seconds the client locally fires
   `Spells._apply_spell()` which broadcasts `CastSpell { spell_name,
   target_id }` *and* `CastCompleteBroadcast { spell_name }`.
3. Server processes `CastSpell` immediately on receipt — applies
   damage / heal / buffs without verifying the cast bar actually
   ran.

A modified client (or a packet replay) can send back-to-back
`CastStartBroadcast` + `CastSpell` with no real wait. Result: instant
nukes on every long-cast spell (Inferno 2.5 s, Meteor 3.5 s, Complete
Heal 8 s).

This was deferred when Track 6 sub-task 3b landed the server-side
spell handler. It's been sitting in the deferred list ever since.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `a224543` (Track 9 client: refresh stale AOE comment) |
| Server | `F:\Projects\server\` | `main` | `0ed2cbe` (Track 9: server-side AOE damage) |
| Launcher | `F:\Projects\launcher\` | `main` | `18da871` (protocol.gd: add SW_ENEMY_SPAWN / SW_ENTITY_TARGET tags) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS) |

Run `git -C <each> log --oneline -5` before touching anything.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_18_track9.md` — yesterday's
   work; Track 9 closeout. Helper extraction pattern matters here
   because cast gating slots into the same `CastSpell` arm.
3. `crates/projectdawn-server/src/world/connection.rs:213-225` —
   `PerConnection.cast_spell_name`, `cast_total_duration`,
   `cast_set_at` fields. **Track 4 already populates these.** That's
   the whole point — the cache exists, you just need to *check* it.
4. `crates/projectdawn-server/src/world/handlers.rs:237-255` —
   `CastStartBroadcast` / `CastCompleteBroadcast` arms. These set
   and clear the cache fields. Look at these to confirm you
   understand what's already tracked.
5. `crates/projectdawn-server/src/world/tick.rs:1298-1942` — the
   `CastSpell` intent processing loop. Cast-gate check goes near
   the top, before mana deduction (line ~1315).
6. `crates/projectdawn-server/src/world/spells.rs` — `Spell.cast_time`
   field. Instant casts (`cast_time == 0`) skip the gate entirely.
7. `tests/world_two_clients.rs:445-507` — `two_clients_cast_fanout`
   exercises the existing CastStart / CastComplete broadcast loop.
   Closest template for a "cast gate rejects too-early CastSpell"
   integration test.

---

## Scope

**In:**
- Server rejects `CastSpell` if `spell.cast_time > 0` and either:
  - No cast is in flight on `PerConnection`, OR
  - Cast in flight is for a different spell name, OR
  - Elapsed wall time < `cast_total_duration - tolerance` (tolerance
    ≈ 100 ms to absorb network jitter).
- Reject = log at info, do not deduct mana, do not apply effect,
  send back `CastFail { caster, reason }` so the client can clear
  its local cast bar if it somehow desynced.
- Clear the cast cache (`cast_spell_name`, `cast_total_duration`,
  `cast_set_at`) on successful `CastSpell` processing too — today
  only `CastCompleteBroadcast` clears them, which means a client
  that fires `CastSpell` without `CastCompleteBroadcast` leaves
  stale cache (low-stakes but tidy to close).

**Out:**
- **Movement-interrupt enforcement.** Spells with a cast time should
  fail if the caster moves during the cast. Today the client handles
  this — `Spells.try_interrupt_cast()` cancels the bar on damage /
  movement / target loss. Server-side interrupt detection (compare
  position at `cast_set_at` vs current) is its own track. Don't
  bundle.
- **Damage-interrupt enforcement.** Same — client handles via
  `try_interrupt_cast()` on enemy hit. Server tracks could be added
  but it's parallel work.
- **Silence / mez gate on `CastSpell`.** Already covered in Track 6
  sub-task 4d (`buffs::is_silenced` / `is_mezzed` checks gate the
  CastSpell intent before this gate would run). No change needed.
- **Cooldown gate.** Cooldowns are client-side only today. Lifting
  to server would close another hole but it's a separate concern
  with its own state model.
- **Cast bar movement interrupt for AOE / instant casts.** AOE casts
  have a cast bar; instant casts don't. Both already flow through
  the same gate logic via `cast_time > 0` discriminator.

## What's already in place

- `PerConnection.cast_spell_name: String` — empty when not casting.
- `PerConnection.cast_total_duration: f32`.
- `PerConnection.cast_set_at: Option<Instant>`.
- `handlers.rs:237 CastStartBroadcast` sets all three.
- `handlers.rs:247 CastCompleteBroadcast` clears all three.
- `Outcome::CastFailFanOut { caster, reason }` already exists; used
  for "cast interrupted by damage" today. Reuse for "too early".
- `Spell.cast_time: f32` in `spells.rs` — directly authoritative.

## The implementation

In `tick.rs`'s `CastSpell` arm (around line 1310, after the
`spells::lookup` early-return and the `connections.get(&caster_cid)`
early-return, **before** the mana-cost check):

```rust
// Track 10 — server-side cast-time gate. Instant casts (cast_time
// == 0) skip; for timed casts we require the caster to have a
// matching CastStartBroadcast on file with enough wall time elapsed.
if spell.cast_time > 0.0 {
    const CAST_TOLERANCE_MS: u64 = 100;
    let gate_ok = caster_conn.cast_spell_name == spell.name
        && caster_conn
            .cast_set_at
            .map(|set_at| {
                let elapsed = now.duration_since(set_at).as_millis() as u64;
                let required = (spell.cast_time * 1000.0) as u64;
                elapsed + CAST_TOLERANCE_MS >= required
            })
            .unwrap_or(false);
    if !gate_ok {
        tracing::info!(
            caster = intent.caster,
            spell = %spell.name,
            cast_time = spell.cast_time,
            in_flight = %caster_conn.cast_spell_name,
            "CastSpell rejected — cast-time gate (no matching CastStart or too early)"
        );
        // Tell the client to clear its cast bar in case of desync.
        handlers::fan_out_cast_fail(
            &mut server,
            &in_world_recipients_now,
            intent.caster,
            "cast not ready".into(),
        );
        continue;
    }
}
```

After the cast goes through (anywhere after mana deduction
succeeds, before the `match spell.target_type.as_str()`), clear the
cache:

```rust
if let Some(cc) = connections.get_mut(&caster_cid) {
    cc.cast_spell_name.clear();
    cc.cast_total_duration = 0.0;
    cc.cast_set_at = None;
}
```

(The existing `CastCompleteBroadcast` arm still clears them on the
broadcast path; this just covers the case where a client fires
`CastSpell` without the `CastCompleteBroadcast` follow-up.)

`fan_out_cast_fail` may or may not exist as a free helper — check
`handlers.rs`. The pattern is the same as `fan_out_hit`. If it
doesn't exist, add it next to its neighbours.

## Test plan

New integration test in `tests/world_two_clients.rs`, parked next to
`two_clients_cast_fanout`:

```rust
async fn cast_spell_rejected_before_cast_time() {
    // Provision a Magician. Fireball has cast_time 1.5 s.
    // Walk to camp 0 so an enemy is in range.
    // Send CastStartBroadcast { spell_name: "Fireball", duration: 1.5 }.
    // *Immediately* (within 100 ms) send CastSpell { spell_name: "Fireball", target_id: <enemy id> }.
    // Assert:
    //   - A CastFail with reason = "cast not ready" arrives.
    //   - No Hit arrives for the next 500 ms.
    //   - Caster's mana didn't decrease (HealthUpdate / ManaUpdate sequence).
}

async fn cast_spell_accepted_after_cast_time() {
    // Same setup. Send CastStartBroadcast. Wait 1.6 s. Send CastSpell.
    // Assert Hit arrives with attacker=caster, target=enemy.
}
```

Two tests minimum. The first proves the gate fires; the second
proves it doesn't false-positive past the threshold.

Both should pass with `--test-threads=1` against the existing
69-test baseline → 71 with the AOE test from yesterday → 73 with
the two new ones.

## Client changes (likely zero)

The client already broadcasts `CastStartBroadcast` before the cast
bar starts and `CastSpell` only after the bar finishes. As long as
the existing flow is unmodified, the server-side gate is invisible
to legitimate clients.

If the existing flow has any race where `CastSpell` ships before
`CastStartBroadcast` lands at the server (unreliable channel? out
of order?), you'd see false-positive rejections. Verify by checking
`spells.gd._apply_spell` — `Net.broadcast_cast_spell` should fire
*after* `Net.broadcast_cast_complete` (or the order should be such
that the server processes CastStart first in the same tick).

`CastStartBroadcast` goes on `CHANNEL_SYSTEM` (reliable ordered)
and `CastSpell` does too — they'll arrive in order at the server.
No client change needed.

If the test surfaces a real ordering issue, fall back to: client
sends `CastStartBroadcast` and waits 1 tick (~50 ms) before
sending `CastSpell`. But verify empirically first.

## Commit shape

Probably one server commit covering the gate + cache clear + two
tests. Client may need no commit.

Suggested message:
> Track 10: server-side cast-time gate on CastSpell

## Risks / gotchas

1. **Network jitter on cast bar duration.** A legitimate client
   under packet loss might arrive at `cast_set_at + cast_time + 80 ms`
   wall-clock; tolerance of 100 ms covers typical jitter but a
   degraded connection could false-positive. If playtest reports
   "Spell didn't go off!", widen the tolerance. 200 ms is the
   ceiling before it starts feeling cheaty.
2. **Cast cache stale across spells.** If a client casts Fireball
   (1.5 s) and then immediately Frost Bolt (instant) without sending
   `CastCompleteBroadcast` for Fireball, `cast_spell_name` is still
   "Fireball" when Frost Bolt arrives. The gate doesn't fire for
   instants so this is fine, but a subsequent timed cast would
   reject. The post-success clear handles this; just make sure it
   runs on every accepted `CastSpell`, including instants.
3. **Test flakiness on the second test.** `tokio::time::sleep(1.6 s)`
   plus the existing AI-walk approach pushes test wall time toward
   the ~30 s integration cap. Use a shorter-cast spell (Heal at 1.2 s,
   Smite at 0 s won't trigger the gate so it has to be a timed one).
   Or stub the cast time in the test via a test-only spell entry.

## After Track 10

Server-authoritative spell pipeline is feature-complete:
authentication of caster (Track 4), mana cost (Track 6 sub-task 3b),
silence / mez gate (Track 6 sub-task 4d), target validation (Track 6
sub-task 3b + Track 8 ALLY arm), damage / heal / CC application
(Track 6 + Track 8 + Track 9), AOI fan-out (Track 7 + Track 9
helper), and cast-time gate (Track 10).

Remaining big-ticket server-auth work after this:
- **Pet system** — Beast Master / Necromancer / Magician / Enchanter
  pets. Lifecycle (summon / die / despawn), AI, ownership. Mirrors
  Track 5's enemy lift but with player-side authority. Biggest
  remaining gameplay unblock for those four classes.
- **Server-side inventory** — anti-cheat. Currently the client is
  authoritative on its own inventory; loot pickup routes through
  the server for arbitration but the inventory itself is local.
- **Cooldown server-auth.** Smaller scope; could bundle with a
  Track 10 stretch goal if you want to lift more spell trust to
  the server.

Pick one and write the next handoff.
