# Necromantic Scribing

*Exclusive — Evil alignment required. Necromancer primary; Shadow Knight secondary.*

## Overview

Necromantic Scribing is the dark counterpart to Scribing. Where standard Scribing copies spells and maps and produces scrolls any class can use, Necromantic Scribing copies dark tomes, inscribes summon scrolls, and produces components for death-magic rituals. The products are not usable by classes outside Necromancer and Shadow Knight.

The skill is mechanically identical to Scribing — the player sits at a writing surface, uses materials, produces a scroll or document. The difference is what the scroll contains and what receiving it does to you.

Necromantic Scribing cannot be learned by improving Scribing. They share no XP pool. A Grandmaster Scribe starts Necromantic Scribing at 0.

---

## Requirements

| Requirement | Detail |
|---|---|
| Alignment | Evil (score ≤ -1500) or High Evil (score ≤ -1000 with Necromancer class) |
| Primary Class | Necromancer |
| Secondary Access | Shadow Knight (restricted recipe subset; see below) |
| Trainer | Dark Elf guild or Necromancer hall only — recipe cannot be self-taught |
| Skill Start | 0; no racial bonus |

**Lich transformation:** Raises cap to 250. Additionally, the Lich can inscribe scrolls with longer-lasting effects and access the Void tier recipes. Lich transformation is the primary driver for pushing Necromantic Scribing to its ceiling.

---

## Reagent Sources

Necromantic Scribing requires components not found in standard vendor inventories:

| Reagent | Source |
|---|---|
| Bone Dust | Crushing Bone components (Bone Carving by-product; Grave Robbing yield) |
| Lich Dust | Grave Robbing (Necromancer's crypt tier); rare dungeon drop |
| Death Rune | Grave Robbing (Mage's tomb); carved from dungeon walls |
| Soul Shard | Grave Robbing (Necromancer's crypt); boss mob drop |
| Dark Ink | Black Alchemy product (Necromancer's Ink — Alchemy skill 160+) |
| Void Bloom | Herbalism (end-game zones, Lich-corrupted areas) |
| Ruinstone Rubbing | Scribing-adjacent: a rubbing taken from a Ruinstone block (Quarrying) |
| Grave Flower | Herbalism (near burial sites, undead zones) |
| Shadowscript Paper | Necromantic Scribing intermediate: Dark Ink + Parchment + Bone Dust at skill 30 |

**Necromancer's Ink:** The Alchemy product that feeds Necromantic Scribing is itself restricted — the recipe is only sold at Dark Elf guilds and Necromancer halls. This creates a chain: an Evil-aligned Alchemist produces Necromancer's Ink → Necromantic Scribe uses it. If the Necromancer is also the Alchemist, they are entirely self-contained. If not, they depend on a dark-aligned Alchemist supplier.

---

## Products

### Necromancer Exclusive (Evil alignment, Necromancer class)

| Product | Materials | Min Skill | Effect |
|---|---|---|---|
| Scroll of Minor Summoning | Shadowscript Paper + Bone Dust | 30 | Single-use: summons a Skeleton (weaker than class-cast version; any evil-aligned Necromancer can use) |
| Dark Tome Page | Shadowscript Paper + Death Rune | 50 | Lore item: combines into full tomes for quest/story content |
| Scroll of Bind Undead | Shadowscript Paper + Soul Shard | 80 | Single-use: temporarily commands an enemy undead (1 minute; no pet slot consumed) |
| Ritual Circle Component | Shadowscript Paper × 3 + Death Rune + Lich Dust | 100 | Physical component placed on the ground; activates a 5-minute undead-summoning ward |
| Scroll of Life Leech | Dark Ink + Shadowscript Paper + Bat Blood | 110 | Single-use: drain 60 HP from target; restored to caster; no mana cost |
| Necromancer's Codex (volume) | 5× Shadowscript + Dark Ink + Bone Carving cover | 140 | Tradeable lore tome; contains dark ritual lore; collectible; some unlock one-time effects when read |
| Lich Ritual Text | Dark Ink × 3 + Soul Shard + Void Bloom | 160 | Required component for Lich transformation initiation ritual; one per character ever |
| Void Scroll | Void Bloom + Lich Dust + Shadowscript × 2 | 180 (Lich) | Single-use: summons a Void entity for 30 seconds; powerful but costly |

### Shadow Knight Access (subset)

Shadow Knights cannot learn the full Necromantic Scribing recipe list. They have access to a restricted subset:

| Product | Min Skill | Effect |
|---|---|---|
| Scroll of Dark Ward | 40 | Single-use: absorb shield (Shadow-type); equivalent to class skill but storable |
| Dark Iron Binding | 60 | Applied to armor: +10 shadow resistance; functionally similar to Runecarving for dark-aligned gear |
| Fallen Covenant Scroll | 120 | Requires Fallen Paladin transformation; copies a version of the transformation's dark spells to scroll form; extremely rare |

---

## The Lich Ritual Text

The Lich Ritual Text deserves its own note. It is the gateway item for the Lich transformation (see `docs/design/systems.md` — Earned Transformations). One Lich Ritual Text is consumed per transformation attempt. The character must be Necromancer level 30, Evil alignment, and have the Text in inventory during the ritual.

This means the path to Lich runs through Necromantic Scribing. A Necromancer who wants the transformation but has not leveled Necromantic Scribing to 160 either produces the Text themselves or purchases it from another Necromantic Scribe. Given that qualified sellers are rare (Evil Necromancers who've leveled the skill to 160), the Lich Ritual Text is one of the rarest and most valuable tradeskill products in the game.

**There is exactly one per Lich transformation.** It is not reusable. Once consumed, the Necromancer is transformed and can never create a Lich Ritual Text again (they already are one).

---

## The Broader Picture

Necromantic Scribing is the economic spine of Evil-aligned caster play. It creates:
- Direct dependency on Grave Robbing (reagent supply)
- Direct dependency on Black Alchemy (Necromancer's Ink)
- A market for Bone Carving products (covers and components)
- The hard gate on the Lich transformation

A Necromancer who builds out the full dark tradeskill tree — Herbalism (Grave Flower), Black Alchemy, Grave Robbing, and Necromantic Scribing — is one of the most self-sufficient characters in the game. They never need to visit a good-aligned vendor. They can operate entirely within the dark economy.

That isolation is by design. The dark economy is its own world.
