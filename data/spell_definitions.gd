class_name SpellDefinitions

# All spell data in one place. Add new spells here; no logic code needs to change.
# Fields: name, desc, mana_cost, cast_time, cooldown, base_damage,
#         damage_type, target_type, heal_amount, hp_cost, classes

const REQUIRED_KEYS: Array[String] = ["name", "desc", "mana_cost", "cast_time", "cooldown", "base_damage", "damage_type", "target_type", "heal_amount", "classes"]

static func validate() -> void:
	for entry in ALL:
		for key in REQUIRED_KEYS:
			if not entry.has(key):
				push_error("SpellDefinitions: entry '%s' is missing required key '%s'" % [entry.get("name", "?"), key])
const ALL: Array = [
	# ── Magician ──────────────────────────────────────────────────────────────
	{"name": "Fireball",        "desc": "Hurls a ball of flame at the target.",              "mana_cost": 30.0, "cast_time": 1.5, "cooldown": 8.0,  "base_damage": 50.0, "damage_type": "FIRE",      "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Magician"]},
	{"name": "Frost Bolt",      "desc": "A bolt of freezing ice.",                           "mana_cost": 20.0, "cast_time": 0.0, "cooldown": 4.0,  "base_damage": 30.0, "damage_type": "ICE",       "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Magician"]},
	{"name": "Lightning Strike","desc": "Calls down a bolt of lightning.",                  "mana_cost": 40.0, "cast_time": 2.0, "cooldown": 12.0, "base_damage": 80.0, "damage_type": "LIGHTNING", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Magician"]},
	{"name": "Heal",            "desc": "Restores HP to yourself.",                         "mana_cost": 25.0, "cast_time": 1.0, "cooldown": 6.0,  "base_damage": 0.0,  "damage_type": "NONE",      "target_type": "SELF",  "heal_amount": 40.0, "classes": ["Magician"]},
	{"name": "Arcane Missile",  "desc": "Rapid arcane shots.",                              "mana_cost": 15.0, "cast_time": 0.0, "cooldown": 2.0,  "base_damage": 20.0, "damage_type": "ARCANE",    "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Magician"]},

	# ── Cleric ────────────────────────────────────────────────────────────────
	{"name": "Healing Light",   "desc": "Calls down a beam of holy light to mend wounds.",  "mana_cost": 35.0, "cast_time": 1.2, "cooldown": 5.0,  "base_damage": 0.0,  "damage_type": "HOLY",  "target_type": "SELF",  "heal_amount": 60.0,  "classes": ["Cleric"]},
	{"name": "Greater Heal",    "desc": "A powerful prayer that restores a great amount of health.", "mana_cost": 55.0, "cast_time": 2.5, "cooldown": 12.0, "base_damage": 0.0, "damage_type": "HOLY", "target_type": "SELF", "heal_amount": 120.0, "classes": ["Cleric"]},
	{"name": "Smite",           "desc": "Channels divine wrath into a burst of holy energy.", "mana_cost": 20.0, "cast_time": 0.0, "cooldown": 3.0, "base_damage": 35.0, "damage_type": "HOLY",  "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Cleric"]},
	{"name": "Divine Wrath",    "desc": "Calls upon holy power to devastate the wicked.",   "mana_cost": 40.0, "cast_time": 1.8, "cooldown": 10.0, "base_damage": 75.0, "damage_type": "HOLY",  "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Cleric"]},

	# ── Druid ─────────────────────────────────────────────────────────────────
	{"name": "Regrowth",        "desc": "Wraps the caster in natural energies that mend wounds over time.", "mana_cost": 25.0, "cast_time": 1.0, "cooldown": 6.0,  "base_damage": 0.0,  "damage_type": "NATURE", "target_type": "SELF",  "heal_amount": 0.0, "hot_hps": 5.0, "hot_duration": 18.0, "classes": ["Druid"]},
	{"name": "Wrath",           "desc": "Channels raw natural energy into a damaging strike.", "mana_cost": 20.0, "cast_time": 0.0, "cooldown": 3.5,  "base_damage": 25.0, "damage_type": "NATURE", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Druid"]},
	{"name": "Call Lightning",  "desc": "Summons a storm bolt from the sky.",                "mana_cost": 35.0, "cast_time": 1.5, "cooldown": 9.0,  "base_damage": 65.0, "damage_type": "NATURE", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Druid"]},
	{"name": "Entangle",        "desc": "Lashes the target with writhing vines that continue to tear at them.", "mana_cost": 18.0, "cast_time": 0.0, "cooldown": 18.0, "base_damage": 10.0, "damage_type": "NATURE", "target_type": "ENEMY", "heal_amount": 0.0, "dot_dps": 5.0, "dot_duration": 18.0, "classes": ["Druid"]},

	# ── Shaman ────────────────────────────────────────────────────────────────
	{"name": "Healing Wave",    "desc": "Calls upon ancestor spirits to mend wounds over time.", "mana_cost": 30.0, "cast_time": 1.0, "cooldown": 6.0,  "base_damage": 0.0,  "damage_type": "SPIRIT", "target_type": "SELF",  "heal_amount": 15.0, "hot_hps": 4.0, "hot_duration": 18.0, "classes": ["Shaman"]},
	{"name": "Mending",         "desc": "A quick spiritual mend for minor wounds.",          "mana_cost": 15.0, "cast_time": 0.5, "cooldown": 4.0,  "base_damage": 0.0,  "damage_type": "SPIRIT", "target_type": "SELF",  "heal_amount": 25.0, "classes": ["Shaman"]},
	{"name": "Spirit Bolt",     "desc": "Launches a bolt of concentrated spirit energy.",    "mana_cost": 20.0, "cast_time": 0.0, "cooldown": 3.0,  "base_damage": 28.0, "damage_type": "SPIRIT", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Shaman"]},
	{"name": "Ancestral Strike","desc": "Calls ancestral fury down upon the enemy.",         "mana_cost": 40.0, "cast_time": 2.0, "cooldown": 10.0, "base_damage": 70.0, "damage_type": "SPIRIT", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Shaman"]},

	# ── Blood Mage ────────────────────────────────────────────────────────────
	{"name": "Blood Bolt",      "desc": "Hurls a razor-sharp shard of solidified blood.",   "mana_cost": 20.0, "cast_time": 0.0, "cooldown": 3.0,  "base_damage": 35.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Blood Mage"]},
	{"name": "Crimson Bolt",    "desc": "A quick lash of shadowy blood-fire.",               "mana_cost": 15.0, "cast_time": 0.0, "cooldown": 2.5,  "base_damage": 22.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Blood Mage"]},
	{"name": "Life Drain",      "desc": "Siphons the life force from the target to restore your own.", "mana_cost": 30.0, "cast_time": 0.5, "cooldown": 7.0, "base_damage": 40.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 20.0, "classes": ["Blood Mage"]},
	{"name": "Hemorrhage",      "desc": "Tears open deep wounds that deal massive shadow damage.", "mana_cost": 45.0, "cast_time": 2.0, "cooldown": 12.0, "base_damage": 90.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Blood Mage"]},

	# ── Paladin ───────────────────────────────────────────────────────────────
	{"name": "Lay on Hands",    "desc": "Channels pure divine energy to restore a massive amount of health.", "mana_cost": 45.0, "cast_time": 2.0, "cooldown": 15.0, "base_damage": 0.0, "damage_type": "HOLY", "target_type": "SELF", "heal_amount": 80.0, "classes": ["Paladin"]},
	{"name": "Crusader's Mend", "desc": "A quick blessing that mends wounds mid-combat.",    "mana_cost": 20.0, "cast_time": 0.5, "cooldown": 5.0,  "base_damage": 0.0,  "damage_type": "HOLY", "target_type": "SELF",  "heal_amount": 35.0, "classes": ["Paladin"]},
	{"name": "Righteous Fire",  "desc": "Blasts the target with a burst of divine flame.",   "mana_cost": 25.0, "cast_time": 0.0, "cooldown": 4.0,  "base_damage": 45.0, "damage_type": "HOLY", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Paladin"]},
	{"name": "Judgment",        "desc": "Calls divine judgment down upon a wicked target.",  "mana_cost": 40.0, "cast_time": 2.0, "cooldown": 10.0, "base_damage": 80.0, "damage_type": "HOLY", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Paladin"]},

	# ── Shadow Knight ─────────────────────────────────────────────────────────
	{"name": "Lifetap",         "desc": "Drains the target's life force to restore your own.", "mana_cost": 30.0, "cast_time": 0.5, "cooldown": 6.0, "base_damage": 35.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 25.0, "classes": ["Shadow Knight"]},
	{"name": "Siphon",          "desc": "Rapidly bleeds shadow energy from the target.",      "mana_cost": 15.0, "cast_time": 0.0, "cooldown": 3.0,  "base_damage": 20.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Shadow Knight"]},
	{"name": "Dark Shroud",     "desc": "Wraps the target in suffocating shadow.",            "mana_cost": 35.0, "cast_time": 1.5, "cooldown": 9.0,  "base_damage": 55.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Shadow Knight"]},

	# ── Necromancer ───────────────────────────────────────────────────────────
	{"name": "Summon Skeleton", "desc": "Raises a loyal skeleton warrior to fight at your side.", "mana_cost": 60.0, "cast_time": 3.0, "cooldown": 30.0, "base_damage": 0.0, "damage_type": "NONE", "target_type": "PET_SUMMON", "heal_amount": 0.0, "pet_type": "skeleton", "classes": ["Necromancer"]},
	{"name": "Bone Shards",     "desc": "Launches a volley of razor-sharp bone fragments.",  "mana_cost": 18.0, "cast_time": 0.0, "cooldown": 3.0,  "base_damage": 30.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Necromancer"]},
	{"name": "Soul Drain",      "desc": "Tears the soul partially free, dealing damage and healing the caster.", "mana_cost": 28.0, "cast_time": 0.5, "cooldown": 6.0, "base_damage": 40.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 15.0, "classes": ["Necromancer"]},
	{"name": "Dark Decay",      "desc": "Fills the target with necrotic corruption that festers and spreads.", "mana_cost": 40.0, "cast_time": 2.0, "cooldown": 24.0, "base_damage": 20.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0, "dot_dps": 7.0, "dot_duration": 24.0, "classes": ["Necromancer"]},
	{"name": "Enervation",      "desc": "A powerful curse that strips vitality to nothing.", "mana_cost": 50.0, "cast_time": 3.0, "cooldown": 15.0, "base_damage": 85.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Necromancer"]},

	# ── Enchanter ─────────────────────────────────────────────────────────────
	{"name": "Charm",              "desc": "Bends the target's will, forcing it to fight for you. Lasts 60 seconds.", "mana_cost": 40.0, "cast_time": 2.0, "cooldown": 60.0, "base_damage": 0.0, "damage_type": "ARCANE", "target_type": "PET_CHARM", "heal_amount": 0.0, "duration": 60.0, "classes": ["Enchanter"]},
	{"name": "Color Spray",        "desc": "A prismatic burst of arcane light that overwhelms the senses.", "mana_cost": 15.0, "cast_time": 0.0, "cooldown": 3.0, "base_damage": 25.0, "damage_type": "ARCANE", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Enchanter"]},
	{"name": "Mesmerize",          "desc": "Locks the target in a waking dream. Breaks on damage.",         "mana_cost": 20.0, "cast_time": 0.0, "cooldown": 12.0, "base_damage": 0.0, "damage_type": "ARCANE", "target_type": "ENEMY", "heal_amount": 0.0, "cc_duration": 12.0, "classes": ["Enchanter"]},
	{"name": "Rune",               "desc": "Inscribes a protective rune that absorbs incoming harm.",       "mana_cost": 25.0, "cast_time": 0.0, "cooldown": 8.0,  "base_damage": 0.0, "damage_type": "ARCANE", "target_type": "SELF",  "heal_amount": 0.0, "absorb_amount": 40.0, "classes": ["Enchanter"]},
	{"name": "Cascade of Stars",   "desc": "A torrent of arcane energy that batters the target.",           "mana_cost": 35.0, "cast_time": 1.5, "cooldown": 10.0,"base_damage": 55.0, "damage_type": "ARCANE", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Enchanter"]},

	# ── Bard ──────────────────────────────────────────────────────────────────
	{"name": "Siren's Song",    "desc": "A haunting melody that ensnares a foe's mind and turns it to your cause. Lasts 30 seconds.", "mana_cost": 30.0, "cast_time": 1.5, "cooldown": 45.0, "base_damage": 0.0, "damage_type": "ARCANE", "target_type": "PET_CHARM", "heal_amount": 0.0, "duration": 30.0, "classes": ["Bard"]},
	{"name": "Dissonance",      "desc": "Strikes the target with a painful chord of raw arcane sound.", "mana_cost": 15.0, "cast_time": 0.0, "cooldown": 3.0, "base_damage": 20.0, "damage_type": "ARCANE", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Bard"]},
	{"name": "Battle Hymn",     "desc": "A rousing song that patches wounds and steadies the spirit.", "mana_cost": 20.0, "cast_time": 0.5, "cooldown": 6.0, "base_damage": 0.0,  "damage_type": "ARCANE", "target_type": "SELF",  "heal_amount": 30.0, "classes": ["Bard"]},
	{"name": "Chorus of Misery","desc": "A dirge that makes the target feel every wound it has ever taken.", "mana_cost": 30.0, "cast_time": 1.5, "cooldown": 9.0, "base_damage": 45.0, "damage_type": "ARCANE", "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Bard"]},

	# ── Ranger ────────────────────────────────────────────────────────────────
	{"name": "Hunter's Mark",   "desc": "Designates the target, increasing the effectiveness of your strikes.", "mana_cost": 15.0, "cast_time": 0.0, "cooldown": 3.5, "base_damage": 25.0, "damage_type": "NATURE", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Ranger"]},
	{"name": "Nature's Cure",   "desc": "Draws on forest magic to close wounds and restore vitality.", "mana_cost": 20.0, "cast_time": 0.5, "cooldown": 5.0, "base_damage": 0.0, "damage_type": "NATURE", "target_type": "SELF",  "heal_amount": 35.0, "classes": ["Ranger"]},

	# ── Witch Hunter ──────────────────────────────────────────────────────────
	{"name": "Witchfire",       "desc": "Ignites the target with cursed flame that burns through magical defenses.", "mana_cost": 22.0, "cast_time": 0.0, "cooldown": 4.0,  "base_damage": 35.0, "damage_type": "FIRE",  "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Witch Hunter"]},
	{"name": "Expose",          "desc": "Strips away the target's protections in a burst of scouring shadow.",       "mana_cost": 15.0, "cast_time": 0.0, "cooldown": 3.0,  "base_damage": 20.0, "damage_type": "SHADOW","target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Witch Hunter"]},
	{"name": "Rite of Warding", "desc": "A hunter's prayer that seals wounds and steels the nerves.",                "mana_cost": 18.0, "cast_time": 0.5, "cooldown": 5.0,  "base_damage": 0.0,  "damage_type": "HOLY",  "target_type": "SELF",  "heal_amount": 30.0, "classes": ["Witch Hunter"]},
	{"name": "Banishment",      "desc": "Channels pure holy force to devastate corrupted and arcane targets.",        "mana_cost": 40.0, "cast_time": 1.8, "cooldown": 10.0, "base_damage": 70.0, "damage_type": "HOLY",  "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Witch Hunter"]},

	# ── Fallen Paladin (Paladin at Evil alignment) ────────────────────────────
	{"name": "Death's Embrace", "desc": "Channels dark devotion into a crushing wave of shadow damage.",        "mana_cost": 40.0, "cast_time": 0.0, "cooldown": 8.0,  "base_damage": 80.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Paladin_Fallen"]},
	{"name": "Blood Price",     "desc": "Seals your wounds with dark will — at a cost paid in flesh.",         "mana_cost": 20.0, "cast_time": 0.5, "cooldown": 5.0,  "base_damage": 0.0,  "damage_type": "SHADOW", "target_type": "SELF",  "heal_amount": 35.0, "hp_cost": 15.0, "classes": ["Paladin_Fallen"]},
	{"name": "Shadow Flame",    "desc": "Blasts the target with dark fire that ignores holy defenses.",        "mana_cost": 25.0, "cast_time": 0.0, "cooldown": 4.0,  "base_damage": 55.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Paladin_Fallen"]},
	{"name": "Condemnation",    "desc": "Calls down shadow judgment. Devastating and demoralizing.",           "mana_cost": 40.0, "cast_time": 2.0, "cooldown": 10.0, "base_damage": 85.0, "damage_type": "SHADOW", "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Paladin_Fallen"]},

	# ── Redeemed Shadow Knight (Shadow Knight at Exalted alignment) ───────────
	{"name": "Sacrificial Mend","desc": "Pays for redemption in blood — heals wounds at a personal cost.",    "mana_cost": 20.0, "cast_time": 0.5, "cooldown": 5.0,  "base_damage": 0.0,  "damage_type": "HOLY",   "target_type": "SELF",  "heal_amount": 35.0, "hp_cost": 15.0, "classes": ["Shadow Knight_Redeemed"]},
	{"name": "Radiant Bolt",    "desc": "Launches a bolt of hard-won holy light.",                             "mana_cost": 15.0, "cast_time": 0.0, "cooldown": 3.0,  "base_damage": 38.0, "damage_type": "HOLY",   "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Shadow Knight_Redeemed"]},
	{"name": "Holy Mantle",     "desc": "Wraps shadow armor in holy fire, burning all who face it.",           "mana_cost": 35.0, "cast_time": 1.5, "cooldown": 9.0,  "base_damage": 55.0, "damage_type": "HOLY",   "target_type": "ENEMY", "heal_amount": 0.0,  "classes": ["Shadow Knight_Redeemed"]},

	# ── Wizard ────────────────────────────────────────────────────────────────
	{"name": "Ice Spear",    "desc": "A razor-sharp javelin of pure ice.",                             "mana_cost": 28.0, "cast_time": 1.0, "cooldown":  5.0, "base_damage":  50.0, "damage_type": "ICE",       "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Wizard"]},
	{"name": "Flame Wave",   "desc": "A crashing wave of superheated flame.",                         "mana_cost": 38.0, "cast_time": 1.8, "cooldown":  9.0, "base_damage":  75.0, "damage_type": "FIRE",      "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Wizard"]},
	{"name": "Thunder Clap", "desc": "Calls down a focused bolt of pure lightning.",                  "mana_cost": 50.0, "cast_time": 2.5, "cooldown": 14.0, "base_damage": 100.0, "damage_type": "LIGHTNING", "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Wizard"]},
	{"name": "Blizzard",     "desc": "An intense flash-freeze that deals heavy ice damage.",          "mana_cost": 45.0, "cast_time": 2.0, "cooldown": 12.0, "base_damage":  65.0, "damage_type": "ICE",       "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Wizard"]},
	{"name": "Meteor",       "desc": "Calls a fragment of burning stone from the sky.",               "mana_cost": 65.0, "cast_time": 3.5, "cooldown": 20.0, "base_damage": 130.0, "damage_type": "FIRE",      "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Wizard"]},

	# ── Sorcerer ──────────────────────────────────────────────────────────────
	{"name": "Arcane Burst", "desc": "A raw surge of innate arcane power.",                           "mana_cost": 18.0, "cast_time": 0.0, "cooldown":  3.0, "base_damage":  30.0, "damage_type": "ARCANE",    "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Sorcerer"]},
	{"name": "Void Lance",   "desc": "A spear of unformed magical force.",                            "mana_cost": 28.0, "cast_time": 1.0, "cooldown":  6.0, "base_damage":  55.0, "damage_type": "ARCANE",    "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Sorcerer"]},
	{"name": "Bloodfire",    "desc": "Ignites the target with sorcerous flame drawn from the blood.", "mana_cost": 22.0, "cast_time": 0.0, "cooldown":  4.0, "base_damage":  40.0, "damage_type": "FIRE",      "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Sorcerer"]},
	{"name": "Tempest Bolt", "desc": "A bolt of crackling sorcerous lightning.",                      "mana_cost": 35.0, "cast_time": 1.5, "cooldown": 10.0, "base_damage":  65.0, "damage_type": "LIGHTNING", "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Sorcerer"]},
	{"name": "Soul Surge",   "desc": "Channels raw sorcerous will into a devastating burst.",         "mana_cost": 45.0, "cast_time": 2.0, "cooldown": 14.0, "base_damage":  80.0, "damage_type": "ARCANE",    "target_type": "ENEMY", "heal_amount": 0.0, "classes": ["Sorcerer"]},

	# ── Beast Master ──────────────────────────────────────────────────────────
	{"name": "Spirit Mend",   "desc": "Calls on a thread of spirit energy to quickly close wounds.",                                        "mana_cost": 15.0, "cast_time": 0.5, "cooldown":  4.0, "base_damage":  0.0, "damage_type": "SPIRIT", "target_type": "SELF",     "heal_amount": 25.0, "classes": ["Beast Master"]},
	{"name": "Feral Shriek",  "desc": "A primal spirit cry that tears into the target and disrupts its movement.",                          "mana_cost": 22.0, "cast_time": 0.0, "cooldown":  6.0, "base_damage": 35.0, "damage_type": "SPIRIT", "target_type": "ENEMY",    "heal_amount":  0.0, "classes": ["Beast Master"]},
	{"name": "Warder's Mend", "desc": "Channels spirit energy into your warder, mending its wounds.",                                      "mana_cost": 30.0, "cast_time": 1.5, "cooldown":  8.0, "base_damage":  0.0, "damage_type": "SPIRIT", "target_type": "PET_HEAL", "heal_amount": 60.0, "classes": ["Beast Master"]},
	{"name": "Primal Bond",   "desc": "Deepens the spirit bond, sharpening the reflexes of both hunter and warder. (Haste — design target)", "mana_cost": 25.0, "cast_time": 1.5, "cooldown": 30.0, "base_damage":  0.0, "damage_type": "SPIRIT", "target_type": "SELF",     "heal_amount":  0.0, "absorb_amount": 40.0, "classes": ["Beast Master"]},
	{"name": "Spirit Strike", "desc": "Hurls a focused bolt of pure spirit energy at the target.",                                         "mana_cost": 35.0, "cast_time": 2.0, "cooldown": 10.0, "base_damage": 55.0, "damage_type": "SPIRIT", "target_type": "ENEMY",    "heal_amount":  0.0, "classes": ["Beast Master"]},
]
