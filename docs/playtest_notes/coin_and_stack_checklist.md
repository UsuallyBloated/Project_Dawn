# Coin, Stack All & Vendor Narration Playtest Checklist — 2026-08-26

Four items built 2026-08-21 / 08-24 that never got their playtest. **All solo-testable.**
Prerequisites are already met: the server side has been live since the `22ae5b2` deploy, and
the client side (vendor narration) rides the current export.

Diagnostics: `journalctl -u projectdawn -f` on the R720; refusals also arrive in chat.

---

## 1 — The bank breaks a higher coin (deposit AND withdraw)

The four tiers stay independent stacks, but the banker now makes change instead of refusing.

- [x] **Carry e.g. `1p 5g 5s 75c`, deposit `6s`** → accepted. Wallet shows a gold broken into
      silver (the `9g 95s` pattern minus the deposit), bank gains 6s. Total value unchanged —
      eyeball the totals before/after. notes:
- [x] **Withdraw silver from a bank holding only gold** → same thing in reverse: the bank
      breaks a gold to pay out. notes:
- [x] **Ask for more value than you actually have** → still refused, with the refusal line.
      notes:

## 2 — Corpse coin comes back tier by tier

Dying used to normalise your coin (312c returned as 3s 12c — same value, far less weight, so
dying compressed your purse).

- [x] **Carry a mixed wallet including a big copper stack** (Test Panel can grant coin), note
      the exact per-tier counts, die, loot your corpse → the SAME per-tier counts return.
      312 copper comes back as 312 copper, not 3s 12c. notes:
- [x] **Encumbrance matches** — you weigh the same after the corpse run as before the death.
      notes:

## 3 — Stack All merges within a container only

- [x] **Bread (or any stackable) split across main inventory + two pouches** → Stack All:
      partial stacks merge WITHIN main and WITHIN each pouch, but nothing moves between
      containers — the three piles stay in their three homes. notes:
- [x] **Two partial stacks inside one bag** → Stack All merges them as before. notes:
- [x] **After Stack All, drag items around freely** → no `source slot empty` rejections in the
      server log (the desync regression canary). notes:

## 4 — The vendor window narrates the request, not the outcome

- [x] **Buy with deliberately full bags** → the window says "Asked the merchant for X" (no
      price, no quantity claimed as fact), the server's refusal arrives in chat, and no coin is
      charged. notes:  Appears as though the system is only looking at the main inventory, and not the potential space in the Small Pouches that are in the inventory.  Player is receiving "Your bags are full" error in chat window even though they have empty space in both Small Pouches they currently have in their inventory.  
- [x] **Normal buy** → request line, then the items and coin actually change. notes:
- [x] **Sell an item** → "Offered X to the merchant." with no locally-computed price; the coin
      that arrives is the server's number. notes:

---

## Result

- Client build (`/version`): d1aecd6-dirty, exported 2026-08-27T12:10 UTC, gdext 5918f106
- Server build (boot line): 9b320c8, dev_cmds=false
- Overall: PASS, every row — four items ticked 2026-08-27 (bank coin breaking, corpse coin
  tiers, Stack All container scope, vendor narration). One new finding from the full-bags row:
  purchases only consider base inventory slots, never bag space ("Buying and granting ignore
  bag space" in the To-Do; log shows three `BuyItem rejected — inventory full` with two empty
  pouches carried).
