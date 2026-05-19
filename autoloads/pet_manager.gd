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
	# Track 11.5 — in launcher mode the server is authoritative for
	# pets and RemotePetManager will register the spawned RemotePet
	# via register_remote_pet() once PetSpawn arrives. Skip the local
	# Pet instantiation so we don't end up with two visuals.
	if Net.is_launcher_mode():
		return
	match pet_type:
		"skeleton":
			_summon_skeleton()
		_:
			push_error("PetManager: unknown pet_type '%s'" % pet_type)

# Track 11.5 — RemotePetManager calls this when the local player's
# server-spawned pet first arrives (PetSpawn with owner ==
# Net.get_player_id()). Mirrors _register_pet's signal contract so
# the HUD pet panel and any other PetManager.pet_summoned listener
# works in launcher mode without changes.
func register_remote_pet(remote_pet) -> void:
	if remote_pet == null or not is_instance_valid(remote_pet):
		return
	active_pet = remote_pet
	_pet_is_charmed = false
	_is_warder = false
	if not remote_pet.is_connected("hp_changed", pet_hp_changed.emit):
		remote_pet.hp_changed.connect(pet_hp_changed.emit)
	if not remote_pet.is_connected("died", _on_remote_pet_died):
		remote_pet.died.connect(_on_remote_pet_died.bind(remote_pet))
	pet_summoned.emit(remote_pet)

# Track 11.5 — RemotePetManager calls this when the local player's
# pet despawns server-side (owner disconnect / EntityDespawn after
# the corpse linger window).
func dismiss_remote_pet() -> void:
	if active_pet == null:
		return
	var was_remote := active_pet is RemotePet
	active_pet = null
	_pet_is_charmed = false
	_is_warder = false
	if was_remote:
		pet_dismissed.emit()

func _on_remote_pet_died(remote_pet) -> void:
	if active_pet != remote_pet:
		return
	pet_died.emit(remote_pet)

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
	# Track 12 Piece A — launcher mode routes through the wire.
	# Solo / Test Room keeps the legacy local Pet.set_mode call.
	if Net.is_launcher_mode():
		Net.broadcast_pet_command(NetProtocol.PetCommand.FOLLOW, 0)
		pet_info.emit("Your pet follows you.")
		return
	active_pet.set_mode(Pet.Mode.FOLLOW)
	pet_info.emit("Your pet follows you.")

# Track 12 Piece A — explicit "attack this target" command. Locks the
# pet onto `target` until the sticky window expires (server-side) or
# the player issues another command.
func command_attack(target = null) -> void:
	if not has_pet() or _pet_is_charmed:
		return
	if target == null:
		target = Combat.current_target
	if target == null or not is_instance_valid(target):
		pet_info.emit("No target selected.")
		return
	if Net.is_launcher_mode():
		# Pet attacks must target a server-known entity. RemoteEnemy
		# carries an enemy_id; RemotePlayer (PvP pets) carries char_id.
		var target_id := 0
		if target is RemoteEnemy:
			target_id = (target as RemoteEnemy).enemy_id
		elif target is RemotePlayer:
			target_id = (target as RemotePlayer).char_id
		if target_id <= 0:
			pet_info.emit("That target can't be attacked by your pet.")
			return
		Net.broadcast_pet_command(NetProtocol.PetCommand.ATTACK, target_id)
		var target_name: String = target.get("mob_name")
		if target_name == null or target_name == "":
			target_name = target.get("player_name")
		if target_name == null or target_name == "":
			target_name = "target"
		pet_info.emit("Your pet attacks %s!" % target_name)
		return
	# Solo / Test Room: local Pet has an attack method if available;
	# otherwise just set its target via Combat plumbing.
	if active_pet.has_method("attack_target"):
		active_pet.attack_target(target)
		pet_info.emit("Your pet attacks!")

func command_back() -> void:
	if not has_pet() or _pet_is_charmed:
		return
	if Net.is_launcher_mode():
		Net.broadcast_pet_command(NetProtocol.PetCommand.BACK, 0)
		pet_info.emit("Your pet returns to your side.")
		return
	# Solo: switch local Pet to FOLLOW mode (legacy semantics).
	if active_pet.has_method("set_mode"):
		active_pet.set_mode(Pet.Mode.FOLLOW)
		pet_info.emit("Your pet returns to your side.")

func command_guard() -> void:
	if not has_pet() or _pet_is_charmed:
		return
	# Track 12 Piece A — Guard isn't wired server-side yet (reserved
	# in the wire format). In launcher mode this is a no-op; solo
	# mode keeps the legacy local Pet.set_guard_target call.
	if Net.is_launcher_mode():
		pet_info.emit("Pet guard not yet implemented in multiplayer.")
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
	# Track 12 Piece A — Sit/Passive isn't wired server-side yet
	# (reserved in the wire format). Launcher mode is a no-op; solo
	# keeps the legacy local Pet.set_mode call.
	if Net.is_launcher_mode():
		pet_info.emit("Pet passive not yet implemented in multiplayer.")
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
