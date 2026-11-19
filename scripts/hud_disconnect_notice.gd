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

@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _reason: Label = $Panel/Margin/VBox/Reason
@onready var _hint: Label = $Panel/Margin/VBox/Hint
@onready var _quit_btn: Button = $Panel/Margin/VBox/QuitBtn

# The frame is scenes/hud_disconnect_notice.tscn: a full-screen dim (anchors
# and offsets both, so it has a real size under a CanvasLayer) that swallows
# clicks, drawn above the death screen (z 110: being disconnected outranks
# being dead; picking ignores z_index, so the notice also moves to the front
# of the tree when it shows, see _on_disconnected), with the panel centred.
func _ready() -> void:
	# A window raised while the notice is up goes back beneath it.
	add_to_group(DraggablePanel.MODAL_OVERLAY_GROUP)
	_title.text = TITLE
	_hint.text = RELOGIN_HINT
	_quit_btn.pressed.connect(func(): get_tree().quit())
	Net.app_disconnected.connect(_on_disconnected)

# Nothing behind the notice can be used, the keyboard included: I, B and the
# rest open windows from hud._unhandled_input, and a window opened under the
# notice would otherwise be picked over it.
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		get_viewport().set_input_as_handled()

func _on_disconnected(reason: String) -> void:
	var text := reason.strip_edges()
	_reason.text = text if text != "" else NO_REASON
	visible = true
	move_to_front()
	DebugLog.warn("World connection ended: %s" % _reason.text)
	# The same line in chat, so it is still on screen in the log behind the
	# notice and lands in any chat window the player kept open.
	CombatLog.add_line("Disconnected: %s" % _reason.text, CombatLog.MsgType.INFO)
