# Sorcerer
*Arcane DPS (Innate) — Any Alignment — Bloodline*

## Overview
The Sorcerer was not taught. They were born this way. Where the Wizard spent decades memorizing and the Magician studied broadly across schools, the Sorcerer's power is biological — it runs in the blood, it has always been there, and it cannot be prepared away or locked behind a spellbook. What cannot be memorized cannot be forgotten. The Sorcerer's spells are always available.

The practical consequence: a Sorcerer who pulls the fifteenth mob in a dungeon run is performing almost identically to the Sorcerer who pulled the first. No preparation window. No re-memorize sit. No spellbook to consult. The cost of this reliability is ceiling — peak single-hit damage (Soul Surge at 80) sits meaningfully below the Wizard's Meteor (130). That tradeoff is the class in a sentence: lower ceiling, no floor.

The bloodline also creates a fallback the other arcane classes don't have. When mana is genuinely low, the Sorcerer can convert HP into power rather than sitting. This costs health and is not sustainable, but it exists — a last option that reflects something primal about where the power actually comes from.

## Combat Profile
- **Armor:** Cloth
- **Weapons:** Staves
- **Primary Resource:** Mana (with HP fallback — see Bloodsurge)
- **Pet:** None

## Spells — Current Implementation
| Spell | Type | Damage | Mana | Cast | Cooldown |
|---|---|---|---|---|---|
| Arcane Burst | Arcane dmg | 30 | 18 | Instant | 3s |
| Bloodfire | Fire dmg | 40 | 22 | Instant | 4s |
| Void Lance | Arcane dmg | 55 | 28 | 1.0s | 6s |
| Tempest Bolt | Lightning dmg | 65 | 35 | 1.5s | 10s |
| Soul Surge | Arcane dmg | 80 | 45 | 2.0s | 14s |

Two instants (Arcane Burst, Bloodfire) give the Sorcerer output windows no other arcane class can access — anything that interrupts a Wizard's cast is irrelevant to a Sorcerer.

## Signature Spells — Design Targets
| Spell | Type | Effect | Notes |
|---|---|---|---|
| **Bloodsurge** | Arcane dmg | 90 damage; costs 30 HP + 20 mana instead of full mana | The fallback; the bloodline powering itself off the body; only useful when mana-pressed |
| **Arcane Nova** | Arcane AoE | Instant-cast AoE burst around the Sorcerer | Bloodline flaring outward; shorter range than most AoEs; dangerous to cast in melee but that's the point |
| **Resonance** | Passive | Each successive spell hit on the same target builds resonance stacks; at 5 stacks, the next spell auto-crits | Rewards sustained focus on a single target; punishes mob-swapping |
| **Void Anchor** | Arcane | Slows the target's movement speed significantly for 8s | Not a root; not a stun; target can still attack and cast; pure kiting tool |
| **Mana Feed** | Self-utility | Instant; converts 50 HP to 40 mana | The "never runs dry" mechanic; the body is the battery |

## Skills
None — pure spellcaster.

## Race Availability
**Available:** Human, Elf, Dark Elf, Wood Elf, Gnome, Halfling, Dwarf, Half-Elf, Troll, Kel`varath, Fae, Felhari, Kobold, Half-Ogre

**Blocked:** Ogre, Minotaur — the bloodline power exists in these races but manifests as uncontrolled destructive episodes rather than usable magic; the control structure required to direct it never developed.

## Versus Wizard and Magician

| | Wizard | Sorcerer | Magician |
|---|---|---|---|
| Source of power | Academic (specialist) | Bloodline (innate) | Academic (generalist) |
| Preparation overhead | High — memorize before every pull | None | None |
| Mana floor | Crashes hard when memorized set is spent | Low floor (Mana Feed fallback) | Low floor (broad pool) |
| Burst ceiling | Highest (Meteor 130) | Medium (Soul Surge 80) | Medium (Lightning Strike 80) |
| Sustained output | Volatile | Best | Good |
| Instants available | None | 2 | 2 |
| AoE | None (design targets only) | Arcane Nova (design target) | None (design targets) |

## Playstyle
Engage immediately — no preparation, no delay. Rotate Arcane Burst and Bloodfire on cooldown for baseline pressure; escalate to Void Lance and Tempest Bolt as the fight extends; commit Soul Surge to high-value targets or as a finisher. Resonance rewards staying on one target rather than bouncing between enemies.

When mana is genuinely critical, Mana Feed converts HP to mana — this is the difference between the Sorcerer and every other arcane class. A Wizard at empty memorized slots is finished. A Sorcerer at low mana has a choice.

The Sorcerer's strength is visible over a long session: multiple pulls, no rest stops, consistent output across all of them. In content that moves fast and rewards not sitting, the Sorcerer outperforms the Wizard in practice even when the Wizard's ceiling is theoretically higher.

## Spell Unlock Schedule

Spells are not learned from books — they surface as the bloodline matures. Sorcerers visit guild mystics who identify and unlock latent abilities at each threshold. All spells are always available once unlocked; none require memorization.

### Level 1

| Spell | Description | School | Mana |
|---|---|---|---|
| Arcane Burst | Arcane damage (30); instant | Arcane | 18 |
| Bloodfire | Fire damage (40); instant | Arcane | 22 |
| Arcane Flare | Arcane damage (22); instant | Arcane | 12 |
| Shadow Touch | Shadow damage (18) + DoT 5/s for 8s; instant | Shadow | 15 |

### Level 4

| Spell | Description | School | Mana |
|---|---|---|---|
| Void Lance | Arcane damage (55); 1.0s cast | Arcane | 28 |
| Arcane Pulse | Arcane damage (38); instant | Arcane | 22 |
| Sanguine Flame | Fire damage (52); instant | Arcane | 28 |

### Level 8

| Spell | Description | School | Mana |
|---|---|---|---|
| Tempest Bolt | Lightning damage (65); 1.5s cast | Arcane | 35 |
| Void Strike | Arcane damage (70); 1.0s cast | Arcane | 38 |
| Arcane Burst II | Arcane damage (42); instant | Arcane | 24 |
| Void Anchor | Reduce target movement speed by 50% for 8s; instant | Arcane | 22 |
| Bloodfire II | Fire damage (55); instant | Arcane | 30 |

### Level 12

| Spell | Description | School | Mana |
|---|---|---|---|
| Soul Surge | Arcane damage (80); 2.0s cast | Arcane | 45 |
| Tempest Surge | Lightning damage (80); 1.5s cast | Arcane | 42 |
| Void Lance II | Arcane damage (72); 1.0s cast | Arcane | 38 |
| Mana Feed | Convert 50 HP into 40 mana; instant | Arcane | 0 |
| Arcane Torrent | Arcane damage (50); instant | Arcane | 30 |

### Level 16

| Spell | Description | School | Mana |
|---|---|---|---|
| Bloodsurge | Arcane damage (90); costs 30 HP + 20 mana instead of full mana cost | Shadow | 20 |
| Soul Surge II | Arcane damage (100); 2.0s cast | Arcane | 58 |
| Arcane Nova | AoE arcane damage (55) around caster; 6m radius; instant | Arcane | 40 |
| Crimson Wave | Fire damage (68); instant | Arcane | 38 |
| Tempest Bolt II | Lightning damage (85); 1.5s cast | Arcane | 48 |

### Level 20

| Spell | Description | School | Mana |
|---|---|---|---|
| Void Bolt | Arcane damage (88); 1.0s cast | Arcane | 50 |
| Soul Surge III | Arcane damage (120); 2.0s cast | Arcane | 72 |
| Arcane Burst III | Arcane damage (58); instant | Arcane | 33 |
| Sanguine Fury | Fire damage (82); instant | Arcane | 46 |
| Arcane Nova II | AoE arcane damage (72) in 6m; instant | Arcane | 52 |

### Level 24

| Spell | Description | School | Mana |
|---|---|---|---|
| Soul Shatter | Arcane damage (135); 2.0s cast | Arcane | 85 |
| Void Lance III | Arcane damage (95); 1.0s cast | Arcane | 60 |
| Bloodsurge II | Arcane damage (118); costs 40 HP + 22 mana | Shadow | 22 |
| Arcane Lance | Arcane damage (68); instant | Arcane | 42 |
| Mana Feed II | Convert 80 HP into 70 mana; instant | Arcane | 0 |
| Resonance | Passive: each spell hit on same target builds a stack; at 5 stacks next spell auto-crits | Arcane | — |

### Level 29

| Spell | Description | School | Mana |
|---|---|---|---|
| Tempest Barrage | Lightning damage (105); 1.5s cast | Arcane | 65 |
| Soul Surge IV | Arcane damage (155); 2.0s cast | Arcane | 95 |
| Void Surge | Arcane damage (112); 1.0s cast | Arcane | 72 |
| Arcane Eruption | AoE arcane damage (88) in 8m; instant | Arcane | 68 |
| Blood Blaze | Fire damage (102); instant | Arcane | 58 |
| Void Anchor II | Reduce target movement by 65% for 10s; instant | Arcane | 30 |

### Level 34

| Spell | Description | School | Mana |
|---|---|---|---|
| Soul Collapse | Arcane damage (175); 2.0s cast | Arcane | 112 |
| Void Barrage | Arcane damage (125); 1.0s cast | Arcane | 85 |
| Sanguine Fury II | Fire damage (120); instant | Arcane | 72 |
| Arcane Blast | Arcane damage (85); instant | Arcane | 55 |
| Bloodsurge III | Arcane damage (145); costs 48 HP + 25 mana | Shadow | 25 |

### Level 39

| Spell | Description | School | Mana |
|---|---|---|---|
| Soul Rupture | Arcane damage (198); 2.0s cast | Arcane | 130 |
| Tempest Bolt III | Lightning damage (128); 1.5s cast | Arcane | 82 |
| Arcane Nova III | AoE arcane damage (105) in 10m; instant | Arcane | 88 |
| Void Lance IV | Arcane damage (142); 1.0s cast | Arcane | 100 |
| Mana Feed III | Convert 120 HP into 110 mana; instant | Arcane | 0 |

### Level 44

| Spell | Description | School | Mana |
|---|---|---|---|
| Soul Surge V | Arcane damage (222); 2.0s cast | Arcane | 155 |
| Blood Conflagration | Fire damage (148); instant | Arcane | 92 |
| Void Storm | Arcane damage (155); 1.0s cast | Arcane | 112 |
| Arcane Burst IV | Arcane damage (105); instant | Arcane | 68 |
| Ancient Arcane Nova | AoE arcane damage (130) in 12m; instant | Arcane | 115 |

### Level 49

| Spell | Description | School | Mana |
|---|---|---|---|
| Ancient Soul Surge | Arcane damage (262); 2.0s cast | Arcane | 182 |
| Ancient Void Lance | Arcane damage (182); 1.0s cast | Arcane | 135 |
| Ancient Bloodfire | Fire damage (185); instant | Arcane | 118 |
| Ancient Tempest | Lightning damage (158); 1.5s cast | Arcane | 102 |
| Bloodsurge (Ancient) | Arcane damage (210); costs 60 HP + 28 mana | Shadow | 28 |

### Level 50

| Spell | Description | School | Mana |
|---|---|---|---|
| Blood Apotheosis | 30s: all spells cost HP instead of mana (60 HP per cast); unlimited casting | Shadow | 180 |
| Void Collapse | AoE arcane damage (320) in 20m radius; instant | Arcane | 280 |

## Portrait Reference
*See [characters.md](../characters.md) — Troll Sorcerer: "The Burning Ground"*
