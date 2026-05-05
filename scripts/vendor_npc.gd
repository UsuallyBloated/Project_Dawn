class_name VendorNPC
extends FriendlyNPC

@export var vendor_name: String = "General Merchant"
@export var vendor_type: String = "General Merchant"

func _register() -> void:
	add_to_group("vendor_npcs")

func _display_name() -> String:
	return vendor_name

func _on_player_nearby(is_near: bool) -> void:
	if is_near:
		VendorManager.register_nearby(self)
	else:
		VendorManager.unregister_nearby(self)
