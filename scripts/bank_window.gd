extends DraggablePanel

# Banker window (Banker slice 1: coins). Deposit / withdraw coin between the
# carried wallet and the zero-weight bank, and exchange coin between tiers.
#
# Server-authoritative: every action sends an intent and waits for the server's
# CoinsUpdate (wallet) + BankSnapshot (bank) fans to refresh the displays — no
# optimistic local mutation. Mirrors vendor_window.gd's imperative build +
# DraggablePanel base. Slice 2 adds the "Items" tab: a 10-slot per-character
# vault + 2 account-shared slots, with right-click quick-transfer.
# See docs/concepts/world/currency.md.

const W := 460.0
const H := 560.0
const SLOT := 48

# Tier indices match the server's BankExchange (0 = copper … 3 = platinum).
const TIER_NAMES := ["Copper", "Silver", "Gold", "Platinum"]

var _title_lbl: Label = null
var _wallet_chips: Array = []   # per-tier clickable coin chips (right-click deposits)
var _bank_chips: Array = []     # per-tier clickable coin chips (right-click withdraws)
var _amount_spins: Array[SpinBox] = []   # parallel to [Platinum, Gold, Silver, Copper]
var _from_opt: OptionButton = null
var _to_opt: OptionButton = null
var _qty_spin: SpinBox = null

# Armed by a deposit/withdraw send; the confirming BankSnapshot fan clears the
# entry spinboxes. A rejected action disarms it so the amounts survive for retry.
var _pending_clear := false

# PD_W0016 — Banker slice 2 item-vault UI (the "Items" tab). Cell panels render
# from BankerManager's cache; the Personal/Shared toggle picks the deposit target.
var _personal_cells: Array = []
var _shared_cells: Array = []
var _personal_btn: Button = null
var _shared_btn: Button = null

func _ready() -> void:
	_build_ui()
	PlayerStats.coins_changed.connect(func(_p, _g, _s, _c): _refresh_wallet())
	BankerManager.bank_balance_changed.connect(_on_bank_balance_changed)
	BankerManager.banker_closed.connect(func(): visible = false)
	BankerManager.vault_changed.connect(_refresh_vault)
	Net.world_bank_rejected.connect(_on_bank_rejected)
	# Keep BankerManager.bank_is_open in sync so the inventory/bag right-click
	# quick-transfer deposits only while this window is open.
	visibility_changed.connect(func(): BankerManager.bank_is_open = visible)

func open_for(banker_name: String) -> void:
	_title_lbl.text = banker_name
	_refresh_wallet()
	_refresh_bank()
	_refresh_vault(false)
	_refresh_vault(true)
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

	# Coins (slice 1) and Items (slice 2) live on separate tabs. Coins stays the
	# default tab so the _pending_clear deposit/withdraw flow is on the visible
	# tab when the window opens.
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var coins_tab := VBoxContainer.new()
	coins_tab.name = "Coins"
	coins_tab.add_theme_constant_override("separation", 6)
	tabs.add_child(coins_tab)
	_build_balances(coins_tab)
	coins_tab.add_child(HSeparator.new())
	_build_deposit_withdraw(coins_tab)
	coins_tab.add_child(HSeparator.new())
	_build_exchange(coins_tab)

	var items_tab := VBoxContainer.new()
	items_tab.name = "Items"
	items_tab.add_theme_constant_override("separation", 6)
	tabs.add_child(items_tab)
	_build_items(items_tab)

	tabs.current_tab = 0

func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	_title_lbl = Label.new()
	_title_lbl.text = "Bank"
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	_title_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(_title_lbl)

	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.add_theme_color_override("font_color", UITheme.C_TEXT)
	close.pressed.connect(func(): visible = false)
	row.add_child(close)

func _build_balances(parent: VBoxContainer) -> void:
	# Per-tier clickable coin chips. Right-click a Carried tier to deposit it, a
	# Bank tier to withdraw it (whole tier; the buttons below do exact amounts).
	var w_row := HBoxContainer.new()
	w_row.add_theme_constant_override("separation", 8)
	parent.add_child(w_row)
	w_row.add_child(_make_section_label("Carried:"))
	_wallet_chips = _build_coin_chips(w_row, false)

	var b_row := HBoxContainer.new()
	b_row.add_theme_constant_override("separation", 8)
	parent.add_child(b_row)
	b_row.add_child(_make_section_label("Bank:"))
	_bank_chips = _build_coin_chips(b_row, true)

func _build_coin_chips(row: HBoxContainer, is_bank: bool) -> Array:
	var chips: Array = []
	# Platinum to copper, left to right, like a price.
	for tier in [3, 2, 1, 0]:
		var chip := Label.new()
		chip.add_theme_color_override("font_color", UITheme.C_COINS)
		chip.add_theme_font_size_override("font_size", 12)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.tooltip_text = "Right-click to withdraw this coin" if is_bank else "Right-click to deposit this coin"
		chip.gui_input.connect(_on_coin_chip_input.bind(is_bank, tier))
		row.add_child(chip)
		chips.append({"label": chip, "tier": tier})
	return chips

func _build_deposit_withdraw(parent: VBoxContainer) -> void:
	var hdr := _make_section_label("Deposit / Withdraw")
	parent.add_child(hdr)

	# One spinbox per tier, ordered Platinum → Copper to read like a price.
	var spins_row := HBoxContainer.new()
	spins_row.add_theme_constant_override("separation", 6)
	spins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(spins_row)
	for tier_label in ["P", "G", "S", "C"]:
		var col := VBoxContainer.new()
		var lbl := Label.new()
		lbl.text = tier_label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		lbl.add_theme_font_size_override("font_size", 11)
		col.add_child(lbl)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 1_000_000_000
		spin.step = 1
		spin.custom_minimum_size = Vector2(80, 0)
		col.add_child(spin)
		_amount_spins.append(spin)
		spins_row.add_child(col)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	parent.add_child(btn_row)
	var dep := Button.new()
	dep.text = "Deposit"
	dep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dep.pressed.connect(_do_deposit)
	btn_row.add_child(dep)
	var wd := Button.new()
	wd.text = "Withdraw"
	wd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wd.pressed.connect(_do_withdraw)
	btn_row.add_child(wd)

func _build_exchange(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_label("Exchange coin (free)"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	_qty_spin = SpinBox.new()
	_qty_spin.min_value = 1
	_qty_spin.max_value = 1_000_000_000
	_qty_spin.value = 100
	_qty_spin.custom_minimum_size = Vector2(96, 0)
	row.add_child(_qty_spin)

	_from_opt = OptionButton.new()
	for i in TIER_NAMES.size():
		_from_opt.add_item(TIER_NAMES[i], i)
	_from_opt.select(0)  # Copper
	row.add_child(_from_opt)

	var arrow := Label.new()
	arrow.text = "to"
	arrow.add_theme_color_override("font_color", UITheme.C_TEXT)
	row.add_child(arrow)

	_to_opt = OptionButton.new()
	for i in TIER_NAMES.size():
		_to_opt.add_item(TIER_NAMES[i], i)
	_to_opt.select(1)  # Silver
	row.add_child(_to_opt)

	var ex := Button.new()
	ex.text = "Exchange"
	ex.pressed.connect(_do_exchange)
	row.add_child(ex)

	var hint := Label.new()
	hint.text = "100 copper = 1 silver. Up-conversions take whole multiples; any remainder stays put."
	hint.add_theme_color_override("font_color", UITheme.C_TEXT)
	hint.add_theme_font_size_override("font_size", 10)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl

# ── Items tab (slice 2) ────────────────────────────────────────────────────────

func _build_items(parent: VBoxContainer) -> void:
	# Deposit-target toggle: which vault a right-click quick-transfer deposits to.
	var tgt_row := HBoxContainer.new()
	tgt_row.add_theme_constant_override("separation", 6)
	parent.add_child(tgt_row)
	tgt_row.add_child(_make_section_label("Deposit to:"))
	var group := ButtonGroup.new()
	_personal_btn = _make_target_button("Personal", group, false)
	_shared_btn = _make_target_button("Shared", group, true)
	_personal_btn.button_pressed = true
	tgt_row.add_child(_personal_btn)
	tgt_row.add_child(_shared_btn)

	parent.add_child(_make_section_label("Bank vault (this character)"))
	_personal_cells = _build_vault_grid(parent, false, BankerManager.BANK_VAULT_SLOTS)

	parent.add_child(_make_section_label("Shared vault (all your characters)"))
	_shared_cells = _build_vault_grid(parent, true, BankerManager.ACCOUNT_VAULT_SLOTS)

	var hint := Label.new()
	hint.text = "Right-click a vault item to withdraw it. With the bank open, right-click an item in your bags to deposit it."
	hint.add_theme_color_override("font_color", UITheme.C_TEXT)
	hint.add_theme_font_size_override("font_size", 10)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)

func _build_vault_grid(parent: VBoxContainer, shared: bool, count: int) -> Array:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var cells: Array = []
	for i in count:
		var cell := _make_vault_cell(shared, i)
		grid.add_child(cell)
		cells.append(cell)
	parent.add_child(grid)
	return cells

func _make_target_button(text: String, group: ButtonGroup, shared: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.toggled.connect(func(on: bool):
		if on:
			BankerManager.deposit_to_shared = shared)
	return b

func _make_vault_cell(shared: bool, slot: int) -> Panel:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(SLOT, SLOT)
	# Personal slots use the normal border; shared slots a cool blue so the
	# account-shared (cross-character) slots read as clearly different.
	var border: Color = Color(0.40, 0.55, 0.75) if shared else UITheme.C_BORDER
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C_SLOT_BG
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	cell.add_theme_stylebox_override("panel", sb)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)

	# Name fallback, shown when the item has no icon. Not decoration: no item in
	# the game defines an icon yet, so without this a deposited stack of one
	# paints an empty texture over an empty count label and the slot looks
	# EMPTY — which is what made deposits appear to destroy items. Mirrors the
	# same fallback in inventory_window.gd, which is why bags never had the bug.
	var name_lbl := Label.new()
	name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.visible = false
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(name_lbl)

	var count := Label.new()
	count.anchor_right = 1.0
	count.anchor_bottom = 1.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 10)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 3)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(count)

	cell.set_meta("icon", icon)
	cell.set_meta("name", name_lbl)
	cell.set_meta("count", count)
	cell.gui_input.connect(_on_vault_cell_input.bind(shared, slot))
	return cell

func _on_vault_cell_input(event: InputEvent, shared: bool, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		Net.broadcast_bank_withdraw_item(shared, slot)
		get_viewport().set_input_as_handled()

func _refresh_vault(shared: bool) -> void:
	var cells: Array = _shared_cells if shared else _personal_cells
	var arr: Array = BankerManager.get_vault(shared)
	for i in cells.size():
		var cell: Panel = cells[i]
		var icon: TextureRect = cell.get_meta("icon")
		var name_lbl: Label = cell.get_meta("name")
		var count: Label = cell.get_meta("count")
		var entry = arr[i] if i < arr.size() else null
		if entry == null:
			icon.texture = null
			name_lbl.visible = false
			name_lbl.text = ""
			count.text = ""
			cell.tooltip_text = ""
		else:
			var item: ItemData = entry["item"]
			icon.texture = item.icon
			# Fall back to the name whenever there is no icon, so a stored item is
			# always visible as something.
			name_lbl.visible = item.icon == null
			name_lbl.text = item.item_name
			count.text = str(entry["count"]) if entry["count"] > 1 else ""
			cell.tooltip_text = "%s%s\nRight-click to withdraw." % [
				item.item_name,
				" x%d" % int(entry["count"]) if int(entry["count"]) > 1 else "",
			]

# ── Display refresh ───────────────────────────────────────────────────────────

func _refresh_wallet() -> void:
	_set_coin_chips(_wallet_chips, [PlayerStats.copper, PlayerStats.silver, PlayerStats.gold, PlayerStats.platinum])

func _refresh_bank() -> void:
	_set_coin_chips(_bank_chips, [BankerManager.bank_copper, BankerManager.bank_silver, BankerManager.bank_gold, BankerManager.bank_platinum])

# by_tier indexed 0=copper..3=platinum.
func _set_coin_chips(chips: Array, by_tier: Array) -> void:
	for entry in chips:
		var tier: int = entry["tier"]
		(entry["label"] as Label).text = "%d%s" % [by_tier[tier], ["c", "s", "g", "p"][tier]]

# Right-click a coin chip to quick-transfer that whole tier (deposit from the
# wallet, withdraw from the bank). Exact amounts still use the buttons below.
func _on_coin_chip_input(event: InputEvent, is_bank: bool, tier: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var by_tier: Array = (
		[BankerManager.bank_copper, BankerManager.bank_silver, BankerManager.bank_gold, BankerManager.bank_platinum]
		if is_bank else
		[PlayerStats.copper, PlayerStats.silver, PlayerStats.gold, PlayerStats.platinum]
	)
	var amt: int = by_tier[tier]
	if amt <= 0:
		return
	# Wire order is (platinum, gold, silver, copper); tier 0=copper..3=platinum.
	var p: int = amt if tier == 3 else 0
	var g: int = amt if tier == 2 else 0
	var s: int = amt if tier == 1 else 0
	var c: int = amt if tier == 0 else 0
	if is_bank:
		Net.broadcast_bank_withdraw(p, g, s, c)
	else:
		Net.broadcast_bank_deposit(p, g, s, c)
	get_viewport().set_input_as_handled()

# A successful deposit/withdraw fans a fresh BankSnapshot — that's the cue the
# action landed, so clear the entry spinboxes now (not optimistically on send,
# since the server can reject). Snapshots from login / other actions don't
# clear, since the flag is only armed by _do_deposit / _do_withdraw.
func _on_bank_balance_changed(_platinum: int, _gold: int, _silver: int, _copper: int) -> void:
	_refresh_bank()
	if _pending_clear:
		_pending_clear = false
		_clear_amounts()

# ── Actions (server-authoritative; no optimistic mutation) ─────────────────────

# Spin values as [platinum, gold, silver, copper] to match the wire order.
func _amounts() -> Array:
	return [
		int(_amount_spins[0].value), int(_amount_spins[1].value),
		int(_amount_spins[2].value), int(_amount_spins[3].value),
	]

func _clear_amounts() -> void:
	for spin in _amount_spins:
		spin.value = 0

func _do_deposit() -> void:
	var a := _amounts()
	if a[0] == 0 and a[1] == 0 and a[2] == 0 and a[3] == 0:
		return
	Net.broadcast_bank_deposit(a[0], a[1], a[2], a[3])
	_pending_clear = true

func _do_withdraw() -> void:
	var a := _amounts()
	if a[0] == 0 and a[1] == 0 and a[2] == 0 and a[3] == 0:
		return
	Net.broadcast_bank_withdraw(a[0], a[1], a[2], a[3])
	_pending_clear = true

func _do_exchange() -> void:
	var from_tier := _from_opt.get_selected_id()
	var to_tier := _to_opt.get_selected_id()
	var qty := int(_qty_spin.value)
	if from_tier == to_tier or qty <= 0:
		return
	Net.broadcast_bank_exchange(from_tier, to_tier, qty)

func _on_bank_rejected(reason: String) -> void:
	# Keep the entered amounts so the player can fix + retry (the server left the
	# wallet untouched on reject); only a confirming snapshot clears them.
	_pending_clear = false
	CombatLog.add_line(reason, CombatLog.MsgType.INFO)
