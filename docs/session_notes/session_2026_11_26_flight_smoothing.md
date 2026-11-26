# Session 2026-11-26: GM flight smoothed

The user, after flying on the `c4f5aa4` zip: "The flying works but its a little clunky. do you
think you could smooth it out?" Two causes, read in `player.gd`, and the user's go on fixing both.

## What was clunky
1. **Instant velocity.** `_fly_tick` set the body's velocity straight to the keys' direction times
   the speed: full speed on the first frame of a keypress, a dead stop on the frame of release,
   and the boost and every turn the same.
2. **60 Hz steps.** Flight ran in `_physics_process` (60 Hz, no physics interpolation in the
   project), and the camera rides the body. At 25 m/s a step is 0.4 m, at 200 m/s boosted 3.3 m,
   which the camera shows as judder on any display faster than the physics rate, or wherever the
   steps fall unevenly against the frames.

## What was built (client `9d81945`, on the deploy branch, pushed)
- **`scripts/fly_glide.gd` (`FlyGlide`)**, pure: `advance(vel, target, dt)` is the closed form of
  an exponential ease (`ACCEL_RATE` 12, 95% in 0.25 s toward a heading; `STOP_RATE` 15, 95% in
  0.2 s toward rest, a stop gliding speed / 15 m), exact for any frame length, so frame by frame
  equals one step. `plan(...)` is the displacement the ease covers over the next tick divided by
  the speed times the tick: the direction a Move carries.
- **Why the server needs nothing:** it flies each Move's direction for one tick at the flier's
  speed (a direction shorter than 1 flies proportionally slower; it clamps at `FLY_BOOST`), so a
  Move carrying the next tick's planned displacement makes the server run the body's own track a
  tick late. The planned direction is a weighted mean of velocities no faster than the boosted
  speed, so it is never longer than the boost. The reconciler's prediction formula is unchanged
  (the body plus the direction times the speed times the tick); its bands are sized by the larger
  of the velocity and the target.
- **`player.gd`:** flight moves in a new `_process` (every rendered frame); `_physics_process`
  returns early for a flier. Velocity into the plate's edge, into the ground (falling) or into
  the ceiling (climbing) is zeroed, so a released key does not leave the body pressing on.
  `_fly_vel` is reset at takeoff and landing.

## Checks
`probe_fly_reconciler.gd` gained the ease (the first frame of a takeoff under a tenth of full
speed; 95 m/s of 100 after a quarter second; a stop at 100 m/s gliding 6.67 m; 36 frames equal to
one quarter-second step) and a 144 fps run through the 20 Hz server model with 100 ms of latency
and the server's tick taking the newest Move (a takeoff, a turn, a boost, a climbing diagonal, a
stop): no snap, the body within 0.30 m of its own track, settled within 0.05 m of the server, no
Position a tick of travel off its prediction (worst 2.9 m at 100 to 200 m/s), and the mean error
1.16 m against 2.29 m for a Move carrying the velocity of the moment. A first version compared
the body's worst distance from its own track instead; that is set by which Moves the server's
tick happens to take during the stop (0.30 against 0.22, a coin toss), so the check measures the
error the reconciler sees. `probe_flight_toggle.gd` green; all 21 of
`check_all.ps1 -ServerRoot F:\Projects\server`; the game boots clean headless.

## Export
From the worktree clean at `9d81945`: `[BuildStamp] stamped 9d81945`, `--export-release`, the
exported console exe booting headless (300 frames, exit 0), the DLL byte-identical to the
`c4f5aa4` zip's (`22800a86c691`). The zip `builds/ProjectDawn-alpha-9d81945.zip` (41,988,794
bytes) replaces `c4f5aa4`. No server change; the R720's `9a7c3ba` is unchanged.

## Not done
The low-altitude ground follow is unchanged (the server clamps to the same ground, so easing it on
the client alone would desync them). The six new rows are `gm_flight_checklist.md` section 8.
