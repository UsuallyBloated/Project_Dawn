class_name Enemy
extends MobileCharacter

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

@export_group("Resistances")
@export var fire_resist:      float = 0.0
@export var ice_resist:       float = 0.0
@export var lightning_resist: float = 0.0
@export var arcane_resist:    float = 0.0
@export var holy_resist:      float = 0.0
@export var nature_resist:    float = 0.0
@export var spirit_resist:    float = 0.0
@export var shadow_resist:    float = 0.0

@export_group("Behaviour")
@export var aggro_range:     float = 10.0
@export var melee_range:     float = 1.8
@export var leash_range:     float = 20.0
@export var move_speed:      float = 2.5
@export var attack_interval: float = 2.5

@export_group("Caster")
@export var spell_damage:    int   = 0    # 0 = melee-only; >0 = caster, uses spells
@export var spell_interval:  float = 3.0
@export var caster_range:    float = 8.0  # preferred engagement distance
@export var flee_range:      float = 3.0  # backs away if player closer than this
@export var spell_damage_type: SpellData.DamageType = SpellData.DamageType.NONE

@export_group("Healer")
@export var healer_flee_hp:  float = 0.0  # fraction 0.0–1.0; flee + self-heal when below
@export var heal_amount:     float = 0.0
@export var heal_interval:   float = 5.0

@export_group("Skinning")
@export var is_skinnable: bool = false
@export var skinning_tier: int = 0  # 0=tattered 1=damaged 2=fresh 3=pristine quality cap

var _has_been_skinned: bool = false

# Named / boss mob runtime state
var _named_drops: Array[ItemData] = []
var _damage_mult: float = 1.0
var _speed_mult:  float = 1.0
var _enraged:             bool  = false
var _enrage_threshold:    float = 0.0
var _enrage_damage_mult:  float = 1.5
var _enrage_speed_mult:   float = 1.3

var hp: float
var is_charmed: bool = false
var _charm_timer: float = 0.0
var is_mezzed: bool = false
var _mez_timer: float = 0.0
var is_stunned: bool = false
var _stun_timer: float = 0.0
var is_rooted: bool = false
var _root_timer: float = 0.0
var _snare_amount: float = 0.0
var _snare_timer: float = 0.0
var _attack_slow_amount: float = 0.0
var _attack_slow_timer: float = 0.0
var is_silenced: bool = false
var _silence_timer: float = 0.0

enum State { IDLE, CHASE, ATTACK, LEASH, FLEE, DEAD }
var state := State.IDLE
var is_dead: bool:
	get:
		return state == State.DEAD

var _player:             Node3D = null
var _attack_cooldown:    float  = 0.0
var _spell_cooldown:     float  = 0.0
var _heal_cooldown:      float  = 0.0
var _spawn_position:     Vector3
var _force_chase_timer:  float  = 0.0

@onready var _mesh:             MeshInstance3D = $MeshInstance3D
@onready var _target_indicator: MeshInstance3D = $TargetIndicator
@onready var _name_label:       Label3D        = $NameLabel

var _flash_tween: Tween = null
var _hit_tween:   Tween = null
var _base_color:  Color

func _ready() -> void:
	hp = max_hp
	_spawn_position = global_position
	add_to_group("enemies")
	_name_label.text = mob_name
	if loot_table == null:
		loot_table = _build_default_loot_table()
	if not is_skinnable and MobLootTables.is_skinnable_type(mob_name):
		is_skinnable = true
		skinning_tier = MobLootTables.skinning_tier_for(mob_name)
	Loot.register_enemy(self)
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat = mat.duplicate() as StandardMaterial3D
		_mesh.set_surface_override_material(0, mat)
		_base_color = mat.albedo_color

func get_spell_resist(damage_type: SpellData.DamageType) -> float:
	match damage_type:
		SpellData.DamageType.FIRE:      return fire_resist
		SpellData.DamageType.ICE:       return ice_resist
		SpellData.DamageType.LIGHTNING: return lightning_resist
		SpellData.DamageType.ARCANE:    return arcane_resist
		SpellData.DamageType.HOLY:      return holy_resist
		SpellData.DamageType.NATURE:    return nature_resist
		SpellData.DamageType.SPIRIT:    return spirit_resist
		SpellData.DamageType.SHADOW:    return shadow_resist
	return 0.0

