extends Control

# ── Data ──────────────────────────────────────────────────────────────────────

const RACES: Array[String] = [
	"Human", "Elf", "Dark Elf", "Wood Elf", "Gnome",
	"Halfling", "Dwarf", "Half-Elf", "Ogre", "Troll"
]

const CLASSES: Array[String] = ["Warrior", "Mage", "Rogue"]

const RACE_DATA: Dictionary = {
	"Human": {
		"desc": "Versatile and adaptable. Balanced bonuses across all attributes suit any profession.",
		"bonuses": {"strength": 2, "dexterity": 2, "agility": 2, "intelligence": 2, "wisdom": 2, "charisma": 2, "constitution": 2}
	},
	"Elf": {
		"desc": "Graceful and keen. High dexterity and intellect, but physically fragile.",
		"bonuses": {"dexterity": 10, "agility": 10, "intelligence": 10, "wisdom": 5, "strength": -5, "constitution": -5}
	},
	"Dark Elf": {
		"desc": "Cunning masters of dark magic with exceptional reflexes. Few trust them.",
		"bonuses": {"intelligence": 15, "dexterity": 10, "agility": 5, "wisdom": -5, "charisma": -10}
	},
	"Gnome": {
		"desc": "Brilliant tinkerers with extraordinary intellect and wisdom, but weak in body.",
		"bonuses": {"intelligence": 15, "wisdom": 5, "strength": -5, "constitution": -5}
	},
	"Halfling": {
		"desc": "Quick and nimble folk. Masters of stealth and sleight of hand.",
		"bonuses": {"dexterity": 10, "agility": 10, "charisma": 5, "strength": -5, "constitution": -5}
	},
	"Dwarf": {
		"desc": "Hardy mountainfolk, nearly unbreakable. Exceptional constitution and wisdom.",
		"bonuses": {"constitution": 15, "strength": 5, "wisdom": 5, "charisma": -5, "agility": -5}
	},
	"Wood Elf": {
		"desc": "Children of the forest, swift and sure-eyed. Exceptional hunters and rangers.",
		"bonuses": {"dexterity": 10, "agility": 10, "wisdom": 5, "intelligence": -5, "charisma": -5}
	},
	"Half-Elf": {
		"desc": "Blending elven grace with human resilience. Well-rounded and adaptable.",
		"bonuses": {"dexterity": 5, "agility": 5, "intelligence": 5, "wisdom": 5}
	},
	"Ogre": {
		"desc": "Massive and brutish. Unmatched raw power at the cost of wit and charm.",
		"bonuses": {"strength": 20, "constitution": 10, "charisma": -15, "intelligence": -5, "wisdom": -5}
	},
	"Troll": {
		"desc": "Savage regenerators with extraordinary endurance. Fearsome but repugnant.",
		"bonuses": {"constitution": 20, "strength": 10, "charisma": -15, "wisdom": -10, "intelligence": -5}
	},
}

const CLASS_DATA: Dictionary = {
	"Warrior": {
		"desc": "Masters of melee combat. Heavy armor, high HP, and physical dominance define their path.",
		"bonuses": {"strength": 10, "constitution": 8},
		"hp_bonus": 50.0, "mp_bonus": 0.0, "stamina_bonus": 20.0
	},
	"Mage": {
		"desc": "Wielders of arcane power. Devastating spells and vast mana, at the cost of physical frailty.",
		"bonuses": {"intelligence": 15, "wisdom": 10},
		"hp_bonus": -10.0, "mp_bonus": 100.0, "stamina_bonus": 0.0
	},
	"Rogue": {
		"desc": "Cunning infiltrators. Precision strikes, poisons, and unmatched agility define their craft.",
		"bonuses": {"dexterity": 15, "agility": 10},
		"hp_bonus": 20.0, "mp_bonus": 0.0, "stamina_bonus": 20.0
	},
}

const STAT_KEYS: Array[String] = [
	"strength", "dexterity", "agility",
	"intelligence", "wisdom", "charisma", "constitution"
]

const STAT_SHORT: Array[String] = ["STR", "DEX", "AGI", "INT", "WIS", "CHA", "CON"]

const BASE: int = 10
const BASE_HP: float = 100.0
const BASE_MP: float = 100.0
const BASE_ST: float = 100.0

# ── Colors ─────────────────────────────────────────────────────────────────────

const C_BG        := Color(0.04, 0.03, 0.02)
const C_PANEL     := Color(0.10, 0.08, 0.06)
const C_BORDER    := Color(0.30, 0.22, 0.08)
const C_TEXT      := Color(0.90, 0.82, 0.65)
const C_TITLE     := Color(0.95, 0.78, 0.25)
const C_SELECTED  := Color(0.60, 0.44, 0.12)
const C_BTN_NORM  := Color(0.14, 0.11, 0.07)
const C_BTN_HOVER := Color(0.22, 0.17, 0.09)
const C_POS       := Color(0.40, 0.90, 0.40)
const C_NEG       := Color(0.90, 0.35, 0.35)
const C_NEUTRAL   := Color(0.75, 0.70, 0.55)

