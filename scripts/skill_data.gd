class_name SkillData
extends Resource

enum TargetType { ENEMY, SELF, NONE }
enum EffectType { NONE, EVADE_BOOST, ABSORB_SHIELD, WARDER_FURY, STUN, FEIGN_DEATH, STEALTH, TRUESIGHT }

@export var skill_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var cooldown: float = 5.0
@export var stamina_cost: float = 10.0
@export var damage_multiplier: float = 1.0
@export var target_type: TargetType = TargetType.ENEMY
@export var effect_type: EffectType = EffectType.NONE
@export var effect_duration: float = 0.0
@export var absorb_amount: float = 0.0
@export var stun_duration: float = 0.0
@export var stealth_duration: float = 0.0
@export var allowed_classes: Array[String] = []
