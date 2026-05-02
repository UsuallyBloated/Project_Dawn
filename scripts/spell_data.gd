class_name SpellData
extends Resource

enum TargetType { ENEMY, SELF, NONE, PET_SUMMON, PET_CHARM, PET_HEAL, PORT, BIND, AOE }
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
@export var root_duration: float = 0.0
@export var slow_amount: float = 0.0
@export var slow_duration: float = 0.0
@export var attack_slow_amount: float = 0.0
@export var attack_slow_duration: float = 0.0
@export var port_zone_path: String = ""
@export var port_entry_id: String = ""
@export var port_zone_name: String = ""
@export var port_is_group: bool = false
# Movement speed buff (1.4 = 40% faster). 0 = none.
@export var move_speed_mult: float = 0.0
@export var move_speed_duration: float = 0.0
# Mana regeneration buff (MP per second).
@export var mp_regen_hps: float = 0.0
@export var mp_regen_duration: float = 0.0
# Attack speed buff for player (0.5 = attacks 50% faster). 0 = none.
@export var haste_amount: float = 0.0
@export var haste_duration: float = 0.0
# Accuracy / crit buff (Hunter's Eye).
@export var accuracy_buff: float = 0.0
@export var crit_buff: float = 0.0
@export var stat_buff_duration: float = 0.0
# Primary stat buffs (STR/AGI/INT/WIS/CON/max HP/max MP). Applied directly to PlayerStats
# for the duration; undone on expire or clear.
@export var str_buff: int = 0
@export var agi_buff: int = 0
@export var int_buff: int = 0
@export var wis_buff: int = 0
@export var con_buff: int = 0
@export var max_hp_buff: float = 0.0
@export var max_mp_buff: float = 0.0
@export var primary_stat_buff_duration: float = 0.0
# Stealth effect.
@export var is_stealth: bool = false
@export var stealth_duration: float = 0.0
# Dispel: strip one buff from the target.
@export var is_dispel: bool = false
# Silence: prevent target from casting spells for duration.
@export var silence_duration: float = 0.0
# Lich Form toggle: disables HP regen, enables extreme MP regen.
@export var is_lich_form: bool = false
@export var lich_mp_regen: float = 0.0
# Exsanguinate: deal damage equal to this amount and convert it to caster mana.
@export var mana_drain: float = 0.0
# Damage shield: attacker takes this much damage on each hit.
@export var damage_shield_amount: float = 0.0
@export var damage_shield_duration: float = 0.0
# AOE radius in meters (AOE target_type only). 0 = not an AOE spell.
@export var aoe_radius: float = 0.0
# Song: route through BardSongs twist system instead of standard effect handling.
@export var is_song: bool = false
@export var allowed_classes: Array[String] = []
# Minimum character level required to have this spell available.
@export var min_level: int = 1
# Casting discipline that trains when this spell is cast. See CastingSkillDefinitions.ALL.
# "evocation", "alteration", "abjuration", "conjuration", "divination" — or "" if unassigned.
@export var discipline: String = ""
# Rank system: rank 1 is the base spell, 2 and 3 are upgrades.
# base_name links all ranks of the same spell (e.g. "Fireball").
# setup_for_class() keeps only the highest accessible rank per base_name.
@export var rank: int = 1
@export var base_name: String = ""
