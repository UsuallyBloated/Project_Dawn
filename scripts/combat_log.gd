extends CanvasLayer

const MAX_LINES    := 200
const PANEL_HEIGHT := 148

const C_BG       := Color(0.04, 0.03, 0.02, 0.80)
const C_BORDER   := Color(0.20, 0.15, 0.05)
const C_DMG_OUT  := Color(0.95, 0.78, 0.25)
const C_CRIT     := Color(1.00, 0.92, 0.30)
const C_DMG_IN   := Color(0.90, 0.30, 0.25)
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
			   SAY, SHOUT, OOC, TELL_OUT, TELL_IN, GROUP_CHAT, CRIT }

signal chat_submitted(text: String)

var _scroll: ScrollContainer = null
var _msg_vbox: VBoxContainer = null
var _panel: DraggablePanel = null
var _back_btn: Button = null
var _chat_input: LineEdit = null
var _last_hp: float = 0.0
var _auto_scroll := true

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
	_panel.offset_top    = -(PANEL_HEIGHT + 80)

	var style := StyleBoxFlat.new()
	style.bg_color     = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 6; _scroll.offset_top = 6
	_scroll.offset_right = -6; _scroll.offset_bottom = -32
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	_msg_vbox = VBoxContainer.new()
	_msg_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_vbox.add_theme_constant_override("separation", 1)
	_scroll.add_child(_msg_vbox)

	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_value_changed)

	_back_btn = Button.new()
	_back_btn.text = "▼  latest"
	_back_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_back_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_back_btn.offset_left   =  6.0
	_back_btn.offset_right  = -6.0
	_back_btn.offset_top    = -26.0
	_back_btn.offset_bottom = -6.0
	_back_btn.add_theme_font_size_override("font_size", 10)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.10, 0.08, 0.05, 0.90)
	btn_style.border_color = UITheme.C_GOLDEN_BORDER
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(2)
	_back_btn.add_theme_stylebox_override("normal",  btn_style)
	_back_btn.add_theme_stylebox_override("hover",   btn_style)
	_back_btn.add_theme_stylebox_override("pressed", btn_style)
	_back_btn.add_theme_color_override("font_color", UITheme.C_TITLE)
	_back_btn.visible = false
	_back_btn.pressed.connect(_on_back_to_bottom_pressed)
	_panel.add_child(_back_btn)

	_chat_input = LineEdit.new()
	_chat_input.anchor_left = 0.0
	_chat_input.anchor_top = 1.0
	_chat_input.anchor_right = 1.0
	_chat_input.anchor_bottom = 1.0
	_chat_input.offset_left = 6
	_chat_input.offset_right = -6
	_chat_input.offset_top = -28
	_chat_input.offset_bottom = -2
	_chat_input.placeholder_text = "Press Enter to type..."
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_on_chat_submitted)
	_chat_input.focus_exited.connect(func(): _chat_input.visible = false)
	_panel.add_child(_chat_input)

func show_chat_input() -> void:
	if _chat_input == null:
		return
	_chat_input.visible = true
	_chat_input.text = ""
	_chat_input.grab_focus()

func is_chat_input_focused() -> bool:
	return _chat_input != null and _chat_input.has_focus()

func _on_chat_submitted(text: String) -> void:
	_chat_input.visible = false
	_chat_input.text = ""
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	chat_submitted.emit(trimmed)

