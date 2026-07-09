# Racial XP Trade-offs (Troll regen model): design + build plan

**Written 2026-07-08 for handoff to a fresh Claude session.** This is HALF design decision, HALF
build plan. Nothing here is committed design: **every number and mapping below is a proposal for the
user to edit before any code is written.** Present the decision table, get the user's rulings, then
build the slices.

## Context for a fresh session (do not skip)

- **Two repos:** Godot 4.4 client at `f:\Projects\Project_Dawn` (GDScript), Rust server at
  `F:\Projects\server`. Branch `fix/xp-leveling-overflow`. LOCAL git only. Read `CLAUDE.md` first.
- **Leveling is EQ-authentic and server-authoritative** (committed 2026-06-26 to 07-08): per-level
  cost is the cubic `L^3 x 1000 x hell_mod(L)` (`char_data.rs`, mirrored byte-for-byte in
  `autoloads/player_stats.gd`, lockstep rule: edit both in one commit); per-kill XP is
  `mob_level^2 x ZEM x 3.5` (`progression::kill_xp`); ALL XP mutations flow through ONE choke point,
  `progression::award_xp`, and kill awards through `award_kill` in `world/tick.rs`. Death penalty:
  5% of the current band, floor at level 5. Level cap 60 (`world/skills.rs MAX_LEVEL`).
- **Research base:** `docs/design/everquest_xp_curve_reference.md`, section 5 + the "Racial
  trade-offs" subsection. Verified against P99: race XP modifiers were multiplicative on the
  requirement (Troll/Iksar -20%, Ogre -15%, Barbarian -5%, Halfling +5%, everyone else neutral), and
  the -20% races got **always-on faster HP regeneration** in exchange (~2 HP/tick sitting at low
  levels scaling to ~18 HP/tick at 60; ticks every 6s). Class penalties (hybrids -40% etc.) also
  existed and were REMOVED by Sony in Jan 2001 because they felt terrible.
- **The design principle the user cares about:** the trade-off stays COUPLED. Late EQ removed the XP
  penalty but kept the regen, which broke the bargain. If a race levels slower, the perk is why, and
  they ship together.
