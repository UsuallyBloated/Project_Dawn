extends PassiveSkillTracker

const KIND_WEAPON := 0

func _ready() -> void:
	super._ready()
	# Track 18.1 — server fans skill advances; subscribe to Net and
	# route the matching kind into our score cache. Solo / Test Room
	# fall through to the base class's local-roll path.
	Net.world_skill_progress_update.connect(_on_skill_progress_update)
	Net.world_skill_progress_snapshot.connect(_on_skill_progress_snapshot)

func _on_skill_progress_update(kind: int, key: String, new_score: int) -> void:
	if kind != KIND_WEAPON:
		return
	apply_remote_score(key, new_score)

func _on_skill_progress_snapshot(
		weapon_keys: PackedStringArray, weapon_scores: PackedInt32Array,
		_armor_keys: PackedStringArray, _armor_scores: PackedInt32Array,
		_casting_keys: PackedStringArray, _casting_scores: PackedInt32Array) -> void:
	var entries: Dictionary = {}
	for i in weapon_keys.size():
		entries[weapon_keys[i]] = weapon_scores[i]
	apply_remote_snapshot(entries)

func initialize(player_class: String, level: int) -> void:
	_player_class = player_class
	_level = level
	_skills.clear()
	for skill in WeaponSkillDefinitions.ALL:
		_skills[skill] = WeaponSkillDefinitions.get_starting_value(player_class, skill)

func get_cap(skill_name: String) -> int:
	return WeaponSkillDefinitions.get_cap(_player_class, skill_name, _level)

# 0.05–0.35 miss chance scaling from skill vs cap. Unusable weapon type = 80% miss.
func get_miss_chance(skill_name: String) -> float:
	if _player_class == "":
		return 0.0
	var cap := get_cap(skill_name)
	if cap == 0:
		return 0.80
	var current := get_current(skill_name)
	return maxf(0.05, 0.35 * (1.0 - float(current) / float(cap)))

# 1.0–1.15 damage multiplier from skill proficiency. Unusable weapon type = 0.5x.
func get_damage_multiplier(skill_name: String) -> float:
	if _player_class == "":
		return 1.0
	var cap := get_cap(skill_name)
	if cap == 0:
		return 0.5
	var current := get_current(skill_name)
	return 1.0 + 0.15 * float(current) / float(cap)
