extends DraggablePanel

const SLOT_SIZE := 48
const COLS := 8
const ROWS := 5

const C_BG := Color(0.07, 0.06, 0.04, 0.95)

var _slot_cells: Array = []
var _tooltip: Panel = null
var _tooltip_label: Label = null

var _drag_item: ItemData = null
var _drag_count: int = 0
var _drag_source_slot: int = -1
var _drag_icon: TextureRect = null

var _destroy_btn: Button = null
var _confirm_panel: Panel = null
var _confirm_label: Label = null

func _ready() -> void:
	_build_ui()
	_build_drag_icon()
	_build_confirm_dialog()
	Inventory.inventory_changed.connect(_refresh)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	custom_minimum_size = Vector2(COLS * SLOT_SIZE + 24, ROWS * SLOT_SIZE + 74)

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
	title.add_theme_color_override("font_color", UITheme.C_TITLE)
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	close_btn.pressed.connect(func():
		if _drag_item != null:
			_return_item_to_slot()
		visible = false)
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

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(bottom_row)

	_destroy_btn = Button.new()
	_destroy_btn.text = "Destroy"
	_destroy_btn.add_theme_font_size_override("font_size", 11)
	_destroy_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_destroy_btn.pressed.connect(_on_destroy_pressed)
	bottom_row.add_child(_destroy_btn)

	var tip := make_tooltip()
	_tooltip = tip[0]
	_tooltip_label = tip[1]

func _build_drag_icon() -> void:
	_drag_icon = TextureRect.new()
	_drag_icon.top_level = true
	_drag_icon.z_index = 100
	_drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_icon.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_drag_icon.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_drag_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_icon.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_drag_icon.visible = false
	add_child(_drag_icon)

func _build_confirm_dialog() -> void:
	_confirm_panel = Panel.new()
	_confirm_panel.top_level = true
	_confirm_panel.z_index = 200
	_confirm_panel.visible = false
	_confirm_panel.custom_minimum_size = Vector2(300, 110)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.06, 0.98)
	style.border_color = Color(0.75, 0.25, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_confirm_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.offset_left = 14; vbox.offset_top = 14
	vbox.offset_right = -14; vbox.offset_bottom = -14
	_confirm_panel.add_child(vbox)

	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.add_theme_color_override("font_color", UITheme.C_TEXT)
	_confirm_label.add_theme_font_size_override("font_size", 12)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_confirm_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(64, 0)
	yes_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	yes_btn.pressed.connect(_confirm_destroy)
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(64, 0)
	no_btn.pressed.connect(_cancel_destroy)
	btn_row.add_child(no_btn)

	add_child(_confirm_panel)

func _make_slot_cell(index: int) -> Panel:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.C_SLOT_BG
	s.border_color = UITheme.C_BORDER
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

func _process(_delta: float) -> void:
	if _drag_item != null and _drag_icon != null:
		var mp := get_viewport().get_mouse_position()
		_drag_icon.position = mp - Vector2(SLOT_SIZE * 0.5, SLOT_SIZE * 0.5)

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
	if _drag_item != null:
		_tooltip.visible = false
		return
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

func _on_slot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if _confirm_panel != null and _confirm_panel.visible:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if _drag_item != null:
			return
		var slot = Inventory.slots[index]
		if slot == null:
			return
		var item: ItemData = slot["item"]
		if item.type != ItemData.Type.CONSUMABLE and item.type != ItemData.Type.MISC:
			Inventory.remove_at(index)
			Equipment.equip(item)
			get_viewport().set_input_as_handled()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if _drag_item == null:
		var slot = Inventory.slots[index]
		if slot == null:
			return
		_drag_item = slot["item"]
		_drag_count = slot["count"]
		_drag_source_slot = index
		Inventory.clear_slot(index)
		_drag_icon.texture = _drag_item.icon
		_drag_icon.visible = true
		_tooltip.visible = false
		get_viewport().set_input_as_handled()
	else:
		var existing = Inventory.slots[index]
		if existing == null:
			Inventory.slots[index] = {"item": _drag_item, "count": _drag_count}
			_end_drag()
		else:
			# Swap: place dragged item here, pick up the existing item
			var swap_item: ItemData = existing["item"]
			var swap_count: int = existing["count"]
			Inventory.slots[index] = {"item": _drag_item, "count": _drag_count}
			_drag_item = swap_item
			_drag_count = swap_count
			_drag_source_slot = index
			_drag_icon.texture = _drag_item.icon
			Inventory.inventory_changed.emit()
		get_viewport().set_input_as_handled()

# Prevent window-dragging while an item is being dragged.
func _gui_input(event: InputEvent) -> void:
	if _drag_item != null and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		return
	super._gui_input(event)

# Catch left-clicks that land outside all slots while dragging an item.
func _input(event: InputEvent) -> void:
	super._input(event)
	if not visible or _drag_item == null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _confirm_panel != null and _confirm_panel.visible:
		return
	var mp := get_viewport().get_mouse_position()
	for cell in _slot_cells:
		if cell.get_global_rect().has_point(mp):
			return
	if _destroy_btn != null and _destroy_btn.get_global_rect().has_point(mp):
		return
	_show_destroy_confirm()
	get_viewport().set_input_as_handled()

func _on_visibility_changed() -> void:
	if not visible and _drag_item != null:
		_return_item_to_slot()

func _on_destroy_pressed() -> void:
	if _drag_item == null:
		return
	_show_destroy_confirm()

func _show_destroy_confirm() -> void:
	if _drag_item == null:
		return
	_confirm_label.text = 'Are you sure you want to destroy\n"%s"?' % _drag_item.item_name
	var vp := get_viewport_rect().size
	_confirm_panel.position = (vp * 0.5) - (_confirm_panel.custom_minimum_size * 0.5)
	_confirm_panel.visible = true

func _confirm_destroy() -> void:
	_confirm_panel.visible = false
	var destroyed := _drag_item
	_clear_drag()
	Inventory.item_removed.emit(destroyed)

func _cancel_destroy() -> void:
	_confirm_panel.visible = false

func _return_item_to_slot() -> void:
	if _drag_item == null:
		return
	if _drag_source_slot >= 0 and Inventory.slots[_drag_source_slot] == null:
		Inventory.slots[_drag_source_slot] = {"item": _drag_item, "count": _drag_count}
		Inventory.inventory_changed.emit()
	else:
		Inventory.add_item(_drag_item, _drag_count)
	_clear_drag()

func _end_drag() -> void:
	Inventory.inventory_changed.emit()
	_clear_drag()

func _clear_drag() -> void:
	_drag_item = null
	_drag_count = 0
	_drag_source_slot = -1
	if _drag_icon != null:
		_drag_icon.visible = false
		_drag_icon.texture = null
	if _confirm_panel != null:
		_confirm_panel.visible = false
