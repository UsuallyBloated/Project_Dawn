# Project Dawn — Systems Design Reference

---

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
| Kel`varath | 12 | 11 | 11 | 11 | 9 | 7 | 11 | Lizardmen; no Paladin |
| Minotaur | 16 | 8 | 8 | 8 | 10 | 6 | 15 | Warrior/Shaman; melee-focused |
| Felhari | 13 | 12 | 13 | 9 | 9 | 10 | 11 | Feline; Bard/Beast Master affinity |
| Half-Ogre | 15 | 7 | 7 | 8 | 9 | 7 | 14 | Paladin/Warrior hybrid potential |
| Fae | 5 | 12 | 25 | 13 | 12 | 14 | 6 | Tiny; extreme AGI; very low CON |
| Kobold | 10 | 13 | 12 | 11 | 8 | 7 | 10 | Dog-like; Tinkering racial bonus |
| Revenant | — | — | — | — | — | — | — | Earned transformation; not available at character creation |

**CON → HP scaling:** `(CON - 10) * 5` bonus HP applied at character creation (in addition to class base HP). CON gains on level-up each add `5 HP` to max_hp via `_level_up()`.

---

## Classes

Eighteen classes are playable. See `data/character_data.gd` for all stats, bonuses, and level gains.

### Melee / Tank
- **Warrior** — Pure melee. Heaviest armor, highest HP growth, no magic. STR/CON growth.
- **Monk** — Unarmed martial arts. No armor, no weapons — speed, technique, and inner discipline. STR/DEX/AGI growth.
- **Rogue** — Precision strikes, poisons, ambush. Backstab from stealth for massive burst. DEX/AGI growth.

### Zealot(evil & good)
- **Paladin** — Divine faith translated into steel. Heals, protects, and destroys undead. STR/WIS/CON growth. *Starts Good.*
- **Shadow Knight** — Dark faith and death magic sustaining a warrior. Lifetap, fear, and undead summons. STR/INT/CON growth. *Starts Evil.*

### Healers / Spirit Casters
- **Cleric** — Primary healer. The deepest heal pool and the only class with resurrection. WIS/CON growth.
- **Druid** — Nature healer and caster. HoTs, DoTs, snares, and some of the best utility in the game. WIS/INT growth.
- **Shaman** — Spirit healer and buffer. The most powerful slow in the game. Ancestor-spirit tradition; not available to all races. WIS/CON/STR growth.

### Nature / Hybrid Melee
- **Ranger** — Swift dual-wielder and archer. Nature spells at reduced capacity. DEX/AGI/WIS growth.
- **Beast Master** — Permanent spirit-bonded animal warder fights alongside the player at all times. Melee + spirit spells. STR/CON/AGI/WIS growth. *Warder retreats 15s on death; returns wounded.*
- **Bard** — Music magic. Sustaining songs that pulse effects. Fast switches. DEX/CHA growth.

### Arcane DPS
- **Magician** — Broad generalist arcane caster. No ceiling, no floor — versatile and reliable. INT/WIS growth.
- **Wizard** — Memorized spellbook. Highest single-hit damage in the game; catastrophically slow once dry. INT growth.
- **Sorcerer** — Innate bloodline magic, always available. No preparation — fewer spells than Wizard but never runs dry. INT/CHA growth.

### Crowd Control / Support
- **Enchanter** — Illusion and mind magic. The best CC in the game. Mana regeneration buffs for the group. INT/CHA growth.

### Dark / Death Casters
- **Necromancer** — Undead summoner. DoTs, lifetap, skeleton pet that persists until killed. INT/WIS growth. *Starts Evil.*
- **Blood Mage** — Life force as fuel. Drains enemies and converts HP into spell power. INT/CON growth.

### Anti-Magic
- **Witch Hunter** — Hunts and unravels corrupted magic. Strong against caster-type enemies. INT/WIS/CON growth.

*Planned future classes: Assassin (stealth / assassination), Warlock (pact magic).*

---

## Race / Class Restrictions

Locked combinations are enforced at character creation (`LOCKED_COMBOS` in `data/character_data.gd`). The full design target matrix is in `docs/concepts/race_class_restrictions.md`.

| Race | Locked Classes |
|---|---|
| Dark Elf | Paladin, Beast Master |
| Wood Elf | Necromancer |
| Gnome | Beast Master |
| Halfling | Shadow Knight, Beast Master |
| Dwarf | Necromancer, Beast Master |
| Troll | Paladin, Monk |
| Kel`varath | Paladin |
| Fae | Shadow Knight, Monk, Beast Master |
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
| All others | 0 |
| Blood Mage | -500 |
| Shadow Knight | -1600 |
| Necromancer | -1600 |

**NPC recognition:** NPCs observe and react to alignment tier. Players cannot directly see another player's alignment score — only NPCs acknowledge it.

**Drift:** `PlayerStats.modify_alignment(delta)`. When a tier threshold is crossed, `alignment_changed` fires; `Skills` and `Spells` autoloads rebuild available lists via `setup_for_class()`. Signal is fully wired — `Skills`, `Spells`, and HUD all subscribe; alignment tier and color display on the HUD.

**Spell effectiveness:** Paladin spells are penalized at Neutral (0.7×) and Bad (0.4×) alignment. Shadow Knight spells are penalized at Neutral (0.7×) and Good (0.4×). Full effectiveness only at the intended extreme. Implemented in `Spells._get_alignment_effectiveness()`.

---

## Alignment-Based Class Transformations (Fallen / Redeemed)

Hot-swaps the effective class, rebuilding the full spell and skill list without changing the stored class. Drift logic is live. **Known gap:** `Paladin_Fallen` and `Shadow Knight_Redeemed` are not defined in `spell_definitions.gd` or `skill_definitions.gd` — transformed characters currently have no spells or skills until those entries are added.

### Fallen Paladin
- **Trigger:** Paladin reaches Evil tier (≤ -1501)
- **Effective class:** `Paladin_Fallen`
- Loses all holy spells and Divine Blow / Holy Shield
- **Gains:** Shadow Flame, Death's Embrace, Blood Price (HP cost 15), Condemnation; Profane Strike, Dark Ward

### Redeemed Shadow Knight
- **Trigger:** Shadow Knight reaches Exalted tier (≥ 1500)
- **Effective class:** `Shadow Knight_Redeemed`
- Loses all dark spells and Dark Strike / Harm Touch
- **Gains:** Radiant Bolt, Holy Mantle, Sacrificial Mend (HP cost 15); Redeemed Strike, Penitent's Touch

---

## Combat

Auto-attack fires on a timer (`combat.gd`). Skills and spells layer on top.

- **Auto-attack damage:** `(STR / 5.0) + randf_range(1, 6)` — scales with strength.
- **Haste dependency:** Enchanter Haste requires the auto-attack interval to be a data-driven per-weapon stat, not the current hardcoded 2.0s literal in combat.gd. Implement the interval as a modifiable stat before Haste is built.
- **Damage reduction (armor):** `received_damage * (1.0 - armor_reduction)`.
- **Critical hits:** **Implemented.** Auto-attack and skill crits roll against DEX (0–30% chance). Spell crits roll against INT (0–20% chance). All crits deal 1.5–2.0× damage. Logged in bright gold `MsgType.CRIT` color.
- **Evasion (AGI):** `clamp((agility - 10) * 0.005, 0.0, 0.50)`. Checked before armor. Max 50% at AGI 110. Logged as EVADE in CombatLog.
- **Tab targeting:** Cycle through nearby enemies. Combat.set_target() updates the target frame.
- **Player attacked signal:** `Combat.player_attacked` fires when the player takes damage; used by PetManager to direct the warder to counter-attack.

---

## Spell Damage Schools

Every spell belongs to one of eight damage schools. Currently informational — the resist system is a design target.

