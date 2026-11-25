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

# The casting skills no longer scale a spell's damage, duration or absorb: as
# on P99 a spell does its listed number and a low skill makes it FIZZLE, which
# the server rolls at the cast's start (the EQ parity audit of 2026-10-20).
# The channeling skill's interrupt roll is the server's too.
