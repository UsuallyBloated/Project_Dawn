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
- [ ] A character of level 5 or higher (below the floor there is no XP penalty to double). notes:

## 1 — Leaving dead
- [ ] **Die to a mob, note the XP and level, then close the game with the window X while still dead** → the body lingers and reaps; nothing else happens. notes:
- [ ] **Log back in** → you arrive dead where you were (the death UI, the Respawn button), with the SAME XP and level as noted; `server.log` shows no second `server-detected player death` for the relogin. notes:
- [ ] **Look around the spawn after respawning** → one corpse, at the place you died; no second empty one at the spawn. notes:
- [ ] **Respawn, loot your corpse** → everything returns as before (the fix touches only the relogin). notes:

## 2 — Reliable resend (needs a lossy link; otherwise `[-]` with a note)
- [ ] **Over a connection with real packet loss (a phone hotspot, or a deliberately throttled Wi-Fi), play for ten minutes with heavy inventory dragging and chat** → no inventory desync and no missing chat lines; before the fix a lost delta stayed lost until relog. notes:

## Notes / observations
-
