# Handoff — A finer-grained schedule for the planner

**For:** a fresh Claude session working in `F:\Projects\Project_Dawn` (docs work; no code).
**Written:** 2026-10-05. **Branch:** `fix/xp-leveling-overflow` (both repos).
**Requested by:** the project's planner, the user's wife, through the user: she wants "a more
molecular coverage of the schedule". She reads `docs/schedule.html`, not the repo.

The user is at a usage limit and will hand you this file. Ask the planner's questions in Part 2
before producing anything; the user relays, or she answers directly.

---

## Part 1 — What exists today (read these first)

**The schedule itself.**
- `docs/schedule.md` is canonical; `docs/schedule.html` (1,121 lines, hand-written, standalone
  so it can be emailed) is the rendering non-repo readers use. Target **2026-11-08** (slipped
  from 09-14, then 10-05). Working assumption 30 hours a week.
- It was **restructured on 2026-09-09** after an accuracy audit found the same facts in three
  hand-synced homes drifting in opposite directions. The rules since then, which this work must
  keep: the per-phase bullet lists are frozen snapshots and never edited; **§7 Status is the only
  live part** (one row per phase); **the CLAUDE.md To-Do is the only live item list**; nothing is
  ticked without a filled checklist in `docs/playtest_notes/`. Read `schedule.md` lines 15 to 46
  for the rule in the project's own words, and the memory of it in the To-Do entry "Audit the
  schedule and the To-Do for accuracy end to end" (closed 09-09).
- Its granularity is six phases in two-week windows. Nothing in it says what happens on which
  day or week between now and 11-08. That is the gap the planner is pointing at.

**Where the molecules already live.** You do not need to invent the work; you need to lay it out.
- `CLAUDE.md` To-Do: every open item, with "BUILT, pending playtest" states and the name of
  the checklist that would close each. This is the source of truth for status.
- `docs/playtest_notes/*checklist*.md`: 71 checklists; 39 fully filled; 32 with open rows. The
  current verification queue is eight of them, 123 rows, all runnable now (server and client
  are both current as of 2026-10-05 evening). Count them with the snippet in Part 5.
- `docs/design/spell_batch_plan_2026_10_05.md`: a six-step build plan with day estimates
  (about 5 working days of build plus review and checklists). **Proposed, not approved.** Carry
  it as tentative, clearly marked, unless the user says it is approved.
- `docs/design/trade_window.md`: built on `feat/trade-window`; needs its own deploy day with a
  protocol bump (both sides move together, DLL rebuilt from that branch).
- `docs/design/phase5_plan.md`: what comes after the target; three open questions at the end.
- `docs/deployment/inviting_a_player.md` and `README_FOR_TESTERS.md`: onboarding one friend.
  (`docs/deployment/` is deliberately untracked; read it, never commit it.)
- `docs/session_notes/README.md`: dated rows for every sitting; the honest record of pace.
- `schedule.md` §1: the measured velocity (7 epics in 4.3 weeks, typical 3 days, with real
  gaps of 3 and 10 days). Any estimate you write must trace back to this or to the plan file.

**How the work actually flows** (the planner needs this to sequence anything):
- Claude builds, often unattended on days the user is away, and writes a checklist per change.
- Only the user can: redeploy the hosted server (the R720), export the client, run checklists,
  invite friends. Some checklist sections need a second seat (two accounts) or a friend.
- A server change reaches players after a redeploy (about 15 minutes of the user's time; the
  world is down two minutes). A client change reaches them only through a new export and a new
  zip sent to testers.
- The acceptance test for the current phase is a session: two friends, three hours, and it is
  also the opening act of the final phase.

---

## Part 2 — Ask the planner before building (use AskUserQuestion)

1. **Unit size.** Half-days, days, or week buckets? ("Molecular" suggests the smallest unit that
   can be verified: one checklist sitting, one build step, one redeploy, one friend session.)
2. **Horizon.** Only to 11-08, or the phase 5 work after it as well?
3. **Format.** A new section in `schedule.html`; a separate detail page next to it; a published
   page she can open from a link (the Artifact tool makes a private claude.ai page); or a
   spreadsheet she can edit herself. Offer these four; recommend the first unless she edits.
4. **Columns.** For each unit: what, who (user at a desk / user on the phone / Claude unattended
   / testers / friends), what it needs (redeploy, export, second seat, a decision), how long,
   what it waits on, and "done when" (the checklist name). Confirm this is the detail she wants.
5. **Keeping it current.** Who updates it and when (after each session note? weekly?). This
   matters more than the first draft; the 09-09 audit exists because nobody had an answer.
6. **Tentative work.** Show the unapproved spell batch and the undecided items, marked as such,
   or only approved work?

---

## Part 3 — Constraints (not optional)

- **One home per fact.** The detail schedule carries dates, sequence, owner and dependencies.
  It must not carry status. Every row names its To-Do entry or checklist so a reader can look
  the status up there, and the page says this rule out loud. If you find yourself writing a
  tick mark, stop.
- **Generated beats hand-synced.** If the format allows, produce the inventory with a script
  (a small Python or GDScript tool in `tools/`, like the existing `tools/export_items_oneshot.py`
  and `tools/check_spell_lockstep.gd`) that reads the To-Do and the checklists, so a rerun
  refreshes the counts. At minimum stamp a "last reconciled" date and give the planner a
  three-line reconcile procedure.
- **Estimates from evidence only.** Velocity from `schedule.md` §1 and the session-note dates;
  build sizes from the plan file; checklist sittings from row counts (a sitting of 15 to 20
  rows has taken one to two hours in this project). Mark every assumption as one.
- **Canonical stays canonical.** If you change `schedule.md`, change `schedule.html` in the
  same pass, or make the detail its own md/html pair with the same rule written into both.
- **Plain words for a non-engineer.** No em-dashes, no arrows in prose (user preference; the
  checklist row format is the one exception). Spell out what a redeploy or an export is once.
- **Verify every row** against the To-Do and git before it goes in. A row that says "built"
  when the To-Do says "pending playtest" is the drift this project has been burned by.
- No code changes, nothing ticked, nothing deployed. Docs only.

---

## Part 4 — A recommended shape (change it if the planner wants otherwise)

**Five lanes, week by week to 11-08**, each unit a row with the columns from Part 2 question 4:
- **Build** (Claude; can run on away days).
- **Operate** (user at a desk: redeploy, export, zip to testers).
- **Verify** (user: checklist sittings; which need a second seat).
- **People** (friend onboarding, the two-friends/three-hours rehearsal, the 11-08 evening).
- **Decide** (open decisions with the date by which each blocks something).

**The inventory to lay out, as of 2026-10-05 evening:**
- Verify debt: 8 checklists, 123 rows (`ported_spells`, `inspect_range_gm_audit_ban`,
  `time_of_day`, `scale_readiness`, `tell_reply_and_inspect_click`,
  `xp_eligibility_and_pet_levels`, `full_bags_move`, `loc_command`), plus 7 pouch rows in
  `bagspace_groupbars` and single leftover rows in older ones. Two of the eight need a second
  seat for parts.
- Build queue, tentative: the six-step spell batch (0.5 + 0.5 + 1 + 0.5 + 1 + 1.5 days, plus a
  review pass and a checklist per step). Two findings in it are live bugs on the hosted server
  (mobs nukable from beyond their leash; charm apparently expiring at once), which argues for
  its step 0 going early.
- Trade window: deploy day (both sides), then its checklist.
- The phase 4 acceptance session, then onboarding the rest of the friends, then 11-08.
- Decisions pending: the spell batch approval; Aria of Dismay's slow strength; the three
  phase 5 plan questions; whether `docs/deployment/` stays untracked.
- Risks to show, from the schedule's own §5 plus this autumn: the user's away days (velocity
  pauses on the operate and verify lanes, not the build lane); the pile of unverified work
  (built is not done); a protocol bump day that strands any tester on an old client.

**Milestones to hang the weeks on** (propose dates by working back from 11-08 at the measured
pace, with slack): verification debt cleared; Bind and Gate live; trade live; the rehearsal
session; the door opens.

---

## Part 5 — How to do the work

1. Read, in this order: `CLAUDE.md` (Session workflow and the To-Do), `docs/schedule.md`,
   the structure of `docs/schedule.html` (grep for `<h2>`), `docs/design/spell_batch_plan_2026_10_05.md`,
   the last three weeks of `docs/session_notes/README.md`, and the two memory files on the
   schedule rule (`project_schedule_structure.md`) and the audit.
2. Count the checklist state (from `docs/playtest_notes/`):
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
3. Ask the Part 2 questions. Do not draft before the answers to 1, 3 and 5.
4. Build the inventory table and verify each row against the To-Do and `git log`.
5. Lay out the lanes week by week; check the total against the measured pace; add slack and
   say where it is.
6. Produce the deliverable in the agreed format. If it lives in the repo: commit, push, a
   session note (`docs/session_notes/session_YYYY_MM_DD.md`) and a row in the README index.
   If it is a published page, also note its link in the session note.
7. Write the "how this stays current" rule into the deliverable and into `schedule.md`'s
   "How this doc is tracked" section, so the next person knows.

---

## Context and conventions for the incoming session

- Two repos: this one (Godot client) and `F:\Projects\server` (Rust). Both on
  `fix/xp-leveling-overflow`; the hosted server deploys from that branch on GitHub.
- The user wants terse replies and no end-of-task recaps. He is the only operator and tester
  most days; the planner reads the HTML.
- The To-Do is the one checkbox list. Do not add status to the schedule. Do not tick anything.
- Current state when this was written: server `c0046af` deployed 2026-10-05; client exported
  the same day from `fc880df`; the spell batch plan proposed and not approved; 32 checklists
  with open rows.
