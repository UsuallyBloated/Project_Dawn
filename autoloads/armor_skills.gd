extends PassiveSkillTracker

const KIND_ARMOR := 1

func _ready() -> void:
	super._ready()
	Net.world_skill_progress_update.connect(_on_skill_progress_update)
	Net.world_skill_progress_snapshot.connect(_on_skill_progress_snapshot)

func _on_skill_progress_update(kind: int, key: String, new_score: int) -> void:
	if kind != KIND_ARMOR:
		return
	apply_remote_score(key, new_score)

func _on_skill_progress_snapshot(
		_weapon_keys: PackedStringArray, _weapon_scores: PackedInt32Array,
		armor_keys: PackedStringArray, armor_scores: PackedInt32Array,
		_casting_keys: PackedStringArray, _casting_scores: PackedInt32Array) -> void:
	var entries: Dictionary = {}
	for i in armor_keys.size():
		entries[armor_keys[i]] = armor_scores[i]
	apply_remote_snapshot(entries)

func initialize(player_class: String, level: int) -> void:
	_player_class = player_class
	_level = level
	_skills.clear()
	for skill in ArmorSkillDefinitions.ALL:
		_skills[skill] = ArmorSkillDefinitions.get_starting_value(player_class, skill)

func get_cap(skill_name: String) -> int:
	return ArmorSkillDefinitions.get_cap(_player_class, skill_name, _level)

# Called when the player takes a hit. Advances skill for each unique armor type worn.
func try_advance_worn(equipped: Dictionary) -> void:
	var seen: Dictionary = {}
	for slot in equipped:
		var item = equipped[slot]
		if item == null or item.armor_type == "":
			continue
		if seen.has(item.armor_type):
			continue
		seen[item.armor_type] = true
		try_advance(item.armor_type)

# Returns the effective armor multiplier for a given armor type.
# cap=0 (wrong armor type): 0.5x. Trained: 1.0–1.25x scaling with skill.
func get_armor_multiplier(armor_type: String) -> float:
	if _player_class == "":
		return 1.0
	var cap := get_cap(armor_type)
	if cap == 0:
		return 0.5
	var current := get_current(armor_type)
	return 1.0 + 0.25 * float(current) / float(cap)

# Returns total effective armor from all equipped pieces, modified by armor skill.
func get_effective_armor(equipped: Dictionary) -> int:
	var total := 0
	for slot in equipped:
		var item = equipped[slot]
		if item == null or item.bonus_armor <= 0:
			continue
		var mult := get_armor_multiplier(item.armor_type)
		total += int(item.bonus_armor * mult)
	return total
