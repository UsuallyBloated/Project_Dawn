class_name PassiveSkillTracker
extends Node

signal skill_advanced(skill_name: String, new_value: int, cap: int)

const ADVANCE_CHANCE_BASE := 0.2

var _skills: Dictionary = {}
var _player_class: String = ""
var _level: int = 1

func _ready() -> void:
	PlayerStats.level_changed.connect(_on_level_changed)

func try_advance(skill_name: String) -> void:
	if _player_class == "" or not _skills.has(skill_name):
		return
	var current: int = _skills[skill_name]
	var cap: int = get_cap(skill_name)
	if cap == 0 or current >= cap:
		return
	var advance_chance := ADVANCE_CHANCE_BASE * (1.0 - float(current) / float(cap))
	if randf() < advance_chance:
		_skills[skill_name] = current + 1
		skill_advanced.emit(skill_name, _skills[skill_name], cap)

func get_current(skill_name: String) -> int:
	return _skills.get(skill_name, 0)

func get_cap(_skill_name: String) -> int:
	return 0  # override in subclass

func _on_level_changed(new_level: int) -> void:
	_level = new_level

func save_state() -> Dictionary:
	return {"skills": _skills.duplicate()}

func load_state(d: Dictionary) -> void:
	var saved: Dictionary = d.get("skills", {})
	for k in saved:
		if _skills.has(k):
			_skills[k] = int(saved[k])
