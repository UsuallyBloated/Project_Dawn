class_name Enemy
extends CharacterBody3D

signal died(enemy)
signal hp_changed(current: float, maximum: float)

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
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) <= aggro_range:
		_transition(State.CHASE)

func _tick_chase() -> void:
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
	if global_position.distance_to(_spawn_position) < 0.5:
		hp = max_hp
		hp_changed.emit(hp, max_hp)
		_transition(State.IDLE)
	else:
		_move_toward(_spawn_position)

# ── helpers ───────────────────────────────────────────────────────────────────

func _player_valid() -> bool:
	return _player != null and is_instance_valid(_player)

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
	Combat.receive_player_damage(base_damage, mob_name)
	if _player_valid():
		DamageNumbers.spawn(_player.global_position, base_damage, true)

# ── public API ────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	DamageNumbers.spawn(global_position, amount, false)
	if state == State.IDLE:
		_transition(State.CHASE)
	if hp <= 0.0:
		_die()

func _die() -> void:
	_transition(State.DEAD)
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
		_name_label.modulate = Color.WHITE
