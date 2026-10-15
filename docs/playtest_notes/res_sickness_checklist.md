# Resurrection Sickness Playtest Checklist — 2026-10-14

The last open piece of the corpse plan: an accepted resurrection leaves **Resurrection
Sickness** for five minutes, classic EQ's Resurrection Effects. The five primaries (STR, AGI,
INT, WIS, CON) each lose one point per four levels (never less than one), and natural HP and
mana regen run at half speed while it lasts. "You are exhausted." on accept, "You feel your
strength return." when it wears off. **Server half needs the redeploy (server `53ad557`
or later); the sheet showing the reduced stats and the buff-bar entry need the next export.**
Two seats: a Cleric 20 or higher (Resurrection (Minor)) and someone to die.

| Level of the dead | Cut per stat | Example |
|---|---|---|
| 1 to 7 | 1 | STR 12 reads 11 |
| 8 to 11 | 2 | |
| 20 | 5 | STR 20 reads 15 |
| 60 | 15 | |

Diagnostics: `server.log` has `resurrection accepted` with the refund; the sickness itself has no
line. The buff bar and the character sheet are the client-side tells; the regen rate is the one
you can time (a near-empty HP bar fills at half the usual pace, sitting or standing).

## Setup
- [ ] Server redeployed at `53ad557` or later (`build=` on the boot line)
- [ ] For §2, the next export (built from this checklist's commit or later)
- [ ] Two seats: a Cleric 20+ on one, a character of level 8 or higher on the other (a cut of 2 or more is easier to read on the sheet)

## 1 — The sickness lands (server side, works on the old client)
- [ ] **Die, respawn, let the Cleric cast Resurrection (Minor) on the corpse, accept** → you are summoned to the corpse, the XP refund arrives, and chat says "You are exhausted.". notes:
- [ ] **Watch HP regen for a minute with a low bar** → it fills at about half the usual pace, sitting or standing. notes:
- [ ] **Same for mana** → half pace. notes:
- [ ] **Wait five minutes** → chat says "You feel your strength return." and regen is back to normal. notes:
- [ ] **Die and get resurrected again inside the five minutes** → the sickness restarts at five minutes (one entry, not two). notes:

## 2 — The sheet and the bar (needs the export)
- [ ] **Open the character sheet right after accepting** → STR, AGI, INT, WIS and CON each read lower by the cut for your level (table above); DEX and CHA unchanged. notes:
- [ ] **Buff bar** → "Resurrection Sickness" with a five-minute countdown. notes:
- [ ] **When it wears off** → the sheet's numbers come back exactly and the bar entry leaves. notes:
- [ ] **Relog while sick** → the sickness is gone: buffs and debuffs do not survive a relog (as in classic EQ, where camping cleared them). The dodge costs the camp or linkdead wait; flagged in the To-Do as a knob if it should persist. notes:

## 3 — Regression: nearby behavior unchanged
- [ ] **A resurrection declined** → no sickness, no line. notes:
- [ ] **Respawn at bind without a res** → no sickness. notes:
- [ ] **Another stat buff cast on you while sick** → both show; the cut and the buff add up on the sheet. notes:

## Notes / observations
-
