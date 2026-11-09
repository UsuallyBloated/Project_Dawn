# Remote Facing Playtest Checklist — 2026-10-27

Other players now turn on your screen. Your client sends its body's facing with every movement
packet (the way EQ and WoW do it), the server stores it and relays it in the position stream it
already sent, and each other client turns that body to match. Cosmetic only: the server reads
the facing into nothing. **Rides the next bump day (PD_W0029)**: needs the server redeployed
from the merged `feat/facing` AND the export with the rebuilt `gdext_net.dll`. Two seats.

| Rule | What happens |
|---|---|
| A turns in place (right-drag) | B sees A's body turn |
| A strafes or backs up | B sees A keep facing forward while sliding sideways or backwards |
| A logs out facing east, logs in | A faces east on both screens (the facing persists with the position) |
| A forged non-finite facing | dropped whole; a huge one is wrapped into a normal angle |

Diagnostics: there is no log line for a facing (it rides every Move); a body that never turns
with the DLL check green means the server build predates PD_W0029.

> **Run through `bump_build_master_checklist.md` (2026-11-06):** this sheet's rows are in the
> master in sitting order, each tagged `R<section>.<row>` (`RS.n` for Setup). Fill the master;
> the marks are copied back here.

## Setup
- [x] Server on the R720 from the merged bump (boot line `build=`, `dev_cmds=false`). notes: [the 11-05 deploy's boot line, `build="267065f" dev_cmds=false`, no restart since.]
- [ ] Both seats on the bump export; `tools/check_wire_layer.gd` green on its checkout. notes:

## 1 — Turning
- [x] **B watches A; A right-drags to turn in place** → B sees A's body turn smoothly to the new facing, no slide, no snap. notes: PASS (11-09, master O2.1 / R1.1).
- [x] **A runs a circle** → B sees A face the way it runs throughout. notes: PASS (11-09, master R1.2).
- [x] **A strafes left and right** → B sees A face forward while sliding. notes: PASS (11-09, master R1.3).
- [x] **A walks backwards** → B sees A face forward while backing up. notes: PASS (11-09, master R1.4).
- [x] **A left-drags (camera orbit only)** → B sees A's body stay put: the camera is not the body. notes: PASS (11-09, master R1.5).

## 2 — Persistence and spawn
- [x] **A turns to face B, logs out, logs back in** → A faces the same way on both screens straight after the login. notes: Marked PASS by the user (11-09, master R2.1) with: "character appears to login facing the correct direction then is suddenly rotated a small amount. Can you look into this?" [Read in the code the same day: the client's own body never reads its facing back from the server. It logs in facing the scene's default and its first Move (sent every 50 ms, input or not) overwrites the facing the server saved, so the watcher sees the saved facing for a tick, then the turn, and the player's own screen never showed the saved facing at all. Older than the bump (the facing's first build). A client fix is filed under the facing entry: seed the body's facing from the first server Position and send no Move before it.]
- [x] **B logs in while A stands facing away** → A's body faces away on B's screen from the first frame. notes: PASS (11-09, master R2.2).
- [x] **GM: Test Panel spawn a mob** → it lands in front of where you actually face (the stale yaw used to put it in front of your login facing). notes: PASS (11-06, master R2.3).

## 3 — Regression
- [x] **Running, jumping, the jump relay, sitting** → unchanged. notes: PASS (11-09, master F9.1 / R3.1, on the hills).
- [x] **`/loc` before and after a minute of turning in place** → the position reads the same: turning moves nobody. notes: PASS (11-09, master R3.2).

## Notes / observations
-
