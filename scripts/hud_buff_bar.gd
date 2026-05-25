extends DraggablePanel

var _hbox: HBoxContainer = null
var _timer_labels: Dictionary = {}

func _ready() -> void:
	# Default position: directly below the player stat panel at top-
	# left (left=32, right=342, ending at y=133). 8 px gap below the
	# panel; matches the panel's width (310) for visual alignment.
	# DraggablePanel lets the player move it at runtime if they want.
	anchor_left   = 0.0
	anchor_top    = 0.0
	anchor_right  = 0.0
	anchor_bottom = 0.0
	offset_left   = 32.0
	offset_right  = 342.0
	offset_top    = 141.0
	offset_bottom = 189.0
	clip_contents = true

	apply_style(Color(0.04, 0.03, 0.02, 0.70), UITheme.C_BORDER)

	_hbox = HBoxContainer.new()
	_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hbox.offset_left = 3; _hbox.offset_top = 3
	_hbox.offset_right = -3; _hbox.offset_bottom = -3
	_hbox.add_theme_constant_override("separation", 4)
	add_child(_hbox)

	BuffManager.buffs_changed.connect(_on_buffs_changed)
	_on_buffs_changed()

func _process(_delta: float) -> void:
	_update_timers()

func _on_buffs_changed() -> void:
	_timer_labels.clear()
	for child in _hbox.get_children():
		child.queue_free()
	for h in BuffManager.get_hots():
		_timer_labels["hot:%s" % h.spell_name] = _add_icon("hot", h.spell_name)
	if BuffManager.get_absorb_hp() > 0.0:
		var absorb_label: String = BuffManager.get_absorb_source()
		if absorb_label == "":
			absorb_label = "Shield"
		_timer_labels["absorb"] = _add_icon("absorb", absorb_label)
	if BuffManager.get_evade_remaining() > 0.0:
		_timer_labels["evade"] = _add_icon("evade", "Evade")
	var food := BuffManager.get_food_buff()
	if not food.is_empty():
		_timer_labels["food"] = _add_icon("food", food.get("buff_name", "Food"))
	var drink := BuffManager.get_drink_buff()
	if not drink.is_empty():
		_timer_labels["drink"] = _add_icon("drink", drink.get("buff_name", "Drink"))
	var spd := BuffManager.get_speed_buff()
	if not spd.is_empty():
		_timer_labels["speed"] = _add_icon("speed", spd.get("buff_name", "SoW"))
	var haste := BuffManager.get_haste_buff()
	if not haste.is_empty():
		_timer_labels["haste"] = _add_icon("haste", haste.get("buff_name", "Haste"))
	var mp_r := BuffManager.get_mp_regen_buff()
	if not mp_r.is_empty():
		_timer_labels["mp_regen"] = _add_icon("mp_regen", mp_r.get("buff_name", "Clarity"))
	var stat := BuffManager.get_stat_buff()
	if not stat.is_empty():
		_timer_labels["stat"] = _add_icon("stat", stat.get("buff_name", "Focused"))
	var pstat := BuffManager.get_primary_stat_buff()
	if not pstat.is_empty():
		_timer_labels["primary_stat"] = _add_icon("primary_stat", pstat.get("buff_name", "Bless"))
	var dshield := BuffManager.get_damage_shield()
	if not dshield.is_empty():
		_timer_labels["damage_shield"] = _add_icon("damage_shield", dshield.get("buff_name", "Thorns"))
	if BuffManager.is_stealthed():
		_timer_labels["stealth"] = _add_icon("stealth", "Hidden")
	if BuffManager.is_lich_form():
		_timer_labels["lich"] = _add_icon("lich", "Lich")

func _add_icon(type: String, spell_name: String) -> Label:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	match type:
		"hot":      style.border_color = Color(0.25, 0.65, 0.25)
		"absorb":   style.border_color = Color(0.30, 0.50, 0.90)
		"evade":    style.border_color = Color(0.80, 0.70, 0.20)
		"food":     style.border_color = Color(0.75, 0.45, 0.15)
		"drink":    style.border_color = Color(0.20, 0.55, 0.80)
		"speed":    style.border_color = Color(0.40, 0.85, 0.40)
		"haste":    style.border_color = Color(0.95, 0.85, 0.10)
		"mp_regen": style.border_color = Color(0.30, 0.50, 1.00)
		"stat":     style.border_color = Color(0.70, 0.40, 0.90)
		"primary_stat":  style.border_color = Color(0.95, 0.80, 0.35)
		"damage_shield": style.border_color = Color(0.85, 0.40, 0.20)
		"stealth":  style.border_color = Color(0.45, 0.45, 0.55)
		"lich":     style.border_color = Color(0.55, 0.10, 0.80)
		_:          style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	icon.add_theme_stylebox_override("panel", style)
	_hbox.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 2; vbox.offset_top = 2
	vbox.offset_right = -2; vbox.offset_bottom = -2
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = spell_name.left(7)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var timer_lbl := Label.new()
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.add_theme_font_size_override("font_size", 10)
	timer_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(timer_lbl)
	return timer_lbl

func _update_timers() -> void:
	for key in _timer_labels:
		var lbl: Label = _timer_labels[key]
		if key == "absorb":
			lbl.text = "%dhp" % int(BuffManager.get_absorb_hp())
		elif key == "evade":
			lbl.text = "%ds" % ceili(BuffManager.get_evade_remaining())
		elif key == "food":
			var f := BuffManager.get_food_buff()
			if not f.is_empty():
				lbl.text = "%ds" % ceili(f.remaining)
		elif key == "drink":
			var d := BuffManager.get_drink_buff()
			if not d.is_empty():
				lbl.text = "%ds" % ceili(d.remaining)
		elif key.begins_with("hot:"):
			var sname: String = key.substr(4)
			for h in BuffManager.get_hots():
				if h.spell_name == sname:
					lbl.text = "%ds" % ceili(h.remaining)
					break
		elif key == "speed":
			var b := BuffManager.get_speed_buff()
			if not b.is_empty():
				lbl.text = "%ds" % ceili(b.remaining)
		elif key == "haste":
			var b := BuffManager.get_haste_buff()
			if not b.is_empty():
				lbl.text = "%ds" % ceili(b.remaining)
		elif key == "mp_regen":
			var b := BuffManager.get_mp_regen_buff()
			if not b.is_empty():
				lbl.text = "%ds" % ceili(b.remaining)
		elif key == "stat":
			var b := BuffManager.get_stat_buff()
			if not b.is_empty():
				lbl.text = "%ds" % ceili(b.remaining)
		elif key == "primary_stat":
			var b := BuffManager.get_primary_stat_buff()
			if not b.is_empty():
				lbl.text = "%ds" % ceili(b.remaining)
		elif key == "damage_shield":
			var b := BuffManager.get_damage_shield()
			if not b.is_empty():
				lbl.text = "%ds" % ceili(b.remaining)
		elif key == "stealth":
			lbl.text = "%ds" % ceili(BuffManager.get_stealth_remaining())
		elif key == "lich":
			lbl.text = "ON"
