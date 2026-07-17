# Quest Phase 2 Slice B Playtest Checklist — 2026-07-10

> **RECONCILED (Phase 0, 2026-07-17) — partial.** The `[-]` row 35 (rotfang_hunt turn-in) failed
> on two specific complaints — "killing the dev-panel Rotfang grants no kill credit" and "Rotfang
> drops the old golden orb". BOTH were closed by the dev-panel pass `5ae6808` (2026-07-16); see
> `session_2026_07_11_dev_panel.md:65` (rat + Rotfang full quest loops complete). **But the row's
> actual expectation is that a Hunter's Medal (STR +2, CON +2) LANDS on turn-in, and that item
> was never re-tested** — only kill credit and XP were evidenced. Left OPEN as a re-test row, not
> ticked. Also still open (see rows 56-57 + Notes): the **Tarnished Silver Ring equips but its
> AGI +1 never applies** — a ring-specific item-stat bug (the gnoll boots DO apply their stats,
> `quest_sliceD_brom_checklist.md:33`). Both tracked in `CLAUDE.md` To-Do.

Server-granted quest ITEM rewards on turn-in. Turning a quest in now grants its authored item
(server-side, via the same `InventoryDelta` path as loot), gated once-per-character by the same
completion record as the XP. If your bag is full the WHOLE turn-in is refused with a visible
line and the quest stays "Ready" so you can make room and retry (no item lost, no XP either).

**Build prerequisites (no wire change → NO DLL rebuild):**
- Re-export / reload Project_Dawn in Godot (picks up the 3 new reward `.tres`).
- Rebuild + restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` piped to
  `Tee-Object server.log` (embeds the new `items.toml` + `quests.toml`).

| Quest | Turn-in NPC | Item reward | Stats |
|---|---|---|---|
| wolf_threat (L1) | Aldric the Guard | Tarnished Silver Ring | AGI +1 |
| rotfang_hunt (L5) | Aldric the Guard | Hunter's Medal | STR +2, CON +2 |
| gnoll_raiders (L3) | Brom (**slice D — unreachable**) | Scout's Leather Boots | AGI +2, Armor +6 |
| rat_infestation / test_q1 | — | (none) | — |

> **Gotcha:** only wolf_threat (Aldric) and rotfang_hunt (Aldric, needs L5) can be turned in via
> an NPC right now — Brom's dialogue is slice D, so the gnoll boots aren't testable yet. Server
> log anchors: `quest completed`, `quest turn-in rejected — inventory full`, `bank store`.

## Setup
- [x] Re-export Project_Dawn (3 new .tres present)
- [x] Rebuild + restart server with `PD_DEV_CMDS=1`
- [ ] A character that can accept wolf_threat from Aldric

## 1 — Item reward lands on turn-in
- [x] **Accept wolf_threat, kill 5 wolves, turn in at Aldric with free bag space** → a **Tarnished
  Silver Ring** appears in an inventory slot; you also get the 300 quest XP; server.log shows
  `quest completed … quest_id=wolf_threat`. notes:
- [x] **Open the ring's tooltip** → it reads AGI +1, vendor price 30 (the authored item, not a
  placeholder). notes:  Player can sell to vender for 15c.  I'm not saying this needs to be corrected to 30c, just informing.  
- [-] **(If you reach L5) rotfang_hunt turn-in** → a **Hunter's Medal** lands (STR +2, CON +2). notes:  Rotfang appears to need an update.  killing the enemy that is spawned in by the dev panel does not grant kill credit for the quest.  Also Rotfang drops the old floating golden orb.  Let me know what you think.

## 2 — Full inventory refuses the whole turn-in (no loss)
- [x] **Fill all 8 base inventory slots** (Test Panel gives items; or loot), then turn in a
  READY wolf_threat → combat log "…: Your inventory is full — make room and try again.", **NO ring,
  NO XP**, and the quest stays **Ready** in the journal; server.log `quest turn-in rejected —
  inventory full`. notes:  Tarnished Silver Ring appeared to overwrite "Hunter's Shortbow" in the character's inventory.  Let me know what you think.

  - Tested again with "Iron Short Sword" in each inventory slot;  Tarnished Silver Ring did not overwrite any item when the character's inventory was full and displayed message "The Wolf Threat: Your inventory is full - make room and try again.  Appears to work as intended. problem appears to be with old items granted by dev window.
- [x] **Free one slot, turn in again** → the ring lands AND the 300 XP arrives this time. notes: 

## 3 — Granted once, ever (no dup)
- [x] **After receiving the ring, log out and back in** → you STILL have exactly one ring (it
  persisted; the forced save means it survives even an immediate relog), the quest is in the
  Completed tab, and Aldric offers no re-turn-in. notes:
- [x] **Stop + restart the server, log in** → still exactly one ring, quest still completed. notes:
- [x] **Drop/vendor the ring, then try to re-turn-in wolf_threat** (dialogue shouldn't offer it,
  but if you force it via anything) → rejected "already completed", NO second ring. notes:  Appears to work as intended, cannot turn in the wolf threat quest and quest is still listed as "Completed" in journal.

## 4 — The item is a real, equippable item
- [x] **Equip the Tarnished Silver Ring** (drag to the ring paperdoll slot) → it equips and your
  AGI goes up by 1 (character window). notes: Ring can be equipped but the item does not affect the player's stats (AGI does not +1)
- [x] **Relog while it's equipped** → still equipped, stat still applied. notes: reloged, ring still equipped, stat not applied.

## 5 — Regression: no-reward quests unchanged
- [ ] **Complete test_q1 (Test Panel) or rat_infestation** → XP only, no item, no "inventory full"
  path triggered. notes:  Are you refering to the rotfang quest?  I dont know of a rat_infestation quest.
- [x] **Normal loot still works** (kill a mob, loot a drop) → unaffected. notes:

## Notes / observations
- Tarnished Silver Ring does not increase player's AGI +1.
- We need to make sure the Dev panel stays updated alongside the changes we make to the game.  Rotfang appears to be out of date and dropping golden orbs.  Let me know what you think about this.
- Tarnished Silver Ring appears to overwrite items in the inventory.  Is this possibly because the items granted by the dev window are old and broken code?
- 