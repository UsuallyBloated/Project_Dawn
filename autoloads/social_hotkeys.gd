extends Node

const BANK_COUNT := 10
const SLOT_COUNT := 10
const MAX_LABEL_LENGTH := 6

const TYPE_EMPTY  := "empty"
const TYPE_SPELL  := "spell"
const TYPE_SKILL  := "skill"
const TYPE_SOCIAL := "social"

var current_bank: int = 0
# banks[b][s] = { type, label, identifier, lines, library_id }
# For TYPE_SOCIAL: lines is empty when the slot references a library
# entry (library_id non-empty); legacy slots may still have inline
# lines (migrated on load). label is denormalised from the library
# entry for tooltip / hotbar render without an extra lookup.
var banks: Array = []

# Track 16.2 — social/macro library tier. Per-character library that
# outlives any one slot or bank; slot assignment is "pick from library".
# Editing a library entry instantly updates every slot referencing it.
# library entry: { id: String, label: String, lines: Array[String] }
var library: Array = []
var _next_lib_seq: int = 1

var _save_timer: Timer = null

signal bank_changed(bank_idx: int)
signal slot_changed(bank_idx: int, slot_idx: int)
signal library_changed

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.wait_time = 0.5
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_save)
	add_child(_save_timer)
	_init_banks()
	_load()

func _init_banks() -> void:
	banks.clear()
	for _b in BANK_COUNT:
		var bank: Array = []
		for _s in SLOT_COUNT:
			bank.append(_empty_slot())
		banks.append(bank)

func _empty_slot() -> Dictionary:
	return {"type": TYPE_EMPTY, "label": "", "identifier": "", "lines": [], "library_id": ""}

func get_slot(slot: int) -> Dictionary:
	return banks[current_bank][slot]

func switch_bank(idx: int) -> void:
	current_bank = clampi(idx, 0, BANK_COUNT - 1)
	bank_changed.emit(current_bank)

func set_slot_spell(slot: int, spell: SpellData) -> void:
	_set_slot(slot, TYPE_SPELL, spell.spell_name, spell.spell_name, [], "")

func set_slot_skill(slot: int, skill: SkillData) -> void:
	_set_slot(slot, TYPE_SKILL, skill.skill_name, skill.skill_name, [], "")

# Track 16.2 — legacy API kept as a one-shot convenience: callers that
# pass inline lines get a library entry minted for them, and the slot
# stores a ref. New code should call library_add → set_slot_social_ref
# directly.
func set_slot_social(slot: int, label: String, lines: Array) -> void:
	var id := library_add(label, lines)
	set_slot_social_ref(slot, id)

func set_slot_social_ref(slot: int, library_id: String) -> void:
	var entry := library_get(library_id)
	if entry.is_empty():
		return
	_set_slot(slot, TYPE_SOCIAL, entry["label"], "", [], library_id)

func clear_slot(slot: int) -> void:
	banks[current_bank][slot] = _empty_slot()
	slot_changed.emit(current_bank, slot)
	_schedule_save()

func _set_slot(slot: int, type: String, label: String, identifier: String, lines: Array, library_id: String) -> void:
	banks[current_bank][slot] = {
		"type": type,
		"label": label.left(MAX_LABEL_LENGTH),
		"identifier": identifier,
		"lines": lines,
		"library_id": library_id,
	}
	slot_changed.emit(current_bank, slot)
	_schedule_save()

func _schedule_save() -> void:
	_save_timer.start()

# ── Library API ───────────────────────────────────────────────────────

func library_add(label: String, lines: Array) -> String:
	var id := _mint_id()
	library.append({
		"id":    id,
		"label": label.left(MAX_LABEL_LENGTH),
		"lines": lines.duplicate(),
	})
	library_changed.emit()
	_schedule_save()
	return id

func library_edit(id: String, label: String, lines: Array) -> void:
	for entry: Dictionary in library:
		if entry["id"] == id:
			entry["label"] = label.left(MAX_LABEL_LENGTH)
			entry["lines"] = lines.duplicate()
			break
	# Slots that ref this entry need their denormalised label updated.
	for b in BANK_COUNT:
		for s in SLOT_COUNT:
			var slot: Dictionary = banks[b][s]
			if slot.get("type") == TYPE_SOCIAL and slot.get("library_id") == id:
				slot["label"] = label.left(MAX_LABEL_LENGTH)
				slot_changed.emit(b, s)
	library_changed.emit()
	_schedule_save()

