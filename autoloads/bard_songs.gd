extends Node

# Bard Song Twist mechanic.
# Only one song "plays" at a time — casting a new song replaces the active one.
# The active song pulses its effect every PULSE_INTERVAL seconds.
# Its buff lingers for PULSE_INTERVAL + 0.5s so effects stay active even after
# the song stops, until the next expected pulse would have fired.
# Twist: by rapidly cycling 3-4 songs the player can keep all of their lingering
# buffs active simultaneously — the defining high-skill Bard mechanic.

signal songs_changed

const PULSE_INTERVAL := 3.0

var _active_song: SpellData = null
var _pulse_timer: float = 0.0

func _ready() -> void:
	PlayerDeath.player_died.connect(_stop)
	ZoneLoader.zone_changed.connect(func(_z): _stop())

func _stop() -> void:
	if _active_song == null:
		return
	_active_song = null
	_pulse_timer = 0.0
	songs_changed.emit()

func _process(delta: float) -> void:
	if _active_song == null:
		return
	_pulse_timer += delta
	if _pulse_timer >= PULSE_INTERVAL:
		_pulse_timer -= PULSE_INTERVAL
		_pulse(_active_song)

func activate_song(spell: SpellData) -> void:
	if _active_song != null and _active_song.spell_name == spell.spell_name:
		# Re-cast of the same song: toggle off
		_active_song = null
		_pulse_timer = 0.0
		songs_changed.emit()
		CombatLog.add_line("You stop singing %s." % spell.spell_name, CombatLog.MsgType.INFO)
		return

	_active_song = spell
	_pulse_timer = 0.0
	_pulse(spell)  # Immediate first pulse on activation
	songs_changed.emit()
	CombatLog.add_line("You begin singing %s." % spell.spell_name, CombatLog.MsgType.INFO)

func get_active_song() -> SpellData:
	return _active_song

func _pulse(spell: SpellData) -> void:
	var linger := PULSE_INTERVAL + 0.5

	if spell.heal_amount > 0.0:
		PlayerStats.set_hp(PlayerStats.hp + spell.heal_amount)

	if spell.move_speed_mult > 0.0:
		BuffManager.add_speed_buff(spell.move_speed_mult, linger, spell.spell_name)

	if spell.mp_regen_hps > 0.0:
		BuffManager.add_mp_regen_buff(spell.mp_regen_hps, linger, spell.spell_name)

	if spell.haste_amount > 0.0:
		BuffManager.add_haste_buff(spell.haste_amount, linger, spell.spell_name)

	if spell.absorb_amount > 0.0:
		BuffManager.add_absorb(spell.absorb_amount, spell.spell_name)
