# Resurrection Sickness Playtest Checklist — 2026-10-15

The last open piece of the corpse plan, built to classic EQ's Resurrection Effects as Project
1999 keeps them (user call 2026-10-15: "Difficult is what we are looking for"). An accepted
resurrection **lands you at a quarter of your max HP with no mana**, beside whatever killed
you, and leaves **Resurrection Sickness** for five minutes: STR, AGI, INT, WIS and CON each lose
a level-scaled fraction of what race, class and level give (gear and buffs are not cut), from a
tenth at level 1 to a half at 60. "You are exhausted." on landing, "You feel your strength
return." when it wears off. **Server half needs the redeploy (server `528ae23` or later); the
sheet showing the cut and the buff-bar entry need the next export.** Two seats: a Cleric 20 or
higher (Resurrection (Minor)) and someone to die.

| Level of the dead | Fraction cut | Human Warrior's STR | reads |
|---|---|---|---|
| 1 | 10% | 22 | 20 |
| 20 | about 23% | 60 | 46 |
| 60 | 50% | 140 | 70 |

The cut is of the intrinsic value, so a Warrior's WIS of 12 loses 1 at level 1, 3 at 20, 6 at
60; nothing ever goes below zero.

Diagnostics: `server.log` has `resurrection accepted` with the refund; the sickness itself has no
line. The HP and mana bars dropping on landing, the buff bar and the character sheet are the
tells. The XP refund tiers are unchanged (25/50/75%, locked 2026-06-22).

## Setup
- [ ] Server redeployed at `528ae23` or later (`build=` on the boot line)
- [ ] For §2, the next export (built from this checklist's commit or later)
- [ ] Two seats: a Cleric 20+ on one, a character of level 8 or higher on the other (a bigger cut is easier to read on the sheet)

## 1 — The landing and the sickness (server side, works on the old client)
- [ ] **Die, respawn, let the Cleric cast Resurrection (Minor) on the corpse, accept** → you are summoned to the corpse, the XP refund arrives, chat says "You are exhausted.", and your HP bar drops to a quarter with your mana bar at zero. notes:
- [ ] **Accept while already hurt (below a quarter)** → HP stays where it was, not raised to a quarter; mana still zero. notes:
- [ ] **Wait five minutes** → chat says "You feel your strength return."; natural regen ran normally throughout (the sickness does not slow it). notes:
- [ ] **Die and get resurrected again inside the five minutes** → the sickness restarts at five minutes (one entry, not two); you land at a quarter HP again. notes:
- [ ] **Decline the res** → nothing: no summon, no strip, no sickness. notes:

## 2 — The sheet and the bar (needs the export)
- [ ] **Open the character sheet right after accepting** → STR, AGI, INT, WIS and CON each read lower by the fraction for your level (table above, applied to the unbuffed, ungeared value); DEX and CHA unchanged. notes:
- [ ] **Buff bar** → "Resurrection Sickness" with a five-minute countdown. notes:
- [ ] **With a stat buff or gear bonus on you** → the cut is the same number as without them (the cut is of the intrinsic stat, not the buffed one). notes:
- [ ] **When it wears off** → the sheet's numbers come back exactly and the bar entry leaves. notes:
- [ ] **Relog while sick** → the sickness is gone: buffs and debuffs do not survive a relog (as in classic EQ, where camping cleared them). The dodge costs the camp or linkdead wait; flagged in the To-Do as a knob if it should persist. notes:

## 3 — Regression: nearby behavior unchanged
- [ ] **Respawn at bind without a res** → full HP and mana as before, no sickness. notes:
- [ ] **A heal cast on you while sick** → lands normally (the sickness cuts stats, not healing). notes:
- [ ] **Another stat buff cast on you while sick** → both show; the cut and the buff add up on the sheet. notes:

## Notes / observations
-
