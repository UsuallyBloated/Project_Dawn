class_name DialogueNPC
extends FriendlyNPC

@export var npc_name: String = ""
@export var npc_title: String = ""

func _register() -> void:
	add_to_group("dialogue_npcs")

func _display_name() -> String:
	return npc_name

func _on_player_nearby(is_near: bool) -> void:
	if is_near:
		DialogueManager.register_nearby(self)
	else:
		DialogueManager.unregister_nearby(self)
