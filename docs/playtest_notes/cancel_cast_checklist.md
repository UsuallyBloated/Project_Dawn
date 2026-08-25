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

- [ ] **Start a long cast (Regrowth), press ESC mid-bar** → "You stop casting.", the bar clears,
      **and the mana returns**. notes:
- [ ] **Start a cast, walk forward mid-bar** → same: cancelled + refunded. notes:
- [ ] **Start a cast, jump** → same. notes:
- [ ] **Let a cast complete normally** → mana stays spent, spell lands. The refund must only
      happen on a cancel. notes:

## 2 — ESC ordering

- [ ] **With a window open AND a cast running, press ESC** → the cast cancels first; the window
      stays open. Second ESC closes the window. notes:
- [ ] **With no cast running** → ESC closes windows / opens options exactly as before. notes:

## 3 — Interrupts and edge cases

- [ ] **Get hit while casting (server interrupt)** → cast fails as before, and the mana bar
      recovers rather than staying down. notes:
- [ ] **Cancel, then immediately re-cast the same spell** → works; no stuck cooldown (the
      cooldown only starts on completion). notes:
- [ ] **Instant-cast spells are unaffected** (no bar, nothing to cancel). notes:

---

## Result

- Client build (`/version`):
- Overall:
