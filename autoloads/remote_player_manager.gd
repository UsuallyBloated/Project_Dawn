extends Node

# RemotePlayerManager — visual replication of every other player in the
# current zone. Listens to Net's coarse signals; manages a dict of
# `remote_player.tscn` instances keyed by char_id.
#
# Two maps, two lifetimes:
#   _spawn_data — last known identity + spawn pose per char_id. Survives
#       scene changes (autoload-scoped). The source of truth for
#       re-instantiation when the local scene tree shifts under us.
#   _by_id — live RemotePlayer node per char_id, parented under the
#       current scene's root so it dies with the scene on transition.
#
# Why two maps: the lobby→world transition for the second-joining client.
# Server fan-out delivers EntitySpawn(A) to B at app-Connect time, which
# is BEFORE B clicks Enter World — so B is still on the lobby scene.
# Parenting RemotePlayer(A) under the lobby means it gets freed on
# transition, and the server doesn't re-send spawn (it's a one-shot
# reliable message). With _spawn_data persistent, the `_process` poll
# below catches the scene swap and re-instantiates into world.tscn.
#
# Own player is rendered by world.tscn + handled by player.gd; we filter
# out broadcasts where id == Net.get_player_id() on every signal.

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")

var _spawn_data: Dictionary = {}   # int char_id -> spawn dict
var _by_id: Dictionary = {}        # int char_id -> RemotePlayer node
var _last_scene: Node = null
# Set when a scene swap drops _by_id; cleared once we've reinstantiated
# into a scene that actually hosts the local player. Persists across
# frames so the local player joining its group one tick after the scene
# becomes current doesn't fall through the cracks.
var _needs_rehydrate: bool = false

func _ready() -> void:
	Net.world_entity_spawn.connect(_on_entity_spawn)
	Net.world_entity_despawn.connect(_on_entity_despawn)
	Net.world_position.connect(_on_position)
	Net.world_health_update.connect(_on_health_update)
	Net.world_mana_update.connect(_on_mana_update)
	Net.world_stamina_update.connect(_on_stamina_update)
	Net.world_cast_start.connect(_on_cast_start)
	Net.world_cast_complete.connect(_on_cast_complete)
	Net.world_cast_fail.connect(_on_cast_fail)
	Net.world_buff_snapshot.connect(_on_buff_snapshot)
	Net.world_hit.connect(_on_hit)
	Net.world_proc_triggered.connect(_on_proc_triggered)
	Net.world_miss.connect(_on_miss)
	Net.world_evade.connect(_on_evade)
	Net.world_entity_died.connect(_on_entity_died)
	Net.world_damage_shield_trigger.connect(_on_damage_shield_trigger)
	# Track 22.H — peer target broadcast routes through the same
	# shared EntityTarget signal RemoteEnemyManager uses. We filter
	# by id partition (< ENEMY_ID_BASE = player) so the two managers
	# don't collide.
	Net.world_entity_target.connect(_on_entity_target)

# Track 21B — public accessor used by the target-of-target frame
# to resolve a peer char_id back to its RemotePlayer node.
func get_by_id(id: int) -> Node:
	return _by_id.get(id)

func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _last_scene:
		# Scene swap (or `current_scene` transitioning through null between
		# change_scene_to_file and the actual swap — Godot does this briefly).
		# Free every live node we know about before dropping the map; relying
		# on "scene change frees its children" misses the case where the
		# scene didn't actually change but `_last_scene` was invalidated
		# (e.g. transient null), which would otherwise leave orphaned
		# RemotePlayer bodies in the live scene tree.
		for rp in _by_id.values():
			if is_instance_valid(rp):
				rp.queue_free()
		_last_scene = scene
		_by_id.clear()
		_needs_rehydrate = true
	if not _needs_rehydrate or scene == null:
		return
	if not _scene_hosts_local_player(scene):
		return
	for id in _spawn_data:
		if not _by_id.has(id):
			_instantiate_into(id, scene)
	_needs_rehydrate = false

