# Dead Relogin + Reliable Resend Playtest Checklist — next redeploy

Two pre-existing server bugs found by the 2026-10-12 review of the hosting branch and fixed
on the deploy branch (server `6a09aa1`): a character that left while dead died AGAIN on its
first tick back (a second XP penalty, a second empty corpse), and renet's own update was
never called, so a lost reliable packet (an inventory delta, a chat line, a kick) was never
resent. Needs a redeploy with `645606a` or later (`6a09aa1` carried the renet call twice;
`645606a` once); no client change.

| Thing | Where | Notes |
|---|---|---|
| The death line | `server.log`: `server-detected player death` | must appear ONCE per death, never on a relogin |
| XP before and after | `/version` is not it; the character sheet, or `admin_report` | the number to compare across the relogin |
| Corpses | the world: one body per death | a second, empty corpse at the spawn is the old bug |

## Setup
- [ ] Server on the R720 from `645606a` or later (boot line `build=`). notes:
- [x] A character of level 5 or higher (below the floor there is no XP penalty to double). notes:

## 1 — Leaving dead
- [x] **Die to a mob, note the XP and level, then close the game with the window X while still dead** → the body lingers and reaps; nothing else happens. notes:
- [x] **Log back in** → you arrive dead where you were (the death UI, the Respawn button), with the SAME XP and level as noted; `server.log` shows no second `server-detected player death` for the relogin. notes: Uh oh, we found something!  When I logged back in as Bun the character is standing in the middle of "Bun's corpse" and cant move from this location. (Claude: the third bug, fixed in `3f09fbd`, §4. The relogin itself passed: one death line and one corpse in the journal.)
- [x] **Look around the spawn after respawning** → one corpse, at the place you died; no second empty one at the spawn. notes:
- [x] **Respawn, loot your corpse** → everything returns as before (the fix touches only the relogin). notes:  I cant respawn.  Bun is stuck. Trigger Death does not work. (Before the `3f09fbd` fix; passed after it, with this row and the one above ticked once Bun respawned and looted.)

## 2 — Reliable resend (needs a lossy link; otherwise `[-]` with a note)
- [-] **Over a connection with real packet loss (a phone hotspot, or a deliberately throttled Wi-Fi), play for ten minutes with heavy inventory dragging and chat** → no inventory desync and no missing chat lines; before the fix a lost delta stayed lost until relog. notes: I dont currently have access to this.

## 3 — A second Water Flask is refused (server `a9219b9`, the stopgap before the EQ food model)
- [-] **Drink a Water Flask, then right-click another while the first still runs** → "You're already drinking something." and the second flask stays in the bag (before: taken for nothing). notes: 
- [-] **Eat a Bread Loaf twice the same way** → "You're already eating something." (this one always worked; a regression row). notes: Current plan is to allow player to eat and drink at will for the sake of RP.  however the item is only as effective as the standard cool down,  so even though the player has consumed 7 waters in 1 second, the effect of the water does not compound.  This rule applies to food aswell.  (Superseded by the food and water system: both rows. The journal showed every bread and flask taken, as that system's rule says. The user confirmed its rule on 2026-10-26: each one adds half its size until the bar is full, then the explode line.)

## 4 — A dead login is told it is dead (server `3f09fbd`, client `4a93d6e`)
§1's relogin left Bun stuck: the server sends your own HP only when it changed, and a dead
character with full mana and stamina changes nothing, so the client never learned it was dead
(no death screen, no respawn) while the server refused every move, the loot and Trigger Death.
The server now always sends your HP, mana and stamina on entering the world. Separately, the
login printed "You were healed for 22 health.": the client's reset of the bars from a 100 HP
placeholder to the level's 122, cosmetic, and gone in the next export.
- [x] **After the redeploy (boot line `build="3f09fbd"` or later), log Bun in** → the death
  screen shows, and Bun respawns at the bind about 5 s later; then §1's last two rows (one
  corpse, loot it). notes: Boot line `build="3f09fbd" dev_cmds=false`; §1's last two rows passed
  on it (2026-10-26).
- [x] **Log in on the next export** → no "You were healed for N health." line at login; a real
  heal (a spell, a respawn) still prints one. notes:

## Notes / observations
-
