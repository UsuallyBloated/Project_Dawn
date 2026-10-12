extends Node

# Chat broker. Listens to gameplay signals from every system (Combat,
# Skills, Spells, BuffManager, etc.), converts them to user-facing chat
# lines, and emits `line_added`. ChatWindowManager subscribes per-window
# and renders the line where the user chose to see it.
#
# Public API preserved for existing callers (~30 files):
# - add_line(text, type)          → fan out to windows
# - add_damage_out / add_evade    → convenience helpers
# - show_chat_input()             → asks the manager to focus the input
# - is_chat_input_focused()       → manager state passthrough
# - chat_submitted (signal)       → emitted by the manager on submit
# - MsgType (enum)                → the canonical message taxonomy

signal line_added(text: String, type: int)
signal chat_submitted(text: String)
signal show_chat_input_requested()

enum MsgType { DAMAGE_OUT, DAMAGE_IN, HEAL, INFO, LEVEL_UP, LOOT, EVADE,
			   SAY, SHOUT, OOC, TELL_OUT, TELL_IN, GROUP_CHAT, CRIT,
			   PET_DAMAGE_OUT, PET_DAMAGE_IN }

var _last_hp: float = 0.0
# Sentinel: -1 means "haven't seen a level_changed yet". The first one
# is the initial apply_character seed (not a real level-up); skip it.
var _last_logged_level: int = -1

# Everyone who has sent this character a tell since it entered the world,
# most recent first. `/r` replies to the front of the list and TAB in the
# chat line walks it (EQ's reply targets). Session-only by design.
const TELL_SENDER_HISTORY := 10
const TELL_PREFIXES: Array[String] = ["/tell ", "/t "]
const REPLY_PREFIXES: Array[String] = ["/reply ", "/r "]
var _tell_senders: Array[String] = []

func _ready() -> void:
	_connect_signals()
	_last_hp = PlayerStats.hp
	Net.app_connected.connect(_on_app_connected)

# Entering the world, possibly as a different character, which must not
# inherit the last one's reply targets.
func _on_app_connected(_player_id: int) -> void:
	_tell_senders.clear()

func add_line(text: String, type: int = MsgType.INFO) -> void:
	line_added.emit(text, type)

func add_damage_out(target_name: String, amount: int, is_crit: bool = false) -> void:
	if is_crit:
		add_line("** You critically hit %s for %d damage! **" % [target_name, amount], MsgType.CRIT)
	else:
		add_line("You hit %s for %d damage." % [target_name, amount], MsgType.DAMAGE_OUT)

func add_evade(attacker_name: String) -> void:
	add_line("You evade %s's attack!" % attacker_name, MsgType.EVADE)

# ── Chat input delegation ────────────────────────────────────────────────────

func show_chat_input() -> void:
	show_chat_input_requested.emit()

func is_chat_input_focused() -> bool:
	return ChatWindowManager.is_chat_input_focused()

# ── Tell reply targets ───────────────────────────────────────────────────────

## The most recent player to send us a tell, or "" when nobody has.
func last_tell_sender() -> String:
	return _tell_senders[0] if not _tell_senders.is_empty() else ""

func _note_tell_sender(sender: String) -> void:
	if sender == "":
		return
	for i in range(_tell_senders.size()):
		if _tell_senders[i].to_lower() == sender.to_lower():
			_tell_senders.remove_at(i)
			break
	_tell_senders.push_front(sender)
	if _tell_senders.size() > TELL_SENDER_HISTORY:
		_tell_senders.resize(TELL_SENDER_HISTORY)

## What TAB turns the chat line into. An empty line (or a bare `/r`) becomes a
## tell to the most recent sender; a tell already being written moves to the
## next sender and keeps whatever message was typed. Anything else comes back
## unchanged, so TAB never eats a half-written /say, and never re-addresses a
## message written to someone outside the list.
func cycle_tell_text(text: String) -> String:
	if _tell_senders.is_empty():
		return text
	var trimmed := text.strip_edges(true, false)
	var lower := trimmed.to_lower()
	var bare := lower.strip_edges()
	if bare == "" or bare == "/r" or bare == "/reply":
		return "/tell %s " % _tell_senders[0]
	for prefix in REPLY_PREFIXES:
		if lower.begins_with(prefix):
			return "/tell %s %s" % [_tell_senders[0], trimmed.substr(prefix.length())]
	for prefix in TELL_PREFIXES:
		if not lower.begins_with(prefix):
			continue
		var rest := trimmed.substr(prefix.length())
		var space_idx := rest.find(" ")
		var current := rest if space_idx < 0 else rest.substr(0, space_idx)
		var message := "" if space_idx < 0 else rest.substr(space_idx + 1)
		var next_idx := -1
		for i in range(_tell_senders.size()):
			if _tell_senders[i].to_lower() == current.to_lower():
				next_idx = (i + 1) % _tell_senders.size()
				break
		if next_idx < 0:
			# A name that never sent us a tell. With a message already typed,
			# leave it: swapping the name would send those words to someone
			# they were not written for. A bare or half-typed name is safe.
			if message.strip_edges() != "":
				return text
			next_idx = 0
		return "/tell %s %s" % [_tell_senders[next_idx], message]
	return text

