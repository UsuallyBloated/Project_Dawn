class_name ZoneData

# Per-zone rules the client checks. Mob camps live on the server
# (zone_camps.toml).

# Track 22.C — zone paths where mount whistles refuse to summon
# (and where the player auto-dismounts on entry). Add a dungeon / city
# interior scene's res:// path here to mark it as no-mount. Empty list =
# mounts allowed everywhere by default.
const NO_MOUNT_ZONES: Array[String] = [
]
