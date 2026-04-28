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

enum MsgType { DAMAGE_OUT, DAMAGE_IN, HEAL, INFO, LEVEL_UP }

var _lines: Array = []
var _labels: Array = []
var _panel: Panel = null
var _last_hp: float = 0.0

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_last_hp = PlayerStats.hp

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.anchor_left   = 0.0
	_panel.anchor_right  = 0.0
	_panel.anchor_top    = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left   = 10
	_panel.offset_right  = 310
	_panel.offset_top    = -(VISIBLE_ROWS * LINE_HEIGHT + 20)
	_panel.offset_bottom = -80

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

func _on_player_hp_changed(current: float, _max: float) -> void:
	var diff := current - _last_hp
	if diff < 0.0:
		add_line("%s hits you for %d damage." % [_get_target_name(), int(-diff)], MsgType.DAMAGE_IN)
	elif diff > 0.0:
		add_line("You recover %d health." % int(diff), MsgType.HEAL)
	_last_hp = current

func _get_target_name() -> String:
	if Combat.current_target != null and is_instance_valid(Combat.current_target):
		return Combat.current_target.mob_name
	return "Something"

func add_line(text: String, type: MsgType = MsgType.INFO) -> void:
	_lines.append({"text": text, "type": type})
	if _lines.size() > MAX_LINES:
		_lines.pop_front()
	_refresh()

func add_damage_out(target_name: String, amount: int) -> void:
	add_line("You hit %s for %d damage." % [target_name, amount], MsgType.DAMAGE_OUT)

func _refresh() -> void:
	var start := max(0, _lines.size() - VISIBLE_ROWS)
	for i in VISIBLE_ROWS:
		var lbl: Label = _labels[i]
		var idx := start + i
		if idx >= _lines.size():
			lbl.text = ""
			continue
		var entry: Dictionary = _lines[idx]
		lbl.text = entry["text"]
		match entry["type"]:
			MsgType.DAMAGE_OUT: lbl.add_theme_color_override("font_color", C_DMG_OUT)
			MsgType.DAMAGE_IN:  lbl.add_theme_color_override("font_color", C_DMG_IN)
			MsgType.HEAL:       lbl.add_theme_color_override("font_color", C_HEAL)
			MsgType.LEVEL_UP:   lbl.add_theme_color_override("font_color", C_LEVEL)
			_:                  lbl.add_theme_color_override("font_color", C_INFO)
