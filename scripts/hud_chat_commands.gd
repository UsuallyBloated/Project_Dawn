extends Node
# The chat line's commands. Every line the player submits arrives here
# (CombatLog.chat_submitted: the chat windows and the social macros) and is
# either sent on its channel or run as a command. One of the hud_*.gd family:
# hud.gd builds it and hands it the few HUD pieces a command needs (setup,
# set_player). A command only prints from local state or asks the server,
# which judges every request itself; nothing decided here is trusted.
# Held by tools/probe_chat_commands.gd.

# Dev Test Panel, mounted on demand by `/testpanel` (world.gd also mounts it at
# world entry for GMs).
const TEST_PANEL_GD := preload("res://scripts/test_panel.gd")

# The local body, for the commands that act on it or read where it stands.
var _player: Node3D = null
var _debug_console: DebugConsole = null
var _track_window: TrackWindow = null
# hud.gd's inspect: the window and its range check live there, and a
# right-click on a player shares it.
var _inspect_player: Callable

# The command tables (filled in _init): what the player typed to the
# function that runs it. Every handler is `_cmd_<name>(text, lower)`: the line
# as typed, and lowered for matching.
var _exact: Dictionary = {}
var _with_args: Dictionary = {}

func _init() -> void:
	# A command that takes nothing: its whole line, lowered. A word after it
	# makes it no command ("/sit down"), so each form a command answers to
	# is its own key.
	_exact = {
		# Posture, camp, pets.
		"/sit": _cmd_sit,
		"/stand": _cmd_stand,
		"/camp": _cmd_camp,
		"/camp cancel": _cmd_camp_cancel,
		"/pet follow": _cmd_pet_follow,
		"/pet guard": _cmd_pet_guard,
		"/pet passive": _cmd_pet_passive, "/pet sit": _cmd_pet_passive,
		"/pet dismiss": _cmd_pet_dismiss,
		"/pet attack": _cmd_pet_attack,
		"/pet back": _cmd_pet_back,
		# Looking around.
		"/inspect": _cmd_inspect,
		"/sense": _cmd_sense, "/sense heading": _cmd_sense,
		"/con": _cmd_consider, "/consider": _cmd_consider,
		"/factions": _cmd_factions,
		"/loc": _cmd_loc, "/location": _cmd_loc,
		"/loc raw": _cmd_loc, "/location raw": _cmd_loc,
		"/track": _cmd_track,
		"/languages": _cmd_languages,
		"/stopsong": _cmd_stopsong,
		# Groups and loot.
		"/invite": _cmd_invite,
		"/accept": _cmd_accept, "/accept invite": _cmd_accept,
		"/leave": _cmd_leave, "/leave group": _cmd_leave,
		"/loot": _cmd_loot,
		"/loot rr": _cmd_loot, "/loot roundrobin": _cmd_loot,
		"/loot ffa": _cmd_loot, "/loot freeforall": _cmd_loot,
		"/autosplit": _cmd_autosplit, "/autosplit on": _cmd_autosplit, "/autosplit off": _cmd_autosplit,
		"/pvp": _cmd_pvp, "/pvp on": _cmd_pvp, "/pvp off": _cmd_pvp,
		# A reply with nobody to reply to (ChatChannel turns every other /r into a tell).
		"/r": _cmd_reply, "/reply": _cmd_reply,
		# The link, the build, the dev tools.
		"/ping": _cmd_ping, "/latency": _cmd_ping,
		"/version": _cmd_version, "/build": _cmd_version,
		"/testpanel": _cmd_testpanel, "/gm": _cmd_testpanel,
		"/console": _cmd_console,
		"/items": _cmd_items,
	}
	# A command that takes a name, a message or a number: its first word.
	_with_args = {
		# The channels, in the one form ChatChannel hands each line on.
		"/say": _cmd_say, "/s": _cmd_say,
		"/shout": _cmd_shout, "/sh": _cmd_shout,
		"/ooc": _cmd_ooc,
		"/g": _cmd_group, "/group": _cmd_group,
		"/tell": _cmd_tell, "/t": _cmd_tell,
		"/r": _cmd_reply, "/reply": _cmd_reply,
		# Languages, groups.
		"/lang": _cmd_lang,
		"/invite": _cmd_invite,
		"/kick": _cmd_kick,
		# Dev tools (the server gates what they ask for).
		"/give": _cmd_give,
		"/items": _cmd_items,
		"/damage": _cmd_damage,
		"/heal": _cmd_heal,
	}

func _ready() -> void:
	CombatLog.chat_submitted.connect(_handle_chat_input)

## The HUD pieces a command toggles or calls, handed over when the HUD builds this.
func setup(debug_console: DebugConsole, track_window: TrackWindow, inspect_player: Callable) -> void:
	_debug_console = debug_console
	_track_window = track_window
	_inspect_player = inspect_player

## The local body, once the HUD has found it.
func set_player(player: Node3D) -> void:
	_player = player

# Every submitted line. A command that takes nothing is found by its whole
# line; one that takes a name, a message or a number by its first word.
func _handle_chat_input(text: String) -> void:
	# One canonical form for every line (ChatChannel): plain text is a /say,
	# and stacked channel commands collapse to the last, so "/say /say hi"
	# says "hi" and a channel command never reaches anyone inside a message.
	text = ChatChannel.normalize(text, CombatLog.last_tell_sender())
	if text == "":
		return

	var lower := text.to_lower()

	var command: Callable = _exact.get(lower, Callable())
	var space := lower.find(" ")
	if not command.is_valid() and space > 0:
		command = _with_args.get(lower.substr(0, space), Callable())
	# `/items` was matched without its space, so "/itemsfoo" lists "foo".
	if not command.is_valid() and lower.begins_with("/items"):
		command = _cmd_items
	if command.is_valid():
		command.call(text, lower)
		return

	CombatLog.add_line("Unknown command: %s" % text, CombatLog.MsgType.INFO)

# ── The commands ──────────────────────────────────────────────────────────────

func _cmd_sit(_text: String, _lower: String) -> void:
	if is_instance_valid(_player):
		_player.sit()

func _cmd_stand(_text: String, _lower: String) -> void:
	if is_instance_valid(_player):
		_player.stand()

# Camp slice B — voluntary sit-gated logout. The server is authoritative on
# the gate and the countdown; we pre-check sit state locally for a fast
# rejection line so a standing player never spams the wire. `/camp cancel`
# aborts an in-progress countdown.
func _cmd_camp(_text: String, _lower: String) -> void:
	if Combat.is_player_seated():
		Net.broadcast_camp()
	else:
		CombatLog.add_line("You must be sitting to camp.", CombatLog.MsgType.INFO)

func _cmd_camp_cancel(_text: String, _lower: String) -> void:
	Net.broadcast_cancel_camp()

func _cmd_pet_follow(_text: String, _lower: String) -> void:
	PetManager.command_follow()

func _cmd_pet_guard(_text: String, _lower: String) -> void:
	PetManager.command_guard()

func _cmd_pet_passive(_text: String, _lower: String) -> void:
	PetManager.command_passive()

func _cmd_pet_dismiss(_text: String, _lower: String) -> void:
	PetManager.dismiss_pet()

# Track 12 Piece A — direct pet commands. /pet attack uses the
# current target; /pet back returns to follow.
func _cmd_pet_attack(_text: String, _lower: String) -> void:
	PetManager.command_attack()

func _cmd_pet_back(_text: String, _lower: String) -> void:
	PetManager.command_back()

func _cmd_say(text: String, lower: String) -> void:
	var my_name := _sender_name()
	for prefix in ["/say ", "/s "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("%s says, '%s'" % [my_name, msg], CombatLog.MsgType.SAY)
			Net.broadcast_chat(Net.CHAT_CHANNEL_SAY, msg)
			return

func _cmd_shout(text: String, lower: String) -> void:
	var my_name := _sender_name()
	for prefix in ["/shout ", "/sh "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("%s shouts, '%s'" % [my_name, msg], CombatLog.MsgType.SHOUT)
			Net.broadcast_chat(Net.CHAT_CHANNEL_SHOUT, msg)
			return

func _cmd_ooc(text: String, _lower: String) -> void:
	var my_name := _sender_name()
	var msg := text.substr("/ooc ".length())
	CombatLog.add_line("[OOC] %s: %s" % [my_name, msg], CombatLog.MsgType.OOC)
	Net.broadcast_chat(Net.CHAT_CHANNEL_OOC, msg)

func _cmd_tell(text: String, lower: String) -> void:
	for prefix in CombatLog.TELL_PREFIXES:
		if lower.begins_with(prefix):
			var rest := text.substr(prefix.length())
			var space_idx := rest.find(" ")
			if space_idx > 0:
				_send_tell(rest.substr(0, space_idx), rest.substr(space_idx + 1))
			else:
				CombatLog.add_line("Usage: /tell <name> <message>", CombatLog.MsgType.INFO)
			return

# EQ-style reply. `/r <message>` answers whoever last sent us a tell; a
# bare `/r` reopens the chat line already addressed to them. TAB in the
# chat line walks the older senders (CombatLog.cycle_tell_text).
func _cmd_reply(text: String, _lower: String) -> void:
	var reply_to := CombatLog.last_tell_sender()
	if reply_to == "":
		CombatLog.add_line("No one has sent you a tell yet.", CombatLog.MsgType.INFO)
		return
	var space_idx := text.find(" ")
	var msg := "" if space_idx < 0 else text.substr(space_idx + 1).strip_edges()
	if msg == "":
		# Deferred: this runs inside the chat line's own submit, which
		# hides the line again as soon as we return.
		ChatWindowManager.show_chat_input.call_deferred("/tell %s " % reply_to)
	else:
		_send_tell(reply_to, msg)

func _cmd_group(text: String, lower: String) -> void:
	var my_name := _sender_name()
	for prefix in ["/g ", "/group "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("[Group] %s: %s" % [my_name, msg], CombatLog.MsgType.GROUP_CHAT)
			# Server fans this to every other group member via the Group
			# arm in the chat handler.
			Net.broadcast_chat(Net.CHAT_CHANNEL_GROUP, msg)
			return

func _cmd_inspect(_text: String, _lower: String) -> void:
	var target = Combat.current_target
	if not is_instance_valid(target) or not (target is RemotePlayer):
		CombatLog.add_line("Target a player to inspect.", CombatLog.MsgType.INFO)
		return
	_inspect_player.call(target)

func _cmd_sense(_text: String, _lower: String) -> void:
	if is_instance_valid(_player):
		CombatLog.add_line(SenseHeading.query(_player.rotation.y), CombatLog.MsgType.INFO)

func _cmd_consider(_text: String, _lower: String) -> void:
	# EQ's consider (factions, 2026-10-23): the server answers with how the
	# target's faction regards you and, for a mob, how its level reads
	# against yours. An NPC is named by its display name (the client holds
	# no server ids for NPCs; the server resolves the name), a mob by its
	# entity id. The server decides everything; this only asks.
	if not Net.is_app_ready():
		CombatLog.add_line("You are not connected to the world.", CombatLog.MsgType.INFO)
		return
	var con_target = Combat.current_target
	if not is_instance_valid(con_target):
		CombatLog.add_line("You must target something to consider it.", CombatLog.MsgType.INFO)
		return
	var npc_name := _npc_display_name(con_target)
	var entity_id := 0 if npc_name != "" else Combat.target_server_id(con_target)
	if npc_name == "" and entity_id == 0:
		CombatLog.add_line("You cannot consider that.", CombatLog.MsgType.INFO)
		return
	if not Net.consider(npc_name, entity_id):
		CombatLog.add_line(
			"This build's gdext_net.dll predates /con (rebuild it with addons/gdext_net/build.ps1).",
			CombatLog.MsgType.INFO)

func _cmd_factions(_text: String, _lower: String) -> void:
	# Every standing the server has told us: only the factions a kill, a
	# quest or the GM panel has moved; the rest sit at Indifferent.
	if Alignment.factions.is_empty():
		CombatLog.add_line("You have moved no faction's standing yet.", CombatLog.MsgType.INFO)
		return
	var ids: Array = Alignment.factions.keys()
	ids.sort()
	for id in ids:
		var f: Dictionary = Alignment.factions[id]
		CombatLog.add_line("%s: %d (%s)" % [f["name"], roundi(f["standing"]),
			Alignment.faction_level_name(int(f["level"]))], CombatLog.MsgType.INFO)

func _cmd_stopsong(_text: String, _lower: String) -> void:
	# EQ's /stopsong: end the song being sung at once. The server pulses
	# the song, so it is told (and says so); the lingering effects run
	# out on their own.
	if Net.stop_song():
		BardSongs.stop_singing()

func _cmd_loc(_text: String, lower: String) -> void:
	# EverQuest's position print (docs/design/location_command.md): north,
	# then west, then height, so a larger first number is further north
	# and a larger second one further west, as EQ printed it (user,
	# 2026-11-14). North is the world's -z and east its +x
	# (ZoneLayout.to_world). `/loc raw` prints the world's x, y, z, which
	# paste straight into zone_camps.toml / npcs.toml. Coordinates only
	# (user, 2026-10-09): which way you face is /sense's job. Works while
	# dead on purpose: a corpse run is exactly when you want it.
	if is_instance_valid(_player):
		var p: Vector3 = _player.global_position
		if lower.ends_with(" raw"):
			CombatLog.add_line(
				"Your world position is %.1f, %.1f, %.1f (x, y, z)." % [p.x, p.y, p.z],
				CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line(
				"Your location is %.1f, %.1f, %.1f (north, west, height)." % [_loc_number(-p.z), _loc_number(-p.x), _loc_number(p.y)],
				CombatLog.MsgType.INFO)
	else:
		# A triage tool must never be silent — say why there is no
		# answer instead of swallowing the command.
		CombatLog.add_line("You have no location right now.", CombatLog.MsgType.INFO)

func _cmd_track(_text: String, _lower: String) -> void:
	if _track_window != null:
		_track_window.toggle()

func _cmd_languages(_text: String, _lower: String) -> void:
	var known: Array = []
	for lang in Languages.skills:
		if Languages.skills[lang] > 0:
			known.append(lang)
	if known.is_empty():
		CombatLog.add_line("You know no languages.", CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("Known languages:", CombatLog.MsgType.INFO)
		for lang in known:
			var active_marker := " (active)" if lang == Languages.active_language else ""
			CombatLog.add_line("  %s — %d%s" % [lang, Languages.skills[lang], active_marker], CombatLog.MsgType.INFO)

func _cmd_lang(text: String, _lower: String) -> void:
	var lang_name := text.substr(6).strip_edges()
	if lang_name == "":
		CombatLog.add_line("Usage: /lang [language name]", CombatLog.MsgType.INFO)
	elif Languages.get_skill(lang_name) > 0:
		Languages.set_active_language(lang_name)
		CombatLog.add_line("You are now speaking %s." % lang_name, CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("You do not know the language '%s'." % lang_name, CombatLog.MsgType.INFO)

# Dev command — drop any ItemRegistry-known item into inventory.
# Syntax: `/give <substring> [count]`. Empty query lists nothing
# (the registry has ~100 entries; a dedicated /items command can
# dump them later). Ambiguous query lists candidates and bails
# without giving so the dev can refine. Single-match → gives.
# Inventory authority is client-only today; when it goes server
# side, this should gate on `accounts.is_gm`.
func _cmd_give(text: String, _lower: String) -> void:
	var rest := text.substr("/give ".length()).strip_edges()
	if rest == "":
		CombatLog.add_line("Usage: /give <item name> [count]", CombatLog.MsgType.INFO)
		return
	var count := 1
	# Optional trailing integer = stack count. Walks back from the
	# end so multi-word names with spaces still parse cleanly
	# ("/give iron short sword 3" → name="iron short sword", count=3).
	var tokens := rest.split(" ", false)
	if tokens.size() > 1 and tokens[tokens.size() - 1].is_valid_int():
		count = int(tokens[tokens.size() - 1])
		tokens.remove_at(tokens.size() - 1)
		rest = " ".join(tokens)
	var matches := ItemRegistry.find_matches(rest, 10)
	if matches.is_empty():
		CombatLog.add_line("No items match '%s'." % rest, CombatLog.MsgType.INFO)
		return
	if matches.size() > 1:
		CombatLog.add_line("Multiple matches for '%s':" % rest, CombatLog.MsgType.INFO)
		for m: ItemData in matches:
			CombatLog.add_line("  • %s" % m.item_name, CombatLog.MsgType.INFO)
		CombatLog.add_line("Refine your search.", CombatLog.MsgType.INFO)
		return
	var item_name := (matches[0] as ItemData).item_name
	# Track 15.2 follow-up — /give goes through the wire (a GM command)
	# so the spawned item exists server-side. The server fans
	# InventoryDelta which Inventory autoload applies.
	Net.broadcast_gm_command("give %s %d" % [item_name, count])
	var suffix := " x%d" % count if count > 1 else ""
	CombatLog.add_line("Requested %s%s from server." % [item_name, suffix], CombatLog.MsgType.INFO)

# Track 6 sub-task 3 dev — toggle PvP authorization on this client.
# Both attacker and target need /pvp on for combat::can_attack to
# allow damage. Used to verify the PvP HP application path before
# the duel / PvP-zone / PvP-server design lands.
func _cmd_pvp(_text: String, lower: String) -> void:
	var on := lower != "/pvp off"
	Net.broadcast_pvp_toggle(on)
	CombatLog.add_line("PvP override: %s" % ("on" if on else "off"), CombatLog.MsgType.INFO)

# Per-player loot auto-split. /autosplit off keeps coin you loot for
# yourself instead of splitting it among the nearby group in Round
# Robin. See docs/design/group_loot_and_coin.md.
func _cmd_autosplit(_text: String, lower: String) -> void:
	var split_on := lower != "/autosplit off"
	Net.broadcast_autosplit(split_on)
	CombatLog.add_line("Auto-split loot: %s" % ("on" if split_on else "off"), CombatLog.MsgType.INFO)

# Group loot distribution mode (leader only). Bare /loot reports the
# current mode; /loot rr | ffa sets it. See group_loot_and_coin.md.
func _cmd_loot(_text: String, lower: String) -> void:
	if lower == "/loot":
		CombatLog.add_line("Loot mode: %s. Leader: /loot rr or /loot ffa." % GroupManager.loot_mode_name(), CombatLog.MsgType.INFO)
		return
	if lower == "/loot rr" or lower == "/loot roundrobin" or lower == "/loot ffa" or lower == "/loot freeforall":
		if not GroupManager.is_leader:
			CombatLog.add_line("Only the group leader can set the loot mode.", CombatLog.MsgType.INFO)
			return
		var ffa := lower == "/loot ffa" or lower == "/loot freeforall"
		var mode := GroupManager.LOOT_FREE_FOR_ALL if ffa else GroupManager.LOOT_ROUND_ROBIN
		GroupManager.set_loot_mode(mode)
		CombatLog.add_line("Loot mode set to %s." % ("Free-for-all" if ffa else "Round Robin"), CombatLog.MsgType.INFO)
		return

# Round trip to the world server, from the wire layer's own ack timing (the
# UDP path the game plays on, smoothed), with renet's packet-loss estimate.
# So a tester on the public host can report a number instead of "it feels
# laggy"; the server logs the same figures per player once a minute as a
# `player link` line. Not GM-gated, for the same reason as /version.
func _cmd_ping(_text: String, _lower: String) -> void:
	if not Net.is_app_ready():
		CombatLog.add_line("Not connected to a world server.", CombatLog.MsgType.INFO)
		return
	var rtt_ms := Net.get_rtt_ms()
	if rtt_ms < 0.0:
		CombatLog.add_line(
			"This build's gdext_net.dll predates /ping (rebuild it with addons/gdext_net/build.ps1).",
			CombatLog.MsgType.INFO,
		)
		return
	CombatLog.add_line(
		"Round trip to the server: %d ms, packet loss %d%%."
			% [roundi(rtt_ms), roundi(maxf(Net.get_packet_loss(), 0.0) * 100.0)],
		CombatLog.MsgType.INFO,
	)

# Report which client build this is. The server stamps its own commit onto the
# boot line; this is the client half, and it is the quickest way to confirm a
# tester actually installed the build we sent them rather than re-running an
# older one. Not GM-gated: knowing your own version is not a privilege, and
# asking a tester to read it back is the whole point.
func _cmd_version(_text: String, _lower: String) -> void:
	for line in BuildInfo.verbose().split("\n"):
		CombatLog.add_line(line, CombatLog.MsgType.INFO)

# Show/hide the dev Test Panel. It mounts only for GM accounts (world.gd),
# but a GM previously had no way to get it OFF the
# screen: it covers a chunk of the viewport and there is no reason to stare at
# it while actually playing. A command rather than a keybind, so it costs no
# key and is discoverable by typing.
func _cmd_testpanel(_text: String, _lower: String) -> void:
	var panel := get_tree().get_first_node_in_group("test_panel") as CanvasLayer
	if panel != null:
		panel.visible = not panel.visible
		CombatLog.add_line(
			"Test Panel: %s" % ("shown" if panel.visible else "hidden"),
			CombatLog.MsgType.INFO,
		)
		return
	# Not mounted. world.gd only mounts it at world-entry, so anything that
	# left `Net.is_gm()` false at that instant (a GM grant applied mid-session,
	# a login path that skipped the LoginOk handler) meant no panel for the
	# rest of the session with no way to recover. Mount it on demand instead,
	# so the command works whenever the account is entitled to it rather than
	# depending on the state at one particular moment.
	if Net.is_gm():
		var host := get_tree().current_scene
		if host != null:
			host.add_child(TEST_PANEL_GD.new())
			CombatLog.add_line("Test Panel: shown", CombatLog.MsgType.INFO)
			return
	# Genuinely not entitled. Report the deciding flags rather than a flat
	# "not available" — this is a dev tool, and "why not" is the useful answer.
	# Nothing here is secret: the server gates every power the panel offers on
	# the is_gm bit in the signed token, independently of this.
	CombatLog.add_line(
		"Test Panel unavailable (GM: %s). GM is per ACCOUNT and is read at login, so if it was granted while you were online, quit to the login screen and sign in again." % [
			"yes" if Net.is_gm() else "no",
		],
		CombatLog.MsgType.INFO,
	)

# Dev-only — backup trigger for the in-game debug console when the
# F2 keybind isn't reaching the game window (editor focus, OS
# steals, etc.). Round-7B fallback.
func _cmd_console(_text: String, _lower: String) -> void:
	if _debug_console != null:
		_debug_console.toggle()
		CombatLog.add_line(
			"Debug console: %s (%d lines buffered)" % [
				"ON" if _debug_console.visible else "OFF",
				DebugLog.recent_lines.size(),
			],
			CombatLog.MsgType.INFO,
		)

# Track 6 sub-task 3 dev — bypass-the-spell-system self damage.
# Routes through the same server damage path PvP and (future) spells
# use, exercising regen + death detection end-to-end. Replaced by
# proper CastSpell handling once the spell table is server-side.
func _cmd_damage(text: String, _lower: String) -> void:
	var arg := text.substr("/damage ".length()).strip_edges()
	if not arg.is_valid_int():
		CombatLog.add_line("Usage: /damage <amount>", CombatLog.MsgType.INFO)
		return
	Net.broadcast_damage_self(int(arg))
	CombatLog.add_line("Dev damage self: %s" % arg, CombatLog.MsgType.INFO)

# Track 6 sub-task 5 — group commands, resolved by the server.
func _cmd_invite(text: String, lower: String) -> void:
	var target_name := ""
	if lower.begins_with("/invite "):
		target_name = text.substr("/invite ".length()).strip_edges()
	# No name given → fall back to the currently-targeted RemotePlayer.
	if target_name == "":
		var target = Combat.current_target
		if is_instance_valid(target) and target is RemotePlayer:
			target_name = target.player_name
	if target_name == "":
		CombatLog.add_line("Usage: /invite <character name> — or target a player first.", CombatLog.MsgType.INFO)
		return
	GroupManager.invite_player_by_name(target_name)
	CombatLog.add_line("Invited %s to your group." % target_name, CombatLog.MsgType.INFO)

func _cmd_accept(_text: String, _lower: String) -> void:
	if GroupManager.pending_invite_from == 0:
		CombatLog.add_line("No pending group invite.", CombatLog.MsgType.INFO)
		return
	GroupManager.accept_invite()
	CombatLog.add_line("Accepted the group invite.", CombatLog.MsgType.INFO)

func _cmd_leave(_text: String, _lower: String) -> void:
	if not GroupManager.in_group:
		CombatLog.add_line("You aren't in a group.", CombatLog.MsgType.INFO)
		return
	GroupManager.leave_group()
	CombatLog.add_line("You left the group.", CombatLog.MsgType.INFO)

func _cmd_kick(text: String, _lower: String) -> void:
	var target_name := text.substr("/kick ".length()).strip_edges()
	if target_name == "":
		CombatLog.add_line("Usage: /kick <character name>", CombatLog.MsgType.INFO)
		return
	if not GroupManager.is_leader:
		CombatLog.add_line("Only the group leader can kick.", CombatLog.MsgType.INFO)
		return
	GroupManager.kick_member_by_name(target_name)
	CombatLog.add_line("Kicked %s from the group." % target_name, CombatLog.MsgType.INFO)

# Track 6 sub-task 3 dev — bypass-the-spell-system self heal.
# Verifies that server-applied heals stick (the regression we noted
# during sub-task 1 verification) before the CastSpell port lands.
func _cmd_heal(text: String, _lower: String) -> void:
	var arg := text.substr("/heal ".length()).strip_edges()
	if not arg.is_valid_int():
		CombatLog.add_line("Usage: /heal <amount>", CombatLog.MsgType.INFO)
		return
	Net.broadcast_heal_self(int(arg))
	CombatLog.add_line("Dev heal self: %s" % arg, CombatLog.MsgType.INFO)

# Dev command — list items whose name matches a substring without
# spawning. Pairs with /give for discoverability without flooding
# the inventory.
func _cmd_items(text: String, _lower: String) -> void:
	var rest := text.substr("/items".length()).strip_edges()
	if rest == "":
		CombatLog.add_line("Usage: /items <substring> (registry has %d items)" % ItemRegistry.count(), CombatLog.MsgType.INFO)
		return
	var matches := ItemRegistry.find_matches(rest, 30)
	if matches.is_empty():
		CombatLog.add_line("No items match '%s'." % rest, CombatLog.MsgType.INFO)
		return
	CombatLog.add_line("Items matching '%s' (%d):" % [rest, matches.size()], CombatLog.MsgType.INFO)
	for m: ItemData in matches:
		CombatLog.add_line("  • %s" % m.item_name, CombatLog.MsgType.INFO)

# ── Helpers ───────────────────────────────────────────────────────────────────

# The name the player's own chat lines are echoed under.
func _sender_name() -> String:
	return PlayerStats.player_name if PlayerStats.player_name != "" else "You"

# One tell on the wire plus the sender's own echo line (the server does not
# echo a tell back to its sender). Shared by /tell and /r.
func _send_tell(target_name: String, msg: String) -> void:
	CombatLog.add_line("You -> %s: %s" % [target_name, msg], CombatLog.MsgType.TELL_OUT)
	Net.broadcast_chat(Net.CHAT_CHANNEL_TELL, msg, target_name)

# A /loc number to one decimal, never "-0.0" (/loc negates two of the axes, and a
# body a hair south of the line would otherwise print a minus on a zero).
static func _loc_number(v: float) -> float:
	return snappedf(v, 0.1) + 0.0

# The display name an NPC node carries, for /con (the client holds no server
# ids for NPCs). `npc_name` first: the vendor and banker labels carry a role
# after a dash that npcs.toml does not, so that part is trimmed.
func _npc_display_name(node) -> String:
	if not is_instance_valid(node):
		return ""
	for key in ["npc_name", "vendor_name", "banker_name"]:
		if key in node and String(node.get(key)) != "":
			var n := String(node.get(key))
			var dash := n.find(" — ")
			return n.substr(0, dash) if dash >= 0 else n
	return ""
