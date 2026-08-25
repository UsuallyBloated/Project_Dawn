extends Node

signal spell_cast(spell: SpellData)
signal spell_failed(reason: String)
signal spell_cooldown_updated(spell_name: String, remaining: float, total: float)
signal casting_started(spell: SpellData)
signal casting_cancelled
signal spells_changed

var _all_spells: Dictionary = {}
var _cooldowns: CooldownTracker
var available: Array[SpellData] = []

var _casting: SpellData = null
var _cast_timer: float = 0.0
var _hit_during_cast: bool = false
var no_cooldowns: bool = false

func _ready() -> void:
	SpellDefinitions.validate()
	_cooldowns = CooldownTracker.new()
	_cooldowns.cooldown_updated.connect(func(n, r, t): spell_cooldown_updated.emit(n, r, t))
	_load_spells()
	PlayerStats.level_changed.connect(_on_level_changed)
	Alignment.alignment_changed.connect(_on_alignment_changed)

func _process(delta: float) -> void:
	if _casting != null:
		_cast_timer -= delta
		if _cast_timer <= 0.0:
			_finish_cast()
	_cooldowns.tick(delta)

func setup_for_class(_player_class: String) -> void:
	var effective := Alignment.get_effective_class()
	var current_level := PlayerStats.level
	var candidates: Array[SpellData] = []
	for sname in _all_spells:
		var spell: SpellData = _all_spells[sname]
		if spell.allowed_classes.is_empty() or effective in spell.allowed_classes:
			if current_level >= spell.min_level:
				candidates.append(spell)
	# For ranked spells, keep only the highest accessible rank per base spell.
	var by_base: Dictionary = {}
	for spell in candidates:
		var base := spell.base_name if spell.base_name != "" else spell.spell_name
		if not by_base.has(base) or spell.rank > (by_base[base] as SpellData).rank:
			by_base[base] = spell
	available.clear()
	for spell in by_base.values():
		available.append(spell as SpellData)
	available.sort_custom(func(a, b): return a.spell_name < b.spell_name)
	spells_changed.emit()

func _get_alignment_effectiveness(player_class: String) -> float:
	var tier := Alignment.alignment_tier
	match player_class:
		"Paladin":
			match tier:
				"Neutral": return 0.7
				"Bad":     return 0.4
		"Shadow Knight":
			match tier:
				"Neutral": return 0.7
				"Good":    return 0.4
	return 1.0

