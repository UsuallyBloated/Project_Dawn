extends Node

# Bard songs (the rework of 2026-10-20, classic EQ's rules): one song is sung
# at a time, a 3 s sing, free; it pulses every PULSE_INTERVAL and each pulse's
# effect lingers LINGER after it. Twisting is cycling songs on those sings so
# several linger at once. Online the SERVER holds the active song and pulses it
# (the buffs arrive through BuffManager's snapshot reconcile, which calls
# apply_song_buffs); this node only remembers which song is sung, for the
# toggle and the UI. Offline (the Test Room) it pulses locally.
#
# A song's strength scales with the bard's level (user, 2026-10-20): a
# fraction of the listed value when first learned, climbing to the full value
# at FULL_AT_LEVEL. The fraction is Selo's own (EQ's Selo's Accelerando ran
# +20% when learned and +65% at 50; 20/65). The data carries the level-50
# values. The four constants mirror the server's world/mod.rs SONG_* knobs;
# keep them in step by hand.

signal songs_changed

const PULSE_INTERVAL := 6.0
const LINGER := 12.0
const SCALE_AT_LEARN := 0.31
const FULL_AT_LEVEL := 50

var _active_song: SpellData = null
var _pulse_timer: float = 0.0

func _ready() -> void:
	PlayerDeath.player_died.connect(stop_singing)
	ZoneLoader.zone_changed.connect(func(_z): stop_singing())

# The fraction of a song's listed effect a bard of `level` gets, the song
# first learned at `learn_level`: SCALE_AT_LEARN there, 1.0 from
# FULL_AT_LEVEL on, linear between (the server's songs::song_scale).
static func song_scale(level: int, learn_level: int) -> float:
	var full: int = maxi(FULL_AT_LEVEL, learn_level + 1)
	if level >= full:
		return 1.0
	var t: float = float(maxi(level - learn_level, 0)) / float(full - learn_level)
	return SCALE_AT_LEARN + (1.0 - SCALE_AT_LEARN) * t

func stop_singing() -> void:
	if _active_song == null:
		return
	_active_song = null
	_pulse_timer = 0.0
	songs_changed.emit()

func _process(delta: float) -> void:
	if _active_song == null or Net.is_launcher_mode():
		return
	_pulse_timer += delta
	if _pulse_timer >= PULSE_INTERVAL:
		_pulse_timer -= PULSE_INTERVAL
		_pulse(_active_song)

# A song's cast landed. Online the server has started (or, sung again,
# stopped) it and says so in chat; here only the bookkeeping. Offline the
# local pulse runs and the lines are printed here.
func activate_song(spell: SpellData) -> void:
	if _active_song != null and _active_song.spell_name == spell.spell_name:
		_active_song = null
		_pulse_timer = 0.0
		songs_changed.emit()
		if not Net.is_launcher_mode():
			CombatLog.add_line("You stop singing %s." % spell.spell_name, CombatLog.MsgType.INFO)
		return
	_active_song = spell
	_pulse_timer = 0.0
	songs_changed.emit()
	if Net.is_launcher_mode():
		return
	_pulse(spell)
	CombatLog.add_line("You begin singing %s." % spell.spell_name, CombatLog.MsgType.INFO)

# Any non-song cast stops the song (EQ's rule); online the server does the
# same and says so.
func on_non_song_cast() -> void:
	stop_singing()

func get_active_song() -> SpellData:
	return _active_song

# Put one pulse's effects on the local player for `remaining` seconds, scaled
# by level: the buffs the server applies (and fans in its snapshot), in the
# same buckets, so the buff bar shows them either way. The heal is a
# heal-over-time of the per-pulse heal spread over the pulse.
func apply_song_buffs(spell: SpellData, remaining: float) -> void:
	var s := song_scale(PlayerStats.level, spell.required_level(PlayerStats.player_class))
	if spell.heal_amount > 0.0:
		BuffManager.add_hot(spell.heal_amount * s / PULSE_INTERVAL, remaining, spell.spell_name)
	if spell.move_speed_mult > 1.0:
		BuffManager.add_speed_buff(1.0 + (spell.move_speed_mult - 1.0) * s, remaining, spell.spell_name)
	if spell.mp_regen_hps > 0.0:
		BuffManager.add_mp_regen_buff(spell.mp_regen_hps * s, remaining, spell.spell_name)
	if spell.haste_amount > 0.0:
		BuffManager.add_haste_buff(spell.haste_amount * s, remaining, spell.spell_name)
	if spell.accuracy_buff > 0.0 or spell.crit_buff > 0.0:
		BuffManager.add_stat_buff(spell.accuracy_buff * s, spell.crit_buff * s, remaining, spell.spell_name)

# The offline pulse: the buffs, and the ENEMY song's slow on the target.
func _pulse(spell: SpellData) -> void:
	apply_song_buffs(spell, LINGER)
	if spell.attack_slow_amount > 0.0 and Combat.has_valid_target():
		var s := song_scale(PlayerStats.level, spell.required_level(PlayerStats.player_class))
		Combat.current_target.apply_attack_slow(spell.attack_slow_amount * s, LINGER)
