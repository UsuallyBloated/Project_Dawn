extends Control

const GAME_SCENE := "res://node_3d.tscn"
const CHAR_CREATION_SCENE := "res://scenes/character_creation.tscn"

@onready var address_field: LineEdit = %AddressField
@onready var port_field: LineEdit = %PortField
@onready var status_label: Label = %StatusLabel
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton

func _ready() -> void:
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
