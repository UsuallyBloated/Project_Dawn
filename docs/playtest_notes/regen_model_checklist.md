# Regen Model (EQ-authentic) Playtest Checklist — 2026-07-20

Verifies the classic-EQ regen rewrite (`docs/design/regen_model.md`): flat per-6s-tick rates by
level bracket + posture, the Troll HP bonus, and the new **Meditate** casting skill (server-trained
while sitting, scales sitting MP). Commit (a) flat rates was already playtested and felt good; this
round confirms (b) — Meditate training + sync + the Troll column — end to end.

**Build prereq: re-export Project_Dawn AND restart the server (release build).** Meditate is trained
server-side, so most of this must be run in **launcher mode** (connected to the server), not the
Test Room. Client `regen.gd` mirrors the tables for the Test Room only.

| Rate | Standing | Sitting | Source |
|---|---|---|---|
| HP (non-Troll, lvl 1-19) | 1 | 2 | flat table |
| HP (Troll, lvl 1-19) | 2 | 4 | Troll column |
| MP (mana class) | 1 | `2 + floor(meditate/12)` | Meditate skill |
| Stamina | 10 | 10 | flat, posture-independent |

Meditate cap = `250 × level / 60` for mana classes, 0 for Warrior / Rogue / Monk.
Diagnostics: character window (Skills tab) for the live Meditate score; `server.log` grep
`SkillProgress` / `meditate` for the server-side gains.

## Setup
- [x] Re-export Project_Dawn
- [x] Restart server (release build)
- [x] Log in a **mana class** (e.g. Cleric / Wizard) in launcher mode, out of combat
- [x] (Troll row) also have, or roll, a **Troll** of any class to compare HP regen

> **Known gotcha:** in combat, seated regen is suppressed to the *standing* rate for 6 s after
> dealing OR taking damage (`sitting_bonus_applies`). If seated regen "isn't kicking in", confirm
> you're actually out of combat — the lockout is the attack-while-seated fix, working as intended.

## 1 — Standing vs sitting MP (mana class)
- [x] **Stand out of combat, spend some MP, wait a tick** → MP climbs 1 per ~6s. notes:
- [x] **Sit and wait a tick** → MP climbs at least 2 per ~6s (more as Meditate grows). notes:
- [x] **Stand back up** → MP regen drops back to 1 per tick. notes:

## 2 — Meditate trains while medding
The skill only advances while **sitting, out of combat, with MP below max** (actually meditating).
- [x] **Sit with MP not full and watch the character window Skills tab** → Meditate score climbs
  over successive ticks. notes:
- [x] **Stand up (or top MP to full)** → Meditate stops advancing (no training while not medding).
  notes:
- [x] **As Meditate climbs, seated MP/tick increases** (crosses 3/tick at meditate 12, 4 at 24, …).
  notes:
- [ ] **`server.log` shows the server-side gains** (grep `meditate`) — training is server-owned,
  not client-claimed. notes:

## 3 — Meditate persists + syncs
- [x] **Med for a while, then log out and back in** → Meditate score is retained (rides
  `character_skills`). notes:
- [ ] **Second client can't inflate its own Meditate** (server-authoritative; a client value never
  overrides the server). notes: I'm not sure how to test this.

## 4 — Pure-melee classes have no Meditate
- [ ] **Log a Warrior / Rogue / Monk, sit with (any) MP** → Meditate stays 0 / absent; seated MP
  regen does not benefit. notes:

## 5 — Troll HP bonus
- [x] **Troll vs non-Troll, same level, both standing, damaged** → Troll HP climbs faster (2 vs 1
  at low level). notes:
- [x] **Both sitting** → Troll HP climbs on the fast column (4 vs 2 at low level). notes:

## 6 — Stamina flat
- [ ] **Spend stamina, wait ticks, standing** → stamina regens ~10/tick. notes:I'm not sure what costs Stamina at the moment.
- [ ] **Sit** → stamina still ~10/tick (posture makes no difference). notes: I'm not sure what costs Stamina at the moment.

## 7 — Combat gate (regression: attack-while-seated fix intact)
- [ ] **Sit, then take or deal damage** → for the next ~6s seated HP/MP regen is suppressed to the
  standing rate. notes:
- [x] **6s after the last hit, still seated** → seated (fast) regen resumes. notes: Can't tell if this works.  6s tick seems to persist at normal pace regardless of incoming damage.

## Notes / observations
-
