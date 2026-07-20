# Attack-While-Seated Playtest Checklist — 2026-07-20

Verifies the "attack while seated" fix: a swing now **stands** a seated player (you can't fight
seated), and the seated "meditation" regen bonus is **suppressed in combat**. Server commit
`3bb9b6d` + client `9303682`.

**Build:** **re-export / reload Project_Dawn** (client `combat.gd` changed) AND restart the server
(`3bb9b6d`). No wire/DLL change.

**Note on the regen half:** base regen is currently **0** (disabled by playtest request), so the
seated-regen suppression has no *visible* effect yet — it's unit-tested (`regen::sitting_bonus_from`)
and guards the exploit for when regen is re-enabled. So this manual pass is really the
**standing-to-swing behavior**.

## 1 — A swing stands you
- [ ] **Sit** (`/sit` or the sit key); confirm the character is visibly seated. notes:
- [ ] **Target an enemy and turn on auto-attack** (default Q) in range → the character **stands
  up** and swings; it does NOT keep attacking while seated. notes:
- [ ] You deal damage normally once standing. notes:

## 2 — You can't stay seated while fighting
- [ ] **While auto-attacking, `/sit`** → you may sit for a moment but the next swing stands you
  again (auto-attack keeps you standing). notes:
- [ ] **Turn OFF auto-attack, then `/sit`** → now you stay seated (out of combat). notes:

## 3 — Regen gate (dormant while base regen = 0)
- [ ] Not directly observable yet (regen disabled). Recorded for when regen is re-enabled: a
  seated player who dealt or took damage in the last ~6s regenerates at the standing rate, not the
  boosted seated rate. Covered by the `sitting_bonus_from` unit test. notes:

## Notes / observations
-
