class_name NamedMobDefinitions

# Named / boss mob data. Key = named_id string used in EnemySpawner.
#
# Fields:
#   display_name      — shown in nameplate
#   subtitle          — appended after display_name ("Rotfang the Feared")
#   hp_mult           — multiplied against the base scene's max_hp
#   damage_mult       — multiplied against base_damage and spell_damage at attack time
#   xp_mult           — multiplied against xp_reward
#   level             — overrides the scene level
#   enrage_threshold  — fraction (0.0–1.0); enrage fires once when hp/max_hp drops below; 0 = disabled
#   enrage_damage_mult — additional damage multiplier applied during enrage (stacks on damage_mult)
#   enrage_speed_mult  — move speed multiplier during enrage
#   guaranteed_loot   — Array of item dicts; always drops (one entry = one item in the bag)
#   rare_loot         — Array of item dicts with drop_chance field; rolled at spawn time
#
# Item dict fields (all optional beyond "name"):
#   name, desc, type (ItemData.Type key string), rarity, vendor_price
#   bonus_strength/agility/dexterity/intelligence/wisdom/constitution
#   bonus_max_hp, bonus_max_mp, bonus_armor
#   weapon_damage_min, weapon_damage_max, weapon_delay, weapon_skill, is_two_handed

const ALL: Dictionary = {
	"rotfang": {
		"display_name": "Rotfang",
		"subtitle": "the Feared",
		"hp_mult": 3.5,
		"damage_mult": 1.8,
		"xp_mult": 4.0,
		"level": 6,
		"enrage_threshold": 0.20,
		"enrage_damage_mult": 1.4,
		"enrage_speed_mult": 1.3,
		"guaranteed_loot": [
			{
				"name": "Rotfang's Fang",
				"desc": "A massive yellowed fang ripped from the beast's jaw. Prized by hunters.",
				"type": "MISC",
				"rarity": "UNCOMMON",
				"vendor_price": 20
			}
		],
		"rare_loot": [
			{
				"name": "Predator's Collar",
				"desc": "A crude loop of cured hide strung with wolf teeth. Worn by the pack's champion.",
				"type": "NECK",
				"rarity": "UNCOMMON",
				"vendor_price": 85,
				"bonus_strength": 3,
				"bonus_agility": 2,
				"drop_chance": 0.30
			}
		]
	},

	"greth": {
		"display_name": "Greth Bonecrusher",
		"subtitle": "",
		"hp_mult": 4.0,
		"damage_mult": 2.0,
		"xp_mult": 5.0,
		"level": 10,
		"enrage_threshold": 0.25,
		"enrage_damage_mult": 1.5,
		"enrage_speed_mult": 1.2,
		"guaranteed_loot": [
			{
				"name": "Gnoll Chief's Seal",
				"desc": "A stamped iron disc marking Greth's authority over the Flats gnolls.",
				"type": "MISC",
				"rarity": "UNCOMMON",
				"vendor_price": 25
			}
		],
		"rare_loot": [
			{
				"name": "Bonecrusher's War Axe",
				"desc": "A brutishly large axe, well-maintained despite its crude appearance.",
				"type": "WEAPON",
				"rarity": "RARE",
				"vendor_price": 220,
				"weapon_damage_min": 12,
				"weapon_damage_max": 24,
				"weapon_delay": 3.2,
				"weapon_skill": "2h_blunt",
				"is_two_handed": true,
				"bonus_strength": 5,
				"drop_chance": 0.25
			}
		]
	},

	"ancient_crawler": {
		"display_name": "Ancient Crawler",
		"subtitle": "",
		"hp_mult": 3.0,
		"damage_mult": 1.6,
		"xp_mult": 3.5,
		"level": 8,
		"enrage_threshold": 0.30,
		"enrage_damage_mult": 1.3,
		"enrage_speed_mult": 1.4,
		"guaranteed_loot": [
			{
				"name": "Pristine Venom Sac",
				"desc": "Intact and full — a rare find. Alchemists pay well for these.",
				"type": "MISC",
				"rarity": "UNCOMMON",
				"vendor_price": 35
			}
		],
		"rare_loot": [
			{
				"name": "Chitinous Ring",
				"desc": "A ring cut from the creature's carapace, hardened by decades in the dark.",
				"type": "RING",
				"rarity": "RARE",
				"vendor_price": 160,
				"bonus_agility": 4,
				"bonus_constitution": 3,
				"bonus_max_hp": 30.0,
				"drop_chance": 0.25
			}
		]
	},

	"sable": {
		"display_name": "Sable",
		"subtitle": "the Dark",
		"hp_mult": 2.5,
		"damage_mult": 1.5,
		"xp_mult": 3.0,
		"level": 5,
		"enrage_threshold": 0.0,
		"enrage_damage_mult": 1.0,
		"enrage_speed_mult": 1.0,
		"guaranteed_loot": [
			{
				"name": "Sable Wing Membrane",
				"desc": "Thin as parchment and dark as a moonless sky. Sought by leatherworkers.",
				"type": "MISC",
				"rarity": "UNCOMMON",
				"vendor_price": 15
			}
		],
		"rare_loot": [
			{
				"name": "Shadow Signet",
				"desc": "A ring of polished jet. Seems to absorb light around it.",
				"type": "RING",
				"rarity": "UNCOMMON",
				"vendor_price": 120,
				"bonus_agility": 3,
				"bonus_intelligence": 2,
				"bonus_max_mp": 20.0,
				"drop_chance": 0.20
			}
		]
	},

	"the_undying": {
		"display_name": "The Undying",
		"subtitle": "",
		"hp_mult": 5.0,
		"damage_mult": 2.2,
		"xp_mult": 6.0,
		"level": 12,
		"enrage_threshold": 0.40,
		"enrage_damage_mult": 1.6,
		"enrage_speed_mult": 1.1,
		"guaranteed_loot": [
			{
				"name": "Undying Marrow",
				"desc": "Pulsing faintly with a sickly light. Necromancers value it highly.",
				"type": "MISC",
				"rarity": "RARE",
				"vendor_price": 60
			}
		],
		"rare_loot": [
			{
				"name": "Cursed Femur",
				"desc": "A blackened bone weapon pitted with necrotic runes. Unnaturally heavy.",
				"type": "WEAPON",
				"rarity": "RARE",
				"vendor_price": 260,
				"weapon_damage_min": 14,
				"weapon_damage_max": 26,
				"weapon_delay": 2.8,
				"weapon_skill": "1h_blunt",
				"bonus_strength": 6,
				"bonus_max_hp": 20.0,
				"drop_chance": 0.20
			}
		]
	}
}

# Builds an ItemData from a loot entry dict. Used by enemy.apply_named().
static func make_item(d: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.item_name   = d.get("name", "Unknown")
	item.description = d.get("desc", "")
	item.type        = _parse_type(d.get("type", "MISC"))
	item.rarity      = _parse_rarity(d.get("rarity", "UNCOMMON"))
	item.vendor_price       = d.get("vendor_price", 0)
	item.bonus_strength     = d.get("bonus_strength", 0)
	item.bonus_dexterity    = d.get("bonus_dexterity", 0)
	item.bonus_agility      = d.get("bonus_agility", 0)
	item.bonus_intelligence = d.get("bonus_intelligence", 0)
	item.bonus_wisdom       = d.get("bonus_wisdom", 0)
	item.bonus_constitution = d.get("bonus_constitution", 0)
	item.bonus_max_hp       = d.get("bonus_max_hp", 0.0)
	item.bonus_max_mp       = d.get("bonus_max_mp", 0.0)
	item.bonus_armor        = d.get("bonus_armor", 0)
	item.weapon_damage_min  = d.get("weapon_damage_min", 0)
	item.weapon_damage_max  = d.get("weapon_damage_max", 0)
	item.weapon_delay       = d.get("weapon_delay", 2.0)
	item.weapon_skill       = d.get("weapon_skill", "")
	item.is_two_handed      = d.get("is_two_handed", false)
	return item

static func _parse_type(s: String) -> ItemData.Type:
	match s:
		"WEAPON":      return ItemData.Type.WEAPON
		"OFFHAND":     return ItemData.Type.OFFHAND
		"HEAD":        return ItemData.Type.HEAD
		"CHEST":       return ItemData.Type.CHEST
		"LEGS":        return ItemData.Type.LEGS
		"FEET":        return ItemData.Type.FEET
		"HANDS":       return ItemData.Type.HANDS
		"RING":        return ItemData.Type.RING
		"NECK":        return ItemData.Type.NECK
		"CONSUMABLE":  return ItemData.Type.CONSUMABLE
		_:             return ItemData.Type.MISC

static func _parse_rarity(s: String) -> ItemData.Rarity:
	match s:
		"UNCOMMON": return ItemData.Rarity.UNCOMMON
		"RARE":     return ItemData.Rarity.RARE
		"EPIC":     return ItemData.Rarity.EPIC
		_:          return ItemData.Rarity.COMMON
