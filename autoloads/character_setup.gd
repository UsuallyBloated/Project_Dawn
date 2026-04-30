extends Node

# Single coordinator for full character reinitialization.
# Connects to PlayerStats.character_applied and calls every subsystem that
# needs a hard reset when race/class/level changes. Add new systems here —
# not in their own _ready() via character_applied.

func _ready() -> void:
	PlayerStats.character_applied.connect(_on_character_applied)

func _on_character_applied() -> void:
	var cls  := PlayerStats.player_class
	var race := PlayerStats.race
	var lvl  := PlayerStats.level
	WeaponSkills.initialize(cls, lvl)
	ArmorSkills.initialize(cls, lvl)
	CastingSkills.initialize(cls, lvl)
	SenseHeading.initialize(lvl)
	Skills.setup_for_class(cls)
	Spells.setup_for_class(cls)
	Languages.initialize(race)
