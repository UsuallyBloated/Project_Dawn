# Phase 1 Durability Playtest Checklist — 2026-10-23

The housekeeping audit's Phase 1 (`docs/security/housekeeping_audit_2026_10_23.md`, M1 M2 M3
M8): a `systemctl stop` or `restart` now saves everyone and tells them before closing; a
logout whose save fails is retried instead of dropped; XP is saved together with the corpse,
quest turn-in or resurrection that changed it; a world loop that fails ends the process.
**Prerequisite: the R720 redeployed to `fix/xp-leveling-overflow` at `6c2bc45` or later**
(boot line `dev_cmds=false` and the new `build=`). Server only: no export needed.

> **This redeploy itself is NOT clean.** The service being stopped is still the OLD binary,
> which has no clean shutdown, so ask everyone to log out before this one deploy. Every stop
> after it is clean.

Diagnostics: the journal (`journalctl -u projectdawn -n 40 --no-pager`). A clean stop logs
`stop signal received`, `stop signal: saving everyone and closing the world` and
`world closed saved=N unsaved=0`; a failed save logs `shutdown save incomplete` and the
service shows a non-zero exit.

## Setup
- [ ] R720 redeployed with everyone logged out; boot line checked (`dev_cmds=false`, new
  `build=`). notes:
- [ ] Two players online (two-boxing works). notes:

## 1 — A restart saves everyone and says so
- [ ] **Player A walks somewhere new and buys or loots an item; within a minute, run
  `sudo systemctl restart projectdawn`** → both players see "The world is being restarted.
  Your progress has been saved; please log in again in a minute." notes:
- [ ] **Both log back in** → A stands where they were and holds the item; B is where they
  were. notes:
- [ ] **Read the journal** → `world closed saved=2 unsaved=0` (or the count online), then a
  clean start. notes:

## 2 — XP is saved with what changed it
- [ ] **A character level 6 or higher dies, and within a minute the server is restarted** →
  after relogging the character is still at the lower XP (the death's loss did not come back).
  notes:
- [ ] **Turn in a quest, then restart within a minute** → after relogging the quest's XP is
  still there and the quest is still done. notes:
- [ ] **A Cleric resurrects a corpse, the owner accepts, then restart within a minute** →
  after relogging the refunded XP is still there. notes:

## 3 — Regression: ordinary play unchanged
- [ ] **Log out and back in normally** → everything as left, and the relogin is immediate.
  notes:
- [ ] **Play a few minutes with kills, loot, a bank trip** → nothing odd; no
  `logout save incomplete` or `shutdown save incomplete` lines in the journal. notes:

> Not reproducible by hand, covered by tests instead: a logout whose save fails waits in a
> retry queue and its relogin is refused ("Your last session is still being saved") until it
> lands (`a_failed_logout_save_holds_the_relogin_until_it_lands`); a failing world loop now
> ends the process so systemd restarts it.

## 4 — Local dev box (optional)
- [ ] **Run `.\scripts\run-server.ps1`, log in, then close the PowerShell window** → the log
  (`logs/server_<timestamp>.log`) ends with `world closed`. notes:

## Notes / observations
-
