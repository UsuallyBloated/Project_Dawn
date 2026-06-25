class_name CorpseBody

# Shared dead-body visual for player corpses (scripts/corpse.gd) and slain-
# creature bodies (scripts/loot_bag.gd, when the loot drop came from a kill).
# A flattened gray capsule lying on the ground with a faint dim-red glow and a
# billboarded white "<name>'s corpse" nameplate. One builder so the two render
# paths can't drift. This is the generic placeholder body (the same capsule
# family the living creatures use); per-creature model + scale is a later change.

# Builds the body mesh + nameplate as children of `parent` (an Area3D/Node3D).
# Visual only on purpose: each caller still owns its own collider + click
# handling, because a player corpse is owner-gated while a creature body uses
# the loot bag's group loot rights.
static func build(parent: Node3D, display_name: String) -> void:
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
	parent.add_child(mesh_inst)

	# White "<name>'s corpse", billboarded. Both player and creature bodies use
	# white so they read consistently; the name itself tells them apart.
	var label := Label3D.new()
	label.text = "%s's corpse" % display_name
	label.font_size = 22
	label.outline_size = 6
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.1
	parent.add_child(label)
