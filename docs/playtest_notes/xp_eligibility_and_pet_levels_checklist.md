# XP Eligibility & Owner-Derived Pet Levels — 2026-09-27

Three server-only builds from the away-week batch, riding the next R720
redeploy together: the dead-XP eligibility filter (server `ba2af81`), owner-
derived pet levels / interim A (`1f73459`), and the NaN Move guard
(`4a55be7`), plus the review-fix pass (`5cf7508`). No client change, no
protocol bump — the current export works.

**Build prerequisite: server at `5cf7508` or later on the R720.**

---

## 1 — XP eligibility (needs the second seat)

- [ ] **Group up, one member dies beside the mob, the other finishes the kill** →
      the dead member gets NO XP line and NO journal tick; the killer's gain is
      the FULL solo amount; `server.log` shows `kill credit granted ... members=1`. notes:
- [ ] **The dead member respawns at bind (town), the killer kills again at the camp** →
      the far member still gets NO XP (outside the 30 m share range) but DOES get
      the quest journal tick if the mob matches — deliberate: the range gate was
      decided for XP shares only. Flag it here if that feels wrong in play. notes:
- [ ] **Both alive at the camp, kill together** → the ordinary split is intact
      (pool = 1.2x base, half each, `members=2`), both journals tick. notes:

## 2 — Owner-derived pet levels (solo)

- [ ] **Log in a leveled Beast Master** → the warder arrives at owner level minus 1
      (`warder auto-summoned ... level=N` in the log; was stuck at 5 forever). notes:
- [ ] **Let the warder die, wait out the ~15 s retreat** → it respawns at
      owner minus 1 again (not the old static 5). notes:
- [ ] **Necromancer: cast Summon Skeleton several times in a row** → the pet's
      level varies between owner-1 and owner-3 across casts (the EQ re-summon
      gamble; log line carries `level=` and `owner_level=`), and never exceeds 10
      on a high-level owner. notes:
- [ ] **Send a pet solo against an even-con camp mob** → the pet LOSES a fair
      one-on-one (it runs at ~70% of the mob curve, so a pet class is not a duo
      by itself). This row is the tuning read on PET_STAT_SCALAR — note the feel. notes:

## 3 — Refused casts keep their mana (silent-refusals closeout, 2026-09-30)

Every one of these should print a System chat line AND leave the mana bar
where it was. Before this build they were silent and charged full price.

- [ ] **Cast an attack spell with NOTHING targeted** → "You need a target for
      that spell." and no mana spent. notes:
- [ ] **Target yourself, cast an attack spell** → "You cannot cast that on
      yourself.", mana intact. notes:
- [ ] **Heal a group-mate at the instant they die** (or right after they zone) →
      "That target is no longer here.", mana intact. notes:
- [ ] **Cast a client-only pet spell** (one the server has no pet_type for) →
      "That magic has no effect here yet.", mana intact. notes:
- [ ] **Charm with nothing targeted, and charm a non-enemy** → the matching
      refusal, mana intact both times. notes:
- [ ] **Regression: an ordinary successful cast** still spends mana normally
      and lands its effect. notes:

## 4 — NaN Move guard (regression only)

- [ ] **Ordinary play after the redeploy** → walking, running, and jumping feel
      unchanged; zero movement weirdness. The exploit half needs a forged client
      and is pinned by the integration test `nan_move_direction_is_dropped`. notes:

---

## Result

- Server build (boot line):
- Client build (`/version`):
- Overall:
