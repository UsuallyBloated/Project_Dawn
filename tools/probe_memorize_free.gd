extends SceneTree
# Headless probe for free memorizing (2026-10-26): a memorize that runs its
# time completes with no mana and takes none, online and offline, as in EQ
# (the mana is paid at the cast). It used to cost half the spell's mana, and a
# caster short of it was refused at the finish. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_memorize_free.gd

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
	var net = root.get_node("/root/Net")
	var ps = root.get_node("/root/PlayerStats")
	var mem = root.get_node("/root/Memorize")
	var completed: Array[int] = [0]
	var cancelled: Array[String] = []
	mem.memorize_completed.connect(func(_s, _slot) -> void: completed[0] += 1)
	mem.memorize_cancelled.connect(func(reason: String) -> void: cancelled.append(reason))

	var smite := SpellData.new()
	smite.spell_name = "Smite"
	smite.mana_cost = 12.0

	# Online (launcher mode): the finish goes to the server and takes nothing
	# here, even with an empty mana bar.
	net._char_id = 7
	ps.mp = 0.0
	mem._committing = true
	mem._commit_spell = smite
	mem._commit_slot = 0
	# The old code charged the cost commit() stored here (half of 12); on the
	# new code the field is gone and this set does nothing.
	mem.set("_commit_mana_cost", smite.mana_cost * 0.5)
	mem._finish_commit()
	_check(completed[0] == 1 and cancelled.is_empty(), "a memorize with no mana completes (cancelled: %s)" % [cancelled])
	_check(ps.mp == 0.0, "and takes no mana (mp %s)" % ps.mp)

	_check(not ("MEMORIZE_COST_FACTOR" in mem), "the memorize cost is gone")

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
