extends CanvasLayer

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

const NORMAL_MOBS := [
	{"name":"Bandit",   "level":3, "max_hp":60.0,  "base_damage":8,  "xp_reward":30, "move_speed":3.0, "aggro_range":8.0},
	{"name":"Wolf",     "level":2, "max_hp":45.0,  "base_damage":6,  "xp_reward":20, "move_speed":4.0, "aggro_range":10.0},
	{"name":"Skeleton", "level":4, "max_hp":55.0,  "base_damage":9,  "xp_reward":35, "move_speed":2.8, "aggro_range":7.0},
	{"name":"Gnoll",    "level":5, "max_hp":80.0,  "base_damage":12, "xp_reward":45, "move_speed":3.2, "aggro_range":9.0},
]

const ZONES := [
	{"name": "World (Test Room)",  "path": "res://scenes/world.tscn",         "entry": "default"},
	{"name": "Dungeon World",      "path": "res://scenes/dungeon_world.tscn", "entry": "default"},
]

const STAT_KEYS := ["strength", "dexterity", "agility", "intelligence", "wisdom", "constitution"]
const STAT_ABBR := ["STR", "DEX", "AGI", "INT", "WIS", "CON"]

const C_BG     := Color(0.10, 0.08, 0.06, 0.93)
const C_BORDER := Color(0.80, 0.60, 0.20, 1.00)
const C_TITLE  := Color(0.90, 0.75, 0.30, 1.00)
const C_TEXT   := Color(0.75, 0.70, 0.60, 1.00)
const C_DIE    := Color(0.70, 0.15, 0.15, 1.00)

var _race_opt: OptionButton
var _class_opt: OptionButton
var _level_lbl: Label
var _body: VBoxContainer
var _toggle_btn: Button
var _collapsed: bool = false

# Section containers
var _sec_character: VBoxContainer
var _sec_resources: VBoxContainer
var _sec_time: VBoxContainer
var _sec_zone: VBoxContainer
var _sec_enemy: VBoxContainer
var _sec_stats: VBoxContainer
var _sec_combat: VBoxContainer

# Time section
var _time_label: Label
var _time_slider: HSlider

# Enemy section
var _normal_mob_opt: OptionButton
var _named_mob_opt: OptionButton

# Stats section
var _stat_labels: Array[Label] = []

func _ready() -> void:
	layer = 10
	_build_ui()
	_populate_options()

func _process(_delta: float) -> void:
	if _collapsed or _time_label == null or not _sec_time.visible:
		return
	_time_label.text = "Current: " + TimeOfDay.get_time_string()

func _build_ui() -> void:
	var panel := DraggablePanel.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(240, 60)
	panel.size = Vector2(240, 480)
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
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
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

	# Body (collapsible) — wrapped in a ScrollContainer so the panel fits any screen size.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	_sec_character = _make_section("CHARACTER", true)
	_sec_resources = _make_section("RESOURCES", true)
	_sec_time      = _make_section("TIME & WORLD")
	_sec_zone      = _make_section("ZONE TRAVEL")
	_sec_enemy     = _make_section("ENEMY SPAWN")
	_sec_stats     = _make_section("STATS OVERRIDE")
	_sec_combat    = _make_section("COMBAT FLAGS")
	_build_character_section()
	_build_resources_section()
	_build_time_section()
	_build_zone_section()
	_build_enemy_section()
	_build_stats_section()
	_build_combat_section()

func _make_section(title: String, start_open: bool = false) -> VBoxContainer:
	var header_btn := Button.new()
	header_btn.text = ("▾ " if start_open else "▸ ") + title
	header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_btn.focus_mode = Control.FOCUS_NONE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.14, 0.11, 0.07, 1.0)
	s.border_color = C_TITLE
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 6; s.content_margin_top = 4
	s.content_margin_right = 6; s.content_margin_bottom = 4
	header_btn.add_theme_stylebox_override("normal", s)
	header_btn.add_theme_stylebox_override("focus", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.22, 0.17, 0.09, 1.0)
	header_btn.add_theme_stylebox_override("hover", h)
	header_btn.add_theme_stylebox_override("pressed", h)
	header_btn.add_theme_color_override("font_color", C_TITLE)
	header_btn.add_theme_font_size_override("font_size", 11)
	_body.add_child(header_btn)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.visible = start_open
	_body.add_child(content)

	header_btn.pressed.connect(func():
		content.visible = not content.visible
		header_btn.text = ("▾ " if content.visible else "▸ ") + title
	)
	return content

