extends CanvasLayer

# 10 slots: 1-9 and 0 keys. First 5 = skills, next 5 = spells (by class availability).
const SLOT_COUNT := 10
const SLOT_SIZE := 56
const KEY_LABELS := ["1","2","3","4","5","6","7","8","9","0"]
const SKILL_SLOTS := 5
const SPELL_SLOTS := 5

const C_BG      := Color(0.06, 0.05, 0.03, 0.90)
const C_BORDER  := Color(0.30, 0.22, 0.08)
const C_COOL    := Color(0.0, 0.0, 0.0, 0.65)
const C_TEXT    := Color(0.90, 0.82, 0.65)
const C_TITLE   := Color(0.95, 0.78, 0.25)
const C_READY   := Color(0.30, 0.22, 0.08)
const C_ACTIVE  := Color(0.55, 0.40, 0.10)

var _slots: Array = []         # Array of slot Dictionaries
var _tooltip_panel: Panel = null
var _tooltip_label: Label = null

func _ready() -> void:
	_build_hotbar()
	Skills.skill_cooldown_updated.connect(_on_skill_cooldown)
	Spells.spell_cooldown_updated.connect(_on_spell_cooldown)
	PlayerStats.level_changed.connect(func(_l): _refresh_slots())
	# Delay one frame so PlayerStats.player_class is set after character creation
	await get_tree().process_frame
	_refresh_slots()

func _build_hotbar() -> void:
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -(SLOT_COUNT * (SLOT_SIZE + 4)) / 2.0
	panel.offset_right = (SLOT_COUNT * (SLOT_SIZE + 4)) / 2.0
	panel.offset_top = -(SLOT_SIZE + 20)
	panel.offset_bottom = -8

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 4)
	hbox.offset_left = 8; hbox.offset_top = 8
	hbox.offset_right = -8; hbox.offset_bottom = -8
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	for i in SLOT_COUNT:
		var slot_data := {
			"index": i,
			"frame": null,
			"icon": null,
			"key_label": null,
			"cooldown_overlay": null,
			"cooldown_label": null,
			"name_label": null,
		}
		var frame := Panel.new()
		frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_style_slot(frame, false)
		hbox.add_child(frame)
		slot_data["frame"] = frame

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(icon)
		slot_data["icon"] = icon

		var cool_overlay := ColorRect.new()
		cool_overlay.color = C_COOL
		cool_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		cool_overlay.visible = false
		frame.add_child(cool_overlay)
		slot_data["cooldown_overlay"] = cool_overlay

		var cool_lbl := Label.new()
		cool_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cool_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cool_lbl.add_theme_font_size_override("font_size", 14)
		cool_lbl.add_theme_color_override("font_color", Color.WHITE)
		cool_lbl.visible = false
		frame.add_child(cool_lbl)
		slot_data["cooldown_label"] = cool_lbl

		var key_lbl := Label.new()
		key_lbl.text = KEY_LABELS[i]
		key_lbl.anchor_right = 1.0
		key_lbl.anchor_bottom = 0.35
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", C_TITLE)
		key_lbl.offset_left = 3
		frame.add_child(key_lbl)
		slot_data["key_label"] = key_lbl

		var name_lbl := Label.new()
		name_lbl.anchor_top = 0.65
		name_lbl.anchor_right = 1.0
		name_lbl.anchor_bottom = 1.0
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", C_TEXT)
		name_lbl.clip_text = true
		frame.add_child(name_lbl)
		slot_data["name_label"] = name_lbl

		frame.mouse_entered.connect(_on_slot_hover.bind(i))
		frame.mouse_exited.connect(func(): if _tooltip_panel: _tooltip_panel.visible = false)
		frame.gui_input.connect(_on_slot_clicked.bind(i))

		_slots.append(slot_data)

	_tooltip_panel = Panel.new()
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 20
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.04, 0.03, 0.02, 0.95)
	tip_style.border_color = C_BORDER
	tip_style.set_border_width_all(1)
	tip_style.set_corner_radius_all(3)
	tip_style.content_margin_left = 8
	tip_style.content_margin_top = 6
	tip_style.content_margin_right = 8
	tip_style.content_margin_bottom = 6
	_tooltip_panel.add_theme_stylebox_override("panel", tip_style)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	_tooltip_label.add_theme_color_override("font_color", C_TEXT)
	_tooltip_panel.add_child(_tooltip_label)
	panel.add_child(_tooltip_panel)

