extends Node

# Ticks every TICK_INTERVAL seconds.
# Sitting grants large regen bonuses for all three stats.

# EQ-authentic regen (docs/design/regen_model.md, 2026-07-20). Mirror of the
# server's regen.rs — RETUNE BOTH TOGETHER. Flat per-6s-tick by level bracket +
# posture (+ Troll bonus for HP, + Meditate for MP); stamina flat. NOT
# stat-scaled. This client tick only runs in Test Room (launcher = server-owned).
const TICK_INTERVAL          := 6.0
const STAMINA_REGEN_PER_TICK := 10.0

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

	var food_hp := BuffManager.get_food_hp_regen() + BuffManager.get_drink_hp_regen()
	var food_mp := BuffManager.get_food_mp_regen() + BuffManager.get_drink_mp_regen()

	# Lich Form: disable HP regen, grant extreme MP regen instead
	var lich_mp := BuffManager.get_lich_mp_regen() * TICK_INTERVAL if BuffManager.is_lich_form() else 0.0

	# Clarity/Breeze mana regen buff
	var mp_regen_buff := BuffManager.get_mp_regen_buff()
	var clarity_mp: float = mp_regen_buff.get("hps", 0.0) * TICK_INTERVAL if not mp_regen_buff.is_empty() else 0.0

	# EQ model: the per-tick functions already return the posture-correct rate
	# (flat table by level / posture / race). Food / Lich / Clarity are additive
	# on top. Stamina is flat (encumbrance-vs-stamina interaction dropped for now,
	# to match the server — it can return on both sides later).
	if PlayerStats.hp < PlayerStats.max_hp and not BuffManager.is_lich_form():
		PlayerStats.set_hp(minf(PlayerStats.hp + _hp_regen_per_tick() + food_hp, PlayerStats.max_hp))
	if PlayerStats.mp < PlayerStats.max_mp:
		PlayerStats.set_mp(minf(PlayerStats.mp + _mp_regen_per_tick() + food_mp + clarity_mp + lich_mp, PlayerStats.max_mp))
	if PlayerStats.stamina < PlayerStats.max_stamina:
		PlayerStats.set_stamina(minf(PlayerStats.stamina + STAMINA_REGEN_PER_TICK, PlayerStats.max_stamina))

func _hp_regen_per_tick() -> float:
	return _hp_table_value(PlayerStats.level, _is_sitting, PlayerStats.race == "Troll")

func _mp_regen_per_tick() -> float:
	# Meditate is a casting skill; sitting MP scales with it. Server-authoritative
	# (trained in the tick loop while medding); mirrored here for Test Room.
	var meditate: int = CastingSkills.get_current("meditate")
	return _mp_table_value(_is_sitting, meditate)

# HP regen per 6s tick — flat by level bracket + posture + Troll bonus. Mirror of
# regen.rs::hp_regen_per_tick; keep in lockstep (docs/design/regen_model.md).
func _hp_table_value(level: int, sitting: bool, troll: bool) -> float:
	# Brackets: 0:≤19  1:20-49  2:50  3:51-55  4:56-59  5:60+
	var bracket := 0
	if level <= 19: bracket = 0
	elif level <= 49: bracket = 1
	elif level <= 50: bracket = 2
	elif level <= 55: bracket = 3
	elif level <= 59: bracket = 4
	else: bracket = 5
	var stand_tbl := [2, 2, 2, 6, 10, 12] if troll else [1, 1, 1, 2, 3, 4]
	var sit_tbl := [4, 6, 8, 12, 16, 18] if troll else [2, 3, 4, 5, 6, 7]
	return float(sit_tbl[bracket] if sitting else stand_tbl[bracket])

# MP regen per 6s tick: 1 standing, 2 + floor(meditate/12) sitting. Mirror of
# regen.rs::mp_regen_per_tick.
func _mp_table_value(sitting: bool, meditate: int) -> float:
	if sitting:
		return float(2 + max(meditate, 0) / 12)
	return 1.0

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
