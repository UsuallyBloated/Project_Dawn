extends Node

signal skill_advanced(new_value: int, cap: int)

var _skill: int = 0
var _level: int = 1

# The world compass (settled 2026-09-27, user call): +Z is NORTH and +X is
# EAST, matching the camp/authoring labels in zone_camps.toml and the quest
# dialogue ("gnolls east of town" sit at +X, "wolves south" at -Z). Note the
# chirality is mirrored versus a real-world compass (facing north, east is on
# your LEFT here) — invisible in game, but don't "fix" it: the content is
# authored against this compass. Ring order matches _rotation_to_idx, which
# steps 45 degrees per index as rotation.y increases (rotation.y = 0 faces
# Godot's -Z = SOUTH).
const DIRS := ["South", "Southwest", "West", "Northwest", "North", "Northeast", "East", "Southeast"]

func _ready() -> void:
	PlayerStats.level_changed.connect(_on_level_changed)

func initialize(level: int) -> void:
	_level = level
	_skill = SenseHeadingDefinitions.get_starting_value()

func try_advance() -> void:
	var cap := SenseHeadingDefinitions.get_cap(_level)
	if _skill >= cap:
		return
	var advance_chance := 0.3 * (1.0 - float(_skill) / float(cap))
	if randf() < advance_chance:
		_skill += 1
		skill_advanced.emit(_skill, cap)

func get_current() -> int:
	return _skill

func get_cap() -> int:
	return SenseHeadingDefinitions.get_cap(_level)

# Returns a text description of the facing direction based on skill level.
# Low skill gives garbled or wrong results; max skill is precise.
func query(rotation_y: float) -> String:
	if _skill == 0:
		return "You have no idea which direction you are facing."

	var cap := SenseHeadingDefinitions.get_cap(_level)
	var ratio := float(_skill) / float(cap)

	var exact_idx := _rotation_to_idx(rotation_y)

	var err_range: int
	if ratio < 0.25:
		err_range = 3
	elif ratio < 0.5:
		err_range = 2
	elif ratio < 0.75:
		err_range = 1
	else:
		err_range = 0

	var idx := (exact_idx + randi_range(-err_range, err_range) + 8) % 8

	if ratio < 0.25:
		return "You think you might be facing %s, but you're not sure." % DIRS[idx]
	elif ratio < 0.75:
		return "You are facing roughly %s." % DIRS[idx]
	else:
		return "You are facing %s." % DIRS[idx]

# Godot rotation.y is counter-clockwise from above; 0 faces -Z, which is
# SOUTH under the settled compass (see DIRS above). Returns an index 0-7
# into DIRS, 45 degrees per step.
func _rotation_to_idx(rotation_y: float) -> int:
	var deg := fmod(rotation_y * 180.0 / PI + 360.0, 360.0)
	return int((deg + 22.5) / 45.0) % 8

func _on_level_changed(new_level: int) -> void:
	_level = new_level
