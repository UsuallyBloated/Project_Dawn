# Playtest Checklist Template

This is the **canonical format for playtest checklists** in Project Dawn. Copy this file to
`docs/playtest_notes/<feature>_checklist.md` and fill it in. The tester (the user) runs it
two-client and edits in place — flipping `[ ]` to `[x]` (pass) or `[-]` (blocked/skipped)
and appending findings after each `notes:`. The granular per-row `notes:` hooks are the
point: they carry the exact signal that lets us triage from `server.log` afterward (e.g.
"doesn't land" + a log line = the real cause).

Keep that structure when authoring a new one; delete this how-to header and the
`<angle-bracket>` placeholders in the copy.

---

# <Feature> Playtest Checklist — <YYYY-MM-DD>

One or two lines on what changed and what this verifies. **State any build prerequisite up
front** (e.g. re-export Project_Dawn + restart the server) — most checklists need both
repos rebuilt.

<Optional reference table — the data under test, so the tester doesn't hunt for it:>

| Thing | Effect | Who/Where | Notes |
|---|---|---|---|
| … | … | … | … |

Tip: name the diagnostics. In-game console (F2 / backtick) for client state; the relevant
`server.log` anchor(s) to grep for (e.g. `"ALLY buff applied"`), so a "didn't work" result
can be split client-vs-server fast.

## Setup
- [ ] Re-export Project_Dawn
- [ ] Restart server (release build)
- [ ] <preconditions: clients logged in, group formed, flags set, etc.>

> **Known gotcha (optional blockquote):** call out anything that produced a false-alarm
> result before (e.g. "regen is off — top mana up via Test Panel → Full Heal, or casts
> silently fail"). Saves a wasted round.

## 1 — <Section: the headline behavior>
Optional one-line framing of what this section proves / what it used to do.

- [ ] **<Action>** → <expected, observable result>. notes:
- [ ] **<Action>** → <expected result>. notes:

## 2 — <Next section>
- [ ] **<Action>** → <expected result>. notes:

<…more numbered sections: edge cases, fallbacks, expiry/cleanup, third-party view, gates,
regression that nearby behavior is unchanged…>

## N — Regression: <nearby behavior unchanged>
- [ ] <thing that should still work the same> → <expected>. notes:

## Notes / observations
-
