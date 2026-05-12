extends Node

# NetCombatBroadcaster — owning-client → server fan-out of combat-adjacent
# state. Resources (HP/MP/stamina) for Track 4 sub-task 1; later sub-tasks
# hang cast / buff / hit / death broadcasts off this same autoload.
#
# Trust model (Track 4): the client computing the value is the authority on
# it. We send when state changes, the server relays to other peers without
# validation. Server-authoritative combat lifts authority server-side in
# Track 6.
#
# Resource throttle: broadcast immediately when any single resource moved
# by >5% of its max in absolute value (big hits land instantly), otherwise
# coalesce small ticks behind a 250 ms minimum gap. Quiet state with no
# changes ⇒ no traffic.

# Tunables. 5% / 250 ms is the Track 4 starting point per the handoff;
# adjust by ear once the wire is live.
const DELTA_PCT_OF_MAX := 0.05
const MIN_GAP_MS := 250

var _last_bcast_hp: float = -1.0
var _last_bcast_max_hp: float = -1.0
var _last_bcast_mp: float = -1.0
var _last_bcast_max_mp: float = -1.0
var _last_bcast_stamina: float = -1.0
var _last_bcast_max_stamina: float = -1.0
var _last_bcast_time_ms: int = -1

var _last_cast_spell_name: String = ""

func _ready() -> void:
	PlayerStats.hp_changed.connect(_on_resource_changed)
	PlayerStats.mp_changed.connect(_on_resource_changed)
	PlayerStats.stamina_changed.connect(_on_resource_changed)
	PlayerStats.stats_changed.connect(_on_stats_changed)
	# Sub-task 2: cast bar replication. casting_started fires only for
	# spells with cast_time > 0 (instant casts skip directly to spell_cast).
	# spell_cast fires for both — we gate the complete-broadcast on
	# whether we previously sent a start.
	Spells.casting_started.connect(_on_casting_started)
	Spells.spell_cast.connect(_on_spell_cast)
	Spells.casting_cancelled.connect(_on_casting_cancelled)
	# No explicit hook on Net.app_connected — apply_character runs in lobby's
	# app-connected handler and its hp/mp/stamina signal cascade naturally
	# triggers the first broadcast with the server-authoritative values.
	# Forcing one earlier would send pre-apply default stats (100/100/100)
	# and the server would cache those briefly until the cascade overwrote
	# them. Cleaner to wait.

func _on_resource_changed(_current: float, _maximum: float) -> void:
	_maybe_broadcast()

func _on_stats_changed() -> void:
	# Gear / buffs that change max_* land here without firing hp_changed.
	_maybe_broadcast()

func _maybe_broadcast() -> void:
	if not Net.is_app_ready():
		return
	var any_change := (
		PlayerStats.hp != _last_bcast_hp
		or PlayerStats.max_hp != _last_bcast_max_hp
		or PlayerStats.mp != _last_bcast_mp
		or PlayerStats.max_mp != _last_bcast_max_mp
		or PlayerStats.stamina != _last_bcast_stamina
		or PlayerStats.max_stamina != _last_bcast_max_stamina
	)
	if not any_change:
		return
	var big_delta := (
		absf(PlayerStats.hp - _last_bcast_hp) > PlayerStats.max_hp * DELTA_PCT_OF_MAX
		or absf(PlayerStats.mp - _last_bcast_mp) > PlayerStats.max_mp * DELTA_PCT_OF_MAX
		or absf(PlayerStats.stamina - _last_bcast_stamina) > PlayerStats.max_stamina * DELTA_PCT_OF_MAX
	)
	var now_ms := Time.get_ticks_msec()
	var elapsed := now_ms - _last_bcast_time_ms
	if not big_delta and elapsed < MIN_GAP_MS:
		return
	_send(now_ms)

# ── Cast lifecycle ──────────────────────────────────────────────────

func _on_casting_started(spell: SpellData) -> void:
	if not Net.is_app_ready():
		return
	_last_cast_spell_name = spell.spell_name
	Net.broadcast_cast_start(spell.spell_name, spell.cast_time)

func _on_spell_cast(spell: SpellData) -> void:
	# spell_cast fires for both instant and cast-time spells; only the
	# cast-time path matched a prior casting_started broadcast, so only
	# that path needs a CastComplete on the wire.
	if not Net.is_app_ready():
		return
	if spell.cast_time <= 0.0:
		return
	Net.broadcast_cast_complete(spell.spell_name)
	_last_cast_spell_name = ""

func _on_casting_cancelled() -> void:
	if not Net.is_app_ready():
		return
	if _last_cast_spell_name == "":
		return
	# Cancel reason is currently always "interrupted" — Spells.gd has no
	# distinct paths for movement-cancel vs damage-interrupt today. When
	# it does, plumb the reason through.
	Net.broadcast_cast_fail("interrupted")
	_last_cast_spell_name = ""

func _send(now_ms: int) -> void:
	Net.broadcast_resources(
		PlayerStats.hp, PlayerStats.max_hp,
		PlayerStats.mp, PlayerStats.max_mp,
		PlayerStats.stamina, PlayerStats.max_stamina)
	_last_bcast_hp = PlayerStats.hp
	_last_bcast_max_hp = PlayerStats.max_hp
	_last_bcast_mp = PlayerStats.mp
	_last_bcast_max_mp = PlayerStats.max_mp
	_last_bcast_stamina = PlayerStats.stamina
	_last_bcast_max_stamina = PlayerStats.max_stamina
	_last_bcast_time_ms = now_ms
