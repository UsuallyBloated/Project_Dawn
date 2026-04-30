# Lycanthrope
*Earned Permanent — Neutral — The Beast That Answers*

## Overview
The Lycanthrope transformation is the only major earned transformation available to Neutral alignment, which means it is the one most likely to be reached mid-career without the character having made a deliberate commitment to either moral extreme. It arrives because the character has spent enough time in a particular alignment with a particular class relationship to nature or the body that something deep in the world takes notice.

At night, they shift. During the day, they carry the awareness of it — the heightened senses, the slightly different relationship to violence, the knowledge of what they become. It is not a curse in the traditional sense. It is a bond with a form the character did not initially choose but cannot easily undo.

The shift is not total loss of control. Lycanthropes in beast form retain their combat skills and class abilities but gain physical enhancements. The beast is not a separate entity — it is them, pushed to a physical extreme.

## Requirements
- **Alignment:** Neutral (-299 to 299)
- **Classes:** Ranger, Druid, Shaman, Monk
- **Level:** 15
- **Trigger:** Threshold condition TBD — candidates include: bite from a specific enemy type, completion of a specific quest in a specific zone, or accumulation of kills in wilderness areas at night

## Effects

**Beast Form (Night Only):**
- Active during night cycle; triggered by TimeOfDay autoload
- STR and AGI significantly increased in beast form
- Natural claw attacks available (replaces weapon attacks temporarily)
- Speed increased
- Cannot use most spell slots in beast form (exception: Druid and Ranger retain nature spells)
- Senses: tracking bonus, bonus to detecting hidden/invisible enemies

**Humanoid Form (All times):**
- Carry-over passive bonuses: minor STR/AGI increase even in humanoid form
- Low-light vision improves
- Bonus to wilderness navigation and tracking
- Passive detection resistance in natural terrain

**Complications:**
- Silver-based weapons deal bonus damage
- Full moon nights (if implemented): beast form cannot be suppressed; the character is in beast form for the entire night
- Some NPCs detect the lycanthropy and react with fear or hostility even in humanoid form

**Visual (Beast Form):**
- Specific beast type reflects race and class combination — a Felhari Lycanthrope becomes a larger, wilder feline; a Dwarf Lycanthrope becomes a bear-form; a Human Ranger becomes a wolf-form
- The transition animation plays at dusk and dawn

## Ability Reference

| Ability | Type | Effect | Mana | Cast |
|---|---|---|---|---|
| Beast Form | Toggle (night only) | Transform: +30 STR, +30 AGI, +20% movement; natural claw attacks (20 base dmg each); most spells unavailable; lasts until dawn | 0 | Instant |
| Claw Strike | Beast Form attack | Two rapid claw attacks each swing; bleed chance 20% (8 dmg/s for 12s) | 0 | Active (beast) |
| Predator Sense | Passive (all times) | Low-light vision; +15 tracking; +20 detection of hidden/invisible creatures; wilderness navigation bonus | — | — |
| Wild Strength | Passive carry-over | Outside beast form: +10 STR, +10 AGI retained; does not stack with beast form | — | — |
| Silver Weakness | Passive vulnerability | Silver-based weapons deal +30% damage; full moon forces beast form for entire night cycle | — | — |