func _on_entity_spawn(
		id: int,
		player_name: String,
		race: String,
		char_class: String,
		level: int,
		pos: Vector3,
		yaw: float) -> void:
	if id == Net.get_player_id():
		# Own-player spawn fan-out skips the subject server-side; this
		# branch is defensive insurance against a future protocol change.
		return
	# Cache regardless of scene — drives rehydration on the next world
	# transition if we're in the lobby right now.
	_spawn_data[id] = {
		"name": player_name,
		"race": race,
		"class": char_class,
		"level": level,
		"pos": pos,
		"yaw": yaw,
	}
	var scene: Node = get_tree().current_scene
	if scene == null or not _scene_hosts_local_player(scene):
		return
	# Duplicate spawn (stale message after a despawn). Replace.
	if _by_id.has(id):
		var old = _by_id[id]
		if is_instance_valid(old):
			old.queue_free()
		_by_id.erase(id)
	# Defensive orphan sweep: free any RemotePlayer in the live scene whose
	# char_id matches but isn't tracked in _by_id. Catches the case where
	# a prior _by_id.clear() lost the reference but Godot didn't free the
	# node (transient scene-null window during change_scene_to_file).
	for child in scene.get_children():
		if child is RemotePlayer and child.char_id == id:
			child.queue_free()
	_instantiate_into(id, scene)

func _on_entity_despawn(id: int) -> void:
	_spawn_data.erase(id)
	var rp = _by_id.get(id)
	if rp != null:
		if is_instance_valid(rp):
			rp.queue_free()
		_by_id.erase(id)

func _on_position(id: int, pos: Vector3, _vel: Vector3, yaw: float, sequence: int) -> void:
	# Own-player position is handled by player.gd._on_world_position.
	if id == Net.get_player_id():
		return
	var rp = _by_id.get(id)
	if rp == null:
		# Position before EntitySpawn (channel race), or while still in
		# the lobby (spawn cached, node not yet instantiated). Drop —
		# subsequent Positions after the node exists will land.
		return
	rp.on_position_update(pos, yaw, sequence)

# Track 6: HP/MP/Stamina updates are server-authoritative. The owning-self
# branch applies to PlayerStats directly (overriding any client-local cache
# that diverged from server truth — e.g. server-side regen, kill-credit XP
# level-ups, or sub-task 3's PvP HP application). Peer branch updates the
# RemotePlayer's bars as before.
func _on_health_update(id: int, hp: float, max_hp: float) -> void:
	if id == Net.get_player_id():
		PlayerStats.max_hp = max_hp
		PlayerStats.set_hp(hp)
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["hp"] = hp
	data["max_hp"] = max_hp
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_health_update(hp, max_hp)

func _on_mana_update(id: int, mp: float, max_mp: float) -> void:
	if id == Net.get_player_id():
		PlayerStats.max_mp = max_mp
		PlayerStats.set_mp(mp)
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["mp"] = mp
	data["max_mp"] = max_mp
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_mana_update(mp, max_mp)

func _on_stamina_update(id: int, stamina: float, maximum: float) -> void:
	if id == Net.get_player_id():
		PlayerStats.max_stamina = maximum
		PlayerStats.set_stamina(stamina)
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["stamina"] = stamina
	data["max_stamina"] = maximum
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_stamina_update(stamina, maximum)

# Track 4 sub-task 2 cast lifecycle. Cast state is transient and not cached
# in _spawn_data — server's step 4a seed catches mid-cast peers for new
# joiners, and a peer's cast bar disappearing during a scene transition is
# acceptable visual loss. RemotePlayer's own state is the source of truth
# while the node lives.
func _on_cast_start(caster: int, spell_name: String, duration: float) -> void:
	if caster == Net.get_player_id():
		return
	var rp = _by_id.get(caster)
	if rp != null and is_instance_valid(rp):
		rp.apply_cast_start(spell_name, duration)

func _on_cast_complete(caster: int, spell_name: String) -> void:
	if caster == Net.get_player_id():
		return
	var rp = _by_id.get(caster)
	if rp != null and is_instance_valid(rp):
		rp.apply_cast_complete(spell_name)

func _on_cast_fail(caster: int, reason: String) -> void:
	if caster == Net.get_player_id():
		# Own cast rejected by the server (silenced / mezzed / etc.).
		# Surface the reason in the combat log so the player knows
		# why nothing happened. Also cancel any local cast bar that
		# may still be running.
		if reason != "":
			CombatLog.add_line("Cast failed: %s" % reason, CombatLog.MsgType.INFO)
		Spells.cancel_cast()
		return
	var rp = _by_id.get(caster)
	if rp != null and is_instance_valid(rp):
		rp.apply_cast_fail(reason)

# Track 6 sub-task 3 — combat outcome from the attacker's POV. For the
# target's local client we render INCOMING text at the local player; for
# any other observer (including the attacker) we render the server's
# authoritative damage number over the targeted RemotePlayer. The PvP
# path also adds a "You hit X for N" combat-log line here (rather than
# in Combat.deal_damage_to_target) so the number matches the post-armor
# applied amount. Track 5+6: server applies HP for both enemy-on-player
# (target.equipped_armor reduction) and player-on-player (can_attack
# gated + same armor reduction) cases — the legacy
# Combat.receive_player_damage call is kept only for enemy attackers
# to drive client-side combat-log + buff-trigger side effects that
# haven't migrated server-side yet.
func _on_hit(attacker: int, target: int, amount: int, crit: bool, dmg_type: int) -> void:
	if target == Net.get_player_id():
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			DamageNumbers.spawn_incoming((players[0] as Node3D).global_position, amount)
		if attacker >= RemoteEnemyManager.ENEMY_ID_BASE:
			var attacker_node: Node = RemoteEnemyManager.get_enemy(attacker)
			var attacker_name := ""
			if attacker_node != null and is_instance_valid(attacker_node):
				attacker_name = attacker_node.mob_name
			# Track 6 sub-task 4a fix: server already deducted HP in
			# sub-task 1's enemy-on-player branch and fans the
			# authoritative HealthUpdate; calling
			# Combat.receive_player_damage here would now route through
			# DamageSelf (sub-task 4a addition) and DOUBLE-APPLY the
			# damage. Trigger the cast-interrupt side effect directly
			# instead.
			Spells.try_interrupt_cast()
			Combat.player_attacked.emit(attacker_node)
			CombatLog.add_line(
				"%s hits you for %d damage." % [
					attacker_name if attacker_name != "" else "Something",
					amount,
				],
				CombatLog.MsgType.DAMAGE_IN,
			)
		else:
			# PvP incoming attack — log the source player so the target
			# knows who hit them. Server's HealthUpdate is the source
			# of truth for HP; we don't call receive_player_damage to
			# avoid double-counting against the local PlayerStats.
			var src_name := "another player"
			var src_rp = _by_id.get(attacker)
			if src_rp != null and is_instance_valid(src_rp):
				src_name = src_rp.player_name
			CombatLog.add_line("%s hits you for %d damage." % [src_name, amount], CombatLog.MsgType.DAMAGE_IN)
		return
	var rp = _by_id.get(target)
	if rp != null and is_instance_valid(rp):
		DamageNumbers.spawn_damage(rp.global_position, amount, crit)
		# PvP outgoing — if this Hit's attacker is us, log the strike
		# against the target. Mirrors the "You hit X for N" line that
		# Combat.deal_damage_to_target emits for enemy targets; for
		# PvP we wait until here so the number reflects server-side
		# armor reduction.
		if attacker == Net.get_player_id():
			CombatLog.add_line("You hit %s for %d damage%s." % [rp.player_name, amount, (" (Critical!)" if crit else "")], CombatLog.MsgType.DAMAGE_OUT)
		_play_spell_impact_fx(rp, amount, dmg_type)
		return
	# Outgoing damage from us on a server-authoritative non-player target
	# (RemoteEnemy or RemotePet). Local prediction is suppressed in
	# Combat.deal_damage_to_target for these, so we render here off the
	# server's authoritative Hit fan-out.
	if attacker != Net.get_player_id():
		return
	if target >= RemotePetManager.PET_ID_BASE:
		var pet_node = RemotePetManager.get_pet(target)
		if pet_node != null and is_instance_valid(pet_node):
			DamageNumbers.spawn_damage(pet_node.global_position, amount, crit)
			var pname: String = pet_node.pet_name if "pet_name" in pet_node else "the pet"
			if amount > 0:
				CombatLog.add_line("You hit %s for %d damage%s." % [pname, amount, (" (Critical!)" if crit else "")], CombatLog.MsgType.DAMAGE_OUT)
			else:
				CombatLog.add_line("You miss %s." % pname, CombatLog.MsgType.DAMAGE_OUT)
			_play_spell_impact_fx(pet_node, amount, dmg_type)
	elif target >= RemoteEnemyManager.ENEMY_ID_BASE:
		var en_node = RemoteEnemyManager.get_enemy(target)
		if en_node != null and is_instance_valid(en_node):
			DamageNumbers.spawn_damage(en_node.global_position, amount, crit)
			var ename: String = en_node.mob_name if "mob_name" in en_node else "the target"
			if amount > 0:
				CombatLog.add_line("You hit %s for %d damage%s." % [ename, amount, (" (Critical!)" if crit else "")], CombatLog.MsgType.DAMAGE_OUT)
			else:
				CombatLog.add_line("You miss %s." % ename, CombatLog.MsgType.DAMAGE_OUT)
			_play_spell_impact_fx(en_node, amount, dmg_type)

# PD_W0025 — render a server-authoritative weapon proc for the attacking player.
# The server already applied the proc damage (folded into the swing); this only
# draws the proc's floating number + elemental flash + named combat-log line
# ("Flaming Strike for 25 damage."). Sent privately to the attacker, but the
# attacker==me guard is kept as defense. Mirrors _on_hit's target resolution.
func _on_proc_triggered(attacker: int, target: int, proc_name: String, amount: int, crit: bool, dmg_type: int) -> void:
	if attacker != Net.get_player_id():
		return
	var node: Node = null
	if target >= RemotePetManager.PET_ID_BASE:
		node = RemotePetManager.get_pet(target)
	elif target >= RemoteEnemyManager.ENEMY_ID_BASE:
		node = RemoteEnemyManager.get_enemy(target)
	if node == null or not is_instance_valid(node):
		return
	if node is Node3D:
		DamageNumbers.spawn_damage((node as Node3D).global_position, amount, crit)
	var label := proc_name if proc_name != "" else "Weapon Proc"
	var suffix := " (Critical!)" if crit else "."
	CombatLog.add_line("%s for %d damage%s" % [label, amount, suffix], CombatLog.MsgType.INFO)
	_play_spell_impact_fx(node, amount, dmg_type)

# Elemental flash + impact light on confirmed spell landings. Server-
# authoritative — only fires when the server's Hit fan-back lands, so
# PvP-rejected casts no longer leave a phantom flash on the target.
# PHYSICAL hits skip the OmniLight burst (mesh flash is handled by the
# per-node hit reactions, not here).
func _play_spell_impact_fx(node: Node, amount: int, dmg_type: int) -> void:
	if amount <= 0 or not is_instance_valid(node):
		return
	if dmg_type == NetProtocol.DamageType.PHYSICAL:
		return
	var color := Combat.net_damage_color(dmg_type)
	if node.has_method("flash_spell_hit"):
		node.flash_spell_hit(color)
	if node is Node3D:
		Combat.spawn_impact_light((node as Node3D).global_position, color)

