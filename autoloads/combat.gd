extends Node

signal target_changed(enemy)
signal player_attacked(attacker)

var current_target = null

var _auto_attack_timer: Timer
var _player: Node3D = null

func register_player(node: Node3D) -> void:
	_player = node

func unregister_player() -> void:
	_player = null

func _ready() -> void:
	_auto_attack_timer = Timer.new()
	_auto_attack_timer.wait_time = 2.0
	_auto_attack_timer.timeout.connect(_on_auto_attack)
	add_child(_auto_attack_timer)

func set_target(enemy) -> void:
	if current_target == enemy:
		return
	if is_instance_valid(current_target) and current_target.has_method("set_targeted"):
		current_target.set_targeted(false)
	current_target = enemy
	if enemy != null and is_instance_valid(enemy):
		enemy.set_targeted(true)
		if not enemy.is_connected("died", _on_target_died):
			enemy.died.connect(_on_target_died)
		_auto_attack_timer.start()
	else:
		current_target = null
		_auto_attack_timer.stop()
	target_changed.emit(current_target)

func _on_target_died(enemy) -> void:
	if enemy == current_target:
		set_target(null)

func _on_auto_attack() -> void:
	if current_target == null or not is_instance_valid(current_target):
		set_target(null)
		return
	if current_target.is_dead:
		set_target(null)
		return
	if not is_instance_valid(_player):
		return
	var dist: float = _player.global_position.distance_to(current_target.global_position)
	if dist > 3.0:
		return
	var skill_name := _get_weapon_skill_name()
	WeaponSkills.try_advance(skill_name)
	if randf() < WeaponSkills.get_miss_chance(skill_name):
		CombatLog.add_line("You miss %s." % current_target.mob_name, CombatLog.MsgType.DAMAGE_OUT)
		return
	deal_damage_to_target(calc_damage())

func deal_damage_to_target(amount: int) -> void:
	if not is_instance_valid(current_target) or current_target.is_dead:
		return
	var target_name: String = current_target.mob_name
	current_target.take_damage(amount)
	CombatLog.add_damage_out(target_name, amount)

func has_valid_target() -> bool:
	return current_target != null and is_instance_valid(current_target) and not current_target.is_dead

func receive_player_damage(amount: int, attacker: Node = null, attacker_name: String = "") -> void:
	if PlayerDeath.is_dead:
		return
	if attacker != null and is_instance_valid(attacker):
		player_attacked.emit(attacker)
	Spells.cancel_cast()
	if BuffManager.is_evade_boosted():
		CombatLog.add_evade(attacker_name if attacker_name != "" else "the attack")
		WeaponSkills.try_advance("dodge")
		return
	var evasion_chance := clampf((PlayerStats.agility - 10) * 0.005, 0.0, 0.50)
	if randf() < evasion_chance:
		CombatLog.add_evade(attacker_name if attacker_name != "" else "the attack")
		WeaponSkills.try_advance("dodge")
		return
	WeaponSkills.try_advance("defense")
	var armor := Equipment.get_armor_class()
	var reduction := armor / float(armor + 100)
	var was_sitting: bool = is_instance_valid(_player) and _player.state == PlayerCharacter.PlayerState.SITTING
	var sit_mult := 2.0 if was_sitting else 1.0
	var effective: int = max(1, int(amount * (1.0 - reduction) * sit_mult))
	if was_sitting:
		_player.stand()
	effective = BuffManager.consume_absorb(effective)
	if effective <= 0:
		return
	PlayerStats.set_hp(PlayerStats.hp - effective)
	CombatLog.add_line(
		"%s hits you for %d damage." % [attacker_name if attacker_name != "" else "Something", effective],
		CombatLog.MsgType.DAMAGE_IN
	)

func calc_damage() -> int:
	var str_bonus: int = PlayerStats.strength / 5
	var weapon: ItemData = Equipment.equipped.get("weapon")
	var base: int
	if weapon != null and weapon.weapon_damage_max > 0:
		base = weapon.weapon_damage_min + randi_range(0, max(0, weapon.weapon_damage_max - weapon.weapon_damage_min)) + str_bonus
	else:
		base = randi_range(1, 4) + str_bonus
	var skill_mult := WeaponSkills.get_damage_multiplier(_get_weapon_skill_name())
	return max(1, int(base * skill_mult))

func _get_weapon_skill_name() -> String:
	var weapon: ItemData = Equipment.equipped.get("weapon")
	if weapon != null and weapon.weapon_skill != "":
		return weapon.weapon_skill
	return "hand_to_hand"
