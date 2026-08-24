class_name Corpse
extends Area3D

# A server-owned player corpse (corpse / resurrection epic). Slice 1 rendered a
# body + nameplate; Slice 2 makes it lootable BY THE OWNER: clicking your own
# corpse opens the shared loot window (scripts/loot_window.gd) against it, and
# Take / Take All send LootItem / LootAll keyed by the corpse id (same id
# partition as loot bags). The owner-only contents arrive via CorpseContents
# (RemoteCorpseManager fills `items` + coins); peers see only the body.

const LOOT_RANGE := 6.0

var corpse_id: int = -1
var owner_id: int = -1
var owner_name: String = ""

# Loot-window data surface, duck-typed like a LootBag so LootWindow drives it
# untouched. `bag_id` is the loot-target id the Take buttons send (= corpse_id).
var bag_id: int = -1
var items: Array = []   # [{item: ItemData, count: int}, ...] — filled from CorpseContents
var coin_platinum: int = 0
var coin_gold: int = 0
var coin_silver: int = 0
var coin_copper: int = 0
signal items_changed

func has_coins() -> bool:
	return coin_platinum > 0 or coin_gold > 0 or coin_silver > 0 or coin_copper > 0

func _ready() -> void:
	add_to_group("corpses")
	bag_id = corpse_id
	input_ray_pickable = true
	collision_layer = 4
	collision_mask = 0

	# Body + white "<owner>'s corpse" nameplate, shared with slain-creature
	# bodies so the two render paths stay identical (scripts/corpse_body.gd).
	CorpseBody.build(self, owner_name)

	# Click-to-loot collider (a sphere over the lying body).
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	col.position.y = 0.3
	add_child(col)

	input_event.connect(_on_input_event)

func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Left-click TARGETS only — a Cleric/Paladin needs the corpse as a cast
	# target to resurrect it (Slice 3). Looting moved to right-click with the
	# rest of the world-interact grammar (Targeting.interact_at), which targets
	# AND opens the loot window for the owner, so one button does everything.
	Combat.set_target(self)