func _on_damage_shield_trigger(defender: int, attacker: int, amount: int, shield_name: String) -> void:
	# Defender's POV — log the reflect and let them see what their
	# shield did to whoever just attacked them.
	if defender == Net.get_player_id():
		var attacker_name := "the attacker"
		if attacker >= RemoteEnemyManager.ENEMY_ID_BASE:
			var att_node: Node = RemoteEnemyManager.get_enemy(attacker)
			if att_node != null and is_instance_valid(att_node):
				attacker_name = att_node.mob_name
		else:
			var att_rp = _by_id.get(attacker)
			if att_rp != null and is_instance_valid(att_rp):
				attacker_name = att_rp.player_name
		CombatLog.add_line(
			"%s has been hit by %d damage from %s." % [attacker_name, amount, shield_name],
			CombatLog.MsgType.DAMAGE_OUT,
		)
		# Floating number on the attacker so the defender sees the reflect land.
		if attacker >= RemoteEnemyManager.ENEMY_ID_BASE:
			var att_node: Node = RemoteEnemyManager.get_enemy(attacker)
			if att_node != null and is_instance_valid(att_node):
				DamageNumbers.spawn_damage((att_node as Node3D).global_position, amount, false)
		else:
			var att_rp = _by_id.get(attacker)
			if att_rp != null and is_instance_valid(att_rp):
				DamageNumbers.spawn_damage((att_rp as Node3D).global_position, amount, false)
		return
	# Pet's POV — the owner sees their pet's Thorns reflect onto the enemy.
	# The attacker is always an enemy (enemy → pet hits). get_by_id is
	# non-null only for a pet we track; the owner check limits the line to
	# the pet's own master.
	var pet_node: Node = RemotePetManager.get_by_id(defender)
	if pet_node != null and is_instance_valid(pet_node) and (pet_node as RemotePet).owner_id == Net.get_player_id():
		var att_node3: Node = RemoteEnemyManager.get_enemy(attacker)
		var att_nm3 := "the attacker"
		if att_node3 != null and is_instance_valid(att_node3):
			att_nm3 = att_node3.mob_name
		CombatLog.add_line(
			"%s has been hit by %d damage from your pet's %s." % [att_nm3, amount, shield_name],
			CombatLog.MsgType.DAMAGE_OUT,
		)
		if att_node3 != null and is_instance_valid(att_node3):
			DamageNumbers.spawn_damage((att_node3 as Node3D).global_position, amount, false)

func _on_miss(attacker: int, target: int) -> void:
	if target == Net.get_player_id():
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			DamageNumbers.spawn_miss((players[0] as Node3D).global_position)
		# Incoming miss — log who whiffed so the defender gets the same
		# situational awareness as an incoming hit ("X hits you"), which
		# matters most in PvP. Mirrors _on_hit's attacker-name resolution.
		CombatLog.add_line("%s misses you." % _attacker_display_name(attacker), CombatLog.MsgType.DAMAGE_IN)
		return
	var rp = _by_id.get(target)
	if rp != null and is_instance_valid(rp):
		DamageNumbers.spawn_miss(rp.global_position)

# Resolve an attacker id to a combat-log name. Mirrors the enemy-vs-peer
# split in _on_hit: enemy ids (>= ENEMY_ID_BASE) read the mob name, peer
# ids read the RemotePlayer name; same fallbacks ("Something" / "another
# player") so incoming-miss lines read like incoming-hit lines.
func _attacker_display_name(attacker: int) -> String:
	if attacker >= RemoteEnemyManager.ENEMY_ID_BASE:
		var en: Node = RemoteEnemyManager.get_enemy(attacker)
		if en != null and is_instance_valid(en):
			return en.mob_name
		return "Something"
	var rp = _by_id.get(attacker)
	if rp != null and is_instance_valid(rp):
		return rp.player_name
	return "another player"

# Track 4 sub-task 5 — peer died. Routes to RemotePlayer.apply_death which
# plays the fall-over visual. Respawn is implied by the next ResourceUpdate
# carrying hp > 0 (handled in RemotePlayer.apply_health_update).
func _on_entity_died(id: int) -> void:
	if id == Net.get_player_id():
		return
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_death()

# Track 22.H — peer target broadcast. EntityTarget is shared with
# enemy AI; filter by id partition (< ENEMY_ID_BASE = player) so
# we don't fight RemoteEnemyManager over the same signal.
const _ENEMY_ID_BASE: int = 1_000_000_000
func _on_entity_target(id: int, target_id: int) -> void:
	if id >= _ENEMY_ID_BASE:
		return  # enemy / bag / pet — not ours
	if id == Net.get_player_id():
		return  # own target broadcast (peers don't send to themselves)
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_target_change(target_id)

func _on_evade(_attacker: int, target: int) -> void:
	# DamageNumbers has no spawn_evade; reuse spawn_miss — same visual
	# meaning (the attack landed but did nothing). Future polish could
	# distinguish them.
	if target == Net.get_player_id():
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			DamageNumbers.spawn_miss((players[0] as Node3D).global_position)
		return
	var rp = _by_id.get(target)
	if rp != null and is_instance_valid(rp):
		DamageNumbers.spawn_miss(rp.global_position)

# Track 4 sub-task 3 — full buff snapshot. Cached on _spawn_data so a
# rehydrate (scene transition with the peer mid-buffs) replays the last
# known list onto the new RemotePlayer instance.
func _on_buff_snapshot(target: int, names: PackedStringArray, durations: PackedFloat32Array) -> void:
	if target == Net.get_player_id():
		# Own snapshot — server is authoritative for buff lifetime.
		# Drops any locally tracked buff the server has dispelled or
		# expired (e.g. Antimagic Ward stripping Bless).
		BuffManager.reconcile_with_server_snapshot(names, durations)
		return
	if not _spawn_data.has(target):
		return
	var data: Dictionary = _spawn_data[target]
	data["buff_names"] = names
	data["buff_durations"] = durations
	var rp = _by_id.get(target)
	if rp != null and is_instance_valid(rp):
		rp.apply_buff_snapshot(names, durations)

func _instantiate_into(id: int, scene: Node) -> void:
	var data: Dictionary = _spawn_data[id]
	var rp := REMOTE_PLAYER_SCENE.instantiate()
	rp.char_id = id
	rp.player_name = data["name"]
	rp.race = data["race"]
	rp.player_class = data["class"]
	rp.level = data["level"]
	rp.global_position = data["pos"]
	rp.rotation.y = data["yaw"]
	scene.add_child(rp)
	_by_id[id] = rp
	# Apply any cached resource state (from earlier broadcasts that arrived
	# while we were in the lobby, or the 4a seed at app-connect). add_child
	# fires _ready first, so the bar nodes are guaranteed live here.
	if data.has("hp"):
		rp.apply_health_update(data["hp"], data["max_hp"])
	if data.has("mp"):
		rp.apply_mana_update(data["mp"], data["max_mp"])
	if data.has("stamina"):
		rp.apply_stamina_update(data["stamina"], data["max_stamina"])
	if data.has("buff_names"):
		rp.apply_buff_snapshot(data["buff_names"], data["buff_durations"])

# A scene "hosts the local player" once player.gd._ready has run and
# added the player to the "player" group. Picks out world.tscn (and any
# future 3D zones that follow the same pattern) without hard-coding a
# scene path.
func _scene_hosts_local_player(_scene: Node) -> bool:
	return get_tree().get_first_node_in_group("player") != null

# Defensive — call before zone swaps if needed. Scene change already
# frees the children when the parent scene goes away.
func clear_all() -> void:
	for id in _by_id:
		var rp = _by_id[id]
		if is_instance_valid(rp):
			rp.queue_free()
	_by_id.clear()
	_spawn_data.clear()
