# GM Flight Playtest Checklist — 2026-11-15

Minecraft Creative-mode movement for a GM (docs/design/handoff_gm_flight.md): `/fly` lifts
the body, Space climbs, Shift descends, Ctrl doubles the speed, descending into the ground
lands. The server flies the body and clamps it; the client predicts it. **Needs the server
redeployed from `feat/gm-flight` (or its merge) AND a client built from the same branch**: on
the old client `/fly` does not exist, and on the old server the body flies alone until the
next Position snaps it back. GM account only (`grant_gm`); a plain account sees nothing.
**Since 2026-11-25 both halves are in the deploy branches:** the R720 (`9a7c3ba`) and the zip
`builds/ProjectDawn-alpha-c4f5aa4.zip` are the pair to run this on.

| Thing | Value | Where |
|---|---|---|
| Default speed | 25 m/s (`/fly` with no number) | `DEFAULT_FLY_SPEED`, both sides |
| Speed range | 1 to 100 m/s (`/fly 50`) | `MIN_FLY_SPEED` / `MAX_FLY_SPEED` |
| Boost | Ctrl held: twice the speed | `FLY_BOOST` |
| Ceiling | 1,000 m | `FLY_CEILING` |
| Journal | `fly on` / `fly off` lines with `char_id`, speed and position; one `gm_actions` row (`command = 'fly'`) per toggle | `server.log`, `admin_report` |

Diagnostics: the HUD's "Flying N m/s" line at the top of the screen; `/loc` for the height;
`debug.log`; the journal's `fly on` / `fly off` lines.

## Setup
- [ ] Server redeployed with the flight build (the boot line's `build=` is the branch's sha)
- [ ] Client built from the same branch; `/version` matches
- [ ] A GM account logged in (`GM account connected` in the journal); a second seat optional for section 6

## 1 — Taking off and steering
- [ ] **Type `/fly`** → "You take to the air (25 m/s). /fly off to land." in chat; "Flying 25 m/s" at the top of the screen; the body hangs where it was. notes:
- [ ] **Hold Space** → the body climbs smoothly, about 25 m in a second; no stutter, no snap back. notes:
- [ ] **WASD and the mouse** → the body flies where the camera points, level; turning in flight works as on foot. notes:
- [ ] **Hold Ctrl while flying forward** → about twice the speed; release, back to the speed set. notes:
- [ ] **Hold Shift** → the body descends. notes:
- [ ] **`/fly 100` in flight** → "You fly at 100 m/s."; the HUD line reads 100; the plate (4 km) crosses in about 40 s boosted. notes:
- [ ] **`/fly 0`, `/fly 500`, `/fly abc`** → refused in chat ("Flight speed must be between 1 and 100 m/s." or the usage line); nothing changes. notes:

## 2 — Where a flier is held
- [ ] **Fly down into a hillside while holding W (not Shift)** → the body slides along the ground's surface, never under it. notes:
- [ ] **Fly straight up for a minute at 100 m/s boosted** → stops at 1,000 m (`/loc` height); the world is small below. notes:
- [ ] **Fly at a mountain range at the plate's edge** → the body stops at the edge and cannot leave the plate. notes:

## 3 — Landing
- [ ] **Hold Shift until the body meets the ground** → "You stop flying."; the HUD line goes; walking works at once. notes:
- [ ] **`/fly off` at about 30 m up** → the body falls, lands, NO "You hit the ground hard" line, HP unchanged. notes:
- [ ] **Double-tap Space on foot** → takes off (as `/fly`); **double-tap Space in flight** → lands (falls harmlessly). notes:
- [ ] **Test Panel: Fly 10 / 25 / 50 / 100 and Land** → each as its command. notes:

## 4 — What flight ends
- [ ] **Fling 20 m while flying (Test Panel)** → flight ends, the body is flung and lands for the fling's damage (45% of max HP). notes:
- [ ] **Accept a resurrection or respawn while the flight ended elsewhere** (optional) → every server move of the body (a respawn, a port, a summon) arrives as a Teleport and lands you on foot; nothing is left flying. notes:
- [ ] **Trigger Death while flying (Test Panel)** → the body dies on the ground below; flight ends; `/fly` while dead is refused; the respawn is on foot. notes:
- [ ] **Log out (`/camp` on the ground, or Quit) at 40 m up, log back in** → standing on the ground under where you were, unhurt, on foot. notes:

## 5 — Mobs and fighting
- [ ] **Let a mob attack you, then `/fly` and hover beside it** → it drops you at takeoff (walks home or turns on someone else) and never swings at you in the air. notes:
- [ ] **Fly low over a camp of idle mobs** → none notice you. notes:
- [ ] **Q (auto-attack), a spell gem, a skill, while flying** → each refused locally with "You cannot do that while flying."; nothing spent; no `Attack rejected` or `cast rejected` line in the journal (the client refused first). notes:
- [ ] **Land beside the camp** → the mobs notice you as usual. notes:

## 6 — A second seat (optional)
- [ ] **The partner watches the GM take off and fly past** → they see the body rise and fly, drawn in the air, no sliding on the ground. notes:
- [ ] **The partner, a plain account, types `/fly`** → "Flight is not available."; nothing in the journal, no `gm_actions` row for them. notes:

## 7 — Regression: on foot, nothing changed
- [ ] **Run, jump, crouch, sit, autorun on foot** → as before. notes:
- [ ] **Walk off a ledge on foot** → the ordinary fall and its damage. notes:
- [ ] **`admin_report`** → one `fly` row per toggle of the sitting, `speed=N` or `off`, none for the plain account. notes:

## Notes / observations
-
