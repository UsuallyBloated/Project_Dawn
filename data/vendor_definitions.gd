class_name VendorDefinitions

# Vendor type name -> { "desc": String, "stock": Array[String] of item_name }
const ALL: Dictionary = {
	"General Merchant": {
		"desc": "Basic goods, food, and everyday supplies.",
		"stock": [
			"Cloth Scraps", "Coal", "Salt", "Flour", "Raw Egg", "Honey",
			"Bread Loaf", "Stale Bread", "Crude Ale", "Water Flask",
			"Empty Bottle", "Empty Vial", "Minor Healing Potion",
			"Wild Berries", "Wild Fruit", "Wild Mushroom",
		],
	},
	"Alchemist": {
		"desc": "Potions, reagents, and magical concoctions.",
		"stock": [
			"Crude Health Potion", "Minor Healing Potion", "Healing Potion",
			"Mana Potion", "Antidote", "Fire Elixir", "Shadow Draught", "Poison Vial",
			"Bloodmoss", "Nightshade", "Wormwood", "Bat Blood", "Feverfew",
			"Snake Venom Sac", "Spider Venom Sac", "Fire Essence", "Ice Essence",
			"Shadow Essence", "Empty Vial", "Empty Bottle",
		],
	},
	"Blacksmith": {
		"desc": "Metal goods, weapons, and chain armor.",
		"stock": [
			"Copper Ore", "Iron Ore", "Coal", "Copper Ingot", "Iron Ingot",
			"Metal Bits", "Small Metal Plate", "Small Metal Sheet",
			"Smithing Hammer", "Ruined Metal Scraps",
			"Copper Dagger", "Iron Dagger", "Copper Short Sword", "Iron Short Sword",
			"Copper Chain Vest", "Iron Chain Vest", "Iron Chain Coif",
			"Iron Chain Boots", "Iron Chain Gloves", "Iron Chain Leggings",
		],
	},
	"Leatherworker": {
		"desc": "Hides, leather goods, and leather armor.",
		"stock": [
			"Boar Hide", "Bear Hide", "Sinew", "Cured Leather Strip", "Thick Leather Slab",
			"Leather Cap", "Leather Vest", "Leather Gloves",
			"Leather Boots", "Leather Leggings",
		],
	},
	"Tailor": {
		"desc": "Cloth, thread, and fabric armor.",
		"stock": [
			"Cloth Scraps", "Linen Thread", "Thick Silk Thread",
			"Sewing Needle", "Spiderling Silk", "Ruined Silk", "Feather",
			"Cloth Cap", "Cloth Robe", "Cloth Pants",
			"Cloth Gloves", "Cloth Slippers",
		],
	},
	"Fletcher": {
		"desc": "Arrows, bows, and woodcraft supplies.",
		"stock": [
			"Arrow Fletching", "Flint Arrowhead", "Feather", "Sinew",
			"Hardwood Shaft", "Pliable Wood", "Arrow Bundle",
		],
	},
	"Jeweler": {
		"desc": "Gems, precious metals, and fine jewelry.",
		"stock": [
			"Rough Ruby", "Rough Sapphire", "Rough Emerald", "Rough Topaz", "Rough Opal",
			"Gold Wire", "Silver Wire", "Tarnished Silver Setting",
			"Silver Ring", "Rough Ruby Ring", "Rough Sapphire Ring",
			"Rough Emerald Ring", "Rough Topaz Ring", "Rough Opal Ring",
		],
	},
	"Provisioner": {
		"desc": "Food, drink, and cooking ingredients.",
		"stock": [
			"Flour", "Salt", "Raw Egg", "Honey", "Wild Berries", "Wild Fruit",
			"Wild Mushroom", "Yeast", "Hops", "Barley",
			"Bread Loaf", "Meat Pie", "Mushroom Bread",
			"Berry Tart", "Crude Ale", "Honey Mead", "Water Flask",
		],
	},
	"Tinkerer": {
		"desc": "Mechanical parts and clockwork devices.",
		"stock": [
			"Small Gear", "Coiled Spring", "Metal Bits",
			"Tinkering Kit", "Crude Clockwork", "Mechanical Trap",
		],
	},
	"Pottery Vendor": {
		"desc": "Clay goods and ceramics.",
		"stock": [
			"Lump of Clay", "Pottery Sketch", "Unfired Pottery", "Fired Clay Bowl",
		],
	},
}
