# Dev Panel Modernization — Playtest Checklist — 2026-07-11

Three things: (1) the Test Panel now grants items **server-side** (no more client-only ghosts),
via a new **GEAR** section with a searchable item picker + the moved loadout buttons; (2) `/give`
(GmCommand) is now **dev-gated** (`is_dev`), closing the exploit-audit's top finding while still
backing the Test Panel; (3) named mobs (Rotfang) spawn as **real server creatures** and a **Rat**
mob was added so `rat_infestation` is fully testable.

**No wire change → NO DLL rebuild.** Rebuild + restart the server (for the `/give` gate) and
re-export the client. Server must run with `PD_DEV_CMDS=1` (as playtests already do) or the
Test Panel gives + `/give` are silently ignored (that's the gate working).

## 1 — GEAR item picker (the headline)
- [x] **Open the Test Panel → the new GEAR section** → it has a search box, an item list, a Qty
      spinner, "Give Selected Item", and the loadout buttons (Bow / Proc / Bags / Food / Craft).
      The old buttons are GONE from RESOURCES. notes:
- [x] **Type in the search box (e.g. "iron")** → the list filters live to matching items. notes:
- [x] **Select an item, set Qty (e.g. 3), click "Give Selected Item"** → the item(s) land in your
      inventory and a "Granted 3x …" line prints. notes:
- [x] **Double-click an item in the list** → same as Give Selected (convenience). notes:
- [x] **Relog** → the granted item is STILL there (it's server-recorded now, not a ghost). notes:
- [x] **Grant an equippable item + equip it** → it equips and its stats apply (no
      "source slot empty" reject). notes:

## 2 — Ghost items fixed (the loadout buttons)
- [x] **Give Bow / Give Proc Weapon** → the weapon lands; relog → still there; equip works. notes:
- [ ] **Give Food & Drink** → bread_loaf + water_flask land (registry items now); relog → there. notes:
- [x] **Give Bags** → 2x Small Pouch land; relog → there. notes:
- [x] **Give Crafting Materials** → the stacks land server-side; relog → there. notes:
- [x] **Fill your inventory with picker-granted items, then turn in a quest with an item reward**
      → the "inventory full" rejection behaves correctly (no overwrite — the earlier ghost bug
      is gone because these items are now server-known). notes:

## 3 — /give is dev-gated (exploit closed)
- [x] **With PD_DEV_CMDS=1 (this playtest): type `/give iron short sword` in chat** → it still
      works (dev). notes:
- [x] **(Optional, proves the fix) Restart the server WITHOUT `PD_DEV_CMDS`, type `/give …`** →
      nothing happens (no item minted); server.log shows no GmGive. Then restart with the flag
      again for the rest of testing. notes: RESOLVED 2026-07-16. First "failure" was the shell
      env still sticky (both retries booted `dev_cmds=true`). Clean dev-off run
      (`dev_panel_gate_retest_devoff.log`, boot line `dev_cmds=false`): chat showed "requested..."
      but zero GmGive lines, no item. Gate proven closed.

## 4 — Rat mob + rat_infestation full loop
- [x] **ENEMY SPAWN → select "Rat" → spawn** → a Rat appears (server mob). notes:
- [x] **Accept rat_infestation from Brom, spawn + kill 8 Rats, turn in at Brom** → completes,
      XP paid; server.log `quest completed … quest_id=rat_infestation`. notes:

## 5 — Rotfang spawns as a real server mob
- [x] **ENEMY SPAWN (named) → Rotfang → spawn** → it's a real server creature: killing it gives
      **quest kill credit** and drops a **server corpse** (NOT the old floating golden orb). notes:
- [x] **Accept rotfang_hunt from Aldric (needs L5), kill the spawned Rotfang, turn in at Aldric**
      → completes, **Hunter's Medal** lands + XP. notes:
- [-] **Note:** Rotfang no longer enrages / drops the guaranteed fang (those are client-only
      features with no server side yet) — expected; it's a generic server mob named Rotfang. notes: Fang did not drop.  Maybe I missed it.

## 6 — Regression
- [x] **Give 1,000 Copper / Give purse** (RESOURCES) → coins still work (unchanged). notes:
- [x] **Normal spawns (Grey Wolf, Gnoll, etc.)** → still spawn + give credit as before. notes:
- [x] **Add/Complete Test Quest buttons** (still in RESOURCES) → unchanged. notes:

## Notes / observations
- Unrelated:  Character can attack while seated.
- 
