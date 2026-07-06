class_name QuestDefinitions

# All quest data. Key = quest id (must match dialogue "quest_id" fields).
#
# Quest fields:
#   id, name, description, zone, level_req, reward_tier
#   objectives: Array of {text, type ("kill"), target (mob name), count_needed}
#   item_rewards: Array of item dicts (same schema as NamedMobDefinitions items)
#   giver_npc, turn_in_npc: NPC name strings (informational; dialogue wires the actual flow)

# Quest XP is a difficulty TIER expressed as a fraction of ONE level at the
# quest's level_req. A low-level quest is a meaningful chunk to a same-level
# character but "gray" (negligible) to a high-level one — classic EQ. (Faction,
# when that system exists, is the parallel draw for high-levels doing low content;
# quests will grow a `faction_rewards` field then.) Tweak the whole quest XP
# economy from this one table — every quest of a tier moves together:
const REWARD_TIERS := {
	"trivial":  0.15,  # a quick fetch / a few weak kills
	"standard": 0.30,  # the bread-and-butter kill-several
	"hard":     0.50,  # many kills / tougher, a mini-boss
	"named":    0.80,  # a named-boss quest
}

# XP a quest grants at turn-in: tier% of the cubic band at its level_req (fixed
# per quest, NOT scaled to the turn-in-er's level — that's what keeps it gray to
# high-levels). An unknown tier yields 0, surfacing a typo as "no reward".
static func xp_reward_for(tier: String, level_req: int) -> int:
	return roundi(float(REWARD_TIERS.get(tier, 0.0)) * PlayerStats.band_for(level_req))

const ALL: Dictionary = {
	"wolf_threat": {
		"id": "wolf_threat",
		"name": "The Wolf Threat",
		"description": "Wolves have been attacking travelers on the roads near Valdis. The garrison needs someone to thin their numbers before more people get hurt.",
		"zone": "Valdis Wilds",
		"level_req": 1,
		"reward_tier": "standard",
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
		"reward_tier": "trivial",
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
		"reward_tier": "standard",
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
		"reward_tier": "named",
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
