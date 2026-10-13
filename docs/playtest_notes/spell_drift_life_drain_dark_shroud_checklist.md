# Ported Spells Re-test — Life Drain + Dark Shroud — 2026-07-22

> **Triage 2026-10-12** (the planner's week-5 chore, done early): the setup rows and the stock-client row retired; four casts worth a re-run (a Blood Mage and a Shadow Knight; ported_spells_checklist.md covered nine other spells, not these two).
> Rows flipped to `[-]` below carry the verdict and the reason after their `notes:`; the
> rows still open are the re-run: 25, 27, 30, 31 (line numbers as of the triage).

Follow-up to the cast-gate playtest, which surfaced that a Blood Mage's **Life Drain** and a Shadow
Knight's **Dark Shroud** did nothing (mana spent, "You cast X" in chat, no effect). Root cause was
client/server spell drift: both existed only in the client `spell_definitions.gd`, so the server
dropped the cast as "unknown spell" (5 such drops in `server.log`). Both are now in `spells.toml`
(server `e6a3542`). This verifies the ports land.

**Build prereq: restart the server (release build). No client re-export** — the client already had
these spells; only the server was missing them.

| Spell | Class | min_level | Effect | Notes |
|---|---|---|---|---|
| Life Drain | Blood Mage | 6 | 40 SHADOW dmg + heal caster for min(20, dmg) — lifetap | ENEMY |
| Dark Shroud | Shadow Knight | 10 | 55 SHADOW dmg | ENEMY |

Diagnostic: `server.log` should now show NO "unknown spell name ... spell=Life Drain / Dark Shroud"
lines for these casts.

## Setup
- [-] Restart server (release build) triage 2026-10-12: RETIRED, a setup row.
- [-] Log a Blood Mage (>= level 6) and a Shadow Knight (>= level 10); have an enemy to hit triage 2026-10-12: RETIRED, a setup row.

## 1 — Life Drain (Blood Mage lifetap)
- [ ] **Cast Life Drain on an enemy** → enemy takes damage AND you heal (up to 20, capped at the
  damage dealt). Not just "You cast" with no effect. notes:
- [ ] **`server.log` shows no "unknown spell ... Life Drain"** for this cast. notes:

## 2 — Dark Shroud (Shadow Knight nuke)
- [ ] **Cast Dark Shroud on an enemy** → enemy takes ~55 shadow damage. notes:
- [ ] **`server.log` shows no "unknown spell ... Dark Shroud"** for this cast. notes:

## 3 — Regression: the cast gate still holds on the ported spells
- [-] **A non-Blood-Mage can't cast Life Drain / a non-Shadow-Knight can't cast Dark Shroud** (they triage 2026-10-12: RETIRED, marked likely skipped on a stock client.
  won't have it scribed on a stock client; this is the backstop) — no effect, no mana spent, and if
  forced, `server.log` logs `class/level not eligible`. notes: (likely `[-]` — stock client)

## Notes / observations
-
