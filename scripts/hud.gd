extends CanvasLayer

const _OptionsScreenScript   := preload("res://scripts/options_screen.gd")
const _CraftingWindowScript  := preload("res://scripts/crafting_window.gd")
const _VendorWindowScript    := preload("res://scripts/vendor_window.gd")

@onready var health_bar: ProgressBar = $Panel/VBoxContainer/HPRow/HealthBar
@onready var stamina_bar: ProgressBar = $Panel/VBoxContainer/STARow/StaminaBar
@onready var mana_bar: ProgressBar = $Panel/VBoxContainer/MPRow/ManaBar
@onready var character_window: Panel = $CharacterWindow
@onready var inventory_window: Panel = $InventoryWindow
@onready var paperdoll_window: Panel = $PaperdollWindow
var _death_overlay: ColorRect = null
var _death_label: Label = null
@onready var target_frame: Panel = $TargetFrame
@onready var target_name_label: Label = $TargetFrame/VBox/NameLabel
@onready var target_level_label: Label = $TargetFrame/VBox/LevelLabel
@onready var target_hp_bar: ProgressBar = $TargetFrame/VBox/HPBar

var _cast_bar_panel: Panel = null
var _cast_progress: ProgressBar = null
var _cast_label: Label = null
var _cast_time_total: float = 0.0
var _cast_time_elapsed: float = 0.0
var _is_casting: bool = false

var _clock_label: Label = null

var _state_label: Label = null
var _command_input: LineEdit = null

var _window_stack: Array = []
var _tracked_target = null
var _player: Node3D = null
var _options_screen: Panel = null
var _crafting_window: Panel = null
var _vendor_window: Panel = null

var _hp_label: Label = null
var _mp_label: Label = null
var _sta_label: Label = null
var _xp_bar: ProgressBar = null
var _xp_label: Label = null
var _alignment_label: Label = null

var _pet_frame: Panel = null
var _pet_name_label: Label = null
var _pet_level_label: Label = null
var _pet_hp_bar: ProgressBar = null

var _buff_bar: HBoxContainer = null
var _buff_timer_labels: Dictionary = {}

var _group_window: Panel = null
var _group_header_lbl: Label = null
var _group_members_vbox: VBoxContainer = null
var _group_action_btn: Button = null
var _group_leave_btn: Button = null
var _group_context_menu: PopupMenu = null
var _group_context_peer: int = 0
var _member_bars: Dictionary = {}

