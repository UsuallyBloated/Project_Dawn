# Trade Window — Slice 1 (player to player) — 2026-09-29

PD_W0028. Escrow by locking: offered items stay in your real inventory until
a single atomic commit. Design + the exploit ledger this list follows:
`docs/design/trade_window.md` §5.

**Build prerequisites (both move together — a protocol bump refuses old clients):**
- Server on `feat/trade-window` (boot sha), and a client export from the
  matching branch carrying the refreshed `gdext_net.dll`.
- Two accounts / two seats (one char per account permits two-boxing).

---

## 1 — The happy path

- [x] **Hold an item, left-click the other player** → both windows open instantly,
      each titled with the partner's name; the click also targeted them. notes:
- [x] **Look at where it opened, then drag it by its background** (client `0ae26a6`, next
      export) → it opens in the middle of the screen and moves with the mouse like the bank
      window; it used to open off the top-left corner and could not be moved. notes: opened in the middle of screen.  nice work.
- [x] **Click one of YOUR slots while holding** → the item leaves the cursor into
      the window slot; the partner's side shows it (name + count). notes:
- [x] **Type coin into your fields** → the partner sees "Coin: Np Ng Ns Nc". notes:  
- [x] **Both press Trade** → items and coin change hands, both windows close with
      "Trade complete.", and the goods are in the receivers' bags. notes:
- [x] **A gift (one side offers, other offers nothing)** → commits fine. notes:

## 2 — The exploit ledger (each must hold)

- [x] **Bait-and-switch (ledger 1)**: you accept, partner then changes their offer
      → your accept light goes dark; a lone re-accept by them does NOT commit. notes:
- [x] **Escrow lock (ledger 2)**: with an item offered, try to move / drop / equip /
      sell / bank that same slot from your inventory → refused, "That item is
      offered in a trade."; the item never moves. notes:
- [x] **Double-spend (ledger 2)**: the offered slot cannot be offered into a second
      window slot; you have only one session at a time. notes:
- [x] **Coin overdraft (ledger 4)**: offer more coin than your wallet holds →
      refused with "You don't have that much coin." notes:
- [x] **Stack cap (ledger 5)**: trade a stack that would push the receiver over the
      item's cap → the receiver's placement stays capped, never a 41-stack. notes: "Your bags cannot hold their offer." and "Their bags cannot hold your offer."
- [x] **Capacity grief (ledger 6)**: fill the receiver's bags, then commit → refused
      cleanly ("their/your bags cannot hold..."), nothing half-applied, window stays
      open. notes:
- [x] **Range/state escape (ledger 7)**: open a trade, walk >10 m apart (or one
      party dies / logs out) → the session closes for both with a reason, and every
      locked slot is free again. notes:
- [x] **Self / busy (ledger 8)**: trying to trade yourself refuses; requesting a
      player already trading refuses quietly to you only. notes:  Currently the only way i know of to trade is to pick an item up from my inventory, then click on the other person you want to trade with while holding that item.  When i try to pick up an item and click on my own character model i get the "Do you want to drop the <item>" prompt.  This appears to work well.
- [x] **Enemy/NPC target (ledger 10)**: holding an item and clicking a mob or NPC
      does NOT open a trade (targets only). notes:
- [x] **Bag swap (review 2026-10-12)**: offer an item that sits inside a pouch, then
      try to move or swap that pouch → refused with "That item is offered in a
      trade."; the partner receives exactly what their window showed. notes: When the player has a full inventory, the item's indicator moves back to the pouch while the trade is being conducted.  During this time the item and bag show "That item is offered in a trade."  If the player has an open slot in their inventory, the item is moved from the pouch to the primary inventory.  During this time the item shows "That item is offered in a trade." but the pouch is now movable.  This all appears to work great.  
- [x] **Filling an offered bag**: offer an EMPTY pouch, then try to drag something
      into it → refused with the same line. notes:
- [x] **An offered stack grows** (offer some bread, then buy or loot one more bread so it
      merges, then both accept) → refused, the bread leaves your trade window with "An
      item you offered changed...", the partner sees "Their offer changed..."; offer it
      again and the trade goes through with the new count. notes:
- [x] **Offered food is not auto-eaten**: run a character nearly out of food (or ask for it
      to be set on the host), offer its only bread in a trade, and let the food run out →
      the bread stays in the trade window (the character goes hungry rather than eat an
      offer). notes:
- [x] **Request from afar**: request a trade with a player more than 10 m away →
      "There is no one here to trade with." (the same line as for nobody). notes:

## 3 — Persistence / crash safety

- [x] **Cancel mid-trade** → both windows close, every offered item is exactly where
      it was, nothing consumed. notes:
- [x] **Relog right after a completed trade** → the received goods and spent/gained
      coin persist (the commit was one transaction). notes:

---

## Result

- Server build (boot line):
- Client build (`/version`):
- Overall:
