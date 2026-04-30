class_name RecipeData
extends Resource

@export var recipe_name: String = ""
@export var tradeskill: String = ""
@export var required_skill: int = 0
@export var trivial_at: int = 50
# Each entry: {item: String, qty: int}
@export var ingredients: Array[Dictionary] = []
@export var output_item: String = ""
@export var output_quantity: int = 1
# Required tool (not consumed by the combine)
@export var tool_required: String = ""
# Required station type: "forge", "alchemy_table", "kiln", "oven", "brewing_barrel"
@export var station_required: String = ""
