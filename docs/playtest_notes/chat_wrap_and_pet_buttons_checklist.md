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

## 3 — Regression
- [ ] **The target frame shows the distance to the target** (from 10-06, same export). notes:
- [ ] **Chat tabs, `/r` and TAB tell-cycling** → unchanged. notes:

## Notes / observations
-
