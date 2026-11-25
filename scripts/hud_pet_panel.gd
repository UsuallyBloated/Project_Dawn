extends DraggablePanel

@onready var _name_label: Label = $VBox/NameRow/Name
@onready var _level_label: Label = $VBox/NameRow/Level
@onready var _hp_bar: ProgressBar = $VBox/HpBar
@onready var _commands_row: HBoxContainer = $VBox/Commands

# The frame is scenes/hud_pet_panel.tscn; this script fills the name, the
# level and the bar, and builds the command row.
func _ready() -> void:
	UITheme.style_bar(_hp_bar, UITheme.C_BAR_HP, false)

	# One row of the /pet commands (user ask 2026-10-07: "Buttons for attack,
	# guard, etc. would be terrific"). Each button is the chat command it
	# names, through the same PetManager call the command uses.
	var row := _commands_row
	var commands: Array = [
		["Attack", PetManager.command_attack],
		["Back", PetManager.command_back],
		["Guard", PetManager.command_guard],
		["Follow", PetManager.command_follow],
		["Sit", PetManager.command_passive],
	]
	for entry in commands:
		var btn := Button.new()
		btn.text = entry[0]
		btn.add_theme_font_size_override("font_size", 10)
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(entry[1])
		row.add_child(btn)

	PetManager.pet_summoned.connect(_on_pet_summoned)
	PetManager.pet_dismissed.connect(func(): visible = false)
	PetManager.pet_died.connect(func(_p): visible = false)
	PetManager.pet_hp_changed.connect(_on_hp_changed)

func _on_pet_summoned(pet) -> void:
	if pet == null or not is_instance_valid(pet):
		return
	_name_label.text = pet.pet_name
	_level_label.text = " (Lv %d)" % pet.level
	_hp_bar.max_value = pet.max_hp
	_hp_bar.value = pet.hp
	visible = true

func _on_hp_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current

