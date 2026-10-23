extends Node
# Alignment and faction standings, the server's since the factions build
# (docs/design/factions_and_alignment.md, 2026-10-23). Online this autoload
# FOLLOWS the server: the score arrives as AlignmentUpdate and every moved
# standing as FactionUpdate; nothing here moves either by itself. The tiers
# and the class starts mirror the server's alignment.rs (kept in lockstep by
# hand); the offline Test Room still seeds from the class start.

signal alignment_changed(tier: String, score: int)
# One faction standing as the server holds it: the number the faction's NPCs
# see and its con level (0 Scowls to 8 Ally).
signal faction_changed(faction_id: String, faction_name: String, standing: float, level: int)

const LEVEL_NAMES := ["Scowls", "Threatening", "Dubious", "Apprehensive",
	"Indifferent", "Amiable", "Kindly", "Warmly", "Ally"]

var alignment_score: int = 0
var alignment_tier: String = "Neutral"
# The server's exact score; the tier reads it, so a boundary falls where the
# server's does and not where a rounded integer would.
var exact_score: float = 0.0
# faction_id to {"name": String, "standing": float, "level": int}, only the
# factions the server has told us about (the rest sit at Indifferent).
var factions: Dictionary = {}
# True once the server has told this character its score: from then on a
# class re-apply (a level change, the Test Panel) must not reseed it.
var _server_held: bool = false

func _ready() -> void:
	# Net loads after this autoload; connect once every autoload exists.
	_connect_net.call_deferred()

func _connect_net() -> void:
	Net.world_alignment_update.connect(_on_server_alignment)
	Net.world_faction_update.connect(_on_server_faction)
	Net.app_connected.connect(_on_app_connected)

# Entering the world, possibly as a different character, which must not
# inherit the last one's standings or score; the server sends both right
# after this.
func _on_app_connected(_player_id: int) -> void:
	factions.clear()
	_server_held = false

# The class's starting score, from PlayerStats.apply_character: the offline
# seed, and online only until the server's own score has arrived.
func seed_class_start(score: float) -> void:
	if _server_held:
		return
	set_alignment(score)

func set_alignment(score: float) -> void:
	exact_score = clampf(score, -2000.0, 2000.0)
	alignment_score = roundi(exact_score)
	alignment_tier = _calc_tier()
	alignment_changed.emit(alignment_tier, alignment_score)

func modify_alignment(delta: float) -> void:
	exact_score = clampf(exact_score + delta, -2000.0, 2000.0)
	alignment_score = roundi(exact_score)
	var new_tier := _calc_tier()
	if new_tier != alignment_tier:
		alignment_tier = new_tier
		alignment_changed.emit(alignment_tier, alignment_score)

func _on_server_alignment(score: float) -> void:
	var old_tier := alignment_tier
	var first := not _server_held
	_server_held = true
	exact_score = clampf(score, -2000.0, 2000.0)
	alignment_score = roundi(exact_score)
	alignment_tier = _calc_tier()
	DebugLog.info("Alignment: server score %.4f (%s)" % [exact_score, alignment_tier])
	# The first word from the server always re-runs the kits (the class seed
	# may have guessed the tier wrong for a character that has moved).
	if first or alignment_tier != old_tier:
		alignment_changed.emit(alignment_tier, alignment_score)

func _on_server_faction(faction_id: String, faction_name: String, standing: float, level: int) -> void:
	factions[faction_id] = {"name": faction_name, "standing": standing, "level": level}
	DebugLog.info("Faction: %s %d (%s)" % [faction_name, roundi(standing), faction_level_name(level)])
	faction_changed.emit(faction_id, faction_name, standing, level)

func faction_level_name(level: int) -> String:
	return LEVEL_NAMES[clampi(level, 0, LEVEL_NAMES.size() - 1)]

func _calc_tier() -> String:
	if exact_score >= 1500.0:
		return "Exalted"
	elif exact_score >= 300.0:
		return "Good"
	elif exact_score >= -300.0:
		return "Neutral"
	elif exact_score >= -1500.0:
		return "Bad"
	else:
		return "Evil"

func get_effective_class() -> String:
	match PlayerStats.player_class:
		"Paladin":
			if alignment_tier == "Evil":
				return "Paladin_Fallen"
		"Shadow Knight":
			if alignment_tier == "Exalted":
				return "Shadow Knight_Redeemed"
	return PlayerStats.player_class

func save_state() -> Dictionary:
	return {"alignment_score": exact_score}

func load_state(d: Dictionary) -> void:
	set_alignment(float(d.get("alignment_score", 0)))