| School | Primary Classes |
|---|---|
| Fire | Wizard, Magician, Sorcerer, Witch Hunter |
| Ice | Wizard, Magician |
| Lightning | Wizard, Sorcerer |
| Arcane | Magician, Sorcerer, Enchanter, Bard |
| Holy | Paladin, Cleric |
| Shadow | Shadow Knight, Necromancer, Blood Mage |
| Spirit | Shaman, Beast Master |
| Nature | Druid, Ranger |

**Design target — Resist system:** Enemies will have resist values per school (0–100). A spell hitting a target with 40 fire resistance has a 40% chance to be partially resisted, reducing damage by 25–75%. Full resists are possible but rare. This makes school diversity meaningful — a Wizard with Fire and Ice spells can switch to exploit weakness.

---

## Spell Effect Types

Implemented in `data/spell_definitions.gd` and applied in `autoloads/spells.gd`:

| Field | Effect |
|---|---|
| `base_damage` | Direct damage to target; scaled by INT and alignment effectiveness |
| `heal_amount` | Self-heal (player) |
| `hp_cost` | Player pays HP to cast (Blood Mage / Fallen Paladin) |
| `dot_dps` + `dot_duration` | Damage-over-time applied via BuffManager |
| `hot_hps` + `hot_duration` | Heal-over-time applied via BuffManager |
| `absorb_amount` | Damage shield; absorbed before HP is reduced |
| `cc_duration` | Mesmerize — enemy frozen until timer expires or damaged |
| `duration` | Charm duration (PET_CHARM type) |
| `pet_type` | Which pet to summon (PET_SUMMON type) |
| `root_duration` | Enemy cannot move for duration; can still attack and cast (Root effect type) |
| `slow_amount` + `slow_duration` | Enemy movement speed reduced by slow_amount % for duration (Snare/movement slow) |
| `interrupt` + `silence_duration` | Cancels the target's active cast; if silence_duration > 0, prevents casting for that window |
| `stealth_duration` | Caster enters reduced-detection state; broken by running or taking damage (Camouflage) |
| `dispel_count` | Removes dispel_count active buffs from the target (Expose, Antimagic Ward) |

**Target types:** `ENEMY`, `SELF`, `NONE`, `PET_SUMMON`, `PET_CHARM`, `PET_HEAL`

---

## Buff / Debuff System

Managed by `BuffManager` autoload. All effects tick in `_process`.

| Buff Type | Applied Via | Notes |
|---|---|---|
| **DoT** | `BuffManager.add_dot(target, dps, duration, name)` | Deals damage to an enemy node each tick |
| **HoT** | `BuffManager.add_hot(hps, duration, name)` | Heals player each tick |
| **Absorb Shield** | `BuffManager.add_absorb(amount, name)` | Intercepts incoming damage before HP; multiple shields stack |
| **Evade Boost** | `BuffManager.add_evade_boost(duration)` | Evasion = 1.0 for the duration (guaranteed dodge) |

**Buff bar UI:** Implemented. `scripts/hud_buff_bar.gd` — icon strip with countdown timers for HoT, absorb shield, evade boost, food, and drink buffs. Subscribes to `BuffManager.buffs_changed`.

---

## Pet System

Managed by `PetManager` autoload.

### Beast Master Warder
- Summoned automatically when Beast Master is loaded. Never permanently lost.
- Stats: `max_hp = 60 + level * 12`, `damage = 6 + level * 3`.
- On death: retreats for 15 seconds, returns at 30% HP with `warder_returned` signal.
- **Warder's Fury skill:** player deals 2.0× damage and commands warder to attack the same target simultaneously.
- Warder modes: `FOLLOW`, `GUARD`, `PASSIVE`. Responds to `player_attacked` signal automatically in non-passive mode.

### Necromancer Skeleton
- Summoned via `Summon Skeleton` spell (3.0s cast, 60 mana).
- Persists until killed or dismissed. One active pet at a time.
- Stats: `max_hp = 50 + level * 10`, `damage = 5 + level * 3`.

### Magician Elemental (Design Target)
Magician summons one of four elemental types — Earth (tank), Fire (DPS), Water (support/heal), Air (utility/speed). Unlike Warder and Skeleton, elemental stats must be defined per type rather than a single formula. Full design in `docs/concepts/classes/magician.md`. The PetManager/WarderAI split is complete — implementation can proceed when elemental definitions are ready.

### Enchanter / Bard Charm
- `PetManager.charm_current_target(duration)` converts the current combat target into a temporary ally.
- Charm breaks on timer expiry (`charm_broke` signal). The formerly charmed creature becomes hostile again.
- Siren's Song (Bard): 30s. Charm (Enchanter): 60s.

---

## Skill Effect Types

Implemented in `data/skill_definitions.gd` and applied in `autoloads/skills.gd`:

| Effect Type | Behavior |
|---|---|
| `NONE` | Pure damage hit (damage_multiplier × base attack) |
| `EVADE_BOOST` | Calls `BuffManager.add_evade_boost(effect_duration)` — 100% evasion for duration |
| `ABSORB_SHIELD` | Calls `BuffManager.add_absorb(absorb_amount, name)` |
| `WARDER_FURY` | Calls `PetManager.command_fury()` — directs warder to attack current target |

---

## Regen System

`Regen` autoload ticks HP/MP/Stamina recovery each second.

- Regen rates increase when not in combat (out-of-combat regen bonus).
- **Design target — Meditation:** Sitting triggers a "meditate" state with dramatically accelerated MP regen. Troll racial passive provides passive HP regen regardless of combat state. Food/drink buffs further accelerate out-of-combat regen.

---

## Day / Night Cycle

`TimeOfDay` autoload is live. Architecture: `PhysicalSkyMaterial` with a `Sun` (DirectionalLight3D) node driven by time-of-day float. Moon position and intensity are tracked separately.

**Design targets:**
- Undead mobs spawn only at night; some NPCs close shops after dark.
- Day/night affects certain spell effectiveness (Shadow spells stronger at night).

**Status:** `TimeOfDay` emits `hour_changed` every in-game hour. Signal currently has 0 listeners — all time-based mob and NPC behavior is blocked until this signal is wired to spawn managers and NPC schedulers.

---

## Earned Transformations

Permanent race-like changes unlocked by meeting alignment, class, and level requirements. Tracked in `PlayerStats.transformation`. Once applied, cannot be reversed. *Implementation: design target, not yet coded.*

| Transformation | Alignment | Classes | Level | Effect |
|---|---|---|---|---|
| Revenant | Evil | Necromancer, Shadow Knight, Blood Mage | 20 | Undead body type; immune to fear; -CHA |
| Vampire Lord | Evil | Blood Mage, Shadow Knight | 25 | Lifedrain on auto-attack; sun damage |
| Lich | Evil | Necromancer | 30 | Vastly increased mana pool; no HP regen |
| Lycanthrope | Neutral | Ranger, Druid, Shaman, Monk | 15 | Beast form at night; enhanced STR/AGI |
| Exalted | Exalted | Paladin, Cleric | 30 | Glow aura; undead auto-damage proximity |
| Warden of the Wild | Exalted | Druid, Ranger | 25 | Commune with animals; nature immunity |

---

## Crafting Skills

Design target. All skills tracked in `Crafting` autoload (stub). XP per level: 20. Base cap: 200. Full design in `docs/concepts/tradeskills/`.

### Gathering Skills
| Skill | Feeds Into |
|---|---|
| Mining | Blacksmithing, Jewelcrafting, Pottery |
| Herbalism | Alchemy, Cooking, Brewing, Scribing |
| Logging | Woodworking, Fletching |
| Skinning | Leatherworking, Tailoring |
| Fishing | Cooking, Alchemy |
| Grave Robbing | Necromantic Scribing, Black Alchemy, Bone Carving — Evil/Neutral only |
| Deepwater Fishing | Cooking, Alchemy — Troll exclusive |

### Production Skills
| Skill | Requires | Racial Bonus |
|---|---|---|
| Blacksmithing | Mining | Dwarf: +XP, higher cap (250) |
| Leatherworking | Skinning | — |
| Tailoring | Herbalism, Skinning | — |
| Woodworking | Logging | — |
| Fletching | Logging, Skinning | Wood Elf: bonus |
| Jewelcrafting | Mining | — |
| Alchemy | Herbalism, Fishing | Alignment-split: White (good/neutral) and Black (evil/neutral) |
| Cooking | Fishing, Herbalism | Halfling: bonus; exclusive recipes |
| Brewing | Herbalism, Cooking | Dwarf: +XP, cap 250; Halfling: minor bonus |
| Pottery | Mining | — |
| Scribing | Herbalism, Logging | — |
| Enchanting | — | Elf: +XP |
| Tinkering | Mining, Woodworking | Gnome, Kobold: 1.5× XP, +100 cap (max 300) |
| Poison Making | Herbalism, Alchemy | Dark Elf: bonus; restricted to Evil/Neutral alignment and eligible classes |

### Tradeskill Prestige Paths

Two tradeskills have prestige paths — advanced tiers unlocked within the same skill score:

- **Clockwork Engineering** (Tinkering 150+, Gnome/Kobold only): Produces mechanical companions, Clockwork Golems, and siege mechanisms. See `docs/concepts/tradeskills/tinkering.md`.
- **Runeforging** (Blacksmithing 150+, Dwarf only): Fuses rune into metal during the forge process. Stronger and more permanent than Runecarving. See `docs/concepts/tradeskills/runeforging.md`.

---

## Consumables System

*Design target — tied to the Regen System and Meditation mechanic.*

Consumables are tradeskill outputs destroyed on use. They drive the bulk of the player economy at maturity because demand is permanent. Three categories:

### Food (HP Regen)
Produced by Baking and Cooking. Occupies the Food buff slot. Only one active at a time; higher-tier replaces lower.

| Tier | Approx HP Regen | Source | Duration |
|---|---|---|---|
| 1 (Simple Bread) | +3/tick | Baking skill 0–30 | 30 min |
| 2 (Roasted Meat) | +5/tick | Cooking skill 40 | 45 min |
| 3 (Hearty Stew) | +7/tick | Cooking skill 80 | 60 min |
| 4 (Halfling Feast) | +15/tick | Halfling only; Cooking 160 | 90 min |

### Drink (MP Regen)
Produced by Brewing. Occupies the Drink buff slot. One active at a time; replacement rule same as Food.

| Tier | Approx MP Regen | Source | Duration |
|---|---|---|---|
| 1 (Thin Ale) | +2/tick | Brewing skill 0 | 20 min |
| 2 (Halfling Mead) | +4/tick | Brewing skill 40 | 40 min |
| 3 (Elven Wine) | +5/tick | Brewing skill 80 | 50 min |
| 4 (Dwarven Grand Stout) | +8/tick (also HP) | Dwarf Runeforging path; Brewing 180 | 90 min |

### Potions (Instant Effects)
Produced by Alchemy. Stack with Food and Drink — potions don't occupy the Food/Drink slot. Healing potions, mana tonics, and stat elixirs. See `docs/concepts/tradeskills/alchemy.md`.

### The Meditation Loop
Food + Drink + Sitting (meditation) = maximum out-of-combat regen:
- **Sitting:** Triggers meditate state. MP regenerates at 3× base rate.
- **Food buff active:** HP regen bonus from tier.
- **Drink buff active:** MP regen bonus from tier (stacks with meditate multiplier).
- **All three simultaneously:** Maximum regen. The pull-kill-sit-med-eat-drink-pull loop.

Implementation in `Regen` autoload: meditation state detection on sit, food/drink buff slots tracked as active buff entries in `BuffManager`.

### Ritual Consumables
A third consumable category: components burned during spellcasting rituals. Candlemaking and Incense Crafting produce these. Required for some high-tier Cleric, Shaman, and Necromancer abilities (Resurrection requires Holy Incense; Lich Form toggle requires Dark Incense). This creates persistent demand for the artisan chain: Beekeeping → Candlemaking → Incense Crafting.

