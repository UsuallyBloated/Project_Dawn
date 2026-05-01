# Wizard
*Arcane DPS (Specialist) — Any Alignment — Memorized Spellbook*

## Overview
The highest damage ceiling in the game — when prepared. The Wizard is defined by a single constraint that shapes every decision they make: they cannot cast a spell they haven't memorized. Before entering content, a Wizard selects a specific set of spells from their spellbook and loads them into memorized slots. Only those spells are available until the Wizard sits and re-memorizes — which takes real time out of combat. Every other arcane caster sacrifices something to be flexible. The Wizard sacrifices everything to hit the hardest.

When fully prepared, Meteor is the highest single-hit damage spell in the game. When the prepared spells run dry, the Wizard is a cloth-wearing staff-user waiting for mana to return. The class punishes improvisation absolutely and rewards it zero percent. What it rewards is preparation, positioning, and the discipline to not waste resources on targets that don't justify the expenditure.

The Wizard is the academic caster. The Sorcerer was born with it. The Magician learned broadly. The Wizard studied for decades, wrote it down, memorized it, and will not apologize for how long that took.

## Combat Profile
- **Armor:** Cloth
- **Weapons:** Staves
- **Primary Resource:** Mana (preparation-gated — see Memorization below)
- **Pet:** None

## The Memorization System
*Design target — not yet implemented.*

Before entering combat, the Wizard prepares a fixed number of spell slots from their full spellbook. Only memorized spells appear on the action bar during combat. The unmemorized remainder exists in the spellbook but cannot be cast.

**Implications:**
- Commit to a plan before pulling. A Wizard who memorized fire spells against a fire-immune enemy is in trouble.
- Re-memorizing requires sitting for a meaningful duration — not a brief pause. Changing loadout mid-dungeon is a real cost.
- The preparation window is the Wizard's most important combat decision.
- A fully prepared Wizard opening an encounter with memorized spells is the game's highest burst state.
- A Wizard who has spent their memorized spells is genuinely weaker than any other arcane class until re-memorized.

## Spells — Current Implementation
| Spell | Type | Damage | Mana | Cast | Cooldown |
|---|---|---|---|---|---|
| Ice Spear | Ice dmg | 50 | 28 | 1.0s | 5s |
| Flame Wave | Fire dmg | 75 | 38 | 1.8s | 9s |
| Blizzard | Ice dmg | 65 | 45 | 2.0s | 12s |
| Thunder Clap | Lightning dmg | 100 | 50 | 2.5s | 14s |
| Meteor | Fire dmg | 130 | 65 | 3.5s | 20s |

All Wizard spells have meaningful cast times. No instants. Every cast is a commitment.

## Signature Spells — Design Targets
| Spell | Type | Effect | Notes |
|---|---|---|---|
| **Gate** | Utility | Instant teleport to bind point | Emergency escape; Wizard pillar; usable from anywhere, one use between binds |
| **Frost Nova** | Ice AoE | AoE freeze in melee radius | Defensive — pushes enemies away when they reach melee; buys cast time |
| **Concussive Blast** | Lightning AoE | AoE damage + interrupt | Interrupts all ongoing casts in range |
| **Manaburn** | Arcane dmg | Drains target mana as damage | Against caster enemies; converts their mana pool into your damage |
| **Telekinetic Burst** | Arcane | Knockback + stun | Positional control without damage school commitment |

## Skills
None — pure spellcaster.

## Race Availability
**Available:** Human, Elf, Dark Elf, Gnome, Dwarf, Half-Elf, Kel`varath, Fae

**Blocked:** Ogre, Troll (cannot hold the sustained abstract concepts); Wood Elf (oral tradition only — no written spellbook); Halfling (no institutional arcane tradition); Minotaur (displaced people, no fixed schools); Felhari (no written arcane tradition); Kobold (lifespan too short for meaningful academic completion); Half-Ogre.

## Versus Magician and Sorcerer

| | Magician | Sorcerer | Wizard |
|---|---|---|---|
| Source of power | Learned (generalist) | Innate (bloodline) | Learned (specialist) |
| Preparation required | None | None | Yes — memorization before pull |
| Flexibility | Highest (cross-school) | High (always available) | None (memorized set only) |
| Single-hit ceiling | Medium (80) | Medium (80) | Highest (130) |
| Sustained output | Good | Best (never dry) | Volatile (high peaks, crashes) |
| Spell variety | Widest breadth | Narrower but available | Narrowest active set |
| Solo viability | Good | Best | Conditional on preparation |

## Playstyle
Prepare before pulling. Commit highest-output spells (Meteor, Thunder Clap) to memorized slots; maintain Ice Spear and Flame Wave for sustained damage after the big cooldowns. Open encounters with memorized burst; disengage if preparation is exhausted rather than continuing at diminished capacity. Gate is the escape hatch when everything goes wrong — use it without hesitation. Between pulls, sit and consider whether the remaining content justifies re-memorizing.

The Wizard's skill floor is medium (cast the big spells when they're up) and their skill ceiling is very high (read the upcoming encounter, memorize correctly, position for maximum cast time, Gate at the last safe moment).

## Spell Unlock Schedule

Spells are purchased from Wizard guild libraries or copied from recovered arcane texts. All Wizard spells have meaningful cast times — the school produces no instants by design. Spells not currently memorized exist in the spellbook but cannot be cast.

### Level 1

| Spell | Description | School | Mana |
|---|---|---|---|
| Flame Bolt | Fire damage (30); 1.0s cast | Fire | 18 |
| Frost Arrow | Ice damage (28); 1.0s cast | Ice | 18 |
| Shock Bolt | Lightning damage (25); 1.0s cast | Lightning | 15 |
| Fire Shield | Self: absorb 50 fire damage for 60s | Fire | 20 |

### Level 4

| Spell | Description | School | Mana |
|---|---|---|---|
| Flame Wave | Fire damage (75); 1.8s cast | Fire | 38 |
| Ice Spear | Ice damage (50); 1.0s cast | Ice | 28 |
| Fire Blast | Fire damage (55); 1.5s cast | Fire | 30 |
| Frost Spike | Ice damage (42); 1.2s cast | Ice | 25 |
| Bind Affinity | Bind target (or self) to this location; cannot cast in dungeons; 3s cast | Utility | 30 |

### Level 8

| Spell | Description | School | Mana |
|---|---|---|---|
| Blizzard | Ice damage (65); 2.0s cast | Ice | 45 |
| Thunder Strike | Lightning damage (80); 2.0s cast | Lightning | 45 |
| Flame Wave II | Fire damage (98); 1.8s cast | Fire | 52 |
| Frost Shards | AoE ice damage (45) in 8m radius; 2.0s cast | Ice | 55 |

### Level 12

| Spell | Description | School | Mana |
|---|---|---|---|
| Thunder Clap | Lightning damage (100); 2.5s cast | Lightning | 50 |
| Flame Wave III | Fire damage (122); 1.8s cast | Fire | 65 |
| Blizzard II | Ice damage (90); 2.0s cast | Ice | 58 |
| Gate | Instant teleport to bound location; emergency escape; one use per bind | Utility | 60 |

### Level 16

| Spell | Description | School | Mana |
|---|---|---|---|
| Ice Spear II | Ice damage (75); 1.0s cast | Ice | 40 |
| Meteor | Fire damage (130); 3.5s cast | Fire | 65 |
| Frost Nova | AoE ice damage (55) in 5m radius; push enemies back; 2.0s cast | Ice | 60 |
| Thunder Clap II | Lightning damage (128); 2.5s cast | Lightning | 65 |
| Teleport: Aelindra | Port group to the ley anchor outside Aelindra; 8s cast | Utility | 150 |

### Level 20

| Spell | Description | School | Mana |
|---|---|---|---|
| Meteor II | Fire damage (162); 3.5s cast | Fire | 82 |
| Conflagration | Fire damage (145); 2.0s cast | Fire | 85 |
| Blizzard III | Ice damage (118); 2.0s cast | Ice | 75 |
| Tempest | Lightning damage (142); 2.5s cast | Lightning | 82 |
| Manaburn | Drain target caster's mana as damage; equal to mana drained | Arcane | 40 |
| Telekinetic Burst | Arcane knockback + stun 2s; 1.5s cast; no damage school | Arcane | 35 |
| Teleport: Greyveil | Port group to the ley anchor above Greyveil; 8s cast | Utility | 150 |

### Level 24

| Spell | Description | School | Mana |
|---|---|---|---|
| Ice Spear III | Ice damage (100); 1.0s cast | Ice | 52 |
| Wildfire | AoE fire damage (90) in 12m radius; 2.5s cast | Fire | 95 |
| Blizzard IV | Ice damage (148); 2.0s cast | Ice | 95 |
| Thunder Clap III | Lightning damage (158); 2.5s cast | Lightning | 82 |
| Meteor III | Fire damage (195); 3.5s cast | Fire | 100 |
| Teleport: Harrowmere | Port group to the ley anchor above Harrowmere; 8s cast | Utility | 150 |

### Level 29

| Spell | Description | School | Mana |
|---|---|---|---|
| Flame Wave IV | Fire damage (175); 1.8s cast | Fire | 108 |
| Blizzard V | Ice damage (180); 2.0s cast | Ice | 115 |
| Concussive Blast | AoE lightning damage (88) in 12m; interrupt all active casts in range; 2.5s cast | Lightning | 100 |
| Thunder Clap IV | Lightning damage (190); 2.5s cast | Lightning | 100 |
| Frost Nova II | AoE ice damage (80) in 5m; push back + root 3s; 2.0s cast | Ice | 85 |
| Teleport: Varek's Spire | Port group to the base of Varek's Spire; 8s cast | Utility | 150 |

### Level 34

| Spell | Description | School | Mana |
|---|---|---|---|
| Ice Spear IV | Ice damage (128); 1.0s cast | Ice | 68 |
| Wildfire II | AoE fire damage (135) in 15m radius; 2.5s cast | Fire | 130 |
| Thunder Clap V | Lightning damage (222); 2.5s cast | Lightning | 118 |
| Meteor IV | Fire damage (232); 3.5s cast | Fire | 120 |
| Manaburn II | Drain target mana as damage; bonus 20% of mana drained added | Arcane | 55 |

### Level 39

| Spell | Description | School | Mana |
|---|---|---|---|
| Flame Wave V | Fire damage (215); 1.8s cast | Fire | 132 |
| Blizzard VI | Ice damage (215); 2.0s cast | Ice | 138 |
| Thunder Clap VI | Lightning damage (258); 2.5s cast | Lightning | 138 |
| Meteor V | Fire damage (272); 3.5s cast | Fire | 142 |
| Ancient Gate | Instant teleport; bind point reset timer halved | Utility | 55 |
| Concussive Blast II | AoE lightning (125) in 15m; interrupt all casts; 2.5s cast | Lightning | 128 |

### Level 44

| Spell | Description | School | Mana |
|---|---|---|---|
| Ancient Flame Wave | Fire damage (255); 1.8s cast | Fire | 158 |
| Thunder Clap VII | Lightning damage (298); 2.5s cast | Lightning | 160 |
| Meteor VI | Fire damage (315); 3.5s cast | Fire | 165 |
| Ice Spear V | Ice damage (162); 1.0s cast | Ice | 88 |
| Telekinetic Storm | AoE knockback + stun 3s in 15m radius; 2.0s cast | Arcane | 80 |

### Level 49

| Spell | Description | School | Mana |
|---|---|---|---|
| Ancient Thunder Clap | Lightning damage (342); 2.5s cast | Lightning | 185 |
| Ancient Meteor | Fire damage (365); 3.5s cast | Fire | 195 |
| Ancient Blizzard | Ice damage (258); 2.0s cast | Ice | 168 |
| Ancient Flame Wave II | Fire damage (298); 1.8s cast | Fire | 182 |
| Manaburn III | Drain target mana as damage; bonus 40% added; instant | Arcane | 72 |

### Level 50

| Spell | Description | School | Mana |
|---|---|---|---|
| Grand Meteor | Fire damage (430); 4.0s cast; highest single-hit damage in the game | Fire | 240 |
| Ancient Concussive Storm | AoE lightning (200) in 20m; interrupt all casts; push back 15m | Lightning | 220 |
| Arcane Transcendence | 20s: all spells deal triple damage and have no cast time | Arcane | 250 |

## Portrait Reference
*See [characters.md](../lore/characters.md) — Human Wizard: "The Annotated Life"*
