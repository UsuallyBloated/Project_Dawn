class_name QuestDefinitions

# All quest data. Key = quest id (must match dialogue "quest_id" fields).
#
# Quest fields:
#   id, name, description, zone, level_req, xp_reward
#   objectives: Array of {text, type ("kill"), target (mob name), count_needed}
#   item_rewards: Array of item dicts (same schema as NamedMobDefinitions items)
#   giver_npc, turn_in_npc: NPC name strings (informational; dialogue wires the actual flow)

const ALL: Dictionary = {
	"wolf_threat": {
		"id": "wolf_threat",
		"name": "The Wolf Threat",
		"description": "Wolves have been attacking travelers on the roads near Valdis. The garrison needs someone to thin their numbers before more people get hurt.",
		"zone": "Valdis Wilds",
		"level_req": 1,
		"xp_reward": 150,
		"objectives": [
			{"text": "Kill wolves near Valdis", "type": "kill", "target": "Wolf", "count_needed": 5}
		],
		"item_rewards": [
			{
				"name": "Tarnished Silver Ring",
				"desc": "A plain ring given as payment for services rendered.",
				"type": "RING",
				"rarity": "COMMON",
				"vendor_price": 30,
				"bonus_agility": 1
			}
		],
		"giver_npc": "Aldric the Guard",
		"turn_in_npc": "Aldric the Guard"
	},

	"rat_infestation": {
		"id": "rat_infestation",
		"name": "Rat Infestation",
		"description": "Rats have gotten into the provisioner's storage cellar and spoiled half the supplies. Clear them out before the problem spreads.",
		"zone": "Valdis",
		"level_req": 1,
		"xp_reward": 80,
		"objectives": [
			{"text": "Kill rats in the cellar", "type": "kill", "target": "Rat", "count_needed": 8}
		],
		"item_rewards": [],
		"giver_npc": "Brom",
		"turn_in_npc": "Brom"
	},

	"gnoll_raiders": {
		"id": "gnoll_raiders",
		"name": "Drive Back the Raiders",
		"description": "Gnoll war parties have been raiding supply routes east of town. Brom needs someone to hit them hard enough to buy the caravans some breathing room.",
		"zone": "Gnoll Flats",
		"level_req": 3,
		"xp_reward": 350,
		"objectives": [
			{"text": "Kill gnoll raiders", "type": "kill", "target": "Gnoll", "count_needed": 8}
		],
		"item_rewards": [
			{
				"name": "Scout's Leather Boots",
				"desc": "Sturdy boots stripped from a gnoll patrol leader. Well-made despite their origin.",
				"type": "FEET",
				"rarity": "UNCOMMON",
				"vendor_price": 65,
				"bonus_agility": 2,
				"bonus_armor": 6
			}
		],
		"giver_npc": "Brom",
		"turn_in_npc": "Brom"
	},

	"rotfang_hunt": {
		"id": "rotfang_hunt",
		"name": "Hunt the Beast",
		"description": "Rotfang the Feared has killed three hunters this month. The garrison will pay well for proof of its death. Bring back Rotfang's Fang.",
		"zone": "Valdis Wilds",
		"level_req": 5,
		"xp_reward": 600,
		"objectives": [
			{"text": "Kill Rotfang the Feared", "type": "kill", "target": "Rotfang", "count_needed": 1}
		],
		"item_rewards": [
			{
				"name": "Hunter's Medal",
				"desc": "Awarded by the Valdis garrison for outstanding service. Worn with pride.",
				"type": "NECK",
				"rarity": "UNCOMMON",
				"vendor_price": 100,
				"bonus_strength": 2,
				"bonus_constitution": 2
			}
		],
		"giver_npc": "Aldric the Guard",
		"turn_in_npc": "Aldric the Guard"
	}
}
