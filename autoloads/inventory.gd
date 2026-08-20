extends Node

signal inventory_changed
signal item_added(item: ItemData)
signal item_removed(item: ItemData)

const BASE_SLOT_COUNT := 8

# 8 base inventory slots. Each: null | { "item": ItemData, "count": int }
# Bags live here too (count is always 1 for bags).
var base_slots: Array = []

# Parallel to base_slots.
# When base_slots[i] holds a BAG, bag_contents[i] is Array[bag.bag_num_slots].
# Otherwise bag_contents[i] is null.
var bag_contents: Array = []

func _ready() -> void:
	base_slots.resize(BASE_SLOT_COUNT)
	base_slots.fill(null)
	bag_contents.resize(BASE_SLOT_COUNT)
	bag_contents.fill(null)
	# Track 13.2 — in launcher mode the server is authoritative. The
	# InventorySnapshot fired privately on EnterWorld seeds us with
	# whatever was persisted; subsequent server-side mutations
	# (loot, MoveItem, drop) arrive as InventoryDelta.
	Net.world_inventory_snapshot.connect(_on_inventory_snapshot)
	Net.world_inventory_delta.connect(_on_inventory_delta)

# Track 13.2 / 14.3 — apply a server-authoritative snapshot. Wipes
# the current base_slots / bag_contents and rebuilds from the wire
# tuples. Track 13.3 routes 'equip' entries to Equipment; Track
# 14.3 routes 'bag_<i>' entries into bag_contents (via a two-pass
# walk so the bag's parent base entry — which determines the
# inner Vec's size from item.bag_num_slots — is in place before
# its contents arrive).
# In solo / Test Room mode Net never fires this signal so the
# legacy local autoload state is preserved.
func _on_inventory_snapshot(
		locations: PackedStringArray,
		slots: PackedInt32Array,
		item_paths: PackedStringArray,
		counts: PackedInt32Array) -> void:
	base_slots.fill(null)
	bag_contents.fill(null)
	# Track 13.3 — clear the paperdoll before re-applying. Server
	# is authoritative here too; any stale Equipment state from a
	# prior session is wiped.
	Equipment.apply_remote_snapshot_clear()
	var n: int = mini(mini(locations.size(), slots.size()), mini(item_paths.size(), counts.size()))
	# Pass 1 — base + equip. Bag entries hit _init_bag_contents
	# via set_base_slot's normal path so pass 2 has somewhere to
	# write.
	for i in n:
		var loc: String = locations[i]
		var slot_idx: int = slots[i]
		var path: String = item_paths[i]
		var count: int = counts[i]
		if path == "" or count <= 0:
			continue
		var item := load(path) as ItemData
		if item == null:
			push_warning("Inventory snapshot: unknown ItemData path '%s'" % path)
			continue
		if loc == NetProtocol.INV_LOCATION_BASE:
			if slot_idx < 0 or slot_idx >= BASE_SLOT_COUNT:
				continue
			base_slots[slot_idx] = {"item": item, "count": count}
			if item.type == ItemData.Type.BAG and bag_contents[slot_idx] == null:
				_init_bag_contents(slot_idx, item.bag_num_slots)
		elif loc == NetProtocol.INV_LOCATION_EQUIP:
			Equipment.apply_remote_equip(slot_idx, item)
	# Pass 2 — bag_<i> entries. Skip rows whose parent base slot
	# turned out not to hold a bag.
	for i in n:
		var loc: String = locations[i]
		if not loc.begins_with("bag_"):
			continue
		var base_idx: int = loc.trim_prefix("bag_").to_int()
		if base_idx < 0 or base_idx >= BASE_SLOT_COUNT:
			continue
		if bag_contents[base_idx] == null:
			continue  # parent base slot wasn't a bag this snapshot.
		var arr: Array = bag_contents[base_idx]
		var slot_idx: int = slots[i]
		var path: String = item_paths[i]
		var count: int = counts[i]
		if path == "" or count <= 0:
			continue
		if slot_idx < 0 or slot_idx >= arr.size():
			continue
		var item := load(path) as ItemData
		if item == null:
			push_warning("Inventory snapshot: unknown bag-inner ItemData path '%s'" % path)
			continue
		arr[slot_idx] = {"item": item, "count": count}
	inventory_changed.emit()

