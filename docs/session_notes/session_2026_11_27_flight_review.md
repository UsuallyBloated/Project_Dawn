# Session 2026-11-27: GM flight, the review pass

The user, after the smoothing of 11-26 (`9d81945`): "Excellent work. Please review as Fable."
The review returned nine findings; each was read in the source and the ones with numbers were
replayed through the probe's server model before anything was reported. The user's go on fixing
all nine. All client only. None is exploitable: flight is GM-gated and the server clamps every
direction and every position itself, whatever a client sends.

## The findings, and what was done (client `ade04e1`, on the deploy branch, pushed)
1. **A flight speed lowered while moving pulled the body back.** `start_flight` in flight set
   the new speed and kept `_fly_vel`; `FlyGlide.plan` then cut every Move to the boost at the
   new speed, so the body outran the server until the ease had bled the velocity off. Replayed:
   5.8 m from 100 to 10 m/s, 16 to 18 m with the boost held. Introduced by the smoothing. In
   play the way to do it is a Fly button on the Test Panel clicked with W held (the chat line
   takes the keys, so a typed `/fly 10` arrives after the glide to rest). **Fix:**
   `FlyGlide.carry_over(vel, speed, max_len)` cuts the velocity to what the new speed can fly;
   about 1.5 m is left, the Moves already on their way when the speed changed.
2. **Under 20 frames a second the Move limit broke.** The send accumulator subtracted one
   interval per send and sent at most one Move a frame, so at 15 fps it banked a quarter of
   every frame (1.5 s after six seconds) and then paid it back as a Move on every frame or
   physics step. Position was unaffected; the cost was traffic. Introduced when flight moved to
   `_process` (a physics step is always 1/60 s, so walking alone could not bank). **Fix:** one
   helper, `_move_due(delta)`, for walking and flight, keeping under one interval of carry-over
   (`fmod`). At 20 fps and above it is bit for bit what the subtraction was.
3. **Skimming into a steep face left the body floating.** The body and the server both ride up
   the ground; the prediction recorded for each Move (`body + direction * speed * tick`) had no
   clamp, so it sat inside the hill, the Position read as an error upward, and the correction
   put the body above where the server had it: 6.8 m at 100 m/s into a 72 degree face, which
   then sat inside the dead band (7.5 m at that speed) until the next stop. Older than the
   smoothing. It matters because `/loc` reads the client's body. **Fix:** `_fly_clamp` (the
   plate, the ground, the ceiling, the server's order, checked against
   `world/tick/movement.rs`) is the one clamp for the body and for the prediction. Replayed with
   the clamp: 0.0 m at every speed and slope tried.
4. **The text-focus scan ran every rendered frame in flight.** `_is_text_input_focused()` walks
   the whole tree when no field has focus (2,384 nodes in the zone, about 1.1 ms a call), and
   `_process` called it on top of the physics step's call. **Fix:** the physics step keeps its
   answer in `_text_focused`; the frame step reads it.
5. **Each flight Move left a frame late.** Net is an autoload, so its `_process` (which puts
   queued messages on the wire) ran before the player's, and a Move queued in the player's
   frame step waited for the next frame. **Fix:** the player's `process_priority` is -1.
6. **The probe's "no direction longer than the boost" check could not fail** (it measured after
   `plan`'s own cut). It now measures what the ease asks for before the cut, and the eased run
   is repeated with the speed lowered from 100 to 10 m/s mid-boost, with the cut (1.52 m, no
   snap) and without it (a Move asking for 8.9 times the speed, 16.4 m pulled back).
7. **`probe_flight_toggle.gd` timed flight in physics frames** while flight now runs on frame
   time, so its distances varied by run. It sums the frame time the body was given (the main
   loop's own `_process`, with the key going down and up at the top of a frame) and holds the
   climb to a centimetre of the ease's closed form: 5.585 m in 0.305 s on one run, 5.546 m in
   0.303 s on the next, each matching to the millimetre.
8. Two constants declared mid-file in `probe_fly_reconciler.gd` moved to the top; the boost is
   read off `player.gd` at start (a `-s` script cannot name `PlayerCharacter`: player.gd names
   autoloads, which are not globals yet when the probe compiles; tried, it errors).
9. The comment that called a 60 Hz step "a metre or more" gives the real figures (0.4 m at
   25 m/s, 3.3 m at 200). `fly_glide.gd`'s header no longer claims the direction is always
   within the boost; it says when that holds.

## Checks
`probe_flight_toggle.gd` gained four checks that call the body's frame step with a chosen frame
time (the ease is exact for any, so the numbers are the same on every run): the speed cut
(99.8 m/s to 20.0), the prediction on the ground (0.000, was -1.177), the half second at 144 fps
after six seconds at 15 (10 Moves, was 39), and the priority (-1 before 0). Each fix was then
taken out in turn and the probe run: five planted faults (the four, and flight put back in the
physics step), five failures, each on its own check. All 21 of
`check_all.ps1 -ServerRoot F:\Projects\server`; the nine probes that load the player or the
world; the game boots clean headless.

## Looked at and left alone
At frame rates that divide the tick exactly (240, 165, 120, 30 fps) the replay shows the body
up to 1.4 to 2.4 m off its own track with 4 or 5 blended corrections, against 0.2 to 0.3 m at
144, 90, 60 and 45. In the replay every frame is exactly 1/240 s, so the accumulator lands on
the threshold and float rounding decides, always the same way, and the send phase creeps past
the server's tick. Real frames are never exactly even, so no fix was built for it; a hair of
slack at the threshold cured it in the replay and made 24 fps worse (3.8 m), which is why it
was not taken as it stood.

## Export
From the worktree clean at `ade04e1`: `[BuildStamp] stamped ade04e1`, `--export-release`, the
exported console exe booting headless (300 frames, exit 0), the DLL byte-identical to the
`9d81945` zip's (`22800a86c691`). The zip `builds/ProjectDawn-alpha-ade04e1.zip` (41,993,582
bytes) replaces `9d81945`. No server change; the R720's `9a7c3ba` is unchanged.

## Also
The main checkout's Godot class cache (dated 11-25) had neither `FlyGlide` nor `FlyReconciler`,
so headless tools there could not parse `player.gd`; a headless `--import` after the
fast-forward fixed it (no editor was open on it; no tracked file changed).

The three new rows are `gm_flight_checklist.md` section 9.
