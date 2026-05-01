extends Node

signal skill_level_changed(skill_name: String, new_level: int)

const XP_PER_LEVEL: int = 20
const RACIAL_XP_MULTIPLIER: float = 1.5

var _all_skills: Dictionary = {}
var _skill_levels: Dictionary = {}
var _skill_xp: Dictionary = {}

func _ready() -> void:
	_register_defaults()

# --- Skill queries -----------------------------------------------------------

func get_skill_level(skill_name: String) -> int:
	return _skill_levels.get(skill_name, 0)

func get_skill_cap(skill_name: String) -> int:
	var skill: CraftingSkillData = _all_skills.get(skill_name)
	if skill == null:
		return 200
	if PlayerStats.race in skill.racial_bonus_races:
		return skill.base_cap + skill.racial_cap_bonus
	return skill.base_cap

# Returns true when the current character's race, class, and alignment all
# satisfy the access gates defined in TradeskillDefinitions.
func can_access_skill(skill_name: String) -> bool:
	var skill: CraftingSkillData = _all_skills.get(skill_name)
	if skill == null:
		return false
	# open_races bypasses all other gates — race always has access
	if PlayerStats.race in skill.open_races:
		return true
	# exclusive_races blocks every other race before class/alignment checks
	if not skill.exclusive_races.is_empty() and PlayerStats.race not in skill.exclusive_races:
		return false
	if not skill.allowed_classes.is_empty() and PlayerStats.player_class not in skill.allowed_classes:
		return false
	if skill.required_alignment != "":
		var tier := Alignment.alignment_tier
		match skill.required_alignment:
			"Good":    if tier not in ["Exalted", "Good"]:  return false
			"NotGood": if tier in ["Exalted", "Good"]:      return false
			"Evil":    if tier not in ["Bad", "Evil"]:       return false
	return true

func get_accessible_skills() -> Array[CraftingSkillData]:
	var result: Array[CraftingSkillData] = []
	for sname in _all_skills:
		if can_access_skill(sname):
			result.append(_all_skills[sname])
	return result

func get_all_skills_by_category(cat: CraftingSkillData.Category) -> Array[CraftingSkillData]:
	var result: Array[CraftingSkillData] = []
	for sname in _all_skills:
		var skill: CraftingSkillData = _all_skills[sname]
		if skill.category == cat:
			result.append(skill)
	return result

# Returns the accessible recipes for a tradeskill.
func get_recipes(tradeskill: String) -> Array:
	if not can_access_skill(tradeskill):
		return []
	return RecipeDefinitions.get_by_tradeskill(tradeskill)

# --- XP and combining --------------------------------------------------------

func gain_skill_xp(skill_name: String, amount: int) -> void:
	if not _all_skills.has(skill_name):
		return
	var skill: CraftingSkillData = _all_skills[skill_name]
	var effective := amount
	if PlayerStats.race in skill.racial_bonus_races:
		effective = int(amount * RACIAL_XP_MULTIPLIER)
	var cap := get_skill_cap(skill_name)
	var level: int = _skill_levels.get(skill_name, 0)
	if level >= cap:
		return
	var xp: int = _skill_xp.get(skill_name, 0) + effective
	while xp >= XP_PER_LEVEL and level < cap:
		xp -= XP_PER_LEVEL
		level += 1
		skill_level_changed.emit(skill_name, level)
	_skill_levels[skill_name] = level
	_skill_xp[skill_name] = xp

# Attempts a crafting combine. Returns a human-readable result string.
# XP is only granted below trivial_at.
func try_combine(recipe: Dictionary, tradeskill: String) -> String:
	if not can_access_skill(tradeskill):
		return "You do not have access to %s." % tradeskill

	var required: int = recipe.get("required_skill", 0)
	var trivial: int  = recipe.get("trivial_at", 50)
	var level := get_skill_level(tradeskill)

	if level < required:
		return "You need %s skill %d to attempt this (you have %d)." % [tradeskill, required, level]

	var tool: String = recipe.get("tool", "")
	if tool != "" and count_item(tool) == 0:
		return "You need a %s to craft this." % tool

	for ing in recipe.get("ingredients", []):
		var have := count_item(ing["item"])
		if have < int(ing["qty"]):
			return "You need %d %s (you have %d)." % [ing["qty"], ing["item"], have]

	var output_name: String = recipe.get("output", "")
	var output_qty: int     = recipe.get("output_qty", 1)
	var item := _load_item_by_name(output_name)
	if item == null:
		return "Error: output item '%s' not found." % output_name

	# Consume ingredients — lost on both success and failure (EQ-style risk)
	for ing in recipe.get("ingredients", []):
		_remove_item_by_name(ing["item"], int(ing["qty"]))

	var success_chance := clampf((level - required + 20) / 40.0, 0.05, 0.95)
	if randf() > success_chance:
		return "You failed to create %s. The materials were ruined." % output_name

	if not Inventory.add_item(item, output_qty):
		return "Inventory is full."

	if level < trivial:
		gain_skill_xp(tradeskill, 10)

	return "You created %s%s." % [output_name, " x%d" % output_qty if output_qty > 1 else ""]

# --- Inventory helpers -------------------------------------------------------

func count_item(item_name: String) -> int:
	var total := 0
	for slot in Inventory.slots:
		if slot != null and (slot["item"] as ItemData).item_name == item_name:
			total += int(slot["count"])
	return total

func _remove_item_by_name(item_name: String, qty: int) -> void:
	var item_ref: ItemData = null
	for slot in Inventory.slots:
		if slot != null and (slot["item"] as ItemData).item_name == item_name:
			item_ref = slot["item"]
			break
	if item_ref != null:
		Inventory.remove_item(item_ref, qty)

func _load_item_by_name(item_name: String) -> ItemData:
	var path := "res://data/loot/items/%s.tres" % item_name.to_lower().replace(" ", "_")
	if ResourceLoader.exists(path):
		return load(path) as ItemData
	return null

# --- Registration ------------------------------------------------------------

func _register_defaults() -> void:
	for entry in TradeskillDefinitions.ALL:
		var s := CraftingSkillData.new()
		s.skill_name = entry["name"]
		s.description = entry["desc"]
		match entry["category"]:
			"gathering":  s.category = CraftingSkillData.Category.GATHERING
			"production": s.category = CraftingSkillData.Category.PRODUCTION
			"service":    s.category = CraftingSkillData.Category.SERVICE
		for f in entry["feeds_into"]:         s.feeds_into.append(f)
		for r in entry["requires"]:           s.required_inputs.append(r)
		for race in entry["racial_bonus_races"]: s.racial_bonus_races.append(race)
		for race in entry["exclusive_races"]:  s.exclusive_races.append(race)
		for race in entry["open_races"]:       s.open_races.append(race)
		for cls in entry["allowed_classes"]:   s.allowed_classes.append(cls)
		s.required_alignment = entry["required_alignment"]
		s.base_cap           = entry["base_cap"]
		s.racial_cap_bonus   = entry.get("racial_cap_bonus", 50)
		_all_skills[s.skill_name]  = s
		_skill_levels[s.skill_name] = 0
		_skill_xp[s.skill_name]    = 0