func _on_scroll_value_changed(value: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	_auto_scroll = value >= bar.max_value - bar.page
	_back_btn.visible = not _auto_scroll

func _connect_signals() -> void:
	Skills.skill_used.connect(func(sk):
		add_line("You use %s." % sk.skill_name, MsgType.INFO))
	Spells.spell_cast.connect(func(sp):
		add_line("You cast %s." % sp.spell_name, MsgType.INFO))
	Spells.spell_failed.connect(func(reason):
		add_line(reason, MsgType.DAMAGE_IN))
	PlayerStats.level_changed.connect(func(lvl):
		add_line("You have reached level %d!" % lvl, MsgType.LEVEL_UP))
	PlayerStats.hp_changed.connect(_on_player_hp_changed)
	Combat.target_changed.connect(func(enemy):
		if enemy != null and is_instance_valid(enemy):
			var tname: String = enemy.get("mob_name") if "mob_name" in enemy else enemy.name
			add_line("You target %s." % tname, MsgType.INFO))
	Combat.player_hit_enemy.connect(func(t, a, c): add_damage_out(t, a, c))
	Combat.player_missed_enemy.connect(func(t): add_line("You miss %s." % t, MsgType.DAMAGE_OUT))
	Combat.player_evaded_attack.connect(func(n): add_evade(n))
	Combat.player_took_damage.connect(func(n, a):
		add_line("%s hits you for %d damage." % [n, a], MsgType.DAMAGE_IN))
	WeaponSkills.skill_advanced.connect(func(skill_name: String, new_value: int, cap: int):
		var display: String = WeaponSkillDefinitions.DISPLAY.get(skill_name, skill_name)
		add_line("Your %s skill has increased to %d (cap: %d)." % [display, new_value, cap], MsgType.LEVEL_UP))
	ArmorSkills.skill_advanced.connect(func(skill_name: String, new_value: int, cap: int):
		var display: String = ArmorSkillDefinitions.DISPLAY.get(skill_name, skill_name)
		add_line("Your %s skill has increased to %d (cap: %d)." % [display, new_value, cap], MsgType.LEVEL_UP))
	CastingSkills.skill_advanced.connect(func(skill_name: String, new_value: int, cap: int):
		var display: String = CastingSkillDefinitions.DISPLAY.get(skill_name, skill_name)
		add_line("Your %s skill has increased to %d (cap: %d)." % [display, new_value, cap], MsgType.LEVEL_UP))
	BuffManager.dot_applied.connect(func(tname, sname):
		add_line("%s is afflicted by %s." % [tname, sname], MsgType.DAMAGE_OUT))
	BuffManager.hot_applied.connect(func(sname):
		add_line("You feel the effects of %s." % sname, MsgType.HEAL))
	BuffManager.absorb_applied.connect(func(amount, sname):
		add_line("A %s shield forms around you. (%d HP)" % [sname, amount], MsgType.HEAL))
	BuffManager.absorb_damaged.connect(func(absorbed, remaining):
		add_line("Your shield absorbs %d damage. (%d remaining)" % [absorbed, remaining], MsgType.HEAL))
	BuffManager.absorb_broken.connect(func():
		add_line("Your shield has been destroyed!", MsgType.DAMAGE_IN))
	BuffManager.evade_boost_applied.connect(func():
		add_line("You slip into a defensive stance.", MsgType.INFO))
	BuffManager.dot_ticked.connect(func(tname, amount, sname):
		add_line("%s takes %d from %s." % [tname, amount, sname], MsgType.DAMAGE_OUT))
	BuffManager.hot_ticked.connect(func(amount, sname):
		add_line("You recover %d health from %s." % [amount, sname], MsgType.HEAL))
	PetManager.pet_info.connect(func(text): add_line(text, MsgType.INFO))
	Combat.enemy_stunned.connect(func(n): add_line("%s is stunned!" % n, MsgType.INFO))
	Combat.enemy_stun_wore_off.connect(func(n): add_line("The stun on %s wears off." % n, MsgType.INFO))
	Combat.enemy_rooted.connect(func(n): add_line("%s is rooted!" % n, MsgType.INFO))
	Combat.enemy_snared.connect(func(n): add_line("%s is snared!" % n, MsgType.INFO))
	Combat.enemy_slowed.connect(func(n): add_line("%s is slowed!" % n, MsgType.INFO))
	Combat.enemy_mez_applied.connect(func(n): add_line("%s is mesmerized!" % n, MsgType.INFO))
	Combat.enemy_mez_broke.connect(func(n): add_line("The mesmerize on %s breaks!" % n, MsgType.INFO))
	Combat.enemy_charmed_attacked.connect(func(atk, tgt, amt): add_line("%s hits %s for %d." % [atk, tgt, amt], MsgType.DAMAGE_OUT))
	Combat.enemy_silenced.connect(func(n): add_line("%s is silenced!" % n, MsgType.INFO))

func _on_player_hp_changed(current: float, _max: float) -> void:
	var diff := current - _last_hp
	if diff > 0.0 and not BuffManager.is_hot_healing():
		add_line("You recover %d health." % int(diff), MsgType.HEAL)
	_last_hp = current

func add_line(text: String, type: MsgType = MsgType.INFO) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.add_theme_color_override("font_color", _color_for(type))
	_msg_vbox.add_child(lbl)

	if _msg_vbox.get_child_count() > MAX_LINES:
		_msg_vbox.get_child(0).queue_free()

	if _auto_scroll:
		call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

func _on_back_to_bottom_pressed() -> void:
	_auto_scroll = true
	_back_btn.visible = false
	_scroll_to_bottom()

func _color_for(type: MsgType) -> Color:
	match type:
		MsgType.DAMAGE_OUT: return C_DMG_OUT
		MsgType.DAMAGE_IN:  return C_DMG_IN
		MsgType.HEAL:       return C_HEAL
		MsgType.LEVEL_UP:   return C_LEVEL
		MsgType.LOOT:       return C_LOOT
		MsgType.EVADE:      return C_EVADE
		MsgType.SAY:        return C_SAY
		MsgType.SHOUT:      return C_SHOUT
		MsgType.OOC:        return C_OOC
		MsgType.TELL_OUT:   return C_TELL_OUT
		MsgType.TELL_IN:    return C_TELL_IN
		MsgType.GROUP_CHAT: return C_GROUP
		MsgType.CRIT:       return C_CRIT
		_:                  return C_INFO

func add_damage_out(target_name: String, amount: int, is_crit: bool = false) -> void:
	if is_crit:
		add_line("** You critically hit %s for %d damage! **" % [target_name, amount], MsgType.CRIT)
	else:
		add_line("You hit %s for %d damage." % [target_name, amount], MsgType.DAMAGE_OUT)

func add_evade(attacker_name: String) -> void:
	add_line("You evade %s's attack!" % attacker_name, MsgType.EVADE)
