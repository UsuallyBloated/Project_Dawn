# The Overnight Builds of 2026-11-01 Playtest Checklist — 2026-11-01

Three builds from the night of 11-01, the housekeeping audit's last big pieces. **§1 needs only
the next redeploy** of the deploy branch (server `d4f1a2a` or later): the `world health` log
line. **§2 and §3 wait for the next bump day**, when `feat/facing` merges and then the two
refactor branches merge after it: the server's `refactor/tick-split` (the world loop split
into one module per step; nothing should behave differently) and the client's
`refactor/remove-offline-code` (the offline game removed; the client is online-only). §2 is
a regression sweep of ordinary play, since a split that changes nothing has nothing new to
show; §3 is what the client removal changes on screen.

| Thing | Where | Notes |
|---|---|---|
| The `world health` line | `journalctl -u projectdawn \| grep "world health"` | once a minute while anyone is in the world: `ticks` (about 1,200), `p50_ms`, `p99_ms`, `max_ms`, `over_budget` (ticks past 50 ms), `checkpoint_max_ms` |
| A script error on the client | the in-game console (backtick) | red lines; there should be none all evening |

## Setup
- [ ] §1: the R720 at the deploy branch's newest build (boot line `build=`, `dev_cmds=false`). notes:
- [ ] §2 and §3: the bump-day redeploy and the export from the merged branches (the login screen's build stamp). notes:
- [ ] Two seats for the group rows (two-boxing works); a GM account for the Test Panel rows. notes:

## 1 — The world health line (one seat, after the redeploy)
- [x] **Log in and play for three minutes** → three `world health` lines, about 1,200 `ticks` each, `over_budget=0` (or a handful), `players_in_world=1`. notes:
- [x] **Stay online past a 60 s checkpoint** → one line shows `checkpoints=1` and a `checkpoint_max_ms` (a few milliseconds). notes:
- [x] **Log out and wait two minutes** → no `world health` line while nobody is online. notes:

## 2 — Ordinary play on the split server (after the bump)
> [Claude, 11-02: the marks below were run on the pre-bump builds, the R720 at `d4f1a2a` (the
> deploy branch, without the split) and a client exported from `feat/facing` at `f2ed345`
> (without the offline removal), so they are a regression check of those builds, not of the
> split. With the user's go, the marks stay as written; §2 and §3 are run again after the bump
> day, on the merged server and the export from it. The journal over the 11-02 sitting has no
> `ERROR` line and no panic (`grep -E "ERROR|panic"` from the 16:24 boot). The turning note is
> expected: facing reaches the server on the bump day.]
- [x] **Two seats enter the world** → each sees the other, moves and turns. notes: Characters do NOT see eachother turn/spin.
- [x] **Melee a camp mob to death, loot the corpse** → swings land, the kill pays XP, the loot window takes items. notes:
- [x] **Cast a heal and a nuke; let one fizzle or get interrupted** → mana and lines as before. notes:
- [x] **Group the two seats, kill a mob** → the XP share and the group panel bars. notes:
- [x] **Buy from Brom, sell to him, deposit at the bank and withdraw** → coins and items move as before. notes:
- [x] **Trade an item between the seats** → the commit lands on both. notes:
- [x] **Die, respawn, loot the corpse** → gear goes back on. notes:
- [x] **/camp one seat, close the other with the window X** → the camp logs out; the other lingers about 30 s, as before. notes:
- [x] **The journal over the sitting** → no `ERROR` line and no panic. notes:  I forgot to start the log.  Let me know how to handle this.

## 3 — The client without the offline game (after the export)
> [Claude, 11-02: run on the `feat/facing` export (`f2ed345`), which still carries the offline
> code; the bag window's Destroy button is that build's, and the removal branch deletes it.
> These rows are run again on the bump-day export. The levels note is filed in the To-Do (UI
> polish, "Other players' levels"); the Healing Light note waits on a screenshot (both sides list
> it at 10 mana and nothing on the client changes the cost).]
- [x] **The login screen** → no Offline button. notes:
- [x] **The lobby** → the character list and Enter World only (no Solo, Host, Join, Test Room, Test Dungeon or Delete Save). Create a character from it as usual. notes:
- [x] **Grouped with the second seat, look at the group panel** → your own row is marked as you on both seats, and the leader sees the kick and leadership controls on the other member's row, not their own (online both used to key on whichever member had character id 1). notes:  We cant currently see eachother's levels in game.  But you probably already know that.
- [x] **A pet class: summon a pet, attack a mob, watch the console** → the pet fights; no red line on each hit (online it used to error on every mob hit). notes:
- [x] **The Test Panel (GM): Spawn Normal, Spawn Named, Despawn All, a GEAR give, Give 1,000 Copper, a faction slider, Take 20 dmg, Full Heal, Trigger Death** → each works as before. The removed buttons (the CHARACTER section, STATS OVERRIDE, ZONE TRAVEL, God Mode, No Cooldowns, Clear All Buffs) are gone. notes:
- [x] **Open a bag window** → no Destroy button in it; destroying still works by holding the item over the inventory's trash cell. notes:  Destroy button still visible in the bag, destroy button doesnt work.
- [x] **Eat by hand, drink by hand, sit to regen, sing a song (a Bard)** → all as before; the regen and buff bars follow the server. notes:
- [x] **/dismount** → not a command any more (nothing can be mounted online). notes:
- [x] **The console over the whole sitting** → no red script error. notes: Not that i saw.

## Notes / observations
- Mana Cost of Healing Light cost reduced from 10 to 8.
