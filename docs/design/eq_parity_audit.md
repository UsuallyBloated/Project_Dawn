# EQ Parity Audit (2026-10-20)

Every spell, active skill, mob, weapon and player pool we have, set against its Project 1999
counterpart (classic EverQuest through Velious), with the ratio and a recommendation. Research
only: nothing in either repo changes from this document. The user makes the calls at the end
(§8); the changes are then data edits on both sides, held together by the lockstep checks.

Asked for by the user on 2026-10-20 ("a lot of our spells, skills, effects, etc are pretty
over inflated"), after the Bard song pass found Mana Weave at twelve times P99's mana song.
Baseline, scope and the user's time were settled the same day: P99; spells and active skills
first, then mobs, player pools and regen, weapon bands, XP; the user's calls on one table.

## 1. How to read it

**Sources.** PQDI (pqdi.cc), which lists every class's spells by level with the effect
numbers and their level scaling, and fetches cleanly; the Project 1999 wiki for mob stats,
weapons and mechanics (its certificate refuses direct fetches, so its figures come through
search summaries and its forum threads); EQEmu's server source for the formulas P99 does not
publish (player pools, skill damage). Every number below names its source in §9.

**Era caveat.** PQDI's lists run to level 65 and include spells from Luclin and later (anything
with a level 51 to 65 figure, "Celestial", "Blessing of", most of the pet focus lines).
Where a counterpart is from a later era it is marked *(later era)* and the nearest classic
spell is given beside it. Beastlord is a Luclin class; it is used for Beast Master only as the
nearest shape, marked throughout.

**The comparison principle: ratios at the same level, not raw numbers.** A whole game could be
scaled by a constant and feel identical. What matters is how a level-N player's spell measures
against a level-N mob's hit points, how a level-N mob's hit measures against the player's
pool, and how steeply each climbs. So the headline (§2) reads the ratios; the tables give the
numbers.

**EQ numbers scale within one spell.** An EQ spell's effect usually grows with the caster's
level ("Strike: 7 at L1 to 8 at L4"). Ours are fixed per rank and grow by rank. Where ours has
ranks, each rank is set against EQ's value at that rank's level.

**What this pass did not compare**, because PQDI's lists do not carry them: mana costs and
cast times (per-spell pages hold them; a second pass if wanted). Cooldowns are not an EQ
concept (a spell can be recast after its cast time plus the gem refresh); ours have them by
design, and that difference is noted, not scored.

## 2. The headline: where the inflation is, and where it is not

| Area | Verdict | The number |
|---|---|---|
| **Player hit points and mana at level 1** | **Inflated 6 to 10x** | A Human Warrior starts with 200 HP here; EQ's formula gives 32. A Wizard 105 here, 20 there. A Wizard's mana 210 here, 22 there. |
| Player pools at level 50 | **In line for melee and priests; casters under** | Our Warrior reaches about 1,670 HP at 50; EQ's 1,692. The per-level gain is EQ's; the start is not. A Wizard ends at about 240 against EQ's 755: its 3 HP a level is a quarter of EQ's. |
| **Level 1 to 10 spells, damage and heals** | **Inflated 4 to 6x** | Smite 35 at 1 vs Strike 7; Healing Light 60 at 1 vs Minor Healing 10; Fireball 50 at 1 vs Flame Bolt 41 at 8 (and nothing like it at 1). |
| Level 12 to 20 spells | **In line or under** | Meteor 130 at 18 vs Force Shock 171 at 20; Divine Wrath 75 at 12 vs Smite 74 at 14; Complete Heal at 20 vs EQ's at 39 (early, same shape). |
| **Regeneration buffs** (HoT, mana regen, Lich) | **Inflated 6 to 12x, and 12 to 33 levels early** | Clarity 8 mana a second at 14 vs EQ's Clarity 4 a tick (0.67 a second) at 29; Breeze 4 a second at 4 vs 2 a tick at 16; Regrowth 5 HP a second at 1 vs Regeneration 5 a tick at 34. |
| Haste | Inflated 1.7x | Haste 50% at 16 vs Quickness 28 to 30% at 16. |
| Stat buffs, damage shields, absorbs, roots, mez, snare, speed | In line (several early) | Rune 40 at 1 vs Rune I 27 to 55 at 16; Thorns 8 vs Shield of Thistles 6; Spirit of Wolf 1.4 vs 34 to 55%. |
| **Mob damage per hit** | **EQ's, almost to the point** | Ours 3, 5, 7, 9, 10, 12, 15, 20, 22, 26 at levels 1 to 12; EQ's classic cap is 2 x level + 2: 4, 6, 8, 10, 12, 14, 16, 20, 22, 26. |
| Mob hit points | Above at low levels, about 1.5 to 3x | A level 1 mob 24 to 25 HP here, 16 on P99 (a decaying skeleton, a gnoll pup); a level 4 to 6 mob 78 to 116 here, Fippy Darkpaw 39. |
| Weapons | In line | Copper Short Sword 4 to 9 vs a Rusty Short Sword's 4 damage (an 8 max hit at level 1); delays 2.5 to 3.2 s vs EQ's 2.3 to 4.1. |
| Active skills | In line at the low end | Backstab 3x vs EQ's 3x at skill 50 (6.5x at max); Flying Kick 2.2x of a swing vs EQ's flat 25 plus skill. |
| Regen rates | **Already P99's** | Our HP regen table is the P99 table (1 standing, 2 sitting at low level); mana 1 standing, 2 plus meditate sitting. |
| XP curve | **Already EQ's** | The cubic curve with hell levels, 2026-06-26. |

**So the inflation is on the player's side at low levels, and almost nowhere else.** A level 1
character here has six times EQ's hit points and casts spells five times EQ's size, against
mobs that hit for EQ's numbers and carry about one and a half times EQ's hit points. The
consequences in play: a level 1 fighter takes some sixty hits to die (EQ: about twelve); a
level 1 caster kills a mob in one or two casts (EQ: three or four); nothing at level 1 is
dangerous. By level 12 to 20 the numbers have converged with EQ's, so the curve is flat at the
start and EQ-shaped after: exactly the "level 1 as capable as level 10" the user named. The
fix is reshaping the bottom of three curves (pools, low-level spells, regen buffs), not a
global cut.

## 3. Player pools

EQ's base hit points (EQEmu's classic path, `Client::CalcBaseHP`):
`5 + level x factor / 10 + STA x level x factor / 3000`, the factor by class (Warrior 220
under 20, 270 by 50; Paladin and Shadow Knight 210 to 230; Monk, Bard, Rogue 180; Ranger 200;
Cleric, Druid, Shaman 150; Wizard, Magician, Necromancer, Enchanter 120). Base mana for a
caster with 100 INT or WIS: `22.5 x level`.

| Character | Ours, level 1 | EQ, level 1 | Ratio | Ours, 50 | EQ, 50 |
|---|---|---|---|---|---|
| Human Warrior HP | 200 (100 base + 50 class + 50 from CON 20) | 32 (STA 75) | 6.3x | about 1,670 | 1,692 |
| Human Wizard HP | 95 (100 - 15 class + 10 from CON 12) | 20 | 4.8x | about 240 | 755 |
| Human Cleric HP | 180 | 24 | 7.5x | about 1,010 | 942 |
| Human Wizard mana | 210 (100 base + 110 class) | 22 (INT 100) | 9.5x | about 1,580 | 1,125 |
| Human Cleric mana | 160 | 22 (WIS 100) | 7x | about 1,140 | 1,125 |

Ours: `BASE_HP 100 + class bonus + (CON - 10) x 5` at level 1, then the class's per-level gain
plus 5 HP for every point of CON the level adds (`char_data.rs`, `compute` and `level_gains`).
The gains are close to EQ's slope for melee and priests (a Warrior adds 30 a level counting its
CON, EQ's about 34); the casters' HP gain (3 a level, no CON) is a quarter of EQ's 15, which is
why the Wizard ends at a third. EQ's level 50 figures are the classic formula with STA 75 and
the level 50 class factors (Warrior 270, priests 150, casters 120); mana is `22.5 x level`
for a 100-stat caster at every level in the classic branch.

**Recommendation:** adopt EQ's formula outright for base HP and mana (it is five lines, and
the client's `apply_character` mirrors it), with our stats in place of STA/INT/WIS. A level 1
Warrior then starts at about 32, a Wizard at 20 with 22 mana, and level 50 lands where ours
already does. Everything that reads max HP (the res-sickness quarter, the seated rule, mob
damage) follows. This is the single largest change in the document and the one every other
row's feel depends on, so it is listed first in §8.

## 4. Spells, by class

Columns: ours (level, effect), the P99 counterpart (level, effect at that level, the spell's
range where it scales), the ratio of ours to EQ's at our level, and a note. "Early" means we
give the effect at a lower level than EQ. Ratios are of the main effect.

### Cleric

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Smite 35 at 1 | Strike, 7 to 8 (L1 to 4) | 5x | |
| Smite Rk. II 50 at 8 | Furor 17 to 19 (L5 to 10) | 2.8x | |
| Divine Wrath 75 at 12 | Smite 74 to 83 (L14 to 23) | 1x | in line, 2 levels early |
| Healing Light 60 at 1 | Minor Healing 10 | 6x | |
| Healing Light Rk. II 85 at 8 | Light Healing 26 to 33 (L5 to 18) | 2.9x | |
| Greater Heal 120 at 8 | Healing 84 to 100 (L14 to 30) | 1.3x of a L14 spell | 6 levels early |
| Healing Light Rk. III 115 at 16 | Healing 84 to 100 | 1.2x | in line |
| Complete Heal 9999 at 20 | Complete Healing 7500 at 39 | same shape | 19 levels early; EQ's was the defining Cleric spell of the 40s |
| Valor +10 STR, +50 HP at 10 | Center +44 to 100 HP (L9+), no STR; Courage +11 to 20 HP at 1 | in line | |
| Bless +5 WIS at 4 | no classic Cleric WIS buff below 44 | n/a | |
| Resurrection (Minor) 25% at 20, Resurrection 50% at 30, Resurrection II 75% at 45 | Reanimation 0% at 14, Reconstitution 10% at 19, Reparation 20% at 24, Revive 35% at 29, Renewal 50% at 34, Resuscitate 60% at 39, Restoration 75% at 44, Resurrection 90% at 49 | in line | the 25/50/75 tiers were the 2026-06-22 lock |
| Summon Drink at 3 / Food at 9 | Summon Drink at 5, Summon Food at 9 | in line | ours conjures up to 10 (user, 2026-10-19); EQ one |

### Paladin

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Righteous Fire 45 at 1 | no Paladin nuke until Flame of Light 125 at 50; Ward Undead 35 to 41 (L15, undead only) | 6x of the L1 Cleric Strike | Paladins did not nuke in classic |
| Righteous Fire Rk. II 63 at 8 | as above | | |
| Judgment 80 at 12 | Holy Might 29 to 60 plus a 6 s stun, at 49 | n/a | no classic counterpart at 12 |
| Crusader's Mend 35 at 1 | Minor Healing 10 at 9 | 3.5x, 8 levels early | EQ Paladins heal from 9 |
| Crusader's Mend Rk. II 50 at 8 | Minor Healing 10 at 9; Light Healing 26 to 33 at 15 | 5x | |
| Lay on Hands 80 at 6 | Lay on Hands 33 at 1 (to 2,081 at 65), once a day | 2.4x | EQ's was a once-a-day clicky, not a spell |
| Reclaim Soul 20% res at 35 | Revive 35% at 39 | in line | |

### Shadow Knight

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Siphon 20 at 1 | Lifetap 4 to 5 (L9 for SKs; L1 Necro) | 4.5x, 8 levels early | |
| Siphon Rk. II 32 at 6 | Lifespike 9 to 11 (L15) | 3x | |
| Lifetap 35 + 25 heal at 4 | Lifetap 4 to 5 taps the same | 7x | EQ's tap heals what it deals |
| Lifetap Rk. II 50 + 35 at 10 | Lifedraw 39 to 45 at 30 | 1.2x, 20 levels early | |
| Dark Shroud 55 at 10 | Spear of Disease 130 at 34; nothing at 10 | n/a | |
| Harm Touch (skill) 2.5x swing at 1 | Harm Touch: level x 10 + 1, once a day | | ours is a swing multiplier on a 12 s cooldown; EQ's a daily nuke |

### Druid

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Wrath 25 at 1 | Burst of Flame 4 to 5 | 5.5x | |
| Wrath Rk. II 38 at 6 | Burst of Fire 13 to 15 (L5 to 10) | 2.7x | |
| Call Lightning 65 at 8 | Ignite 32 to 37 (L9 to 14) | 1.9x | |
| Wrath Rk. III 55 at 14 | Careless Lightning 94 to 99 (L19) | 0.6x | under |
| Nature's Wrath AOE 40 at 16 | Cascade of Hail 27 AE at 14; Pogonip 62 at 24 | in line | |
| Regrowth HoT 5 HP/s (30 a tick) at 1 | Regeneration 5 a tick at 34; nothing below | 6x, 33 levels early | **the biggest early gift in the game** |
| Regrowth Rk. II 7/s at 8 | as above | 8x | |
| Entangle 10 + 5/s DoT (15 a tick) at 6 | Flame Lick 2 to 3 a tick at 1; Stinging Swarm 13 a tick at 14 | 5x of L1, in line with L14 | 8 levels early |
| Snare 50% at 4 | Snare 41 to 55% at 1 | in line | |
| Ensnare root at 14 | Grasping Roots at 5 | in line, late | |
| Thorns DS 8 at 10 | Shield of Thistles 6 at 9 | in line | |
| Spirit of Wolf 1.4 at 12 | Spirit of Wolf +34 to 55% (L9 to 50) | in line | EQ's scaled by level |
| Succor at 12, Evacuate at 16 | Lesser Succor at 18, Succor at 29 | 6 to 13 levels early | |

### Shaman

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Spirit Bolt 28 at 1 | Burst of Flame 4 to 5 | 6x | |
| Spirit Bolt Rk. II 40 at 6 | Frost Rift 13 to 15 (L5 to 10) | 2.9x | |
| Ancestral Strike 70 at 12 | Spirit Strike 74 to 81 (L14 to 21) | 0.9x | in line |
| Spirit Bolt Rk. III 55 at 14 | Spirit Strike 74 | 0.7x | under |
| Mending 25 at 1 | Minor Healing 10 | 2.5x | the closest of the level-1 heals |
| Mending Rk. II 38 at 6 | Light Healing 26 to 33 (L9) | 1.2x | in line |
| Healing Wave 15 + HoT 4/s at 4 | nothing: Regeneration 5 a tick at 24 | 5x, 20 levels early | |
| Spirit of the Bear +10 STR +5 CON at 10 | Spirit of Bear +12 to 15 STA at 9; Strengthen +5 to 10 STR at 1 | in line | |
| Gift of Insight +8 WIS +5 INT at 14 | no classic Shaman WIS buff | n/a | |
| Slow 5% at 8 (with Enchanter) | Drowsy 25% at 5; Walking Sleep 35% at 14 | 0.2x | **under EQ, the user's 2026-10-05 call** |
| Torpor 10% at 20 | Tagar's Insects 50% at 29 | 0.2x | under; the user's call |

### Magician

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Arcane Missile 20 at 1 | Burst of Flame 4 to 5 | 4.4x | |
| Frost Bolt 30 at 1 | Burn 11 to 14 at 4 | 2.7x of a L4 | |
| Fireball 50 at 1 | Flame Bolt 41 to 47 at 8 | 1.2x of a L8, 7 levels early | three nukes at level 1; EQ gave one |
| Heal 40 at 1 | no Magician heal (Renew Elements, pet only) | n/a | Magicians never healed players |
| Lightning Strike 80 at 6 | Shock of Flame 91 to 96 at 16 | 0.9x of a L16, 10 levels early | |
| Fireball Rk. II 70 at 8 | Flame Bolt 41 to 47 | 1.6x | |
| Inferno AOE 45 at 12 | Column of Fire 49 to 51 at 12 | in line | |
| Fireball Rk. III 95 at 16 | Shock of Flame 91 | in line | |
| Summon Drink / Food at 1 | Summon Drink and Food at 1 | in line | |

### Wizard (and Sorcerer, which has no EQ class; Wizard's lines are used)

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Ice Spear 50 at 1 | Frost Bolt 5 to 7; Shock of Frost 5 to 6 | 8x | the most inflated level-1 nuke |
| Flame Wave 75 at 4 | Shock of Fire 13 to 16 at 4 | 5x | |
| Blizzard 65 at 8 | Shock of Ice 34 to 38 at 8; Fire Bolt 45 to 51 | 1.5x | |
| Ice Spear Rk. II 70 at 10 | Shock of Lightning 78 to 83 at 12 | 0.9x | in line |
| Thunder Clap 100 at 10 | Flame Shock 102 to 110 at 16 | in line, 6 levels early | |
| Flame Wave Rk. II 105 at 12 | Lightning Bolt 117 to 125 at 16 | 0.9x | in line |
| Ice Storm AOE 70 at 14 | Pillar of Fire 68 to 76 AE at 16 | in line | |
| Meteor 130 at 18 | Force Shock 171 to 179 at 20 | 0.8x | in line |
| Sorcerer: Arcane Burst 30 at 1, Bloodfire 40 at 4, Void Lance 55 at 6, Tempest Bolt 65 at 10, Soul Surge 80 at 14, Arcane Nova AOE 65 at 18 | the Wizard lines above | 5x at 1, in line from 10 | the same shape as the Wizard |
| Bind Affinity at 1 (ten classes) | Bind Affinity at 12 to 14 | 11 levels early | |
| Gate at 8 (ten classes) | Gate at 4 to 5 | in line | |

### Enchanter

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Color Spray 25 at 1 | Shallow Breath 4 to 5 at 1; Chaotic Feedback 43 to 48 at 8 | 5x | EQ's Color Flux at 4 was a stun, no damage |
| Color Spray Rk. II 38 at 6 | Chaotic Feedback 43 at 8 | in line | |
| Cascade of Stars 55 at 12 | Sanity Warp 88 to 95 at 16 | 0.6x | under |
| Rune 40 at 1 | Rune I 27 to 55 at 16 | in line, 15 levels early | |
| Rune Rk. II 60 at 10 | Rune I 27 to 55 at 16 | in line | |
| Breeze 4 mana/s (24 a tick) at 4 | Breeze 2 a tick at 16 | **12x, 12 levels early** | |
| Clarity 8 mana/s (48 a tick) at 14 | Clarity 4 to 9 a tick at 29 | **12x, 15 levels early** | |
| Mesmerize 12 s at 6 | Mesmerize at 4 (to level 55) | in line | |
| Immobilize root 15 s at 8 | Root at 8 | in line | |
| Strength +12 at 8 | Strengthen +5 to 10 at 1 | 1.2x | |
| Brilliance +10 INT +5 WIS at 10 | Brilliance +12 INT at 44; Insight at 39 | 34 levels early | |
| Spellshield DS 10 at 10 | Feedback 11 at 29 | 19 levels early | |
| Haste 50% at 16 | Quickness 28 to 30% at 16; Alacrity 34 to 40% at 24 | 1.7x | |
| Charm 60 s at 20 | Charm (to level 25) at 12; Beguile at 24 | in line | |
| Slow 5% at 8 | Languid Pace 30% at 12 | 0.2x | under; the user's call |

### Necromancer (and Blood Mage, no EQ class; Necromancer's taps and DoTs are used)

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Bone Shards 30 at 1 | Lifetap 4 to 5 | 6.7x | |
| Soul Drain 40 + 15 heal at 4 | Lifespike 9 to 11 at 4 | 4x | |
| Bone Shards Rk. II 44 at 6 | Lifespike 9 to 11 | 4x | |
| Summon Skeleton at 6 | Leering Corpse at 4; Bone Walk at 8 | in line | |
| Dark Decay 20 + 7/s DoT (21 a tick) at 10 | Heat Blood 17 a tick at 12; Poison Bolt 5 a tick at 4 | 1.2x of a L12, 2 levels early | in line |
| Soul Drain Rk. II 58 + 25 at 10 | Lifedraw 39 to 45 at 12 | 1.4x | |
| Bone Shards Rk. III 62 at 14 | Siphon Life 65 to 75 at 20 | in line | |
| Enervation 85 at 16 | Shock of Poison 146 to 160 at 24 | 0.6x | under |
| Lich Form 8 mana/s (48 a tick) at 20 | Dark Pact 2 a tick at 8; Allure of Death 4 at 20; Call of Bones 8 at 34; Lich 20 a tick at 49 | **12x of the L20 spell; 2.4x of Lich itself, 29 levels early** | |
| Blood Mage: Crimson Bolt 22 at 1, Blood Bolt 35 at 4, Life Drain 40 + 20 at 6, Hemorrhage 90 at 12 | the Necromancer lines above | 5x at 1, 1.2x at 12 | |

### Bard (the songs are matched already; the rest)

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Dissonance 20 at 1, Rk. II 30 at 8 | Chords of Dissonance 3 to 19 a tick (AE, L2) ; Brusco's Boastful Bellow 7 at 12 | 3x | EQ Bards had no instant nuke |
| Chorus of Misery 45 at 10 | Brusco's 7 at 12 | 6x | |
| Battle Hymn 30 heal at 1, Rk. II 45 at 8 | Hymn of Restoration 2 a tick (L6) | n/a | EQ Bards had no direct heal |
| Siren's Song charm 30 s at 14 | Solon's Song of the Sirens at 27 | 13 levels early | |
| The six songs | matched 2026-10-20 | | Selos' on Selo's curve; Poet's, Wanderer's, Mana Weave to their P99 lines; Aria and Anthem on hold |

### Ranger (and Witch Hunter, no EQ class; Ranger and Paladin lines)

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Hunter's Mark 25 at 1 | Flame Lick 2 to 3 a tick at 9 (first Ranger spell); Burst of Fire 13 to 15 at 15 | 8x, 8 levels early | EQ Rangers cast from 9 |
| Hunter's Mark Rk. II 38 at 8 | Burst of Fire 13 to 15 at 15 | 2.7x | |
| Nature's Cure 35 at 1 | Minor Healing 10 at 9 | 3.5x, 8 levels early | |
| Ensnaring Roots 15 s at 6 | Grasping Roots at 15 | 9 levels early | |
| Hunter's Eye +15% accuracy, +10% crit at 10 | Hawk Eye (archery hit +10) at 15 | in line | |
| Witch Hunter: Witchfire 35 at 1, Rk. II 52 at 8, Banishment 70 at 12 | the Ranger and Paladin lines | 5x at 1 | |
| Expose (dispel) at 4, Antimagic Ward at 16 | Cancel Magic at 8 to 16 | in line | |
| Spellbreak silence 4 s at 8 | no classic silence | n/a | |

### Beast Master (Beastlord is a Luclin class; nearest shape only)

| Ours | EQ counterpart | Ratio | Note |
|---|---|---|---|
| Spirit Mend 25 at 1, Rk. II 38 at 8 | Minor Healing 10 at 9; Light Healing 26 to 33 at 22 | 2.5x, 8 levels early | |
| Warder's Mend 60 at 1 | Sharik's Replenishing 28 to 33 at 9 | 2x, 8 levels early | |
| Feral Shriek 35 at 4, Rk. II 50 at 10 | Blast of Frost 20 at 15 | 2.5x, 11 levels early | |
| Spirit Strike 55 at 12 | Spirit Strike 74 to 81 at 30 | 0.7x, 18 levels early | |
| Primal Bond absorb 40 at 8 | no Beastlord absorb | n/a | |

## 5. Active skills

EQ's skills are mostly flat base damage plus a skill bonus (EQEmu's classic path), not
multipliers of a swing; ours multiply a full swing. Compared at the levels our testers will meet.

| Ours | EQ | Verdict |
|---|---|---|
| Backstab 3x a swing, 6 s cooldown | weapon damage x (2 + skill x 0.02): 3x at skill 50 (about level 10), 6.5x at 225; every 10 s or so by the skill's reuse | in line at the low end; EQ's grows with skill |
| Shield Bash 1.2x + a 3 s stun | Bash: base 2 + skill/10 + shield AC; a stun chance, not a sure stun | ours stuns every time; EQ's Bash stun was a chance (and interrupted casts) |
| Flying Kick 2.2x | base 25 + skill/9 (a level 30 skill in EQ) | ours is earlier; EQ's a flat 25 to 50 |
| Tiger Claw 1.2x, Roundhouse 1.6x | Tiger Claw base 4, Round Kick base 5, plus skill | in line |
| Kick-type strikes (Slash 1.5x, Pummel 1.0x, Holy Strike 1.3x, Primal Strike 1.4x, Divine Blow 1.4x, Dark Strike 1.4x) | Kick: base 3 + skill/10 (Warriors, Rangers, Monks, Beastlords only); priests and knights had no strike skills | ours give every class a strike; EQ gave Kick to four classes |
| Harm Touch 2.5x on a 12 s cooldown | Harm Touch: level x 10 + 1 damage, once every 72 minutes | a different thing: EQ's was the Shadow Knight's daily |
| Aimed Shot 3x, True Shot 2x, Rapid Shot 2.1x (Ranger) | no classic archery skills beyond the bow swing | ours are new |
| Hide, Evade, Feign Death, Holy Shield | Hide, Evade (the hide-in-combat trick), Feign Death (Monk at 17, Shadow Knight at 30, Necromancer at 16), no absorb skill | in line; Holy Shield has no EQ counterpart |

## 6. Mobs

P99 reference points (the wiki): a decaying skeleton, level 1, 16 HP, hits 1 to 4; a gnoll pup,
level 1, 16 HP, 1 to 2; Fippy Darkpaw, level 4 to 6, 39 HP, 1 to 10; Tranixx Darkpaw, level 17,
1 to 34. The classic max-hit rule for an ordinary mob: 2 x level + 2 (giants and spectres +20).
EQEmu's default scaling has a level 50 trash mob at 10,000 HP hitting 74 to 204.

| Mob | Lvl | Our HP | Our dmg | EQ max hit (2L+2) | EQ HP at the level | Verdict |
|---|---|---|---|---|---|---|
| Decrepit Skeleton, Grey Wolf | 1 | 24 to 25 | 3 | 4 | 16 | HP 1.5x; damage in line |
| Plague Rat | 2 | 38 | 5 | 6 | | |
| Rotting Skeleton, Gnoll Raider | 3 | 55 to 58 | 7 | 8 | | |
| Wild Boar, Cave Bat | 4 | 60 to 78 | 8 to 9 | 10 | 39 (Fippy, 4 to 6) | HP 1.5 to 2x |
| Bandit Scout, Dire Wolf | 5 | 88 to 92 | 10 | 12 | 39 | HP 2.3x |
| Plagued Zombie | 6 | 116 | 12 | 14 | 39 | HP 3x |
| Giant Spider | 7 | 140 | 15 | 16 | | |
| Skeleton Champion | 9 | 188 | 20 | 20 | | |
| Gnoll Brute | 10 | 215 | 22 | 22 | | |
| Barrow Zombie | 12 | 265 | 26 | 26 | | |
| Bone Colossus | 14 | 365 | 35 | 30 | | |
| Ancient Wraith | 16 | 328 | 40 | 34 | | |

**Verdict:** mob damage is EQ's rule almost to the point (the 2026-09 content pass evidently
used it). Mob hit points sit 1.5 to 3x above P99's at levels 1 to 6; whether that holds past 10
needs the wiki's mid-level mob pages, which this pass could not fetch (a second pass through
the forum or Allakhazam). Not the problem: with EQ's player pools and spells, these mobs would
take EQ's time to kill, slightly longer.

## 7. Weapons, regen, XP

**Weapons.** Our nine weapons run 3 to 7 (Copper Dagger) up to 14 to 26 (Cursed Femur) at
delays of 2.5 to 3.2 s. P99's low-end: Rusty Short Sword 4 damage, 28 delay (2.8 s); Short
Sword 4/24; Fine Steel Short Sword 4/23; the level-1 max hit is about twice the weapon's
damage, so 8. Our Copper Short Sword (4 to 9, plus STR/5) lands in the same band. In line.
The forum's rule of thumb holds until 28, where bonus damage begins. Our swing adds STR/5 and a
skill multiplier to 1.15; EQ added STR through ATK and the skill through the hit chance. Same
order.

**Regeneration.** Already P99's: our table is the P99 HP regen table by level bracket (1
standing, 2 sitting to 19; 1 and 3 to 49), Trolls doubled; mana 1 a tick standing, 2 plus
meditate/12 sitting (`regen_model.md`). Not inflated.

**XP.** EQ's cubic curve with hell levels and the per-kill award from the mob's level, since
2026-06-26. Not inflated.

**Food.** Summon Food conjures up to 10 a cast from level 10 (user, 2026-10-19); EQ's conjured
one until the stacking versions in the 20s and 30s. A deliberate deviation, recorded.

## 8. Recommendations, worst first (the user's calls)

