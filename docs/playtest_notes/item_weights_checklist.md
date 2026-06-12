# Item Weights (Full Content Pass) Playtest Checklist — 2026-06-12

All 169 items now have real carry weight (previously 20). **Client-only — re-export /
reload Project_Dawn; no server rebuild or restart needed.** (Exception: the Test Panel
money buttons used in the regression section still need the server running with
`PD_DEV_CMDS=1`.)

Key numbers under test (full table: `docs/design/item_weight_proposal.md`):

| Thing | Effect | Who/Where | Notes |
|---|---|---|---|
| Capacity | `10 + STR` | character window Weight row | yellow > capacity, red ≥ 2× |
| Ore / pickaxe | 3.0 each / 5.0 | mining haul | ~5 iron ore fills a STR-10 miner with pickaxe |
| Iron chain kit | 18.5 worn (coif 3, vest 6, leggings 5, boots 3, gloves 1.5) | paperdoll | rescaled this pass — was 30.5 |
| Potions / reagents | 0.3 / 0.1 each | bags | 10-potion stack = 3.0 |
| Arrow Bundle | 1.0 each, **stack cap now 20** | inventory | was stack 200 (= 200.0 weight) |

Diagnostics: in-game console (backtick or `/console`); `Encumbrance.total_weight` /
`capacity` are the autoload fields if a readout looks wrong.

## Setup
- [ ] Reload / re-export Project_Dawn (152 `.tres` changed)
- [ ] Server running with `PD_DEV_CMDS=1` (only for the money-button regression rows)
- [ ] Client logged in; character window open so the Weight row is visible

## 1 — Ore run (the heavy haul)
The designed gathering pressure: ore is the heaviest common stackable.

- [ ] **Carry a pickaxe** → Weight row +5.0. notes:
- [ ] **Add iron/copper ore one at a time** → +3.0 per ore; on a fresh-STR character
  the encumbered transition ("You are encumbered!" + yellow Weight + HUD label) hits
  around the 5th–6th ore. notes:
- [ ] **While encumbered, move** → visibly slower; keep stacking toward 2× capacity →
  Weight turns red, HUD says "Overloaded!". notes:
- [ ] **Drop/vendor the ore** → speed and colors recover, "no longer encumbered". notes:

## 2 — Full armor kit (worn gear counts; chain was rescaled)
- [ ] **Equip full iron chain + iron short sword** (22.5 worn total) → Weight row
  reflects every piece; a fresh Warrior-class character (capacity ≈ 30+) is **not**
  encumbered standing still. notes:
- [ ] **Unequip the vest** → Weight drops by exactly 6.0 (rescaled value, not the old
  10.0). notes:
- [ ] **Swap iron vest → cloth robe** → drop of 4.0 (6.0 → 2.0). notes:

## 3 — Potion / reagent bag (stacks multiply, bags count)
- [ ] **10 healing potions in a bag** → +3.0 (bag contents count). notes:
- [ ] **20 bat wings** → +2.0; **20 gnoll teeth** → +2.0. notes:
- [ ] **A meat stack (10 wolf meat)** → +2.5 (0.25 each — Weight row shows the
  fraction). notes:

## 4 — Arrow Bundle stack fix
- [ ] **Try to stack arrow bundles past 20** → stack caps at 20 (was 200); a full
  stack adds 20.0 weight. notes:

## 5 — Flavor spot-checks
- [ ] **Mithril ingot (0.1) vs adamantite ingot (3.0)** → the lore reads in the Weight
  row when carrying a stack of each. notes:
- [ ] **Brown Steed Whistle** → barely registers (0.1). notes:

## 6 — Regression: currency & encumbrance UI unchanged (from currency_ui_checklist §5)
- [ ] Vendor window: footer wallet raw stacks, item prices reduced ("2s 50c"). notes:
- [ ] Inventory drag/drop, bag open/close, trash delete → unchanged. notes:
- [ ] Encumbrance speed penalty + stamina-regen gate still fire at the same
  thresholds (now reachable via items alone, not just coins). notes:
- [ ] Save → quit → reload → wallet stacks identical, Weight identical. notes:

## Notes / observations
-
