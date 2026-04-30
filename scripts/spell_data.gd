class_name SpellData
extends Resource

enum TargetType { ENEMY, SELF, NONE, PET_SUMMON, PET_CHARM, PET_HEAL, PORT, BIND }
enum DamageType { FIRE, ICE, LIGHTNING, ARCANE, HEALING, HOLY, NATURE, SPIRIT, SHADOW, NONE }

@export var spell_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var mana_cost: float = 20.0
@export var cast_time: float = 0.0
@export var cooldown: float = 3.0
@export var base_damage: float = 30.0
@export var damage_type: DamageType = DamageType.ARCANE
@export var target_type: TargetType = TargetType.ENEMY
@export var heal_amount: float = 0.0
@export var hp_cost: float = 0.0
@export var duration: float = 0.0
@export var pet_type: String = ""
@export var dot_dps: float = 0.0
@export var dot_duration: float = 0.0
@export var hot_hps: float = 0.0
@export var hot_duration: float = 0.0
@export var absorb_amount: float = 0.0
@export var cc_duration: float = 0.0
@export var port_zone_path: String = ""
@export var port_entry_id: String = ""
@export var port_zone_name: String = ""
@export var port_is_group: bool = false
@export var allowed_classes: Array[String] = []
# Casting discipline that trains when this spell is cast. See CastingSkillDefinitions.ALL.
# "evocation", "alteration", "abjuration", "conjuration", "divination" — or "" if unassigned.
@export var discipline: String = ""
