extends Node

# Bard songs (the rework of 2026-10-20, classic EQ's rules): one song is sung
# at a time, a 3 s sing, free; it pulses every PULSE_INTERVAL and each pulse's
# effect lingers LINGER after it. Twisting is cycling songs on those sings so
# several linger at once. The SERVER holds the active song and pulses it (the
# buffs arrive through BuffManager's snapshot reconcile, which calls
# apply_song_buffs); this node only remembers which song is sung, for the
# toggle and the UI.
#
# A song's strength scales with the bard's level (user, 2026-10-20): a
# fraction of the listed value when first learned, climbing to the full value
# at FULL_AT_LEVEL. The fraction is the song's own `song_scale_at_learn` when
# it has one (Selos' carries EQ's Selo's curve, +20% when learned of +65% at
# 50) and SCALE_AT_LEARN otherwise. The data carries the level-50 values. The
# four constants mirror the server's world/mod.rs SONG_* knobs; keep them in
# step by hand (check_constant_lockstep compares them; LINGER is not read on
# the client, which takes each pulse's remaining time from the snapshot).

signal songs_changed

const PULSE_INTERVAL := 6.0
const LINGER := 12.0
const SCALE_AT_LEARN := 0.4
const FULL_AT_LEVEL := 50

var _active_song: SpellData = null

func _ready() -> void:
	PlayerDeath.player_died.connect(stop_singing)
	ZoneLoader.zone_changed.connect(func(_z): stop_singing())

# The fraction of a song's listed effect a bard of `level` gets, the song
# first learned at `learn_level`: `at_learn` there, 1.0 from FULL_AT_LEVEL on,
# linear between (the server's songs::song_scale).
static func song_scale(level: int, learn_level: int, at_learn: float = SCALE_AT_LEARN) -> float:
	var full: int = maxi(FULL_AT_LEVEL, learn_level + 1)
	if level >= full:
		return 1.0
	var t: float = float(maxi(level - learn_level, 0)) / float(full - learn_level)
	return at_learn + (1.0 - at_learn) * t

# The scale for `spell` on the local player: its own start fraction when it
# has one, the global otherwise (the server's songs::scale_at_learn).
static func scale_for(spell: SpellData) -> float:
	var at_learn: float = spell.song_scale_at_learn if spell.song_scale_at_learn > 0.0 else SCALE_AT_LEARN
	return song_scale(PlayerStats.level, spell.required_level(PlayerStats.player_class), at_learn)

func stop_singing() -> void:
	if _active_song == null:
		return
	_active_song = null
	songs_changed.emit()

# A song's cast landed. The server has started (or, sung again, stopped) it
# and says so in chat; here only the bookkeeping.
func activate_song(spell: SpellData) -> void:
	if _active_song != null and _active_song.spell_name == spell.spell_name:
		_active_song = null
		songs_changed.emit()
		return
	_active_song = spell
	songs_changed.emit()

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
	var s := scale_for(spell)
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
