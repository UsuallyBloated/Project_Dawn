# XP Eligibility & Owner-Derived Pet Levels — 2026-09-27

Three server-only builds from the away-week batch, riding the next R720
redeploy together: the dead-XP eligibility filter (server `ba2af81`), owner-
derived pet levels / interim A (`1f73459`), and the NaN Move guard
(`4a55be7`), plus the review-fix pass (`5cf7508`). No client change, no
protocol bump — the current export works.

**Build prerequisite: server at `5cf7508` or later on the R720.** (Met since 10-05; on 10-07
the R720 is on `e3a6fa8`.) **Wording note (10-07):** the refusal lines in §3 were rewritten on
10-02 as `Cast failed: <reason>`, so judge each row on "refused, and the mana stayed", not on
the exact words below.

---

## 1 — XP eligibility (needs the second seat)

- [x] **Group up, one member dies beside the mob, the other finishes the kill** →
      the dead member gets NO XP line and NO journal tick; the killer's gain is
      the FULL solo amount; `server.log` shows `kill credit granted ... members=1`. notes: Triage 10-07 from the journal: group formed 21:45:35 (`gid=1`, chars 7 and 1); `21:46:29 corpse created char_id=1` beside the skeleton; `21:46:32 kill credit granted killer=7 mob=Decrepit Skeleton base_xp=263 pool=263 per_member=263 members=1`. The dead member was filtered and the killer took the full amount. PASS.
- [x] **The dead member respawns at bind (town), the killer kills again at the camp** →
      the far member still gets NO XP (outside the 30 m share range) but DOES get
      the quest journal tick if the mob matches — deliberate: the range gate was
      decided for XP shares only. Flag it here if that feels wrong in play. notes: (Claude, 10-07: SKIP this row. The 30 m rule is changing to 200 m for XP, journal ticks and coin alike, decided 10-05; the row gets rewritten with step 1 of the spell batch.) Triage 10-07: the XP half shows in the journal anyway: char 1's five Gnoll Brute kills from 21:48 to 21:51, while grouped with char 7 at the skeletons, all read `members=1`, so the far member got no share.
- [x] **Both alive at the camp, kill together** → the ordinary split is intact
      (pool = 1.2x base, half each, `members=2`), both journals tick. notes: Triage 10-07: the pasted journal (to 21:54) has no `members=2` line; if the shared kill came after that, paste its `kill credit granted ... pool=... per_member=... members=2` line here and the row is proven.

## 2 — Owner-derived pet levels (solo)

- [x] **Log in a leveled Beast Master** → the warder arrives at owner level minus 1
      (`warder auto-summoned ... level=N` in the log; was stuck at 5 forever). notes: 2026-10-06 journal, Fennric (Beast Master 4): `19:13:20 Beast Master warder auto-summoned owner=9 pet_id=3000000002 level=3`. Owner minus one.
- [x] **Let the warder die, wait out the ~15 s retreat** → it respawns at
      owner minus 1 again (not the old static 5). notes:
- [x] **Necromancer: cast Summon Skeleton several times in a row** → the pet's
      level varies between owner-1 and owner-3 across casts (the EQ re-summon
      gamble; log line carries `level=` and `owner_level=`), and never exceeds 10
      on a high-level owner. notes:
- [x] **Send a pet solo against an even-con camp mob** → the pet LOSES a fair
      one-on-one (it runs at ~70% of the mob curve, so a pet class is not a duo
      by itself). This row is the tuning read on PET_STAT_SCALAR — note the feel. notes:  I used a charmed pet.  I assume this isnt balanced the same. **Triage 10-07: right, it is not.** A charmed mob keeps its own full stats (it IS the mob); only summoned pets, the warder and Summon Skeleton, run at the 70% scalar. So the tuning read is still open: send Fennric's warder (or a Necro skeleton) alone at an even-con mob and note whether it loses. Left ticked as you marked it; the feel note is what this row is for.

## 3 — Refused casts keep their mana (silent-refusals closeout, 2026-09-30)

Every one of these should print a System chat line AND leave the mana bar
where it was. Before this build they were silent and charged full price.

- [x] **Cast an attack spell with NOTHING targeted** → "You need a target for
      that spell." and no mana spent. notes:
- [x] **Target yourself, cast an attack spell** → "You cannot cast that on
      yourself.", mana intact. notes:  "No valid target." Triage 10-07: that line is the client's own pre-check refusing before anything is sent (the server's "You cannot cast that on yourself." sits behind it for a forged client). Refused, mana kept: PASS.
- [ ] **Heal a group-mate at the instant they die** (or right after they zone) →
      "That target is no longer here.", mana intact. notes: (Claude, 10-07: easiest staging is the one you did by accident: char 1 dies to gnolls while Mirelle has them targeted; start the heal as they drop. If it will not line up, mark `[-]`; the dead-target refusal is pinned by the cast pre-flight's tests.)
- [ ] **Cast a client-only pet spell** (one the server has no pet_type for) →
      "That magic has no effect here yet.", mana intact. notes: (Claude, 10-07: use Fennric's Warder's Mend, a Beast Master level 1 spell the server has no arm for; the line now reads `Cast failed: ...`.):  Can we make sure there are no client-only pet spells?w **Triage 10-07: yes, and done.** Warder's Mend was the only one; the server now has a PET_HEAL arm (server `8a826a5`, pending redeploy): it mends your own pet, whatever is targeted, and says "You have no pet to mend." when you have none. The lockstep check shows 22 client-only spells left, none of them pet spells. **This row becomes:** after the redeploy, Fennric casts Warder's Mend on a hurt warder: the warder's HP bar rises by 60 and `PET_HEAL applied` is in the journal; with no warder, the refusal above and the mana kept.
- [x] **Charm with nothing targeted, and charm a non-enemy** → the matching
      refusal, mana intact both times. notes: "No valid target" when targeting player group member, "Cast failed: You cannot charm that."  when targeting self. Triage 10-07: the first is the client's pre-check, the second the server's pre-flight; both refused with the mana kept. PASS.
- [x] **Regression: an ordinary successful cast** still spends mana normally
      and lands its effect. notes:

## 4 — NaN Move guard (regression only)

- [x] **Ordinary play after the redeploy** → walking, running, and jumping feel
      unchanged; zero movement weirdness. The exploit half needs a forged client
      and is pinned by the integration test `nan_move_direction_is_dropped`. notes: (Claude, 10-07: three sittings of play on builds carrying the guard, 10-05 to 10-07; tick it if movement has felt normal.)

---

## Result

- Server build (boot line): `e3a6fa8` (2026-10-07 02:34 UTC), `dev_cmds=false`
- Client build (`/version`): the 10-05 export (`fc880df`) or the editor
- Overall: 2026-10-07, two rows left (the dying-ally heal; Warder's Mend after the redeploy of `8a826a5`); the pet tuning read wants a summoned pet.
