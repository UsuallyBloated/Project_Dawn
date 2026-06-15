class_name LootBag
extends Area3D

# `items` is the user-facing entry list:
#   [{item: ItemData, count: int}, ...]
# Network-driven bags get their entries written by RemoteLootBagManager
# from a LootBagSpawn broadcast (path → load() → ItemData); local-mode
# bags get them from autoloads/loot.gd's _roll(). Same shape either way
# so LootWindow doesn't care.
var items: Array = []

# PD_W0014 — coin sitting on this corpse, shown in the loot window.
# Server-authoritative; written by RemoteLootBagManager from each
# LootBagSpawn snapshot. Looting any item (or Take All) credits it
# server-side and a re-snapshot zeroes these. Local-mode bags stay 0.
var coin_platinum: int = 0
var coin_gold: int = 0
var coin_silver: int = 0
var coin_copper: int = 0

func has_coins() -> bool:
	return coin_platinum > 0 or coin_gold > 0 or coin_silver > 0 or coin_copper > 0

# Track 5 sub-task 4 — when non-negative, this bag is server-owned and
# its lifecycle is driven by LootBagSpawn / EntityDespawn broadcasts.
# Local single-player bags leave this at -1; they keep the legacy
# 120-second despawn timer in _ready below. Setting before add_child
# so _ready can branch on it.
var bag_id: int = -1

# Emitted whenever `items` is reassigned from outside (server re-snap-
# shot after a LootItem / LootAll). LootWindow subscribes to refresh
# its row list. Local-mode bags also emit this from the legacy local
# take path so the same wire keeps both flows in sync.
signal items_changed

func _ready() -> void:
	input_ray_pickable = true
	collision_layer = 4
	collision_mask = 0
	add_to_group("loot_bags")

	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mesh_inst.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.55, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.5, 0.0)
	mat.emission_energy_multiplier = 0.6
	mesh_inst.set_surface_override_material(0, mat)
	add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	col.shape = shape
	add_child(col)

	var tween := create_tween().set_loops()
	tween.tween_property(mesh_inst, "position:y", 0.2, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh_inst, "position:y", -0.05, 0.9).set_trans(Tween.TRANS_SINE)

	input_event.connect(_on_input_event)

	# Local despawn timer applies only to single-player Test Room bags.
	# Server-owned bags use EntityDespawn broadcasts after the server-
	# side LOOT_BAG_LINGER_SECS (matches the local 120s for parity).
	if bag_id < 0:
		var despawn_timer := Timer.new()
		despawn_timer.wait_time = 120.0
		despawn_timer.one_shot = true
		despawn_timer.autostart = true
		despawn_timer.timeout.connect(queue_free)
		add_child(despawn_timer)

const LOOT_RANGE := 6.0

func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player := get_tree().get_first_node_in_group("player")
		if player == null or global_position.distance_to(player.global_position) > LOOT_RANGE:
			return
		Loot.show_window(self)
