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
# Fired when the auto-attack toggle flips. UI subscribers (e.g. a HUD
# indicator) and combat_log render based on this.
signal auto_attack_toggled(on: bool)

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
# Auto-attack toggle (keybind: `toggle_auto_attack`, default Q). When
# false, the swing timer never starts, regardless of target. When true,
# swings fire only against valid combat targets (currently NPC enemies;
# RemotePlayers are silent-skipped until PvP target validation lands).
var is_auto_attacking: bool = false

var _auto_attack_timer: Timer
var _offhand_timer: Timer
var _player: Node3D = null
var _last_crit: bool = false
var god_mode: bool = false

func register_player(node: Node3D) -> void:
	_player = node

func is_player_seated() -> bool:
	return is_instance_valid(_player) and _player.state == PlayerCharacter.PlayerState.SITTING

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
	# Disengage auto-attack when the local player dies (PvP knockout,
	# fall, etc.). Without this the timer keeps firing on the corpse
	# and the "Auto attack is now OFF." cue never appears, which left
	# Round-3 verification flagging the case.
	PlayerDeath.player_died.connect(_on_player_died)

func set_target(node) -> void:
	if current_target == node:
		return
	if is_instance_valid(current_target) and current_target.has_method("set_targeted"):
		current_target.set_targeted(false)
	current_target = node
	if node != null and is_instance_valid(node):
		if node.has_method("set_targeted"):
			node.set_targeted(true)
		# Subscribe to death so the timer stops when the target dies
		# even if the player keeps auto-attack engaged. RemotePlayer
		# is included here so the targeting bookkeeping still fires;
		# the timer-start gate below silent-skips peer auto-attack.
		if node.is_in_group("enemies") or node is RemotePlayer or node is RemotePet:
			if node.has_signal("died") and not node.is_connected("died", _on_target_died):
				node.died.connect(_on_target_died)
		_sync_auto_attack_timer()
		# Targeting feedback when auto-attack is engaged but the target
		# won't be swung at (peer / friendly NPC / non-combat object).
		# Helps the player notice they're locked in attack stance before
		# they walk up to a friendly NPC and start (or fail to start) a
		# fight by accident.
		if is_auto_attacking and not _target_is_attackable():
			var nm := _target_display_name(node)
			if nm != "":
				CombatLog.add_line("You cannot attack %s." % nm, CombatLog.MsgType.INFO)
			else:
				CombatLog.add_line("You cannot attack that target.", CombatLog.MsgType.INFO)
	else:
		current_target = null
		_auto_attack_timer.stop()
		_offhand_timer.stop()
	target_changed.emit(current_target)

func _target_display_name(node) -> String:
	if node == null:
		return ""
	if "mob_name" in node:
		var mn = node.get("mob_name")
		if mn != null and String(mn) != "":
			return String(mn)
	if "pet_name" in node:
		var pet_nm = node.get("pet_name")
		if pet_nm != null and String(pet_nm) != "":
			return String(pet_nm)
	if "player_name" in node:
		var pn = node.get("player_name")
		if pn != null and String(pn) != "":
			return String(pn)
	return ""
	# Track 22.H — broadcast the new target id to the server so peers
	# can render target-of-target for the local player. Extracts the
	# id from whichever node type the target is (RemoteEnemy /
	# RemotePlayer / RemotePet). Solo / Test Room targets have no
	# server id and broadcast 0 (no-op for peers since there are none).
	if Net.is_launcher_mode():
		var tid: int = 0
		if is_instance_valid(current_target):
			if "enemy_id" in current_target:
				tid = current_target.enemy_id
			elif "char_id" in current_target:
				tid = current_target.char_id
			elif "pet_id" in current_target:
				tid = current_target.pet_id
		Net.broadcast_set_target(tid)

func toggle_auto_attack() -> void:
	is_auto_attacking = not is_auto_attacking
	auto_attack_toggled.emit(is_auto_attacking)
	_sync_auto_attack_timer()

