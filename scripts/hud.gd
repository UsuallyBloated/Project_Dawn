extends CanvasLayer

const _OptionsScreenScript  := preload("res://scripts/options_screen.gd")
const _CraftingWindowScript := preload("res://scripts/crafting_window.gd")
const _VendorWindowScript   := preload("res://scripts/vendor_window.gd")
const _HudDeathScreen       := preload("res://scripts/hud_death_screen.gd")
const _HudCastBar           := preload("res://scripts/hud_cast_bar.gd")
const _HudBuffBar           := preload("res://scripts/hud_buff_bar.gd")
const _HudPetPanel          := preload("res://scripts/hud_pet_panel.gd")
const _HudGroupPanel        := preload("res://scripts/hud_group_panel.gd")
const _TrackWindowScript    := preload("res://scripts/track_window.gd")
const _SpellBookScript      := preload("res://scripts/spell_book.gd")
const _QuestJournalScript   := preload("res://scripts/quest_journal.gd")
const _DialogueWindowScript := preload("res://scripts/dialogue_window.gd")

@onready var health_bar: ProgressBar = $Panel/VBoxContainer/HPRow/HealthBar
@onready var stamina_bar: ProgressBar = $Panel/VBoxContainer/STARow/StaminaBar
@onready var mana_bar: ProgressBar = $Panel/VBoxContainer/MPRow/ManaBar
@onready var character_window: Panel = $CharacterWindow
@onready var inventory_window: Panel = $InventoryWindow
@onready var paperdoll_window: Panel = $PaperdollWindow
@onready var target_frame: Panel = $TargetFrame
@onready var target_name_label: Label = $TargetFrame/VBox/NameLabel
@onready var target_level_label: Label = $TargetFrame/VBox/LevelLabel
@onready var target_hp_bar: ProgressBar = $TargetFrame/VBox/HPBar

var _clock_label: Label = null
var _state_label: Label = null
var _command_input: LineEdit = null
var _hp_label: Label = null
var _mp_label: Label = null
var _sta_label: Label = null
var _xp_bar: ProgressBar = null
var _xp_label: Label = null
var _alignment_label: Label = null

var _window_stack: Array = []
var _tracked_target = null
var _player: Node3D = null
var _options_screen: Panel = null
var _crafting_window: Panel = null
var _vendor_window: Panel = null

var _group_panel = null
var _pet_panel = null
var _track_window: TrackWindow = null
var _spell_book: Panel = null
var _quest_journal: Panel = null
var _dialogue_window: Panel = null
var _target_hp_label: Label = null

var _tot_frame: DraggablePanel = null
var _tot_name_label: Label = null
var _tot_hp_bar: ProgressBar = null
var _tot_hp_label: Label = null

var _self_targeted: bool = false

func _ready() -> void:
	_style_panel()
	_hp_label  = UITheme.style_bar(health_bar,  UITheme.C_BAR_HP)
	_sta_label = UITheme.style_bar(stamina_bar, UITheme.C_BAR_STAMINA)
	_mp_label  = UITheme.style_bar(mana_bar,    UITheme.C_BAR_MANA)
	$Panel/VBoxContainer/HPRow/HPLabel.add_theme_color_override("font_color",  Color(0.95, 0.45, 0.45))
	$Panel/VBoxContainer/MPRow/MPLabel.add_theme_color_override("font_color",  Color(0.45, 0.60, 1.00))
	$Panel/VBoxContainer/STARow/STALabel.add_theme_color_override("font_color", Color(1.00, 0.92, 0.35))

	_target_hp_label = UITheme.style_bar(target_hp_bar, UITheme.C_BAR_HP)

	PlayerStats.hp_changed.connect(_on_hp_changed)
	PlayerStats.mp_changed.connect(_on_mp_changed)
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	Combat.target_changed.connect(_on_target_changed)
	target_frame.visible = false
	$Panel.gui_input.connect(_on_stat_panel_input)

	health_bar.max_value = PlayerStats.max_hp
	health_bar.value = PlayerStats.hp
	stamina_bar.max_value = PlayerStats.max_stamina
	stamina_bar.value = PlayerStats.stamina
	mana_bar.max_value = PlayerStats.max_mp
	mana_bar.value = PlayerStats.mp
	_hp_label.text  = "%d / %d" % [int(PlayerStats.hp),      int(PlayerStats.max_hp)]
	_mp_label.text  = "%d / %d" % [int(PlayerStats.mp),      int(PlayerStats.max_mp)]
	_sta_label.text = "%d / %d" % [int(PlayerStats.stamina), int(PlayerStats.max_stamina)]

	for w in [character_window, inventory_window, paperdoll_window]:
		w.visibility_changed.connect(_on_window_visibility_changed.bind(w))

	_build_xp_bar()
	_build_alignment_label()
	_build_clock()
	_build_state_label()
	_build_command_input()
	_build_options_screen()
	_build_crafting_window()
	_build_vendor_window()
	_build_components()
	_connect_player_state()
	Alignment.alignment_changed.connect(_on_alignment_changed)

func _build_components() -> void:
	var death_screen := _HudDeathScreen.new()
	add_child(death_screen)

	var cast_bar := _HudCastBar.new()
	add_child(cast_bar)

	var buff_bar := _HudBuffBar.new()
	add_child(buff_bar)

	_group_panel = _HudGroupPanel.new()
	add_child(_group_panel)

	_pet_panel = _HudPetPanel.new()
	add_child(_pet_panel)

	_track_window = _TrackWindowScript.new()
	add_child(_track_window)

	_spell_book = _SpellBookScript.new()
	_spell_book.visible = false
	add_child(_spell_book)
	_spell_book.visibility_changed.connect(_on_window_visibility_changed.bind(_spell_book))

	_quest_journal = _QuestJournalScript.new()
	_quest_journal.visible = false
	add_child(_quest_journal)
	_quest_journal.visibility_changed.connect(_on_window_visibility_changed.bind(_quest_journal))

	_dialogue_window = _DialogueWindowScript.new()
	_dialogue_window.visible = false
	add_child(_dialogue_window)

	_build_tot_frame()

	_group_panel.layout_changed.connect(_reposition_pet_panel)
	_reposition_pet_panel()

func _reposition_pet_panel() -> void:
	if _pet_panel == null or _group_panel == null:
		return
	_pet_panel.position.y = _group_panel.position.y + _group_panel.size.y + 8.0

func _build_tot_frame() -> void:
	var tot := DraggablePanel.new()
	_tot_frame = tot
	_tot_frame.visible = false

	add_child(_tot_frame)
	var vp := get_viewport().get_visible_rect().size
	_tot_frame.setup(Vector2(vp.x - 154.0, 4.0), Vector2(150.0, 34.0), Vector2(100.0, 28.0))
	tot.apply_style(Color(0.06, 0.05, 0.04, 0.88))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 1)
	vbox.offset_left = 4; vbox.offset_top = 2
	vbox.offset_right = -4; vbox.offset_bottom = -2
	_tot_frame.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 2)
	vbox.add_child(name_row)

	var arrow := Label.new()
	arrow.text = "▶"
	arrow.add_theme_font_size_override("font_size", 8)
	arrow.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(arrow)

	_tot_name_label = Label.new()
	_tot_name_label.add_theme_font_size_override("font_size", 10)
	_tot_name_label.add_theme_color_override("font_color", UITheme.C_TITLE)
	_tot_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tot_name_label.clip_text = true
	name_row.add_child(_tot_name_label)

	_tot_hp_bar = ProgressBar.new()
	_tot_hp_bar.custom_minimum_size = Vector2(0, 6)
	_tot_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tot_hp_bar.show_percentage = false
	_tot_hp_label = UITheme.style_bar(_tot_hp_bar, UITheme.C_BAR_HP)
	vbox.add_child(_tot_hp_bar)

# ── XP bar ────────────────────────────────────────────────────────────────────

