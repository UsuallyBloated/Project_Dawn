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
	# Track 6 sub-task 4a removed the client-driven BuffSnapshot. The
	# server originates BuffSnapshot from its own active_buffs state
	# whenever buffs change server-side (HoT applied via CastSpell,
	# MP regen buff, Lich Form toggle, expiration). BuffManager
	# .buffs_changed still fires for client-side HUD updates; we just
	# don't send the snapshot upstream anymore.
	# No armor sync: the server works out armor from the equipment it
	# holds, and ignored the client's EquipUpdate. Sending it on every gear
	# change (eight at once when a death strips the gear) also drew the
	# dead-state gate's refusal for nothing (playtest 2026-10-26).

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
# (Track 6 sub-task 4a removed _on_buffs_changed — server originates
# BuffSnapshot from its active_buffs state via tick.rs step 5a. The
# Net.broadcast_buff_snapshot wrapper stays for now but is unused;
# sub-task 4b removes the wire variant entirely.)

