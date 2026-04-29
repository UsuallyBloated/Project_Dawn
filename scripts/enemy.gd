class_name Enemy
extends CharacterBody3D

signal died(enemy)
signal hp_changed(current: float, maximum: float)
signal charm_broke

const GRAVITY := -20.0

@export_group("Identity")
@export var mob_name:   String    = "Skeleton"
@export var level:      int       = 1
@export var loot_table: LootTable = null

@export_group("Stats")
@export var max_hp:      float = 50.0
@export var xp_reward:   int   = 20
@export var base_damage: int   = 5

@export_group("Behaviour")
@export var aggro_range:     float = 10.0
@export var melee_range:     float = 1.8
@export var leash_range:     float = 20.0
@export var move_speed:      float = 2.5
@export var attack_interval: float = 2.5

var hp: float
var is_charmed: bool = false
var _charm_timer: float = 0.0
var is_mezzed: bool = false
var _mez_timer: float = 0.0

enum State { IDLE, CHASE, ATTACK, LEASH, DEAD }
var state := State.IDLE
var is_dead: bool:
	get:
		return state == State.DEAD

var _player:          Node3D = null
var _attack_cooldown: float  = 0.0
var _spawn_position:  Vector3

@onready var _target_indicator: MeshInstance3D = $TargetIndicator
@onready var _name_label:       Label3D        = $NameLabel

var _flash_tween: Tween = null

func _ready() -> void:
	hp = max_hp
	_spawn_position = global_position
	add_to_group("enemies")
	_name_label.text = mob_name
	if loot_table == null:
		loot_table = _build_default_loot_table()
	Loot.register_enemy(self)

func _build_default_loot_table() -> LootTable:
	var table := LootTable.new()
	table.rolls = 1
	table.empty_weight = 1.5
	table.entries.append(_make_loot_entry("Tattered Cloth",  "A scrap of worn cloth.",       ItemData.Type.MISC,    ItemData.Rarity.COMMON,   2.0))
	table.entries.append(_make_loot_entry("Bone Fragment",   "A brittle piece of bone.",     ItemData.Type.MISC,    ItemData.Rarity.COMMON,   1.5))
	if level >= 1:
		var sword := _make_loot_entry("Rusty Shortsword", "A worn, pitted blade.", ItemData.Type.WEAPON, ItemData.Rarity.COMMON, 0.8)
		sword.item.weapon_damage_min = 2 + level
		sword.item.weapon_damage_max = 6 + level * 2
		table.entries.append(sword)
	if level >= 2:
		var buckler := _make_loot_entry("Cracked Buckler", "A battered round shield.", ItemData.Type.OFFHAND, ItemData.Rarity.COMMON, 0.6)
		buckler.item.bonus_armor = 4 + level
		table.entries.append(buckler)
		var helm := _make_loot_entry("Tattered Helm", "Barely wearable leather.", ItemData.Type.HEAD, ItemData.Rarity.COMMON, 0.6)
		helm.item.bonus_armor = 3 + level
		table.entries.append(helm)
	if level >= 3:
		var ring := _make_loot_entry("Iron Ring", "A simple iron band.", ItemData.Type.RING, ItemData.Rarity.UNCOMMON, 0.3)
		ring.item.bonus_strength = 2
		table.entries.append(ring)
	return table

func _make_loot_entry(iname: String, idesc: String, itype: ItemData.Type, irarity: ItemData.Rarity, iweight: float) -> LootEntry:
	var item := ItemData.new()
	item.item_name   = iname
	item.description = idesc
	item.type        = itype
	item.rarity      = irarity
	var entry := LootEntry.new()
	entry.item      = item
	entry.weight    = iweight
	entry.min_count = 1
	entry.max_count = 1
	return entry

func _physics_process(delta: float) -> void:
	if is_charmed:
		_charm_timer -= delta
		if _charm_timer <= 0.0:
			break_charm()
	if is_mezzed:
		_mez_timer -= delta
		if _mez_timer <= 0.0:
			_break_mez_expire()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	match state:
		State.IDLE:   _tick_idle()
		State.CHASE:  _tick_chase()
		State.ATTACK: _tick_attack(delta)
		State.LEASH:  _tick_leash()
		State.DEAD:   pass
	move_and_slide()

func _transition(new_state: State) -> void:
	state = new_state
	if new_state in [State.IDLE, State.DEAD]:
		velocity.x = 0.0
		velocity.z = 0.0

# ── state ticks ───────────────────────────────────────────────────────────────

func _tick_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_charmed:
		if Combat.has_valid_target() and Combat.current_target != self:
			_transition(State.CHASE)
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) <= aggro_range and not PlayerDeath.is_dead:
		_transition(State.CHASE)