func _ready() -> void:
	_style_panel()
	_hp_label  = _style_bar(health_bar,  UITheme.C_BAR_HP)
	_sta_label = _style_bar(stamina_bar, UITheme.C_BAR_STAMINA)
	_mp_label  = _style_bar(mana_bar,    UITheme.C_BAR_MANA)
	$Panel/VBoxContainer/HPRow/HPLabel.add_theme_color_override("font_color",  Color(0.95, 0.45, 0.45))
	$Panel/VBoxContainer/MPRow/MPLabel.add_theme_color_override("font_color",  Color(0.45, 0.60, 1.00))
	$Panel/VBoxContainer/STARow/STALabel.add_theme_color_override("font_color", Color(1.00, 0.92, 0.35))

	_build_death_overlay()
	_build_cast_bar()
	Spells.casting_started.connect(_on_casting_started)
	Spells.casting_cancelled.connect(func(): _hide_cast_bar())
	Spells.spell_cast.connect(func(_sp): _hide_cast_bar())
	PlayerStats.hp_changed.connect(_on_hp_changed)
	PlayerDeath.player_died.connect(_on_player_died)
	PlayerDeath.player_respawned.connect(_on_player_respawned)
	PlayerStats.mp_changed.connect(_on_mp_changed)
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	Combat.target_changed.connect(_on_target_changed)
	target_frame.visible = false
	PetManager.pet_summoned.connect(_on_pet_summoned)
	PetManager.pet_dismissed.connect(_on_pet_dismissed)
	PetManager.pet_died.connect(func(_p): _on_pet_dismissed())
	PetManager.pet_hp_changed.connect(_on_pet_hp_changed)
	GroupManager.group_updated.connect(_on_group_updated)
	GroupManager.invite_received.connect(func(_id, _n): _on_group_updated(true))
	_style_bar(target_hp_bar, UITheme.C_BAR_HP)

	for w in [character_window, inventory_window, paperdoll_window]:
		w.visibility_changed.connect(_on_window_visibility_changed.bind(w))

	health_bar.max_value = PlayerStats.max_hp
	health_bar.value = PlayerStats.hp
	stamina_bar.max_value = PlayerStats.max_stamina
	stamina_bar.value = PlayerStats.stamina
	mana_bar.max_value = PlayerStats.max_mp
	mana_bar.value = PlayerStats.mp
	_hp_label.text  = "%d / %d" % [int(PlayerStats.hp),      int(PlayerStats.max_hp)]
	_mp_label.text  = "%d / %d" % [int(PlayerStats.mp),      int(PlayerStats.max_mp)]
	_sta_label.text = "%d / %d" % [int(PlayerStats.stamina), int(PlayerStats.max_stamina)]

	_build_clock()
	_build_state_label()
	_build_command_input()
	_build_group_window()
	_build_pet_frame()
	_reposition_pet_frame()
	_build_buff_bar()
	_build_xp_bar()
	_build_alignment_label()
	_build_options_screen()
	_build_crafting_window()
	_build_vendor_window()
	_connect_player_state()
	PlayerStats.alignment_changed.connect(_on_alignment_changed)

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
	_xp_label = _style_bar(_xp_bar, Color(0.20, 0.55, 1.00))
	row.add_child(_xp_bar)

	_xp_label.text = "%d / %d" % [PlayerStats.xp, PlayerStats.xp_to_next]
	PlayerStats.xp_changed.connect(_on_xp_changed)

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = current_xp
	_xp_label.text = "%d / %d" % [current_xp, xp_to_next]

func _build_alignment_label() -> void:
	_alignment_label = Label.new()
	_alignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alignment_label.add_theme_font_size_override("font_size", 11)
	_alignment_label.add_theme_color_override("font_color", _alignment_color(PlayerStats.alignment_tier))
	_alignment_label.text = PlayerStats.alignment_tier
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
		elif event.is_action("toggle_character"):
			character_window.visible = !character_window.visible
		elif event.is_action("toggle_inventory"):
			inventory_window.visible = !inventory_window.visible
		elif event.is_action("toggle_paperdoll"):
			paperdoll_window.visible = !paperdoll_window.visible
		elif event.is_action("toggle_crafting"):
			_crafting_window.visible = !_crafting_window.visible
		elif event.is_action("interact"):
			if VendorManager.nearby_vendor != null:
				VendorManager.open_nearby()

func _on_window_visibility_changed(window: Panel) -> void:
	if window.visible:
		_window_stack.erase(window)
		_window_stack.append(window)
	else:
		_window_stack.erase(window)

func _style_panel() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.05, 0.03, 0.92)
	s.border_color = UITheme.C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	$Panel.add_theme_stylebox_override("panel", s)

func _style_bar(bar: ProgressBar, color: Color) -> Label:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.C_BAR_BG
	bg.set_corner_radius_all(4)
	bg.border_color = Color(0.25, 0.18, 0.06, 0.85)
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(lbl)
	return lbl

func _on_hp_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	if _hp_label:
		_hp_label.text = "%d / %d" % [int(current), int(maximum)]

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

func _on_target_changed(enemy) -> void:
	if is_instance_valid(_tracked_target):
		if _tracked_target.is_connected("hp_changed", _on_target_hp_changed):
			_tracked_target.hp_changed.disconnect(_on_target_hp_changed)
		if _tracked_target.is_connected("died", _on_target_enemy_died):
			_tracked_target.died.disconnect(_on_target_enemy_died)
	_tracked_target = enemy
	if enemy == null or not is_instance_valid(enemy):
		target_frame.visible = false
		return
	target_frame.visible = true
	target_name_label.text = enemy.mob_name
	target_level_label.text = "Level %d" % enemy.level
	target_hp_bar.max_value = enemy.max_hp
	target_hp_bar.value = enemy.hp
	enemy.hp_changed.connect(_on_target_hp_changed)
	enemy.died.connect(_on_target_enemy_died)

