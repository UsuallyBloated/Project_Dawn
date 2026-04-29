extends Node

const BANK_COUNT := 10
const SLOT_COUNT := 10
const MAX_LABEL_LENGTH := 6

const TYPE_EMPTY  := "empty"
const TYPE_SPELL  := "spell"
const TYPE_SKILL  := "skill"
const TYPE_SOCIAL := "social"

var current_bank: int = 0
# banks[b][s] = { type, label, identifier, lines }
var banks: Array = []
var _save_timer: Timer = null

signal bank_changed(bank_idx: int)
signal slot_changed(bank_idx: int, slot_idx: int)

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
	return {"type": TYPE_EMPTY, "label": "", "identifier": "", "lines": []}

func get_slot(slot: int) -> Dictionary:
	return banks[current_bank][slot]

func switch_bank(idx: int) -> void:
	current_bank = clampi(idx, 0, BANK_COUNT - 1)
	bank_changed.emit(current_bank)

func set_slot_spell(slot: int, spell: SpellData) -> void:
	_set_slot(slot, TYPE_SPELL, spell.spell_name, spell.spell_name, [])

func set_slot_skill(slot: int, skill: SkillData) -> void:
	_set_slot(slot, TYPE_SKILL, skill.skill_name, skill.skill_name, [])

func set_slot_social(slot: int, label: String, lines: Array) -> void:
	_set_slot(slot, TYPE_SOCIAL, label, "", lines.duplicate())

func clear_slot(slot: int) -> void:
	banks[current_bank][slot] = _empty_slot()
	slot_changed.emit(current_bank, slot)
	_schedule_save()

func _set_slot(slot: int, type: String, label: String, identifier: String, lines: Array) -> void:
	banks[current_bank][slot] = {
		"type": type,
		"label": label.left(MAX_LABEL_LENGTH),
		"identifier": identifier,
		"lines": lines
	}
	slot_changed.emit(current_bank, slot)
	_schedule_save()

func _schedule_save() -> void:
	_save_timer.start()

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
	var target_name := ""
	if is_instance_valid(Combat.current_target):
		target_name = Combat.current_target.mob_name
	var char_name: String = PlayerStats.player_name

	for line: String in sd.get("lines", []):
		var cmd := line.strip_edges()
		if cmd == "":
			continue
		cmd = cmd.replace("%t", target_name).replace("%n", char_name)
		_execute_command(cmd)

func _execute_command(cmd: String) -> void:
	if cmd.begins_with("/say "):
		CombatLog.add_line("[Say] " + cmd.substr(5), CombatLog.MsgType.INFO)
	elif cmd.begins_with("/yell "):
		CombatLog.add_line("[Yell] " + cmd.substr(6), CombatLog.MsgType.INFO)
	elif cmd.begins_with("/shout "):
		CombatLog.add_line("[Shout] " + cmd.substr(7), CombatLog.MsgType.INFO)
	elif cmd.begins_with("/group "):
		CombatLog.add_line("[Group] " + cmd.substr(7), CombatLog.MsgType.INFO)
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
		CombatLog.add_line("[Say] " + cmd, CombatLog.MsgType.INFO)

func _save() -> void:
	var data: Array = []
	for bank: Array in banks:
		var bank_data: Array = []
		for slot: Dictionary in bank:
			bank_data.append({
				"type":       slot["type"],
				"label":      slot["label"],
				"identifier": slot["identifier"],
				"lines":      slot["lines"].duplicate()
			})
		data.append(bank_data)
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
	if not data is Array:
		return
	for b in mini((data as Array).size(), BANK_COUNT):
		if not data[b] is Array:
			continue
		for s in mini((data[b] as Array).size(), SLOT_COUNT):
			var sd = data[b][s]
			if not sd is Dictionary:
				continue
			banks[b][s] = {
				"type":       sd.get("type", TYPE_EMPTY),
				"label":      sd.get("label", ""),
				"identifier": sd.get("identifier", ""),
				"lines":      sd.get("lines", [])
			}
