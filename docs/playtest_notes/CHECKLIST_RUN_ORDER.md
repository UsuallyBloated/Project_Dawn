# Checklist run order

The order to run the open playtest checklists in, and what each needs. Kept current whenever a
checklist is added or finished (last update 2026-10-06). The status of every row lives in the
checklist files themselves; this page only says what to run next.

**As of 2026-10-06 evening, both sides are current:** server `6a802f4` on the R720 (redeployed
20:06 with the charm and leash fixes from the first ported-spells sitting), client exported
from `fc880df`. Every list below is runnable now; `ported_spells_checklist.md` §4 reruns as
the regression for those two fixes.

**Test characters:** the `spelltest` account holds one character per class the spell rows
need (table in `ported_spells_checklist.md`). Log in as `spelltest` with password
`VFRJDgPerb25yzDk` (a throwaway non-GM account on the tailnet-only server; the user asked for
it kept here, 2026-10-06. If it ever needs changing: `reset_password spelltest` on the host).

## One seat, in this order

1. `ported_spells_checklist.md` (7 rows + 2 spot checks in §4). Use the `spelltest` characters.
2. `scale_readiness_checklist.md` §1, §2, §4. The §1 log line on the R720:
   `journalctl -u projectdawn --since "5 min ago" --no-pager | grep "enemy position fan"`.
   §4 is the pet: `/pet guard`, run off past 300 m (`/loc` measures it), `/pet follow`.
3. `xp_eligibility_and_pet_levels_checklist.md` §2, §3, §4. In §3 judge on "refused, and the
   mana stayed", not the exact wording (it changed on 10-02).
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
- `scale_readiness_checklist.md` §3
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
