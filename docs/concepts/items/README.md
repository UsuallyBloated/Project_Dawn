# Items

Canonical item reference for Project Dawn. Use this folder when writing recipes, loot tables, vendor inventories, or GDScript item definitions. The goal is one authoritative list so `recipe_definitions.gd`, future `loot_tables.gd`, and vendor inventories all use identical names.

**Economy flow:** Raw materials (gathered) → Processed intermediates (crafted) → Equipment / Consumables (final output)

---

## Files

| File | Contents |
|---|---|
| [raw_materials.md](raw_materials.md) | Node drops and mob loot: ores, herbs, hides, wood, fish, stone, grave yields |
| [processed.md](processed.md) | Intermediate crafted materials: ingots, cured leather, silk, rope, vials, thread |
| [consumables.md](consumables.md) | Potions, elixirs, food, drink, and poisons — all single-use items |
| [equipment.md](equipment.md) | Craftable weapons, armor, and jewelry |
| [components.md](components.md) | Tools, containers, reagents, tinkering parts — non-equippable non-consumables |

---

## Open Questions

These items appear in `recipe_definitions.gd` but have no defined source. Resolve before building loot tables or vendors.

| Item | Used In | Source | Status |
|---|---|---|---|
| Cloth Scraps | Tailoring | Mob loot — humanoid enemies (bandits, cultists, zombies) | **Decided: mob loot** |
| Linen Thread | Tailoring | Crafted: 3× Flax → 2× Linen Thread (Tailoring skill 0) | **Resolved — recipe added** |
| Thick Silk Thread | Tailoring tier 2 | Crafted: 2× Spiderling Silk → 1× Thick Silk Thread | **Resolved — recipe added** |
| Flour | Baking | Vendor-sold (basic supply); Farming mill recipe deferred | **Decided: vendor** |
| Coal | Smelting (fuel) | Mining — coal seam nodes | **Resolved — added to gathering.md** |
| Arrow Fletching | Fletching | Crafted: 3× Feather → 5× Arrow Fletching (Fletching skill 0) | **Resolved — recipe added** |
| Flint Arrowhead | Fletching | Quarrying: Flint (skill 0) → knapped into 5× Flint Arrowhead | **Resolved — recipe added** |
| Feverfew | Alchemy | Herb — meadows/road-side verges, skill 0 | **Resolved — added to gathering.md** |
| Wormwood | Alchemy (Antidote, Mana Potion) | Herb — marshes, disturbed soil, skill 10 | **Resolved — added to gathering.md** |
| Wild Mushroom | Baking | Herb node — shaded forest floors, skill 0 | **Resolved — added to gathering.md** |
| Wild Berries | Baking | Herb node — forest edges, skill 0 | **Resolved — added to gathering.md** |
| Metal Bits | Smelting | Mob loot from constructs / scrap piles | **Decided: mob loot** |
| Tarnished Silver Setting | Jewelry Crafting | Vendor-sold (jewelry supplies) | **Decided: vendor** |
| Raw Egg | Baking | Mob loot from birds; Farming (chickens) later | **Decided: mob loot for now** |
| Iron Shavings | Black Alchemy (Blood Elixir) | Smithing by-product or vendor — needs recipe or loot entry | **Pending** |
| Bone Dust | Black Alchemy | Bone Carving by-product; ground at Mortar and Pestle | **Pending — needs recipe** |
| Silver Wire | Jewelry Crafting | Smelting: 1× Silver Ingot → 2× Silver Wire | **Resolved — recipe added** |
| Gold Wire | Jewelry Crafting | Smelting: 1× Gold Ingot → 2× Gold Wire | **Resolved — recipe added** |
| Small Gear | Tinkering | Blacksmithing: 1× Small Metal Sheet → 2× Small Gear | **Resolved — recipe added** |
| Coiled Spring | Tinkering | Blacksmithing: 1× Small Metal Sheet → 1× Coiled Spring | **Resolved — recipe added** |
| Tin/Bronze/Silver/Gold/Mithril/Adamantite Ingot | Smithing | Smelting from ore + Coal | **Resolved — recipes added** |
| Spider Venom / Spider Venom Sac | Alchemy, Poison Making | Mob loot from spiders | **Blocked: spider mob not yet built** |
| Spiderling Silk | Tailoring | Mob loot from spiders | **Blocked: spider mob not yet built** |
| Snake Venom Sac | Poison Making | Mob loot from snakes | **Blocked: snake mob not yet built** |
| Bat Blood | Black Alchemy | Mob loot from bats | **Blocked: bat mob not yet built** |
| Ice / Fire / Shadow Essence | Alchemy | Mob loot from elemental creatures | **Blocked: elemental mobs not yet designed** |
| Flax | Tailoring (Linen Thread) | Farming crop | **Blocked: Farming not yet implemented** |

---

## Naming Rules

- Item names in `recipe_definitions.gd` are the canonical names. Doc files must match exactly.
- When alchemy.md or gathering.md uses a different name than the recipe file, the recipe file wins until explicitly reconciled.
- Plural forms are never used in item names (`Wolf Pelt`, not `Wolf Pelts`).