func cast_spell(spell: SpellData) -> bool:
	if _casting != null:
		return false
	if Combat.is_player_seated():
		spell_failed.emit("You cannot cast while sitting.")
		return false
	if _cooldowns.is_active(spell.spell_name) and not no_cooldowns:
		spell_failed.emit("Spell is on cooldown.")
		return false
	if PlayerStats.mp < spell.mana_cost:
		spell_failed.emit("Not enough mana.")
		return false
	if spell.target_type == SpellData.TargetType.ENEMY:
		if not Combat.has_valid_target():
			spell_failed.emit("No valid target.")
			return false
		# Local-side gates for damage casts against allied targets, run
		# before the cast bar starts so no mana is spent and no
		# elemental flash misreads as a hit landing. Two cases:
		#   1. Own pet — server would reject ("Your pet won't attack
		#      itself.") but we should never even ask.
		#   2. Peer / peer-pet while local /pvp is off — server's PvP
		#      gate rejects after the cast. If local /pvp is on but the
		#      peer's flag is off, the cast must still proceed because
		#      peer state is server-only.
		if Net.is_launcher_mode():
			var t = Combat.current_target
			if t is RemotePet and (t as RemotePet).owner_id == Net.get_player_id():
				spell_failed.emit("You cannot attack your own pet.")
				return false
			if not Net.is_local_pvp_on():
				var t_is_pvp_target := false
				if t is RemotePlayer:
					t_is_pvp_target = (t as RemotePlayer).char_id != Net.get_player_id()
				elif t is RemotePet:
					t_is_pvp_target = (t as RemotePet).owner_id != Net.get_player_id()
				if t_is_pvp_target:
					spell_failed.emit("PvP is off. Type /pvp on to attack other players.")
					return false
	# ALLY beneficial-cast pre-check (heals AND buffs). Mirrors the
	# damage-cast pre-check above so the cast bar doesn't run + mana
	# isn't spent when the server's PvP gate would refuse. Triggers when
	# local /pvp is on and the target isn't self / group-mate. False
	# positives are possible (peer might be /pvp off, meaning the cast
	# would land) but in practice a /pvp-on caster shouldn't be buffing
	# or healing a hostile-tinted target anyway.
	if spell.target_type == SpellData.TargetType.ALLY:
		if Net.is_launcher_mode() and Net.is_local_pvp_on():
			var t = Combat.current_target
			if t is RemotePet:
				var ownr := (t as RemotePet).owner_id
				if ownr != Net.get_player_id() and not GroupManager.is_member(ownr):
					spell_failed.emit("You cannot cast that on an enemy's pet.")
					return false
			elif t is RemotePlayer:
				var cid := (t as RemotePlayer).char_id
				if cid != Net.get_player_id() and not GroupManager.is_member(cid):
					spell_failed.emit("You cannot cast that on an enemy.")
					return false
	if spell.target_type == SpellData.TargetType.PET_CHARM:
		if not Combat.has_valid_target():
			spell_failed.emit("No valid target to charm.")
			return false

	if spell.target_type == SpellData.TargetType.PORT:
		var is_gate        := spell.port_zone_path.is_empty() and spell.port_entry_id.is_empty()
		var is_same_zone   := spell.port_zone_path.is_empty() and not spell.port_entry_id.is_empty()
		if is_gate and PlayerStats.bind_zone_path.is_empty():
			spell_failed.emit("You have no bind point. Cast Bind Affinity first.")
			return false
		if is_same_zone and ZoneLoader.current_zone_path.is_empty():
			spell_failed.emit("Cannot port — no zone loaded.")
			return false
		if not spell.port_zone_path.is_empty() and not FileAccess.file_exists(spell.port_zone_path):
			spell_failed.emit("That destination has not yet been discovered.")
			return false

	if spell.target_type == SpellData.TargetType.BIND:
		if ZoneLoader.current_zone_path.is_empty():
			spell_failed.emit("You cannot bind here.")
			return false
		if ZoneLoader.current_zone_path in ZoneData.NON_BINDABLE_ZONES:
			spell_failed.emit("The magic will not anchor here.")
			return false

	# Slice 3 — a resurrection needs a corpse targeted. Gate before the mana spend
	# + cast bar (mirrors the ENEMY gate) so a mis-cast doesn't burn a long res cast.
	if spell.target_type == SpellData.TargetType.CORPSE:
		if not (Combat.current_target is Corpse):
			spell_failed.emit("You must target a corpse.")
			return false

	PlayerStats.set_mp(PlayerStats.mp - spell.mana_cost)

	if spell.cast_time > 0.0:
		_casting = spell
		_cast_timer = spell.cast_time
		_hit_during_cast = false
		casting_started.emit(spell)
	else:
		_apply_spell(spell)
	return true

func cast_by_index(index: int) -> bool:
	if index < 0 or index >= available.size():
		return false
	return cast_spell(available[index])

func is_casting() -> bool:
	return _casting != null

func cancel_cast() -> void:
	if _casting == null:
		return
	# Refund the mana. It was spent at cast START (before the bar), but the
	# server only deducts when CastSpell arrives at completion — which a
	# cancelled cast never sends — so the client's optimistic spend is the only
	# record and would linger until the next server ManaUpdate overwrote it.
	# Same principle as the server's unknown-spell refund: hand back what was
	# never really taken. Applies to every cancel path (deliberate stop,
	# server CastFail) and offline alike — in no cancel case was mana truly
	# consumed anywhere.
	PlayerStats.set_mp(minf(PlayerStats.mp + _casting.mana_cost, PlayerStats.max_mp))
	_casting = null
	_cast_timer = 0.0
	_hit_during_cast = false
	casting_cancelled.emit()

