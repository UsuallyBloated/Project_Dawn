# Two-Handed Weapon Damage Arc (Cleave) — Design Note

> Status: **idea / not started.** Floated 2026-06-11. Captured for later work.

## The idea

Large two-handed weapons (greatswords, two-handed axes, polearms) get a **frontal
arc cleave** on auto-attack: a swing can hit more than one enemy in a cone in front of
the player, instead of only the current target.

## Why

Today the only thing separating a 2H weapon from dual-wielding is damage-per-swing vs.
swings-per-second — same single-target math, different cadence. A cleave gives 2H its
own identity: *fewer, slower hits, but they splash*. That's a real tradeoff to build
around rather than a bigger number.

## Open decisions (settle before building)

1. **Departure from the EQ-era pillar.** Classic EQ melee was strictly single-target;
   AoE-on-swing is a more modern (WoW/ARPG) feel. It directly weakens the "a bad pull
   that grabs 3 mobs is dangerous" tension this game leans on — a cleave weapon quietly
   auto-handles that danger. So gate it hard:
   - small secondary-target cap (2–3 extra),
   - reduced damage to secondary targets (~50%),
   - narrow cone (~90–120° front).
2. **Arc = frontal cone, not radius splash.** This is the genuinely new mechanic. Spell
   AoE here (`Combat.deal_aoe_spell_damage`) is pure radius with no facing check. A true
   arc needs a `forward.angle_to(to_enemy) < half_cone` test, so which secondary targets
   get hit depends on where the player is aimed. Confirm this is the intent vs. a 360°
   splash.
3. **Not every 2H cleaves.** Likely axes/polearms cleave while a 2H mace stays
   single-target high-impact. Implies a per-weapon flag/affix (e.g. `cleave_arc`), not a
   blanket behavior keyed off `is_two_handed`.

## Implementation sketch (rough — not a plan yet)

- **Items:** `ItemData` already has `is_two_handed` ([scripts/item_data.gd:30](../../scripts/item_data.gd#L30)).
  Add an opt-in cleave flag/affix; don't key purely off `is_two_handed`.
- **Targeting:** `RemoteEnemyManager` can enumerate nearby enemies; filter them through
  the cone test relative to player facing.
- **Damage path:** auto-attack runs through `Combat._on_auto_attack` →
  `deal_damage_to_target` ([autoloads/combat.gd:201](../../autoloads/combat.gd#L201)).
  Cleave needs to resolve **server-side** like spell AoE already does (the AoE arm exists
  from `deal_aoe_spell_damage`), or melee desyncs across the wire.
- **Balance hooks:** secondary-target damage multiplier, target cap, cone half-angle —
  all per-weapon-tunable.
