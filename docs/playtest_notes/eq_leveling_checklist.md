# EverQuest-Authentic Leveling — Playtest Checklist — 2026-06-26

This replaces the geometric ×1.25 curve with the **classic EverQuest leveling model** (research:
`docs/design/everquest_xp_curve_reference.md`). Two coupled parts:

- **Per-level cost is CUBIC + hell levels:** `total XP to complete L = L³ × 1000 × hell_mod(L)`; the band is
  the difference. The hell_mod spikes at bracket boundaries (30/35/40/45, then every level 51-60) create the
  classic **hell levels**. Reproduces the P99 table exactly (band(30)=5,311,000, band(60)=53,463,000).
- **Per-kill reward is QUADRATIC:** `kill XP = mob_level² × ZEM` (ZEM 75 baseline). Pairing a quadratic reward
  with a cubic cost keeps kills-per-level roughly constant (~11) on normal levels, and lets the hell levels
  spike. Per-kill no longer reads a flat per-mob constant, it derives from the mob's level.

**The numbers (even-con kill, normal zone):**

| Level | Band (XP to clear) | Kill XP | Kills/level | |
|---|---|---|---|---|
| 1 | 1,000 | 262 | ~4 | |
| 5 | 61,000 | 6,562 | ~9 | |
| 10 | 271,000 | 26,250 | ~10 | |
| 29 | 2,437,000 | 220,762 | ~11 | last "normal" level |
| **30** | **5,311,000** | 236,250 | **~22** | **hell level** |
| **40** | **12,017,200** | 420,000 | **~29** | **hell level** |
| 50 | 10,291,400 | 656,250 | ~16 | |
| **51** | **23,976,500** | 682,762 | **~35** | **hell level** |
| **54** | **46,090,700** | 765,450 | **~60** | **hell level** |
| **59** | **89,334,599** | 913,762 | **~98** | **triple hell (the famous one)** |
| 60 | 53,463,000 | 945,000 | ~57 | (note: band(59) > band(60)) |

**Build prerequisites (only two — wire unchanged):**
- Re-export / reload Project_Dawn (`player_stats.gd` reloads). **No `gdext_net.dll` rebuild** (still PD_W0022;
  xp stays i32 on the wire).
- Restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:/Projects/server`. Capture
  `... | Tee-Object server.log`.

> **EXISTING CHARACTERS auto-reconcile on login** (level clamped to 60, band recomputed on the cubic curve,
> stored xp clamped into it). A fresh character is the cleanest way to feel the new pacing from level 1.

> **QUEST XP is NOT re-tuned here.** `data/quest_definitions.gd` `xp_reward` values are still old-curve
> numbers and now under-reward badly (bands are 10-1000× bigger). That's a separate balance pass; ignore quest
> XP weirdness for this test.

Diagnostics (server.log): `level change` (from/to), the `quest xp grant` line. Kill XP is the `XpGained` feed.

## Setup
- [x] Re-export client + reload editor; restart server. **Make a fresh character.** notes:

## 1 — Cubic pacing (the bar)
- [x] Fresh char: "to next" is **1,000 at L1, 7,000 at L2, 19,000 at L3** (cubic deltas), not the old
  100/125/156. notes:
- [x] Use Test Panel **"Level Up"** to climb. Bands grow fast: ~271K at L10, ~1.1M at L20, ~2.4M at L29. notes:

## 2 — Per-kill scales with mob level (mob_level²)
- [x] Kill a **low-level** mob and a **higher-level** mob; the higher one awards **much** more XP (it scales
  with mob_level², so a L10 mob ≈ 100× a L1 mob, not a flat constant). notes:
- [x] On a normal even-con level, leveling takes **~10-11 kills** (not 1, not hundreds). notes: I really appreciate that killing a level 10 enemy as a level 10 character is a challenge and likely not possible by a solo cleric.  I think it should take quite a few more than 10-11 kills to level.

## 3 — Hell levels (the EQ texture)
- [x] Reaching **level 30** the band jumps to ~5.3M (kills/level roughly **doubles** vs level 29) → the first
  hell level. notes:
- [x] If you can get high (use "Level Up"): **51, 54, and especially 59** are brutal walls (level 59 ≈ 98
  kills/level, the classic triple-hell), then **60** is *easier* than 59 (band(59) > band(60)). notes:

## 4 — Level cap + death + res (regressions)
- [x] Leveling still **stops at 60** ("Level Up" past the 50s caps at 60). notes:
- [x] A **level 5+** death loses **5% of the (now large) band**; the corpse + Cleric/Paladin res refund a
  sane % of that. De-level still **floors at level 5**. notes:

## 5 — Existing-character reconciliation
- [-] Log in an **old character** (saved on a prior curve). It loads at its level (≤60) with a **sane cubic
  band** for that level, not a stale/huge number. notes:  Deleted old characters and started fresh.

## 6 — Client/server agreement + de-level-to-1 watch
- [x] The client XP bar's "to next" **matches** the server at every level (cubic lockstep). notes: Appears to work.
- [x] No character ever drops to **level 1** on death/relog. If it happens, capture before/after level +
  server.log (still a separate, unfixed client-desync suspect). notes: I didnt encounter this error.

## Notes / observations
- Great test.  Great work.
