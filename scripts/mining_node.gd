class_name MiningNode
extends Area3D

# An ore vein. Mining is not on the server yet, so the vein refuses honestly;
# its data (ore, skill, respawn) stays for the server port.

@export var ore_type: String = "Tin Ore"
@export var required_skill: int = 0
@export var respawn_time: float = 60.0

const _ORE_COLORS: Dictionary = {
	"Tin Ore":        Color(0.70, 0.70, 0.60),
	"Silver Ore":     Color(0.85, 0.85, 0.90),
	"Gold Ore":       Color(0.90, 0.75, 0.20),
	"Mithril Ore":    Color(0.40, 0.55, 0.90),
	"Adamantite Ore": Color(0.65, 0.25, 0.25),
}

func _ready() -> void:
	add_to_group("mining_nodes")
	var mesh_inst := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _ORE_COLORS.get(ore_type, Color(0.5, 0.45, 0.40))
		mat.roughness = 0.95
		mesh_inst.set_surface_override_material(0, mat)
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.text = ore_type

func try_mine() -> String:
	# Tradeskills are not on the server yet. A local mine would add an ore the
	# server never hears about: a phantom item that vanishes on relog, and
	# worse, client slot indices out of line with the server's so a later
	# right-click could destroy the WRONG real item. Refuse honestly until
	# mining goes through the server (the CompleteQuest pattern: grant nothing
	# optimistically).
	return "Mining isn't available online yet."
