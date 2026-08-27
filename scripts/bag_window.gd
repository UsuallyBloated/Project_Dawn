extends DraggablePanel
class_name BagWindow

const SLOT_SIZE := 48
const COLS := 4

var bag_index: int = -1
var inv_win: Node = null  # InventoryWindow reference

var _slot_cells: Array = []
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null
var _destroy_btn: Button = null
var _confirm_panel: Panel = null
var _confirm_label: Label = null

func init_bag(p_bag_index: int, p_inv_win: Node) -> void:
	bag_index = p_bag_index
	inv_win = p_inv_win
	_build_ui()
	_build_confirm_dialog()
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

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(bottom_row)

	# No Stack All here. It lives once, in the main inventory window: the action
	# is inventory-wide rather than per-bag (it always consolidated across every
	# bag AND the base slots regardless of which window you clicked it from), so
	# a copy in each open bag window offered a choice that did not exist.
	_destroy_btn = Button.new()
	_destroy_btn.text = "Destroy"
	_destroy_btn.add_theme_font_size_override("font_size", 11)
	_destroy_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_destroy_btn.pressed.connect(_on_destroy_pressed)
	bottom_row.add_child(_destroy_btn)

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
			# Hide source-slot icon during a drag from this same slot
			# (matches the inventory_window UX so only the drag overlay
			# is visible mid-move).
			var is_drag_source: bool = inv_win != null \
				and inv_win.drag_item != null \
				and inv_win.drag_source_bi == bag_index \
				and inv_win.drag_source_si == i
			icon_rect.texture = null if is_drag_source else item.icon
			count_label.text = "" if is_drag_source else (str(slot["count"]) if slot["count"] > 1 else "")
			if name_label:
				name_label.visible = (not is_drag_source) and item.icon == null
				name_label.text = item.item_name
			_set_slot_tint(cell, _rarity_slot_color(item.rarity))

func _on_slot_hover(index: int) -> void:
	if inv_win.drag_item != null:
		_tooltip.visible = false
		return
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
	if _confirm_panel != null and _confirm_panel.visible:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if inv_win.drag_item != null or Inventory.cursor_slot != null:
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
			# Track 15.1 — routes through Net.broadcast_equip_item in
			# launcher mode; legacy local mutation in solo mode.
			Equipment.request_equip_from(NetProtocol.inv_location_bag(bag_index), index, item)
			get_viewport().set_input_as_handled()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# PD_W0027 — a server-cursor item places into the clicked inner slot
	# before any local drag logic (same law as the base cells).
	if Inventory.cursor_slot != null and inv_win.drag_item == null:
		Net.broadcast_move_item(NetProtocol.INV_LOCATION_CURSOR, 0, NetProtocol.inv_location_bag(bag_index), index)
		get_viewport().set_input_as_handled()
		return

	if inv_win.drag_item == null:
		var slot = Inventory.get_slot(bag_index, index)
		if slot == null:
			return
		inv_win.begin_drag(slot["item"], slot["count"], bag_index, index)
		# Track 14 follow-up — in launcher mode keep the source
		# slot visually populated until the server confirms the
		# move.
		if not Net.is_launcher_mode():
			Inventory.clear_slot(bag_index, index)
		_tooltip.visible = false
		get_viewport().set_input_as_handled()
	else:
		if Net.is_launcher_mode():
			# Server-authoritative MoveItem. Source is whatever the
			# inventory_window's begin_drag captured (base or another
			# bag); dst is this bag's inner slot.
			var src_loc: String = NetProtocol.INV_LOCATION_BASE if inv_win.drag_source_bi == -1 \
				else NetProtocol.inv_location_bag(inv_win.drag_source_bi)
			Net.broadcast_move_item(
				src_loc,
				inv_win.drag_source_si,
				NetProtocol.inv_location_bag(bag_index),
				index,
			)
			inv_win.end_drag()
			get_viewport().set_input_as_handled()
			return
		var existing = Inventory.get_slot(bag_index, index)
		if existing == null:
			Inventory.set_slot(bag_index, index, {"item": inv_win.drag_item, "count": inv_win.drag_count})
			inv_win.end_drag()
		else:
			# Swap: place dragged item here, pick up existing
			var swap_item: ItemData = existing["item"]
			var swap_count: int = existing["count"]
			Inventory.set_slot(bag_index, index, {"item": inv_win.drag_item, "count": inv_win.drag_count})
			inv_win.begin_drag(swap_item, swap_count, bag_index, index)
		get_viewport().set_input_as_handled()