# Called by combat when the player takes a hit during a cast.
# Uses Channeling skill to determine whether the cast is interrupted or survives.
#
# Track 19A — in launcher mode the server owns the roll and fans
# CastFail("interrupted (hit during cast)") on a successful interrupt
# (RemotePlayerManager._on_cast_fail handles the local cancel).
# Channeling advance also lives server-side. So this is a no-op in
# launcher mode; solo / Test Room keeps the local roll.
func try_interrupt_cast() -> void:
	if Net.is_launcher_mode():
		return
	if _casting == null:
		return
	if randf() < CastingSkills.get_interrupt_chance():
		cancel_cast()
	else:
		_hit_during_cast = true

func is_on_cooldown(spell_name: String) -> bool:
	return _cooldowns.is_active(spell_name)

func get_cooldown_remaining(spell_name: String) -> float:
	return _cooldowns.get_remaining(spell_name)

# Any loaded spell by exact name, regardless of class/level gating
# (`available` is the class-filtered subset; `_all_spells` is everything).
# Used by BuffManager to reconstruct an ALLY buff another player cast on
# us from a BuffSnapshot name. Returns null for unknown names.
func get_spell_by_name(n: String) -> SpellData:
	return _all_spells.get(n, null)

func _finish_cast() -> void:
	var spell := _casting
	var was_hit := _hit_during_cast
	_casting = null
	_cast_timer = 0.0
	_hit_during_cast = false
	if was_hit:
		CastingSkills.try_advance("channeling")
	_apply_spell(spell)

