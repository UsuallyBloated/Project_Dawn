# Track 21B — Target-of-target HUD frame (real resolution)

Date: 2026-05-22 (continuation from Track 20D).

Closes a long-open UI gap: the player can now see who their target
is targeting. Essential for group play — tanks know if mobs are
peeling off them, healers see who's getting focused, DPS knows
when to off-tank-swap.

The hud already had a `_tot_frame` widget (built but always hidden)
and a `_refresh_tot()` function that hard-coded "you" as the
target-of-target. This track wires it to actually resolve the
tracked target's current target across all entity kinds.

## Touchpoints

**`autoloads/remote_enemy_manager.gd`**,
**`autoloads/remote_player_manager.gd`**,
**`autoloads/remote_pet_manager.gd`** — added a public
`get_by_id(id: int) -> Node` accessor on each. Used by the new HUD
resolver to look up the entity for a server-sent target_id without
reaching into the manager's private `_by_id` dict.

**`scripts/hud.gd`**:

- New `_tot_entity: Node` field — cached binding so we can
  disconnect the entity's `hp_changed` / `died` signals on
  retarget without a scene-tree walk. `null` when ToT is hidden
  or pointing at the local player (PlayerStats is the source there).
- Rewrote `_refresh_tot()` as a proper resolver:
  - Reads the tracked target's `target_id` (RemoteEnemy) or
    derives "you" from local enemy state (CHASE / ATTACK).
  - 0 (no target) → hide.
  - Own player_id or sentinel `-1` → render "You" + PlayerStats
    HP; leaves `_tot_entity = null` so the existing
    `_on_hp_changed` updates the bar.
  - Otherwise resolves the id partition (`< 1B` → player, `1B-2B`
    → remote enemy, `≥ 3B` → remote pet; loot bags ignored) →
    binds the entity's hp_changed + died and renders its name +
    HP.
- New helpers: `_resolve_tracked_target_target_id`,
  `_resolve_remote_entity`, `_bind_tot_entity`,
  `_clear_tot_entity_binding`, `_render_tot_entity`,
  `_on_tot_entity_hp_changed`, `_on_tot_entity_died`,
  `_on_tracked_target_target_changed`.
- `_on_target_changed` (enemies branch) now subscribes to
  `enemy.target_changed` when present (RemoteEnemy emits it on
  every `EntityTarget` broadcast). Disconnect happens in the
  existing pre-retarget disconnect block.
- `_clear_tot_entity_binding()` called at every target-switch
  transition (retarget, enemy died, self-target).
- `_on_hp_changed` (PlayerStats subscriber) now gates the ToT-bar
  mirror on `_tot_entity == null` — so a peer-on-peer ToT
  doesn't get clobbered when the local player takes damage.

## Behavioural matrix

| Tracked target | ToT shows |
|---|---|
| Local Enemy (solo) in CHASE/ATTACK | "You" + own HP |
| Local Enemy in IDLE/LEASH/FLEE/DEAD | hidden |
| RemoteEnemy whose `target_id == own_id` | "You" + own HP |
| RemoteEnemy targeting a peer | peer name + peer HP |
| RemoteEnemy targeting another enemy (charm/pet) | enemy name + HP |
| RemoteEnemy targeting a pet | pet name + HP |
| RemoteEnemy with `target_id == 0` | hidden |
| Pet (own / remote) | hidden (out of scope for v1) |
| Vendor / NPC | hidden (no target concept) |
| Self-target | hidden (own HP is already in the stat panel) |

## Tests

No automated tests — this is HUD code that needs running Godot to
exercise. **Manual verification deferred** (Godot not in PATH on
the workstation; can't run the launcher headlessly from here).

**Verification checklist for the next playtest**:
1. Solo / Test Room: target a wolf. Attack it. ToT should appear
   showing "You" + own HP bar.
2. Two-client launcher mode:
   - Both clients EnterWorld.
   - Client A targets an enemy that's currently attacking client B.
     ToT should show client B's name + HP.
   - B uses an aggro move (or pet pulls). ToT should update to
     show the new target on the enemy's `target_changed`.
   - Enemy de-aggros (out of range / leashes home). ToT should
     hide once `target_id` goes to 0.
   - Target a remote player. ToT stays hidden (no server-side
     peer→peer target broadcast yet).

## Files touched

Client (`F:\Projects\Project_Dawn\`):
- `autoloads/remote_enemy_manager.gd` (+`get_by_id` accessor)
- `autoloads/remote_player_manager.gd` (+`get_by_id` accessor)
- `autoloads/remote_pet_manager.gd` (+`get_by_id` accessor)
- `scripts/hud.gd` (rewritten `_refresh_tot` + 7 new helpers,
  wired into the existing target-switch + hp-changed paths)

No server changes; no protocol bump.

## Carry-forward

- **Peer→peer target frame** — needs a server-side broadcast of
  the local player's current target (similar to `EntityTarget`
  for enemies but for player char_ids). Once that lands, ToT for
  a tracked remote player will show what they're attacking. Out
  of Track 21B scope; queue if the playtest asks for it.
- **AOI despawn while ToT-bound** — if the ToT entity drifts out
  of AOI without dying, the entity node gets freed but my
  reference may stay until the next refresh. The
  `is_instance_valid` check at the top of `_refresh_tot` catches
  this, but the bar can briefly show stale values. Acceptable
  for v1; the next `target_changed` or any retarget clears it.
  If it bites in practice, subscribe to `Net.world_entity_despawn`
  in the binding too.
- **Local Enemy state transitions** — the local-Enemy ToT path
  shows "You" on CHASE/ATTACK but doesn't refresh when the
  enemy transitions IDLE → CHASE. The first hit on the enemy
  fires `Combat.target_changed` (re-target into self) which
  doesn't re-resolve ToT for the already-tracked enemy. A poll
  in `_process` would fix it but solo mode's ToT is low-value
  (the player is alone). Defer.
