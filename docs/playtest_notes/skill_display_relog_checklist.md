# Skill Display on Relog Playtest Checklist — 2026-07-23

Follow-up to the weapon_path playtest, which surfaced that weapon/armor/casting skills displayed as
their starting values (e.g. `1 / x`) after a relogin until the next advance snapped them to the
correct number. The scores were correct on the server the whole time — the bug was a stale character
window: it paints skills at world-load (before the server's `SkillProgressSnapshot` arrives), and
the snapshot then updates the cache silently (no repaint, to avoid CombatLog spam). Fixed by a
dedicated `snapshot_applied` signal that repaints the window when the snapshot lands (client
`0f0489b`).

**Build prereq: re-export Project_Dawn** (client-only change). Server restart optional.

Diagnostic: open the Character window (skills section shows `current / cap` per skill).

## Setup
- [x] Re-export Project_Dawn
- [x] Have a character that has trained at least one weapon/armor/casting skill above its start value

## 1 — Trained skills survive a relog (the fix)
- [x] **Note a trained skill's value, log out, log back in, open the Character window** → the skill
  shows its trained value immediately (NOT `1 / x`). notes:
- [x] **Do it with the Character window already open across the relog flow** (open it right after
  entering world) → values are correct without needing a skill to advance first. notes:

## 2 — No bogus CombatLog spam (regression)
- [x] **Watch the combat log during login** → NO "Your <skill> skill has increased to N" lines fire
  on entering the world (the snapshot repaint must not masquerade as an advance). notes:

## 3 — Live advance still works (regression)
- [x] **After login, train a skill (swing / cast) and watch it tick up** → the number increments live
  in the Character window and the combat log shows the real "increased to N" line. notes:

## 4 — All three skill kinds (regression)
- [x] **Confirm weapon, armor, AND casting skills all show correct trained values after relog**
  (armor advances by taking hits, casting by casting / medding). notes:

## Notes / observations
-
