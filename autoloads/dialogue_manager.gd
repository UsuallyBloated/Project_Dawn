extends Node

signal dialogue_opened(npc_name: String)

var nearby_npc: Node = null

func register_nearby(npc: Node) -> void:
	nearby_npc = npc

func unregister_nearby(npc: Node) -> void:
	if nearby_npc == npc:
		nearby_npc = null

func open_nearby() -> void:
	if nearby_npc == null:
		return
	dialogue_opened.emit(nearby_npc.npc_name)
