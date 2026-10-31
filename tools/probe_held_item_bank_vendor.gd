extends SceneTree
# Headless probe for the held-item bank and vendor interactions (2026-10-30,
# PD_W0029). The bank window deposits what the cursor holds into the vault a
# cell of which was clicked, refuses a held bag before anything is sent (the
# bank's own line) and asks nothing with an empty hand; the vendor window's
# SELL list leads with the item in hand, labelled as such and sold from the
# cursor, lists nothing extra with an empty hand or a held item the merchant
# would not take, and selling it describes the request. On the old code a
# click on a vault cell while holding did nothing and the held item was
# nowhere in the sell list. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_held_item_bank_vendor.gd

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

# The autoloads join the tree after _initialize, so the checks run on the
# first frame.
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var inv = root.get_node("/root/Inventory")
	var net = root.get_node("/root/Net")
	var log = root.get_node("/root/CombatLog")
	# Online: the windows send through Net (which stays quiet off the wire).
	net._char_id = 7
	var lines: Array[String] = []
	log.line_added.connect(func(text: String, _type: int) -> void: lines.append(text))
	var bread: ItemData = load("res://data/loot/items/bread_loaf.tres")
	var pouch: ItemData = load("res://data/loot/items/small_pouch.tres")
	var conjured: ItemData = load("res://data/loot/items/conjured_bread.tres")

	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	await process_frame

	# ── The bank ────────────────────────────────────────────────────────────
	var bank = load("res://scripts/bank_window.gd").new()
	hud.add_child(bank)
	await process_frame
	var asked: Array = []
	bank.held_deposit_requested.connect(func(shared: bool) -> void: asked.append(shared))

	inv.cursor_slot = null
	_check(not bank.deposit_held_into(false), "an empty hand deposits nothing")
	inv.cursor_slot = {"item": bread, "count": 3}
	_check(bank.deposit_held_into(false), "held loaves are asked into the personal vault")
	_check(bank.deposit_held_into(true), "or into the shared one")
	_check(asked == [false, true], "each request names its vault (%s)" % [asked])
	inv.cursor_slot = {"item": pouch, "count": 1}
	_check(not bank.deposit_held_into(false), "a held bag is refused before anything is sent")
	_check(lines.has("Bags can't go in the bank vault."), "with the bank's own line (%s)" % [lines])
	_check(asked.size() == 2, "and asks nothing")

	# The click path: a left click on a shared-vault cell while holding asks
	# the shared vault; a right click still withdraws (and asks no deposit).
	inv.cursor_slot = {"item": bread, "count": 3}
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	bank._on_vault_cell_input(left, true, 1)
	_check(asked.size() == 3 and asked[2] == true, "a left click on a shared cell while holding deposits there")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	bank._on_vault_cell_input(right, false, 0)
	_check(asked.size() == 3, "a right click asks no deposit")
	inv.cursor_slot = null
	bank._on_vault_cell_input(left, false, 0)
	_check(asked.size() == 3, "a left click with an empty hand asks nothing")

	# ── The merchant ────────────────────────────────────────────────────────
	var vendor = load("res://scripts/vendor_window.gd").new()
	hud.add_child(vendor)
	await process_frame
	vendor.open_for("Brom", "no_such_vendor_type")
	for i in inv.BASE_SLOT_COUNT:
		inv.base_slots[i] = null
		inv.bag_contents[i] = null
	inv.base_slots[2] = {"item": bread, "count": 5}

	inv.cursor_slot = null
	vendor._set_mode(vendor.Mode.SELL)
	_check(vendor._sell_items.size() == 1 and vendor._sell_items[0]["location"] == "base",
		"with an empty hand the list is the bags alone (%d entries)" % vendor._sell_items.size())

	inv.cursor_slot = {"item": bread, "count": 3}
	vendor._populate_list()
	_check(vendor._sell_items.size() == 2, "the held loaves join the list (%d entries)" % vendor._sell_items.size())
	var first = vendor._sell_items[0]
	_check(first["location"] == NetProtocol.INV_LOCATION_CURSOR and first["slot_idx"] == 0 and first["count"] == 3,
		"and head it, from the cursor (%s)" % [first])
	_check(vendor._list_btns[0].text == "In hand: Bread Loaf (3)", "labelled as in hand (%s)" % vendor._list_btns[0].text)
	_check(vendor._sell_items[1]["location"] == "base", "the bags follow")

	vendor._on_list_btn_pressed(0)
	vendor._do_sell()
	_check(vendor._result_lbl.text == "Offered Bread Loaf to the merchant.",
		"selling the held entry describes the request (%s)" % vendor._result_lbl.text)

	inv.cursor_slot = {"item": conjured, "count": 4}
	vendor._populate_list()
	_check(vendor._sell_items.size() == 1 and vendor._sell_items[0]["location"] == "base",
		"a held item with no vendor value is left off the list")

	inv.cursor_slot = null
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
