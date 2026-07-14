# Disconnect-Flush Persistence Fix — Playtest Checklist — 2026-07-11

The clean-logout flush (`reap_connection`) now also saves **inventory, resources (HP/MP/
stamina/XP/level), and passive skills** — previously it only flushed coins/bank/quest/position,
so any of those three could roll back to the last 60s checkpoint if you logged out soon after
changing them. This is the fix for "unequip the ring, relog, and it's equipped again."

**Server-only change → rebuild + restart the server. NO client re-export, NO DLL rebuild.**
(The already-committed gear-stat client fix stays as-is.)

## Setup
- [x] Rebuild + restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` piped
      to `Tee-Object server.log`
- [x] One character in the world. **Key timing rule for every row below: do the action, then
      log out within a few seconds** (well under 60s) so you're testing the disconnect flush,
      not the periodic checkpoint.

## 1 — The reported bug: unequip survives a quick logout
- [x] **Equip the ring, then unequip it, then log out immediately and back in** → the ring is
      **still in your bag, NOT equipped**. (Before: it came back equipped.) notes:
- [x] **Equip something, log out immediately, relog** → it's **still equipped** (the equip also
      persists — this direction should already have worked, confirm it still does). notes:

## 2 — Inventory changes survive a quick logout
- [x] **Loot an item, log out within a few seconds, relog** → the looted item is still there. notes:
- [x] **Move items between slots / into a bag, quick logout, relog** → the new layout persists. notes:
- [x] **Drop an item, quick logout, relog** → it's still gone (drop persists). notes: Item remained on ground, in server.

## 3 — Resources (XP / level) survive a quick logout
- [x] **Kill a few mobs for XP** (watch the bar move), **log out within a few seconds, relog**
      → your XP is at the post-kill value, not rolled back. notes:  When player logs back in XP bar appears as 0/X.  after killing an enemy the player's XP bar jumps to the amount recorded before log out.
- [x] **(If convenient) gain a level, quick logout, relog** → you're still the new level. notes:

## 4 — Passive skills survive a quick logout
- [x] **Melee / cast / take hits until a skill-up message fires** (weapon/armor/casting), then
      **log out within a few seconds, relog** → open the character window; the advanced skill
      score held (didn't roll back). notes:

## 5 — Regression: nothing that already persisted broke
- [x] **Coins:** vendor-sell something, quick logout, relog → coin total is correct (still
      flushes as before). notes:
- [x] **Bank:** deposit an item/coin, quick logout, relog → still in the bank. notes:
- [x] **Quests:** kill 1 of a quest's mobs, quick logout, relog → progress held. notes:
- [x] **Gear stats (from the prior fix):** relog with gear equipped → the stat bonuses still
      show on the character sheet. notes:

## 6 — Server restart (the harder persistence case)
- [x] **Make a batch of changes** (equip/unequip, loot, a kill or two), **cleanly log out**,
      then **stop + restart the server** and log in → everything is where you left it. notes:

## Notes / observations
-
