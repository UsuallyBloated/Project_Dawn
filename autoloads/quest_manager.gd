extends Node

signal quest_added(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

enum Status { ACTIVE, COMPLETED, FAILED }

# Quest dict shape:
#   id: String, name: String, description: String,
#   objectives: Array[{
#     text: String, done: bool,
#     type: String ("", "kill", "collect"),  -- optional; "" = manual only
#     target: String,                        -- mob_name or item_name to match
#     count_needed: int, count_done: int     -- progress tracking
#   }],
#   status: Status, zone: String, level_req: int, reward_tier: String
var _quests: Dictionary = {}  # id -> quest dict

func add_quest(quest_data: Dictionary) -> bool:
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
	}
	_quests[id] = q
	quest_added.emit(id)
	return true

func notify_kill(mob_name: String) -> void:
	for q in _quests.values():
		if q["status"] != Status.ACTIVE:
			continue
		for obj in q["objectives"]:
			if obj["done"] or obj["type"] != "kill":
				continue
			if obj["target"].to_lower() in mob_name.to_lower() or mob_name.to_lower() in obj["target"].to_lower():
				obj["count_done"] = mini(obj["count_done"] + 1, obj["count_needed"])
				obj["text"] = "%s: %d / %d" % [obj["_base_text"], obj["count_done"], obj["count_needed"]]
				if obj["count_done"] >= obj["count_needed"]:
					obj["done"] = true
				quest_updated.emit(q["id"])
				if _all_objectives_done(q):
					complete_quest(q["id"])

func notify_collect(item_name: String) -> void:
	for q in _quests.values():
		if q["status"] != Status.ACTIVE:
			continue
		for obj in q["objectives"]:
			if obj["done"] or obj["type"] != "collect":
				continue
			if obj["target"] == item_name:
				obj["count_done"] = mini(obj["count_done"] + 1, obj["count_needed"])
				obj["text"] = "%s: %d / %d" % [obj["_base_text"], obj["count_done"], obj["count_needed"]]
				if obj["count_done"] >= obj["count_needed"]:
					obj["done"] = true
				quest_updated.emit(q["id"])
				if _all_objectives_done(q):
					complete_quest(q["id"])

func complete_objective(quest_id: String, obj_index: int) -> void:
	if not _quests.has(quest_id):
		return
	var q: Dictionary = _quests[quest_id]
	if q["status"] != Status.ACTIVE:
		return
	if obj_index < 0 or obj_index >= q["objectives"].size():
		return
	q["objectives"][obj_index]["done"] = true
	quest_updated.emit(quest_id)
	if _all_objectives_done(q):
		complete_quest(quest_id)

func complete_quest(quest_id: String) -> void:
	if not _quests.has(quest_id):
		return
	var q: Dictionary = _quests[quest_id]
	if q["status"] == Status.COMPLETED:
		return
	q["status"] = Status.COMPLETED
	var xp: int = QuestDefinitions.xp_reward_for(q.get("reward_tier", ""), q.get("level_req", 1))
	if xp > 0:
		# PD_W0018 — in launcher mode the server owns xp/leveling, so report the
		# reward and let it apply (the server replies with XpGained / LevelUp).
		# Test Room / no-server still grants locally.
		if Net.is_launcher_mode():
			Net.grant_quest_xp(xp)
		else:
			PlayerStats.gain_xp(xp, "quest")
		CombatLog.add_line("Quest complete: %s!" % q["name"], CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("Quest complete: %s!" % q["name"], CombatLog.MsgType.INFO)
	for d: Dictionary in q.get("item_rewards", []):
		var item := _make_reward_item(d)
		if not Inventory.add_item(item, 1):
			CombatLog.add_line("Inventory full — could not receive %s." % item.item_name, CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("You receive: %s." % item.item_name, CombatLog.MsgType.INFO)
	quest_completed.emit(quest_id)

func get_quest_status(quest_id: String) -> int:
	if not _quests.has(quest_id):
		return -1   # -1 = not accepted
	return _quests[quest_id]["status"]

func _make_reward_item(d: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.item_name          = d.get("name", "Unknown")
	item.description        = d.get("desc", "")
	item.vendor_price       = d.get("vendor_price", 0)
	item.bonus_strength     = d.get("bonus_strength", 0)
	item.bonus_agility      = d.get("bonus_agility", 0)
	item.bonus_dexterity    = d.get("bonus_dexterity", 0)
	item.bonus_intelligence = d.get("bonus_intelligence", 0)
	item.bonus_wisdom       = d.get("bonus_wisdom", 0)
	item.bonus_constitution = d.get("bonus_constitution", 0)
	item.bonus_max_hp       = d.get("bonus_max_hp", 0.0)
	item.bonus_max_mp       = d.get("bonus_max_mp", 0.0)
	item.bonus_armor        = d.get("bonus_armor", 0)
	match d.get("type", "MISC"):
		"WEAPON":  item.type = ItemData.Type.WEAPON
		"HEAD":    item.type = ItemData.Type.HEAD
		"CHEST":   item.type = ItemData.Type.CHEST
		"LEGS":    item.type = ItemData.Type.LEGS
		"FEET":    item.type = ItemData.Type.FEET
		"HANDS":   item.type = ItemData.Type.HANDS
		"RING":    item.type = ItemData.Type.RING
		"NECK":    item.type = ItemData.Type.NECK
		_:         item.type = ItemData.Type.MISC
	match d.get("rarity", "COMMON"):
		"UNCOMMON": item.rarity = ItemData.Rarity.UNCOMMON
		"RARE":     item.rarity = ItemData.Rarity.RARE
		"EPIC":     item.rarity = ItemData.Rarity.EPIC
		_:          item.rarity = ItemData.Rarity.COMMON
	return item

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
		if q["status"] == Status.ACTIVE:
			result.append(q)
	return result

func get_completed_quests() -> Array:
	var result: Array = []
	for q in _quests.values():
		if q["status"] == Status.COMPLETED:
			result.append(q)
	return result

func _all_objectives_done(q: Dictionary) -> bool:
	for obj in q["objectives"]:
		if not obj["done"]:
			return false
	return true

# ── Save / load (Tier 1 persistence) ──────────────────────────────────────────

func save_state() -> Dictionary:
	return {"quests": _quests.duplicate(true)}

func load_state(d: Dictionary) -> void:
	_quests.clear()
	var saved: Dictionary = d.get("quests", {})
	for id in saved:
		_quests[id] = (saved[id] as Dictionary).duplicate(true)
		quest_added.emit(id)
