# Ported Spells Re-test — Life Drain + Dark Shroud — 2026-07-22

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
- [ ] Restart server (release build)
- [ ] Log a Blood Mage (>= level 6) and a Shadow Knight (>= level 10); have an enemy to hit

## 1 — Life Drain (Blood Mage lifetap)
- [ ] **Cast Life Drain on an enemy** → enemy takes damage AND you heal (up to 20, capped at the
  damage dealt). Not just "You cast" with no effect. notes:
- [ ] **`server.log` shows no "unknown spell ... Life Drain"** for this cast. notes:

## 2 — Dark Shroud (Shadow Knight nuke)
- [ ] **Cast Dark Shroud on an enemy** → enemy takes ~55 shadow damage. notes:
- [ ] **`server.log` shows no "unknown spell ... Dark Shroud"** for this cast. notes:

## 3 — Regression: the cast gate still holds on the ported spells
- [ ] **A non-Blood-Mage can't cast Life Drain / a non-Shadow-Knight can't cast Dark Shroud** (they
  won't have it scribed on a stock client; this is the backstop) — no effect, no mana spent, and if
  forced, `server.log` logs `class/level not eligible`. notes: (likely `[-]` — stock client)

## Notes / observations
-
