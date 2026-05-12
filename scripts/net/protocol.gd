class_name NetProtocol
extends RefCounted

# Hand-mirror of the Rust types in Projects/server/crates/protocol/.
# Auth uses JSON over WebSocket; helpers below build/parse those messages.
# World types are bincode over UDP — only tags and enums are mirrored here;
# bincode ser/deser ships with the future net adapter (GDExtension shim).

const CLIENT_VERSION := "0.1.0"

# ─── Auth: message type tags ────────────────────────────────────────

const AUTH_REGISTER             := "Register"
const AUTH_LOGIN                := "Login"
const AUTH_CHAR_LIST            := "CharList"
const AUTH_CHAR_CREATE          := "CharCreate"
const AUTH_CHAR_DELETE          := "CharDelete"
const AUTH_LOGOUT               := "Logout"
const AUTH_REQUEST_WORLD_TOKEN  := "RequestWorldToken"

const AUTH_REGISTER_OK          := "RegisterOk"
const AUTH_LOGIN_OK             := "LoginOk"
const AUTH_CHAR_CREATED         := "CharCreated"
const AUTH_CHAR_DELETED         := "CharDeleted"
const AUTH_LOGOUT_OK            := "LogoutOk"
const AUTH_WORLD_CONNECT_TOKEN  := "WorldConnectToken"
const AUTH_ERROR                := "Error"

# ─── Auth: ErrorCode (snake_case wire form) ─────────────────────────

const ERR_NAME_TAKEN       := "name_taken"
const ERR_AUTH_FAILED      := "auth_failed"
const ERR_VERSION_MISMATCH := "version_mismatch"
const ERR_SESSION_EXPIRED  := "session_expired"
const ERR_BANNED           := "banned"
const ERR_INVALID_INPUT    := "invalid_input"
const ERR_NOT_FOUND        := "not_found"
const ERR_INTERNAL         := "internal"

# ─── Auth: Client → Server builders ─────────────────────────────────

static func make_register(username: String, password: String, email: String = "") -> Dictionary:
	var d := {"type": AUTH_REGISTER, "username": username, "password": password}
	if email != "":
		d["email"] = email
	return d

static func make_login(username: String, password: String, client_version: String = CLIENT_VERSION) -> Dictionary:
	return {
		"type": AUTH_LOGIN,
		"username": username,
		"password": password,
		"client_version": client_version,
	}

static func make_char_list(session_token: String) -> Dictionary:
	return {"type": AUTH_CHAR_LIST, "session_token": session_token}

static func make_char_create(session_token: String, name: String, race: String, char_class: String) -> Dictionary:
	return {
		"type": AUTH_CHAR_CREATE,
		"session_token": session_token,
		"name": name,
		"race": race,
		"class": char_class,
	}

static func make_char_delete(session_token: String, char_id: int) -> Dictionary:
	return {"type": AUTH_CHAR_DELETE, "session_token": session_token, "char_id": char_id}

static func make_logout(session_token: String) -> Dictionary:
	return {"type": AUTH_LOGOUT, "session_token": session_token}

# Launcher → auth, after the user picks Play. Server validates the session and
# char ownership, then mints a renet ConnectToken and replies with
# WorldConnectToken. The launcher hands `token_bytes` to the game .exe via
# tempfile (NOT CLI arg — args are visible in `ps`/Task Manager).
static func make_request_world_token(session_token: String, char_id: int) -> Dictionary:
	return {
		"type": AUTH_REQUEST_WORLD_TOKEN,
		"session_token": session_token,
		"char_id": char_id,
	}

# Decode WorldConnectToken.token_bytes from the JSON wire form (Vec<u8> on the
# Rust side serialises as an Array of integers, not a base64 string) into a
# PackedByteArray suitable for `NetClient.connect_to_server` or for writing
# to the launcher → game tempfile.
static func decode_world_token_bytes(arr: Variant) -> PackedByteArray:
	var pba := PackedByteArray()
	if typeof(arr) != TYPE_ARRAY:
		return pba
	pba.resize(arr.size())
	for i in arr.size():
		pba[i] = int(arr[i]) & 0xFF
	return pba

# ─── Auth: JSON wire helpers ────────────────────────────────────────