# Prevent window-dragging while an item is being dragged.
func _gui_input(event: InputEvent) -> void:
	if inv_win != null and inv_win.drag_item != null \
			and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		return
	super._gui_input(event)

func _on_destroy_pressed() -> void:
	if inv_win.drag_item == null:
		return
	_show_destroy_confirm()

func _show_destroy_confirm() -> void:
	_confirm_label.text = 'Destroy\n"%s"?' % inv_win.drag_item.item_name
	var vp := get_viewport_rect().size
	_confirm_panel.position = (vp * 0.5) - (_confirm_panel.custom_minimum_size * 0.5)
	_confirm_panel.visible = true

func _confirm_destroy() -> void:
	_confirm_panel.visible = false
	var destroyed: ItemData = inv_win.drag_item
	# Track 15.1 — in launcher mode the source slot still holds the
	# item server-side (pickup doesn't clear). Send DestroyItem so
	# the server fans an InventoryDelta. Solo mode preserves the
	# legacy local-only flow (the source slot was cleared at pickup
	# time, so cancel_drag is enough).
	if Net.is_launcher_mode():
		if destroyed != null:
			var src_loc: String = NetProtocol.INV_LOCATION_BASE if inv_win.drag_source_bi == -1 \
				else NetProtocol.inv_location_bag(inv_win.drag_source_bi)
			Net.broadcast_destroy_item(src_loc, inv_win.drag_source_si, inv_win.drag_count)
	inv_win.cancel_drag()
	Inventory.item_removed.emit(destroyed)

func _cancel_destroy() -> void:
	_confirm_panel.visible = false

func _use_consumable(item: ItemData, index: int) -> void:
	# Track 15.2 — server-authoritative consumable use. Mirrors the
	# inventory_window arm; see the comment there for the full
	# rationale.
	if Net.is_launcher_mode():
		if item.is_food:
			Net.broadcast_use_consumable(NetProtocol.inv_location_bag(bag_index), index)
			CombatLog.add_line("You eat %s." % item.item_name, CombatLog.MsgType.INFO)
		elif item.is_drink:
			Net.broadcast_use_consumable(NetProtocol.inv_location_bag(bag_index), index)
			CombatLog.add_line("You drink %s." % item.item_name, CombatLog.MsgType.INFO)
		elif item.heal_on_use > 0.0 or item.mp_on_use > 0.0:
			Net.broadcast_use_consumable(NetProtocol.inv_location_bag(bag_index), index)
			CombatLog.add_line("You use %s." % item.item_name, CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("You can't use %s that way." % item.item_name, CombatLog.MsgType.INFO)
		return
	if item.is_food:
		if BuffManager.has_food_buff():
			CombatLog.add_line("You are already eating something.", CombatLog.MsgType.INFO)
			return
		Inventory.remove_at(bag_index, index)
		BuffManager.add_food_buff(item.food_hp_regen, item.food_mp_regen, item.food_duration, item.item_name)
		CombatLog.add_line("You eat %s." % item.item_name, CombatLog.MsgType.INFO)
		return
	if item.is_drink:
		if BuffManager.has_drink_buff():
			CombatLog.add_line("You are already drinking something.", CombatLog.MsgType.INFO)
			return
		Inventory.remove_at(bag_index, index)
		BuffManager.add_drink_buff(item.food_hp_regen, item.food_mp_regen, item.food_duration, item.item_name)
		CombatLog.add_line("You drink %s." % item.item_name, CombatLog.MsgType.INFO)
		return
	if item.heal_on_use == 0.0 and item.mp_on_use == 0.0:
		CombatLog.add_line("You can't use %s that way." % item.item_name, CombatLog.MsgType.INFO)
		return
	Inventory.remove_at(bag_index, index)
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