---

## Bookbinding and Player-Authored Lore

*Design target — unique feature; see `docs/concepts/tradeskills/service.md`.*

Bookbinding (Scribing 50 + Cartography 50 prerequisite) produces bound books with player-authored content. When a player creates a book of Journal tier or higher, they get a text input window. Whatever they write becomes the book's readable content. Other players who find or purchase the book can read it.

This is the lore delivery mechanism for player-driven world history. Key features:
- **Skill Manual:** A book written by a Grandmaster crafter grants readers a passive skill XP bonus (+5–10% for 24 in-game hours) in that skill. Creates a literal market for expertise.
- **Atlas:** Bundled Cartography maps in book form. Zone guides with resource node locations.
- **Bard Song Scroll:** Scribing-adjacent (Scribing 130+) — a one-use scroll any class can play that triggers a short version of one Bard song. High demand from groups without a Bard.
- **Grand Grimoire (Grandmaster):** Magically preserved books placed in player housing as permanent lore objects.

---

## Design Targets — Spells & Class Depth

### Per-Class Spell Expansion
Each class will eventually have 15–25 spells spanning their leveling range. The current 3–5 spells per class are placeholders for early levels only. Spell ranks (Rank I → II → III) are the primary growth mechanism — the same spell name gets more powerful versions found or purchased at level thresholds.

### Cross-Class Spell Overlap
Several utility spells will exist in multiple class spell lists at different power levels — intentional, like EQ. This makes every class feel like it belongs to a shared world rather than a vacuum.