func _build_character_section() -> void:
	_sec_character.add_child(_make_label("Race"))
	_race_opt = OptionButton.new()
	_race_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_opt.focus_mode = Control.FOCUS_NONE
	_sec_character.add_child(_race_opt)

	_sec_character.add_child(_make_label("Class"))
	_class_opt = OptionButton.new()
	_class_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_opt.focus_mode = Control.FOCUS_NONE
	_sec_character.add_child(_class_opt)

	_sec_character.add_child(_make_label("Level"))
	var lvl_row := HBoxContainer.new()
	lvl_row.add_theme_constant_override("separation", 4)
	_sec_character.add_child(lvl_row)

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
	_sec_character.add_child(apply_btn)

func _build_resources_section() -> void:
	var heal_btn := _make_btn("Full Heal", Color(0.20, 0.55, 0.20, 1.0))
	heal_btn.pressed.connect(_full_heal)
	_sec_resources.add_child(heal_btn)

	var die_btn := _make_btn("Trigger Death", C_DIE)
	die_btn.pressed.connect(_trigger_death)
	_sec_resources.add_child(die_btn)

	var xp_btn := _make_btn("Grant 250 XP", Color(0.30, 0.45, 0.60, 1.0))
	xp_btn.pressed.connect(_grant_test_xp)
	_sec_resources.add_child(xp_btn)

	var level_btn := _make_btn("Level Up", Color(0.30, 0.55, 0.45, 1.0))
	level_btn.pressed.connect(_level_up_test)
	_sec_resources.add_child(level_btn)

	var copper_btn := _make_btn("Give 1,000 Copper", Color(0.55, 0.30, 0.15, 1.0))
	copper_btn.pressed.connect(_give_copper_hoard)
	_sec_resources.add_child(copper_btn)

	var purse_btn := _make_btn("Give 1p 5g 5s", Color(0.70, 0.65, 0.45, 1.0))
	purse_btn.pressed.connect(_give_mixed_purse)
	_sec_resources.add_child(purse_btn)

	var broke_btn := _make_btn("Clear Money", Color(0.40, 0.25, 0.25, 1.0))
	broke_btn.pressed.connect(_clear_money)
	_sec_resources.add_child(broke_btn)

	var bags_btn := _make_btn("Give Bags", Color(0.45, 0.35, 0.15, 1.0))
	bags_btn.pressed.connect(_give_bags)
	_sec_resources.add_child(bags_btn)

	var food_btn := _make_btn("Give Food & Drink", Color(0.35, 0.60, 0.20, 1.0))
	food_btn.pressed.connect(_give_consumables)
	_sec_resources.add_child(food_btn)

	var bow_btn := _make_btn("Give Bow", Color(0.55, 0.35, 0.10, 1.0))
	bow_btn.pressed.connect(_give_bow)
	_sec_resources.add_child(bow_btn)

	var proc_btn := _make_btn("Give Proc Weapon", Color(0.65, 0.25, 0.05, 1.0))
	proc_btn.pressed.connect(_give_proc_weapon)
	_sec_resources.add_child(proc_btn)

	var quest_btn := _make_btn("Add Test Quest", Color(0.60, 0.45, 0.10, 1.0))
	quest_btn.pressed.connect(_add_test_quest)
	_sec_resources.add_child(quest_btn)

	var quest_done_btn := _make_btn("Complete Test Quest", Color(0.50, 0.40, 0.15, 1.0))
	quest_done_btn.pressed.connect(_complete_test_quest)
	_sec_resources.add_child(quest_done_btn)

	var craft_btn := _make_btn("Give Crafting Materials", Color(0.20, 0.50, 0.65, 1.0))
	craft_btn.pressed.connect(_give_crafting_materials)
	_sec_resources.add_child(craft_btn)

