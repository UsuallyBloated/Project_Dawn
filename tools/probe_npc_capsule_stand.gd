extends SceneTree
# Headless probe for the NPC placeholder bodies (2026-11-09). The three NPC scenes
# drew a centred 1.8 m capsule at the node origin, so 0.9 m of every NPC sat below
# the ground (the user's screenshot on part A of the master sheet; always so, not
# the hills: the remote player's capsule was raised 1 m, the NPCs' never). The
# click capsule and the mesh now stand on the node origin, the name label above
# them, so an NPC stands as a player does. A real model will not need this: its
# origin is at its feet. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_npc_capsule_stand.gd

const SCENES := [
	"res://scenes/dialogue_npc.tscn",
	"res://scenes/vendor_npc.tscn",
	"res://scenes/banker_npc.tscn",
]
# How far a foot may sit off the ground before it reads as sunk or floating.
const FOOT_SLACK := 0.1

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	for path: String in SCENES:
		var name := path.get_file()
		var npc: Node = load(path).instantiate()
		var mesh := npc.get_node("MeshInstance3D") as MeshInstance3D
		var click := npc.get_node("CollisionShape3D") as CollisionShape3D
		var label := npc.get_node("NameLabel") as Label3D
		var body := mesh.mesh as CapsuleMesh
		var foot := mesh.position.y - body.height / 2.0
		var top := mesh.position.y + body.height / 2.0
		_check(absf(foot) <= FOOT_SLACK,
			"%s: the body stands on the node origin (foot at y %.2f)" % [name, foot])
		var shape := click.shape as CapsuleShape3D
		var click_foot := click.position.y - shape.height / 2.0
		_check(absf(click_foot) <= FOOT_SLACK,
			"%s: the click capsule stands with the body (foot at y %.2f)" % [name, click_foot])
		_check(absf(click.position.y - mesh.position.y) <= FOOT_SLACK,
			"%s: the click capsule and the body are centred together" % name)
		_check(label.position.y >= top,
			"%s: the name label sits above the body (%.2f over a top of %.2f)" % [name, label.position.y, top])
		npc.free()

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