- **Workflow:** design sign-off first, then per-slice: build, adversarial review, playtest checklist
  (`docs/playtest_notes/TEMPLATE_checklist.md`), user playtests, THEN commit (one server + one client
  commit, exclude `.claude/*` + banker_slice2_checklist.md, trailer
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`). Server.log is UTF-16.

## Decision 1: where the modifier applies (recommendation: award-side)

- **Option A, requirement-side (EQ-literal):** multiply the per-level band by a race mod
  (`band = L^3 x 1000 x hell x race_mod`). Authentic, and the 5% death penalty scales with it
  automatically. COST: the band math is lockstep-mirrored client/server and feeds the XP bar,
  corpse `lost_xp`, res refunds, and the level-cap clamp; adding race to `xp_to_next_for` /
  `band_for` churns every caller on both sides.
- **Option B, award-side (recommended):** multiply positive XP GAINS by the race factor at the choke
  points (kill XP in `award_kill`, quest rewards in the `CompleteQuest` payout). One server-side
  table, zero wire change, zero lockstep churn, trivially re-tunable. Honest nuance to surface: the
  death penalty stays race-neutral (5% of the same band), so a -20% race feels deaths RELATIVELY
  harder than in EQ's requirement-side model. That is arguably in the spirit of the trade-off, but
  say it out loud to the user.
- Sub-decision under B: scale kill XP only, or kill + quest? Recommend BOTH (all gains), so the
  race identity is consistent; res refunds stay unscaled (they refund actual lost XP, which was
  race-neutral).

## Decision 2: the race table (DRAFT, every row is the user's call)

Our 16 races: Human, Elf, Dark Elf, Wood Elf, Gnome, Halfling, Dwarf, Half-Elf, Ogre, Troll,
Kel\`varath, Minotaur, Fae, Felhari, Kobold, Half-Ogre.

Proposed starting point (mirrors EQ's shape: MOST races neutral, a few strong trades):

| Race | XP rate | Coupled perk | Notes |
|---|---|---|---|
| Troll | **-20%** | **HP regeneration** (always-on, scales with level) | the direct EQ analog; buildable NOW |
| Ogre | -15% | frontal stun immunity | **BLOCKED: no stun mechanic exists** (server CC = mez/root/snare/attack-slow only). Either defer the perk, or pick an alternative (e.g. knockback immunity, or a flat melee damage-taken reduction from the front) |
| Half-Ogre | -10% | lesser version of the Ogre perk | optional; or neutral |
| Halfling | **+5%** | none (the bonus IS the perk) | the only positive rate, like EQ |
| Kobold | ? | ? | user's canvas; scavenger/tinker flavor |
| Minotaur | ? | ? | user's canvas; another natural "big + slow-XP" candidate |
| Kel\`varath, Fae, Felhari | ? | ? | user's canvas (note Fae already carry a real malus: carry capacity below the cloth kit) |
| Human, Elf, Dark Elf, Wood Elf, Gnome, Dwarf, Half-Elf | neutral | none | matches EQ (most races neutral) |

**Class XP penalties: recommend NO.** EQ's hybrid -40% was so disliked Sony deleted it. If the user
wants a nod to it, the Warrior/Rogue ~+9-10% bonuses are the gentle version, but default to racial
only.

## Decision 3: the Troll regen numbers

P99-shaped proposal, server tick is continuous (world/regen.rs), so express it as HP/sec equivalent
of the EQ per-6s tick: base racial bonus ~0.33 HP/s at low level scaling linearly to ~3 HP/s at 60,
roughly DOUBLED while sitting (the server knows seated state; the /camp system gates on it). Must be
visibly meaningful in a playtest: a Troll and a Human side by side after a fight, the Troll's bar
climbs noticeably faster. Numbers are tunable constants in one place.

## Build slices (after the user locks the table)

- **Slice 0 (no code): the user edits the table above** and rules on Decisions 1-3. Update this doc
  with the rulings.
- **Slice 1: the XP rate.** Server: `race_xp_mult(race: &str) -> f32` beside the quest/kill payout
  code (data table in `char_data.rs` or a small `races.toml`, mirrored as constants in
  `data/character_data.gd` for UI display, lockstep-commented both sides). Apply at `award_kill`
  (scale `base_xp` before the group split so the split stays fair) and the `CompleteQuest` payout.
  Tests: anchor the multiplier per race; a Troll kill pays floor(263 x 0.8) at level 1, etc.
  Client: show the XP rate in character creation (the race description panel) so the trade is a
  visible choice, not a hidden tax. No wire change.
- **Slice 2: Troll regen.** Server: racial bonus term in `world/regen.rs` HP regen (level-scaled,
  sitting-aware). Client: nothing functional (HP arrives via HealthUpdate), but add the perk line to
  the race description. Playtest: side-by-side regen race, and confirm the bonus does NOT stack
  weirdly with heal-over-time buffs or food (regen buffs are additive today; food/water gating is a
  separate open to-do).
- **Slice 3: the other perks,** each gated on its system existing (Ogre stun immunity waits for a
  stun mechanic; revisit when combat CC grows one).

## Exploit / balance review notes for the reviewer pass

The multiplier is server-side only (client display is cosmetic), so there is no forgery surface.
Check: the group split with mixed races (each member's OWN rate should apply to their share, decide
and test: recommended is applying the rate per-member AFTER the split, not to the pool, so one
Troll doesn't drag a group); res refunds and death penalties deliberately unscaled under option B
(assert in tests); Halfling +5% interacts with the once-ever quest payouts (fine, but anchor-test
the rounding); and the character-creation UI must match the server table exactly (a wrong label is
a player-trust bug).

## Definition of done

The user's locked table lives in this doc; a Troll levels visibly slower and regens visibly faster
in a two-client side-by-side; every rate matches its creation-screen label; tests anchor each race's
multiplier and the regen term; no change to wire, bands, death penalty, or res refunds.
