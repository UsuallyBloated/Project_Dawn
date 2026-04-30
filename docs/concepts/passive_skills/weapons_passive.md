# Passive Weapon Skills

Weapon skills train passively through use. Every swing of an auto-attack runs `WeaponSkills.try_advance()` — skill advances with decreasing probability as you approach your class cap.

---

## How Skills Work

- **Miss chance**: scales from 35% (untrained) down to 5% (max skill). Using a weapon type your class cannot train at all (cap = 0) carries an 80% miss penalty.
- **Damage multiplier**: scales from 1.0× (untrained) up to 1.15× (max skill). Unusable weapon type = 0.5×.
- **Cap formula**: `class_cap_at_60 * level / 60` — cap grows linearly as you level.

---

## Skill List

| Skill | What It Covers | Trains When |
|---|---|---|
| **1H Slashing** | One-handed swords, axes, hand axes | Auto-attacking with a 1H slashing weapon |
| **2H Slashing** | Two-handed swords and axes | Auto-attacking with a 2H slashing weapon |
| **1H Blunt** | Maces, hammers, flails (one-handed) | Auto-attacking with a 1H blunt weapon |
| **2H Blunt** | Two-handed maces and hammers | Auto-attacking with a 2H blunt weapon |
| **Piercing** | Daggers, spears, rapiers | Auto-attacking with a piercing weapon |
| **Hand to Hand** | Unarmed; fist weapons | Auto-attacking without a weapon equipped |
| **Defense** | Passive mitigation through stance and movement | Taking any melee hit |
| **Dodge** | Pure avoidance; chance to fully dodge a swing | Successfully evading an attack (including evade boost) |

---

## Class Caps (at level 60)

| Class | 1H Slash | 2H Slash | 1H Blunt | 2H Blunt | Piercing | H2H | Defense | Dodge |
|---|---|---|---|---|---|---|---|---|
| Warrior | 250 | 250 | 250 | 250 | 250 | 100 | 250 | 200 |
| Paladin | 225 | 225 | 225 | 225 | 150 | 75 | 225 | 175 |
| Shadow Knight | 225 | 225 | 225 | 225 | 150 | 75 | 225 | 175 |
| Rogue | 225 | — | 75 | — | 250 | 200 | 200 | 250 |
| Monk | 50 | — | 200 | 100 | — | 250 | 250 | 250 |
| Ranger | 225 | 225 | 175 | 175 | 225 | 100 | 200 | 225 |
| Bard | 200 | 150 | 175 | 150 | 200 | 100 | 175 | 200 |
| Witch Hunter | 200 | 150 | 100 | — | 225 | 125 | 200 | 200 |
| Cleric | — | — | 200 | 200 | — | 50 | 200 | 150 |
| Shaman | 150 | — | 200 | 200 | 100 | 100 | 200 | 150 |
| Druid | — | — | 175 | 175 | — | 50 | 175 | 150 |
| Beast Master | — | — | — | — | — | — | — | — |
| Magician | — | — | 75 | — | — | 25 | 100 | 75 |
| Wizard | — | — | 75 | — | — | 25 | 100 | 75 |
| Sorcerer | — | — | 75 | — | — | 25 | 100 | 75 |
| Necromancer | — | — | 75 | — | — | 25 | 100 | 75 |
| Enchanter | — | — | 75 | — | — | 25 | 100 | 75 |
| Blood Mage | — | — | 100 | — | 50 | 50 | 100 | 75 |

`—` = cap is 0 (80% miss penalty; 0.5× damage).

---

## Future: Parry and Riposte

Two additional combat-reaction skills are planned:

- **Parry** — Passive chance to deflect an incoming melee attack. Requires a weapon to be equipped. Trains when you block an incoming swing. Higher caps for sword-and-board classes.
- **Riposte** — Passive chance to counter-attack immediately after a successful parry or dodge. High DEX contributes. Only available to certain classes (Warrior, Rogue, Ranger, Bard).

These are design targets not yet implemented.
