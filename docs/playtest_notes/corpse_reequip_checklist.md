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

- [ ] **Wear a full set (weapon, helm, chest, legs, boots, gloves, a ring), carry a bag with something in it, die** → the corpse window lists your worn gear first, then what you carried. notes:
- [ ] **Respawn, run back, Loot All** → every worn piece is back on its paperdoll slot at once; the bag and its contents are in your inventory; chat shows a "You loot:" line per item. notes:
- [ ] **Open the character sheet** → AC, max HP / mana and the stat bonuses match what they were before the death. notes:
- [ ] **Relog** → the gear is still worn (it was saved with the loot). notes:

## 2 — One item at a time

- [ ] **Die again, loot only the helm** → it goes on the head, nothing else moves. notes:
- [ ] **Before looting the chest piece, put a different chest item on from your bags, then loot the old one** → the old chest piece goes to your bags; the one you put on stays worn. notes:
- [ ] **Loot a weapon that was in your main hand** → it goes back in the main hand. notes:

## 3 — Edges

- [ ] **Die with full bags and loot everything** → worn gear goes back on (it needs no bag room); anything that does not fit stays on the corpse, and chat says "Your bags are full: N items stay on your corpse." Loot again after making room → it comes off. notes:
- [ ] **Die holding an item on the cursor** → it is on the corpse and comes back into your bags, not onto a slot. notes:
- [ ] **A corpse from before the redeploy, if one exists** → loots into the bags as it always did. notes:
- [ ] **Resurrected corpse** (a Cleric or Paladin res, then loot) → same behaviour; the res is unaffected. notes:

## Notes / observations
