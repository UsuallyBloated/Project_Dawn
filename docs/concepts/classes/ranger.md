# Ranger
*Archer / Scout / Nature Hybrid — Any Alignment — Skill + Nature*

## Overview
The wilderness made practical. The Ranger is the game's premier ranged fighter, the only class with a developed tracking system, and the closest thing to a solo-viable archer the game has. They are not a caster with a bow — they are a hunter who learned some nature magic as a tool. Their spells are specifically useful (snare, root, healing, camouflage) but they do not define the class. The bow defines the class.

The strategic model: stay at range, control the fight's geography, dictate the distance. An enemy that cannot reach the Ranger cannot hit them. The bow enables this; snare and root enforce it; True Shot and Aimed Shot punish any enemy that holds still long enough. When the distance collapses despite everything, the Ranger shifts to dual-wield melee — a real fallback, not a death sentence, but not the plan.

The Ranger is one of the most self-sufficient solo classes in the game. They have tools to escape, tools to slow, tools to heal, and the detection range to see threats before those threats see them.

## Combat Profile
- **Armor:** Leather/chain
- **Weapons:** Bows (primary), dual swords/axes (melee fallback), quivers
- **Primary Resource:** Both mana and stamina
- **Pet:** None

## Bow Mechanics
*Design target — partially implemented.*

The bow operates on a range check. Bow skills and bow auto-attack require the Ranger to be outside melee range. At optimal range (medium distance), attacks deal full damage. At extreme range (near maximum), damage drops slightly — the bow has a ceiling on effective range, not a minimum. At melee range, bow attacks are disabled; the Ranger switches to equipped melee weapons automatically.

Quivers hold arrows. Arrows are a consumable resource. Different arrow types exist for different situations (standard, broadhead for bleed, silver-tipped for magical targets). Running out of arrows during a fight forces melee fallback regardless of positioning.

## Spells

| Spell | Type | Damage/Heal | Mana | Cast | Cooldown |
|---|---|---|---|---|---|
| Hunter's Mark | Nature dmg | 25 | 15 | Instant | 6s |
| Nature's Cure | Self-heal | +35 HP | 20 | 0.5s | 8s |
| Ensnaring Roots | Root | — | 25 | Instant | 18s |
| Camouflage | Stealth | — | 20 | 1.0s | 30s |
| Hunter's Eye | Self-buff | +15% accuracy, +10% crit chance, 30s | 22 | Instant | 45s |
| Snare | Slow | Enemy movement –60% for 15s | 18 | Instant | 12s |

**Ensnaring Roots** — Enemy cannot move but can still attack and cast. The Ranger's primary range-enforcement tool. A rooted caster is not stopped; a rooted melee fighter is helpless.

**Camouflage** — Nature stealth. The Ranger becomes difficult for enemies to detect. Moving at walk speed maintains the effect; running breaks it. Used for repositioning, approach, or disengaging after a bad pull.

**Snare** — Movement reduction rather than a full root. The enemy is slowed but can still chase. Used to maintain distance rather than hard-lock an enemy in place. More mana-efficient than roots; less absolute.

**Hunter's Eye** — The Ranger's self-buff. Accuracy and critical hit bonus for 30 seconds. Cast before opening fire; refreshed when it drops.

## Skills

| Skill | Dmg Multiplier | Stamina | Cooldown | Notes |
|---|---|---|---|---|
| True Shot | 2.0x | 20 | 8s | Requires bow equipped; full-power ranged burst |
| Aimed Shot | 3.0x | 35 | 20s | Requires bow; 1.5s startup; telegraphed; the highest single-hit ranged damage in the game |
| Rapid Shot | 0.7x × 3 | 25 | 12s | Three quick arrows in succession; total 2.1x damage if all hit; less accurate |
| Double Strike | 1.1x | 8 | 2.5s | Melee fallback; available when bow skills are locked out at melee range |
| Dual Flurry | 1.3x per weapon | 18 | 10s | Dual-wield only; both weapons attack simultaneously; requires two melee weapons equipped |

**Aimed Shot** — The highest-damage single ranged attack in the game, period. Requires staying still for 1.5 seconds of startup before the shot fires. Any movement during windup cancels it. The risk is standing still; the reward is substantial.

**Rapid Shot** — Three arrows in fast succession, each at reduced accuracy. The burst window for DPS; more reliable against large slow targets, unreliable against small fast ones.

## Tracking
*Design target — not yet implemented.*

Tracking is a Ranger-exclusive ability. Activating it opens a detection window listing all living enemies and players within the zone, sorted by distance. Each entry shows the target name, distance, and bearing. Passive tracking (a shorter-range background scan) alerts the Ranger when something approaches that they haven't seen yet.

The Ranger knows the terrain. This is the mechanical expression of that.

## Race Availability
**Available:** Human, Elf, Wood Elf, Halfling, Dwarf, Half-Elf, Minotaur, Fae, Felhari

**Blocked:** Dark Elf (no tradition of open-field hunting); Ogre, Troll, Half-Ogre (too large and loud for ranged precision and stalking); Kel`varath (close-combat martial tradition, bow is not the weapon); Gnome (insufficient physical build for effective draw weight and field endurance); Kobold (pack-hunting style is incompatible with the Ranger's solo-tracking discipline).

## Playstyle
Before engaging: cast Hunter's Eye. Open at range with Hunter's Mark to apply the debuff. Follow with True Shot for immediate burst. Maintain distance with Snare or Ensnaring Roots as the enemy approaches. Use Aimed Shot when the enemy is rooted and standing still — it is too slow to land against a moving target at range.

Rapid Shot fills gaps between longer cooldowns. Nature's Cure handles self-healing between abilities. Camouflage is the escape tool when everything goes wrong — move to break line of sight, activate Camouflage, walk away.

When melee range happens anyway: Double Strike and Dual Flurry are real tools, not embarrassments. The Ranger fights with two weapons at close range. It is a weaker state than optimal range, but the class can handle it.

The Ranger's skill ceiling is in distance management. Anyone can press True Shot. Fewer players can maintain 20+ meters of separation against aggressive melee enemies for an entire pull while keeping roots on cooldown, Aimed Shot landing on rooted targets, and Camouflage available as an emergency exit.

## Spell Unlock Schedule

Spells are learned from wilderness scouts, Ranger guilds, or nature-aligned trainers. All spells reflect field utility — the Ranger does not study magic; they learned what works.

### Level 1

| Spell | Description | School | Mana |
|---|---|---|---|
| Hunter's Mark | Single target nature damage (25); instant | Nature | 15 |
| Nature's Cure | Self-heal: restore 35 HP; 0.5s cast | Restoration | 20 |
| Sense Animals | Detect all animals within 60m for 30s | Divination | 8 |
| True North | Navigation; reveal direction and nearest landmarks | Divination | 5 |
| Forage | Locate edible plants and water within the area | Divination | 5 |

### Level 4

| Spell | Description | School | Mana |
|---|---|---|---|
| Snare | Reduce target movement speed by 60% for 15s; instant | Nature | 18 |
| Hunter's Mark II | Single target nature damage (38); instant | Nature | 22 |
| Nature's Cure II | Self-heal: restore 55 HP; 0.5s cast | Restoration | 28 |
| Camouflage (Minor) | Self: reduce enemy aggro range by 40% for 60s | Alteration | 15 |

### Level 8

| Spell | Description | School | Mana |
|---|---|---|---|
| Ensnaring Roots | Root target; cannot move but can attack and cast; 18s duration | Nature | 25 |
| Hunter's Eye | Self: +15% accuracy, +10% crit chance for 30s; instant | Nature | 22 |
| Hunter's Mark III | Single target nature damage (55); instant | Nature | 30 |
| Nature's Cure III | Self-heal: restore 78 HP; 0.5s cast | Restoration | 38 |

### Level 12

| Spell | Description | School | Mana |
|---|---|---|---|
| Snare II | Reduce target movement by 70% for 18s; instant | Nature | 25 |
| Hunter's Eye II | Self: +22% accuracy, +15% crit chance for 30s; instant | Nature | 30 |
| Camouflage | Self: full stealth vs animals; partial vs sentient foes for 90s | Alteration | 22 |
| Hunter's Mark IV | Single target nature damage (72); instant | Nature | 38 |
| Nature's Mending | Self HoT: +12 HP/s for 18s | Restoration | 28 |

### Level 16

| Spell | Description | School | Mana |
|---|---|---|---|
| Ensnaring Roots II | Root target for 28s | Nature | 35 |
| Hunter's Eye III | Self: +28% accuracy, +20% crit chance for 30s; instant | Nature | 38 |
| Nature's Cure IV | Self-heal: restore 105 HP; 0.5s cast | Restoration | 50 |
| Wolf Pack | Group: +10% movement speed for 60s | Nature | 30 |

### Level 20

| Spell | Description | School | Mana |
|---|---|---|---|
| Hunter's Mark V | Single target nature damage (90); instant | Nature | 48 |
| Snare III | Reduce target movement by 75% for 22s; instant | Nature | 32 |
| Hunter's Eye IV | Self: +35% accuracy, +25% crit chance, +10% damage for 30s | Nature | 48 |
| Nature's Rejuvenation | Self HoT: +22 HP/s for 18s | Restoration | 42 |

### Level 24

| Spell | Description | School | Mana |
|---|---|---|---|
| Ensnaring Roots III | Root target for 38s | Nature | 45 |
| Hunter's Eye V | Self: +40% accuracy, +30% crit chance, +15% damage for 30s | Nature | 58 |
| Hunter's Mark VI | Single target nature damage (110); instant | Nature | 58 |
| Camouflage II | Self: full stealth vs all enemies; walk-speed maintained for 120s | Alteration | 30 |

### Level 29

| Spell | Description | School | Mana |
|---|---|---|---|
| Snare IV | Reduce target movement by 80% for 25s; instant | Nature | 40 |
| Hunter's Eye VI | Self: +45% accuracy, +35% crit, +20% damage for 45s | Nature | 68 |
| Nature's Cure V | Self-heal: restore 145 HP; 0.5s cast | Restoration | 68 |
| Hunter's Mark VII | Single target nature damage (132); instant | Nature | 70 |

### Level 34

| Spell | Description | School | Mana |
|---|---|---|---|
| Ensnaring Roots IV | Root target for 50s | Nature | 58 |
| Hunter's Mark VIII | Single target nature damage (155); instant | Nature | 82 |
| Nature's Rejuvenation II | Self HoT: +38 HP/s for 18s | Restoration | 65 |
| Hunter's Eye VII | Self: +50% accuracy, +40% crit, +25% damage for 45s | Nature | 80 |
| Pierce the Veil | Self: see through all stealth and camouflage for 60s | Divination | 25 |

### Level 39

| Spell | Description | School | Mana |
|---|---|---|---|
| Snare V | Reduce target movement by 85% for 30s; instant | Nature | 50 |
| Hunter's Eye VIII | Self: +55% accuracy, +45% crit, +30% damage for 45s | Nature | 95 |
| Nature's Cure VI | Self-heal: restore 195 HP; 0.5s cast | Restoration | 88 |
| Hunter's Mark IX | Single target nature damage (182); instant | Nature | 98 |

### Level 44

| Spell | Description | School | Mana |
|---|---|---|---|
| Ensnaring Roots V | Root target for 65s | Nature | 72 |
| Hunter's Eye IX | Self: +60% accuracy, +50% crit, +35% damage for 60s | Nature | 112 |
| Hunter's Mark X | Single target nature damage (212); instant | Nature | 115 |
| Nature's Rejuvenation III | Self HoT: +58 HP/s for 18s | Restoration | 90 |

### Level 49

| Spell | Description | School | Mana |
|---|---|---|---|
| Snare (Ancient) | Reduce target movement by 90% for 35s; instant | Nature | 62 |
| Hunter's Eye X (Ancient) | Self: +70% accuracy, +60% crit, +45% damage for 60s | Nature | 132 |
| Nature's Grace | Self-heal: restore 290 HP; instant | Restoration | 120 |
| Ancient Hunter's Mark | Single target nature damage (248); instant | Nature | 135 |

### Level 50

| Spell | Description | School | Mana |
|---|---|---|---|
| Ancient Ensnaring Roots | Root target for 90s; immune to breakout damage | Nature | 90 |
| Nature's Bond | 30s: immune to nature damage; +100% movement; +50% crit chance | Nature | 180 |

## Portrait Reference
*See [characters.md](../characters.md) — Wood Elf Ranger: "The Patient Distance"*
