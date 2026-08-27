# Coin, Stack All & Vendor Narration Playtest Checklist — 2026-08-26

Four items built 2026-08-21 / 08-24 that never got their playtest. **All solo-testable.**
Prerequisites are already met: the server side has been live since the `22ae5b2` deploy, and
the client side (vendor narration) rides the current export.

Diagnostics: `journalctl -u projectdawn -f` on the R720; refusals also arrive in chat.

---

## 1 — The bank breaks a higher coin (deposit AND withdraw)

The four tiers stay independent stacks, but the banker now makes change instead of refusing.

- [ ] **Carry e.g. `1p 5g 5s 75c`, deposit `6s`** → accepted. Wallet shows a gold broken into
      silver (the `9g 95s` pattern minus the deposit), bank gains 6s. Total value unchanged —
      eyeball the totals before/after. notes:
- [ ] **Withdraw silver from a bank holding only gold** → same thing in reverse: the bank
      breaks a gold to pay out. notes:
- [ ] **Ask for more value than you actually have** → still refused, with the refusal line.
      notes:

## 2 — Corpse coin comes back tier by tier

Dying used to normalise your coin (312c returned as 3s 12c — same value, far less weight, so
dying compressed your purse).

- [ ] **Carry a mixed wallet including a big copper stack** (Test Panel can grant coin), note
      the exact per-tier counts, die, loot your corpse → the SAME per-tier counts return.
      312 copper comes back as 312 copper, not 3s 12c. notes:
- [ ] **Encumbrance matches** — you weigh the same after the corpse run as before the death.
      notes:

## 3 — Stack All merges within a container only

- [ ] **Bread (or any stackable) split across main inventory + two pouches** → Stack All:
      partial stacks merge WITHIN main and WITHIN each pouch, but nothing moves between
      containers — the three piles stay in their three homes. notes:
- [ ] **Two partial stacks inside one bag** → Stack All merges them as before. notes:
- [ ] **After Stack All, drag items around freely** → no `source slot empty` rejections in the
      server log (the desync regression canary). notes:

## 4 — The vendor window narrates the request, not the outcome

- [ ] **Buy with deliberately full bags** → the window says "Asked the merchant for X" (no
      price, no quantity claimed as fact), the server's refusal arrives in chat, and no coin is
      charged. notes:
- [ ] **Normal buy** → request line, then the items and coin actually change. notes:
- [ ] **Sell an item** → "Offered X to the merchant." with no locally-computed price; the coin
      that arrives is the server's number. notes:

---

## Result

- Client build (`/version`):
- Server build (boot line):
- Overall:
