extends Node

# Ticks every TICK_INTERVAL seconds.
# Sitting grants large regen bonuses for all three stats.

const TICK_INTERVAL    := 3.0
const SITTING_HP_MULT  := 5.0
const SITTING_MP_MULT  := 5.0
const SITTING_ST_MULT  := 3.0
# Round-7 playtest request: default regen disabled until target
# numbers are decided. Mirror of the server's regen.rs constants —
# Test Room single-player path stays in lockstep so behavior matches
# launcher mode. Sitting / food / drink / Lich / Clarity buffs still
# apply (additive on top of the base 0).
const HP_BASE_REGEN    := 0.0
const HP_CON_SCALE     := 0.0
const MP_BASE_REGEN    := 0.0
const MP_WIS_SCALE     := 0.0
const ST_BASE_REGEN    := 0.0
const ST_AGI_SCALE     := 0.0

var _tick_timer: float = 0.0
var _in_combat: bool = false
var _player: Node3D = null
var _is_sitting: bool = false

func register_player(node: Node3D) -> void:
	_player = node
	if _player.has_signal("state_changed"):
		_player.state_changed.connect(_on_player_state_changed)

func unregister_player() -> void:
	if is_instance_valid(_player) and _player.has_signal("state_changed"):
		if _player.state_changed.is_connected(_on_player_state_changed):
			_player.state_changed.disconnect(_on_player_state_changed)
	_player = null
	_is_sitting = false

func _ready() -> void:
	Combat.target_changed.connect(_on_target_changed)

func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer -= TICK_INTERVAL
		_do_regen()

func _do_regen() -> void:
	# Track 6: server owns regen in launcher mode. The server reads sit
	# state from Sit/Stand intents (broadcast by player.gd's state_changed
	# handler) and fans HealthUpdate / ManaUpdate / StaminaUpdate back, so
	# running the local tick would double-count.
	if Net.is_launcher_mode():
		return
	if _in_combat:
		return

	var hp_mult := SITTING_HP_MULT if _is_sitting else 1.0
	var mp_mult := SITTING_MP_MULT if _is_sitting else 1.0
	# Carrying too much weight halves stamina recovery (or stops it entirely
	# at double capacity) — see autoloads/encumbrance.gd.
	var st_mult := (SITTING_ST_MULT if _is_sitting else 1.0) \
			* Encumbrance.get_stamina_regen_mult()

	var food_hp := BuffManager.get_food_hp_regen() + BuffManager.get_drink_hp_regen()
	var food_mp := BuffManager.get_food_mp_regen() + BuffManager.get_drink_mp_regen()

	# Lich Form: disable HP regen, grant extreme MP regen instead
	var lich_mp := BuffManager.get_lich_mp_regen() * TICK_INTERVAL if BuffManager.is_lich_form() else 0.0

	# Clarity/Breeze mana regen buff
	var mp_regen_buff := BuffManager.get_mp_regen_buff()
	var clarity_mp: float = mp_regen_buff.get("hps", 0.0) * TICK_INTERVAL if not mp_regen_buff.is_empty() else 0.0

	if PlayerStats.hp < PlayerStats.max_hp and not BuffManager.is_lich_form():
		PlayerStats.set_hp(minf(PlayerStats.hp + _hp_regen_per_tick() * hp_mult + food_hp, PlayerStats.max_hp))
	if PlayerStats.mp < PlayerStats.max_mp:
		PlayerStats.set_mp(minf(PlayerStats.mp + _mp_regen_per_tick() * mp_mult + food_mp + clarity_mp + lich_mp, PlayerStats.max_mp))
	if PlayerStats.stamina < PlayerStats.max_stamina:
		PlayerStats.set_stamina(minf(PlayerStats.stamina + _st_regen_per_tick() * st_mult, PlayerStats.max_stamina))

func _hp_regen_per_tick() -> float:
	return HP_BASE_REGEN + PlayerStats.constitution * HP_CON_SCALE

func _mp_regen_per_tick() -> float:
	return MP_BASE_REGEN + PlayerStats.wisdom * MP_WIS_SCALE

func _st_regen_per_tick() -> float:
	return ST_BASE_REGEN + PlayerStats.agility * ST_AGI_SCALE

func _on_player_state_changed(new_state: int) -> void:
	var was_sitting := _is_sitting
	_is_sitting = new_state == PlayerCharacter.PlayerState.SITTING
	_tick_timer = TICK_INTERVAL * 0.5
	# Track 6: forward sit/stand transitions to the server so its regen
	# tick can apply the same multiplier. Only fire on actual transitions
	# to avoid spamming the wire on every state_changed (which also fires
	# for crouch / stand-from-crouch).
	if was_sitting != _is_sitting and Net.is_launcher_mode():
		if _is_sitting:
			Net.broadcast_sit()
		else:
			Net.broadcast_stand()

func _on_target_changed(enemy) -> void:
	_in_combat = enemy != null and is_instance_valid(enemy)
	if not _in_combat:
		_tick_timer = TICK_INTERVAL * 0.5
	elif _is_sitting and is_instance_valid(_player):
		_player.stand()
