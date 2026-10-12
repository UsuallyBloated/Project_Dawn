# Charm Re-target Playtest Checklist — 2026-10-12

A charm used to drop your target: the server re-keys the mob under a new id when the charm
lands and again when it ends, and the client saw a despawn plus an unrelated spawn. Now both
spawns say which id they replace and the client moves its target across, so the mob stays
targeted throughout, as in EQ.

**Build prerequisite:** rides the PD_W0028 bump day (Oct 22) with the trade window. Needs the
R720 on the merged `feat/trade-window` server AND a client exported with the rebuilt
`gdext_net.dll`. An old DLL logs `gdext_net.dll predates entity_replaced` in the console and
the charm drops the target as before.

| Spell | Class / level | Lasts |
|---|---|---|
| Charm | Enchanter 20 | 60 s |
| Siren's Song | Bard 14 | 30 s (quicker for §2) |

Log anchors: `enemy charmed into pet` (landing, has `old_enemy_id` and `new_pet_id`),
`charm expired — mob returned hostile` (ending, has `pet_id` and `mob_id`).

## 1 — The charm lands

- [ ] **Target a mob, charm it** → the target frame stays on it the moment it becomes your
      pet (same name, now your pet). No re-click needed. notes:
- [ ] **Second seat targets the same mob; first seat charms it** → the second seat's target
      also stays on it (now the first seat's pet). notes:
- [ ] **Second seat targets a DIFFERENT mob while the first seat charms** → the second seat's
      target does not move. notes:

## 2 — The charm ends

- [ ] **Keep the pet targeted until the charm runs out** → the returned hostile mob is
      targeted with no click; auto-attack (if on) swings at it. notes:
- [ ] **Target yourself (F1) before the charm runs out** → when it ends you stay on
      yourself; the returned mob is not auto-targeted. notes:
- [ ] **Charmer camps / quits while the pet is targeted by a second seat** → the second
      seat's target moves to the mob that walks home. notes:

## 3 — Regression

- [ ] **Ordinary summon (warder or Summon Skeleton) while targeting a mob** → target
      unchanged. notes:
- [ ] **Console clean** through all of the above (no `Nonexistent signal`, no errors from
      `targeting.gd`). notes:

---

## Result

- Server build (boot line):
- Client build (`/version`):
- Overall:
