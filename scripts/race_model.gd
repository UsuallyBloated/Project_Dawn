class_name RaceModel

# Per-race visual model overrides for the player capsule.
#
# The player and every remote player are authored in their scenes as a plain
# 2 m capsule "Visual" MeshInstance3D. When a race has a custom model listed
# here, apply() hides that capsule mesh and mounts the imported model in its
# place. Races absent from MODELS keep the capsule, so this grows one race at
# a time without touching the scenes.
#
# The model is purely cosmetic: collision, camera height, targeting and
# nameplates still use the capsule, so per-race collision/camera tuning is a
# separate pass (see docs/reference/creature_heights.md).

# Fields per race:
#   scene      - imported glb (a PackedScene under res://assets/models/...).
#   feet_y     - the model's lowest point in its own space (metres, usually
#                negative). apply() lifts the model by -feet_y so the feet
#                rest on the ground instead of sinking or floating.
#   yaw        - extra Y rotation (radians) if the model faces the wrong way.
#   hide_nodes - child nodes to hide, e.g. modeling scaffolds exported
#                alongside the body (reference planes, blockout frameworks).
const MODELS: Dictionary = {
	"Gnome": {
		"scene": "res://assets/models/characters/gnome/gnome.glb",
		"feet_y": 0.0,
		"yaw": 0.0,
		"hide_nodes": ["Gnome_Framework", "2D_Model_Front", "2D_Model_Side"],
	},
}

# Swap the scene's default capsule (`mount`, a MeshInstance3D) for `race`'s
# custom model. No-op for races without an entry. The model is parented under
# `mount` so the player's first-person hide (mount.visible = false) cascades to
# it; because `mount` sits at the capsule's centre we subtract mount.position.y
# so the model still lands feet-on-ground in world space.
static func apply(mount: MeshInstance3D, race: String) -> void:
	if mount == null:
		return
	var cfg: Dictionary = MODELS.get(race, {})
	if cfg.is_empty():
		return
	var packed: PackedScene = load(cfg["scene"])
	if packed == null:
		push_warning("RaceModel: could not load %s for race %s" % [cfg["scene"], race])
		return

	# Keep the capsule node (its .visible drives first-person hiding) but stop
	# it drawing, then ride the model in as its child.
	mount.mesh = null
	var inst: Node3D = packed.instantiate()
	inst.position.y = -float(cfg.get("feet_y", 0.0)) - mount.position.y
	inst.rotation.y = float(cfg.get("yaw", 0.0))
	mount.add_child(inst)

	for node_name in cfg.get("hide_nodes", []):
		var node: Node = inst.get_node_or_null(NodePath(node_name))
		if node is Node3D:
			(node as Node3D).visible = false
