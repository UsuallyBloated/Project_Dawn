# Alignment System
*The world remembers what you do.*

## Overview

Alignment is a numerical score that tracks the cumulative moral weight of a character's choices — every kill, every spell cast, every quest completed, every act of cruelty or mercy. It is not a label the character applies to themselves. It is a record.

The score runs from **-2000** (most evil) to **+2000** (most good). At any moment it places the character in one of five tiers, each of which changes how the world perceives and treats them. The score is private — players cannot see each other's exact number. NPCs, however, can read it, and they respond accordingly.

---

## The Five Tiers

| Tier | Score Range | Summary |
|---|---|---|
| [**Exalted**](exalted.md) | ≥ 1500 | Recognized by the divine; the world bends toward you |
| [**Good**](good.md) | 300 to 1499 | Trusted; welcomed in civilized settlements |
| [**Neutral**](neutral.md) | -299 to 299 | Assessed individually; no automatic doors open or close |
| [**Bad**](bad.md) | -1500 to -300 | Distrusted; certain cities and factions shut down |
| [**Evil**](evil.md) | ≤ -1501 | Recognized as a threat; open hostility in Good-aligned territories |

---

## Starting Alignment by Class

| Class | Starting Score | Starting Tier |
|---|---|---|
| Paladin | +500 | Good |
| Cleric | +400 | Good |
| Monk | +100 | Good |
| Witch Hunter | +100 | Good |
| Warrior, Rogue, Ranger, Bard, Magician, Wizard, Sorcerer, Druid, Shaman, Enchanter, Beast Master | 0 | Neutral |
| Blood Mage | -500 | Bad |
| Shadow Knight | -1600 | Evil |
| Necromancer | -1600 | Evil |

Starting tier is not destiny. Alignment drifts throughout play.

---

## Drift — How Alignment Changes

Alignment shifts through action. The `PlayerStats.modify_alignment(delta)` function applies changes. When a tier threshold is crossed, `alignment_changed` fires and the `Skills` and `Spells` autoloads rebuild available lists.

**Moves alignment down (toward Evil):**
- Killing Good-aligned NPCs or creatures
- Casting Evil-school spells (Shadow, Necromantic) in volume
- Completing quests for Evil-aligned factions
- Blood Mage HP drain spells (small negative per cast)
- Certain item use

**Moves alignment up (toward Good):**
- Killing Evil-aligned enemies
- Completing quests for Good-aligned factions
- Healing players and NPCs
- Cleric/Paladin holy spells (small positive per cast)
- Donations to temples

**Momentum:** The further from center, the harder it is to move further. Reaching Exalted from Good requires sustained effort over a long time. A Shadow Knight starting at -1600 reaching Exalted is nearly impossible through normal play — it requires a deliberate, extended redemption arc.

---

## Spell Effectiveness by Alignment

Some classes have abilities that depend on alignment being at the correct extreme.

| Class | At Neutral | At Opposing Extreme |
|---|---|---|
| Paladin | 0.7× effectiveness | 0.4× effectiveness |
| Shadow Knight | 0.7× effectiveness | 0.4× effectiveness |

Full effectiveness only at the intended alignment extreme. This makes alignment drift a mechanical consequence as well as a social one — a Paladin flirting with Evil loses power before they lose standing.

---

## NPC Recognition

NPCs observe alignment tier, not score. The tier determines:
- Whether guards attack on sight
- Which vendors will deal with the character
- Whether quest-givers engage or refuse
- What dialogue options are available
- NPC ambient reactions (bowing, cowering, spitting, warning others)

NPCs do not announce the tier — they simply behave accordingly. A player who doesn't know their tier will learn it from how the world treats them.

---

## Alignment-Triggered Transformations

Reaching certain tiers triggers permanent or semi-permanent changes. See the [Transformations index](../transformations/transformations.md).

**Drift-triggered (reversible if alignment shifts back):**
- Fallen Paladin — Evil tier
- Redeemed Shadow Knight — Exalted tier
- Fallen Cleric — Evil tier
- Corrupted Druid — Evil tier
- Enlightened Warrior — Exalted tier
- Tainted Monk — Evil tier
- Dark Trapper — Evil tier
- Redeemed Necromancer — Exalted tier

**Earned transformations (alignment is one gate among several):**
- Revenant requires Evil
- Vampire Lord requires Evil
- Lich requires Evil
- Lycanthrope requires Neutral
- Exalted (transformation) requires Exalted tier
- Warden of the Wild requires Exalted tier
- Seraphim Aspect requires Exalted tier
- Grove Heart requires Exalted tier

---

## Implementation Notes

- `PlayerStats.transformation` tracks the current transformation state
- `Transformations` autoload (stubbed) will handle trigger checking and application
- `alignment_changed` signal fires at tier boundary crossings
- Spell effectiveness implemented in `Spells._get_alignment_effectiveness()`
