extends SceneTree
# Headless probe for the ammo slot (2026-11-13): arrows pick the ammo slot and
# fit nowhere else, nothing else fits it, the quiver's count follows the
# server's deltas, and a bow with an empty quiver fires nothing (the line, no
# attack sent) while one with arrows shoots. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_ammo_slot.gd

const ENEMY_SCENE := "res://scenes/remote_enemy.tscn"

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

func _run() -> void:
	var eq = root.get_node("/root/Equipment")
	var combat = root.get_node("/root/Combat")
	var ps = root.get_node("/root/PlayerStats")
	root.get_node("/root/CombatLog").line_added.connect(func(text: String, _type: int) -> void: _lines.append(text))
	var arrows: ItemData = load("res://data/loot/items/arrow_bundle.tres")
	var bow: ItemData = load("res://data/loot/items/hunters_shortbow.tres")
	var sword: ItemData = load("res://data/loot/items/iron_short_sword.tres")
	ps.player_name = "ProbeArcher"
	ps.apply_character("Human", "Ranger", 15)
	root.get_node("/root/WeaponSkills").initialize("Ranger", 15)
	root.get_node("/root/ArmorSkills").initialize("Ranger", 15)

	# The slot and the fit.
	_check(eq.SLOTS.size() == 10 and eq.SLOTS[9] == "ammo", "the ammo slot is the tenth (%s)" % [eq.SLOTS])
	_check(arrows.type == ItemData.Type.AMMO, "the arrows are AMMO")
	_check(eq._pick_slot(arrows) == "ammo", "arrows pick the ammo slot")
	_check(eq._is_valid_target_slot(arrows, "ammo"), "arrows fit the ammo slot")
	_check(not eq._is_valid_target_slot(arrows, "weapon"), "arrows do not fit the main hand")
	_check(not eq._is_valid_target_slot(arrows, "offhand"), "arrows do not fit the off hand")
	_check(not eq._is_valid_target_slot(sword, "ammo"), "a sword does not fit the ammo slot")
	_check(not eq._is_valid_target_slot(bow, "ammo"), "a bow does not fit the ammo slot")
	_check(eq.equip_refusal(arrows, "ammo") == "", "no class refuses arrows")

	# The count follows the deltas.
	_check(eq.ammo_count() == 0, "an empty quiver counts 0")
	eq.apply_remote_equip(9, arrows, 2)
	_check(eq.ammo_count() == 2 and eq.equipped["ammo"] == arrows, "two arrows in the quiver count 2")
	eq.apply_remote_equip(9, arrows, 1)
	_check(eq.ammo_count() == 1, "a shot's delta leaves 1")
	eq.apply_remote_unequip(9)
	_check(eq.ammo_count() == 0 and eq.equipped["ammo"] == null, "the last arrow's delta empties the quiver")

	# A bow with an empty quiver fires nothing; with arrows it shoots.
	var enemy = load(ENEMY_SCENE).instantiate()
	root.add_child(enemy)
	# The combat tick needs a registered player for the range check; a bare
	# node at the origin beside the enemy stands in for the scene's body. The
	# shot itself goes nowhere headless (no connection, no scene for the arrow
	# effect), so the line is the evidence either way.
	var stand_in := _StandIn.new()
	root.add_child(stand_in)
	combat.register_player(stand_in)
	eq.equipped["weapon"] = bow
	eq.equipped["offhand"] = null
	combat.set_target(enemy)
	_lines.clear()
	combat._on_auto_attack()
	_check(_lines.has(combat.NO_AMMUNITION_LINE), "an empty quiver says so (%s)" % [_lines])
	eq.apply_remote_equip(9, arrows, 3)
	_lines.clear()
	combat._on_auto_attack()
	_check(not _lines.has(combat.NO_AMMUNITION_LINE), "with arrows the shot goes (%s)" % [_lines])
	eq.equipped["weapon"] = sword
	eq.apply_remote_unequip(9)
	_lines.clear()
	combat._on_auto_attack()
	_check(not _lines.has(combat.NO_AMMUNITION_LINE), "a sword needs no arrow (%s)" % [_lines])

	print("\nprobe_ammo_slot: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)

# The player the combat tick reads: standing (PlayerCharacter.PlayerState's
# 0; naming the class here would parse player.gd before the autoloads exist),
# at the origin.
class _StandIn extends Node3D:
	var state: int = 0
	func stand() -> void:
		state = 0