func library_delete(id: String) -> void:
	for i in range(library.size() - 1, -1, -1):
		if library[i]["id"] == id:
			library.remove_at(i)
			break
	# Clear every slot that referenced the deleted entry.
	for b in BANK_COUNT:
		for s in SLOT_COUNT:
			var slot: Dictionary = banks[b][s]
			if slot.get("type") == TYPE_SOCIAL and slot.get("library_id") == id:
				banks[b][s] = _empty_slot()
				slot_changed.emit(b, s)
	library_changed.emit()
	_schedule_save()

func library_list() -> Array:
	return library

func library_get(id: String) -> Dictionary:
	for entry: Dictionary in library:
		if entry["id"] == id:
			return entry
	return {}

func _mint_id() -> String:
	var id := "lib_%d_%d" % [Time.get_unix_time_from_system(), _next_lib_seq]
	_next_lib_seq += 1
	return id

# ── Execution ─────────────────────────────────────────────────────────

func execute_slot(slot: int) -> void:
	var sd: Dictionary = banks[current_bank][slot]
	match sd["type"]:
		TYPE_SPELL:
			_cast_spell(sd["identifier"])
		TYPE_SKILL:
			_use_skill(sd["identifier"])
		TYPE_SOCIAL:
			_execute_social(sd)

func _cast_spell(spell_name: String) -> void:
	# Track 18.2 — a spell mapped to a hotkey-bar slot is a convenience
	# shortcut to the spell bar. Classic-MMO rule: you can only cast
	# what's memorized. Check SpellBar; if the spell isn't there,
	# refuse and log so the player knows why their keybind is silent.
	var memorized := false
	for i in SpellBar.SLOT_COUNT:
		if SpellBar.get_slot(i) == spell_name:
			memorized = true
			break
	if not memorized:
		CombatLog.add_line(
			"You haven't memorized %s." % spell_name,
			CombatLog.MsgType.INFO,
		)
		return
	for i in Spells.available.size():
		if Spells.available[i].spell_name == spell_name:
			Spells.cast_by_index(i)
			return

func _use_skill(skill_name: String) -> void:
	for i in Skills.available.size():
		if Skills.available[i].skill_name == skill_name:
			Skills.use_skill_by_index(i)
			return

func _execute_social(sd: Dictionary) -> void:
	# Prefer the library entry — slot lines are kept empty on new
	# saves but stay populated for legacy / pre-migration slots.
	var lines: Array = sd.get("lines", [])
	var lib_id: String = sd.get("library_id", "")
	if lib_id != "":
		var entry := library_get(lib_id)
		if not entry.is_empty():
			lines = entry["lines"]

	var target_name := ""
	if is_instance_valid(Combat.current_target):
		target_name = Combat.current_target.mob_name
	var char_name: String = PlayerStats.player_name

	for line: String in lines:
		var cmd := line.strip_edges()
		if cmd == "":
			continue
		cmd = cmd.replace("%t", target_name).replace("%n", char_name)
		_execute_command(cmd)

