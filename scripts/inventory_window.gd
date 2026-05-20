extends DraggablePanel

const SLOT_SIZE := 48
const COLS := 2
const C_BG := Color(0.07, 0.06, 0.04, 0.95)

# Shared drag state — owned here, read by BagWindows.
# drag_source_bi == -1  →  dragged from a base slot (drag_source_si = base index)
# drag_source_bi >= 0   →  dragged from a bag slot  (bi = bag's base index, si = slot within bag)
var drag_item: ItemData = null
var drag_count: int = 0
var drag_source_bi: int = -1
var drag_source_si: int = -1
var _drag_icon: TextureRect = null

var _base_cells: Array = []   # BASE_SLOT_COUNT Panel nodes
var _bag_windows: Array = []  # BASE_SLOT_COUNT BagWindow or null
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null
var _trash_cell: Panel = null
var _delete_dialog: ConfirmationDialog = null

func _ready() -> void:
	_bag_windows.resize(Inventory.BASE_SLOT_COUNT)
	_bag_windows.fill(null)
	_build_ui()
	_build_drag_icon()
	Inventory.inventory_changed.connect(_refresh_all)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_all()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	var rows := ceili(float(Inventory.BASE_SLOT_COUNT) / float(COLS))
	# header (24) + grid + separator (8) + trash slot + margins (24)
	custom_minimum_size = Vector2(COLS * SLOT_SIZE + 24, rows * SLOT_SIZE + 24 + SLOT_SIZE + 32)

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

	var stack_btn := Button.new()
	stack_btn.text = "Stack All"
	stack_btn.flat = true
	stack_btn.add_theme_font_size_override("font_size", 10)
	stack_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	stack_btn.tooltip_text = "Consolidate stackable items into fewest stacks"
	stack_btn.pressed.connect(Inventory.stack_all)
	header.add_child(stack_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	for i in Inventory.BASE_SLOT_COUNT:
		var cell := _make_slot_cell(i)
		grid.add_child(cell)
		_base_cells.append(cell)

	_trash_cell = _make_trash_cell()
	vbox.add_child(_trash_cell)

	var tip := make_tooltip()
	_tooltip = tip[0]
	_tooltip_label = tip[1]

func _make_trash_cell() -> Panel:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_slot_style(cell, Color(0.18, 0.06, 0.04, 1.0), Color(0.70, 0.20, 0.18, 1.0), 1)
	cell.tooltip_text = "Drag an item here to delete it"

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = "🗑"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.85, 0.45, 0.40))
	cell.add_child(label)

	return cell

func _make_slot_cell(index: int) -> Panel:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_apply_slot_style(cell, UITheme.C_SLOT_BG, UITheme.C_BORDER, 1)
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
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 3)
	count_label.set_meta("is_count", true)
	cell.add_child(count_label)

	var name_label := Label.new()
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.visible = false
	name_label.set_meta("is_name", true)
	cell.add_child(name_label)

	# Badge on bag items showing slot count
	var badge := Label.new()
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 2)
	badge.set_meta("is_badge", true)
	cell.add_child(badge)

	cell.mouse_entered.connect(_on_cell_hover.bind(index))
	cell.mouse_exited.connect(func(): _tooltip.visible = false)
	cell.gui_input.connect(_on_cell_input.bind(index))

	return cell

func _build_drag_icon() -> void:
	_drag_icon = TextureRect.new()
	_drag_icon.top_level = true
	_drag_icon.z_index = 100
	_drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_icon.custom_minimum_size = Vector2(48, 48)
	_drag_icon.size = Vector2(48, 48)
	_drag_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_icon.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_drag_icon.visible = false
	add_child(_drag_icon)

func _process(_delta: float) -> void:
	if drag_item != null and _drag_icon != null:
		_drag_icon.position = get_viewport().get_mouse_position() - Vector2(24.0, 24.0)

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	for i in Inventory.BASE_SLOT_COUNT:
		_refresh_cell(i)

func _refresh_cell(index: int) -> void:
	var cell: Panel = _base_cells[index]
	var icon_rect: TextureRect = _find_meta_child(cell, "is_icon")
	var count_label: Label = _find_meta_child(cell, "is_count")
	var name_label: Label = _find_meta_child(cell, "is_name")
	var badge: Label = _find_meta_child(cell, "is_badge")

	var slot = Inventory.base_slots[index]
	if slot == null:
		icon_rect.texture = null
		count_label.text = ""
		if name_label: name_label.visible = false
		if badge: badge.text = ""
		_apply_slot_style(cell, UITheme.C_SLOT_BG, UITheme.C_BORDER, 1)
		return

	var item: ItemData = slot["item"]
	icon_rect.texture = item.icon
	if name_label:
		name_label.visible = item.icon == null
		name_label.text = item.item_name

	if item.type == ItemData.Type.BAG:
		count_label.text = ""
		if badge:
			var contents = Inventory.bag_contents[index]
			badge.text = "%d" % (contents.size() if contents != null else 0)
		var is_open: bool = _bag_windows[index] != null and _bag_windows[index].visible
		_apply_slot_style(cell, _rarity_color(item.rarity),
			Color(0.8, 0.7, 0.3) if is_open else UITheme.C_BORDER,
			2 if is_open else 1)
	else:
		count_label.text = str(slot["count"]) if slot["count"] > 1 else ""
		if badge: badge.text = ""
		_apply_slot_style(cell, _rarity_color(item.rarity), UITheme.C_BORDER, 1)

