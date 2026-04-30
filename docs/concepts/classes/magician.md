# Magician
*Arcane DPS (Generalist) + Pet — Any Alignment — Studied (Generalist)*

## Overview
The Magician went wide where the Wizard went deep. They studied fire and ice and lightning and arcane without specializing in any of them, which means they are never the best tool against any specific enemy type — and never useless against any enemy type either. Where the Wizard commits to memorized spells and the Sorcerer's bloodline limits their variety, the Magician has the widest active spell pool of the three arcane classes.

The distinguishing mechanic is elemental pets. The Magician is the only arcane class with a sustained companion, and each elemental type has a distinct tactical function: the earth elemental holds aggro and absorbs damage, the fire elemental deals the highest damage output of any pet, the water elemental provides healing support, and the air elemental contributes utility and evasion. No other pet class offers this elemental specialization choice on a per-encounter basis.

The Heal spell gives the Magician more self-sufficiency than any other pure arcane caster. Combined with the earth elemental as a damage sponge, a prepared Magician can handle solo content that would require a group for a Wizard or Sorcerer.

## Combat Profile
- **Armor:** Cloth
- **Weapons:** Staves, wands
- **Primary Resource:** Mana
- **Pet:** Elemental (summoned; one active at a time; see Elemental System below)

## Elemental System
*Design target — not yet implemented.*

The Magician summons one elemental at a time from four types. Summoning requires mana and a short cast. The active elemental persists until dismissed, killed, or replaced. Elemental level scales with the Magician's level.

| Elemental | Role | Primary Function | Weakness |
|---|---|---|---|
| **Earth** | Tank | Highest HP and armor of the four; holds aggro; low damage | Slow; cannot chase fleeing enemies effectively |
| **Fire** | DPS | Highest damage output; AoE burn on contact | Lowest HP; dies fast if targeted |
| **Water** | Support | Pulses healing to nearby allies; slows enemy movement | Low damage; requires enemy to engage it, not ignore it |
| **Air** | Utility | Fastest movement; grants the Magician haste; can scout ahead briefly | Lowest physical damage; relies on mobility to survive |

**Tactical implication:** Before pulling, the Magician chooses a role. Earth for dangerous solo content. Fire to maximize group DPS. Water when playing healer support. Air when the fight requires movement or mobility over sustained pressure.

## Spells — Current Implementation
| Spell | Type | Damage/Heal | Mana | Cast | Cooldown |
|---|---|---|---|---|---|
| Arcane Missile | Arcane dmg | 20 | 15 | Instant | 2s |
| Frost Bolt | Ice dmg | 30 | 20 | Instant | 3s |
| Fireball | Fire dmg | 50 | 30 | 1.5s | 8s |
| Lightning Strike | Lightning dmg | 80 | 40 | 2.0s | 12s |
| Heal | Self-heal | +40 HP | 25 | 1.0s | 6s |

## Signature Spells — Design Targets
| Spell | Type | Effect | Notes |
|---|---|---|---|
| **Conjure Earth / Fire / Water / Air** | Summoning | Summons the selected elemental type | Core class mechanic; fast cast; costs mana |
| **Elemental Fury** | Pet buff | Target elemental deals 50% more damage for 10s | Used to spike DPS during a fire elemental; costs significant mana |
| **Shard Storm** | Ice AoE | Instant-cast cone of ice hitting up to 4 targets | The Magician's AoE access; weaker than dedicated AoE but flexible |
| **Elemental Bond** | Passive | When the active elemental dies, the Magician gains a brief mana refund and a 5s cooldown reduction on all summons | Rewards cycling elementals under pressure rather than panicking |
| **Grounding Field** | Utility | Area debuff that reduces enemy movement speed; pairs with earth elemental as tank | Not damage; positional control |

## Skills
None — pure spellcaster.

## Race Availability
**Available:** All races except Ogre.

**Blocked:** Ogre — INT floor too low for arcane study in any school, generalist or not.

## Versus Wizard and Sorcerer

| | Wizard | Sorcerer | Magician |
|---|---|---|---|
| Source of power | Academic (specialist) | Bloodline (innate) | Academic (generalist) |
| Spell variety | Narrowest active set (memorized) | Moderate | Widest breadth |
| Damage ceiling | Highest (Meteor 130) | Medium (Soul Surge 80) | Medium (Lightning Strike 80) |
| Pet | None | None | Yes — elemental; role-selectable |
| Self-sustain | None | Mana Feed (HP → mana) | Heal spell; earth elemental as sponge |
| Solo viability | Conditional (preparation-dependent) | Good | Best of the three |
| Group specialization | Burst DPS | Sustained DPS | Flexible (pet role + damage school) |

## Playstyle
Before pulling: choose an elemental. Earth for content where survival is uncertain. Fire for farm content where speed matters. Water when group healing is under pressure. Air when you need to move.

In combat: Arcane Missile and Frost Bolt for pressure while long-cooldown spells recharge; Fireball for medium investments; Lightning Strike for the burst moment. Heal keeps the Magician up when the elemental isn't absorbing enough. Elemental Fury spikes the fire elemental's damage for decisive moments.

The Magician's skill expression is in elemental selection and positioning — placing the earth elemental to hold aggro, keeping the fire elemental alive by not pulling it into cleave attacks, using the water elemental's healing where it reaches group members. The spells are the simplest of the three arcane classes. The pet management is the deepest.

## Spell Unlock Schedule

Spells are purchased from Magician guild vendors or arcane libraries. Elemental summons are always available from the guild but require the listed minimum level to successfully bind. A summoned elemental that outlasts the Magician's mana reserve will not vanish — it will simply stop obeying.

### Level 1

| Spell | Description | School | Mana |
|---|---|---|---|
| Arcane Missile | Arcane damage (20); instant | Arcane | 15 |
| Frost Bolt | Ice damage (30); instant | Arcane | 20 |
| Fireball | Fire damage (50); 1.5s cast | Arcane | 30 |
| Heal | Self-heal: restore 40 HP; 1.0s cast | Restoration | 25 |
| Conjure Staff | Summon a temporary magical staff; lasts 30 minutes | Conjuration | 10 |

### Level 4

| Spell | Description | School | Mana |
|---|---|---|---|
| Lightning Strike | Lightning damage (80); 2.0s cast | Arcane | 40 |
| Conjure Earth Elemental | Summon an earth elemental; highest HP of the four; holds aggro | Conjuration | 50 |
| Arcane Missile II | Arcane damage (32); instant | Arcane | 22 |
| Frost Spike | Ice damage (48); instant; minor slow on hit | Arcane | 28 |

### Level 8

| Spell | Description | School | Mana |
|---|---|---|---|
| Conjure Fire Elemental | Summon a fire elemental; highest damage output; low HP | Conjuration | 50 |
| Flames of Ro | Fire damage (72); 1.5s cast | Arcane | 42 |
| Glacial Spear | Ice damage (55); instant | Arcane | 35 |
| Arcane Missile III | Arcane damage (45); instant | Arcane | 30 |
| Heal II | Self-heal: restore 70 HP; 1.0s cast | Restoration | 40 |
| Arcane Shield | Self: absorb 80 incoming damage | Arcane | 35 |

### Level 12

| Spell | Description | School | Mana |
|---|---|---|---|
| Conjure Water Elemental | Summon a water elemental; pulses healing to nearby allies; low damage | Conjuration | 50 |
| Thunderbolt | Lightning damage (110); 2.0s cast | Arcane | 55 |
| Frost Shard | Ice damage (72); instant | Arcane | 42 |
| Blaze | Fire damage (95); 1.5s cast | Arcane | 58 |
| Arcane Missile IV | Arcane damage (58); instant | Arcane | 38 |

### Level 16

| Spell | Description | School | Mana |
|---|---|---|---|
| Conjure Air Elemental | Summon an air elemental; fastest movement; grants haste; utility focus | Conjuration | 50 |
| Frost Storm | AoE ice damage (65) in 10m radius | Arcane | 65 |
| Arcane Missile V | Arcane damage (72); instant | Arcane | 48 |
| Storm Spike | Lightning damage (140); 2.0s cast | Arcane | 72 |
| Heal III | Self-heal: restore 105 HP; 1.0s cast | Restoration | 58 |

### Level 20

| Spell | Description | School | Mana |
|---|---|---|---|
| Elemental Fury | Target elemental: +50% damage for 10s | Conjuration | 55 |
| Conflagration | Fire damage (125); 1.5s cast | Arcane | 78 |
| Blizzard Bolt | Ice damage (100); instant | Arcane | 62 |
| Arcane Missile VI | Arcane damage (88); instant | Arcane | 58 |
| Tempest Lance | Lightning damage (170); 2.0s cast | Arcane | 88 |
| Conjure Greater Earth | Dismiss and re-summon earth elemental at improved level | Conjuration | 65 |

### Level 24

| Spell | Description | School | Mana |
|---|---|---|---|
| Arcane Torrent | Arcane damage (110); instant | Arcane | 72 |
| Frost Storm II | AoE ice damage (100) in 10m radius | Arcane | 88 |
| Conjure Greater Fire | Dismiss and re-summon fire elemental at improved level | Conjuration | 65 |
| Inferno | Fire damage (158); 1.5s cast | Arcane | 98 |
| Lightning Barrage | Lightning damage (205); 2.0s cast | Arcane | 108 |
| Heal IV | Self-heal: restore 148 HP; 1.0s cast | Restoration | 80 |

### Level 29

| Spell | Description | School | Mana |
|---|---|---|---|
| Conjure Greater Water | Dismiss and re-summon water elemental at improved level | Conjuration | 65 |
| Frozen Spike | Ice damage (132); instant | Arcane | 85 |
| Arcane Missile VII | Arcane damage (108); instant | Arcane | 72 |
| Chain Lightning | Lightning damage (165); arcs to 2 additional nearby targets for 50% | Arcane | 120 |
| Cinderblast | Fire damage (192); 1.5s cast | Arcane | 120 |
| Elemental Bond | Passive: when active elemental dies, gain 60 mana and 5s cooldown reduction on summons | Conjuration | 0 |

### Level 34

| Spell | Description | School | Mana |
|---|---|---|---|
| Arcane Torrent II | Arcane damage (138); instant | Arcane | 90 |
| Conjure Greater Air | Dismiss and re-summon air elemental at improved level | Conjuration | 65 |
| Frost Storm III | AoE ice damage (140) in 12m radius | Arcane | 112 |
| Immolation | Fire damage (228); 1.5s cast | Arcane | 142 |
| Tempest Barrage | Lightning damage (248); 2.0s cast | Arcane | 130 |
| Elemental Fury II | Target elemental: +80% damage, +30% HP for 15s | Conjuration | 80 |

### Level 39

| Spell | Description | School | Mana |
|---|---|---|---|
| Arctic Lance | Ice damage (168); instant | Arcane | 108 |
| Arcane Missile VIII | Arcane damage (132); instant | Arcane | 88 |
| Grounding Field | AoE: reduce all enemy movement speed 40% in 15m for 20s | Arcane | 70 |
| Heal V | Self-heal: restore 205 HP; 1.0s cast | Restoration | 110 |
| Wildfire | Fire damage (265); 1.5s cast | Arcane | 165 |
| Storm of Blades | Lightning damage (292); 2.0s cast | Arcane | 155 |

### Level 44

| Spell | Description | School | Mana |
|---|---|---|---|
| Conjure Elder Earth | Dismiss and re-summon earth elemental at elder level; significantly stronger | Conjuration | 90 |
| Arcane Torrent III | Arcane damage (168); instant | Arcane | 110 |
| Frost Storm IV | AoE ice damage (190) in 15m radius | Arcane | 145 |
| Conflagration II | Fire damage (308); 1.5s cast | Arcane | 192 |
| Elemental Fury III | Target elemental: +120% damage, +60% HP for 20s | Conjuration | 110 |

### Level 49

| Spell | Description | School | Mana |
|---|---|---|---|
| Conjure Elder Fire | Dismiss and re-summon fire elemental at elder level | Conjuration | 90 |
| Conjure Elder Water | Dismiss and re-summon water elemental at elder level | Conjuration | 90 |
| Conjure Elder Air | Dismiss and re-summon air elemental at elder level | Conjuration | 90 |
| Ancient Arcane Missile | Arcane damage (162); instant | Arcane | 108 |
| Ancient Wildfire | Fire damage (358); 1.5s cast | Arcane | 220 |
| Ancient Tempest | Lightning damage (342); 2.0s cast | Arcane | 210 |

### Level 50

| Spell | Description | School | Mana |
|---|---|---|---|
| Summon Primal Earth | Summon a primal earth elemental; far beyond elder tier; absorbs punishment indefinitely | Conjuration | 150 |
| Storm of Elements | AoE: fire, ice, and lightning all simultaneously in 20m radius; 200 each school | Arcane | 280 |
| Arcane Mastery | 20s: all spells cost 0 mana and have no cooldown | Arcane | 200 |

## Portrait References
*See [characters.md](../characters.md):*
- *Dark Elf Magician — "The Obsidian Scholar"*
- *Elf Magician — "The Last Archivist"*
