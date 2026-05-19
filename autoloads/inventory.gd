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

# Track 13.2 — apply a server-authoritative snapshot. Wipes the
# current base_slots / bag_contents and rebuilds from the wire
# tuples. Caller is the InventorySnapshot fan-out on EnterWorld.
# In solo / Test Room mode Net never fires this signal so the
# legacy local autoload state is preserved.
func _on_inventory_snapshot(
		locations: PackedStringArray,
		slots: PackedInt32Array,
		item_paths: PackedStringArray,
		counts: PackedInt32Array) -> void:
	base_slots.fill(null)
	bag_contents.fill(null)
	var n: int = mini(mini(locations.size(), slots.size()), mini(item_paths.size(), counts.size()))
	for i in n:
		var loc: String = locations[i]
		if loc != NetProtocol.INV_LOCATION_BASE:
			# 13.2.b / 13.3 will route 'bag_<i>' / 'equip' here.
			continue
		var slot_idx: int = slots[i]
		if slot_idx < 0 or slot_idx >= BASE_SLOT_COUNT:
			continue
		var path: String = item_paths[i]
		var count: int = counts[i]
		if path == "" or count <= 0:
			continue
		var item := load(path) as ItemData
		if item == null:
			push_warning("Inventory snapshot: unknown ItemData path '%s'" % path)
			continue
		base_slots[slot_idx] = {"item": item, "count": count}
	inventory_changed.emit()

# Track 13.2 — apply a single-slot mutation. Empty `item_path`
# clears the slot; non-empty sets it to (item_path, count).
func _on_inventory_delta(location: String, slot: int, item_path: String, count: int) -> void:
	if location != NetProtocol.INV_LOCATION_BASE:
		# 13.2.b / 13.3 will route 'bag_<i>' / 'equip' here.
		return
	if slot < 0 or slot >= BASE_SLOT_COUNT:
		return
	if item_path == "" or count <= 0:
		base_slots[slot] = null
	else:
		var item := load(item_path) as ItemData
		if item == null:
			push_warning("Inventory delta: unknown ItemData path '%s'" % item_path)
			return
		base_slots[slot] = {"item": item, "count": count}
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

func stack_all() -> void:
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
