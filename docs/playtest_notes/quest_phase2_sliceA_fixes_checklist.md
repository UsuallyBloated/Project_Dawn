# Quest Phase 2 Slice A — Fix Verify Checklist — 2026-07-10

Quick re-test of the four follow-ups from the 07-10 playtest. **No wire change this round**
(server-reorder + GDScript only), so **no DLL rebuild** — just re-export the client and restart
the server. Everything else from slice A is unchanged and already passed.

## Setup
- [x] Re-export / reload Project_Dawn in Godot
- [x] Restart server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` (pipe to `Tee-Object server.log`)
- [x] One character, `wolf_threat` acceptable from Aldric (or use test_q1 via Test Panel)

> Tip: the XP-wording fix depends on the server sending `QuestCompleted` just before the reward
> `XpGained`. If the line ever reads "party/plain experience" on a quest turn-in, that ordering
> broke — note it.

## 1 — "Quest experience" wording (was "party experience")
- [x] **Accept wolf_threat, kill 5 wolves, turn in at Aldric** → the XP line reads
  **"You gained 300 quest experience!"** (NOT "party experience", NOT plain "experience"). notes:
- [x] **Repeat while in a group** (the case that showed "party experience" before) → still reads
  "quest experience". notes:

## 2 — Completed quest shows full counts after relog (was "0 / 5")
- [x] **Complete a quest, then log out and back in** → open the journal, Completed tab, select
  the quest → its objective row reads **"Kill wolves near Valdis: 5 / 5"** with the check, not
  "0 / 5". notes:

## 3 — Re-completing a done quest gives feedback (was silent)
- [x] **After completing test_q1, click "Complete Test Quest" again** → combat log shows
  **"You have already completed …"** (previously nothing happened). notes:
- [x] **Relog, re-add test quest, click Complete Test Quest again** → still shows the
  already-completed line (this is the completed-id-only path). notes:

## 4 — Regression: normal completion still clean
- [x] **A fresh quest completes end to end** → "Quest complete: X!" + the XP line, quest moves
  to the Completed tab, no double lines or missing XP. notes:
- [x] **Turn-in-not-ready still rejects** (turn in before finishing) → visible "objectives are
  not complete" line, no XP. notes: 

## Notes / observations
-
