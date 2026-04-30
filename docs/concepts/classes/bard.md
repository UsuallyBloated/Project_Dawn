# Bard
*Support / Hybrid DPS — Any Alignment — Music Magic*

## Overview
The most social class, and the highest skill ceiling in the game by a wide margin.

The Bard's power comes from songs — not spells. Songs are not one-time casts; they are ongoing performances that pulse every 3 seconds. As long as the Bard is performing a song, each pulse delivers its effect to nearby allies or enemies. One song active is simple. The Twist is where the Bard becomes something else entirely.

The Twist is the technique of cycling multiple songs simultaneously. Because each song has its own independent 3-second pulse timer, a skilled Bard who activates Song A, waits 1 second, activates Song B, waits 1 second, activates Song C, then cycles back to refresh A before it expires can keep three or four songs pulsing simultaneously with consistent uptime. This requires exact timing, constant attention, and the ability to manage the rhythm while also positioning, avoiding AoE, and making combat decisions. A one-song Bard is useful. A three-song Twist Bard with optimal timing is one of the most valuable assets in any group in the game.

The direct damage spells exist for moments when the Bard needs to contribute output rather than support. They are not the class. The songs are the class.

## Combat Profile
- **Armor:** Chain/leather
- **Weapons:** Instruments (functional tool — the type of instrument affects which songs can be performed; not purely cosmetic), one-handed swords, daggers
- **Primary Resource:** Both mana and stamina; songs drain mana per pulse
- **Pet:** Temporary — Siren's Song charm (30s; an enemy converted to a combat ally)

## The Song System
*Design target — partially implemented.*

Songs differ from spells in fundamental ways:
- **Pulse-based:** Instead of a one-time effect, songs deliver a pulse of their effect every 3 seconds to all eligible targets in range.
- **Maintenance:** A song continues only while the Bard actively performs it. Switching to a different song, taking a heavy hit, or running out of mana ends the current song.
- **Area effect:** All songs affect everyone in range (buff songs apply to allies; debuff songs apply to enemies). The Bard does not target individual characters with songs.
- **Stacking:** The same song cannot be stacked (performing it twice does not double the effect). Different songs stack freely.

**The Twist** — The Bard's highest-skill mechanic. Each song has its own 3-second timer. A Bard cycling three songs with 1-second offsets between them keeps all three active simultaneously. Perfect execution requires: knowing each song's pulse timer, recognizing when each is about to expire, reactivating without letting it fully drop, and doing all of this while managing combat positioning and mana. At high skill levels, a Twist Bard running four songs is providing more support value than a dedicated buffer or debuffer.

## Songs — Current Implementation
| Song | Type | Effect per Pulse | Mana/Pulse | Notes |
|---|---|---|---|---|
| Dissonance | Arcane dmg | 20 dmg to nearby enemies | 5 | AoE — hits all enemies in range |
| Chorus of Misery | Arcane dmg | 45 dmg to nearby enemies | 10 | Higher damage; shorter range |
| Battle Hymn | Healing | +30 HP to nearby allies | 8 | Heals the Bard and nearby party members |
| Siren's Song | Charm | 30s enemy charm on target | 30 | One-time cast; not a song pulse; special case |

## Songs — Design Targets
| Song | Type | Effect per Pulse | Notes |
|---|---|---|---|
| **Anthem of the Hunt** | Haste buff | Allies gain +20% attack speed | The attack speed buff; one of the most wanted group buffs in the game |
| **Poet's Mending** | HoT buff | Allies regenerate 15 HP per pulse | Sustained healing across the party; weaker than a dedicated healer's burst but free while Twisting |
| **Wanderer's Chord** | Speed buff | Allies gain +25% movement speed | Out-of-combat travel song; massive quality of life |
| **Mana Weave** | Mana regen buff | Caster allies regenerate 10 mana per pulse | Extremely valuable in groups with multiple casters; extends every caster's effective endurance |
| **Aria of Dismay** | Debuff | Enemies lose 15% attack speed per pulse | Applied to all enemies in range; the slow song; pairs with tanks absorbing fewer attacks |
| **Selos' Melody** | Speed buff (AoE) | All nearby characters gain +35% movement speed | Signature; the fastest travel song; entire group benefits; used in dangerous terrain and zone traversal |

## Skills

| Skill | Dmg Multiplier | Stamina | Cooldown | Notes |
|---|---|---|---|---|
| Swindler's Strike | 1.2x | 10 | 4s | Melee; available when combat closes to melee range |
| Disarming Flourish | — | 15 | 20s | Disarms the target for 6s; target cannot use weapon-based skills |
| Discordant Strike | 1.4x | 18 | 12s | Melee; also reduces the target's resistance to sound-based damage for 10s |

## Race Availability
**Available:** Human, Elf, Dark Elf, Wood Elf, Gnome, Halfling, Dwarf, Half-Elf, Minotaur, Fae, Felhari, Kobold

**Blocked:** Ogre, Troll (voice and fine motor control incompatible with the performance demands — the songs require physical precision that neither race's physiology supports well); Kel`varath (no musical tradition; the oral culture exists but not in a form compatible with the Bard's combat performance discipline); Half-Ogre (insufficient fine motor control for instrument performance under combat conditions).

## Signature Spell — Selos' Melody
The movement speed song has a name because it is famous. Selos' Melody is one of the most requested abilities in the game — the entire group moves 35% faster while the Bard performs it. In dangerous zones, during retreats, on long traversals: groups form around Bards partly for this song specifically. A Bard running Selos' as one of their Twist songs effectively gives the entire group a persistent travel buff at no dedicated cost.

## Playstyle
**Solo:** Siren's Song turns a 1v1 into a 2v1 — charm an enemy, let it fight for you, contribute Dissonance and Chorus of Misery from range. Heal with Battle Hymn as needed. Swindler's Strike if melee closes. The charm requires management: reapplied before 30 seconds expires, not pulled prematurely, positioned so the charmed enemy fights the intended target.

**Group:** The Bard's primary value multiplies in group content. Decide which Twist songs the group needs before pulling. A standard pull rotation: Anthem of the Hunt for the melees, Mana Weave for the casters, Aria of Dismay on the enemies. At high Twist proficiency, all three run simultaneously with consistent pulse uptime. The Bard is not standing still doing this — they are managing cooldowns, maintaining position, and keeping the charm alive if applicable.

The Bard's skill floor is medium (one song is still useful). The skill ceiling is the highest in the game: a Bard Twisting four songs with near-perfect timing, maintaining charm, contributing direct damage in gaps, and adjusting the song set mid-fight based on what the group needs is performing a task no other class in the game demands at that complexity level.

## Song Unlock Schedule

Songs are learned from Bard guilds, traveling performers, and instrument vendors. Unlike spells, songs are not memorized — every learned song is always available. Songs pulse their effect every 3 seconds while performed and cost mana per pulse. The Twist (cycling multiple songs simultaneously) requires manually reactivating each before its timer expires.

### Level 1

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Dissonance | AoE arcane damage (20) to all enemies in 10m | Arcane | 5 |
| Ballad of the Heart | Group: restore 12 HP per pulse | Restoration | 6 |
| War March | Group: +10 melee damage for duration | Alteration | 5 |
| Lullaby | Pacify one non-hostile creature; reduce aggro range | Alteration | 4 |

### Level 4

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Chorus of Misery | AoE arcane damage (45) to all enemies in 8m | Arcane | 10 |
| Minstrel's Fortune | Group: +12% dodge chance for duration | Alteration | 5 |
| Wanderer's Refrain | Group: +12% movement speed for duration | Alteration | 4 |

### Level 8

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Battle Hymn | Group: restore 30 HP per pulse | Restoration | 8 |
| Siren's Song | One-time cast on target: charm for 30s (recast to maintain) | Alteration | 30 |
| Dissonance II | AoE arcane damage (35) to all enemies in 10m | Arcane | 8 |
| Wanderer's Chord | Group: +20% movement speed for duration | Alteration | 6 |

### Level 12

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Aria of Alacrity | Group: +20% attack speed for duration | Alteration | 8 |
| Chorus of Misery II | AoE arcane damage (65) to all enemies in 8m | Arcane | 13 |
| Aria of Dismay | AoE: −15% enemy attack speed for duration | Alteration | 7 |
| Battle Hymn II | Group: restore 48 HP per pulse | Restoration | 11 |

### Level 16

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Mana Weave | Group casters: restore 10 mana per pulse | Restoration | 6 |
| Anthem of the Hunt | Group: +20% attack speed, +15 melee damage for duration | Alteration | 9 |
| Wanderer's Chord II | Group: +30% movement speed for duration | Alteration | 8 |
| Dissonance III | AoE arcane damage (52) in 10m | Arcane | 10 |

### Level 20

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Siren's Song II | One-time cast: charm target for 45s | Alteration | 35 |
| Aria of Dismay II | AoE: −25% enemy attack speed for duration | Alteration | 9 |
| Chorus of Misery III | AoE arcane damage (88) in 8m | Arcane | 16 |
| Battle Hymn III | Group: restore 68 HP per pulse | Restoration | 14 |
| Anthem of the Hunt II | Group: +30% attack speed, +25 melee damage for duration | Alteration | 12 |

### Level 24

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Mana Weave II | Group casters: restore 18 mana per pulse | Restoration | 9 |
| Wanderer's Chord III | Group: +40% movement speed for duration | Alteration | 10 |
| Aria of Alacrity II | Group: +35% attack speed for duration | Alteration | 11 |
| Dissonance IV | AoE arcane damage (72) in 10m | Arcane | 13 |
| Poet's Mending | Group HoT: +10 HP/s for duration (persists 6s after song ends) | Restoration | 10 |

### Level 29

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Selos' Melody | Group: +35% movement speed; affects all nearby characters; signature | Alteration | 12 |
| Chorus of Misery IV | AoE arcane damage (112) in 8m | Arcane | 20 |
| Aria of Dismay III | AoE: −35% enemy attack speed for duration | Alteration | 12 |
| Battle Hymn IV | Group: restore 92 HP per pulse | Restoration | 18 |

### Level 34

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Mana Weave III | Group casters: restore 28 mana per pulse | Restoration | 12 |
| Anthem of the Hunt III | Group: +45% attack speed, +40 melee damage for duration | Alteration | 15 |
| Wanderer's Chord IV | Group: +50% movement speed for duration | Alteration | 13 |
| Selos' Melody II | Group: +45% movement speed; no range limit on group members | Alteration | 16 |
| Dissonance V | AoE arcane damage (98) in 12m | Arcane | 16 |

### Level 39

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Aria of Arcana | Group casters: +20% spell damage, +15 mana per pulse for duration | Arcane | 14 |
| Battle Hymn V | Group: restore 125 HP per pulse | Restoration | 22 |
| Chorus of Misery V | AoE arcane damage (142) in 8m | Arcane | 25 |
| Aria of Dismay IV | AoE: −45% enemy attack speed for duration | Alteration | 15 |
| Anthem of the Hunt IV | Group: +55% attack speed, +55 melee damage for duration | Alteration | 18 |

### Level 44

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Mana Weave IV | Group casters: restore 40 mana per pulse | Restoration | 16 |
| Selos' Melody III | Group: +55% movement speed; no decrement from terrain | Alteration | 20 |
| Ancient Dissonance | AoE arcane damage (175) in 12m | Arcane | 28 |
| Battle Hymn VI | Group: restore 165 HP per pulse | Restoration | 28 |
| Siren's Song III | One-time cast: charm target for 60s | Alteration | 45 |

### Level 49

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Ancient Chorus of Misery | AoE arcane damage (215) in 10m | Arcane | 35 |
| Anthem of the Hunt V | Group: +70% attack speed, +75 melee damage for duration | Alteration | 24 |
| Aria of Dissolution | AoE: enemies lose 3 random buffs per pulse | Abjuration | 22 |
| Ancient Selos' Melody | Group: +65% movement speed; extends 5s after song ends | Alteration | 26 |

### Level 50

| Song | Effect per Pulse | School | Mana/Pulse |
|---|---|---|---|
| Rhapsody of the Ages | Group: +50% all damage, +100 HP regen, +40 mana regen; hardest song to maintain | Arcane | 40 |
| Ancient Anthem of the Hunt | Group: +85% attack speed, +100 melee damage; double pulse rate | Alteration | 35 |

## Portrait Reference
*See [characters.md](../characters.md) — Kobold Bard: "The Unexpected Note"*
