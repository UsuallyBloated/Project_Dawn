extends SceneTree
# Headless probe for the build stamp's debug mark (2026-11-09). An export made with
# the DEBUG template (the editor's Export dialog default) has recorded
# debug_build=true since the stamp existed, but nothing printed it, so on
# 2026-11-06 a debug export read as a normal build in /version. short() now ends
# "-debug" and verbose() carries a line; the login footer turns amber on it. The
# checks run the format over hand-made stamps, so no export is needed. Exits 1 on
# any miss. Run:
#   godot --headless --path . -s tools/probe_build_stamp_debug.gd

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	var release := {"status": "ok", "commit": "da83ea8", "debug_build": false}
	var debug := {"status": "ok", "commit": "df4f29c", "debug_build": true}
	var dirty_debug := {"status": "ok", "commit": "df4f29c", "dirty": true, "debug_build": true}
	# A stamp from before the flag existed carries no key at all.
	var old := {"status": "ok", "commit": "0ff0387"}
	var unstamped := {"status": "unstamped", "reason": "no stamp", "commit": "UNSTAMPED"}

	_check(BuildInfo.short_of(release) == "da83ea8", "a release export reads the sha alone")
	_check(BuildInfo.short_of(debug) == "df4f29c-debug", "a debug export reads sha-debug (got %s)" % BuildInfo.short_of(debug))
	_check(BuildInfo.short_of(dirty_debug) == "df4f29c-dirty-debug", "dirty comes before debug (got %s)" % BuildInfo.short_of(dirty_debug))
	_check(BuildInfo.short_of(old) == "0ff0387", "a stamp without the flag reads as a release")
	_check(BuildInfo.short_of(unstamped) == "UNSTAMPED", "an unstamped build still reads UNSTAMPED")

	var v := BuildInfo.verbose_of(debug)
	_check(v.begins_with("Build df4f29c-debug"), "verbose leads with the marked sha")
	_check("debug export" in v, "verbose carries the debug export line")
	_check(not ("debug export" in BuildInfo.verbose_of(release)), "a release export has no such line")
	_check(BuildInfo.verbose_of(unstamped).begins_with("Build: UNSTAMPED"), "an unstamped build's verbose is unchanged")
	_check(BuildInfo.short() == BuildInfo.short_of(BuildInfo.data()), "short() is short_of() over the live stamp")

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
