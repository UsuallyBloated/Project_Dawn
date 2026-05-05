extends Control

const GAME_SCENE   := "res://scenes/world.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon_world.tscn"
const CHAR_CREATION_SCENE := "res://scenes/character_creation.tscn"

@onready var address_field: LineEdit = %AddressField
@onready var port_field: LineEdit = %PortField
@onready var status_label: Label = %StatusLabel
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton

func _ready() -> void:
	Network.is_test_room = false
	multiplayer.connected_to_server.connect(_on_connected)
	Network.connection_failed.connect(_on_connection_failed)
	Network.server_disconnected.connect(_on_server_disconnected)

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
