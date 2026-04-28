extends CanvasLayer

@onready var health_bar: ProgressBar = $Panel/VBoxContainer/HPRow/HealthBar
@onready var stamina_bar: ProgressBar = $Panel/VBoxContainer/STARow/StaminaBar
@onready var mana_bar: ProgressBar = $Panel/VBoxContainer/MPRow/ManaBar
@onready var character_window: Panel = $CharacterWindow
@onready var target_frame: Panel = $TargetFrame
@onready var target_name_label: Label = $TargetFrame/VBox/NameLabel
@onready var target_level_label: Label = $TargetFrame/VBox/LevelLabel
@onready var target_hp_bar: ProgressBar = $TargetFrame/VBox/HPBar

func _ready() -> void:
	_style_bar(health_bar, Color(0.80, 0.10, 0.10))
	_style_bar(stamina_bar, Color(0.85, 0.75, 0.00))
	_style_bar(mana_bar, Color(0.10, 0.30, 0.90))

	PlayerStats.hp_changed.connect(_on_hp_changed)
	PlayerStats.mp_changed.connect(_on_mp_changed)
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	Combat.target_changed.connect(_on_target_changed)
	target_frame.visible = false
	_style_bar(target_hp_bar, Color(0.80, 0.10, 0.10))

	health_bar.max_value = PlayerStats.max_hp
	health_bar.value = PlayerStats.hp
	stamina_bar.max_value = PlayerStats.max_stamina
	stamina_bar.value = PlayerStats.stamina
	mana_bar.max_value = PlayerStats.max_mp
	mana_bar.value = PlayerStats.mp

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			character_window.visible = !character_window.visible

func _style_bar(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.9)
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
