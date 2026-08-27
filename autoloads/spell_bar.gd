extends Node

# Track 16.1 — memorize bar storage. The right-side spell bar used to
# auto-populate from `Spells.available`; now slots hold a memorized
# spell name and the player explicitly assigns / clears them via the
# memorize workflow (sit + spell-book click + spell-bar slot click).
#
# Storage is per-character (actually per-character since the 2026-08-26
# keyed-save split — before that one global file shared the memorized bar
# across every character on the machine, the same bleed the hotbar had).
# Each character owns user://spell_bar_c<char_id>.json, reloaded on the
# world handshake; the old global file stays as a first-login seed and as
# the Test Room's store. Slot value is the spell name as it appears in
# `Spells.available[i].spell_name`; empty string means the slot is empty.

const SLOT_COUNT := 10
const LEGACY_SAVE_PATH := "user://spell_bar.json"

# Track 17.1 — slots unlock with level. Below MIN_SLOTS even L1 casters
# get a workable bar; the cap climbs one slot per 5 levels until L35
# unlocks the full 10. Classic-MMO pacing: forces "what do I memorize
# this fight?" decisions early on and gradually relaxes them.
const MIN_SLOTS := 3
const SLOTS_PER_LEVEL_TIER := 5  # +1 slot per N levels above 1

signal slot_changed(slot: int)
signal cap_changed(new_cap: int)

var slots: Array = []
var _save_timer: Timer = null
var _char_key: String = ""  # "" until the world handshake names the character

func _save_path() -> String:
	if _char_key == "":
		return LEGACY_SAVE_PATH
	return "user://spell_bar_c%s.json" % _char_key

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.wait_time = 0.5
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_save)
	add_child(_save_timer)
	_init_slots()
	_load_from(_save_path())
	Spells.spells_changed.connect(_on_spells_changed)
	PlayerStats.level_changed.connect(_on_level_changed)
	Net.app_connected.connect(_on_app_connected)

# A character logged into the world: swap to that character's memorized
# bar. Flush any pending save first so the debounce timer can't write the
# previous character's slots into this one's file. Ordering note: this
# handler connects at process start, so within the app_connected emission
# it runs BEFORE the lobby's handler that drives PlayerStats.apply_character
# — the reload lands first, and the setup_for_class → spells_changed chain
# that follows prunes any seeded spell this class can't use.
func _on_app_connected(player_id: int) -> void:
	var key := str(player_id)
	if key == _char_key:
		return
	if _save_timer.time_left > 0.0:
		_save_timer.stop()
		_save()
	_char_key = key
	_init_slots()
	if not FileAccess.file_exists(_save_path()) and FileAccess.file_exists(LEGACY_SAVE_PATH):
		# First login since the split: seed from the old global file so the
		# existing bar survives, persisted under this character's own key.
		_load_from(LEGACY_SAVE_PATH)
		_save_timer.start()
	else:
		_load_from(_save_path())
	for i in SLOT_COUNT:
		slot_changed.emit(i)

func max_slots_for_level(level: int = -1) -> int:
	var lvl: int = PlayerStats.level if level < 0 else level
	return clampi(MIN_SLOTS + lvl / SLOTS_PER_LEVEL_TIER, MIN_SLOTS, SLOT_COUNT)

func is_slot_unlocked(slot: int) -> bool:
	return slot >= 0 and slot < max_slots_for_level()

func _on_level_changed(_lvl: int) -> void:
	cap_changed.emit(max_slots_for_level())

func _init_slots() -> void:
	slots.clear()
	for _i in SLOT_COUNT:
		slots.append("")

func get_slot(slot: int) -> String:
	if slot < 0 or slot >= SLOT_COUNT:
		return ""
	return slots[slot]

func set_slot(slot: int, spell_name: String) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	# Track 17.1 — clearing a slot ("") is always allowed; assigning
	# requires the slot to be unlocked at the player's current level.
	if spell_name != "" and not is_slot_unlocked(slot):
		return
	slots[slot] = spell_name
	slot_changed.emit(slot)
	_save_timer.start()

# Track 17.1 — first level at which a given slot index becomes
# available. Used by the hotbar to render "Lv N" on locked slots.
func unlock_level_for_slot(slot: int) -> int:
	if slot < MIN_SLOTS:
		return 1
	return (slot - MIN_SLOTS + 1) * SLOTS_PER_LEVEL_TIER

func clear_slot(slot: int) -> void:
	set_slot(slot, "")

func get_spell(slot: int) -> SpellData:
	var n := get_slot(slot)
	if n == "":
		return null
	for sp in Spells.available:
		if sp.spell_name == n:
			return sp
	return null

func cast_slot(slot: int) -> bool:
	var sp := get_spell(slot)
	if sp == null:
		return false
	return Spells.cast_spell(sp)

func _on_spells_changed() -> void:
	# Clear any slot whose memorized spell is no longer in the
	# available list (level-up rank refresh, alignment shift, etc.).
	var dropped := false
	for i in SLOT_COUNT:
		var n: String = slots[i]
		if n == "":
			continue
		var found := false
		for sp in Spells.available:
			if sp.spell_name == n:
				found = true
				break
		if not found:
			slots[i] = ""
			slot_changed.emit(i)
			dropped = true
	if dropped:
		_save_timer.start()

func _save() -> void:
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(slots, "\t"))
		f.close()

func _load_from(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if not data is Array:
		return
	for i in mini((data as Array).size(), SLOT_COUNT):
		var v = data[i]
		if v is String:
			slots[i] = v
