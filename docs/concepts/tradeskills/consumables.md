# Consumables

Consumables are tradeskill outputs that are destroyed when used. This gives them permanent economic demand — unlike armor or weapons, they must be continuously re-supplied. Consumables drive the bulk of the player-to-player economy once crafting is mature.

---

## The Regen Loop

The core reason consumables matter is the meditation regen system. Out-of-combat mechanics:

1. **Sitting** triggers a meditate state: MP regenerates at 3× normal rate.
2. **Food buff** (active): HP regenerates faster.
3. **Drink buff** (active): MP regenerates faster.
4. **All three at once:** maximum regen rate. The pull-kill-sit-eat-med-drink-pull loop is the EQ heartbeat.

A character who skips food and drink regen during downtime is slower than one who doesn't. In group play, this gap compounds — casters who stay topped up on mana last longer in a dungeon session.

**Consumable duration:** Food and drink buffs persist even after standing. They don't require sitting to maintain. Duration ranges from 30 minutes to 90 minutes depending on quality tier.

**Stacking rules:**
- One food buff active at a time. A higher-tier food replaces a lower one.
- One drink buff active at a time. Same replacement rule.
- Food and drink stack with each other.
- Alchemy potions stack with both food and drink. Potions do not share the food/drink slot.

---

## Baking

**Requires:** Oven or Campfire (field baking) | **Prerequisites:** None | **Cap:** 200

Produce bread, pies, and simple baked goods that restore HP over time. Baking is the earliest and most accessible food tradeskill — Campfire baking requires only firewood and no station. Oven baking unlocks better recipes.

Baked goods provide **HP regen** buffs. They occupy the Food buff slot.

### Baking Recipes

| Item | Materials | Min Skill | Effect | Duration |
|---|---|---|---|---|
| Hard Tack | Flour + Water | 0 | +2 HP regen | 20 min |
| Simple Bread | Flour + Water + Yeast | 10 | +3 HP regen | 30 min |
| Meat Pie | Flour + Water + Any Meat | 40 | +5 HP regen | 40 min |
| Honey Cake | Honey + Flour + Egg | 60 | +6 HP regen, +2 STR | 45 min |
| Halfling Sweet Cake | Honey + Flour + Egg + Wildberries | 80 | +8 HP regen, +3 STR | 50 min |
| Trail Waybread | Rare Herbs + Flour + Honey + Egg | 140 | +10 HP regen, portable (24-hour in-game duration) | 60 min |
| Lembas (Grandmaster) | Ancientwood Grain + Moonpetal + Honey | 185 | +15 HP regen, +5 STR, +3 CON | 90 min |

**Halfling exclusive recipes:** Halflings have access to a Halfling Sweet Cake variant with a 20% higher effect than the standard version, and their Trail Waybread version includes a minor movement speed bonus. These recipes are not available to other races regardless of skill.

**Flour:** Baking requires flour as a base. Flour is produced via Farming (grain crops → milled flour). Players can purchase flour from vendors but Farming provides it at material cost only.

---

## Cooking

**Requires:** Cooking Pot (portable or station) | **Prerequisites:** None | **Cap:** 200

Complex meal preparation with stat-buff effects beyond simple HP regen. Cooking is Baking's sibling — Baking produces simple food, Cooking produces meals. They are intentionally separate: a dedicated Halfling Cooker + Halfling Baker is a formidable supply operation.

Cooked food provides **HP regen + secondary stat buffs**. It occupies the Food buff slot.

### Cooking Recipes

| Item | Materials | Min Skill | Effect | Duration |
|---|---|---|---|---|
| Roasted Meat | Any Raw Meat + Firewood | 0 | +3 HP regen, +1 STR | 30 min |
| Herb-Roasted Venison | Venison + Bitterroot + Swampweed | 40 | +5 HP regen, +3 STR | 45 min |
| Fisherman's Stew | Any Fish + Potato + Onion | 50 | +5 HP regen, +3 CON | 45 min |
| Hearty Stew | Any Meat + Potato + Carrot + Onion | 80 | +7 HP regen, +3 MP regen | 60 min |
| Braised Boar | Boar Meat + Swampweed + Deeproot | 100 | +8 HP regen, +5 CON | 60 min |
| Spiced Sea Catch | Rare Fish + Dragonwort + Salt | 120 | +10 HP regen, +5 AGI, +3 CON | 70 min |
| Halfling Feast | Best Bread + 3× quality ingredients + Spice blend | 160 | +15 HP regen, +8 MP regen, +5 STR, +3 CON | 90 min |
| Troll Deep-Sea Stew | Abyssal Fish + Cave Mushroom + Dark Spice | 160 | +12 HP regen, +5 CON, night-vision buff | 60 min |