| Spell Concept | Who Gets It |
|---|---|
| Minor heal | Cleric (best), Druid, Shaman, Paladin, Bard, Beast Master, Ranger |
| Snare (slow movement) | Druid (best), Shaman, Ranger, Witch Hunter |
| Root (immobile, can still attack) | Druid, Wizard, Ranger |
| Mesmerize / Stun | Enchanter (best), Bard, Wizard, Paladin |
| Mana Regen buff | Enchanter (best), Bard, Cleric |
| Movement speed buff | Druid (Spirit of Wolf), Shaman, Bard (Selo's) |
| Damage shield (thorns) | Druid (best), Enchanter, Paladin |
| Stat buff (STR/AGI/etc.) | Shaman (best), Enchanter, Cleric, Druid |

### Signature Spells (High Value Targets)
These are spells that define a class's group role — they must exist before the class feels complete:

| Class | Signature Spell | Why It Matters |
|---|---|---|
| Cleric | **Complete Heal** — 8s cast, heals target to full HP | The backbone of every serious group pull |
| Cleric | **Resurrection** — restores a dead player at the corpse | The only class that brings people back |
| Shaman | **Torpor** — massive slow + powerful HoT combined | Irreplaceable in group play; defines the class |
| Enchanter | **Clarity** — regenerates target's mana rapidly | Makes long sessions possible for casters |
| Enchanter | **Haste** — reduces melee auto-attack delay | Doubles effective DPS of a warrior; defines group synergy |
| Druid | **Spirit of Wolf** — movement speed buff (AoE) | Zone traversal; everyone wants this |
| Bard | **Selos' Melody** — movement speed song | Bard's version of SoW; affects whole group |
| Necromancer | **Lich Form** — trade HP regen for extreme mana regen | Toggle that changes how you play entirely |
| Wizard | **Gate** — instant teleport to bind point | Emergency escape; Wizard utility pillar |
| Blood Mage | **Exsanguinate** — convert enemy HP directly into your mana | The defining Blood Mage fantasy |

### Bard Song Mechanic (Design Target)
Bard spells are **songs** — they don't fire once and expire. A song is activated and then **pulses** an effect every 3 seconds while the Bard keeps it playing. Only one song plays at a time.

The **Twist** is the advanced technique: manually cycle through 3–4 songs quickly enough that all of their pulse timers stay active simultaneously. A skilled Bard who twists has the most complex and rewarding rotation in the game — speed haste, mana regen, and AoE mezz all running at once. An unskilled Bard just plays one song.

### Meditation / Sitting (Design Target)
Out-of-combat sitting triggers a meditate state. Mana regenerates 3× faster while meditating. Moving or being attacked cancels it. Food and drink items further accelerate regen while sitting. This is the EQ-style "pull, engage, kill, sit and med, pull again" loop that makes resource management tactile.

---

## Evasion

```
evasion_chance = clamp((agility - 10) * 0.005, 0.0, 0.50)
```

Checked in `Combat.receive_player_damage()` before armor reduction. Max evasion: 50% at AGI 110. Fae base AGI 25 → ~7.5% evasion at character creation. Evaded attacks are logged with EVADE message type.

---

## Key Autoloads (registered in project.godot)

| Singleton | Path | Status |
|---|---|---|
| Network | autoloads/network.gd | Live |
| PlayerStats | autoloads/player_stats.gd | Live |
| Alignment | autoloads/alignment.gd | Live — extracted from PlayerStats |
| Combat | autoloads/combat.gd | Live |
| Inventory | autoloads/inventory.gd | Live |
| Equipment | autoloads/equipment.gd | Live |
| Skills | autoloads/skills.gd | Live |
| Spells | autoloads/spells.gd | Live |
| WeaponSkills | autoloads/weapon_skills.gd | Live — passive skill gains on use |
| ArmorSkills | autoloads/armor_skills.gd | Live — passive armor skill gains |
| CastingSkills | autoloads/casting_skills.gd | Live — channeling/discipline mastery |
| BuffManager | autoloads/buff_manager.gd | Live |
| PetManager | autoloads/pet_manager.gd | Live — generic pet lifecycle only |
| WarderAI | autoloads/warder_ai.gd | Live — extracted from PetManager; owns warder retreat/fury/summon |
| DamageNumbers | autoloads/damage_numbers.gd | Live |
| PlayerDeath | autoloads/player_death.gd | Live |
| Regen | autoloads/regen.gd | Live |
| TimeOfDay | autoloads/time_of_day.gd | Live |
| VisionSystem | autoloads/vision_system.gd | Live — race vision types; night brightness/tint |
| SenseHeading | autoloads/sense_heading.gd | Live — /sense command, compass direction |
| CombatLog | autoloads/combat_log.gd | Live |
| Targeting | autoloads/targeting.gd | Live |
| Loot | autoloads/loot.gd | Live |
| ZoneLoader | autoloads/zone_loader.gd | Live — scene switching with transitions |
| Crafting | autoloads/crafting.gd | Stub |
| Transformations | autoloads/transformations.gd | Written — not wired (0 callers trigger it) |
| GroupManager | autoloads/group_manager.gd | Live |
| VendorManager | autoloads/vendor_manager.gd | Stub |
| SocialHotkeys | autoloads/social_hotkeys.gd | Live |
| Settings | autoloads/settings.gd | Live |
| CharacterSetup | autoloads/character_setup.gd | Live — race/class application at game start |

---

## Data Files (class_name singletons, not autoloads)

| Class | Path | Purpose |
|---|---|---|
| CharacterData | data/character_data.gd | Races, classes, bonuses, level gains, restrictions, alignment defaults |
| SkillDefinitions | data/skill_definitions.gd | All skill definitions as const array |
| SpellDefinitions | data/spell_definitions.gd | All spell definitions as const array |

---

## Faction System
*Design target.*

Faction standing is a per-character numerical score with each named faction. Independent of alignment tier — a character can have high Greyveil Standing while at Evil alignment tier. Standing determines:
- Whether guards are hostile, neutral, or friendly
- Which vendors will deal with the character (and at what prices)
- Whether quest-givers offer content
- Which districts or areas are accessible

**Hostility thresholds (design target):**
| Standing | NPC Behavior |
|---|---|
| Allied (≥ 750) | Discounts; access to private services; faction quests |
| Friendly (300–749) | Normal commerce; quest access |
| Neutral (0–299) | Assessed individually; no automatic access |
| Wary (-1 to -299) | Merchants reluctant; guards watch |
| Hostile (-300 to -749) | Guards will not assist; vendors refuse |
| KOS (-750 or less) | Kill on sight; no commerce possible |

**Faction vs. Alignment:** Alignment tier governs the broad moral world reaction. Faction standing governs specific organizational relationships. A Neutral-aligned character can have KOS standing with one guild and Allied standing with its rival. The two systems apply simultaneously — a character must satisfy both to operate freely in a location.

**Faction changes:** Quests, kills, and donations shift faction standing per the quest/encounter design. Killing faction members always reduces standing with that faction regardless of alignment.

---

## Death and Respawn
*Design target — `PlayerDeath` autoload is live; respawn behavior is placeholder.*

**On death:**
1. Player character falls (death animation).
2. Gear and inventory remain on the **corpse** at the death location.
3. Player respawns at their **bind point** (default: zone entry; updated with `/bind` at valid camps and inns).
4. Player respawns with no gear — naked.
5. Corpse persists for a configurable duration (design target: 30 minutes real time).

**Corpse run:** Player must return to corpse location to recover gear. Corpse is visible and lootable only by the owning player. Risk: re-dying on the corpse run, creating a chain.

**Bind point system:** `/bind` command at designated bind locations (inn rooms, guild halls, camp NPCs). Only one bind point active at a time. Gate (Wizard) teleports to bind point. On death without a bind, respawn at zone entry.

**Special cases:**
- Cleric Resurrection: restores a dead player at their corpse with partial XP return; corpse is looted automatically on successful res.
- Ancestor Vessel (Minotaur Shaman transformation): held at 1 HP for 5 seconds on death; if healed in that window, death is prevented.

---

## NPC AI Types
*Design target — all enemies currently use basic attack-closest behavior.*

The enemy roster needs behavioral variety. Target palette:

| AI Type | Behavior | Example |
|---|---|---|
| **Melee Aggressor** | Charges and attacks; no retreat | Most standard enemies |
| **Caster Kiter** | Maintains range; casts from distance; backs away when engaged in melee | Goblin shamans, caster mobs |
| **Healer** | Hangs back; heals other mobs when they lose HP; flees when targeted | Camp healers |
| **Pack Leader** | Buffs nearby allies; calls for help when HP drops below 50% | Named mob leaders |
| **Ambusher** | Stealthy approach; breaks stealth for burst opener | Rogues, certain predators |
| **Undead Shambler** | Low speed; high HP; ignores fear; does not flee | Undead |
| **Summoner** | Summons adds during combat; priority target | Necromancer enemies |
| **Patrol** | Follows a set path; aggros on proximity; returns to path after losing aggro | Guard NPCs, patrol enemies |

NPC aggro radius and whether an NPC assists other nearby NPCs of its faction are per-mob properties. Social aggro (calling for help) is a core mechanic for making dungeon pulls feel dangerous.

---

## Class Progression
*Design target — level currently only increases stats via flat bonuses.*

Each class gains new spells and abilities at specific level thresholds. The current 3–5 spells per class are level 1–10 placeholders only. Full design target:

- **Levels 1–10:** 3–5 core spells established; class identity clear.
- **Levels 11–20:** Spell Rank II versions begin appearing; 1–2 new spell slots.
- **Levels 21–30:** Signature spells become available (Complete Heal, Gate, Lich Form, etc.); skill caps increase.
- **Levels 31–40:** Spell Rank III; cross-class utility spells available; transformation prerequisites reachable.
- **Levels 41–50:** Endgame spells; highest-tier signature abilities; transformation content.

**Spell ranks:** The same spell name gains a more powerful version at level thresholds. Rank I → Rank II → Rank III. Higher ranks are purchased from trainers or found as drops — they do not unlock automatically on level-up.

**Trainer system (design target):** Most spells above Rank I require purchasing from a class trainer NPC. Trainers are located in zone hubs; trainer access may require faction standing with that zone's faction.
