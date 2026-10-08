# Checklist run order

The order to run the open playtest checklists in, and what each needs. Kept current whenever a
checklist is added or finished (last update 2026-10-06). The status of every row lives in the
checklist files themselves; this page only says what to run next.

**As of 2026-10-07 evening:** server `8a826a5` on the R720 (redeployed 23:40 UTC with
Warder's Mend and the charm walk-home; `e3a6fa8` and `6a802f4` earlier the same day), client
exported from `fc880df` (10-05). Every server-side list below is runnable now; the
client-only sheet (1c) needs an export or the editor. **Pushed, not deployed (10-08):**
`5d8d385` (step 0), `c71b686` (step 1), `75ab979` + review fixes `7e07351` (step 2),
`4303459` (step 3), `9c4895e` (step 4); 3b to 3f wait on that redeploy, 3c's spell rows and
all of 3d and 3f on the next export too.

**Test characters:** the `spelltest` account holds one character per class the spell rows
need (table in `ported_spells_checklist.md`). Log in as `spelltest` with password
`VFRJDgPerb25yzDk` (a throwaway non-GM account on the tailnet-only server; the user asked for
it kept here, 2026-10-06. If it ever needs changing: `reset_password spelltest` on the host).

## One seat, in this order

1. `ported_spells_checklist.md`: COMPLETE 2026-10-06 (every row filled; the §4 bugs fixed and
   rerun the same evening).
1b. `charm_return_checklist.md`: COMPLETE 2026-10-07 (all 9 rows); one re-check row after
   the next redeploy (the quit case now walks home).
1c. `chat_wrap_and_pet_buttons_checklist.md` (8 rows; client-only, run from the editor or wait
   for the next export): chat lines wrap, pet panel buttons, the distance readout.
2. `scale_readiness_checklist.md`: COMPLETE 2026-10-07 (every row, §3 two-boxed).
3. `xp_eligibility_and_pet_levels_checklist.md`: mostly filled 2026-10-07. Left: the
   dying-ally heal row (§3), the Warder's Mend row after the redeploy of `8a826a5` (§3), and
   the `members=2` line for §1's shared kill. The pet tuning read wants a summoned pet.
3b. `cast_hardening_checklist.md` (12 rows; needs a redeploy with `5d8d385` or later,
   server only): spell batch step 0. Two rows want a second seat; two are test-pinned.
3c. `small_rules_checklist.md` (16 rows; needs a redeploy with `c71b686` or later; the spell
   rows also want the next export or the editor): spell batch step 1. §1 wants a second seat.
3d. `bind_and_gate_checklist.md` (25 rows; needs a redeploy with `7e07351` or later AND the
   next export, since the old client still runs Gate locally): spell batch step 2. §3 and §4
   want a second seat.
3e. `interrupt_charge_checklist.md` (13 rows; needs a redeploy with `4303459` or later;
   server only): spell batch step 3. §3 wants a second seat.
3f. `global_cooldown_checklist.md` (16 rows; needs a redeploy with `9c4895e` or later AND
   the next export, since the gem greying and the client-side refusal are client code): spell
   batch step 4. Caderyn (Bard 10 on `spelltest`) for the twisting rows.
4. `loc_command_checklist.md` (5 rows).
5. `full_bags_move_checklist.md` (9 rows).
6. `time_of_day_checklist.md` §1, §3, §4 (quit and relaunch: the clock carries on, not back to 08:00).
7. `inspect_range_gm_audit_ban_checklist.md` §2 (audit log via `admin_report`), §5 (dev tools
   regression), §6 (the Hunter's Medal on the sheet).
8. `bagspace_groupbars_checklist.md` §1 (carry a pouch, buy something, watch it fill).

## Two seats (two accounts; two-boxing works)

- `tell_reply_and_inspect_click_checklist.md` (all of it)
- `xp_eligibility_and_pet_levels_checklist.md` §1. **Skip** the row where the dead member
  respawns in town and the killer keeps killing: that 30 m rule is changing to 200 m and the row
  will be rewritten.
- `time_of_day_checklist.md` §2
- `inspect_range_gm_audit_ban_checklist.md` §1 (inspect range), §3 (ban a throwaway account
  while it is logged in), §4 (heals and nukes out of range)

## Stragglers (older checklists with a few rows left)

- `bagspace_groupbars_checklist.md`: the pouch rows above.
- `machine_day_2026_09_22_checklist.md`: 4 rows.
- `silent_refusals_checklist.md`: 2 rows (a refused cast keeps its mana).
- Sixteen older files have 1 to 6 rows each, mostly single edge cases never exercised.

## Never started, probably stale (audit before playtesting)

`camp_checklist.md` (18), `item_weights_checklist.md` (20), `gnome_model_checklist.md` (17),
`spell_drift_life_drain_dark_shroud_checklist.md` (7), most of `group_loot_coin_checklist.md`
(14 of 51). Some of that work was confirmed in play without the sheet being filled in.

## Counting the open rows

From `docs/playtest_notes/`:

```
python - <<'EOF'
import re,glob,os,time
for f in sorted(glob.glob('*checklist*.md'), key=os.path.getmtime, reverse=True):
    if f.startswith('TEMPLATE'): continue
    s=open(f,encoding='utf-8').read()
    o=len(re.findall(r'^\s*- \[ \]',s,re.M)); x=len(re.findall(r'^\s*- \[[xX]\]',s,re.M)); d=len(re.findall(r'^\s*- \[-\]',s,re.M))
    if o: print(f"{time.strftime('%m-%d',time.localtime(os.path.getmtime(f)))} open={o:2d} pass={x:2d} skip={d:2d} {f}")
EOF
```
