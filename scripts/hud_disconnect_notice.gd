extends ColorRect

# The "you are no longer connected" notice. When the world connection ends
# while the player is in the world (a server kick, a ban, a server restart, a
# dropped network), the world simply stops: mobs freeze, chat goes quiet, and
# until this existed nothing said why. This dims the screen, shows the
# server's reason when it gave one, and offers the only honest next step.
#
# There is no return-to-character-select flow yet, so the button quits; the
# player relaunches to come back. A `/camp` never reaches here: it quits on
# its own before any disconnect arrives.

const TITLE := "Disconnected"
const NO_REASON := "The connection to the server was lost."
# After an unclean exit the character lingers in the world and a relogin is
# refused until it is gone (README_FOR_TESTERS says up to about 45 seconds).
const RELOGIN_HINT := "Your character stays in the world for a short while after a disconnect. If logging back in is refused, wait about 45 seconds and try again."

var _title: Label
var _reason: Label
var _hint: Label
var _quit_btn: Button

func _ready() -> void:
	color = Color(0.0, 0.0, 0.0, 0.6)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Above the death screen (z 100): being disconnected outranks being dead.
	z_index = 110
	# Swallow clicks so nothing behind the notice can be used; the world is
	# not listening any more.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460.0, 0.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title = Label.new()
	_title.text = TITLE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", UITheme.C_TITLE)
	vbox.add_child(_title)

	_reason = Label.new()
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_reason)

	_hint = Label.new()
	_hint.text = RELOGIN_HINT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.7)
	vbox.add_child(_hint)

	_quit_btn = Button.new()
	_quit_btn.text = "Quit"
	_quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quit_btn.custom_minimum_size = Vector2(120.0, 0.0)
	_quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(_quit_btn)

	Net.app_disconnected.connect(_on_disconnected)

func _on_disconnected(reason: String) -> void:
	var text := reason.strip_edges()
	_reason.text = text if text != "" else NO_REASON
	visible = true
	DebugLog.warn("World connection ended: %s" % _reason.text)
	# The same line in chat, so it is still on screen in the log behind the
	# notice and lands in any chat window the player kept open.
	CombatLog.add_line("Disconnected: %s" % _reason.text, CombatLog.MsgType.INFO)
