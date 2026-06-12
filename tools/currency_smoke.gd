# Headless smoke test for Currency math + the PlayerStats wallet.
# Run: godot --headless --path . --script tools/currency_smoke.gd
# `--script` runs a bare SceneTree (no autoloads), so the two scripts are
# instantiated manually; PlayerStats resolves `Currency` through the root
# node we add first.
extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []

	var cur: Node = load("res://autoloads/currency.gd").new()
	cur.name = "Currency"
	root.add_child(cur)
	var ps: Node = load("res://autoloads/player_stats.gd").new()
	ps.name = "PlayerStats"
	root.add_child(ps)

	# total / from_copper round-trip
	if cur.total_copper(1, 23, 45, 67) != 1_234_567:
		failures.append("total_copper(1,23,45,67) != 1_234_567")
	if cur.from_copper(1_234_567) != [1, 23, 45, 67]:
		failures.append("from_copper(1_234_567) != [1,23,45,67]")

	# format
	if cur.format_coins(0, 2, 5, 30) != "2g 5s 30c":
		failures.append("format_coins(0,2,5,30) != '2g 5s 30c'")
	if cur.format_coins(0, 0, 0, 0) != "0c":
		failures.append("format_coins zero != '0c'")
	if cur.format_coins(0, 0, 0, 350) != "350c":
		failures.append("raw 350 copper must display as '350c'")

	# spend: copper hoard stays intact
	var w: Array[int] = [0, 0, 0, 5000]
	if not cur.spend(w, 1) or w != [0, 0, 0, 4999]:
		failures.append("hoard spend: %s" % str(w))

	# spend: break a platinum for 1c
	w = [1, 0, 0, 0]
	if not cur.spend(w, 1) or w != [0, 99, 99, 99]:
		failures.append("break platinum: %s" % str(w))

	# spend: unaffordable leaves wallet untouched
	w = [0, 0, 1, 0]
	if cur.spend(w, 150) or w != [0, 0, 1, 0]:
		failures.append("unaffordable spend mutated wallet: %s" % str(w))

	# PlayerStats wallet round-trip incl. legacy single-int save
	ps.load_state({"coins": 250})
	if ps.platinum != 0 or ps.copper != 250:
		failures.append("legacy coins=250 didn't land in copper")
	ps.add_coins(5000)  # payout: +50s, copper hoard untouched
	if ps.silver != 50 or ps.copper != 250:
		failures.append("payout consolidated the hoard: %ds %dc" % [ps.silver, ps.copper])
	if not ps.spend_coins(300):
		failures.append("spend_coins(300) failed")
	if ps.total_copper() != 250 + 5000 - 300:
		failures.append("total after spend wrong: %d" % ps.total_copper())
	var saved: Dictionary = ps.save_state()
	ps.load_state(saved)
	if ps.total_copper() != 4950:
		failures.append("save/load round-trip lost coins: %d" % ps.total_copper())

	if failures.is_empty():
		print("CURRENCY_SMOKE_PASS")
	else:
		for f in failures:
			print("CURRENCY_SMOKE_FAIL: %s" % f)
	quit()