# Track 13.2 / 14.3 — apply a single-slot mutation. Empty
# `item_path` clears the slot; non-empty sets it to (item_path,
# count). Track 13.3 routes 'equip' to Equipment; Track 14.3
# routes 'bag_<i>' into bag_contents[i].
func _on_inventory_delta(location: String, slot: int, item_path: String, count: int) -> void:
	if location == NetProtocol.INV_LOCATION_BASE:
		if slot < 0 or slot >= BASE_SLOT_COUNT:
			return
		if item_path == "" or count <= 0:
			# Track 14.3 — clearing a base slot also drops any bag
			# contents Vec attached to it. The server side ensures a
			# non-empty bag can't reach this delta (move/drop rules
			# reject), so dropping the Vec here can't orphan items.
			base_slots[slot] = null
			bag_contents[slot] = null
		else:
			var item := load(item_path) as ItemData
			if item == null:
				push_warning("Inventory delta: unknown ItemData path '%s'" % item_path)
				return
			base_slots[slot] = {"item": item, "count": count}
			# Track 14.3 — a bag landing in this slot needs its
			# inner Vec allocated so subsequent bag_<i> deltas have
			# somewhere to write. Non-bag items get their Vec
			# cleared.
			if item.type == ItemData.Type.BAG:
				if bag_contents[slot] == null:
					_init_bag_contents(slot, item.bag_num_slots)
			else:
				bag_contents[slot] = null
		inventory_changed.emit()
		return
	if location == NetProtocol.INV_LOCATION_EQUIP:
		if item_path == "" or count <= 0:
			Equipment.apply_remote_unequip(slot)
		else:
			var item := load(item_path) as ItemData
			if item == null:
				push_warning("Inventory delta: unknown ItemData path '%s'" % item_path)
				return
			Equipment.apply_remote_equip(slot, item)
		return
	# Track 14.3 — bag_<i> delta.
	if location.begins_with("bag_"):
		var base_idx: int = location.trim_prefix("bag_").to_int()
		if base_idx < 0 or base_idx >= BASE_SLOT_COUNT:
			return
		# The server is authoritative: if it is telling us what is inside a bag,
		# that bag exists. This used to drop the delta whenever our own view
		# disagreed, on the stated assumption that "the next snapshot will
		# resync" — but there is no periodic snapshot, only the one at
		# enter-world, so the discarded update was gone for good and the client
		# stayed wrong until relog. A playtest on 2026-08-18 caught exactly that:
		# items rendered as vanished while the server held them safely.
		# Make room and apply it instead, and log it, because needing this at all
		# means our base slots were already out of step.
		if bag_contents[base_idx] == null:
			var host = base_slots[base_idx]
			var want: int = slot + 1
			if host != null and host["item"].type == ItemData.Type.BAG:
				want = maxi(int(host["item"].bag_num_slots), slot + 1)
			else:
				DebugLog.warn("Inventory: bag_%d delta arrived but base slot %d holds no bag; client view was stale" % [base_idx, base_idx])
			_init_bag_contents(base_idx, want)
		var arr: Array = bag_contents[base_idx]
		if slot < 0:
			return
		if slot >= arr.size():
			# Same reasoning: grow rather than discard the server's truth.
			DebugLog.warn("Inventory: bag_%d slot %d is beyond the known size %d; growing" % [base_idx, slot, arr.size()])
			arr.resize(slot + 1)
		if item_path == "" or count <= 0:
			arr[slot] = null
		else:
			var item := load(item_path) as ItemData
			if item == null:
				push_warning("Inventory delta: unknown bag-inner ItemData path '%s'" % item_path)
				return
			arr[slot] = {"item": item, "count": count}
		inventory_changed.emit()

# ── Base slot API (used by InventoryWindow) ───────────────────────────────────

func get_base_slot(i: int) -> Variant:
	return base_slots[i]

func set_base_slot(i: int, val: Variant) -> void:
	base_slots[i] = val
	if val == null or val["item"].type != ItemData.Type.BAG:
		bag_contents[i] = null
	elif bag_contents[i] == null:
		_init_bag_contents(i, val["item"].bag_num_slots)
	inventory_changed.emit()

func clear_base_slot(i: int) -> void:
	base_slots[i] = null
	bag_contents[i] = null
	inventory_changed.emit()

func remove_base_at(i: int) -> void:
	if base_slots[i] == null:
		return
	var item: ItemData = base_slots[i]["item"]
	base_slots[i] = null
	bag_contents[i] = null
	inventory_changed.emit()
	item_removed.emit(item)

# ── Bag slot API (used by BagWindow) ─────────────────────────────────────────
# bag_base_index = the base slot index that holds the bag.

func get_slot(bag_base_index: int, slot_index: int) -> Variant:
	if bag_contents[bag_base_index] == null:
		return null
	return bag_contents[bag_base_index][slot_index]

## True when the bag in base slot `bag_base_index` still holds something.
## Mirrors the server's `bag_at_base_is_nonempty` (world/inventory.rs), which
## rejects moving or dropping a non-empty bag. The UI checks this so the refusal
## is immediate and explained rather than a silent server-side rejection.
func bag_has_contents(bag_base_index: int) -> bool:
	if bag_base_index < 0 or bag_base_index >= bag_contents.size():
		return false
	var arr = bag_contents[bag_base_index]
	if arr == null:
		return false
	for entry in arr:
		if entry != null:
			return true
	return false

func set_slot(bag_base_index: int, slot_index: int, val: Variant) -> void:
	if bag_contents[bag_base_index] == null:
		return
	bag_contents[bag_base_index][slot_index] = val
	inventory_changed.emit()

func clear_slot(bag_base_index: int, slot_index: int) -> void:
	if bag_contents[bag_base_index] == null:
		return
	bag_contents[bag_base_index][slot_index] = null
	inventory_changed.emit()

func remove_at(bag_base_index: int, slot_index: int) -> void:
	if bag_contents[bag_base_index] == null:
		return
	var arr: Array = bag_contents[bag_base_index]
	if arr[slot_index] == null:
		return
	var item: ItemData = arr[slot_index]["item"]
	arr[slot_index] = null
	inventory_changed.emit()
	item_removed.emit(item)

# ── add_item ──────────────────────────────────────────────────────────────────

func add_item(item: ItemData, count: int = 1) -> bool:
	# Bags go in base slots only — no bag-in-bag.
	if item.type == ItemData.Type.BAG:
		for i in BASE_SLOT_COUNT:
			if base_slots[i] == null:
				base_slots[i] = {"item": item, "count": 1}
				_init_bag_contents(i, item.bag_num_slots)
				inventory_changed.emit()
				item_added.emit(item)
				return true
		return false

	# Try to top-up existing stacks: base slots first, then bag slots.
	if item.stack_size > 1:
		for i in BASE_SLOT_COUNT:
			if base_slots[i] != null and base_slots[i]["item"].item_name == item.item_name:
				var space := item.stack_size - int(base_slots[i]["count"])
				if space > 0:
					var add := mini(count, space)
					base_slots[i]["count"] += add
					count -= add
					if count == 0:
						inventory_changed.emit()
						item_added.emit(item)
						return true
		for i in BASE_SLOT_COUNT:
			if bag_contents[i] == null:
				continue
			var arr: Array = bag_contents[i]
			for j in arr.size():
				if arr[j] != null and arr[j]["item"].item_name == item.item_name:
					var space := item.stack_size - int(arr[j]["count"])
					if space > 0:
						var add := mini(count, space)
						arr[j]["count"] += add
						count -= add
						if count == 0:
							inventory_changed.emit()
							item_added.emit(item)
							return true

	# Place remainder in first free slot.
	while count > 0:
		var found := _first_free_slot()
		if found.is_empty():
			return false
		var batch := mini(count, item.stack_size)
		if found.size() == 1:
			base_slots[found[0]] = {"item": item, "count": batch}
		else:
			bag_contents[found[0]][found[1]] = {"item": item, "count": batch}
		count -= batch

	inventory_changed.emit()
	item_added.emit(item)
	return true

# ── remove_item ───────────────────────────────────────────────────────────────

func remove_item(item: ItemData, count: int = 1) -> bool:
	var remaining := count
	for i in BASE_SLOT_COUNT:
		if remaining == 0:
			break
		if base_slots[i] != null and base_slots[i]["item"].item_name == item.item_name:
			var take := mini(remaining, int(base_slots[i]["count"]))
			base_slots[i]["count"] -= take
			remaining -= take
			if base_slots[i]["count"] == 0:
				base_slots[i] = null
	for i in BASE_SLOT_COUNT:
		if remaining == 0:
			break
		if bag_contents[i] == null:
			continue
		var arr: Array = bag_contents[i]
		for j in arr.size():
			if remaining == 0:
				break
			if arr[j] != null and arr[j]["item"].item_name == item.item_name:
				var take := mini(remaining, int(arr[j]["count"]))
				arr[j]["count"] -= take
				remaining -= take
				if arr[j]["count"] == 0:
					arr[j] = null
	if remaining < count:
		inventory_changed.emit()
		item_removed.emit(item)
		return true
	return false

# ── stack_all ─────────────────────────────────────────────────────────────────

## Consolidate stackable items into the fewest stacks.
##
## Hosted play routes every merge through the server. It used to rewrite
## base_slots and bag_contents directly and tell the server nothing, which in
## launcher mode desynced the whole inventory in one click: the client's view
## became fiction while the server still held the original layout, so every
## later move from a now-phantom slot was refused. That is the origin of the
## 2026-08-18 "items get hung up / items vanished" reports.
func stack_all() -> void:
	if Net.is_launcher_mode():
		_stack_all_via_server()
		return
	_stack_all_local()

## Hosted path: merge same-item stacks by asking the server to move them, and
## mutate nothing locally. The server's InventoryDelta fan-out is what updates
## the UI, exactly like a hand-dragged move.
##
## Deliberately MERGE-ONLY, never relocate. The offline path below redistributes
## through `_first_free_slot()`, which scans base slots before bags and so drags
## bag contents out into the main window — reported as "items unstack and move to
## the main inventory window". Consolidating stacks is the job; rehoming them
## between containers was never asked for.
##
## Only merges that stay within `stack_size` are sent: the server's move-merge
## does a plain `saturating_add` with no cap, so an over-large pairing would
## produce a stack bigger than the item allows.
func _stack_all_via_server() -> void:
	# item_name -> Array of {loc, slot, count, cap}, in scan order.
	var groups: Dictionary = {}
	for i in BASE_SLOT_COUNT:
		var entry = base_slots[i]
		if entry != null:
			_collect_stackable(groups, entry, NetProtocol.INV_LOCATION_BASE, i)
		if bag_contents[i] == null:
			continue
		var arr: Array = bag_contents[i]
		for j in arr.size():
			if arr[j] != null:
				_collect_stackable(groups, arr[j], NetProtocol.inv_location_bag(i), j)

	var sent: int = 0
	for key in groups:
		var slots: Array = groups[key]
		# Fill the earliest stacks from the latest ones, so partial stacks
		# collapse toward the front of the inventory.
		var head: int = 0
		var tail: int = slots.size() - 1
		while head < tail:
			var dst: Dictionary = slots[head]
			var src: Dictionary = slots[tail]
			if dst["count"] >= dst["cap"]:
				head += 1
				continue
			if src["count"] <= 0:
				tail -= 1
				continue
			# The wire move carries the WHOLE source stack, so only pair them
			# when the total fits.
			if dst["count"] + src["count"] > dst["cap"]:
				head += 1
				continue
			Net.broadcast_move_item(src["loc"], src["slot"], dst["loc"], dst["slot"])
			sent += 1
			dst["count"] += src["count"]
			src["count"] = 0
			tail -= 1

	if sent == 0:
		CombatLog.add_line("Nothing left to stack.", CombatLog.MsgType.INFO)

func _collect_stackable(groups: Dictionary, entry: Dictionary, loc: String, slot: int) -> void:
	var item: ItemData = entry["item"]
	if item.stack_size <= 1 or item.type == ItemData.Type.BAG:
		return
	if not groups.has(item.item_name):
		groups[item.item_name] = []
	groups[item.item_name].append({
		"loc": loc, "slot": slot,
		"count": int(entry["count"]), "cap": int(item.stack_size),
	})

## Offline / Test Room path, unchanged: with no server there is nothing to ask,
## so the local rewrite is correct here.
func _stack_all_local() -> void:
	# Key = item_name so we consolidate across different-reference copies of the same item.
	var totals: Dictionary = {}  # item_name -> { "item": ItemData, "count": int }
	for i in BASE_SLOT_COUNT:
		if base_slots[i] != null:
			var item: ItemData = base_slots[i]["item"]
			if item.stack_size > 1 and item.type != ItemData.Type.BAG:
				if not totals.has(item.item_name):
					totals[item.item_name] = {"item": item, "count": 0}
				totals[item.item_name]["count"] += base_slots[i]["count"]
				base_slots[i] = null
		if bag_contents[i] == null:
			continue
		var arr: Array = bag_contents[i]
		for j in arr.size():
			if arr[j] == null:
				continue
			var item: ItemData = arr[j]["item"]
			if item.stack_size <= 1:
				continue
			if not totals.has(item.item_name):
				totals[item.item_name] = {"item": item, "count": 0}
			totals[item.item_name]["count"] += arr[j]["count"]
			arr[j] = null
	for key in totals:
		var entry: Dictionary = totals[key]
		var item: ItemData = entry["item"]
		var remaining: int = entry["count"]
		while remaining > 0:
			var found := _first_free_slot()
			if found.is_empty():
				break
			var batch := mini(remaining, item.stack_size)
			if found.size() == 1:
				base_slots[found[0]] = {"item": item, "count": batch}
			else:
				bag_contents[found[0]][found[1]] = {"item": item, "count": batch}
			remaining -= batch
	inventory_changed.emit()

# ── helpers ───────────────────────────────────────────────────────────────────

# Returns [base_index] for a free base slot, or [base_index, bag_slot_index] for a bag slot.
func _first_free_slot() -> Array:
	for i in BASE_SLOT_COUNT:
		if base_slots[i] == null:
			return [i]
	for i in BASE_SLOT_COUNT:
		if bag_contents[i] == null:
			continue
		var arr: Array = bag_contents[i]
		for j in arr.size():
			if arr[j] == null:
				return [i, j]
	return []

func _init_bag_contents(base_index: int, num_slots: int) -> void:
	var arr: Array = []
	arr.resize(num_slots)
	arr.fill(null)
	bag_contents[base_index] = arr

# Flat list of all non-null item entries, for crafting / count_item iteration.
func all_slots() -> Array:
	var result: Array = []
	for i in BASE_SLOT_COUNT:
		if base_slots[i] != null:
			result.append(base_slots[i])
		if bag_contents[i] == null:
			continue
		for s in bag_contents[i]:
			if s != null:
				result.append(s)
	return result

# ── Save / load (Tier 2) ──────────────────────────────────────────────────────

func save_state() -> Dictionary:
	var base_out: Array = []
	var bags_out: Array = []
	for i in BASE_SLOT_COUNT:
		base_out.append(_slot_to_dict(base_slots[i]))
		if bag_contents[i] == null:
			bags_out.append(null)
		else:
			var bag_out: Array = []
			for s in bag_contents[i]:
				bag_out.append(_slot_to_dict(s))
			bags_out.append(bag_out)
	return {"base": base_out, "bags": bags_out}

func load_state(d: Dictionary) -> void:
	for i in BASE_SLOT_COUNT:
		base_slots[i] = null
		bag_contents[i] = null
	var base_in: Array = d.get("base", [])
	var bags_in: Array = d.get("bags", [])
	for i in BASE_SLOT_COUNT:
		if i < base_in.size():
			var slot: Variant = _slot_from_dict(base_in[i])
			if slot != null:
				base_slots[i] = slot
				if slot["item"].type == ItemData.Type.BAG and i < bags_in.size():
					var raw_bag: Variant = bags_in[i]
					if raw_bag is Array:
						var size: int = slot["item"].bag_num_slots
						var bag_arr: Array = []
						bag_arr.resize(size)
						bag_arr.fill(null)
						for j in mini(size, (raw_bag as Array).size()):
							bag_arr[j] = _slot_from_dict((raw_bag as Array)[j])
						bag_contents[i] = bag_arr
	inventory_changed.emit()

func _slot_to_dict(slot: Variant) -> Variant:
	if slot == null:
		return null
	var item: ItemData = slot["item"]
	return {"item": item.to_save_dict(), "count": int(slot["count"])}

func _slot_from_dict(raw: Variant) -> Variant:
	if raw == null or not (raw is Dictionary):
		return null
	var d: Dictionary = raw
	var item: ItemData = ItemData.from_save_dict(d.get("item", {}))
	if item == null:
		return null
	return {"item": item, "count": int(d.get("count", 1))}
