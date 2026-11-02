extends DraggablePanel
class_name BagWindow

const SLOT_SIZE := 48
const COLS := 4

var bag_index: int = -1

var _slot_cells: Array = []
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null

func init_bag(p_bag_index: int) -> void:
	bag_index = p_bag_index
	_build_ui()
	Inventory.inventory_changed.connect(_refresh)
	_refresh()

func _build_ui() -> void:
	var bag = Inventory.base_slots[bag_index]
	var num_slots: int = Inventory.bag_contents[bag_index].size()
	var cols := mini(num_slots, COLS)
	var rows := ceili(float(num_slots) / float(cols))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.04, 0.95)
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	custom_minimum_size = Vector2(cols * SLOT_SIZE + 24, rows * SLOT_SIZE + 54)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left = 8; vbox.offset_top = 8
	vbox.offset_right = -8; vbox.offset_bottom = -8
	add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = bag["item"].item_name
	title.add_theme_color_override("font_color", UITheme.C_TITLE)
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	for i in num_slots:
		var cell := _make_slot_cell(i)
		grid.add_child(cell)
		_slot_cells.append(cell)

	# No Stack All here. It lives once, in the main inventory window: the action
	# is inventory-wide rather than per-bag, so a copy in each open bag window
	# offered a choice that did not exist. Destroying is the inventory window's
	# trash cell, with the item held.

	var tip := make_tooltip()
	_tooltip = tip[0]
	_tooltip_label = tip[1]

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

	cell.mouse_entered.connect(_on_slot_hover.bind(index))
	cell.mouse_exited.connect(func(): _tooltip.visible = false)
	cell.gui_input.connect(_on_slot_input.bind(index))

	return cell

func _refresh() -> void:
	var bag = Inventory.base_slots[bag_index]
	if bag == null:
		return
	var slots: Array = Inventory.bag_contents[bag_index]
	for i in _slot_cells.size():
		var cell: Panel = _slot_cells[i]
		var slot = slots[i]
		var icon_rect: TextureRect = _find_meta_child(cell, "is_icon")
		var count_label: Label = _find_meta_child(cell, "is_count")
		var name_label: Label = _find_meta_child(cell, "is_name")
		if slot == null:
			icon_rect.texture = null
			count_label.text = ""
			if name_label:
				name_label.visible = false
			_set_slot_tint(cell, Color(UITheme.C_SLOT_BG))
		else:
			var item: ItemData = slot["item"]
			icon_rect.texture = item.icon
			count_label.text = str(slot["count"]) if slot["count"] > 1 else ""
			if name_label:
				name_label.visible = item.icon == null
				name_label.text = item.item_name
			_set_slot_tint(cell, _rarity_slot_color(item.rarity))

func _on_slot_hover(index: int) -> void:
	var slot = Inventory.get_slot(bag_index, index)
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

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if Inventory.cursor_slot != null:
			return
		var slot = Inventory.get_slot(bag_index, index)
		if slot == null:
			return
		# Banker slice 2 — with the bank open, right-click quick-transfers the
		# whole stack into the selected vault instead of use/equip/open.
		if BankerManager.bank_is_open:
			Net.broadcast_bank_store_item(NetProtocol.inv_location_bag(bag_index), index, BankerManager.deposit_to_shared)
			get_viewport().set_input_as_handled()
			return
		var item: ItemData = slot["item"]
		if item.is_mount:
			# Track 22.C — mount whistle. Toggles summon/dismount; the
			# whistle item is not consumed.
			if MountManager.is_mounted() and MountManager.current_mount == item:
				MountManager.dismount()
			else:
				MountManager.summon(item)
			get_viewport().set_input_as_handled()
		elif item.type == ItemData.Type.CONSUMABLE:
			_use_consumable(item, index)
			get_viewport().set_input_as_handled()
		elif item.type != ItemData.Type.MISC:
			# Track 15.1 — routes through Net.broadcast_equip_item.
			Equipment.request_equip_from(NetProtocol.inv_location_bag(bag_index), index, item)
			get_viewport().set_input_as_handled()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# PD_W0027 — a server-cursor item places into the clicked inner slot
	# (same law as the base cells).
	if Inventory.cursor_slot != null:
		Net.broadcast_move_item(NetProtocol.INV_LOCATION_CURSOR, 0, NetProtocol.inv_location_bag(bag_index), index)
		get_viewport().set_input_as_handled()
		return

	var slot = Inventory.get_slot(bag_index, index)
	if slot == null:
		return
	# PD_W0027 slice 1.5 — every lift goes through the real cursor.
	Net.broadcast_move_item(NetProtocol.inv_location_bag(bag_index), index, NetProtocol.INV_LOCATION_CURSOR, 0)
	_tooltip.visible = false
	get_viewport().set_input_as_handled()

func _use_consumable(item: ItemData, index: int) -> void:
	# Track 15.2 — server-authoritative consumable use. Mirrors the
	# inventory_window arm; see the comment there for the full
	# rationale. The server narrates a hand-eat.
	if item.is_food or item.is_drink:
		Net.hand_eat_requested.emit(item.is_food, item.is_drink)
		Net.broadcast_use_consumable(NetProtocol.inv_location_bag(bag_index), index)
	elif item.heal_on_use > 0.0 or item.mp_on_use > 0.0:
		Net.broadcast_use_consumable(NetProtocol.inv_location_bag(bag_index), index)
		CombatLog.add_line("You use %s." % item.item_name, CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("You can't use %s that way." % item.item_name, CombatLog.MsgType.INFO)

func _set_slot_tint(cell: Panel, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = UITheme.C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	cell.add_theme_stylebox_override("panel", s)

func _rarity_slot_color(rarity: ItemData.Rarity) -> Color:
	match rarity:
		ItemData.Rarity.UNCOMMON: return Color(0.06, 0.14, 0.06, 0.95)
		ItemData.Rarity.RARE:     return Color(0.04, 0.08, 0.18, 0.95)
		ItemData.Rarity.EPIC:     return Color(0.12, 0.04, 0.18, 0.95)
		_:                        return Color(UITheme.C_SLOT_BG)
