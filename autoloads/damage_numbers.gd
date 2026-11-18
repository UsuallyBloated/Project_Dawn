extends Node

const _Script := preload("res://scripts/damage_number.gd")

func _ready() -> void:
	PlayerStats.healed.connect(spawn_heal)
	# XP gain is announced in chat (CombatLog subscribes to xp_gained); the
	# floating number above the player is the "XP Gains" checkbox under
	# floating text in Options, off by default since it reads as noise to
	# most. Wired 2026-11-18 (user call); before that the checkbox did nothing.
	PlayerStats.xp_gained.connect(func(amount: int, _source: String) -> void:
		spawn_xp(amount))

func spawn_damage(pos: Vector3, amount: int, is_crit: bool) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_damage:
		return
	_spawn(pos, amount, _Script.Type.CRIT if is_crit else _Script.Type.DAMAGE)

func spawn_incoming(pos: Vector3, amount: int) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_damage:
		return
	_spawn(pos, amount, _Script.Type.INCOMING)

func spawn_miss(pos: Vector3) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_misses:
		return
	_spawn(pos, 0, _Script.Type.MISS)

func spawn_heal(amount: int) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_heals:
		return
	# Same threshold as combat_log's "You were healed for X" line —
	# food / drink / HoT regen ticks (1-5 HP) shouldn't litter the
	# screen with floating numbers. Real spell heals (25+) still show.
	const MIN_HEAL_DISPLAY := 10
	if amount < MIN_HEAL_DISPLAY:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_spawn((players[0] as Node3D).global_position, amount, _Script.Type.HEAL)

func spawn_xp(amount: int) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_xp:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_spawn((players[0] as Node3D).global_position, amount, _Script.Type.XP)

func _spawn(pos: Vector3, amount: int, type: DamageNumber.Type) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var lbl := Label3D.new()
	lbl.set_script(_Script)
	lbl.position = pos + Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3))
	scene.add_child(lbl)
	lbl.setup(amount, type)
