extends CanvasLayer

const SLOT_COUNT := 10
const SLOT_SIZE  := 40
const BAR_GAP    := 6

const C_BG     := Color(0.06, 0.05, 0.03, 0.90)
const C_COOL   := Color(0.0, 0.0, 0.0, 0.65)
const C_READY  := Color(0.30, 0.22, 0.08)
const C_ACTIVE := Color(0.55, 0.40, 0.10)

const KEY_LABELS       := ["1","2","3","4","5","6","7","8","9","0"]
const KEY_LABELS_SPELL := ["A+1","A+2","A+3","A+4","A+5","A+6","A+7","A+8","A+9","A+0"]

var _hotkey_slots: Array          = []
var _hotkey_panel: DraggablePanel = null
var _bank_label: Label            = null

var _spell_slots: Array           = []
var _spell_panel: DraggablePanel  = null

var _tooltip_panel: Panel         = null
var _tooltip_label: Label         = null

var _ctx_menu: PopupMenu          = null
var _spell_menu: PopupMenu        = null
var _skill_menu: PopupMenu        = null
var _ctx_slot: int                = -1

var _social_win: Window           = null
var _social_label_edit: LineEdit  = null
var _social_line_edits: Array[LineEdit] = []
var _social_editing_slot: int     = -1

var _hotkey_by_skill: Dictionary  = {}
var _hotkey_by_spell: Dictionary  = {}
var _spell_bar_idx:   Dictionary  = {}

func _ready() -> void:
	var bar_h: float = SLOT_SIZE + 20

	_hotkey_panel = _build_hotkey_bar(bar_h)
	_spell_panel  = _build_spell_bar(bar_h)

	var tip := _hotkey_panel.make_tooltip()
	_tooltip_panel = tip[0]
	_tooltip_label = tip[1]

	_build_context_menu()
	_build_social_editor()

	Skills.skill_cooldown_updated.connect(_on_skill_cooldown)
	Skills.skills_changed.connect(_refresh_hotkey_slots)
	Spells.spell_cooldown_updated.connect(_on_spell_cooldown)
	Spells.spells_changed.connect(_refresh_spell_slots)
	SocialHotkeys.bank_changed.connect(_on_bank_changed)
	SocialHotkeys.slot_changed.connect(_on_slot_changed)
	PlayerStats.level_changed.connect(func(_l): _refresh_spell_slots())

	await get_tree().process_frame
	_refresh_hotkey_slots()
	_refresh_spell_slots()

func _build_hotkey_bar(bar_h: float) -> DraggablePanel:
	var bar_w: float = SLOT_COUNT * (SLOT_SIZE + 4) + 16

	var panel := DraggablePanel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 1.0
	panel.anchor_bottom = 1.0
	var extra_h := 20.0  # room for bank nav row
	panel.offset_left   = -bar_w / 2.0
	panel.offset_right  =  bar_w / 2.0
	panel.offset_top    = -(bar_h + extra_h) - BAR_GAP / 2.0
	panel.offset_bottom = -BAR_GAP / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.offset_left = 8; vbox.offset_top = 4
	vbox.offset_right = -8; vbox.offset_bottom = -4
	panel.add_child(vbox)

	# Bank navigation row
	var nav_row := HBoxContainer.new()
	nav_row.custom_minimum_size.y = 16
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 4)
	vbox.add_child(nav_row)

	var btn_prev := Button.new()
	btn_prev.text = "<"
	btn_prev.custom_minimum_size = Vector2(18, 16)
	btn_prev.add_theme_font_size_override("font_size", 10)
	btn_prev.pressed.connect(func(): SocialHotkeys.switch_bank(SocialHotkeys.current_bank - 1))
	nav_row.add_child(btn_prev)

	_bank_label = Label.new()
	_bank_label.text = "Bank 1"
	_bank_label.add_theme_font_size_override("font_size", 10)
	_bank_label.add_theme_color_override("font_color", UITheme.C_TITLE)
	_bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bank_label.custom_minimum_size.x = 50
	nav_row.add_child(_bank_label)

	var btn_next := Button.new()
	btn_next.text = ">"
	btn_next.custom_minimum_size = Vector2(18, 16)
	btn_next.add_theme_font_size_override("font_size", 10)
	btn_next.pressed.connect(func(): SocialHotkeys.switch_bank(SocialHotkeys.current_bank + 1))
	nav_row.add_child(btn_next)

	# Slot row
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 4)
	vbox.add_child(slot_row)

	for i in SLOT_COUNT:
		var sd := {
			"index":            i,
			"frame":            null,
			"icon":             null,
			"key_label":        null,
			"name_label":       null,
			"cooldown_overlay": null,
			"cooldown_label":   null,
		}
		var frame := Panel.new()
		frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_style_slot(frame, false)
		slot_row.add_child(frame)
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
		key_lbl.text = KEY_LABELS[i]
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

		frame.mouse_entered.connect(_on_hotkey_hover.bind(i))
		frame.mouse_exited.connect(func(): if _tooltip_panel: _tooltip_panel.visible = false)
		frame.gui_input.connect(_on_hotkey_input.bind(i))

		_hotkey_slots.append(sd)

	return panel

