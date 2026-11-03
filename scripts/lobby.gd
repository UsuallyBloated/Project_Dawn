extends Control

# The lobby: the screen between the login screen's Play and the world. Net is
# already connecting by the time it loads (login.gd hands the world token over
# in process); this scene waits for the app-layer ConnectOk, applies the
# server's character to PlayerStats, then shows Enter World. A drop before
# Enter World shows the reason and, for a kick that named one, a live relogin
# countdown.

const GAME_SCENE := "res://scenes/world.tscn"

@onready var status_label: Label = %StatusLabel
@onready var enter_world_btn: Button = %EnterWorldButton

func _ready() -> void:
	# The countdown's _process runs only while a kick's relogin time ticks.
	set_process(false)
	enter_world_btn.visible = false
	status_label.text = "Connecting to world..."
	Net.app_connected.connect(_on_app_connected)
	Net.app_disconnected.connect(_on_app_disconnected)
	# The Net autoload runs _ready before scenes load, so the app-layer
	# Connect handshake may already have completed by the time we get here.
	if Net.is_app_ready():
		_on_app_connected(Net.get_player_id())

func _on_app_connected(_player_id: int) -> void:
	# Initialize PlayerStats from the server-authoritative identity carried
	# in ConnectOk. Without this the character lands in world.tscn with no
	# class set — no spells, no skills, default base stats. Race/class/level
	# come from the DB-loaded CharacterSpawn on the server side.
	var cls := Net.get_own_class()
	var race := Net.get_own_race()
	var lvl := Net.get_own_level()
	var pname := Net.get_own_name()
	if cls != "" and race != "":
		PlayerStats.player_name = pname
		PlayerStats.apply_character(race, cls, lvl)
	status_label.text = "Connected. Click Enter World to begin."
	enter_world_btn.visible = true

func _on_app_disconnected(reason: String) -> void:
	enter_world_btn.visible = false
	_disconnect_reason = reason
	_show_disconnect()

# The live relogin countdown. When the kick named a time (a duplicate login
# refused while the old body lingers), the server's one-shot "You can try again
# in about Ns." is replaced by a line that ticks down to "now"; with no time,
# the reason shows as the server wrote it.
var _disconnect_reason := ""
var _countdown_shown := -2

func _show_disconnect() -> void:
	var remaining := Net.get_kick_retry_remaining()
	_countdown_shown = remaining
	if remaining < 0:
		status_label.text = "Disconnected: %s" % _disconnect_reason
		set_process(false)
		return
	var reason := _strip_server_retry(_disconnect_reason)
	if remaining > 0:
		status_label.text = "Disconnected: %s You can log in again in %d s." % [reason, remaining]
		set_process(true)
	else:
		status_label.text = "Disconnected: %s You can log in again now." % reason
		set_process(false)

# Drop the server's own "about Ns" sentence, which the live line replaces.
# Matched on its exact wording (tick.rs, the duplicate-login refusal); if the
# wording ever changes, the old sentence simply stays beside the countdown.
func _strip_server_retry(reason: String) -> String:
	var re := RegEx.new()
	re.compile(" You can try again in about \\d+s\\.")
	return re.sub(reason, "")

func _process(_delta: float) -> void:
	if Net.get_kick_retry_remaining() != _countdown_shown:
		_show_disconnect()

func _on_enter_world_pressed() -> void:
	# Track 4 follow-up E: tell the server we've left the lobby. Server
	# gates EntitySpawn / Position fan-out on this so other players don't
	# see our static body while we're still on the Enter World screen.
	# Idempotent server-side; safe even if app_disconnect / reconnect
	# replays this path.
	if Net.is_app_ready():
		Net.send_enter_world()
	get_tree().change_scene_to_file(GAME_SCENE)
