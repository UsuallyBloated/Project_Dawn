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

# A crafting combine. Crafting is not on the server yet, so it refuses before
# touching anything: a local combine deleted the REAL ingredients from the
# client mirror while the server still held them, so every slot index drifted
# out of alignment and a later Sell/Destroy executed against a different, real
# item. The recipes and skill rules here stay for the server port.
func try_combine(_recipe: Dictionary, _tradeskill: String) -> String:
	return "Crafting isn't available online yet."

# --- Inventory helpers -------------------------------------------------------

func count_item(item_name: String) -> int:
	var total := 0
	for slot in Inventory.all_slots():
		if (slot["item"] as ItemData).item_name == item_name:
			total += int(slot["count"])
	return total

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
