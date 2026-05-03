## DungeonSpawner — add this Node3D to your scene.
##
## Multiplayer: host picks `dungeon_seed` and syncs it to all clients before
## scene load. DungeonGenerator is fully deterministic for a given seed, so
## every peer regenerates locally — no geometry sent over the network.
##
## Signals:
##   dungeon_ready(layout: DungeonLayout)  — entrance floor, emitted after build.
class_name DungeonSpawner
extends Node3D

signal dungeon_ready(layout: DungeonLayout)

@export var dungeon_seed:  int  = 0     # 0 = random each load
@export var floor_count:   int  = 1     # set > 1 for multi-floor dungeons
@export var auto_generate: bool = true

var layout: DungeonLayout       = null  # entrance floor layout
var multi_layout: MultiFloorLayout = null


func _ready() -> void:
	if auto_generate:
		generate()


func generate(override_seed: int = -1) -> void:
	var used_seed: int
	if override_seed >= 0:
		used_seed = override_seed
	elif dungeon_seed != 0:
		used_seed = dungeon_seed
	else:
		used_seed = randi()

	for child in get_children():
		child.queue_free()

	if floor_count > 1:
		_build_multi_floor(used_seed)
	else:
		_build_single_floor(used_seed)

	_place_entrance_marker()
	emit_signal("dungeon_ready", layout)


func _build_single_floor(used_seed: int) -> void:
	var gen = DungeonGenerator.new()
	layout = gen.generate(used_seed)
	var mesh = DungeonMeshBuilder.build(layout, 0.0)
	add_child(mesh)
	var groups := {}
	DungeonLightPlacer.place(layout, self, 0.0, 0, groups)
	DungeonLightPlacer.print_debug_groups(groups)
	print("[DungeonSpawner] seed=%d  rooms=%d" % [used_seed, layout.rooms.size()])


func _build_multi_floor(used_seed: int) -> void:
	var gen = MultiFloorGenerator.new()
	multi_layout = gen.generate(used_seed, floor_count)
	layout = multi_layout.entrance_layout()

	var torch_idx := 0
	var groups := {}
	for i in multi_layout.floors.size():
		var fl: DungeonLayout = multi_layout.floors[i]
		var y_off = multi_layout.floor_y_offset(i)
		var mesh = DungeonMeshBuilder.build(fl, y_off)
		mesh.name = "Floor_%d" % i
		add_child(mesh)
		torch_idx = DungeonLightPlacer.place(fl, self, y_off, torch_idx, groups)
	DungeonLightPlacer.print_debug_groups(groups)

	for stair in multi_layout.stairs:
		var lower_y    = multi_layout.floor_y_offset(stair.from_floor)
		var separation = multi_layout.floor_separation()
		var ramp = StairMeshBuilder.build(stair, lower_y, separation)
		add_child(ramp)

	print("[DungeonSpawner] seed=%d  floors=%d  rooms/floor=%d" % [
		used_seed, floor_count, layout.rooms.size()])


func _place_entrance_marker() -> void:
	if layout == null or layout.rooms.is_empty():
		return
	var entrance = layout.entrance_room()
	if entrance == null:
		return
	var center    = entrance.center_cell()
	var world_pos = layout.cell_to_world(center.x, center.y)

	var mi     = MeshInstance3D.new()
	mi.name    = "EntranceMarker"
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mi.mesh    = sphere
	var mat    = StandardMaterial3D.new()
	mat.albedo_color             = Color(1.0, 0.85, 0.1)
	mat.emission_enabled         = true
	mat.emission                 = Color(1.0, 0.85, 0.1)
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	mi.position = world_pos + Vector3(0.0, 1.0, 0.0)
	add_child(mi)
