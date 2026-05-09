extends Node

signal transformation_applied(name: String)
signal transformation_reverted(name: String)

const TRANSFORMATIONS: Dictionary = {
	"Revenant": {
		"desc": "You sacrifice your soul for undeath and dark power. There is no return.",
		"required_alignment": "Evil",
		"required_classes": ["Necromancer", "Shadow Knight", "Blood Mage"],
		"required_level": 20,
		"stat_changes": {"constitution": 15, "intelligence": 10, "strength": 5, "charisma": -15, "wisdom": -5},
		"hp_bonus": 0.0, "mp_bonus": 0.0,
		"languages": {"Ghost Tongue": 100},
	},
	"Vampire Lord": {
		"desc": "You bind yourself to an ancient vampiric lineage. All attacks now leech vitality.",
		"required_alignment": "Evil",
		"required_classes": ["Blood Mage", "Shadow Knight"],
		"required_level": 25,
		"stat_changes": {"intelligence": 12, "constitution": 8, "charisma": 5, "wisdom": -10},
		"hp_bonus": 0.0, "mp_bonus": 20.0,
	},
	"Lich": {
		"desc": "You bind your soul to a phylactery and achieve true undeath. Vast power. Absolute isolation.",
		"required_alignment": "Evil",
		"required_classes": ["Necromancer"],
		"required_level": 30,
		"stat_changes": {"intelligence": 20, "wisdom": 10, "constitution": 10, "charisma": -20, "strength": -10},
		"hp_bonus": 0.0, "mp_bonus": 50.0,
	},
	"Lycanthrope": {
		"desc": "You were bitten. The beast within has woken and will not sleep again.",
		"required_alignment": "Neutral",
		"required_classes": ["Ranger", "Druid", "Shaman", "Monk"],
		"required_level": 15,
		"stat_changes": {"strength": 15, "constitution": 10, "agility": 10, "wisdom": -10, "charisma": -10},
		"hp_bonus": 30.0, "mp_bonus": 0.0,
	},
	"Exalted": {
		"desc": "You are chosen directly by a deity. Light is no longer metaphor — it lives in you.",
		"required_alignment": "Exalted",
		"required_classes": ["Paladin", "Cleric"],
		"required_level": 30,
		"stat_changes": {"wisdom": 15, "charisma": 10, "constitution": 5},
		"hp_bonus": 20.0, "mp_bonus": 30.0,
	},
	"Warden of the Wild": {
		"desc": "You are permanently bound to the natural world. It knows your name. You know its secrets.",
		"required_alignment": "Exalted",
		"required_classes": ["Druid", "Ranger"],
		"required_level": 25,
		"stat_changes": {"wisdom": 12, "agility": 8, "constitution": 8, "intelligence": 5},
		"hp_bonus": 15.0, "mp_bonus": 20.0,
	},
}

# Snapshot of what was applied so the transformation can be cleanly reversed.
var _snapshot: Dictionary = {}

func can_transform(tname: String) -> bool:
	if not TRANSFORMATIONS.has(tname):
		return false
	if PlayerStats.transformation != "":
		return false
	var t: Dictionary = TRANSFORMATIONS[tname]
	if PlayerStats.level < t["required_level"]:
		return false
	if Alignment.alignment_tier != t["required_alignment"]:
		return false
	if PlayerStats.player_class not in t["required_classes"]:
		return false
	return true

func apply_transformation(tname: String) -> bool:
	if not can_transform(tname):
		return false
	var t: Dictionary = TRANSFORMATIONS[tname]
	_snapshot = {"stat_changes": t["stat_changes"].duplicate(), "hp_bonus": t["hp_bonus"], "mp_bonus": t["mp_bonus"]}
	for stat in t["stat_changes"]:
		PlayerStats[stat] += t["stat_changes"][stat]
	PlayerStats.max_hp = maxf(50.0, PlayerStats.max_hp + t["hp_bonus"])
	PlayerStats.max_mp = maxf(20.0, PlayerStats.max_mp + t["mp_bonus"])
	PlayerStats.set_hp(PlayerStats.max_hp)
	PlayerStats.set_mp(PlayerStats.max_mp)
	for lang in t.get("languages", {}):
		Languages.grant_language(lang, t["languages"][lang])
	PlayerStats.transformation = tname
	# Revenant: tradeskill scores are retained unchanged (no reset needed because
	# tradeskill scores live outside PlayerStats; this is a no-op placeholder until
	# the tradeskill system is implemented).
	transformation_applied.emit(tname)
	return true

func revert_transformation() -> void:
	if PlayerStats.transformation == "" or _snapshot.is_empty():
		return
	var reverted_name: String = PlayerStats.transformation
	for stat in _snapshot["stat_changes"]:
		PlayerStats[stat] -= _snapshot["stat_changes"][stat]
	PlayerStats.max_hp = maxf(50.0, PlayerStats.max_hp - _snapshot["hp_bonus"])
	PlayerStats.max_mp = maxf(20.0, PlayerStats.max_mp - _snapshot["mp_bonus"])
	PlayerStats.set_hp(minf(PlayerStats.hp, PlayerStats.max_hp))
	PlayerStats.set_mp(minf(PlayerStats.mp, PlayerStats.max_mp))
	PlayerStats.transformation = ""
	_snapshot = {}
	transformation_reverted.emit(reverted_name)

func get_available_transformations() -> Array[String]:
	var result: Array[String] = []
	for tname in TRANSFORMATIONS:
		if can_transform(tname):
			result.append(tname)
	return result
