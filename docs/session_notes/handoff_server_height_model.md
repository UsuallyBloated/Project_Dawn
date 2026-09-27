# Handoff: Server-Side Terrain Height Model ("height detection")

*Written 2026-09-25 for the Claude session that will plan and build this. Context: the
user wants zones with "great verticality", and the zone-size research
(`docs/design/zone_size_limits.md`, same date) found that the server's missing Y axis is
the one hard blocker. The user has chosen the height-model direction (option 1 in that
doc, section 4). Your first deliverable is the plan; build only after the user approves
it, which is this project's habit for anything this size (see `trade_window.md`,
`pet_levels.md`, `phase4_content_plan.md` for the pattern).*

## Read these first, in order

1. `docs/design/zone_size_limits.md`, especially sections 3 to 5. The research this
   grows from. Every code claim in it was hand-verified on 2026-09-25.
2. `server/docs/server_design.md` via `docs/concepts/architecture/README.md`. The wire
   and persistence contract; mandatory before any change that crosses the wire.
3. CLAUDE.md's Session workflow and the Security section. Note the standing rule: verify
   every claim below against the live source before acting on it. Line numbers were
   correct on 2026-09-25 and will drift.

## The problem, precisely

The server has no vertical axis, but its checks act as if it does:

- `handlers.rs` ~562: Y is zeroed on every `Move` ("server does not simulate gravity or
  jumping"); the `jumping` flag is discarded.
- `tick.rs` ~8621: movement integration touches XZ only. Gravity is client-side.
- `connection.rs:76` `Vec3f::step_toward` deliberately preserves the mover's Y, so a mob
  keeps its camp's spawn Y forever.
- **Yet nearly every range check is 3D** via `Vec3f::distance_to` (`connection.rs:57`):
  melee (`tick.rs` ~3221), spell range (~4460), AOE (~4657), res (~3817), corpse and bag
  loot (~7898, ~8123, ~8406), group coin share, PvP range, NPC service (`npcs.rs:80`),
  mob aggro/leash/melee (`entity.rs` ~787-935), pet AI (~712, ~754). The only 2D check
  in the server is `MAX_CAST_MOVE_DISTANCE` (`tick.rs` ~3637).

Result on non-flat terrain: a mob whose spawn Y differs from a player's stale Y by more
than melee range (1.8 m) chases to the player's XZ and can never attack, because 3D
distance never drops below the height gap. Past leash range in Δy it never aggros.
A 2 m ledge breaks combat. This is why every y in `zone_camps.toml` and `npcs.toml` is
0.0 today, and why authoring nonzero y there is currently harmful.

Client side, the same gap shows visually:

- Remote players/enemies/pets interpolate the server's full `Vector3` verbatim with no
  ground snap (`remote_player.gd` ~276, `remote_enemy.gd` ~108, `remote_pet.gd` ~228);
  corpse and loot-bag managers place at the server position too. On a hill they would
  sink into terrain or float at its base.
- The local player keeps Y under local control (gravity, jump, fall damage in
  `player.gd`; reconciliation touches XZ only, ~508-538), but the server `Teleport`
  handler sets all three axes (`net.gd` ~1108), so respawn/res onto raised terrain
  drops you to y=0.
- Current terrain is a flat 400 x 400 m heightmap mesh (`scripts/terrain_mesh.gd`,
  20x20 cells, all heights 0.0) in `world.tscn`, one unchunked mesh + trimesh collider.

## The chosen direction

The server learns the ground. A heightmap of the zone, exported from the client terrain,
lives server-side next to `zone_camps.toml`. The server samples ground height at any XZ
and pins player, mob, corpse, bag, and NPC Y to it. The 3D range checks stay 3D and
become *correct*. Jumping stays cosmetic and client-side.

Why this over switching checks to 2D distance: 2D makes height invisible to gameplay
(melee through a 30 m cliff face, attacks from unreachable perches) and leaves remote
entities rendering at the wrong height. The research doc records the comparison.

## Invariants the plan must preserve (security, non-negotiable)

1. **The client never gains authority over Y.** The client already cannot send a
   position, only a direction; keep it that way. The server derives Y from its *own*
   heightmap at its *own* XZ. No new client-supplied vertical input of any kind. (This
   is the same reasoning as the jump To-Do's exploit note: a forged flag may only make
   you look silly, never move you.)
2. **The NaN Move gate lands first or in the same change.** Open Security To-Do, found
   in the same research: a forged non-finite `direction` slips `clamp_length`
   (`connection.rs:43`) and poisons `conn.pos`. A poisoned XZ fed into a height sampler
   is undefined behavior stacked on undefined behavior. The fix is a few lines in the
   Move handler (mirror the `is_finite` guard at `handlers.rs` ~793). Do it before
   sampling positions.
3. **Out-of-range sampling must be total.** Define what the sampler returns for XZ
   outside the heightmap's extent (clamp to edge is the obvious choice) and for any
   non-finite input (refuse). A client can walk arbitrarily far; there are no world
   bounds (verified: nothing clamps x/z anywhere).
4. **Fall damage is currently client-originated** (`player.gd` ~542 calls
   `Combat.receive_player_damage` locally). Verticality makes this worth a decision: a
   modified client can already decline to report fall damage, and real cliffs raise the
   stakes. At minimum flag it in the design's exploit ledger; server-side fall damage
   may be out of scope for slice 1 but the ledger should say so explicitly.
5. **Do not regress the death/corpse path.** Corpse positions, res range, and the
   corpse-run are the most playtested consequence chain in the game. Corpses must get
   ground-pinned Y (they persist `pos_y` already, `migrations/0007`), and res range
   checks must still pass for a corpse on a slope.

## Questions the plan must answer (the design doc's spine)

- **Heightmap format and lockstep.** What file, what resolution, where it lives, and
  how it is regenerated when the terrain changes. This project's standing pattern is
  client/server data lockstep with a stated regen path (items, quests, camps, npcs all
  do it; `tools/export_spells.gd` is the cautionary tale of a regen tool that went
  stale). A Godot editor tool that exports the terrain's heights to the server repo is
  the likely shape; make staleness loud, not silent (the build-stamp addon is the
  house style for that).
- **Sampling.** Bilinear interpolation over the grid, presumably; state the resolution
  and error bound relative to the client's collision mesh, because a big mismatch
  between server ground and client ground reintroduces the Δy problem in miniature.
- **Who gets pinned, and when.** Players: on Move integration and on Teleport. Mobs: at
  spawn and inside `step_toward` (which currently preserves Y by design; that comment
  changes meaning). Corpses and loot bags: at creation. NPCs: `npcs.toml` y could
  become derived rather than authored. Decide whether camp/NPC y stays authorable at
  all; deriving everything from the heightmap removes the foot-gun the research doc
  flagged.
- **Client reconciliation.** Probably no protocol bump: `Position` and `Teleport`
  already carry Y; the server just starts filling it truthfully (verify against the
  gdext decode paths before assuming). Decide whether the local player adopts server Y
  on Teleport only (current behavior, now correct) or also reconciles gently during
  play; and whether remote entities still want a client-side ground snap as polish for
  interpolation between updates.
- **Caves and overhangs are out of scope.** A heightmap is single-valued per XZ.
  Multi-level spaces (dungeon floors stacked on the same footprint) need real Y
  tracking and are a later epic; say so in the doc so nobody scopes them in.
- **Mob pathing stays straight-line.** The server still walks mobs through obstacles in
  XZ; the heightmap fixes their height, not their route. Steep-slope behavior (should a
  mob chase up a cliff face?) is a design question worth one paragraph, not a navmesh
  project.
- **Tests.** Unit tests on the sampler (edges, interpolation, non-finite). Integration:
  the harness can dev-spawn (`send_dev_spawn` exists since the flaky-test fix); a
  slope scenario proving a mob on raised ground closes to melee and hits. The suite
  runs fully green (44/44) as of 2026-09-16; keep it that way.
- **Deploy shape.** Likely server + a data file + a client export tool, with the
  existing wire. Confirm whether any client change is needed at all for slice 1 (if
  remote rendering just works once server Y is truthful, the client may ride along
  unchanged until the terrain itself changes). State the R720 deploy steps per
  CLAUDE.md; both repos' branches are `fix/xp-leveling-overflow`.

## Process expectations

- Deliverable one is `docs/design/server_height_model.md` (or similar) with: the
  decisions above, an exploit ledger (the `trade_window.md` ten-point ledger is the
  house standard), slices, and any calls that belong to the user, clearly marked and
  left undecided. The user decides; do not pre-decide for them.
- Playtest checklist authored from `docs/playtest_notes/TEMPLATE_checklist.md` when the
  build lands. Built is not done; nothing ticks without playtest evidence.
- Session note + README index row per session.
- Verify before you trust: every line number above was checked on 2026-09-25 against
  the live tree, but re-grep before editing. The recon that fed this handoff was
  correct, but the project has been burned by unverified recon before (2026-06-22).
- The current world is flat, so nothing breaks while you build. The first non-flat
  terrain should land only after the height model exists; coordinate with the user on
  which comes first if terrain work starts in parallel.
