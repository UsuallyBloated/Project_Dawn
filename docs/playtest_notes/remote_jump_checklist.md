# Remote Jump Playtest Checklist — 2026-10-14

Other players' jumps now show as jumps instead of slides. The jumper's client sends its real
jump flag on its next movement packet, the server relays one "jumped" cue to the players who can
see the jumper (never back to the jumper), and each of their clients plays the hop on that body.
**Cosmetic only**: the server never moves anyone for it. **Rides the Oct 22 bump day**
(PD_W0028): needs the server redeployed from the merged trade branch AND the new export with the
rebuilt `gdext_net.dll`. Run `godot --headless --path . -s tools/check_wire_layer.gd` on the
export's checkout first; it must list `player_jumped` as OK. Two seats throughout.

| Rule | What happens |
|---|---|
| A jumps | B sees A's body hop about 1.2 m and land, 0.7 s in all, while A's feet track the ground as before |
| A spams jump | B sees at most two hops a second, however fast A taps |
| A jumps out of B's view (over 120 m) | B sees nothing |
| A is dead | nothing: a corpse does not jump |

Diagnostics: there is no log line for a relayed jump (they are frequent); the in-game console
on B's seat shows nothing either. A missing hop with the DLL check green means the server
build predates the relay.

## 1 — The hop

- [x] **B watches A; A jumps once, standing still** → B sees A's body rise and land in place, the nameplate riding with it; A's position on B's screen does not slide or snap. notes: User, 2026-10-27, in chat after the two-seat sittings on the `0e58643` server and the day's export: "the jump relay works. I can see other players jumping." The remaining rows (the burst cap, the corpse, the 120 m view edge) are the integration test's and were not run by hand.
- [ ] **A jumps while running** → B sees the hop during the run; A keeps moving along the ground underneath it. notes:
- [ ] **A jumps repeatedly as fast as the key allows** → B sees a hop for each real jump (one per landing, about every 0.7 s), never more than two a second. notes:
- [ ] **A sits, then presses jump** → A does not jump (sitting blocks it); B sees nothing. notes:
- [ ] **A jumps while B stands over 120 m away, then B walks into view** → B saw no hop; nothing odd when A comes into view. notes:

## 2 — Nothing moves for it

- [ ] **A jumps repeatedly next to a mob or a wall** → A's own position never changes from the jumping alone (no climbing, no clipping); `/loc` before and after a dozen jumps reads the same. notes:
- [ ] **A dies, B targets the corpse** → no hop plays on the corpse at any point. notes:
- [ ] **A jumps with B's camera close** → the body comes back to exactly where it stood; no drift of the visual after many hops. notes:

## 3 — The old client (optional)

- [ ] **A on the new build, B on the previous export** → B still sees A slide (the old DLL has no cue); nothing else differs. notes:

## Notes / observations
