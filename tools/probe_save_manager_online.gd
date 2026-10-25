extends SceneTree
# Headless probe: SaveManager writes nothing while online. The local save is
# the offline Test Room's alone; an online character written there would be
# loaded back as the Test Room's character. With a character applied and Net in
# launcher mode, save() must refuse and leave character.save byte for byte as
# it was. It never runs an offline save, so the real file is never written.
# Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_save_manager_online.gd

const SAVE_PATH := "user://character.save"

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)

# The autoloads join the tree after _initialize, so the checks run on the
# first frame.
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var net = root.get_node("/root/Net")
	var ps = root.get_node("/root/PlayerStats")
	var sm = root.get_node("/root/SaveManager")

	var existed := FileAccess.file_exists(SAVE_PATH)
	var before := _read_bytes(SAVE_PATH)

	# A character applied, as in play: the old code saved from here.
	ps.player_name = "ProbeOnline"
	ps.race = "Human"
	ps.player_class = "Warrior"

	# Launcher mode: Net holds a server character id.
	net._char_id = 7
	_check(net.is_launcher_mode(), "Net reports launcher mode with a character id")
	_check(sm.save() == false, "save() refuses while online")
	_check(FileAccess.file_exists(SAVE_PATH) == existed, "no save file appears or disappears")
	_check(_read_bytes(SAVE_PATH) == before, "character.save is unchanged")
	net._char_id = -1

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
