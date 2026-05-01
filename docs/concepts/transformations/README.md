# docs/concepts/transformations — Directory Index

Permanent or semi-permanent changes to what a character is — distinct from buffs, equipment, or leveling.
For the full index organized by category (Alignment Drift, Earned Permanent, Race-Specific), start with `transformations.md`.

---

## Master Reference

| File | Contents |
|---|---|
| [transformations.md](transformations.md) | **Transformation index** — all 34 transformations organized by category with triggers, alignment gates, level requirements, and file links; reversibility rules; stacking rules; start here |

---

## Alignment Drift (Reversible)

Triggered automatically when a class-tied character crosses an alignment threshold. Reverses if alignment shifts back.

| File | Transformation | Class | Trigger |
|---|---|---|---|
| [fallen_paladin.md](fallen_paladin.md) | Fallen Paladin | Paladin | Evil tier |
| [redeemed_shadow_knight.md](redeemed_shadow_knight.md) | Redeemed Shadow Knight | Shadow Knight | Exalted tier |
| [fallen_cleric.md](fallen_cleric.md) | Fallen Cleric | Cleric | Evil tier |
| [corrupted_druid.md](corrupted_druid.md) | Corrupted Druid | Druid | Evil tier |
| [enlightened_warrior.md](enlightened_warrior.md) | Enlightened Warrior | Warrior | Exalted tier |
| [tainted_monk.md](tainted_monk.md) | Tainted Monk | Monk | Evil tier |
| [dark_trapper.md](dark_trapper.md) | Dark Trapper | Rogue | Evil tier |
| [redeemed_necromancer.md](redeemed_necromancer.md) | Redeemed Necromancer | Necromancer | Exalted tier |

---

## Earned Permanent

Require alignment + class + level gates. Permanent once triggered.

| File | Transformation | Alignment | Level |
|---|---|---|---|
| [revenant.md](revenant.md) | Revenant | Evil | 20 |
| [the_hunger.md](the_hunger.md) | The Hunger | Evil | 18 |
| [vampire_lord.md](vampire_lord.md) | Vampire Lord | Evil | 25 |
| [lich.md](lich.md) | Lich | Evil | 30 |
| [lycanthrope.md](lycanthrope.md) | Lycanthrope | Neutral | 15 |
| [exalted.md](exalted.md) | Exalted | Exalted tier | 30 |
| [warden_of_the_wild.md](warden_of_the_wild.md) | Warden of the Wild | Exalted tier | 25 |
| [void_touched.md](void_touched.md) | Void-Touched | Neutral–Evil | 22 |
| [plague_bearer.md](plague_bearer.md) | Plague Bearer | Evil | 24 |
| [phantom.md](phantom.md) | Phantom | Neutral–Evil | 20 |
| [battle_fury_scar.md](battle_fury_scar.md) | Battle-Fury Scar | Neutral–Evil | 18 |
| [spirit_merged.md](spirit_merged.md) | Spirit Merged | Any | 28 |
| [beast_king.md](beast_king.md) | Beast King | Any | 25 |
| [elemental_fusion.md](elemental_fusion.md) | Elemental Fusion | Neutral | 26 |
| [seraphim_aspect.md](seraphim_aspect.md) | Seraphim Aspect | Exalted tier | 35 |
| [grove_heart.md](grove_heart.md) | Grove Heart | Exalted tier | 30 |
| [twice_tempered.md](twice_tempered.md) | Twice-Tempered | Good–Exalted | — |
| [demonbound.md](demonbound.md) | Demonbound | Evil | — |

---

## Race-Specific

Available only to one race. Tied to that race's mythology, biology, or history.

| File | Transformation | Race |
|---|---|---|
| [dragon_kin.md](dragon_kin.md) | Dragon Kin | Kobold |
| [kel_varath_ascendant.md](kel_varath_ascendant.md) | Kel`varath Ascendant | Kel`varath |
| [troll_ancient.md](troll_ancient.md) | Troll Ancient | Troll |
| [dark_spider_blessed.md](dark_spider_blessed.md) | Dark Spider-Blessed | Dark Elf |
| [fae_old.md](fae_old.md) | Fae-Old | Fae |
| [ancestor_vessel.md](ancestor_vessel.md) | Ancestor Vessel | Minotaur |
| [kobold_alpha.md](kobold_alpha.md) | Kobold Alpha | Kobold |
| [felhari_spirit_walker.md](felhari_spirit_walker.md) | Felhari Spirit-Walker | Felhari |

---

*Implementation: `PlayerStats.transformation` tracks state. `autoloads/transformations.gd` (stubbed) handles trigger checking and application.*
