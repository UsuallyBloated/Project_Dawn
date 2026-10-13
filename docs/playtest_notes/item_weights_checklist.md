# Item Weights (Full Content Pass) Playtest Checklist — 2026-06-12

> **Triage 2026-10-12** (the planner's week-5 chore, done early): the ore, pickaxe, smelt and haul rows retired (the stations and veins left world.tscn on 2026-09-22 and tradeskills refuse online); most rows superseded by the 169-item weight pass (systems_overview.md) and cursor_slot_checklist.md row 50; the equip and unequip weight rows (40, 43, 45) kept for a re-run since no later sheet shows them.
> Rows flipped to `[-]` below carry the verdict and the reason after their `notes:`; the
> rows still open are the re-run: 40, 43, 45 (line numbers as of the triage).

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
- [-] Reload / re-export Project_Dawn (152 `.tres` changed) triage 2026-10-12: RETIRED, a setup row.
- [-] Server running with `PD_DEV_CMDS=1` (only for the money-button regression rows) triage 2026-10-12: RETIRED, a setup row.
- [-] Client logged in; character window open so the Weight row is visible triage 2026-10-12: RETIRED, a setup row.

## 1 — Mining & smelting loop (ore rescaled to 0.25 post-sign-off)
Ore is deliberately light now; the smelt should still shrink the haul.

- [-] **Carry a pickaxe** → Weight row +5.0. notes: triage 2026-10-12: RETIRED, needs the ore veins, pickaxe and forge removed from world.tscn 2026-09-22; tradeskills refuse online.
- [-] **A full 20-stack of iron ore** → +5.0 total (0.25 each; fractions render in triage 2026-10-12: RETIRED, needs the ore veins, pickaxe and forge removed from world.tscn 2026-09-22; tradeskills refuse online.
  the Weight row). notes:
- [-] **Smelt 2 ore → 1 ingot at a forge** → those items' carried weight drops triage 2026-10-12: RETIRED, needs the ore veins, pickaxe and forge removed from world.tscn 2026-09-22; tradeskills refuse online.
  0.5 → 0.1. notes:
- [-] **Heavy-haul encumbrance check** (ore no longer triggers it): stack thick triage 2026-10-12: RETIRED, needs the ore veins, pickaxe and forge removed from world.tscn 2026-09-22; tradeskills refuse online.
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
- [-] **10 healing potions in a bag** → +3.0 (bag contents count). notes: triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.
- [-] **20 bat wings** → +2.0; **20 gnoll teeth** → +2.0. notes: triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.
- [-] **A meat stack (10 wolf meat)** → +2.5 (0.25 each — Weight row shows the triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.
  fraction). notes:

## 4 — Arrow Bundle stack fix
- [-] **Try to stack arrow bundles past 20** → stack caps at 20 (was 200); a full triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.
  stack adds 20.0 weight. notes:

## 5 — Flavor spot-checks
- [-] **Mithril ore stack (20 = 2.0) vs adamantite ore stack (20 = 10.0)** → the triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.
  lore still reads in the Weight row, post-rescale. notes:
- [-] **Brown Steed Whistle** → barely registers (0.1). notes: triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.

## 6 — Regression: currency & encumbrance UI unchanged (from currency_ui_checklist §5)
- [-] Vendor window: footer wallet raw stacks, item prices reduced ("2s 50c"). notes: triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.
- [-] Inventory drag/drop, bag open/close, trash delete → unchanged. notes: triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.
- [-] Encumbrance speed penalty + stamina-regen gate still fire at the same triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.
  thresholds (now reachable via items alone, not just coins). notes:
- [-] Save → quit → reload → wallet stacks identical, Weight identical. notes: triage 2026-10-12: SUPERSEDED, the 169-item weight pass of 2026-06-12 (systems_overview.md) and cursor_slot_checklist.md row 50.

## Notes / observations
-
