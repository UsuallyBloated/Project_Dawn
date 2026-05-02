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
| ✅ | All 150+ item `.tres` files — ores, ingots, hides, herbs, armor, weapons, tools, consumables |
| ✅ | `data/loot_tables.gd` — MobLootTables: 12 mob archetypes (Wolf, Gnoll, Skeleton, Rat, Boar, Snake, Bear, Spider, Bat, Zombie, Bandit) + generic fallback; partial mob-name matching; SKINNING dict with pelt-quality progression |
| ✅ | Vendor NPCs — `scenes/vendor_npc.tscn`; Elara (General Merchant) + Brom (Provisioner) in world.tscn; F key opens shop; 10 vendor types in `data/vendor_definitions.gd` |
| ✅ | Test Panel "Give Crafting Materials" — seeds 35 stacks covering all 8 Phase 2 loops |

---

## Phase 1 — Core Infrastructure

*Everything else depends on this. No other systems required.*

### Item Definitions

All items implemented as `.tres` files in `data/loot/items/` — no separate `item_definitions.gd` needed; `crafting.gd` and `vendor_window.gd` both load by path.

| Status | Item |
|---|---|
| ✅ | Raw materials — copper/tin/iron/silver/gold/mithril/adamantite ores, herbs, hides, wood, flax, flint, coal |
| ✅ | Processed materials — all ingots, leather strips/slabs, thread, vials, wires |
| ✅ | Crafted equipment — cloth/leather/chain/copper armor sets, weapons, jewelry |
| ✅ | Consumables — potions, food, drink, poisons |
| ✅ | Tools and components — Smithing Hammer, Sewing Needle, Skinning Knife, Tinkering Kit, pickaxe (not yet used) |
| ✅ | Vendor-only items — Flour, Water Flask, Empty Bottle, Tarnished Silver Setting, Yeast all have `.tres` files and appear in vendor stock |

### Combine Window (UI)

| Status | Item |
|---|---|
| ✅ | Combine window — `scripts/crafting_window.gd`; K to open; skill dropdown, recipe list, ingredient have/need display, combine button, result feedback |
| ✅ | Success/failure feedback in chat log |
| ✅ | Skill XP display on success |
| ✅ | Trivial recipe indicator — skill level vs. trivial_at shown on recipe detail |
| ⬜ | Drag-drop ingredient slots — currently shows have/need counts; no drag-drop |
| ✅ | Station gate enforcement — `StationManager.nearby_station` checked in `Crafting.try_combine()`; combine button disabled when not at station; F key near station opens crafting window |

### Crafting Stations (World Objects)

| Status | Item |
|---|---|
| ✅ | Forge — placed in world.tscn at (-4,0,5); colored orange-red; proximity registers in StationManager |
| ✅ | Alchemy Table — placed at (-4,0,11); purple |
| ✅ | Kiln — placed at (-4,0,14); brown |
| ✅ | Oven — placed at (-4,0,8); brown |
| ✅ | Brewing Barrel — placed at (-4,0,17); dark brown |

### Loot Table System

| Status | Item |
|---|---|
| ✅ | `data/loot_tables.gd` — per-enemy loot tables with drop chance and qty range |
| ✅ | Loot roll wired to enemy death — `autoloads/loot.gd` connects `enemy.died`; `MobLootTables.build()` called from `enemy._build_default_loot_table()` |
| ✅ | Humanoid mobs (Gnoll, Zombie, Bandit) — drop Cloth Scraps |
| ✅ | Wolf mobs — drop Wolf Meat, pelts, Sinew |
| ⬜ | Bird mobs — drop Feather, Raw Egg (no bird mob type yet) |
| ⬜ | Construct/golem mobs — dedicated table (Bandit table has Metal Bits as approximation) |

---

## Phase 2 — First Tradeskills Playable

*All loops now testable via Test Panel + Vendor NPCs. Station enforcement still needed for oven/forge/alchemy table recipes.*

| Status | Tradeskill | Loop |
|---|---|---|
| ✅ | Smelting → Blacksmithing | Copper Ore + Coal → smelt Copper Ingot → smith Copper Chain Vest; all items exist; works via test panel |
| ✅ | Tanning → Leatherworking | Skin wolf (F key + Skinning Knife) → tan Cured Leather Strip → craft Leather Vest; full live loop |
| ✅ | Fletching | Buy Hardwood Shaft + Flint from vendor → Flint Arrowhead → Arrow Bundle; no station needed |
| ✅ | Jewelry Crafting | Buy Silver Ore from Blacksmith → smelt Silver Ingot → draw Silver Wire → craft Silver Ring; no station needed |
| 🔨 | Tailoring | Cloth Scraps from General Merchant or humanoid drops; Flax from vendor; works via test panel; no dedicated cloth-mob drops yet |
| 🔨 | Alchemy (White) | Herbs buyable from Alchemist vendor; station gate not enforced, so combines succeed anywhere |
| 🔨 | Baking | Flour + Water Flask buyable from Provisioner; station gate not enforced |
| 🔨 | Brewing | All ingredients buyable from Provisioner; station gate not enforced |

---

## Phase 3 — Gathering Nodes

*Loot table system is done. World object infrastructure still needed for nodes.*

| Status | Skill | Notes |
|---|---|---|
| ✅ | Skinning | `is_skinnable` export auto-detected from mob name; `try_skin()` on enemy corpse (F key within 3m); requires Skinning Knife; pelt quality scales with Skinning skill; XP granted; skinnable corpses linger 30s |
| ✅ | Mining nodes | `scenes/mining_node.tscn` + `scripts/mining_node.gd`; depletes on harvest; respawn timer (60–90s); requires Pickaxe; XP to Mining skill; TinVein1/2 and SilverVein1 placed in world.tscn |
| ⬜ | Coal seam nodes | Separate node type from ore; skill 0; no tool required beyond pickaxe |
| ⬜ | Herbalism nodes | Ground-level spawns; biome-specific; some night-only |
| ⬜ | Logging nodes | Tree objects; requires Axe; yields timber type based on zone |
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
| ⬜ | Tinkering | Gnome/Kobold exclusive; requires Tinkering Kit | Phase 2 combine window ✅ |
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
