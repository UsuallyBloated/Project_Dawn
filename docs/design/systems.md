# Project Dawn — Systems Design Reference

## Races

| Race | STR | DEX | AGI | INT | WIS | CHA | CON | Notes |
|---|---|---|---|---|---|---|---|---|
| Human | 10 | 10 | 10 | 10 | 10 | 10 | 10 | Balanced; no restrictions |
| Elf | 8 | 12 | 12 | 13 | 12 | 11 | 8 | High INT/AGI; low CON |
| Half-Elf | 10 | 11 | 11 | 11 | 11 | 11 | 9 | Versatile; slight dip to CON |
| Dwarf | 13 | 9 | 8 | 9 | 12 | 8 | 14 | Tanky; low mobility |
| Gnome | 7 | 13 | 10 | 14 | 11 | 10 | 8 | INT specialist; Tinkering racial bonus |
| Halfling | 8 | 14 | 12 | 10 | 10 | 12 | 9 | High DEX; no Shadow Knight |
| Ogre | 17 | 6 | 6 | 6 | 8 | 6 | 16 | Brute; restricted to melee/dark classes |
| Troll | 15 | 9 | 9 | 7 | 8 | 6 | 15 | Regen emphasis; no Paladin/Monk |
| Dark Elf | 9 | 13 | 13 | 14 | 11 | 12 | 8 | Shadow/arcane specialist; no Paladin |
| Wood Elf | 9 | 13 | 14 | 12 | 13 | 10 | 8 | Nature/wilderness; no Necromancer |
| Iksar | 12 | 11 | 11 | 11 | 9 | 7 | 11 | Lizardmen; no Paladin |
| Minotaur | 16 | 8 | 8 | 8 | 10 | 6 | 15 | Warrior/Shaman; melee-focused |
| Vah Shir | 13 | 12 | 13 | 9 | 9 | 10 | 11 | Feline; Bard/Monk affinity |
| Half-Ogre | 15 | 7 | 7 | 8 | 9 | 7 | 14 | Paladin/Warrior hybrid potential |
| Fae | 5 | 12 | 25 | 13 | 12 | 14 | 6 | Tiny; extreme AGI compensates for very low CON |
| Kobold | 10 | 13 | 12 | 11 | 8 | 7 | 10 | Dog-like; Tinkering racial bonus |

**CON → HP scaling:** `(CON - 10) * 5` bonus HP applied at character creation (in addition to class base HP). CON gains on level-up each add `5 HP` to max_hp via `_level_up()`.

---

## Classes

### Base Classes
- **Warrior** — Melee DPS/tank. STR/CON growth.
- **Magician** — Pure arcane caster. INT/WIS growth.
- **Rogue** — Melee DPS. DEX/AGI growth.

### Healer / Hybrid Casters
- **Cleric** — Primary healer; holy spells. WIS/CON growth.
- **Druid** — Nature healer/caster. WIS/INT growth.
- **Shaman** — Spirit healer/buffer. WIS/CON/STR growth.
- **Blood Mage** — Dark healer; HP-cost spells. INT/CON growth.

### Hybrid Melee/Caster
- **Paladin** — Holy warrior. STR/WIS growth. Starts Good.
- **Shadow Knight** — Dark warrior. STR/INT growth. Starts Evil.
- **Ranger** — Nature archer. DEX/AGI/WIS growth.
- **Bard** — Support performer. DEX/CHA growth.
- **Monk** — Unarmed martial. STR/DEX/AGI growth.

### Advanced Casters
- **Necromancer** — Undead summoner. INT/WIS growth. Starts Evil.
- **Enchanter** — Illusion/charm. INT/CHA growth.
- **Witch Hunter** — Anti-magic investigator. INT/WIS/CON growth.

---

## Race / Class Restrictions

Locked combinations (hard-blocked at character creation):

| Race | Locked Classes |
|---|---|
| Dark Elf | Paladin |
| Wood Elf | Necromancer |
| Halfling | Shadow Knight |
| Dwarf | Necromancer |
| Troll | Paladin, Monk |
| Iksar | Paladin |
| Fae | Shadow Knight, Monk |
| Kobold | Paladin |

---

## Alignment System

**Score range:** -2000 to +2000

| Tier | Score Range |
|---|---|
| Exalted | ≥ 1500 |
| Good | 300 to 1499 |
| Neutral | -299 to 299 |
| Bad | -1500 to -300 |
| Evil | ≤ -1501 |

**Starting alignment by class:**

| Class | Starting Score |
|---|---|
| Paladin | +500 |
| Cleric | +400 |
| Monk | +100 |
| Witch Hunter | +100 |
| Blood Mage | -500 |
| Shadow Knight | -1600 |
| Necromancer | -1600 |
| All others | 0 |

**NPC recognition:** NPCs observe and react to alignment tier. Players cannot directly see another player's alignment tier — only NPCs acknowledge it.

**Drift:** Alignment changes via `PlayerStats.modify_alignment(delta)`. When tier threshold is crossed, `alignment_changed` signal fires. Skills and Spells autoloads reconnect available spell/skill lists via `setup_for_class()`.

