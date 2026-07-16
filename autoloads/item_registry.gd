extends Node

# ItemRegistry — runtime index of every ItemData resource in
# `data/loot/items/`. Built once on _ready by scanning the directory
# and loading each .tres file; subsequent lookups are O(1) by lower-case
# item_name (exact match) or O(n) for substring fuzzy match (n ~ 100).
#
# Today's primary consumer is the `/give` chat command in hud.gd — dev
# workflow to drop any item into the inventory without hunting for
# specific test-panel buttons. Future: vendor pricing tables, quest
# reward indexing, item-stat search tools.

const ITEMS_DIR := "res://data/loot/items"

# Map of lower(item_name) -> ItemData (the template loaded from disk).
# Callers should duplicate before mutating to avoid sharing state across
# inventory slots — see give_by_name() for the canonical flow.
var _by_name: Dictionary = {}

func _ready() -> void:
	_scan_directory(ITEMS_DIR)
	# Surface the count via print() (visible in the console wrapper on
	# exported builds) AND DebugLog (editor mode). Empty registry usually
	# means the scan didn't see .tres/.res files — common cause is the
	# exported PCK uses a different layout than the editor. The /items
	# command also reports the count via CombatLog for in-game diagnosis.
	var msg := "ItemRegistry: indexed %d items from %s" % [_by_name.size(), ITEMS_DIR]
	print(msg)
	DebugLog.info(msg)
	if _by_name.is_empty():
		push_warning("ItemRegistry: no items found under %s — /give will fail" % ITEMS_DIR)

func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ItemRegistry: cannot open %s" % path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				_scan_directory(path + "/" + entry)
		# Accept both .tres (editor / un-exported) and .res (exported —
		# Godot 4's default preset converts text resources to binary).
		# Strip Godot's `.remap` suffix that appears on some exported
		# builds so the load() call can resolve the canonical path.
		elif entry.ends_with(".tres") or entry.ends_with(".res") or entry.ends_with(".tres.remap") or entry.ends_with(".res.remap"):
			var full := path + "/" + entry
			if full.ends_with(".remap"):
				full = full.substr(0, full.length() - ".remap".length())
			var res: Resource = load(full)
			if res == null:
				continue
			if res is ItemData:
				var item: ItemData = res
				if item.item_name != "":
					_by_name[item.item_name.to_lower()] = item
		entry = dir.get_next()
	dir.list_dir_end()

# Exact (case-insensitive) match by item_name. Returns the loaded
# template ItemData; caller must .duplicate() before mutating.
func find_exact(name: String) -> ItemData:
	return _by_name.get(name.to_lower())

# Substring fuzzy match. Returns up to `limit` items whose item_name
# contains `query` (case-insensitive). Useful for "/give iron" → see
# which "iron" items exist. Empty query returns empty result.
func find_matches(query: String, limit: int = 10) -> Array[ItemData]:
	var out: Array[ItemData] = []
	if query.strip_edges() == "":
		return out
	var needle := query.to_lower().strip_edges()
	# Exact match wins first.
	if _by_name.has(needle):
		out.append(_by_name[needle])
		return out
	# Then substring matches, alphabetised for deterministic UX.
	var sorted_keys := _by_name.keys()
	sorted_keys.sort()
	for k in sorted_keys:
		if needle in k:
			out.append(_by_name[k])
			if out.size() >= limit:
				break
	return out

# Dev convenience: resolve a name + add a fresh copy to the local
# inventory. Returns true on success, false if no match / inventory
# full / load failure. Multiple matches → returns false and the caller
# is expected to list ambiguity via find_matches() (the /give command
# handles this).
func give_by_name(name: String, count: int = 1) -> bool:
	var matches := find_matches(name, 2)
	if matches.size() != 1:
		return false
	var template: ItemData = matches[0]
	for _i in count:
		var copy: ItemData = template.duplicate()
		# Resource.duplicate() drops resource_path. Re-attach so the
		# Track 6 server-side items.toml lookup still resolves
		# (server reads weapon.resource_path from the Attack intent).
		copy.resource_path = template.resource_path
		if not Inventory.add_item(copy):
			return false
	return true

func count() -> int:
	return _by_name.size()

# Every indexed item template, sorted by display name. For dev/UI tools (the
# Test Panel item picker). Callers must .duplicate() before mutating.
func all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	var keys := _by_name.keys()
	keys.sort()
	for k in keys:
		out.append(_by_name[k])
	return out