# ── Input ─────────────────────────────────────────────────────────────────────

func _on_cell_hover(index: int) -> void:
	if drag_item != null:
		_tooltip.visible = false
		return
	var slot = Inventory.base_slots[index]
	if slot == null:
		_tooltip.visible = false
		return
	var item: ItemData = slot["item"]
	var lines: Array[String] = [item.item_name]
	if item.type == ItemData.Type.BAG:
		lines.append("%d slot bag" % item.bag_num_slots)
	if item.description != "":
		lines.append(item.description)
	_append_stat_lines(item, lines)
	_tooltip_label.text = "\n".join(lines)
	_tooltip.position = Vector2(SLOT_SIZE * COLS + 12, _base_cells[index].position.y)
	_tooltip.size = Vector2.ZERO
	_tooltip.visible = true

func _on_cell_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if drag_item != null:
			return
		var slot = Inventory.base_slots[index]
		if slot == null:
			return
		var item: ItemData = slot["item"]
		if item.type == ItemData.Type.BAG:
			_toggle_bag(index)
		elif item.type == ItemData.Type.CONSUMABLE:
			_use_consumable(item, index)
		elif item.type != ItemData.Type.MISC:
			Inventory.remove_base_at(index)
			Equipment.equip(item)
		get_viewport().set_input_as_handled()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if drag_item == null:
		var slot = Inventory.base_slots[index]
		if slot == null:
			return
		if slot["item"].type == ItemData.Type.BAG:
			_toggle_bag(index)
			get_viewport().set_input_as_handled()
			return
		begin_drag(slot["item"], slot["count"], -1, index)
		# Track 14 follow-up — in launcher mode the server is
		# authoritative; the source slot stays filled visually until
		# the MoveItem InventoryDelta confirms the swap. Solo / Test
		# Room mode keeps the optimistic local-clear path.
		if not Net.is_launcher_mode():
			Inventory.clear_base_slot(index)
		_tooltip.visible = false
		get_viewport().set_input_as_handled()
	else:
		# Can't drop a bag on an occupied slot
		var existing = Inventory.base_slots[index]
		if drag_item.type == ItemData.Type.BAG and existing != null:
			get_viewport().set_input_as_handled()
			return
		if Net.is_launcher_mode():
			# Server-authoritative path. Send MoveItem; the server
			# fans InventoryDelta(s) which Inventory autoload
			# applies. End the drag locally without mutating state.
			var src_loc: String = NetProtocol.INV_LOCATION_BASE if drag_source_bi == -1 \
				else NetProtocol.inv_location_bag(drag_source_bi)
			Net.broadcast_move_item(src_loc, drag_source_si, NetProtocol.INV_LOCATION_BASE, index)
			end_drag()
			get_viewport().set_input_as_handled()
			return
		if existing == null:
			Inventory.set_base_slot(index, {"item": drag_item, "count": drag_count})
			end_drag()
		else:
			# Swap
			var swap_item: ItemData = existing["item"]
			var swap_count: int = existing["count"]
			Inventory.set_base_slot(index, {"item": drag_item, "count": drag_count})
			begin_drag(swap_item, swap_count, -1, index)
		get_viewport().set_input_as_handled()

# ── Bag open/close ────────────────────────────────────────────────────────────

func _toggle_bag(base_index: int) -> void:
	if _bag_windows[base_index] == null:
		_open_bag(base_index)
	else:
		_bag_windows[base_index].visible = not _bag_windows[base_index].visible
		_refresh_cell(base_index)

func _open_bag(base_index: int) -> void:
	var win := BagWindow.new()
	win.top_level = true
	add_child(win)
	win.init_bag(base_index, self)
	win.position = global_position + Vector2(size.x + 8, base_index * 12)
	win.visibility_changed.connect(func(): _refresh_cell(base_index))
	_bag_windows[base_index] = win
	_refresh_cell(base_index)

func _on_visibility_changed() -> void:
	if not visible:
		if drag_item != null:
			_return_drag_to_source()
		for win in _bag_windows:
			if win != null:
				win.visible = false

# ── Drag API (called by BagWindow) ───────────────────────────────────────────

func begin_drag(item: ItemData, count: int, bi: int, si: int) -> void:
	drag_item = item
	drag_count = count
	drag_source_bi = bi
	drag_source_si = si
	_drag_icon.texture = item.icon
	_drag_icon.visible = true

func end_drag() -> void:
	Inventory.inventory_changed.emit()
	_clear_drag()

func cancel_drag() -> void:
	_clear_drag()