func _execute_command(cmd: String) -> void:
	if cmd.begins_with("/lang "):
		var lang := cmd.substr(6).strip_edges()
		if lang not in LanguageDefinitions.LANGUAGES:
			CombatLog.add_line("Unknown language: %s" % lang, CombatLog.MsgType.INFO)
		elif Languages.get_skill(lang) == 0:
			CombatLog.add_line("You do not know that language.", CombatLog.MsgType.INFO)
		else:
			Languages.set_active_language(lang)
			CombatLog.add_line("You will now speak in %s." % lang, CombatLog.MsgType.INFO)
	elif cmd == "/languages":
		CombatLog.add_line("Your languages:", CombatLog.MsgType.INFO)
		for lang in LanguageDefinitions.LANGUAGES:
			var skill := Languages.get_skill(lang)
			if skill > 0:
				var marker := " *" if lang == Languages.active_language else ""
				CombatLog.add_line("  %s: %d/100%s" % [lang, skill, marker], CombatLog.MsgType.INFO)
	elif cmd.begins_with("/say "):
		CombatLog.add_line("[Say%s] %s" % [_lang_tag(), cmd.substr(5)], CombatLog.MsgType.INFO)
	elif cmd.begins_with("/yell "):
		CombatLog.add_line("[Yell%s] %s" % [_lang_tag(), cmd.substr(6)], CombatLog.MsgType.INFO)
	elif cmd.begins_with("/shout "):
		CombatLog.add_line("[Shout%s] %s" % [_lang_tag(), cmd.substr(7)], CombatLog.MsgType.INFO)
	elif cmd.begins_with("/group "):
		CombatLog.add_line("[Group%s] %s" % [_lang_tag(), cmd.substr(7)], CombatLog.MsgType.INFO)
	elif cmd.begins_with("/tell "):
		var rest := cmd.substr(6)
		var sep := rest.find(" ")
		if sep > 0:
			var to := rest.left(sep)
			var msg := rest.substr(sep + 1)
			CombatLog.add_line("[Tell -> %s] %s" % [to, msg], CombatLog.MsgType.INFO)
	elif cmd == "/sit":
		CombatLog.add_line("You sit down.", CombatLog.MsgType.INFO)
	elif cmd == "/stand":
		CombatLog.add_line("You stand up.", CombatLog.MsgType.INFO)
	elif cmd == "/attack":
		if is_instance_valid(Combat.current_target):
			Combat.set_target(Combat.current_target)
	elif cmd.begins_with("/"):
		CombatLog.add_line(cmd, CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("[Say%s] %s" % [_lang_tag(), cmd], CombatLog.MsgType.INFO)

func _lang_tag() -> String:
	var lang := Languages.active_language
	return "" if lang == "Common" else " (%s)" % lang

# ── Persistence ───────────────────────────────────────────────────────

func _save() -> void:
	var data := {
		"banks": [],
		"library": [],
		"next_lib_seq": _next_lib_seq,
	}
	for bank: Array in banks:
		var bank_data: Array = []
		for slot: Dictionary in bank:
			bank_data.append({
				"type":       slot["type"],
				"label":      slot["label"],
				"identifier": slot["identifier"],
				"lines":      slot["lines"].duplicate(),
				"library_id": slot.get("library_id", ""),
			})
		(data["banks"] as Array).append(bank_data)
	for entry: Dictionary in library:
		(data["library"] as Array).append({
			"id":    entry["id"],
			"label": entry["label"],
			"lines": entry["lines"].duplicate(),
		})
	var f := FileAccess.open("user://social_hotkeys.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func _load() -> void:
	var f := FileAccess.open("user://social_hotkeys.json", FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data

	# Track 16.2 — accept the legacy schema (top-level Array of banks)
	# and the new schema (Dictionary with banks + library + seq). The
	# migration mints library entries for any inline-lines socials so
	# the player's existing macros survive the upgrade.
	var loaded_banks
	if data is Array:
		loaded_banks = data
	elif data is Dictionary:
		loaded_banks = data.get("banks", [])
		var lib_data = data.get("library", [])
		if lib_data is Array:
			for entry in lib_data:
				if entry is Dictionary:
					library.append({
						"id":    entry.get("id", _mint_id()),
						"label": entry.get("label", ""),
						"lines": entry.get("lines", []),
					})
		_next_lib_seq = int(data.get("next_lib_seq", 1))
	else:
		return

	if not loaded_banks is Array:
		return
	for b in mini((loaded_banks as Array).size(), BANK_COUNT):
		if not loaded_banks[b] is Array:
			continue
		for s in mini((loaded_banks[b] as Array).size(), SLOT_COUNT):
			var sd = loaded_banks[b][s]
			if not sd is Dictionary:
				continue
			var slot := {
				"type":       sd.get("type", TYPE_EMPTY),
				"label":      sd.get("label", ""),
				"identifier": sd.get("identifier", ""),
				"lines":      sd.get("lines", []),
				"library_id": sd.get("library_id", ""),
			}
			# Migration: a SOCIAL slot with inline lines but no
			# library_id gets a library entry minted.
			if slot["type"] == TYPE_SOCIAL and slot["library_id"] == "" \
					and not (slot["lines"] as Array).is_empty():
				var id := library_add(slot["label"], slot["lines"])
				slot["library_id"] = id
				slot["lines"] = []
			banks[b][s] = slot
