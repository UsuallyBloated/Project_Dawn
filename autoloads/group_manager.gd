extends Node

# membership_changed=true for join/leave/leader shifts; false for stat-only ticks
signal group_updated(membership_changed: bool)
signal invite_received(from_peer_id: int, from_name: String)

const MAX_SIZE := 6
const GROUP_XP_BONUS := 1.20

var in_group := false
var is_leader := false
var leader_peer_id := 0
var members: Array = []
var pending_invite_from := 0

# PD_W0014 — group loot distribution mode, server-authoritative (mirrors
# the roster's loot_mode field). 0 = Round Robin (default), 1 = Free-for-all.
# See docs/design/group_loot_and_coin.md.
const LOOT_ROUND_ROBIN := 0
const LOOT_FREE_FOR_ALL := 1
var loot_mode := LOOT_ROUND_ROBIN

var _my_peer_id := 0
var _stats_dirty := false

func _ready() -> void:
	_my_peer_id = multiplayer.get_unique_id()
	PlayerStats.hp_changed.connect(func(_c, _m): _sync_stats())
	PlayerStats.mp_changed.connect(func(_c, _m): _sync_stats())
	PlayerStats.stamina_changed.connect(func(_c, _m): _sync_stats())
	# Track 6 sub-task 5 — wire to server-driven group state in
	# launcher mode. The legacy enet MultiplayerAPI RPCs below stay
	# for Test Room single-player; in launcher mode they're dead code
	# because the action methods route through Net early-return paths.
	Net.world_group_invited.connect(_on_world_group_invited)
	Net.world_group_roster.connect(_on_world_group_roster)
	# Round-7 playtest fix — on transport disconnect (relog / zone-out)
	# the server drops us from any group server-side but never re-fans
	# our own state on reconnect (the server's GroupRoster fan only
	# targets remaining group members, and the leaver is already gone).
	# Clearing the local mirror here prevents stale group state from
	# leaking across the disconnect, which surfaced as "I'm not in a
	# group anymore but my pet allegiance still treats peers as
	# group-mates" after a relog.
	Net.app_disconnected.connect(func(_reason): _clear_group())

func _sync_stats() -> void:
	if not in_group or _stats_dirty:
		return
	_stats_dirty = true
	call_deferred("_flush_stats")

func _flush_stats() -> void:
	_stats_dirty = false
	if not in_group:
		return
	if _my_peer_id == leader_peer_id:
		_update_member_entry(_local_stats())
		for m in members:
			var pid: int = m.get("peer_id", 0)
			if pid != 0 and pid != _my_peer_id:
				_rpc_member_stat_delta.rpc_id(pid, _my_peer_id,
					PlayerStats.hp, PlayerStats.max_hp,
					PlayerStats.mp, PlayerStats.max_mp,
					PlayerStats.stamina, PlayerStats.max_stamina)
		group_updated.emit(false)
	else:
		_rpc_stat_update.rpc_id(leader_peer_id, _my_peer_id,
			PlayerStats.hp, PlayerStats.max_hp,
			PlayerStats.mp, PlayerStats.max_mp,
			PlayerStats.stamina, PlayerStats.max_stamina)

# â”€â”€ Local actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func invite_player(target_peer_id: int) -> void:
	# Track 6 sub-task 5: launcher mode routes through Net (server
	# resolves the target by name). The local-RPC path stays for
	# Test Room single-player. target_peer_id is unused in launcher
	# mode — UI passes 0 or the legacy ID.
	if Net.is_launcher_mode():
		# Caller should use invite_player_by_name in launcher mode.
		push_warning("GroupManager.invite_player called in launcher mode — use invite_player_by_name")
		return
	if in_group and members.size() >= MAX_SIZE:
		return
	_rpc_receive_invite.rpc_id(target_peer_id, _my_peer_id, PlayerStats.player_name)

# Track 6 sub-task 5 — chat / UI entry point for "/invite <name>" in
# launcher mode. Server looks up the target by name in its
# connections map. Test Room single-player has no server; logs a
# message.
func invite_player_by_name(target_name: String) -> void:
	if Net.is_launcher_mode():
		Net.broadcast_group_invite(target_name)
	else:
		push_warning("GroupManager.invite_player_by_name unsupported outside launcher mode")

func accept_invite() -> void:
	if Net.is_launcher_mode():
		if pending_invite_from == 0:
			return
		Net.broadcast_group_accept_invite(pending_invite_from)
		pending_invite_from = 0
		return
	if pending_invite_from == 0:
		return
	_rpc_receive_accept.rpc_id(pending_invite_from, _my_peer_id, _local_stats())
	pending_invite_from = 0

func leave_group() -> void:
	if not in_group:
		return
	if Net.is_launcher_mode():
		Net.broadcast_group_leave()
		# Server will fan an empty roster back; _on_world_group_roster
		# clears local state. Optimistically clear here too so the UI
		# updates without waiting for the round-trip.
		_clear_group()
		return
	if is_leader:
		if members.size() <= 1:
			_disband()
			return
		var new_leader := 0
		var remaining: Array = []
		for m in members:
			var pid: int = m.get("peer_id", 0)
			if pid == _my_peer_id:
				continue
			remaining.append(m)
			if new_leader == 0:
				new_leader = pid
		members = remaining
		leader_peer_id = new_leader
		_broadcast_state()
	else:
		_rpc_receive_leave.rpc_id(leader_peer_id, _my_peer_id)
	_clear_group()

# Track 6 sub-task 5 — leader-only kick by name (launcher mode).
func kick_member_by_name(target_name: String) -> void:
	if Net.is_launcher_mode():
		Net.broadcast_group_kick(target_name)
	else:
		push_warning("GroupManager.kick_member_by_name unsupported outside launcher mode")

# Track 6 sub-task 5 — Net signal handlers. Server is authoritative
# on group membership in launcher mode; these handlers update the
# local mirror so the rest of the GroupManager API (in_group,
# members, is_leader, etc.) stays accurate without changing the
# downstream consumers' code.
func _on_world_group_invited(from_id: int, from_name: String) -> void:
	pending_invite_from = from_id
	invite_received.emit(from_id, from_name)

func _on_world_group_roster(_group_id: int, leader_id: int, member_ids: PackedInt64Array, member_names: PackedStringArray, p_loot_mode: int) -> void:
	if member_ids.is_empty():
		# Group dissolved or we got kicked.
		_clear_group()
		return
	loot_mode = p_loot_mode
	leader_peer_id = leader_id
	is_leader = (Net.get_player_id() == leader_id)
	in_group = true
	members.clear()
	for i in member_ids.size():
		var nm := member_names[i] if i < member_names.size() else ""
		members.append({
			"peer_id": member_ids[i],
			"name": nm,
			"level": 0,
			"hp": 0.0, "max_hp": 0.0,
			"mp": 0.0, "max_mp": 0.0,
			"sta": 0.0, "max_sta": 0.0,
		})
	group_updated.emit(true)

# PD_W0014 — leader requests a loot-mode change. The server validates
# leadership and re-fans the roster, which updates `loot_mode` here and
# fires group_updated. No-op for non-leaders.
func set_loot_mode(mode: int) -> void:
	if not is_leader:
		return
	Net.broadcast_set_group_loot_mode(mode)

func loot_mode_name() -> String:
	return "Free-for-all" if loot_mode == LOOT_FREE_FOR_ALL else "Round Robin"

func pass_leadership(new_leader_peer_id: int) -> void:
	if not is_leader:
		return
	if Net.is_launcher_mode():
		# Server validates (current leader → member) and re-fans the
		# roster, which updates leader_peer_id / is_leader for everyone.
		# No optimistic local change — the old local-only path was the bug
		# (the next server roster snapped leadership back to the original).
		Net.broadcast_pass_leadership(new_leader_peer_id)
		return
	leader_peer_id = new_leader_peer_id
	_broadcast_state()

func distribute_kill_xp(base_xp: int) -> void:
	# Track 6 sub-task 5: server splits XP among the killer's group
	# in launcher mode (kill credit branch in tick.rs). The local
	# Net.xp_gained handler calls PlayerStats.gain_xp directly. This
	# RPC path stays for Test Room single-player.
	if Net.is_launcher_mode():
		return
	if not in_group or members.size() <= 1:
		PlayerStats.gain_xp(base_xp)
		return
	var share: int = maxi(1, int(base_xp * GROUP_XP_BONUS / members.size()))
	PlayerStats.gain_xp(share)
	for m in members:
		var pid: int = m.get("peer_id", 0)
		if pid != 0 and pid != _my_peer_id:
			_rpc_receive_xp.rpc_id(pid, share)

func broadcast_group_chat(sender_name: String, msg: String) -> void:
	if not in_group:
		return
	for m in members:
		var pid: int = m.get("peer_id", 0)
		if pid != 0 and pid != _my_peer_id:
			_rpc_group_chat.rpc_id(pid, sender_name, msg)

# â”€â”€ RPCs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@rpc("any_peer", "reliable")
func _rpc_receive_invite(from_peer_id: int, from_name: String) -> void:
	if multiplayer.get_remote_sender_id() != from_peer_id:
		return
	pending_invite_from = from_peer_id
	invite_received.emit(from_peer_id, from_name)

@rpc("any_peer", "reliable")
func _rpc_receive_accept(new_peer_id: int, stats: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != new_peer_id:
		return
	if in_group and not is_leader:
		return
	if not in_group:
		in_group = true
		is_leader = true
		leader_peer_id = _my_peer_id
		members = [_local_stats()]
	if members.size() >= MAX_SIZE:
		return
	members.append(stats)
	_broadcast_state()

@rpc("any_peer", "reliable")
func _rpc_receive_leave(leaving_peer_id: int) -> void:
	if not is_leader:
		return
	members = members.filter(func(m): return m.get("peer_id") != leaving_peer_id)
	if members.size() <= 1:
		_disband()
	else:
		_broadcast_state()

@rpc("any_peer", "reliable")
func _rpc_receive_state(new_leader_id: int, new_members: Array) -> void:
	leader_peer_id = new_leader_id
	is_leader = (_my_peer_id == new_leader_id)
	members = new_members
	in_group = true
	group_updated.emit(true)

# Received by the leader from a member whose stats changed.
@rpc("any_peer", "unreliable_ordered")
func _rpc_stat_update(peer_id: int, hp: float, max_hp: float, mp: float, max_mp: float, sta: float, max_sta: float) -> void:
	if not is_leader:
		return
	var stats := {"peer_id": peer_id, "hp": hp, "max_hp": max_hp,
		"mp": mp, "max_mp": max_mp, "sta": sta, "max_sta": max_sta}
	_update_member_entry(stats)
	for m in members:
		var pid: int = m.get("peer_id", 0)
		if pid != 0 and pid != _my_peer_id and pid != peer_id:
			_rpc_member_stat_delta.rpc_id(pid, peer_id, hp, max_hp, mp, max_mp, sta, max_sta)
	group_updated.emit(false)

# Forwarded by the leader to all other members â€” stat delta only, no membership change.
@rpc("any_peer", "unreliable_ordered")
func _rpc_member_stat_delta(peer_id: int, hp: float, max_hp: float, mp: float, max_mp: float, sta: float, max_sta: float) -> void:
	_update_member_entry({"peer_id": peer_id, "hp": hp, "max_hp": max_hp,
		"mp": mp, "max_mp": max_mp, "sta": sta, "max_sta": max_sta})
	group_updated.emit(false)

@rpc("any_peer", "reliable")
func _rpc_receive_xp(amount: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	for m in members:
		if m.get("peer_id", 0) == sender:
			PlayerStats.gain_xp(amount)
			return

@rpc("any_peer", "reliable")
func _rpc_receive_disband() -> void:
	_clear_group()

@rpc("any_peer", "reliable")
func _rpc_group_chat(sender_name: String, msg: String) -> void:
	if sender_name.length() > 64 or msg.length() > 256:
		return
	CombatLog.add_line("[Group] %s: %s" % [sender_name, msg], CombatLog.MsgType.GROUP_CHAT)

# â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

# True when `peer_id` (a server char_id in launcher mode, or an enet
# unique-id in Test Room) is a current member of the group. Used by
# friend/foe UI (RemotePet allegiance tint) and PvP heal pre-checks
# (spells.gd) to distinguish group-mate from neutral / hostile.
func is_member(peer_id: int) -> bool:
	if not in_group:
		return false
	for m in members:
		if int(m.get("peer_id", 0)) == peer_id:
			return true
	return false

func _local_stats() -> Dictionary:
	return {
		"peer_id": _my_peer_id,
		"name": PlayerStats.player_name,
		"level": PlayerStats.level,
		"hp": PlayerStats.hp, "max_hp": PlayerStats.max_hp,
		"mp": PlayerStats.mp, "max_mp": PlayerStats.max_mp,
		"sta": PlayerStats.stamina, "max_sta": PlayerStats.max_stamina,
	}

func _update_member_entry(stats: Dictionary) -> void:
	var pid: int = stats.get("peer_id", 0)
	for i in members.size():
		if members[i].get("peer_id") == pid:
			members[i].merge(stats, true)
			return

func _broadcast_state() -> void:
	for m in members:
		var pid: int = m.get("peer_id", 0)
		if pid != 0 and pid != _my_peer_id:
			_rpc_receive_state.rpc_id(pid, leader_peer_id, members)
	is_leader = (_my_peer_id == leader_peer_id)
	group_updated.emit(true)

func _disband() -> void:
	if not multiplayer.has_multiplayer_peer():
		_clear_group()
		return
	for m in members:
		var pid: int = m.get("peer_id", 0)
		if pid != 0 and pid != _my_peer_id:
			_rpc_receive_disband.rpc_id(pid)
	_clear_group()

func _clear_group() -> void:
	in_group = false
	is_leader = false
	leader_peer_id = 0
	members = []
	pending_invite_from = 0
	_stats_dirty = false
	group_updated.emit(true)
