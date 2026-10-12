# Shared Sky (Server-Driven Time of Day) Playtest Checklist — 2026-10-04

Every player now sees the same time of day. The server owns the clock (a 20-minute day derived
from real time, so it does not reset when the server restarts); it tells each player the hour
as they enter the world and re-sends it once a minute. Before this, each client ran its own
clock that restarted at 8 AM whenever the game was launched.

**Needs both halves:** the R720 on server `e8164b1` or later, and a fresh client export that
carries the rebuilt `gdext_net.dll`. A client from before this build still connects and plays;
it just keeps its private sky.

Tip: the HUD clock is the readout. Server side, nothing is logged per send (it would be a line
a minute); the proof is two clients agreeing. If a new client shows
`Net: gdext_net.dll predates the world clock` in the console (backtick), the DLL beside the
exe is a stale one: copy the current `addons/gdext_net/gdext_net.dll` over it.

## Setup
- [x] Redeploy the server (boot line shows `build=` at `e8164b1` or later, `dev_cmds=false`) notes: (filled from the log) `d593609`, which contains `e8164b1`; `dev_cmds=false`.
- [x] Re-export Project_Dawn and confirm `[BuildStamp] stamped <sha>` notes: (filled from `builds/`) exported 2026-10-09 13:34.
- [x] Copy `addons/gdext_net/gdext_net.dll` into `builds/` beside the exe (this is a hand copy; the one in `builds/` today is from 09-25 and has no world clock in it) notes: (filled from `builds/`) the copy there is the 10-04 rebuild, same size as `addons/`; the §1 console row confirms it.
- [-] `/version` in game: note the DLL fingerprint in notes, so a tester's build can be compared later. notes: not recorded this sitting.

## 1 — The clock comes from the server
- [x] **Log in and read the HUD clock; quit the game completely, relaunch, log in again** → the clock has moved on by the real time that passed (20 real minutes is one game day, 50 real seconds is one game hour). It does NOT restart at 08:00. notes:
- [x] **Sit at the login screen for a few minutes before logging in** → on entering the world the sky is at the server's hour, however long the launcher was open. notes:
- [x] **Check the console after entering the world** → no `predates the world clock` line. notes:

## 2 — Two players share a sky (two seats)
- [x] **Launch the two clients a few minutes apart, log both in, compare HUD clocks** → the same time on both, to the minute. notes:
- [x] **Stand together through a dusk or a dawn** → both screens darken or brighten together. notes:
- [x] **Leave both logged in for 20 minutes (one full day)** → the clocks still agree at the end. notes:

## 3 — The sky moves smoothly
- [x] **Watch the sun and shadows for two or three minutes** → steady motion; no visible step once a minute when the server's hour arrives. notes:
- [x] **Restart the server while logged out, then log back in** → the clock carries on from real time; it is not back at a fixed hour. notes:

## 4 — Dev tools (GM account)
- [x] **Test Panel: tick Pause Cycle, then drag the time slider** → the sky follows the slider and stays where you put it. notes:
- [x] **Untick Pause Cycle** → within a minute the sky returns to the server's hour (a jump is expected here). notes:
- [x] **Drag the slider WITHOUT Pause ticked** → the sky changes, then returns to the server's hour within a minute. notes:

## 5 — Regression
- [x] **Play a race with night vision (ultravision or infravision) through a night** → the vision effect still comes and goes with the night as before. notes:
- [-] **An older client (the build testers have today) against the new server** → connects and plays normally; its sky is simply its own. notes:  Not worried about that.

## Notes / observations
- **Result 2026-10-09: PASS, every row.** Server `d593609` (restarted 20:18:12 for §3's
  restart row; the log shows both seats out before the stop and back in after). The old-client
  row was skipped by choice.
