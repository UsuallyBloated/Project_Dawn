extends Node

# RemotePlayerManager — visual replication of every other player in the
# current zone. Listens to Net's coarse signals; manages a dict of
# `remote_player.tscn` instances keyed by char_id.
#
# Two maps, two lifetimes:
#   _spawn_data — last known identity + spawn pose per char_id. Survives
#       scene changes (autoload-scoped). The source of truth for
#       re-instantiation when the local scene tree shifts under us.
#   _by_id — live RemotePlayer node per char_id, parented under the
#       current scene's root so it dies with the scene on transition.
#
# Why two maps: the lobby→world transition for the second-joining client.
# Server fan-out delivers EntitySpawn(A) to B at app-Connect time, which
# is BEFORE B clicks Enter World — so B is still on the lobby scene.
# Parenting RemotePlayer(A) under the lobby means it gets freed on
# transition, and the server doesn't re-send spawn (it's a one-shot
# reliable message). With _spawn_data persistent, the `_process` poll
# below catches the scene swap and re-instantiates into world.tscn.
#
# Own player is rendered by world.tscn + handled by player.gd; we filter
# out broadcasts where id == Net.get_player_id() on every signal.

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")

var _spawn_data: Dictionary = {}   # int char_id -> spawn dict
var _by_id: Dictionary = {}        # int char_id -> RemotePlayer node
var _last_scene: Node = null
# Set when a scene swap drops _by_id; cleared once we've reinstantiated
# into a scene that actually hosts the local player. Persists across
# frames so the local player joining its group one tick after the scene
# becomes current doesn't fall through the cracks.
var _needs_rehydrate: bool = false

func _ready() -> void:
	Net.world_entity_spawn.connect(_on_entity_spawn)
	Net.world_entity_despawn.connect(_on_entity_despawn)
	Net.world_position.connect(_on_position)
	Net.world_health_update.connect(_on_health_update)
	Net.world_mana_update.connect(_on_mana_update)
	Net.world_stamina_update.connect(_on_stamina_update)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _last_scene:
		# Scene swap (or `current_scene` transitioning through null between
		# change_scene_to_file and the actual swap — Godot does this briefly).
		# Free every live node we know about before dropping the map; relying
		# on "scene change frees its children" misses the case where the
		# scene didn't actually change but `_last_scene` was invalidated
		# (e.g. transient null), which would otherwise leave orphaned
		# RemotePlayer bodies in the live scene tree.
		for rp in _by_id.values():
			if is_instance_valid(rp):
				rp.queue_free()
		_last_scene = scene
		_by_id.clear()
		_needs_rehydrate = true
	if not _needs_rehydrate or scene == null:
		return
	if not _scene_hosts_local_player(scene):
		return
	for id in _spawn_data:
		if not _by_id.has(id):
			_instantiate_into(id, scene)
	_needs_rehydrate = false

func _on_entity_spawn(
		id: int,
		player_name: String,
		race: String,
		char_class: String,
		level: int,
		pos: Vector3,
		yaw: float) -> void:
	if id == Net.get_player_id():
		# Own-player spawn fan-out skips the subject server-side; this
		# branch is defensive insurance against a future protocol change.
		return
	# Cache regardless of scene — drives rehydration on the next world
	# transition if we're in the lobby right now.
	_spawn_data[id] = {
		"name": player_name,
		"race": race,
		"class": char_class,
		"level": level,
		"pos": pos,
		"yaw": yaw,
	}
	var scene := get_tree().current_scene
	if scene == null or not _scene_hosts_local_player(scene):
		return
	# Duplicate spawn (stale message after a despawn). Replace.
	if _by_id.has(id):
		var old = _by_id[id]
		if is_instance_valid(old):
			old.queue_free()
		_by_id.erase(id)
	# Defensive orphan sweep: free any RemotePlayer in the live scene whose
	# char_id matches but isn't tracked in _by_id. Catches the case where
	# a prior _by_id.clear() lost the reference but Godot didn't free the
	# node (transient scene-null window during change_scene_to_file).
	for child in scene.get_children():
		if child is RemotePlayer and child.char_id == id:
			child.queue_free()
	_instantiate_into(id, scene)

func _on_entity_despawn(id: int) -> void:
	_spawn_data.erase(id)
	var rp = _by_id.get(id)
	if rp != null:
		if is_instance_valid(rp):
			rp.queue_free()
		_by_id.erase(id)

func _on_position(id: int, pos: Vector3, _vel: Vector3, yaw: float, sequence: int) -> void:
	# Own-player position is handled by player.gd._on_world_position.
	if id == Net.get_player_id():
		return
	var rp = _by_id.get(id)
	if rp == null:
		# Position before EntitySpawn (channel race), or while still in
		# the lobby (spawn cached, node not yet instantiated). Drop —
		# subsequent Positions after the node exists will land.
		return
	rp.on_position_update(pos, yaw, sequence)

# Track 4: peer resource fan-out. Owner is filtered out (server already skips
# self, but defensive). If we have no spawn record for `id`, drop — happens
# only if EntityDespawn already cleared the record but a late HealthUpdate
# slipped through the reliable channel.
func _on_health_update(id: int, hp: float, max_hp: float) -> void:
	if id == Net.get_player_id():
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["hp"] = hp
	data["max_hp"] = max_hp
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_health_update(hp, max_hp)

func _on_mana_update(id: int, mp: float, max_mp: float) -> void:
	if id == Net.get_player_id():
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["mp"] = mp
	data["max_mp"] = max_mp
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_mana_update(mp, max_mp)

func _on_stamina_update(id: int, stamina: float, maximum: float) -> void:
	if id == Net.get_player_id():
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["stamina"] = stamina
	data["max_stamina"] = maximum
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_stamina_update(stamina, maximum)

func _instantiate_into(id: int, scene: Node) -> void:
	var data: Dictionary = _spawn_data[id]
	var rp := REMOTE_PLAYER_SCENE.instantiate()
	rp.char_id = id
	rp.player_name = data["name"]
	rp.race = data["race"]
	rp.player_class = data["class"]
	rp.level = data["level"]
	rp.global_position = data["pos"]
	rp.rotation.y = data["yaw"]
	scene.add_child(rp)
	_by_id[id] = rp
	# Apply any cached resource state (from earlier broadcasts that arrived
	# while we were in the lobby, or the 4a seed at app-connect). add_child
	# fires _ready first, so the bar nodes are guaranteed live here.
	if data.has("hp"):
		rp.apply_health_update(data["hp"], data["max_hp"])
	if data.has("mp"):
		rp.apply_mana_update(data["mp"], data["max_mp"])
	if data.has("stamina"):
		rp.apply_stamina_update(data["stamina"], data["max_stamina"])

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
		var rp = _by_id[id]
		if is_instance_valid(rp):
			rp.queue_free()
	_by_id.clear()
	_spawn_data.clear()
