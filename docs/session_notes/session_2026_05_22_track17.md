# Track 17 — Memorize cost / cap + cast cooldown & movement server-auth

Date: 2026-05-22 (same-day continuation from Track 16).

Track 17 tightens the spell pipeline: memorize is no longer free
(half mana cost + 2 s cast bar + cancellable), the spell bar caps to
the player's level, and the server now owns per-spell cooldowns plus
a movement-during-cast interrupt. Closes carry-forwards from Tracks
14 / 15 / 16.

## 17.1 — Client: memorize cost + level-gated bar

`autoloads/spell_bar.gd` extensions:
- `MIN_SLOTS = 3`, `SLOTS_PER_LEVEL_TIER = 5`. New
  `max_slots_for_level(level=-1)` returns `clampi(MIN_SLOTS + lvl/5,
  MIN_SLOTS, SLOT_COUNT)` — L1 starts with 3 unlocked, +1 every 5
  levels, all 10 unlocked at L35.
- `is_slot_unlocked(slot)` + `unlock_level_for_slot(slot)` accessors.
- `set_slot` rejects assignments to locked slots (clears are always
  allowed).
- New `cap_changed(new_cap)` signal fires on `PlayerStats.level_changed`
  so the hotbar can re-render the lock badges.

`autoloads/memorize.gd` rewrite — the candidate state from 16.1 is
still there, but slot assignment now goes through `commit(slot)`:
- `MEMORIZE_CAST_TIME = 2.0 s`, `MEMORIZE_COST_FACTOR = 0.5`,
  `MEMORIZE_MOVE_CANCEL_DIST = 0.5 m`.
