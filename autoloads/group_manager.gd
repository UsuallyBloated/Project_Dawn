extends Node

# membership_changed=true for join/leave/leader shifts; false for stat-only ticks
signal group_updated(membership_changed: bool)
signal invite_received(from_peer_id: int, from_name: String)

const MAX_SIZE := 6

var in_group := false
var is_leader := false
var leader_peer_id := 0
var members: Array = []
var pending_invite_from := 0

var _my_peer_id := 0
var _stats_dirty := false

func _ready() -> void:
	_my_peer_id = multiplayer.get_unique_id()
	PlayerStats.hp_changed.connect(func(_c, _m): _sync_stats())
	PlayerStats.mp_changed.connect(func(_c, _m): _sync_stats())
	PlayerStats.stamina_changed.connect(func(_c, _m): _sync_stats())

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
	if in_group and members.size() >= MAX_SIZE:
		return
	_rpc_receive_invite.rpc_id(target_peer_id, _my_peer_id, PlayerStats.player_name)

func accept_invite() -> void:
	if pending_invite_from == 0:
		return
	_rpc_receive_accept.rpc_id(pending_invite_from, _my_peer_id, _local_stats())
	pending_invite_from = 0

func leave_group() -> void:
	if not in_group:
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

func pass_leadership(new_leader_peer_id: int) -> void:
	if not is_leader:
		return
	leader_peer_id = new_leader_peer_id
	_broadcast_state()

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
func _rpc_receive_disband() -> void:
	_clear_group()

@rpc("any_peer", "reliable")
func _rpc_group_chat(sender_name: String, msg: String) -> void:
	if sender_name.length() > 64 or msg.length() > 256:
		return
	CombatLog.add_line("[Group] %s: %s" % [sender_name, msg], CombatLog.MsgType.GROUP_CHAT)

# â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
