# Item Weights (Full Content Pass) Playtest Checklist — 2026-06-12

All 169 items now have real carry weight (previously 20). **Client-only — re-export /
reload Project_Dawn; no server rebuild or restart needed.** (Exception: the Test Panel
money buttons used in the regression section still need the server running with
`PD_DEV_CMDS=1`.)

Key numbers under test (full table: `docs/design/item_weight_proposal.md`):

| Thing | Effect | Who/Where | Notes |
|---|---|---|---|
| Capacity | `10 + STR` | character window Weight row | yellow > capacity, red ≥ 2× |
| Ore / pickaxe | 0.25 each / 5.0 | mining haul | family rescaled ÷12 post-sign-off; full 20-stack of ore = 5.0 |
| Iron chain kit | 18.5 worn (coif 3, vest 6, leggings 5, boots 3, gloves 1.5) | paperdoll | rescaled this pass — was 30.5 |
| Potions / reagents | 0.3 / 0.1 each | bags | 10-potion stack = 3.0 |
| Arrow Bundle | 1.0 each, **stack cap now 20** | inventory | was stack 200 (= 200.0 weight) |

Diagnostics: in-game console (backtick or `/console`); `Encumbrance.total_weight` /
`capacity` are the autoload fields if a readout looks wrong.

## Setup
- [ ] Reload / re-export Project_Dawn (152 `.tres` changed)
- [ ] Server running with `PD_DEV_CMDS=1` (only for the money-button regression rows)
- [ ] Client logged in; character window open so the Weight row is visible

## 1 — Mining & smelting loop (ore rescaled to 0.25 post-sign-off)
Ore is deliberately light now; the smelt should still shrink the haul.

- [ ] **Carry a pickaxe** → Weight row +5.0. notes:
- [ ] **A full 20-stack of iron ore** → +5.0 total (0.25 each; fractions render in
  the Weight row). notes:
- [ ] **Smelt 2 ore → 1 ingot at a forge** → those items' carried weight drops
  0.5 → 0.1. notes:
- [ ] **Heavy-haul encumbrance check** (ore no longer triggers it): stack thick
  leather slabs (1.5) / lumps of clay (0.5) / ale (0.5) until over capacity →
  "You are encumbered!" + yellow Weight + HUD label; movement visibly slower; keep
  going toward 2× → red "Overloaded!"; drop the load → recovers. notes:

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
- [ ] **Mithril ore stack (20 = 2.0) vs adamantite ore stack (20 = 10.0)** → the
  lore still reads in the Weight row, post-rescale. notes:
- [ ] **Brown Steed Whistle** → barely registers (0.1). notes:

## 6 — Regression: currency & encumbrance UI unchanged (from currency_ui_checklist §5)
- [ ] Vendor window: footer wallet raw stacks, item prices reduced ("2s 50c"). notes:
- [ ] Inventory drag/drop, bag open/close, trash delete → unchanged. notes:
- [ ] Encumbrance speed penalty + stamina-regen gate still fire at the same
  thresholds (now reachable via items alone, not just coins). notes:
- [ ] Save → quit → reload → wallet stacks identical, Weight identical. notes:

## Notes / observations
-
