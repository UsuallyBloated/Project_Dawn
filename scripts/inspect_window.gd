extends DraggablePanel
class_name InspectWindow

# Read-only paperdoll view of another player's equipped items. Opened
# by the /inspect command or HUD wire-up; populated by the
# `Net.world_inspect_result` signal. Bag contents are not exposed —
# only the 10 paperdoll slots are public. The frame (title bar, close
# button, name line, the slot grid) is scenes/inspect_window.tscn; this
# script fills the grid and the names.

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
	"Ammo",     # 9
]

const C_EMPTY    := Color(0.55, 0.55, 0.55)

@onready var _title_label: Label = $TitleLabel
@onready var _name_label: Label = $NameLabel
@onready var _close_btn: Button = $CloseBtn
@onready var _grid: GridContainer = $Grid
var _slot_value_labels: Array[Label] = []
var _current_target_char_id: int = 0

func _ready() -> void:
	_close_btn.pressed.connect(func(): visible = false)
	_build_rows()
	Net.world_inspect_result.connect(_on_inspect_result)

# One row per paperdoll slot, from SLOT_LABELS, so the list is data-driven.
func _build_rows() -> void:
	var grid := _grid
	for label_text in SLOT_LABELS:
		var slot_label := Label.new()
		slot_label.text = label_text
		slot_label.add_theme_font_size_override("font_size", 12)
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
