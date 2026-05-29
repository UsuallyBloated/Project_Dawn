extends Node

signal warder_retreating(retreat_duration: float)
signal warder_returned

var warder_type: String = "Wolf"

var _retreating: bool = false
var _retreat_timer: float = 0.0

const RETREAT_DURATION := 15.0

func _ready() -> void:
	PetManager.warder_died.connect(_on_warder_died)
	PetManager.warder_pet_dismissed.connect(_on_warder_dismissed)
	PlayerStats.level_changed.connect(func(_lvl): setup_for_class(PlayerStats.player_class))
	call_deferred("_check_initial_class")

func _process(delta: float) -> void:
	if _retreating:
		_retreat_timer -= delta
		if _retreat_timer <= 0.0:
			_retreating = false
			_spawn_warder(0.3)

# ── public API ────────────────────────────────────────────────────────────────

func is_retreating() -> bool:
	return _retreating

func setup_for_class(player_class: String) -> void:
	# Server owns warder lifecycle in launcher mode (EnterWorld
	# auto-summon + respawn after retreat per Track 12B). A local
	# summon here would create a phantom client-only pet that the
	# server can't see — and the level_changed handler would
	# re-trigger this every level-up, stacking phantoms.
	if Net.is_launcher_mode():
		return
	if player_class == "Beast Master" and not PetManager.has_pet() and not _retreating:
		summon_warder()

func summon_warder(p_type: String = "") -> void:
	if p_type != "":
		warder_type = p_type
	if PetManager.has_pet():
		return
	_spawn_warder(1.0)

func heal_warder(amount: float) -> void:
	if PetManager.is_warder_active() and PetManager.has_pet():
		PetManager.active_pet.heal(amount)

func command_fury() -> void:
	if not PetManager.is_warder_active() or not PetManager.has_pet():
		return
	var target = Combat.current_target
	if target == null or not is_instance_valid(target):
		return
	PetManager.active_pet.set_attack_target(target)
	PetManager.pet_info.emit("Your warder lunges at the target!")

# ── private ───────────────────────────────────────────────────────────────────

func _check_initial_class() -> void:
	setup_for_class(PlayerStats.player_class)

func _spawn_warder(hp_fraction: float) -> void:
	var pet_scene: PackedScene = PetManager.get_pet_scene()
	if pet_scene == null:
		push_error("WarderAI: pet scene not loaded — create scenes/pet.tscn first.")
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var pet: Pet = pet_scene.instantiate()
	var max_hp := 60.0 + PlayerStats.level * 12.0
	pet.setup_summoned(
		warder_type,
		PlayerStats.level,
		max_hp,
		6 + PlayerStats.level * 3
	)
	pet.hp = max_hp * hp_fraction
	get_tree().current_scene.add_child(pet)
	pet.global_position = player.global_position + player.global_transform.basis.x * 2.0
	PetManager.register_warder_pet(pet)
	if hp_fraction >= 1.0:
		PetManager.pet_info.emit("Your warder %s is by your side." % warder_type)
	else:
		PetManager.pet_info.emit("Your warder %s returns, wounded." % warder_type)
		warder_returned.emit()

func _on_warder_died() -> void:
	_retreating = true
	_retreat_timer = RETREAT_DURATION
	warder_retreating.emit(RETREAT_DURATION)
	PetManager.pet_info.emit("Your warder retreats! It will return in %d seconds." % int(RETREAT_DURATION))

func _on_warder_dismissed() -> void:
	_retreating = true
	_retreat_timer = 3.0
