class_name DialogueNPC
extends Area3D

@export var npc_name: String = ""
@export var npc_title: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("dialogue_npcs")
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.text = npc_name

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		DialogueManager.register_nearby(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		DialogueManager.unregister_nearby(self)