func _build_default_loot_table() -> LootTable:
	var named := MobLootTables.build(mob_name)
	if named != null and not named.entries.is_empty():
		return named
	# Generic fallback for unknown mob types
	var table := LootTable.new()
	table.rolls = 1
	table.empty_weight = 1.5
	table.entries.append(_make_loot_entry("Cloth Scraps",    "Scraps of woven cloth.",       ItemData.Type.MISC,    ItemData.Rarity.COMMON,   2.0))
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

func try_skin() -> String:
	# Same guard as mining/crafting: the pelt would exist only client-side and
	# desync the slot indices. (Online this path is doubly unreachable — local
	# Enemy nodes aren't spawned in launcher mode — but the guard keeps that
	# truth in one obvious place instead of relying on scene wiring.)
	if Net.is_launcher_mode():
		return "Skinning isn't available online yet."
	if state != State.DEAD:
		return "That isn't dead yet."
	if _has_been_skinned:
		return "You've already harvested this creature."
	if Crafting.count_item("Skinning Knife") == 0:
		return "You need a Skinning Knife to skin this."
	_has_been_skinned = true
	var skill := Crafting.get_skill_level("Skinning")
	var pelt  := MobLootTables.roll_skin(mob_name, skill)
	if pelt == null:
		Crafting.gain_skill_xp("Skinning", 5)
		return "You attempted to skin the %s but ruined the hide." % mob_name
	if not Inventory.add_item(pelt, 1):
		_has_been_skinned = false
		return "Your inventory is full."
	Crafting.gain_skill_xp("Skinning", 10)
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(self): queue_free())
	return "You skinned the %s and received %s." % [mob_name, pelt.item_name]

func _make_loot_entry(iname: String, idesc: String, itype: ItemData.Type, irarity: ItemData.Rarity, iweight: float) -> LootEntry:
	var item := ItemData.new()
	item.item_name   = iname
	item.description = idesc
	item.type        = itype
	item.rarity      = irarity
	item.stack_size  = 20 if itype == ItemData.Type.MISC else 1
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
	if state == State.DEAD:
		return
	if is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			is_stunned = false
			if not is_mezzed and not is_charmed:
				_name_label.modulate = Color.WHITE
			Combat.enemy_stun_wore_off.emit(mob_name)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if is_mezzed:
		_mez_timer -= delta
		if _mez_timer <= 0.0:
			_break_mez_expire()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if is_rooted:
		_root_timer -= delta
		if _root_timer <= 0.0:
			is_rooted = false
			if not is_stunned and not is_mezzed and not is_charmed:
				_name_label.modulate = Color.WHITE
	if _snare_timer > 0.0:
		_snare_timer -= delta
		if _snare_timer <= 0.0:
			_snare_amount = 0.0
	if _attack_slow_timer > 0.0:
		_attack_slow_timer -= delta
		if _attack_slow_timer <= 0.0:
			_attack_slow_amount = 0.0
	if _silence_timer > 0.0:
		_silence_timer -= delta
		if _silence_timer <= 0.0:
			is_silenced = false
			if not is_stunned and not is_mezzed and not is_charmed and not is_rooted:
				_name_label.modulate = Color.WHITE
	if _force_chase_timer > 0.0:
		_force_chase_timer -= delta
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	match state:
		State.IDLE:   _tick_idle()
		State.CHASE:  _tick_chase()
		State.ATTACK: _tick_attack(delta)
		State.LEASH:  _tick_leash()
		State.FLEE:   _tick_flee(delta)
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
		elif not is_rooted:
			_move_toward(t.global_position)
		return
	if not _player_valid():
		_transition(State.LEASH)
		return
	if _should_flee():
		_transition(State.FLEE)
		return
	var dist := global_position.distance_to(_player.global_position)
	var effective_leash := leash_range * 3.0 if _force_chase_timer > 0.0 else leash_range
	var engage_range := caster_range if spell_damage > 0 else melee_range
	if dist > effective_leash:
		_transition(State.LEASH)
	elif dist <= engage_range:
		_transition(State.ATTACK)
	elif not is_rooted:
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
			_attack_cooldown = attack_interval * (1.0 + _attack_slow_amount)
			var tname: String = t.mob_name
			t.take_damage(base_damage)
			if is_instance_valid(t):
				DamageNumbers.spawn_damage(t.global_position, base_damage, false)
			Combat.enemy_charmed_attacked.emit(mob_name, tname, base_damage)
		return
	if not _player_valid():
		_transition(State.LEASH)
		return
	if _should_flee():
		_transition(State.FLEE)
		return
	var dist := global_position.distance_to(_player.global_position)
	if spell_damage > 0:
		_tick_attack_caster(delta, dist)
	else:
		if dist > melee_range * 1.2:
			_transition(State.CHASE)
			return
		velocity.x = 0.0
		velocity.z = 0.0
		_face_toward(_player.global_position)
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval * (1.0 + _attack_slow_amount)
			_do_attack()

func _tick_attack_caster(delta: float, dist: float) -> void:
	_face_toward(_player.global_position)
	if dist < flee_range and not is_rooted:
		var away := (global_position - _player.global_position).normalized()
		velocity.x = away.x * move_speed
		velocity.z = away.z * move_speed
	elif dist > caster_range * 1.3:
		_transition(State.CHASE)
		return
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if is_silenced:
		return
	_spell_cooldown -= delta
	if _spell_cooldown <= 0.0:
		_spell_cooldown = spell_interval
		_do_cast_spell()

func _tick_leash() -> void:
	if is_charmed:
		_transition(State.IDLE)
		return
	if global_position.distance_to(_spawn_position) < 2.0:
		hp = max_hp
		hp_changed.emit(hp, max_hp)
		_transition(State.IDLE)
	else:
		_move_toward(_spawn_position)

func _tick_flee(delta: float) -> void:
	if not _should_flee():
		_transition(State.CHASE)
		return
	_move_toward(_spawn_position)
	_heal_cooldown -= delta
	if _heal_cooldown <= 0.0 and heal_amount > 0.0:
		_heal_cooldown = heal_interval
		hp = minf(hp + heal_amount, max_hp)
		hp_changed.emit(hp, max_hp)
		flash_spell_hit(Color(0.2, 1.0, 0.2))
		CombatLog.add_line("%s heals itself for %d." % [mob_name, int(heal_amount)], CombatLog.MsgType.INFO)

func _should_flee() -> bool:
	return healer_flee_hp > 0.0 and hp / max_hp < healer_flee_hp

# ── helpers ───────────────────────────────────────────────────────────────────

func _player_valid() -> bool:
	return _player != null and is_instance_valid(_player) and not PlayerDeath.is_dead

func _move_toward(target_pos: Vector3) -> void:
	_move_at_speed(target_pos, move_speed * _speed_mult * (1.0 - _snare_amount))

func _do_attack() -> void:
	var dmg := int(base_damage * _damage_mult)
	Combat.receive_player_damage(dmg, self, mob_name)
	if _player_valid():
		DamageNumbers.spawn_incoming(_player.global_position, dmg)

func _do_cast_spell() -> void:
	if not _player_valid():
		return
	var crit_roll := randf() < 0.05
	var amount: int = int(spell_damage * _damage_mult) * 2 if crit_roll else int(spell_damage * _damage_mult)
	Combat.receive_player_damage(amount, self, mob_name)
	if _player_valid():
		var color := Combat.spell_color(spell_damage_type)
		DamageNumbers.spawn_incoming(_player.global_position, amount)
		Combat.spawn_impact_light(_player.global_position, color)

# ── public API ────────────────────────────────────────────────────────────────

func stun(duration: float) -> void:
	if state == State.DEAD:
		return
	is_stunned = true
	_stun_timer = duration
	_name_label.modulate = Color(1.0, 0.65, 0.10)
	Combat.enemy_stunned.emit(mob_name)

func root(duration: float) -> void:
	if state == State.DEAD:
		return
	is_rooted = true
	_root_timer = duration
	_name_label.modulate = Color(0.40, 0.90, 0.30)
	Combat.enemy_rooted.emit(mob_name)

func snare(amount: float, duration: float) -> void:
	if state == State.DEAD:
		return
	_snare_amount = clampf(amount, 0.0, 0.99)
	_snare_timer = duration
	Combat.enemy_snared.emit(mob_name)

func apply_attack_slow(amount: float, duration: float) -> void:
	if state == State.DEAD:
		return
	_attack_slow_amount = clampf(amount, 0.0, 0.9)
	_attack_slow_timer = duration
	Combat.enemy_slowed.emit(mob_name)

func mesmerize(duration: float) -> void:
	if state == State.DEAD or is_charmed:
		return
	is_mezzed = true
	_mez_timer = duration
	_name_label.modulate = Color(0.85, 0.50, 1.00)
	Combat.enemy_mez_applied.emit(mob_name)

