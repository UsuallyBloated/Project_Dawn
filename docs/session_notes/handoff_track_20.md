# Track 20 Handoff — Open scope (B/C/D menu carry-forward)

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Track 19A (2026-05-22) closed the last server-auth gap: cast
interrupt on incoming damage. The original Track 19 handoff
listed four options (A/B/C/D); A is now done. Track 20 picks from
the remaining three or follows a fresh playtest signal.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_22_track19A.md` — Track 19A
   closeout. The `InterruptOutcome` enum + `roll_cast_interrupt`
   helper pattern is the template if a new "on-damage side effect"
   needs to fan out.
3. `docs/playtest_notes/` — check for new files dated after
   2026-05-22.
4. `CLAUDE.md` To-Do list — long-tail UI / content / mechanics
   items.

## Four repos at handoff

| Repo | Path | Branch |
|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` |
| Server | `F:\Projects\server\` | `main` |
| Launcher | `F:\Projects\launcher\` | `main` |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` |

Track 19A changes are uncommitted on both client and server. Roll
a commit when the boundary feels clean.

## Recommended starting menu

In rough priority order. If a new playtest note exists, it overrides.

### Option B — UI polish item (~1 session)

Most user-visible payoff. From the to-do list:
- **Target-of-target frame** — show what your target is targeting
  next to the existing target frame. Already partially tracked
  server-side (enemies expose `target` and the server fans
  `EntityTarget`); add a small frame that reads
  `Combat.current_target.target` and displays its name + HP bar.
  Essential for group play.
- **Player portrait** — race/class portrait in the HUD panel. Art
  assets exist in `docs/concepts/lore/portraits/`. Needs a
  TextureRect in the HUD panel plus a portrait-lookup table keyed
  by `(race, class)`.
- **EQ-style multi-window chat system** — biggest piece. Three
  sub-chunks per the to-do list: multi-window framework + per-window
  message filters + per-window display settings. Probably 2-3
  sessions total.

### Option C — Mount system (~1.5 sessions)

The to-do list lists Mount as a precondition for Animal Husbandry,
Spirit of Wolf stacking, and Selos' Melody interactions. Design
sketch first (zone-level interaction + speed modifier rules), then
client-side implementation. Server-auth lift is a follow-up if PvP
mount-rules need it.

### Option D — Cross-cutting cleanups (~0.5–1 session)

Still open:
- **Soul Drain + Bind Affinity in `spells.toml`** — ~10 lines of TOML
  to silence "unknown spell name — server-side cast dropped" logs.
  Verify the GDScript-side fields match the toml schema; regen via
  the export script if needed.
- **Named-mob runtime loot has no `.tres`** — author ~15 `.tres`
  files from `data/named_mob_definitions.gd` inline dicts (Chitinous
  Ring, Pristine Venom Sac, etc.); regen `items.toml`. Until this
  lands, server rejects equip/sell/destroy on these items.
- **Destroy button "some items not others"** — still no repro. If
  the user follows up, look at `bag_window._confirm_destroy` +
  `drag_source_*` state.

### Option E — Spell damage interrupt (carry-forward from 19A)

Track 19A's interrupt covers melee Attack (enemy + PvP) only. Spell
damage on a casting player (DoT ticks, AOE) doesn't yet trigger
interrupt. Mechanical extension: call `roll_cast_interrupt(...)` from
each `apply_spell_damage_to_*` site that targets a player. Probably
0.5 session.

## Carry-forward beyond Track 20

- **Skill cap at L1 = starting score** — characters can't advance
  any skill until level-up grows the cap (`max_cap × level / 60`
  rounds toward zero so L1 starting ≈ L1 cap). If the upcoming
  playtest flags this, change `starting_value` to a fraction of cap
  in both `world/skills.rs` and the three GDScript definition
  files.
- **Memorize cost client-only** — server doesn't model the spell
  bar. Forging a free memorize is harmless because casting still
  pays the full server-side gate. Lift if there's a reason.
- **Zone transitions** — server-side zone routing, world-token
  re-issue or re-handshake, position handoff, AOI grid per zone.
  Gated by content; when the second zone lands, this is the next
  major server lift.

## Known flaky tests

`world_two_clients.rs` still has the documented AI-walks-into-melee
flake (1-3 intermittent failures per full-suite run, all pass in
isolation). The expanded list as of 19A:
- `lifesteal_spell_heals_caster`
- `player_attack_kills_enemy_and_corpse_despawns`
- `enemy_aggros_chases_and_attacks_player`
- `pet_pulls_aggro_via_threat_reaggro`
- `aoe_spell_damages_nearby_enemies`
- `pet_command_attack_locks_onto_target` (newly observed in 19A's
  full-suite run; same category)

Track 19A's new `cast_interrupted_by_incoming_pvp_hit` is stable
(uses PvP, not AI).

## Suggested first move

Commit Track 19A (server + client). Then check
`docs/playtest_notes/` for any new files and let the user's signal
pick the Track 20 direction. With no signal, **Option D Soul Drain
TOML + named-mob `.tres` files** is the highest-ROI: fixes visible
playtest issues, no design decisions needed, low test-flakiness
risk.
