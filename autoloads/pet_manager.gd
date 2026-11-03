extends Node

# The local player's pet as the client sees it: the RemotePet the server
# spawned for us (registered by RemotePetManager), the pet panel's signals,
# and the /pet commands, which go to the server as PetCommand intents. The
# server owns the pet's whole life: summon, charm, warder respawn, stance.

signal pet_summoned(pet)
signal pet_dismissed
signal pet_died(pet)
signal pet_hp_changed(current: float, maximum: float)
signal pet_info(text: String)

var active_pet = null

func _ready() -> void:
	# Pet combat lines: the server fans the same Hit message it does for
	# player swings; we resolve attacker/target against the local pet id and
	# route to a dedicated MsgType.
	Net.world_hit.connect(_on_world_hit)

func _on_world_hit(attacker: int, target: int, amount: int, _crit: bool, _dmg_type: int) -> void:
	var my_pet_id := -1
	if active_pet != null and is_instance_valid(active_pet) and active_pet is RemotePet:
		my_pet_id = (active_pet as RemotePet).pet_id
	if my_pet_id < 0:
		return
	var pet_name := _pet_display_name()
	if attacker == my_pet_id:
		# My pet hit (or missed if amount==0) something. Resolve target
		# name from RemoteEnemy (most common) or fall back generic.
		var target_name := "the target"
		if target >= RemoteEnemyManager.ENEMY_ID_BASE:
			var out_target = RemoteEnemyManager.get_enemy(target)
			if out_target != null and is_instance_valid(out_target) and "mob_name" in out_target:
				target_name = out_target.mob_name
		if amount > 0:
			CombatLog.add_line("%s hits %s for %d damage." % [pet_name, target_name, amount],
					CombatLog.MsgType.PET_DAMAGE_OUT)
		else:
			CombatLog.add_line("%s misses %s." % [pet_name, target_name],
					CombatLog.MsgType.PET_DAMAGE_OUT)
		return
	if target == my_pet_id:
		var attacker_name := "Something"
		if attacker >= RemoteEnemyManager.ENEMY_ID_BASE:
			var in_attacker = RemoteEnemyManager.get_enemy(attacker)
			if in_attacker != null and is_instance_valid(in_attacker) and "mob_name" in in_attacker:
				attacker_name = in_attacker.mob_name
		if amount > 0:
			CombatLog.add_line("%s hits %s for %d damage." % [attacker_name, pet_name, amount],
					CombatLog.MsgType.PET_DAMAGE_IN)
		else:
			CombatLog.add_line("%s misses %s." % [attacker_name, pet_name],
					CombatLog.MsgType.PET_DAMAGE_IN)

func _pet_display_name() -> String:
	if active_pet == null or not is_instance_valid(active_pet):
		return "Your pet"
	if "pet_name" in active_pet:
		var nm = active_pet.get("pet_name")
		if nm != null and String(nm) != "":
			return "Your %s" % String(nm)
	return "Your pet"

# ── public API ────────────────────────────────────────────────────────────────

func has_pet() -> bool:
	return active_pet != null and is_instance_valid(active_pet)

# Track 11.5 — RemotePetManager calls this when the local player's
# server-spawned pet first arrives (PetSpawn with owner ==
# Net.get_player_id()).
func register_remote_pet(remote_pet) -> void:
	if remote_pet == null or not is_instance_valid(remote_pet):
		return
	active_pet = remote_pet
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
	if was_remote:
		pet_dismissed.emit()

func _on_remote_pet_died(remote_pet) -> void:
	if active_pet != remote_pet:
		return
	pet_died.emit(remote_pet)

# /pet dismiss: drops the pet from the panel. Nothing goes to the server.
func dismiss_pet() -> void:
	if not has_pet():
		return
	var pet = active_pet
	if pet.is_connected("hp_changed", pet_hp_changed.emit):
		pet.hp_changed.disconnect(pet_hp_changed.emit)
	active_pet = null
	pet_dismissed.emit()

func command_follow() -> void:
	if not has_pet():
		return
	Net.broadcast_pet_command(NetProtocol.PetCommand.FOLLOW, 0)
	pet_info.emit("Your pet follows you.")

# Track 12 Piece A — explicit "attack this target" command. Locks the
# pet onto `target` until the sticky window expires (server-side) or
# the player issues another command.
func command_attack(target = null) -> void:
	if not has_pet():
		return
	if target == null:
		target = Combat.current_target
	if target == null or not is_instance_valid(target):
		pet_info.emit("No target selected.")
		return
	# Pet attacks must target a server-known entity. RemoteEnemy
	# carries an enemy_id; RemotePlayer (PvP pets) carries char_id;
	# RemotePet (pet-on-pet PvP) carries pet_id. The server's
	# PetCommand::ATTACK handler runs the can_attack gate when the
	# target is a pet, so we don't need to know peer PvP state here.
	var target_id := 0
	if target is RemoteEnemy:
		target_id = (target as RemoteEnemy).enemy_id
	elif target is RemotePlayer:
		target_id = (target as RemotePlayer).char_id
	elif target is RemotePet:
		target_id = (target as RemotePet).pet_id
	if target_id <= 0:
		pet_info.emit("That target can't be attacked by your pet.")
		return
	Net.broadcast_pet_command(NetProtocol.PetCommand.ATTACK, target_id)
	# Confirmation line only fires for NPC targets where the command
	# cannot be PvP-rejected. For RemotePlayer / RemotePet the
	# server's gate may refuse — emitting "Your pet attacks X!"
	# optimistically reads as a contradiction when the rejection
	# chat lands the same tick (Round-5 playtest report). Visible
	# pet engagement is the success cue for PvP targets; rejection
	# fans its own "Unable to attack X." chat line.
	if target is RemoteEnemy:
		var target_name: String = target.get("mob_name")
		if target_name == null or target_name == "":
			target_name = "target"
		pet_info.emit("Your pet attacks %s!" % target_name)

func command_back() -> void:
	if not has_pet():
		return
	Net.broadcast_pet_command(NetProtocol.PetCommand.BACK, 0)
	pet_info.emit("Your pet returns to your side.")

func command_guard() -> void:
	if not has_pet():
		return
	# Track 15.3 — server-side Guard parks the pet at its current
	# spot. The pet drops any target, doesn't auto-inherit from
	# owner attacks, but retaliates on incoming damage.
	Net.broadcast_pet_command(NetProtocol.PetCommand.GUARD, 0)
	pet_info.emit("Your pet guards this spot.")

func command_passive() -> void:
	if not has_pet():
		return
	# Track 15.3 — server-side Sit puts the pet in full passive:
	# drops target, stands still, ignores incoming damage.
	Net.broadcast_pet_command(NetProtocol.PetCommand.SIT, 0)
	pet_info.emit("Your pet sits and waits.")
