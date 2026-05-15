extends NetClient

# Net — single-owner network adapter wrapping the gdext_net `NetClient`.
#
# This script *extends* the GDExtension class directly so all the typed
# signals (`transport_connected`, `position`, ...) are available as-is.
# On top, this layer:
#
#   1. Parses launcher CLI args once on `_ready`.
#   2. If launcher mode, reads the world-token tempfile, deletes it, and
#      kicks off the connect flow (transport handshake → app Connect →
#      ConnectOk).
#   3. Tracks the high-level state machine and re-emits coarser signals
#      callers care about: `app_connected`, `app_disconnected`.
#   4. Pumps `poll(delta)` every frame while a connection exists.
#
# Local-save / Test Room flow: when `CliArgs.parse()` returns null, this
# autoload sits idle. Nothing else changes; the existing client-authoritative
# code continues to drive the game.

enum State {
	DISCONNECTED,
	CONNECTING_TRANSPORT,  # renet handshake in flight
	CONNECTED_TRANSPORT,   # transport up, waiting for ConnectOk
	CONNECTED_APP,         # ready for gameplay intents
}

# Server kicks at HEARTBEAT_TIMEOUT (10 s) of app-layer silence. Beat at 4 s
# so a single dropped packet still leaves headroom — the system channel is
# reliable so loss is unlikely, but cheap insurance. Any other inbound app
# message (Move, etc.) also resets the server's idle timer, so once
# `send_movement` is wired into player.gd this becomes redundant but
# harmless.
const HEARTBEAT_INTERVAL_SEC := 4.0

# Coarse, high-level signals — most callers want these, not the raw
# transport-level ones from the GDExtension.
signal app_connected(player_id: int)
signal app_disconnected(reason: String)
signal world_position(id: int, pos: Vector3, vel: Vector3, yaw: float, sequence: int)
# Track 3 entity replication. `char_class` rather than `class` because the
# latter is reserved in GDScript.
signal world_entity_spawn(
	id: int,
	player_name: String,
	race: String,
	char_class: String,
	level: int,
	pos: Vector3,
	yaw: float)
signal world_entity_despawn(id: int)
# Track 4 resource bars — relayed from each peer's owning-client broadcast.
signal world_health_update(id: int, hp: float, max_hp: float)
signal world_mana_update(id: int, mp: float, max_mp: float)
signal world_stamina_update(id: int, stamina: float, maximum: float)
# Track 4 sub-task 2 cast lifecycle — relayed from the casting peer's
# broadcasts. `duration` is the time the receiver should run the bar for.
signal world_cast_start(caster: int, spell_name: String, duration: float)
signal world_cast_complete(caster: int, spell_name: String)
signal world_cast_fail(caster: int, reason: String)
# Track 4 sub-task 3 buff snapshot — names/durations are parallel arrays.
signal world_buff_snapshot(
	target: int,
	names: PackedStringArray,
	durations: PackedFloat32Array)
# Track 4 sub-task 4 combat events — pure visualization fan-out; the
# target's HP isn't driven by these (sub-task 6 / Track 6 lifts authority).
signal world_hit(attacker: int, target: int, amount: int, crit: bool, dmg_type: int)
signal world_miss(attacker: int, target: int)
signal world_evade(attacker: int, target: int)
# Track 4 sub-task 5 — peer's HP hit zero. Receiver plays death anim;
# respawn lands silently via the next ResourceUpdate.
signal world_entity_died(id: int)
# Track 5 sub-task 2 — server announces a server-spawned enemy. `id` is
# in the reserved enemy-id partition (>= 1_000_000_000) so the client
# can distinguish from player EntitySpawns by id alone.
signal world_enemy_spawn(
	id: int,
	mob_name: String,
	level: int,
	max_hp: float,
	hp: float,
	pos: Vector3,
	yaw: float)
# Track 5 sub-task 2 — server-driven aggro replication. `target_id == 0`
# encodes "no target" (drop / leash); non-zero is the targeted entity's id.
signal world_entity_target(id: int, target_id: int)
# Track 5 sub-task 4 — server-spawned loot bag landed in the AOI.
# `item_paths` and `item_counts` are parallel arrays of the bag's
# current contents. Re-fires (with shrinking arrays) every time the
# server processes a successful LootItem / LootAll — clients update
# the bag's view by reassignment, not diff application.
signal world_loot_bag_spawn(
	bag_id: int,
	pos: Vector3,
	item_paths: PackedStringArray,
	item_counts: PackedInt32Array)
# Track 5 sub-task 4 — private confirmation that the local player's
# LootItem / LootAll intent landed. Carries one stack the looter just
# claimed; the GDScript handler loads `item_path` → ItemData and adds
# to Inventory.
signal world_loot_granted(item_path: String, count: int)
# Track 5 sub-task 5 — private kill-credit XP grant. Receive-side
# handler calls PlayerStats.gain_xp directly (mirror of how
# RemoteLootBagManager._on_loot_granted invokes Inventory.add_item).
# `current` / `to_next` are placeholder zeros from the server in
# Track 5; PlayerStats.gain_xp computes them internally.
signal world_xp_gained(amount: int, current: int, to_next: int)
# Track 6 sub-task 5 — group state from the server.
# group_invited: someone is asking us to join their group.
# group_roster: the group we belong to has a new membership snapshot
# (empty member arrays = the group dissolved or we were kicked).
signal world_group_invited(from_id: int, from_name: String)
signal world_group_roster(group_id: int, leader_id: int, member_ids: PackedInt64Array, member_names: PackedStringArray)
# damage_shield_trigger: a player's Thorns / Spellshield reflected
# damage back at an attacker. defender = the player whose shield fired.
signal world_damage_shield_trigger(defender: int, attacker: int, amount: int, shield_name: String)

var _state: State = State.DISCONNECTED
var _session_token_bytes := PackedByteArray()
var _char_id: int = -1
var _client_version := ""
var _player_id: int = -1
var _move_sequence: int = 0
var _heartbeat_timer: Timer = null

# Server-authoritative identity, delivered in ConnectOk. The lobby reads
# these in _on_app_connected to call PlayerStats.apply_character before
# entering world.tscn — without it the local character spawns classless
# with default base stats.
var _own_name := ""
var _own_race := ""
var _own_class := ""
var _own_level: int = 1

func _ready() -> void:
	# Hook GDExtension signals — populated from the renet poll loop.
	transport_connected.connect(_on_transport_connected)
	transport_disconnected.connect(_on_transport_disconnected)
	connect_ok.connect(_on_connect_ok)
	kicked.connect(_on_kicked)
	position.connect(_on_position)
	entity_spawn.connect(_on_entity_spawn)
	entity_despawn.connect(_on_entity_despawn)
	health_update.connect(_on_health_update)
	mana_update.connect(_on_mana_update)
	stamina_update.connect(_on_stamina_update)
	cast_start.connect(_on_cast_start)
	cast_complete.connect(_on_cast_complete)
	cast_fail.connect(_on_cast_fail)
	buff_snapshot.connect(_on_buff_snapshot)
	hit.connect(_on_hit)
	miss.connect(_on_miss)
	evade.connect(_on_evade)
	entity_died.connect(_on_entity_died)
	enemy_spawn.connect(_on_enemy_spawn)
	entity_target.connect(_on_entity_target)
	loot_bag_spawn.connect(_on_loot_bag_spawn)
	loot_granted.connect(_on_loot_granted)
	xp_gained.connect(_on_xp_gained)
	group_invited.connect(_on_group_invited)
	group_roster.connect(_on_group_roster)
	damage_shield_trigger.connect(_on_damage_shield_trigger)

	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL_SEC
	_heartbeat_timer.one_shot = false
	_heartbeat_timer.autostart = false
	_heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	add_child(_heartbeat_timer)

	var args: Variant = CliArgs.parse()
	if args == null:
		# Local-save / dev-iteration path. Nothing to do.
		return
	var ok := _start_from_args(args as Dictionary)
	if not ok:
		push_warning("Net: launcher handoff failed; staying disconnected")

func _process(delta: float) -> void:
	if _state == State.DISCONNECTED:
		return
	poll(delta)

# ─── Public API ─────────────────────────────────────────────────────

func is_launcher_mode() -> bool:
	return _state != State.DISCONNECTED or _char_id >= 0

func is_app_ready() -> bool:
	return _state == State.CONNECTED_APP

func get_player_id() -> int:
	return _player_id

# Server-authoritative identity from ConnectOk. Empty strings / 0 until the
# handshake completes; lobby's _on_app_connected uses these to drive
# PlayerStats.apply_character.
func get_own_name() -> String:
	return _own_name

func get_own_race() -> String:
	return _own_race

func get_own_class() -> String:
	return _own_class

func get_own_level() -> int:
	return _own_level

