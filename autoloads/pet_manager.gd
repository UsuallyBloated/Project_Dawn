extends Node

signal pet_summoned(pet)
signal pet_dismissed
signal pet_died(pet)
signal pet_hp_changed(current: float, maximum: float)
signal pet_info(text: String)
signal warder_died
signal warder_pet_dismissed

var active_pet = null

var _pet_is_charmed: bool = false
var _is_warder: bool = false
var _pet_scene: PackedScene = null

const PET_SCENE_PATH := "res://scenes/pet.tscn"

func _ready() -> void:
	Combat.player_attacked.connect(_on_player_attacked)
	if ResourceLoader.exists(PET_SCENE_PATH):
		_pet_scene = load(PET_SCENE_PATH)

# ── public API ────────────────────────────────────────────────────────────────

func has_pet() -> bool:
	return active_pet != null and is_instance_valid(active_pet)

func is_warder_active() -> bool:
	return _is_warder

func get_pet_scene() -> PackedScene:
	return _pet_scene

func register_warder_pet(pet: Pet) -> void:
	_is_warder = true
	_register_pet(pet, false)

func summon(pet_type: String) -> void:
	match pet_type:
		"skeleton":
			_summon_skeleton()
		_:
			push_error("PetManager: unknown pet_type '%s'" % pet_type)

func charm_current_target(duration: float) -> void:
	if not Combat.has_valid_target():
		return
	var enemy = Combat.current_target
	if has_pet():
		dismiss_pet()
	enemy.charm(duration)
	_register_pet(enemy, true)
	Combat.set_target(null)
	pet_info.emit("You charm %s!" % enemy.mob_name)

func dismiss_pet() -> void:
	if not has_pet():
		return
	var pet = active_pet
	var was_warder := _is_warder
	_unregister_pet(pet)
	active_pet = null
	_pet_is_charmed = false
	_is_warder = false
	if pet is Pet:
		pet.dismiss()
	elif pet.has_method("break_charm"):
		pet.break_charm()
	pet_dismissed.emit()
	if was_warder:
		warder_pet_dismissed.emit()

func command_follow() -> void:
	if not has_pet() or _pet_is_charmed:
		return
	active_pet.set_mode(Pet.Mode.FOLLOW)
	pet_info.emit("Your pet follows you.")

func command_guard() -> void:
	if not has_pet() or _pet_is_charmed:
		return
	var guard_target = Combat.current_target
	if guard_target == null or not is_instance_valid(guard_target):
		pet_info.emit("No target selected to guard.")
		return
	active_pet.set_guard_target(guard_target)
	var target_name: String = guard_target.get("mob_name")
	if target_name == null or target_name == "":
		target_name = guard_target.get("player_name")
	if target_name == null or target_name == "":
		target_name = "target"
	pet_info.emit("Your pet guards %s." % target_name)

func command_passive() -> void:
	if not has_pet() or _pet_is_charmed:
		return
	active_pet.set_mode(Pet.Mode.PASSIVE)
	pet_info.emit("Your pet holds its position.")

# ── private ───────────────────────────────────────────────────────────────────

func _summon_skeleton() -> void:
	if has_pet():
		dismiss_pet()
	if _pet_scene == null:
		push_error("PetManager: %s not found — create scenes/pet.tscn first." % PET_SCENE_PATH)
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var pet: Pet = _pet_scene.instantiate()
	pet.setup_summoned(
		"Skeleton",
		PlayerStats.level,
		50.0 + PlayerStats.level * 10.0,
		5 + PlayerStats.level * 3
	)
	get_tree().current_scene.add_child(pet)
	pet.global_position = player.global_position + player.global_transform.basis.x * 2.0
	_register_pet(pet, false)
	pet_info.emit("A skeleton rises to serve you.")

func _register_pet(pet, is_charmed: bool) -> void:
	active_pet = pet
	_pet_is_charmed = is_charmed
	if not pet.is_connected("died", _on_pet_died):
		pet.died.connect(_on_pet_died)
	if not pet.is_connected("hp_changed", pet_hp_changed.emit):
		pet.hp_changed.connect(pet_hp_changed.emit)
	if is_charmed and not pet.is_connected("charm_broke", _on_charm_broke):
		pet.charm_broke.connect(_on_charm_broke)
	if pet.has_signal("hit_target") and not pet.is_connected("hit_target", _on_pet_hit_target):
		pet.hit_target.connect(_on_pet_hit_target)
	pet_summoned.emit(pet)

func _on_pet_hit_target(attacker_name: String, target_name: String, amount: int) -> void:
	pet_info.emit("%s hits %s for %d." % [attacker_name, target_name, amount])

func _unregister_pet(pet) -> void:
	if not is_instance_valid(pet):
		return
	if pet.is_connected("died", _on_pet_died):
		pet.died.disconnect(_on_pet_died)
	if pet.is_connected("hp_changed", pet_hp_changed.emit):
		pet.hp_changed.disconnect(pet_hp_changed.emit)
	if _pet_is_charmed and pet.is_connected("charm_broke", _on_charm_broke):
		pet.charm_broke.disconnect(_on_charm_broke)
	if pet.has_signal("hit_target") and pet.is_connected("hit_target", _on_pet_hit_target):
		pet.hit_target.disconnect(_on_pet_hit_target)

func _deactivate_pet() -> void:
	_unregister_pet(active_pet)
	active_pet = null
	_pet_is_charmed = false
	_is_warder = false

func _on_player_attacked(attacker: Node) -> void:
	if not has_pet() or _pet_is_charmed:
		return
	if active_pet.mode == Pet.Mode.PASSIVE or active_pet.mode == Pet.Mode.GUARD:
		return
	active_pet.set_attack_target(attacker)

func _on_pet_died(pet) -> void:
	if _is_warder:
		_unregister_pet(pet)
		active_pet = null
		_is_warder = false
		warder_died.emit()
	else:
		_deactivate_pet()
		pet_died.emit(pet)

func _on_charm_broke() -> void:
	var pet = active_pet
	_deactivate_pet()
	pet_info.emit("The charm has broken!")
	pet_died.emit(pet)
