# Bag Space & Group Bars Playtest Checklist — 2026-09-09

Two server fixes built remotely, riding the next R720 redeploy (with the two cursor retest
rows from `cursor_slice15_checklist.md`). No client change and no protocol bump — your
existing export works.

**Build prerequisite: server `01dd8fa` on the R720.**

---

## 1 — Grants spill into bags (solo)

- [ ] **Fill your base slots, carry a pouch with free space, buy from Brom** → the purchase
      lands INSIDE the pouch (no more "Your bags are full" with empty pouch slots). notes:
- [ ] **Same setup, loot a kill** → the loot lands in the pouch. notes:
- [ ] **Same setup, withdraw an item from the bank** → into the pouch. notes:
- [ ] **A partial stack in a pouch tops up first** — with 5 bread in a pouch (cap 20) and base
      full, buying more bread fills the pouch stack before opening a new one. notes:
- [ ] **Buying a BAG with a full base** → still refused ("Your bags are full") — a bag never
      lands inside a bag, so there is genuinely nowhere for it. notes:
- [ ] **Quest turn-in with only pouch space free** → the reward is accepted and lands in the
      pouch (the capacity pre-check now probes the same placer). notes:

## 2 — Group bars fill on sight (needs the second seat)

- [x] **Form a group while both players are idle at full HP** → both panels show full
      HP/MP/STA bars IMMEDIATELY — no waiting for someone to take a hit. notes:
      PASS 09-27 (two-boxed session, gid=1, both fresh characters idle at
      full): user confirms both members' panels showed full HP/MP/stamina
      the moment the group formed. First two-seat exercise of the 01dd8fa
      roster fan; evidence cross-recorded on phase4_content_checklist §6.
- [ ] **A member leaves or is kicked** → the survivors' panels stay correct (rows refill on
      the roster change). notes: unobserved 09-27 — both seats disconnected
      2 s apart, so no survivor moment existed. Ten-second check next time
      two seats are up: one leaves, the other watches their panel.

---

## Result

- Server build (boot line):
- Client build (`/version`):
- Overall:
