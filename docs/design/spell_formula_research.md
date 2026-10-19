# Spell damage and healing formulas: how other games do it

**Researched 2026-10-19** at the user's request ("do research on other spell formulas used in
other games. Perhaps even take into account Dungeons and Dragons?"), after the server took over
the client's spell formula as is (client-authority audit fix 3, server `b81da60`). This is a
reference for the later balance pass, not a decision. Claims marked *verified* were re-read by
hand on the source page; the rest come from a research sweep and say so.

## Our formula today

From `autoloads/spells.gd`, now computed on the server in `world/spell_power.rs`:

- **Nuke:** `(base_damage + INT x 0.5) x evocation`, evocation 1.0 to 1.15 with skill.
- **Heal:** `heal_amount + WIS x 0.3`.
- **Crit:** chance `(INT - 10) x 0.002`, at most 20%, for 1.5x to 2x.
- Absorbs x abjuration (to 1.20), timed effects x alteration (to 1.25).

What it does across levels (server stat tables, `char_data.rs`):

| | Level 1 | Level 12 to 20 | Level 60 |
|---|---|---|---|
| Gnome Wizard INT, nuke bonus | 43, +21 | 119 at 20, +60 | 279, +140 |
| Human Cleric WIS, heal bonus | 24, +7 | 81 at 20, +24 | 201, +60 |
| A 30-damage level 1 nuke | 51 (+70%) | | |
| Banishment (70, level 12) | | 113 at INT 87 (+62%) | |
| Greater Heal (120, level 8) | | 133 at WIS 45 (+11%) | |

The flat stat term is large against low-level spells and shrinks against big ones, and it
grows with the caster's level whatever spell is cast.

## How other games do it

**EverQuest classic (Project 1999).** Damage is set per spell, and a spell can scale with
the caster's level inside a band, capped: *verified*, P99 Lightning Shock, Wizard 39,
"Decrease Hitpoints by 381 (L39) to 405 (L45)" (https://wiki.project1999.com/Lightning_Shock).
INT and WIS set the mana pool and fizzle rate; no source found says they add damage or
healing (Allakhazam's stats page lists mana and fizzle only,
https://everquest.allakhazam.com/wiki/eq:Stats). This is an inference from silence, not a
quoted rule. Spell crits arrived late, as an alternate-advancement ability at level 55 in
Shadows of Luclin: "increase your chance to score a critical by 2, 4, and 7 percent", with
crit damage +40, 60 and 100 percent (https://everquest.allakhazam.com/wiki/eq:Spell_Casting_Fury).
Before that, Wizards were said to be the only class whose nukes could crit
(https://almarsguides.com/eq/endgame/classguides/classic-por/wizard/). Power beyond the spell
came from **focus items**, a percentage bonus (direct damage 20 to 45% on Allakhazam's
later-era table), cut by 5% of its value per level when the spell is above the focus's level
bound (https://everquest.allakhazam.com/wiki/eq:Foci).

**EverQuest II.** A 2007 forum post says INT increases spell damage; the "potency" rule could
not be confirmed. Unverified.

**World of Warcraft.** *Verified:* each spell has its own spell power coefficient, and "casters
now gain 1 spell power per point of intellect" only from patch 4.0.1 (2010); before that, INT
gave mana and crit, not damage (https://warcraft.wiki.gg/wiki/Spell_power). The classic
coefficient rule, from Allakhazam's page: "[Cast Time of Spell] / 3.5 = [Coefficient]", capped
at 200%, damage over time "[Duration of Spell] / 15", and a penalty for spells below level 20
and for down-ranking (https://everquest.allakhazam.com/wiki/spell_coefficient_(WoW)). Crit chance
grows with Intellect plus gear rating; crit size was 1.5x and later 2.0x
(https://warcraft.wiki.gg/wiki/Spell_critical_strike).

**Dungeons & Dragons 5e.** Damage is dice set by the spell and the slot it is cast in, and the
ability modifier mostly feeds the attack roll and the save DC, not damage: "Spell attack
modifier = your spellcasting ability modifier + your Proficiency Bonus"
(https://www.dndbeyond.com/sources/dnd/free-rules/spells). Cantrips scale with character level
(Fire Bolt 1d10, then 2d10, 3d10, 4d10 at levels 5, 11 and 17,
https://roll20.net/compendium/dnd5e/Fire%20Bolt). Healing is the notable exception that adds
the modifier: *verified*, Cure Wounds heals "1d8 + your spellcasting ability modifier" and "the
healing increases by 1d8 for each slot level above 1st"
(https://dnd-srd-sphinx.readthedocs.io/en/latest/spell/cure-wounds.html). **3.5e** scales by
caster level with a cap: Fireball "1d6 points of fire damage per caster level (maximum 10d6)"
(https://www.d20srd.org/srd/spells/fireball).

**Monsters and Memories.** *Verified:* INT "increases damage done on offensive damage spells"
and WIS "increases healing done on healing spells"; no number is published
(https://monstersandmemories.miraheze.org/wiki/Statistics). A spell description mentions a
percentage "Spell Damage" buff, which suggests their spell modifiers are percentages.

**Lineage II.** Magic damage comes from the caster's M.Atk against the target's M.Def with the
skill's power as a multiplier (`91 x sqrt(M.Atk) / M.Def x power` in one emulator version);
the two emulator versions found disagree, so the exact form is unverified. **Star Wars
Galaxies:** nothing solid found.

## The patterns

1. **Fixed per spell** (classic EQ). Power comes from learning bigger spells; stats mean mana.
   Easy to tune per tier; stat growth does nothing for a given spell.
2. **Level-scaled with a cap** (EQ's level bands, 3.5e Fireball, 5e cantrips). A spell grows
   with its caster but stops, so an old spell cannot outgrow its tier.
3. **Percentage multipliers** (EQ foci, M&M's spell-damage buff). Proportionate at every
   level, because they scale with the spell's own size.
4. **Flat stat bonus** (our formula; WoW spell power before coefficients; D&D's modifier on
   heals). Large on small spells, small on big ones. WoW's answer was a per-spell coefficient
   (cast time / 3.5), so the bonus scales with the spell's size and cast length.
5. **Dice and ability-to-hit** (D&D). Stats decide whether a spell lands, not how hard it
   hits; healing is the exception.
6. **Ratio models** (Lineage II). Caster power against target defence.

**Crits:** classic EQ made them late and earned (an AA, 2 to 7%); WoW ties them to Intellect
and gear (1.5x, later 2x); our 20% cap at 1.5 to 2x sits nearer WoW's.

**Where our formula sits:** pattern 4, the one with the low-level problem: a flat
`INT x 0.5` adds about 70% to a level 1 nuke but under half that to a big late spell. If the
first playtest finds low-level nukes too strong, the options the other games point to are a
per-spell coefficient (WoW), a percentage bonus instead of a flat one (EQ foci, M&M), or
level-scaled spells with caps (EQ, D&D 3.5). All of them are changes to `spell_power.rs` and
`autoloads/spells.gd` together.
