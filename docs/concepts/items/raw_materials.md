# Raw Materials

Items obtained directly from gathering nodes or mob loot. These are inputs — they are not usable on their own except as crafting ingredients.

---

## Mining

**Tool:** Pickaxe | **Skill:** Mining | **Racial bonus:** Dwarf (+XP, +gem chance), Ogre (+XP)

### Ore

| Item | Min Skill | Node Location | Smelts Into |
|---|---|---|---|
| Copper Ore | 0 | Surface caves, shallow dungeons | Copper Ingot |
| Tin Ore | 25 | Mid-tier caves | Tin Ingot |
| Iron Ore | 60 | Deep caves, mountain zones | Iron Ingot |
| Silver Ore | 90 | Mountain cave veins | Silver Ingot |
| Gold Ore | 120 | Deep mountain, dungeon rare spawns | Gold Ingot |
| Mithril Ore | 160 | High mountain, dungeon upper floors | Mithril Ingot |
| Adamantite Ore | 185 | End-game zones only | Adamantite Ingot |

**Bronze alloy:** Copper Ore + Tin Ore → Bronze Ingot at Smelting skill 30. No separate ore type.

### Coal

| Item | Min Skill | Node Location | Used In |
|---|---|---|---|
| Coal | 0 | Coal seam nodes in caves | Smelting (fuel) |

*Coal seam nodes need to be added to zone design. Currently missing from gathering.md.*

### Gems

Gem nodes are rare spawns within ore veins at Mining 50+. Higher skill raises both find chance and tier.

| Item | Approx Min Skill | Primary Use |
|---|---|---|
| Rough Jasper | 50 | Low-tier Jewelry Crafting |
| Rough Bloodstone | 70 | Jewelry Crafting |
| Rough Ruby | 80 | Jewelry Crafting |
| Rough Sapphire | 90 | Jewelry Crafting |
| Rough Emerald | 100 | Jewelry Crafting |
| Rough Topaz | 110 | Jewelry Crafting |
| Rough Opal | 120 | Jewelry Crafting |
| Diamond | 160 | High-tier Jewelry Crafting, Enchanting |

### Misc Mining Loot

| Item | Source | Used In |
|---|---|---|
| Flint Arrowhead | Flint deposits (stone nodes, skill 0) | Fletching |
| Metal Bits | Construct mob loot; scrap nodes | Smelting |

---

## Logging

**Tool:** Axe | **Skill:** Logging | **Feeds into:** Woodworking, Fletching, Scribing (bark pulp)

| Item | Min Skill | Zone | Properties |
|---|---|---|---|
| Pine | 0 | Common forests, hillsides | General-purpose; cheap; plentiful |
| Oak | 30 | Temperate forests | Dense and durable; best for shields |
| Birch | 50 | Northern forests, elevated zones | Light and straight-grained; bows and arrow shafts |
| Ash | 80 | Ancient forests | Strong and flexible; premium bow wood |
| Ironwood | 120 | Deep forest, dungeon groves | Near-metal hardness; weapon hafts, heavy staves |
| Darkwood | 150 | Shadow biomes, cursed groves | Shadow Weaving looms; dark caster staves |
| Ancientwood | 185 | Oldest forest zones | Legendary staves, Druid ritual objects |

**Bark Pulp:** By-product of Logging at skill 40+. Feeds Scribing (paper production). Arrives alongside the main timber yield.

---

## Herbalism

**Tool:** None (Herb Pouch in inventory increases yield stack size) | **Skill:** Herbalism | **Racial bonus:** Wood Elf (+XP, pre-harvest quality assessment)

| Item | Min Skill | Biome / Condition | Primary Use |
|---|---|---|---|
| Bloodmoss | 0 | Common fields, forest edges | White Alchemy (healing base) |
| Bitterroot | 0 | Marshes, riverbanks | White Alchemy (antidotes) |
| Feverfew | 0 | Meadows, field edges | White Alchemy (healing) — *add to gathering.md* |
| Wormwood | 10 | Marshes, disturbed soil | White Alchemy (antidotes, mana); *add to gathering.md* |
| Nightshade | 25 | Forests, night-only spawn | Black Alchemy, Poison Making |
| Silverleaf | 40 | Temperate fields, hillsides | White Alchemy (mana restoration, Purified Water) |
| Shimmerbloom | 60 | High elevation, mountain meadows | White Alchemy (stat elixirs) |
| Swampweed | 60 | Marshes, bog zones | Brewing; Cooking |
| Wild Mushroom | 0 | Shaded forest floors | Baking (Mushroom Bread) — *add to gathering.md* |
| Wild Berries | 0 | Forest edges, hedgerows | Baking (Berry Tart) — *add to gathering.md* |
| Rotting Fungi | 80 | Dungeon floors, cave walls, near undead | Black Alchemy |
| Deeproot | 90 | Deep cave systems, underground gardens | Alchemy, Incense Crafting |
| Dragonwort | 120 | Volcanic zones, magma-adjacent caves | Fire Alchemy; Enchanting (fire) |
| Moonpetal | 140 | Open ground, night-only | Superior-tier White Alchemy |
| Grave Flower | 160 | Near burial sites, undead zones | Necromantic Scribing; Black Alchemy |
| Spirit Sage | 170 | Ancient burial grounds, spirit-touched areas | Shaman rituals; White Alchemy |
| Void Bloom | 185 | End-game zones; Lich-corrupted areas | Legendary Alchemy; Necromantic Scribing |

*Feverfew and Wormwood are used in `recipe_definitions.gd` but missing from `gathering.md`. Add them.*

---

## Skinning

**Tool:** Skinning Knife (must be in inventory) | **Skill:** Skinning | **Racial bonus:** Troll (+XP, +rare hide variant chance)

### Hides and Pelts (from kills)

| Item | Min Skill | Source Creature | Feeds Into |
|---|---|---|---|
| Tattered Pelt | 0 | Rat, rabbit | Tanning → Cured Leather Strip (low yield) |
| Damaged Wolf Pelt | 0 | Wolf (damaged) | Tanning → Cured Leather Strip |
| Fresh Wolf Pelt | 5 | Wolf (healthy) | Tanning → Cured Leather Strip |
| Pristine Wolf Pelt | 15 | Elite wolves | Tanning → Cured Leather Strip (best yield) |
| Snake Skin | 10 | Serpents | Tanning |
| Boar Hide | 20 | Boar | Tanning → Thick Leather Slab |
| Bear Hide | 35 | Bear | Tanning → Thick Leather Slab (2×) |
| Scale Leather | 60 | Serpent, lizard | Leatherworking (scale-pattern appearance) |
| Silkpelt | 80 | Big cats | Premium Leatherworking; Tailoring upper tier |
| Drake Scale | 120 | Drake, wyvern | High-tier scale armor; partial magic resistance |
| Shadow Hide | 150 | Undead beasts, spectral creatures | Shadow Weaving; Leatherworking (stealth) |
| Dragon Scale | 185 | Dragon (end-game) | Legendary armor; Enchanting reagent |

**Sinew:** By-product of any Skinning action at skill 30+. Used in Leatherworking and Fletching (bowstrings).

### Other Mob Loot (Skinning-adjacent)

| Item | Source | Used In |
|---|---|---|
| Rabbit Pelt | Trapping (Snare Trap) | Tanning (low-tier) |
| Rabbit Meat | Trapping | Cooking |
| Fox Pelt | Trapping (Spring Trap) | Tanning (premium small hide) |
| Wolf Pelt | Trapping (Bear Trap) | Tanning |
| Goat Hide | Trapping (Bear Trap) | Tanning |
| Bone | Trapping (Bear Trap, Deadfall); Grave Robbing | Bone Carving |
| Spiderling Silk | Spider mobs | Tailoring (Cloth Robe, tier 2) |
| Thick Silk Thread | Processed from Spiderling Silk | Tailoring |
| Spider Venom | Spider mobs | Alchemy, Poison Making |
| Spider Venom Sac | Spider mobs | Alchemy, Poison Making |
| Snake Venom Sac | Snake mobs | Poison Making |
| Bat Blood | Bat mobs | Black Alchemy |
| Feather | Bird mobs; Cage Trap | Fletching; Alchemy (Elixir of Agility) |
| Wolf Meat | Wolf mobs | Baking (Meat Pie) |
| Raw Egg | Bird mobs; Farming | Baking |

---

## Fishing

**Tool:** Fishing Rod (weapon slot) + Bait (consumed per cast) | **Skill:** Fishing | **Troll exclusive:** Deepwater Fishing (skill 150+)

