extends SceneTree
# Headless probe for the fizzle's cooldown (2026-10-27): a fizzle starts the
# gem's refresh on the server, so the client keeps (or starts) its global
# cooldown instead of clearing it with the refusal's; the fizzled spell's own
# cooldown is dropped, a running bar is cancelled with its mana back, and an
# ordinary refusal still clears everything. On the old code a fizzled instant
# cast left the global cooldown at zero and the next click met the server's
# "You cannot cast again yet." (the 2026-10-27 journal). Exits 1 on any miss.
# Run:
#   godot --headless --path . -s tools/probe_fizzle_cooldown.gd

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
	var sp = root.get_node("/root/Spells")
	var rpm = root.get_node("/root/RemotePlayerManager")
	var ps = root.get_node("/root/PlayerStats")
	# Launcher mode, and the id a CastFail is matched against as our own.
	net._char_id = 7
	net._player_id = 7

	# An instant cast that fizzled: its own cooldown and the global one were
	# started at the send.
	sp._cooldowns.start("Smite", 3.0)
	sp._sent_spell_name = "Smite"
	sp._sent_at_msec = Time.get_ticks_msec()
	sp._gcd_remaining = sp.GLOBAL_COOLDOWN_SECS
	rpm._on_cast_fail(7, "Your spell fizzles!")
	_check(sp.get_global_cooldown_remaining() > 0.0, "a fizzled instant cast keeps the global cooldown (%.2f s)" % sp.get_global_cooldown_remaining())
	_check(not sp.is_on_cooldown("Smite"), "and drops the spell's own cooldown")

	# A timed cast that fizzled at its start: the bar is cancelled, the
	# optimistic spend comes back, and the global cooldown starts.
	var heal := SpellData.new()
	heal.spell_name = "Healing Light"
	heal.mana_cost = 10.0
	heal.cast_time = 3.0
	ps.max_mp = 50.0
	ps.mp = 30.0
	sp._casting = heal
	sp._cast_timer = 0.5
	sp._gcd_remaining = 0.0
	rpm._on_cast_fail(7, "Your spell fizzles!")
	_check(sp._casting == null, "a fizzled timed cast cancels its bar")
	_check(is_equal_approx(ps.mp, 40.0), "with the optimistic spend back (mp %s)" % ps.mp)
	_check(sp.get_global_cooldown_remaining() > 0.0, "and starts the global cooldown")

	# An ordinary refusal still clears both, as before.
	sp._cooldowns.start("Smite", 3.0)
	sp._sent_spell_name = "Smite"
	sp._sent_at_msec = Time.get_ticks_msec()
	sp._gcd_remaining = sp.GLOBAL_COOLDOWN_SECS
	rpm._on_cast_fail(7, "That target is too far away.")
	_check(sp.get_global_cooldown_remaining() == 0.0, "a refusal clears the global cooldown")
	_check(not sp.is_on_cooldown("Smite"), "and the spell's own")

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
