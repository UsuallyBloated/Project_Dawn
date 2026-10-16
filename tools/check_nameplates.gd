extends SceneTree

# Regression check (run headless, exits 1 on failure): every nameplate (a Label3D named NameLabel) in the world's
# scenes is depth-tested, so walls hide it; nothing but floating damage numbers
# draws through geometry.

const SCENES := [
	"res://scenes/remote_player.tscn",
	"res://scenes/remote_enemy.tscn",
	"res://scenes/remote_pet.tscn",
	"res://scenes/enemy.tscn",
	"res://scenes/pet.tscn",
	"res://scenes/banker_npc.tscn",
	"res://scenes/dialogue_npc.tscn",
	"res://scenes/vendor_npc.tscn",
	"res://scenes/crafting_station.tscn",
	"res://scenes/mining_node.tscn",
]

var failures := 0

func check(cond: bool, what: String) -> void:
	print("%s  %s" % ["OK     " if cond else "FAILED ", what])
	if not cond:
		failures += 1

func _initialize() -> void:
	await process_frame
	for path in SCENES:
		var packed := load(path) as PackedScene
		if packed == null:
			check(false, "loads: " + path)
			continue
		var node := packed.instantiate()
		var label := node.get_node_or_null("NameLabel") as Label3D
		check(label != null and not label.no_depth_test, "walls hide the nameplate: " + path)
		node.free()
	print("nameplate probe: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
