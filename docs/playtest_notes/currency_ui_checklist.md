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
- [x] Reload / re-export Project_Dawn (UI scripts + .tres changed)
- [x] Restart server with `PD_DEV_CMDS=1` (money buttons need it)
- [x] Client logged in (launcher mode)

## 1 — Wallet line in the inventory window
- [x] **Open inventory** → wallet line visible between the slot grid and trash slot, gold
  text. notes:
- [x] **Compare with vendor window footer** → identical string (raw stacks, e.g. a
  1000-copper grant reads "1000c", not "10s"). notes:
- [x] **Test Panel → Give 1,000 Copper** → inventory wallet line updates live without
  reopening the window. notes:
- [x] **Buy and sell something at a vendor** → wallet line tracks both directions. notes:
- [x] **Clear Money** → "0c". notes:

## 2 — WT row in the character window
- [x] **Open character window** → WT row at the bottom of the attribute grid shows
  `weight / capacity`; capacity = 10 + STR. notes:
- [x] **Hover the WT label** → tooltip explains coins+items+gear, 10 + STR, and both
  penalties. notes: No tooltip visible when overing over WT
- [x] **Equip / unequip a tagged piece (e.g. iron chain vest, weight 10)** → WT updates
  live by that amount either direction (worn gear still counts). notes:
- [x] **Give 1,000 Copper until over capacity** → WT number turns yellow at the same
  moment "You are encumbered!" hits chat. notes:
- [x] **Keep stacking to ≥ 2× capacity** → WT turns red. notes:
- [x] **Clear Money** → WT drops, color back to normal, "You are no longer
  encumbered." notes:

## 3 — HUD encumbrance warning
- [x] **Under capacity** → no warning label anywhere under the HP/MP/ST panel. notes:
- [x] **Cross capacity** → yellow "Encumbered  <w> / <cap>" appears under the stat panel
  without opening any window. notes:
- [x] **Cross 2× capacity** → label turns red "Overloaded!". notes:
- [x] **Clear Money** → label disappears. notes:

## 4 — Item weights actually weigh
- [x] **Pick up / carry a tagged weapon or armor piece** → WT rises by its weight (in a
  bag counts too). notes:
- [x] **A stack of tagged reagents (e.g. 20 bat wings)** → contributes weight × count
  (= 2.0). notes:
- [x] **Untagged items (most of the catalog)** → still weightless, WT unchanged. notes: Tested Torn Cloth Gloves

## 5 — Regression: nearby behavior unchanged
- [x] Vendor window wallet footer + reduced prices ("2s 50c") → unchanged. notes: Not sure what you're looking for here.
- [x] Inventory drag/drop, bag open/close, trash delete → unchanged (the wallet line sits
  between grid and trash — make sure drops near it still land). notes:
- [x] Encumbrance speed penalty + stamina-regen gate → unchanged (UI only). notes:
- [x] Save → quit → reload → wallet stacks identical, WT identical. notes:

## Notes / observations
- Please change WT to Weight in the character window.

Looking good.  Nice work.

---

## Round 2 — fixes from the first pass (2026-06-12, later)

Both findings fixed; client-only again — just reload the project, no server restart
needed.

- **WT tooltip (row 2.2) — fixed, and it was bigger than WT.** Godot `Label`s ignore
  the mouse by default, which also suppresses tooltips — so *none* of the character
  window's stat tooltips (HP/MP/ST/AC/STR/…/ATK) ever showed; WT was just the first one
  anyone hovered. All 13 labels now use `MOUSE_FILTER_PASS` (hoverable, clicks still
  fall through so window-dragging works).
- **"WT" → "Weight" (notes) — renamed** in the character window.

Re-test:
- [ ] **Hover Weight in the character window** → tooltip appears (coins+items+gear,
  10 + STR, both penalties). notes:
- [ ] **Hover a few others (STR, AC, HP)** → those tooltips appear too (first time
  ever). notes:
- [ ] **Drag the character window by grabbing a label** → still drags. notes:

Answers to first-round questions:
- *Row 5.1 "Not sure what you're looking for here"* — just that the vendor window
  itself didn't regress: footer wallet still shows raw stacks, item prices still show
  the reduced form ("2s 50c"). Your [x] covers it.
- `server.log` reviewed: clean — every grant/buy/sell/equip in the run logged with
  correct totals, no errors, no `coin checkpoint failed`.