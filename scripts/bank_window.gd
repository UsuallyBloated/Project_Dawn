extends DraggablePanel

# Banker window (Banker slice 1: coins). Deposit / withdraw coin between the
# carried wallet and the zero-weight bank, and exchange coin between tiers.
#
# Server-authoritative: every action sends an intent and waits for the server's
# CoinsUpdate (wallet) + BankSnapshot (bank) fans to refresh the displays — no
# optimistic local mutation. Mirrors vendor_window.gd's imperative build +
# DraggablePanel base. Item storage (incl. the 2 account-shared slots) is slice
# 2. See docs/concepts/world/currency.md.

const W := 460.0
const H := 380.0

# Tier indices match the server's BankExchange (0 = copper … 3 = platinum).
const TIER_NAMES := ["Copper", "Silver", "Gold", "Platinum"]

var _title_lbl: Label = null
var _wallet_lbl: Label = null
var _bank_lbl: Label = null
var _amount_spins: Array[SpinBox] = []   # parallel to [Platinum, Gold, Silver, Copper]
var _from_opt: OptionButton = null
var _to_opt: OptionButton = null
var _qty_spin: SpinBox = null

# Armed by a deposit/withdraw send; the confirming BankSnapshot fan clears the
# entry spinboxes. A rejected action disarms it so the amounts survive for retry.
var _pending_clear := false

func _ready() -> void:
	_build_ui()
	PlayerStats.coins_changed.connect(func(_p, _g, _s, _c): _refresh_wallet())
	BankerManager.bank_balance_changed.connect(_on_bank_balance_changed)
	BankerManager.banker_closed.connect(func(): visible = false)
	Net.world_bank_rejected.connect(_on_bank_rejected)

func open_for(banker_name: String) -> void:
	_title_lbl.text = banker_name
	_refresh_wallet()
	_refresh_bank()
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
	_build_balances(root)
	root.add_child(HSeparator.new())
	_build_deposit_withdraw(root)
	root.add_child(HSeparator.new())
	_build_exchange(root)

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
	_wallet_lbl = _make_coin_label()
	parent.add_child(_wallet_lbl)
	_bank_lbl = _make_coin_label()
	parent.add_child(_bank_lbl)

func _make_coin_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_color_override("font_color", UITheme.C_COINS)
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl

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

# ── Display refresh ───────────────────────────────────────────────────────────

func _refresh_wallet() -> void:
	_wallet_lbl.text = "Carried:  " + Currency.format_coins(
		PlayerStats.platinum, PlayerStats.gold, PlayerStats.silver, PlayerStats.copper)

func _refresh_bank() -> void:
	_bank_lbl.text = "Bank:     " + Currency.format_coins(
		BankerManager.bank_platinum, BankerManager.bank_gold,
		BankerManager.bank_silver, BankerManager.bank_copper)

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
