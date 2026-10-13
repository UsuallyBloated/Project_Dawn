# Attack-While-Seated Playtest Checklist — 2026-07-20

> **Triage 2026-10-12** (the planner's week-5 chore, done early): one row left, superseded.
> Rows flipped to `[-]` below carry the verdict and the reason after their `notes:`; the
> rows still open are the re-run: none (line numbers as of the triage).

Verifies the "attack while seated" fix: a swing now **stands** a seated player (you can't fight
seated), and the seated "meditation" regen bonus is **suppressed in combat**. Server commit
`3bb9b6d` + client `9303682`.

**Build:** **re-export / reload Project_Dawn** (client `combat.gd` changed) AND restart the server
(`3bb9b6d`). No wire/DLL change.

**Note on the regen half:** base regen is currently **0** (disabled by playtest request), so the
seated-regen suppression has no *visible* effect yet — it's unit-tested (`regen::sitting_bonus_from`)
and guards the exploit for when regen is re-enabled. So this manual pass is really the
**standing-to-swing behavior**.

> **UPDATE 2026-07-20 (after this checklist was authored):** regen was re-activated to the EQ model,
> so the seated-regen-in-combat suppression is now LIVE, not dormant. Section 3 is therefore
> live + unit-tested; the standing-to-swing behavior (sections 1-2, both `[x]`) is the manual
> evidence for the tick.

## 1 — A swing stands you
- [x] **Sit** (`/sit` or the sit key); confirm the character is visibly seated. notes:
- [x] **Target an enemy and turn on auto-attack** (default Q) in range → the character **stands
  up** and swings; it does NOT keep attacking while seated. notes:
- [x] You deal damage normally once standing. notes:

## 2 — You can't stay seated while fighting
- [x] **While auto-attacking, `/sit`** → you may sit for a moment but the next swing stands you
  again (auto-attack keeps you standing). notes:
- [x] **Turn OFF auto-attack, then `/sit`** → now you stay seated (out of combat). notes:

## 3 — Regen gate (dormant while base regen = 0)
- [-] Not directly observable yet (regen disabled). Recorded for when regen is re-enabled: a triage 2026-10-12: SUPERSEDED, the same check is regen_model_checklist.md row 69 (combat suppresses seated regen).
  seated player who dealt or took damage in the last ~6s regenerates at the standing rate, not the
  boosted seated rate. Covered by the `sitting_bonus_from` unit test. notes:

## Notes / observations
- Player will eventually take bonus damage from attacks while seated, including a bonus to attacker's critical chance and critical damge.
- Player will eventually stand when receiving damage.
