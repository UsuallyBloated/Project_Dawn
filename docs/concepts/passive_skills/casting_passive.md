# Passive Casting Skills

Casting passive skills are a design target — not yet implemented. This document defines the intended system.

Spell casting is divided into two orthogonal systems: **spell disciplines** (what kind of magic the spell *is*) and **damage schools** (what element the spell *deals in*). A Wizard's Fireball is both Evocation discipline and Fire school.

The **damage schools** (Fire, Ice, Lightning, Arcane, Holy, Shadow, Spirit, Nature) already exist as `damage_type` tags on every spell in `data/spell_definitions.gd`. They will feed the enemy resist system.

The **spell disciplines** below are what the *caster* trains. Higher skill means spells in that discipline are harder to resist and carry secondary benefits.

---

## Spell Disciplines

### Evocation
Direct-damage spells that convert raw magical energy into destructive force.

- **What trains it:** Casting any damaging spell that deals direct hit damage (`base_damage > 0`).
- **Benefit:** Reduces the base resist chance of Evocation spells by up to 20% at max skill.
- **Primary classes:** Wizard (cap 250), Sorcerer (250), Magician (225), Druid (175), Shaman (150), Necromancer (175), Blood Mage (200), Cleric (100), Witch Hunter (225), Enchanter (125), Paladin (100), Shadow Knight (100), Bard (125), Ranger (125).
- **Example spells:** Fireball, Frost Bolt, Lightning Strike, Bone Shards, Blood Bolt, Smite, Spirit Bolt, Wrath.

### Alteration
Spells that modify the world: speed, stat buffs, transformations, heal-over-time, slow, haste, movement.

- **What trains it:** Casting any buff, debuff, HoT, slow, or speed spell.
- **Benefit:** Buff and debuff *duration* scales up to +25% at max skill.
- **Primary classes:** Enchanter (250), Shaman (250), Druid (225), Cleric (200), Bard (200), Ranger (175), Paladin (150), Beast Master (150), Blood Mage (125), Necromancer (125), Shadow Knight (100).
- **Example spells:** Spirit of Wolf (Druid), Torpor (Shaman), Haste (Enchanter), Slow (Shaman), Heal-over-time variants.

### Abjuration
Protective and warding spells: damage shields, absorbs, wards, and cancellation of magic.

- **What trains it:** Casting any absorb, ward, or dispel spell.
- **Benefit:** Absorb shields are up to 20% stronger at max skill. Dispels have higher success chance.
- **Primary classes:** Cleric (250), Paladin (225), Enchanter (200), Druid (175), Wizard (150), Shaman (125), Shadow Knight (100).
- **Example spells:** Rune (Enchanter), Holy Shield (Paladin), damage-shield variants (Druid), dispel magic (future).

### Conjuration
Summoning spells: pets, items, portals, and called objects.

- **What trains it:** Casting any summon or conjure spell.
- **Benefit:** Summoned pets start with up to 20% more HP at max skill. Summoned items have improved quality.
- **Primary classes:** Magician (250), Necromancer (225), Enchanter (150), Wizard (125), Shaman (100).
- **Example spells:** Summon Skeleton (Necromancer), Charm (Enchanter/Bard, partial), future Magician elemental summons.

### Divination
Spells of detection, tracking, identification, and arcane sight.

- **What trains it:** Casting identify, detect, or locate spells.
- **Benefit:** Detect range increases. Identified item information becomes more detailed at high skill.
- **Primary classes:** Wizard (225), Cleric (200), Druid (175), Shaman (150), Ranger (150), Enchanter (125).
- **Example spells:** Detect Magic (future), Identify Item (future), See Invisible (future), Wizard Gate (Divination component).

### Channeling
The ability to maintain concentration when struck — reducing the chance that incoming damage interrupts a spell cast.

- **What trains it:** Completing a spell cast while absorbing at least one hit during the cast time.
- **Benefit:** Each point of Channeling skill reduces the interrupt-on-hit probability. At cap, very hard to interrupt.
- **Interrupt formula (design target):** `interrupt_chance = 0.70 - (channeling / cap) * 0.60` → ranges from 70% at skill 0 down to 10% at max skill.
- **All casting classes train this.** Melee-hybrid casters (Paladin, Shadow Knight, Shaman, Bard, Witch Hunter) have higher caps than pure casters, since they cast in melee range.

| Class | Channeling Cap |
|---|---|
| Wizard, Magician, Sorcerer, Enchanter, Necromancer | 150 |
| Cleric, Druid, Blood Mage | 175 |
| Paladin, Shadow Knight | 225 |
| Shaman, Bard, Witch Hunter, Ranger | 200 |
| Beast Master | 175 |

---

## Discipline → Spell Assignment

Each spell in `spell_definitions.gd` will gain a `discipline` field:

| Discipline | Spells |
|---|---|
| Evocation | Fireball, Frost Bolt, Lightning Strike, Arcane Missile, Smite, Divine Wrath, Spirit Bolt, Ancestral Strike, Wrath, Call Lightning, Blood Bolt, Crimson Bolt, Bone Shards, Siphon, Dark Shroud, Color Spray, Cascade of Stars, Dissonance, Hunter's Mark, Silver Bolt, … |
| Alteration | Regrowth, Entangle, Healing Wave, Life Drain (DoT component), Dark Decay, Mesmerize, Battle Hymn, Nature's Cure, … |
| Abjuration | Rune, Holy Shield, Dark Ward, … |
| Conjuration | Summon Skeleton, Charm, Siren's Song, … |
| Divination | (future spells) |

---

## Relation to Damage Schools

These two systems are independent and stack:

- A Wizard's **Ice Spear** is Evocation discipline (trains Evocation, benefits from Evocation skill) and Ice school (resisted by enemy Ice resistance).
- A Druid's **Regrowth** is Alteration discipline (trains Alteration, duration scales with skill) and Nature school (resisted by enemy Nature resistance — relevant if dispelled or for damage-HoT combos).
- An Enchanter's **Rune** is Abjuration discipline (stronger absorb with skill) and Arcane school (no damage → resist irrelevant).

---

## Implementation Notes

- Add `discipline: String = ""` field to `SpellDefinitions` entries.
- Create `data/casting_skill_definitions.gd` for per-class caps.
- Create `autoloads/casting_skills.gd` mirroring `weapon_skills.gd`.
- Hook `try_advance(discipline)` into `autoloads/spells.gd` after a successful cast completes.
- Hook Channeling advance into cast-completion logic when a hit was absorbed during the cast.
