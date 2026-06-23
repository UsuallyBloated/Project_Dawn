class_name Corpse
extends Node3D

# A server-owned player corpse (corpse / resurrection epic, Slice 1).
# Render-only for now: a body mesh + a "<owner>'s corpse" nameplate. Spawned and
# despawned by RemoteCorpseManager from CorpseSpawn / EntityDespawn broadcasts.
# Looting (walk back, take your gear) lands in Slice 2 — that's when this gains
# an Area3D + interaction, mirroring scripts/loot_bag.gd.
#
# `owner_id` is the dead player's char_id; the manager sets the public fields
# before add_child so _ready can label the nameplate.

var corpse_id: int = -1
var owner_id: int = -1
var owner_name: String = ""

func _ready() -> void:
	add_to_group("corpses")

	# Body: a flattened, desaturated capsule lying on the ground — deliberately
	# distinct from the golden loot-bag sphere. Placeholder until a real model.
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
