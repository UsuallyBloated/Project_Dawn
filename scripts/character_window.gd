extends DraggablePanel

@onready var class_value: Label = $MarginContainer/VBox/IdentityGrid/V_Class
@onready var race_value: Label = $MarginContainer/VBox/IdentityGrid/V_Race
@onready var level_value: Label = $MarginContainer/VBox/IdentityGrid/V_Level
@onready var xp_value: Label = $MarginContainer/VBox/IdentityGrid/V_XP
@onready var hp_value: Label = $MarginContainer/VBox/VitalsGrid/V_HP
@onready var mp_value: Label = $MarginContainer/VBox/VitalsGrid/V_MP
@onready var stamina_value: Label = $MarginContainer/VBox/VitalsGrid/V_ST
@onready var ac_value: Label = $MarginContainer/VBox/VitalsGrid/V_AC
@onready var str_value: Label = $MarginContainer/VBox/AttribGrid/V_STR
@onready var dex_value: Label = $MarginContainer/VBox/AttribGrid/V_DEX
@onready var agi_value: Label = $MarginContainer/VBox/AttribGrid/V_AGI
@onready var int_value: Label = $MarginContainer/VBox/AttribGrid/V_INT
@onready var wis_value: Label = $MarginContainer/VBox/AttribGrid/V_WIS
@onready var cha_value: Label = $MarginContainer/VBox/AttribGrid/V_CHA
@onready var con_value: Label = $MarginContainer/VBox/AttribGrid/V_CON
@onready var xp_bar: ProgressBar = $MarginContainer/VBox/XPBar

@onready var _l_hp: Label = $MarginContainer/VBox/VitalsGrid/L_HP
@onready var _l_mp: Label = $MarginContainer/VBox/VitalsGrid/L_MP
@onready var _l_st: Label = $MarginContainer/VBox/VitalsGrid/L_ST
@onready var _l_ac: Label = $MarginContainer/VBox/VitalsGrid/L_AC
@onready var _l_str: Label = $MarginContainer/VBox/AttribGrid/L_STR
@onready var _l_dex: Label = $MarginContainer/VBox/AttribGrid/L_DEX
@onready var _l_agi: Label = $MarginContainer/VBox/AttribGrid/L_AGI
@onready var _l_int: Label = $MarginContainer/VBox/AttribGrid/L_INT
@onready var _l_wis: Label = $MarginContainer/VBox/AttribGrid/L_WIS
@onready var _l_cha: Label = $MarginContainer/VBox/AttribGrid/L_CHA
@onready var _l_con: Label = $MarginContainer/VBox/AttribGrid/L_CON

func _ready() -> void:
	PlayerStats.hp_changed.connect(_on_hp_changed)
	PlayerStats.mp_changed.connect(_on_mp_changed)
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	PlayerStats.level_changed.connect(_on_level_changed)
	PlayerStats.xp_changed.connect(_on_xp_changed)
	PlayerStats.stats_changed.connect(_refresh)
	_style_xp_bar()
	_setup_tooltips()
	_refresh()

func _setup_tooltips() -> void:
	_l_hp.tooltip_text = "Hit Points — your life force. Reaching 0 HP means death."
	_l_mp.tooltip_text = "Mana Points — fuel for spells. Spells consume MP; it regenerates while resting or meditating."
	_l_st.tooltip_text = "Stamina — physical endurance. Used by combat abilities and sprinting; recovers while resting."
	_l_ac.tooltip_text = "Armor Class — your physical defense rating. Higher AC reduces incoming melee and ranged damage."
	_l_str.tooltip_text = "Strength — raw physical power. Increases melee damage dealt and your carry weight capacity."
	_l_dex.tooltip_text = "Dexterity — hand-eye coordination. Improves ranged attack accuracy and reduces your chance to miss."
	_l_agi.tooltip_text = "Agility — speed and reflexes. Increases your dodge chance and movement speed."
	_l_int.tooltip_text = "Intelligence — arcane knowledge. Boosts spell damage and effectiveness; raises maximum MP for Magicians."
	_l_wis.tooltip_text = "Wisdom — insight and attunement. Improves MP regeneration rate and the potency of healing spells."
	_l_cha.tooltip_text = "Charisma — force of personality. Improves NPC reactions, merchant prices, and group leadership bonuses."
	_l_con.tooltip_text = "Constitution — physical toughness. Increases maximum HP and your health regeneration rate."

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
	ac_value.text = str(Equipment.get_armor_class())

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