func _on_target_hp_changed(current: float, maximum: float) -> void:
	target_hp_bar.max_value = maximum
	target_hp_bar.value = current

func _on_target_enemy_died(_enemy) -> void:
	_tracked_target = null
	target_frame.visible = false

func _build_death_overlay() -> void:
	_death_overlay = ColorRect.new()
	_death_overlay.color = Color(0.4, 0.0, 0.0, 0.55)
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.visible = false
	add_child(_death_overlay)

	_death_label = Label.new()
	_death_label.text = "YOU HAVE DIED\nRespawning..."
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_label.add_theme_font_size_override("font_size", 36)
	_death_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.20))
	_death_overlay.add_child(_death_label)

func _on_player_died() -> void:
	_death_overlay.visible = true

func _on_player_respawned() -> void:
	_death_overlay.visible = false

func _build_cast_bar() -> void:
	_cast_bar_panel = Panel.new()
	_cast_bar_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cast_bar_panel.position = Vector2(-150.0, -120.0)
	_cast_bar_panel.size = Vector2(300.0, 48.0)
	_cast_bar_panel.visible = false
	add_child(_cast_bar_panel)

	_cast_label = Label.new()
	_cast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_label.add_theme_font_size_override("font_size", 12)
	_cast_bar_panel.add_child(_cast_label)

	_cast_progress = ProgressBar.new()
	_cast_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cast_progress.min_value = 0.0
	_cast_progress.max_value = 1.0
	_cast_progress.value = 0.0
	_cast_progress.show_percentage = false
	_cast_bar_panel.add_child(_cast_progress)

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

	CombatLog.add_line("Unknown command: %s" % text, CombatLog.MsgType.INFO)

func _on_player_state_changed(new_state: int) -> void:
	if _state_label == null:
		return
	if new_state == PlayerCharacter.PlayerState.SITTING:
		_state_label.text = "Resting / Meditating"
		_state_label.visible = true
	else:
		_state_label.visible = false

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

func _build_pet_frame() -> void:
	_pet_frame = Panel.new()
	_pet_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pet_frame.position = Vector2(10.0, 120.0)
	_pet_frame.size = Vector2(200.0, 56.0)
	_pet_frame.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.02, 0.80)
	style.border_color = Color(0.25, 0.45, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	_pet_frame.add_theme_stylebox_override("panel", style)
	add_child(_pet_frame)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 6
	vbox.offset_top    = 4
	vbox.offset_right  = -6
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	_pet_frame.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	_pet_name_label = Label.new()
	_pet_name_label.add_theme_font_size_override("font_size", 12)
	_pet_name_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_pet_name_label.text = "Pet"
	hbox.add_child(_pet_name_label)

	_pet_level_label = Label.new()
	_pet_level_label.add_theme_font_size_override("font_size", 11)
	_pet_level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_pet_level_label.text = ""
	hbox.add_child(_pet_level_label)

	_pet_hp_bar = ProgressBar.new()
	_pet_hp_bar.show_percentage = false
	_pet_hp_bar.min_value = 0.0
	_pet_hp_bar.max_value = 100.0
	_pet_hp_bar.value = 100.0
	_pet_hp_bar.custom_minimum_size = Vector2(0, 14)
	_style_bar(_pet_hp_bar, UITheme.C_BAR_HP)
	vbox.add_child(_pet_hp_bar)

func _on_pet_summoned(pet) -> void:
	if pet == null or not is_instance_valid(pet):
		return
	_pet_name_label.text  = pet.mob_name if pet is Enemy else pet.pet_name
	_pet_level_label.text = " (Lv %d)" % pet.level
	_pet_hp_bar.max_value = pet.max_hp
	_pet_hp_bar.value     = pet.hp
	_pet_frame.visible = true

func _on_pet_dismissed() -> void:
	_pet_frame.visible = false

func _on_pet_hp_changed(current: float, maximum: float) -> void:
	_pet_hp_bar.max_value = maximum
	_pet_hp_bar.value = current

func _on_casting_started(spell: SpellData) -> void:
	_cast_time_total = spell.cast_time
	_cast_time_elapsed = 0.0
	_is_casting = true
	_cast_label.text = spell.spell_name
	_cast_progress.value = 0.0
	_cast_bar_panel.visible = true

func _hide_cast_bar() -> void:
	_is_casting = false
	_cast_bar_panel.visible = false

func _process(delta: float) -> void:
	if _is_casting and _cast_time_total > 0.0:
		_cast_time_elapsed = minf(_cast_time_elapsed + delta, _cast_time_total)
		_cast_progress.value = _cast_time_elapsed / _cast_time_total
	if _clock_label != null:
		var t := TimeOfDay.get_time_string()
		if t != _clock_label.text:
			_clock_label.text = t
	_update_buff_timers()

# ── Buff bar ──────────────────────────────────────────────────────────────────

func _build_buff_bar() -> void:
	_buff_bar = HBoxContainer.new()
	_buff_bar.anchor_left   = 0.0
	_buff_bar.anchor_top    = 1.0
	_buff_bar.anchor_right  = 0.0
	_buff_bar.anchor_bottom = 1.0
	_buff_bar.position = Vector2(10.0, -152.0)
	_buff_bar.add_theme_constant_override("separation", 4)
	add_child(_buff_bar)
	BuffManager.buffs_changed.connect(_on_buffs_changed)
	_on_buffs_changed()

func _on_buffs_changed() -> void:
	_buff_timer_labels.clear()
	for child in _buff_bar.get_children():
		child.queue_free()
	for h in BuffManager.get_hots():
		_buff_timer_labels["hot:%s" % h.spell_name] = _add_buff_icon("hot", h.spell_name)
	if BuffManager.get_absorb_hp() > 0.0:
		_buff_timer_labels["absorb"] = _add_buff_icon("absorb", "Shield")
	if BuffManager.get_evade_remaining() > 0.0:
		_buff_timer_labels["evade"] = _add_buff_icon("evade", "Evade")
	var food := BuffManager.get_food_buff()
	if not food.is_empty():
		_buff_timer_labels["food"] = _add_buff_icon("food", food.get("buff_name", "Food"))
	var drink := BuffManager.get_drink_buff()
	if not drink.is_empty():
		_buff_timer_labels["drink"] = _add_buff_icon("drink", drink.get("buff_name", "Drink"))

func _add_buff_icon(type: String, spell_name: String) -> Label:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	match type:
		"hot":    style.border_color = Color(0.25, 0.65, 0.25)
		"absorb": style.border_color = Color(0.30, 0.50, 0.90)
		"evade":  style.border_color = Color(0.80, 0.70, 0.20)
		"food":   style.border_color = Color(0.75, 0.45, 0.15)
		"drink":  style.border_color = Color(0.20, 0.55, 0.80)
		_:        style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	icon.add_theme_stylebox_override("panel", style)
	_buff_bar.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 2; vbox.offset_top = 2
	vbox.offset_right = -2; vbox.offset_bottom = -2
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = spell_name.left(7)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var timer_lbl := Label.new()
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.add_theme_font_size_override("font_size", 10)
	timer_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(timer_lbl)
	return timer_lbl

func _update_buff_timers() -> void:
	for key in _buff_timer_labels:
		var lbl: Label = _buff_timer_labels[key]
		if key == "absorb":
			lbl.text = "%dhp" % int(BuffManager.get_absorb_hp())
		elif key == "evade":
			lbl.text = "%ds" % ceili(BuffManager.get_evade_remaining())
		elif key == "food":
			var f := BuffManager.get_food_buff()
			if not f.is_empty():
				lbl.text = "%ds" % ceili(f.remaining)
		elif key == "drink":
			var d := BuffManager.get_drink_buff()
			if not d.is_empty():
				lbl.text = "%ds" % ceili(d.remaining)
		elif key.begins_with("hot:"):
			var sname := key.substr(4)
			for h in BuffManager.get_hots():
				if h.spell_name == sname:
					lbl.text = "%ds" % ceili(h.remaining)
					break

# ── Group window ──────────────────────────────────────────────────────────────

func _build_group_window() -> void:
	_group_window = Panel.new()
	_group_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_group_window.position = Vector2(10.0, 10.0)
	_group_window.size = Vector2(220.0, 60.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.06, 0.88)
	style.border_color = Color(0.35, 0.25, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	_group_window.add_theme_stylebox_override("panel", style)
	add_child(_group_window)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6; vbox.offset_top = 4
	vbox.offset_right = -6; vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 3)
	_group_window.add_child(vbox)

	_group_header_lbl = Label.new()
	_group_header_lbl.text = "GROUP"
	_group_header_lbl.add_theme_font_size_override("font_size", 11)
	_group_header_lbl.add_theme_color_override("font_color", Color(0.75, 0.60, 1.0))
	_group_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_group_header_lbl)

	_group_members_vbox = VBoxContainer.new()
	_group_members_vbox.add_theme_constant_override("separation", 2)
	_group_members_vbox.visible = false
	vbox.add_child(_group_members_vbox)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_hbox)

	_group_action_btn = Button.new()
	_group_action_btn.text = "Invite"
	_group_action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_group_action_btn.add_theme_font_size_override("font_size", 11)
	_group_action_btn.pressed.connect(_on_group_action_pressed)
	btn_hbox.add_child(_group_action_btn)

	_group_leave_btn = Button.new()
	_group_leave_btn.text = "Leave"
	_group_leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_group_leave_btn.add_theme_font_size_override("font_size", 11)
	_group_leave_btn.visible = false
	_group_leave_btn.pressed.connect(GroupManager.leave_group)
	btn_hbox.add_child(_group_leave_btn)

	_group_context_menu = PopupMenu.new()
	_group_context_menu.add_item("Pass Leadership", 0)
	_group_context_menu.id_pressed.connect(_on_group_context_id_pressed)
	add_child(_group_context_menu)

