extends DraggablePanel

const SLOT_SIZE := 48
const COLS := 2
const C_BG := Color(0.07, 0.06, 0.04, 0.95)

# The base inventory window. Every move goes through the server's cursor slot
# (PD_W0027): a left-click lifts a stack into the hand or places the held one,
# and the server's InventoryDelta repaints both ends. Nothing here mutates the
# inventory locally.

var _base_cells: Array = []   # BASE_SLOT_COUNT Panel nodes
var _bag_windows: Array = []  # BASE_SLOT_COUNT BagWindow or null
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null
var _trash_cell: Panel = null
var _delete_dialog: ConfirmationDialog = null
var _wallet_label: Label = null

func _ready() -> void:
	_bag_windows.resize(Inventory.BASE_SLOT_COUNT)
	_bag_windows.fill(null)
	_build_ui()
	Inventory.inventory_changed.connect(_refresh_all)
	PlayerStats.coins_changed.connect(_on_coins_changed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_all()
	# Center the window on the viewport at startup. Waits one frame so
	# custom_minimum_size from _build_ui has settled into the actual
	# `size`. DraggablePanel lets the player move it from there.
	await get_tree().process_frame
	var vp_size := get_viewport_rect().size
	position = ((vp_size - size) * 0.5).round()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	var rows := ceili(float(Inventory.BASE_SLOT_COUNT) / float(COLS))
	# header (24) + grid + wallet line (20) + trash slot + margins (24)
	custom_minimum_size = Vector2(COLS * SLOT_SIZE + 24, rows * SLOT_SIZE + 24 + 20 + SLOT_SIZE + 32)

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

	# Wallet line — raw per-tier stacks, same format as the vendor window
	# footer. Never the reduced form: a 4,000-copper hoard reads "4000c".
	_wallet_label = Label.new()
	_wallet_label.text = _wallet_text()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.add_theme_font_size_override("font_size", 12)
	_wallet_label.add_theme_color_override("font_color", UITheme.C_COINS)
	# PASS (not STOP): tooltips need a non-IGNORE filter, and clicks should
	# still fall through so the window can be dragged from the wallet line.
	_wallet_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_wallet_label.tooltip_text = "Your coins, as carried — stacks are never consolidated automatically. Every coin has weight."
	vbox.add_child(_wallet_label)

	# Trash (destroy) sits on the bottom row. The Drop cell that used to sit
	# beside it is gone (2026-08-28): dropping is clicking the world while
	# holding, which is where a player reaches for it anyway.
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 8)
	_trash_cell = _make_trash_cell()
	bottom_row.add_child(_trash_cell)
	vbox.add_child(bottom_row)

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


	cell.mouse_entered.connect(_on_cell_hover.bind(index))
	cell.mouse_exited.connect(func(): _tooltip.visible = false)
	cell.gui_input.connect(_on_cell_input.bind(index))

	return cell

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_close_orphaned_bag_windows()
	for i in Inventory.BASE_SLOT_COUNT:
		_refresh_cell(i)

# Bag windows are keyed by BASE SLOT INDEX, not by the bag item. Now that a bag
# can actually be picked up and rearranged (it never could before, since
# left-click opened it instead), a window can outlive the bag that opened it and
# sit there showing the contents of a slot that no longer holds a bag. Close any
# window whose slot is no longer a bag.
func _close_orphaned_bag_windows() -> void:
	for i in _bag_windows.size():
		var win = _bag_windows[i]
		if win == null:
			continue
		var slot = Inventory.base_slots[i]
		if slot == null or slot["item"].type != ItemData.Type.BAG:
			win.queue_free()
			_bag_windows[i] = null

func _refresh_cell(index: int) -> void:
	var cell: Panel = _base_cells[index]
	var icon_rect: TextureRect = _find_meta_child(cell, "is_icon")
	var count_label: Label = _find_meta_child(cell, "is_count")
	var name_label: Label = _find_meta_child(cell, "is_name")

	var slot = Inventory.base_slots[index]
	if slot == null:
		icon_rect.texture = null
		count_label.text = ""
		if name_label: name_label.visible = false
		_apply_slot_style(cell, UITheme.C_SLOT_BG, UITheme.C_BORDER, 1)
		return

	var item: ItemData = slot["item"]
	icon_rect.texture = item.icon
	if name_label:
		name_label.visible = item.icon == null
		name_label.text = item.item_name

	if item.type == ItemData.Type.BAG:
		# No slot-count number on the cell. Capacity is static, so stamping it on
		# every bag is permanent clutter; the tooltip already says "N slot bag".
		count_label.text = ""
		var is_open: bool = _bag_windows[index] != null and _bag_windows[index].visible
		_apply_slot_style(cell, _rarity_color(item.rarity),
			Color(0.8, 0.7, 0.3) if is_open else UITheme.C_BORDER,
			2 if is_open else 1)
	else:
		count_label.text = str(slot["count"]) if slot["count"] > 1 else ""
		_apply_slot_style(cell, _rarity_color(item.rarity), UITheme.C_BORDER, 1)

# Mirrors vendor_window._coins_text — actual stacks, never reduced.
func _wallet_text() -> String:
	return Currency.format_coins(
		PlayerStats.platinum, PlayerStats.gold, PlayerStats.silver, PlayerStats.copper)

func _on_coins_changed(platinum: int, gold: int, silver: int, copper: int) -> void:
	_wallet_label.text = Currency.format_coins(platinum, gold, silver, copper)

# ── Input ─────────────────────────────────────────────────────────────────────

func _on_cell_hover(index: int) -> void:
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
		if Inventory.cursor_slot != null:
			return
		var slot = Inventory.base_slots[index]
		if slot == null:
			return
		# Banker slice 2 — with the bank open, right-click quick-transfers the
		# whole stack into the selected vault instead of use/equip/open.
		if BankerManager.bank_is_open:
			Net.broadcast_bank_store_item(NetProtocol.INV_LOCATION_BASE, index, BankerManager.deposit_to_shared)
			get_viewport().set_input_as_handled()
			return
		var item: ItemData = slot["item"]
		if item.is_mount:
			# Track 22.C — mount whistle (MountManager refuses until the
			# server has a mount model).
			MountManager.summon(item)
		elif item.type == ItemData.Type.BAG:
			_toggle_bag(index)
		elif item.type == ItemData.Type.CONSUMABLE:
			_use_consumable(item, index)
		elif item.type != ItemData.Type.MISC:
			# Track 15.1 — Equipment.request_equip_from routes through
			# Net.broadcast_equip_item (server fans InventoryDelta +
			# apply_remote_equip).
			Equipment.request_equip_from(NetProtocol.INV_LOCATION_BASE, index, item)
		get_viewport().set_input_as_handled()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# PD_W0027 — an item held on the SERVER cursor places: one MoveItem, and
	# the deltas repaint both ends (empty → move, same item → capped merge,
	# different item → swap onto the cursor).
	if Inventory.cursor_slot != null:
		Net.broadcast_move_item(NetProtocol.INV_LOCATION_CURSOR, 0, NetProtocol.INV_LOCATION_BASE, index)
		get_viewport().set_input_as_handled()
		return

	var slot = Inventory.base_slots[index]
	if slot == null:
		return
	# A bag is lifted by left-click like any other item, and OPENED by
	# right-click (inventory_interaction_grammar.md §3). A full bag lifts WITH
	# its contents: the server re-keys them onto the cursor (2026-09-27).
	# Every lift goes through the real cursor (PD_W0027 slice 1.5): one
	# MoveItem into the hand, and the server's delta puts the item on the mouse.
	Net.broadcast_move_item(NetProtocol.INV_LOCATION_BASE, index, NetProtocol.INV_LOCATION_CURSOR, 0)
	_tooltip.visible = false
	get_viewport().set_input_as_handled()

# ── Bag open/close ────────────────────────────────────────────────────────────

func _toggle_bag(base_index: int) -> void:
	if _bag_windows[base_index] == null:
		_open_bag(base_index)
	else:
		_bag_windows[base_index].visible = not _bag_windows[base_index].visible
		_refresh_cell(base_index)

func _open_bag(base_index: int) -> void:
	# A bag is a window of its own, so it lives beside this one under the HUD,
	# not under it: a bag can then come to the front over the bank or the book,
	# and its destroy confirm with it (picking follows tree order).
	var win := BagWindow.new()
	get_parent().add_child(win)
	tree_exiting.connect(win.queue_free)   # a bag never outlives the inventory it reads
	win.init_bag(base_index)
	win.position = global_position + Vector2(size.x + 8, base_index * 12)
	win.visibility_changed.connect(func(): _refresh_cell(base_index))
	_bag_windows[base_index] = win
	_refresh_cell(base_index)

