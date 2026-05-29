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
			   SAY, SHOUT, OOC, TELL_OUT, TELL_IN, GROUP_CHAT, CRIT }

var _last_hp: float = 0.0
# Sentinel: -1 means "haven't seen a level_changed yet". The first one
# is the initial apply_character seed (not a real level-up); skip it.
var _last_logged_level: int = -1

func _ready() -> void:
	_connect_signals()
	_last_hp = PlayerStats.hp

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
	Combat.target_changed.connect(func(enemy):
		if enemy != null and is_instance_valid(enemy):
			var tname: String = enemy.get("mob_name") if "mob_name" in enemy else enemy.name
			add_line("You target %s." % tname, MsgType.INFO))
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
			add_line("%s tells you, '%s'" % [speaker, text], MsgType.TELL_IN)
		Net.CHAT_CHANNEL_GROUP:
			add_line("[Group] %s: %s" % [speaker, text], MsgType.GROUP_CHAT)
		Net.CHAT_CHANNEL_SYSTEM:
			add_line(text, MsgType.INFO)
		_:
			add_line(text, MsgType.INFO)

func _on_player_hp_changed(current: float, _max: float) -> void:
	var diff := current - _last_hp
	if diff > 0.0 and not BuffManager.is_hot_healing():
		add_line("You recover %d health." % int(diff), MsgType.HEAL)
	_last_hp = current
