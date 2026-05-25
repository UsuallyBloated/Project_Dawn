extends Node

# Track 22.C — mount state.
#
# Design (locked 2026-05-24):
#   - Source:    item-based whistles (ItemData.is_mount). Right-click in
#                inventory routes through summon(item).
#   - Zones:     per-zone `mounts_allowed: bool`. Summon refuses in
#                no-mount zones; entering a no-mount zone auto-dismounts.
#   - Dismount:  any incoming damage. Also fires on death, manual
#                /dismount, and zone change into a no-mount zone.
#   - Speed:     mount_speed_mult overrides every other speed source
#                (BuffManager.get_speed_mult is ignored while mounted).
#                player.gd uses get_effective_speed_mult() instead.
#
# Whistles are NOT consumed on summon — they're travel tools, not
# single-use consumables. They remain in the inventory.

signal mount_changed(mounted: bool, mount_name: String)
signal dismount_reason(reason: String)

var current_mount: ItemData = null

func _ready() -> void:
	# Track 22.C — auto-dismount when traveling into a no-mount zone.
	# Subscribed on the ZoneLoader.zone_changed signal which fires
	# during the fade-out before change_scene_to_file lands, so the
	# dismount log line and state flip both happen with the rider
	# still in their old scene.
	ZoneLoader.zone_changed.connect(_on_zone_changed)

func _on_zone_changed(_zone_name: String) -> void:
	if is_mounted() and not _mounts_allowed_here():
		dismount("no mounts allowed here")

func is_mounted() -> bool:
	return current_mount != null

func summon(item: ItemData) -> bool:
	if item == null or not item.is_mount:
		CombatLog.add_line("You can't ride that.", CombatLog.MsgType.INFO)
		return false
	if is_mounted():
		# Re-summoning the same whistle is a no-op; a different whistle
		# swaps mounts.
		if current_mount == item:
			return true
		dismount("switching mounts")
	# Zone-permission check. ZoneLoader is the source of truth for the
	# current zone; if the loader can't be reached (early boot, solo
	# Test Room), default-allow.
	if not _mounts_allowed_here():
		CombatLog.add_line("You can't mount here.", CombatLog.MsgType.INFO)
		return false
	current_mount = item
	var nm := item.mount_name if item.mount_name != "" else item.item_name
	CombatLog.add_line("You mount your %s." % nm, CombatLog.MsgType.INFO)
	mount_changed.emit(true, nm)
	return true

func dismount(reason: String = "") -> void:
	if not is_mounted():
		return
	var nm := current_mount.mount_name if current_mount.mount_name != "" else current_mount.item_name
	current_mount = null
	if reason != "":
		CombatLog.add_line("You are dismounted (%s)." % reason, CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("You dismount your %s." % nm, CombatLog.MsgType.INFO)
	dismount_reason.emit(reason)
	mount_changed.emit(false, "")

# Speed multiplier including mount override. Caller is player.gd's
# physics tick. Returns 1.0 when not mounted (preserves the legacy
# BuffManager-only path).
func get_effective_speed_mult() -> float:
	if is_mounted():
		return current_mount.mount_speed_mult
	return BuffManager.get_speed_mult()

# Zone-permission lookup. Mirrors the Bind Affinity pattern in
# ZoneData.NON_BINDABLE_ZONES — checks the current zone path against
# a blacklist. Empty list (the default) means mounts everywhere.
func _mounts_allowed_here() -> bool:
	if not is_instance_valid(ZoneLoader):
		return true
	var zone_path: String = ZoneLoader.current_zone_path
	if zone_path == "":
		return true
	return zone_path not in ZoneData.NO_MOUNT_ZONES
