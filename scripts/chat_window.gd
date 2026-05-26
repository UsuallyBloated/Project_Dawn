extends DraggablePanel
class_name ChatWindow

# Per-window chat output panel. Subscribes to CombatLog.line_added and
# gates each line through `filters` (a per-window MsgType allow-list)
# before rendering. The chat input bar at the bottom is owned by this
# window — pressing Enter focuses the active window's input.

signal window_renamed(id: int, new_name: String)
signal close_requested(id: int)
signal context_menu_requested(id: int, screen_pos: Vector2)
signal focus_requested(id: int)
signal text_submitted(id: int, text: String)

const MAX_LINES   := 200
const LINE_FONT_SZ := 12
const TITLE_FONT_SZ := 11
const TITLE_BAR_H := 18
const INPUT_BAR_H := 28

const C_BG       := Color(0.04, 0.03, 0.02, 0.80)
const C_BORDER   := Color(0.20, 0.15, 0.05)
const C_TITLE_BG := Color(0.10, 0.08, 0.05, 0.95)
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

var window_id: int = 0
var window_name: String = "Chat"
# Per-window MsgType filter set. Keys are FILTER_KEYS values; values are
# bool. Missing keys default to enabled so that layouts saved before
# chunk 2 still show everything on load.
var filters: Dictionary = {}

var _title_label: Label = null
var _scroll: ScrollContainer = null
var _msg_vbox: VBoxContainer = null
var _back_btn: Button = null
var _chat_input: LineEdit = null
var _auto_scroll: bool = true

# Filter keys used in the `filters` dict and persisted to settings.cfg.
# Index of each entry MUST match the corresponding `CombatLog.MsgType`
# enum value — that's how `_filter_key_for(type)` resolves an incoming
# line's type to its filter key. Strings (not ints) are persisted so
# settings.cfg stays human-readable and survives enum reorderings IF
# this array is reordered to match.
const FILTER_KEYS: Array[String] = [
	"damage_out",  # MsgType.DAMAGE_OUT
	"damage_in",   # MsgType.DAMAGE_IN
	"heal",        # MsgType.HEAL
	"info",        # MsgType.INFO
	"level_up",    # MsgType.LEVEL_UP
	"loot",        # MsgType.LOOT
	"evade",       # MsgType.EVADE
	"say",         # MsgType.SAY
	"shout",       # MsgType.SHOUT
	"ooc",         # MsgType.OOC
	"tell_out",    # MsgType.TELL_OUT
	"tell_in",     # MsgType.TELL_IN
	"group_chat",  # MsgType.GROUP_CHAT
	"crit",        # MsgType.CRIT
]

static func default_filters() -> Dictionary:
	var d: Dictionary = {}
	for key in FILTER_KEYS:
		d[key] = true
	return d

func _ready() -> void:
	apply_style(C_BG, C_BORDER)
	if filters.is_empty():
		filters = default_filters()
	_build_title_bar()
	_build_scroll()
	_build_back_button()
	_build_chat_input()
	CombatLog.line_added.connect(add_line)

func _build_title_bar() -> void:
	var title_bg := ColorRect.new()
	title_bg.color = C_TITLE_BG
	title_bg.anchor_left = 0.0; title_bg.anchor_right = 1.0
	title_bg.anchor_top = 0.0; title_bg.anchor_bottom = 0.0
	title_bg.offset_left = 1; title_bg.offset_right = -1
	title_bg.offset_top = 1; title_bg.offset_bottom = TITLE_BAR_H
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_bg)

	_title_label = Label.new()
	_title_label.text = window_name
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	_title_label.anchor_left = 0.0; _title_label.anchor_right = 1.0
	_title_label.offset_left = 6; _title_label.offset_right = -6
	_title_label.offset_top = 2; _title_label.offset_bottom = TITLE_BAR_H
	_title_label.clip_text = true
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

func _build_scroll() -> void:
	_scroll = ScrollContainer.new()
	_scroll.anchor_left = 0.0; _scroll.anchor_right = 1.0
	_scroll.anchor_top = 0.0; _scroll.anchor_bottom = 1.0
	_scroll.offset_left = 6; _scroll.offset_right = -6
	_scroll.offset_top = TITLE_BAR_H + 4
	_scroll.offset_bottom = -(INPUT_BAR_H + 2)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_msg_vbox = VBoxContainer.new()
	_msg_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_vbox.add_theme_constant_override("separation", 1)
	_scroll.add_child(_msg_vbox)

	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_value_changed)

func _build_back_button() -> void:
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
	add_child(_back_btn)

