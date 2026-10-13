# Camp + Linkdead Playtest Checklist — 2026-06-20

> **Triage 2026-10-12** (the planner's week-5 chore, done early): built and verified 2026-06-20 (session_2026_06_19_camp_linkdead.md: "Playtest 2026-06-20: works"; systems_overview.md, Camp) but never ticked here; the two setup rows retired, 13 rows superseded by that verification, rows 38-40 (the unclean-kill relogin refusal) worth a re-run because the To-Do item "Unclean-kill relogin was not refused" says the evidence contradicts itself.
> Rows flipped to `[-]` below carry the verdict and the reason after their `notes:`; the
> rows still open are the re-run: 38, 39, 40 (line numbers as of the triage).

Verifies the EverQuest logout model (`docs/design/camp_and_linkdead.md`), both slices:
**linkdead** (involuntary, slice A) and **`/camp`** (voluntary, slice B). Wire is **PD_W0017**.

**Build prerequisite (both repos):** rebuild the gdext DLL (`addons/gdext_net/build.ps1`) and
restart the server on the new protocol, or client↔server will refuse to connect.

| Trigger | Result | Window |
|---|---|---|
| Window **X button** | hard self-kill → **linkdead** (vulnerable, relogin refused) | ~30 s after detection |
| **Quit Game** (Options) | clean logout, account freed at once | instant |
| **`/camp`** (seated, uninterrupted) | clean logout (exits to desktop, like Quit Game) | 30 s |

Diagnostics: in-game console (backtick) for client state; `server.log` anchors — `client linkdead`,
`linkdead window elapsed — reaping`, `camp window elapsed — client logs out`, `duplicate login refused`.

## Setup
- [-] Rebuild gdext DLL + restart server (release, `PD_DEV_CMDS=1`) triage 2026-10-12: RETIRED, a build step.
- [-] Two clients on one machine (A and B), both in-world, near a mob for the damage rows triage 2026-10-12: RETIRED, a build step.

> **Known gotcha:** the window **X** is now a *crash* (linkdead), not a clean logout. Use **Quit Game**
> in Options to leave cleanly. X kills only that one client window; the other keeps running.

## 1 — `/camp` happy path
- [-] **Stand, type `/camp`** → rejected: "You must be sitting to camp.", no countdown. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **`/sit` (or sit toggle), then `/camp`** → amber "Making camp... 30" appears and counts down. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **Wait the full 30 s seated, untouched** → at 0 you log out cleanly (game exits to desktop). notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **Relaunch + relog immediately** → succeeds (account was freed at once). notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.

## 2 — `/camp` cancellation
- [-] **`/sit`, `/camp`, then move (WASD)** → countdown cancels immediately, label hides, you stay in-world. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **`/sit`, `/camp`, then stand** → cancels, you stay. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **`/sit`, `/camp`, let a mob hit you** → cancels on the hit, you stay. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **`/sit`, `/camp`, then `/camp cancel`** → countdown clears, you stay. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.

## 3 — Linkdead (involuntary, slice A regression)
- [ ] **Hard-kill A via the window X** → A's body lingers ~30 s; B (or a mob) can still damage/kill it. notes:
- [ ] **Try to relog A during the window** → refused: "You already have a character in this world." + a "try again in ~Ns" estimate. notes:
- [ ] **Wait out the window** → A's body reaps; relog A → succeeds. notes:

## 4 — Edge / interaction
- [-] **`/camp` to ~3 s left, then take a single mob hit** → cancels (no last-second sneak-out). notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **Camp while a pet is out** → camp behaves normally; nothing odd with the pet on logout. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **Die while seated mid-camp** (let a mob finish you) → camp aborts; no phantom logout 30 s later. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.

## 5 — Regression: clean logout unchanged
- [-] **Quit Game (Options)** → still an instant clean logout; relog at once. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.
- [-] **Normal combat / sit / stand** with no `/camp` in play → unchanged. notes: triage 2026-10-12: SUPERSEDED, camp verified in play 2026-06-20 and documented built in systems_overview.md.

## Notes / observations
-
