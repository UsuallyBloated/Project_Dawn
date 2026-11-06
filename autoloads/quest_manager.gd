extends Node

# The quest journal, a RENDERER (PD_W0024): the server tracks objectives in
# its own active_quests table, seeds the journal via QuestSnapshot on
# EnterWorld (so it survives relog/restart), drives progress via
# QuestProgress, and confirms turn-ins via QuestCompleted / QuestRejected.

signal quest_added(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal quest_removed(quest_id: String)

# READY = every tracked objective met, reward waiting at the turn-in NPC
# (classic EQ). Appended after FAILED so saved dicts keep their int values.
enum Status { ACTIVE, COMPLETED, FAILED, READY }

# Quest dict shape:
#   id: String, name: String, description: String,
#   objectives: Array[{
#     text: String, done: bool,
#     type: String ("", "kill", "collect"),  -- optional; "" = manual only
#     target: String,                        -- mob_name or item_name to match
#     count_needed: int, count_done: int     -- progress tracking
#   }],
#   status: Status, zone: String, level_req: int, reward_tier: String,
#   turn_in_npc: String
var _quests: Dictionary = {}  # id -> quest dict
# Every quest id the SERVER says this character has ever completed — includes
# quests finished before a relog that have no journal entry. Answers
# get_quest_status so dialogue hides re-offers of finished quests.
var _completed_ids: Dictionary = {}  # id -> true

# `from_server` marks a snapshot-driven rebuild: skip the AcceptQuest echo
# (the server already tracks these — re-accepting would just be noise).
func add_quest(quest_data: Dictionary, from_server: bool = false) -> bool:
	var id: String = quest_data.get("id", "")
	if id == "" or _quests.has(id):
		return false
	var objectives: Array = []
	for raw_obj in quest_data.get("objectives", []):
		var obj: Dictionary = (raw_obj as Dictionary).duplicate()
		if not obj.has("type"):         obj["type"]         = ""
		if not obj.has("target"):       obj["target"]       = ""
		if not obj.has("count_needed"): obj["count_needed"] = 1
		if not obj.has("count_done"):   obj["count_done"]   = 0
		if not obj.has("done"):         obj["done"]         = false
		obj["_base_text"] = obj.get("text", "")
		if obj["type"] in ["kill", "collect"] and obj["count_needed"] > 1:
			obj["text"] = "%s: 0 / %d" % [obj["_base_text"], obj["count_needed"]]
		objectives.append(obj)
	var q := {
		"id":           id,
		"name":         quest_data.get("name", id),
		"description":  quest_data.get("description", ""),
		"objectives":   objectives,
		"status":       Status.ACTIVE,
		"zone":         quest_data.get("zone", ""),
		"level_req":    quest_data.get("level_req", 1),
		"reward_tier":  quest_data.get("reward_tier", "standard"),
		"item_rewards": quest_data.get("item_rewards", []),
		"turn_in_npc":  quest_data.get("turn_in_npc", ""),
	}
	_quests[id] = q
	# PD_W0024 — tell the server to start counting (optimistic add: a
	# QuestRejected reply rolls this entry back via on_server_rejected).
	if not from_server:
		Net.accept_quest(id)
	quest_added.emit(id)
	return true

# ── PD_W0024: server-driven journal ───────────────────────────

# Rebuild the journal from the server's authoritative snapshot (sent privately
# on EnterWorld). Active quests rebuild from QuestDefinitions by id with the
# server's per-objective counts; completed ids materialize into the Completed
# tab. Replaces any pre-snapshot state.
func apply_server_snapshot(active_ids: PackedStringArray, objective_counts: PackedInt32Array, progress_flat: PackedInt32Array, completed: PackedStringArray) -> void:
	_quests.clear()
	_completed_ids.clear()
	for id in completed:
		_completed_ids[id] = true
		var def: Dictionary = QuestDefinitions.ALL.get(id, {})
		if def.is_empty():
			continue  # unknown to this client build; get_quest_status still answers via _completed_ids
		add_quest(def, true)
		var q: Dictionary = _quests[id]
		q["status"] = Status.COMPLETED
		_mark_objectives_satisfied(q)
	var flat_i := 0
	for i in active_ids.size():
		var id := active_ids[i]
		var n := objective_counts[i]
		var def: Dictionary = QuestDefinitions.ALL.get(id, {})
		if def.is_empty():
			DebugLog.warn("QuestSnapshot: unknown quest id '%s' (client data out of date?)" % id)
			flat_i += n
			continue
		add_quest(def, true)
		var q: Dictionary = _quests[id]
		for j in n:
			var count: int = progress_flat[flat_i + j] if flat_i + j < progress_flat.size() else 0
			var obj := _tracked_objective(q, j)
			if obj.is_empty():
				continue
			obj["count_done"] = mini(count, obj["count_needed"])
			obj["text"] = "%s: %d / %d" % [obj["_base_text"], obj["count_done"], obj["count_needed"]]
			obj["done"] = obj["count_done"] >= obj["count_needed"]
		flat_i += n
		_check_ready(q)
		quest_updated.emit(id)

# One objective counter moved (the server counted a kill). `count` is the new
# absolute value; index is into the server's objective list, which counts only
# TRACKED (kill-type) objectives.
func apply_server_progress(quest_id: String, objective_index: int, count: int) -> void:
	if not _quests.has(quest_id):
		return
	var q: Dictionary = _quests[quest_id]
	if q["status"] != Status.ACTIVE:
		return
	var obj := _tracked_objective(q, objective_index)
	if obj.is_empty():
		return
	obj["count_done"] = mini(count, obj["count_needed"])
	obj["text"] = "%s: %d / %d" % [obj["_base_text"], obj["count_done"], obj["count_needed"]]
	obj["done"] = obj["count_done"] >= obj["count_needed"]
	quest_updated.emit(quest_id)
	_check_ready(q)

# The server confirmed a turn-in paid out. Its reward XP arrives right after via
# XpGained; flag the next XP as quest-sourced so the chat line reads "quest
# experience" instead of the generic kill/party wording (the server sends
# QuestCompleted just BEFORE the XpGained, so this lands first). Item rewards
# are the server's and arrive as InventoryDelta.
func on_server_completed(quest_id: String) -> void:
	_completed_ids[quest_id] = true
	PlayerStats.note_next_xp_source("quest")
	if not _quests.has(quest_id):
		return
	var q: Dictionary = _quests[quest_id]
	if q["status"] == Status.COMPLETED:
		return
	q["status"] = Status.COMPLETED
	_mark_objectives_satisfied(q)
	CombatLog.add_line("Quest complete: %s!" % q["name"], CombatLog.MsgType.INFO)
	quest_completed.emit(quest_id)

# Mark every objective met and pin its count to the requirement, so a completed
# quest's detail panel reads "5 / 5" rather than a checked-but-"0 / 5" row (which
# happens when a completed quest is rebuilt from a QuestSnapshot after relog,
# since the snapshot carries no per-objective counts for finished quests).
func _mark_objectives_satisfied(q: Dictionary) -> void:
	for obj in q["objectives"]:
		obj["done"] = true
		if obj["type"] in ["kill", "collect"]:
			obj["count_done"] = obj["count_needed"]
			obj["text"] = "%s: %d / %d" % [obj["_base_text"], obj["count_needed"], obj["count_needed"]]

# The server refused an accept / abandon / turn-in. Always show why. `rollback`
# is the server's own signal (accept-phase only) that it never started tracking
# this quest, so the optimistic add must be undone; a turn-in rejection sends
# rollback=false and leaves the still-tracked entry alone. The server decides,
# not a fragile client-side reason-string match.
func on_server_rejected(quest_id: String, reason: String, rollback: bool) -> void:
	var q: Dictionary = _quests.get(quest_id, {})
	var label: String = q.get("name", quest_id)
	CombatLog.add_line("%s: %s" % [label, reason], CombatLog.MsgType.INFO)
	if rollback and not q.is_empty():
		_quests.erase(quest_id)
		quest_removed.emit(quest_id)

# Drop an active quest (journal Abandon button). Progress is forgotten
# server-side; re-accepting starts at zero. The pay-once completion record is
# untouched, so this can never re-open a payout.
func abandon_quest(quest_id: String) -> void:
	if not _quests.has(quest_id):
		return
	var q: Dictionary = _quests[quest_id]
	if q["status"] != Status.ACTIVE and q["status"] != Status.READY:
		return
	_quests.erase(quest_id)
	Net.abandon_quest(quest_id)
	CombatLog.add_line("Quest abandoned: %s." % q["name"], CombatLog.MsgType.INFO)
	quest_removed.emit(quest_id)

# Server objective indices count only TRACKED (kill-type) objectives, in
# authored order — flavor lines (type "") aren't server-counted; the turn-in
# itself is that step. Map a server index onto the matching journal objective.
func _tracked_objective(q: Dictionary, server_index: int) -> Dictionary:
	var i := 0
	for obj in q["objectives"]:
		if obj["type"] == "kill":
			if i == server_index:
				return obj
			i += 1
	return {}

# ACTIVE -> READY once every tracked objective is met: the reward now waits at
# the turn-in NPC (classic EQ). Flavor objectives don't gate READY.
func _check_ready(q: Dictionary) -> void:
	if q["status"] != Status.ACTIVE:
		return
	for obj in q["objectives"]:
		if obj["type"] == "kill" and not obj["done"]:
			return
	q["status"] = Status.READY
	var where: String = q.get("turn_in_npc", "")
	if where == "":
		where = "the quest giver"
	CombatLog.add_line("Objectives complete: %s. Return to %s." % [q["name"], where], CombatLog.MsgType.INFO)
	quest_updated.emit(q["id"])

func complete_quest(quest_id: String) -> void:
	if not _quests.has(quest_id):
		# Already completed on a prior login (no journal entry, only the
		# completed-id record). Give feedback rather than a silent no-op — this
		# is the Test Panel "Complete Test Quest" re-click after a relog.
		if _completed_ids.has(quest_id):
			CombatLog.add_line("You have already completed this quest.", CombatLog.MsgType.INFO)
		return
	var q: Dictionary = _quests[quest_id]
	if q["status"] == Status.COMPLETED:
		# Completed this session and still in the journal — same feedback so the
		# turn-in gesture never silently does nothing.
		CombatLog.add_line("You have already completed %s." % q["name"], CombatLog.MsgType.INFO)
		return
	# PD_W0024 — this only REQUESTS the turn-in. The server verifies its own
	# objective counts and answers QuestCompleted (flipped in
	# on_server_completed) or QuestRejected (a visible reason line). Nothing
	# is granted or flipped optimistically.
	if not Net.complete_quest(quest_id):
		CombatLog.add_line("Cannot turn in %s — not connected." % q["name"], CombatLog.MsgType.INFO)

func get_quest_status(quest_id: String) -> int:
	if _quests.has(quest_id):
		return _quests[quest_id]["status"]
	if _completed_ids.has(quest_id):
		return Status.COMPLETED  # completed on the server (e.g. before a relog)
	return -1   # -1 = not accepted

func fail_quest(quest_id: String) -> void:
	if not _quests.has(quest_id):
		return
	_quests[quest_id]["status"] = Status.FAILED
	quest_failed.emit(quest_id)

func get_quest(quest_id: String) -> Dictionary:
	return _quests.get(quest_id, {})

func get_active_quests() -> Array:
	var result: Array = []
	for q in _quests.values():
		# READY (done, awaiting the NPC turn-in) still lives in the Active tab.
		if q["status"] == Status.ACTIVE or q["status"] == Status.READY:
			result.append(q)
	return result

func get_completed_quests() -> Array:
	var result: Array = []
	for q in _quests.values():
		if q["status"] == Status.COMPLETED:
			result.append(q)
	return result
