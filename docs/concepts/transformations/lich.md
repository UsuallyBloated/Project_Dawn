# Lich
*Earned Permanent — Evil — The White Death*

## Overview
The Lich is what a Necromancer becomes when they apply their own discipline to themselves. Not undeath-by-accident, not a curse, not a transformation visited upon them by outside force — a deliberate ritual, thoroughly researched, carefully executed, at the cost of everything that makes a body alive. The phylactery is the keystone: a physical object containing the Lich's soul, outside their body, which means the body can be destroyed and the Lich will simply reconstitute. The body is a tool. The phylactery is what they actually are.

The power gained is extraordinary. The mana pool available to a Lich exceeds any living caster's capacity. The undead they command answer more readily. The spells available to them include abilities that require a caster to have personally died to cast. The cost is the body's living quality and, more importantly, the phylactery's vulnerability — it must be kept safe, and destroying it reverses the transformation at catastrophic personal cost.

This is the apex transformation for the Necromancer class, and among the most mechanically consequential in the game.

## Requirements
- **Alignment:** Evil (≤ -1501)
- **Class:** Necromancer
- **Level:** 30
- **Prerequisites:** The White Death quest (see below)

## The White Death Quest Arc
The Lich transformation is not automatic. The Necromancer must:

1. **Research the Ritual** — Acquire the phylactery schematics from a specific library or NPC in an Evil-aligned city. May require faction standing.
2. **Craft the Phylactery** — Requires rare materials (exact list TBD during implementation), a crafting skill threshold, and completion at a specific ritual site (a place of significant necromantic power).
3. **The Death** — The ritual requires the Necromancer to die at the phylactery site. This is a real death event — they go through the death sequence — and then the phylactery triggers the reconstitution.
4. **The Lich rises** — Transformation is complete at reconstitution.

The Phylactery carries ongoing stakes: if it is destroyed (by enemy action, specific quests, or another player in a PvP context if implemented), the transformation reverses and the Necromancer suffers extreme stat penalties for a lengthy period while the phylactery rebuilds.

## Effects

**Gained:**
- **Mana pool vastly increased** — The Lich can hold significantly more mana than any living caster
- **Lich Form** (signature toggle) — Trade HP regen for extreme mana regeneration; previously a design target spell that now becomes structural
- **Death's Command** — Can control one additional undead pet beyond the normal limit
- **Soul Cage** — Trap a recently-killed enemy's soul briefly; they cannot be resurrected for the duration, and the Lich can drain information or power from the caged soul
- **Bone Armor** — Passive damage reduction from skeletal reinforcement
- **Phylactery Anchor** — On death, reconstitute at the phylactery location after a significant delay rather than going to the standard death respawn

**Lost:**
- All out-of-combat natural HP regeneration
- Food/drink benefits
- Access to certain living-only consumables

**Visual:**
- Physical form becomes visibly undead: hollow eye sockets, skeletal hands, robes that move slightly wrong
- Lich Form toggle changes the appearance dramatically — the full classical lich aesthetic
- Particle effects on spells shift: darker, more architectural (orbiting bones, fragments of skull)

## Phylactery Mechanics
- The phylactery is a physical item in the character's possession (or a safe location of their choice)
- If another player or NPC accesses and destroys it, the Lich reconstitutes naked at the site with 1 HP and extreme debuffs
- The phylactery can be hidden; its location is not announced to other players
- Rebuilding the phylactery (if destroyed) requires repeating portions of the craft component of the quest

## Ability Reference

| Ability | Type | Effect | Mana | Cast |
|---|---|---|---|---|
| Lich Form | Toggle (signature) | Disable HP regen; mana regen ×5; appearance shifts to full lich aesthetic | 80 | Instant |
| Death's Command | Passive | Control one additional undead pet beyond the class cap | — | — |
| Soul Cage | Active utility | Trap a recently-killed enemy's soul for 30s; prevents resurrection; drain 50 mana from the soul per 5s | 35 | 1.0s |
| Bone Armor | Passive | Passive 8% physical damage reduction; skeletal reinforcement around the body | — | — |
| Phylactery Anchor | Passive (death mechanic) | On death: reconstitute at phylactery location after 60s instead of going to death respawn; phylactery must be intact | — | — |
| Expanded Mana Pool | Passive | Maximum mana increased by 50%; Lich form can hold more mana than any living caster | — | — |

## Notes
- Lich and Revenant are mutually exclusive — both occupy the undead-body space.
- Lich and Vampire Lord are mutually exclusive.
- This transformation has the highest complexity and implementation cost of any transformation in the game.
