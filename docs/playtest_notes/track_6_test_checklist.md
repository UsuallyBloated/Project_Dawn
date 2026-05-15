# Track 6 Test Checklist — sub-tasks 4b / 4c / 4d / 5

## Setup
- [x] Re-export Project_Dawn
- [x] Restart server

## Sub-task 4b — Stat buffs
- [x] Cast **Bless** (Cleric); confirm stats rise on cast and revert on expire notes: Bless increases WIS +5, currently self-cast only. No buff icon in HUD while active. **FIXED 2026-05-15:** primary_stat icon now renders.
- [x] Cast **Valor** (Cleric/Paladin); +50 max_hp is visible; reverts on expire notes: currently self-cast only. No buff icon in HUD while active. **FIXED 2026-05-15:** primary_stat icon now renders.
- [x] Cast **Spirit of the Bear** (Shaman); stats rise on cast and revert on expire. notes: No buff icon in HUD while active. currently self-cast only. +10 str +5 con **FIXED 2026-05-15:** primary_stat icon now renders.
- [x] Cast **Brilliance** (Enchanter); stats rise on cast and revert on expire. notes: currently self-cast only. No buff icon in HUD while active. +10 int +5 wis **FIXED 2026-05-15:** primary_stat icon now renders.

## Sub-task 4c — Modifier buffs
- [x] **Spirit of Wolf** — speed increases while buff is active. notes: currently self-cast only.
- [x] **Thorns / Spellshield** — let an enemy hit you; attacker loses HP from damage shield. notes: I think thorn's affects are persisting after the buff is removed. currently self-cast only.  Can we get a message to the combat log "N has been hit by X damage from Z" N=attacker X=damage Z=damage shield(thorns, spellshield, etc.) **PARTIAL 2026-05-15:** damage_shield HUD icon now renders; combat log line + lingering-after-expire investigation still open.
- [x] **Rune / Primal Bond** — incoming damage absorbed; HP doesn't drop until pool drains. notes: Rune appears to be working. Primal Bond is visible on HUD when activated, but does not appear functional.
- [x] **Hunter's Eye** — crit chance increase observable. notes:  Buff visible on HUD while active. 

## Sub-task 4d — Crowd control (two clients)
- [x] `/pvp on` on both clients
- [x] **Mesmerize** other player; target can't act
- [x] **Ensnare** other player; target can't move (can still cast/attack)
- [x] **Snare** other player; target moves slowed but not stopped
- [x] **Slow** other player; target's attack/cast speed reduced. Notes: appears to be working.  not positive
- [-] **Spellbreak** other player; verify silence (target can't cast) notes: Not working
- [x] **Antimagic Ward** dispels one buff from target. notes: Character A casts Antimagic Ward on character B, character A can no longer see "Spirit of Wolf" buff listed on target pane, character B loses effects of Spirit of Wolf, character B still has Spirit of Wolf buff on HUD. Buff HUD icon does not update when antimagic ward is used. **FIXED 2026-05-15:** own-id BuffSnapshot now routes through `BuffManager.reconcile_with_server_snapshot()` so the dispelled buff clears locally.
- [x] **Expose** dispels one buff from target. notes: Same as Antimagic Ward.  Expose removes effects of spirit of wolf, but HUD does not update correctly **FIXED 2026-05-15:** same reconciler path.

## Sub-task 5 — Groups (two clients, A and B)
- [x] From A: `/invite <B's name>` — B sees an invite prompt
- [x] B: `/accept` — both clients see the roster populated. notes: I used the "follow" button, not /accept.
- [x] Kill an enemy together; both clients receive XP (each ~60% of base for 2-person group, including +20% pool bonus)
- [x] `/leave` works as expected. notes: character A removed self from group, A's HUD updates, B's HUD did not remove A from the roster **FIXED 2026-05-15:** `GroupManager::leave()` now returns the surviving solo member so the server can fan a dissolution roster to them.
- [x] `/kick <name>` works as expected. notes: removed target from the group, did not remove the target from the group roster HUD **FIXED 2026-05-15:** same fix.




notes:  

I get the feeling that our buff system is overcomplicated.  Rune and Primal Bond are the same thing, it's standing out to me that Rune works and Primal Bond doesnt.  Is there something we can do to simplify the buff system to make it a more plug-and-play system?  Perhaps that is already what you are working on, forgive my silly questions.

We need a debuff HUD window to display debuffs (root, snare, slow, etc.)

Healing spells work only on caster.  

"Full Heal" button in Test Panel is broken.  HP doesn't stick.  Click "Full Heal" -> HP briefly jumps to full -> then quickly drops back to original value. **FIXED 2026-05-15:** Full Heal routes the missing HP through `Net.broadcast_heal_self()` in launcher mode so the server applies it.