# ── Gameplay signal → chat line wiring ───────────────────────────────────────

func _connect_signals() -> void:
	Skills.skill_used.connect(func(sk):
		add_line("You use %s." % sk.skill_name, MsgType.INFO))
	Spells.spell_cast.connect(func(sp):
		add_line("You cast %s." % sp.spell_name, MsgType.INFO))
	Spells.spell_failed.connect(func(reason):
		add_line(reason, MsgType.DAMAGE_IN))
	PlayerStats.level_changed.connect(func(lvl):
		# Suppress the initial apply_character emit (level loaded from
		# save / server) — only log actual level-ups.
		if _last_logged_level < 0:
			_last_logged_level = lvl
			return
		if lvl > _last_logged_level:
			add_line("You have reached level %d!" % lvl, MsgType.LEVEL_UP)
		_last_logged_level = lvl)
	PlayerStats.hp_changed.connect(_on_player_hp_changed)
	# XP gain announce — text only, no number per playtest feedback.
	# Source distinguishes quest turn-ins from kill credit:
	#   - "quest" → "You received experience."
	#   - "kill"  → solo vs party based on GroupManager.in_group
	# Group state is read at the moment XP lands (server-side split
	# already happened); this is purely a presentation cue.
	PlayerStats.xp_gained.connect(func(amount: int, source: String):
		var line: String
		if source == "quest":
			line = "You gained %d quest experience!" % amount
		elif GroupManager.in_group:
			line = "You gained %d party experience." % amount
		else:
			line = "You gained %d experience!" % amount
		add_line(line, MsgType.INFO))
	# Corpse / resurrection Slice 1 — surface death in the log. The corpse
	# location line ("Your corpse rests where you fell.") is added by
	# RemoteCorpseManager when the CorpseSpawn for your own body arrives.
	PlayerDeath.player_died.connect(func(): add_line("You have died. Returning to bind point.", MsgType.DAMAGE_IN))
	Combat.target_changed.connect(func(enemy):
		if enemy != null and is_instance_valid(enemy):
			add_line("You target %s." % _target_display_name(enemy), MsgType.INFO))
	Combat.player_hit_enemy.connect(func(t, a, c): add_damage_out(t, a, c))
	Combat.player_missed_enemy.connect(func(t): add_line("You miss %s." % t, MsgType.DAMAGE_OUT))
	Combat.player_evaded_attack.connect(func(n): add_evade(n))
	Combat.player_took_damage.connect(func(n, a):
		add_line("%s hits you for %d damage." % [n, a], MsgType.DAMAGE_IN))
	WeaponSkills.skill_advanced.connect(func(skill_name: String, new_value: int, cap: int):
		var display: String = WeaponSkillDefinitions.DISPLAY.get(skill_name, skill_name)
		add_line("Your %s skill has increased to %d (cap: %d)." % [display, new_value, cap], MsgType.LEVEL_UP))
	ArmorSkills.skill_advanced.connect(func(skill_name: String, new_value: int, cap: int):
		var display: String = ArmorSkillDefinitions.DISPLAY.get(skill_name, skill_name)
		add_line("Your %s skill has increased to %d (cap: %d)." % [display, new_value, cap], MsgType.LEVEL_UP))
	CastingSkills.skill_advanced.connect(func(skill_name: String, new_value: int, cap: int):
		var display: String = CastingSkillDefinitions.DISPLAY.get(skill_name, skill_name)
		add_line("Your %s skill has increased to %d (cap: %d)." % [display, new_value, cap], MsgType.LEVEL_UP))
	BuffManager.dot_applied.connect(func(tname, sname):
		add_line("%s is afflicted by %s." % [tname, sname], MsgType.DAMAGE_OUT))
	BuffManager.hot_applied.connect(func(sname):
		add_line("You feel the effects of %s." % sname, MsgType.HEAL))
	BuffManager.absorb_applied.connect(func(amount, sname):
		add_line("A %s shield forms around you. (%d HP)" % [sname, amount], MsgType.HEAL))
	BuffManager.absorb_damaged.connect(func(absorbed, remaining):
		add_line("Your shield absorbs %d damage. (%d remaining)" % [absorbed, remaining], MsgType.HEAL))
	BuffManager.absorb_broken.connect(func():
		add_line("Your shield has been destroyed!", MsgType.DAMAGE_IN))
	BuffManager.evade_boost_applied.connect(func():
		add_line("You slip into a defensive stance.", MsgType.INFO))
	BuffManager.dot_ticked.connect(func(tname, amount, sname):
		add_line("%s takes %d from %s." % [tname, amount, sname], MsgType.DAMAGE_OUT))
	BuffManager.hot_ticked.connect(func(amount, sname):
		add_line("You recover %d health from %s." % [amount, sname], MsgType.HEAL))
	PetManager.pet_info.connect(func(text): add_line(text, MsgType.INFO))
	Combat.enemy_stunned.connect(func(n): add_line("%s is stunned!" % n, MsgType.INFO))
	Combat.enemy_stun_wore_off.connect(func(n): add_line("The stun on %s wears off." % n, MsgType.INFO))
	Combat.enemy_rooted.connect(func(n): add_line("%s is rooted!" % n, MsgType.INFO))
	Combat.enemy_snared.connect(func(n): add_line("%s is snared!" % n, MsgType.INFO))
	Combat.enemy_slowed.connect(func(n): add_line("%s is slowed!" % n, MsgType.INFO))
	Combat.enemy_mez_applied.connect(func(n): add_line("%s is mesmerized!" % n, MsgType.INFO))
	Combat.enemy_mez_broke.connect(func(n): add_line("The mesmerize on %s breaks!" % n, MsgType.INFO))
	Combat.enemy_charmed_attacked.connect(func(atk, tgt, amt): add_line("%s hits %s for %d." % [atk, tgt, amt], MsgType.DAMAGE_OUT))
	Combat.enemy_silenced.connect(func(n): add_line("%s is silenced!" % n, MsgType.INFO))
	Combat.auto_attack_toggled.connect(func(on: bool):
		add_line("Auto attack is now %s." % ("ON" if on else "OFF"), MsgType.INFO))
	Net.world_chat_message.connect(_on_remote_chat_message)