func _style_slot(frame: Panel, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = C_ACTIVE if active else C_READY
	s.border_color = C_TITLE if active else C_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", s)

func _refresh_slots() -> void:
	var skill_list: Array[SkillData] = Skills.available
	var spell_list: Array[SpellData] = Spells.available

	for i in SLOT_COUNT:
		var sd := _slots[i]
		var icon: TextureRect = sd["icon"]
		var name_lbl: Label = sd["name_label"]

		if i < SKILL_SLOTS:
			if i < skill_list.size():
				icon.texture = skill_list[i].icon
				name_lbl.text = skill_list[i].skill_name
			else:
				icon.texture = null
				name_lbl.text = ""
		else:
			var pi := i - SKILL_SLOTS
			if pi < spell_list.size():
				icon.texture = spell_list[pi].icon
				name_lbl.text = spell_list[pi].spell_name
			else:
				icon.texture = null
				name_lbl.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event.keycode
		var slot_idx := -1
		match key:
			KEY_1: slot_idx = 0
			KEY_2: slot_idx = 1
			KEY_3: slot_idx = 2
			KEY_4: slot_idx = 3
			KEY_5: slot_idx = 4
			KEY_6: slot_idx = 5
			KEY_7: slot_idx = 6
			KEY_8: slot_idx = 7
			KEY_9: slot_idx = 8
			KEY_0: slot_idx = 9
		if slot_idx >= 0:
			_activate_slot(slot_idx)

func _on_slot_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activate_slot(index)

func _activate_slot(index: int) -> void:
	if index < SKILL_SLOTS:
		Skills.use_skill_by_index(index)
	else:
		Spells.cast_by_index(index - SKILL_SLOTS)

func _on_skill_cooldown(skill_name: String, remaining: float, total: float) -> void:
	var idx := _skill_slot_index(skill_name)
	if idx < 0:
		return
	var sd := _slots[idx]
	var overlay: ColorRect = sd["cooldown_overlay"]
	var lbl: Label = sd["cooldown_label"]
	if remaining > 0.0:
		overlay.visible = true
		lbl.visible = true
		lbl.text = "%.1f" % remaining
		# Scale overlay height to represent remaining fraction
		overlay.anchor_top = 1.0 - (remaining / total)
	else:
		overlay.visible = false
		lbl.visible = false

func _on_spell_cooldown(spell_name: String, remaining: float, total: float) -> void:
	var idx := _spell_slot_index(spell_name)
	if idx < 0:
		return
	var sd := _slots[idx]
	var overlay: ColorRect = sd["cooldown_overlay"]
	var lbl: Label = sd["cooldown_label"]
	if remaining > 0.0:
		overlay.visible = true
		lbl.visible = true
		lbl.text = "%.1f" % remaining
		overlay.anchor_top = 1.0 - (remaining / total)
	else:
		overlay.visible = false
		lbl.visible = false

func _skill_slot_index(skill_name: String) -> int:
	for i in SKILL_SLOTS:
		if i < Skills.available.size() and Skills.available[i].skill_name == skill_name:
			return i
	return -1

func _spell_slot_index(spell_name: String) -> int:
	for i in SPELL_SLOTS:
		if i < Spells.available.size() and Spells.available[i].spell_name == spell_name:
			return SKILL_SLOTS + i
	return -1

func _on_slot_hover(index: int) -> void:
	var text := ""
	if index < SKILL_SLOTS:
		if index < Skills.available.size():
			var sk := Skills.available[index]
			text = "%s\n%s\nST: %.0f  CD: %.1fs" % [sk.skill_name, sk.description, sk.stamina_cost, sk.cooldown]
	else:
		var pi := index - SKILL_SLOTS
		if pi < Spells.available.size():
			var sp := Spells.available[pi]
			text = "%s\n%s\nMP: %.0f  CD: %.1fs" % [sp.spell_name, sp.description, sp.mana_cost, sp.cooldown]

	if text == "":
		_tooltip_panel.visible = false
		return

	_tooltip_label.text = text
	_tooltip_panel.position = _slots[index]["frame"].position + Vector2(0, -(80))
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.visible = true
