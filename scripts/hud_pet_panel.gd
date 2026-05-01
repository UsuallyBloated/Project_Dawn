extends Panel

var _name_label: Label = null
var _level_label: Label = null
var _hp_bar: ProgressBar = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(10.0, 120.0)
	size = Vector2(200.0, 56.0)
	visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.02, 0.80)
	style.border_color = Color(0.25, 0.45, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6; vbox.offset_top = 4
	vbox.offset_right = -6; vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_name_label.text = "Pet"
	hbox.add_child(_name_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_level_label.text = ""
	hbox.add_child(_level_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.custom_minimum_size = Vector2(0, 14)
	UITheme.style_bar(_hp_bar, UITheme.C_BAR_HP, false)
	vbox.add_child(_hp_bar)

	PetManager.pet_summoned.connect(_on_pet_summoned)
	PetManager.pet_dismissed.connect(func(): visible = false)
	PetManager.pet_died.connect(func(_p): visible = false)
	PetManager.pet_hp_changed.connect(_on_hp_changed)

func _on_pet_summoned(pet) -> void:
	if pet == null or not is_instance_valid(pet):
		return
	_name_label.text = pet.mob_name if pet is Enemy else pet.pet_name
	_level_label.text = " (Lv %d)" % pet.level
	_hp_bar.max_value = pet.max_hp
	_hp_bar.value = pet.hp
	visible = true

func _on_hp_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current