func _apply_spell(spell: SpellData) -> void:
	# Track 6 sub-task 3b: broadcast the cast intent so the server runs
	# its authoritative damage / heal pipeline. The local mutations
	# below still fire for instant visual feedback; the server's next
	# HealthUpdate / ManaUpdate overrides PlayerStats with the
	# authoritative value. Spells not in the server's spells.toml fall
	# through silently (the server logs at debug); only the local
	# effects land. target_id = 0 encodes "no target" for SELF.
	if Net.is_launcher_mode() and Net.is_app_ready():
		Net.broadcast_cast_spell(spell.spell_name, _cast_target_id(spell))

	_cooldowns.start(spell.spell_name, spell.cooldown)
	var effectiveness := _get_alignment_effectiveness(PlayerStats.player_class)
	var dmg_mult    := CastingSkills.get_damage_mult(spell.discipline)
	var dur_mult    := CastingSkills.get_duration_mult(spell.discipline)
	var absorb_mult := CastingSkills.get_absorb_mult(spell.discipline)
	# ALLY beneficial spells cast on a remote recipient (peer OR pet) are
	# applied by the server, which fans the authoritative result back; skip
	# the local mutation so we don't double-apply or buff the caster instead
	# of the target. Pets are server-authoritative buff/heal recipients now.
	var ally_remote := _ally_target_is_remote(spell)

	if spell.target_type == SpellData.TargetType.ENEMY:
		Combat.deal_spell_damage(int((spell.base_damage + PlayerStats.intelligence * 0.5) * effectiveness * dmg_mult), spell.damage_type)

	if spell.target_type == SpellData.TargetType.AOE:
		Combat.deal_aoe_spell_damage(
			spell.aoe_radius,
			int((spell.base_damage + PlayerStats.intelligence * 0.5) * effectiveness * dmg_mult),
			spell.damage_type)

	if spell.target_type == SpellData.TargetType.PET_SUMMON:
		PetManager.summon(spell.pet_type)

	if spell.target_type == SpellData.TargetType.PET_CHARM:
		PetManager.charm_current_target(spell.duration)

	if spell.target_type == SpellData.TargetType.PET_HEAL:
		WarderAI.heal_warder(spell.heal_amount + PlayerStats.wisdom * 0.3)

	# In launcher mode the server applies the self-heal and the hp-cost
	# authoritatively and fans HealthUpdate; applying them locally too makes the
	# HP bar jump to a client-predicted value (the local heal adds WIS + alignment
	# effectiveness the server's flat heal omits) and then snap back down a
	# HealthUpdate later — the "bouncing" health bar. Skip the local self-HP
	# writes in launcher mode, matching regen.gd and the HoT tick; Test Room
	# (no server) keeps the instant local effect.
	var server_owns_hp := Net.is_launcher_mode()

	if spell.heal_amount > 0.0 and spell.target_type != SpellData.TargetType.PET_HEAL:
		if not ally_remote and not server_owns_hp:
			var heal := (spell.heal_amount + PlayerStats.wisdom * 0.3) * effectiveness
			PlayerStats.set_hp(PlayerStats.hp + heal)

	if spell.hp_cost > 0.0 and not server_owns_hp:
		PlayerStats.set_hp(PlayerStats.hp - spell.hp_cost)

	if spell.dot_dps > 0.0 and spell.dot_duration > 0.0:
		# Track 6 sub-task 3b: DoTs on RemotePlayer targets aren't
		# applied client-side (BuffManager.add_dot expects an enemy
		# node with take_damage etc.). Server-side DoT processing
		# lands in sub-task 4 when buff state moves server-side.
		if spell.target_type == SpellData.TargetType.ENEMY and Combat.has_valid_target() and not (Combat.current_target is RemotePlayer or Combat.current_target is RemotePet):
			BuffManager.add_dot(Combat.current_target, spell.dot_dps * effectiveness,
				spell.dot_duration * dur_mult, spell.spell_name)

	if spell.hot_hps > 0.0 and spell.hot_duration > 0.0:
		if not ally_remote:
			BuffManager.add_hot(spell.hot_hps * effectiveness, spell.hot_duration * dur_mult, spell.spell_name)

	if spell.absorb_amount > 0.0 and not ally_remote:
		BuffManager.add_absorb(spell.absorb_amount * effectiveness * absorb_mult, spell.spell_name)

	if spell.damage_shield_amount > 0.0 and spell.damage_shield_duration > 0.0 and not ally_remote:
		BuffManager.add_damage_shield(spell.damage_shield_amount * effectiveness, spell.damage_shield_duration * dur_mult, spell.spell_name)

	# Track 6 sub-task 3b: CC / snare / silence / dispel only fire on
	# enemy NPC targets that expose the matching methods. RemotePlayer
	# stubs don't yet exist — sub-task 4 lifts these to server-side
	# buff state. The has_method guards keep PvP casts crash-free
	# while documenting the gap.
	if spell.cc_duration > 0.0:
		if spell.target_type == SpellData.TargetType.ENEMY and Combat.has_valid_target() and Combat.current_target.has_method("mesmerize"):
			Combat.current_target.mesmerize(spell.cc_duration * dur_mult)

	if spell.root_duration > 0.0:
		if spell.target_type == SpellData.TargetType.ENEMY and Combat.has_valid_target() and Combat.current_target.has_method("root"):
			Combat.current_target.root(spell.root_duration * dur_mult)

	if spell.slow_amount > 0.0 and spell.slow_duration > 0.0:
		if spell.target_type == SpellData.TargetType.ENEMY and Combat.has_valid_target() and Combat.current_target.has_method("snare"):
			Combat.current_target.snare(spell.slow_amount, spell.slow_duration * dur_mult)

	if spell.attack_slow_amount > 0.0 and spell.attack_slow_duration > 0.0:
		if spell.target_type == SpellData.TargetType.ENEMY and Combat.has_valid_target() and Combat.current_target.has_method("apply_attack_slow"):
			Combat.current_target.apply_attack_slow(spell.attack_slow_amount, spell.attack_slow_duration * dur_mult)

	if spell.primary_stat_buff_duration > 0.0 and not ally_remote:
		BuffManager.add_primary_stat_buff(
			spell.str_buff, spell.agi_buff, spell.int_buff,
			spell.wis_buff, spell.con_buff,
			spell.max_hp_buff, spell.max_mp_buff,
			spell.primary_stat_buff_duration * dur_mult, spell.spell_name)

	if spell.target_type == SpellData.TargetType.PORT:
		_execute_port(spell)

	if spell.target_type == SpellData.TargetType.BIND:
		_execute_bind()

	if not spell.is_song:
		if spell.move_speed_mult > 0.0 and spell.move_speed_duration > 0.0 and not ally_remote:
			BuffManager.add_speed_buff(spell.move_speed_mult, spell.move_speed_duration * dur_mult, spell.spell_name)

		if spell.mp_regen_hps > 0.0 and spell.mp_regen_duration > 0.0 and not ally_remote:
			BuffManager.add_mp_regen_buff(spell.mp_regen_hps * effectiveness, spell.mp_regen_duration * dur_mult, spell.spell_name)

		if spell.haste_amount > 0.0 and spell.haste_duration > 0.0 and not ally_remote:
			BuffManager.add_haste_buff(spell.haste_amount, spell.haste_duration * dur_mult, spell.spell_name)

		if (spell.accuracy_buff > 0.0 or spell.crit_buff > 0.0) and not ally_remote:
			BuffManager.add_stat_buff(spell.accuracy_buff, spell.crit_buff, spell.stat_buff_duration * dur_mult, spell.spell_name)

	if spell.is_stealth:
		BuffManager.add_stealth(spell.stealth_duration * dur_mult, spell.spell_name)

	if spell.is_dispel:
		if Combat.has_valid_target() and Combat.current_target.has_method("strip_one_buff"):
			var stripped: bool = Combat.current_target.strip_one_buff()
			if stripped:
				CombatLog.add_line("You strip a buff from %s." % Combat.current_target.mob_name, CombatLog.MsgType.INFO)
			else:
				CombatLog.add_line("%s has no buffs to strip." % Combat.current_target.mob_name, CombatLog.MsgType.INFO)

	if spell.silence_duration > 0.0:
		if Combat.has_valid_target() and Combat.current_target.has_method("silence"):
			Combat.current_target.silence(spell.silence_duration * dur_mult)

	if spell.is_lich_form:
		BuffManager.toggle_lich_form(spell.lich_mp_regen)

	if spell.mana_drain > 0.0:
		# Mana drain (Exsanguinate) needs take_damage on the target;
		# RemotePlayer doesn't expose that path yet (server handles HP
		# via CastSpell). Caster still gets the mana, but the damage
		# applies through the server's spell handler.
		if Combat.has_valid_target() and Combat.current_target.has_method("take_damage"):
			var drained := minf(spell.mana_drain * effectiveness * dmg_mult, Combat.current_target.hp)
			Combat.current_target.take_damage(int(drained))
			PlayerStats.set_mp(PlayerStats.mp + drained)
			CombatLog.add_line("You drain %d life from %s into mana." % [int(drained), Combat.current_target.mob_name], CombatLog.MsgType.INFO)
		elif Combat.has_valid_target():
			PlayerStats.set_mp(PlayerStats.mp + spell.mana_drain * effectiveness * dmg_mult)

	if spell.is_song:
		BardSongs.activate_song(spell)

	if spell.target_type in [SpellData.TargetType.ENEMY, SpellData.TargetType.AOE]:
		BuffManager.break_stealth()

	if spell.discipline != "":
		CastingSkills.try_advance(spell.discipline)

	spell_cast.emit(spell)

