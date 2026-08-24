class_name MiningNode
extends Area3D

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

var _depleted: bool = false

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
	# Tradeskills are client-local: the ore would be added by a bare local
	# Inventory.add_item() the server never hears about. Online that makes a
	# phantom item that vanishes on relog, and worse, shifts the client's slot
	# indices out of line with the server's so a later right-click can destroy
	# the WRONG real item. Refuse honestly until tradeskills go through the
	# server (the CompleteQuest pattern: grant nothing optimistically).
	if Net.is_launcher_mode():
		return "Mining isn't available online yet."
	if _depleted:
		return "This vein is depleted."
	var level := Crafting.get_skill_level("Mining")
	if level < required_skill:
		return "You need Mining skill %d to mine this (you have %d)." % [required_skill, level]
	if Crafting.count_item("Pickaxe") == 0:
		return "You need a Pickaxe to mine ore."
	var item := _load_item(ore_type)
	if item == null:
		return "Error: ore item '%s' not found." % ore_type
	var success_chance := clampf((level - required_skill + 20) / 40.0, 0.15, 0.95)
	_start_depletion()
	if randf() > success_chance:
		Crafting.gain_skill_xp("Mining", 5)
		return "You swing your pickaxe but the vein crumbles without yielding ore."
	if not Inventory.add_item(item, 1):
		return "Inventory is full."
	Crafting.gain_skill_xp("Mining", 10)
	return "You mine 1 %s." % ore_type

func _start_depletion() -> void:
	_depleted = true
	monitoring = false
	var mesh_inst := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		mesh_inst.visible = false
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.visible = false
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)

func _respawn() -> void:
	if not is_instance_valid(self):
		return
	_depleted = false
	monitoring = true
	var mesh_inst := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		mesh_inst.visible = true
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.visible = true

func _load_item(item_name: String) -> ItemData:
	var path := "res://data/loot/items/%s.tres" % item_name.to_lower().replace(" ", "_")
	return load(path) as ItemData
