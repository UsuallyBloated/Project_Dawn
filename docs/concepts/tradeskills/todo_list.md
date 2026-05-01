# Tradeskill Development To-Do

Tracks implementation status of the tradeskill system. Design docs live alongside this file. Item definitions live in `docs/concepts/items/`.

**Legend:** ✅ Done | 🔨 In Progress | ⬜ Not Started | 🚫 Blocked

---

## Foundation (already implemented)

| Status | Item |
|---|---|
| ✅ | `crafting.gd` autoload — skill XP, success formula, racial multipliers, combine resolution |
| ✅ | `tradeskill_definitions.gd` — all 38+ skills with caps, racial bonuses, access gates |
| ✅ | `recipe_definitions.gd` — Smelting, Tanning, Leatherworking, Tailoring, Blacksmithing, Weaponsmithing, Woodworking, Fletching, Alchemy, Poison Making, Baking, Brewing, Jewelry Crafting, Pottery, Tinkering |
| ✅ | `item_data.gd` — ItemData class with stat bonuses, weapon stats, armor, food/drink, augment fields |
| ✅ | Food/drink buff system — `BuffManager.add_food_buff` / `add_drink_buff`; regen.gd ticks |
| ✅ | Item docs — `docs/concepts/items/` with raw materials, processed, consumables, equipment, components |
| ✅ | Full ore chain in recipes — Tin, Bronze, Silver, Gold, Mithril, Adamantite ingots |
| ✅ | Wire drawing — Silver Wire, Gold Wire added to Smelting |
| ✅ | Copper chain set completed — Coif, Gloves, Boots, Leggings added |
| ✅ | Tinkering inputs — Small Gear, Coiled Spring added to Blacksmithing |
| ✅ | Thread recipes — Linen Thread (from Flax), Thick Silk Thread (from Spiderling Silk) |
| ✅ | Arrow components — Arrow Fletching (from Feather), Flint Arrowhead (from Flint) |

---

## Phase 1 — Core Infrastructure

*Everything else depends on this. No other systems required.*

### Item Definitions (GDScript)

The recipe file references item names as strings. These need matching `ItemData` resources or a central `item_definitions.gd` lookup so the combine window and loot system can find them.

| Status | Item |
|---|---|
| ⬜ | Create `data/item_definitions.gd` — static dictionary of all items keyed by name |
| ⬜ | Raw materials (ores, herbs, hides, wood, stone, grave yields) |
| ⬜ | Processed materials (ingots, leather strips, thread, rope, vials) |
| ⬜ | Crafted equipment (cloth/leather/chain armor, weapons, jewelry) |
| ⬜ | Consumables (potions, food, drink, poisons) |
| ⬜ | Tools and components (pickaxe, sewing needle, smithing hammer, tinkering kit, etc.) |
| ⬜ | Vendor-only items — Flour, Water Flask, Empty Bottle, Tarnished Silver Setting, Yeast |

### Combine Window (UI)

| Status | Item |
|---|---|
| ⬜ | Combine window scene — lists recipes for selected tradeskill |
| ⬜ | Ingredient slot UI — drag items from inventory into combine slots |
| ⬜ | Attempt combine button — calls `Crafting.try_combine()` |
| ⬜ | Success/failure feedback in chat log |
| ⬜ | Skill XP display on success |
| ⬜ | Trivial recipe indicator (grey out when no XP awarded) |
| ⬜ | Station gate — recipe greyed out if required station not nearby |

### Crafting Stations (World Objects)

| Status | Item |
|---|---|
| ⬜ | Forge scene — opens Blacksmithing/Weaponsmithing/Smelting combine window on interact |
| ⬜ | Alchemy Table — opens Alchemy/Poison Making combine window |
| ⬜ | Kiln — opens Pottery combine window |
| ⬜ | Oven — opens Baking combine window |
| ⬜ | Brewing Barrel — opens Brewing combine window |

### Loot Table System

Required for Cloth Scraps, Metal Bits, Feathers, mob venoms, and all mob-drop raw materials.

| Status | Item |
|---|---|
| ⬜ | `data/loot_tables.gd` — per-enemy loot tables with drop chance and qty range |
| ⬜ | Wire loot roll into enemy death in `enemy.gd` |
| ⬜ | Humanoid mobs (bandits, cultists, zombies) — drop Cloth Scraps |
| ⬜ | Bird mobs — drop Feather, Raw Egg |
| ⬜ | Construct/golem mobs — drop Metal Bits |
| ⬜ | Wolf mobs — drop Wolf Meat (already have Wolf Pelts from skinning) |

---

## Phase 2 — First Tradeskills Playable

*Requires Phase 1. Targets the shortest path to a working crafting loop.*

| Status | Tradeskill | Loop |
|---|---|---|
| ⬜ | Smelting → Blacksmithing | Mine Copper Ore → smelt Copper Ingot → smith Copper Chain Vest → equip |
| ⬜ | Tanning → Leatherworking | Skin wolf → tan Cured Leather Strip → craft Leather Vest → equip |
| ⬜ | Tailoring | Loot Cloth Scraps from humanoid → spin Linen Thread from Flax → craft Cloth Robe |
| ⬜ | Alchemy (White) | Pick Feverfew + Bloodmoss → combine at alchemy table → Minor Healing Potion |
| ⬜ | Baking | Buy Flour + Water Flask from vendor → bake Bread Loaf → eat for HP regen buff |
| ⬜ | Brewing | Buy Barley + Hops + Yeast → brew Crude Ale → drink for MP regen buff |
| ⬜ | Fletching | Quarry Flint → knap Flint Arrowheads → combine with Hardwood Shafts + Feathers → Arrow Bundle |
| ⬜ | Jewelry Crafting | Mine Silver Ore → smelt Silver Ingot → draw Silver Wire → craft Silver Ring → equip |

