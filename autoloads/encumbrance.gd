# Encumbrance — carry weight vs. STR-driven capacity. Weight comes from coins
# (the designed driver: every coin weighs the same regardless of tier, so a
# copper hoard is heavy — see docs/concepts/world/currency.md), inventory
# items, and worn equipment. Pure consumer: reads Inventory / Equipment /
# PlayerStats and recomputes on their change signals; never mutates them.
#
# Online the SERVER owns encumbrance (crates/projectdawn-server/src/world/
# encumbrance.rs): it slows your movement and your stamina regen. This copy
# predicts the movement penalty so local movement matches the server's, and
# drives the "You are encumbered!" line. Its constants and arithmetic are kept
# in lockstep with the server's by hand: change one, change the other.
extends Node

signal encumbrance_changed(weight: float, capacity: float)

# Every coin weighs the same regardless of tier — 1,000,000 copper (worth 1
# platinum) weighs a million times the single platinum coin of equal value.
# That asymmetry is the whole point; don't "fix" it.
const COIN_WEIGHT := 0.02

# capacity = BASE_CAPACITY + STR * CAPACITY_PER_STR. A fresh STR-10 character
# carries 20 units (= 1000 coins) before slowing.
const BASE_CAPACITY := 10.0
const CAPACITY_PER_STR := 1.0

# Over capacity, speed falls linearly: -SPEED_PENALTY_RATE per 1.0 of
# weight/capacity ratio above 1.0, floored at MIN_SPEED_MULT (a crawl, never
# a full stop — being rooted by your own money is more frustrating than fun).
const SPEED_PENALTY_RATE := 0.6
const MIN_SPEED_MULT := 0.25

# At this multiple of capacity the server stops stamina regen entirely (it
# halves it while merely encumbered); the HUD and the sheet show "overloaded".
const OVERLOADED_RATIO := 2.0

var total_weight: float = 0.0
var capacity: float = BASE_CAPACITY + 10.0 * CAPACITY_PER_STR

var _was_encumbered := false


func _ready() -> void:
	Inventory.inventory_changed.connect(_recompute)
	Equipment.equipment_changed.connect(_on_equipment_changed)
	PlayerStats.coins_changed.connect(_on_coins_changed)
	PlayerStats.stats_changed.connect(_recompute)  # STR affects capacity
	PlayerStats.character_applied.connect(_recompute)
	_recompute()


func is_encumbered() -> bool:
	return total_weight > capacity


# Multiplier for player movement speed; player.gd applies it after the
# mount multiplier (an overloaded mount is still overloaded).
func get_speed_mult() -> float:
	if capacity <= 0.0 or total_weight <= capacity:
		return 1.0
	var ratio := total_weight / capacity
	return clampf(1.0 - SPEED_PENALTY_RATE * (ratio - 1.0), MIN_SPEED_MULT, 1.0)


func _on_equipment_changed(_slot: String, _item) -> void:
	_recompute()


func _on_coins_changed(_p: int, _g: int, _s: int, _c: int) -> void:
	_recompute()


func _recompute() -> void:
	var w := _coin_weight() + _inventory_weight() + _equipment_weight()
	var cap := BASE_CAPACITY + PlayerStats.strength * CAPACITY_PER_STR
	if is_equal_approx(w, total_weight) and is_equal_approx(cap, capacity):
		return
	total_weight = w
	capacity = cap
	encumbrance_changed.emit(total_weight, capacity)
	_announce_transition()


func _coin_weight() -> float:
	var coin_count := PlayerStats.platinum + PlayerStats.gold \
		+ PlayerStats.silver + PlayerStats.copper
	return coin_count * COIN_WEIGHT


func _inventory_weight() -> float:
	var w := 0.0
	for i in Inventory.BASE_SLOT_COUNT:
		var slot: Variant = Inventory.get_base_slot(i)
		if slot != null:
			w += slot["item"].weight * slot["count"]
		var bag: Variant = Inventory.bag_contents[i]
		if bag is Array:
			for inner in bag:
				if inner != null:
					w += inner["item"].weight * inner["count"]
	# PD_W0027 — a held stack weighs what it weighs. Carrying an item on
	# the cursor must never be a way to dodge encumbrance.
	if Inventory.cursor_slot != null:
		w += Inventory.cursor_slot["item"].weight * Inventory.cursor_slot["count"]
	# Full-bags-move: a bag riding the cursor keeps weighing its contents.
	for inner in Inventory.cursor_bag_contents:
		if inner != null:
			w += inner["item"].weight * inner["count"]
	return w


func _equipment_weight() -> float:
	var w := 0.0
	for slot_name in Equipment.equipped:
		var item: ItemData = Equipment.equipped[slot_name]
		if item != null:
			w += item.weight
	return w


# Classic-MMO chat line on crossing the threshold, either direction.
func _announce_transition() -> void:
	var now_encumbered := is_encumbered()
	if now_encumbered == _was_encumbered:
		return
	_was_encumbered = now_encumbered
	if now_encumbered:
		CombatLog.add_line("You are encumbered!", CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("You are no longer encumbered.", CombatLog.MsgType.INFO)
