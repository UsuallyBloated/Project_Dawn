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
@onready var atk_value: Label = $MarginContainer/VBox/AttribGrid/V_ATK
@onready var wt_value: Label = $MarginContainer/VBox/AttribGrid/V_WT
@onready var xp_bar: ProgressBar = $MarginContainer/VBox/XPBar

var _skills_rows: Dictionary = {}         # weapon skill_key -> {name: Label, val: Label}
var _armor_skill_rows: Dictionary = {}    # armor skill_key -> {name: Label, val: Label}
var _casting_skill_rows: Dictionary = {}  # casting skill_key -> {name: Label, val: Label}

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
@onready var _l_atk: Label = $MarginContainer/VBox/AttribGrid/L_ATK
@onready var _l_wt: Label = $MarginContainer/VBox/AttribGrid/L_WT

@onready var _close_btn: Button = $MarginContainer/VBox/TitleRow/CloseBtn
@onready var _title_lbl: Label = $MarginContainer/VBox/TitleRow/Title

func _ready() -> void:
	_apply_panel_style()
	_title_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	_close_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	_close_btn.pressed.connect(func() -> void: visible = false)

	PlayerStats.hp_changed.connect(_on_hp_changed)
	PlayerStats.mp_changed.connect(_on_mp_changed)
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	PlayerStats.level_changed.connect(_on_level_changed)
	PlayerStats.xp_changed.connect(_on_xp_changed)
	PlayerStats.stats_changed.connect(_refresh)
	Equipment.equipment_changed.connect(func(_slot, _item) -> void: _refresh())
	Encumbrance.encumbrance_changed.connect(_on_encumbrance_changed)
	_style_xp_bar()
	_setup_tooltips()
	_refresh()
	_build_skills_section()
	WeaponSkills.skill_advanced.connect(_on_skill_advanced)
	ArmorSkills.skill_advanced.connect(_on_armor_skill_advanced)
	CastingSkills.skill_advanced.connect(_on_casting_skill_advanced)

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.C_WINDOW_BG
	style.border_color = UITheme.C_GOLDEN_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)

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
	_l_atk.tooltip_text = "Attack — your melee damage range. Weapon damage is fixed; Strength adds a bonus (STR / 5) on top."
	_l_wt.tooltip_text = "Weight — everything you carry: coins, inventory, and worn equipment, against your capacity (10 + STR). Over capacity slows movement; at double capacity stamina stops regenerating."

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
	atk_value.text = _get_attack_range()
	ac_value.text = str(Equipment.get_armor_class())
	_refresh_weight(Encumbrance.total_weight, Encumbrance.capacity)

func _get_attack_range() -> String:
	@warning_ignore("integer_division")
	var str_bonus: int = PlayerStats.strength / 5
	var weapon: ItemData = Equipment.equipped.get("weapon")
	if weapon != null and weapon.weapon_damage_max > 0:
		return "%d - %d" % [weapon.weapon_damage_min + str_bonus, weapon.weapon_damage_max + str_bonus]
	return "%d - %d" % [1 + str_bonus, 4 + str_bonus]

func _on_encumbrance_changed(weight: float, capacity: float) -> void:
	_refresh_weight(weight, capacity)

# Carried weight vs capacity, colored at the two penalty thresholds
# (Encumbrance: > capacity slows movement, ≥ 2× stops stamina regen).
func _refresh_weight(weight: float, capacity: float) -> void:
	wt_value.text = "%.1f / %.1f" % [weight, capacity]
	if weight >= capacity * Encumbrance.OVERLOADED_RATIO:
		wt_value.add_theme_color_override("font_color", UITheme.C_OVERLOADED)
	elif weight > capacity:
		wt_value.add_theme_color_override("font_color", UITheme.C_ENCUMBERED)
	else:
		wt_value.remove_theme_color_override("font_color")

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
	_refresh_skills()
	_refresh_armor_skills()

