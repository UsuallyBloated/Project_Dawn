class_name WeaponItemTable

# Central lookup: item_name -> weapon skill key.
# Add every weapon here when you add it to the game.
# Skill keys must match WeaponSkillDefinitions.ALL.
#
# Priority order in combat.gd:
#   1. ItemData.weapon_skill (per-item override on the .tres/.gd)
#   2. This table (looked up by item_name)
#   3. "hand_to_hand" (fallback for anything not listed)

const SKILLS: Dictionary = {

	# ── 1H Slashing ───────────────────────────────────────────────────────────
	"Rusty Short Sword":         "1h_slashing",
	"Rusty Shortsword":          "1h_slashing",   # dynamic enemy drop

	# ── 2H Slashing ───────────────────────────────────────────────────────────
	# (none yet)

	# ── 1H Blunt ──────────────────────────────────────────────────────────────
	"Cracked Wooden Club":       "1h_blunt",

	# ── 2H Blunt ──────────────────────────────────────────────────────────────
	"Splintered Staff":          "2h_blunt",

	# ── Piercing ──────────────────────────────────────────────────────────────
	"Bent Dagger":               "piercing",

	# ── Hand to Hand ──────────────────────────────────────────────────────────
	# (unarmed — combat.gd falls back to this automatically; no entry needed)
}

static func get_skill(item_name: String) -> String:
	return SKILLS.get(item_name, "hand_to_hand")
