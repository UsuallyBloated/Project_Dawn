class_name VendorNPC
extends Area3D

@export var vendor_name: String = "General Merchant"
@export var vendor_type: String = "General Merchant"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("vendor_npcs")
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.text = vendor_name

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		VendorManager.register_nearby(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		VendorManager.unregister_nearby(self)
