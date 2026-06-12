# Currency & Encumbrance Visibility UI Playtest Checklist — 2026-06-12

The wallet and weight systems now have UI beyond the vendor footer: a wallet line in the
inventory window, a WT row in the character window, a HUD warning while encumbered, and
20 items now have real weight. Client-only change — **no server rebuild, no DLL rebuild;
just re-export / reload the project in Godot.** Server still needs `PD_DEV_CMDS=1` for
the Test Panel money buttons.

| Thing | Effect | Who/Where | Notes |
|---|---|---|---|
| Wallet line | raw stacks, e.g. "1p 5g 5s 350c" | inventory window, above trash slot | gold text; same format as vendor footer |
| WT row | "12.4 / 60.0" weight vs capacity | character window, attribute grid | default color → yellow > capacity → red ≥ 2× |
| HUD warning | "Encumbered 24.3 / 20.0" / "Overloaded! …" | under the HP/MP/ST panel | only visible while over capacity |
| Item weights | 20 items tagged | weapons 2–8, armor 1–10, potions 0.3, reagents 0.1 | e.g. iron chain vest 10, iron short sword 4 |

Diagnostics: in-game console (backtick) for client state; `Encumbrance.total_weight` /
`capacity` are the autoload fields if a readout looks wrong.

## Setup
- [ ] Reload / re-export Project_Dawn (UI scripts + .tres changed)
- [ ] Restart server with `PD_DEV_CMDS=1` (money buttons need it)
- [ ] Client logged in (launcher mode)

## 1 — Wallet line in the inventory window
- [ ] **Open inventory** → wallet line visible between the slot grid and trash slot, gold
  text. notes:
- [ ] **Compare with vendor window footer** → identical string (raw stacks, e.g. a
  1000-copper grant reads "1000c", not "10s"). notes:
- [ ] **Test Panel → Give 1,000 Copper** → inventory wallet line updates live without
  reopening the window. notes:
- [ ] **Buy and sell something at a vendor** → wallet line tracks both directions. notes:
- [ ] **Clear Money** → "0c". notes:

## 2 — WT row in the character window
- [ ] **Open character window** → WT row at the bottom of the attribute grid shows
  `weight / capacity`; capacity = 10 + STR. notes:
- [ ] **Hover the WT label** → tooltip explains coins+items+gear, 10 + STR, and both
  penalties. notes:
- [ ] **Equip / unequip a tagged piece (e.g. iron chain vest, weight 10)** → WT updates
  live by that amount either direction (worn gear still counts). notes:
- [ ] **Give 1,000 Copper until over capacity** → WT number turns yellow at the same
  moment "You are encumbered!" hits chat. notes:
- [ ] **Keep stacking to ≥ 2× capacity** → WT turns red. notes:
- [ ] **Clear Money** → WT drops, color back to normal, "You are no longer
  encumbered." notes:

## 3 — HUD encumbrance warning
- [ ] **Under capacity** → no warning label anywhere under the HP/MP/ST panel. notes:
- [ ] **Cross capacity** → yellow "Encumbered  <w> / <cap>" appears under the stat panel
  without opening any window. notes:
- [ ] **Cross 2× capacity** → label turns red "Overloaded!". notes:
- [ ] **Clear Money** → label disappears. notes:

## 4 — Item weights actually weigh
- [ ] **Pick up / carry a tagged weapon or armor piece** → WT rises by its weight (in a
  bag counts too). notes:
- [ ] **A stack of tagged reagents (e.g. 20 bat wings)** → contributes weight × count
  (= 2.0). notes:
- [ ] **Untagged items (most of the catalog)** → still weightless, WT unchanged. notes:

## 5 — Regression: nearby behavior unchanged
- [ ] Vendor window wallet footer + reduced prices ("2s 50c") → unchanged. notes:
- [ ] Inventory drag/drop, bag open/close, trash delete → unchanged (the wallet line sits
  between grid and trash — make sure drops near it still land). notes:
- [ ] Encumbrance speed penalty + stamina-regen gate → unchanged (UI only). notes:
- [ ] Save → quit → reload → wallet stacks identical, WT identical. notes:

## Notes / observations
-