func _target_is_attackable() -> bool:
	if not is_instance_valid(current_target):
		return false
	# Own pet is never a valid auto-attack target — pre-reject before
	# the timer starts so the player doesn't get spammed with
	# "Unable to attack <Self>'s Wolf." on every swing.
	if current_target is RemotePet and (current_target as RemotePet).owner_id == Net.get_player_id():
		return false
	# Peers (RemotePlayer) and player-owned pets (RemotePet) are also
	# attackable from the client's POV — the server's PvP gate decides
	# whether the swing actually lands. Rejected swings fan an explicit
	# "Unable to attack X." chat line back to the attacker, so the
	# player gets clear feedback either way.
	return (
		current_target.is_in_group("enemies")
		or current_target is RemotePlayer
		or current_target is RemotePet
	)

func _sync_auto_attack_timer() -> void:
	if is_auto_attacking and _target_is_attackable():
		_auto_attack_timer.start()
		if _is_dual_wielding():
			_offhand_timer.start()
	else:
		_auto_attack_timer.stop()
		_offhand_timer.stop()

func _is_dual_wielding() -> bool:
	var oh: ItemData = Equipment.equipped.get("offhand")
	return oh != null and oh.type == ItemData.Type.WEAPON

func _on_equipment_changed(slot: String, _item) -> void:
	if slot not in ["weapon", "offhand"] or current_target == null:
		return
	# Dual-wield onset/offset honors the auto-attack toggle. Re-syncing
	# both timers keeps the main + offhand cadence consistent.
	_sync_auto_attack_timer()

func _on_player_died() -> void:
	if is_auto_attacking:
		toggle_auto_attack()
	set_target(null)

func _on_target_died(enemy) -> void:
	if enemy == current_target:
		# Target death disengages auto-attack — the player must
		# acquire a new target and re-press the toggle. Matches the
		# WoW-style explicit-engage flow (rather than EQ's persistent
		# auto-attack that follows you to the next target).
		if is_auto_attacking:
			toggle_auto_attack()
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
	# Standing is required to swing (EQ-style): a swing stands a seated player.
	# Mirrors the server-side auto-stand in the attack apply so the visual and the
	# server's `is_sitting` agree. `stand()` also forwards a Stand to the server
	# through regen.gd's sit/stand transition watcher.
	if is_player_seated():
		_player.stand()
	var dist: float = _player.global_position.distance_to(current_target.global_position)
	var weapon: ItemData = Equipment.equipped.get("weapon")
	var is_ranged_weapon := weapon != null and weapon.is_ranged
	var max_range := RANGED_RANGE if is_ranged_weapon else MELEE_RANGE
	if dist > max_range:
		# Log every tick — the player asked for the "Target is out of
		# range." line to keep firing at the swing cadence as a visible
		# reminder that auto-attack is still engaged.
		CombatLog.add_line("Target is out of range.", CombatLog.MsgType.INFO)
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
	# Weapon procs are server-authoritative (PD_W0025): the server rolls
	# proc_chance on the landed swing, applies proc_damage, and sends
	# ProcTriggered, which RemotePlayerManager renders. The client no longer
	# rolls or sends the proc (the old client-sent proc Attack double-hit and is
	# dropped by the swing-rate limit anyway).
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
	# Procs are server-authoritative now (see the main-hand note in _on_auto_attack).
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
	var target_name: String = ""
	if "mob_name" in current_target:
		target_name = current_target.mob_name
	elif "pet_name" in current_target:
		target_name = current_target.pet_name
	var is_crit := _last_crit
	_last_crit = false
	var hit_pos: Vector3 = current_target.global_position
	# Server is authoritative for damage on any remote network entity
	# (RemotePlayer / RemoteEnemy / RemotePet). For all three the
	# client suppresses the predictive damage number and chat line —
	# the server's Hit fan-out drives the visible damage, and a
	# rejected attack (PvP gate or otherwise) shouldn't leave a
	# misleading "You hit X" in the log.
	var target_is_remote := (
		current_target is RemotePlayer
		or current_target is RemoteEnemy
		or current_target is RemotePet
	)
	_apply_damage_to_node(current_target, amount, is_crit, dmg_type, is_offhand, via_spell)
	if not target_is_remote:
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
	if target is RemotePlayer or target is RemoteEnemy or target is RemotePet:
		if via_spell:
			return  # CastSpell intent already in flight; server applies.
		var weapon: ItemData = Equipment.equipped.get("offhand" if is_offhand else "weapon")
		var weapon_path := ""
		if weapon != null and weapon.resource_path != "":
			weapon_path = weapon.resource_path
		var target_id: int = 0
		if target is RemotePlayer:
			target_id = (target as RemotePlayer).char_id
		elif target is RemoteEnemy:
			target_id = (target as RemoteEnemy).enemy_id
		elif target is RemotePet:
			target_id = (target as RemotePet).pet_id
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
		var nm := _target_display_name(current_target)
		CombatLog.add_line("%s resists your spell." % (nm if nm != "" else "The target"), CombatLog.MsgType.INFO)
		return
	var fx_target: Node = current_target
	var fx_is_remote := (
		fx_target is RemotePlayer
		or fx_target is RemoteEnemy
		or fx_target is RemotePet
	)
	# Spell damage application goes through the server's CastSpell
	# handler (Spells._apply_spell broadcast). Skip the Attack broadcast
	# here so the server doesn't apply damage twice. For remote targets
	# we also defer the elemental flash + impact light until the server
	# confirms the hit (see RemotePlayerManager._on_hit); otherwise a
	# PvP-rejected or out-of-range cast still flashes the victim, which
	# misreads as "spell landed."
	deal_damage_to_target(effective, _spell_to_net_damage_type(damage_type), false, true)
	if not fx_is_remote and is_instance_valid(fx_target):
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
	return current_target.is_in_group("enemies") or current_target is RemotePlayer or current_target is RemotePet

func receive_player_damage(amount: int, attacker: Node = null, attacker_name: String = "") -> void:
	if PlayerDeath.is_dead:
		return
	if god_mode:
		return
	if attacker != null and is_instance_valid(attacker):
		player_attacked.emit(attacker)
	Spells.try_interrupt_cast()
	# Track 22.C — any incoming hit dismounts the rider. Classic-EQ
	# feel; mounts are travel tools, not combat platforms.
	MountManager.dismount("hit")
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

# NetProtocol.DamageType → elemental color. Used by the server-Hit
# fan-back render path so spell visuals (flash, impact light) only fire
# on confirmed landings. PHYSICAL returns WHITE; melee hit flashes use
# a separate mesh-tint path and shouldn't burst an OmniLight.
func net_damage_color(net_dt: int) -> Color:
	match net_dt:
		NetProtocol.DamageType.FIRE:      return Color(1.0, 0.45, 0.10)
		NetProtocol.DamageType.ICE:       return Color(0.50, 0.85, 1.0)
		NetProtocol.DamageType.LIGHTNING: return Color(1.0, 1.0, 0.20)
		NetProtocol.DamageType.ARCANE:    return Color(0.90, 0.40, 1.0)
		NetProtocol.DamageType.HOLY:      return Color(1.0, 1.0, 0.60)
		NetProtocol.DamageType.NATURE:    return Color(0.20, 1.0, 0.30)
		NetProtocol.DamageType.SPIRIT:    return Color(0.70, 0.50, 1.0)
		NetProtocol.DamageType.SHADOW:    return Color(0.50, 0.10, 0.80)
	return Color.WHITE

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

func _get_weapon_skill_name() -> String:
	var weapon: ItemData = Equipment.equipped.get("weapon")
	if weapon == null:
		return "hand_to_hand"
	if weapon.weapon_skill != "":
		return weapon.weapon_skill
	return WeaponItemTable.get_skill(weapon.item_name)
