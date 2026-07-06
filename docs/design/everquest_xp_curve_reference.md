# EverQuest XP / Leveling Reference (Classic / Kunark / Velious)

**Purpose:** canonical reference for how leveling and experience scaling worked in
EverQuest's Classic (1999), Kunark (2000), and Velious (2000-2001) eras, gathered to
inform Project Dawn's own XP curve work (see the "Implications for Project Dawn" section
at the end and `docs/playtest_notes/xp_curve_flatten_checklist.md`).

**Compiled:** 2026-06-26, via a multi-source web research pass (Project 1999 wiki, EQEmu
source, TAKP wiki, the EQEmulator-forum "Treatise"). Every claim below was put through
3-vote adversarial verification; refuted claims are listed separately at the bottom so a
reader does not build on them.

**Provenance / how trustworthy is this:** Almost all of the concrete math is **community
reverse-engineering**, NOT an official Verant/Sony disclosure. The constants were pulled
from the live client by the ShowEQ packet-sniffing community and codified in the EQEmu
emulator source and the P99/TAKP wikis. The sources say so themselves: TAKP states
"no-one knows the specifics of how it is calculated," and the Treatise author notes the
term names are "player invented and what Sony called them is unknown." The single
genuinely *official* data point is the January 2001 Producer's Letter announcing the
removal of class/race XP penalties. Treat the formula constants as the best available
reconstruction, not verbatim Verant internals. EQEmu/P99 implement formulas that
approximate but are not provably byte-identical to 1999-2001 live code.

---

## TL;DR

- **XP-to-level curve is CUBIC:** `Total XP to complete level L = L^3 x ClassMod x RaceMod x HellMod`.
  For a neutral class/race this normalizes to `L^3 x 1000 x multiplier`. Reaching level 60
  costs ~669,600,000 total XP.
- **Per-kill XP is a SEPARATE QUADRATIC formula:** `kill XP = mob_level^2 x ZEM`, then
  scaled by con color, group split, and class/race modifiers.
- **Level caps:** Classic launch 50, Kunark raised to 60, Velious stayed 60.
- **Hell levels (30, 35, 40, 45, 51, 54, 59)** come from jumps in the HellMod between
  consecutive levels at bracket boundaries, not from the mod being high in absolute terms.
- **Class penalties (pre-Jan 2001):** hybrids (Paladin/Shadowknight/Ranger/Bard) -40%,
  Monk -20%, pure casters -10%, Warrior +10%, Rogue +9%. **Race penalties:** Troll/Iksar
  -20%, Ogre -15%, Barbarian -5%, Halfling +5% bonus (the only race with a bonus). All
  multiplicative. Class/race penalties were officially removed in the Jan 2001 patch.
- The cubic structure held from Classic through Planes of Power; what changed across eras
  was the level cap and the high-level HellMod values, not the formula shape.

---

## 1. The XP-to-level curve (cubic)

```
Total XP to complete a level L = L^3 x ClassMod x RaceMod x HellMod
```

For a neutral class and race, `ClassMod x RaceMod = 10 x 100 = 1000`, so P99 normalizes
the published table as:

```
Total XP at end of level L = L^3 x 1000 x multiplier
```

where the "multiplier" column is the HellMod (see section 3). Sample exact values from the
P99 Experience table:

| Level | XP to complete that level | Note |
|---|---|---|
| 10 (end) | total 1,000,000 | 10^3 x 1000 x 1.0 |
| 29 | 2,437,000 | last "normal" level |
| 30 | 5,311,000 | hell level (2.18x the prior jump) |
| 39 to 40 | 5,336,400 | |
| 40 to 41 | 12,017,200 | over 2x the prior level |
| 50 | 10,291,400 | |
| 51 | 23,976,500 | hell level (2.33x) |
| 60 (end) | total 669,600,000 | 60^3 x 1000 x 3.1 |

Confidence: HIGH (3-0 verification). The cubic `L^3 x C x R x H` form is stated verbatim
on the P99 wiki and matches the Treatise. The table is internally exact (e.g.
`60^3 x 1000 x 3.1 = 669,600,000`).

---

## 2. Level caps per era

- **Classic launch (1999): cap 50**
- **Kunark (2000): raised to 60**
- **Velious (2000-2001): stayed 60**

