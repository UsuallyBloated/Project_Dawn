extends Control

const GAME_SCENE   := "res://scenes/world.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon_world.tscn"
const CHAR_CREATION_SCENE := "res://scenes/character_creation.tscn"

@onready var address_field: LineEdit = %AddressField
@onready var port_field: LineEdit = %PortField
@onready var status_label: Label = %StatusLabel
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var solo_btn: Button = %SoloButton
@onready var test_room_btn: Button = %TestRoomButton
@onready var test_dungeon_btn: Button = %TestDungeonButton
@onready var delete_save_btn: Button = %DeleteSaveButton
@onready var enter_world_btn: Button = %EnterWorldButton

# Local buttons that drive the legacy ENet / single-player flow. Hidden when
# Net is in launcher mode (a server-authoritative session is already live);
# re-shown if the world connection drops, so the user can fall back to
# offline play.
@onready var _local_buttons: Array[Control] = [
	address_field, port_field,
	solo_btn, host_btn, join_btn,
	test_room_btn, test_dungeon_btn, delete_save_btn,
]

func _ready() -> void:
	Network.is_test_room = false
	multiplayer.connected_to_server.connect(_on_connected)
	Network.connection_failed.connect(_on_connection_failed)
	Network.server_disconnected.connect(_on_server_disconnected)

	if Net.is_launcher_mode():
		_setup_launcher_mode()

func _on_solo_pressed() -> void:
	Network.is_online = false
	get_tree().change_scene_to_file(CHAR_CREATION_SCENE)

func _on_host_pressed() -> void:
	var port := int(port_field.text) if port_field.text.is_valid_int() else Network.DEFAULT_PORT
	var err := Network.host_game(port)
	if err != OK:
		status_label.text = "Failed to host: " + error_string(err)
		return
	status_label.text = "Hosting on port %d" % port
	get_tree().change_scene_to_file(CHAR_CREATION_SCENE)

func _on_join_pressed() -> void:
	var address := address_field.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var port := int(port_field.text) if port_field.text.is_valid_int() else Network.DEFAULT_PORT
	var err := Network.join_game(address, port)
	if err != OK:
		status_label.text = "Failed to connect: " + error_string(err)
		return
	status_label.text = "Connecting..."
	host_btn.disabled = true
	join_btn.disabled = true

func _on_connected() -> void:
	get_tree().change_scene_to_file(CHAR_CREATION_SCENE)

func _on_connection_failed() -> void:
	status_label.text = "Connection failed."
	host_btn.disabled = false
	join_btn.disabled = false

func _on_server_disconnected() -> void:
	status_label.text = "Server disconnected."
	host_btn.disabled = false
	join_btn.disabled = false

func _on_test_room_pressed() -> void:
	Network.is_online = false
	Network.is_test_room = true
	_setup_default_character()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_test_dungeon_pressed() -> void:
	Network.is_online = false
	Network.is_test_room = true
	_setup_default_character()
	get_tree().change_scene_to_file(DUNGEON_SCENE)

const TEST_CHARACTER_NAME  := "Chortle"
const TEST_CHARACTER_RACE  := "Troll"
const TEST_CHARACTER_CLASS := "Shadow Knight"
const TEST_CHARACTER_LEVEL := 50

func _setup_default_character() -> void:
	if SaveManager.load_save():
		return
	PlayerStats.player_name = TEST_CHARACTER_NAME
	PlayerStats.apply_character(TEST_CHARACTER_RACE, TEST_CHARACTER_CLASS, TEST_CHARACTER_LEVEL)

func _on_delete_save_pressed() -> void:
	if SaveManager.has_save():
		SaveManager.delete_save()
		status_label.text = "Save deleted."
	else:
		status_label.text = "No save to delete."

# ─── Launcher-mode flow ─────────────────────────────────────────────
# When the game was spawned by the launcher, Net is already (or about to be)
# connected to the world server. The local-mode buttons all assume offline /
# legacy-ENet state and would put the player into an incoherent session
# (e.g. clicking Test Dungeon teleports X/Z to whatever world.tscn position
# the server has saved, dropping the player off the dungeon's floor mesh).
# Hide the local UI, wait for the app-layer Connect handshake, then show an
# Enter World button. If the connection drops before/after that, fall back
# to local-save mode so offline dev iteration still works.

func _setup_launcher_mode() -> void:
	for control in _local_buttons:
		control.visible = false
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
	status_label.text = "Disconnected: %s. You can play offline if you wish." % reason
	for control in _local_buttons:
		control.visible = true

func _on_enter_world_pressed() -> void:
	# Legacy ENet flags must be in a known state — they're irrelevant in
	# launcher mode but world.gd / its children still read them.
	Network.is_online = false
	Network.is_test_room = false
	# Track 4 follow-up E: tell the server we've left the lobby. Server
	# gates EntitySpawn / Position fan-out on this so other players don't
	# see our static body while we're still on the Enter World screen.
	# Idempotent server-side; safe even if app_disconnect / reconnect
	# replays this path.
	if Net.is_app_ready():
		Net.send_enter_world()
	get_tree().change_scene_to_file(GAME_SCENE)
