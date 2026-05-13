extends Node

# NetCombatBroadcaster — owning-client → server fan-out of cast / buff
# state. Track 6 removed the resource-broadcast path: HP/MP/Stamina are now
# server-authoritative, so the client receives HealthUpdate / ManaUpdate /
# StaminaUpdate from the server rather than telling the server what they
# are. Cast bars and buff snapshots stay client-driven for now (sub-task 4
# lifts buff authority server-side).

var _last_cast_spell_name: String = ""

func _ready() -> void:
	# Sub-task 2: cast bar replication. casting_started fires only for
	# spells with cast_time > 0 (instant casts skip directly to spell_cast).
	# spell_cast fires for both — we gate the complete-broadcast on
	# whether we previously sent a start.
	Spells.casting_started.connect(_on_casting_started)
	Spells.spell_cast.connect(_on_spell_cast)
	Spells.casting_cancelled.connect(_on_casting_cancelled)
	# Sub-task 3: buff snapshot replication. BuffManager.buffs_changed
	# fires on every buff add/expire/clear; we send a fresh snapshot each
	# time. ~10 buffs × ~30 B per entry = ~300 B per change on the
	# reliable channel — negligible.
	BuffManager.buffs_changed.connect(_on_buffs_changed)

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

# ── Buff snapshot ───────────────────────────────────────────────────

func _on_buffs_changed() -> void:
	if not Net.is_app_ready():
		return
	var snap: Dictionary = BuffManager.get_snapshot_arrays()
	Net.broadcast_buff_snapshot(snap["names"], snap["durations"])
