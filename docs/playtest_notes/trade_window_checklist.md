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

- [ ] **Hold an item, left-click the other player** → both windows open instantly,
      each titled with the partner's name; the click also targeted them. notes:
- [ ] **Click one of YOUR slots while holding** → the item leaves the cursor into
      the window slot; the partner's side shows it (name + count). notes:
- [ ] **Type coin into your fields** → the partner sees "Coin: Np Ng Ns Nc". notes:
- [ ] **Both press Trade** → items and coin change hands, both windows close with
      "Trade complete.", and the goods are in the receivers' bags. notes:
- [ ] **A gift (one side offers, other offers nothing)** → commits fine. notes:

## 2 — The exploit ledger (each must hold)

- [ ] **Bait-and-switch (ledger 1)**: you accept, partner then changes their offer
      → your accept light goes dark; a lone re-accept by them does NOT commit. notes:
- [ ] **Escrow lock (ledger 2)**: with an item offered, try to move / drop / equip /
      sell / bank that same slot from your inventory → refused, "That item is
      offered in a trade."; the item never moves. notes:
- [ ] **Double-spend (ledger 2)**: the offered slot cannot be offered into a second
      window slot; you have only one session at a time. notes:
- [ ] **Coin overdraft (ledger 4)**: offer more coin than your wallet holds →
      refused with "You don't have that much coin." notes:
- [ ] **Stack cap (ledger 5)**: trade a stack that would push the receiver over the
      item's cap → the receiver's placement stays capped, never a 41-stack. notes:
- [ ] **Capacity grief (ledger 6)**: fill the receiver's bags, then commit → refused
      cleanly ("their/your bags cannot hold..."), nothing half-applied, window stays
      open. notes:
- [ ] **Range/state escape (ledger 7)**: open a trade, walk >10 m apart (or one
      party dies / logs out) → the session closes for both with a reason, and every
      locked slot is free again. notes:
- [ ] **Self / busy (ledger 8)**: trying to trade yourself refuses; requesting a
      player already trading refuses quietly to you only. notes:
- [ ] **Enemy/NPC target (ledger 10)**: holding an item and clicking a mob or NPC
      does NOT open a trade (targets only). notes:

## 3 — Persistence / crash safety

- [ ] **Cancel mid-trade** → both windows close, every offered item is exactly where
      it was, nothing consumed. notes:
- [ ] **Relog right after a completed trade** → the received goods and spent/gained
      coin persist (the commit was one transaction). notes:

---

## Result

- Server build (boot line):
- Client build (`/version`):
- Overall:
