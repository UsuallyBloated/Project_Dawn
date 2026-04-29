# ZoneLine — attach to an Area3D node with a CollisionShape3D child.
# When the player walks through it, the zone fades out and the target scene loads.
#
# Setup in editor:
#   1. Add an Area3D to your zone scene, name it e.g. "ZoneLine_East"
#   2. Attach this script
#   3. Add a CollisionShape3D child with a BoxShape3D sized to cover the border
#   4. Fill in target_zone_path and target_entry_id in the Inspector
#   5. Optionally set target_zone_name for the zone_changed signal

class_name ZoneLine
extends Area3D

@export var target_zone_path: String = ""
@export var target_entry_id: String = "default"
@export var target_zone_name: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 1  # layer 1 — same as the player CharacterBody3D

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and target_zone_path != "":
		ZoneLoader.travel_to(target_zone_path, target_entry_id, target_zone_name)
