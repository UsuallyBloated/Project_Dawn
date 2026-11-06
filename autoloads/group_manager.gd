extends Node

# The client's mirror of the server's group: roster, leader, loot mode and the
# members' resource bars. The server owns every membership change; the action
# methods here send intents through Net and the roster fan updates the mirror.

# membership_changed=true for join/leave/leader shifts; false for stat-only ticks
signal group_updated(membership_changed: bool)
signal invite_received(from_peer_id: int, from_name: String)

const MAX_SIZE := 6

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

var _stats_dirty := false

func _ready() -> void:
	PlayerStats.hp_changed.connect(func(_c, _m): _sync_stats())
	PlayerStats.mp_changed.connect(func(_c, _m): _sync_stats())
	PlayerStats.stamina_changed.connect(func(_c, _m): _sync_stats())
	# Track 6 sub-task 5 — server-driven group state.
	Net.world_group_invited.connect(_on_world_group_invited)
	Net.world_group_roster.connect(_on_world_group_roster)
	# Group-mate bars. The server already fans HealthUpdate / ManaUpdate /
	# StaminaUpdate to every in-world client, owner included and with no
	# range culling, so a member's resources are already on this machine —
	# nothing here needs a new wire message. Its throttle is what makes the
	# bars usable for a healer: a fan-out fires immediately when a value
	# swings more than 5% of max, and otherwise on a slow clock, so a big
	# hit lands at once while idle regen just ticks.
	Net.world_health_update.connect(_on_peer_health_update)
	Net.world_mana_update.connect(_on_peer_mana_update)
	Net.world_stamina_update.connect(_on_peer_stamina_update)
	# PD_W0014 — group-mate toggled /autosplit (or future group notices).
	# Surface the server's one-line text in the combat log.
	Net.world_group_notice.connect(_on_world_group_notice)
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
	# Refresh our own row from local PlayerStats (instant, no round trip) and
	# leave every other member to the server fan-out.
	_update_member_entry(_local_stats())
	group_updated.emit(false)

# ── Local actions ───────────────────────────────────────────────────

# Track 6 sub-task 5 — chat / UI entry point for "/invite <name>". The
# server looks up the target by name in its connections map.
func invite_player_by_name(target_name: String) -> void:
	Net.broadcast_group_invite(target_name)

func accept_invite() -> void:
	if pending_invite_from == 0:
		return
	Net.broadcast_group_accept_invite(pending_invite_from)
	pending_invite_from = 0

func leave_group() -> void:
	if not in_group:
		return
	Net.broadcast_group_leave()
	# Server will fan an empty roster back; _on_world_group_roster
	# clears local state. Optimistically clear here too so the UI
	# updates without waiting for the round-trip.
	_clear_group()

# Track 6 sub-task 5 — leader-only kick by name.
func kick_member_by_name(target_name: String) -> void:
	Net.broadcast_group_kick(target_name)

# Track 6 sub-task 5 — Net signal handlers. Server is authoritative
# on group membership; these handlers update the
# local mirror so the rest of the GroupManager API (in_group,
# members, is_leader, etc.) stays accurate without changing the
# downstream consumers' code.
func _on_world_group_invited(from_id: int, from_name: String) -> void:
	pending_invite_from = from_id
	invite_received.emit(from_id, from_name)

# PD_W0014 — a group-mate's server-side notice (currently /autosplit
# toggles). The toggler echoes their own change locally (hud.gd), so this
# only ever fires for the *other* members; just surface the text.
func _on_world_group_notice(text: String) -> void:
	CombatLog.add_line(text, CombatLog.MsgType.INFO)

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
	# Server validates (current leader to member) and re-fans the roster,
	# which updates leader_peer_id / is_leader for everyone. No optimistic
	# local change: the next server roster would snap it back.
	Net.broadcast_pass_leadership(new_leader_peer_id)

# ─── Server-driven group-mate resources ──────────────────────────────
# These three signals carry every entity's resources, not just group-mates:
# enemies and pets ride them too (RemoteEnemyManager / RemotePetManager
# listen to the same ones). `_apply_peer_stat` returns without emitting
# when the id is not in `members`, so the non-group traffic costs one short
# loop and nothing else.

func _on_peer_health_update(id: int, hp: float, max_hp: float) -> void:
	_apply_peer_stat(id, {"hp": hp, "max_hp": max_hp})

func _on_peer_mana_update(id: int, mp: float, max_mp: float) -> void:
	_apply_peer_stat(id, {"mp": mp, "max_mp": max_mp})

func _on_peer_stamina_update(id: int, stamina: float, maximum: float) -> void:
	_apply_peer_stat(id, {"sta": stamina, "max_sta": maximum})

# Merge a partial resource update into the matching member row. Partial by
# design: each wire message carries one resource, so merging only the keys
# present leaves the other two intact.
func _apply_peer_stat(id: int, fields: Dictionary) -> void:
	if not in_group:
		return
	for i in members.size():
		if members[i].get("peer_id") == id:
			members[i].merge(fields, true)
			group_updated.emit(false)
			return

# ── Helpers ─────────────────────────────────────────────────────────

# True when `peer_id` (a server char_id) is a current member of the group. Used by
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
	# The roster is keyed on server char_ids, so our own row is the one under
	# Net.get_player_id(). (Godot's multiplayer unique id is 1 on every client;
	# using it once put a non-leader's own HP under the leader's name.)
	var pid: int = Net.get_player_id()
	return {
		"peer_id": pid,
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

func _clear_group() -> void:
	in_group = false
	is_leader = false
	leader_peer_id = 0
	members = []
	pending_invite_from = 0
	_stats_dirty = false
	group_updated.emit(true)
