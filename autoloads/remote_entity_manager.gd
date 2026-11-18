extends Node
class_name RemoteEntityManager

# RemoteEntityManager: what the five managers of server-driven bodies share
# (RemotePlayerManager, RemoteEnemyManager, RemotePetManager,
# RemoteLootBagManager, RemoteCorpseManager): the two maps with their two
# lifetimes, the lookup by id, the rule for when a scene can host the bodies,
# and the sweep that clears them. Lifted out of the five on 2026-11-18 (R3).
# Each manager still wires its own Net signals in _ready, builds its own node
# in _instantiate_into and routes its own id partition.
#
# Two maps, two lifetimes:
#   _spawn_data — last known identity and pose per id (the spawn dict each
#       manager records). Survives scene swaps (autoload-scoped); the source
#       of truth for re-instantiation when the scene tree shifts under us.
#   _by_id — the live node per id, parented under the current scene's root
#       so it dies with the scene on transition; rehydrated from _spawn_data
#       when the next scene hosts the local player.
var _spawn_data: Dictionary = {}
var _by_id: Dictionary = {}

# Public accessor (Track 21B): the target-of-target frame and the damage
# shield path resolve a server-sent id back to its live node.
func get_by_id(id: int) -> Node:
	return _by_id.get(id)

# A scene "hosts the local player" once player.gd._ready has run and
# added the player to the "player" group. Picks out world.tscn (and any
# future 3D zones that follow the same pattern) without hard-coding a
# scene path.
func _scene_hosts_local_player(_scene: Node) -> bool:
	return get_tree().get_first_node_in_group("player") != null

# Defensive — call before zone swaps if needed. Scene change already
# frees the children when the parent scene goes away.
func clear_all() -> void:
	for id in _by_id:
		var node = _by_id[id]
		if is_instance_valid(node):
			node.queue_free()
	_by_id.clear()
	_spawn_data.clear()
