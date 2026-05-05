extends Node

signal vendor_opened(vendor_name: String, vendor_type: String)
signal vendor_closed

# nearby_vendor is set by proximity (VendorNPC body_entered/exited) and used as
# a fallback when callers don't have an explicit reference. Prefer open_for()
# when you do — it avoids stale state from the proximity tracker.
var nearby_vendor: Node = null

func register_nearby(npc: Node) -> void:
	nearby_vendor = npc

func unregister_nearby(npc: Node) -> void:
	if nearby_vendor == npc:
		nearby_vendor = null

func open_for(vendor: Node) -> void:
	if vendor == null or not is_instance_valid(vendor):
		return
	vendor_opened.emit(vendor.vendor_name, vendor.vendor_type)

func open_nearby() -> void:
	open_for(nearby_vendor)

func close() -> void:
	vendor_closed.emit()
