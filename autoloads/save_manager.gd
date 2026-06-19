extends Node

# Single-character JSON save coordinator.
# Persists: PlayerStats (gear-free intrinsic stats — see PlayerStats.save_state),
# Alignment, QuestManager, the three passive skill trackers, Inventory, and
# Equipment. Buffs / cooldowns / pet state are transient and not persisted.
#
# Auto-save fires on level-up and zone change. SaveManager owns window-close:
# the X button is wired as a hard self-kill (OS.kill on our own PID) so it
# simulates a crash and drives the server's linkdead path, NOT a clean logout.
# The clean path (save + Net.leave_session app-Disconnect + get_tree().quit) now
# lives only on the in-game Quit Game button in the Options screen.
#
# Atomic writes: data is staged at character.save.tmp, the previous primary is
# rotated to character.save.bak, then tmp is renamed into place. A crash mid-
# write leaves either the previous good save or a recoverable .bak.

const SAVE_PATH := "user://character.save"
const SAVE_PATH_TMP := "user://character.save.tmp"
const SAVE_PATH_BAK := "user://character.save.bak"
const SAVE_VERSION := 3  # bumped: inventory + equipment now persisted

signal saved
signal loaded

var _is_loading: bool = false

func _ready() -> void:
	# Auto-save triggers. Window-close save runs from _on_close_requested below.
	PlayerStats.level_changed.connect(func(_lvl: int) -> void:
		if not _is_loading:
			save())
	ZoneLoader.zone_ready.connect(func() -> void:
		if not _is_loading:
			save())
	# Take over window-close handling so we can autosave before quit. In Godot
	# 4 the close request is delivered to the root Window's `close_requested`
	# signal — autoloads do NOT receive NOTIFICATION_WM_CLOSE_REQUEST via
	# _notification (that path is for Window nodes only and does not propagate
	# to scene-tree children). SaveManager is the single owner of this signal;
	# Net intentionally does not connect to it.
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_on_close_requested)

func _on_close_requested() -> void:
	# The window X button simulates a HARD client crash so we can exercise the
	# server's linkdead path: the body lingers in-world ~30 s (vulnerable,
	# killable), a same-account relogin is refused meanwhile, then it reaps. See
	# docs/design/camp_and_linkdead.md.
	#
	# So we deliberately do NOT save or call Net.leave_session() here. Sending the
	# app-layer Disconnect would make the server reap immediately (a CLEAN logout)
	# — that is exactly what "Quit Game" in the Options screen is for, and it
	# stays the way to leave cleanly. Killing our own process is the in-app
	# equivalent of ending the task in Task Manager, and it kills only THIS
	# instance's PID, so a second client on the same machine keeps running.
	OS.kill(OS.get_process_id())

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save() -> bool:
	# Skip if no character has ever been applied (e.g. fresh launch on lobby).
	if PlayerStats.player_name == "" or PlayerStats.race == "" or PlayerStats.player_class == "":
		return false
	var data := {
		"version":        SAVE_VERSION,
		"player_stats":   PlayerStats.save_state(),
		"alignment":      Alignment.save_state(),
		"quests":         QuestManager.save_state(),
		"weapon_skills":  WeaponSkills.save_state(),
		"armor_skills":   ArmorSkills.save_state(),
		"casting_skills": CastingSkills.save_state(),
		"inventory":      Inventory.save_state(),
		"equipment":      Equipment.save_state(),
	}
	# Atomic write: dump JSON to a tmp file, then rotate existing save → .bak,
	# then rename tmp → primary. A crash mid-write leaves either the previous
	# good save or a recoverable .bak — never a half-written primary file.
	var file := FileAccess.open(SAVE_PATH_TMP, FileAccess.WRITE)
	if file == null:
		DebugLog.error("[SaveManager] Failed to open %s for writing." % SAVE_PATH_TMP)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		DebugLog.error("[SaveManager] Cannot open user:// to rotate save files.")
		return false
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_PATH_BAK):
			dir.remove(SAVE_PATH_BAK.trim_prefix("user://"))
		dir.rename(SAVE_PATH.trim_prefix("user://"), SAVE_PATH_BAK.trim_prefix("user://"))
	dir.rename(SAVE_PATH_TMP.trim_prefix("user://"), SAVE_PATH.trim_prefix("user://"))
	saved.emit()
	DebugLog.info("[SaveManager] Saved character %s (lvl %d %s)." % [
		PlayerStats.player_name, PlayerStats.level, PlayerStats.player_class])
	return true

func load_save() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		DebugLog.error("[SaveManager] Failed to open %s for reading." % SAVE_PATH)
		return false
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		DebugLog.error("[SaveManager] %s is not valid JSON." % SAVE_PATH)
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		DebugLog.warn("[SaveManager] Save file version mismatch — discarded.")
		return false
	_is_loading = true
	# Strict load order — do NOT reorder.
	# 1. Alignment first: PlayerStats's character_applied signal triggers
	#    Spells/Skills.setup_for_class which queries Alignment.get_effective_class.
	# 2. PlayerStats: stats restored gear-free (M1); fires character_applied →
	#    CharacterSetup runs → skill trackers initialized to class defaults.
	# 3. Skill trackers + quests: overwrite class-default values with saved data.
	# 4. Inventory: items restored without applying stat bonuses (none equipped yet).
	# 5. Equipment LAST: re-equips items; apply_item_bonuses adds onto the
	#    gear-free PlayerStats baseline. No double-counting.
	Alignment.load_state(data.get("alignment", {}))
	PlayerStats.load_state(data.get("player_stats", {}))
	WeaponSkills.load_state(data.get("weapon_skills", {}))
	ArmorSkills.load_state(data.get("armor_skills", {}))
	CastingSkills.load_state(data.get("casting_skills", {}))
	QuestManager.load_state(data.get("quests", {}))
	Inventory.load_state(data.get("inventory", {}))
	Equipment.load_state(data.get("equipment", {}))
	_is_loading = false
	loaded.emit()
	DebugLog.info("[SaveManager] Loaded character %s (lvl %d %s)." % [
		PlayerStats.player_name, PlayerStats.level, PlayerStats.player_class])
	return true

func delete_save() -> void:
	for p: String in [SAVE_PATH, SAVE_PATH_TMP, SAVE_PATH_BAK]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DebugLog.info("[SaveManager] Save files deleted.")
