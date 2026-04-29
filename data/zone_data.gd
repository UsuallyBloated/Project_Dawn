class_name ZoneData

const DEFAULT_RADIUS: float  = 3.0
const DEFAULT_RESPAWN: float = 35.0

# Starter zone camps, arranged outward by ring distance from center.
# To add or tune a camp: edit this file only — zone_manager.gd reads it but
# has no camp-specific knowledge.
#
# Required mob keys : name, level, hp, dmg, xp, speed, aggro
# Optional camp keys: radius (float), respawn (float) — fall back to defaults above
const STARTER_ZONE_CAMPS: Array = [
	# ── Ring 1 · 18-22 units · lvl 1 ────────────────────────────────────────────
	{
		"desc": "Bonepile — decrepit skeletons lurking just outside the safe area",
		"mob": {"name": "Decrepit Skeleton", "level": 1, "hp": 25.0,  "dmg":  3, "xp":  10, "speed": 1.8, "aggro":  8.0},
		"spawns": [Vector3(20, 0, 5), Vector3(8, 0, 22), Vector3(-18, 0, 12), Vector3(12, 0, -20)],
	},
	# ── Ring 2 NE · 36-48 units · lvl 3 ─────────────────────────────────────────
	{
		"desc": "Shallow Graves — rotting skeletons clawing out of the earth",
		"mob": {"name": "Rotting Skeleton", "level": 3, "hp": 58.0,  "dmg":  7, "xp":  28, "speed": 2.2, "aggro": 10.0},
		"spawns": [Vector3(36, 0, 28), Vector3(44, 0, 22), Vector3(30, 0, 40)],
	},
	# ── Ring 2 SW · 35-48 units · lvl 2 ─────────────────────────────────────────
	{
		"desc": "Rat Warrens — fast, skittish plague rats that swarm",
		"mob": {"name": "Plague Rat",       "level": 2, "hp": 38.0,  "dmg":  5, "xp":  18, "speed": 4.2, "aggro": 14.0},
		"spawns": [Vector3(-35, 0, -28), Vector3(-28, 0, -42), Vector3(-44, 0, -22), Vector3(-20, 0, -46)],
	},
	# ── Ring 3 NW · 65-72 units · lvl 5 ─────────────────────────────────────────
	{
		"desc": "Bandit Outpost — road cutthroats with actual combat training",
		"mob": {"name": "Bandit Scout",     "level": 5, "hp": 92.0,  "dmg": 10, "xp":  50, "speed": 3.2, "aggro": 14.0},
		"spawns": [Vector3(-56, 0, 52), Vector3(-64, 0, 60), Vector3(-50, 0, 66)],
	},
	# ── Ring 3 SE · 68-78 units · lvl 6 ─────────────────────────────────────────
	{
		"desc": "Festering Mound — bloated ghouls that shamble fast when aggroed",
		"mob": {"name": "Plagued Ghoul",    "level": 6, "hp": 116.0, "dmg": 12, "xp":  62, "speed": 2.6, "aggro": 14.0},
		"spawns": [Vector3(58, 0, -56), Vector3(70, 0, -52), Vector3(55, 0, -70)],
	},
	# ── Ring 4 N · 112-125 units · lvl 9 ────────────────────────────────────────
	{
		"desc": "The Broken Crypt — undead champions, armoured and relentless",
		"mob": {"name": "Undead Champion",  "level": 9, "hp": 188.0, "dmg": 20, "xp":  92, "speed": 2.5, "aggro": 12.0},
		"spawns": [Vector3(10, 0, 118), Vector3(-8, 0, 124), Vector3(2, 0, 112)],
		"radius": 4.0, "respawn": 50.0,
	},
	# ── Ring 4 S · 112-125 units · lvl 10 ───────────────────────────────────────
	{
		"desc": "Gnoll War Camp — gnoll brutes standing guard over a ruined encampment",
		"mob": {"name": "Gnoll Brute",      "level": 10, "hp": 215.0, "dmg": 22, "xp": 102, "speed": 3.0, "aggro": 16.0},
		"spawns": [Vector3(2, 0, -118), Vector3(16, 0, -114), Vector3(-12, 0, -124)],
		"radius": 4.0, "respawn": 50.0,
	},
	# ── Ring 5 W · 162-175 units · lvl 14 ───────────────────────────────────────
	{
		"desc": "Ossuary — bone colossi, rare and long-respawning",
		"mob": {"name": "Bone Colossus",    "level": 14, "hp": 365.0, "dmg": 35, "xp": 165, "speed": 1.8, "aggro": 15.0},
		"spawns": [Vector3(-168, 0, 8), Vector3(-174, 0, -14)],
		"radius": 5.0, "respawn": 90.0,
	},
	# ── Ring 5 E · 172-182 units · lvl 16 ───────────────────────────────────────
	{
		"desc": "Wraith Gate — ancient wraiths patrolling the far eastern edge",
		"mob": {"name": "Ancient Wraith",   "level": 16, "hp": 328.0, "dmg": 40, "xp": 205, "speed": 4.2, "aggro": 22.0},
		"spawns": [Vector3(178, 0, 5), Vector3(175, 0, -20)],
		"radius": 5.0, "respawn": 90.0,
	},
]