Caveat: this clean cap history survived verification only **indirectly** (it is supported
by the Kunark "10 new levels" / HellMod-extension reasoning rather than a dedicated
cap-history source that passed adversarial voting). It matches well-known EQ history but is
slightly softer-sourced than the formula itself.

---

## 3. Hell levels and the HellMod table

A "hell level" is NOT caused by the HellMod being high in absolute terms. It is caused by
the **difference** in HellMod between consecutive levels at a bracket boundary.

| Levels | HellMod |
|---|---|
| 1-29 | 1.0 |
| 30-34 | 1.1 |
| 35-39 | 1.2 |
| 40-44 | 1.3 |
| 45-50 | 1.4 |
| 51 | 1.5 |
| 54 | 1.9 |
| 58 | 2.7 |
| 59 | 3.0 |
| 60 | 3.1 |

P99: hell levels "are determined entirely by the difference in the Level/Hell Mod from the
current level and the previous level... the important factor here is not that the level
mods themselves are high, but that the difference between each mod is high." A 0.1 jump is
a hell level, 0.2 a "double hell," 0.3 a "triple hell." Level 59 is a triple hell (2.7 to
3.0).

Era split: the **classic** hell levels were **30, 35, 40, 45**. The steep **51-60** spikes
are **Kunark-era**: because Kunark added only 10 levels (50 to 60), Sony "had to crank up
the hell_mod every level" to fit them onto the curve.

Confidence: HIGH (3-0).

---

## 4. Per-kill XP (quadratic, separate from the curve)

Do not confuse this with the level curve. XP *awarded* for a kill:

```
kill XP = mob_level^2 x ZEM   (then scaled by con color, group split, class/HBM/MLM mods)
```

- **ZEM (Zone Experience Modifier)** is a per-zone multiplicative scalar. On P99's
  normalized scale, **75 = normal** (most outdoor zones), below 75 is a penalty, above 75 a
  bonus, applied multiplicatively (150 = +100%). Dungeons are typically ~80, some newbie
  zones ~100. Two same-level mobs in different zones give different XP by design, set "in
  correlation with the risk in a particular zone."
- EQEmu's base macro is literally `#define EXP_FORMULA (level * level * 75 * 35 / 10)` =
  `mob_level^2 * 262.5`, using the SLAIN mob's level in `GetExperienceForKill()`.
- Con-color (level-difference) scaling and group-size splits exist and modify this, but
  the exact percentages did NOT survive verification (see "Open / unconfirmed").

Confidence: HIGH for the `mob_level^2 x ZEM` core and ZEM multiplicativity (3-0). The con
and group-split details are open.

---

## 5. Class and race experience penalties (pre-Jan 2001)

Both are **multiplicative modifiers on XP-required-to-level**. Shown as the EQEmu
"modifier" value (class baseline 10, race baseline 100 = neutral) and as the equivalent
penalty/bonus.

**Class** (baseline 10):

| Class | Modifier | Effect |
|---|---|---|
| Warrior | 9 | ~10% less XP needed (bonus) |
| Rogue | 9.05 | ~9% less (bonus) |
| Cleric / Druid / Shaman | 10 | neutral |
| Wizard / Enchanter / Magician / Necromancer | 11 | -10% |
| Monk | 12 | -20% |
| Ranger / Paladin / Shadowknight / Bard | 14 | -40% (the hybrids) |

**Race** (baseline 100):

| Race | Modifier | Effect |
|---|---|---|
| Halfling | 95 | +5% bonus (only race with an XP bonus) |
| Barbarian | 105 | -5% |
| Ogre | 115 | -15% |
| Troll, Iksar | 120 | -20% |
| all others | 100 | neutral |

They **stack multiplicatively**: a Troll Shadowknight = 1.4 (class) x 1.2 (race) = 1.68, a
68% penalty. The class/race penalties were officially removed in the **Jan 2001 patch**
(this removal is the one officially-disclosed fact, via the Producer's Letter). The small
Warrior/Rogue/Halfling bonuses lingered far longer (removed 2019 on live EQ).

Confidence: HIGH (3-0).

### Racial trade-offs — what the XP penalty "bought"

*(Added 2026-07-06; sources: P99 "Choosing a Race" + "Troll" pages.)*

The race XP penalties were not free losses — each penalized race got a **racial advantage**
in exchange, and the penalty size roughly tracked how strong that advantage was:

| Race | XP mod | Racial advantage (the trade-off) |
|---|---|---|
| **Troll, Iksar** | -20% | **faster HP regeneration** (the marquee soloist/tank perk) |
| Ogre | -15% | **frontal stun immunity** (cannot be stunned from the front — big for a tank) |
| Barbarian | -5% | **Slam** (a bash-like knockback melee proc) |
| Halfling | +5% *bonus* | small size + the only race with an XP *bonus*, not a penalty |

**The Troll / Iksar regeneration** is the trade-off people remember, and **only those two
races** have it: a **passive, always-on** HP-regen bonus on the standard ~6-second regen
tick that **scales with level** — roughly **2 HP/tick sitting (1 standing) at low levels,
rising to ~18 HP/tick sitting at level 60**. Both P99 sources are explicit that the -20% XP
is the deliberate *price* for it ("Iksar and Trolls share [the -20%] because of their
regeneration"). It made them exceptional soloists with minimal between-fight downtime.

**Era note (matters for us):** the Jan 2001 patch removed the XP *penalties* but kept the
racial *abilities* — so post-2001 a Troll kept its faster regen at no XP cost. The balanced
"slower XP for a perk" trade only existed in the Classic/Kunark/Velious window this doc
targets; if Project Dawn wants the trade-off to *mean* something, it has to keep both halves
coupled (unlike late EQ, which broke the coupling).

Confidence: HIGH on the existence of the Troll/Iksar regen and the -20%-for-regen pairing
(both sources agree). MEDIUM on the exact per-tick numbers — P99 gives level-scaled figures
but does not cleanly separate the racial *delta* from base regen.

---

## 6. P99 / EQEmu fidelity notes

- P99 documents the classic formula faithfully (cubic curve, full HellMod table for 1-60,
  ZEM list, class/race penalties) and is the best public reference.
- Modern stock EQEmu reframes the model as **bonuses, not penalties**, by default: it
  applies +5% multiplicative bonuses to Halfling/Rogue/Warrior gated by
  `RuleB(Character, UseRaceClassExpBonuses)` (defaults **true**), while the classic penalty
  rules (`UseOldRaceExpPenalties`, `UseOldClassExpPenalties`) default **false**. Both
  frameworks live in the code and are toggled per server.
- Even P99 is not a perfect 1999-live mirror: it selectively disables class penalties
  (dated 9/21/15 on Blue) to match its chosen ruleset/timeline.

---

## 7. Quest experience and faction

*(Added 2026-07-06, second research pass; sources at the bottom.)*

A single quest turn-in pays out on **two decoupled tracks**: an XP reward that decays in
relative value as you level, and a faction reward that does NOT. This is why a low-level
quest (Crushbone Belts is the stock example) is an appealing XP route only near its
intended level, yet stays worth doing at high level purely for faction standing. Crushbone
is just one of hundreds of such quests; each carries its own XP value and its own
faction-hit vector.

### Quest XP (decays with level)

Two authoritative sources DISAGREE on the mechanism; both are given.

- **Code-grounded model (Treatise / EQEmu):** quest XP is *"merely a constant value per
  quest (but with a cap)"*, sent directly to the client, NOT derived from any mob level.
  The cap is a fraction of *your current level's* requirement: **classic / old EQ = 25% of
  a level**; later reduced to **14.284% (one-seventh)**.
- **Community "nobody knows" model (TAKP):** *"Quest XP is calculated differently from
  normal XP and no-one understands the specifics."* Hypothesizes each quest has an assigned
  level and rewards XP like killing a mob of that level, with a *"sweet spot"* where turning
  in outside the intended range *"will yield little to no XP at all."*

Both predict the observed decay, but the constant-value model explains it more cleanly: a
fixed XP chunk is a large slice of a small (low-level) bar and a negligible sliver of a
large (high-level) bar. The Crushbone anecdotes show a **smooth decay, not a hard
sweet-spot cliff**: ~5% per belt at L6, ~4% at L7, ~2-3% at L8, ~1-2% at L11.

**Classic-era takeaway:** the per-turn-in cap was **25% of a level in classic EQ** (the
modern 1/7 = 14.284% came later). One turn-in could never exceed a quarter-level.

**The cap % is CONTESTED** (flag it): reported variously as ~11% per turn-in (a P99
summary), a "13% per kill" figure that was adversarially *refuted* in this doc's kill-XP
research, 14.284% (1/7) modern, and 25% classic (Treatise). Solid: "there is a cap,
expressed as a fraction of your current level." Uncertain: the exact percentage, and
whether the value is a flat constant vs an assigned-level lookup.

Most quests are XP-negligible (community consensus: "your time is best spent killing
mobs"); a few are outliers (Hero's Bracers, Elder Gelok supplies, Strength of the Elements)
worthwhile far up the curve.

### Faction (level-independent)

Faction from a turn-in is a **fixed set of "hits" independent of character level**. One
turn-in raises some factions and lowers others (dual-impact). Crushbone belts to Canloe
Nusback (Kaladim Warrior's Guild, South Kaladim): **up** with Storm Guard, Kazon
Stormhammer, Miners Guild 249, Merchants of Kaladim; **down** with Craknek Warriors (the
Ogre warriors).

Nine standing tiers, best to worst (P99 point ranges in parentheses):

| Tier | Range |
|---|---|
| Ally | 1051 to 2000 |
| Warmly | 701 to 1050 |
| Kindly | 451 to 700 |
| Amiable | 51 to 450 |
| Indifferent | -49 to 50 |
| Apprehensive | -50 to -449 |
| Dubious | -450 to -699 |
| Threatening | -700 to -1049 |
| Scowls | -1050 to -2000 |

Tiers gate real things (vendors refuse to trade below Dubious, guards attack on sight,
NPCs won't talk to you). Caveat: P99 warns the specific per-hit magnitudes on its pages
"were taken from a non-classic source ... very often incorrect", so treat the exact +N/-N
numbers as illustrative, not authoritative.

Because the faction hit is the **same at level 8 or level 50** while the XP shrinks toward
nothing, high-level characters grind belts purely for standing (e.g. to clear KOS status,
open a city/vendor, or unlock a quest line). That is the asymmetry.

### Design note for Project Dawn

The elegant part worth borrowing: EQ never has to "expire" a low-level quest. Two
orthogonal reward channels on one turn-in:

- **XP reward** capped at a fraction of the *current* level's requirement (self-scaling;
  auto-decays in relative value; no per-quest re-tune needed as content ages).
- **Faction reward** = a fixed vector of `+/- standing` hits across named factions
  (level-independent; gates *access*, not power).

`data/quest_definitions.gd` already has an `xp_reward` field. Pairing it with a
`faction_deltas` map, and (for the classic self-scaling feel) treating `xp_reward` as
*capped by a fraction of the current level's band* rather than as a flat absolute,
reproduces this two-track behavior. Note the existing open to-do: quest kill-objectives
don't advance in launcher mode (`QuestManager.notify_kill` only fires for local Test-Room
enemies), so a faction/XP turn-in loop needs the server-driven kill-credit path first.

Confidence: that quest XP is a capped constant and faction is a level-independent
dual-impact vector = HIGH; the exact cap % and the constant-vs-assigned-level question =
uncertain / contested (see above).

---

## Refuted (do NOT use these)

These plausible-sounding formulations were adversarially rejected during verification:

- A **"13% hard cap on XP per kill"** (refuted 0-3, twice).
- A specific **group-split table** (1/2/4/6 members = 100/120/220/260% total; refuted 0-3).
- The **"L^3 x 1.5 x 1000"** constant form (refuted; the real normalization is
  `L^3 x 1000 x per-level-multiplier`, where the multiplier is the HellMod, not a flat 1.5).

## Open / unconfirmed

- The exact con-color (level-difference) multiplier curve for per-kill XP
  (green/light-blue/blue/white/yellow/red percentages). The one specific
  green/light-blue/blue 0%/25%/50% claim was refuted 1-2, so it stays open.
- The exact group-size XP split table by party size.
- Per-era ZEM tables for specific zones (the 75/80/100 figures are the classic-era P99
  baseline; ZEM values drifted upward in later expansions).
- Whether any XP-curve constant beyond HellMod/level cap differed between Kunark and
  Velious specifically (sources treat Classic-through-PoP as structurally identical).

---

## Sources

Primary (open-source code):
- EQEmu `zone/exp.cpp` — https://github.com/EQEmu/Server/blob/master/zone/exp.cpp
- EQEmu `common/features.h` (EXP_FORMULA macro) — https://github.com/EQEmu/EQEmu/blob/master/common/features.h
- EQEmu `common/ruletypes.h` (bonus/penalty rules) — https://github.com/EQEmu/Server/blob/master/common/ruletypes.h

Secondary (community wikis / writeups):
- P99 Experience — https://wiki.project1999.com/Experience
- P99 Experience table — https://wiki.project1999.com/Experience_table
- P99 Recommended Levels and ZEM List — https://wiki.project1999.com/Recommended_Levels_and_ZEM_List
- P99 Choosing a Race — https://wiki.project1999.com/Choosing_a_Race
- "A Treatise on EverQuest's Experience Calculations" (republished) — https://quarm.guide/2024/06/11/Treatise/
- EQEmulator forum thread — https://www.eqemulator.org/forums/showthread.php?t=44103
- TAKP Experience Points — https://wiki.takp.info/index.php/Experience_Points
- TAKP Current ZEMs — https://wiki.takp.info/Current_ZEMs

Quest XP and faction (section 7, added 2026-07-06):
- P99 Crushbone Belts — https://wiki.project1999.com/Crushbone_Belts
- P99 Faction — https://wiki.project1999.com/Faction
- Quarm Treatise (quest XP section) — https://quarm.guide/2024/06/11/Treatise/
- TAKP Experience Points (quest XP section) — https://wiki.takp.info/index.php?title=Experience_Points
- EQ Fandom: Crushbone Belts — https://everquest.fandom.com/wiki/Quest:_Crushbone_Belts

---

## Implications for Project Dawn

**STATUS (2026-06-26): this EQ model was ADOPTED.** A first pass flattened the broken x1.5
geometric curve to x1.25 geometric; this research then showed cubic is both more authentic
and *gentler* at the high end, so branch `fix/xp-leveling-overflow` now implements the EQ
model directly: per-level cost is the cubic `total(L) = L^3 x 1000 x hell_mod(L)` with the
full hell-level table (band(60) = 53,463,000, reproducing the P99 table exactly), and
per-kill reward is the quadratic `mob_level^2 x ZEM` (server `world::progression::kill_xp`,
ZEM 75 baseline). See `char_data.rs` (`hell_mod` / `total_xp` / `xp_to_next_for`), its
`autoloads/player_stats.gd` mirror, and `docs/playtest_notes/eq_leveling_checklist.md`. The
points below are the reasoning that drove the switch.

How EQ's design compared to the interim x1.25 geometric curve (the case for switching):

1. **EQ was cubic (L^3); Project Dawn's new curve is geometric (x1.25^L).** They diverge at
   the high end. Across levels 10 to 60, EQ's *per-level* cost grows about 197x; a x1.25
   band grows about 70,000x over the same span. Geometric is far steeper in *relative*
   terms than EQ's cubic. If "classic pacing" is the goal, an `L^3`-shaped curve is closer
   than any geometric ratio.

2. **The ceiling already matches.** Project Dawn's L60 band (~51.5M) is close to EQ's real
   level-60 cost (~53.5M to complete level 60). It is the *shape* between 1 and 60 that
   differs, not the top.

3. **Hell levels were deliberate texture, not a bug.** EQ intentionally spiked difficulty at
   30/35/40/45/51/54/59. A smooth geometric curve has none. That is a design choice; if the
   classic feel is wanted, it is a small per-level multiplier table.

4. **EQ decoupled per-kill award (quadratic) from per-level cost (cubic).** That kept
   kills-per-level growing roughly linearly with level (~L^3 / L^2 = L), plus the hell-level
   bumps. Project Dawn's mob/quest XP are currently authored constants tuned to the old
   curve; with a geometric curve and flat-ish kill XP, kills-per-level will balloon
   geometrically unless kill XP scales with mob level the way EQ's `mob_level^2` did. A
   mob/quest XP re-tune is already flagged as a separate balance pass in the checklist.
