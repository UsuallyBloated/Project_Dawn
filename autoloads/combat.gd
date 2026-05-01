extends Node

signal target_changed(enemy)
signal player_attacked(attacker)
signal player_hit_enemy(target_name: String, amount: int, is_crit: bool)
signal player_missed_enemy(target_name: String)
signal player_evaded_attack(attacker_name: String)
signal player_took_damage(attacker_name: String, amount: int)

signal enemy_stunned(mob_name: String)
signal enemy_stun_wore_off(mob_name: String)
signal enemy_rooted(mob_name: String)
signal enemy_snared(mob_name: String)
signal enemy_slowed(mob_name: String)
signal enemy_mez_applied(mob_name: String)
signal enemy_mez_broke(mob_name: String)
signal enemy_charmed_attacked(attacker: String, target: String, amount: int)
signal enemy_silenced(mob_name: String)

var current_target = null

var _auto_attack_timer: Timer
var _player: Node3D = null
var _last_crit: bool = false

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
		_update_attack_interval()
		return
	var skill_name := _get_weapon_skill_name()
	WeaponSkills.try_advance(skill_name)
	var miss_chance := maxf(0.0, WeaponSkills.get_miss_chance(skill_name) - BuffManager.get_accuracy_bonus())
	if randf() < miss_chance:
		player_missed_enemy.emit(current_target.mob_name)
		DamageNumbers.spawn_miss(current_target.global_position)
		_update_attack_interval()
		return
	deal_damage_to_target(calc_damage())
	_update_attack_interval()

func _get_weapon_delay() -> float:
	var weapon: ItemData = Equipment.equipped.get("weapon")
	return weapon.weapon_delay if weapon != null else 2.0

func _update_attack_interval() -> void:
	var haste := BuffManager.get_haste_amount()
	_auto_attack_timer.wait_time = maxf(0.5, _get_weapon_delay() * (1.0 - haste))

func deal_damage_to_target(amount: int) -> void:
	if not is_instance_valid(current_target) or current_target.is_dead:
		return
	var target_name: String = current_target.mob_name
	var is_crit := _last_crit
	_last_crit = false
	var hit_pos: Vector3 = current_target.global_position
	current_target.take_damage(amount)
	player_hit_enemy.emit(target_name, amount, is_crit)
	DamageNumbers.spawn_damage(hit_pos, amount, is_crit)

func deal_spell_damage(amount: int, damage_type: SpellData.DamageType = SpellData.DamageType.NONE) -> void:
	if not has_valid_target():
		return
	var resist: float = current_target.get_spell_resist(damage_type)
	var crit_chance := clampf((PlayerStats.intelligence - 10) * 0.002, 0.0, 0.20)
	_last_crit = randf() < crit_chance
	var effective: int = max(1, int(amount * randf_range(1.5, 2.0))) if _last_crit else amount
	effective = max(0, int(effective * (1.0 - resist)))
	if effective <= 0:
		CombatLog.add_line("%s resists your spell." % current_target.mob_name, CombatLog.MsgType.INFO)
		return
	var fx_target: Node = current_target
	deal_damage_to_target(effective)
	if is_instance_valid(fx_target):
		var sc := _spell_color(damage_type)
		fx_target.flash_spell_hit(sc)
		_spawn_impact_light(fx_target.global_position, sc)

func has_valid_target() -> bool:
	return current_target != null and is_instance_valid(current_target) and not current_target.is_dead

func receive_player_damage(amount: int, attacker: Node = null, attacker_name: String = "") -> void:
	if PlayerDeath.is_dead:
		return
	if attacker != null and is_instance_valid(attacker):
		player_attacked.emit(attacker)
	Spells.try_interrupt_cast()
	if BuffManager.is_evade_boosted():
		player_evaded_attack.emit(attacker_name if attacker_name != "" else "the attack")
		WeaponSkills.try_advance("dodge")
		return
	var evasion_chance := clampf((PlayerStats.agility - 10) * 0.005, 0.0, 0.50)
	if randf() < evasion_chance:
		player_evaded_attack.emit(attacker_name if attacker_name != "" else "the attack")
		WeaponSkills.try_advance("dodge")
		return
	WeaponSkills.try_advance("defense")
	ArmorSkills.try_advance_worn(Equipment.equipped)
	var armor := Equipment.get_armor_class()
	var reduction := armor / float(armor + 100)
	var was_sitting: bool = is_instance_valid(_player) and _player.state == PlayerCharacter.PlayerState.SITTING
	var sit_mult := 2.0 if was_sitting else 1.0
	var effective: int = max(1, int(amount * (1.0 - reduction) * sit_mult))
	if was_sitting:
		_player.stand()
	var shield_dmg := BuffManager.get_damage_shield_amount()
	if shield_dmg > 0.0 and attacker != null and is_instance_valid(attacker) and not attacker.is_dead:
		attacker.take_damage(int(shield_dmg))
	effective = BuffManager.consume_absorb(effective)
	if effective <= 0:
		return
	PlayerStats.set_hp(PlayerStats.hp - effective)
	player_took_damage.emit(attacker_name if attacker_name != "" else "Something", effective)

func calc_damage() -> int:
	var str_bonus: int = PlayerStats.strength / 5
	var weapon: ItemData = Equipment.equipped.get("weapon")
	var base: int
	if weapon != null and weapon.weapon_damage_max > 0:
		base = weapon.weapon_damage_min + randi_range(0, max(0, weapon.weapon_damage_max - weapon.weapon_damage_min)) + str_bonus
	else:
		base = randi_range(1, 4) + str_bonus
	var skill_mult := WeaponSkills.get_damage_multiplier(_get_weapon_skill_name())
	var crit_chance := clampf((PlayerStats.dexterity - 10) * 0.003 + BuffManager.get_crit_bonus(), 0.0, 0.30)
	_last_crit = randf() < crit_chance
	var crit_mult := randf_range(1.5, 2.0) if _last_crit else 1.0
	return max(1, int(base * skill_mult * crit_mult))

func _spell_color(damage_type: SpellData.DamageType) -> Color:
	match damage_type:
		SpellData.DamageType.FIRE:      return Color(1.0, 0.45, 0.10)
		SpellData.DamageType.ICE:       return Color(0.50, 0.85, 1.0)
		SpellData.DamageType.LIGHTNING: return Color(1.0, 1.0, 0.20)
		SpellData.DamageType.ARCANE:    return Color(0.90, 0.40, 1.0)
		SpellData.DamageType.HOLY:      return Color(1.0, 1.0, 0.60)
		SpellData.DamageType.NATURE:    return Color(0.20, 1.0, 0.30)
		SpellData.DamageType.SPIRIT:    return Color(0.70, 0.50, 1.0)
		SpellData.DamageType.SHADOW:    return Color(0.50, 0.10, 0.80)
	return Color.WHITE

func _spawn_impact_light(pos: Vector3, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 5.0
	light.omni_range = 4.0
	light.position = pos + Vector3.UP * 0.5
	scene.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)

func _get_weapon_skill_name() -> String:
	var weapon: ItemData = Equipment.equipped.get("weapon")
	if weapon == null:
		return "hand_to_hand"
	if weapon.weapon_skill != "":
		return weapon.weapon_skill
	return WeaponItemTable.get_skill(weapon.item_name)
