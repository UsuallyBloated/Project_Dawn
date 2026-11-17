# Session 2026-11-17: obstacle collision, the plan

**Asked for (user):** "Currently players are able to run through structures and trees etc.. We
need something for collision. Can you write a plan for this? or perhaps Godot has something
built in? let me know what you think is the best approach."

**Outcome:** a design, `docs/design/obstacle_collision.md`, with eight decisions waiting on the
user (its section 9). No code, no server change, nothing committed.

## 1. What was read

- Client: `scripts/player.gd` (the body, the Move send, the blend toward the server),
  `scenes/player.tscn` (capsule 0.4 m by 2.0 m), `scripts/zone/` (flora, town, landmarks,
  props, the `LowPoly` builder), `tools/check_zone_scenery.gd`, `docs/reference/invariants.md`
  (L2).
- Server: `world/tick/movement.rs` (`run_movement`: the grounded, airborne, flight and dead
  branches), `world/terrain.rs` (`player_step`, `slope_ok`, `can_see`), `world/entity.rs`
  (`step_on`, the stuck clock, `is_evading`), `world/buffs.rs` (`speed_mult` takes the largest
  buff, so the largest step on foot is 0.4125 m a tick).

## 2. What was measured

A read-only headless build of `world.tscn` (a scratch script, not in the repo) counted what
`ZoneFlora` plants on the current ground: 16,363 things. Pine 8,323, tall pine 3,517, dead
tree 616, dark tree 530, broadleaf 363 (13,349 trees); boulders 860; bushes 1,609, scrub 348,
bones 197. Town has 21 child nodes and Landmarks 40.

## 3. The answer on Godot's built-in collision

It exists (`StaticBody3D` and `CollisionShape3D`; the player is already a `CharacterBody3D`)
and it cannot be the whole answer:

1. The server moves the body from the direction sent, so a wall only the client has is walked
   through on the server and the client snaps after it. This is invariant L2's own reasoning.
2. A modified client removes its own walls.
3. The server's world is an X, a Z and the ground. A 3D collider has a top a client body can
   land on; the server would keep dragging that body off.

Recommended instead: footprints (circles and turned boxes, each a column of any height) that
the server holds, exported once for both sides, and one small rule written in Rust and in
GDScript and checked against each other. Godot's own collision is used for the camera only,
in the last slice.

## 4. Slices

0. Footprints declared on the scenery, the exporter and its report, the server's file with its
   hash and boot line, the lockstep check, a dev outline view. Nothing collides.
1. Players stop, on both sides; every placement goes to the nearest free point.
2. Walls and buildings block sight (spells, arrows, AoE, a mob's scan).
3. Mobs and pets collide; a mob a wall holds gives up by the existing 8 s rule and is evading
   meanwhile. No pathfinder.
4. The camera stops at walls and buildings.

No wire change, no DLL rebuild, no migration. Both sides move together from slice 1.

## 5. Not done

- No planner row was added to `docs/schedule_detail.toml` for the eight decisions, and the
  planner page was not regenerated or republished.
- Nothing is committed: the design, this note, the notes index row and the To-Do entry are
  working-tree changes on the deploy branch.

## 6. Other sessions

Session `project-dawn-5b` asked what this session touches before starting group-mate levels on
`feat/group-levels` (worktrees `server-levels` and `Project_Dawn-levels`). Answered: docs only
here, in the main client checkout, uncommitted; the one shared file is `CLAUDE.md`.
