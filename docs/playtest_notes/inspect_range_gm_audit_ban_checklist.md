# Inspect Range, GM Audit Log, Ban Tool and Charm Range Playtest Checklist — 2026-10-01

Four server-side changes from the 2026-10-01 away-day batch (server `3523bd1`, `b47aadb`,
`81150c7`, review fixes `30f0474`; client `cd9f1d1`). **Restart the R720 on the new build.** The
only client change is the tidy `/inspect` range line, which rides the next export; everything
else can be tested on the build testers already have.

| Thing | Value | Where |
|---|---|---|
| `/inspect` range | 20 m on the client, 30 m server backstop | `hud.gd`, `world/mod.rs` |
| Audit log | one row per authorized dev command, read with `admin_report` | `gm_actions` table |
| Dev command budget | burst of 128, then 8 a second; over it the command is REFUSED | `connection.rs` |
| Ban tool | `admin_account ban <username> [reason]` / `unban <username>` | server repo |
| Charm range | 25 m, the same reach as a nuke | `RANGED_ATTACK_RANGE` |

Diagnostics: `admin_report` for the audit log (console section "GM actions", or the card at the
bottom of `world_report.html`); `server.log` anchors `banned account refused at world connect`,
`PET_CHARM dropped — out of range`. The ops tools must be run from the directory that holds
`world.db` (on the R720 that is `/opt/projectdawn`, not the source tree), or with
`PROJECTDAWN_DATABASE_URL` set.

## Setup
- [ ] Restart the R720 on the new build (`journalctl -u projectdawn -n 20` shows the new `build=` sha and `dev_cmds=false`)
- [ ] A GM account logged in; for §1 and §4 a second character (two-boxing is fine)

> **Known gotcha:** on a build exported before `cd9f1d1`, a too-far `/inspect` shows the server's
> line "That player is not close enough to inspect." and the window reads "(target not in
> world)". That is the server gate working through an older client, not a failure.

## 1 — /inspect has a range now (two seats)
- [ ] **Stand next to the other character, target them, `/inspect`** → the window opens with their name and worn gear, as before. notes:
- [ ] **Move more than ~30 m apart, target them, `/inspect`** → a "too far" line in chat and no gear shown. notes:
- [ ] **Walk back within range and `/inspect` again** → works again. notes:

## 2 — The GM audit log
What this proves: every dev command an authorized account issues is written down.

- [ ] **As the GM: `/give Bread Loaf 1`, Test Panel Full Heal, spawn one mob, grant coins once** → all four work as before. notes:
- [ ] **Run `admin_report` and read the "GM actions" section** → four rows, newest first, your account and character named, commands `give` / `heal_self` / `dev_spawn_mob` / `give_coins`, and every row ends `via=gm`. Paste them here. notes:
- [ ] **Confirm no row says `dev`** (`via=dev` or `via=gm+dev`) → none; if one does, the server was started with `PD_DEV_CMDS` on and every player has dev tools. notes:
- [ ] **Test Panel "give crafting materials" (about 34 items at once)** → the items arrive as before (bag space allowing), and `admin_report` shows one `give` row per item, no `audit_overflow` row. notes:
- [ ] **From a NON-GM character, click Full Heal on the Test Panel if you can reach it, or `/heal 50`** → nothing happens server-side and `admin_report` shows no row for that account. notes:

## 3 — Banning an account
Use a throwaway account, not your own.

- [ ] **`admin_account` with no arguments** → every account listed with flags, characters and live sessions. notes:
- [ ] **With the throwaway logged OUT: `admin_account ban <name> testing the ban tool`, then try to log in as it** → login is refused and the reason "testing the ban tool" is shown. notes:
- [ ] **`admin_account` again** → the account shows `[BANNED]` with its reason. notes:
- [ ] **`admin_account unban <name>`, then log in** → login works again. notes:
- [ ] **Ban it WHILE its character is in the world** → the character keeps playing (expected: there is no kick yet). Log it out and try to come back → refused. notes:
- [ ] **From the wrong directory (for example the source tree on the R720), run `admin_account`** → an error about opening the database, and no new `world.db` file appears there. notes:

## 4 — Charm has a range now (an Enchanter, level 20 or higher)
- [ ] **Charm a mob at normal casting distance** → it becomes your pet, as before. notes:
- [ ] **Target a mob, back away past ~25 m (well beyond where a nuke would reach), cast Charm** → "That target is too far away." and the mana comes back. notes:

## 5 — Regression: dev tools still work for a GM
- [ ] **Level Up, Grant 250 XP, Spawn Named, give-coins, `/give`, `/heal`, `/damage`** → each works on the first click, no rate-limit line. notes:
- [ ] **Click a dev button rapidly for a few seconds (ordinary impatient clicking)** → no "rate limited" line; it takes a script to reach the budget. notes:

## Notes / observations
-
