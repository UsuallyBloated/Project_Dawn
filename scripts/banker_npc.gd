class_name BankerNPC
extends FriendlyNPC

# Town Banker — zero-weight coin storage + tier exchange (Banker slice 1).
# Same FriendlyNPC base as VendorNPC; registers with BankerManager so the
# hud interact path can open the BankWindow. Town-anchored by design (banks
# are infrastructure; see docs/concepts/world/currency.md).

@export var banker_name: String = "Banker"

func _register() -> void:
	add_to_group("banker_npcs")

func _display_name() -> String:
	return banker_name

func _on_player_nearby(is_near: bool) -> void:
	if is_near:
		BankerManager.register_nearby(self)
	else:
		BankerManager.unregister_nearby(self)
