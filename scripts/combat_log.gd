extends CanvasLayer

const MAX_LINES   := 30
const VISIBLE_ROWS := 6
const LINE_HEIGHT  := 18

const C_BG       := Color(0.04, 0.03, 0.02, 0.80)
const C_BORDER   := Color(0.20, 0.15, 0.05)
const C_DMG_OUT  := Color(0.95, 0.78, 0.25)  # player deals damage
const C_DMG_IN   := Color(0.90, 0.30, 0.25)  # player takes damage
const C_HEAL     := Color(0.35, 0.90, 0.45)
const C_INFO     := Color(0.70, 0.65, 0.55)
const C_LEVEL    := Color(0.60, 0.85, 1.00)
const C_LOOT     := Color(0.55, 0.90, 0.55)
const C_EVADE    := Color(0.55, 0.75, 0.95)
const C_SAY      := Color(1.00, 1.00, 1.00)
const C_SHOUT    := Color(1.00, 0.75, 0.20)
const C_OOC      := Color(0.30, 0.85, 0.70)
const C_TELL_OUT := Color(0.90, 0.55, 1.00)
const C_TELL_IN  := Color(1.00, 0.70, 1.00)
const C_GROUP    := Color(0.45, 0.80, 1.00)

enum MsgType { DAMAGE_OUT, DAMAGE_IN, HEAL, INFO, LEVEL_UP, LOOT, EVADE,
			   SAY, SHOUT, OOC, TELL_OUT, TELL_IN, GROUP_CHAT }

var _lines: Array = []
var _labels: Array = []
var _panel: DraggablePanel = null
var _last_hp: float = 0.0

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_last_hp = PlayerStats.hp

func _build_ui() -> void:
	_panel = DraggablePanel.new()
	_panel.anchor_left   = 0.0
	_panel.anchor_right  = 0.0
	_panel.anchor_top    = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left   = 10
	_panel.offset_right  = 310
	_panel.offset_bottom = -80
	_panel.offset_top    = -(VISIBLE_ROWS * LINE_HEIGHT + 20 + 80)

	var style := StyleBoxFlat.new()
	style.bg_color     = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	for i in VISIBLE_ROWS:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.anchor_left  = 0.0
		lbl.anchor_right = 1.0
		lbl.offset_left  = 6
		lbl.offset_right = -6
		lbl.offset_top   = 6 + i * LINE_HEIGHT
		lbl.offset_bottom = 6 + (i + 1) * LINE_HEIGHT
		lbl.clip_text    = true
		_panel.add_child(lbl)
		_labels.append(lbl)

func _connect_signals() -> void:
	Skills.skill_used.connect(func(sk):
		add_line("You use %s." % sk.skill_name, MsgType.INFO))
	Spells.spell_cast.connect(func(sp):
		add_line("You cast %s." % sp.spell_name, MsgType.INFO))
	Spells.spell_failed.connect(func(reason):
		add_line(reason, MsgType.INFO))
	PlayerStats.level_changed.connect(func(lvl):
		add_line("You have reached level %d!" % lvl, MsgType.LEVEL_UP))
	PlayerStats.hp_changed.connect(_on_player_hp_changed)
	Combat.target_changed.connect(func(enemy):
		if enemy != null and is_instance_valid(enemy):
			add_line("You target %s." % enemy.mob_name, MsgType.INFO))
	WeaponSkills.skill_advanced.connect(func(skill_name: String, new_value: int, cap: int):
		var display := WeaponSkillDefinitions.DISPLAY.get(skill_name, skill_name)
		add_line("Your %s skill has increased to %d (cap: %d)." % [display, new_value, cap], MsgType.LEVEL_UP))

func _on_player_hp_changed(current: float, _max: float) -> void:
	var diff := current - _last_hp
	if diff > 0.0:
		add_line("You recover %d health." % int(diff), MsgType.HEAL)
	_last_hp = current

func add_line(text: String, type: MsgType = MsgType.INFO) -> void:
	_lines.append({"text": text, "type": type})
	if _lines.size() > MAX_LINES:
		_lines.pop_front()
	_refresh()

func add_damage_out(target_name: String, amount: int) -> void:
	add_line("You hit %s for %d damage." % [target_name, amount], MsgType.DAMAGE_OUT)

func add_evade(attacker_name: String) -> void:
	add_line("You evade %s's attack!" % attacker_name, MsgType.EVADE)

func _refresh() -> void:
	var start := maxi(0, _lines.size() - VISIBLE_ROWS)
	for i in VISIBLE_ROWS:
		var lbl: Label = _labels[i]
		var idx := start + i
		if idx >= _lines.size():
			lbl.text = ""
			continue
		var entry: Dictionary = _lines[idx]
		lbl.text = entry["text"]
		match entry["type"]:
			MsgType.DAMAGE_OUT:  lbl.add_theme_color_override("font_color", C_DMG_OUT)
			MsgType.DAMAGE_IN:   lbl.add_theme_color_override("font_color", C_DMG_IN)
			MsgType.HEAL:        lbl.add_theme_color_override("font_color", C_HEAL)
			MsgType.LEVEL_UP:    lbl.add_theme_color_override("font_color", C_LEVEL)
			MsgType.LOOT:        lbl.add_theme_color_override("font_color", C_LOOT)
			MsgType.EVADE:       lbl.add_theme_color_override("font_color", C_EVADE)
			MsgType.SAY:         lbl.add_theme_color_override("font_color", C_SAY)
			MsgType.SHOUT:       lbl.add_theme_color_override("font_color", C_SHOUT)
			MsgType.OOC:         lbl.add_theme_color_override("font_color", C_OOC)
			MsgType.TELL_OUT:    lbl.add_theme_color_override("font_color", C_TELL_OUT)
			MsgType.TELL_IN:     lbl.add_theme_color_override("font_color", C_TELL_IN)
			MsgType.GROUP_CHAT:  lbl.add_theme_color_override("font_color", C_GROUP)
			_:                   lbl.add_theme_color_override("font_color", C_INFO)
