# Components

Non-equippable, non-consumable items. Includes gathering tools, crafting tools, containers, crafting reagents, tinkering parts, and misc lore/currency items.

---

## Gathering Tools

Required to perform gathering skills. Not consumed unless noted.

| Item | Skill | Notes |
|---|---|---|
| Pickaxe | Mining | Held in inventory; not equipped to weapon slot |
| Axe | Logging | Held in inventory |
| Herb Pouch | Herbalism | Increases yield stack size per node |
| Skinning Knife | Skinning | Must be in inventory; not equipped |
| Fishing Rod | Fishing | Equips to weapon slot |
| Bait | Fishing | **Consumed** per cast; type affects catch tier |
| Trap Kit | Trapping | **Consumed** on placement; recovered on successful catch |
| Maul and Chisel | Quarrying | Two-item set; both must be in inventory |
| Shovel | Grave Robbing | Held in inventory |

---

## Crafting Tools

Required for specific recipes. Not consumed (durable tools).

| Item | Used In | Notes |
|---|---|---|
| Smithing Hammer | Blacksmithing, Weaponsmithing, Smelting | Required at forge |
| Sewing Needle | Leatherworking, Tailoring | Portable; no station required |
| Alchemy Kit | Alchemy | Portable; allows Apprentice/Journeyman recipes anywhere; degrades slowly |
| Mortar and Pestle | Alchemy (grinding) | Produces powders from raw ingredients |
| Tinkering Kit | Tinkering | Required for all Tinkering recipes |

---

## Containers / Vessels

Used in recipes as combine containers or consumable outputs.

| Item | Source | Used In | Notes |
|---|---|---|---|
| Empty Vial | Pottery / Glassblowing / Vendor | Alchemy (generic; maps to Clay Vial below skill 100) | Stack 20 |
| Clay Vial | Pottery (Fired Clay Bowl derivative) | Alchemy (Apprentice/Journeyman) | Stack 20 |
| Glass Vial | Glassblowing (skill 40) | Alchemy (Artisan+) | Stack 20 |
| Grand Vial | Glassblowing (skill 140) | Alchemy (Legendary tier) | Stack 10 |
| Empty Bottle | Glassblowing / Vendor | Brewing | Stack 10 |
| Water Flask | Vendor / Farming (well) | Baking, Brewing | Stack 10; consumed in recipe |
| Iron Casing | Smithing (Weaponsmithing, low skill) | Plague Grenade | Stack 5 |

---

## Tinkering Components

Produced by Smelting / Smithing; consumed in Tinkering recipes.

| Item | Source | Min Skill to Produce | Used In |
|---|---|---|---|
| Small Metal Sheet | 3× Metal Bits at forge | Smelting 10 | Tinkering (base component) |
| Small Metal Plate | 1× Small Metal Sheet | Smelting 10 | Mechanical Trap, Crude Clockwork |
| Small Gear | Smithed from metal stock | Smithing ~30 | Mechanical Trap, Crude Clockwork |
| Coiled Spring | Smithed from metal stock | Smithing ~35 | Mechanical Trap, Crude Clockwork |

*Recipes for Small Gear and Coiled Spring need to be added to `recipe_definitions.gd`.*

---

## Jewelry Components

| Item | Source | Used In |
|---|---|---|
| Silver Wire | Smelting (1× Silver Ingot → wire) | Jewelry Crafting |
| Gold Wire | Smelting (1× Gold Ingot → wire) | Jewelry Crafting |
| Tarnished Silver Setting | Vendor | Jewelry Crafting (Silver Ring) |

*Wire-drawing recipes need to be added to `recipe_definitions.gd`.*

---

## Alchemy / Crafting Reagents

These are intermediate or supporting items used as crafting inputs. Not equipped or consumed by the player directly.

| Item | Source | Used In |
|---|---|---|
| Iron Dust | Mortar and Pestle from Iron Ingot | Elixir of Strength |
| Gold Dust | Mortar and Pestle from Gold Ingot | Elixir of Intellect |
| Silver Dust | Mortar and Pestle from Silver Ingot | Elixir of Wisdom |
| Bone Dust | Mortar and Pestle from Bone/Bone Chips; Bone Carving by-product | Black Alchemy |
| Purified Water | Riverwater + Silverleaf (Alchemy skill 10) | Antidote; mid-tier potions |
| Necromancer's Ink | Black Alchemy (skill 160) | Necromantic Scribing |
| Bark Pulp | Logging by-product (skill 40+) | Scribing (paper) |
| Arrow Fletching | Crafted from Feather; or looted | Fletching |

---

## Tinkered Devices (Output)

Produced by Tinkering. Not equippable in combat slots — placed in the world or inventory-activated.

| Item | Min Skill | Function |
|---|---|---|
| Mechanical Trap | 30 | Placed in world; triggers on enemy proximity |
| Crude Clockwork | 50 | Animated device; behavior TBD (Clockwork Engineering prestige path) |

---

## Misc / Lore Items

Items with vendor value or lore significance but no crafting use.

| Item | Source | Notes |
|---|---|---|
| Old Coin | Grave Robbing | Vendor currency |
| Iron Burial Token | Grave Robbing | Vendor value; lore |
| Fossil Fragment | Quarrying (skill 100+) | Vendor; Necromantic Scribing |
| Cursed Relic | Grave Robbing | Lore; Necromantic Scribing input |
| Spell Shard | Grave Robbing (Mage's tomb) | Scribing (study; passive XP?) |
| Hero's Remains | Grave Robbing (one per tomb) | Unique lore item |
| Dark Crown Components | Grave Robbing | Necromantic Scribing (end-game) |
| River Shell | Fishing (freshwater) | Pottery |
| Coral | Fishing (coastal) | Jewelry Crafting; Enchanting |
