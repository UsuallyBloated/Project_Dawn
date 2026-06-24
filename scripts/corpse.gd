class_name Corpse
extends Area3D

# A server-owned player corpse (corpse / resurrection epic). Slice 1 rendered a
# body + nameplate; Slice 2 makes it lootable BY THE OWNER: clicking your own
# corpse opens the shared loot window (scripts/loot_window.gd) against it, and
# Take / Take All send LootItem / LootAll keyed by the corpse id (same id
# partition as loot bags). The owner-only contents arrive via CorpseContents
# (RemoteCorpseManager fills `items` + coins); peers see only the body.

const LOOT_RANGE := 6.0

var corpse_id: int = -1
var owner_id: int = -1
var owner_name: String = ""

# Loot-window data surface, duck-typed like a LootBag so LootWindow drives it
# untouched. `bag_id` is the loot-target id the Take buttons send (= corpse_id).
var bag_id: int = -1
var items: Array = []   # [{item: ItemData, count: int}, ...] — filled from CorpseContents
var coin_platinum: int = 0
var coin_gold: int = 0
var coin_silver: int = 0
var coin_copper: int = 0
signal items_changed

func has_coins() -> bool:
	return coin_platinum > 0 or coin_gold > 0 or coin_silver > 0 or coin_copper > 0

func _ready() -> void:
	add_to_group("corpses")
	bag_id = corpse_id
	input_ray_pickable = true
	collision_layer = 4
	collision_mask = 0

	# Body: a flattened, desaturated capsule lying on the ground — distinct from
	# the golden loot-bag sphere. Placeholder until a real corpse model.
	var mesh_inst := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 1.6
	mesh_inst.mesh = body
	mesh_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)  # lie flat
	mesh_inst.position.y = 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.30, 0.30)
	mat.emission_enabled = true
	mat.emission = Color(0.20, 0.04, 0.06)  # faint dim-red glow, findable from a distance
	mat.emission_energy_multiplier = 0.35
	mesh_inst.set_surface_override_material(0, mat)
	add_child(mesh_inst)

	# Nameplate: "<owner>'s corpse", billboarded like the enemy nameplate.
	var label := Label3D.new()
	label.text = "%s's corpse" % owner_name
	label.font_size = 22
	label.outline_size = 6
	label.modulate = Color(0.85, 0.7, 0.7)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.1
	add_child(label)

	# Click-to-loot collider (a sphere over the lying body).
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	col.position.y = 0.3
	add_child(col)

	input_event.connect(_on_input_event)

func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Owner-only: only your own corpse opens a loot window. The server is the
	# authority and also rejects a non-owner take with "That is not your corpse.";
	# this is the client pre-gate so non-owners don't open an empty window.
	if owner_id != Net.get_player_id():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or global_position.distance_to(player.global_position) > LOOT_RANGE:
		return
	Loot.show_window(self)
