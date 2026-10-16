# Nameplates Through Walls Playtest Checklist — 2026-10-15

Other players' nameplates used to draw over everything, so a player standing behind a building
or a wall showed their name through it (in PvP, a free look at someone hiding). They are now
depth-tested like every other nameplate: walls and terrain hide them. Enemy, NPC, pet and
station nameplates have been depth-tested since 2026-05-01 (the May complaint was fixed the
same day it was written down); their rows here are the regression check. **Client only: needs
the next export** (built from this checklist's commit or later); the server needs nothing.
Two seats for §1.

Diagnostics: `tools/check_nameplates.gd` (headless, exits 1) checks the flag on every
nameplate scene; a plate showing through a wall on a build that passes it means a different
cause (an untextured or transparent wall), so note the wall.

## Setup
- [ ] The next export on both seats
- [ ] Two characters near the town buildings

## 1 — Other players (the change)
- [ ] **B walks behind a building while A watches** → B's nameplate disappears with B; it does not float through the wall. notes:
- [ ] **B steps back into view** → the nameplate is there again at once, readable. notes:
- [ ] **A targets B, then B walks behind the building** → B's plate hides; A's target frame still shows B. notes:
- [ ] **B grouped with A, behind a wall** → hidden too (a group-mate's plate is no exception, as in EQ). notes:
- [ ] **B in the open at 30 to 40 m** → the plate reads clearly and is not clipped by B's own head. notes:

## 2 — Regression: the rest stay as they were
- [ ] **A mob behind a wall or building** → its nameplate is hidden. notes:
- [ ] **An NPC behind the bank or a stall** → hidden. notes:
- [ ] **A corpse behind a wall** → its "<name>'s corpse" label is hidden. notes:
- [ ] **Damage numbers in a fight** → still float over everything (deliberately not depth-tested). notes:

## Notes / observations
-
