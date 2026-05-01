# Necromancer
*Undead Master — Evil preferred — Death magic*

## Overview
The dead are tools. The Necromancer commands undead allies — a permanent skeleton at the current stage of implementation — while dealing sustained shadow damage and draining life. They are not simply dark mages; they are administrators of death, treating corpses and spirits as raw materials for ongoing utility. Their DoT (Dark Decay) and summoned skeleton make them exceptionally strong in solo attrition without requiring a healer.

## Combat Profile
- **Armor:** Cloth
- **Weapons:** Staves, dark ritual weapons
- **Primary Resource:** Mana
- **Pet:** Permanent — Summon Skeleton (currently implemented); additional undead types are a design target

## Spells

| Spell | Type | Damage/Effect | Mana | Cast |
|---|---|---|---|---|
| Bone Shards | Shadow dmg | 30 | 18 | Instant |
| Soul Drain | Shadow dmg + heal | 40 dmg / +15 HP | 28 | 0.5s |
| Dark Decay | Shadow DoT | 20 + 7/s for 24s | 40 | 2.0s |
| Enervation | Shadow dmg | 85 | 50 | 3.0s |
| Summon Skeleton | Pet summon | — | 60 | 3.0s |

## Skills
None — pure spellcaster.

## Race Availability
**Available:** Human, Dark Elf, Gnome, Ogre, Troll, Kel`varath, Kobold

**Blocked:** Elf, Halfling, Dwarf — the prohibition is cultural bedrock, not enforceable law; a member of these races could theoretically practice necromancy but community exclusion makes it functionally impossible. Also blocked: Wood Elf, Half-Elf, Minotaur, Fae, Felhari, Half-Ogre.

## Playstyle
Summon Skeleton at the start of every encounter — it absorbs damage and provides automatic DPS throughout. Bone Shards for fast instant-cast damage; Soul Drain for life-steal sustain; Dark Decay applied early for maximum 24-second payoff; Enervation as the 3.0s heavy finisher when the target is nearly dead. The skeleton handles attrition while spells handle burst. Most good-aligned cities do not welcome Necromancers openly — access to vendors, trainers, and NPCs may be restricted.

## Spell Unlock Schedule

Spells are purchased from Necromancer guild vendors in cities that tolerate the practice, recovered from tombs, or extracted from captured texts. Good-aligned cities will not sell these. The vendor's willingness to do business is a useful indicator of how welcome the Necromancer is in that zone.

### Level 1

| Spell | Description | School | Mana |
|---|---|---|---|
| Bone Shards | Shadow damage (30); instant | Shadow | 18 |
| Soul Drain | Shadow damage (40) + restore 15 HP; 0.5s cast | Shadow | 28 |
| Dark Decay | Target DoT: 20 initial + 7/s for 24s; 2.0s cast | Shadow | 40 |
| Shadow Spite | Shadow damage (18); instant | Shadow | 12 |
| Invoke Fear | Target flees randomly for 8s | Shadow | 22 |
| Gather Shadows | Self: minor stealth; enemies have reduced aggro range 30s | Shadow | 15 |

### Level 4

| Spell | Description | School | Mana |
|---|---|---|---|
| Enervation | Shadow damage (85); 3.0s cast | Shadow | 50 |
| Splinter of Bone | Shadow damage (45); instant | Shadow | 25 |
| Dark Torment | Target DoT: 25 initial + 10/s for 24s; 2.0s cast | Shadow | 50 |
| Soul Leech | Shadow damage (55) + restore 25 HP; 0.5s cast | Shadow | 38 |
| Summon Skeleton | Summon a skeleton companion; permanent; recalled if killed | Conjuration | 60 |
| Darkness | Blind target for 5s; −30% accuracy | Shadow | 22 |

### Level 8

| Spell | Description | School | Mana |
|---|---|---|---|
| Bone Cascade | Shadow damage (62); instant | Shadow | 38 |
| Plague Bolt | Shadow damage (110); 3.0s cast | Shadow | 65 |
| Soul Rend | Shadow damage (70) + restore 35 HP; 0.5s cast | Shadow | 48 |
| Rotting Touch | Target DoT: 35 initial + 14/s for 24s; 2.0s cast | Shadow | 62 |
| Death Pact | Next death: survive at 1 HP instead; 5-minute cooldown | Shadow | 40 |
| Invoke Terror | Target flees for 15s | Shadow | 32 |

### Level 12

| Spell | Description | School | Mana |
|---|---|---|---|
| Shattered Bones | Shadow damage (80); instant | Shadow | 48 |
| Dark Bolt | Shadow damage (135); 3.0s cast | Shadow | 80 |
| Soul Devour | Shadow damage (88) + restore 48 HP; 0.5s cast | Shadow | 60 |
| Plague | Target DoT: 45 initial + 18/s for 24s; 2.0s cast | Shadow | 75 |
| Summon Skeleton Warrior | Stronger skeleton companion; permanent | Conjuration | 75 |
| Shadow Veil | Self: absorb 100 incoming damage | Abjuration | 35 |

### Level 16

| Spell | Description | School | Mana |
|---|---|---|---|
| Skeletal Shards | Shadow damage (100); instant | Shadow | 60 |
| Gangrenous Touch | Target DoT: 55 initial + 24/s for 24s; 2.0s cast | Shadow | 90 |
| Dark Strike | Shadow damage (162); 3.0s cast | Shadow | 96 |
| Siphon of Vitality | Shadow damage (108) + restore 62 HP; 0.5s cast | Shadow | 78 |
| Summon Bone Knight | Armored skeleton fighter; permanent | Conjuration | 80 |
| Grave Cold | AoE shadow damage (60) in 10m radius | Shadow | 55 |

### Level 20

| Spell | Description | School | Mana |
|---|---|---|---|
| Bone Shard Cascade | Shadow damage (120); instant | Shadow | 72 |
| Enervation II | Shadow damage (190); 3.0s cast | Shadow | 115 |
| Soul Collapse | Shadow damage (130) + restore 78 HP; 0.5s cast | Shadow | 95 |
| Decomposition | Target DoT: 70 initial + 32/s for 24s; 2.0s cast | Shadow | 108 |
| Summon Zombie | Zombie companion; regenerates if out of combat; permanent | Conjuration | 80 |
| Grasp of the Vampyre | AoE lifetap: 50 shadow damage + 25 HP restore in 10m | Shadow | 65 |

### Level 24

| Spell | Description | School | Mana |
|---|---|---|---|
| Ossified Doom | Shadow damage (142); instant | Shadow | 86 |
| Dark Lance | Shadow damage (225); 3.0s cast | Shadow | 138 |
| Siphon of Vitality II | Shadow damage (158) + restore 98 HP; 0.5s cast | Shadow | 115 |
| Ancient Blight | Target DoT: 88 initial + 42/s for 24s; 2.0s cast | Shadow | 130 |
| Summon Skeletal Mage | Caster skeleton companion; permanent | Conjuration | 90 |
| Doom | Target: −50 shadow resist, −30 AC for 60s | Shadow | 48 |

### Level 29

| Spell | Description | School | Mana |
|---|---|---|---|
| Bone Storm | Shadow damage (165); instant | Shadow | 100 |
| Plague Lance | Shadow damage (260); 3.0s cast | Shadow | 160 |
| Soul Rend II | Shadow damage (188) + restore 118 HP; 0.5s cast | Shadow | 138 |
| Rotting Skin | Target DoT: 108 initial + 55/s for 24s; 2.0s cast | Shadow | 155 |
| Summon Greater Skeleton | Advanced skeleton companion; permanent | Conjuration | 95 |
| Dark Pact | Sacrifice 100 HP to restore 130 mana; instant | Shadow | 0 |

### Level 34

| Spell | Description | School | Mana |
|---|---|---|---|
| Lich Form | Toggle: HP regen disabled; mana regen ×3; appearance shifts; signature | Shadow | 80 |
| Shattered Souls | Shadow damage (190); instant | Shadow | 115 |
| Enervation III | Shadow damage (295); 3.0s cast | Shadow | 180 |
| Death's Embrace | Shadow damage (220) + restore 145 HP; 0.5s cast | Shadow | 165 |
| Death's Communion | Target DoT: 130 initial + 70/s for 24s; 2.0s cast | Shadow | 185 |
| Summon Revenant | Revenant companion; the strongest undead summon to this point | Conjuration | 110 |

### Level 39

| Spell | Description | School | Mana |
|---|---|---|---|
| Bone Tempest | Shadow damage (215); instant | Shadow | 132 |
| Dark Fusillade | Shadow damage (330); 3.0s cast | Shadow | 202 |
| Soul Harvest | Shadow damage (252) + restore 172 HP; 0.5s cast | Shadow | 192 |
| Plague of Bonewither | Target DoT: 155 initial + 88/s for 24s; 2.0s cast | Shadow | 218 |
| Lich Form II | Toggle: HP regen disabled; mana regen ×4; improved | Shadow | 80 |
| Terror IV | AoE fear: 10m radius; flee 40s | Shadow | 80 |

### Level 44

| Spell | Description | School | Mana |
|---|---|---|---|
| Ossification | Shadow damage (245); instant | Shadow | 150 |
| Enervation IV | Shadow damage (375); 3.0s cast | Shadow | 228 |
| Grand Lifetap | Shadow damage (290) + restore 208 HP; 0.5s cast | Shadow | 222 |
| Death's Communion II | Target DoT: 185 initial + 110/s for 24s; 2.0s cast | Shadow | 250 |
| Summon Death Knight | Armored elite undead champion companion; permanent | Conjuration | 140 |
| Lich's Caress | AoE shadow damage (140) in 15m; all targets −60 resists for 60s | Shadow | 145 |

### Level 49

| Spell | Description | School | Mana |
|---|---|---|---|
| Ancient Bone Shards | Shadow damage (285); instant | Shadow | 175 |
| Ancient Enervation | Shadow damage (425); 3.0s cast | Shadow | 262 |
| Ancient Lifetap | Shadow damage (336) + restore 248 HP; 0.5s cast | Shadow | 252 |
| Ancient Decay | Target DoT: 220 initial + 140/s for 24s; 2.0s cast | Shadow | 285 |
| Lich Form III | Toggle: HP regen disabled; mana regen ×5; near-unlimited casting | Shadow | 80 |

### Level 50

| Spell | Description | School | Mana |
|---|---|---|---|
| Finger of Death | Instant shadow damage (600); 30% chance to instantly kill non-elite targets | Shadow | 250 |
| Wail of the Banshee | AoE: shadow DoT 300 initial + 200/s in 20m; AoE fear 60s | Shadow | 320 |
| Lich's Ascension | Permanent toggle: no HP regen; unlimited mana regen; near-immortal while active | Shadow | 300 |

## Portrait Reference
*See [characters.md](../lore/characters.md) — Kel`varath Necromancer: "The Bone Cartographer"*
