extends Node

# Track 22.C — mounts. The server decides movement speed and has no mount
# model yet, so a mount would only move you on your own screen (and
# rubber-band back). A whistle refuses honestly, as the tradeskills do, until
# the server rides it. The mount data stays for that port: the whistles'
# ItemData (is_mount, mount_name, mount_speed_mult) and ZoneData.NO_MOUNT_ZONES.
#
# The design (locked 2026-05-24) the port should follow:
#   - Source:    item-based whistles (ItemData.is_mount), right-clicked in
#                the inventory. Whistles are NOT consumed on summon.
#   - Zones:     summon refuses in a no-mount zone; entering one dismounts.
#   - Dismount:  any incoming damage, death, /dismount, or a no-mount zone.
#   - Speed:     the mount's multiplier overrides every other speed source;
#                encumbrance still applies on top.

func summon(item: ItemData) -> bool:
	if item == null or not item.is_mount:
		CombatLog.add_line("You can't ride that.", CombatLog.MsgType.INFO)
		return false
	CombatLog.add_line("Mounts are not available online yet.", CombatLog.MsgType.INFO)
	return false
