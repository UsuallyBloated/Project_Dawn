extends CanvasLayer

@onready var health_bar: ProgressBar = $Panel/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $Panel/VBoxContainer/StaminaBar
@onready var mana_bar: ProgressBar = $Panel/VBoxContainer/ManaBar

func _ready() -> void:
	_style_bar(health_bar, Color(0.80, 0.10, 0.10))
	_style_bar(stamina_bar, Color(0.85, 0.75, 0.00))
	_style_bar(mana_bar, Color(0.10, 0.30, 0.90))

func _style_bar(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	bar.add_theme_stylebox_override("background", bg)

func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func set_stamina(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current

func set_mana(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
