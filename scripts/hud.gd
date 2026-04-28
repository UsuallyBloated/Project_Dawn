extends CanvasLayer

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

var _window_stack: Array = []

func _ready() -> void:
	_style_bar(health_bar, UITheme.C_BAR_HP)
	_style_bar(stamina_bar, UITheme.C_BAR_STAMINA)
	_style_bar(mana_bar, UITheme.C_BAR_MANA)

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
	_style_bar(target_hp_bar, UITheme.C_BAR_HP)

	for w in [character_window, inventory_window, paperdoll_window]:
		w.visibility_changed.connect(_on_window_visibility_changed.bind(w))

	health_bar.max_value = PlayerStats.max_hp
	health_bar.value = PlayerStats.hp
	stamina_bar.max_value = PlayerStats.max_stamina
	stamina_bar.value = PlayerStats.stamina
	mana_bar.max_value = PlayerStats.max_mp
	mana_bar.value = PlayerStats.mp

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _window_stack.size() > 0:
				_window_stack.back().visible = false
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:
			character_window.visible = !character_window.visible
		elif event.keycode == KEY_I:
			inventory_window.visible = !inventory_window.visible
		elif event.keycode == KEY_P:
			paperdoll_window.visible = !paperdoll_window.visible

func _on_window_visibility_changed(window: Panel) -> void:
	if window.visible:
		_window_stack.erase(window)
		_window_stack.append(window)
	else:
		_window_stack.erase(window)

func _style_bar(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.C_BAR_BG
	bar.add_theme_stylebox_override("background", bg)

func _on_hp_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_mp_changed(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current

func _on_target_changed(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		target_frame.visible = false
		return
	target_frame.visible = true
	target_name_label.text = enemy.mob_name
	target_level_label.text = "Level %d" % enemy.level
	target_hp_bar.max_value = enemy.max_hp
	target_hp_bar.value = enemy.hp
	if not enemy.is_connected("hp_changed", _on_target_hp_changed):
		enemy.hp_changed.connect(_on_target_hp_changed)
	if not enemy.is_connected("died", _on_target_enemy_died):
		enemy.died.connect(_on_target_enemy_died)

func _on_target_hp_changed(current: float, maximum: float) -> void:
	target_hp_bar.max_value = maximum
	target_hp_bar.value = current

func _on_target_enemy_died(_enemy) -> void:
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