func _tick_chase() -> void:
	if is_charmed:
		var t = Combat.current_target
		if t == null or not is_instance_valid(t) or t.is_dead or t == self:
			_transition(State.IDLE)
			return
		var dist := global_position.distance_to(t.global_position)
		if dist > leash_range:
			_transition(State.IDLE)
		elif dist <= melee_range:
			_transition(State.ATTACK)
		else:
			_move_toward(t.global_position)
		return
	if not _player_valid():
		_transition(State.LEASH)
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > leash_range:
		_transition(State.LEASH)
	elif dist <= melee_range:
		_transition(State.ATTACK)
	else:
		_move_toward(_player.global_position)

func _tick_attack(delta: float) -> void:
	if is_charmed:
		var t = Combat.current_target
		if t == null or not is_instance_valid(t) or t.is_dead or t == self:
			_transition(State.IDLE)
			return
		var dist := global_position.distance_to(t.global_position)
		if dist > melee_range * 1.2:
			_transition(State.CHASE)
			return
		velocity.x = 0.0
		velocity.z = 0.0
		_face_toward(t.global_position)
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval
			var tname: String = t.mob_name
			t.take_damage(base_damage)
			if is_instance_valid(t):
				DamageNumbers.spawn(t.global_position, base_damage, false)
			CombatLog.add_line(
				"%s hits %s for %d." % [mob_name, tname, base_damage],
				CombatLog.MsgType.DAMAGE_OUT
			)
		return
	if not _player_valid():
		_transition(State.LEASH)
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > melee_range * 1.2:  # small buffer to prevent CHASE/ATTACK ping-pong
		_transition(State.CHASE)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_face_toward(_player.global_position)
	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0:
		_attack_cooldown = attack_interval
		_do_attack()

func _tick_leash() -> void:
	if is_charmed:
		_transition(State.IDLE)
		return
	if global_position.distance_to(_spawn_position) < 0.5:
		hp = max_hp
		hp_changed.emit(hp, max_hp)
		_transition(State.IDLE)
	else:
		_move_toward(_spawn_position)

# ── helpers ───────────────────────────────────────────────────────────────────

func _player_valid() -> bool:
	return _player != null and is_instance_valid(_player) and not PlayerDeath.is_dead

func _move_toward(target_pos: Vector3) -> void:
	var dir := (target_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face_toward(target_pos)

func _face_toward(target_pos: Vector3) -> void:
	var look_pos := Vector3(target_pos.x, global_position.y, target_pos.z)
	if look_pos.distance_to(global_position) > 0.01:
		look_at(look_pos, Vector3.UP)

func _do_attack() -> void:
	Combat.receive_player_damage(base_damage, self, mob_name)
	if _player_valid():
		DamageNumbers.spawn(_player.global_position, base_damage, true)

# ── public API ────────────────────────────────────────────────────────────────

func mesmerize(duration: float) -> void:
	if state == State.DEAD or is_charmed:
		return
	is_mezzed = true
	_mez_timer = duration
	_name_label.modulate = Color(0.85, 0.50, 1.00)
	CombatLog.add_line("%s is mesmerized!" % mob_name, CombatLog.MsgType.INFO)

func _break_mez_damage() -> void:
	is_mezzed = false
	_mez_timer = 0.0
	_name_label.modulate = Color.WHITE
	CombatLog.add_line("The mesmerize on %s breaks!" % mob_name, CombatLog.MsgType.INFO)

func _break_mez_expire() -> void:
	is_mezzed = false
	_mez_timer = 0.0
	_name_label.modulate = Color.WHITE

func charm(duration: float) -> void:
	is_charmed = true
	_charm_timer = duration
	_name_label.modulate = Color(0.5, 0.8, 1.0, 1.0)
	if state in [State.CHASE, State.ATTACK, State.LEASH]:
		_transition(State.IDLE)

func break_charm() -> void:
	if not is_charmed:
		return
	is_charmed = false
	_charm_timer = 0.0
	_name_label.modulate = Color.WHITE
	charm_broke.emit()
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player != null and global_position.distance_to(_player.global_position) <= aggro_range:
		_transition(State.CHASE)
	else:
		_transition(State.LEASH)

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	if is_mezzed:
		_break_mez_damage()
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	DamageNumbers.spawn(global_position, amount, false)
	if state == State.IDLE:
		_transition(State.CHASE)
	if hp <= 0.0:
		_die()

func _die() -> void:
	_transition(State.DEAD)
	if not is_charmed:
		PlayerStats.gain_xp(xp_reward)
	died.emit(self)
	await get_tree().create_timer(2.0).timeout
	queue_free()

func set_targeted(targeted: bool) -> void:
	_target_indicator.visible = targeted
	if _flash_tween:
		_flash_tween.kill()
		_flash_tween = null
	if targeted:
		_flash_tween = create_tween().set_loops()
		_flash_tween.tween_property(_name_label, "modulate", Color(1.0, 0.9, 0.1, 1.0), 0.4)
		_flash_tween.tween_property(_name_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)
	else:
		_name_label.modulate = Color(0.5, 0.8, 1.0, 1.0) if is_charmed else Color.WHITE
