# Track 21 Handoff — Open scope (UI polish, mounts, or playtest signal)

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Track 20D closed the Track 16-19 cross-cutting cleanups (missing
server spells + named-mob `.tres` files). After 20D the
"trust-model story" is functionally complete — every player action
that needs server authority has it, and every visible cleanup gap
from the playtest log is plugged. Track 21 is **open scope**;
follow a fresh playtest signal or pick from the remaining menu.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_22_track20D.md` — Track 20D
   closeout. The "regen `items.toml` after editing `.tres`" workflow
   is what new item authoring looks like now.
3. `docs/playtest_notes/` — check for new files dated after
   2026-05-22.
4. `CLAUDE.md` To-Do list — the long-tail UI / content / mechanics
   items.

## Four repos at handoff

| Repo | Path | Branch |
|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` |
| Server | `F:\Projects\server\` | `main` |
| Launcher | `F:\Projects\launcher\` | `main` |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` |

Track 20D is uncommitted on both client and server. Recommended
first move: commit Track 20D.

## Recommended starting menu

In rough priority order; a new playtest note overrides everything.

### Option B (still open) — Target-of-target UI frame (~1 session)

Highest player-facing payoff that requires no design call. Group
play is currently broken without target-of-target — players can't
see what their tank is fighting or coordinate focus-fire.

Sketch:
- Add a `TargetOfTargetFrame` to `scenes/hud.tscn` next to the
  existing `TargetFrame`.
- Subscribe to `Combat.target_changed`. When the current target is
  an `Enemy`, read `enemy.target` (the entity it's attacking, if
  any) and render the target-of-target frame.
- For remote players, read `RemotePlayer.target_entity_id` (server
  fans `EntityTarget` already).
- Hide the frame when the chain doesn't resolve (no target, or
  target isn't engaged).

About 60–80 lines of GDScript + a HUD scene edit.

### Option C — Mount system (~1.5 sessions)

The to-do list lists Mount as a precondition for Animal Husbandry,
Spirit of Wolf stacking, and Selos' Melody interactions. Needs a
design call first (zone-level mount permission rules, dismount-on-
damage threshold, mount speed math vs Spirit of Wolf). Then client-
side implementation; server-auth lift is a follow-up.

### Option E — Spell damage interrupt (carry-forward from Track 19A)

Track 19A's interrupt hook only fires on melee Attack intents
(enemy + PvP). Spell damage (DoTs, AOE) on a casting player doesn't
trigger interrupt yet. Mechanical extension: call
`roll_cast_interrupt(...)` from each `apply_spell_damage_to_*` site
that targets a player. Probably 0.5 session.

### Option F — Skill cap rebalance (~0.5 session)

After Track 18 + 19A, fresh L1 characters still can't advance any
skill (`starting_value` equals `cap` at L1 because both use the same
formula `max_cap × level / 60` and integer division floors). If the
upcoming playtest flags "skill bars don't move," change
`starting_value` to a fraction of cap (e.g. `cap / 4`) in both
`world/skills.rs` and the three GDScript definition files. Test
adjustments: the snapshot test in `world_two_clients.rs` spot-checks
Warrior `1h_slashing = 4` (the current L1 cap); that assertion
needs updating.

### Option G — Multi-window chat (~2-3 sessions)

The biggest UI piece. Three sub-chunks from the to-do list:
- Multi-window framework (create / rename / delete; dock / float)
- Per-window message filters (right-click → MsgType checklist)
- Per-window display settings (alpha, font, default channel)

## Carry-forward beyond Track 21

- **L1 cap = starting score** — Option F above. Cheap fix; deferred
  for the next playtest's verdict.
- **`make_item` / `_parse_type` / `_parse_rarity` removed in 20D** —
  if a test or doc references them they'll fail loudly.
- **Memorize cost client-only** — server doesn't model the spell
  bar; forging a free memorize is harmless because casting still
  pays the full server-side gate.
- **Zone transitions** — gated by content. When the second zone
  lands, this is the next major server lift.

## Known flaky tests

`world_two_clients.rs` still has the documented AI-walks-into-melee
flake (1-3 intermittent failures per full-suite run; all pass in
isolation):
- `lifesteal_spell_heals_caster`
- `player_attack_kills_enemy_and_corpse_despawns`
- `enemy_aggros_chases_and_attacks_player`
- `pet_pulls_aggro_via_threat_reaggro` (caught in 20D's full-suite
  run; passes in isolation)
- `aoe_spell_damages_nearby_enemies`
- `pet_command_attack_locks_onto_target`

Track 20D's `.tres` lift doesn't touch combat AI; these flakes are
pre-existing and orthogonal.

## Suggested first move

Commit Track 20D (client + server). Then check
`docs/playtest_notes/` for any new files and let the user's signal
pick the direction. With no signal, **Option B (target-of-target
frame)** is the highest player-facing payoff with no design call
needed.