func _return_drag_to_source() -> void:
	if drag_item == null:
		return
	# Track 14 follow-up — in launcher mode the source slot was
	# never cleared (the lift skips the optimistic local mutation),
	# so there's nothing to put back. Just drop the drag overlay.
	if Net.is_launcher_mode():
		_clear_drag()
		return
	if drag_source_bi == -1:
		if Inventory.get_base_slot(drag_source_si) == null:
			Inventory.set_base_slot(drag_source_si, {"item": drag_item, "count": drag_count})
		else:
			Inventory.add_item(drag_item, drag_count)
	elif Inventory.get_slot(drag_source_bi, drag_source_si) == null:
		Inventory.set_slot(drag_source_bi, drag_source_si, {"item": drag_item, "count": drag_count})
	else:
		Inventory.add_item(drag_item, drag_count)
	_clear_drag()

func _clear_drag() -> void:
	drag_item = null
	drag_count = 0
	drag_source_bi = -1
	drag_source_si = -1
	if _drag_icon != null:
		_drag_icon.visible = false
		_drag_icon.texture = null

func _gui_input(event: InputEvent) -> void:
	if drag_item != null and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		return
	super._gui_input(event)

func _input(event: InputEvent) -> void:
	super._input(event)
	if not visible or drag_item == null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var mp := get_viewport().get_mouse_position()
	for win in _bag_windows:
		if win != null and win.visible and win.get_global_rect().has_point(mp):
			return
	for cell in _base_cells:
		if cell.get_global_rect().has_point(mp):
			return
	if _trash_cell != null and _trash_cell.get_global_rect().has_point(mp):
		_show_delete_confirm()
		get_viewport().set_input_as_handled()
		return
	_return_drag_to_source()
	get_viewport().set_input_as_handled()

func _show_delete_confirm() -> void:
	if _drag_icon != null:
		_drag_icon.visible = false
	if _delete_dialog == null:
		_delete_dialog = ConfirmationDialog.new()
		_delete_dialog.title = "Delete Item"
		_delete_dialog.confirmed.connect(end_drag)
		_delete_dialog.canceled.connect(_return_drag_to_source)
		add_child(_delete_dialog)
	if drag_count > 1:
		_delete_dialog.dialog_text = "Delete %d × %s?" % [drag_count, drag_item.item_name]
	else:
		_delete_dialog.dialog_text = "Delete %s?" % drag_item.item_name
	_delete_dialog.popup_centered()

# ── Consumable use (base slot items) ─────────────────────────────────────────

func _use_consumable(item: ItemData, index: int) -> void:
	if item.is_food:
		if BuffManager.has_food_buff():
			CombatLog.add_line("You are already eating something.", CombatLog.MsgType.INFO)
			return
		Inventory.remove_base_at(index)
		BuffManager.add_food_buff(item.food_hp_regen, item.food_mp_regen, item.food_duration, item.item_name)
		CombatLog.add_line("You eat %s." % item.item_name, CombatLog.MsgType.INFO)
		return
	if item.is_drink:
		if BuffManager.has_drink_buff():
			CombatLog.add_line("You are already drinking something.", CombatLog.MsgType.INFO)
			return
		Inventory.remove_base_at(index)
		BuffManager.add_drink_buff(item.food_hp_regen, item.food_mp_regen, item.food_duration, item.item_name)
		CombatLog.add_line("You drink %s." % item.item_name, CombatLog.MsgType.INFO)
		return
	if item.heal_on_use == 0.0 and item.mp_on_use == 0.0:
		CombatLog.add_line("You can't use %s that way." % item.item_name, CombatLog.MsgType.INFO)
		return
	Inventory.remove_base_at(index)
	var parts: Array[String] = []
	if item.heal_on_use > 0.0:
		var before := PlayerStats.hp
		PlayerStats.set_hp(PlayerStats.hp + item.heal_on_use)
		var gained := PlayerStats.hp - before
		if gained > 0.0:
			parts.append("%d HP" % int(gained))
	if item.mp_on_use > 0.0:
		var before := PlayerStats.mp
		PlayerStats.set_mp(PlayerStats.mp + item.mp_on_use)
		var gained := PlayerStats.mp - before
		if gained > 0.0:
			parts.append("%d MP" % int(gained))
	var msg := "You use %s." % item.item_name
	if not parts.is_empty():
		msg += " You recover %s." % " and ".join(parts)
	CombatLog.add_line(msg, CombatLog.MsgType.INFO)

# ── Style helpers ─────────────────────────────────────────────────────────────

func _apply_slot_style(cell: Panel, bg: Color, border: Color, border_width: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(2)
	cell.add_theme_stylebox_override("panel", s)

func _rarity_color(rarity: ItemData.Rarity) -> Color:
	match rarity:
		ItemData.Rarity.UNCOMMON: return Color(0.06, 0.14, 0.06, 0.95)
		ItemData.Rarity.RARE:     return Color(0.04, 0.08, 0.18, 0.95)
		ItemData.Rarity.EPIC:     return Color(0.12, 0.04, 0.18, 0.95)
		_:                        return Color(UITheme.C_SLOT_BG)