# True when a spell's beneficial effect lands on the recipient as HP/MP
# (heal or HoT) — these can route to pets, where pure stat/haste/etc.
# buffs cannot (server pets have no replicated buff state yet).
# Network target id for a cast. Damage/AOE/charm etc. send whatever entity
# is targeted. An ALLY (beneficial) spell accepts a peer OR a pet as a
# remote target — both are server-authoritative heal/buff recipients now.
# An enemy/NPC target falls back to a self-cast (id 0), since beneficial
# magic shouldn't be flung at a hostile. id 0 == "no target / self".
func _cast_target_id(spell: SpellData) -> int:
	var t = Combat.current_target
	if t == null or not is_instance_valid(t):
		return 0
	# Corpse / resurrection Slice 3 — a res spell targets a corpse entity; its id
	# is the corpse_id (loot-bag id partition). The server validates ownership +
	# range; id 0 (no corpse selected) is rejected there.
	if spell.target_type == SpellData.TargetType.CORPSE:
		if t is Corpse:
			return (t as Corpse).corpse_id
		return 0
	if spell.target_type == SpellData.TargetType.ALLY:
		if t is RemotePlayer:
			return (t as RemotePlayer).char_id
		if t is RemotePet:
			return (t as RemotePet).pet_id
		return 0
	if t is RemotePlayer:
		return (t as RemotePlayer).char_id
	if t is RemoteEnemy:
		return (t as RemoteEnemy).enemy_id
	if t is RemotePet:
		return (t as RemotePet).pet_id
	return 0

# True when an ALLY-target spell is being cast on a remote recipient (peer
# or pet) the server — not the client — applies it to. The caster skips its
# local BuffManager / heal mutation; the server fans the authoritative
# result back (the recipient reconstructs a player buff from the
# BuffSnapshot; pets are server-authoritative throughout).
func _ally_target_is_remote(spell: SpellData) -> bool:
	if spell.target_type != SpellData.TargetType.ALLY or not Net.is_launcher_mode():
		return false
	var t = Combat.current_target
	if t == null or not is_instance_valid(t):
		return false
	return t is RemotePlayer or t is RemotePet

func _execute_bind() -> void:
	var zone_path := ZoneLoader.current_zone_path
	if zone_path.is_empty():
		spell_failed.emit("You cannot bind here.")
		return
	if zone_path in ZoneData.NON_BINDABLE_ZONES:
		spell_failed.emit("The magic will not anchor here.")
		return
	# TODO: when multiplayer RPC is wired, check GroupManager for a valid grouped
	# player target and call set_bind_point on them via RPC instead.
	PlayerStats.set_bind_point(zone_path, "default", ZoneLoader.current_zone_name)
	CombatLog.add_line("You are now bound to %s." % ZoneLoader.current_zone_name, CombatLog.MsgType.INFO)

func _execute_port(spell: SpellData) -> void:
	var zone_path := spell.port_zone_path
	var entry_id  := spell.port_entry_id
	var zone_name := spell.port_zone_name

	if zone_path.is_empty() and entry_id.is_empty():
		zone_path = PlayerStats.bind_zone_path
		entry_id  = PlayerStats.bind_entry_id
		zone_name = PlayerStats.bind_zone_name
	elif zone_path.is_empty():
		zone_path = ZoneLoader.current_zone_path
		zone_name = ZoneLoader.current_zone_name

	if zone_path.is_empty():
		spell_failed.emit("No destination zone available.")
		return

	if spell.port_is_group and GroupManager.in_group:
		CombatLog.add_line("Porting group — multiplayer RPC not yet wired.", CombatLog.MsgType.INFO)

	ZoneLoader.travel_to(zone_path, entry_id, zone_name)

func _on_level_changed(_level: int) -> void:
	setup_for_class(PlayerStats.player_class)

func _on_alignment_changed(_tier: String, _score: int) -> void:
	setup_for_class(PlayerStats.player_class)

