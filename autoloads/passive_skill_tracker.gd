class_name PassiveSkillTracker
extends Node

signal skill_advanced(skill_name: String, new_value: int, cap: int)
# Fired once after the enter-world snapshot overwrites the score cache. Distinct
# from `skill_advanced` on purpose: the character window listens to this to repaint
# loaded scores on login, but CombatLog does NOT (a per-skill `skill_advanced` here
# would spam "Your <skill> increased to N" three times on every world entry). See
# apply_remote_snapshot.
signal snapshot_applied

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
# Emits `snapshot_applied` (not `skill_advanced`) once at the end so the
# character window repaints the loaded scores. The window's own `_ready`
# `_refresh()` runs at world load, BEFORE this network snapshot arrives, so
# without this nudge it would show the seeded starting values (e.g. "1 / x")
# until the next real advance repainted them — a relog looked like it wiped
# your skills even though the scores were correct underneath (playtest
# 2026-07-22). `snapshot_applied` is deliberately separate from `skill_advanced`
# so CombatLog (which only wants real advances) doesn't log a bogus increase.
func apply_remote_snapshot(entries: Dictionary) -> void:
	for k in entries:
		if _skills.has(k):
			_skills[k] = int(entries[k])
	snapshot_applied.emit()

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