func _build_xp_bar() -> void:
	$Panel.offset_top -= 22.0
	var vbox: VBoxContainer = $Panel/VBoxContainer

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = "XP"
	lbl.custom_minimum_size = Vector2(32, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 1.00))
	row.add_child(lbl)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 18)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.min_value = 0
	_xp_bar.max_value = PlayerStats.xp_to_next
	_xp_bar.value = PlayerStats.xp
	_xp_bar.show_percentage = false
	_xp_label = UITheme.style_bar(_xp_bar, Color(0.20, 0.55, 1.00))
	row.add_child(_xp_bar)

	_xp_label.text = "%d / %d" % [PlayerStats.xp, PlayerStats.xp_to_next]
	PlayerStats.xp_changed.connect(_on_xp_changed)

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = current_xp
	_xp_label.text = "%d / %d" % [current_xp, xp_to_next]

# ── Alignment label ───────────────────────────────────────────────────────────

func _build_alignment_label() -> void:
	_alignment_label = Label.new()
	_alignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alignment_label.add_theme_font_size_override("font_size", 11)
	_alignment_label.add_theme_color_override("font_color", _alignment_color(Alignment.alignment_tier))
	_alignment_label.text = Alignment.alignment_tier
	_alignment_label.custom_minimum_size = Vector2(0, 16)
	$Panel/VBoxContainer.add_child(_alignment_label)

func _on_alignment_changed(tier: String, _score: int) -> void:
	if _alignment_label == null:
		return
	_alignment_label.text = tier
	_alignment_label.add_theme_color_override("font_color", _alignment_color(tier))

func _alignment_color(tier: String) -> Color:
	match tier:
		"Exalted": return Color(1.00, 0.88, 0.20)
		"Good":    return Color(0.40, 0.85, 1.00)
		"Neutral": return Color(0.65, 0.65, 0.65)
		"Bad":     return Color(1.00, 0.55, 0.15)
		"Evil":    return Color(0.85, 0.15, 0.15)
	return Color(0.65, 0.65, 0.65)

# ── Utility windows ───────────────────────────────────────────────────────────

func _build_options_screen() -> void:
	_options_screen = _OptionsScreenScript.new()
	_options_screen.visible = false
	_options_screen.z_index = 20
	add_child(_options_screen)
	_options_screen.visibility_changed.connect(
		_on_window_visibility_changed.bind(_options_screen))

func _build_crafting_window() -> void:
	_crafting_window = _CraftingWindowScript.new()
	_crafting_window.visible = false
	_crafting_window.z_index = 20
	add_child(_crafting_window)
	_crafting_window.visibility_changed.connect(
		_on_window_visibility_changed.bind(_crafting_window))
	Crafting.skill_level_changed.connect(func(skill: String, lvl: int) -> void:
		CombatLog.add_line(
			"Your %s skill has increased to %d!" % [skill, lvl],
			CombatLog.MsgType.INFO))

func _build_vendor_window() -> void:
	_vendor_window = _VendorWindowScript.new()
	_vendor_window.visible = false
	_vendor_window.z_index = 20
	add_child(_vendor_window)
	_vendor_window.visibility_changed.connect(
		_on_window_visibility_changed.bind(_vendor_window))
	VendorManager.vendor_opened.connect(func(vname: String, vtype: String) -> void:
		(_vendor_window as Node).call("open_for", vname, vtype))

# ── Clock ─────────────────────────────────────────────────────────────────────

func _build_clock() -> void:
	_clock_label = Label.new()
	_clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock_label.position = Vector2(-108.0, 8.0)
	_clock_label.size = Vector2(100.0, 24.0)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.add_theme_color_override("font_color", Color(0.90, 0.84, 0.58))
	_clock_label.add_theme_font_size_override("font_size", 14)
	_clock_label.text = TimeOfDay.get_time_string()
	add_child(_clock_label)

# ── State label & command input ───────────────────────────────────────────────

func _build_state_label() -> void:
	_state_label = Label.new()
	_state_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_state_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_state_label.position = Vector2(-100.0, -160.0)
	_state_label.size = Vector2(200.0, 24.0)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0))
	_state_label.add_theme_font_size_override("font_size", 13)
	_state_label.visible = false
	add_child(_state_label)

func _build_command_input() -> void:
	_command_input = LineEdit.new()
	_command_input.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_command_input.position = Vector2(-150.0, -60.0)
	_command_input.size = Vector2(300.0, 28.0)
	_command_input.placeholder_text = "Type a command..."
	_command_input.visible = false
	_command_input.text_submitted.connect(_on_command_submitted)
	_command_input.focus_exited.connect(func(): _command_input.visible = false)
	add_child(_command_input)

func _connect_player_state() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		await get_tree().process_frame
		players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_player = players[0]
	if _player.has_signal("state_changed"):
		_player.state_changed.connect(_on_player_state_changed)

# ── Process ───────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _clock_label != null:
		var t := TimeOfDay.get_time_string()
		if t != _clock_label.text:
			_clock_label.text = t

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _command_input != null and not _command_input.visible:
				_command_input.visible = true
				_command_input.text = ""
				_command_input.grab_focus()
				get_viewport().set_input_as_handled()
				return
		if _command_input != null and _command_input.visible:
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if _window_stack.size() > 0:
				_window_stack.back().visible = false
				get_viewport().set_input_as_handled()
			elif _options_screen != null:
				_options_screen.visible = !_options_screen.visible
				get_viewport().set_input_as_handled()
		elif event.is_action("target_self"):
			if _self_targeted:
				_clear_self_target()
			else:
				Combat.set_target(null)
				_show_self_target()
		elif event.is_action("toggle_character"):
			character_window.visible = !character_window.visible
		elif event.is_action("toggle_inventory"):
			inventory_window.visible = !inventory_window.visible
		elif event.is_action("toggle_paperdoll"):
			paperdoll_window.visible = !paperdoll_window.visible
		elif event.is_action("toggle_crafting"):
			_crafting_window.visible = !_crafting_window.visible
		elif event.is_action("toggle_spell_book"):
			if _spell_book != null:
				_spell_book.visible = !_spell_book.visible
		elif event.is_action("toggle_quest_journal"):
			if _quest_journal != null:
				_quest_journal.visible = !_quest_journal.visible
		elif event.is_action("interact"):
			if DialogueManager.nearby_npc != null:
				DialogueManager.open_nearby()
			elif VendorManager.nearby_vendor != null:
				VendorManager.open_nearby()
			elif StationManager.nearby_station != "":
				_crafting_window.visible = true
			elif _try_loot_nearby():
				pass
			elif not _try_mine_nearby():
				_try_skin_nearby()

func _try_loot_nearby() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	const LOOT_RANGE := 6.0
	for node in get_tree().get_nodes_in_group("loot_bags"):
		var bag := node as LootBag
		if bag == null or not is_instance_valid(bag):
			continue
		if bag.global_position.distance_to(player.global_position) <= LOOT_RANGE:
			Loot.show_window(bag)
			return true
	return false

func _try_mine_nearby() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	const MINE_RANGE := 3.0
	for node in get_tree().get_nodes_in_group("mining_nodes"):
		var mn := node as MiningNode
		if mn == null:
			continue
		if mn.global_position.distance_to(player.global_position) > MINE_RANGE:
			continue
		var msg := mn.try_mine()
		CombatLog.add_line(msg, CombatLog.MsgType.INFO)
		return true
	return false

func _try_skin_nearby() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	const SKIN_RANGE := 3.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_skinnable:
			continue
		if enemy.global_position.distance_to(player.global_position) > SKIN_RANGE:
			continue
		var msg := enemy.try_skin()
		CombatLog.add_line(msg, CombatLog.MsgType.INFO)
		return

func _on_window_visibility_changed(window: Panel) -> void:
	if window.visible:
		_window_stack.erase(window)
		_window_stack.append(window)
	else:
		_window_stack.erase(window)

# ── Styling helpers ───────────────────────────────────────────────────────────

func _style_panel() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.05, 0.03, 0.92)
	s.border_color = UITheme.C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	$Panel.add_theme_stylebox_override("panel", s)

# ── Stat bar callbacks ────────────────────────────────────────────────────────