1. **Player pools: EQ's formula.** Base HP `5 + level x factor / 10 + STA x level x factor /
   3000` and base mana `22.5 x level` for a 100-stat caster, with our stats and EQ's class
   factors (§3). The one change that fixes the feel of level 1 to 10 on its own: a level 1
   Warrior at 32 HP dies to twelve hits, as on P99, and level 50 lands where ours already
   does for melee and priests while the casters gain the hit points they lack (a Wizard 755
   instead of 240). Everything else in this list is calibrated against it. Server
   `char_data::compute` and the client's `apply_character`, kept in lockstep as the level
   gains are.
2. **Level 1 to 10 spells reshaped to EQ's lines**, per the class tables: the level-1 nukes to
   EQ's 4 to 7, the level-1 heals to 10, the rank IIs to their level's EQ figure, with the
   level 12+ spells left where they are (they already match). About forty data rows on both
   sides. The alternative, a single factor (divide every spell under level 12 by five), is
   cruder and leaves the rank steps wrong.
3. **Regeneration buffs to EQ's**: Regrowth, Healing Wave's HoT, Breeze, Clarity and Lich
   Form to their P99 per-tick figures and, where ours arrive 12 to 33 levels early, to
   EQ's levels or a lower-rank version at ours (Breeze at 16, Clarity at 29, Regeneration at
   24 to 34, Lich at 49). The 12x here is the Mana Weave pattern again.
4. **Haste** 50% to EQ's 30% at 16 (Alacrity's 40% would be a level-24 rank).
5. **Mob hit points** at levels 1 to 6 down toward P99's (16 at 1, about 40 at 5): a smaller
   change than it looks once the player pools move, and it can wait for the mid-level data.
6. **Leave alone:** mob damage, weapons, regen, XP, the stat buffs, damage shields, absorbs,
   roots, mez, snare, speed; the user's own calls (Slow and Torpor under EQ, Aria 8%, conjured
   food x10, the 25/50/75 resurrection tiers, the spell formula "for now").
7. **A second pass, if wanted:** mana costs and cast times from PQDI's per-spell pages (not in
   its lists); mid-level mob hit points from the forum or Allakhazam.

**Knobs this creates:** none new; the changes are data on both sides. The pools formula's class
factor table becomes a constant table in `char_data.rs` mirrored in `character_data.gd`.

## 9. Decisions and the build (2026-10-20)

**The user's calls, the same day: "yes to all"** on the five recommendations, then three on
the spell formula when the build plan was laid out: **"If the INT and WIS bonus is not P99
accurate, then we can discard it"** (it goes); **"casting-skill multiplier should follow p99
rules"** (on P99 the casting skills never scaled an effect; a low skill made the spell
fizzle, so the multipliers go and a fizzle comes in); **"INT-base spell crit should be added
even though its not classic"** (the crit stays).

**Built on `feat/server-speed` in both repos, riding the Oct 22 bump** (server `0b60460`,
client `92c1442`; `eq_parity_checklist.md`, 36 rows; 310 unit and 129 integration tests green,
the client's pool probe and the spell lockstep check at zero drift; session note 2026-10-20 §7
has what the build taught):

1. **Pools:** EQ's formulas replace `BASE_HP + class bonus + CON x 5 + per-level gains`
   (`char_data::base_hp` / `base_mana` / `hp_level_factor`, mirrored in
   `CharacterData.base_hp` / `base_mana`): `5 + level x factor / 10 + CON x level x factor /
   3000` with EQEmu's class factors (our classes on the EQ class each is shaped after:
   Sorcerer and Blood Mage the casters', Beast Master the Beastlord's, Witch Hunter the
   Ranger's) and EQ's classic mana (`22.5 x level` at a stat of 100), both in EQEmu's integer
   arithmetic so the two sides agree to the point. Our CON, INT and WIS stand in for EQ's
   STA, INT and WIS: they start near 20 and 30 where EQ's started near 75, so the stat term
   is small at level 1 and the level term carries the curve. A Human Warrior is 28 at 1 and
   1,886 at 50 (EQ: 32 and 1,692); a Wizard 17 HP and 17 mana at 1. The pure melee keep a
   token 20 mana so no bar divides by zero. The per-level HP and mana gains are gone from
   both gain tables (stat and stamina gains stay); a level change recomputes the pools from
   the formula, up and down. Existing characters recompute at login with current HP and
   mana clamped (the clamp was already there).
2. **Spells:** the level 1 to 10 rows (about forty-five on both sides, listed in the
   checklist's table and the session note), each to EQ's counterpart at its level, EQ's
   line interpolated where EQ had no spell there (Greater Heal 50 at 8; Fireball 12 at 1
   between Burst of Flame and Burn). The 12+ spells kept their numbers. **Their mana costs
   went with them**, which §8 had left to a second pass: with EQ's pools a level 1 caster
   holds about 16 mana and our level 1 spells cost 15 to 35, so the first test run showed
   nobody at level 1 could cast at all. Each changed spell took its EQ counterpart's cost
   from the PQDI spell pages (Strike 12, Minor Healing 10, Burst of Flame 7, Shock of Frost
   8, Frost Bolt 10, Shock of Fire 15, Burn 15, Shock of Ice 30, Fire Bolt and Flame Bolt
   40, Lifetap 9, Lifespike 18, Furor 20, Light Healing 25, Chaotic Feedback 45), about one
   mana per point of effect at these levels, the same line where EQ had no counterpart.
   Two level 1 utilities a 16-mana caster could not have cast at all, Rune and Bind
   Affinity, went to 10. Cast times are still ours (most level 1 nukes are instant; EQ's
   took 1.1 to 1.8 s), the second pass that remains.
3. **Regen buffs:** Breeze to level 16 at 2 a tick, Clarity to 29 at 4, Regrowth to 34 at 5
   (Rk. II to 44 at 10, EQ's Chloroplast), Lich Form kept at 20 at 4 a tick (EQ's Allure of
   Death, the level 20 rank), Healing Wave's HoT dropped (its direct heal to 20). **EQ's
   durations and costs came with the rates** (the PQDI pages): a 2-a-tick Breeze over our
   old 30 s would have returned 10 mana for its 20, a net loss; EQ's lasts 27 minutes for
   35 mana (540 back), Clarity 27 minutes for 75, Regeneration up to 20.5 minutes for 100,
   Chloroplast 200, Quickness up to 11 minutes for 80. Breeze and Clarity run 1620 s,
   Regrowth and Rk. II 1230 s, Haste 660 s, at those costs (ours are flat where EQ's grew
   with level, so the top of each range). Lich Form stays a free toggle: EQ's lich line
   drained hit points for the mana (Allure of Death 8 HP a tick for 4 mana), which ours does
   not model, flagged below.
4. **Haste** 30%.
5. **Mobs:** levels 1 to 9 on a ramp toward P99's (level 1 25 to 16, level 6 116 to 80, level
   9 188 to 160), 10 and up unchanged; the pet stat curve moved with the camp ladder.
6. **The formula:** `spell_power::empower` and the client's INT, WIS and casting-skill terms
   deleted; a spell does its listed number; the INT crit stays.
7. **Fizzles:** EQEmu's `Client::CheckFizzle` as `cast_gate::fizzle_chance` (par `5 x spell
   level - 10`, at most 235, plus the level, against skill plus level; a hundred points of
   the casting stat move it one percent, a Bard's CHA against 110; base ten percent, 1 to
   95), rolled by the server at a timed cast's CastStart and an instant cast's CastSpell,
   after the target checks and before the mana. A fizzle refuses the cast with EQ's "Your
   spell fizzles!", burns a quarter of the mana (EQEmu's rule; classic charged for a fizzle
   too, "reduced and capped" in June 1999 per P99's patch notes), starts the gem's refresh
   (the global cooldown; P99's spell pages list a 2.25 s "fizzle time") and trains nothing.
   Songs never fizzle: EQ rolled them on the singing skill, which does not exist yet.

**Flagged, not built:** cast times (the second pass; the mana half is done above); mid-level
mob HP; the alignment multiplier on the client (the alignment build); a fizzle's "%1's spell
fizzles!" to bystanders; per-spell `base_difficulty` (EQ's extra fizzle weight on hard
spells; ours is 0); Lich Form's hit point drain (EQ's lich line paid HP for the mana; ours
regenerates for free, so at 4 a tick it is a permanent Breeze for a level 20 Necromancer).

## 10. Sources

- PQDI class spell lists, read 2026-10-20: Cleric `pqdi.cc/list-spells/2`, Paladin 3, Ranger
  4, Shadow Knight 5, Druid 6, Bard 8, Shaman 10, Necromancer 11, Wizard 12, Magician 13,
  Enchanter 14, Beastlord 15. The level-scaled effect figures in §4 are theirs.
- Project 1999 wiki (via search summaries): A Decaying Skeleton, A gnoll pup, Fippy Darkpaw,
  Tranixx Darkpaw; Rusty Weapons, Rusty Short Sword, Fine Steel Short Sword, Tarnished Weapons,
  Weapons; Game Mechanics (the 2 x level + 2 mob damage rule, the level-1 melee max hit).
- Project 1999 forums: "Game Mechanics: Melee Damage (Long)", "Melee Damage Information",
  "Damage cap after level 20", "Game Mechanics: Bard Songs" (the song research of the same day).
- EQEmu server source (GitHub, master): `zone/client_mods.cpp` (`CalcBaseHP`, `CalcBaseMana`,
  `GetClassLevelFactor`), `zone/special_attacks.cpp` (Backstab, Kick, Bash, Flying Kick,
  Tiger Claw formulas), `common/skills.cpp` and `common/ruletypes.h` (the skill base damage
  defaults: Kick 3, Bash 2, Round Kick 5, Flying Kick 25, Tiger Claw 4, Eagle Strike 7, Dragon
  Punch 12, Frenzy 10).
- Gates of Time EQEmu wiki, NPC-Scaling (the level 50 trash row: 10,000 HP, 74 to 204).
- Ours: `spells.toml` (142) and the 16 client-only spells, `active_skills.toml` (32),
  `zone_camps.toml`, `items.toml`, `char_data.rs`, `regen.rs`, all read the same day.
