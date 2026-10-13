# Chat Wrap and Pet Buttons Playtest Checklist — 2026-10-07

Two asks from the charm-return sitting, both client-only. Chat lines now wrap at the window's
width and re-wrap when the window is resized (they used to be clipped at the right edge). The
pet panel (top left, shown while you have a pet) has a row of buttons for the five `/pet`
commands. **Client-only: needs an export, or a run from the editor; any server.** The
target-frame distance readout from 10-06 rides the same export.

## Setup
- [ ] Run a build from `2026-10-07` or later (the login-screen stamp), or the editor

## 1 — Chat wrapping
- [ ] **Fight something so long combat lines arrive** → every line wraps inside the window; nothing is cut off at the right edge. notes:
- [ ] **Drag the chat window narrower, then wider** → the lines re-wrap to the new width both ways and the view stays at the bottom. notes:
- [ ] **Change the chat font size** → wrapped lines re-flow at the new size. notes:

## 2 — Pet buttons
- [ ] **Summon or charm a pet** → the pet panel shows name, level, an HP bar and five buttons: Attack, Back, Guard, Follow, Sit. notes:
- [ ] **Target a mob and press Attack** → the pet goes for it, same as `/pet attack`. notes:
- [ ] **Press Guard, walk away, press Follow** → it stays, then comes; Back brings it to your side; Sit parks it passive. notes:

## 3 — Spell tooltip range (built 2026-10-12, rides the same export)
The three spell tooltips (a hotbar gem, a memorized gem, a book row) end with `Range:` for a
spell that has something to reach; spells with no target to reach show no range.
- [ ] **Hover a nuke on the hotbar, in the spell bar and in the book** → each tooltip ends `Range: 24 m`. notes:
- [ ] **Hover a heal or a buff** → `Range: 29 m to others`; hover a self-only buff, a port, Bind Affinity or a summon → no Range at all; hover Reclaim Soul → `Range: 30 m`. notes:

## 4 — Casting while seated (built 2026-10-12, same export)
The client used to refuse with "You cannot cast while sitting."; the server stands a caster
at CastStart, so the client now stands you and casts, as EQ does.
- [ ] **Sit, then cast anything** → you stand up and the cast goes on; no "cannot cast while sitting" line. notes:
- [ ] **Sit, cast, and watch the HP/MP tick** → the regen drops to the standing rate at once (the Stand reached the server; the server log shows no seated regen after the cast). notes:

## 5 — Regression
- [ ] **The target frame shows the distance to the target** (from 10-06, same export). notes:
- [ ] **Chat tabs, `/r` and TAB tell-cycling** → unchanged. notes:

## Notes / observations
-
