extends Node

# RemotePlayerManager — owns the Dictionary[char_id → RemotePlayer node]
# for every other player visible to the local client. Listens to Net's
# coarse signals; instantiates / frees `remote_player.tscn` in response.
#
# The own player is rendered by world.tscn / player.tscn — this manager
# explicitly filters out broadcasts where `id == Net.get_player_id()`.
#
# Remote-player nodes are scene-scoped (parented under the current scene's
# root, not this autoload) so they are freed automatically on scene change.
# `clear_all()` is a defensive belt-and-suspenders for callers that want
# to force a clean slate (e.g. zone transitions before scene swap).

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")

var _by_id: Dictionary = {}  # int char_id -> RemotePlayer node

func _ready() -> void:
	Net.world_entity_spawn.connect(_on_entity_spawn)
	Net.world_entity_despawn.connect(_on_entity_despawn)
	Net.world_position.connect(_on_position)

func _on_entity_spawn(
		id: int,
		player_name: String,
		race: String,
		char_class: String,
		level: int,
		pos: Vector3,
		yaw: float) -> void:
	# Own-player spawn is handled by world.tscn instantiating player.tscn.
	# We get the broadcast too (server fan-out includes self for the
	# Position channel; spawn fan-out skips subject, so this branch is
	# defensive insurance against a future protocol change).
	if id == Net.get_player_id():
		return
	if _by_id.has(id):
		# Duplicate spawn (server-side bug or a stale message arriving
		# after a despawn). Replace silently.
		_by_id[id].queue_free()
		_by_id.erase(id)
	var rp := REMOTE_PLAYER_SCENE.instantiate()
	rp.char_id = id
	rp.player_name = player_name
	rp.race = race
	rp.player_class = char_class
	rp.level = level
	rp.global_position = pos
	rp.rotation.y = yaw
	_add_to_active_scene(rp)
	_by_id[id] = rp

func _on_entity_despawn(id: int) -> void:
	var rp = _by_id.get(id)
	if rp == null:
		return
	rp.queue_free()
	_by_id.erase(id)

func _on_position(id: int, pos: Vector3, _vel: Vector3, yaw: float, sequence: int) -> void:
	# Own-player position is handled by player.gd._on_world_position.
	if id == Net.get_player_id():
		return
	var rp = _by_id.get(id)
	if rp == null:
		# Position arrived before EntitySpawn (race across the reliable
		# and unreliable channels). Drop; the next Position after the
		# spawn arrives will land on the freshly-created node.
		return
	rp.on_position_update(pos, yaw, sequence)

func _add_to_active_scene(rp: Node) -> void:
	# Parent under the current scene's root so remote players are freed
	# automatically on scene change (lobby ↔ world.tscn ↔ future zones).
	var scene := get_tree().current_scene
	if scene == null:
		push_warning("RemotePlayerManager: no current scene; dropping spawn")
		rp.queue_free()
		return
	scene.add_child(rp)

# Defensive — call before zone swaps if needed. Scene change already frees
# the children when the parent scene goes away.
func clear_all() -> void:
	for id in _by_id:
		_by_id[id].queue_free()
	_by_id.clear()
