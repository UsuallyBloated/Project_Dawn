# The Haste-Aware Swing Limit and the Cast Relays — 2026-10-30

Two server-only items from Phase 4 of the housekeeping audit (the client/server line), built
the night of 10-30 on the deploy branch; a redeploy, no export. **The swing-rate limit reads
your haste**: the server used to let everyone swing as if fully hasted (a modified client could
swing at twice an honest unhasted rate); it now holds each hand to the weapon's own delay at
the haste the server holds for you, less a grace for jitter, and the pacing of the last
accepted swing carries into the next, so a Haste that runs out, or a slower weapon swapped in,
between two swings costs nothing. **The cast relays carry the server's numbers**: what other
players see of your cast (the bar's length and the spell's name) and what ends it used to be
whatever your client sent; now only a spell the server knows is relayed, under its own name and
at its own cast time, and a cancel carries one fixed word.

| Thing | Where | Notes |
|---|---|---|
| A dropped swing | `journalctl -u projectdawn \| grep "swing-rate limit"` | `Attack rejected — swing-rate limit (too fast)` with `haste=` and `min_interval=`; an honest client should never produce one |
| The gates | fists 2.0 s, a 3.2 s axe | unhasted: 1.65 s and 2.85 s between same-hand swings; under Haste (30%): 1.05 s and 1.89 s; the off hand at 1.5 times the delay |
| A relayed bar | the other seat's screen | the bar runs the spell's own cast time, whatever the caster's client said |

## Setup
- [x] Server on the R720 at the build (boot line `build=`, `dev_cmds=false`); no export needed. notes:
- [x] Two seats for §2 (two-boxing works). notes:

## 1 — The swing limit under honest play (one seat, a GM)
No row here should produce a `swing-rate limit` line in the journal; one is a finding, with the
weapon, the haste and the moment.

