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
	# Track 18.1 — in launcher mode the server runs the advance roll
	# and fans a SkillProgressUpdate; the client just renders. Solo /
	# Test Room still need the local math, so the gate falls through
	# to the legacy path when Net isn't acting as a launcher client.
	if Net.is_launcher_mode():
		return
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

# Track 18.1 — apply a server-fanned advance. Launcher-mode callers
# (the three concrete subclasses subscribed to Net.world_skill_progress_update)
# overwrite the local cache and emit `skill_advanced` so existing UI
# subscribers (character window) repaint.
func apply_remote_score(skill_name: String, new_score: int) -> void:
	if not _skills.has(skill_name):
		# Seed the row if the server is fanning an advance for a key
		# we don't yet know about (shouldn't normally happen — the
		# enter-world snapshot populates the full set first).
		_skills[skill_name] = new_score
	else:
		_skills[skill_name] = new_score
	var cap: int = get_cap(skill_name)
	skill_advanced.emit(skill_name, new_score, cap)

# Track 18.1 — apply the full enter-world snapshot. Overwrites every
# known key with the server's value; unknown keys are skipped (the
# initialize() pass populates the canonical key set first, so the
# snapshot's keys should match exactly).
#
# Note: no broadcast emit. An earlier version fired
# `skill_advanced.emit("", 0, 0)` as a "snapshot landed" nudge for the
# character window to re-render — but CombatLog also subscribes to
# `skill_advanced` and logged "Your  skill has increased to 0
# (cap: 0)." three times (once per tracker) on every world entry.
# Character window already calls `_refresh()` in its _ready and is
# closed by default; opening it after a snapshot reads fresh values.
func apply_remote_snapshot(entries: Dictionary) -> void:
	for k in entries:
		if _skills.has(k):
			_skills[k] = int(entries[k])

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
