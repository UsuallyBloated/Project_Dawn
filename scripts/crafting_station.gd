class_name CraftingStation
extends Area3D

# Valid station_type values match the "station" field in recipe_definitions.gd:
#   "forge"  "alchemy_table"  "kiln"  "oven"  "brewing_barrel"
@export var station_type: String = "forge"

# Display label shown to the player when nearby
@export var station_label: String = ""

const _COLORS: Dictionary = {
	"forge":          Color(0.80, 0.35, 0.10, 1),
	"alchemy_table":  Color(0.35, 0.20, 0.65, 1),
	"kiln":           Color(0.55, 0.40, 0.25, 1),
	"oven":           Color(0.50, 0.28, 0.12, 1),
	"brewing_barrel": Color(0.35, 0.22, 0.10, 1),
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("crafting_stations")

	var mesh_inst := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _COLORS.get(station_type, Color(0.5, 0.5, 0.5, 1))
		mesh_inst.set_surface_override_material(0, mat)

	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.text = station_label if station_label != "" else _default_label()

func _default_label() -> String:
	match station_type:
		"forge":          return "Forge"
		"alchemy_table":  return "Alchemy Table"
		"kiln":           return "Kiln"
		"oven":           return "Oven"
		"brewing_barrel": return "Brewing Barrel"
	return station_type.capitalize()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		StationManager.register_nearby(station_type)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		StationManager.unregister_nearby(station_type)
