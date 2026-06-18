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

# nearby_banker is set by proximity (BankerNPC body_entered/exited); open_for()
# is preferred when the caller has an explicit reference.
var nearby_banker: Node = null

# Cached bank balance (last BankSnapshot from the server). Four independent
# tier stacks, same convention as the wallet.
var bank_platinum: int = 0
var bank_gold: int = 0
var bank_silver: int = 0
var bank_copper: int = 0

func _ready() -> void:
	Net.world_bank_snapshot.connect(_on_bank_snapshot)

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
