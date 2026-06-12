# Headless audit of ItemData.weight coverage across data/loot/items/.
# Run: godot --headless --path . --script tools/item_weight_audit.gd
# Prints one markdown table row per item (sorted by type, then name) plus a
# summary line. Used to generate the item-weight proposal table and, after the
# content pass, as the coverage check — zero-weight items are listed by name so
# an approved zero-weight allowlist can be eyeballed against it.
extends SceneTree

const ITEMS_DIR := "res://data/loot/items"

# Display names for ItemData.Type indices (keep in sync with scripts/item_data.gd).
const TYPE_NAMES: Array[String] = [
	"WEAPON", "OFFHAND", "HEAD", "CHEST", "LEGS", "FEET", "HANDS",
	"RING", "NECK", "CONSUMABLE", "MISC", "AUGMENT", "BAG",
]


func _initialize() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		print("ITEM_WEIGHT_AUDIT_FAIL: cannot open %s" % ITEMS_DIR)
		quit(1)
		return

	var rows: Array[Dictionary] = []
	var load_failures: Array[String] = []
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var item: ItemData = load("%s/%s" % [ITEMS_DIR, file]) as ItemData
		if item == null:
			load_failures.append(file)
			continue
		rows.append({
			"name": item.item_name,
			"type": item.type,
			"stack_size": item.stack_size,
			"vendor_price": item.vendor_price,
			"weight": item.weight,
		})

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["type"] != b["type"]:
			return a["type"] < b["type"]
		return a["name"] < b["name"])

	print("| name | type | stack_size | vendor_price | current weight |")
	print("|---|---|---|---|---|")
	var untagged: Array[String] = []
	for r in rows:
		var type_name: String = TYPE_NAMES[r["type"]] if r["type"] < TYPE_NAMES.size() else "UNKNOWN(%d)" % r["type"]
		print("| %s | %s | %d | %d | %s |" % [r["name"], type_name, r["stack_size"], r["vendor_price"], String.num(r["weight"], 2)])
		if r["weight"] == 0.0:
			untagged.append(r["name"])

	print("%d items, %d untagged" % [rows.size(), untagged.size()])
	if not untagged.is_empty():
		print("zero-weight: %s" % ", ".join(untagged))
	for f in load_failures:
		print("ITEM_WEIGHT_AUDIT_FAIL: %s did not load as ItemData" % f)
	quit()
