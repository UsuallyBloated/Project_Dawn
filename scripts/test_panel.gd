extends CanvasLayer

var _race_opt: OptionButton
var _class_opt: OptionButton
var _level_lbl: Label
var _body: VBoxContainer
var _toggle_btn: Button
var _collapsed: bool = false

const C_BG     := Color(0.10, 0.08, 0.06, 0.93)
const C_BORDER := Color(0.80, 0.60, 0.20, 1.00)
const C_TITLE  := Color(0.90, 0.75, 0.30, 1.00)
const C_TEXT   := Color(0.75, 0.70, 0.60, 1.00)
const C_DIE    := Color(0.70, 0.15, 0.15, 1.00)

func _ready() -> void:
	layer = 10
	_build_ui()
	_populate_options()

func _build_ui() -> void:
	var panel := DraggablePanel.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(230, 60)
	panel.size = Vector2(230, 500)
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "TEST ROOM"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", C_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_toggle_btn = Button.new()
	_toggle_btn.text = "−"
	_toggle_btn.custom_minimum_size = Vector2(24, 24)
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.pressed.connect(_toggle_collapse)
	header.add_child(_toggle_btn)

	# Body (collapsible)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	vbox.add_child(_body)

	_body.add_child(_make_label("Race"))
	_race_opt = OptionButton.new()
	_race_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_opt.focus_mode = Control.FOCUS_NONE
	_body.add_child(_race_opt)

	_body.add_child(_make_label("Class"))
	_class_opt = OptionButton.new()
	_class_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_opt.focus_mode = Control.FOCUS_NONE
	_body.add_child(_class_opt)

	# Level row
	_body.add_child(_make_label("Level"))
	var lvl_row := HBoxContainer.new()
	lvl_row.add_theme_constant_override("separation", 4)
	_body.add_child(lvl_row)

	var btn_minus := _make_step_btn("−")
	btn_minus.pressed.connect(_change_level.bind(-1))
	lvl_row.add_child(btn_minus)

	_level_lbl = Label.new()
	_level_lbl.text = "1"
	_level_lbl.add_theme_font_size_override("font_size", 14)
	_level_lbl.add_theme_color_override("font_color", C_TITLE)
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_row.add_child(_level_lbl)

	var btn_plus := _make_step_btn("+")
	btn_plus.pressed.connect(_change_level.bind(1))
	lvl_row.add_child(btn_plus)

	var apply_btn := _make_btn("Apply Race / Class / Level", C_BORDER)
	apply_btn.pressed.connect(_apply_race_class)
	_body.add_child(apply_btn)

	_body.add_child(HSeparator.new())

	var heal_btn := _make_btn("Full Heal", Color(0.20, 0.55, 0.20, 1.0))
	heal_btn.pressed.connect(_full_heal)
	_body.add_child(heal_btn)

	var die_btn := _make_btn("Trigger Death", C_DIE)
	die_btn.pressed.connect(_trigger_death)
	_body.add_child(die_btn)

	var bags_btn := _make_btn("Give Bags", Color(0.45, 0.35, 0.15, 1.0))
	bags_btn.pressed.connect(_give_bags)
	_body.add_child(bags_btn)

	var food_btn := _make_btn("Give Food & Drink", Color(0.35, 0.60, 0.20, 1.0))
	food_btn.pressed.connect(_give_consumables)
	_body.add_child(food_btn)

	var bow_btn := _make_btn("Give Bow", Color(0.55, 0.35, 0.10, 1.0))
	bow_btn.pressed.connect(_give_bow)
	_body.add_child(bow_btn)

	var proc_btn := _make_btn("Give Proc Weapon", Color(0.65, 0.25, 0.05, 1.0))
	proc_btn.pressed.connect(_give_proc_weapon)
	_body.add_child(proc_btn)

	var quest_btn := _make_btn("Add Test Quest", Color(0.60, 0.45, 0.10, 1.0))
	quest_btn.pressed.connect(_add_test_quest)
	_body.add_child(quest_btn)

	var craft_btn := _make_btn("Give Crafting Materials", Color(0.20, 0.50, 0.65, 1.0))
	craft_btn.pressed.connect(_give_crafting_materials)
	_body.add_child(craft_btn)

func _make_label(t: String) -> Label:
	var lbl := Label.new()
	lbl.text = t
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_TEXT)
	return lbl

func _make_step_btn(t: String) -> Button:
	var btn := Button.new()
	btn.text = t
	btn.custom_minimum_size = Vector2(30, 28)
	btn.focus_mode = Control.FOCUS_NONE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.14, 0.08, 1.0)
	s.border_color = C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("focus", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.30, 0.22, 0.10, 1.0)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", C_TITLE)
	btn.add_theme_font_size_override("font_size", 16)
	return btn

