extends Node

signal target_changed(enemy)

var current_target = null

var _auto_attack_timer: Timer
var _player: Node3D = null

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

func _on_target_died(_enemy) -> void:
	set_target(null)

func _on_auto_attack() -> void:
	if current_target == null or not is_instance_valid(current_target):
		set_target(null)
		return
	if current_target.is_dead:
		set_target(null)
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	var dist: float = _player.global_position.distance_to(current_target.global_position)
	if dist > 3.0:
		return
	var damage: int = calc_damage()
	current_target.take_damage(damage)
	CombatLog.add_damage_out(current_target.mob_name, damage)

func calc_damage() -> int:
	return PlayerStats.strength / 2 + randi_range(1, 8)
