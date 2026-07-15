class_name DialogueNPC
extends FriendlyNPC

@export var npc_name: String = ""
@export var npc_title: String = ""

# Optional vendor. A talker you HAIL for dialogue (quests, lore) can ALSO sell:
# a dialogue "open_vendor" response opens this vendor via VendorManager. Leave
# vendor_name empty for a pure talker (e.g. Aldric). When it's set, the NPC also
# registers with VendorManager on proximity so the open_vendor response has a
# nearby vendor to open — interaction still opens the DIALOGUE first (the HUD
# routes `dialogue_npcs` ahead of `vendor_npcs`), so trading stays a choice
# inside the hail (e.g. Brom the Provisioner, who also gives the rat/gnoll
# quests). The vendor window reads vendor_name/vendor_type off this node.
@export var vendor_name: String = ""
@export var vendor_type: String = ""

func _register() -> void:
	add_to_group("dialogue_npcs")

func _display_name() -> String:
	return npc_name

func _on_player_nearby(is_near: bool) -> void:
	if is_near:
		DialogueManager.register_nearby(self)
		if vendor_name != "":
			VendorManager.register_nearby(self)
	else:
		DialogueManager.unregister_nearby(self)
		if vendor_name != "":
			VendorManager.unregister_nearby(self)
