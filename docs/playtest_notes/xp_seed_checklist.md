# XP Bar Seed on Login — Playtest Checklist — 2026-07-11

The server now seeds your persisted XP into the character's current level on enter-world, so the
XP bar shows the real value the moment you log in instead of reading `0/X` until the next kill.
Found during the disconnect-flush playtest: the XP was persisting correctly, the client just
wasn't being told its loaded value on login (`ConnectOk` carries level but not XP).

**Server-only change → rebuild + restart the server. NO client re-export, NO DLL rebuild.**

## 1 — The fix
- [x] **Have some XP into your current level** (kill a mob or two so the bar isn't at 0/X), then
      **log out and back in** → the XP bar shows your **real value immediately** on login, not
      `0/X`. notes:
- [x] **No spurious message on login** → logging in does NOT print a "You gained 0 experience"
      or any XP line in the combat log (the seed is silent). notes:

## 2 — Regression: XP still works normally
- [x] **Kill a mob after logging in** → XP line prints and the bar advances from the seeded
      value (not from 0). notes:
- [x] **Level up** → still works; the bar resets into the new level correctly. notes:
- [x] **Die (XP loss)** → the "You lost N experience" line still appears; the bar reflects it. notes:

## Notes / observations
-
