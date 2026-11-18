extends DraggablePanel

# Banker window (Banker slice 1: coins). Deposit / withdraw coin between the
# carried wallet and the zero-weight bank, and exchange coin between tiers.
#
# Server-authoritative: every action sends an intent and waits for the server's
# CoinsUpdate (wallet) + BankSnapshot (bank) fans to refresh the displays — no
# optimistic local mutation. Mirrors vendor_window.gd's imperative build +
# DraggablePanel base. Slice 2 adds the "Items" tab: a 10-slot per-character
# vault + 2 account-shared slots, with right-click quick-transfer; since
# 2026-10-30 a click on a vault slot while holding an item deposits what is
# held (EQ's drop-on-the-banker), into whichever vault was clicked.
# See docs/concepts/world/currency.md.

const SLOT := 48

# Tier indices match the server's BankExchange (0 = copper … 3 = platinum).
const TIER_NAMES := ["Copper", "Silver", "Gold", "Platinum"]

var _wallet_chips: Array = []   # per-tier clickable coin chips (right-click deposits)
var _bank_chips: Array = []     # per-tier clickable coin chips (right-click withdraws)
var _amount_spins: Array[SpinBox] = []   # parallel to [Platinum, Gold, Silver, Copper]

# Armed by a deposit/withdraw send; the confirming BankSnapshot fan clears the
# entry spinboxes. A rejected action disarms it so the amounts survive for retry.
var _pending_clear := false

# A deposit of the held item was asked of the server (`shared` names the
# vault). The window holds no state about it: the server's cursor delta
# empties the hand and its vault snapshot repaints the cells.
signal held_deposit_requested(shared: bool)

# PD_W0016 — Banker slice 2 item-vault UI (the "Items" tab). Cell panels render
# from BankerManager's cache; the Personal/Shared toggle picks the deposit target.
var _personal_cells: Array = []
var _shared_cells: Array = []

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

# ── UI construction ──────────────────────────────────────

# The frame is scenes/bank_window.tscn (header, the Coins tab with its coin
# rows, deposit and withdraw spins and the exchange row, the Items tab with
# the deposit target and the two vault grids); this script fills the chips,
# the spins, the vault cells and wires the buttons.
const ITEMS_HINT := "Right-click a vault item to withdraw it. With the bank open, right-click an item in your bags to deposit it, or click a vault slot while holding one."

@onready var _title_lbl: Label = $Root/Header/TitleLbl
@onready var _close_btn: Button = $Root/Header/CloseBtn
@onready var _tabs: TabContainer = $Root/Tabs
@onready var _wallet_row: HBoxContainer = $Root/Tabs/Coins/WalletRow
@onready var _bank_row: HBoxContainer = $Root/Tabs/Coins/BankRow
@onready var _spins_row: HBoxContainer = $Root/Tabs/Coins/SpinsRow
@onready var _deposit_btn: Button = $Root/Tabs/Coins/BtnRow/DepositBtn
@onready var _withdraw_btn: Button = $Root/Tabs/Coins/BtnRow/WithdrawBtn
@onready var _qty_spin: SpinBox = $Root/Tabs/Coins/ExRow/QtySpin
@onready var _from_opt: OptionButton = $Root/Tabs/Coins/ExRow/FromOpt
@onready var _to_opt: OptionButton = $Root/Tabs/Coins/ExRow/ToOpt
@onready var _exchange_btn: Button = $Root/Tabs/Coins/ExRow/ExchangeBtn
@onready var _personal_btn: Button = $Root/Tabs/Items/TgtRow/PersonalBtn
@onready var _shared_btn: Button = $Root/Tabs/Items/TgtRow/SharedBtn
@onready var _personal_grid: GridContainer = $Root/Tabs/Items/PersonalGrid
@onready var _shared_grid: GridContainer = $Root/Tabs/Items/SharedGrid
@onready var _items_hint: Label = $Root/Tabs/Items/ItemsHint

func _build_ui() -> void:
	_close_btn.pressed.connect(func(): visible = false)

	# Coins: per-tier clickable coin chips. Right-click a Carried tier to
	# deposit it, a Bank tier to withdraw it (whole tier; the buttons below do
	# exact amounts).
	_wallet_chips = _build_coin_chips(_wallet_row, false)
	_bank_chips = _build_coin_chips(_bank_row, true)

	# One spinbox per tier, ordered Platinum to Copper to read like a price.
	for tier_label in ["P", "G", "S", "C"]:
		var col := VBoxContainer.new()
		var lbl := Label.new()
		lbl.text = tier_label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		col.add_child(lbl)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 1_000_000_000
		spin.step = 1
		spin.custom_minimum_size = Vector2(80, 0)
		col.add_child(spin)
		_amount_spins.append(spin)
		_spins_row.add_child(col)
	_deposit_btn.pressed.connect(_do_deposit)
	_withdraw_btn.pressed.connect(_do_withdraw)

	for i in TIER_NAMES.size():
		_from_opt.add_item(TIER_NAMES[i], i)
		_to_opt.add_item(TIER_NAMES[i], i)
	_from_opt.select(0)  # Copper
	_to_opt.select(1)  # Silver
	_exchange_btn.pressed.connect(_do_exchange)

	# Items: which vault a right-click quick-transfer deposits to, then the
	# two vault grids.
	var group := ButtonGroup.new()
	_wire_target_button(_personal_btn, group, false)
	_wire_target_button(_shared_btn, group, true)
	_personal_cells = _fill_vault_grid(_personal_grid, false, BankerManager.BANK_VAULT_SLOTS)
	_shared_cells = _fill_vault_grid(_shared_grid, true, BankerManager.ACCOUNT_VAULT_SLOTS)
	_items_hint.text = ITEMS_HINT

	# Coins stays the default tab so the _pending_clear deposit/withdraw flow
	# is on the visible tab when the window opens.
	_tabs.current_tab = 0

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


func _fill_vault_grid(grid: GridContainer, shared: bool, count: int) -> Array:
	var cells: Array = []
	for i in count:
		var cell := _make_vault_cell(shared, i)
		grid.add_child(cell)
		cells.append(cell)
	return cells

func _wire_target_button(b: Button, group: ButtonGroup, shared: bool) -> void:
	b.button_group = group
	b.toggled.connect(func(on: bool):
		if on:
			BankerManager.deposit_to_shared = shared)

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
	if not (event is InputEventMouseButton and event.pressed):
		return
	# Holding an item, a left click on any cell of a vault puts the item in
	# that vault (the cell itself does not matter: the server merges into a
	# same-item stack first, then takes a free slot).
	if event.button_index == MOUSE_BUTTON_LEFT and Inventory.cursor_slot != null:
		deposit_held_into(shared)
		get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		Net.broadcast_bank_withdraw_item(shared, slot)
		get_viewport().set_input_as_handled()

# Deposit what the cursor holds into the personal (false) or the shared (true)
# vault. The server places it and its cursor delta empties the hand; the
# refusals it would send (no banker in reach, a full vault, a bag) arrive as
# BankRejected, except the bag, which no vault takes and so is refused here
# with the bank's own line before anything is sent. Returns whether a request
# went out.
func deposit_held_into(shared: bool) -> bool:
	var held = Inventory.cursor_slot
	if held == null:
		return false
	if held["item"].type == ItemData.Type.BAG:
		CombatLog.add_line("Bags can't go in the bank vault.", CombatLog.MsgType.INFO)
		return false
	Net.broadcast_bank_store_item(NetProtocol.INV_LOCATION_CURSOR, 0, shared)
	held_deposit_requested.emit(shared)
	return true

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
