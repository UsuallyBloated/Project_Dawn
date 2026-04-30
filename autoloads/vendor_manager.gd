extends Node

signal vendor_opened(vendor_name: String, vendor_type: String)
signal vendor_closed

var nearby_vendor: Node = null

func register_nearby(npc: Node) -> void:
	nearby_vendor = npc

func unregister_nearby(npc: Node) -> void:
	if nearby_vendor == npc:
		nearby_vendor = null

func open_nearby() -> void:
	if nearby_vendor == null:
		return
	vendor_opened.emit(
		nearby_vendor.vendor_name,
		nearby_vendor.vendor_type)

func close() -> void:
	vendor_closed.emit()