---

## Alignment-Based Class Transformations (Fallen / Redeemed)

These are not permanent race changes but effective-class swaps that hot-swap the available spell and skill lists.

### Fallen Paladin
- Trigger: Paladin reaches Evil tier (score ≤ -1501)
- Effective class becomes `Paladin_Fallen`
- Loses holy spells; gains shadow/dark variants
- Spells gained: Death's Embrace, Blood Price (HP cost: 15), Shadow Flame, Condemnation
- Effectiveness scaling: Neutral=0.7×, Bad=0.4×, Evil=1.0× (full dark power)

### Redeemed Shadow Knight
- Trigger: Shadow Knight reaches Exalted tier (score ≥ 1500)
- Effective class becomes `Shadow Knight_Redeemed`
- Loses dark spells; gains holy/redemption variants
- Spells gained: Sacrificial Mend (HP cost: 15), Radiant Bolt, Holy Mantle
- Effectiveness scaling: Neutral=0.7×, Good=0.4×, Exalted=1.0× (full holy power)

---

## Evasion (AGI)

```
evasion_chance = clamp((agility - 10) * 0.005, 0.0, 0.50)
```

- Checked in `Combat.receive_player_damage()` before armor reduction
- Max evasion: 50% at AGI 110 (effectively unreachable in normal play)
- Fae base AGI 25 → ~7.5% evasion at character creation
- Evaded attacks are logged in CombatLog with light-blue EVADE message type

---

## Crafting Skills

All skills tracked in the `Crafting` autoload. XP per level: 20. Base cap: 200.

### Gathering Skills

| Skill | Feeds Into |
|---|---|
| Mining | Blacksmithing, Jewelcrafting, Pottery |
| Herbalism | Alchemy, Cooking, Brewing, Scribing |
| Logging | Woodworking, Fletching |
| Skinning | Leatherworking, Tailoring |
| Fishing | Cooking, Alchemy |
| Prospecting | Jewelcrafting |

### Production Skills

| Skill | Requires | Racial Bonus |
|---|---|---|
| Blacksmithing | Mining | — |
| Leatherworking | Skinning | — |
| Tailoring | Herbalism, Skinning | — |
| Woodworking | Logging | — |
| Fletching | Logging, Skinning | — |
| Jewelcrafting | Mining, Prospecting | — |
| Alchemy | Herbalism, Fishing | — |
| Cooking | Fishing, Herbalism | — |
| Brewing | Herbalism, Cooking | — |
| Pottery | Mining | — |
| Scribing | Herbalism, Logging | — |
| Enchanting | — | — |
| Tinkering | Mining, Woodworking | Gnome, Kobold: 1.5× XP, +100 cap |

**Racial cap bonus:** Gnome and Kobold can reach level 300 in Tinkering (base 200 + 100 bonus) and gain 1.5× XP from all Tinkering activity.

---

## Earned Transformations

Transformations are permanent race-like changes unlocked by meeting alignment, class, and level requirements. Tracked in `PlayerStats.transformation`. Once applied, cannot be reversed.

| Transformation | Alignment | Classes | Level |
|---|---|---|---|
| Revenant | Evil | Necromancer, Shadow Knight, Blood Mage | 20 |
| Vampire Lord | Evil | Blood Mage, Shadow Knight | 25 |
| Lich | Evil | Necromancer | 30 |
| Lycanthrope | Neutral | Ranger, Druid, Shaman, Monk | 15 |
| Exalted | Exalted | Paladin, Cleric | 30 |
| Warden of the Wild | Exalted | Druid, Ranger | 25 |

Transformations are checked and applied via `Transformations.apply_transformation(name)`. `get_available_transformations()` returns the list currently eligible. `can_transform(name)` returns a bool for UI gating.

---

## Day / Night Cycle

Architecture planned: `PhysicalSkyMaterial` with a `Sun` (DirectionalLight3D) node driven by `TimeOfDay` autoload. Implementation pending.

---

## Key Autoloads (registered in project.godot)

| Singleton | Path |
|---|---|
| Network | autoloads/network.gd |
| PlayerStats | autoloads/player_stats.gd |
| Combat | autoloads/combat.gd |
| Inventory | autoloads/inventory.gd |
| Equipment | autoloads/equipment.gd |
| Skills | autoloads/skills.gd |
| Spells | autoloads/spells.gd |
| DamageNumbers | autoloads/damage_numbers.gd |
| PlayerDeath | autoloads/player_death.gd |
| Regen | autoloads/regen.gd |
| TimeOfDay | autoloads/time_of_day.gd |
| CombatLog | scripts/combat_log.gd |
| Targeting | autoloads/targeting.gd |
| Loot | autoloads/loot.gd |
| Crafting | autoloads/crafting.gd |
| Transformations | autoloads/transformations.gd |

---

## Data Files (class_name singletons, not autoloads)

| Class | Path | Purpose |
|---|---|---|
| SkillDefinitions | data/skill_definitions.gd | All skill definitions as const array |
| SpellDefinitions | data/spell_definitions.gd | All spell definitions as const array |
