# Processed Materials

Intermediate items produced by crafting tradeskills. These are inputs to higher-tier recipes, not final products. Most require a processing tradeskill (Smelting, Tanning, Rope Making) before feeding into production tradeskills (Blacksmithing, Leatherworking, Tailoring).

---

## Smelting

**Station:** Forge | **Racial bonus:** Dwarf

### Ingots

| Item | Ingredients | Min Skill | Used In |
|---|---|---|---|
| Copper Ingot | 2× Copper Ore + 1× Coal | 0 | Blacksmithing, Weaponsmithing, Jewelry Crafting |
| Tin Ingot | 2× Tin Ore + 1× Coal | 0 | Smelting (Bronze alloy) |
| Bronze Ingot | 1× Copper Ingot + 1× Tin Ingot | 30 | Blacksmithing, Weaponsmithing |
| Iron Ingot | 2× Iron Ore + 2× Coal | 50 | Blacksmithing, Weaponsmithing |
| Silver Ingot | 2× Silver Ore + 1× Coal | 90 | Jewelry Crafting, Weaponsmithing (silver weapons) |
| Gold Ingot | 2× Gold Ore + 1× Coal | 120 | Jewelry Crafting, Enchanting reagent |
| Mithril Ingot | 2× Mithril Ore + 2× Coal | 160 | High-tier Blacksmithing/Weaponsmithing |
| Adamantite Ingot | 2× Adamantite Ore + 3× Coal | 185 | Legendary tier smithing |

### Metal Stock

| Item | Ingredients | Min Skill | Used In |
|---|---|---|---|
| Small Metal Sheet | 3× Metal Bits | 10 | Tinkering |
| Silver Wire | 1× Silver Ingot | 40 | Jewelry Crafting |
| Gold Wire | 1× Gold Ingot | 80 | Jewelry Crafting |
| Small Gear | Smithed from metal stock | 30 | Tinkering |
| Coiled Spring | Smithed from metal stock | 35 | Tinkering |
| Small Metal Plate | 1× Small Metal Sheet | 10 | Tinkering |

*Small Gear, Coiled Spring: these are referenced in Tinkering recipes but have no recipe yet. Add to Weaponsmithing or create a "Metalworking" sub-skill.*

---

## Tanning

**Station:** None (portable) | **Skill:** Tanning | **Feeds into:** Leatherworking

| Item | Ingredients | Min Skill | Output Qty | Notes |
|---|---|---|---|---|
| Cured Leather Strip | 1× Tattered Pelt | 0 | 1 | Lowest tier |
| Cured Leather Strip | 1× Damaged Wolf Pelt | 0 | 2 | |
| Cured Leather Strip | 1× Fresh Wolf Pelt | 5 | 3 | |
| Cured Leather Strip | 1× Pristine Wolf Pelt | 15 | 4 | Best common yield |
| Cured Leather Strip | 1× Snake Skin | 10 | 2 | |
| Thick Leather Slab | 1× Boar Hide | 20 | 1 | Mid-tier Leatherworking |
| Thick Leather Slab | 1× Bear Hide | 35 | 2 | |

---

## Rope Making

**Station:** None | **Skill:** Rope Making | **Feeds into:** Fletching, Sailing, various

| Item | Ingredients | Min Skill | Used In |
|---|---|---|---|
| Rope | Plant Fiber × 3 | 0 | Sailing, construction, general utility |
| Bowstring | Sinew × 2 | 20 | Woodworking (bows), Fletching |
| Shadow Cord | Shadow Fiber + Sinew | 80 | Shadow Weaving; dark gear |

*Plant Fiber source: low-skill Herbalism/Farming (flax, hemp stalks). Not yet in recipe file.*

---

## Woodworking (Processing Tier)

Before Woodworking produces final gear, raw timber must be shaped into stock.

| Item | Ingredients | Min Skill | Used In |
|---|---|---|---|
| Hardwood Shaft | 1× Oak or Birch log | 10 | Woodworking (staves), Fletching (arrow shafts) |
| Pliable Wood | 1× Pine log | 0 | Woodworking (carved items) |

*These are not currently explicit recipes in `recipe_definitions.gd` — they are assumed inputs. Add recipes to bring raw timber into the recipe chain.*

---

## Glassblowing

**Station:** Kiln (high heat) | **Skill:** Glassblowing | **Feeds into:** Alchemy (vials), Brewing (bottles)

| Item | Min Skill | Notes |
|---|---|---|
| Clay Vial | 0 | Basic Alchemy container; Pottery-adjacent (can also come from Pottery) |
| Empty Vial | 0 | Generic name used in `recipe_definitions.gd`; maps to Clay Vial below skill 100 |
| Glass Vial | 40 | Required for Artisan-tier Alchemy recipes |
| Grand Vial | 140 | Required for Legendary-tier Alchemy |
| Empty Bottle | 10 | Brewing container |

*`recipe_definitions.gd` uses "Empty Vial" generically. Below skill 100, Empty Vial = Clay Vial. Above 100, some recipes require Glass Vial specifically.*

---

## Pottery

**Station:** Kiln (for firing) | **Skill:** Pottery

| Item | Ingredients | Min Skill | Used In |
|---|---|---|---|
| Unfired Pottery | 3× Lump of Clay | 0 | Pottery (next step) |
| Fired Clay Bowl | 1× Unfired Pottery | 0 | Container; Alchemy (Clay Vial equivalent) |

---

## Alchemy Intermediates

| Item | Ingredients | Min Skill | Used In |
|---|---|---|---|
| Purified Water | River/Ocean Water + Silverleaf | 10 | Antidote; mid-tier Alchemy |
| Iron Dust | Ground from Iron Ingot | — | Elixir of Strength |
| Gold Dust | Ground from Gold Ingot | — | Elixir of Intellect |
| Silver Dust | Ground from Silver Ingot | — | Elixir of Wisdom |
| Bone Dust | Ground from Bone/Bone Chips | — | Black Alchemy |

*Grinding recipes (Ingot → Dust) need a Mortar and Pestle station entry in `recipe_definitions.gd`.*

---

## Silk (Tailoring)

| Item | Source | Min Skill | Used In |
|---|---|---|---|
| Spiderling Silk | Spider mob loot | — | Spun into Thick Silk Thread |
| Thick Silk Thread | 2× Spiderling Silk | 50 | Cloth Robe (Silk) |

*Spinning recipe needs to be added to `recipe_definitions.gd` under Tailoring.*
