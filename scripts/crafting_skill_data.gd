class_name CraftingSkillData
extends Resource

enum Category { GATHERING, PRODUCTION }

@export var skill_name: String = ""
@export var description: String = ""
@export var category: Category = Category.GATHERING
@export var feeds_into: Array[String] = []
@export var required_inputs: Array[String] = []
@export var racial_bonus_races: Array[String] = []
@export var base_cap: int = 200
@export var racial_cap_bonus: int = 100
