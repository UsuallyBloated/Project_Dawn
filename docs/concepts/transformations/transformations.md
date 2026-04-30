# Transformations Index
*Permanent or semi-permanent changes to what a character is.*

Transformations are distinct from buffs and equipment. They redefine the character's body, nature, or relationship to the world. Most are irreversible. All are earned.

---

## Categories

### Alignment Drift (Class Hot-Swap)
Triggered automatically when a class-tied character crosses an alignment threshold. Rebuilds the spell and skill list without changing the stored class. Reverses if alignment shifts back.

| Transformation | Class | Trigger | File |
|---|---|---|---|
| [Fallen Paladin](fallen_paladin.md) | Paladin | Reaches Evil tier | fallen_paladin.md |
| [Redeemed Shadow Knight](redeemed_shadow_knight.md) | Shadow Knight | Reaches Exalted tier | redeemed_shadow_knight.md |
| [Fallen Cleric](fallen_cleric.md) | Cleric | Reaches Evil tier | fallen_cleric.md |
| [Corrupted Druid](corrupted_druid.md) | Druid | Reaches Evil tier | corrupted_druid.md |
| [Enlightened Warrior](enlightened_warrior.md) | Warrior | Reaches Exalted tier | enlightened_warrior.md |
| [Tainted Monk](tainted_monk.md) | Monk | Reaches Evil tier | tainted_monk.md |
| [Dark Trapper](dark_trapper.md) | Rogue | Reaches Evil tier | dark_trapper.md |
| [Redeemed Necromancer](redeemed_necromancer.md) | Necromancer | Reaches Exalted tier | redeemed_necromancer.md |

### Earned Permanent
Require alignment + class + level gates. Permanent once triggered. Cannot be reversed through normal play.

| Transformation | Alignment | Classes | Level | File |
|---|---|---|---|---|
| [Revenant](revenant.md) | Evil | Necromancer, Shadow Knight, Blood Mage | 20 | revenant.md |
| [The Hunger](the_hunger.md) | Evil | Any (accelerated for BM/SK) | 18 | the_hunger.md |
| [Vampire Lord](vampire_lord.md) | Evil | Blood Mage, Shadow Knight | 25 | vampire_lord.md |
| [Lich](lich.md) | Evil | Necromancer | 30 | lich.md |
| [Lycanthrope](lycanthrope.md) | Neutral | Ranger, Druid, Shaman, Monk | 15 | lycanthrope.md |
| [Exalted](exalted.md) | Exalted | Paladin, Cleric | 30 | exalted.md |
| [Warden of the Wild](warden_of_the_wild.md) | Exalted | Druid, Ranger | 25 | warden_of_the_wild.md |
| [Void-Touched](void_touched.md) | Neutral–Evil | Wizard, Sorcerer, Magician | 22 | void_touched.md |
| [Plague Bearer](plague_bearer.md) | Evil | Necromancer, Shaman | 24 | plague_bearer.md |
| [Phantom](phantom.md) | Neutral–Evil | Rogue | 20 | phantom.md |
| [Battle-Fury Scar](battle_fury_scar.md) | Neutral–Evil | Warrior, Monk | 18 | battle_fury_scar.md |
| [Spirit Merged](spirit_merged.md) | Any | Shaman | 28 | spirit_merged.md |
| [Beast King](beast_king.md) | Any | Beast Master | 25 | beast_king.md |
| [Elemental Fusion](elemental_fusion.md) | Neutral | Magician, Sorcerer | 26 | elemental_fusion.md |
| [Seraphim Aspect](seraphim_aspect.md) | Exalted | Paladin, Cleric | 35 | seraphim_aspect.md |
| [Grove Heart](grove_heart.md) | Exalted | Druid | 30 | grove_heart.md |
| [Twice-Tempered](twice_tempered.md) | Good–Exalted | Paladin (Fallen and returned) | — | twice_tempered.md |
| [Demonbound](demonbound.md) | Evil | Any | — | demonbound.md |

### Race-Specific
Available only to one race. Tied to that race's mythology, biology, or history.

| Transformation | Race | Alignment | File |
|---|---|---|---|
| [Dragon Kin](dragon_kin.md) | Kobold | Any | dragon_kin.md |
| [Kel`varath Ascendant](kel_varath_ascendant.md) | Kel`varath | Evil | kel_varath_ascendant.md |
| [Troll Ancient](troll_ancient.md) | Troll | Neutral–Evil | troll_ancient.md |
| [Dark Spider-Blessed](dark_spider_blessed.md) | Dark Elf | Evil | dark_spider_blessed.md |
| [Fae-Old](fae_old.md) | Fae | Any | fae_old.md |
| [Ancestor Vessel](ancestor_vessel.md) | Minotaur | Any | ancestor_vessel.md |
| [Kobold Alpha](kobold_alpha.md) | Kobold | Evil | kobold_alpha.md |
| [Felhari Spirit-Walker](felhari_spirit_walker.md) | Felhari | Neutral | felhari_spirit_walker.md |

---

## General Design Notes

**Reversibility:** Drift transformations reverse when alignment shifts back. Earned transformations are permanent by default. Quest-endpoint transformations (Twice-Tempered, Demonbound) are permanent but may have reversal quests at significant cost.

**Stacking:** Most transformations are mutually exclusive — you are one thing. Drift transformations (Fallen Paladin, etc.) can coexist with an earned transformation if the earned one was acquired before the drift, but this is an edge case to be ruled on per-case during implementation.

**Visibility:** Transformations should be visibly legible to other players. NPC reactions should reflect transformation state in addition to alignment tier.

**Implementation:** `PlayerStats.transformation` tracks state. `Transformations` autoload (stubbed in project.godot) handles trigger checking and application.