func _build_skills_section() -> void:
	var vbox: VBoxContainer = $MarginContainer/VBox

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	scroll.add_child(inner)

	var header := Label.new()
	header.text = "Combat Skills"
	header.add_theme_color_override("font_color", UITheme.C_TITLE)
	header.add_theme_font_size_override("font_size", 12)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	inner.add_child(grid)

	for skill in WeaponSkillDefinitions.ALL:
		var name_lbl := Label.new()
		name_lbl.text = WeaponSkillDefinitions.DISPLAY.get(skill, skill)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val_lbl)
		_skills_rows[skill] = {"name": name_lbl, "val": val_lbl}

	_refresh_skills()

	inner.add_child(HSeparator.new())

	var armor_header := Label.new()
	armor_header.text = "Armor Skills"
	armor_header.add_theme_color_override("font_color", UITheme.C_TITLE)
	armor_header.add_theme_font_size_override("font_size", 12)
	armor_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(armor_header)

	var armor_grid := GridContainer.new()
	armor_grid.columns = 2
	armor_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armor_grid.add_theme_constant_override("h_separation", 8)
	armor_grid.add_theme_constant_override("v_separation", 3)
	inner.add_child(armor_grid)

	for skill in ArmorSkillDefinitions.ALL:
		var name_lbl := Label.new()
		name_lbl.text = ArmorSkillDefinitions.DISPLAY.get(skill, skill)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		armor_grid.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		armor_grid.add_child(val_lbl)
		_armor_skill_rows[skill] = {"name": name_lbl, "val": val_lbl}

	_refresh_armor_skills()

	inner.add_child(HSeparator.new())

	var casting_header := Label.new()
	casting_header.text = "Casting Skills"
	casting_header.add_theme_color_override("font_color", UITheme.C_TITLE)
	casting_header.add_theme_font_size_override("font_size", 12)
	casting_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(casting_header)

	var casting_grid := GridContainer.new()
	casting_grid.columns = 2
	casting_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	casting_grid.add_theme_constant_override("h_separation", 8)
	casting_grid.add_theme_constant_override("v_separation", 3)
	inner.add_child(casting_grid)

	for skill in CastingSkillDefinitions.ALL:
		var name_lbl := Label.new()
		name_lbl.text = CastingSkillDefinitions.DISPLAY.get(skill, skill)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		casting_grid.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		casting_grid.add_child(val_lbl)
		_casting_skill_rows[skill] = {"name": name_lbl, "val": val_lbl}

	_refresh_casting_skills()

func _refresh_skills() -> void:
	for skill in _skills_rows:
		var cap := WeaponSkills.get_cap(skill)
		var row: Dictionary = _skills_rows[skill]
		var name_lbl: Label = row["name"]
		var val_lbl: Label = row["val"]
		if cap == 0:
			name_lbl.visible = false
			val_lbl.visible = false
		else:
			name_lbl.visible = true
			val_lbl.visible = true
			val_lbl.text = "%d / %d" % [WeaponSkills.get_current(skill), cap]

func _on_skill_advanced(_skill_name: String, _new_value: int, _cap: int) -> void:
	_refresh_skills()

func _refresh_armor_skills() -> void:
	for skill in _armor_skill_rows:
		var cap := ArmorSkills.get_cap(skill)
		var row: Dictionary = _armor_skill_rows[skill]
		var name_lbl: Label = row["name"]
		var val_lbl: Label = row["val"]
		if cap == 0:
			name_lbl.visible = false
			val_lbl.visible = false
		else:
			name_lbl.visible = true
			val_lbl.visible = true
			val_lbl.text = "%d / %d" % [ArmorSkills.get_current(skill), cap]

func _on_armor_skill_advanced(_skill_name: String, _new_value: int, _cap: int) -> void:
	_refresh_armor_skills()

func _refresh_casting_skills() -> void:
	for skill in _casting_skill_rows:
		var cap := CastingSkills.get_cap(skill)
		var row: Dictionary = _casting_skill_rows[skill]
		var name_lbl: Label = row["name"]
		var val_lbl: Label = row["val"]
		if cap == 0:
			name_lbl.visible = false
			val_lbl.visible = false
		else:
			name_lbl.visible = true
			val_lbl.visible = true
			val_lbl.text = "%d / %d" % [CastingSkills.get_current(skill), cap]

func _on_casting_skill_advanced(_skill_name: String, _new_value: int, _cap: int) -> void:
	_refresh_casting_skills()