---

## Phase 3 — Gathering Nodes

*Requires the loot table and world object systems. Makes gathering skills functional.*

| Status | Skill | Notes |
|---|---|---|
| ⬜ | Mining nodes | Ore vein scene; depletes on harvest; respawn timer; requires Pickaxe in inventory |
| ⬜ | Coal seam nodes | Separate node type from ore; skill 0; no tool required beyond pickaxe |
| ⬜ | Herbalism nodes | Ground-level spawns; biome-specific; some night-only |
| ⬜ | Logging nodes | Tree objects; requires Axe; yields timber type based on zone |
| ⬜ | Skinning | Add `is_skinnable` flag to enemy; require Skinning Knife in inventory; yield based on Skinning skill vs. creature tier |
| ⬜ | Quarrying nodes | Stone outcroppings; requires Maul and Chisel; yields Flint, Limestone, etc. |
| ⬜ | Fishing | Rod equips to weapon slot; cast at water node; wait for catch event |
| ⬜ | Trapping | Place Trap Kit in world; return to collect; skill affects what tier spawns |
| ⬜ | Node minimap visibility | Higher gathering skill reveals more nodes on minimap / track window |

---

## Phase 4 — Gated Tradeskills

*Requires Phase 2–3 plus specific access conditions.*

| Status | Tradeskill | Gate | Dependency |
|---|---|---|---|
| ⬜ | Poison Making | Alignment ≤ Neutral + class gate (Rogue/Necro/SK/BM/WH/Dark Elf) | Alignment already wired; just needs combine window |
| ⬜ | Weaponsmithing specialization | Blacksmithing 150 fork | Specialization system |
| ⬜ | Grave Robbing | Alignment ≤ Neutral; requires Shovel; world burial nodes | Burial site world objects |
| ⬜ | Necromantic Scribing | Evil alignment + Necromancer/SK class; requires Grave Robbing output | Grave Robbing nodes |
| ⬜ | Shadow Weaving | Dark Elf exclusive; requires Shadow Fiber (shadow biome Herbalism) | Shadow biome zone |
| ⬜ | Tinkering | Gnome/Kobold exclusive; requires Tinkering Kit | Phase 2 combine window |
| ⬜ | Black Alchemy | Alignment ≤ Neutral; same skill as White | Phase 2 alchemy; alignment gate check in combine window |
| ⬜ | Bone Carving | Ogre/Troll exclusive (Minotaur via Ancestor Vessel transformation) | Phase 3 mob loot for bones |

---

## Phase 5 — Advanced Systems

*Lower priority; design is complete but implementation effort is high.*

| Status | Item | Notes |
|---|---|---|
| ⬜ | Specialization fork (skill 150) | One-time permanent choice; Blacksmithing → Weaponsmithing vs. Armorsmithing; Alchemy → Potioncraft vs. Elixir Craft; etc. |
| ⬜ | Recipe discovery | Failed combines at 75%+ of trivial skill: 2–10% chance to discover new recipe; Grand Discovery (one unique per tradeskill) |
| ⬜ | Crafter's mark | Discovered recipes produce items with crafter's name |
| ⬜ | Skill trainer NPCs | Sells initial recipe book and teaches skills above 0; faction/alignment gates on advanced trainers |
| ⬜ | Mortar and Pestle recipes | Grind ingots → metal dusts (Iron/Gold/Silver Dust) for Alchemy elixirs; Bones → Bone Dust |
| ⬜ | Purified Water recipe | River/Ocean Water + Silverleaf at Alchemy skill 10 |
| ⬜ | Prospecting | Requires Mining 40; improves gem quality/chance from ore veins |
| ⬜ | Taxidermy | Requires Skinning 30; trophy mounts from boss creatures |

---

## Blocked — Requires Other Systems First

These cannot be started until the listed dependency ships.

| Status | Tradeskill / Item | Blocked On |
|---|---|---|
| 🚫 | Flax crop → Linen Thread (Farming source) | Farming system |
| 🚫 | Barley, Hops, Grain crops | Farming system |
| 🚫 | Beekeeping → Honey (world source) | Farming system |
| 🚫 | Animal Husbandry | Mount system |
| 🚫 | Sailing | Water/boat system |
| 🚫 | Deepwater Fishing (Troll) | Water/boat system |
| 🚫 | Spider Venom / Venom Sac / Spiderling Silk | Spider mob type |
| 🚫 | Snake Venom Sac | Snake mob type |
| 🚫 | Bat Blood | Bat mob type |
| 🚫 | Ice / Fire / Shadow Essence | Elemental mob types |
| 🚫 | Runeforging trainer access (Friendly+ faction) | Faction system |
| 🚫 | Bookbinding / Grand Grimoire housing item | Player housing system |
| 🚫 | Clockwork Engineering prestige path | Tinkering Phase 4 complete first |
| 🚫 | Cartography (map reveals nodes) | Minimap system |
| 🚫 | Resurrection spell (Cleric) | Corpse system |

---

## Open Item Questions

See `docs/concepts/items/README.md` for the full table. Remaining pending items:

| Item | Decision Needed |
|---|---|
| Iron Shavings | Smithing by-product recipe, or just vendor-sold? |
| Bone Dust | Mortar and Pestle recipe from Bone Chips, or Bone Carving by-product only? |
| Water Flask | Vendor-only, or craftable via Pottery (filled flask)? |
| Arrow bundle count | How many arrows per bundle? (Recommend: 20) |
