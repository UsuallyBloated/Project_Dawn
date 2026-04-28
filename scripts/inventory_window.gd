extends Panel

const SLOT_SIZE := 48
const COLS := 8
const ROWS := 5

const C_BG       := Color(0.07, 0.06, 0.04, 0.95)
const C_BORDER   := Color(0.30, 0.22, 0.08)
const C_SLOT_BG  := Color(0.12, 0.10, 0.07)
const C_SLOT_HL  := Color(0.30, 0.22, 0.08)
const C_TITLE    := Color(0.95, 0.78, 0.25)
const C_TEXT     := Color(0.90, 0.82, 0.65)
const C_TOOLTIP  := Color(0.04, 0.03, 0.02, 0.95)

var _slot_cells: Array = []
var _tooltip: Panel = null
var _tooltip_label: Label = null
var _dragging_from: int = -1

func _ready() -> void:
	_build_ui()
	Inventory.inventory_changed.connect(_refresh)
	_refresh()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	custom_minimum_size = Vector2(COLS * SLOT_SIZE + 24, ROWS * SLOT_SIZE + 50)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left = 8; vbox.offset_top = 8
	vbox.offset_right = -8; vbox.offset_bottom = -8
	add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_color_override("font_color", C_TITLE)
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", C_TEXT)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	for i in Inventory.MAX_SLOTS:
		var cell := _make_slot_cell(i)
		grid.add_child(cell)
		_slot_cells.append(cell)

	_tooltip = Panel.new()
	_tooltip.visible = false
	_tooltip.z_index = 10
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = C_TOOLTIP
	tip_style.border_color = C_BORDER
	tip_style.set_border_width_all(1)
	tip_style.set_corner_radius_all(3)
	tip_style.content_margin_left = 8
	tip_style.content_margin_top = 6
	tip_style.content_margin_right = 8
	tip_style.content_margin_bottom = 6
	_tooltip.add_theme_stylebox_override("panel", tip_style)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	_tooltip_label.add_theme_color_override("font_color", C_TEXT)
	_tooltip.add_child(_tooltip_label)
	add_child(_tooltip)

func _make_slot_cell(index: int) -> Panel:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var s := StyleBoxFlat.new()
	s.bg_color = C_SLOT_BG
	s.border_color = C_SLOT_HL
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	cell.add_theme_stylebox_override("panel", s)
	cell.set_meta("slot_index", index)

	var icon_rect := TextureRect.new()
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_meta("is_icon", true)
	cell.add_child(icon_rect)

	var count_label := Label.new()
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.set_meta("is_count", true)
	cell.add_child(count_label)

	cell.mouse_entered.connect(_on_slot_hover.bind(index))
	cell.mouse_exited.connect(func(): _tooltip.visible = false)
	cell.gui_input.connect(_on_slot_input.bind(index))

	return cell

func _refresh() -> void:
	for i in _slot_cells.size():
		var cell: Panel = _slot_cells[i]
		var slot = Inventory.slots[i]
		var icon_rect: TextureRect = _find_meta_child(cell, "is_icon")
		var count_label: Label = _find_meta_child(cell, "is_count")
		if slot == null:
			icon_rect.texture = null
			count_label.text = ""
		else:
			icon_rect.texture = slot["item"].icon
			count_label.text = str(slot["count"]) if slot["count"] > 1 else ""

func _on_slot_hover(index: int) -> void:
	var slot = Inventory.slots[index]
	if slot == null:
		_tooltip.visible = false
		return
	var item: ItemData = slot["item"]
	var lines := [item.item_name, item.description]
	_append_stat_lines(item, lines)
	_tooltip_label.text = "\n".join(lines)
	_tooltip.position = _slot_cells[index].position + Vector2(SLOT_SIZE + 4, 0)
	_tooltip.size = Vector2.ZERO
	_tooltip.visible = true

func _append_stat_lines(item: ItemData, lines: Array) -> void:
	var checks := [
		["bonus_strength", "STR"], ["bonus_dexterity", "DEX"], ["bonus_agility", "AGI"],
		["bonus_intelligence", "INT"], ["bonus_wisdom", "WIS"], ["bonus_charisma", "CHA"],
		["bonus_constitution", "CON"], ["bonus_max_hp", "Max HP"],
		["bonus_max_mp", "Max MP"], ["bonus_max_stamina", "Max ST"],
	]
	for pair in checks:
		var val = item.get(pair[0])
		if val != 0:
			lines.append(("%s +%s" if val > 0 else "%s %s") % [pair[1], val])

func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var slot = Inventory.slots[index]
			if slot == null:
				return
			var item: ItemData = slot["item"]
			if item.type != ItemData.Type.CONSUMABLE and item.type != ItemData.Type.MISC:
				Inventory.remove_at(index)
				Equipment.equip(item)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			Inventory.remove_at(index)

func _find_meta_child(parent: Node, meta_key: String) -> Node:
	for child in parent.get_children():
		if child.has_meta(meta_key):
			return child
	return null
