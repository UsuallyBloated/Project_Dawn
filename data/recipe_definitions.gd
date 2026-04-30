class_name RecipeDefinitions

# All crafting recipes organized by tradeskill.
#
# Recipe fields:
#   name         — display name shown in the combine window
#   required_skill — minimum skill to attempt (0 = anyone can try)
#   trivial_at   — skill level where this recipe stops granting skill XP
#   ingredients  — Array of {item: String, qty: int}  (item matches ItemData.item_name)
#   output       — output item name (matches ItemData.item_name)
#   output_qty   — quantity produced per successful combine
#   tool         — required tool item name, not consumed ("" = none)
#   station      — required crafting station type ("" = none)
#                  valid stations: "forge", "alchemy_table", "kiln", "oven", "brewing_barrel"

const ALL: Dictionary = {

	# -----------------------------------------------------------------------
	# SMELTING — ore + fuel → ingots and metal stock
	# -----------------------------------------------------------------------
	"Smelting": [
		{
			"name": "Copper Ingot",
			"required_skill": 0, "trivial_at": 40,
			"ingredients": [{"item": "Copper Ore", "qty": 2}, {"item": "Coal", "qty": 1}],
			"output": "Copper Ingot", "output_qty": 1,
			"tool": "", "station": "forge"
		},
		{
			"name": "Iron Ingot",
			"required_skill": 50, "trivial_at": 90,
			"ingredients": [{"item": "Iron Ore", "qty": 2}, {"item": "Coal", "qty": 2}],
			"output": "Iron Ingot", "output_qty": 1,
			"tool": "", "station": "forge"
		},
		{
			"name": "Small Metal Sheet",
			"required_skill": 10, "trivial_at": 45,
			"ingredients": [{"item": "Metal Bits", "qty": 3}],
			"output": "Small Metal Sheet", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
	],

	# -----------------------------------------------------------------------
	# TANNING — raw hides and pelts → cured leather components
	# -----------------------------------------------------------------------
	"Tanning": [
		{
			"name": "Cured Leather Strip (Tattered)",
			"required_skill": 0, "trivial_at": 25,
			"ingredients": [{"item": "Tattered Pelt", "qty": 1}],
			"output": "Cured Leather Strip", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Cured Leather Strip (Damaged Wolf)",
			"required_skill": 0, "trivial_at": 35,
			"ingredients": [{"item": "Damaged Wolf Pelt", "qty": 1}],
			"output": "Cured Leather Strip", "output_qty": 2,
			"tool": "", "station": ""
		},
		{
			"name": "Cured Leather Strip (Fresh Wolf)",
			"required_skill": 5, "trivial_at": 40,
			"ingredients": [{"item": "Fresh Wolf Pelt", "qty": 1}],
			"output": "Cured Leather Strip", "output_qty": 3,
			"tool": "", "station": ""
		},
		{
			"name": "Cured Leather Strip (Pristine Wolf)",
			"required_skill": 15, "trivial_at": 55,
			"ingredients": [{"item": "Pristine Wolf Pelt", "qty": 1}],
			"output": "Cured Leather Strip", "output_qty": 4,
			"tool": "", "station": ""
		},
		{
			"name": "Cured Leather Strip (Snake Skin)",
			"required_skill": 10, "trivial_at": 50,
			"ingredients": [{"item": "Snake Skin", "qty": 1}],
			"output": "Cured Leather Strip", "output_qty": 2,
			"tool": "", "station": ""
		},
		{
			"name": "Thick Leather Slab (Boar)",
			"required_skill": 20, "trivial_at": 60,
			"ingredients": [{"item": "Boar Hide", "qty": 1}],
			"output": "Thick Leather Slab", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Thick Leather Slab (Bear)",
			"required_skill": 35, "trivial_at": 75,
			"ingredients": [{"item": "Bear Hide", "qty": 1}],
			"output": "Thick Leather Slab", "output_qty": 2,
			"tool": "", "station": ""
		},
	],

	# -----------------------------------------------------------------------
	# LEATHERWORKING — cured leather → leather armor
	# -----------------------------------------------------------------------
	"Leatherworking": [
		{
			"name": "Leather Cap",
			"required_skill": 25, "trivial_at": 65,
			"ingredients": [{"item": "Cured Leather Strip", "qty": 2}, {"item": "Sinew", "qty": 1}],
			"output": "Leather Cap", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Leather Gloves",
			"required_skill": 25, "trivial_at": 65,
			"ingredients": [{"item": "Cured Leather Strip", "qty": 2}, {"item": "Sinew", "qty": 1}],
			"output": "Leather Gloves", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Leather Boots",
			"required_skill": 30, "trivial_at": 70,
			"ingredients": [{"item": "Cured Leather Strip", "qty": 2}, {"item": "Sinew", "qty": 1}],
			"output": "Leather Boots", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Leather Leggings",
			"required_skill": 35, "trivial_at": 75,
			"ingredients": [{"item": "Cured Leather Strip", "qty": 3}, {"item": "Sinew", "qty": 2}],
			"output": "Leather Leggings", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Leather Vest",
			"required_skill": 40, "trivial_at": 80,
			"ingredients": [{"item": "Cured Leather Strip", "qty": 4}, {"item": "Sinew", "qty": 2}],
			"output": "Leather Vest", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Leather Boots (Thick)",
			"required_skill": 55, "trivial_at": 95,
			"ingredients": [{"item": "Thick Leather Slab", "qty": 1}, {"item": "Sinew", "qty": 2}],
			"output": "Leather Boots", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
	],

	# -----------------------------------------------------------------------
	# TAILORING — cloth scraps + thread → cloth armor
	# -----------------------------------------------------------------------
	"Tailoring": [
		{
			"name": "Cloth Cap",
			"required_skill": 10, "trivial_at": 50,
			"ingredients": [{"item": "Cloth Scraps", "qty": 2}, {"item": "Linen Thread", "qty": 1}],
			"output": "Cloth Cap", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Cloth Gloves",
			"required_skill": 10, "trivial_at": 50,
			"ingredients": [{"item": "Cloth Scraps", "qty": 2}, {"item": "Linen Thread", "qty": 1}],
			"output": "Cloth Gloves", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Cloth Slippers",
			"required_skill": 10, "trivial_at": 50,
			"ingredients": [{"item": "Cloth Scraps", "qty": 2}, {"item": "Linen Thread", "qty": 1}],
			"output": "Cloth Slippers", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Cloth Pants",
			"required_skill": 15, "trivial_at": 55,
			"ingredients": [{"item": "Cloth Scraps", "qty": 3}, {"item": "Linen Thread", "qty": 2}],
			"output": "Cloth Pants", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Cloth Robe",
			"required_skill": 20, "trivial_at": 60,
			"ingredients": [{"item": "Cloth Scraps", "qty": 4}, {"item": "Linen Thread", "qty": 2}],
			"output": "Cloth Robe", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
		{
			"name": "Cloth Robe (Silk)",
			"required_skill": 60, "trivial_at": 100,
			"ingredients": [
				{"item": "Thick Silk Thread", "qty": 4},
				{"item": "Spiderling Silk", "qty": 2},
				{"item": "Linen Thread", "qty": 2}
			],
			"output": "Cloth Robe", "output_qty": 1,
			"tool": "Sewing Needle", "station": ""
		},
	],

	# -----------------------------------------------------------------------
	# BLACKSMITHING — ingots → chain armor
	# -----------------------------------------------------------------------
	"Blacksmithing": [
		{
			"name": "Copper Chain Vest",
			"required_skill": 30, "trivial_at": 70,
			"ingredients": [{"item": "Copper Ingot", "qty": 4}],
			"output": "Copper Chain Vest", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
		{
			"name": "Iron Chain Gloves",
			"required_skill": 55, "trivial_at": 95,
			"ingredients": [{"item": "Iron Ingot", "qty": 2}],
			"output": "Iron Chain Gloves", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
		{
			"name": "Iron Chain Boots",
			"required_skill": 55, "trivial_at": 95,
			"ingredients": [{"item": "Iron Ingot", "qty": 3}],
			"output": "Iron Chain Boots", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
		{
			"name": "Iron Chain Coif",
			"required_skill": 60, "trivial_at": 100,
			"ingredients": [{"item": "Iron Ingot", "qty": 2}],
			"output": "Iron Chain Coif", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
		{
			"name": "Iron Chain Leggings",
			"required_skill": 65, "trivial_at": 105,
			"ingredients": [{"item": "Iron Ingot", "qty": 4}],
			"output": "Iron Chain Leggings", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
		{
			"name": "Iron Chain Vest",
			"required_skill": 75, "trivial_at": 115,
			"ingredients": [{"item": "Iron Ingot", "qty": 5}],
			"output": "Iron Chain Vest", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
	],

	# -----------------------------------------------------------------------
	# WEAPONSMITHING — ingots → melee weapons
	# -----------------------------------------------------------------------
	"Weaponsmithing": [
		{
			"name": "Copper Dagger",
			"required_skill": 20, "trivial_at": 60,
			"ingredients": [{"item": "Copper Ingot", "qty": 2}],
			"output": "Copper Dagger", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
		{
			"name": "Copper Short Sword",
			"required_skill": 30, "trivial_at": 70,
			"ingredients": [{"item": "Copper Ingot", "qty": 3}],
			"output": "Copper Short Sword", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
		{
			"name": "Iron Dagger",
			"required_skill": 55, "trivial_at": 95,
			"ingredients": [{"item": "Iron Ingot", "qty": 2}],
			"output": "Iron Dagger", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
		{
			"name": "Iron Short Sword",
			"required_skill": 70, "trivial_at": 110,
			"ingredients": [{"item": "Iron Ingot", "qty": 4}],
			"output": "Iron Short Sword", "output_qty": 1,
			"tool": "Smithing Hammer", "station": "forge"
		},
	],

	# -----------------------------------------------------------------------
	# WOODWORKING — timber → staves and utility items
	# -----------------------------------------------------------------------
	"Woodworking": [
		{
			"name": "Carved Staff",
			"required_skill": 25, "trivial_at": 65,
			"ingredients": [{"item": "Hardwood Shaft", "qty": 2}, {"item": "Pliable Wood", "qty": 1}],
			"output": "Carved Staff", "output_qty": 1,
			"tool": "", "station": ""
		},
	],

	# -----------------------------------------------------------------------
	# FLETCHING — shafts + heads + fletching → arrows
	# -----------------------------------------------------------------------
	"Fletching": [
		{
			"name": "Arrow Bundle",
			"required_skill": 0, "trivial_at": 40,
			"ingredients": [
				{"item": "Hardwood Shaft", "qty": 5},
				{"item": "Flint Arrowhead", "qty": 5},
				{"item": "Arrow Fletching", "qty": 5}
			],
			"output": "Arrow Bundle", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Arrow Bundle (Feathered)",
			"required_skill": 25, "trivial_at": 65,
			"ingredients": [
				{"item": "Hardwood Shaft", "qty": 5},
				{"item": "Flint Arrowhead", "qty": 5},
				{"item": "Feather", "qty": 5}
			],
			"output": "Arrow Bundle", "output_qty": 1,
			"tool": "", "station": ""
		},
	],

	# -----------------------------------------------------------------------
	# ALCHEMY — herbs and essences → potions and elixirs
	# -----------------------------------------------------------------------
	"Alchemy": [
		{
			"name": "Minor Healing Potion",
			"required_skill": 0, "trivial_at": 40,
			"ingredients": [
				{"item": "Feverfew", "qty": 1},
				{"item": "Bloodmoss", "qty": 1},
				{"item": "Empty Vial", "qty": 1}
			],
			"output": "Minor Healing Potion", "output_qty": 1,
			"tool": "", "station": "alchemy_table"
		},
		{
			"name": "Healing Potion",
			"required_skill": 50, "trivial_at": 90,
			"ingredients": [
				{"item": "Feverfew", "qty": 2},
				{"item": "Bloodmoss", "qty": 2},
				{"item": "Empty Vial", "qty": 1}
			],
			"output": "Healing Potion", "output_qty": 1,
			"tool": "", "station": "alchemy_table"
		},
		{
			"name": "Antidote",
			"required_skill": 20, "trivial_at": 60,
			"ingredients": [{"item": "Wormwood", "qty": 2}, {"item": "Empty Vial", "qty": 1}],
			"output": "Antidote", "output_qty": 1,
			"tool": "", "station": "alchemy_table"
		},
		{
			"name": "Mana Potion",
			"required_skill": 35, "trivial_at": 75,
			"ingredients": [
				{"item": "Ice Essence", "qty": 1},
				{"item": "Wormwood", "qty": 1},
				{"item": "Empty Vial", "qty": 1}
			],
			"output": "Mana Potion", "output_qty": 1,
			"tool": "", "station": "alchemy_table"
		},
		{
			"name": "Fire Elixir",
			"required_skill": 30, "trivial_at": 70,
			"ingredients": [{"item": "Fire Essence", "qty": 1}, {"item": "Empty Vial", "qty": 1}],
			"output": "Fire Elixir", "output_qty": 1,
			"tool": "", "station": "alchemy_table"
		},
		{
			"name": "Shadow Draught",
			"required_skill": 40, "trivial_at": 80,
			"ingredients": [
				{"item": "Shadow Essence", "qty": 1},
				{"item": "Bat Blood", "qty": 1},
				{"item": "Empty Vial", "qty": 1}
			],
			"output": "Shadow Draught", "output_qty": 1,
			"tool": "", "station": "alchemy_table"
		},
	],

	# -----------------------------------------------------------------------
	# POISON MAKING — venoms and nightshade → combat poisons
	# Restricted: evil-aligned, Rogue/Necromancer/Shadow Knight/Blood Mage/Dark Elf
	# -----------------------------------------------------------------------
	"Poison Making": [
		{
			"name": "Poison Vial",
			"required_skill": 25, "trivial_at": 65,
			"ingredients": [
				{"item": "Nightshade", "qty": 2},
				{"item": "Snake Venom Sac", "qty": 1},
				{"item": "Empty Vial", "qty": 1}
			],
			"output": "Poison Vial", "output_qty": 1,
			"tool": "", "station": "alchemy_table"
		},
		{
			"name": "Potent Poison",
			"required_skill": 60, "trivial_at": 100,
			"ingredients": [
				{"item": "Nightshade", "qty": 3},
				{"item": "Spider Venom Sac", "qty": 2},
				{"item": "Empty Vial", "qty": 1}
			],
			"output": "Poison Vial", "output_qty": 2,
			"tool": "", "station": "alchemy_table"
		},
	],

	# -----------------------------------------------------------------------
	# BAKING — flour, eggs, and foraged food → cooked meals
	# -----------------------------------------------------------------------
	"Baking": [
		{
			"name": "Bread Loaf",
			"required_skill": 0, "trivial_at": 35,
			"ingredients": [{"item": "Flour", "qty": 2}, {"item": "Water Flask", "qty": 1}],
			"output": "Bread Loaf", "output_qty": 1,
			"tool": "", "station": "oven"
		},
		{
			"name": "Meat Pie",
			"required_skill": 15, "trivial_at": 55,
			"ingredients": [
				{"item": "Wolf Meat", "qty": 1},
				{"item": "Flour", "qty": 1},
				{"item": "Raw Egg", "qty": 1}
			],
			"output": "Meat Pie", "output_qty": 1,
			"tool": "", "station": "oven"
		},
		{
			"name": "Mushroom Bread",
			"required_skill": 20, "trivial_at": 60,
			"ingredients": [
				{"item": "Wild Mushroom", "qty": 2},
				{"item": "Flour", "qty": 2},
				{"item": "Water Flask", "qty": 1}
			],
			"output": "Mushroom Bread", "output_qty": 1,
			"tool": "", "station": "oven"
		},
		{
			"name": "Berry Tart",
			"required_skill": 25, "trivial_at": 65,
			"ingredients": [
				{"item": "Wild Berries", "qty": 3},
				{"item": "Flour", "qty": 1},
				{"item": "Honey", "qty": 1}
			],
			"output": "Berry Tart", "output_qty": 1,
			"tool": "", "station": "oven"
		},
	],

	# -----------------------------------------------------------------------
	# BREWING — barley, hops, honey, yeast → ales and meads
	# -----------------------------------------------------------------------
	"Brewing": [
		{
			"name": "Crude Ale",
			"required_skill": 0, "trivial_at": 40,
			"ingredients": [
				{"item": "Barley", "qty": 1},
				{"item": "Hops", "qty": 1},
				{"item": "Yeast", "qty": 1},
				{"item": "Water Flask", "qty": 1},
				{"item": "Empty Bottle", "qty": 1}
			],
			"output": "Crude Ale", "output_qty": 1,
			"tool": "", "station": "brewing_barrel"
		},
		{
			"name": "Honey Mead",
			"required_skill": 20, "trivial_at": 60,
			"ingredients": [
				{"item": "Honey", "qty": 3},
				{"item": "Yeast", "qty": 1},
				{"item": "Empty Bottle", "qty": 1}
			],
			"output": "Honey Mead", "output_qty": 1,
			"tool": "", "station": "brewing_barrel"
		},
	],

	# -----------------------------------------------------------------------
	# JEWELRY CRAFTING — wire, settings, and gems → rings and jewelry
	# -----------------------------------------------------------------------
	"Jewelry Crafting": [
		{
			"name": "Silver Ring",
			"required_skill": 10, "trivial_at": 50,
			"ingredients": [
				{"item": "Silver Wire", "qty": 2},
				{"item": "Tarnished Silver Setting", "qty": 1}
			],
			"output": "Silver Ring", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Rough Ruby Ring",
			"required_skill": 20, "trivial_at": 60,
			"ingredients": [{"item": "Silver Wire", "qty": 2}, {"item": "Rough Ruby", "qty": 1}],
			"output": "Rough Ruby Ring", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Rough Sapphire Ring",
			"required_skill": 25, "trivial_at": 65,
			"ingredients": [{"item": "Silver Wire", "qty": 2}, {"item": "Rough Sapphire", "qty": 1}],
			"output": "Rough Sapphire Ring", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Rough Emerald Ring",
			"required_skill": 30, "trivial_at": 70,
			"ingredients": [{"item": "Gold Wire", "qty": 2}, {"item": "Rough Emerald", "qty": 1}],
			"output": "Rough Emerald Ring", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Rough Topaz Ring",
			"required_skill": 35, "trivial_at": 75,
			"ingredients": [{"item": "Gold Wire", "qty": 2}, {"item": "Rough Topaz", "qty": 1}],
			"output": "Rough Topaz Ring", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Rough Opal Ring",
			"required_skill": 40, "trivial_at": 80,
			"ingredients": [{"item": "Silver Wire", "qty": 2}, {"item": "Rough Opal", "qty": 1}],
			"output": "Rough Opal Ring", "output_qty": 1,
			"tool": "", "station": ""
		},
	],

	# -----------------------------------------------------------------------
	# POTTERY — clay → unfired pottery → fired goods (kiln required to fire)
	# -----------------------------------------------------------------------
	"Pottery": [
		{
			"name": "Unfired Pottery",
			"required_skill": 0, "trivial_at": 35,
			"ingredients": [{"item": "Lump of Clay", "qty": 3}],
			"output": "Unfired Pottery", "output_qty": 1,
			"tool": "", "station": ""
		},
		{
			"name": "Fired Clay Bowl",
			"required_skill": 0, "trivial_at": 35,
			"ingredients": [{"item": "Unfired Pottery", "qty": 1}],
			"output": "Fired Clay Bowl", "output_qty": 1,
			"tool": "", "station": "kiln"
		},
	],

	# -----------------------------------------------------------------------
	# TINKERING — gears, springs, and metal → mechanical devices
	# Restricted: Gnome and Kobold races only
	# -----------------------------------------------------------------------
	"Tinkering": [
		{
			"name": "Mechanical Trap",
			"required_skill": 30, "trivial_at": 70,
			"ingredients": [
				{"item": "Small Gear", "qty": 2},
				{"item": "Coiled Spring", "qty": 1},
				{"item": "Small Metal Plate", "qty": 1}
			],
			"output": "Mechanical Trap", "output_qty": 1,
			"tool": "Tinkering Kit", "station": ""
		},
		{
			"name": "Crude Clockwork",
			"required_skill": 50, "trivial_at": 90,
			"ingredients": [
				{"item": "Small Gear", "qty": 3},
				{"item": "Coiled Spring", "qty": 2},
				{"item": "Small Metal Plate", "qty": 1}
			],
			"output": "Crude Clockwork", "output_qty": 1,
			"tool": "Tinkering Kit", "station": ""
		},
	],
}

static func get_by_tradeskill(tradeskill: String) -> Array:
	return ALL.get(tradeskill, [])

static func get_all() -> Array:
	var result: Array = []
	for recipes in ALL.values():
		result.append_array(recipes)
	return result

static func find_by_output(item_name: String) -> Array:
	var result: Array = []
	for recipes in ALL.values():
		for recipe in recipes:
			if recipe.output == item_name:
				result.append(recipe)
	return result
