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

const MELEE_RANGE             := 3.0
const RANGED_RANGE            := 25.0
const EVASION_PER_AGI         := 0.005
const EVASION_MAX             := 0.50
const CRIT_PER_DEX            := 0.003
const CRIT_MAX                := 0.30
const SPELL_CRIT_PER_INT      := 0.002
const SPELL_CRIT_MAX          := 0.20
const DUAL_WIELD_MISS_PENALTY := 0.20
const OFFHAND_DAMAGE_MULT     := 0.80
const OFFHAND_DELAY_MULT      := 1.50
const ARMOR_DR_DIVISOR        := 100.0

var current_target = null

var _auto_attack_timer: Timer
var _offhand_timer: Timer
var _player: Node3D = null
var _last_crit: bool = false
var god_mode: bool = false

func register_player(node: Node3D) -> void:
	_player = node

func unregister_player() -> void:
	_player = null

func _ready() -> void:
	_auto_attack_timer = Timer.new()
	_auto_attack_timer.wait_time = 2.0
	_auto_attack_timer.timeout.connect(_on_auto_attack)
	add_child(_auto_attack_timer)

	_offhand_timer = Timer.new()
	_offhand_timer.wait_time = 3.0
	_offhand_timer.timeout.connect(_on_offhand_attack)
	add_child(_offhand_timer)

	Equipment.equipment_changed.connect(_on_equipment_changed)

func set_target(node) -> void:
	if current_target == node:
		return
	if is_instance_valid(current_target) and current_target.has_method("set_targeted"):
		current_target.set_targeted(false)
	current_target = node
	if node != null and is_instance_valid(node):
		if node.has_method("set_targeted"):
			node.set_targeted(true)
		# Track 6 sub-task 3: RemotePlayer targets also start the auto-
		# attack timer so PvP swings actually fire. Server's can_attack
		# chokepoint gates whether the damage applies; the timer firing
		# here is just "are we trying to attack." Pure-NPC targets
		# (vendors / dialogue NPCs) fall through and don't start the
		# timer.
		if node.is_in_group("enemies") or node is RemotePlayer:
			if node.has_signal("died") and not node.is_connected("died", _on_target_died):
				node.died.connect(_on_target_died)
			_auto_attack_timer.start()
			if _is_dual_wielding():
				_offhand_timer.start()
		else:
			_auto_attack_timer.stop()
			_offhand_timer.stop()
	else:
		current_target = null
		_auto_attack_timer.stop()
		_offhand_timer.stop()
	target_changed.emit(current_target)

func _is_dual_wielding() -> bool:
	var oh: ItemData = Equipment.equipped.get("offhand")
	return oh != null and oh.type == ItemData.Type.WEAPON

func _on_equipment_changed(slot: String, _item) -> void:
	if slot not in ["weapon", "offhand"] or current_target == null:
		return
	if _is_dual_wielding():
		if _offhand_timer.is_stopped():
			_offhand_timer.start()
	else:
		_offhand_timer.stop()

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
	var weapon: ItemData = Equipment.equipped.get("weapon")
	var is_ranged_weapon := weapon != null and weapon.is_ranged
	var max_range := RANGED_RANGE if is_ranged_weapon else MELEE_RANGE
	if dist > max_range:
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
	if is_ranged_weapon and is_instance_valid(current_target):
		_spawn_arrow_fx(current_target.global_position)
	_try_fire_proc(weapon)
	_update_attack_interval()

func _get_weapon_delay() -> float:
	var weapon: ItemData = Equipment.equipped.get("weapon")
	return weapon.weapon_delay if weapon != null else 2.0

func _update_attack_interval() -> void:
	var haste := BuffManager.get_haste_amount()
	_auto_attack_timer.wait_time = maxf(0.5, _get_weapon_delay() * (1.0 - haste))

func _on_offhand_attack() -> void:
	if not _is_dual_wielding():
		_offhand_timer.stop()
		return
	if current_target == null or not is_instance_valid(current_target):
		set_target(null)
		return
	if current_target.is_dead:
		set_target(null)
		return
	if not is_instance_valid(_player):
		return
	var dist: float = _player.global_position.distance_to(current_target.global_position)
	if dist > MELEE_RANGE:
		_update_offhand_interval()
		return
	var oh: ItemData = Equipment.equipped.get("offhand")
	var skill_name := oh.weapon_skill if oh.weapon_skill != "" else "1h_slashing"
	WeaponSkills.try_advance(skill_name)
	WeaponSkills.try_advance("dual_wield")
	var miss_chance := minf(0.95, WeaponSkills.get_miss_chance(skill_name) + DUAL_WIELD_MISS_PENALTY - BuffManager.get_accuracy_bonus())
	if randf() < miss_chance:
		player_missed_enemy.emit(current_target.mob_name)
		DamageNumbers.spawn_miss(current_target.global_position)
		_update_offhand_interval()
		return
	deal_damage_to_target(calc_offhand_damage(), NetProtocol.DamageType.PHYSICAL, true)
	_try_fire_proc(oh)
	_update_offhand_interval()

func calc_offhand_damage() -> int:
	@warning_ignore("integer_division")
	var str_bonus: int = PlayerStats.strength / 5
	var oh: ItemData = Equipment.equipped.get("offhand")
	var base: int
	if oh != null and oh.weapon_damage_max > 0:
		base = oh.weapon_damage_min + randi_range(0, max(0, oh.weapon_damage_max - oh.weapon_damage_min)) + str_bonus
	else:
		base = randi_range(1, 4) + str_bonus
	base = int(base * OFFHAND_DAMAGE_MULT)
	var skill_name := oh.weapon_skill if oh != null and oh.weapon_skill != "" else "1h_slashing"
	var skill_mult := WeaponSkills.get_damage_multiplier(skill_name)
	var crit_chance := clampf((PlayerStats.dexterity - 10) * CRIT_PER_DEX * 0.6 + BuffManager.get_crit_bonus() * 0.6, 0.0, SPELL_CRIT_MAX)
	_last_crit = randf() < crit_chance
	var crit_mult := randf_range(1.5, 2.0) if _last_crit else 1.0
	return max(1, int(base * skill_mult * crit_mult))

func _update_offhand_interval() -> void:
	var oh: ItemData = Equipment.equipped.get("offhand")
	var delay := (oh.weapon_delay if oh != null else 2.0) * OFFHAND_DELAY_MULT
	var haste := BuffManager.get_haste_amount()
	_offhand_timer.wait_time = maxf(0.5, delay * (1.0 - haste))

func deal_damage_to_target(amount: int, dmg_type: int = NetProtocol.DamageType.PHYSICAL, is_offhand: bool = false, via_spell: bool = false) -> void:
	if not is_instance_valid(current_target) or current_target.is_dead:
		return
	var target_name: String = current_target.mob_name
	var is_crit := _last_crit
	_last_crit = false
	var hit_pos: Vector3 = current_target.global_position
	var target_is_pvp := current_target is RemotePlayer
	_apply_damage_to_node(current_target, amount, is_crit, dmg_type, is_offhand, via_spell)
	# Track 6 sub-task 3: for PvP swings the server applies armor
	# reduction and fans an authoritative Hit — RemotePlayerManager
	# ._on_hit then spawns the authoritative damage number. Suppressing
	# the predictive number here avoids the visual double-spawn where
	# the higher pre-armor value would mask the lower post-armor one.
	# The combat log line is also deferred to _on_hit so it matches the
	# applied amount.
	if not target_is_pvp:
		player_hit_enemy.emit(target_name, amount, is_crit)
		DamageNumbers.spawn_damage(hit_pos, amount, is_crit)