func _on_group_updated(membership_changed: bool) -> void:
	if membership_changed:
		_refresh_group_ui()
	else:
		_update_member_bars()

func _refresh_group_ui() -> void:
	_member_bars.clear()
	for child in _group_members_vbox.get_children():
		child.queue_free()

	if GroupManager.in_group:
		_group_members_vbox.visible = true
		for member in GroupManager.members:
			var pid: int = member.get("peer_id", 0)
			var row_data := _build_member_row(member)
			_group_members_vbox.add_child(row_data.panel)
			_member_bars[pid] = {"hp": row_data.hp_bar, "mp": row_data.mp_bar, "sta": row_data.sta_bar}
		var show_invite := GroupManager.is_leader and GroupManager.members.size() < GroupManager.MAX_SIZE
		_group_action_btn.visible = show_invite
		_group_action_btn.text = "Invite"
		_group_leave_btn.visible = true
		_group_header_lbl.text = "GROUP (Leader)" if GroupManager.is_leader else "GROUP"
		_group_window.size.y = 60.0 + GroupManager.members.size() * 54.0
	else:
		_group_members_vbox.visible = false
		_group_leave_btn.visible = false
		_group_action_btn.visible = true
		if GroupManager.pending_invite_from != 0:
			_group_action_btn.text = "Follow"
			_group_header_lbl.text = "GROUP (Invited)"
		else:
			_group_action_btn.text = "Invite"
			_group_header_lbl.text = "GROUP"
		_group_window.size.y = 60.0

	_reposition_pet_frame()

