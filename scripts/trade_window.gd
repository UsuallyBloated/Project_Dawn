extends Panel
class_name TradeWindow

# PD_W0028 — the trade window (docs/design/trade_window.md).
#
# A two-sided view driven ENTIRELY by the server. The client holds no trade
# state of its own: it renders the last `world_trade_offer_update` per side,
# forwards clicks as intents, and closes on `world_trade_closed`. Escrow is
# server-side (offered items stay locked in the owner's real inventory until
# the atomic commit), so nothing here can dupe or strand an item.
#
# Interaction: click one of YOUR 8 slots while holding an item to offer it
# from the cursor; click a filled slot of yours to retrieve it. The partner's
# side is display-only. Coins are typed into four per-tier fields. Any edit
# clears both accepts, server-side, so the accept lights always reflect truth.

const TRADE_SLOTS := 8
const SLOT_PX := 44

var _partner_id: int = -1
var _my_slots: Array[Button] = []
var _their_slots: Array[Button] = []
var _my_accept_light: Label = null
var _their_accept_light: Label = null
var _accept_button: Button = null
var _coin_fields: Dictionary = {}  # tier name -> SpinBox
var _their_coins_label: Label = null
var _title: Label = null
# The last coin offer the SERVER confirmed for my side. Pushes only fire when
# a field differs from this, so re-committing an unchanged value (or a
# refused overdraft the server never applied) cannot fire a no-op edit that
# clears both accepts.
var _my_coins_confirmed: Array[int] = [0, 0, 0, 0]

func _ready() -> void:
	custom_minimum_size = Vector2(560, 360)
	# Centered on screen: with center anchors the position is the offset
	# from the midpoint, so back it up by half the size (same as the HUD's
	# other centered panels).
	set_anchors_preset(Control.PRESET_CENTER)
	position = -custom_minimum_size / 2.0
	_build()
	visible = false
	Net.world_trade_opened.connect(_on_trade_opened)
	Net.world_trade_offer_update.connect(_on_offer_update)
	Net.world_trade_accept_state.connect(_on_accept_state)
	Net.world_trade_closed.connect(_on_trade_closed)
	# The HUD's ESC stack hides the top window by flipping `visible`. A hide
	# while a session is live must CANCEL it server-side, or the offered items
	# stay escrowed with no window to reach Cancel from. `_on_trade_closed`
	# clears `_partner_id` before hiding, so a server-driven close does not
	# double-cancel.
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if not visible and _partner_id >= 0:
		_partner_id = -1
		Net.broadcast_trade_cancel()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	add_child(root)

	_title = Label.new()
	_title.text = "Trade"
	_title.add_theme_font_size_override("font_size", 20)
	root.add_child(_title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	columns.add_child(_build_side("Your offer", _my_slots, true))
	columns.add_child(_build_side("Their offer", _their_slots, false))

	# Accept lights.
	var lights := HBoxContainer.new()
	lights.add_theme_constant_override("separation", 24)
	root.add_child(lights)
	_my_accept_light = Label.new()
	_my_accept_light.text = "You: not accepted"
	lights.add_child(_my_accept_light)
	_their_accept_light = Label.new()
	_their_accept_light.text = "Them: not accepted"
	lights.add_child(_their_accept_light)

	# Buttons.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	_accept_button = Button.new()
	_accept_button.text = "Trade"
	_accept_button.pressed.connect(func(): Net.broadcast_trade_accept())
	buttons.add_child(_accept_button)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): Net.broadcast_trade_cancel())
	buttons.add_child(cancel)

func _build_side(heading: String, slot_arr: Array[Button], mine: bool) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Label.new()
	head.text = heading
	col.add_child(head)

	var grid := GridContainer.new()
	grid.columns = 4
	col.add_child(grid)
	for i in TRADE_SLOTS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		slot.clip_text = true
		if mine:
			slot.pressed.connect(_on_my_slot_pressed.bind(i))
		else:
			slot.disabled = true
		slot_arr.append(slot)
		grid.add_child(slot)

	# Coins.
	var coin_row := HBoxContainer.new()
	col.add_child(coin_row)
	if mine:
		for tier in ["platinum", "gold", "silver", "copper"]:
			var box := SpinBox.new()
			box.min_value = 0
			box.max_value = 999999
			box.prefix = tier.substr(0, 1).to_upper()
			box.custom_minimum_size = Vector2(72, 0)
			box.value_changed.connect(func(_v): _push_coins())
			_coin_fields[tier] = box
			coin_row.add_child(box)
	else:
		_their_coins_label = Label.new()
		_their_coins_label.text = "Coin: 0"
		coin_row.add_child(_their_coins_label)
	return col

