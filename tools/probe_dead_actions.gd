extends SceneTree
# Headless probe for the client's dead guards (2026-10-26): while dead, a
# skill, a spell and turning auto-attack on are refused before anything is
# sent, announced or put on cooldown, with "You cannot do that while dead."
# said once per death; switching auto-attack off still works; and the
# client no longer has an EquipUpdate send. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_dead_actions.gd

const DEAD_LINE := "You cannot do that while dead."

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
	var death = root.get_node("/root/PlayerDeath")
	var log = root.get_node("/root/CombatLog")
	var skills = root.get_node("/root/Skills")
	var spells = root.get_node("/root/Spells")
	var combat = root.get_node("/root/Combat")
	var net = root.get_node("/root/Net")

	var dead_lines: Array[int] = [0]
	var announced: Array[int] = [0]
	log.line_added.connect(func(t: String, _ty: int) -> void:
		if t == DEAD_LINE:
			dead_lines[0] += 1)
	skills.skill_used.connect(func(_sk) -> void: announced[0] += 1)
	spells.spell_cast.connect(func(_sp) -> void: announced[0] += 1)

	var skill := SkillData.new()
	skill.skill_name = "Slash"
	var spell := SpellData.new()
	spell.spell_name = "Smite"

	# A fresh death.
	death.is_dead = true
	death._told_dead = false
	combat.is_auto_attacking = false

	_check(skills.use_skill(skill) == false, "a skill is refused while dead")
	_check(spells.cast_spell(spell) == false, "a spell is refused while dead")
	combat.toggle_auto_attack()
	_check(combat.is_auto_attacking == false, "auto-attack cannot be switched on while dead")
	_check(announced[0] == 0, "nothing is announced (no 'You use' or 'You cast')")
	_check(dead_lines[0] == 1, "the dead line is said once for three refusals (got %d)" % dead_lines[0])

	# Switching auto-attack off is never refused.
	combat.is_auto_attacking = true
	combat.toggle_auto_attack()
	_check(combat.is_auto_attacking == false, "auto-attack can still be switched off while dead")

	# A new death is told again.
	death._told_dead = false
	skills.use_skill(skill)
	_check(dead_lines[0] == 2, "a new death says the line once more")

	# Alive: no refusal line from the guard.
	death.is_dead = false
	var before: int = dead_lines[0]
	_check(death.refuse_if_dead() == false and dead_lines[0] == before, "alive, the guard refuses nothing")

	_check(not net.has_method("broadcast_equip_update"), "the client has no EquipUpdate send")

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