func _make_btn(t: String, border: Color) -> Button:
	var btn := Button.new()
	btn.text = t
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(border.r * 0.25, border.g * 0.25, border.b * 0.25, 1.0)
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left   = 8
	s.content_margin_top    = 5
	s.content_margin_right  = 8
	s.content_margin_bottom = 5
	for state in ["normal", "focus"]:
		btn.add_theme_stylebox_override(state, s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(border.r * 0.4, border.g * 0.4, border.b * 0.4, 1.0)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	return btn

func _populate_options() -> void:
	for race in CharacterData.RACES:
		_race_opt.add_item(race)
	for cls in CharacterData.CLASSES:
		_class_opt.add_item(cls)

	var race_idx := CharacterData.RACES.find(PlayerStats.race)
	if race_idx >= 0:
		_race_opt.select(race_idx)
	var cls_idx := CharacterData.CLASSES.find(PlayerStats.player_class)
	if cls_idx >= 0:
		_class_opt.select(cls_idx)

	_level_lbl.text = str(PlayerStats.level)

func _toggle_collapse() -> void:
	_collapsed = !_collapsed
	_body.visible = !_collapsed
	_toggle_btn.text = "+" if _collapsed else "−"

func _apply_race_class() -> void:
	PlayerStats.apply_character(
		CharacterData.RACES[_race_opt.selected],
		CharacterData.CLASSES[_class_opt.selected],
		PlayerStats.level)

func _change_level(delta: int) -> void:
	var new_lvl := clampi(PlayerStats.level + delta, 1, 99)
	if new_lvl == PlayerStats.level:
		return
	PlayerStats.apply_character(PlayerStats.race, PlayerStats.player_class, new_lvl)
	_level_lbl.text = str(PlayerStats.level)

func _full_heal() -> void:
	PlayerStats.set_hp(PlayerStats.max_hp)
	PlayerStats.set_mp(PlayerStats.max_mp)
	PlayerStats.set_stamina(PlayerStats.max_stamina)

func _trigger_death() -> void:
	PlayerStats.set_hp(0.0)

func _give_consumables() -> void:
	var bread := ItemData.new()
	bread.item_name = "Journeybread"
	bread.description = "Dense traveler's bread. Restores HP while resting."
	bread.type = ItemData.Type.CONSUMABLE
	bread.is_food = true
	bread.food_hp_regen = 4.0
	bread.food_duration = 180.0
	Inventory.add_item(bread, 5)

	var water := ItemData.new()
	water.item_name = "Waterskin"
	water.description = "Fresh water in a skin pouch. Restores MP while resting."
	water.type = ItemData.Type.CONSUMABLE
	water.is_drink = true
	water.food_mp_regen = 5.0
	water.food_duration = 180.0
	Inventory.add_item(water, 5)

	CombatLog.add_line("Received 5x Journeybread and 5x Waterskin.", CombatLog.MsgType.INFO)

func _add_test_quest() -> void:
	var ok := QuestManager.add_quest({
		"id": "test_q1",
		"name": "Slay the Infected Wolves",
		"description": "The wolves near the eastern road have grown diseased and aggressive. Thin their numbers before travelers are harmed.",
		"zone": "Eastern Road",
		"level_req": 1,
		"xp_reward": 250,
		"objectives": [
			{"text": "Slay Infected Wolves", "type": "kill", "target": "Wolf", "count_needed": 5},
			{"text": "Report back to Captain Aldren"},
		],
	})
	if ok:
		CombatLog.add_line("Quest added: Slay the Infected Wolves.", CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("Quest already in journal.", CombatLog.MsgType.INFO)

func _give_crafting_materials() -> void:
	var mats: Array[Dictionary] = [
		# Smelting / Blacksmithing / Weaponsmithing
		{p = "res://data/loot/items/copper_ore.tres",    qty = 10},
		{p = "res://data/loot/items/tin_ore.tres",       qty = 10},
		{p = "res://data/loot/items/iron_ore.tres",      qty = 10},
		{p = "res://data/loot/items/coal.tres",          qty = 20},
		{p = "res://data/loot/items/metal_bits.tres",    qty = 10},
		{p = "res://data/loot/items/smithing_hammer.tres", qty = 1},
		{p = "res://data/loot/items/pickaxe.tres",        qty = 1},
		# Tanning / Leatherworking
		{p = "res://data/loot/items/tattered_pelt.tres",       qty = 4},
		{p = "res://data/loot/items/damaged_wolf_pelt.tres",   qty = 4},
		{p = "res://data/loot/items/fresh_wolf_pelt.tres",     qty = 4},
		{p = "res://data/loot/items/sinew.tres",               qty = 8},
		{p = "res://data/loot/items/sewing_needle.tres",       qty = 1},
		# Tailoring
		{p = "res://data/loot/items/cloth_scraps.tres",  qty = 10},
		{p = "res://data/loot/items/flax.tres",          qty = 10},
		{p = "res://data/loot/items/linen_thread.tres",  qty = 6},
		# Alchemy
		{p = "res://data/loot/items/feverfew.tres",      qty = 6},
		{p = "res://data/loot/items/bloodmoss.tres",     qty = 6},
		{p = "res://data/loot/items/wormwood.tres",      qty = 6},
		{p = "res://data/loot/items/empty_vial.tres",    qty = 10},
		# Baking
		{p = "res://data/loot/items/flour.tres",         qty = 6},
		{p = "res://data/loot/items/water_flask.tres",   qty = 6},
		{p = "res://data/loot/items/wolf_meat.tres",     qty = 4},
		{p = "res://data/loot/items/raw_egg.tres",       qty = 4},
		# Brewing
		{p = "res://data/loot/items/barley.tres",        qty = 4},
		{p = "res://data/loot/items/hops.tres",          qty = 4},
		{p = "res://data/loot/items/yeast.tres",         qty = 4},
		{p = "res://data/loot/items/empty_bottle.tres",  qty = 4},
		# Fletching
		{p = "res://data/loot/items/hardwood_shaft.tres",  qty = 10},
		{p = "res://data/loot/items/flint.tres",           qty = 10},
		{p = "res://data/loot/items/feather.tres",         qty = 10},
		# Jewelry Crafting
		{p = "res://data/loot/items/silver_ore.tres",      qty = 6},
		{p = "res://data/loot/items/tarnished_silver_setting.tres", qty = 3},
		{p = "res://data/loot/items/rough_ruby.tres",      qty = 2},
		# Pottery
		{p = "res://data/loot/items/lump_of_clay.tres",    qty = 6},
	]
	var given := 0
	for entry in mats:
		var item := load(entry.p) as ItemData
		if item and Inventory.add_item(item, entry.qty):
			given += 1
	CombatLog.add_line("Crafting materials seeded (%d stacks)." % given, CombatLog.MsgType.INFO)

func _give_bow() -> void:
	var bow := ItemData.new()
	bow.item_name       = "Hunter's Shortbow"
	bow.description     = "A compact recurve bow, well-worn but reliable."
	bow.type            = ItemData.Type.WEAPON
	bow.rarity          = ItemData.Rarity.COMMON
	bow.is_ranged       = true
	bow.is_two_handed   = true
	bow.weapon_skill    = "archery"
	bow.weapon_damage_min = 6
	bow.weapon_damage_max = 14
	bow.weapon_delay    = 3.0
	if not Inventory.add_item(bow):
		CombatLog.add_line("No bag space for the bow.", CombatLog.MsgType.INFO)
		return
	CombatLog.add_line("Hunter's Shortbow added to inventory. Right-click to equip.", CombatLog.MsgType.INFO)

func _give_proc_weapon() -> void:
	var sword := ItemData.new()
	sword.item_name        = "Flamebrand"
	sword.description      = "A blade that occasionally erupts in searing flame on a successful strike."
	sword.type             = ItemData.Type.WEAPON
	sword.rarity           = ItemData.Rarity.UNCOMMON
	sword.weapon_skill     = "1h_slashing"
	sword.weapon_damage_min = 8
	sword.weapon_damage_max = 18
	sword.weapon_delay     = 2.5
	sword.proc_chance      = 0.15
	sword.proc_damage      = 25
	sword.proc_damage_type = SpellData.DamageType.FIRE
	sword.proc_name        = "Flaming Strike"
	if not Inventory.add_item(sword):
		CombatLog.add_line("No bag space for Flamebrand.", CombatLog.MsgType.INFO)
		return
	CombatLog.add_line("Flamebrand added to inventory. Right-click to equip.", CombatLog.MsgType.INFO)

func _give_bags() -> void:
	var names := ["Small Pouch", "Worn Satchel"]
	var sizes := [6, 10]
	var given := 0
	for i in names.size():
		var bag := ItemData.new()
		bag.item_name = names[i]
		bag.description = "A %s-slot bag." % sizes[i]
		bag.type = ItemData.Type.BAG
		bag.bag_num_slots = sizes[i]
		if Inventory.add_item(bag):
			given += 1
	if given > 0:
		CombatLog.add_line("Added %d bag(s) to inventory." % given, CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("No inventory space for bags.", CombatLog.MsgType.INFO)
