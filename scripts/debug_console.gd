extends Control
class_name DebugConsole

# In-game tail of DebugLog. Subscribes to DebugLog.line_emitted plus
# seeds from DebugLog.recent_lines on open. Toggle visibility from
# hud.gd (backtick `, or /console). No file IO; everything is in-memory
# so this stays useful even if DebugLog's FileAccess is borked.
#
# Built entirely in code (no .tscn) so the HUD's preload doesn't fail
# on first-touch before Godot has imported the scene file.

const MAX_VISIBLE_LINES := 2000

var _bg: ColorRect = null
var _scroll: ScrollContainer = null
var _log_label: RichTextLabel = null

func _ready() -> void:
	_build_ui()
	visible = false
	# Seed from whatever DebugLog has accumulated before this scene
	# was open. Caller (hud.gd) calls toggle() on backtick (`).
	for entry in DebugLog.recent_lines:
		_append_line(entry["text"], entry["level"])
	DebugLog.line_emitted.connect(_on_line_emitted)

func _build_ui() -> void:
	# Fixed pixel-position panel so anchor calc against an unsized
	# CanvasLayer parent can't make it 0×0 invisible. Upper-left
	# corner, ~960×540, plenty visible.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100  # ensure on top of other HUD elements when open

	const PANEL_X := 60
	const PANEL_Y := 60
	const PANEL_W := 960
	const PANEL_H := 540

	# Border (drawn under the BG, peeks out 2px on each side).
	var border := ColorRect.new()
	border.color = Color(0.30, 0.45, 0.65, 1.0)
	border.position = Vector2(PANEL_X - 2, PANEL_Y - 2)
	border.size = Vector2(PANEL_W + 4, PANEL_H + 4)
	add_child(border)

	_bg = ColorRect.new()
	_bg.color = Color(0.04, 0.04, 0.06, 0.98)
	_bg.position = Vector2(PANEL_X, PANEL_Y)
	_bg.size = Vector2(PANEL_W, PANEL_H)
	add_child(_bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(8, 6)
	vbox.size = Vector2(PANEL_W - 16, PANEL_H - 12)
	_bg.add_child(vbox)

	var title := Label.new()
	title.text = "Debug Console — ` toggle, ESC closes, /console in chat"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_log_label = RichTextLabel.new()
	# fit_content lets the label grow to fit its lines so the outer
	# ScrollContainer can actually scroll. SIZE_EXPAND_FILL on the
	# vertical axis would clamp it to the viewport and kill scroll —
	# only the horizontal axis gets it.
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.size_flags_vertical = 0
	_log_label.fit_content = true
	_log_label.bbcode_enabled = true
	_log_label.scroll_active = false
	_log_label.selection_enabled = true
	_log_label.add_theme_font_size_override("normal_font_size", 11)
	_log_label.add_theme_color_override("default_color", Color(0.92, 0.92, 0.95))
	_scroll.add_child(_log_label)

func toggle() -> void:
	visible = not visible
	if visible:
		_scroll_to_bottom()

func _on_line_emitted(text: String, level: String) -> void:
	# Only auto-snap to bottom if the user is already there. Scrolled
	# up to read older lines? Stay parked, don't yank the view down.
	var was_at_bottom := _is_at_bottom()
	_append_line(text, level)
	if visible and was_at_bottom:
		_scroll_to_bottom()

func _is_at_bottom() -> bool:
	if _scroll == null:
		return true
	var bar := _scroll.get_v_scroll_bar()
	if bar == null:
		return true
	# 8 px tolerance so a not-quite-pixel-perfect position still counts
	# as "at bottom" (rounding from int scroll_vertical vs float max).
	return _scroll.scroll_vertical >= int(bar.max_value - bar.page) - 8

func _append_line(text: String, level: String) -> void:
	if _log_label == null:
		return
	var color := _color_for_level(level)
	_log_label.push_color(color)
	_log_label.add_text(text)
	_log_label.pop()
	_log_label.newline()
	# Cap the buffer so the RichTextLabel doesn't grow unbounded.
	# Each line is one paragraph, so trimming by paragraph count is
	# the cleanest knob.
	while _log_label.get_paragraph_count() > MAX_VISIBLE_LINES:
		_log_label.remove_paragraph(0)

func _color_for_level(level: String) -> Color:
	match level:
		"ERROR":  return Color(1.0, 0.45, 0.45)
		"WARN":   return Color(1.0, 0.85, 0.4)
		"COMBAT": return Color(0.7, 0.85, 1.0)
		_:        return Color(0.85, 0.85, 0.88)

func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	# Two-frame wait gives the RichTextLabel time to lay out the new
	# line before we snap the scroll bar to the bottom. One frame
	# isn't always enough.
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		var bar := _scroll.get_v_scroll_bar()
		if bar != null:
			_scroll.scroll_vertical = int(bar.max_value)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
