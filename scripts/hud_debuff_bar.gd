extends DraggablePanel

# Track 6 — server-driven debuff strip. Subscribes to BuffSnapshot for
# the local player and filters to known CC spell names (mez / root /
# snare / silence / attack_slow). Sits to the right of the buff bar by
# default. Server is authoritative for CC duration, so the icons tick
# down based on the latest snapshot's remaining.

const _CC_SPELL_NAMES := {
	"Mesmerize": "mez",
	"Ensnare": "root",
	"Immobilize": "root",
	"Ensnaring Roots": "root",
	"Snare": "snare",
	"Slow": "attack_slow",
	"Torpor": "attack_slow",
	"Aria of Dismay": "attack_slow",
	"Spellbreak": "silence",
}

var _hbox: HBoxContainer = null
# {spell_name -> {label: Label, remaining: float}}
var _entries: Dictionary = {}

func _ready() -> void:
	anchor_left   = 0.0
	anchor_top    = 1.0
	anchor_right  = 0.0
	anchor_bottom = 1.0
	offset_left   = 320.0
	offset_right  = 620.0
	offset_bottom = -152.0
	offset_top    = -200.0
	clip_contents = true

	apply_style(Color(0.04, 0.02, 0.02, 0.70), UITheme.C_BORDER)

	_hbox = HBoxContainer.new()
	_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hbox.offset_left = 3; _hbox.offset_top = 3
	_hbox.offset_right = -3; _hbox.offset_bottom = -3
	_hbox.add_theme_constant_override("separation", 4)
	add_child(_hbox)

	Net.world_buff_snapshot.connect(_on_buff_snapshot)

func _process(delta: float) -> void:
	for key in _entries:
		var entry: Dictionary = _entries[key]
		entry.remaining = maxf(0.0, entry.remaining - delta)
		(entry.label as Label).text = "%ds" % ceili(entry.remaining)

func _on_buff_snapshot(target: int, names: PackedStringArray, durations: PackedFloat32Array) -> void:
	if target != Net.get_player_id():
		return
	var server_set: Dictionary = {}
	for i in names.size():
		var nm: String = names[i]
		if not _CC_SPELL_NAMES.has(nm):
			continue
		var dur: float = durations[i] if i < durations.size() else 0.0
		server_set[nm] = dur
	# Remove entries no longer present.
	var to_remove: Array = []
	for key in _entries:
		if not server_set.has(key):
			to_remove.append(key)
	for key in to_remove:
		(_entries[key].icon as Node).queue_free()
		_entries.erase(key)
	# Add/update entries.
	for nm in server_set.keys():
		if _entries.has(nm):
			_entries[nm].remaining = server_set[nm]
		else:
			var icon := _add_icon(nm, _CC_SPELL_NAMES[nm])
			_entries[nm] = {"icon": icon[0], "label": icon[1], "remaining": server_set[nm]}

func _add_icon(spell_name: String, kind: String) -> Array:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.04, 0.04, 0.85)
	match kind:
		"mez":         style.border_color = Color(0.75, 0.30, 0.85)
		"root":        style.border_color = Color(0.50, 0.30, 0.10)
		"snare":       style.border_color = Color(0.75, 0.55, 0.25)
		"attack_slow": style.border_color = Color(0.45, 0.65, 0.85)
		"silence":     style.border_color = Color(0.85, 0.85, 0.20)
		_:             style.border_color = UITheme.C_BORDER
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
	timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.7))
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(timer_lbl)
	return [icon, timer_lbl]