- [x] **Bare-handed, auto-attack a camp mob for a minute** → every swing shows a hit number or "You miss"; no rejection line for your char id. notes:
- [x] **Wield a slow weapon (`/give Bonecrusher's War Axe`, delay 3.2) and fight a minute** → the same. notes:
- [x] **Swap to a fast weapon (a Cracked Wooden Club) mid-fight, then back to the axe, without stopping** → no swing dropped at either swap. (The server judges each swing by the weapon worn at that swing; the client re-times its swing on a swap from the next export. On the current export a swap to a slower weapon inside its old interval may drop one swing: note it if seen.) notes: (review 11-01, journal: WAROI (28) wore the axe from 21:47:37 and the club from 21:49:36, fighting through both with no rejection. The swap back to the axe has no `EquipItem applied` line, so only one swap ran; the slow-weapon direction is the one the caveat is about.)
- [x] **A Warrior 15 with two clubs** → both hands swing all fight; no rejection line. notes:
- [x] **Under haste: an Enchanter 16 casts Haste on itself (or a Bard sings Wanderer's Chord beside you), then swing bare-handed** → the swings come faster and every one is answered; no rejection line. notes:  Used haste on warrior level 2 (review 11-01, journal: `ALLY buff applied caster=29 target=28 spell=Haste` at 21:53:37, then WAROI fought from 21:53:46 to 22:01:57 with no rejection line.)
- [x] **Let the haste run out while still swinging** (Wanderer's Chord: `/stopsong`, keep swinging 20 s; the effect ends 12 s after the last pulse) → no rejection line at the edge. notes:  Not while attacking but i tested with and without haste. (review 11-01: **FINDING, one honest swing dropped.** The journal's only rejection: `22:07:11 Attack rejected — swing-rate limit (too fast) attacker=28 weapon_delay=2.0 haste=-0.0 min_interval=1.65`. WAROI's Haste (from gant at 21:53:37, 660 s) ran out at about 22:04:37, between fights; the next fight began about 22:07:08. Cause, measured with a headless Godot probe the same day: a Timer applies a `wait_time` changed inside its own timeout handler one gap LATE (fires at 1.4 s, again 1.4 s later, only then 2.0). So the client's gap between swings N and N+1 is the interval set at swing N-1, and a fresh `start()` runs the interval set at the last swing before the stop. WAROI's first swing of the new fight came on the stale hasted 1.4 s and was accepted (it re-stamped the carried haste to 0), and the second came 1.4 s later on the same stale interval, judged unhasted. The server rule carries one swing's haste; the client lags by two. The fix proposed: carry the last two. This row's mid-fight version would drop one swing the same way. **Fix BUILT 2026-11-01 night, pending the redeploy** (server `d40e505`): the server carries the last two swings' haste, and counts an expired Haste for one second, the round trip the client hears of it in. Replay this row as written after the redeploy. **Deployed 2026-11-02 04:20 UTC**, boot line `build="d40e505" dev_cmds=false`.)
- [ ] **Row 6 again, on `d40e505` (deployed 2026-11-02): keep swinging while a Haste or Wanderer's Chord runs out mid-fight, then let a Haste end between fights and start the next fight at once** → no `swing-rate limit` line in the journal for either. notes:
- [x] **Toggle auto-attack off and on, and switch targets, mid-fight** → no rejection line (the client restarts its interval on both). notes:

## 2 — The relays (two seats: A casts, B watches)
- [x] **A casts Healing Light (1.2 s) on itself** → B sees A's cast bar run its 1.2 s and end. notes:
- [x] **A starts a cast and cancels it (ESC or a step)** → B's bar for A ends at once. notes:
- [x] **A casts a spell the server does not have (one of the seven zone ports in a Wizard's or Druid's book)** → A gets the unknown-spell refusal as before; B sees no bar at all. notes:
- [x] **Optional: A casts Gate (5 s) and B logs in during it** → B sees the bar with the time that is left (the late-joiner seed reads the server's cast time). notes:  B did not see a cast bar on A when be logged in during A casting Gate (review 11-01: inconclusive, not yet a bug. The journal has B (WAROI) reconnecting at 22:15:00 and A's Gate landing at 22:15:16, so the 5 s bar ran from about 22:15:11, likely after B had finished loading, which makes it the ordinary relay, not the late-joiner seed. A peer's bar shows only in the target frame, and only while B has A targeted, so B had to target A inside those five seconds. An integration test settles the server half without play; proposed with the fix. **Server half settled 2026-11-01 night** (server `d40e505`, test `a_late_joiner_sees_a_cast_already_under_way`: a player entering mid-Gate is sent A's bar with the time left on the server's 5 s; the test fails when the seed reads the client's number). What is left is the screen: B targets A while A's bar runs.)

## 3 — Regression
- [x] **A fizzle, an interrupt by a hit, the global cooldown refusal** → unchanged: "Your spell fizzles!", "interrupted (hit during cast)" and "You cannot cast again yet." arrive as before. notes:
- [x] **A Bard twists two songs** → B sees each 3 s bar in turn. notes:

## Notes / observations
- **Review 11-01, from the journal (21:34 to 22:19 UTC; WAROI 28, gant 29, WROIORI 30, CHNU 31, POTSSS 32, GUFG 33).** Every row passes but one finding: the 22:07:11 rejection (row 6's note). The two-club Warrior 16 (WROIORI) fought three skeletons from 22:06:15 with no rejection; Healing Light landed on self at 22:09:08 and 22:09:20 and on WAROI at 22:09:42; the Wizard fizzled Blizzard at 22:16:48 (`burned=7.5`) and was interrupted five times with mana charged (`mana_charged=14.25`, `3.0`, `0.93`, `38.05`, `27.84`, `5.25`); the Bard twisted Poet's Mending, Wanderer's Chord and Selos' Melody from 22:18:52. No unknown-spell line: the client refuses a spell the server does not know before sending it. The global cooldown refusal is the client's own line, so no server line is expected. `player link` read 50 ms for every seat throughout.
- **To close the sheet:** the fix for the finding (built 11-01 night, server `d40e505`; the redeploy next), then row 6 played as written (swing through a Haste or Wanderer's Chord running out mid-fight, and start a new fight right after one ends) with no rejection line.
