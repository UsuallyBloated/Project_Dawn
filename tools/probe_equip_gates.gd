extends SceneTree
# Headless probe for the equip gate (2026-10-27): the item refuses the class at
# the equip, as EQ did. A Cleric's club into the off hand is refused with the
# dual wield line and a Warrior 14's with the level line; a Cleric's sword is
# refused as unwieldable and a Monk's leather vest as unwearable; the club goes
# into the Cleric's main hand and a Monk 1's off hand. The old code sent every
# one of these to the server (the off-hand ones with "Your class cannot dual
# wield." printed AFTER the equip). Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_equip_gates.gd

var _fails: int = 0
var _lines: Array[String] = []

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

func _become(player_class: String, level: int) -> void:
	var ps = root.get_node("/root/PlayerStats")
	ps.player_class = player_class
	ps.level = level
	root.get_node("/root/WeaponSkills").initialize(player_class, level)
	root.get_node("/root/ArmorSkills").initialize(player_class, level)
	_lines.clear()

func _run() -> void:
	var eq = root.get_node("/root/Equipment")
	var net = root.get_node("/root/Net")
	root.get_node("/root/CombatLog").line_added.connect(func(text: String, _type: int) -> void: _lines.append(text))
	var club: ItemData = load("res://data/loot/items/cracked_wooden_club.tres")
	var sword: ItemData = load("res://data/loot/items/iron_short_sword.tres")
	var vest: ItemData = load("res://data/loot/items/cracked_leather_vest.tres")
	var boots: ItemData = load("res://data/loot/items/copper_chain_boots.tres")
	# Online: the request path refuses before anything is sent.
	net._char_id = 7

	_become("Cleric", 1)
	_check(not eq.request_equip_from("base", 0, club, "offhand"), "a Cleric's club is refused for the off hand")
	_check(_lines.has("Your class cannot dual wield."), "with the dual wield line (%s)" % [_lines])
	_check(not eq.request_equip_from("base", 1, sword, ""), "a Cleric's sword is refused")
	_check(_lines.has("Your class cannot wield that."), "as unwieldable (%s)" % [_lines])
	_check(eq.equip_refusal(club, "weapon") == "", "the club goes into the Cleric's main hand")
	_check(eq.equip_refusal(boots, "feet") == "", "and chain boots on its feet")

	_become("Warrior", 14)
	_check(eq.equip_refusal(club, "offhand") == "You will be able to dual wield at level 15.", "a Warrior 14's off hand waits for 15")
	_become("Warrior", 15)
	_check(eq.equip_refusal(club, "offhand") == "", "at 15 it goes on")
	_check(eq.equip_refusal(sword, "weapon") == "", "and a Warrior wields a sword")

	# The two-hander rule (2026-10-29): with a club worn in the off hand the
	# staff is refused for the main hand and nothing is sent; with the staff
	# worn, the club is refused for the off hand, no off hand swings, and a
	# club still swaps in for the staff; a staff never sits in the off hand.
	var staff: ItemData = load("res://data/loot/items/carved_staff.tres")
	_check(staff.is_two_handed, "the Carved Staff carries the two-handed flag")
	eq.equipped["weapon"] = club
	eq.equipped["offhand"] = club
	_check(eq.equip_refusal(staff, "weapon") == "Empty your off hand first.", "a staff is refused beside an off-hand weapon")
	_check(not eq.request_equip_from("base", 0, staff, ""), "and the request sends nothing")
	_check(_lines.has("Empty your off hand first."), "with the line (%s)" % [_lines])
	eq.equipped["weapon"] = staff
	eq.equipped["offhand"] = null
	_check(eq.equip_refusal(club, "offhand") == "You cannot hold that with a two-handed weapon.", "nothing joins a two-hander")
	_check(eq.equip_refusal(staff, "offhand") == "A two-handed weapon goes in the main hand.", "a two-hander never sits in the off hand")
	_check(eq.equip_refusal(club, "weapon") == "", "a club swaps in for the staff")
	_check(not root.get_node("/root/Combat")._is_dual_wielding(), "no off-hand swing beside a two-hander")
	eq.equipped["weapon"] = club
	eq.equipped["offhand"] = club
	_check(root.get_node("/root/Combat")._is_dual_wielding(), "two clubs still dual wield")
	eq.equipped["weapon"] = null
	eq.equipped["offhand"] = null

	_become("Monk", 1)
	_check(eq.equip_refusal(club, "offhand") == "", "a Monk 1's club goes into the off hand")
	_check(not eq.request_equip_from("base", 1, vest, ""), "a Monk's leather vest is refused")
	_check(_lines.has("Your class cannot wear that."), "as unwearable (%s)" % [_lines])

	_become("Wizard", 60)
	_check(eq.equip_refusal(boots, "feet") == "Your class cannot wear that.", "a Wizard never wears chain")

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