# Routes damage to the right authority for `target`:
#   • RemotePlayer / RemoteEnemy → broadcast Attack (server rolls +
#       applies HP). Track 6 sub-task 3 unified the two — peers and
#       enemies share the same wire path now. The server's step 4h
#       branches on `target_id < ENEMY_ID_BASE` to apply PvP gating
#       (combat::can_attack) for player targets vs the existing
#       enemy-HP path. The `amount` arg is now the client's
#       predictive damage (for floating-number flash); the server
#       ignores it and uses its own roll, then fans the authoritative
#       Hit with the real number.
#   • local Enemy    → local take_damage (Test Room single-player path)
# Centralising the branch keeps deal_damage_to_target, deal_aoe_spell_damage,
# and the proc handler from diverging when the trust model evolves.
#
# `via_spell` — Track 6 sub-task 3b: spell damage routes through the
# server's CastSpell handler (Spells._apply_spell broadcasts that
# separately). Suppressing the Attack broadcast here for spell context
# avoids the server applying damage twice to the same target.
func _apply_damage_to_node(target: Node, amount: int, is_crit: bool, dmg_type: int, is_offhand: bool = false, via_spell: bool = false) -> void:
	if not is_instance_valid(target):
		return
	if target is RemotePlayer or target is RemoteEnemy:
		if via_spell:
			return  # CastSpell intent already in flight; server applies.
		var weapon: ItemData = Equipment.equipped.get("offhand" if is_offhand else "weapon")
		var weapon_path := ""
		if weapon != null and weapon.resource_path != "":
			weapon_path = weapon.resource_path
		var target_id: int = (target as RemotePlayer).char_id if target is RemotePlayer else (target as RemoteEnemy).enemy_id
		Net.broadcast_attack(target_id, weapon_path, is_offhand, dmg_type)
	else:
		target.take_damage(amount)

func deal_aoe_spell_damage(radius: float, amount: int, damage_type: SpellData.DamageType = SpellData.DamageType.NONE) -> void:
	if not is_instance_valid(_player):
		return
	var center := _player.global_position
	var hit_count := 0
	var net_dmg_type := _spell_to_net_damage_type(damage_type)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(center) > radius:
			continue
		var resist: float = enemy.get_spell_resist(damage_type)
		var crit_chance := clampf((PlayerStats.intelligence - 10) * SPELL_CRIT_PER_INT, 0.0, SPELL_CRIT_MAX)
		_last_crit = randf() < crit_chance
		var effective: int = max(1, int(amount * randf_range(1.5, 2.0))) if _last_crit else amount
		effective = max(0, int(effective * (1.0 - resist)))
		if effective > 0:
			var fx_color := spell_color(damage_type)
			# Track 9 — server's AOE arm now applies damage authoritatively
			# from the single CastSpell broadcast spells.gd already sent.
			# _apply_damage_to_node with via_spell=true is a no-op for
			# RemoteEnemy targets; the flash / light / damage number
			# below are local predictive UX, and the server's HealthUpdate
			# fan-out updates the actual enemy HP bar shortly after.
			_apply_damage_to_node(enemy, effective, _last_crit, net_dmg_type, false, true)
			if is_instance_valid(enemy):
				enemy.flash_spell_hit(fx_color)
				spawn_impact_light(enemy.global_position, fx_color)
			player_hit_enemy.emit(enemy.mob_name, effective, _last_crit)
			DamageNumbers.spawn_damage(enemy.global_position, effective, _last_crit)
			hit_count += 1
	if hit_count == 0:
		CombatLog.add_line("Your spell finds no targets in range.", CombatLog.MsgType.INFO)

# Map SpellData's authoring enum onto NetProtocol's wire enum (the latter
# mirrors Rust's `#[repr(u8)] DamageType`). HEALING / NONE have no on-wire
# equivalent — heals don't route through Attack and NONE falls back to
# PHYSICAL for melee-flavoured spells.
func _spell_to_net_damage_type(t: int) -> int:
	match t:
		SpellData.DamageType.FIRE:      return NetProtocol.DamageType.FIRE
		SpellData.DamageType.ICE:       return NetProtocol.DamageType.ICE
		SpellData.DamageType.LIGHTNING: return NetProtocol.DamageType.LIGHTNING
		SpellData.DamageType.ARCANE:    return NetProtocol.DamageType.ARCANE
		SpellData.DamageType.HOLY:      return NetProtocol.DamageType.HOLY
		SpellData.DamageType.NATURE:    return NetProtocol.DamageType.NATURE
		SpellData.DamageType.SPIRIT:    return NetProtocol.DamageType.SPIRIT
		SpellData.DamageType.SHADOW:    return NetProtocol.DamageType.SHADOW
		_:                              return NetProtocol.DamageType.PHYSICAL

func deal_spell_damage(amount: int, damage_type: SpellData.DamageType = SpellData.DamageType.NONE) -> void:
	if not has_valid_target():
		return
	var resist: float = current_target.get_spell_resist(damage_type)
	var crit_chance := clampf((PlayerStats.intelligence - 10) * SPELL_CRIT_PER_INT, 0.0, SPELL_CRIT_MAX)
	_last_crit = randf() < crit_chance
	var effective: int = max(1, int(amount * randf_range(1.5, 2.0))) if _last_crit else amount
	effective = max(0, int(effective * (1.0 - resist)))
	if effective <= 0:
		CombatLog.add_line("%s resists your spell." % current_target.mob_name, CombatLog.MsgType.INFO)
		return
	var fx_target: Node = current_target
	# Track 6 sub-task 3b: spell damage application goes through the
	# server's CastSpell handler (Spells._apply_spell broadcast). Skip
	# the Attack broadcast here so the server doesn't apply damage
	# twice. Local visual (floating number + flash) still fires.
	deal_damage_to_target(effective, _spell_to_net_damage_type(damage_type), false, true)
	if is_instance_valid(fx_target):
		var sc := spell_color(damage_type)
		fx_target.flash_spell_hit(sc)
		spawn_impact_light(fx_target.global_position, sc)

func has_valid_target() -> bool:
	# Track 6 sub-task 3b: PvP targets count too. RemotePlayer lives in
	# the "remote_players" group, not "enemies", so the historical
	# check rejected it and Spells.cast_spell fired "No valid target."
	# before broadcasting. Damage / heal still gates server-side via
	# combat::can_attack; this is just "is there *something* selected
	# that a hostile spell can land on."
	if current_target == null or not is_instance_valid(current_target):
		return false
	if current_target.is_dead:
		return false
	return current_target.is_in_group("enemies") or current_target is RemotePlayer

func receive_player_damage(amount: int, attacker: Node = null, attacker_name: String = "") -> void:
	if PlayerDeath.is_dead:
		return
	if god_mode:
		return
	if attacker != null and is_instance_valid(attacker):
		player_attacked.emit(attacker)
	Spells.try_interrupt_cast()
	if BuffManager.is_evade_boosted():
		player_evaded_attack.emit(attacker_name if attacker_name != "" else "the attack")
		WeaponSkills.try_advance("dodge")
		return
	var evasion_chance := clampf((PlayerStats.agility - 10) * EVASION_PER_AGI, 0.0, EVASION_MAX)
	if randf() < evasion_chance:
		player_evaded_attack.emit(attacker_name if attacker_name != "" else "the attack")
		WeaponSkills.try_advance("dodge")
		return
	WeaponSkills.try_advance("defense")
	ArmorSkills.try_advance_worn(Equipment.equipped)
	var armor := Equipment.get_armor_class()
	var reduction := armor / float(armor + ARMOR_DR_DIVISOR)
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
	# Track 6 fix: in launcher mode the server is authoritative on HP.
	# Mutating PlayerStats locally without telling the server creates a
	# desync where peer-view target frames read the (full) server value
	# while the owner sees the (reduced) local value. Route through
	# DamageSelf so the server applies, recalculates regen, and fans the
	# authoritative HealthUpdate back to all peers. Test Room (single-
	# player) still uses the direct local mutation.
	if Net.is_launcher_mode():
		Net.broadcast_damage_self(effective)
	else:
		PlayerStats.set_hp(PlayerStats.hp - effective)
	player_took_damage.emit(attacker_name if attacker_name != "" else "Something", effective)

func calc_damage() -> int:
	var weapon: ItemData = Equipment.equipped.get("weapon")
	var stat_bonus: int
	if weapon != null and weapon.is_ranged:
		@warning_ignore("integer_division")
		stat_bonus = PlayerStats.dexterity / 5
	else:
		@warning_ignore("integer_division")
		stat_bonus = PlayerStats.strength / 5
	var base: int
	if weapon != null and weapon.weapon_damage_max > 0:
		base = weapon.weapon_damage_min + randi_range(0, max(0, weapon.weapon_damage_max - weapon.weapon_damage_min)) + stat_bonus
	else:
		base = randi_range(1, 4) + stat_bonus
	var skill_mult := WeaponSkills.get_damage_multiplier(_get_weapon_skill_name())
	var crit_chance := clampf((PlayerStats.dexterity - 10) * CRIT_PER_DEX + BuffManager.get_crit_bonus(), 0.0, CRIT_MAX)
	_last_crit = randf() < crit_chance
	var crit_mult := randf_range(1.5, 2.0) if _last_crit else 1.0
	return max(1, int(base * skill_mult * crit_mult))

func spell_color(damage_type: SpellData.DamageType) -> Color:
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

func _spawn_arrow_fx(target_pos: Vector3) -> void:
	if not is_instance_valid(_player):
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var start := _player.global_position + Vector3.UP * 1.2
	var end   := target_pos + Vector3.UP * 0.8

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.02
	cyl.bottom_radius = 0.02
	cyl.height        = 0.5
	mesh_inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.45, 0.2)
	mesh_inst.material_override = mat
	scene.add_child(mesh_inst)

	var travel := end - start
	var dist   := travel.length()
	var duration := clampf(dist / 30.0, 0.05, 0.25)

	mesh_inst.global_position = start
	mesh_inst.look_at(end, Vector3.UP)
	mesh_inst.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	var tw := mesh_inst.create_tween()
	tw.tween_property(mesh_inst, "global_position", end, duration)
	tw.tween_callback(mesh_inst.queue_free)

func spawn_impact_light(pos: Vector3, color: Color) -> void:
	var scene: Node = get_tree().current_scene
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

func _try_fire_proc(weapon: ItemData) -> void:
	if weapon == null or weapon.proc_chance <= 0.0 or weapon.proc_damage <= 0:
		return
	if not has_valid_target():
		return
	if randf() >= weapon.proc_chance:
		return
	var resist: float = current_target.get_spell_resist(weapon.proc_damage_type)
	var is_crit := randf() < 0.05
	var amount := int(weapon.proc_damage * randf_range(1.5, 2.0)) if is_crit else weapon.proc_damage
	amount = max(0, int(amount * (1.0 - resist)))
	if amount <= 0:
		return
	var fx_color := spell_color(weapon.proc_damage_type)
	var fx_target: Node3D = current_target
	var hit_pos: Vector3 = fx_target.global_position
	_apply_damage_to_node(current_target, amount, is_crit, _spell_to_net_damage_type(weapon.proc_damage_type))
	if is_instance_valid(fx_target):
		fx_target.flash_spell_hit(fx_color)
		spawn_impact_light(hit_pos, fx_color)
	var label := weapon.proc_name if weapon.proc_name != "" else "Weapon Proc"
	var suffix := " (Critical!)" if is_crit else "."
	CombatLog.add_line("%s for %d damage%s" % [label, amount, suffix], CombatLog.MsgType.INFO)
	DamageNumbers.spawn_damage(hit_pos, amount, is_crit)

func _get_weapon_skill_name() -> String:
	var weapon: ItemData = Equipment.equipped.get("weapon")
	if weapon == null:
		return "hand_to_hand"
	if weapon.weapon_skill != "":
		return weapon.weapon_skill
	return WeaponItemTable.get_skill(weapon.item_name)
