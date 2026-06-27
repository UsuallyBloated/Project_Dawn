# XP Curve Flatten + Level Cap — Playtest Checklist — 2026-06-26

> **SUPERSEDED (same day):** this tested the interim ×1.25 geometric flatten, which passed. EQ research then
> showed a cubic curve is both more authentic and gentler at the high end, so the project went full
> EverQuest-cubic. The shipped curve + its playtest are in `eq_leveling_checklist.md`. Kept as a record of the
> interim pass; do **not** read the ×1.25 numbers below as the live curve.

The XP curve was geometric **×1.5/level stored as i32**, which **saturated at i32::MAX (~2.1B) around level
43** — every level from 43 to the cap needed the same ~2.1B, and a high-level death "lost" ~107M XP (the giant
res-refund numbers you saw). This change makes the curve **×1.25/level** (gentler, classic-feeling), caps the
band so it can never overflow i32, enforces the **level cap at 60**, and fixes an XP-add overflow.

**What changed (no wire change, so no DLL rebuild):**
- Curve growth **1.5 → 1.25**. Bands now: L1=100, L5=243, L10=737, L20≈6,851, L40≈594K, **L60≈51.5M** (was
  2.1B). Numbers stay readable; no more billions/trillions.
- **Leveling stops at 60** (`MAX_LEVEL`). The old curve capped leveling by accident (its band hit i32::MAX at
  ~43 so XP could never reach it); the gentler curve removes that accident, so the cap is now explicit.
- XP add is now `saturating_add` (a huge quest grant near a full band can't overflow i32 into negative).
- Client + server compute the band in **f64** so they agree byte-for-byte at every level.

**Build prerequisites (only two — the wire is unchanged):**
- Re-export / reload Project_Dawn so `player_stats.gd` reloads. **No `gdext_net.dll` rebuild needed** (still
  PD_W0022; xp stays i32 on the wire).
- Restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:/Projects/server`. Capture
  `... | Tee-Object server.log`.

> **EXISTING CHARACTERS auto-reconcile on login.** A char saved on the OLD ×1.5 curve (FERT, Tin, pockets in
> your world.db) had a stale band — FERT's was literally `i32::MAX` (~2.1B). `load_character` now **clamps the
> level to 60, recomputes the band on the new curve, and clamps stored xp into it** the instant they log in
> (then re-persists the fixed values). So they load with a sane bar, NOT the old giant numbers, and a death
> charges 5% of the *new* band. No fresh character required — though one is still the cleanest way to watch the
> new pacing from level 1.

> **BALANCE NOTE (not tested here, flagged for later):** mob kill-XP and quest XP rewards are authored
> constants tuned to the OLD curve, so against the new (smaller) bands they level you **faster** (e.g. a L6 mob
> is ~5 kills/level now vs ~12 before; the rotfang quest clears ~2.5 levels at L5). Nothing's broken — it's a
> pacing shift that makes testing quicker. A mob/quest XP re-tune is a separate balance pass when you want it.

Diagnostics (server.log): `level change` (from/to), `Xp` lines. The de-level cascade still logs each step.

## Setup
- [x] Re-export client + reload editor; restart server. Optionally **make a fresh character**. notes:

## 1 — New pacing (gentler, readable numbers)
- [x] On a fresh char, the XP bar's "to next" is **100 at L1, 125 at L2, 156 at L3** (was 100 / 150 / 225) → the
  new ×1.25 curve. notes:
- [x] Climb with the Test Panel **"Level Up"** button (one click = one level). Around **level 20** the band is
  ~**6,851**, at **level 40** ~**594K** → no billions, no saturation. notes:

## 2 — Level cap at 60
- [x] Keep clicking **"Level Up"** past the 50s → leveling **stops at 60**. The bar sits full and further clicks
  do **not** push to 61+. notes:
- [x] At level 60 the "to next" band is ~**51.5M** (a real number, not i32::MAX / ~2.1B). notes:

## 3 — Death penalty + resurrection still correct (Slice 3 regression)
- [x] A **level 5+** char dies and loses **5% of the new band** (e.g. at L20, ~5% of 6,851 ≈ **342**, not
  millions). A corpse is left. notes:
- [x] A Cleric/Paladin **resurrects** that corpse → the refund is a sane **% of the (now small) lost XP** (e.g.
  25% of 342 ≈ 85), **not** tens of millions. The teleport-to-corpse still works. notes:
- [x] **De-level floor:** a death still **cannot drop a character below level 5**. notes:

## 4 — Client/server agreement
- [x] The client XP bar's "to next" **matches** what the server thinks at every level (no number desync as you
  level up / die). notes: I'm not sure how to confirm.  Things appear smooth though, for what ever that is worth.

## 5 — Existing-character reconciliation (your old saves)
- [-] Log in an **old high-level char** (e.g. FERT, was level 49 with band ≈ i32::MAX). It loads at its level
  (≤60) with a **sane "to next"** (tens of millions max), **not** ~2.1B. notes: I didnt try the old characters, just deleted them and started new characters.
- [x] That char **dies** → the penalty is **5% of the new band** (a real number), not ~107M; the corpse's res
  refund is correspondingly sane. notes:

## 6 — Watch for the de-level-to-1 (separate, not-yet-fixed issue)
- [x] If a character ever shows **level 1** after a death/relog, capture the **before/after level + the
  server.log line**. (We root-caused this as a *client-side level desync*, NOT the death penalty — the server
  floors at 5 — but we don't have a clean repro yet. A capture here would give us one.) notes: I did not encounter this issue at all during my play test. 

## Notes / observations
-  I have another Claude session researching the original EverQuest level-flow.  We will be adjusting what we tested here today. thank you and great work.
