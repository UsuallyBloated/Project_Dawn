extends CanvasLayer

const SLOT_COUNT := 10
const SLOT_SIZE  := 40
const BAR_GAP    := 6

const C_BG    := Color(0.06, 0.05, 0.03, 0.90)
const C_COOL  := Color(0.0, 0.0, 0.0, 0.65)
const C_READY := Color(0.30, 0.22, 0.08)
const C_ACTIVE := Color(0.55, 0.40, 0.10)

const KEY_LABELS       := ["1","2","3","4","5","6","7","8","9","0"]
const KEY_LABELS_SPELL := ["A+1","A+2","A+3","A+4","A+5","A+6","A+7","A+8","A+9","A+0"]

var _skill_slots: Array = []
var _spell_slots: Array = []

var _skill_panel: DraggablePanel = null
var _spell_panel: DraggablePanel = null

var _tooltip_panel: Panel = null
var _tooltip_label: Label = null

func _ready() -> void:
	var bar_h: float = SLOT_SIZE + 20

	_skill_panel = _build_bar(_skill_slots, KEY_LABELS, -bar_h / 2.0 - BAR_GAP / 2.0)
	_spell_panel = _build_bar(_spell_slots, KEY_LABELS_SPELL, 0.0, true)

	var tip := _skill_panel.make_tooltip()
	_tooltip_panel = tip[0]
	_tooltip_label = tip[1]

	Skills.skill_cooldown_updated.connect(_on_skill_cooldown)
	Spells.spell_cooldown_updated.connect(_on_spell_cooldown)
	PlayerStats.level_changed.connect(func(_l): _refresh_slots())

	await get_tree().process_frame
	_refresh_slots()

func _build_bar(slot_array: Array, labels: Array, offset_center_y: float, vertical: bool = false) -> DraggablePanel:
	var bar_w: float
	var bar_h: float
	if vertical:
		bar_w = SLOT_SIZE + 20
		bar_h = SLOT_COUNT * (SLOT_SIZE + 4) + 16
	else:
		bar_w = SLOT_COUNT * (SLOT_SIZE + 4) + 16
		bar_h = SLOT_SIZE + 20

	var panel := DraggablePanel.new()
	if vertical:
		panel.anchor_left   = 1.0
		panel.anchor_right  = 1.0
		panel.anchor_top    = 0.5
		panel.anchor_bottom = 0.5
		panel.offset_left   = -(bar_w + 10)
		panel.offset_right  = -10
		panel.offset_top    = -bar_h / 2.0
		panel.offset_bottom =  bar_h / 2.0
	else:
		panel.anchor_left   = 0.5
		panel.anchor_right  = 0.5
		panel.anchor_top    = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left   = -bar_w / 2.0
		panel.offset_right  =  bar_w / 2.0
		panel.offset_top    = offset_center_y - bar_h / 2.0
		panel.offset_bottom = offset_center_y + bar_h / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.offset_left = 8; box.offset_top = 8
	box.offset_right = -8; box.offset_bottom = -8
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	for i in SLOT_COUNT:
		var sd := {
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
		box.add_child(frame)
		sd["frame"] = frame

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(icon)
		sd["icon"] = icon

		var cool_overlay := ColorRect.new()
		cool_overlay.color = C_COOL
		cool_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		cool_overlay.visible = false
		frame.add_child(cool_overlay)
		sd["cooldown_overlay"] = cool_overlay

		var cool_lbl := Label.new()
		cool_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cool_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cool_lbl.add_theme_font_size_override("font_size", 14)
		cool_lbl.add_theme_color_override("font_color", Color.WHITE)
		cool_lbl.visible = false
		frame.add_child(cool_lbl)
		sd["cooldown_label"] = cool_lbl

		var key_lbl := Label.new()
		key_lbl.text = labels[i]
		key_lbl.anchor_right = 1.0
		key_lbl.anchor_bottom = 0.35
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
		key_lbl.offset_left = 3
		frame.add_child(key_lbl)
		sd["key_label"] = key_lbl

		var name_lbl := Label.new()
		name_lbl.anchor_top = 0.65
		name_lbl.anchor_right = 1.0
		name_lbl.anchor_bottom = 1.0
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		name_lbl.clip_text = true
		frame.add_child(name_lbl)
		sd["name_label"] = name_lbl

		var is_spell_bar := (labels == KEY_LABELS_SPELL)
		frame.mouse_entered.connect(_on_slot_hover.bind(i, is_spell_bar))
		frame.mouse_exited.connect(func(): if _tooltip_panel: _tooltip_panel.visible = false)
		frame.gui_input.connect(_on_slot_clicked.bind(i, is_spell_bar))

		slot_array.append(sd)

	return panel


func _style_slot(frame: Panel, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = C_ACTIVE if active else C_READY
	s.border_color = UITheme.C_TITLE if active else UITheme.C_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", s)

func _refresh_slots() -> void:
	var skill_list: Array[SkillData] = Skills.available
	var spell_list: Array[SpellData] = Spells.available

	for i in SLOT_COUNT:
		var sk_sd: Dictionary = _skill_slots[i]
		if i < skill_list.size():
			(sk_sd["icon"] as TextureRect).texture = skill_list[i].icon
			(sk_sd["name_label"] as Label).text = skill_list[i].skill_name
		else:
			(sk_sd["icon"] as TextureRect).texture = null
			(sk_sd["name_label"] as Label).text = ""

		var sp_sd: Dictionary = _spell_slots[i]
		if i < spell_list.size():
			(sp_sd["icon"] as TextureRect).texture = spell_list[i].icon
			(sp_sd["name_label"] as Label).text = spell_list[i].spell_name
		else:
			(sp_sd["icon"] as TextureRect).texture = null
			(sp_sd["name_label"] as Label).text = ""

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
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
	if slot_idx < 0:
		return
	if event.alt_pressed:
		Spells.cast_by_index(slot_idx)
	else:
		Skills.use_skill_by_index(slot_idx)

func _on_slot_clicked(event: InputEvent, index: int, is_spell: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_spell:
			Spells.cast_by_index(index)
		else:
			Skills.use_skill_by_index(index)

func _on_skill_cooldown(skill_name: String, remaining: float, total: float) -> void:
	for i in SLOT_COUNT:
		if i < Skills.available.size() and Skills.available[i].skill_name == skill_name:
			_apply_cooldown(_skill_slots[i], remaining, total)
			return

func _on_spell_cooldown(spell_name: String, remaining: float, total: float) -> void:
	for i in SLOT_COUNT:
		if i < Spells.available.size() and Spells.available[i].spell_name == spell_name:
			_apply_cooldown(_spell_slots[i], remaining, total)
			return

func _apply_cooldown(sd: Dictionary, remaining: float, total: float) -> void:
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

func _on_slot_hover(index: int, is_spell: bool) -> void:
	var text := ""
	if is_spell:
		if index < Spells.available.size():
			var sp := Spells.available[index]
			text = "%s\n%s\nMP: %.0f  CD: %.1fs" % [sp.spell_name, sp.description, sp.mana_cost, sp.cooldown]
	else:
		if index < Skills.available.size():
			var sk := Skills.available[index]
			text = "%s\n%s\nST: %.0f  CD: %.1fs" % [sk.skill_name, sk.description, sk.stamina_cost, sk.cooldown]

	if text == "":
		_tooltip_panel.visible = false
		return

	_tooltip_label.text = text
	var frame: Panel = ((_spell_slots if is_spell else _skill_slots)[index]["frame"])
	_tooltip_panel.position = frame.global_position - _skill_panel.global_position + Vector2(0, -80)
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.visible = true
