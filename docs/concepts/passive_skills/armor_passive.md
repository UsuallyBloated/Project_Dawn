# Passive Armor Skills

Armor skills train passively through taking damage while wearing that armor type. Each time the player is struck, `ArmorSkills.try_advance_worn()` fires once per unique armor type currently equipped.

---

## How Skills Work

- **Armor effectiveness multiplier**: scales from 1.0× (untrained) up to 1.25× (max skill).
- **Wrong armor type** (cap = 0 for your class): 0.5× — armor is dramatically less effective on a body not conditioned for it.
- Skills do **not** affect the AGI contribution to AC, only the `bonus_armor` from item stats.
- **Cap formula**: `class_cap_at_60 * level / 60` — same linear growth as weapon skills.

Wearing armor your class was never meant to wear is not blocked, but the skill penalty is steep enough to make it a bad idea.

---

## Armor Types

| Type | Description | Slot |
|---|---|---|
| **Cloth** | Robes, tunics, reinforced fabric. No physical weight; relies on stats and enchantments. | Head, Chest, Legs, Hands, Feet |
| **Leather** | Tanned hide. Light and flexible; favored by scouts, druids, and monks. | Head, Chest, Legs, Hands, Feet |
| **Chain** | Interlocked metal rings. Good protection with limited mobility penalty. | Head, Chest, Legs, Hands, Feet |
| **Plate** | Full metal plate. Maximum protection; only the most disciplined fighters can use it effectively. | Head, Chest, Legs, Hands, Feet |
| **Shield** | Offhand defensive item. Trains separately from body armor; contributes its own bonus_armor to AC. | Offhand |

Items declare their type via the `armor_type` property on `ItemData`. An item with `armor_type = ""` contributes raw `bonus_armor` with no skill applied.

---

## Class Caps (at level 60)

| Class | Cloth | Leather | Chain | Plate | Shield |
|---|---|---|---|---|---|
| Warrior | 75 | 150 | 225 | 250 | 250 |
| Paladin | 75 | 150 | 200 | 225 | 250 |
| Shadow Knight | 75 | 150 | 200 | 225 | 225 |
| Cleric | 100 | 100 | 200 | 225 | 225 |
| Druid | 100 | 200 | 175 | — | 125 |
| Shaman | 100 | 175 | 225 | — | 175 |
| Rogue | 100 | 250 | 100 | — | 100 |
| Monk | 150 | — | — | — | — |
| Ranger | 75 | 225 | 225 | — | 175 |
| Beast Master | 75 | 200 | 200 | — | 150 |
| Bard | 75 | 200 | 225 | — | 150 |
| Witch Hunter | 75 | 200 | 225 | — | 150 |
| Magician | 250 | 50 | — | — | — |
| Wizard | 250 | 50 | — | — | — |
| Sorcerer | 250 | 50 | — | — | — |
| Necromancer | 250 | 50 | — | — | — |
| Enchanter | 250 | 50 | — | — | — |
| Blood Mage | 200 | 100 | 50 | — | — |

`—` = cap is 0 (0.5× armor effectiveness).

**Monk note:** Monks train only Cloth as a fallback. Their defense comes from Hand to Hand, Defense, and Dodge weapon skills — not from worn armor. They should generally go unarmored.

---

## Armor Values by Tier (design target)

| Tier | Piece AC Range | Full-set AC (5 pieces) |
|---|---|---|
| Cloth | 1–3 per piece | ~7–15 |
| Leather | 3–6 per piece | ~15–30 |
| Chain | 6–12 per piece | ~30–60 |
| Plate | 10–20 per piece | ~50–100 |

AC feeds into `reduction = armor / (armor + 100)`, so a full plate warrior at max skill at level 60 might have ~120 AC → ~54% damage reduction before evasion.

---

## Implementation

- `data/armor_skill_definitions.gd` — Class caps table
- `autoloads/armor_skills.gd` — Runtime skill tracking; `get_effective_armor()` applies skill multiplier per item
- `autoloads/equipment.gd` — `get_armor_class()` now delegates to `ArmorSkills.get_effective_armor()` instead of raw sum
- `autoloads/combat.gd` — Calls `ArmorSkills.try_advance_worn()` each time the player takes a melee hit
- `scripts/item_data.gd` — `armor_type: String` export field added
