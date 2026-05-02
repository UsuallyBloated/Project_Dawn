extends Node

# Mirrors the VendorManager pattern for crafting stations.
# A single station can be "nearby" at a time.

var nearby_station: String = ""  # matches recipe "station" field

func register_nearby(station_type: String) -> void:
	nearby_station = station_type

func unregister_nearby(station_type: String) -> void:
	if nearby_station == station_type:
		nearby_station = ""