| Item | Zone Type | Min Skill | Used In |
|---|---|---|---|
| Common Fish | Freshwater ponds | 0 | Cooking |
| River Trout | Rivers | 20 | Cooking |
| Crayfish | Rivers | 20 | Cooking; Alchemy (oil) |
| Sea Fish | Coastal saltwater | 50 | Cooking (tier-2 food buffs) |
| Coral | Coastal saltwater | 50 | Jewelry Crafting; Enchanting |
| Rare Fish | Deep ocean | 90 | Cooking (tier-3 food buffs) |
| Shark Hide | Deep ocean | 90 | Leatherworking |
| Cave Creatures | Underwater caves | 120 | Alchemy |
| Bioluminescent Reagent | Underwater caves | 120 | Alchemy; Enchanting |

*Troll deepwater catches (abyssal fish, phosphorescent jellyfish) to be detailed in Troll racial lore.*

---

## Quarrying

**Tool:** Maul and Chisel | **Skill:** Quarrying | **Racial bonus:** Ogre (+XP, larger blocks), Dwarf (minor)

| Item | Min Skill | Primary Use |
|---|---|---|
| Limestone | 0 | Masonry; Pottery (clay substitute) |
| Granite | 40 | Heavy masonry |
| Marble | 80 | Premium housing |
| Obsidian | 120 | Decorative; Enchanting (volcanic) |
| Ruinstone | 160 | Scribing (transcription); Necromantic Scribing |

**Lump of Clay:** Obtained from digging/quarrying at skill 0. Primary Pottery ingredient.

**Fossil Fragment:** Rare by-product at skill 100+. Lore item; Necromantic Scribing use.

---

## Grave Robbing

**Alignment:** Neutral or Evil | **Tool:** Shovel | **Skill:** Grave Robbing | **Feeds into:** Necromantic Scribing, Black Alchemy, Bone Carving

| Item | Min Skill | Site Type | Used In |
|---|---|---|---|
| Bone Chips | 0 | Common grave | Bone Carving |
| Burial Cloth | 0 | Common grave | Necromantic Scribing |
| Old Coin | 0 | Common grave | Vendor (currency) |
| Weapon Fragment | 30 | Warrior's grave | Bone Carving |
| Iron Burial Token | 30 | Warrior's grave | Lore / vendor |
| Arcane Residue | 60 | Mage's tomb | Black Alchemy; Necromantic Scribing |
| Dark Runestone | 60 | Mage's tomb | Necromantic Scribing |
| Spell Shard | 60 | Mage's tomb | Scribing (study) |
| Ancestral Bone | 90 | Ancient burial mound | Bone Carving |
| Cursed Relic | 90 | Ancient burial mound | Lore / Necromantic Scribing |
| Black Alchemical Reagent | 90 | Ancient burial mound | Black Alchemy |
| Lich Dust | 120 | Necromancer's crypt | Black Alchemy; Necromantic Scribing |
| Death Rune | 120 | Necromancer's crypt | Necromantic Scribing |
| Soul Shard | 120 | Necromancer's crypt | Necromantic Scribing |
| Hero's Remains | 160 | Legendary hero's tomb (once only) | Unique lore item |
| Dark Crown Components | 160 | Legendary hero's tomb | Necromantic Scribing (end-game) |

---

## Farming

**Skill:** Farming | **Racial bonus:** Halfling (+XP, cap 275)

| Item | Notes | Used In |
|---|---|---|
| Barley | Grain crop | Brewing (Crude Ale) |
| Hops | Vine crop | Brewing |
| Flour | Milled from grain | Baking |
| Honey | Beekeeping yield | Baking (Berry Tart); Brewing (Honey Mead) |
| Yeast | Cultivated | Brewing |
| Flax | Fiber crop — source of Linen Thread (spin) | Tailoring |

*Linen Thread source: spin Flax via Tailoring at low skill, or purchased from vendor. Design decision pending.*

---

## Mob Loot (Non-Skill)

Items that drop from mobs with no gathering skill required.

| Item | Source | Used In |
|---|---|---|
| Cloth Scraps | Humanoid mobs (bandits, cultists, zombies) | Tailoring |
| Metal Bits | Construct mobs, scrap piles | Smelting |
| Ice Essence | Elemental (ice) mobs | Alchemy |
| Fire Essence | Elemental (fire) mobs | Alchemy |
| Shadow Essence | Shadow/undead mobs | Black Alchemy |
| Iron Shavings | Iron golem / construct mobs; smithing by-product | Black Alchemy |
| Bone Dust | Ground from bones; Bone Carving by-product | Black Alchemy |

*Elemental mob types not yet designed. Mark these items as blocked until mob roster expands.*