# ── State ──────────────────────────────────────────────────────────────────────

var selected_race: String = ""
var selected_class: String = ""
var _race_btns: Dictionary = {}
var _class_btns: Dictionary = {}
var _stat_labels: Dictionary = {}
var _res_labels: Dictionary = {}
var _race_desc_lbl: Label
var _class_desc_lbl: Label
var _confirm_btn: Button

# ── Build ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 50
	root.offset_top = 24
	root.offset_right = -50
	root.offset_bottom = -24
	add_child(root)

	var title := _make_label("PROJECT DAWN", 32, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(title)

	var subtitle := _make_label("Create Your Character", 15, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(subtitle)

	root.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root.add_child(cols)

	_build_race_panel(cols)
	_build_stats_panel(cols)
	_build_class_panel(cols)

	root.add_child(HSeparator.new())

	_confirm_btn = _make_confirm_btn()
	root.add_child(_confirm_btn)


func _build_race_panel(parent: Control) -> void:
	var pc := _make_panel_container(true)
	parent.add_child(pc)

	var margin := _make_margin(pc, 10)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	vbox.add_child(_make_label("— RACE —", 14, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var btn_box := VBoxContainer.new()
	btn_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_box.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_box)

	for race in RACES:
		var btn := _make_select_btn(race)
		btn.pressed.connect(_on_race_selected.bind(race))
		btn_box.add_child(btn)
		_race_btns[race] = btn

	vbox.add_child(HSeparator.new())

	_race_desc_lbl = _make_label("", 12, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_race_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_desc_lbl.custom_minimum_size.y = 50
	vbox.add_child(_race_desc_lbl)


func _build_class_panel(parent: Control) -> void:
	var pc := _make_panel_container(true)
	parent.add_child(pc)

	var margin := _make_margin(pc, 10)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	vbox.add_child(_make_label("— CLASS —", 14, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var btn_box := VBoxContainer.new()
	btn_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_box.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_box)

	for cls in CLASSES:
		var btn := _make_select_btn(cls)
		btn.pressed.connect(_on_class_selected.bind(cls))
		btn_box.add_child(btn)
		_class_btns[cls] = btn

	vbox.add_child(HSeparator.new())

	_class_desc_lbl = _make_label("", 12, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_class_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_desc_lbl.custom_minimum_size.y = 50
	vbox.add_child(_class_desc_lbl)


func _build_stats_panel(parent: Control) -> void:
	var pc := _make_panel_container(false)
	pc.custom_minimum_size.x = 180
	parent.add_child(pc)

	var margin := _make_margin(pc, 10)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(_make_label("— ATTRIBUTES —", 14, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var attr_grid := GridContainer.new()
	attr_grid.columns = 2
	attr_grid.add_theme_constant_override("h_separation", 8)
	attr_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(attr_grid)

	for i in STAT_KEYS.size():
		attr_grid.add_child(_make_label(STAT_SHORT[i], 13, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		var val_lbl := _make_label(str(BASE), 13, C_NEUTRAL, HORIZONTAL_ALIGNMENT_RIGHT)
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attr_grid.add_child(val_lbl)
		_stat_labels[STAT_KEYS[i]] = val_lbl

	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_label("— RESOURCES —", 13, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var res_grid := GridContainer.new()
	res_grid.columns = 2
	res_grid.add_theme_constant_override("h_separation", 8)
	res_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(res_grid)

	for pair: Array in [["HP", "hp"], ["MP", "mp"], ["ST", "st"]]:
		res_grid.add_child(_make_label(pair[0], 13, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		var val := _make_label("—", 13, C_NEUTRAL, HORIZONTAL_ALIGNMENT_RIGHT)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		res_grid.add_child(val)
		_res_labels[pair[1]] = val

# ── Selection ──────────────────────────────────────────────────────────────────

func _on_race_selected(race: String) -> void:
	selected_race = race
	for r in RACES:
		_set_btn_selected(_race_btns[r], r == race)
	_race_desc_lbl.text = RACE_DATA[race]["desc"]
	_refresh_stats()
	_update_confirm()


func _on_class_selected(cls: String) -> void:
	selected_class = cls
	for c in CLASSES:
		_set_btn_selected(_class_btns[c], c == cls)
	_class_desc_lbl.text = CLASS_DATA[cls]["desc"]
	_refresh_stats()
	_update_confirm()


func _refresh_stats() -> void:
	var totals: Dictionary = {}
	for k in STAT_KEYS:
		totals[k] = BASE

	if selected_race != "":
		for k: String in RACE_DATA[selected_race]["bonuses"]:
			totals[k] += RACE_DATA[selected_race]["bonuses"][k]

	if selected_class != "":
		for k: String in CLASS_DATA[selected_class]["bonuses"]:
			totals[k] += CLASS_DATA[selected_class]["bonuses"][k]

	for k in STAT_KEYS:
		var lbl: Label = _stat_labels[k]
		var val: int = totals[k]
		lbl.text = str(val)
		if val > BASE:
			lbl.add_theme_color_override("font_color", C_POS)
		elif val < BASE:
			lbl.add_theme_color_override("font_color", C_NEG)
		else:
			lbl.add_theme_color_override("font_color", C_NEUTRAL)

	if selected_class != "":
		var cd: Dictionary = CLASS_DATA[selected_class]
		_res_labels["hp"].text = str(int(max(50.0, BASE_HP + cd["hp_bonus"])))
		_res_labels["mp"].text = str(int(max(20.0, BASE_MP + cd["mp_bonus"])))
		_res_labels["st"].text = str(int(max(20.0, BASE_ST + cd["stamina_bonus"])))
	else:
		for k in _res_labels:
			(_res_labels[k] as Label).text = "—"


func _update_confirm() -> void:
	_confirm_btn.disabled = selected_race == "" or selected_class == ""

# ── Confirm ────────────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	var rb: Dictionary = RACE_DATA[selected_race]["bonuses"]
	var cb: Dictionary = CLASS_DATA[selected_class]["bonuses"]

	PlayerStats.race         = selected_race
	PlayerStats.player_class = selected_class
	PlayerStats.strength     = BASE + rb.get("strength", 0)     + cb.get("strength", 0)
	PlayerStats.dexterity    = BASE + rb.get("dexterity", 0)    + cb.get("dexterity", 0)
	PlayerStats.agility      = BASE + rb.get("agility", 0)      + cb.get("agility", 0)
	PlayerStats.intelligence = BASE + rb.get("intelligence", 0) + cb.get("intelligence", 0)
	PlayerStats.wisdom       = BASE + rb.get("wisdom", 0)       + cb.get("wisdom", 0)
	PlayerStats.charisma     = BASE + rb.get("charisma", 0)     + cb.get("charisma", 0)
	PlayerStats.constitution = BASE + rb.get("constitution", 0) + cb.get("constitution", 0)

	var cd: Dictionary = CLASS_DATA[selected_class]
	PlayerStats.max_hp      = max(50.0,  BASE_HP + cd["hp_bonus"])
	PlayerStats.max_mp      = max(20.0,  BASE_MP + cd["mp_bonus"])
	PlayerStats.max_stamina = max(20.0,  BASE_ST + cd["stamina_bonus"])
	PlayerStats.set_hp(PlayerStats.max_hp)
	PlayerStats.set_mp(PlayerStats.max_mp)
	PlayerStats.set_stamina(PlayerStats.max_stamina)

	Skills.setup_for_class(selected_class)
	Spells.setup_for_class(selected_class)
	get_tree().change_scene_to_file("res://node_3d.tscn")

# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_panel_container(expand_h: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	pc.add_theme_stylebox_override("panel", style)
	if expand_h:
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return pc


func _make_margin(parent: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", m)
	mc.add_theme_constant_override("margin_top", m)
	mc.add_theme_constant_override("margin_right", m)
	mc.add_theme_constant_override("margin_bottom", m)
	parent.add_child(mc)
	return mc


func _make_label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = align
	return lbl


func _make_select_btn(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	_style_btn(btn, false)
	return btn


func _set_btn_selected(btn: Button, is_selected: bool) -> void:
	_style_btn(btn, is_selected)


func _style_btn(btn: Button, is_selected: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color     = C_SELECTED if is_selected else C_BTN_NORM
	s.border_color = C_TITLE    if is_selected else C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left   = 10
	s.content_margin_top    = 5
	s.content_margin_right  = 10
	s.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus", s)
	btn.add_theme_color_override("font_color", C_TITLE if is_selected else C_TEXT)

	var h := s.duplicate() as StyleBoxFlat
	h.bg_color     = C_SELECTED if is_selected else C_BTN_HOVER
	h.border_color = C_TITLE
	btn.add_theme_stylebox_override("hover", h)


func _make_confirm_btn() -> Button:
	var btn := Button.new()
	btn.text = "Begin Adventure"
	btn.custom_minimum_size = Vector2(280, 46)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", C_TITLE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = true
	btn.pressed.connect(_on_confirm)

	var norm := StyleBoxFlat.new()
	norm.bg_color     = Color(0.18, 0.12, 0.03)
	norm.border_color = Color(0.55, 0.40, 0.10)
	norm.set_border_width_all(2)
	norm.set_corner_radius_all(6)
	norm.content_margin_left   = 24
	norm.content_margin_top    = 10
	norm.content_margin_right  = 24
	norm.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", norm)

	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color     = Color(0.35, 0.25, 0.07)
	hover.border_color = C_TITLE
	btn.add_theme_stylebox_override("hover", hover)

	var dis := norm.duplicate() as StyleBoxFlat
	dis.bg_color     = Color(0.10, 0.08, 0.04)
	dis.border_color = Color(0.25, 0.18, 0.06)
	dis.set_border_width_all(1)
	btn.add_theme_stylebox_override("disabled", dis)

	return btn
