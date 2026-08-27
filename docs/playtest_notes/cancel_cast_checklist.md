# Cast Cancel Playtest Checklist — 2026-08-25

Verifies the new deliberate cast-cancel: **moving or pressing ESC aborts a cast and refunds the
mana.** Until now no player-facing cancel existed at all — walking away mid-cast just ate a
server-side "moved during cast" rejection with the mana bar already down.

**Build prerequisite: client re-export only** (rides with the proximity-gate tweak and the skill
guards — one export carries all three).

**The mana rule, made explicit:** mana is only consumed by a *completed* cast. The client spends
it optimistically when the bar starts; the server only deducts when the finished cast arrives. So
every cancel path — movement, ESC, even a server interrupt — refunds the client's optimistic
spend, because nothing was ever truly taken. (Classic EQ made interrupts eat the mana; doing that
here would be a server design change — deduct at CastStart — noted in the To-Do, not decided.)

---

## 1 — The cancel works

- [x] **Start a long cast (Regrowth), press ESC mid-bar** → "You stop casting.", the bar clears,
      **and the mana returns**. notes:  It appears as though when the player cancels the spell,  the mana is refunded, then it immediately consumed the mana again
      [Triage 2026-08-26: the chat log shows the cancel was followed by a *completed* Regrowth
      ("You feel the effects" + "You cast" + an Alteration skill-up — lines only a finished cast
      produces), so the second dip was the immediate re-cast's own spend at bar-start, which is
      correct. The refund itself worked. One 15-second re-check next session: cancel and touch
      NOTHING — the bar must stay refunded.]
      [Re-check DONE 2026-08-27: plump cast Reclaim Soul on FIGHTME's corpse, ESC mid-bar,
      "You stop casting.", 20 seconds untouched — mana never re-consumed, watched on BOTH
      group displays. The refund holds. Closed.]
- [x] **Start a cast, walk forward mid-bar** → same: cancelled + refunded. notes:
- [x] **Start a cast, jump** → same. notes:
- [x] **Let a cast complete normally** → mana stays spent, spell lands. The refund must only
      happen on a cancel. notes:

## 2 — ESC ordering

- [x] **With a window open AND a cast running, press ESC** → the cast cancels first; the window
      stays open. Second ESC closes the window. notes:
- [x] **With no cast running** → ESC closes windows / opens options exactly as before. notes:

## 3 — Interrupts and edge cases

- [x] **Get hit while casting (server interrupt)** → cast fails as before, and the mana bar
      recovers rather than staying down. notes:  Please look at the logs for this.  I'm not sure if I was getting hit while casting.
      [Checked 2026-08-26: zero `interrupted (hit during cast)` lines anywhere in the server log,
      so no interrupt ever fired — either never hit mid-bar or the Channeling roll survived every
      hit. Row unexercised, carried.]
      [EXERCISED 2026-08-27 21:37:03: `cast interrupted by incoming damage caster=4
      spell=Reclaim Soul` — the Track 19A on-hit roll fired for real during the res attempt.
      The re-cast 28 seconds later completed and the offer/accept flow ran clean; the tester
      was actively watching plump's mana on both group displays through this session and
      reported no wrong consumption.]
- [x] **Cancel, then immediately re-cast the same spell** → works; no stuck cooldown (the
      cooldown only starts on completion). notes:
- [x] **Instant-cast spells are unaffected** (no bar, nothing to cancel). notes:

---

## Result

- Client build (`/version`): c697cde-dirty, exported 2026-08-26T21:50 UTC, gdext 5918f106
- Overall: PASS with two carries — the hit-interrupt row was never exercised (no interrupt in
  the log), and the §1.1 mana observation triaged as the re-cast's own spend (see note). One
  cancel-and-wait re-check stands between this and the tick.
  **2026-08-27: both carries closed** — the deliberate cancel-and-wait ran clean (20 s, no
  re-consume, both group displays), and the server interrupt fired in the wild at 21:37:03.
  Full PASS; item ticked.
