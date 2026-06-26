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
# Track 11 — server-spawned player-owned pet landed in AOI. `id` is in
# the pet-id partition (>= 3_000_000_000) so the client can distinguish
# from enemy / bag / player ids alone. `owner` is the summoner's
# char_id (always in the player range, < ENEMY_ID_BASE).
signal world_pet_spawn(
	id: int,
	owner: int,
	pet_name: String,
	level: int,
	max_hp: float,
	hp: float,
	pos: Vector3,
	yaw: float)
# Track 13.2 — full inventory snapshot privately seeded on EnterWorld.
# Parallel arrays: locations[i] / slots[i] / item_paths[i] / counts[i]
# all describe the same entry. Empty arrays = empty inventory.
signal world_inventory_snapshot(
	locations: PackedStringArray,
	slots: PackedInt32Array,
	item_paths: PackedStringArray,
	counts: PackedInt32Array)
# Track 13.2 — single-slot mutation. `item_path == ""` means the slot
# is now empty; otherwise the slot now holds `(item_path, count)`.
signal world_inventory_delta(
	location: String,
	slot: int,
	item_path: String,
	count: int)
# Track 5 sub-task 2 — server-driven aggro replication. `target_id == 0`
# encodes "no target" (drop / leash); non-zero is the targeted entity's id.
signal world_entity_target(id: int, target_id: int)
# Inbound chat. `channel` is one of CHAT_CHANNEL_*. Routing to a chat
# line happens in `_on_chat_message`.
signal world_chat_message(speaker: String, channel: int, text: String, lang: String)
# Reply to a broadcast_inspect_player request. `slot_keys` and
# `item_paths` are parallel arrays — slot_keys[i] is the EquipSlot
# discriminant (0–8) holding item_paths[i]. Empty arrays = target
# offline or unknown. The inspect window subscribes to render.
signal world_inspect_result(
	target_char_id: int,
	target_name: String,
	slot_keys: PackedInt32Array,
	item_paths: PackedStringArray,
)

# Wire-side ChatChannel discriminants. Must mirror the int returned by
# `gdext_net::chat_channel_to_int`. Outbound `broadcast_chat` takes one
# of these.
const CHAT_CHANNEL_SAY     := 0
const CHAT_CHANNEL_OOC     := 1
const CHAT_CHANNEL_GROUP   := 2
const CHAT_CHANNEL_TELL    := 3
const CHAT_CHANNEL_GUILD   := 4
const CHAT_CHANNEL_RAID    := 5
const CHAT_CHANNEL_AUCTION := 6
const CHAT_CHANNEL_SYSTEM  := 7
const CHAT_CHANNEL_SHOUT   := 8
# Track 5 sub-task 4 — server-spawned loot bag landed in the AOI.
# `item_paths` and `item_counts` are parallel arrays of the bag's
# current contents. Re-fires (with shrinking arrays) every time the
# server processes a successful LootItem / LootAll — clients update
# the bag's view by reassignment, not diff application.
signal world_loot_bag_spawn(
	bag_id: int,
	pos: Vector3,
	item_paths: PackedStringArray,
	item_counts: PackedInt32Array,
	coin_platinum: int,
	coin_gold: int,
	coin_silver: int,
	coin_copper: int,
	creature_name: String)
# PD_W0019 — corpse / resurrection Slice 1. A player corpse spawned in AOI (on
# death or boot-loaded). RemoteCorpseManager renders a body + nameplate;
# `owner_id` is the dead player's char_id.
signal world_corpse_spawn(corpse_id: int, owner_id: int, owner_name: String, pos: Vector3)
# PD_W0020 — corpse / resurrection Slice 2. The owner-only contents of a corpse
# (items + coins), so RemoteCorpseManager can drive a loot window. Re-sent in full
# after each partial loot.
signal world_corpse_contents(
	corpse_id: int,
	item_paths: PackedStringArray,
	item_counts: PackedInt32Array,
	coin_platinum: int,
	coin_gold: int,
	coin_silver: int,
	coin_copper: int)