func _on_my_slot_pressed(window_slot: int) -> void:
	# A filled slot retrieves; an empty slot offers from the cursor.
	var already: String = _my_slots[window_slot].get_meta("path", "")
	if already != "":
		Net.broadcast_trade_retrieve_item(window_slot)
		return
	if Inventory.cursor_slot == null:
		CombatLog.add_line("Pick up the item you want to trade first.", CombatLog.MsgType.INFO)
		return
	Net.broadcast_trade_offer_item(window_slot, NetProtocol.INV_LOCATION_CURSOR, 0)

func _push_coins() -> void:
	var wanted: Array[int] = [
		int(_coin_fields["platinum"].value),
		int(_coin_fields["gold"].value),
		int(_coin_fields["silver"].value),
		int(_coin_fields["copper"].value),
	]
	# No-op edits never reach the server (an edit clears both accepts).
	if wanted == _my_coins_confirmed:
		return
	Net.broadcast_trade_offer_coins(wanted[0], wanted[1], wanted[2], wanted[3])

func _on_trade_opened(partner_id: int, partner_name: String) -> void:
	_partner_id = partner_id
	if _title != null:
		_title.text = "Trade with %s" % partner_name
	_reset_view()
	visible = true

func _reset_view() -> void:
	for arr in [_my_slots, _their_slots]:
		for s in arr:
			s.text = ""
			s.set_meta("path", "")
	for tier in _coin_fields:
		_coin_fields[tier].set_value_no_signal(0)
	_my_coins_confirmed = [0, 0, 0, 0]
	if _their_coins_label != null:
		_their_coins_label.text = "Coin: 0"
	_set_lights(false, false)

func _on_offer_update(mine: bool, item_paths: PackedStringArray, counts: PackedInt32Array, platinum: int, gold: int, silver: int, copper: int) -> void:
	# Always applied, visible or not: the server is the only source of truth
	# and a dropped update would leave the next open showing stale offers.
	var arr := _my_slots if mine else _their_slots
	for i in TRADE_SLOTS:
		var path: String = item_paths[i] if i < item_paths.size() else ""
		var count: int = counts[i] if i < counts.size() else 0
		arr[i].set_meta("path", path)
		if path == "":
			arr[i].text = ""
		else:
			arr[i].text = _label_for(path, count)
	if mine:
		# The fields show what the server APPLIED, never what was typed: a
		# refused overdraft snaps back instead of lying about the offer.
		_my_coins_confirmed = [platinum, gold, silver, copper]
		var tiers := ["platinum", "gold", "silver", "copper"]
		for t in tiers.size():
			if _coin_fields.has(tiers[t]):
				_coin_fields[tiers[t]].set_value_no_signal(_my_coins_confirmed[t])
	elif _their_coins_label != null:
		_their_coins_label.text = "Coin: %s" % _coin_text(platinum, gold, silver, copper)

func _label_for(path: String, count: int) -> String:
	var item := load(path) as ItemData
	var nm: String = item.item_name if item != null else path.get_file().get_basename()
	return "%s\nx%d" % [nm, count] if count > 1 else nm

func _coin_text(p: int, g: int, s: int, c: int) -> String:
	var parts: Array = []
	if p > 0: parts.append("%dp" % p)
	if g > 0: parts.append("%dg" % g)
	if s > 0: parts.append("%ds" % s)
	if c > 0: parts.append("%dc" % c)
	return "0" if parts.is_empty() else " ".join(parts)

func _on_accept_state(you: bool, them: bool) -> void:
	_set_lights(you, them)

func _set_lights(you: bool, them: bool) -> void:
	if _my_accept_light != null:
		_my_accept_light.text = "You: ACCEPTED" if you else "You: not accepted"
		_my_accept_light.modulate = Color(0.5, 1.0, 0.5) if you else Color(1, 1, 1)
	if _their_accept_light != null:
		_their_accept_light.text = "Them: ACCEPTED" if them else "Them: not accepted"
		_their_accept_light.modulate = Color(0.5, 1.0, 0.5) if them else Color(1, 1, 1)

func _on_trade_closed(committed: bool, reason: String) -> void:
	if reason != "":
		CombatLog.add_line(reason, CombatLog.MsgType.INFO)
	_partner_id = -1
	visible = false
