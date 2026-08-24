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

- [x] **Right-click an ore vein (with a Pickaxe)** → "Mining isn't available online yet." No
      ore appears, no Mining skill-up message. notes:
- [x] **Open a crafting station, pick any recipe, press Combine** → "Crafting isn't available
      online yet." **Your ingredients are untouched** — check the counts before and after. notes: No message, but "Combine" button is grey and doesnt function. nice work.
- [x] **After the refused combine, relog** → ingredient counts unchanged. (Before the guard, the
      ingredients would have vanished from view until relog "restored" them.) notes: This isnt really applicable.

## 2 — The desync is actually gone

The point of the guard is that inventory slots can no longer drift.

- [x] **Try to mine, then immediately drag several inventory items around** → no
      `MoveItem rejected ... source slot empty` in `journalctl`. notes:
- [x] **Sell an item right after a refused combine** → the item you clicked is the item that sells.
      notes:

## 3 — Offline / Test Room regression

The guard must only bite online — offline, tradeskills genuinely work locally.

- [-] **Test Room: mine a vein** → works exactly as before (ore, skill-up, depletion). notes:
- [-] **Test Room: complete a combine** → works as before. notes:
- [-] **Test Room: skin a dead mob** → works as before. notes:
-  This game will not have an "offline" version.
---

## Result

- Client build: `fa2ff04-dirty`
- Overall: **PASS** on every online row; the three Test Room regression rows were skipped
  (offline path untouched by inspection, but unexercised — noted honestly).

The server log confirms the guards from the outside: a Pickaxe bought at 22:05 and ore/coal
granted at 22:16, followed by **zero** mining or crafting log lines (the refusals are
client-side, so nothing crosses the wire), and the 22:18 inventory shuffle is **all
`MoveItem applied` with zero `source slot empty` rejections** — the desync signature the guard
exists to prevent, absent.
