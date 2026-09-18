# Pet Levels: Research and Options

**2026-09-17.** Commissioned from the phone ("research needs to be done with how
EQ and other MMOs have handled pet levels"), plus the standing note from the same
conversation: **"this game needs more influence from SWG."**
Status: RESEARCH DONE, awaiting an option pick in section 4.

## 1. Where Project Dawn stands

- The **warder** is a static level 5 template (`pet_templates.rs`), auto-resummons
  ~15 s after death. The complaint that opened this item: a level 22 Beast Master
  fighting beside a level 5 wolf.
- **Summon Skeleton** (Necromancer, min_level 6) is the only server-side pet
  summon spell; it produces a static level 6 skeleton forever.
- No magician pets exist server-side yet (they sit in the ~32 client-only spell
  backlog).

## 2. How the references did it

**EverQuest (classic / P99).** Pets belong to SPELLS, not the owner's level bar:
each new pet spell every few levels summons a categorically stronger pet, and on
each cast the pet's level is ROLLED within that spell's small range, so players
re-summon until they get the "max pet" (reagents are cheap by design; the ritual
is famous). Progression across tiers is steep: the level 1 spell gives a level 1
pet with 30 hp; the level 20 spell a level 19 pet with 600 hp; the level 53 spell
a level 43 pet with 1400 hp. Necromancer pets sat a few levels under the spell's
level; magicians had the same structure across four elemental variants per tier.
Beastlord warders (Luclin era) progressed the same way, through a warder spell
line, with the sources thin on whether warders shared the variance roll.

**EverQuest Legends (2026 emulator-era rework, for contrast).** Dropped the roll:
pet level is fixed 1:1 with the spell, spell rank upgrades add +1 pet level,
capped at owner minus 1. A modern simplification of the same spell-owned shape.

**WoW (classic shape).** The opposite philosophy: pets belong to the OWNER's
level. A warlock demon summons at the warlock's level, always. A hunter pet is
tamed at its wild level, then earns its own XP and catches up, capped at the
hunter's level. No variance, no ritual; the pet is a stat block that follows you.

**Star Wars Galaxies (the requested influence).** The most alive version: a
Creature Handler TAMES wild babies (only if the baby's level fits under the CH's
skill-derived cap), and the pet then earns its own training XP through kills,
maturing level by level. The handler's skill tree caps pet level and how many
pets they field; some babies are born with innate abilities the handler can learn
and teach to other pets; Bio-Engineers CRAFT pets (the sure path to capped and
mutated ones). Pets are individuals with a history, not summons.

## 3. What each shape would mean here

| Shape | Feel | Cost |
|---|---|---|
| EQ spell line + roll | classic ritual, pets gated by content | authoring a pet spell line per class (content), band roll (small code) |
| Owner-tracking | complaint gone instantly, low ceremony | small server change at summon time |
| SWG taming + maturity | pets as companions with history; strongest identity fit for the Beast Master | a real epic: pet XP + persistence, taming interaction, maturity tables, cap rules |

## 4. Options (pick one, or a staged pair)

**Option A, the friends-build fix (recommended now).** Derive pet level at
summon time instead of the static template:
- Warder: level = owner level minus 1, stats interpolated from the same
  per-level curve the camps use.
- Summon Skeleton: level = min(owner minus 1, spell tier cap of ~10) so the
  single authored spell stops being a level 6 forever but does not scale to 60;
  higher tiers arrive with the spell line later.
- Optional EQ seasoning: a small roll (minus 2 to 0) on every summon, so the
  re-summon ritual exists from day one. Cheap either way.
Server-only, no protocol change; rides any post-phase-4 server batch.

**Option B, the EQ spell line (content pass, later).** Author necro/mage pet
spell tiers (and warder tiers) with per-spell level bands and the variance roll.
Pairs with the client-only spell backlog work; this is where magician pets
arrive.

**Option C, the SWG direction (its own epic, flagged for after the friends
build).** Beast Masters tame wild babies from the phase 4 camps (a baby Grey
Wolf, a baby boar), and the warder keeps ITS OWN XP and maturity, capped by
owner level. Distinct class identity, pairs beautifully with the SWG-inspired
crafting philosophy (a future Bio-Engineer-shaped tradeskill could craft pets).
Necro/mage stay spell-summoned, which keeps the lore split clean: summoners
conjure, Beast Masters RAISE.

Recommendation: **A now**, B with the spell-backlog pass, C recorded as the
Beast Master's long-term identity per the SWG note.

## Sources

- [Project 1999 Pet Guide](https://wiki.project1999.com/Pet_Guide) (level
  variance + max-pet ritual)
- [EQProgression, Necromancer Pet Stats](https://www.eqprogression.com/necromancer-pet-stats/)
  (per-tier pet levels and hp)
- [EQLBase Pet Guide](https://eqlbase.com/pets/) and
  [EQL Tools, Pets](https://eqltools.com/learn/pets) (the modern 1:1 rework)
- [Paul Lynch's beastlord warder guides](https://www.paullynch.org/Everquest/VSBL/16spells30.html)
- [Wowhead, WoW Classic Warlock Demon Pets](https://www.wowhead.com/classic/guide/wow-classic-warlock-demon-pets)
- [SWG Wiki, Creature Handler](https://swg.fandom.com/wiki/Creature_Handler) and
  [Tame ability](https://swg.fandom.com/wiki/Tame_(Ability))