# PD_W0022 — corpse / resurrection Slice 3. A Cleric/Paladin offered to resurrect
# the local player's corpse; the HUD shows an accept/decline prompt.
signal world_resurrect_offer(corpse_id: int, caster_name: String, xp_percent: int)
# PD_W0022 — server-forced reposition (a resurrection summon). Net snaps the local
# player to `pos` and re-emits for any other listener.
signal world_teleport(pos: Vector3)
# Track 5 sub-task 4 — private confirmation that the local player's
# LootItem / LootAll intent landed. Carries one stack the looter just
# claimed; the GDScript handler loads `item_path` → ItemData and adds
# to Inventory.
signal world_loot_granted(item_path: String, count: int)
# PD_W0014 — a loot attempt was refused (not the owning group, or not
# your Round Robin turn). RemoteLootBagManager logs the reason.
signal world_loot_rejected(reason: String)
# PD_W0014 — a private one-line group notice (e.g. a group-mate toggled
# /autosplit). GroupManager logs the text to the combat log.
signal world_group_notice(text: String)
# PD_W0018 — private xp update (kill / quest credit, or a death loss with a
# negative amount). The server owns xp + leveling now; the receive-side handler
# mirrors the authoritative `current` / `to_next` onto PlayerStats and does not
# level up locally (a level change arrives via the inherited `level_up` signal).
signal world_xp_gained(amount: int, current: int, to_next: int)

# Track 14 follow-up — server-authoritative coin balance update.
# Vendor BuyItem / SellItem (and any future coin-mutating flow)
# fans this. Carries the four-tier wallet; PlayerStats overwrites its
# stacks and emits its own `coins_changed` so existing UI stays wired.
signal world_coins_update(platinum: int, gold: int, silver: int, copper: int)
# PD_W0015 — Banker, slice 1. The player's bank balance (four tiers) and a
# rejected bank action. BankerManager caches the snapshot; BankWindow logs the reject.
signal world_bank_snapshot(platinum: int, gold: int, silver: int, copper: int)
signal world_bank_rejected(reason: String)
# PD_W0016 — Banker, slice 2. Full contents of one item vault (shared = false is
# the 10-slot personal vault, true is the 2-slot account-shared vault). Parallel
# arrays of (slot, item_path, count) for filled slots. BankerManager caches it.
signal world_bank_item_snapshot(shared: bool, slots: PackedInt32Array, item_paths: PackedStringArray, counts: PackedInt32Array)
# PD_W0017 — Camp, slice B. The server's /camp countdown state: active = true with
# remaining_secs on start, active = false (0) on cancel. The HUD drives a countdown
# label from this. Completion logs the player out (a disconnect), not an update here.
signal world_camp_update(remaining_secs: int, active: bool)
# Track 6 sub-task 5 — group state from the server.
# group_invited: someone is asking us to join their group.
# group_roster: the group we belong to has a new membership snapshot
# (empty member arrays = the group dissolved or we were kicked).
signal world_group_invited(from_id: int, from_name: String)
signal world_group_roster(group_id: int, leader_id: int, member_ids: PackedInt64Array, member_names: PackedStringArray, loot_mode: int)
# damage_shield_trigger: a player's Thorns / Spellshield reflected
# damage back at an attacker. defender = the player whose shield fired.
signal world_damage_shield_trigger(defender: int, attacker: int, amount: int, shield_name: String)

# Track 18.1 — passive skill leveling moved to the server. Skill
# tracker autoloads (WeaponSkills, ArmorSkills, CastingSkills) listen
# for these signals to refresh their `_skills` caches and emit
# `skill_advanced` so the character window repaints. `kind` is 0
# (weapon), 1 (armor), or 2 (casting), matching protocol::world::SkillKind.
signal world_skill_progress_update(kind: int, key: String, new_score: int)
signal world_skill_progress_snapshot(
	weapon_keys: PackedStringArray, weapon_scores: PackedInt32Array,
	armor_keys: PackedStringArray, armor_scores: PackedInt32Array,
	casting_keys: PackedStringArray, casting_scores: PackedInt32Array)

