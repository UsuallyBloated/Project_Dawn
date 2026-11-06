extends SceneTree
# Headless probe for NO DROP (2026-11-03): the starting kit's seven items load
# NO DROP and worth nothing, the tooltip leads with the tag, and the client
# refuses a NO DROP item for the ground, a trade offer and the shared vault
# before anything is sent (Inventory.refuse_no_drop), while an ordinary item
# and the character's own vault are let through. The server refuses again
# whatever a client sends. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_no_drop.gd

const KIT := [
	"res://data/loot/items/ragged_shirt.tres",
	"res://data/loot/items/ragged_pants.tres",
	"res://data/loot/items/trainees_sword.tres",
	"res://data/loot/items/trainees_knife.tres",
	"res://data/loot/items/trainees_club.tres",
	"res://data/loot/items/trainees_spear.tres",
	"res://data/loot/items/trainees_staff.tres",
]
const BREAD := "res://data/loot/items/bread_loaf.tres"

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

# The autoloads join the tree after _initialize, so the checks run on the
# first frame.
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var inv = root.get_node("/root/Inventory")
	for path in KIT:
		var item := load(path) as ItemData
		_check(item != null and item.no_drop and item.vendor_price == 0,
			"%s is NO DROP and worth nothing" % path.get_file())

	var staff := load("res://data/loot/items/trainees_staff.tres") as ItemData
	var bread := load(BREAD) as ItemData
	var lines: Array = []
	var panel := DraggablePanel.new()
	panel._append_stat_lines(staff, lines)
	_check(not lines.is_empty() and lines[0] == "NO DROP", "the tooltip leads with NO DROP (%s)" % [lines])
	panel.free()

	inv.base_slots[0] = {"item": staff, "count": 1}
	inv.base_slots[1] = {"item": bread, "count": 1}
	_check(inv.item_at("base", 0) == staff, "item_at finds the staff in base 0")
	_check(inv.refuse_no_drop("base", 0), "the staff is refused")
	_check(not inv.refuse_no_drop("base", 1), "the bread is let through")
	_check(not inv.refuse_no_drop("base", 2), "an empty slot is let through")

	var saved_bag: Variant = inv.bag_contents[5]
	inv.bag_contents[5] = [null, {"item": staff, "count": 1}]
	_check(inv.item_at("bag_5", 1) == staff, "item_at finds the staff inside a bag")
	_check(inv.refuse_no_drop("bag_5", 1), "the staff in a bag is refused")
	_check(not inv.refuse_no_drop("bag_5", 0) and not inv.refuse_no_drop("bag_6", 0),
		"an empty bag cell and a slot with no bag are let through")
	inv.bag_contents[5] = saved_bag

	inv.cursor_slot = {"item": staff, "count": 1}
	_check(inv.refuse_no_drop("cursor", 0), "a held staff is refused")
	inv.request_ground_drop()
	_check(inv._drop_dialog == null or not inv._drop_dialog.visible,
		"no drop confirm opens for a held NO DROP item")
	inv.cursor_slot = null

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