- `can_commit(slot)` returns `{ok, reason}` — checked before commit
  starts: candidate exists, slot unlocked, player sitting, mana
  available. Surfaces specific reasons ("Slot 7 unlocks at level
  20.", "Not enough mana to memorize.") to the combat log.
- `commit(slot)` snapshots position + starts the 2 s timer; emits
  `memorize_started(spell, duration)`.
- `_tick_commit(delta)` runs in `_process` while committing —
  cancels on stand, on >0.5 m movement, on candidate change. On
  completion, debits mana, calls `SpellBar.set_slot`, emits
  `memorize_completed`.
- Re-issuing commit on the same (spell, slot) is a no-op so a
  double-click doesn't reset the bar partway.
- New signals: `memorize_started`, `memorize_progress`,
  `memorize_cancelled(reason)`, `memorize_completed(spell, slot)`.
- Public accessors `get_commit_spell()` / `get_commit_slot()` so
  the hotbar doesn't reach into private state.

`scripts/hotbar.gd` visual + routing changes:
- New `C_MEMORIZE_FILL` lavender colour for the in-slot progress
  overlay (distinct from cooldown's black fill).
- Each spell-bar slot gets a `memorize_overlay: ColorRect` (bottom-
  anchored, anchor_top tracks elapsed/total) and a `lock_label:
  Label` (shows "Lv N" on slots above the cap).
- `_refresh_spell_slots` reads `SpellBar.is_slot_unlocked(i)` and
  paints lock badges + dims modulate (0.35) on locked slots.
- `_on_spell_clicked` left-click + candidate now routes through
  `Memorize.commit(index)` instead of writing the slot directly.
- Memorize lifecycle handlers (`_on_memorize_started/_progress/
  _cancelled/_completed`) paint the candidate icon onto the target
  slot during the cast and drive the lavender overlay's anchor.
- Hotkey bar's candidate route (16.1) removed — memorize gestures
  now resolve exclusively through the spell bar (where the cost +
  cast bar are enforced). Assign-spell-to-hotkey still works via
  the context menu's `Assign Spell...`.
- Subscribed to `SpellBar.cap_changed` so level-up re-renders the
  lock state.

## 17.2 — Server: cooldown gate + movement-during-cast gate

`crates/projectdawn-server/src/world/connection.rs`:
- New `cast_start_pos: Vec3f` on `PerConnection` — captured at
  CastStartBroadcast handling.
- New `spell_cooldowns: HashMap<String, Instant>` — per-player
  per-spell next-ready time. Cleared on disconnect via the existing
  `connections.remove(&cid)` (no separate cleanup needed).

`world/handlers.rs`:
- `CastStartBroadcast` arm now stamps `conn.cast_start_pos = conn.pos`
  alongside the existing cast cache fields.
- `Outcome::CastSpellIntent` gained `cast_start_pos_at_dispatch` —
  snapshotted at dispatch so a same-batch CastComplete can't blank
  the field before the gate fires (matches the existing pattern
  from Track 10).

`world/tick.rs`:
- Local `CastSpellIntent` struct mirrored.
- Cast gate (existing after the cast-time check) extended:
  1. **Movement gate** (timed casts only) — compares current pos
     to snapshot; >5.0 m fails with `interrupted (moved)`. Cast
     cache also cleared so the next cast isn't stuck behind the
     stale in-flight state.
  2. **Cooldown gate** (all casts, including instant) — looks up
     `spell_cooldowns.get(&spell.name)`; if the entry is in the
     future, fails with `Spell is on cooldown.` and skips dispatch.
- After mana deduction in the successful-cast path, the server
  stamps `spell_cooldowns.insert(name, now + spell.cooldown)` when
  `cooldown > 0`. Damage spells with `cooldown = 0` are unaffected.

**5 m movement threshold rationale**: STALE_MOVE_THRESHOLD lets the
server keep integrating `latest_direction` for 500 ms after the last
Move (so a crashed client doesn't visually freeze instantly). At
MAX_MOVE_SPEED = 7.5 m/s, that's ~3.75 m of post-stop coast. A
1 m threshold would false-positive on the natural "stop walking,
sit, cast" flow. 5 m absorbs the coast while still catching
continuously-moving forgeries (which drift ~7.5 m/s × cast time,
easily clearing the gate).

## Tests

Two new integration tests in
`crates/projectdawn-server/tests/world_two_clients.rs`:

- `cast_spell_rejected_during_cooldown` — Cleric casts Healing
  Wave (1.0 s cast, 6 s cooldown) once; BuffSnapshot confirms it
  lands. Recasts following the full gate flow; second cast is
  rejected with `Spell is on cooldown.` because we're well inside
  the cooldown window.
- `cast_spell_rejected_when_caster_moved_during_cast` — Cleric
  sends CastStart for Healing Wave, then sends Move messages for
  ~1.1 s of the cast (~8 m on the server), then sends CastSpell
  past the cast-time gate. Rejected with `interrupted (moved)`.
  Asserts no BuffSnapshot for Healing Wave fires.

Tests pass: 4 cast-gate tests + the previously-flaky
`pet_pulls_aggro_via_threat_reaggro` all green in isolation. Full
suite re-run had the same pre-existing AI-walks-into-melee timing
flake the Track 16 handoff documented (`pet_pulls_aggro_via_threat_reaggro`
intermittently fails "enemy targets the player initially" under
parallel-test scheduling pressure); not a Track 17 regression.
Lib tests: 111/111 pass.

## Files touched

Client (`F:\Projects\Project_Dawn\`):
- `autoloads/spell_bar.gd` (17.1a — cap + signals)
- `autoloads/memorize.gd` (17.1b — commit flow)
- `scripts/hotbar.gd` (17.1c+d — reroute + visuals)

Server (`F:\Projects\server\`):
- `crates/projectdawn-server/src/world/connection.rs` (cooldown map,
  cast_start_pos)
- `crates/projectdawn-server/src/world/handlers.rs` (CastStart
  stamp, intent extension)
- `crates/projectdawn-server/src/world/tick.rs` (movement +
  cooldown gates, cooldown stamp)
- `crates/projectdawn-server/tests/world_two_clients.rs` (2 new
  tests)

`cargo +1.95.0 check -p projectdawn-server` clean (one pre-existing
dead-code warning, not Track 17's).

## Carry-forward

- **Skill leveling server-auth** — WeaponSkills / ArmorSkills /
  CastingSkills are still client-only. Same pattern as cooldowns:
  per-player skill map server-side, mutations on the server's
  attack / cast paths.
- **Zone transitions** — large track when a second zone lands.
- **Hotkey bar spell shortcut bypasses memorize** — the context
  menu's `Assign Spell...` writes a spell to a hotkey-bar slot
  with no memorize cost. Execution paths through `Spells.cast_spell`
  which doesn't check whether the spell is also in SpellBar. Strict
  classic-feel would require either (a) hotkey-bar spell slots
  only cast if the spell is memorized, or (b) drop spell assignment
  from the hotkey bar entirely. Deferred — needs a design call.
- **Memorize requires sitting at click-time only** — the client
  gate checks `state == SITTING` at can_commit and during the
  cast. A forged client could lie. Server doesn't model the
  memorize bar at all today, so memorize cost forgery is
  client-side; lift to server if it becomes a vector.
- **Memorize cancellation reasons in combat log** — the current
  text reads "Memorize interrupted (moved)." Tighten to
  capitalised forms or move them out of CombatLog if they're noisy
  in practice.