var _state: State = State.DISCONNECTED
var _session_token_bytes := PackedByteArray()
var _char_id: int = -1
var _client_version := ""
var _player_id: int = -1
# Set when the server kicks us with a reason (e.g. duplicate login). The kick is
# immediately followed by a transport drop, and our own disconnect_now() re-enters
# _on_transport_disconnected; without this, that generic transport reason would
# clobber the meaningful kick reason. Cleared when a fresh transport connects.
var _kick_reason: String = ""
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
	pet_spawn.connect(_on_pet_spawn)
	inventory_snapshot.connect(_on_inventory_snapshot)
	inventory_delta.connect(_on_inventory_delta)
	loot_bag_spawn.connect(_on_loot_bag_spawn)
	corpse_spawn.connect(_on_corpse_spawn)
	corpse_contents.connect(_on_corpse_contents)
	resurrect_offer.connect(_on_resurrect_offer)
	teleport.connect(_on_teleport)
	loot_granted.connect(_on_loot_granted)
	loot_rejected.connect(_on_loot_rejected)
	group_notice.connect(_on_group_notice)
	xp_gained.connect(_on_xp_gained)
	level_up.connect(_on_level_up)
	coins_update.connect(_on_coins_update)
	bank_snapshot.connect(_on_bank_snapshot)
	bank_rejected.connect(_on_bank_rejected)
	bank_item_snapshot.connect(_on_bank_item_snapshot)
	camp_update.connect(_on_camp_update)
	group_invited.connect(_on_group_invited)
	group_roster.connect(_on_group_roster)
	damage_shield_trigger.connect(_on_damage_shield_trigger)
	skill_progress_update.connect(_on_skill_progress_update)
	skill_progress_snapshot.connect(_on_skill_progress_snapshot)
	chat_message.connect(_on_chat_message)
	inspect_result.connect(_on_inspect_result)

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

# PD_W0017 — Camp, slice B. Begin / abort a voluntary /camp. The server gates on
# sit state and runs the countdown; the HUD mirrors it via world_camp_update.
func broadcast_camp() -> void:
	if _state != State.CONNECTED_APP:
		return
	send_camp()

func broadcast_cancel_camp() -> void:
	if _state != State.CONNECTED_APP:
		return
	send_cancel_camp()

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

# Track 22.H — peer target broadcast. Combat.set_target calls this
# whenever the local player retargets so the server can fan an
# EntityTarget to in-world peers. target_id == 0 (or negative) =
# no target (encoded as None on the wire).
func broadcast_set_target(target_id: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_set_target(target_id)

# Personal chat channels (Say / Shout / Ooc / Tell). `target_name` is the
# `/tell` recipient; pass "" for the other channels. Server fans
# `ChatMessage` to recipients (AOI peers for Say, every in-world peer for
# Shout/Ooc, the single target for Tell). The sender's own echo is added
# locally by `hud.gd`, not via the server.
func broadcast_chat(channel: int, text: String, target_name: String = "") -> void:
	if _state != State.CONNECTED_APP:
		return
	send_chat(channel, text, target_name)

# Request the equipped-items snapshot for another player by char_id.
# Server fans the reply privately as `world_inspect_result`.
func broadcast_inspect_player(target_char_id: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_inspect_player(target_char_id)

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

# PD_W0018 — report a completed quest's xp reward to the server (quests are
# tracked client-side; the server applies the xp authoritatively and replies
# with XpGained / LevelUp). Returns whether it was sent.
func grant_quest_xp(amount: int) -> bool:
	if _state != State.CONNECTED_APP:
		return false
	return send_grant_quest_xp(amount)

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

# Local mirror of the server's per-connection pvp_override_on. The
# client tracks its own state so cast / attack code can pre-reject
# offensive actions vs. peers / peer-pets before sending an intent the
# server would just refuse. Peer state remains server-side; this only
# resolves the "I forgot I'm /pvp off" case.
var _local_pvp_on: bool = false

# Emitted whenever the local /pvp flag flips so UI that derives
# allegiance / threat colors from it (RemotePet tint, future
# RemotePlayer nameplate) can refresh without polling.
signal pvp_toggled(on: bool)

func is_local_pvp_on() -> bool:
	return _local_pvp_on

# Track 6 sub-task 3: dev /pvp toggle. Server caches the flag on the
# sender's PerConnection; combat::can_attack requires both attacker and
# target to have the flag on.
func broadcast_pvp_toggle(on: bool) -> void:
	if _state != State.CONNECTED_APP:
		return
	if _local_pvp_on != on:
		_local_pvp_on = on
		pvp_toggled.emit(on)
	send_pvp_toggle(on)

# PD_W0014: per-player /autosplit toggle. Server caches the flag on the
# sender's PerConnection; coin the player loots splits to the nearby group
# (on, the default) or stays with them (off). See the loot-rights design
# doc. No local mirror needed — the chat command echoes the new state.
func broadcast_autosplit(on: bool) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_autosplit(on)

# PD_W0014: leader sets the group's loot mode (0 = Round Robin,
# 1 = Free-for-all). Server validates leadership and re-fans the roster
# with the new mode, which arrives back via world_group_roster.
func broadcast_set_group_loot_mode(mode: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_set_group_loot_mode(mode)

# PD_W0014: current leader hands leadership to new_leader (a member's
# char_id). The server validates and re-fans the roster, which updates
# every member's leader_peer_id / is_leader. Fixes the launcher-mode gap
# where pass-leadership was a local-only change the next roster undid.
func broadcast_pass_leadership(new_leader: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_pass_leadership(new_leader)

# Track 6 sub-task 3b: spell cast intent. Server looks up spell_name in
# spells.toml, validates mana / target / range, applies authoritative
# damage or heal, and fans HealthUpdate / ManaUpdate. target_id = 0
# encodes "no target" (SELF / NONE spells); ENEMY / AOE spells supply
# the chosen target's char_id (for player targets) or enemy id.
func broadcast_cast_spell(spell_name: String, target_id: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_cast_spell(spell_name, target_id)

# Track 12 Piece A — direct a server-owned pet. `command` is one of
# the values in NetProtocol.PetCommand (ATTACK / BACK / etc.).
# `target_id` is required for ATTACK (the enemy id); pass 0 for
# commands that don't carry a target.
func broadcast_pet_command(command: int, target_id: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_pet_command(command, target_id)

# Track 13.2 — request a slot-to-slot inventory move. The wire
# format uses string `location`s (one of "base", "bag_<i>", "equip")
# to stay future-proof. Server validates and fans InventoryDelta per
# affected slot.
func broadcast_move_item(src_location: String, src_slot: int, dst_location: String, dst_slot: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_move_item(src_location, src_slot, dst_location, dst_slot)

# Track 13.2.b — split `count` items off the src stack into dst. Dst
# must be empty or hold the same item_path; the server rejects
# different-item dst (use broadcast_move_item for swaps).
func broadcast_split_stack(src_location: String, src_slot: int, dst_location: String, dst_slot: int, count: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_split_stack(src_location, src_slot, dst_location, dst_slot, count)

# Track 13.2.b — drop `count` of the entry at (location, slot) at the
# player's feet as a server-owned LootBag. `count <= 0` drops the
# whole stack.
func broadcast_drop_item(location: String, slot: int, count: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_drop_item(location, slot, count)

# Track 13.3 — equip the item at (src_location, src_slot) into the
# given paperdoll slot. equip_slot indexes match
# NetProtocol.EquipSlot (WEAPON=0, OFFHAND=1, HEAD=2, ...).
func broadcast_equip_item(src_location: String, src_slot: int, equip_slot: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_equip_item(src_location, src_slot, equip_slot)

# Track 15.1 — destroy `count` of the entry at (location, slot)
# outright. Unlike broadcast_drop_item, no loot bag is spawned —
# the item is gone for good. `count <= 0` destroys the whole stack.
func broadcast_destroy_item(location: String, slot: int, count: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_destroy_item(location, slot, count)

# Track 15.2 — consume one unit of the entry at (location, slot).
# Server validates the item is a consumable (heal-on-use / food /
# drink), decrements one, fans InventoryDelta, applies the effect,
# fans HealthUpdate / ManaUpdate / BuffSnapshot.
func broadcast_use_consumable(location: String, slot: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_use_consumable(location, slot)

# Track 15.2 follow-up — GM command line (e.g. "give Crude Ale 3").
# Server parses + executes. Until accounts.is_gm exists, any in-world
# client can issue this; gate accordingly when the auth side lands.
func broadcast_gm_command(line: String) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_gm_command(line)

# Track 13.3 — unequip paperdoll slot into (dst_location, dst_slot).
# Server swaps on dst-occupied.
func broadcast_unequip_item(equip_slot: int, dst_location: String, dst_slot: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_unequip_item(equip_slot, dst_location, dst_slot)

# Track 14 follow-up — vendor purchase. Server validates item exists,
# charges vendor_price * qty from conn.coins, grants via
# add_item_locating, and fans CoinsUpdate + InventoryDelta. vendor_id
# is informational today (no server NPCs yet).
func broadcast_buy_item(vendor_id: int, item_name: String, qty: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_buy_item(vendor_id, item_name, qty)

# Track 14 follow-up — vendor sell. `location` is "base" or "bag_<i>"
# (equip slots reject server-side). Server credits coins = (vendor_price
# / 2) * qty and fans CoinsUpdate + InventoryDelta.
func broadcast_sell_item(location: String, slot: int, qty: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_sell_item(location, slot, qty)

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

# Dev intent — credit exact per-tier coin stacks (Test Panel money buttons).
# Server-gated on PD_DEV_CMDS; the wallet comes back via CoinsUpdate, so no
# optimistic local fill (a silently-ignored grant should LOOK ignored).
func broadcast_give_coins(platinum: int, gold: int, silver: int, copper: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_give_coins(platinum, gold, silver, copper)

# PD_W0015 — Banker, slice 1. Deposit/withdraw move per-tier coin amounts
# between the carried wallet and the zero-weight bank; exchange converts tiers
# on the wallet (tiers 0=copper..3=platinum). Server-authoritative: it fans
# CoinsUpdate (wallet) + BankSnapshot (bank), or BankRejected on failure. No
# optimistic local mutation — wait for the fans.
func broadcast_bank_deposit(platinum: int, gold: int, silver: int, copper: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_bank_deposit(platinum, gold, silver, copper)

func broadcast_bank_withdraw(platinum: int, gold: int, silver: int, copper: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_bank_withdraw(platinum, gold, silver, copper)

func broadcast_bank_exchange(from_tier: int, to_tier: int, qty: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_bank_exchange(from_tier, to_tier, qty)

# PD_W0016 — Banker, slice 2. Quick-transfer whole item stacks between inventory
# and a vault. shared = false is the personal vault, true is the account-shared
# vault. Server-authoritative: it fans an InventoryDelta + a BankItemSnapshot.
func broadcast_bank_store_item(src_location: String, src_slot: int, shared: bool) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_bank_store_item(src_location, src_slot, shared)

func broadcast_bank_withdraw_item(shared: bool, vault_slot: int) -> void:
	if _state != State.CONNECTED_APP:
		return
	send_bank_withdraw_item(shared, vault_slot)

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
	_kick_reason = ""
	# Now safe to send the app-layer Connect.
	if not send_app_connect(_session_token_bytes, _char_id, _client_version):
		push_warning("Net: send_app_connect returned false")

func _on_transport_disconnected(reason: String) -> void:
	_stop_heartbeat()
	_state = State.DISCONNECTED
	_player_id = -1
	# If the server already told us *why* via a Kick (e.g. duplicate login), keep
	# that reason. _on_kicked already surfaced it, then called disconnect_now(),
	# which re-enters here with a generic transport reason that would clobber it.
	if _kick_reason != "":
		return
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
	_kick_reason = reason
	_stop_heartbeat()
	_state = State.DISCONNECTED
	_player_id = -1
	# Surface the server's reason verbatim (e.g. "You already have a character in
	# this world."). disconnect_now() below re-enters _on_transport_disconnected,
	# which defers to _kick_reason so this message isn't overwritten.
	app_disconnected.emit(reason)
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

func _on_pet_spawn(
		id: int,
		owner: int,
		pet_name: String,
		level: int,
		max_hp: float,
		hp: float,
		pos: Vector3,
		yaw: float) -> void:
	world_pet_spawn.emit(id, owner, pet_name, level, max_hp, hp, pos, yaw)

func _on_inventory_snapshot(
		locations: PackedStringArray,
		slots: PackedInt32Array,
		item_paths: PackedStringArray,
		counts: PackedInt32Array) -> void:
	world_inventory_snapshot.emit(locations, slots, item_paths, counts)

func _on_inventory_delta(
		location: String,
		slot: int,
		item_path: String,
		count: int) -> void:
	world_inventory_delta.emit(location, slot, item_path, count)

func _on_entity_target(id: int, target_id: int) -> void:
	world_entity_target.emit(id, target_id)

func _on_chat_message(speaker: String, channel: int, text: String, lang: String) -> void:
	world_chat_message.emit(speaker, channel, text, lang)

func _on_inspect_result(
	target_char_id: int,
	target_name: String,
	slot_keys: PackedInt32Array,
	item_paths: PackedStringArray,
) -> void:
	world_inspect_result.emit(target_char_id, target_name, slot_keys, item_paths)

func _on_loot_bag_spawn(
		bag_id: int,
		pos: Vector3,
		item_paths: PackedStringArray,
		item_counts: PackedInt32Array,
		coin_platinum: int,
		coin_gold: int,
		coin_silver: int,
		coin_copper: int,
		creature_name: String) -> void:
	world_loot_bag_spawn.emit(bag_id, pos, item_paths, item_counts, coin_platinum, coin_gold, coin_silver, coin_copper, creature_name)

func _on_corpse_spawn(corpse_id: int, owner_id: int, owner_name: String, pos: Vector3) -> void:
	world_corpse_spawn.emit(corpse_id, owner_id, owner_name, pos)

func _on_corpse_contents(
		corpse_id: int,
		item_paths: PackedStringArray,
		item_counts: PackedInt32Array,
		coin_platinum: int,
		coin_gold: int,
		coin_silver: int,
		coin_copper: int) -> void:
	world_corpse_contents.emit(corpse_id, item_paths, item_counts, coin_platinum, coin_gold, coin_silver, coin_copper)

func _on_resurrect_offer(corpse_id: int, caster_name: String, xp_percent: int) -> void:
	world_resurrect_offer.emit(corpse_id, caster_name, xp_percent)

# PD_W0022 — the server summons us to our corpse on a resurrection. Snap the local
# player to pos (the server already moved us authoritatively) and re-emit.
func _on_teleport(pos: Vector3) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		player.global_position = pos
		if "velocity" in player:
			player.velocity = Vector3.ZERO
	world_teleport.emit(pos)

func _on_loot_granted(item_path: String, count: int) -> void:
	world_loot_granted.emit(item_path, count)

func _on_loot_rejected(reason: String) -> void:
	world_loot_rejected.emit(reason)

func _on_group_notice(text: String) -> void:
	world_group_notice.emit(text)

func _on_xp_gained(amount: int, current: int, to_next: int) -> void:
	world_xp_gained.emit(amount, current, to_next)
	# PD_W0018 — the server owns xp/leveling. Mirror the authoritative totals
	# onto the bar (no local level-up); a level change arrives separately via
	# the level_up signal. A negative amount is a death penalty.
	PlayerStats.apply_remote_xp(amount, current, to_next)
	if amount < 0:
		CombatLog.add_line("You lost %d experience points." % -amount, CombatLog.MsgType.DAMAGE_IN)

# PD_W0018 — server-authoritative level change (up on xp gain, DOWN on a death
# penalty). Mirror it onto PlayerStats, which applies the intrinsic stat deltas.
func _on_level_up(new_level: int, xp_val: int, xp_to_next_val: int) -> void:
	PlayerStats.apply_server_level(new_level, xp_val, xp_to_next_val)

func _on_coins_update(platinum: int, gold: int, silver: int, copper: int) -> void:
	# Track 14 follow-up — server is authoritative. Push the wallet
	# through PlayerStats.apply_remote_coins so existing UI
	# subscribers (HUD coin label, vendor window footer) re-render
	# via the existing coins_changed signal.
	world_coins_update.emit(platinum, gold, silver, copper)
	PlayerStats.apply_remote_coins(platinum, gold, silver, copper)

# PD_W0015 — Banker, slice 1. The bank balance is display-only on the client
# (the wallet is the one PlayerStats tracks), so just relay the snapshot for
# the BankWindow; no PlayerStats mutation here.
func _on_bank_snapshot(platinum: int, gold: int, silver: int, copper: int) -> void:
	world_bank_snapshot.emit(platinum, gold, silver, copper)

func _on_bank_rejected(reason: String) -> void:
	world_bank_rejected.emit(reason)

func _on_bank_item_snapshot(shared: bool, slots: PackedInt32Array, item_paths: PackedStringArray, counts: PackedInt32Array) -> void:
	world_bank_item_snapshot.emit(shared, slots, item_paths, counts)

# PD_W0017 — Camp, slice B. Relay the server's /camp countdown state to the HUD.
# Display-only; the server is authoritative on the timer and the logout.
func _on_camp_update(remaining_secs: int, active: bool) -> void:
	world_camp_update.emit(remaining_secs, active)

func _on_group_invited(from_id: int, from_name: String) -> void:
	world_group_invited.emit(from_id, from_name)

func _on_group_roster(group_id: int, leader_id: int, member_ids: PackedInt64Array, member_names: PackedStringArray, loot_mode: int) -> void:
	world_group_roster.emit(group_id, leader_id, member_ids, member_names, loot_mode)

func _on_damage_shield_trigger(defender: int, attacker: int, amount: int, shield_name: String) -> void:
	world_damage_shield_trigger.emit(defender, attacker, amount, shield_name)

func _on_skill_progress_update(kind: int, key: String, new_score: int) -> void:
	world_skill_progress_update.emit(kind, key, new_score)

func _on_skill_progress_snapshot(
		weapon_keys: PackedStringArray, weapon_scores: PackedInt32Array,
		armor_keys: PackedStringArray, armor_scores: PackedInt32Array,
		casting_keys: PackedStringArray, casting_scores: PackedInt32Array) -> void:
	world_skill_progress_snapshot.emit(
		weapon_keys, weapon_scores,
		armor_keys, armor_scores,
		casting_keys, casting_scores)

func _on_heartbeat_tick() -> void:
	if _state == State.CONNECTED_APP:
		send_heartbeat()

func _stop_heartbeat() -> void:
	if _heartbeat_timer != null and not _heartbeat_timer.is_stopped():
		_heartbeat_timer.stop()
