extends PassiveSkillTracker

const KIND_CASTING := 2

func _ready() -> void:
	super._ready()
	Net.world_skill_progress_update.connect(_on_skill_progress_update)
	Net.world_skill_progress_snapshot.connect(_on_skill_progress_snapshot)

func _on_skill_progress_update(kind: int, key: String, new_score: int) -> void:
	if kind != KIND_CASTING:
		return
	apply_remote_score(key, new_score)

func _on_skill_progress_snapshot(
		_weapon_keys: PackedStringArray, _weapon_scores: PackedInt32Array,
		_armor_keys: PackedStringArray, _armor_scores: PackedInt32Array,
		casting_keys: PackedStringArray, casting_scores: PackedInt32Array) -> void:
	var entries: Dictionary = {}
	for i in casting_keys.size():
		entries[casting_keys[i]] = casting_scores[i]
	apply_remote_snapshot(entries)

func initialize(player_class: String, level: int) -> void:
	_player_class = player_class
	_level = level
	_skills.clear()
	for skill in CastingSkillDefinitions.ALL:
		_skills[skill] = CastingSkillDefinitions.get_starting_value(player_class, skill)

func get_cap(skill_name: String) -> int:
	return CastingSkillDefinitions.get_cap(_player_class, skill_name, _level)

func _get_ratio(skill_name: String) -> float:
	var cap := get_cap(skill_name)
	if cap == 0:
		return 0.0
	return float(get_current(skill_name)) / float(cap)

# 1.0–1.15× damage multiplier for Evocation spells.
func get_damage_mult(discipline: String) -> float:
	if discipline != "evocation":
		return 1.0
	return 1.0 + 0.15 * _get_ratio("evocation")

# 1.0–1.25× duration multiplier for Alteration effects (HoT, DoT, CC duration).
func get_duration_mult(discipline: String) -> float:
	if discipline != "alteration":
		return 1.0
	return 1.0 + 0.25 * _get_ratio("alteration")

# 1.0–1.20× absorb multiplier for Abjuration shields.
func get_absorb_mult(discipline: String) -> float:
	if discipline != "abjuration":
		return 1.0
	return 1.0 + 0.20 * _get_ratio("abjuration")

# Probability [0.10, 0.70] that an incoming hit interrupts an active cast.
# At channeling skill 0: 70%. At max skill: 10%.
# Returns 1.0 for non-casters (cap = 0) — should never be reached in practice.
func get_interrupt_chance() -> float:
	var cap := get_cap("channeling")
	if cap == 0:
		return 1.0
	var ratio := float(get_current("channeling")) / float(cap)
	return maxf(0.10, 0.70 - ratio * 0.60)
