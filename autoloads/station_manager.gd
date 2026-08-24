extends Node

# Mirrors the VendorManager pattern for crafting stations.
# A single station can be "nearby" at a time.

var nearby_station: String = ""  # matches recipe "station" field

# Fired by a right-click on a station (Targeting.interact_at); the HUD owns the
# crafting window and opens it on this. Signal rather than a direct reach into
# the HUD's scene tree, per the cross-scene convention.
signal open_requested

func request_open() -> void:
	open_requested.emit()

func register_nearby(station_type: String) -> void:
	nearby_station = station_type

func unregister_nearby(station_type: String) -> void:
	if nearby_station == station_type:
		nearby_station = ""
