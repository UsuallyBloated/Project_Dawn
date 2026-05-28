extends DraggablePanel
class_name InspectWindow

# Read-only paperdoll view of another player's equipped items. Opened
# by the /inspect command or HUD wire-up; populated by the
# `Net.world_inspect_result` signal. Bag contents are not exposed —
# only the 9 paperdoll slots are public.

# Slot order matches the EquipSlot discriminants on the wire
# (server's protocol.rs ChatChannel comment lists them). Display labels
# are paired here so the row layout is data-driven.
const SLOT_LABELS: Array[String] = [
	"Weapon",   # 0
	"Offhand",  # 1
	"Head",     # 2
	"Chest",    # 3
	"Legs",     # 4
	"Feet",     # 5
	"Hands",    # 6
	"Ring",     # 7
	"Neck",     # 8
]

const C_TITLE_BG := Color(0.10, 0.08, 0.05, 0.95)
const C_EMPTY    := Color(0.55, 0.55, 0.55)

var _title_label: Label = null
var _name_label: Label = null
var _close_btn: Button = null
var _slot_value_labels: Array[Label] = []
var _current_target_char_id: int = 0

func _ready() -> void:
	apply_style()
	setup(Vector2(440, 120), Vector2(260, 320))
	_build_ui()
	Net.world_inspect_result.connect(_on_inspect_result)

func _build_ui() -> void:
	var title_bg := ColorRect.new()
	title_bg.color = C_TITLE_BG
	title_bg.anchor_left = 0.0; title_bg.anchor_right = 1.0
	title_bg.offset_left = 1; title_bg.offset_right = -1
	title_bg.offset_top = 1; title_bg.offset_bottom = 20
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_bg)

	_title_label = Label.new()
	_title_label.text = "Inspect"
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", UITheme.C_TITLE)
	_title_label.anchor_left = 0.0; _title_label.anchor_right = 1.0
	_title_label.offset_left = 6; _title_label.offset_right = -24
	_title_label.offset_top = 2; _title_label.offset_bottom = 20
	_title_label.clip_text = true
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "×"
	_close_btn.flat = true
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.anchor_left = 1.0; _close_btn.anchor_right = 1.0
	_close_btn.offset_left = -20; _close_btn.offset_right = -2
	_close_btn.offset_top = 1; _close_btn.offset_bottom = 20
	_close_btn.pressed.connect(func(): visible = false)
	add_child(_close_btn)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", UITheme.C_TITLE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.anchor_left = 0.0; _name_label.anchor_right = 1.0
	_name_label.offset_left = 6; _name_label.offset_right = -6
	_name_label.offset_top = 26; _name_label.offset_bottom = 46
	_name_label.clip_text = true
	add_child(_name_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	grid.anchor_left = 0.0; grid.anchor_right = 1.0
	grid.offset_left = 12; grid.offset_right = -12
	grid.offset_top = 52; grid.offset_bottom = -8
	add_child(grid)

	for label_text in SLOT_LABELS:
		var slot_label := Label.new()
		slot_label.text = label_text
		slot_label.add_theme_font_size_override("font_size", 12)
		slot_label.add_theme_color_override("font_color", UITheme.C_TEXT)
		grid.add_child(slot_label)

		var value_label := Label.new()
		value_label.text = "—"
		value_label.add_theme_font_size_override("font_size", 12)
		value_label.add_theme_color_override("font_color", C_EMPTY)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.clip_text = true
		grid.add_child(value_label)
		_slot_value_labels.append(value_label)

func open_for(target_char_id: int, target_name: String) -> void:
	# Show a "waiting for server" view immediately so the user gets
	# feedback even before the InspectResult arrives.
	_current_target_char_id = target_char_id
	_title_label.text = "Inspect: %s" % target_name if target_name != "" else "Inspect"
	_name_label.text = "%s..." % target_name if target_name != "" else "Loading..."
	_clear_slots()
	visible = true

func _on_inspect_result(
	target_char_id: int,
	target_name: String,
	slot_keys: PackedInt32Array,
	item_paths: PackedStringArray,
) -> void:
	# Race-safety: if a second inspect lands on a different target while
	# this window is showing, only honour the one we're currently waiting
	# on. (Drop replies for stale requests.)
	if target_char_id != _current_target_char_id:
		return
	if target_name == "" and slot_keys.is_empty():
		_name_label.text = "(target not in world)"
		_clear_slots()
		return
	_title_label.text = "Inspect: %s" % target_name
	_name_label.text = target_name
	_clear_slots()
	for i in slot_keys.size():
		var slot: int = slot_keys[i]
		if slot < 0 or slot >= _slot_value_labels.size():
			continue
		var path: String = item_paths[i] if i < item_paths.size() else ""
		var item_name := _resolve_item_name(path)
		var lbl := _slot_value_labels[slot]
		lbl.text = item_name
		lbl.add_theme_color_override("font_color", UITheme.C_TEXT)

func _clear_slots() -> void:
	for lbl in _slot_value_labels:
		lbl.text = "—"
		lbl.add_theme_color_override("font_color", C_EMPTY)

func _resolve_item_name(path: String) -> String:
	if path == "" or not ResourceLoader.exists(path):
		return path  # show raw path as a fallback
	var item := load(path) as ItemData
	if item == null or item.item_name == "":
		return path
	return item.item_name