func _build_time_section() -> void:
	_time_label = _make_label("Current: " + TimeOfDay.get_time_string())
	_sec_time.add_child(_time_label)

	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = 23.75
	_time_slider.step = 0.25
	_time_slider.value = float(TimeOfDay.get_hour())
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.value_changed.connect(_on_time_slider_changed)
	_sec_time.add_child(_time_slider)

	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 4)
	_sec_time.add_child(presets)
	for entry in [["Dawn", 6.0], ["Noon", 12.0], ["Dusk", 18.0], ["Night", 23.0]]:
		var b := _make_step_btn(entry[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_set_time.bind(entry[1]))
		presets.add_child(b)

	var pause_check := CheckButton.new()
	pause_check.text = "Pause Cycle"
	pause_check.focus_mode = Control.FOCUS_NONE
	pause_check.add_theme_color_override("font_color", C_TEXT)
	pause_check.toggled.connect(func(on: bool): TimeOfDay.paused = on)
	_sec_time.add_child(pause_check)

func _on_time_slider_changed(value: float) -> void:
	TimeOfDay.time_of_day = value / 24.0
	_time_label.text = "Current: " + TimeOfDay.get_time_string()

func _set_time(hour: float) -> void:
	TimeOfDay.time_of_day = hour / 24.0
	_time_slider.value = hour
	_time_label.text = "Current: " + TimeOfDay.get_time_string()

func _build_zone_section() -> void:
	var zone_opt := OptionButton.new()
	zone_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_opt.focus_mode = Control.FOCUS_NONE
	for z in ZONES:
		zone_opt.add_item(z["name"])
	_sec_zone.add_child(zone_opt)

	var teleport_btn := _make_btn("Teleport", Color(0.20, 0.45, 0.75, 1.0))
	teleport_btn.pressed.connect(func():
		if ZoneLoader._transitioning:
			return
		var z: Dictionary = ZONES[zone_opt.selected]
		ZoneLoader.travel_to(z["path"], z["entry"], z["name"])
	)
	_sec_zone.add_child(teleport_btn)

func _build_enemy_section() -> void:
	_sec_enemy.add_child(_make_label("Normal Mob"))
	_normal_mob_opt = OptionButton.new()
	_normal_mob_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_normal_mob_opt.focus_mode = Control.FOCUS_NONE
	for mob in NORMAL_MOBS:
		_normal_mob_opt.add_item(mob["name"])
	_sec_enemy.add_child(_normal_mob_opt)

	var spawn_normal_btn := _make_btn("Spawn Normal", Color(0.35, 0.55, 0.20, 1.0))
	spawn_normal_btn.pressed.connect(_spawn_normal_enemy)
	_sec_enemy.add_child(spawn_normal_btn)

	_sec_enemy.add_child(_make_label("Named Mob"))
	_named_mob_opt = OptionButton.new()
	_named_mob_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_named_mob_opt.focus_mode = Control.FOCUS_NONE
	_sec_enemy.add_child(_named_mob_opt)

	var spawn_named_btn := _make_btn("Spawn Named", Color(0.65, 0.45, 0.10, 1.0))
	spawn_named_btn.pressed.connect(_spawn_named_enemy)
	_sec_enemy.add_child(spawn_named_btn)

	_sec_enemy.add_child(HSeparator.new())

	var despawn_btn := _make_btn("Despawn All Enemies", C_DIE)
	despawn_btn.pressed.connect(_despawn_all_enemies)
	_sec_enemy.add_child(despawn_btn)

func _get_spawn_pos() -> Vector3:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		CombatLog.add_line("TestPanel: no player found for spawn position", CombatLog.MsgType.INFO)
		return Vector3.ZERO
	var p := players[0] as Node3D
	return p.global_position + (-p.transform.basis.z.normalized() * 3.0)

func _spawn_normal_enemy() -> void:
	var data: Dictionary = NORMAL_MOBS[_normal_mob_opt.selected]
	var e = ENEMY_SCENE.instantiate()
	e.mob_name    = data["name"]
	e.level       = data["level"]
	e.max_hp      = data["max_hp"]
	e.base_damage = data["base_damage"]
	e.xp_reward   = data["xp_reward"]
	e.move_speed  = data["move_speed"]
	e.aggro_range = data["aggro_range"]
	get_tree().current_scene.add_child(e)
	e.global_position = _get_spawn_pos()

func _spawn_named_enemy() -> void:
	var keys: Array = NamedMobDefinitions.ALL.keys()
	if keys.is_empty():
		return
	var e = ENEMY_SCENE.instantiate()
	get_tree().current_scene.add_child(e)
	e.global_position = _get_spawn_pos()
	e.apply_named(keys[_named_mob_opt.selected])

func _despawn_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func _build_stats_section() -> void:
	_stat_labels.clear()
	for i in STAT_KEYS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_sec_stats.add_child(row)

		var abbr := Label.new()
		abbr.text = STAT_ABBR[i]
		abbr.custom_minimum_size = Vector2(28, 0)
		abbr.add_theme_font_size_override("font_size", 11)
		abbr.add_theme_color_override("font_color", C_TEXT)
		row.add_child(abbr)

		var minus := _make_step_btn("−")
		minus.pressed.connect(_change_stat.bind(i, -1))
		row.add_child(minus)

		var val := Label.new()
		val.text = str(int(PlayerStats.get(STAT_KEYS[i])))
		val.add_theme_font_size_override("font_size", 13)
		val.add_theme_color_override("font_color", C_TITLE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(val)
		_stat_labels.append(val)

		var plus := _make_step_btn("+")
		plus.pressed.connect(_change_stat.bind(i, 1))
		row.add_child(plus)

	var reset_btn := _make_btn("Reset Stats", Color(0.50, 0.30, 0.15, 1.0))
	reset_btn.pressed.connect(_reset_stats)
	_sec_stats.add_child(reset_btn)

func _change_stat(idx: int, delta: int) -> void:
	var key: String = STAT_KEYS[idx]
	PlayerStats.set(key, clampi(int(PlayerStats.get(key)) + delta, 1, 255))
	_stat_labels[idx].text = str(int(PlayerStats.get(key)))
	PlayerStats.stats_changed.emit()

func _reset_stats() -> void:
	PlayerStats.apply_character(PlayerStats.race, PlayerStats.player_class, PlayerStats.level)
	for i in STAT_KEYS.size():
		_stat_labels[i].text = str(int(PlayerStats.get(STAT_KEYS[i])))

func _build_combat_section() -> void:
	var god_check := CheckButton.new()
	god_check.text = "God Mode"
	god_check.focus_mode = Control.FOCUS_NONE
	god_check.add_theme_color_override("font_color", C_TEXT)
	god_check.toggled.connect(func(on: bool): Combat.god_mode = on)
	_sec_combat.add_child(god_check)

	var cd_check := CheckButton.new()
	cd_check.text = "No Cooldowns"
	cd_check.focus_mode = Control.FOCUS_NONE
	cd_check.add_theme_color_override("font_color", C_TEXT)
	cd_check.toggled.connect(func(on: bool):
		Spells.no_cooldowns = on
		Skills.no_cooldowns = on
	)
	_sec_combat.add_child(cd_check)

	var clear_btn := _make_btn("Clear All Buffs", Color(0.60, 0.20, 0.50, 1.0))
	clear_btn.pressed.connect(func(): BuffManager.clear_all())
	_sec_combat.add_child(clear_btn)

	# Track 4 verification: take fixed damage on demand. Bypasses needing
	# a mob in range to validate that resource broadcasts reach peers.
	# Goes through Combat.receive_player_damage so the full damage path
	# fires (evasion, absorbs, armor reduction, NetCombatBroadcaster).
	var dmg_btn := _make_btn("Take 20 dmg", C_DIE)
	dmg_btn.pressed.connect(func(): Combat.receive_player_damage(20, null, "Test Panel"))
	_sec_combat.add_child(dmg_btn)

	# Track 4 sub-task 4 verification: simulate combat outcomes on the
	# current target. Requires a RemotePlayer target — for enemies these
	# buttons no-op (the standard combat path already fans visuals).
	var hit_btn := _make_btn("Hit Target (20)", Color(0.65, 0.25, 0.15, 1.0))
	hit_btn.pressed.connect(_on_test_hit_target)
	_sec_combat.add_child(hit_btn)

	var miss_btn := _make_btn("Miss Target", Color(0.55, 0.55, 0.20, 1.0))
	miss_btn.pressed.connect(_on_test_miss_target)
	_sec_combat.add_child(miss_btn)

	var evade_btn := _make_btn("Evade Target", Color(0.45, 0.45, 0.65, 1.0))
	evade_btn.pressed.connect(_on_test_evade_target)
	_sec_combat.add_child(evade_btn)

func _on_test_hit_target() -> void:
	var t = _resolve_peer_target()
	if t == null:
		return
	Net.broadcast_hit(t.char_id, 20, false, NetProtocol.DamageType.PHYSICAL)
	DamageNumbers.spawn_damage(t.global_position, 20, false)

func _on_test_miss_target() -> void:
	var t = _resolve_peer_target()
	if t == null:
		return
	Net.broadcast_miss(t.char_id)
	DamageNumbers.spawn_miss(t.global_position)

func _on_test_evade_target() -> void:
	var t = _resolve_peer_target()
	if t == null:
		return
	Net.broadcast_evade(t.char_id)
	DamageNumbers.spawn_miss(t.global_position)

# Group-check rather than `is RemotePlayer` to avoid any class_name lookup
# fragility, and tell the user why we no-op'd so a quiet failure doesn't
# look like a bug in the broadcast path.
func _resolve_peer_target():
	var t = Combat.current_target
	if t == null or not is_instance_valid(t):
		CombatLog.add_line("Test Panel: no target — left-click a remote player first.", CombatLog.MsgType.INFO)
		return null
	if not t.is_in_group("remote_players"):
		CombatLog.add_line("Test Panel: target is not a remote player.", CombatLog.MsgType.INFO)
		return null
	return t

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

	for key in NamedMobDefinitions.ALL.keys():
		_named_mob_opt.add_item(key)

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
	# Launcher: HP / MP / stamina are all server-authoritative. A client-only
	# set is overwritten by the next update — and for MP it won't unblock
	# casting, since the server gates mana independently (this bit us in
	# playtest: bars looked full while the server still rejected for
	# "insufficient mana"). Route through HealSelf, which the server treats as
	# a full dev restore (HP + MP + stamina) and fans the authoritative values
	# back. Always send — even at full HP — so a drained-mana top-off reaches
	# the server. The local sets below are optimistic for an instant bar fill.
	if Net.is_launcher_mode() and Net.is_app_ready():
		Net.broadcast_heal_self(maxi(int(PlayerStats.max_hp - PlayerStats.hp), 0))
	PlayerStats.set_hp(PlayerStats.max_hp)
	PlayerStats.set_mp(PlayerStats.max_mp)
	PlayerStats.set_stamina(PlayerStats.max_stamina)

func _trigger_death() -> void:
	PlayerStats.set_hp(0.0)

# Slice 0 test aid — push xp through the server's authoritative leveling path
# (the GrantQuestXp intent) so a tester can reach level 5+ quickly to verify the
# death penalty / de-level without grinding ~80 kills. Server applies + replies.
func _grant_test_xp() -> void:
	Net.grant_quest_xp(250)

# Grant exactly the xp needed to reach the next level (one level per click), so a
# tester can climb to a spell's min_level without hundreds of +250s. Curve-agnostic
# (it reads the live xp_to_next), and routes through the same server-authoritative
# GrantQuestXp path; the server's award_xp resolves the level-up and fans LevelUp back.
func _level_up_test() -> void:
	var needed: int = PlayerStats.xp_to_next - PlayerStats.xp
	if needed < 1:
		needed = 1
	Net.grant_quest_xp(needed)

# Dev coin grants. Launcher: coins are server-authoritative, so route through
# GiveCoins (PD_DEV_CMDS-gated) and do NOT fill locally — if the server
# silently ignores the grant, the wallet visibly not moving is the correct
# signal (the optimistic fill on Full Heal masked exactly this once).
# Raw copper on purpose: 1,000 coins = 20 weight, the encumbrance driver.
func _give_copper_hoard() -> void:
	_give_coins(0, 0, 0, 1000)

func _give_mixed_purse() -> void:
	_give_coins(1, 5, 5, 0)

# Negative grant; both the server handler and add_coin_stacks floor each
# stack at 0, so this empties the wallet regardless of holdings.
func _clear_money() -> void:
	const WIPE := -1_000_000_000
	_give_coins(WIPE, WIPE, WIPE, WIPE)

func _give_coins(p: int, g: int, s: int, c: int) -> void:
	if Net.is_launcher_mode() and Net.is_app_ready():
		Net.broadcast_give_coins(p, g, s, c)
		return
	PlayerStats.add_coin_stacks(p, g, s, c)

func _give_consumables() -> void:
	var bread := ItemData.new()
	bread.item_name = "Journeybread"
	bread.description = "Dense traveler's bread. Restores HP while resting."
	bread.type = ItemData.Type.CONSUMABLE
	bread.stack_size = 20
	bread.is_food = true
	bread.food_hp_regen = 4.0
	bread.food_duration = 180.0
	Inventory.add_item(bread, 5)

	var water := ItemData.new()
	water.item_name = "Waterskin"
	water.description = "Fresh water in a skin pouch. Restores MP while resting."
	water.type = ItemData.Type.CONSUMABLE
	water.stack_size = 20
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
		"reward_tier": "standard",
		"objectives": [
			{"text": "Slay Infected Wolves", "type": "kill", "target": "Wolf", "count_needed": 5},
			{"text": "Report back to Captain Aldren"},
		],
	})
	if ok:
		CombatLog.add_line("Quest added: Slay the Infected Wolves.", CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("Quest already in journal.", CombatLog.MsgType.INFO)

# The test quest's "report back" objective needs an NPC turn-in that doesn't
# exist, so it can't finish naturally. Force completion to verify the quest ->
# server GrantQuestXp -> XpGained grant path (and the xp feedback line).
func _complete_test_quest() -> void:
	QuestManager.complete_quest("test_q1")

func _give_crafting_materials() -> void:
	var mats: Array[Dictionary] = [
		# Smelting / Blacksmithing / Weaponsmithing
		{"p": "res://data/loot/items/copper_ore.tres",    "qty": 10},
		{"p": "res://data/loot/items/tin_ore.tres",       "qty": 10},
		{"p": "res://data/loot/items/iron_ore.tres",      "qty": 10},
		{"p": "res://data/loot/items/coal.tres",          "qty": 20},
		{"p": "res://data/loot/items/metal_bits.tres",    "qty": 10},
		{"p": "res://data/loot/items/smithing_hammer.tres", "qty": 1},
		{"p": "res://data/loot/items/pickaxe.tres",        "qty": 1},
		# Tanning / Leatherworking
		{"p": "res://data/loot/items/tattered_pelt.tres",       "qty": 4},
		{"p": "res://data/loot/items/damaged_wolf_pelt.tres",   "qty": 4},
		{"p": "res://data/loot/items/fresh_wolf_pelt.tres",     "qty": 4},
		{"p": "res://data/loot/items/sinew.tres",               "qty": 8},
		{"p": "res://data/loot/items/sewing_needle.tres",       "qty": 1},
		# Tailoring
		{"p": "res://data/loot/items/cloth_scraps.tres",  "qty": 10},
		{"p": "res://data/loot/items/flax.tres",          "qty": 10},
		{"p": "res://data/loot/items/linen_thread.tres",  "qty": 6},
		# Alchemy
		{"p": "res://data/loot/items/feverfew.tres",      "qty": 6},
		{"p": "res://data/loot/items/bloodmoss.tres",     "qty": 6},
		{"p": "res://data/loot/items/wormwood.tres",      "qty": 6},
		{"p": "res://data/loot/items/empty_vial.tres",    "qty": 10},
		# Baking
		{"p": "res://data/loot/items/flour.tres",         "qty": 6},
		{"p": "res://data/loot/items/water_flask.tres",   "qty": 6},
		{"p": "res://data/loot/items/wolf_meat.tres",     "qty": 4},
		{"p": "res://data/loot/items/raw_egg.tres",       "qty": 4},
		# Brewing
		{"p": "res://data/loot/items/barley.tres",        "qty": 4},
		{"p": "res://data/loot/items/hops.tres",          "qty": 4},
		{"p": "res://data/loot/items/yeast.tres",         "qty": 4},
		{"p": "res://data/loot/items/empty_bottle.tres",  "qty": 4},
		# Fletching
		{"p": "res://data/loot/items/hardwood_shaft.tres",  "qty": 10},
		{"p": "res://data/loot/items/flint.tres",           "qty": 10},
		{"p": "res://data/loot/items/feather.tres",         "qty": 10},
		# Jewelry Crafting
		{"p": "res://data/loot/items/silver_ore.tres",      "qty": 6},
		{"p": "res://data/loot/items/tarnished_silver_setting.tres", "qty": 3},
		{"p": "res://data/loot/items/rough_ruby.tres",      "qty": 2},
		# Pottery
		{"p": "res://data/loot/items/lump_of_clay.tres",    "qty": 6},
	]
	var given := 0
	var load_failed := 0
	var inv_full := 0
	for entry: Dictionary in mats:
		var path: String = entry.get("p", "")
		var qty: int = int(entry.get("qty", 1))
		var item: ItemData = load(path) as ItemData
		if item == null:
			DebugLog.warn("[TestPanel] Failed to load %s" % path)
			load_failed += 1
			continue
		if Inventory.add_item(item, qty):
			given += 1
		else:
			inv_full += 1
	var parts: PackedStringArray = ["%d stacks added" % given]
	if load_failed > 0: parts.append("%d failed to load" % load_failed)
	if inv_full > 0:    parts.append("%d skipped (no inventory space)" % inv_full)
	CombatLog.add_line("Crafting materials: " + ", ".join(parts) + ".", CombatLog.MsgType.INFO)

func _give_bow() -> void:
	# Track 6 sub-task 2 (fix): load from .tres so weapon.resource_path is
	# populated. The server's Attack handler looks up the path in
	# items.toml to read damage_min/max + is_ranged; without the path it
	# falls back to fists + melee range and the bow visually fires but
	# does no damage. Same applies to Flamebrand below. .duplicate() to
	# avoid sharing the disk-loaded singleton across inventory slots,
	# then re-attach resource_path so the server lookup still works.
	var src: ItemData = load("res://data/loot/items/hunters_shortbow.tres")
	if src == null:
		CombatLog.add_line("Failed to load Hunter's Shortbow.", CombatLog.MsgType.INFO)
		return
	var bow: ItemData = src.duplicate()
	bow.resource_path = src.resource_path
	if not Inventory.add_item(bow):
		CombatLog.add_line("No bag space for the bow.", CombatLog.MsgType.INFO)
		return
	CombatLog.add_line("Hunter's Shortbow added to inventory. Right-click to equip.", CombatLog.MsgType.INFO)

func _give_proc_weapon() -> void:
	var src: ItemData = load("res://data/loot/items/flamebrand.tres")
	if src == null:
		CombatLog.add_line("Failed to load Flamebrand.", CombatLog.MsgType.INFO)
		return
	var sword: ItemData = src.duplicate()
	sword.resource_path = src.resource_path
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
