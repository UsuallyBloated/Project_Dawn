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

## Setup
- [ ] Server on the R720 from the merged bump (boot line `build=`, `dev_cmds=false`). notes:
- [ ] Both seats on the bump export; `tools/check_wire_layer.gd` green on its checkout. notes:

## 1 — Turning
- [ ] **B watches A; A right-drags to turn in place** → B sees A's body turn smoothly to the new facing, no slide, no snap. notes:
- [ ] **A runs a circle** → B sees A face the way it runs throughout. notes:
- [ ] **A strafes left and right** → B sees A face forward while sliding. notes:
- [ ] **A walks backwards** → B sees A face forward while backing up. notes:
- [ ] **A left-drags (camera orbit only)** → B sees A's body stay put: the camera is not the body. notes:

## 2 — Persistence and spawn
- [ ] **A turns to face B, logs out, logs back in** → A faces the same way on both screens straight after the login. notes:
- [ ] **B logs in while A stands facing away** → A's body faces away on B's screen from the first frame. notes:
- [ ] **GM: Test Panel spawn a mob** → it lands in front of where you actually face (the stale yaw used to put it in front of your login facing). notes:

## 3 — Regression
- [ ] **Running, jumping, the jump relay, sitting** → unchanged. notes:
- [ ] **`/loc` before and after a minute of turning in place** → the position reads the same: turning moves nobody. notes:

## Notes / observations
-