func _on_visibility_changed() -> void:
	if not visible:
		for win in _bag_windows:
			if win != null:
				win.visible = false

func _input(event: InputEvent) -> void:
	super._input(event)
	# PD_W0027 — a held server-cursor item can reach the Trash cell (the
	# full-bags escape hatch).
	if not visible or Inventory.cursor_slot == null:
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
	# Track 16.0 bug 3 — Node-level _input fires before paperdoll's
	# Control-level _gui_input, which equips from the hand.
	var paperdoll := _find_paperdoll_window()
	if paperdoll != null and paperdoll.visible and paperdoll.get_global_rect().has_point(mp):
		return
	if _trash_cell != null and _trash_cell.get_global_rect().has_point(mp):
		_show_delete_confirm()
		get_viewport().set_input_as_handled()
	# A world click while holding is a ground drop (Inventory.request_ground_drop
	# via player.gd), so anything else falls through untouched.

func _find_paperdoll_window() -> Control:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	return _scan_for_paperdoll(root)

func _scan_for_paperdoll(node: Node) -> Control:
	var s: Script = node.get_script() as Script
	if s != null and s.resource_path.ends_with("paperdoll_window.gd"):
		return node as Control
	for c in node.get_children():
		var found: Control = _scan_for_paperdoll(c)
		if found != null:
			return found
	return null

func _show_delete_confirm() -> void:
	if _delete_dialog == null:
		_delete_dialog = ConfirmationDialog.new()
		_delete_dialog.title = "Delete Item"
		# Track 15.1 — route through DestroyItem on the wire.
		_delete_dialog.confirmed.connect(_confirm_trash_delete)
		_delete_dialog.visibility_changed.connect(func():
			if not _delete_dialog.visible:
				Inventory.note_modal_closed())
		add_child(_delete_dialog)
	var del_item: ItemData = Inventory.cursor_slot["item"]
	var del_count: int = Inventory.cursor_slot["count"]
	if del_count > 1:
		_delete_dialog.dialog_text = "Delete %d × %s?" % [del_count, del_item.item_name]
	else:
		_delete_dialog.dialog_text = "Delete %s?" % del_item.item_name
	_delete_dialog.popup_centered()

# Track 15.1 — trash cell confirm: DestroyItem on the held stack, and the
# server's cursor delta clears the hand.
func _confirm_trash_delete() -> void:
	if Inventory.cursor_slot == null:
		return
	# Full-bags-move: the server refuses destroying a held bag with contents
	# (they would orphan); mirror the refusal instead of letting the confirm be
	# a no-op.
	if Inventory.cursor_holds_full_bag():
		CombatLog.add_line("Empty the bag before destroying it.", CombatLog.MsgType.INFO)
		return
	Net.broadcast_destroy_item(NetProtocol.INV_LOCATION_CURSOR, 0, Inventory.cursor_slot["count"])

# ── Consumable use (base slot items) ─────────────────────────────────────────

func _use_consumable(item: ItemData, index: int) -> void:
	# Track 15.2 — server-authoritative consumable use. Server
	# validates the item, decrements the stack, fans InventoryDelta,
	# applies the heal / food / drink effect via the buff pipeline,
	# and fans HealthUpdate / ManaUpdate / BuffSnapshot. The combat
	# log line still fires locally for snappy feedback; gate the
	# broadcast on client-side data so a non-consumable doesn't
	# round-trip just to be rejected.
	# Food and water the EQ way: the server says "You eat a X." when it
	# takes the item, or refuses with EQ's line when you are full, so no
	# line is printed here (it would double or contradict the server's).
	if item.is_food or item.is_drink:
		Net.hand_eat_requested.emit(item.is_food, item.is_drink)
		Net.broadcast_use_consumable(NetProtocol.INV_LOCATION_BASE, index)
	elif item.heal_on_use > 0.0 or item.mp_on_use > 0.0:
		Net.broadcast_use_consumable(NetProtocol.INV_LOCATION_BASE, index)
		CombatLog.add_line("You use %s." % item.item_name, CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("You can't use %s that way." % item.item_name, CombatLog.MsgType.INFO)

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
