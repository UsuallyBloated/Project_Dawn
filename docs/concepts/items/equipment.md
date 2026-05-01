# Equipment

Craftable weapons, armor, and jewelry. These are final-output items that go into the player's equipment slots (paperdoll).

Stat values are not listed here — define them in the GDScript item definitions once the item data pipeline is built. This doc tracks what exists as a craftable recipe.

---

## Cloth Armor

**Tradeskill:** Tailoring | **Tool:** Sewing Needle | **Armor type:** Cloth | **Classes:** Wizard, Sorcerer, Magician, Enchanter, Necromancer, Blood Mage, Bard

| Item | Slot | Ingredients | Min Skill |
|---|---|---|---|
| Cloth Cap | Head | 2× Cloth Scraps + Linen Thread | 10 |
| Cloth Gloves | Hands | 2× Cloth Scraps + Linen Thread | 10 |
| Cloth Slippers | Feet | 2× Cloth Scraps + Linen Thread | 10 |
| Cloth Pants | Legs | 3× Cloth Scraps + 2× Linen Thread | 15 |
| Cloth Robe | Chest | 4× Cloth Scraps + 2× Linen Thread | 20 |
| Cloth Robe (Silk) | Chest | 4× Thick Silk Thread + 2× Spiderling Silk + 2× Linen Thread | 60 |

---

## Leather Armor

**Tradeskill:** Leatherworking | **Tool:** Sewing Needle | **Armor type:** Leather | **Classes:** Rogue, Monk, Bard, Ranger, Beast Master, Witch Hunter, Druid, Shaman

| Item | Slot | Ingredients | Min Skill |
|---|---|---|---|
| Leather Cap | Head | 2× Cured Leather Strip + Sinew | 25 |
| Leather Gloves | Hands | 2× Cured Leather Strip + Sinew | 25 |
| Leather Boots | Feet | 2× Cured Leather Strip + Sinew | 30 |
| Leather Boots (Thick) | Feet | Thick Leather Slab + 2× Sinew | 55 |
| Leather Leggings | Legs | 3× Cured Leather Strip + 2× Sinew | 35 |
| Leather Vest | Chest | 4× Cured Leather Strip + 2× Sinew | 40 |

---

## Chain Armor

**Tradeskill:** Blacksmithing | **Tool:** Smithing Hammer | **Station:** Forge | **Armor type:** Chain | **Classes:** Paladin, Cleric, Shadow Knight, Shaman, Bard (some), Ranger

### Copper Tier

| Item | Slot | Ingredients | Min Skill |
|---|---|---|---|
| Copper Chain Vest | Chest | 4× Copper Ingot | 30 |

*Copper chain set is incomplete — add Coif, Gloves, Boots, Leggings to recipe_definitions.gd for a full set.*

### Iron Tier

| Item | Slot | Ingredients | Min Skill |
|---|---|---|---|
| Iron Chain Gloves | Hands | 2× Iron Ingot | 55 |
| Iron Chain Boots | Feet | 3× Iron Ingot | 55 |
| Iron Chain Coif | Head | 2× Iron Ingot | 60 |
| Iron Chain Leggings | Legs | 4× Iron Ingot | 65 |
| Iron Chain Vest | Chest | 5× Iron Ingot | 75 |

### Planned Tiers (not yet in recipe file)

| Tier | Ore | Notes |
|---|---|---|
| Silver | Silver Ingot | Effective vs. undead; Witch Hunter demand |
| Mithril | Mithril Ingot | Highest standard tier |
| Adamantite | Adamantite Ingot | Legendary |

---

## Plate Armor

*Plate armor recipes not yet in `recipe_definitions.gd`. Add under Blacksmithing (Armorsmithing specialization). Classes: Warrior, Paladin, Shadow Knight.*

---

## Weapons

### One-Handed — Smithed

**Tradeskill:** Weaponsmithing | **Tool:** Smithing Hammer | **Station:** Forge

| Item | Type | Ingredients | Min Skill |
|---|---|---|---|
| Copper Dagger | 1H Piercing | 2× Copper Ingot | 20 |
| Copper Short Sword | 1H Slashing | 3× Copper Ingot | 30 |
| Iron Dagger | 1H Piercing | 2× Iron Ingot | 55 |
| Iron Short Sword | 1H Slashing | 4× Iron Ingot | 70 |

### Two-Handed — Woodworking

**Tradeskill:** Woodworking | **Station:** None

| Item | Type | Ingredients | Min Skill |
|---|---|---|---|
| Carved Staff | 2H Blunt / Caster Focus | 2× Hardwood Shaft + Pliable Wood | 25 |

### Ranged

*Bow and crossbow recipes not yet in `recipe_definitions.gd`. Required for Ranger ranged combat. Add under Woodworking (Bowyer specialization).*

### Arrows / Ammunition

**Tradeskill:** Fletching | **Station:** None

| Item | Ingredients | Min Skill | Output |
|---|---|---|---|
| Arrow Bundle | 5× Hardwood Shaft + 5× Flint Arrowhead + 5× Arrow Fletching | 0 | 1 bundle |
| Arrow Bundle (Feathered) | 5× Hardwood Shaft + 5× Flint Arrowhead + 5× Feather | 25 | 1 bundle |

*Bundle count (arrows per bundle) needs to be defined. Recommend: 20 arrows per bundle.*

---

## Jewelry

**Tradeskill:** Jewelry Crafting | **Station:** None | **Feeds from:** Smelting (wire), Mining (gems)

| Item | Slot | Ingredients | Min Skill |
|---|---|---|---|
| Silver Ring | Ring | 2× Silver Wire + Tarnished Silver Setting | 10 |
| Rough Ruby Ring | Ring | 2× Silver Wire + Rough Ruby | 20 |
| Rough Sapphire Ring | Ring | 2× Silver Wire + Rough Sapphire | 25 |
| Rough Emerald Ring | Ring | 2× Gold Wire + Rough Emerald | 30 |
| Rough Topaz Ring | Ring | 2× Gold Wire + Rough Topaz | 35 |
| Rough Opal Ring | Ring | 2× Silver Wire + Rough Opal | 40 |

*Necklace/Neck slot recipes not yet defined.*

---

## Planned Equipment (Not Yet in Recipe File)

| Category | Notes |
|---|---|
| Plate armor (full set) | Blacksmithing/Armorsmithing specialization |
| Mithril / Adamantite gear | High-tier smithing |
| Scale armor (Drake, Dragon) | Leatherworking from exotic hides |
| Shadow Weave armor | Dark Elf exclusive tradeskill |
| Bone Carving weapons/trinkets | Ogre/Troll exclusive |
| Bows and crossbows | Woodworking (Bowyer spec); required for Ranger |
| Necklaces | Jewelry Crafting |
| Runeforged gear | Dwarf prestige path (Blacksmithing 150+) |
| Tinkered devices | Gnome/Kobold — Clockwork automata, traps |
