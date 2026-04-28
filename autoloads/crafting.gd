extends Node

signal skill_level_changed(skill_name: String, new_level: int)

const XP_PER_LEVEL: int = 20
const RACIAL_XP_MULTIPLIER: float = 1.5

var _all_skills: Dictionary = {}
var _skill_levels: Dictionary = {}
var _skill_xp: Dictionary = {}

func _ready() -> void:
	_register_defaults()

func get_skill_level(skill_name: String) -> int:
	return _skill_levels.get(skill_name, 0)

func get_skill_cap(skill_name: String) -> int:
	var skill: CraftingSkillData = _all_skills.get(skill_name)
	if skill == null:
		return 200
	if PlayerStats.race in skill.racial_bonus_races:
		return skill.base_cap + skill.racial_cap_bonus
	return skill.base_cap

func gain_skill_xp(skill_name: String, amount: int) -> void:
	if not _all_skills.has(skill_name):
		return
	var skill: CraftingSkillData = _all_skills[skill_name]
	var effective := amount
	if PlayerStats.race in skill.racial_bonus_races:
		effective = int(amount * RACIAL_XP_MULTIPLIER)
	var cap := get_skill_cap(skill_name)
	var level := _skill_levels.get(skill_name, 0)
	if level >= cap:
		return
	var xp := _skill_xp.get(skill_name, 0) + effective
	while xp >= XP_PER_LEVEL and level < cap:
		xp -= XP_PER_LEVEL
		level += 1
		skill_level_changed.emit(skill_name, level)
	_skill_levels[skill_name] = level
	_skill_xp[skill_name] = xp

func get_all_skills_by_category(cat: CraftingSkillData.Category) -> Array[CraftingSkillData]:
	var result: Array[CraftingSkillData] = []
	for sname in _all_skills:
		var skill: CraftingSkillData = _all_skills[sname]
		if skill.category == cat:
			result.append(skill)
	return result

func _register_defaults() -> void:
	# ── Gathering ──────────────────────────────────────────────────────────────
	_reg("Mining",      "Extract ore, stone, and gemstones from the earth.",
		CraftingSkillData.Category.GATHERING, ["Blacksmithing", "Jewelcrafting", "Pottery"], [], [])
	_reg("Herbalism",   "Harvest plants, roots, and alchemical reagents.",
		CraftingSkillData.Category.GATHERING, ["Alchemy", "Cooking", "Brewing", "Scribing"], [], [])
	_reg("Logging",     "Fell trees for wood, bark, and resin.",
		CraftingSkillData.Category.GATHERING, ["Woodworking", "Fletching"], [], [])
	_reg("Skinning",    "Harvest hides, sinew, and bone from creatures.",
		CraftingSkillData.Category.GATHERING, ["Leatherworking", "Tailoring"], [], [])
	_reg("Fishing",     "Pull fish, coral, and rare items from the water.",
		CraftingSkillData.Category.GATHERING, ["Cooking", "Alchemy"], [], [])
	_reg("Prospecting", "Locate rare ore veins and gem deposits.",
		CraftingSkillData.Category.GATHERING, ["Jewelcrafting"], [], [])

	# ── Production ─────────────────────────────────────────────────────────────
	_reg("Blacksmithing",  "Forge metal weapons and heavy armor.",
		CraftingSkillData.Category.PRODUCTION, [], ["Mining"], [])
	_reg("Leatherworking", "Craft leather armor, belts, and bags.",
		CraftingSkillData.Category.PRODUCTION, [], ["Skinning"], [])
	_reg("Tailoring",      "Sew cloth armor, robes, and containers.",
		CraftingSkillData.Category.PRODUCTION, [], ["Herbalism", "Skinning"], [])
	_reg("Woodworking",    "Craft staves, shields, and wooden goods.",
		CraftingSkillData.Category.PRODUCTION, [], ["Logging"], [])
	_reg("Fletching",      "Create bows, crossbows, and arrows.",
		CraftingSkillData.Category.PRODUCTION, [], ["Logging", "Skinning"], [])
	_reg("Jewelcrafting",  "Set gems and forge rings, amulets, and trinkets.",
		CraftingSkillData.Category.PRODUCTION, [], ["Mining", "Prospecting"], [])
	_reg("Alchemy",        "Brew potions, poisons, and magical reagents.",
		CraftingSkillData.Category.PRODUCTION, [], ["Herbalism", "Fishing"], [])
	_reg("Cooking",        "Prepare food that restores health and grants buffs.",
		CraftingSkillData.Category.PRODUCTION, [], ["Fishing", "Herbalism"], [])
	_reg("Brewing",        "Craft ales, tonics, and restorative drinks.",
		CraftingSkillData.Category.PRODUCTION, [], ["Herbalism", "Cooking"], [])
	_reg("Pottery",        "Shape clay into containers and reagent vessels.",
		CraftingSkillData.Category.PRODUCTION, [], ["Mining"], [])
	_reg("Scribing",       "Write spell scrolls, skill tomes, and maps.",
		CraftingSkillData.Category.PRODUCTION, [], ["Herbalism", "Logging"], [])
	_reg("Enchanting",     "Imbue crafted items with magical properties.",
		CraftingSkillData.Category.PRODUCTION, [], [], [])
	_reg("Tinkering",      "Build mechanical devices, traps, and gadgets. Gnomes and Kobolds excel here.",
		CraftingSkillData.Category.PRODUCTION, [], ["Mining", "Woodworking"], ["Gnome", "Kobold"])

func _reg(
	sname: String, desc: String, cat: CraftingSkillData.Category,
	feeds: Array, requires: Array, bonus_races: Array
) -> void:
	var s := CraftingSkillData.new()
	s.skill_name = sname
	s.description = desc
	s.category = cat
	for f in feeds:
		s.feeds_into.append(f)
	for r in requires:
		s.required_inputs.append(r)
	for race in bonus_races:
		s.racial_bonus_races.append(race)
	_all_skills[sname] = s
	_skill_levels[sname] = 0
	_skill_xp[sname] = 0
