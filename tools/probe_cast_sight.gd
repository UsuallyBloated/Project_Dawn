extends SceneTree
# Headless probe for the client's sight check (the first hills): a targeted
# cast with terrain between the caster and the target is refused before the
# bar and the mana with the server's line, "You cannot see your target.";
# with the terrain moved away the cast is not refused for sight; and a body
# on layer 1 alone (a mob, a corpse, another player) between them blocks
# nothing, since the ray asks for the terrain layer only. Before the check the
# first case went to the server, which refused it a round trip later. Exits 1
# on any miss. Run:
#   godot --headless --path . -s tools/probe_cast_sight.gd

const SIGHT_LINE := "You cannot see your target."

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

# A wall 2 m thick and 10 m high across x = 10, on `layer`.
func _wall(layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = Vector3(10.0, 5.0, 0.0)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 10.0, 20.0)
	col.shape = box
	body.add_child(col)
	root.add_child(body)
	return body

# Between cases: no global cooldown or spell cooldown left from the last.
func _reset(spells) -> void:
	spells._gcd_remaining = 0.0
	spells._cooldowns.clear("Probe Bolt")

func _run() -> void:
	var spells = root.get_node("/root/Spells")
	var combat = root.get_node("/root/Combat")
	var refusals: Array[String] = []
	spells.spell_failed.connect(func(reason: String) -> void: refusals.append(reason))
	var cast_lines: Array[int] = [0]
	spells.spell_cast.connect(func(_sp) -> void: cast_lines[0] += 1)

	var me := Node3D.new()
	me.add_to_group("player")
	root.add_child(me)
	var target_script := GDScript.new()
	target_script.source_code = "extends Node3D\nvar is_dead := false\n"
	target_script.reload()
	var target: Node3D = target_script.new()
	target.add_to_group("enemies")
	target.position = Vector3(20.0, 0.0, 0.0)
	root.add_child(target)
	combat.set_target(target)

	var spell := SpellData.new()
	spell.spell_name = "Probe Bolt"
	spell.target_type = SpellData.TargetType.ENEMY
	spell.mana_cost = 0.0
	# A timed spell: a cast that passes every check starts a bar (cancelled
	# below), so nothing lands on the stand-in target and no cooldown is left
	# to stop the next case before it reaches the sight check.
	spell.cast_time = 2.0
	spell.cooldown = 0.0

	var wall := _wall(spells.TERRAIN_LAYER_MASK)
	await physics_frame
	await physics_frame
	_check(spells.cast_spell(spell) == false, "a cast with terrain between is refused")
	_check(refusals.has(SIGHT_LINE), "with the server's line (%s)" % [refusals])
	_check(cast_lines[0] == 0, "and nothing is cast")

	wall.free()
	await physics_frame
	await physics_frame
	refusals.clear()
	_check(spells.cast_spell(spell), "with the terrain gone, the cast begins (%s)" % [refusals])
	spells.cancel_cast()
	_reset(spells)

	var body := _wall(1)
	await physics_frame
	await physics_frame
	refusals.clear()
	_check(spells.cast_spell(spell), "a body on layer 1 alone blocks nothing (%s)" % [refusals])
	spells.cancel_cast()
	body.free()

	print("")
	quit(_fails)