func _on_hp_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	if _hp_label:
		_hp_label.text = "%d / %d" % [int(current), int(maximum)]
	if _tot_frame != null and _tot_frame.visible:
		_tot_hp_bar.max_value = maximum
		_tot_hp_bar.value = current
		if _tot_hp_label:
			_tot_hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_mp_changed(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	if _mp_label:
		_mp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	if _sta_label:
		_sta_label.text = "%d / %d" % [int(current), int(maximum)]

# ── Target frame ──────────────────────────────────────────────────────────────

func _on_stat_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _self_targeted:
			_clear_self_target()
		else:
			Combat.set_target(null)
			_show_self_target()

func _show_self_target() -> void:
	_self_targeted = true
	if is_instance_valid(_tracked_target):
		if _tracked_target.is_connected("hp_changed", _on_target_hp_changed):
			_tracked_target.hp_changed.disconnect(_on_target_hp_changed)
		if _tracked_target.is_connected("died", _on_target_enemy_died):
			_tracked_target.died.disconnect(_on_target_enemy_died)
	_tracked_target = null
	var pname := PlayerStats.player_name if PlayerStats.player_name != "" else "You"
	target_name_label.text = pname
	target_level_label.text = "Level %d" % PlayerStats.level
	target_hp_bar.max_value = PlayerStats.max_hp
	target_hp_bar.value = PlayerStats.hp
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(PlayerStats.hp), int(PlayerStats.max_hp)]
		_target_hp_label.visible = true
	target_frame.visible = true
	if not PlayerStats.is_connected("hp_changed", _on_self_target_hp_changed):
		PlayerStats.hp_changed.connect(_on_self_target_hp_changed)
	if _tot_frame != null:
		_tot_frame.visible = false

func _clear_self_target() -> void:
	_self_targeted = false
	if PlayerStats.is_connected("hp_changed", _on_self_target_hp_changed):
		PlayerStats.hp_changed.disconnect(_on_self_target_hp_changed)
	target_frame.visible = false
	if _target_hp_label:
		_target_hp_label.visible = false

func _on_self_target_hp_changed(current: float, maximum: float) -> void:
	target_hp_bar.max_value = maximum
	target_hp_bar.value = current
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_target_changed(enemy) -> void:
	if _self_targeted:
		_clear_self_target()
	if is_instance_valid(_tracked_target):
		if _tracked_target.is_connected("hp_changed", _on_target_hp_changed):
			_tracked_target.hp_changed.disconnect(_on_target_hp_changed)
		if _tracked_target.is_connected("died", _on_target_enemy_died):
			_tracked_target.died.disconnect(_on_target_enemy_died)
	_tracked_target = enemy
	if enemy == null or not is_instance_valid(enemy):
		target_frame.visible = false
		if _target_hp_label:
			_target_hp_label.visible = false
		if _tot_frame != null:
			_tot_frame.visible = false
		return
	target_frame.visible = true
	target_name_label.text = enemy.mob_name
	target_level_label.text = "Level %d" % enemy.level
	target_hp_bar.max_value = enemy.max_hp
	target_hp_bar.value = enemy.hp
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(enemy.hp), int(enemy.max_hp)]
		_target_hp_label.visible = true
	enemy.hp_changed.connect(_on_target_hp_changed)
	enemy.died.connect(_on_target_enemy_died)
	_refresh_tot()

func _on_target_hp_changed(current: float, maximum: float) -> void:
	target_hp_bar.max_value = maximum
	target_hp_bar.value = current
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_target_enemy_died(_enemy) -> void:
	_tracked_target = null
	target_frame.visible = false
	if _tot_frame != null:
		_tot_frame.visible = false

func _refresh_tot() -> void:
	if _tot_frame == null or _tracked_target == null:
		return
	var pname := PlayerStats.player_name if PlayerStats.player_name != "" else "You"
	_tot_name_label.text = pname
	_tot_hp_bar.max_value = PlayerStats.max_hp
	_tot_hp_bar.value = PlayerStats.hp
	if _tot_hp_label:
		_tot_hp_label.text = "%d / %d" % [int(PlayerStats.hp), int(PlayerStats.max_hp)]
	_tot_frame.visible = true

# ── Player state ──────────────────────────────────────────────────────────────

func _on_player_state_changed(new_state: int) -> void:
	if _state_label == null:
		return
	if new_state == PlayerCharacter.PlayerState.SITTING:
		_state_label.text = "Resting / Meditating"
		_state_label.visible = true
	else:
		_state_label.visible = false

# ── Command input ─────────────────────────────────────────────────────────────

func _on_command_submitted(text: String) -> void:
	_command_input.visible = false
	_command_input.text = ""
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	_handle_chat_input(trimmed)

func _handle_chat_input(text: String) -> void:
	var my_name := PlayerStats.player_name if PlayerStats.player_name != "" else "You"

	if not text.begins_with("/"):
		CombatLog.add_line("%s says, '%s'" % [my_name, text], CombatLog.MsgType.SAY)
		return

	var lower := text.to_lower()

	if lower == "/sit":
		if is_instance_valid(_player):
			_player.sit()
		return
	if lower == "/stand":
		if is_instance_valid(_player):
			_player.stand()
		return
	if lower == "/pet follow":
		PetManager.command_follow()
		return
	if lower == "/pet guard":
		PetManager.command_guard()
		return
	if lower == "/pet passive":
		PetManager.command_passive()
		return
	if lower == "/pet dismiss":
		PetManager.dismiss_pet()
		return

	for prefix in ["/say ", "/s "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("%s says, '%s'" % [my_name, msg], CombatLog.MsgType.SAY)
			return

	for prefix in ["/shout ", "/sh "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("%s shouts, '%s'" % [my_name, msg], CombatLog.MsgType.SHOUT)
			return

	if lower.begins_with("/ooc "):
		var msg := text.substr("/ooc ".length())
		CombatLog.add_line("[OOC] %s: %s" % [my_name, msg], CombatLog.MsgType.OOC)
		return

	for prefix in ["/tell ", "/t "]:
		if lower.begins_with(prefix):
			var rest := text.substr(prefix.length())
			var space_idx := rest.find(" ")
			if space_idx > 0:
				var target_name := rest.substr(0, space_idx)
				var msg := rest.substr(space_idx + 1)
				CombatLog.add_line("You -> %s: %s" % [target_name, msg], CombatLog.MsgType.TELL_OUT)
			else:
				CombatLog.add_line("Usage: /tell <name> <message>", CombatLog.MsgType.INFO)
			return

	for prefix in ["/g ", "/group "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("[Group] %s: %s" % [my_name, msg], CombatLog.MsgType.GROUP_CHAT)
			GroupManager.broadcast_group_chat(my_name, msg)
			return

	if lower == "/sense" or lower == "/sense heading":
		if is_instance_valid(_player):
			CombatLog.add_line(SenseHeading.query(_player.rotation.y), CombatLog.MsgType.INFO)
		return

	if lower == "/track":
		if _track_window != null:
			_track_window.toggle()
		return

	if lower == "/languages":
		var known: Array = []
		for lang in Languages.skills:
			if Languages.skills[lang] > 0:
				known.append(lang)
		if known.is_empty():
			CombatLog.add_line("You know no languages.", CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("Known languages:", CombatLog.MsgType.INFO)
			for lang in known:
				var active_marker := " (active)" if lang == Languages.active_language else ""
				CombatLog.add_line("  %s — %d%s" % [lang, Languages.skills[lang], active_marker], CombatLog.MsgType.INFO)
		return

	if lower.begins_with("/lang "):
		var lang_name := text.substr(6).strip_edges()
		if lang_name == "":
			CombatLog.add_line("Usage: /lang [language name]", CombatLog.MsgType.INFO)
		elif Languages.get_skill(lang_name) > 0:
			Languages.set_active_language(lang_name)
			CombatLog.add_line("You are now speaking %s." % lang_name, CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("You do not know the language '%s'." % lang_name, CombatLog.MsgType.INFO)
		return

	CombatLog.add_line("Unknown command: %s" % text, CombatLog.MsgType.INFO)
