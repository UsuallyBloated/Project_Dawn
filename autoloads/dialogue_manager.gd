extends Node

signal dialogue_opened(npc_name: String)

# nearby_npc is set by proximity (DialogueNPC body_entered/exited) and used as
# a fallback when callers don't have an explicit reference. Prefer open_for()
# when you do — it avoids stale state from the proximity tracker.
var nearby_npc: Node = null

func register_nearby(npc: Node) -> void:
	nearby_npc = npc

func unregister_nearby(npc: Node) -> void:
	if nearby_npc == npc:
		nearby_npc = null

func open_for(npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	dialogue_opened.emit(npc.npc_name)

func open_nearby() -> void:
	open_for(nearby_npc)
