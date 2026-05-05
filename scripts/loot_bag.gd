class_name LootBag
extends Area3D

var items: Array = []

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
