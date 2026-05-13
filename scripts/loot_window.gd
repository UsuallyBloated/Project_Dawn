class_name LootWindow
extends DraggablePanel

const C_BG := Color(0.07, 0.06, 0.04, 0.95)

var bag: LootBag
var _rows: VBoxContainer

func _init(b: LootBag) -> void:
	bag = b

func _ready() -> void:
	bag.tree_exiting.connect(queue_free)
	# Track 5 sub-task 4: server re-broadcasts a fresh bag snapshot
	# every time a slot is claimed. Manager updates bag.items, then
	# emits items_changed; we re-render the row list.
	bag.items_changed.connect(refresh)
	_build_ui()
	await get_tree().process_frame
	size = Vector2(360.0, 220.0)
	position = (get_viewport_rect().size * 0.5) - (size * 0.5) + Vector2(-80.0, -60.0)

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_GOLDEN_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(320.0, 80.0)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left = 8; vbox.offset_top = 8
	vbox.offset_right = -8; vbox.offset_bottom = -8
	add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Loot"
	title.add_theme_color_override("font_color", UITheme.C_TITLE)
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var take_all_btn := Button.new()
	take_all_btn.text = "Take All"
	take_all_btn.add_theme_font_size_override("font_size", 11)
	take_all_btn.pressed.connect(_take_all)
	header.add_child(take_all_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	vbox.add_child(_rows)

	refresh()

func refresh() -> void:
	if not is_instance_valid(bag):
		queue_free()
		return
	for child in _rows.get_children():
		child.queue_free()
	for i in bag.items.size():
		_add_row(bag.items[i], i)

func _add_row(entry: Dictionary, slot_idx: int) -> void:
	var item: ItemData = entry["item"]
	var count: int = entry["count"]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_rows.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name + (" x%d" % count if count > 1 else "")
	name_lbl.add_theme_color_override("font_color", _rarity_color(item.rarity))
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.text = "Take"
	btn.add_theme_font_size_override("font_size", 11)
	var captured := entry
	var captured_slot := slot_idx
	btn.pressed.connect(func(): _take_entry(captured, captured_slot))
	row.add_child(btn)

func _inv_error_msg() -> String:
	return "Your inventory is full."

func _take_entry(entry: Dictionary, slot_idx: int) -> void:
	if not is_instance_valid(bag):
		queue_free()
		return
	# Network-owned bag: send the intent and let the server arbitrate.
	# The server replies with a private LootGranted (handled by
	# RemoteLootBagManager → Inventory.add_item) and a fresh
	# LootBagSpawn snapshot → bag.items_changed → refresh.
	if bag.bag_id >= 0:
		Net.broadcast_loot_item(bag.bag_id, slot_idx)
		return
	if Inventory.add_item(entry["item"], entry["count"]):
		bag.items.erase(entry)
		bag.items_changed.emit()
		CombatLog.add_line("You loot: %s." % entry["item"].item_name, CombatLog.MsgType.LOOT)
		if bag.items.is_empty():
			bag.queue_free()
	else:
		CombatLog.add_line(_inv_error_msg(), CombatLog.MsgType.INFO)

func _take_all() -> void:
	if not is_instance_valid(bag):
		queue_free()
		return
	if bag.bag_id >= 0:
		Net.broadcast_loot_all(bag.bag_id)
		return
	var remaining: Array = []
	for entry in bag.items:
		if Inventory.add_item(entry["item"], entry["count"]):
			CombatLog.add_line("You loot: %s." % entry["item"].item_name, CombatLog.MsgType.LOOT)
		else:
			remaining.append(entry)
	bag.items = remaining
	bag.items_changed.emit()
	if bag.items.is_empty():
		bag.queue_free()
	else:
		CombatLog.add_line(_inv_error_msg(), CombatLog.MsgType.INFO)

func _rarity_color(rarity: ItemData.Rarity) -> Color:
	match rarity:
		ItemData.Rarity.UNCOMMON: return Color(0.3, 0.9, 0.3)
		ItemData.Rarity.RARE:     return Color(0.2, 0.5, 1.0)
		ItemData.Rarity.EPIC:     return Color(0.7, 0.2, 1.0)
		_:                        return UITheme.C_TEXT
