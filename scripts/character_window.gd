extends DraggablePanel

@onready var class_value: Label = $MarginContainer/VBox/IdentityGrid/V_Class
@onready var race_value: Label = $MarginContainer/VBox/IdentityGrid/V_Race
@onready var level_value: Label = $MarginContainer/VBox/IdentityGrid/V_Level
@onready var xp_value: Label = $MarginContainer/VBox/IdentityGrid/V_XP
@onready var hp_value: Label = $MarginContainer/VBox/VitalsGrid/V_HP
@onready var mp_value: Label = $MarginContainer/VBox/VitalsGrid/V_MP
@onready var stamina_value: Label = $MarginContainer/VBox/VitalsGrid/V_ST
@onready var str_value: Label = $MarginContainer/VBox/AttribGrid/V_STR
@onready var dex_value: Label = $MarginContainer/VBox/AttribGrid/V_DEX
@onready var agi_value: Label = $MarginContainer/VBox/AttribGrid/V_AGI
@onready var int_value: Label = $MarginContainer/VBox/AttribGrid/V_INT
@onready var wis_value: Label = $MarginContainer/VBox/AttribGrid/V_WIS
@onready var cha_value: Label = $MarginContainer/VBox/AttribGrid/V_CHA
@onready var con_value: Label = $MarginContainer/VBox/AttribGrid/V_CON
@onready var xp_bar: ProgressBar = $MarginContainer/VBox/XPBar

func _ready() -> void:
	PlayerStats.hp_changed.connect(_on_hp_changed)
	PlayerStats.mp_changed.connect(_on_mp_changed)
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	PlayerStats.level_changed.connect(_on_level_changed)
	PlayerStats.xp_changed.connect(_on_xp_changed)
	_style_xp_bar()
	_refresh()

func _style_xp_bar() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.C_BAR_XP
	xp_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.C_BAR_BG
	xp_bar.add_theme_stylebox_override("background", bg)

func _refresh() -> void:
	class_value.text = PlayerStats.player_class if PlayerStats.player_class != "" else "—"
	race_value.text = PlayerStats.race if PlayerStats.race != "" else "—"
	level_value.text = str(PlayerStats.level)
	xp_value.text = "%d / %d" % [PlayerStats.xp, PlayerStats.xp_to_next]
	xp_bar.max_value = PlayerStats.xp_to_next
	xp_bar.value = PlayerStats.xp
	hp_value.text = "%d / %d" % [int(PlayerStats.hp), int(PlayerStats.max_hp)]
	mp_value.text = "%d / %d" % [int(PlayerStats.mp), int(PlayerStats.max_mp)]
	stamina_value.text = "%d / %d" % [int(PlayerStats.stamina), int(PlayerStats.max_stamina)]
	str_value.text = str(PlayerStats.strength)
	dex_value.text = str(PlayerStats.dexterity)
	agi_value.text = str(PlayerStats.agility)
	int_value.text = str(PlayerStats.intelligence)
	wis_value.text = str(PlayerStats.wisdom)
	cha_value.text = str(PlayerStats.charisma)
	con_value.text = str(PlayerStats.constitution)

func _on_hp_changed(current: float, maximum: float) -> void:
	hp_value.text = "%d / %d" % [int(current), int(maximum)]

func _on_mp_changed(current: float, maximum: float) -> void:
	mp_value.text = "%d / %d" % [int(current), int(maximum)]

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_value.text = "%d / %d" % [int(current), int(maximum)]

func _on_xp_changed(current_xp: int, next_xp: int) -> void:
	xp_value.text = "%d / %d" % [current_xp, next_xp]
	xp_bar.max_value = next_xp
	xp_bar.value = current_xp

func _on_level_changed(new_level: int) -> void:
	level_value.text = str(new_level)
	xp_value.text = "%d / %d" % [PlayerStats.xp, PlayerStats.xp_to_next]
	xp_bar.max_value = PlayerStats.xp_to_next
	xp_bar.value = PlayerStats.xp
