class_name SpellData
extends Resource

enum TargetType { ENEMY, SELF, ALLY, NONE, PET_SUMMON, PET_CHARM, PET_HEAL, PORT, BIND, AOE, CORPSE, SUMMON_ITEM }
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
# A song's own start fraction (its share of the listed level-50 effect when
# first learned); 0 means BardSongs.SCALE_AT_LEARN. Selos' carries EQ's
# Selo's curve (0.3077, +20% of +65%).
@export var song_scale_at_learn: float = 0.0
@export var allowed_classes: Array[String] = []
# Minimum character level required to have this spell available.
@export var min_level: int = 1
# Per-class level requirements on a spell several classes share (Summon
# Drink: Magician 1, Shaman 2, Cleric 3, Druid 10); a class absent here uses
# min_level. Mirror of the server's `class_min_levels`, compared by the
# lockstep check.
@export var class_min_levels: Dictionary = {}
# SUMMON_ITEM spells (Summon Food / Drink): the item conjured into the bags
# and the most of it one cast makes; the count is the server's (one at the
# class's level, one more per ten levels).
@export var summon_item: String = ""
@export var summon_max: int = 0
# How far this spell reaches its target, metres; 0 means DEFAULT_SPELL_RANGE
# (use reach()). Per-spell since 2026-10-19, on Monsters and Memories' 30 m
# baseline for every single-target spell; the server's Spell::reach is the
# authority and the two are compared by tools/check_spell_lockstep.gd.
@export var range: float = 0.0

const DEFAULT_SPELL_RANGE := 30.0

func reach() -> float:
	return range if range > 0.0 else DEFAULT_SPELL_RANGE

func required_level(cls: String) -> int:
	return int(class_min_levels.get(cls, min_level))
# Casting discipline that trains when this spell is cast. See CastingSkillDefinitions.ALL.
# "evocation", "alteration", "abjuration", "conjuration", "divination" — or "" if unassigned.
@export var discipline: String = ""
# Rank system: rank 1 is the base spell, 2 and 3 are upgrades.
# base_name links all ranks of the same spell (e.g. "Fireball").
# setup_for_class() keeps only the highest accessible rank per base_name.
@export var rank: int = 1
@export var base_name: String = ""