# Send a Move intent. Server clamps the direction to unit length. Sequence
# is auto-incremented; out-of-order packets are dropped server-side.
func send_movement(direction: Vector3, jumping: bool = false) -> void:
	if _state != State.CONNECTED_APP:
		return
	_move_sequence += 1
	send_move(_move_sequence, direction, jumping)

# Track 6: Sit / Stand intents — server uses them to scale regen rates
# server-side. Movement auto-stands on either side, so a dropped Stand
# self-heals; the explicit intent just speeds the transition. Gated like
# every other send wrapper so local-save mode stays quiet on the wire.
func broadcast_sit() -> void:
	if _state != State.CONNECTED_APP:
		return
	send_sit()

func broadcast_stand() -> void:
	if _state != State.CONNECTED_APP:
		return
	send_stand()

# Track 4 sub-task 2: cast broadcast wrappers. Gated like every other send
# so local-save and lobby phases stay quiet on the wire.
func broadcast_cast_start(spell_name: String, duration: float) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_cast_start_broadcast(spell_name, duration)

func broadcast_cast_complete(spell_name: String) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_cast_complete_broadcast(spell_name)

func broadcast_cast_fail(reason: String) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_cast_fail_broadcast(reason)

func broadcast_buff_snapshot(names: PackedStringArray, durations: PackedFloat32Array) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_buff_snapshot_broadcast(names, durations)

# Track 4 sub-task 4 combat broadcasts.
func broadcast_hit(target: int, amount: int, crit: bool, dmg_type: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_hit_broadcast(target, amount, crit, dmg_type)

# Track 6 sub-task 2 — player → server attack intent. Server runs the
# damage formula against its own copy of attacker stats + the equipped
# weapon (looked up by path in its items table) + main/offhand flag.
# weapon_path is the .tres resource path ("" for bare-handed). Server
# fans Hit + HealthUpdate + (on kill) EntityDied to in_world peers.
func broadcast_attack(target_id: int, weapon_path: String, is_offhand: bool, dmg_type: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_attack(target_id, weapon_path, is_offhand, dmg_type)

# Track 5 sub-task 4 — player → server loot pickup intents. Server
# validates pickup range + slot bounds, transfers the stack with a
# private LootGranted, and re-broadcasts the bag (or despawns it when
# empty).
func broadcast_loot_item(bag_id: int, slot: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_loot_item(bag_id, slot)

func broadcast_loot_all(bag_id: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_loot_all(bag_id)

func broadcast_miss(target: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_miss_broadcast(target)

func broadcast_evade(target: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_evade_broadcast(target)

func broadcast_death() -> void:
	if _state != State.CONNECTED_APP:
		return
	send_death_broadcast()

# Track 6: local death timer elapsed; tell the server we're back. Server
# resets conn.hp/mp/stamina to max and fans HealthUpdate / ManaUpdate /
# StaminaUpdate so peer RemotePlayer bars stand back up.
func broadcast_respawn() -> void:
	if _state != State.CONNECTED_APP:
		return
	send_respawn()

# Track 6 sub-task 3: armor sync. Fires on Equipment.equipment_changed
# so the server's incoming-damage formula applies the same AC reduction
# the client uses. Cheaty (client picks the number) but matches Track
# 6's transitional trust model.
func broadcast_equip_update(armor: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_equip_update(armor)

# Track 6 sub-task 3: dev /pvp toggle. Server caches the flag on the
# sender's PerConnection; combat::can_attack requires both attacker and
# target to have the flag on.
func broadcast_pvp_toggle(on: bool) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_pvp_toggle(on)

# Track 6 sub-task 3b: spell cast intent. Server looks up spell_name in
# spells.toml, validates mana / target / range, applies authoritative
# damage or heal, and fans HealthUpdate / ManaUpdate. target_id = 0
# encodes "no target" (SELF / NONE spells); ENEMY / AOE spells supply
# the chosen target's char_id (for player targets) or enemy id.
func broadcast_cast_spell(spell_name: String, target_id: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_cast_spell(spell_name, target_id)

# Track 6 sub-task 3 dev intents. Bypass the CastSpell pipeline so we
# can verify server-driven HP/heal application before the spell port
# lands.
func broadcast_damage_self(amount: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_damage_self(amount)

func broadcast_heal_self(amount: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_heal_self(amount)

# Track 6 sub-task 5 — group action wrappers. Server processes the
# corresponding ClientWorldMsg variants, fans GroupInvited /
# GroupRoster back through the typed signals above.
func broadcast_group_invite(target_name: String) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_group_invite(target_name)

func broadcast_group_accept_invite(from_id: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_group_accept_invite(from_id)

func broadcast_group_leave() -> void:
	if _state != State.CONNECTED_APP:
		return
	send_group_leave()

func broadcast_group_kick(target_name: String) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_group_kick(target_name)

func leave_session() -> void:
	# Send the app-layer Disconnect and drive renet a few times so the
	# message actually reaches the UDP socket. ~200 ms total.
	#
	# We deliberately do NOT call disconnect_now() here: it sends a
	# netcode-level disconnect packet, which races the app message at the
	# server. When both arrive in the same tick, renet's transport.update()
	# evicts the connection's channel buffers BEFORE our tick code drains
	# them, so the app Disconnect is silently lost and the server reports
	# `reason=Transport` instead of logging `client requested disconnect`.
	#
	# Skipping disconnect_now means the OS closes the UDP socket on
	# process exit; the server processes our message cleanly, calls
	# Outcome::Disconnect → server.disconnect(), and reports
	# `reason=DisconnectedByServer`. Both log lines land.
	#
	# This is fine for the current callers (window-close + Quit Game),
	# which both lead to immediate process exit. A future return-to-lobby
	# flow that needs to keep the process alive would need a different
	# teardown path (poll long enough for the message to be acked, then
	# disconnect_now).
	if _state == State.CONNECTED_APP:
		send_disconnect()
		for i in 4:
			poll(0.05)
	_stop_heartbeat()
	_state = State.DISCONNECTED
	_player_id = -1

# ─── Internal: launcher flow ────────────────────────────────────────

func _start_from_args(args: Dictionary) -> bool:
	if _state != State.DISCONNECTED:
		push_warning("Net._start_from_args called in state %d" % _state)
		return false

	var token_path := str(args.get("world_token_path", ""))
	var endpoint := str(args.get("world_endpoint", ""))
	var auth_token_hex := str(args.get("auth_token", ""))
	var char_id := int(args.get("char_id", -1))
	var client_version := str(args.get("client_version", ""))

	if token_path == "" or endpoint == "" or auth_token_hex == "" or char_id < 0:
		push_warning("Net: launcher args incomplete")
		return false

	var token_bytes := _read_and_delete_token_file(token_path)
	if token_bytes.is_empty():
		push_warning("Net: world token file unreadable: %s" % token_path)
		return false

	var session_bytes := _hex_to_bytes(auth_token_hex)
	if session_bytes.size() != 32:
		push_warning("Net: auth token decode produced %d bytes (expected 32)"
			% session_bytes.size())
		return false

	_session_token_bytes = session_bytes
	_char_id = char_id
	_client_version = client_version
	_move_sequence = 0

	if not connect_to_server(token_bytes, endpoint):
		push_warning("Net: NetClient.connect_to_server returned false")
		return false

	_state = State.CONNECTING_TRANSPORT
	return true

# Reads the token bytes and immediately removes the tempfile. Even if the
# subsequent connect fails, the token is gone — the 30 s server-side TTL is
# the secondary safeguard, not the primary defense.
func _read_and_delete_token_file(path: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	if not FileAccess.file_exists(path):
		return bytes
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return bytes
	bytes = f.get_buffer(f.get_length())
	f.close()
	# Best-effort delete — log but don't fail if the OS won't let us remove it.
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_warning("Net: could not delete world token file (err=%d): %s" % [err, path])
	return bytes

func _hex_to_bytes(hex: String) -> PackedByteArray:
	var pba := PackedByteArray()
	if hex.length() % 2 != 0:
		return pba
	@warning_ignore("integer_division")
	pba.resize(hex.length() / 2)
	for i in pba.size():
		pba[i] = hex.substr(i * 2, 2).hex_to_int() & 0xFF
	return pba

# ─── Internal: GDExtension signal handlers ──────────────────────────

func _on_transport_connected() -> void:
	_state = State.CONNECTED_TRANSPORT
	# Now safe to send the app-layer Connect.
	if not send_app_connect(_session_token_bytes, _char_id, _client_version):
		push_warning("Net: send_app_connect returned false")

func _on_transport_disconnected(reason: String) -> void:
	_stop_heartbeat()
	_state = State.DISCONNECTED
	_player_id = -1
	app_disconnected.emit(reason)

func _on_connect_ok(
		player_id: int,
		n: String,
		race: String,
		char_class: String,
		level: int) -> void:
	_player_id = player_id
	_own_name = n
	_own_race = race
	_own_class = char_class
	_own_level = level
	_state = State.CONNECTED_APP
	_heartbeat_timer.start()
	app_connected.emit(player_id)

func _on_kicked(reason: String, code: String) -> void:
	push_warning("Net: kicked code=%s reason=%s" % [code, reason])
	_stop_heartbeat()
	_state = State.DISCONNECTED
	_player_id = -1
	app_disconnected.emit("kicked: %s" % reason)
	disconnect_now()

func _on_position(id: int, pos: Vector3, vel: Vector3, yaw: float, sequence: int) -> void:
	world_position.emit(id, pos, vel, yaw, sequence)

# GDExtension `entity_spawn` signal parameter names mirror the Rust side
# (id, name, race, class, level, pos, yaw). Receiver parameter names rebind
# safely: `n` instead of `name` so we don't shadow Node.name; `char_class`
# instead of `class` (GDScript reserved word).
func _on_entity_spawn(
		id: int,
		n: String,
		race: String,
		char_class: String,
		level: int,
		pos: Vector3,
		yaw: float) -> void:
	world_entity_spawn.emit(id, n, race, char_class, level, pos, yaw)

func _on_entity_despawn(id: int) -> void:
	world_entity_despawn.emit(id)

# Track 4: GDExtension signal parameter names mirror the Rust side. Receiver
# uses `maximum` for stamina_update's `max` to avoid shadowing GDScript's @max.
func _on_health_update(id: int, hp: float, max_hp: float) -> void:
	world_health_update.emit(id, hp, max_hp)

func _on_mana_update(id: int, mp: float, max_mp: float) -> void:
	world_mana_update.emit(id, mp, max_mp)

func _on_stamina_update(id: int, stamina: float, maximum: float) -> void:
	world_stamina_update.emit(id, stamina, maximum)

func _on_cast_start(caster: int, spell_name: String, duration: float) -> void:
	world_cast_start.emit(caster, spell_name, duration)

func _on_cast_complete(caster: int, spell_name: String) -> void:
	world_cast_complete.emit(caster, spell_name)

func _on_cast_fail(caster: int, reason: String) -> void:
	world_cast_fail.emit(caster, reason)

func _on_buff_snapshot(target: int, names: PackedStringArray, durations: PackedFloat32Array) -> void:
	world_buff_snapshot.emit(target, names, durations)

func _on_hit(attacker: int, target: int, amount: int, crit: bool, dmg_type: int) -> void:
	world_hit.emit(attacker, target, amount, crit, dmg_type)

func _on_miss(attacker: int, target: int) -> void:
	world_miss.emit(attacker, target)

func _on_evade(attacker: int, target: int) -> void:
	world_evade.emit(attacker, target)

func _on_entity_died(id: int) -> void:
	world_entity_died.emit(id)

func _on_enemy_spawn(
		id: int,
		mob_name: String,
		level: int,
		max_hp: float,
		hp: float,
		pos: Vector3,
		yaw: float) -> void:
	world_enemy_spawn.emit(id, mob_name, level, max_hp, hp, pos, yaw)

func _on_entity_target(id: int, target_id: int) -> void:
	world_entity_target.emit(id, target_id)

func _on_loot_bag_spawn(
		bag_id: int,
		pos: Vector3,
		item_paths: PackedStringArray,
		item_counts: PackedInt32Array) -> void:
	world_loot_bag_spawn.emit(bag_id, pos, item_paths, item_counts)

func _on_loot_granted(item_path: String, count: int) -> void:
	world_loot_granted.emit(item_path, count)

func _on_xp_gained(amount: int, current: int, to_next: int) -> void:
	world_xp_gained.emit(amount, current, to_next)
	PlayerStats.gain_xp(amount)

func _on_group_invited(from_id: int, from_name: String) -> void:
	world_group_invited.emit(from_id, from_name)

func _on_group_roster(group_id: int, leader_id: int, member_ids: PackedInt64Array, member_names: PackedStringArray) -> void:
	world_group_roster.emit(group_id, leader_id, member_ids, member_names)

func _on_damage_shield_trigger(defender: int, attacker: int, amount: int, shield_name: String) -> void:
	world_damage_shield_trigger.emit(defender, attacker, amount, shield_name)

func _on_heartbeat_tick() -> void:
	if _state == State.CONNECTED_APP:
		send_heartbeat()

func _stop_heartbeat() -> void:
	if _heartbeat_timer != null and not _heartbeat_timer.is_stopped():
		_heartbeat_timer.stop()
