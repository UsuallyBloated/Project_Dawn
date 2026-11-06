# Corpse Auto-Re-equip Playtest Checklist — 2026-10-13

Looting your own corpse now puts the gear you were wearing back on the slot you wore it in,
as classic EQ did; carried items still go to your bags. **Server-only** (server `d598ad6` + `5986f26`, migration
`0014_corpse_equip_slot.sql`): it needs a redeploy, no export and no protocol change. Corpses made
before the redeploy have no record of what was worn and loot into the bags exactly as before.

| Rule | What happens |
|---|---|
| A worn item, its slot empty | goes straight back on, gear bonuses and all |
| A worn item, its slot now filled (you put something else on) | goes to your bags; what you wear now is never displaced |
| A carried item, or a bag and its contents | goes to your bags, as before |
| No room in the bags | stays on the corpse with the line "Your bags are full: N items stay on your corpse.", and still remembers its slot for a later loot |

Diagnostics: `server.log` anchors `corpse loot put worn gear back on` (with `reequipped=N`),
`corpse created` (with `item_stacks`), `corpse looted empty — despawned`.

## 1 — The ordinary corpse run

- [x] **Wear a full set (weapon, helm, chest, legs, boots, gloves, a ring), carry a bag with something in it, die** → the corpse window lists your worn gear first, then what you carried. notes: Per the tester (confirmed across today's deaths). the R720 journal, 2026-10-26 to 27: eight corpse runs on char 1, each `corpse created` with 8 to 16 stacks.
- [x] **Respawn, run back, Loot All** → every worn piece is back on its paperdoll slot at once; the bag and its contents are in your inventory; chat shows a "You loot:" line per item. notes: the R720 journal, 2026-10-26 to 27: all eight show `corpse loot put worn gear back on ... reequipped=8` and `corpse looted empty` in the same millisecond (e.g. 2000000004: 11 stacks, 8 back on their slots, the other 3 to the bags). One, 2000000013, was created at 15:42 and looted at 15:44 by a new server process, so a restart in between kept the worn slots.
- [x] **Open the character sheet** → AC, max HP / mana and the stat bonuses match what they were before the death. notes: Per the tester; not something the log shows.
- [x] **Relog** → the gear is still worn (it was saved with the loot). notes: Each death after a relog or a restart stripped 8 worn pieces again (e.g. 21:35:59, after the 16:38 loot and a server restart), so the gear stayed worn and saved.

## 2 — One item at a time

- [x] **Die again, loot only the helm** → it goes on the head, nothing else moves. notes:
- [x] **Before looting the chest piece, put a different chest item on from your bags, then loot the old one** → the old chest piece goes to your bags; the one you put on stays worn. notes:  Tested with boots slot instead.
- [x] **Loot a weapon that was in your main hand** → it goes back in the main hand. notes: Covered by the Loot All runs: the full set includes the weapon, and all 8 pieces went back each time.

## 3 — Edges

- [x] **Die, respawn, fill your bags first (buy from a vendor, or loot kills), then Loot All** → worn gear goes back on (it needs no bag room); anything that does not fit stays on the corpse, and chat says "Your bags are full: N items stay on your corpse." Loot again after making room → it comes off. notes:
- [x] **Die holding an item on the cursor** → it is on the corpse and comes back into your bags, not onto a slot. notes:
- [-] **A corpse from before the redeploy, if one exists** → loots into the bags as it always did. notes: None exists: a fresh world since 2026-10-25.
- [x] **Resurrected corpse** (a Cleric or Paladin res, then loot) → same behaviour; the res is unaffected. notes: The journal, 2026-10-27: Dip (level 1) died at 02:29:59 (`corpse created ... item_stacks=9`); REZZZZ cast Resurrection (Minor), Dip accepted (`refund=0`, a level 1 death costs no XP), then looted: `corpse loot put worn gear back on ... reequipped=8`, `corpse looted empty`.

## Notes / observations
- Quick note.  We have a mana cost for memorizing a spell.  This isnt good.  spells will be memorized for no cost of mana.  Casting the spell is where the cost of mana comes in.