# Routes inbound Net.world_chat_message to a typed chat line. Outbound
# echoes (the sender's own line) are still added directly by hud.gd —
# the server doesn't echo back to the sender to avoid double-rendering.
func _on_remote_chat_message(speaker: String, channel: int, text: String, _lang: String) -> void:
	match channel:
		Net.CHAT_CHANNEL_SAY:
			add_line("%s says, '%s'" % [speaker, text], MsgType.SAY)
		Net.CHAT_CHANNEL_SHOUT:
			add_line("%s shouts, '%s'" % [speaker, text], MsgType.SHOUT)
		Net.CHAT_CHANNEL_OOC:
			add_line("[OOC] %s: %s" % [speaker, text], MsgType.OOC)
		Net.CHAT_CHANNEL_TELL:
			_note_tell_sender(speaker)
			add_line("%s tells you, '%s'" % [speaker, text], MsgType.TELL_IN)
		Net.CHAT_CHANNEL_GROUP:
			add_line("[Group] %s: %s" % [speaker, text], MsgType.GROUP_CHAT)
		Net.CHAT_CHANNEL_SYSTEM:
			add_line(text, MsgType.INFO)
		_:
			add_line(text, MsgType.INFO)

func _on_player_hp_changed(current: float, _max: float) -> void:
	var diff := current - _last_hp
	# Threshold the chat line so per-tick noise from food / drink / HoT
	# regen (typically 1-5 HP per tick) doesn't spam the log. Spell heals
	# clear this threshold with room to spare. Server-driven HoT in
	# launcher mode bypasses BuffManager._is_hot_healing entirely, so the
	# threshold is the only suppressor that works for both modes.
	const MIN_HEAL_DISPLAY := 10
	if diff >= MIN_HEAL_DISPLAY and not BuffManager.is_hot_healing():
		add_line("You were healed for %d health." % int(diff), MsgType.HEAL)
	_last_hp = current

# Best-effort display name across the entity zoo (NPCs, pets, peers).
# Order: mob_name (NPCs / and peer RemotePlayer mirrors player_name into
# mob_name), pet_name (pets), player_name (peers without mirror).
# Falls through to the Godot Node name only if none of those are set,
# which is the case the user reported ("@CharacterBody3D@969" / "RemotePet").
func _target_display_name(target) -> String:
	if target == null:
		return ""
	# Corpses and loot bags are targets (player corpses for res casts; kill
	# corpses since slice 1.5). Name them the way the target frame does, or the
	# fall-through below prints the node name ("You target @Area3D@1582.").
	if target is Corpse:
		return "%s's corpse" % target.owner_name
	if target is LootBag:
		return "%s's corpse" % target.creature_name if target.creature_name != "" else "Dropped items"
	if "mob_name" in target:
		var mn = target.get("mob_name")
		if mn != null and String(mn) != "":
			return String(mn)
	if "pet_name" in target:
		var pn = target.get("pet_name")
		if pn != null and String(pn) != "":
			return String(pn)
	if "player_name" in target:
		var pln = target.get("player_name")
		if pln != null and String(pln) != "":
			return String(pln)
	return String(target.name)