func _update_member_bars() -> void:
	for member in GroupManager.members:
		var pid: int = member.get("peer_id", 0)
		if not _member_bars.has(pid):
			continue
		var bars: Dictionary = _member_bars[pid]
		bars.hp.max_value  = maxf(member.get("max_hp",  100.0), 1.0)
		bars.hp.value      = member.get("hp",  0.0)
		bars.mp.max_value  = maxf(member.get("max_mp",  100.0), 1.0)
		bars.mp.value      = member.get("mp",  0.0)
		bars.sta.max_value = maxf(member.get("max_sta", 100.0), 1.0)
		bars.sta.value     = member.get("sta", 0.0)

func _build_member_row(member: Dictionary) -> Dictionary:
	var peer_id: int = member.get("peer_id", 0)
	var my_id := multiplayer.get_unique_id()
	var is_me := peer_id == my_id
	var is_mem_leader := peer_id == GroupManager.leader_peer_id

	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 50)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.06, 0.12, 0.70) if is_me else Color(0.05, 0.04, 0.08, 0.50)
	row_style.border_color = UITheme.C_GOLDEN_BORDER if is_mem_leader else Color(0.20, 0.15, 0.30)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(2)
	row.add_theme_stylebox_override("panel", row_style)

	if GroupManager.is_leader and not is_me:
		row.gui_input.connect(_on_member_row_input.bind(peer_id))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4; vbox.offset_top = 3
	vbox.offset_right = -4; vbox.offset_bottom = -3
	vbox.add_theme_constant_override("separation", 2)
	row.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = member.get("name", "???")
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", UITheme.C_TITLE if is_mem_leader else Color(0.90, 0.90, 0.90))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_row.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "Lv %d" % member.get("level", 1)
	lv_lbl.add_theme_font_size_override("font_size", 10)
	lv_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	name_row.add_child(lv_lbl)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0.0
	hp_bar.max_value = maxf(member.get("max_hp", 100.0), 1.0)
	hp_bar.value = member.get("hp", 100.0)
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 10)
	_style_bar(hp_bar, UITheme.C_BAR_HP)
	vbox.add_child(hp_bar)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 2)
	vbox.add_child(bar_row)

	var mp_bar := ProgressBar.new()
	mp_bar.min_value = 0.0
	mp_bar.max_value = maxf(member.get("max_mp", 100.0), 1.0)
	mp_bar.value = member.get("mp", 100.0)
	mp_bar.show_percentage = false
	mp_bar.custom_minimum_size = Vector2(0, 10)
	mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_bar(mp_bar, UITheme.C_BAR_MANA)
	bar_row.add_child(mp_bar)

	var sta_bar := ProgressBar.new()
	sta_bar.min_value = 0.0
	sta_bar.max_value = maxf(member.get("max_sta", 100.0), 1.0)
	sta_bar.value = member.get("sta", 100.0)
	sta_bar.show_percentage = false
	sta_bar.custom_minimum_size = Vector2(0, 10)
	sta_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_bar(sta_bar, UITheme.C_BAR_STAMINA)
	bar_row.add_child(sta_bar)

	return {"panel": row, "hp_bar": hp_bar, "mp_bar": mp_bar, "sta_bar": sta_bar}

func _reposition_pet_frame() -> void:
	if _pet_frame == null or _group_window == null:
		return
	_pet_frame.position.y = _group_window.position.y + _group_window.size.y + 8.0

func _on_group_action_pressed() -> void:
	if GroupManager.pending_invite_from != 0:
		GroupManager.accept_invite()
	else:
		_invite_current_target()

func _invite_current_target() -> void:
	var target = Combat.current_target
	if not is_instance_valid(target):
		return
	if not target.is_in_group("players"):
		return
	var peer_id: int = target.get_meta("peer_id", 0)
	if peer_id == 0:
		return
	GroupManager.invite_player(peer_id)

func _on_member_row_input(event: InputEvent, peer_id: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_group_context_peer = peer_id
		_group_context_menu.popup(Rect2(get_viewport().get_mouse_position(), Vector2.ZERO))

func _on_group_context_id_pressed(id: int) -> void:
	if id == 0:
		GroupManager.pass_leadership(_group_context_peer)
