extends DraggablePanel

const W := 520.0
const H := 440.0

enum Mode { BUY, SELL }

var _mode: Mode = Mode.BUY
var _vendor_name: String = ""
var _vendor_type: String = ""
var _stock: Array[String] = []          # item_name strings for BUY
var _sell_items: Array = []             # inventory slots for SELL

var _title_lbl: Label = null
var _coins_lbl: Label = null
var _buy_tab: Button = null
var _sell_tab: Button = null
var _list_vbox: VBoxContainer = null
var _list_btns: Array[Button] = []
var _detail_vbox: VBoxContainer = null
var _qty_label: Label = null
var _action_btn: Button = null
var _result_lbl: Label = null

var _selected_index: int = -1
var _qty: int = 1

func _ready() -> void:
	_build_ui()
	PlayerStats.coins_changed.connect(_on_coins_changed)
	Inventory.inventory_changed.connect(_on_inventory_changed)
	VendorManager.vendor_closed.connect(func(): visible = false)

func open_for(vname: String, vtype: String) -> void:
	_vendor_name = vname
	_vendor_type = vtype
	_title_lbl.text = vname
	_stock.clear()
	var def: Dictionary = VendorDefinitions.ALL.get(vtype, {})
	for iname in def.get("stock", []):
		_stock.append(iname)
	_set_mode(Mode.BUY)
	visible = true

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	size = Vector2(W, H)
	var vp := get_viewport_rect().size
	position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)

	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.C_WINDOW_BG
	bg.border_color = UITheme.C_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8; root.offset_top = 8
	root.offset_right = -8; root.offset_bottom = -8
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	_build_header(root)
	root.add_child(HSeparator.new())
	_build_tabs(root)
	root.add_child(HSeparator.new())
	_build_body(root)
	root.add_child(HSeparator.new())
	_build_footer(root)

func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	_title_lbl = Label.new()
	_title_lbl.text = "Merchant"
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	_title_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(_title_lbl)

	_coins_lbl = Label.new()
	_coins_lbl.text = _coins_text()
	_coins_lbl.add_theme_color_override("font_color", Color(1.00, 0.88, 0.30))
	_coins_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(_coins_lbl)

	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.add_theme_color_override("font_color", UITheme.C_TEXT)
	close.pressed.connect(func(): visible = false)
	row.add_child(close)

func _build_tabs(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	_buy_tab = UITheme.make_button("Buy")
	_buy_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_tab.pressed.connect(func(): _set_mode(Mode.BUY))
	row.add_child(_buy_tab)

	_sell_tab = UITheme.make_button("Sell")
	_sell_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_tab.pressed.connect(func(): _set_mode(Mode.SELL))
	row.add_child(_sell_tab)

func _build_body(parent: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	parent.add_child(body)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(175, 0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 2)
	list_scroll.add_child(_list_vbox)

	body.add_child(VSeparator.new())

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(detail_scroll)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(_detail_vbox)

func _build_footer(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_result_lbl = Label.new()
	_result_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	_result_lbl.add_theme_font_size_override("font_size", 12)
	_result_lbl.clip_text = true
	row.add_child(_result_lbl)

# ── Mode switching ────────────────────────────────────────────────────────────

func _set_mode(m: Mode) -> void:
	_mode = m
	_selected_index = -1
	_qty = 1
	_result_lbl.text = ""

	var active_style := UITheme.make_stylebox(UITheme.C_SELECTED)
	var inactive_style := UITheme.make_stylebox(UITheme.C_BTN_NORM)
	_buy_tab.add_theme_stylebox_override("normal", active_style if m == Mode.BUY else inactive_style)
	_sell_tab.add_theme_stylebox_override("normal", active_style if m == Mode.SELL else inactive_style)

	_populate_list()
	_show_detail_hint()

func _populate_list() -> void:
	_list_btns.clear()
	for child in _list_vbox.get_children():
		child.queue_free()

	if _mode == Mode.BUY:
		for i in _stock.size():
			var iname: String = _stock[i]
			var btn := _make_list_btn(iname, i)
			_list_vbox.add_child(btn)
			_list_btns.append(btn)
	else:
		_sell_items.clear()
		for slot in Inventory.all_slots():
			var item: ItemData = slot["item"]
			if item.vendor_price > 0:
				_sell_items.append(slot)
		for i in _sell_items.size():
			var slot = _sell_items[i]
			var item: ItemData = slot["item"]
			var label := item.item_name
			if slot["count"] > 1:
				label += " (%d)" % slot["count"]
			var btn := _make_list_btn(label, i)
			_list_vbox.add_child(btn)
			_list_btns.append(btn)

func _make_list_btn(label: String, index: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_stylebox_override("normal", UITheme.make_stylebox(UITheme.C_BTN_NORM))
	btn.add_theme_stylebox_override("hover",  UITheme.make_stylebox(UITheme.C_BTN_HOVER))
	btn.pressed.connect(_on_list_btn_pressed.bind(index))
	return btn

# ── Detail panel ──────────────────────────────────────────────────────────────

func _show_detail_hint() -> void:
	_clear_detail()
	_add_detail_label(
		"Select an item." if _mode == Mode.BUY else "Select an item to sell.",
		UITheme.C_NEUTRAL, 12)

func _clear_detail() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()
	_qty_label = null
	_action_btn = null

func _on_list_btn_pressed(idx: int) -> void:
	_selected_index = idx
	_qty = 1
	_result_lbl.text = ""
	for i in _list_btns.size():
		_list_btns[i].add_theme_stylebox_override("normal",
			UITheme.make_stylebox(UITheme.C_SELECTED if i == idx else UITheme.C_BTN_NORM))
	_refresh_detail()

func _refresh_detail() -> void:
	_clear_detail()
	if _selected_index < 0:
		_show_detail_hint()
		return

	var item: ItemData
	var price: int
	var max_qty: int

	if _mode == Mode.BUY:
		if _selected_index >= _stock.size():
			return
		item = _load_item(_stock[_selected_index])
		if item == null:
			_add_detail_label("Item not found.", UITheme.C_NEGATIVE, 12)
			return
		price = item.vendor_price
		max_qty = item.stack_size
	else:
		if _selected_index >= _sell_items.size():
			return
		var slot = _sell_items[_selected_index]
		item = slot["item"]
		price = item.vendor_price / 2
		max_qty = slot["count"]

	_add_detail_label(item.item_name, UITheme.C_TITLE, 13)
	if item.description != "":
		_add_detail_label(item.description, UITheme.C_NEUTRAL, 11)

	var stats_lines: Array = []
	_append_stat_lines(item, stats_lines)
	for line in stats_lines:
		_add_detail_label(line, UITheme.C_TEXT, 11)

	_detail_vbox.add_child(HSeparator.new())

	var price_lbl := "Price: %dg" % price if _mode == Mode.BUY else "Sell value: %dg each" % price
	_add_detail_label(price_lbl, UITheme.C_POSITIVE, 12)

	# Qty selector
	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", 6)
	_detail_vbox.add_child(qty_row)

	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(28, 0)
	minus.pressed.connect(_on_qty_minus)
	qty_row.add_child(minus)

	_qty_label = Label.new()
	_qty_label.text = str(_qty)
	_qty_label.custom_minimum_size = Vector2(32, 0)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_label.add_theme_color_override("font_color", UITheme.C_TEXT)
	_qty_label.add_theme_font_size_override("font_size", 13)
	qty_row.add_child(_qty_label)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 0)
	plus.pressed.connect(_on_qty_plus.bind(max_qty))
	qty_row.add_child(plus)

	_add_detail_label("Total: %dg" % (price * _qty), UITheme.C_TEXT, 12)

	_detail_vbox.add_child(HSeparator.new())

	var action_label := "Buy" if _mode == Mode.BUY else "Sell"
	_action_btn = UITheme.make_button(action_label)
	if _mode == Mode.BUY:
		_action_btn.disabled = PlayerStats.coins < price * _qty
	_action_btn.pressed.connect(_on_action_pressed)
	_detail_vbox.add_child(_action_btn)

func _on_qty_minus() -> void:
	if _qty > 1:
		_qty -= 1
		_refresh_detail()

func _on_qty_plus(max_qty: int) -> void:
	if _qty < max_qty:
		_qty += 1
		_refresh_detail()

# ── Transactions ──────────────────────────────────────────────────────────────

func _on_action_pressed() -> void:
	if _mode == Mode.BUY:
		_do_buy()
	else:
		_do_sell()

func _do_buy() -> void:
	if _selected_index < 0 or _selected_index >= _stock.size():
		return
	var item := _load_item(_stock[_selected_index])
	if item == null:
		return
	var total := item.vendor_price * _qty
	if not PlayerStats.spend_coins(total):
		_set_result("You don't have enough coins.", false)
		return
	if not Inventory.add_item(item, _qty):
		PlayerStats.add_coins(total)  # refund
		_set_result("Your inventory is full.", false)
		return
	_set_result("Purchased %s%s for %dg." % [
		item.item_name,
		" x%d" % _qty if _qty > 1 else "",
		total], true)
	_qty = 1
	_refresh_detail()

func _do_sell() -> void:
	if _selected_index < 0 or _selected_index >= _sell_items.size():
		return
	var slot = _sell_items[_selected_index]
	var item: ItemData = slot["item"]
	var sell_price := item.vendor_price / 2
	var actual_qty := mini(_qty, slot["count"])
	var total := sell_price * actual_qty
	_selected_index = -1
	_qty = 1
	Inventory.remove_item(item, actual_qty)  # fires inventory_changed -> _populate_list
	PlayerStats.add_coins(total)
	_set_result("Sold %s%s for %dg." % [
		item.item_name,
		" x%d" % actual_qty if actual_qty > 1 else "",
		total], true)
	_show_detail_hint()

func _set_result(msg: String, ok: bool) -> void:
	_result_lbl.text = msg
	_result_lbl.add_theme_color_override("font_color",
		UITheme.C_POSITIVE if ok else UITheme.C_NEGATIVE)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _load_item(item_name: String) -> ItemData:
	var path := "res://data/loot/items/%s.tres" % item_name.to_lower().replace(" ", "_")
	return load(path) as ItemData

func _add_detail_label(text: String, color: Color, font_size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_vbox.add_child(lbl)

func _coins_text() -> String:
	return "%dg" % PlayerStats.coins

func _on_coins_changed(amount: int) -> void:
	_coins_lbl.text = "%dg" % amount
	if _action_btn != null and _mode == Mode.BUY and _selected_index >= 0:
		var item := _load_item(_stock[_selected_index])
		if item != null:
			_action_btn.disabled = PlayerStats.coins < item.vendor_price * _qty

func _on_inventory_changed() -> void:
	if visible and _mode == Mode.SELL:
		_populate_list()
