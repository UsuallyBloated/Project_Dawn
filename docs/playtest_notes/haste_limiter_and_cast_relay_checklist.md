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
- [ ] Server on the R720 at the build (boot line `build=`, `dev_cmds=false`); no export needed. notes:
- [ ] Two seats for §2 (two-boxing works). notes:

## 1 — The swing limit under honest play (one seat, a GM)
No row here should produce a `swing-rate limit` line in the journal; one is a finding, with the
weapon, the haste and the moment.

- [ ] **Bare-handed, auto-attack a camp mob for a minute** → every swing shows a hit number or "You miss"; no rejection line for your char id. notes:
- [ ] **Wield a slow weapon (`/give Bonecrusher's War Axe`, delay 3.2) and fight a minute** → the same. notes:
- [ ] **Swap to a fast weapon (a Cracked Wooden Club) mid-fight, then back to the axe, without stopping** → no swing dropped at either swap. (The server judges each swing by the weapon worn at that swing; the client re-times its swing on a swap from the next export. On the current export a swap to a slower weapon inside its old interval may drop one swing: note it if seen.) notes:
- [ ] **A Warrior 15 with two clubs** → both hands swing all fight; no rejection line. notes:
- [ ] **Under haste: an Enchanter 16 casts Haste on itself (or a Bard sings Wanderer's Chord beside you), then swing bare-handed** → the swings come faster and every one is answered; no rejection line. notes:
- [ ] **Let the haste run out while still swinging** (Wanderer's Chord: `/stopsong`, keep swinging 20 s; the effect ends 12 s after the last pulse) → no rejection line at the edge. notes:
- [ ] **Toggle auto-attack off and on, and switch targets, mid-fight** → no rejection line (the client restarts its interval on both). notes:

## 2 — The relays (two seats: A casts, B watches)
- [ ] **A casts Healing Light (1.2 s) on itself** → B sees A's cast bar run its 1.2 s and end. notes:
- [ ] **A starts a cast and cancels it (ESC or a step)** → B's bar for A ends at once. notes:
- [ ] **A casts a spell the server does not have (one of the seven zone ports in a Wizard's or Druid's book)** → A gets the unknown-spell refusal as before; B sees no bar at all. notes:
- [ ] **Optional: A casts Gate (5 s) and B logs in during it** → B sees the bar with the time that is left (the late-joiner seed reads the server's cast time). notes:

## 3 — Regression
- [ ] **A fizzle, an interrupt by a hit, the global cooldown refusal** → unchanged: "Your spell fizzles!", "interrupted (hit during cast)" and "You cannot cast again yet." arrive as before. notes:
- [ ] **A Bard twists two songs** → B sees each 3 s bar in turn. notes:

## Notes / observations
-
