# Tradeskills Index

Tradeskills are the crafting, gathering, and service economy of Project Dawn. They advance independently of character level through practice — every successful combine or gather action yields skill XP. Skills are available to all characters except where race, class, or alignment restrictions apply.

*See `autoloads/crafting.gd` (stub) for current code state. Full design in this directory.*

---

## Categories

| Category | Role | File |
|---|---|---|
| **Gathering** | Extract raw materials from the world | [gathering.md](gathering.md) |
| **Processing** | Convert raw materials into usable components | [processing.md](processing.md) |
| **Production** | Combine components into finished goods | [production.md](production.md) |
| **Consumables** | Produce food, drink, potions, and ritual goods | [consumables.md](consumables.md) |
| **Service** | Non-crafting support skills | [service.md](service.md) |
| **Alchemy** | Deep-dive: White/Black branches, alignment gating | [alchemy.md](alchemy.md) |
| **Tinkering / Clockwork Engineering** | Deep-dive: Gnome/Kobold prestige path | [tinkering.md](tinkering.md) |
| **Runeforging** | Deep-dive: Dwarf exclusive forge+rune fusion | [runeforging.md](runeforging.md) |
| **Enchanting** | Deep-dive: Post-craft magical imbuing | [enchanting.md](enchanting.md) |
| **Necromantic Scribing** | Deep-dive: Evil counterpart to Scribing | [necromantic_scribing.md](necromantic_scribing.md) |
| **Poison Making** | Deep-dive: Alignment-gated weapon coatings | [poison_making.md](poison_making.md) |
| **Bone Carving** | Deep-dive: Ogre/Troll exclusive primitive crafting | [bone_carving.md](bone_carving.md) |
| **Shadow Weaving** | Deep-dive: Dark Elf exclusive stealth cloth | [shadow_weaving.md](shadow_weaving.md) |

---

## All Tradeskills

| Tradeskill | Category | Base Cap | Racial Bonus | Restriction |
|---|---|---|---|---|
| Mining | Gathering | 200 | Dwarf +XP, Ogre +XP | — |
| Logging | Gathering | 200 | — | — |
| Herbalism | Gathering | 200 | Wood Elf +XP, Druid +XP | — |
| Skinning | Gathering | 200 | Troll +XP | — |
| Fishing | Gathering | 200 | — | — |
| Trapping | Gathering | 200 | Ranger +XP | — |
| Quarrying | Gathering | 200 | Ogre +XP, Dwarf minor | — |
| Grave Robbing | Gathering | 200 (300 Lich) | — | Evil/Neutral alignment |
| Deepwater Fishing | Gathering | 200 | — | Troll only |
| Smelting | Processing | 200 | Dwarf minor | — |
| Tanning | Processing | 200 | — | — |
| Rope Making | Processing | 200 | — | — |
| Blacksmithing | Production | 250 (Dwarf) | Dwarf cap +50, +XP | — |
| Armorsmithing | Production | 200 | — | Requires Blacksmithing 50 |
| Weaponsmithing | Production | 200 | — | Requires Blacksmithing 50 |
| Tailoring | Production | 200 | — | — |
| Leatherworking | Production | 200 | — | Requires Tanning 25 |
| Woodworking | Production | 200 | — | — |
| Fletching | Production | 200 | Wood Elf +XP | — |
| Jewel Crafting | Production | 200 | — | Requires Mining 40 |
| Pottery | Production | 200 | — | — |
| Masonry | Production | 200 | Ogre +XP | Requires Quarrying 30 |
| Baking | Consumables | 200 | Halfling +XP, exclusive recipes | — |
| Cooking | Consumables | 200 | Halfling +XP, exclusive recipes | — |
| Brewing | Consumables | 250 (Dwarf) | Dwarf cap +50, +XP | — |
| Alchemy | Consumables | 200 | — | Branch by alignment |
| Candlemaking | Consumables | 200 | — | — |
| Incense Crafting | Consumables | 200 | — | Requires Candlemaking 30 |
| Glassblowing | Consumables | 200 | — | — |
| Enchanting | Arcane | 200 | Elf +XP | — |
| Runecarving | Arcane | 200 | Dark Elf +XP | — |
| Scribing | Arcane | 200 | — | — |
| Bookbinding | Service | 200 | — | Requires Scribing 50, Cartography 50 |
| Cartography | Service | 200 | — | — |
| First Aid | Service | 200 | — | — |
| Lockpicking | Service | 200 | — | Rogue-type classes only |
| Animal Husbandry | Service | 200 | — | — |
| Farming | Service | 200 | Halfling +XP | — |
| Sailing | Service | 200 | — | — |
| Beekeeping | Service | 200 | — | — |
| Tinkering | Exclusive | 300 (Gnome/Kobold) | Gnome/Kobold 1.5× XP, cap 300 | — |
| Clockwork Engineering | Exclusive | 300 | — | Gnome or Kobold; Tinkering 150+ |
| Runeforging | Exclusive | 300 | — | Dwarf only; Blacksmithing 150+ |
| Bone Carving | Exclusive | 200 | — | Ogre, Troll; Minotaur via Ancestor Vessel |
| Shadow Weaving | Exclusive | 200 | — | Dark Elf only |
| Poison Making | Exclusive | 200 | Dark Elf +XP, +potency | Evil/Neutral; eligible classes only |
| Necromantic Scribing | Exclusive | 200 (250 Lich) | — | Evil alignment; Necromancer primary |

---

## Skill Mechanics

### Skill Score
Every tradeskill starts at 0. Successful combines grant XP; the amount scales with how close the recipe's difficulty is to the current skill score.

**Trivial threshold:** When skill is 100+ above a recipe's difficulty, the combine auto-succeeds with 0 XP gain.

**Failure:** Below a recipe's difficulty rating, combines can fail and destroy some or all materials. Failure chance is steep at large negative gaps.

### Difficulty Tiers

| Tier | Skill Range | XP per Success |
|---|---|---|
| Apprentice | 0–49 | 4 |
| Journeyman | 50–99 | 3 |
| Artisan | 100–149 | 2 |
| Master | 150–199 | 1 |
| Grandmaster | 200 | 1 |

**XP per level:** 20 (consistent with character XP in `PlayerStats`).

### Skill Caps

- **Base cap:** 200 for most tradeskills.
- **Racial cap bonus:** Applies a flat cap increase on top of base for racial affinity skills.
- **Prestige paths:** Clockwork Engineering and Runeforging have hard caps of 300; only accessible to specific races.
- **Transformation bonus:** Lich raises Necromantic Scribing cap to 250 and Grave Robbing cap to 300.

### Gathering Skill Mechanics
Gathering skill affects four things:
1. **Detection range** — higher skill = spots nodes from farther away (passive).
2. **Yield** — more materials per node.
3. **Tier access** — some nodes require a minimum skill to harvest at all.
4. **Rare material chance** — chance to find a premium variant (gems in ore, rare herb in herb patch).

---

## Economy Loop

1. **Gathering** extracts raw materials from the world.
2. **Processing** converts raws to usable components (Smelting ore → ingots; Tanning hides → leather).
3. **Production** combines components into finished goods.
4. **Consumables** are produced and destroyed on use — permanent demand.
5. **Vendor NPCs** buy crafted goods at base value. Player-to-player trade targets the premium tier.

**Self-sufficiency chains:**
- Ranger: Logging → Woodworking (shafts) + Skinning (sinew) + Blacksmithing (heads) → Fletching (arrows). Ranger-crafted arrows have a bonus proc chance.
- Warrior: Mining → Smelting → Blacksmithing (armor, weapons).
- Druid / Cleric: Herbalism → Alchemy (potions).
- Halfling regen package: Farming → Baking + Brewing = best food/drink in game.
- Dwarf endgame: Mining → Smelting → Blacksmithing → Runeforging.
- Dark caster: Herbalism + Grave Robbing → Black Alchemy → Necromantic Scribing / Poison Making.
- Artisan chain: Beekeeping → Candlemaking → Incense Crafting (ritual consumables for Clerics, Druids, Shamans).

---

## Class Connections

| Class | Primary Affinities | Notes |
|---|---|---|
| Ranger | Fletching, Trapping, Herbalism, Skinning | Ranger-crafted arrows have bonus proc chance |
| Rogue | Lockpicking, Poison Making, Tinkering | The complete subversive toolkit |
| Druid | Herbalism, Farming, Alchemy (White) | Bonus Herbalism XP; White Alchemy feeds their potion use |
| Shaman | Herbalism, Bone Carving, Alchemy (White/Black) | Reagent access for rituals |
| Necromancer | Grave Robbing, Necromantic Scribing, Alchemy (Black) | Primary user of all three |
| Blood Mage | Alchemy (Black), Poison Making | Poisons that cost HP; elixirs with self-damage riders |
| Witch Hunter | Tinkering, Poison Making | Silver bolt crafting; alchemical wards |
| Bard | Scribing, Cartography, Bookbinding | Reproducing songs as scrolls; player-authored lore books |
| Cleric | Enchanting, Candlemaking, Incense Crafting | Consecrated components for holy rites |
| Magician | Enchanting, Runecarving, Scribing | Spell enhancement via rune and scroll work |
| Wizard | Scribing, Enchanting | Spellbook copying; rune-enhanced focus items |

---

## Racial Bonuses

| Race | Tradeskill | Effect |
|---|---|---|
| Gnome | Tinkering | Co-exclusive with Kobold; 1.5× XP; cap 300 |
| Kobold | Tinkering | Co-exclusive with Gnome; 1.5× XP; cap 300 |
| Dwarf | Blacksmithing | +50 cap (250 total); +XP rate |
| Dwarf | Mining | +XP rate; bonus gem chance in veins |
| Dwarf | Brewing | +50 cap (250 total); +XP rate |
| Dwarf | Runeforging | Exclusive prestige path; cap 300 |
| Halfling | Cooking / Baking | +XP rate; exclusive recipes not available to other races |
| Halfling | Farming | +XP rate |
| Wood Elf | Herbalism | +XP rate; can assess herb quality before harvesting |
| Wood Elf | Fletching | +XP rate |
| Dark Elf | Poison Making | +XP rate; bonus potency on coated weapons |
| Dark Elf | Runecarving | +XP rate (ancient arcane tradition) |
| Dark Elf | Shadow Weaving | Exclusive |
| Elf | Enchanting | +XP rate |
| Ogre | Mining / Quarrying | +XP rate (raw strength) |
| Ogre | Bone Carving | Co-exclusive with Troll |
| Troll | Skinning | +XP rate; bonus rare hide chance |
| Troll | Bone Carving | Co-exclusive with Ogre |
| Troll | Deepwater Fishing | Troll exclusive gathering skill |
| Human | Any one (player's choice) | +20 cap on chosen skill; chosen at character creation |
| Minotaur | Bone Carving | Access via Ancestor Vessel transformation only |

---

## Access Restrictions

| Tradeskill | Alignment | Class |
|---|---|---|
| Grave Robbing | Neutral or Evil | Open |
| Poison Making | Neutral or Evil | Necromancer, Shadow Knight, Blood Mage, Rogue, Witch Hunter |
| Necromantic Scribing | Evil | Necromancer (primary), Shadow Knight (secondary) |
| Shadow Weaving | Any | Dark Elf only |
| Lockpicking | Any | Rogue-type classes only |
| Clockwork Engineering | Any | Gnome or Kobold; Tinkering 150+ |
| Runeforging | Any | Dwarf only; Blacksmithing 150+ |
| Bone Carving | Any | Ogre, Troll; Minotaur via Ancestor Vessel transformation |

**Alchemy branch split:** Alchemy is open to all alignments, but the recipe book is split — White Alchemy (good/neutral) and Black Alchemy (evil/neutral). A character who shifts alignment permanently loses the recipes of the branch they no longer qualify for. Neutral characters have access to both. See [alchemy.md](alchemy.md).

**Transformation effects on tradeskills:**
| Transformation | Tradeskill Effect |
|---|---|
| **Revenant** | All tradeskill scores are preserved at their pre-transformation levels. A Revenant who was a Grandmaster Blacksmith remains one. A Revenant with no skills remains unskilled. The grind survives death. |
| Lich | Grave Robbing cap → 300; Necromantic Scribing cap → 250; can sense hidden burial sites passively |
| Kobold Alpha | Tinkering cap increases; access to deeper Kobold tunnel trade networks |
| Fae-Old | Enchanting effectiveness increases; illusion-imbued items last longer |
| Ancestor Vessel (Minotaur) | Unlocks Bone Carving; crafted pieces carry ancestral resonance (+lore bonuses) |
| Warden of the Wild (Druid) | Herbalism reveals hidden nodes not visible at lower mastery |
| Redeemed Shadow Knight | Loses Poison Making; Blacksmithing gains holy-imbue option |
| Fallen Paladin | Gains Poison Making; Enchanting can imbue shadow effects |
