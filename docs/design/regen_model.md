# Regen Model (EQ-authentic) — design + tuning spec

Replaces the stat-scaled regen (`base + stat × scale`) with the classic-EQ **flat rate by level
bracket + posture (+ race for HP, + Meditate skill for MP)**. Source: EQ health/mana regen tables.
This doc is the spec to implement against **and** the tuning reference. **`regen.rs` (server) and
`regen.gd` (client) must stay in lockstep** — retune both together.

## Decisions (locked with the user 2026-07-20)
1. **Scope:** regen RATES only. The pool-size formulas (STA→HP max-HP, the mana-pool equation) are
   OUT of scope here — see "Deferred".
2. **Tick cadence:** **6 s** (was 3 s). EQ's per-tick numbers apply directly at 6 s (no halving).
3. **Meditate:** implement the skill now (server-authoritative, trains while sitting).
4. **Fast-regen race:** **Troll** only for now (EQ's Troll/Iksar bonus). More later.
5. **Stamina:** flat **10 / tick**, posture-independent.

## HP regen (per 6 s tick)
Flat, by level bracket and posture. Not stat-scaled. Troll gets the fast column.

| Level | Standing | Sitting | Troll Standing | Troll Sitting |
|---|---|---|---|---|
| 1-19  | 1 | 2 | 2 | 4 |
| 20-49 | 1 | 3 | 2 | 6 |
| 50    | 1 | 4 | 2 | 8 |
| 51-55 | 2 | 5 | 6 | 12 |
| 56-59 | 3 | 6 | 10 | 16 |
| 60    | 4 | 7 | 12 | 18 |

- **Posture:** we have `STANDING / CROUCHING / SITTING`. Standing and Crouching both use the
  *Standing* column; Sitting uses the *Sitting* column. EQ's **Feigned** column is dropped (no Feign
  Death state yet — a later posture).
- **Combat gate:** the attack-while-seated fix already suppresses the *sitting* rate in combat
  (`sitting_bonus_applies`, 6 s lockout after dealing/taking damage) — a seated player in combat
  regens at the Standing rate. Keep that.
- Note how stingy this is early (1-2 HP/6s at low level) — that is the classic-EQ "downtime matters"
  feel, and a big slowdown from the current values. Intended.

## MP regen (per 6 s tick)
- **Standing:** 1 MP, always (regardless of Meditate).
- **Sitting:** `2 + floor(meditate_skill / 12)` MP.
- Combat-gated like HP: in combat, a seated caster regens at the Standing rate (1).
- Classes with no mana pool (Warrior / Monk / Rogue) regen 0 MP and have no Meditate.

## Stamina regen (per 6 s tick)
- Flat **10 / tick**, posture-independent (no sitting bonus, no combat gate unless we decide
  otherwise). Simple; EQ's tables don't cover our stamina bar.

## Meditate skill (new, server-authoritative)
Rides the existing skill infra (`character_skills` persist + `SkillProgress` sync + the client
`CastingSkills` mirror), added as a skill the server owns.
- **Who has it:** classes with a mana pool. Pure-melee classes never train it.
- **Cap:** `min(5 × level, 250)` (tunable). At 60 → 250 → up to `+20` MP/tick sitting.
- **Training:** server-side, in the tick loop. While **sitting with MP < max** (actually meditating),
  each 6 s tick advances Meditate toward its cap (EQ skill-up: `+1` with a diminishing-returns
  chance, or simply `+1` per med-tick until cap — start simple, tune later). Fan a `SkillProgress`
  update on a change so the client mirror + character window update.
- **Persistence / sync:** free — it rides `character_skills` and the existing `SkillProgress` path.
- **Auth:** server-authoritative (client never asserts the score), consistent with the exploit
  posture — a modified client can't claim Meditate 250.

## Implementation plan
1. **Tick cadence → 6 s.** `regen.rs` `CLIENT_TICK_INTERVAL_SECS` and `regen.gd` `TICK_INTERVAL`
   (both 3.0 → 6.0). Server still integrates every 50 ms and scales by `dt / 6.0`.
2. **HP/MP/ST rate rewrite.** Replace the `base + stat × scale` formulas with the lookups above,
   keyed by `conn.level`, posture (`is_sitting`), and race (`conn.race == "Troll"`). Mirror in
   `regen.gd`. Keep the combat gate on the sitting HP/MP rate.
3. **Meditate skill.** Define it (client `CastingSkillDefinitions` + server `skills.rs`), seed
   per-class starting scores, add the sit-based training hook in the tick loop, and read it in MP
   regen. Lockstep the cap + training between client and server.
4. **Tests.** Unit-test the rate lookup (bracket/posture/race) and the Meditate MP contribution;
   keep `sitting_bonus_applies`. Playtest checklist for the feel + Meditate training + Troll bonus.

## Deferred (explicitly NOT in this pass)
- **Pool-size formulas** — the STA→HP max-HP conversions (class+level scaled) and the mana-pool
  equation `((80 × level)/425) × WIS/INT`. These change how max HP/MP are *computed*, a separate
  system from regen. Revisit as its own task.
- **Feign Death posture** (the EQ "Feigned" column) — needs an FD state first.
- **More fast-regen races** beyond Troll.
- **Food/water gating** of base regen (already its own To-Do item) — orthogonal; can layer later.

## Open tuning questions
- Meditate cap formula + training rate (start `min(5×level, 250)`, `+1` per med-tick; tune on feel).
- Should stamina get a sitting bonus, or stay flat 10? (Currently flat.)
- Low-level HP regen is very slow (1-2/6s); confirm that's the intended feel before shipping wide.