static func encode_auth(msg: Dictionary) -> String:
	return JSON.stringify(msg)

# Returns the parsed message Dictionary on success, or null on parse failure
# / non-dict payload. Caller branches on the "type" field.
static func decode_auth(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

# ─── World: enums ───────────────────────────────────────────────────

# DamageType is #[repr(u8)] on the Rust side; values must stay aligned.
enum DamageType {
	PHYSICAL = 0,
	FIRE = 1,
	ICE = 2,
	LIGHTNING = 3,
	ARCANE = 4,
	HOLY = 5,
	NATURE = 6,
	SPIRIT = 7,
	SHADOW = 8,
	POISON = 9,
}

enum ChatChannel { SAY, OOC, GROUP, TELL, GUILD, RAID, AUCTION, SYSTEM }
enum EquipSlot { WEAPON, OFFHAND, HEAD, CHEST, LEGS, FEET, HANDS, RING, NECK }
enum KickCode { SESSION_EXPIRED, RESTART, BANNED_NOW, DUPLICATE_LOGIN, UNKNOWN }
enum QuestStatus { ACTIVE, COMPLETED, FAILED }

# ─── World: SlotRef (tagged) ────────────────────────────────────────

const SLOT_BASE  := "BaseSlot"
const SLOT_BAG   := "BagSlot"
const SLOT_EQUIP := "EquipSlot"

static func slot_base(idx: int) -> Dictionary:
	return {"kind": SLOT_BASE, "idx": idx}

static func slot_bag(base: int, slot: int) -> Dictionary:
	return {"kind": SLOT_BAG, "base": base, "slot": slot}

static func slot_equip(equip_slot: int) -> Dictionary:
	return {"kind": SLOT_EQUIP, "slot": equip_slot}

# ─── World: Vec3 helpers ────────────────────────────────────────────

static func vec3(x: float, y: float, z: float) -> Dictionary:
	return {"x": x, "y": y, "z": z}

static func vec3_from_godot(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}

static func vec3_to_godot(d: Dictionary) -> Vector3:
	return Vector3(d.get("x", 0.0), d.get("y", 0.0), d.get("z", 0.0))

# ─── World: Client → Server message tags ────────────────────────────

const W_CONNECT             := "Connect"
const W_DISCONNECT          := "Disconnect"
const W_HEARTBEAT           := "Heartbeat"
const W_MOVE                := "Move"
const W_SET_TARGET          := "SetTarget"
const W_ATTACK              := "Attack"
const W_CAST_SPELL          := "CastSpell"
const W_USE_SKILL           := "UseSkill"
const W_CANCEL_CAST         := "CancelCast"
const W_MOVE_ITEM           := "MoveItem"
const W_EQUIP_ITEM          := "EquipItem"
const W_UNEQUIP_ITEM        := "UnequipItem"
const W_DROP_ITEM           := "DropItem"
const W_USE_CONSUMABLE      := "UseConsumable"
const W_STACK_ALL           := "StackAll"
const W_INTERACT            := "Interact"
const W_DIALOGUE_RESPONSE   := "DialogueResponse"
const W_BUY_ITEM            := "BuyItem"
const W_SELL_ITEM           := "SellItem"
const W_LOOT_ITEM           := "LootItem"
const W_LOOT_ALL            := "LootAll"
const W_ACCEPT_QUEST        := "AcceptQuest"
const W_ABANDON_QUEST       := "AbandonQuest"
const W_TURN_IN_QUEST       := "TurnInQuest"
const W_START_COMBINE       := "StartCombine"
const W_START_MINING        := "StartMining"
const W_START_SKINNING      := "StartSkinning"
const W_CHAT                := "Chat"
const W_SIT                 := "Sit"
const W_STAND               := "Stand"
const W_BIND_AT_LOCATION    := "BindAtCurrentLocation"
const W_GROUP_INVITE        := "GroupInvite"
const W_GROUP_ACCEPT_INVITE := "GroupAcceptInvite"
const W_GROUP_LEAVE         := "GroupLeave"
const W_GROUP_KICK          := "GroupKick"
const W_GM_COMMAND          := "GmCommand"

# Track 4: owning-client → server broadcast of current resources. The server
# fans out three separate SW_HEALTH_UPDATE / SW_MANA_UPDATE / SW_STAMINA_UPDATE
# messages to each other ready peer. Throttled client-side; reliable channel.
const W_RESOURCE_UPDATE     := "ResourceUpdate"

# Track 4 follow-up: client signals it has left the lobby (Enter World button
# pressed). Server gates EntitySpawn / Position fan-out on this so peers
# don't see ghost bodies while a player is still on the Enter World screen.
const W_ENTER_WORLD         := "EnterWorld"

# Track 4 sub-task 2: cast lifecycle broadcasts. Server relays as
# SW_CAST_START / SW_CAST_COMPLETE / SW_CAST_FAIL to in_world peers; the
# casting peer's target frame renders a cast bar for the duration.
const W_CAST_START_BROADCAST    := "CastStartBroadcast"
const W_CAST_COMPLETE_BROADCAST := "CastCompleteBroadcast"
const W_CAST_FAIL_BROADCAST     := "CastFailBroadcast"

# Track 4 sub-task 3: full buff list broadcast on every BuffManager
# state change. Server relays as ServerWorldMsg::BuffSnapshot (with the
# casting peer's char_id as target) to in_world peers.
const W_BUFF_SNAPSHOT_BROADCAST := "BuffSnapshotBroadcast"

# Track 4 sub-task 4: attacker broadcasts a combat outcome so peers can
# render floating damage / "MISS" / "EVADE" text over the target. Pure
# visualization — target HP isn't driven by these in Track 4.
const W_HIT_BROADCAST   := "HitBroadcast"
const W_MISS_BROADCAST  := "MissBroadcast"
const W_EVADE_BROADCAST := "EvadeBroadcast"

# Track 4 sub-task 5: dying client signals HP-zero. Server relays as
# SW_ENTITY_DIED to in_world peers. Respawn lands silently via the next
# ResourceUpdate (no Respawn variant by design).
const W_DEATH_BROADCAST := "DeathBroadcast"

# ─── World: Server → Client message tags ────────────────────────────

const SW_CONNECT_OK        := "ConnectOk"
const SW_KICK              := "Kick"
const SW_HEARTBEAT         := "Heartbeat"
const SW_ENTITY_DESPAWN    := "EntityDespawn"
const SW_ENTITY_SPAWN      := "EntitySpawn"
const SW_POSITION          := "Position"
const SW_HEALTH_UPDATE     := "HealthUpdate"
const SW_MANA_UPDATE       := "ManaUpdate"
const SW_STAMINA_UPDATE    := "StaminaUpdate"
const SW_COINS_UPDATE      := "CoinsUpdate"
const SW_XP_GAINED         := "XpGained"
const SW_LEVEL_UP          := "LevelUp"
const SW_ALIGNMENT_CHANGED := "AlignmentChanged"
const SW_HIT               := "Hit"
const SW_MISS              := "Miss"
const SW_EVADE             := "Evade"
const SW_ENTITY_DIED       := "EntityDied"
const SW_BUFF_APPLIED      := "BuffApplied"
const SW_BUFF_REMOVED      := "BuffRemoved"
const SW_HOT_TICK          := "HotTick"
const SW_DOT_TICK          := "DotTick"
const SW_CAST_START        := "CastStart"
const SW_CAST_COMPLETE     := "CastComplete"
const SW_CAST_FAIL         := "CastFail"
const SW_COOLDOWN          := "Cooldown"
const SW_TIME_OF_DAY       := "TimeOfDay"
const SW_CHAT_MESSAGE      := "ChatMessage"
const SW_ERROR             := "Error"
const SW_BROADCAST_MESSAGE := "BroadcastMessage"

# Track 5 sub-task 2: server-authoritative enemies. SW_ENEMY_SPAWN carries
# the mob identity + initial state when a server-spawned enemy enters the
# recipient's AOI; ongoing Position / HealthUpdate / EntityDied reuse the
# generic variants. SW_ENTITY_TARGET fires on enemy aggro switch and lets
# the client render a "what is the mob targeting" indicator.
const SW_ENEMY_SPAWN       := "EnemySpawn"
const SW_ENTITY_TARGET     := "EntityTarget"
