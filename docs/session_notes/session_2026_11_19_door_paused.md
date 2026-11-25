# Session 2026-11-19 (evening): the door's date is paused

The door was set for tonight. The user: "its not happening tonight. People are busy. lets pause
on securing a date for now." So the friends' first evening has no date, and nothing else
changes: the R720 keeps running `87c58fe`, the zip to send stays
`builds/ProjectDawn-alpha-a1a154e.zip` (obstacle collision and group levels), and the branches
held for the bump after the door (`feat/command-confirm` in both repos, the `feat/gm-flight`
client) stay held until the user says whether that bump goes out now. The UI themes were merged
into the deploy branch earlier today and are not in any zip yet.

## Records

- `docs/schedule.md`: the header's target, the time-box line, the phase 5 heading, and §7's
  phase 5 row (which also named the old zip, `919671b`; it now names `a1a154e`).
- `docs/schedule.html`: the Target and Status stats, the timeline paragraph, phase 05's dates,
  and the "this document expires" line.
- `CLAUDE.md`: the "Current plan" pointer.
- The planner: `tools/schedule_detail.py` learned a paused door. `target_paused` in the plan's
  meta shows "Paused" in place of the target; `paused = true` on a milestone shows "Date
  paused"; `by_paused = true` on a decision shows "Before the door". The dates stay in the file
  for ordering only. Milestone m5, rows o8 and p5, and decisions d7, d10 and d11 carry them;
  week w7's summary says what happened. When a date is chosen, set `target` and the dates and
  remove the three flags. Regenerated and republished.
- Memory: the schedule structure and planner notes, and the zip note.
