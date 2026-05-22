extends Node

# Track 16.1 — spell-book → spell-bar memorize workflow. Tiny state
# layer between the spell book (which selects a spell) and the spell /
# hotkey bar (which becomes the assignment target on click). Both read
# `candidate` and listen for `candidate_changed`.
#
# Track 17.1 — memorize is no longer free. Slot assignment now goes
# through `commit(slot)`, which starts a 2 s memorize cast (visualised
# by the existing HUD cast bar), debits half the spell's mana cost on
# completion, and aborts on stand / movement / candidate-clear. The
# spell only lands in the bar when the cast completes — no half-paid
# assignments.

signal candidate_changed(spell)  # SpellData or null when cleared
signal memorize_started(spell: SpellData, duration: float)
signal memorize_progress(elapsed: float, total: float)
signal memorize_cancelled(reason: String)
signal memorize_completed(spell: SpellData, slot: int)

const MEMORIZE_CAST_TIME := 2.0
const MEMORIZE_COST_FACTOR := 0.5
# Allowed slack between the click-time position and the position at
# any tick during the cast. Sub-metre because sitting characters don't
# move except via stand → walk; if the player crosses 0.5 m the
# gesture is already broken.
const MEMORIZE_MOVE_CANCEL_DIST := 0.5

var candidate: SpellData = null

# Track 17.1 — in-flight memorize state.
var _committing: bool = false
var _commit_spell: SpellData = null
var _commit_slot: int = -1
var _commit_elapsed: float = 0.0
var _commit_start_pos: Vector3 = Vector3.ZERO
var _commit_mana_cost: float = 0.0

# Track 16.1 — clear the candidate when the player stops sitting.
# Standing breaks the memorize gesture (the rule is sit + book click +
# slot click; standing means the player abandoned the flow). Polled
# in _process because the player node doesn't exist at autoload
# _ready and rebinding on respawn / zone change would otherwise drop
# the subscription silently. Cost: one node lookup per frame.
var _player: PlayerCharacter = null
var _last_state: int = -1

func _process(delta: float) -> void:
	# 17.1 — memorize cast tick. Runs every frame while committing;
	# evaluates movement / state / candidate gates before advancing
	# time so a cancel cause is reported on the same frame it occurs.
	if _committing:
		_tick_commit(delta)
		return
	if candidate == null:
		# Nothing staged — skip the work; the bind catches up the
		# next time something is staged.
		return
	if not is_instance_valid(_player):
		_player = _find_local_player()
		if _player == null:
			return
		_last_state = _player.state
	if _player.state != _last_state:
		_last_state = _player.state
		if _player.state != PlayerCharacter.PlayerState.SITTING:
			clear()

func _find_local_player() -> PlayerCharacter:
	var nodes := get_tree().get_nodes_in_group("player")
	for n in nodes:
		if n is PlayerCharacter and (n as PlayerCharacter).is_multiplayer_authority():
			return n
	return null

func set_candidate(spell: SpellData) -> void:
	if candidate == spell:
		return
	candidate = spell
	# Selecting a new spell aborts any in-flight memorize of the old
	# one (no point paying for two memorizes per gesture).
	if _committing:
		_cancel_commit("changed selection")
	candidate_changed.emit(spell)

func clear() -> void:
	if _committing:
		_cancel_commit("cancelled")
	set_candidate(null)

# ── 17.1 commit flow ─────────────────────────────────────────────────

func can_commit(slot: int) -> Dictionary:
	# Returns { ok: bool, reason: String }. Lets the caller surface a
	# specific message ("not enough mana" vs "slot is locked").
	if candidate == null:
		return {"ok": false, "reason": "No spell selected."}
	if not SpellBar.is_slot_unlocked(slot):
		var lvl := SpellBar.unlock_level_for_slot(slot)
		return {"ok": false, "reason": "Slot %d unlocks at level %d." % [slot + 1, lvl]}
	if not is_instance_valid(_player):
		_player = _find_local_player()
	if _player == null or _player.state != PlayerCharacter.PlayerState.SITTING:
		return {"ok": false, "reason": "You must be sitting to memorize spells."}
	var cost := candidate.mana_cost * MEMORIZE_COST_FACTOR
	if PlayerStats.mp < cost:
		return {"ok": false, "reason": "Not enough mana to memorize."}
	return {"ok": true, "reason": ""}

func commit(slot: int) -> bool:
	var check := can_commit(slot)
	if not check["ok"]:
		CombatLog.add_line(check["reason"], CombatLog.MsgType.INFO)
		return false
	if _committing:
		# Re-issuing commit on the same slot is a no-op so a
		# double-click doesn't reset the bar partway through. A
		# different slot starts over.
		if _commit_slot == slot and _commit_spell == candidate:
			return true
		_cancel_commit("restarted")
	_committing = true
	_commit_spell = candidate
	_commit_slot = slot
	_commit_elapsed = 0.0
	_commit_mana_cost = candidate.mana_cost * MEMORIZE_COST_FACTOR
	_commit_start_pos = _player.global_position
	memorize_started.emit(_commit_spell, MEMORIZE_CAST_TIME)
	return true

func is_committing() -> bool:
	return _committing

func get_commit_spell() -> SpellData:
	return _commit_spell

func get_commit_slot() -> int:
	return _commit_slot

func _tick_commit(delta: float) -> void:
	if not is_instance_valid(_player):
		_cancel_commit("interrupted")
		return
	if _player.state != PlayerCharacter.PlayerState.SITTING:
		_cancel_commit("stood up")
		return
	if _player.global_position.distance_to(_commit_start_pos) > MEMORIZE_MOVE_CANCEL_DIST:
		_cancel_commit("moved")
		return
	if candidate != _commit_spell:
		# Candidate switched mid-cast (or was cleared). The set_candidate
		# path already calls _cancel_commit; this is the belt.
		_cancel_commit("changed selection")
		return
	_commit_elapsed = minf(_commit_elapsed + delta, MEMORIZE_CAST_TIME)
	memorize_progress.emit(_commit_elapsed, MEMORIZE_CAST_TIME)
	if _commit_elapsed >= MEMORIZE_CAST_TIME:
		_finish_commit()

func _finish_commit() -> void:
	# Final mana check — the player could have drained MP elsewhere
	# during the cast (proc damage shield, etc). If they're now short,
	# fail rather than overdraw.
	if PlayerStats.mp < _commit_mana_cost:
		_cancel_commit("not enough mana")
		return
	var spell := _commit_spell
	var slot := _commit_slot
	PlayerStats.set_mp(PlayerStats.mp - _commit_mana_cost)
	SpellBar.set_slot(slot, spell.spell_name)
	CombatLog.add_line(
		"You memorize %s into slot %d." % [spell.spell_name, slot + 1],
		CombatLog.MsgType.INFO,
	)
	_committing = false
	_commit_spell = null
	_commit_slot = -1
	_commit_elapsed = 0.0
	memorize_completed.emit(spell, slot)
	# Clear the candidate so the next click executes again instead of
	# restarting another memorize. The set_candidate guard already
	# skips _cancel_commit when _committing is false.
	set_candidate(null)

func _cancel_commit(reason: String) -> void:
	if not _committing:
		return
	_committing = false
	_commit_spell = null
	_commit_slot = -1
	_commit_elapsed = 0.0
	if reason != "cancelled" and reason != "restarted":
		CombatLog.add_line("Memorize interrupted (%s)." % reason, CombatLog.MsgType.INFO)
	memorize_cancelled.emit(reason)
