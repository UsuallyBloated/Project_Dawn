# Online Play Leaves the Offline Save Alone: Playtest Checklist (2026-10-23)

`SaveManager` wrote the online character to the offline Test Room's save file
(`character.save`) on every level-up, zone load, Quit Game and finished `/camp`; the Test
Room then loaded that online character as its own. Online it now writes nothing: the server
is the save. Housekeeping audit Phase 5, step 1 (`docs/security/housekeeping_audit_2026_10_23.md`).
Client only, rides the Oct 22 export from the merged branch; no server change.

The file lives at `%APPDATA%\Godot\app_userdata\Project_Dawn\character.save`. Note its
"Date modified" before you start. (On 2026-10-23 it held "Splenda", a level 10 Shadow
Knight, written at 16:25 that afternoon, not the Test Room's default Chortle.)

## Setup
- [ ] Running the Oct 22 export (login screen bottom right shows its build). notes:
- [ ] Note `character.save`'s Date modified (or that it does not exist). notes:

## 1 — Online play writes nothing
- [ ] **Log in online, level up once** (Test Panel Level Up, as a GM) → `character.save`'s
  Date modified does not change. notes:
- [ ] **Quit with Options, Quit Game** → still unchanged; on relogging, the character is as
  the server kept it (nothing lost). notes:
- [ ] **Log in, `/camp`, let the countdown finish** → the game closes as before; the file is
  still unchanged. notes:

## 2 — Regression: the Test Room still saves
- [ ] **Optional (dev box only): launch the editor, Test Room, level up** → `character.save`'s
  Date modified moves (the offline save still works). notes:
