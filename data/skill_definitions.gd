class_name SkillDefinitions

# All skill data in one place. Add new skills here; no logic code needs to change.
# damage_multiplier == 0 means the skill targets SELF (no damage).
const ALL: Array = [
	{"name": "Slash",            "desc": "A quick slashing strike.",                              "cooldown": 3.0,  "stamina_cost": 8.0,  "damage_multiplier": 1.5, "classes": ["Warrior", "Rogue"]},
	{"name": "Shield Bash",      "desc": "Stuns and damages with your shield.",                   "cooldown": 8.0,  "stamina_cost": 15.0, "damage_multiplier": 1.2, "classes": ["Warrior"]},
	{"name": "Backstab",         "desc": "A devastating blow from the shadows.",                  "cooldown": 6.0,  "stamina_cost": 20.0, "damage_multiplier": 3.0, "classes": ["Rogue"]},
	{"name": "Evade",            "desc": "Grants a burst of agility.",                            "cooldown": 12.0, "stamina_cost": 10.0, "damage_multiplier": 0.0, "classes": ["Rogue"]},
	{"name": "Pummel",           "desc": "A rapid series of blows.",                              "cooldown": 5.0,  "stamina_cost": 12.0, "damage_multiplier": 1.0, "classes": ["Warrior"]},
	{"name": "Holy Strike",      "desc": "A weapon strike blessed with divine energy.",           "cooldown": 5.0,  "stamina_cost": 10.0, "damage_multiplier": 1.3, "classes": ["Cleric"]},
	{"name": "Primal Strike",    "desc": "A ferocious blow fueled by ancestral spirits.",         "cooldown": 4.0,  "stamina_cost": 12.0, "damage_multiplier": 1.4, "classes": ["Shaman"]},
	{"name": "Divine Blow",      "desc": "A powerful strike that channels the light through steel.", "cooldown": 5.0, "stamina_cost": 12.0, "damage_multiplier": 1.4, "classes": ["Paladin"]},
	{"name": "Holy Shield",      "desc": "Raises a blessed ward. Costs stamina, deals no damage.", "cooldown": 15.0, "stamina_cost": 10.0, "damage_multiplier": 0.0, "classes": ["Paladin"]},
	{"name": "Dark Strike",      "desc": "A vicious blow infused with shadow energy.",            "cooldown": 5.0,  "stamina_cost": 12.0, "damage_multiplier": 1.4, "classes": ["Shadow Knight"]},
	{"name": "Harm Touch",       "desc": "A touch of death that deals massive damage.",           "cooldown": 12.0, "stamina_cost": 25.0, "damage_multiplier": 2.5, "classes": ["Shadow Knight"]},
	{"name": "Swindler's Strike","desc": "A fast, opportunistic hit from an unexpected angle.",   "cooldown": 4.0,  "stamina_cost": 10.0, "damage_multiplier": 1.2, "classes": ["Bard"]},
	{"name": "Double Strike",    "desc": "Two rapid blows in quick succession.",                  "cooldown": 2.5,  "stamina_cost": 8.0,  "damage_multiplier": 1.1, "classes": ["Ranger"]},
	{"name": "True Shot",        "desc": "A carefully aimed strike that hits a critical point.",  "cooldown": 8.0,  "stamina_cost": 20.0, "damage_multiplier": 2.0, "classes": ["Ranger"]},
	{"name": "Tiger Claw",       "desc": "A swift raking strike with bare hands.",                "cooldown": 3.0,  "stamina_cost": 10.0, "damage_multiplier": 1.2, "classes": ["Monk"]},
	{"name": "Roundhouse",       "desc": "A spinning kick that carries devastating momentum.",    "cooldown": 6.0,  "stamina_cost": 15.0, "damage_multiplier": 1.6, "classes": ["Monk"]},
	{"name": "Flying Kick",      "desc": "Launches the monk through the air into the target.",   "cooldown": 10.0, "stamina_cost": 20.0, "damage_multiplier": 2.2, "classes": ["Monk"]},
	{"name": "Silver Bolt",      "desc": "A short-range burst of witch-hunter's silver.",        "cooldown": 5.0,  "stamina_cost": 12.0, "damage_multiplier": 1.5, "classes": ["Witch Hunter"]},

	# ── Alignment variants ────────────────────────────────────────────────────
	# Paladin who has fallen to Evil alignment
	{"name": "Profane Strike",    "desc": "A corrupted blow that drives dark energy through steel.",  "cooldown": 5.0,  "stamina_cost": 12.0, "damage_multiplier": 1.6, "classes": ["Paladin_Fallen"]},
	{"name": "Dark Ward",         "desc": "Raises a shadow ward. Costs stamina, deals no damage.",   "cooldown": 15.0, "stamina_cost": 10.0, "damage_multiplier": 0.0, "classes": ["Paladin_Fallen"]},
	# Shadow Knight who has reached Exalted alignment
	{"name": "Redeemed Strike",   "desc": "A blow fueled by hard-won conviction.",                   "cooldown": 5.0,  "stamina_cost": 12.0, "damage_multiplier": 1.4, "classes": ["Shadow Knight_Redeemed"]},
	{"name": "Penitent's Touch",  "desc": "Channels redemptive suffering into devastating force.",   "cooldown": 12.0, "stamina_cost": 25.0, "damage_multiplier": 2.5, "classes": ["Shadow Knight_Redeemed"]},
]