func _build_spell_bar(bar_h: float) -> DraggablePanel:
	var bar_w: float = SLOT_SIZE + 20
	var total_h: float = SLOT_COUNT * (SLOT_SIZE + 4) + 16

	var panel := DraggablePanel.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -(bar_w + 10)
	panel.offset_right  = -10
	panel.offset_top    = -total_h / 2.0
	panel.offset_bottom =  total_h / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.offset_left = 8; box.offset_top = 8
	box.offset_right = -8; box.offset_bottom = -8
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	for i in SLOT_COUNT:
		var sd := {
			"index":            i,
			"frame":            null,
			"icon":             null,
			"key_label":        null,
			"name_label":       null,
			"cooldown_overlay": null,
			"cooldown_label":   null,
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
		key_lbl.text = KEY_LABELS_SPELL[i]
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

		frame.mouse_entered.connect(_on_spell_hover.bind(i))
		frame.mouse_exited.connect(func(): if _tooltip_panel: _tooltip_panel.visible = false)
		frame.gui_input.connect(_on_spell_clicked.bind(i))

		_spell_slots.append(sd)

	return panel

func _build_context_menu() -> void:
	_ctx_menu = PopupMenu.new()
	_ctx_menu.add_item("Assign Spell...",  0)
	_ctx_menu.add_item("Assign Skill...",  1)
	_ctx_menu.add_item("Create Social...", 2)
	_ctx_menu.add_separator()
	_ctx_menu.add_item("Clear",            3)
	_ctx_menu.id_pressed.connect(_on_ctx_menu_id)
	add_child(_ctx_menu)

	_spell_menu = PopupMenu.new()
	_spell_menu.id_pressed.connect(_on_spell_assign)
	add_child(_spell_menu)

	_skill_menu = PopupMenu.new()
	_skill_menu.id_pressed.connect(_on_skill_assign)
	add_child(_skill_menu)

func _on_hotkey_input(event: InputEvent, slot: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		SocialHotkeys.execute_slot(slot)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_ctx_slot = slot
		_ctx_menu.popup(Rect2i(int(mb.global_position.x), int(mb.global_position.y), 0, 0))

func _on_ctx_menu_id(id: int) -> void:
	match id:
		0: _open_spell_assign_menu()
		1: _open_skill_assign_menu()
		2: _open_social_editor(_ctx_slot)
		3: SocialHotkeys.clear_slot(_ctx_slot)

func _open_spell_assign_menu() -> void:
	var names: Array = []
	for sp in Spells.available: names.append(sp.spell_name)
	_open_assign_menu(_spell_menu, names, 0)

func _open_skill_assign_menu() -> void:
	var names: Array = []
	for sk in Skills.available: names.append(sk.skill_name)
	_open_assign_menu(_skill_menu, names, 1)

func _open_assign_menu(menu: PopupMenu, names: Array, ctx_item_idx: int) -> void:
	menu.clear()
	for i in names.size():
		menu.add_item(names[i], i)
	if menu.item_count == 0:
		menu.add_item("(none available)", -1)
	var r: Rect2 = _ctx_menu.get_item_rect(ctx_item_idx)
	menu.popup(Rect2i(int(_ctx_menu.position.x) + r.size.x, int(_ctx_menu.position.y), 0, 0))

func _on_spell_assign(id: int) -> void:
	if id < 0 or id >= Spells.available.size():
		return
	SocialHotkeys.set_slot_spell(_ctx_slot, Spells.available[id])

func _on_skill_assign(id: int) -> void:
	if id < 0 or id >= Skills.available.size():
		return
	SocialHotkeys.set_slot_skill(_ctx_slot, Skills.available[id])

func _build_social_editor() -> void:
	_social_win = Window.new()
	_social_win.title = "Social / Macro"
	_social_win.size = Vector2i(340, 280)
	_social_win.unresizable = true
	_social_win.visible = false
	_social_win.close_requested.connect(func(): _social_win.hide())
	add_child(_social_win)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12; vbox.offset_top = 12
	vbox.offset_right = -12; vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 6)
	_social_win.add_child(vbox)

	# Label row
	var lbl_row := HBoxContainer.new()
	vbox.add_child(lbl_row)
	var lbl_hdr := Label.new()
	lbl_hdr.text = "Button Label (6 chars):"
	lbl_hdr.add_theme_font_size_override("font_size", 11)
	lbl_row.add_child(lbl_hdr)

	_social_label_edit = LineEdit.new()
	_social_label_edit.max_length = 6
	_social_label_edit.custom_minimum_size.x = 80
	lbl_row.add_child(_social_label_edit)

	# Help text
	var help := Label.new()
	help.text = "Commands: /say /yell /shout /group /tell name msg\n/sit  /stand  /attack\nVars: %t = target name,  %n = your name"
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", UITheme.C_TEXT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(help)

	# Five command lines
	_social_line_edits.clear()
	for i in 5:
		var row := HBoxContainer.new()
		vbox.add_child(row)

		var lnum := Label.new()
		lnum.text = "Line %d:" % (i + 1)
		lnum.custom_minimum_size.x = 50
		lnum.add_theme_font_size_override("font_size", 11)
		row.add_child(lnum)

		var le := LineEdit.new()
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.placeholder_text = "/say Hello!" if i == 0 else ""
		row.add_child(le)
		_social_line_edits.append(le)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.pressed.connect(func(): _social_win.hide())
	btn_row.add_child(btn_cancel)

	var btn_ok := Button.new()
	btn_ok.text = "OK"
	btn_ok.pressed.connect(_on_social_ok)
	btn_row.add_child(btn_ok)

func _open_social_editor(slot: int) -> void:
	_social_editing_slot = slot
	var sd: Dictionary = SocialHotkeys.get_slot(slot)
	if sd["type"] == SocialHotkeys.TYPE_SOCIAL:
		_social_label_edit.text = sd["label"]
		var lines: Array = sd["lines"]
		for i in 5:
			_social_line_edits[i].text = lines[i] if i < lines.size() else ""
	else:
		_social_label_edit.text = ""
		for le in _social_line_edits:
			le.text = ""
	_social_win.popup_centered()

func _on_social_ok() -> void:
	var lbl: String = _social_label_edit.text.strip_edges()
	if lbl == "":
		lbl = "Macro"
	var lines: Array = []
	for le: LineEdit in _social_line_edits:
		lines.append(le.text)
	SocialHotkeys.set_slot_social(_social_editing_slot, lbl, lines)
	_social_win.hide()

func _refresh_hotkey_slots() -> void:
	_bank_label.text = "Bank %d" % (SocialHotkeys.current_bank + 1)
	for i in SLOT_COUNT:
		_update_hotkey_slot(i)
	_rebuild_hotkey_maps()

func _update_hotkey_slot(i: int) -> void:
	var sd: Dictionary  = SocialHotkeys.get_slot(i)
	var vis: Dictionary = _hotkey_slots[i]

	var icon: TextureRect = vis["icon"]
	var name_lbl: Label   = vis["name_label"]

	match sd["type"]:
		SocialHotkeys.TYPE_SPELL:
			var sp := _find_spell(sd["identifier"])
			icon.texture = sp.icon if sp else null
			name_lbl.text = sd["label"]
		SocialHotkeys.TYPE_SKILL:
			var sk := _find_skill(sd["identifier"])
			icon.texture = sk.icon if sk else null
			name_lbl.text = sd["label"]
		SocialHotkeys.TYPE_SOCIAL:
			icon.texture = null
			name_lbl.text = sd["label"]
		_:
			icon.texture = null
			name_lbl.text = ""

func _refresh_spell_slots() -> void:
	_spell_bar_idx.clear()
	var spell_list: Array[SpellData] = Spells.available
	for i in SLOT_COUNT:
		var vis: Dictionary = _spell_slots[i]
		if i < spell_list.size():
			(vis["icon"] as TextureRect).texture = spell_list[i].icon
			(vis["name_label"] as Label).text    = spell_list[i].spell_name
			_spell_bar_idx[spell_list[i].spell_name] = i
		else:
			(vis["icon"] as TextureRect).texture = null
			(vis["name_label"] as Label).text    = ""

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
		SocialHotkeys.execute_slot(slot_idx)

func _on_spell_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Spells.cast_by_index(index)

func _on_skill_cooldown(skill_name: String, remaining: float, total: float) -> void:
	var idx: int = _hotkey_by_skill.get(skill_name, -1)
	if idx >= 0:
		_apply_cooldown(_hotkey_slots[idx], remaining, total)

func _on_spell_cooldown(spell_name: String, remaining: float, total: float) -> void:
	var hidx: int = _hotkey_by_spell.get(spell_name, -1)
	if hidx >= 0:
		_apply_cooldown(_hotkey_slots[hidx], remaining, total)
	var sidx: int = _spell_bar_idx.get(spell_name, -1)
	if sidx >= 0:
		_apply_cooldown(_spell_slots[sidx], remaining, total)

func _apply_cooldown(vis: Dictionary, remaining: float, total: float) -> void:
	var overlay: ColorRect = vis["cooldown_overlay"]
	var lbl: Label         = vis["cooldown_label"]
	if remaining > 0.0:
		overlay.visible   = true
		lbl.visible       = true
		lbl.text          = "%.1f" % remaining
		overlay.anchor_top = 1.0 - (remaining / total)
	else:
		overlay.visible = false
		lbl.visible     = false

func _on_bank_changed(_bank_idx: int) -> void:
	_refresh_hotkey_slots()

func _on_slot_changed(bank_idx: int, slot_idx: int) -> void:
	if bank_idx == SocialHotkeys.current_bank:
		_update_hotkey_slot(slot_idx)
		_rebuild_hotkey_maps()

func _rebuild_hotkey_maps() -> void:
	_hotkey_by_skill.clear()
	_hotkey_by_spell.clear()
	for i in SLOT_COUNT:
		var sd := SocialHotkeys.get_slot(i)
		match sd["type"]:
			SocialHotkeys.TYPE_SKILL:
				_hotkey_by_skill[sd["identifier"]] = i
			SocialHotkeys.TYPE_SPELL:
				_hotkey_by_spell[sd["identifier"]] = i

func _on_hotkey_hover(slot: int) -> void:
	var sd: Dictionary = SocialHotkeys.get_slot(slot)
	var text := ""
	match sd["type"]:
		SocialHotkeys.TYPE_SPELL:
			var sp := _find_spell(sd["identifier"])
			if sp:
				text = "%s\n%s\nMP: %.0f  CD: %.1fs" % [sp.spell_name, sp.description, sp.mana_cost, sp.cooldown]
		SocialHotkeys.TYPE_SKILL:
			var sk := _find_skill(sd["identifier"])
			if sk:
				text = "%s\n%s\nST: %.0f  CD: %.1fs" % [sk.skill_name, sk.description, sk.stamina_cost, sk.cooldown]
		SocialHotkeys.TYPE_SOCIAL:
			var lines := sd.get("lines", []) as Array
			var preview := "\n".join(lines.filter(func(l): return l.strip_edges() != ""))
			text = "[Social] %s\n%s" % [sd["label"], preview]
	if text == "":
		_tooltip_panel.visible = false
		return
	_tooltip_label.text = text
	var frame: Panel = _hotkey_slots[slot]["frame"]
	_tooltip_panel.position = frame.global_position - _hotkey_panel.global_position + Vector2(0, -80)
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.visible = true

func _on_spell_hover(index: int) -> void:
	var text := ""
	if index < Spells.available.size():
		var sp := Spells.available[index]
		text = "%s\n%s\nMP: %.0f  CD: %.1fs" % [sp.spell_name, sp.description, sp.mana_cost, sp.cooldown]
	if text == "":
		_tooltip_panel.visible = false
		return
	_tooltip_label.text = text
	var frame: Panel = _spell_slots[index]["frame"]
	_tooltip_panel.position = frame.global_position - _hotkey_panel.global_position + Vector2(0, -80)
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.visible = true

func _style_slot(frame: Panel, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color     = C_ACTIVE if active else C_READY
	s.border_color = UITheme.C_TITLE if active else UITheme.C_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", s)

func _find_spell(name: String) -> SpellData:
	for sp in Spells.available:
		if sp.spell_name == name:
			return sp
	return null

func _find_skill(name: String) -> SkillData:
	for sk in Skills.available:
		if sk.skill_name == name:
			return sk
	return null
