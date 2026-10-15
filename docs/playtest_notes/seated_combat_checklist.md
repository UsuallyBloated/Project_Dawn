# Seated Combat Playtest Checklist — 2026-10-14

The classic EQ seated-combat rule (user call 2026-10-14, both halves as Project 1999 and
EQEmu keep them): **a hit on a sitting player cannot miss and lands for the most the attacker
can do, with no armor taken off; and any damage stands you up.** Sitting near a mob is now
dangerous, as in EQ. **Server half (both rules) needs the redeploy (server `d4f6b47` or
later); the client half (your own body standing when hit) needs the next export.** On the
old client the server still stands you (regen stops, `/camp` cancels), but your body keeps
drawing seated until you move or press the sit key; that is expected until the export.

| Rule | Standing | Sitting |
|---|---|---|
| A mob's swing | armor takes `armor / (armor + 100)` off | the mob's full swing, no armor |
| A player's swing (PvP) | a roll across the weapon's band, armor off | the top of the band, no armor |
| Taking any damage | nothing | you stand (regen bonus, `/camp` and the seated rule all end) |

Diagnostics: `server.log` has no line per hit (hits are frequent). Compare numbers in the chat
log: a mob's hits on a standing armored character vary only by armor (its swing is flat), so a
seated hit reads as the larger, unmitigated number every time. `/camp` is the server-side probe
for "does the server think I sit": it is refused outright when the server has stood you.

## Setup
- [ ] Server redeployed at `d4f6b47` or later (`build=` on the boot line)
- [ ] For §3, the next export (built from this checklist's commit or later)
- [ ] A character wearing some armor (any piece with AC), near a low mob it can survive

## 1 — A seated target takes the max
- [ ] **Stand and let a low mob hit you three or four times** → the hit numbers in chat are the mob's swing less your armor; note the number. notes:
- [ ] **Sit as it keeps swinging** → the first hit while seated is larger than the standing hits (the full swing, no armor), and you stand up from it. notes:
- [ ] **Sit again between its swings, several times** → every hit that lands while you sit is that same larger number; every hit that lands while you stand is the smaller one. notes:
- [ ] **Take off all armor, repeat** → the seated and standing numbers are the same (nothing to mitigate). notes:

## 2 — Any damage stands you (server side)
- [ ] **Sit, then `/camp`, then let a mob hit you** → the camp cancels ("cancelled" line) and the seated regen rate stops (the HP/MP bars tick at the standing rate). notes:
- [ ] **Sit, get hit once, then type `/camp` without pressing sit** → `/camp` is refused (no countdown): the server stood you on the hit. Press sit, `/camp` again → the countdown starts. notes:
- [ ] **Second seat: both `/pvp on`, B sits, A swings bare fists** → B's first seated hit is exactly A's fist max (4 plus A's STR/5), and B stands. notes:
- [ ] **Second seat: B sits, A casts a direct-damage spell on B** → B stands from the spell hit (any damage, not only melee). notes:
- [ ] **A Dark Decay or Entangle on a seated flagged player** → the first tick stands them. notes:

## 3 — Your body stands (needs the export)
- [ ] **Sit, get hit by a mob** → your character stands on the hit without a key press, and the HUD's seated state (regen display) follows. notes:
- [ ] **Sit with the spellbook open, get hit** → you stand and the book closes, as in EQ. notes:
- [ ] **Sit, get hit for 0 (an absorb rune eating the whole hit)** → you stay seated (no damage was taken). notes:

## 4 — Regression: nearby behavior unchanged
- [ ] **Standing melee, PvP and mob** → hit numbers vary across the band and armor still mitigates, as before. notes:
- [ ] **Sit out of combat for a minute** → the seated regen bonus still runs; nothing stands you. notes:
- [ ] **Sit, cast a spell** → casting still stands you (the older rule), the cast lands. notes:
- [ ] **Sit, swing at a mob** → swinging still stands you. notes:

## Notes / observations
-
