# Inspect Range, GM Audit Log, Ban Tool and Spell Reach Playtest Checklist — 2026-10-02

Server-side changes from the 2026-10-01 and 10-02 away-day batches (server `3523bd1`, `b47aadb`,
`81150c7`, `30f0474`, then `fe0e789`, `9b0bf87`, `8e662d6`; client `cd9f1d1`, `228db25`).
**Restart the R720 on the new build.** The client changes (a tidy `/inspect` range line, a spell
range check before the cast bar, and the cooldown handed back on a refused cast) ride the next
export; rows that need the new export say so, everything else works on the build testers have.

| Thing | Value | Where |
|---|---|---|
| `/inspect` range | 20 m on the client, 30 m server backstop | `hud.gd`, `world/mod.rs` |
| Audit log | one row per authorized dev command, read with `admin_report` | `gm_actions` table |
| Dev command budget | burst of 128, then 8 a second; over it the command is REFUSED | `connection.rs` |
| Ban tool | `admin_account ban <username> [reason]` / `unban <username>` | server repo |
| Ban reaching a live session | within about 10 seconds, no restart | the world loop's ban sweep |
| Spell reach | 25 m for every targeted spell: nukes, heals, buffs, Charm | `RANGED_ATTACK_RANGE` |
| A refused cast | costs no mana and burns no cooldown | `cast_target_refusal` |

Diagnostics: `admin_report` for the audit log (console section "GM actions", or the card at the
bottom of `world_report.html`); `server.log` anchors `banned account refused at world connect`,
`banned account kicked from the world`, `CastSpell refused — target pre-flight`. The ops tools
must be run from the directory that holds `world.db` (on the R720 that is `/opt/projectdawn`,
not the source tree), or with `PROJECTDAWN_DATABASE_URL` set.

## Setup
- [ ] Restart the R720 on the new build (`journalctl -u projectdawn -n 20` shows the new `build=` sha and `dev_cmds=false`)
- [ ] A GM account logged in; for §1, §3 and §4 a second character (two-boxing is fine)

> **Known gotcha:** on a build exported before `cd9f1d1`, a too-far `/inspect` shows the server's
> line "That player is not close enough to inspect." and the window reads "(target not in
> world)". That is the server gate working through an older client, not a failure.
>
> **Known gotcha:** on a build exported before `228db25`, a cast at a far target runs its whole
> cast bar, then prints "Cast failed: That target is too far away or no longer here.", and the
> spell's button shows its cooldown even though the server charged none. The new export checks
> the range first and gives the cooldown back.

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
- [ ] **Ban it WHILE its character is in the world** → within about ten seconds that client is kicked with "This account is banned."; `server.log` shows `banned account kicked from the world`. No restart. notes:
- [ ] **Watch the kicked character from the other seat** → it stands where it was for about 30 seconds (the ordinary linkdead linger), then vanishes. notes:
- [ ] **Try to log the banned account back in** → refused with the reason. notes:
- [ ] **From the wrong directory (for example the source tree on the R720), run `admin_account`** → an error about opening the database, and no new `world.db` file appears there. notes:

## 4 — Spells have a reach now
Every targeted spell needs its target within 25 m. Before this, heals and buffs worked on anyone
anywhere, and a PvP nuke reached across the world.

- [ ] **Heal or buff a group-mate standing next to you** → lands as before. notes:
- [ ] **Target the same group-mate from well over 25 m (the group window still lets you target them) and cast the heal** → refused, they are NOT healed, and your mana is unchanged. notes:
- [ ] **(New export) The same far heal** → "Your target is too far away." appears at once and the cast bar never starts. notes:
- [ ] **Right after a refused cast of a spell that has a cooldown, walk into range and cast it again** → it casts; the refused attempt did not put it on cooldown. (Needs the new export for the button to agree; on an older build the button still shows a cooldown.) notes:
- [ ] **An Enchanter casts Charm on a mob at normal distance** → it becomes your pet, as before. notes:
- [ ] **Charm a mob from beyond ~25 m** → refused, mana unchanged. notes:
- [ ] **Two seats, both `/pvp on`, more than 25 m apart: nuke the other player** → refused, they take no damage. Step within range → the nuke lands as before. notes:
- [ ] **Cast Bind Affinity** → "That magic has no effect here yet." and your mana does NOT move (it used to drop and come back). notes:
- [ ] **A Cleric casts a resurrection with a non-corpse targeted, or from too far away** → refused with the reason, and the mana is unchanged. notes:

## 5 — Regression: dev tools still work for a GM
- [ ] **Level Up, Grant 250 XP, Spawn Named, give-coins, `/give`, `/heal`, `/damage`** → each works on the first click, no rate-limit line. notes:
- [ ] **Click a dev button rapidly for a few seconds (ordinary impatient clicking)** → no "rate limited" line; it takes a script to reach the budget. notes:

## 6 — One leftover from the quest rewards
- [ ] **Equip the Hunter's Medal (the rotfang_hunt reward, a NECK item)** → STR +2 and CON +2 show on the character window, and unequipping removes them. (The ring's AGI and other slots' STR/CON passed in `gear_stat_display_checklist.md`; this is the one slot never eyeballed.) notes:

## Notes / observations
-
