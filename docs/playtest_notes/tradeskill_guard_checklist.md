# Tradeskill Guard Playtest Checklist — 2026-08-24

Verifies that mining, crafting and skinning **refuse honestly online** instead of creating phantom
items that desync the inventory.

**Build prerequisite: client re-export only.** No server change, no R720 restart.

**What was wrong.** All three tradeskills ended in a bare local `Inventory.add_item()` the server
never heard about. Online, the created item was a ghost that vanished on relog — and crafting was
actively dangerous: it deleted the *real* ingredients from the client's mirror while the server
still held them, so the slot indices drifted and a later Sell/Destroy the player legitimately
clicked could execute against a **different, real item**. Found by the 2026-08-24 dead-intents
audit. Real server-authoritative tradeskills are a later build; this guard converts silent item
loss into a clear "not built yet."

---

## 1 — The guards (online, on the R720)

- [ ] **Walk to an ore vein with a Pickaxe and press F** → "Mining isn't available online yet." No
      ore appears, no Mining skill-up message. notes:
- [ ] **Open a crafting station, pick any recipe, press Combine** → "Crafting isn't available
      online yet." **Your ingredients are untouched** — check the counts before and after. notes:
- [ ] **After the refused combine, relog** → ingredient counts unchanged. (Before the guard, the
      ingredients would have vanished from view until relog "restored" them.) notes:

## 2 — The desync is actually gone

The point of the guard is that inventory slots can no longer drift.

- [ ] **Try to mine, then immediately drag several inventory items around** → no
      `MoveItem rejected ... source slot empty` in `journalctl`. notes:
- [ ] **Sell an item right after a refused combine** → the item you clicked is the item that sells.
      notes:

## 3 — Offline / Test Room regression

The guard must only bite online — offline, tradeskills genuinely work locally.

- [ ] **Test Room: mine a vein** → works exactly as before (ore, skill-up, depletion). notes:
- [ ] **Test Room: complete a combine** → works as before. notes:
- [ ] **Test Room: skin a dead mob** → works as before. notes:

---

## Result

- Client build (`/version`):
- Overall:
