# Melee Swing-Rate Limit Playtest Checklist — 2026-07-29

The server now enforces a per-hand minimum interval between swings (no swing timer existed, so a
modified client could spam `Attack` for an attack-speed hack). It derives the equipped weapon's
`weapon_delay`, assumes max haste, and silently drops any same-hand swing that arrives faster than
the floor. A stock client already paces itself and sends an `Attack` only on a landed hit, so this
is invisible to normal play — this playtest is a **regression sweep**: confirm every melee/ranged
mode still swings at full, un-throttled cadence. The exploit path (spamming Attack) needs a modified
client, so it's covered by unit tests (`swing_rate_min_interval_...`, `swing_too_fast_...`) + the log.

**Build prereq: restart the server (release build). No client re-export** — server-only change.

Diagnostic: `server.log` grep `swing-rate limit (too fast)` and `off-hand swing with no off-hand`.
Neither should appear for ANY legit action below. (They only fire for forged / too-fast packets.)

## Setup
- [ ] Restart server (release build)
- [ ] Have weapons to equip (1H, a 2H, a bow, and two 1H for dual-wield) and an enemy to fight

## 1 — Normal melee cadence (regression)
- [ ] **Auto-attack an enemy with a 1H weapon for ~30s** → every swing lands at the normal cadence;
  no swings silently vanish; damage output feels the same as before. notes:
- [ ] **Swap to a slow 2H (e.g. war axe) and fight** → swings land at the slower cadence, none
  dropped. notes:
- [ ] **Fight bare-handed (no weapon)** → fists swing normally, none dropped. notes:

## 2 — Dual-wield (the key false-positive risk)
- [ ] **Equip main + off-hand weapons and auto-attack** → BOTH hands swing at their own cadence;
  neither hand throttles the other; off-hand hits land as before. notes:
- [ ] **Watch for ~30s** → no swing-rate rejections in `server.log` for either hand. notes:

## 3 — Haste (calibration case)
- [ ] **Get a Haste buff (Enchanter Haste, or Bard song) and fight** → the faster hasted cadence is
  fully honored; no hasted swings are dropped. notes:
- [ ] **`server.log` shows NO `swing-rate limit (too fast)` line while hasted.** notes:

## 4 — Ranged (regression)
- [ ] **Equip a bow and auto-fire at range** → shots fire at the bow's cadence, none dropped. notes:

## 5 — Exploit closed (forged spam — expect [-] on a stock client)
- [ ] **Spam Attack far faster than the weapon allows** (needs a modified client) → the server drops
  the excess silently (capped to ~1 swing per floor); `server.log` shows `swing-rate limit (too
  fast)`. notes: (expected `[-]` — stock client can't spam; unit-test + log covered)
- [ ] **Send an off-hand Attack with no off-hand weapon equipped** (modified client) → rejected;
  log shows `off-hand swing with no off-hand weapon`. notes: (expected `[-]`)

## 6 — Known interaction (NOT a bug to fix here)
> A **proc weapon** (e.g. Flamebrand, "Flaming Strike") sends its proc as a second same-hand Attack,
> which the gate now drops. This is expected: pre-change the server resolved that proc Attack as a
> FULL weapon-damage roll (double-hitting), not the authored 25. The proper fix is
> server-authoritative procs (To-Do filed). For now the client still SHOWS the proc number/flash,
> but it does not apply server-side; the base swing is unaffected.
- [ ] **Fight with a proc weapon (Flamebrand)** → base swings land normally; note whether the missing
  proc damage is noticeable/acceptable for now. notes:

## Notes / observations
-
