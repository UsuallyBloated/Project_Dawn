# ZoneEntry — marks a spawn point inside a zone.
# ZoneLoader searches for nodes in the "zone_entries" group and matches entry_id.
#
# Setup in editor:
#   1. Add a Node3D to your zone scene, name it e.g. "Entry_FromWest"
#   2. Attach this script
#   3. Set entry_id to match the target_entry_id on the ZoneLine in the adjacent zone
#      e.g. if the west zone's ZoneLine has target_entry_id = "from_ashfield",
#           this node's entry_id should also be "from_ashfield"
#   4. Position the node just inside your zone border, facing inward
#
# The "default" entry_id is used for the initial game load and any unmatched entry.

class_name ZoneEntry
extends Node3D

@export var entry_id: String = "default"

func _ready() -> void:
	add_to_group("zone_entries")
