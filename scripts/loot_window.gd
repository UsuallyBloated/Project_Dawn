class_name LootWindow
extends DraggablePanel

# Duck-typed: a LootBag OR a Corpse (corpse / resurrection Slice 2). Both expose
# `items`, `coin_*` + `has_coins()`, `bag_id` (loot-target id), and an
# `items_changed` signal, so this window drives either without caring which.
# Set by the opener (Loot.show_window) before the window joins the tree.
var bag
@onready var _rows: VBoxContainer = $VBox/Rows
@onready var _take_all_btn: Button = $VBox/Header/TakeAllBtn
@onready var _close_btn: Button = $VBox/Header/CloseBtn

# The frame is scenes/loot_window.tscn (title, Take All, close, the row list);
# this script fills the rows from the bag.
func _ready() -> void:
	bag.tree_exiting.connect(queue_free)
	# Track 5 sub-task 4: server re-broadcasts a fresh bag snapshot
	# every time a slot is claimed. Manager updates bag.items, then
	# emits items_changed; we re-render the row list.
	bag.items_changed.connect(refresh)
	_take_all_btn.pressed.connect(_take_all)
	_close_btn.pressed.connect(func(): visible = false)
	refresh()
	await get_tree().process_frame
	size = Vector2(360.0, 220.0)
	position = (get_viewport_rect().size * 0.5) - (size * 0.5) + Vector2(-80.0, -60.0)

func refresh() -> void:
	if not is_instance_valid(bag):
		queue_free()
		return
	for child in _rows.get_children():
		child.queue_free()
	# PD_W0014 — coin sits at the top of the corpse contents. It's
	# informational: looting any item (or Take All) auto-credits the coin
	# server-side, so there's no per-coin Take button.
	if bag.has_coins():
		_add_coin_row()
	for i in bag.items.size():
		_add_row(bag.items[i], i)

func _add_coin_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_rows.add_child(row)
	var lbl := Label.new()
	lbl.text = "Coins: " + Currency.format_coins(
		bag.coin_platinum, bag.coin_gold, bag.coin_silver, bag.coin_copper)
	lbl.add_theme_color_override("font_color", UITheme.C_COINS)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

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

func _take_entry(entry: Dictionary, slot_idx: int) -> void:
	if not is_instance_valid(bag):
		queue_free()
		return
	# Send the intent and let the server arbitrate. The server replies with
	# a private LootGranted (the chat line), an InventoryDelta (the item) and
	# a fresh LootBagSpawn snapshot → bag.items_changed → refresh.
	Net.broadcast_loot_item(bag.bag_id, slot_idx)

func _take_all() -> void:
	if not is_instance_valid(bag):
		queue_free()
		return
	Net.broadcast_loot_all(bag.bag_id)

func _rarity_color(rarity: ItemData.Rarity) -> Color:
	match rarity:
		ItemData.Rarity.UNCOMMON: return Color(0.3, 0.9, 0.3)
		ItemData.Rarity.RARE:     return Color(0.2, 0.5, 1.0)
		ItemData.Rarity.EPIC:     return Color(0.7, 0.2, 1.0)
		_:                        return UITheme.C_TEXT
