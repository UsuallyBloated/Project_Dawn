# CastSpell Class/Level Gate Playtest Checklist — 2026-07-20

Server now rejects a `CastSpell` unless the caster's class is in the spell's `classes` AND the
caster's level meets `min_level` (audit finding: "any class can cast any spell it can name").
Checked before mana / cooldown / skill side effects. The point of this playtest is a **regression
sweep**: confirm the gate is invisible to legit play — every casting class can still cast its own
spells. The rejection path itself needs a forged client to exercise, so it's covered by the server
unit tests (`cast_gate_eligibility_matches_class_and_level`, `every_spell_is_class_and_level_tagged`)
+ the server log; a stock client can't attempt a forbidden cast.

**Build prereq: restart the server (release build). No client re-export needed** — this is a
server-only change; the client is unchanged.

| Spell | Class | min_level | Notes |
|---|---|---|---|
| Fireball | Magician | 1 | basic nuke |
| Healing Light | Cleric | 1 | ALLY heal |
| Meteor | Wizard | 18 | high min_level |
| Spirit of Wolf | Druid / Shaman | 12 | multi-class |
| Lay on Hands | Paladin | 6 | multi-word class |
| Spirit Mend | Beast Master | 1 | multi-word class |

Diagnostic: `server.log` grep `CastSpell rejected — class/level not eligible` (should appear ONLY
if a forbidden cast is attempted; must NOT appear for any cast below).

## Setup
- [ ] Restart server (release build)
- [ ] Log in a caster of a mana class; have MP available (regen is slow — sit/med or use Test Panel)

> **Known gotcha:** a cast can silently fail for unrelated reasons (not enough mana, on cooldown,
> silenced, moved during cast). If a legit cast "doesn't land", check `server.log` for the specific
> reject reason before blaming this gate — the gate logs `class/level not eligible` specifically.

## 1 — Regression: each casting class casts its own spells (must all succeed)
Cast at least one spell per class you can roll. None should be rejected; the log must show NO
`class/level not eligible` line for any of these.
- [ ] **Magician casts Fireball** → lands (damage applied). notes:
- [ ] **Cleric casts Healing Light on an ally** → heal lands. notes:
- [ ] **Wizard (level >= 18) casts Meteor** → lands. notes:
- [ ] **Druid or Shaman casts Spirit of Wolf** (multi-class spell) → buff lands. notes:
- [ ] **A multi-word class casts its own spell** (Paladin Lay on Hands / Beast Master Spirit Mend /
  Shadow Knight / Witch Hunter / Blood Mage) → lands, NOT rejected. notes:

## 2 — Level gate on a real spell (legit path)
- [ ] **A Wizard below level 18 has no Meteor scribed / can't slot it** → confirms the client keeps
  you off it before the server ever sees the cast (the gate is the backstop, not the front line).
  notes:
- [ ] **Level a Wizard to 18 and cast Meteor** → now lands. notes:

## 3 — Buff / heal / pet spells still route normally (regression)
- [ ] **Cast a self-buff, an ally-buff, a HoT, and a pet spell you own** → all apply as before (the
  gate sits ahead of the target-type branch; it must not disturb SELF / ALLY / PET / CORPSE). notes:
- [ ] **A Cleric/Paladin resurrection on a corpse still works** → res offer fires (the CORPSE arm's
  own class check is now redundant defense-in-depth, not a double-reject). notes:

## 4 — Rejection path (forged cast — expect [-] on a stock client)
- [ ] **Attempt to cast a spell your class can't** (needs a modified client / raw wire msg) → server
  drops it, fans "Your class cannot cast that.", no mana spent; `server.log` shows the reject.
  notes: (expected `[-]` — stock client can't send this; unit-test-covered)

## Notes / observations
-