**Halfling Feast:** The best food item in the game. The recipe is Halfling-accessible only (other races technically can combine it but miss the critical "Halfling's Touch" passive that brings it to full effect). Demand from non-Halflings is consistent — Halfling cooks can command significant prices.

**Troll Deep-Sea Stew:** Requires Abyssal Fish from Troll Deepwater Fishing. Night-vision buff removes darkness penalties in dungeons and night zones for the duration. Troll exclusive by ingredient, not recipe — anyone with the fish can cook it, but only Trolls catch the fish.

**Cooking fire:** A Cooking Pot can be used on a campfire in the field. Station Hearths in town produce faster and allow larger batch sizes.

---

## Brewing

**Requires:** Brewing Barrel + Bottling Kit | **Prerequisites:** None | **Cap:** 200 base; 250 for Dwarves

Ferment ales, meads, wines, and spirits. Brewed goods provide **MP regen** buffs, occupy the Drink buff slot, and often include minor secondary effects. The fermentation mechanic adds time depth — most brews require actual wait time between initial combine and bottling.

**Fermentation:** After the initial combine (grain + water + yeast into a barrel), the batch must sit for a real-world duration before it's ready to bottle. Cheap ales: 10 minutes. Quality meads: 30 minutes. Legendary spirits: 2 hours. This makes brewing a supply-management skill as much as a crafting one.

### Brewing Recipes

| Item | Materials | Min Skill | Effect | Duration | Ferment Time |
|---|---|---|---|---|---|
| Thin Ale | Barley + Water + Yeast | 0 | +2 MP regen | 20 min | 5 min |
| Darkwood Ale | Barley + Hops + Water + Yeast | 25 | +3 HP regen, +2 STR | 30 min | 10 min |
| Halfling Mead | Honey + Water + Wildflowers + Yeast | 40 | +4 HP regen, +4 MP regen | 40 min | 15 min |
| Elven Wine | Shimmerbloom + Sweetgrape + Water + Yeast | 80 | +5 MP regen, +3 INT | 50 min | 20 min |
| Dwarven Stout | Roasted Barley + Cave Mushroom + Water + Yeast | 90 | +5 HP regen, +5 CON | 50 min | 20 min |
| Gnome Engine Fuel | Special-roasted Barley + Ironwort + Water | 100 | +8 STR, -2 INT, +8 HP regen | 30 min | 15 min |
| Shaman's Root Beer | Deeproot + Bitterroot + Honey + Water + Yeast | 120 | +6 MP regen, +4 WIS | 60 min | 25 min |
| Kobold Tunnel Brew | Rotting Fungi + Cave Water + Yeast | 130 | +7 MP regen, mild poison resistance | 50 min | 20 min |
| Dwarven Grand Stout | Runebrewed Grain + Cave Mushroom + Gold Dust | 180 | +10 HP regen, +8 CON, +5 STR | 90 min | 45 min |

**Gnome Engine Fuel:** Named by Gnomes who claim it keeps their clockwork running. The name is a joke — it is extremely strong ale. It genuinely causes minor screen blur at low CON. Its popularity among non-Gnomes is a cultural mystery.

**Dwarven Grand Stout:** Requires a Runeforged Brewing Vessel (Blacksmithing + Runeforging combine — a station item a Dwarf must craft). Only available to Dwarves via the Runeforging path. The best drink buff in the game.

**Racial bonus:**
- **Dwarf:** +XP rate; cap raised to 250; Runebrewed Grain recipe unlocked at skill 150 (feeds Grand Stout).
- **Halfling:** Minor bonus — Halfling Mead has 10% extended duration when brewed by a Halfling.

---

## Candlemaking

**Requires:** None (candle mold, portable) | **Prerequisites:** None | **Cap:** 200

Produce candles, torches, and oil lamps as functional light sources and ritual components. Candlemaking is the first step in the artisan chain: Beekeeping → Candlemaking → Incense Crafting. A character who keeps bees, makes candles, and crafts incense is a one-person ritual supply shop.

### Products

| Item | Materials | Min Skill | Use |
|---|---|---|---|
| Tallow Candle | 1 Animal Fat (Cooking by-product) | 0 | Light source; 30 min burn time |
| Beeswax Candle | 1 Beeswax (Beekeeping) | 20 | Better light; 60 min burn; Incense Crafting component |
| Scented Candle | 1 Beeswax + 1 Herb | 50 | Regen minor bonus when burned in camp (+1 HP regen, +1 MP regen in radius) |
| Ritual Candle | 1 Beeswax + 1 Silver Dust + 1 Herb | 80 | Cleric/Shaman ritual component; required for some holy spells |
| Black Ritual Candle | 1 Tallow + 1 Bone Dust + Nightshade Wax | 100 | Necromancer ritual component; required for some death spells |
| Oil Lamp | 1 Clay Vial + Fish Oil + Rope Wick | 60 | Persistent light source; housing item |

**Ritual components:** Higher-tier Cleric and Shaman spells require physical consumable components (Ritual Candles, Incense). This is intentional — it creates demand for the artisan chain and gives non-combat tradeskills a direct link to combat-active classes.

---

## Incense Crafting

**Requires:** Workbench | **Prerequisites:** Candlemaking 30 | **Cap:** 200

Create incense and ritual smoke components used in spellcasting and shrine activation. Incense Crafting is the end of the Beekeeping → Candlemaking → Incense chain. The products are consumed in rituals, not carried in combat — but they are required components for certain high-tier spells.

### Products

| Item | Materials | Min Skill | Use |
|---|---|---|---|
| Common Incense | Herb + Beeswax + Bark | 30 | Shrine activation; meditation aura minor (+0.5 MP regen while burning in camp) |
| Spirit Smoke | Spirit Sage + Beeswax + Deeproot | 80 | Shaman ritual component; ancestor-summoning rites |
| Holy Incense | Shimmerbloom + Ritual Candle + Silver Dust | 100 | Cleric rite component; required for Resurrection (one per use) |
| Dark Incense | Grave Flower + Black Ritual Candle + Bone Dust | 110 | Necromancer ritual component; required for Lich Form toggle (one per activation) |
| Ward Smoke | Dragonwort + Beeswax + Iron Dust | 130 | Witch Hunter alchemical ward — burns in a small area, damages summoned creatures |
| Grand Ritual Smoke | Moonpetal + Ancientwood Bark + Void Bloom | 185 | Legendary ritual; once-per-character effects (specific to endgame content) |

**The artisan fantasy:** A Cleric who keeps bees, makes candles, and crafts incense never needs to buy their ritual components. A dedicated artisan crafter who supplies Clerics, Shamans, and Necromancers serves three separate markets with one skill chain. The supply chain is: Beekeeping (honey + wax) → Herbalism (herbs) → Candlemaking (wax candles) → Incense Crafting (ritual smoke). No metal. No forge. No violence required to supply the chain.

---

## Glassblowing

**Requires:** Glass Furnace station | **Prerequisites:** None | **Cap:** 200

Craft vials, flasks, lanterns, and ornamental glass. Glassblowing's primary economic function is producing containers for Alchemy — a Glassblower supplying an Alchemist is one of the cleanest economic partnerships in the game (Potters do the same for clay containers). High-tier Glassblowing produces decorative housing items and optical components for Tinkering.

### Products

| Item | Materials | Min Skill | Use |
|---|---|---|---|
| Empty Glass Vial (5-stack) | Sand + Ash | 0 | Alchemy container (same function as Clay Vial) |
| Glass Flask | Sand + Ash + Blowing technique | 20 | Better Alchemy container; slightly more fluid capacity |
| Glass Lantern | Sand + Ash + Iron Wire | 60 | Persistent light source; housing item; sharper light than oil lamp |
| Stained Glass Panel | Sand + Ash + Mineral Pigments | 100 | Housing decorative item; high vendor value |
| Crystal Lens | Pure Sand + Gold Dust + Precision technique | 140 | Tinkering component (optical mechanisms); Gnome engineering demand |
| Enchanter's Orb | Pure Sand + Sapphire Dust + Enchanting Reagent | 160 | Enchanter off-hand focus item; +3 INT, +5 CC duration |

**Sand:** A gathering by-product available near beaches and desert zones. Low skill required; abundant supply. Ash comes from Smelting and Cooking (wood ash by-product). Both are effectively free from other tradeskills' operations.