func _load_spells() -> void:
	for d in SpellDefinitions.ALL:
		var s := SpellData.new()
		s.spell_name = d["name"]
		s.description = d["desc"]
		s.mana_cost = d["mana_cost"]
		s.cast_time = d["cast_time"]
		s.cooldown = d["cooldown"]
		s.base_damage = d["base_damage"]
		s.damage_type = _parse_damage_type(d["damage_type"])
		s.target_type = _parse_target_type(d["target_type"])
		s.heal_amount = d["heal_amount"]
		s.hp_cost = d.get("hp_cost", 0.0)
		s.duration = d.get("duration", 0.0)
		s.pet_type = d.get("pet_type", "")
		s.dot_dps = d.get("dot_dps", 0.0)
		s.dot_duration = d.get("dot_duration", 0.0)
		s.hot_hps = d.get("hot_hps", 0.0)
		s.hot_duration = d.get("hot_duration", 0.0)
		s.absorb_amount = d.get("absorb_amount", 0.0)
		s.cc_duration         = d.get("cc_duration", 0.0)
		s.root_duration       = d.get("root_duration", 0.0)
		s.slow_amount         = d.get("slow_amount", 0.0)
		s.slow_duration       = d.get("slow_duration", 0.0)
		s.attack_slow_amount  = d.get("attack_slow_amount", 0.0)
		s.attack_slow_duration = d.get("attack_slow_duration", 0.0)
		s.port_zone_path = d.get("port_zone_path", "")
		s.port_entry_id  = d.get("port_entry_id", "")
		s.port_zone_name = d.get("port_zone_name", "")
		s.port_is_group  = d.get("port_is_group", false)
		s.move_speed_mult     = d.get("move_speed_mult", 0.0)
		s.move_speed_duration = d.get("move_speed_duration", 0.0)
		s.mp_regen_hps        = d.get("mp_regen_hps", 0.0)
		s.mp_regen_duration   = d.get("mp_regen_duration", 0.0)
		s.haste_amount        = d.get("haste_amount", 0.0)
		s.haste_duration      = d.get("haste_duration", 0.0)
		s.accuracy_buff       = d.get("accuracy_buff", 0.0)
		s.crit_buff           = d.get("crit_buff", 0.0)
		s.stat_buff_duration  = d.get("stat_buff_duration", 0.0)
		s.is_stealth          = d.get("is_stealth", false)
		s.stealth_duration    = d.get("stealth_duration", 0.0)
		s.is_dispel           = d.get("is_dispel", false)
		s.silence_duration    = d.get("silence_duration", 0.0)
		s.is_lich_form        = d.get("is_lich_form", false)
		s.lich_mp_regen       = d.get("lich_mp_regen", 0.0)
		s.mana_drain          = d.get("mana_drain", 0.0)
		s.damage_shield_amount   = d.get("damage_shield_amount", 0.0)
		s.damage_shield_duration = d.get("damage_shield_duration", 0.0)
		s.is_song             = d.get("is_song", false)
		s.min_level           = d.get("min_level", 1)
		s.str_buff                  = d.get("str_buff", 0)
		s.agi_buff                  = d.get("agi_buff", 0)
		s.int_buff                  = d.get("int_buff", 0)
		s.wis_buff                  = d.get("wis_buff", 0)
		s.con_buff                  = d.get("con_buff", 0)
		s.max_hp_buff               = d.get("max_hp_buff", 0.0)
		s.max_mp_buff               = d.get("max_mp_buff", 0.0)
		s.primary_stat_buff_duration = d.get("primary_stat_buff_duration", 0.0)
		s.aoe_radius = d.get("aoe_radius", 0.0)
		s.rank      = d.get("rank", 1)
		s.base_name = d.get("base_name", "")
		# Discipline: exact name first, then fall back to base_name so rank II/III
		# spells don't need a separate DISCIPLINE entry.
		var disc: String = SpellDefinitions.DISCIPLINE.get(d["name"], "")
		if disc == "" and s.base_name != "":
			disc = SpellDefinitions.DISCIPLINE.get(s.base_name, "")
		s.discipline = disc
		for c in d["classes"]:
			s.allowed_classes.append(c)
		_all_spells[s.spell_name] = s

func _parse_damage_type(s: String) -> SpellData.DamageType:
	match s:
		"FIRE":      return SpellData.DamageType.FIRE
		"ICE":       return SpellData.DamageType.ICE
		"LIGHTNING": return SpellData.DamageType.LIGHTNING
		"ARCANE":    return SpellData.DamageType.ARCANE
		"HOLY":      return SpellData.DamageType.HOLY
		"NATURE":    return SpellData.DamageType.NATURE
		"SPIRIT":    return SpellData.DamageType.SPIRIT
		"SHADOW":    return SpellData.DamageType.SHADOW
	return SpellData.DamageType.NONE

func _parse_target_type(s: String) -> SpellData.TargetType:
	match s:
		"ENEMY":      return SpellData.TargetType.ENEMY
		"SELF":       return SpellData.TargetType.SELF
		"ALLY":       return SpellData.TargetType.ALLY
		"PET_SUMMON": return SpellData.TargetType.PET_SUMMON
		"PET_CHARM":  return SpellData.TargetType.PET_CHARM
		"PET_HEAL":   return SpellData.TargetType.PET_HEAL
		"PORT":       return SpellData.TargetType.PORT
		"BIND":       return SpellData.TargetType.BIND
		"AOE":        return SpellData.TargetType.AOE
		"CORPSE":     return SpellData.TargetType.CORPSE
	return SpellData.TargetType.NONE
