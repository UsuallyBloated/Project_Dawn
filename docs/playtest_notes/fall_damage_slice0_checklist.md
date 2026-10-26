# Fall Damage Slice 0 Playtest Checklist (2026-10-24)

The instant-death message (`DeathBroadcast`) is a GM command now: a modified client can no longer
kill itself on demand for a free trip home and a hate wipe (housekeeping audit B1). Online, a
fall no longer pretends to hurt you: it never did for ordinary players (the server ignored it),
and the server will judge falls itself once it has hills (`docs/design/server_fall_damage.md`).

Two halves, each verifiable on its own:
- **Server** (`779a033` on the deploy branch): needs the next R720 redeploy. Works with the
  client testers already have.
- **Client** (on `feat/server-speed`): needs the Oct 22 export.

Diagnostics: `cargo run -p projectdawn-server --bin admin_report` (from `/opt/projectdawn` on the
R720) lists the newest GM action rows; a GM's Trigger Death writes one `death_broadcast` row on
the server build, one `damage_self` row on the new client.

## Setup
- [x] R720 redeployed with the server half; boot line shows `dev_cmds=false` and the new `build=`. notes:
- [x] A GM account and a plain account available. notes:

## 1 — Server half (any client)
- [x] **GM: Test Panel, Trigger Death** → you die, leave a corpse, respawn as usual; the admin
  report shows one GM row for it. notes:
- [x] **Plain account: get killed by a mob** → an ordinary death (corpse, respawn, XP loss above
  level 5), and no new GM row appears for it. notes:
- [x] **GM: get killed by a mob** → an ordinary death, and no GM row for it (only Trigger Death
  writes one). notes:

## 2 — Client half (the Oct 22 export)
- [-] **Jump off the highest thing you can find** → no "You hit the ground hard" line, no
  damage number, HP unchanged (true for GM and plain accounts alike). notes:  We dont currently have a high point.  Can we make a tool that flings the character up in the air, then they will fall and incure fall damage. **Skipped (2026-10-26): no high point online; the probe covers it** (`tools/probe_fall_and_death_online.gd`: an online hard landing prints no fall-damage line, and it fails on the previous code). A fling tool waits for slice 1: once the server simulates falls it must be a server-side GM command, since a client-side one would test nothing the probe does not.
- [x] **GM: Test Panel, Trigger Death** → still kills you; the admin report shows a
  `damage_self` row this time. notes:  Trigger Death still works
- [x] **Die to a mob, wait out the respawn** → respawn at your bind point as before. notes:
