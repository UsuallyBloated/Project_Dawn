# Per-Character Hotbar & Spell Bar Playtest Checklist — 2026-08-26

Verifies the fix for the hotbar bleed (found 2026-08-26: skills placed on the Warrior's hotbar
appeared on the Monk's). Both stores were one global file shared by every character on the
machine; each character now owns their own save (`social_hotkeys_c<id>.json` /
`spell_bar_c<id>.json`), loaded when that character enters the world. The audit found the
**memorized spell bar had the same disease**, so it got the same fix in the same pass.

**Build prerequisite: client re-export only.**

**Read this before calling a row failed:** the very first login of each character after the
update shows the OLD shared layout one time. That is the seed — it exists so nobody's current
bars vanish in the migration. The fix is proven by what happens *after* you edit: changes made
on one character must never appear on another again.

Headless proof already ran green (two simulated characters: isolation, persistence, and the
legacy seed files never written). This playtest is the eyes-on confirmation.

---

## 1 — Hotbar isolation

- [x] **Log in the Warrior** → his bars show what they showed before the update (the seed).
      notes:
- [x] **Change something on the Warrior** — place a skill from the book's Skills tab, clear a
      slot, whatever. Log out. notes:
- [x] **Log in the Monk** → the Warrior's change is NOT there. (First Monk login still shows the
      old shared layout — that's the seed, see above.) notes:
- [x] **Rearrange the Monk's bars** — remove what doesn't belong, add Monk skills. Log out.
      notes:
- [x] **Back to the Warrior** → his layout is exactly as he left it; none of the Monk's edits
      appear. notes:
- [x] **Back to the Monk** → his rearranged layout persisted. notes:

## 2 — Memorized spell bar isolation

- [x] **On Chumby (Druid), note the memorized spell bar**, change one memorized slot, log out.
      notes:
- [x] **Log in a different character** → their spell bar is their own (seed on first login),
      and Chumby's change is not on it. notes:
- [x] **Back to Chumby** → the memorized bar is exactly as she left it. notes:

## 3 — Macro library

- [x] **Create a new social/macro on character A** (post-update). Log out, log in character B →
      the new macro is NOT in B's library. notes: Macro made on character "Funk", logged out, created Zoltan, social macro made by "Funk" is not visible to Zoltan.  While we are in here though, there is a "PATK" social macro that is in every character's default social macro list.  Can we remove that?  Let me know if that doesn't make sense.

## 4 — Regression

- [x] **Pickup-and-place still works** — book Skills tab, click skill, click empty slot, ESC
      cancels. notes: When a player drops an item on the ground
- [x] **Hotbar bank switching** still works and each character keeps their own bank contents.
      notes:

---

## Result

- Client build (`/version`): d1aecd6-dirty, exported 2026-08-27T12:10 UTC, gdext 5918f106
- Overall: PASS, every row — isolation both directions, per-character persistence, memorized
  bar isolated, macro library isolated (Funk to Zoltan). Item ticked 2026-08-27. The "PATK"
  macro seen everywhere was legacy user data riding the seed (a June "/pet attack" macro), not
  a code default — removed from the legacy file and all seven per-character files same day.
  One loose end: the note on the pickup-and-place row cuts off mid-sentence ("When a player
  drops an item on the ground") — finish the thought next session.
