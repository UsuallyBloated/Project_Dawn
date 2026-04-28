class_name SkillData
extends Resource

enum TargetType { ENEMY, SELF, NONE }

@export var skill_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var cooldown: float = 5.0
@export var stamina_cost: float = 10.0
@export var damage_multiplier: float = 1.0
@export var target_type: TargetType = TargetType.ENEMY
@export var allowed_classes: Array[String] = []
