extends DraggablePanel

const SLOT_SIZE := 52
const C_BG := Color(0.07, 0.06, 0.04, 0.95)

# Layout: slot_name -> grid position [col, row] in a 3-column layout
# Col 0 = left column, Col 1 = center (silhouette), Col 2 = right column
const SLOT_LAYOUT: Dictionary = {
	"head":    [1, 0],
	"neck":    [2, 0],
	"chest":   [1, 1],
	"hands":   [0, 1],
	"ring":    [0, 2],
	"legs":    [1, 2],
	"offhand": [2, 1],
	"weapon":  [2, 2],
	"feet":    [1, 3],
}

const SLOT_LABELS: Dictionary = {
	"head": "Head", "neck": "Neck", "chest": "Chest",
	"hands": "Hands", "ring": "Ring", "legs": "Legs",
	"offhand": "Off", "weapon": "Wpn", "feet": "Feet",
}

var _slot_frames: Dictionary = {}
var _tooltip_panel: PanelContainer = null
var _tooltip_label: Label = null

func _ready() -> void:
	_build_ui()
	Equipment.equipment_changed.connect(_on_equipment_changed)
	for slot_name in SLOT_LAYOUT:
		_refresh_slot(slot_name)

func _build_ui() -> void:
	custom_minimum_size = Vector2(220, 280)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_BG
	panel_style.border_color = UITheme.C_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8; vbox.offset_top = 8
	vbox.offset_right = -8; vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Equipment"
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

	# 3-col x 4-row grid
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	var cells: Array = []
	for _r in 4:
		for _c in 3:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
			grid.add_child(spacer)
			cells.append(spacer)

	for slot_name in SLOT_LAYOUT:
		var pos: Array = SLOT_LAYOUT[slot_name]
		var cell_idx: int = pos[1] * 3 + pos[0]
		var old_spacer: Control = cells[cell_idx]
		var frame := _make_slot_frame(slot_name)
		grid.remove_child(old_spacer)
		old_spacer.queue_free()
		grid.add_child(frame)
		grid.move_child(frame, cell_idx)
		cells[cell_idx] = frame
		_slot_frames[slot_name] = frame

	var tip := make_tooltip()
	_tooltip_panel = tip[0]
	_tooltip_label = tip[1]

func _make_slot_frame(slot_name: String) -> Panel:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	frame.set_meta("slot_name", slot_name)

	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.C_SLOT_BG
	s.border_color = UITheme.C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	frame.add_theme_stylebox_override("panel", s)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_meta("is_icon", true)
	frame.add_child(icon)

	# Slot-type label — visible when slot is empty.
	var lbl := Label.new()
	lbl.text = SLOT_LABELS.get(slot_name, slot_name)
	lbl.anchor_top = 0.65
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	lbl.set_meta("is_label", true)
	frame.add_child(lbl)

	# Item name label — visible when something is equipped.
	var item_lbl := Label.new()
	item_lbl.anchor_right = 1.0
	item_lbl.anchor_bottom = 1.0
	item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_lbl.add_theme_font_size_override("font_size", 7)
	item_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	item_lbl.set_meta("is_item_label", true)
	item_lbl.visible = false
	frame.add_child(item_lbl)

	frame.mouse_entered.connect(_on_slot_hover.bind(slot_name))
	frame.mouse_exited.connect(func(): _tooltip_panel.visible = false)
	frame.gui_input.connect(_on_slot_input.bind(slot_name))

	return frame

func _on_equipment_changed(slot: String, _item) -> void:
	_refresh_slot(slot)

func _refresh_slot(slot_name: String) -> void:
	var frame: Panel = _slot_frames.get(slot_name)
	if frame == null:
		return
	var item = Equipment.equipped.get(slot_name)
	var icon := _find_meta_child(frame, "is_icon") as TextureRect
	if icon:
		icon.texture = item.icon if item != null else null
	var slot_lbl  := _find_meta_child(frame, "is_label")      as Label
	var item_lbl  := _find_meta_child(frame, "is_item_label") as Label
	if item != null:
		if slot_lbl: slot_lbl.visible = false
		if item_lbl:
			item_lbl.text    = item.item_name
			item_lbl.visible = true
	else:
		if slot_lbl: slot_lbl.visible = true
		if item_lbl:
			item_lbl.text    = ""
			item_lbl.visible = false

func _on_slot_hover(slot_name: String) -> void:
	var item = Equipment.equipped.get(slot_name)
	if item == null:
		_tooltip_label.text = SLOT_LABELS.get(slot_name, slot_name) + " (empty)"
	else:
		var lines := [item.item_name, item.description]
		_append_stat_lines(item, lines)
		lines.append("\n[Right-click to unequip]")
		_tooltip_label.text = "\n".join(lines)

	var frame: Panel = _slot_frames[slot_name]
	_tooltip_panel.position = frame.position + Vector2(SLOT_SIZE + 4, 0)
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.visible = true

func _on_slot_input(event: InputEvent, slot_name: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		# Track 15.1 — Equipment.request_unequip routes through
		# Net.broadcast_unequip_item in launcher mode (picking the
		# first empty base slot as dst). Legacy unequip path runs in
		# solo / Test Room mode.
		Equipment.request_unequip(slot_name)
		_tooltip_panel.visible = false
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		# PD_W0027 — equip straight from the hand: clicking a paperdoll slot
		# with a server-cursor item routes EquipItem from "cursor". A
		# previously-worn item pops back onto the cursor (the server's swap),
		# which is exactly EQ's click-the-doll-while-holding.
		if Inventory.cursor_slot != null:
			Equipment.request_equip_from(NetProtocol.INV_LOCATION_CURSOR, 0, Inventory.cursor_slot["item"], slot_name)
			_tooltip_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		# PD_W0027 slice 1.5 — empty hand: lift the worn item onto the cursor.
		if Net.is_launcher_mode() and Equipment.equipped.get(slot_name) != null:
			Equipment.request_unequip_to_cursor(slot_name)
			_tooltip_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		# Drop-equip: if the user has an inventory drag in flight and
		# clicks a paperdoll slot, route the held item through
		# Equipment.request_equip_from with the clicked slot as the
		# target hint. Source location/slot come from the inventory
		# window's shared drag state.
		var inv_win = _find_inventory_window()
		if inv_win == null or inv_win.drag_item == null:
			return
		var item: ItemData = inv_win.drag_item
		var src_loc: String = NetProtocol.INV_LOCATION_BASE if inv_win.drag_source_bi == -1 \
			else NetProtocol.inv_location_bag(inv_win.drag_source_bi)
		var src_slot: int = inv_win.drag_source_si
		if Equipment.request_equip_from(src_loc, src_slot, item, slot_name):
			inv_win.cancel_drag()
		_tooltip_panel.visible = false
		get_viewport().set_input_as_handled()

func _find_inventory_window() -> Node:
	# Inventory window isn't grouped; walk the scene tree once. Cheap
	# (~10 top-level UI nodes); avoids hard-coding a path that breaks
	# when the HUD reshapes.
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	return _scan_for_inventory_window(root)

func _scan_for_inventory_window(node: Node) -> Node:
	var s: Script = node.get_script() as Script
	if s != null and s.resource_path.ends_with("inventory_window.gd"):
		return node
	for c in node.get_children():
		var found: Node = _scan_for_inventory_window(c)
		if found != null:
			return found
	return null
