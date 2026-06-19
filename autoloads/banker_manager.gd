extends Node

# Town Banker NPC manager (Banker slice 1: coins). Mirrors VendorManager's
# proximity + open pattern. The Banker offers zero-weight coin storage
# (deposit / withdraw) and tier exchange — the relief valve for the four-tier
# coin-weight system. See docs/concepts/world/currency.md.
#
# The player's *bank* balance is server-authoritative and display-only on the
# client: this autoload caches it from the server's BankSnapshot (seeded on
# login, refreshed after every deposit/withdraw) so the BankWindow can render
# immediately on open. The carried wallet stays on PlayerStats as before.

signal banker_opened(banker_name: String)
signal banker_closed
signal bank_balance_changed(platinum: int, gold: int, silver: int, copper: int)
# PD_W0016 — Banker slice 2. One item vault changed (shared selects which); the
# BankWindow repaints that grid.
signal vault_changed(shared: bool)

# Item-vault sizes, mirroring the server (world/inventory.rs).
const BANK_VAULT_SLOTS := 10
const ACCOUNT_VAULT_SLOTS := 2

# nearby_banker is set by proximity (BankerNPC body_entered/exited); open_for()
# is preferred when the caller has an explicit reference.
var nearby_banker: Node = null

# Cached bank balance (last BankSnapshot from the server). Four independent
# tier stacks, same convention as the wallet.
var bank_platinum: int = 0
var bank_gold: int = 0
var bank_silver: int = 0
var bank_copper: int = 0

# PD_W0016 — Banker slice 2. Cached item-vault contents (display-only mirror of
# the server). Each entry is null or {item: ItemData, count: int}.
var vault_personal: Array = []   # BANK_VAULT_SLOTS entries
var vault_shared: Array = []     # ACCOUNT_VAULT_SLOTS entries (shared across the account)
# True while the BankWindow is open. The inventory/bag right-click quick-transfer
# deposits to the bank only while this is set; the BankWindow keeps it in sync.
var bank_is_open: bool = false
# Which vault a quick-transfer deposit targets (set by the BankWindow's toggle).
var deposit_to_shared: bool = false

func _ready() -> void:
	vault_personal.resize(BANK_VAULT_SLOTS)
	vault_shared.resize(ACCOUNT_VAULT_SLOTS)
	Net.world_bank_snapshot.connect(_on_bank_snapshot)
	Net.world_bank_item_snapshot.connect(_on_bank_item_snapshot)

func register_nearby(npc: Node) -> void:
	nearby_banker = npc

func unregister_nearby(npc: Node) -> void:
	if nearby_banker == npc:
		nearby_banker = null

func open_for(banker: Node) -> void:
	if banker == null or not is_instance_valid(banker):
		return
	banker_opened.emit(banker.banker_name)

func open_nearby() -> void:
	open_for(nearby_banker)

func close() -> void:
	banker_closed.emit()

func _on_bank_snapshot(platinum: int, gold: int, silver: int, copper: int) -> void:
	bank_platinum = platinum
	bank_gold = gold
	bank_silver = silver
	bank_copper = copper
	bank_balance_changed.emit(platinum, gold, silver, copper)

# PD_W0016 — full contents of one item vault. Rebuild the cached array (resolve
# each item_path to its ItemData) and notify the BankWindow.
func _on_bank_item_snapshot(shared: bool, slots: PackedInt32Array, item_paths: PackedStringArray, counts: PackedInt32Array) -> void:
	var arr: Array = vault_shared if shared else vault_personal
	for i in arr.size():
		arr[i] = null
	for i in slots.size():
		var s: int = slots[i]
		if s < 0 or s >= arr.size():
			continue
		var item: ItemData = load(item_paths[i]) as ItemData
		if item == null:
			push_warning("BankerManager: bank vault item failed to load: %s" % item_paths[i])
			continue
		arr[s] = {"item": item, "count": int(counts[i])}
	vault_changed.emit(shared)

func get_vault(shared: bool) -> Array:
	return vault_shared if shared else vault_personal
