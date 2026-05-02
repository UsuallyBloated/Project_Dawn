class_name WeaponItemTable

# Fallback lookup: item_name -> weapon skill key.
# Only needed for dynamically-created weapon items that have no .tres file
# (e.g. random enemy drops generated at runtime with an empty weapon_skill field).
# Weapons backed by .tres files should set weapon_skill directly on the resource.
# Skill keys must match WeaponSkillDefinitions.ALL.
#
# Priority order in combat.gd:
#   1. ItemData.weapon_skill (per-item field on the .tres resource)
#   2. This table (looked up by item_name string)
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

	# ── Archery ───────────────────────────────────────────────────────────────
	"Worn Short Bow":            "archery",
	"Hunter's Shortbow":         "archery",
	"Ranger's Longbow":          "archery",
	"Compound Bow":              "archery",
	"Hunting Crossbow":          "archery",

	# ── Hand to Hand ──────────────────────────────────────────────────────────
	# (unarmed — combat.gd falls back to this automatically; no entry needed)
}

static func get_skill(item_name: String) -> String:
	return SKILLS.get(item_name, "hand_to_hand")
