# Track 22 Handoff — Open scope (playtest signal or remaining menu)

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Track 21B closed the highest-leverage UI gap (target-of-target
frame). The Track 18-21B run lifted the netcode trust model to
complete, plugged the visible playtest gaps, and delivered the most-
asked-for group-play UI. Track 22 is **open scope** — best path is
to wait for fresh playtest feedback that exercises 21B's manual
verification checklist, then react.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_22_track21B.md` — Track 21B
   closeout. Includes a **Verification checklist for the next
   playtest** that should be the first thing run.
3. `docs/playtest_notes/` — check for new files dated after
   2026-05-22.

## Four repos at handoff

| Repo | Path | Branch |
|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` |
| Server | `F:\Projects\server\` | `main` |
| Launcher | `F:\Projects\launcher\` | `main` |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` |

Track 21B is uncommitted on the client (no server changes). Roll
the commit when starting Track 22.

## Recommended priority

### Top priority — playtest the 21B checklist

Before any new code, run the 21B verification checklist from the
session notes. If anything in the matrix doesn't behave as
described, fix forward before tackling new scope. Likely failure
modes:
- ToT shows stale HP after entity despawn (carry-forward in
  notes).
- Local enemy ToT doesn't update on IDLE → CHASE transition
  (also carry-forward; cosmetic in solo mode).

### Remaining menu (from earlier handoffs)

In rough priority order if no playtest signal arrives:

**Option C — Mount system (~1.5 sessions)**. Needs a design call
first (zone-level mount permission, dismount-on-damage threshold,
mount speed math vs Spirit of Wolf). Then client-side
implementation; server-auth lift is a follow-up.

**Option E — Spell damage interrupt (~0.5 session)**. Track 19A's
interrupt only fires on melee Attack intents (enemy + PvP). Spell
damage (DoT ticks, AOE) on a casting player doesn't trigger
interrupt yet. Mechanical extension: call
`roll_cast_interrupt(...)` from each `apply_spell_damage_to_*`
site that targets a player.

**Option F — Skill cap rebalance (~0.5 session)**. Fresh L1
characters still can't advance any skill (`starting_value == cap`
at L1). If playtest flags "skill bars don't move," change
`starting_value` to a fraction of cap (e.g. `cap / 4`) in both
`world/skills.rs` and the three GDScript definition files.

**Option G — Multi-window chat (~2-3 sessions)**. The biggest UI
piece. Three sub-chunks per the to-do list.

**Option H — Peer→peer target broadcast (~0.5 session)**. Track
21B's ToT works for tracked-enemy targets but stays hidden when
tracking a remote player (server doesn't broadcast peer→peer
targeting yet). Add a `ClientWorldMsg::TargetUpdate { target_id:
Option<EntityId> }` + `ServerWorldMsg::PlayerTarget` fan-out,
mirror the EntityTarget pattern. Closes the last "ToT
sometimes empty" mystery.

**Option I — UI portrait** (player race/class). Art assets exist
in `docs/concepts/lore/portraits/`. Drop a TextureRect into the
HUD panel, build a `(race, class) → path` lookup. Small lift,
under half a session.

## Carry-forward beyond Track 22

- **L1 cap = starting score** (Option F). Cheap; deferred for
  next playtest's verdict.
- **Memorize cost client-only** — server doesn't model the spell
  bar. Forging a free memorize is harmless because casting pays
  the full server-side gate. Lift only with reason.
- **Zone transitions** — server-side zone routing, world-token
  re-issue, position handoff, AOI grid per zone. Gated by
  content; when the second zone lands, this is the next major
  server lift.
- **ToT for tracked remote players** (Option H above) — pending
  the peer→peer target broadcast.
- **`make_item` / `_parse_type` / `_parse_rarity` removed in 20D**
  — if any test or doc references them they'll fail loudly. Not
  expected to surface but worth noting if a future refactor
  trips on it.

## Known flaky tests

`world_two_clients.rs` has the documented AI-walks-into-melee
flake (1-3 intermittent failures per full-suite run; all pass in
isolation):
- `lifesteal_spell_heals_caster`
- `player_attack_kills_enemy_and_corpse_despawns`
- `enemy_aggros_chases_and_attacks_player`
- `pet_pulls_aggro_via_threat_reaggro`
- `aoe_spell_damages_nearby_enemies`
- `pet_command_attack_locks_onto_target`

Track 21B doesn't touch server code; these flakes are pre-existing.

## Suggested first move

Commit Track 21B (client only). Then walk the verification
checklist in `session_2026_05_22_track21B.md` either via a
two-client launcher session or by asking the user to confirm.
Direct the next track based on what the checklist reveals.