func _build_chat_input() -> void:
	_chat_input = LineEdit.new()
	_chat_input.anchor_left = 0.0; _chat_input.anchor_right = 1.0
	_chat_input.anchor_top = 1.0; _chat_input.anchor_bottom = 1.0
	_chat_input.offset_left = 6; _chat_input.offset_right = -6
	_chat_input.offset_top = -(INPUT_BAR_H + 2)
	_chat_input.offset_bottom = -2
	_chat_input.placeholder_text = "Press Enter to type..."
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_on_chat_text_submitted)
	_chat_input.focus_exited.connect(func(): _chat_input.visible = false)
	add_child(_chat_input)

func show_input() -> void:
	if _chat_input == null:
		return
	_chat_input.visible = true
	_chat_input.text = ""
	_chat_input.grab_focus()

func is_input_focused() -> bool:
	return _chat_input != null and _chat_input.has_focus()

func _on_chat_text_submitted(text: String) -> void:
	_chat_input.visible = false
	_chat_input.text = ""
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	text_submitted.emit(window_id, trimmed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			focus_requested.emit(window_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			focus_requested.emit(window_id)
			context_menu_requested.emit(window_id, get_global_mouse_position())
			accept_event()
			return
	super._gui_input(event)

func set_window_name(new_name: String) -> void:
	window_name = new_name
	if _title_label != null:
		_title_label.text = new_name
	window_renamed.emit(window_id, new_name)

func add_line(text: String, type: int) -> void:
	if _msg_vbox == null:
		return
	if not _passes_filter(type):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", LINE_FONT_SZ)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.add_theme_color_override("font_color", _color_for(type))
	_msg_vbox.add_child(lbl)

	if _msg_vbox.get_child_count() > MAX_LINES:
		_msg_vbox.get_child(0).queue_free()

	if _auto_scroll:
		_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	# A new label added to the VBox doesn't grow `v_scroll_bar.max_value`
	# until the container re-lays out next frame. Wait one frame so the
	# bar's max reflects the freshly-added content, then snap.
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _on_scroll_value_changed(value: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	_auto_scroll = value >= bar.max_value - bar.page
	_back_btn.visible = not _auto_scroll

func _on_back_to_bottom_pressed() -> void:
	_auto_scroll = true
	_back_btn.visible = false
	_scroll_to_bottom()

func get_layout() -> Dictionary:
	return {
		"id":      window_id,
		"name":    window_name,
		"x":       position.x,
		"y":       position.y,
		"w":       size.x,
		"h":       size.y,
		"filters": filters.duplicate(),
	}

func apply_layout(d: Dictionary) -> void:
	window_id = int(d.get("id", window_id))
	set_window_name(String(d.get("name", window_name)))
	position = Vector2(float(d.get("x", position.x)), float(d.get("y", position.y)))
	size = Vector2(float(d.get("w", size.x)), float(d.get("h", size.y)))
	var saved_filters = d.get("filters", null)
	if saved_filters is Dictionary:
		filters = _merge_filters_with_defaults(saved_filters)

func set_filters(new_filters: Dictionary) -> void:
	filters = _merge_filters_with_defaults(new_filters)

func _passes_filter(type: int) -> bool:
	return bool(filters.get(_filter_key_for(type), true))

func _filter_key_for(type: int) -> String:
	if type < 0 or type >= FILTER_KEYS.size():
		return "info"
	return FILTER_KEYS[type]

# Fold saved filters onto a fresh defaults dict so layouts written before
# a new MsgType was added still show the new category by default rather
# than silently hiding it.
func _merge_filters_with_defaults(saved: Dictionary) -> Dictionary:
	var merged := default_filters()
	for key in saved:
		if merged.has(key):
			merged[key] = bool(saved[key])
	return merged

func _color_for(type: int) -> Color:
	# Mirrors the legacy CombatLog._color_for switch. Kept here (not on
	# CombatLog) because rendering is per-window — future chunks add
	# per-window font tints that subclass or override this.
	match type:
		CombatLog.MsgType.DAMAGE_OUT: return C_DMG_OUT
		CombatLog.MsgType.DAMAGE_IN:  return C_DMG_IN
		CombatLog.MsgType.HEAL:       return C_HEAL
		CombatLog.MsgType.LEVEL_UP:   return C_LEVEL
		CombatLog.MsgType.LOOT:       return C_LOOT
		CombatLog.MsgType.EVADE:      return C_EVADE
		CombatLog.MsgType.SAY:        return C_SAY
		CombatLog.MsgType.SHOUT:      return C_SHOUT
		CombatLog.MsgType.OOC:        return C_OOC
		CombatLog.MsgType.TELL_OUT:   return C_TELL_OUT
		CombatLog.MsgType.TELL_IN:    return C_TELL_IN
		CombatLog.MsgType.GROUP_CHAT: return C_GROUP
		CombatLog.MsgType.CRIT:       return C_CRIT
		_:                            return C_INFO
