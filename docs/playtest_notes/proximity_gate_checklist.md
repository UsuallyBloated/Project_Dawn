# NPC Proximity Gate Playtest Checklist — 2026-08-25

Verifies the server now refuses vendor / bank / quest turn-in / soul-bind when the player isn't
actually near the right NPC. Closes the Medium exploit from the 2026-08-24 dead-intents audit.

**Build prerequisite: server restart (primary) + a client re-export (cosmetic).** The gate is
entirely server-side and takes effect on restart. The re-export only carries a tiny dialogue tweak
(the Soul Binder line no longer claims success optimistically — the server confirms it now).

**What this is, and isn't.** It's a *backstop against remote abuse*, not a UI. The service range
is 15 m, deliberately looser than the client's 6 m interact gate, so it must **never refuse an
honest player** standing at an NPC. If an ordinary interaction gets refused, that's the bug.

**The exploit it closes:** a modified client could bank its whole inventory from the bottom of a
dungeon one second before dying, so the corpse held nothing and the death penalty was voided. Also
buy/sell and quest turn-in from anywhere.

Diagnostics: `journalctl -u projectdawn -f`; the anchors are `no vendor within range`,
`no banker within range`, `too far from the turn-in NPC`, `no soul binder within range`.

---

## 1 — Honest play is completely unaffected (the row that matters most)

- [ ] **At the town NPCs, buy and sell from Brom** → works exactly as before, no "no merchant"
      message. notes:
- [ ] **Bank deposit / withdraw / exchange at Thalia** → all work as before. notes:
- [ ] **Turn in a quest at its NPC** (Aldric for wolf_threat/rotfang, Brom for
      rat_infestation/gnoll) → completes normally. notes:
- [ ] **Bind at Sister Maelis** → "Your soul is bound to this place." (now sent by the server, not
      claimed by the client). notes:
- [ ] **Walk to the far edge of the plaza and try each again** → still works within ~15 m. The
      gate must not clip normal movement around the town. notes:

## 2 — The gate bites at range (needs GM tooling or a walk)

The honest client won't *let* you interact from far away, so to see the refusal you either walk
well out of town and watch the log, or use the Test Panel to reach across the map. Any of these
that you can trigger:

- [ ] **From well outside town, if you can force a bank/vendor/turn-in**, the log shows the
      matching `no ... within range` line and nothing changes (no coin, no item). notes:
- [ ] **The refusal message appears in chat** ("There is no merchant/banker near you.", or
      "You must return to <NPC>."). notes:

## 3 — Regression

- [ ] **A full quest arc** — accept, kill, turn in at the right NPC — start to finish. notes:
- [ ] **Die, corpse-run, loot your corpse** → the death/corpse path is untouched by this change.
      notes:
- [ ] **No `no ... within range` lines appear during ordinary town play** in the log. notes:

---

## Result

- Server build (`build=` on the boot line):
- Overall:
