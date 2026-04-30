class_name CraftingSkillData
extends Resource

enum Category { GATHERING, PRODUCTION, SERVICE }

@export var skill_name: String = ""
@export var description: String = ""
@export var category: Category = Category.GATHERING
@export var feeds_into: Array[String] = []
@export var required_inputs: Array[String] = []
@export var racial_bonus_races: Array[String] = []
@export var base_cap: int = 200
@export var racial_cap_bonus: int = 50
# exclusive_races: non-empty → only these races can ever access (e.g. Tinkering)
# open_races:      non-empty → these races always have access, bypassing class/alignment
# allowed_classes: non-empty → only these classes can access (ignored for open_races)
# required_alignment: "" = any | "Good" | "NotGood" | "Evil" (ignored for open_races)
@export var exclusive_races: Array[String] = []
@export var open_races: Array[String] = []
@export var allowed_classes: Array[String] = []
@export var required_alignment: String = ""
