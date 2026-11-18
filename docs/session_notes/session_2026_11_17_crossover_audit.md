# Session 2026-11-17 (evening): the cross-over audit, three flaky tests, and a structure assessment

The user, after the obstacle redeploy and the flight-client merge: "We have gotten so much
done since our last attempt at house keeping. I need you to write a plan to go through the code
and confirm that there are no cross-overs or trips." Then "start the read." Then, heading to
bed: "have a look at the game's use of tools and functions. Are we taking an object oriented
approach? Are we suffering from bloat? Can we be more efficient? ... please dont build
something for the sake of building something."

## 1. The flight client brought up to date (early evening)

`/fly` did nothing for the user because the client half of GM flight had never left
`feat/gm-flight`, which was 25 commits behind the deploy branch. The deploy tip merged into
the branch in `F:\Projects\Project_Dawn-zone` (`231a8ac`, pushed): three conflicts, each
keeping both sides (flight returns before `player.gd`'s obstacle step, matching the server;
the Test Panel keeps Fly and Obstacle Outlines; the session index keeps every row); the
worktree's gitignored DLL replaced with the group-levels one. All 19 checks and the flight,
group-levels and obstacle probes green. The user flew from the editor: "works wonderfuly".
The merge commit's subject carries a stray BOM from a PowerShell here-string; fixing it needs
a force push, refused by the permission system, and it was left.

## 2. The plan (`docs/security/crossover_audit_plan_2026_11_17.md`, `cfffeeb`)

Built on git evidence: each post-bump feature's segment of the deploy branch diffed on its
own, and the files two or more touched listed. `terrain.rs` by seven; the mob state machine
(`entity.rs`, `enemy_ai.rs`, `spawning.rs`, `pet_life.rs`) by three or four each. Nine seams
ordered worst first, the method (read the seam by hand; a lead from an agent is never a
finding; every finding gets a test or a row; exploit lens on each), and three overnight runs.

## 3. The read (`docs/security/crossover_audit_2026_11_17.md`, `8c4c382`)

Every code seam read clean: the tick order (every XP award precedes the roster re-send), the
three readers of the ground (the obstacle check rebakes from the scene; a roam spot asks the
obstacles whether a body stands there; a roam step never feeds the stuck clock), the mob
machine (mob-to-target leash, fliers out of the target list and wiped from every hate list at
takeoff, a follower never immune for its leader), pets (the charm ledger moved and moved
back, `wipe_hate` clears it, a dismissed warder cannot arm the respawn timer), the wire (the
client holds no protocol id; the DLL takes it from the token), the wanderer tables (every
species a loot rule, a faction and the intended quest match; two tests hold it), the client
(no command swallows another; 13 obstacle and 5 flight lockstep pairs present; every
invariant holder resolves). Six NOTED items, none an action.

The trips were in the records: `systems_overview.md:833` still taught "+Z is north" (the
reverse of L3 since the mirror) and had no paragraph for anything built since 11-09; the
runbook's sample boot line lacked the three fields it tells the operator to confirm; the
Test Panel list in `commands.md` predated Fling and Obstacle Outlines; `author_terrain.gd`
did not say to run the exports after a write. H1 to H4 fixed the same night (this commit).
Open: the hosting branch's merge-forward (19 behind), the eleven worktrees at merged tips,
the planner republish.

## 4. The runs, and three flaky tests fixed

The world suite ten times on `87c58fe`: eight runs green, two with failures.
`flight::a_fling_or_a_death_ends_flight` (run 4), `flight::a_flier_is_held_above_the_ground...`
and `roam::a_wanderer_walks_its_region_on_its_own` (run 6). Alone five times: the flight pair
five of five (load sensitivity: `gm_line` collected the server's reply for a fixed 400 ms, the
ledger sleep's shape); the roam test one of five ("got 0.0 m"), so a construction cause: a 30 m
test region against 20 to 80 m legs makes `pick_leg`'s eight draws fail often, and a failed
draw costs the rat a 5 to 25 s pause, longer than the 12 s watch. The real regions are 400 to
2,000 m across, so the server's rule stands. **Fixed, test code only** (server deploy branch,
the commit after `87c58fe`): `gm_line_says` polls up to 3 s for the line; the roam region is
60 m and the watch ends as soon as the rat has walked 5 m. The four tests five of five and the
world suite 201 of 201 after; fmt clean. No redeploy (tests do not ship). The fuzz hour and
the live-roamers hour wait on the user.

## 5. The structure assessment (`docs/design/code_structure_assessment_2026_11_17.md`)

Measured on both repos (sizes, function lengths, autoload coupling, a dead-function sweep,
duplication, signals against direct calls; an agent took the client breadth and every number
leaned on was re-checked). The short answer: not object oriented and rightly so on both
halves (a service layer of 50 autoloads; a data-oriented tick); bloat in two specific places
(four server functions of 1,000 to 1,950 lines that the tick split carried through intact,
and a client UI built in code with one 475-line command dispatcher); runtime is 1 to 2% of
the tick budget, so efficiency is a reading cost, not a running one. Six ranked
recommendations, each with its moment (delete 25 dead functions; `apply_casts` and
`handle_message` into one function per arm before the next feature in those files; a base
class under the five remote managers when the animation channel touches them; the dispatcher
as a command table when a command is next added; new windows as scenes; measure before any
allocation hunt), and a list of what is not worth doing (an ECS, DI, OO for its own sake,
splitting files to hit a count, anything before Thursday). Nothing built.

## 6. Files

Client: the plan, the findings, the assessment, this note and the index; the three doc fixes
(`systems_overview.md`, `server_operations.md`, `commands.md`); `tools/author_terrain.gd` (the
"Next" line); CLAUDE.md's housekeeping entry (a pointer). Server: `tests/world/flight.rs`,
`tests/world/roam.rs`. Flight branch: the merge `231a8ac`.