func _break_mez_damage() -> void:
	is_mezzed = false
	_mez_timer = 0.0
	_name_label.modulate = Color.WHITE
	Combat.enemy_mez_broke.emit(mob_name)

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
	if state == State.DEAD:
		return
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
	_flash_hit(Color.WHITE)
	_check_enrage()
	if state == State.IDLE:
		_transition(State.CHASE)
	_force_chase_timer = 10.0
	if hp <= 0.0:
		_die()

func _check_enrage() -> void:
	if _enraged or _enrage_threshold <= 0.0 or hp <= 0.0:
		return
	if hp / max_hp <= _enrage_threshold:
		_enraged = true
		_damage_mult *= _enrage_damage_mult
		_speed_mult  *= _enrage_speed_mult
		_name_label.add_theme_color_override("font_color", Color(1.0, 0.20, 0.10))
		CombatLog.add_line("%s becomes ENRAGED!" % mob_name, CombatLog.MsgType.DAMAGE_IN)

func _die() -> void:
	_transition(State.DEAD)
	if not is_charmed:
		GroupManager.distribute_kill_xp(xp_reward)
		QuestManager.notify_kill(mob_name)
	died.emit(self)
	_name_label.visible = false
	_target_indicator.visible = false
	if _hit_tween:
		_hit_tween.kill()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation_degrees:z", 90.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.0).set_delay(0.5)
	var despawn_delay := 30.0 if is_skinnable else 3.0
	await get_tree().create_timer(despawn_delay).timeout
	if is_instance_valid(self):
		queue_free()

func apply_named(named_id: String) -> void:
	var data: Dictionary = NamedMobDefinitions.ALL.get(named_id, {})
	if data.is_empty():
		return

	var display: String  = data.get("display_name", mob_name)
	var subtitle: String = data.get("subtitle", "")
	mob_name = display
	_name_label.text = ("%s %s" % [display, subtitle]).strip_edges()
	_name_label.modulate = Color(1.0, 0.85, 0.0)

	level      = data.get("level", level)
	max_hp     = max_hp * data.get("hp_mult", 1.0)
	hp         = max_hp
	xp_reward  = int(xp_reward * data.get("xp_mult", 1.0))
	_damage_mult       = data.get("damage_mult", 1.0)
	_enrage_threshold  = data.get("enrage_threshold", 0.0)
	_enrage_damage_mult = data.get("enrage_damage_mult", 1.5)
	_enrage_speed_mult  = data.get("enrage_speed_mult", 1.3)
	hp_changed.emit(hp, max_hp)

	if loot_table == null:
		loot_table = _build_default_loot_table()

	# Track 20D — named drops resolve from authored .tres paths so
	# the server registry knows about them; equip / sell / destroy
	# now work end-to-end (was silently rejected when items were
	# runtime-only inline dicts).
	for path: String in data.get("guaranteed_loot", []):
		var item := NamedMobDefinitions.load_item(path)
		if item != null:
			_named_drops.append(item)

	for d: Dictionary in data.get("rare_loot", []):
		if randf() < d.get("drop_chance", 0.2):
			var item := NamedMobDefinitions.load_item(d["path"])
			if item != null:
				_named_drops.append(item)

func flash_spell_hit(color: Color) -> void:
	if state != State.DEAD:
		_flash_hit(color)

func _flash_hit(flash_color: Color) -> void:
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	if _hit_tween:
		_hit_tween.kill()
	mat.albedo_color = flash_color
	_hit_tween = create_tween()
	_hit_tween.tween_property(mat, "albedo_color", _base_color, 0.25)

func silence(duration: float) -> void:
	if state == State.DEAD:
		return
	is_silenced = true
	_silence_timer = duration
	_name_label.modulate = Color(0.85, 0.85, 0.25)
	Combat.enemy_silenced.emit(mob_name)

func strip_one_buff() -> bool:
	if is_charmed:
		break_charm()
		return true
	if is_mezzed:
		_break_mez_expire()
		return true
	if is_stunned:
		is_stunned = false
		_stun_timer = 0.0
		if not is_charmed and not is_mezzed:
			_name_label.modulate = Color.WHITE
		return true
	return false

func feign_death_deaggro() -> void:
	if state in [State.CHASE, State.ATTACK]:
		_transition(State.LEASH)

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
