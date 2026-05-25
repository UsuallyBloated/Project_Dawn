# Track 22.E / 22.F / 22.H / 22.I — Spell-damage interrupt, skill rebalance, peer target broadcast, portrait slot

Date: 2026-05-24.

Continuing the alphabetical march through the Track 22 menu after
Track 22.C (mount system). G (multi-window chat) deferred to its
own track as a 2-3 session piece. This file covers the four
remaining options.

## 22.E — Spell damage cast-interrupt

Track 19A wired the channeling-based on-hit interrupt for melee
Attack intents (enemy + PvP). 22.E extends it to spell damage.

Server-side hooks (tick.rs):
- **PvP spell damage on target** — after `tc.hp -= dmg`, re-borrow
  via `connections.get_mut(&target_cid)` and call
  `roll_cast_interrupt`. Fan `CastFail("interrupted (hit during
  cast)")` on success.
- **PvP shield reflect to caster** — same helper called on the
  attacker inside the shield-back block. Catches the edge case
  where the caster's own shield reflect hits them mid-cast (rare;
  the cast cache normally clears before this point, but the path
  is defensive).
- **PvP melee shield reflect to attacker** — added to the PvP
  melee arm too, parallel to the new PvP spell shield branch.

No DoT path wired — server has no DoT damage model on players
today (buffs.rs has HoT but no DoT). The CC/snare path doesn't
deal damage. The enemy-AI spell path doesn't exist yet (enemies
don't cast). Coverage is complete for the cases that exist.

## 22.F — Skill cap rebalance

L1 characters previously couldn't advance any skill because
`starting_value` equalled the L1 cap (both = `max_cap * level /
MAX_LEVEL = max_cap * 1 / 60`, rounded to 1-4 in practice). The
`try_advance` chance formula `0.2 * (1 - score/cap)` was therefore
always 0.

Changed `starting_value` to `cap(L1) / 4` with a floor of 1.
Trainable classes now have immediate headroom (e.g., Warrior
1h_slashing L1: cap 4, start 1 → 3 advances available before
the next level-up tier).

Files touched:
- `crates/projectdawn-server/src/world/skills.rs` — function +
  unit test renamed (`starting_value_quarter_of_cap_with_floor`).
- `data/weapon_skill_definitions.gd`,
  `data/armor_skill_definitions.gd`,
  `data/casting_skill_definitions.gd` — same formula change in
  GDScript for solo / Test Room parity.
- `tests/world_two_clients.rs` — `skill_progress_snapshot_seeded_on_enter_world`
  assertions updated (Warrior 1h_slashing now Some(1), plate
  now Some(1)).

116/116 lib + 40/40 integration tests pass.

Forward-only change: existing characters in DB keep their saved
score rows; only fresh-character seeding sees the new starting
value.

## 22.H — Peer→peer target broadcast

Track 21B's ToT frame resolved enemy `target_id` via `EntityTarget`
broadcasts but stayed hidden when the local player tracked a
remote peer — server didn't fan player target updates. 22.H closes
that gap.

Protocol: `ClientWorldMsg::SetTarget { target_id: Option<EntityId> }`
was scaffolded earlier but never handled. Wired it now.

Server flow:
- New `Outcome::PlayerTargetFanOut { target }` variant.
- New `SetTarget` arm in `handle_message` — stamps
  `conn.current_target` (new field on PerConnection) and returns
  the outcome.
- New `player_target_fanouts` queue drained post-dispatch alongside
  `death_fanouts` — fans the existing `ServerWorldMsg::EntityTarget`
  (no new server message; the variant already supported any
  EntityId) to in-world peers minus the sender.

Client flow:
- `gdext-net`: new `send_set_target(target_id: i64)` `#[func]`;
  `target_id <= 0` encodes None on the wire. DLL rebuilt + copied.
- `autoloads/net.gd`: new `broadcast_set_target(id)` wrapper.
- `autoloads/combat.gd::set_target`: fires
  `Net.broadcast_set_target(tid)` after the local
  `target_changed.emit`. ID extracted by inspecting the target
  node's `enemy_id` / `char_id` / `pet_id` field (whichever
  applies). 0 for null / no-id targets.
- `scripts/remote_player.gd`: new `target_id: int` field +
  `target_changed(target_id: int)` signal + `apply_target_change`
  method (mirror of RemoteEnemy).
- `autoloads/remote_player_manager.gd`: subscribes to
  `Net.world_entity_target`, filters by `id < ENEMY_ID_BASE` to
  pick up player-id broadcasts only (RemoteEnemyManager handles
  the upper partition). Skip own id (peers don't broadcast to
  themselves but defensive).
- `scripts/hud.gd::_setup_peer_target`: subscribes to
  `peer.target_changed` and calls `_refresh_tot` (matching the
  enemy branch's behaviour from Track 21B).
- `scripts/hud.gd::_resolve_tracked_target_target_id`: the
  remote-enemies check now includes `remote_players` group too.

End result: targeting a peer who is currently attacking somebody
shows ToT for the peer's target. Tracks across the peer
retargeting in real time.

## 22.I — Player portrait HUD slot

Art assets don't exist yet (only AI-generation prompts in
`docs/concepts/lore/portraits/prompts.md`). 22.I lands the wiring
so portraits auto-populate when PNGs land at
`assets/sprites/portraits/portrait_<race>_<class>.png`.

`scripts/hud.gd`:
- New `_portrait_rect: TextureRect` (96×96, positioned right of
  the player stat panel at (346, 8)).
- `_build_portrait()` builds the rect hidden.
- `_refresh_portrait()` slugifies `PlayerStats.race` +
  `PlayerStats.player_class` (lowercase, spaces → underscores,
  backticks stripped for Kel`varath), resolves the .png path,
  loads if it exists, hides if not.
- Subscribed to `PlayerStats.character_applied` so the portrait
  updates on character load.

Naming matches `prompts.md`:
- `portrait_dark_elf_magician.png`
- `portrait_human_warrior.png`
- `portrait_kelvarath_necromancer.png` (backtick stripped)
- ...etc.

Drop PNGs at `assets/sprites/portraits/` to populate. No code
changes needed for any new race/class combo — the path is
computed at runtime.

## Tests

All passing:
- 116/116 lib (one new — `starting_value_quarter_of_cap_with_floor`
  replaces the old test of same name).
- 40/40 integration in isolation (the documented AI-walks-into-melee
  flake hits occasionally under parallel load; not 22-related).
- `cast_interrupted_by_incoming_pvp_hit` from 19A still stable.
- `skill_progress_snapshot_seeded_on_enter_world` updated to the
  new 1/1 baseline assertions.

## Files touched

Server (`F:\Projects\server\`):
- `crates/protocol/src/world.rs` — no new variants; reused
  EntityTarget for peer targets.
- `crates/projectdawn-server/src/world/connection.rs`
  (+`current_target` field).
- `crates/projectdawn-server/src/world/handlers.rs` (SetTarget
  arm + `Outcome::PlayerTargetFanOut`).
- `crates/projectdawn-server/src/world/tick.rs`
  (`player_target_fanouts` queue + drain; +3 spell-damage
  interrupt insertion points).
- `crates/projectdawn-server/src/world/skills.rs`
  (`starting_value` rebalance + test rename).
- `crates/projectdawn-server/tests/world_two_clients.rs`
  (snapshot test assertions).
- `crates/gdext-net/src/lib.rs` (`send_set_target` `#[func]`).

Client (`F:\Projects\Project_Dawn\`):
- `addons/gdext_net/gdext_net.dll` (rebuilt, 3.96 MB).
- `autoloads/net.gd` (broadcast_set_target wrapper).
- `autoloads/combat.gd` (peer target broadcast on set_target).
- `autoloads/remote_player_manager.gd` (entity_target sub +
  ENEMY_ID_BASE filter).
- `scripts/remote_player.gd` (target_id + signal +
  apply_target_change).
- `scripts/hud.gd` (ToT extension for peers + portrait slot).
- `data/weapon_skill_definitions.gd`,
  `data/armor_skill_definitions.gd`,
  `data/casting_skill_definitions.gd` (cap/4 starting value).

## Carry-forward

- **Multi-window chat (Option G)** — single biggest remaining
  Track 22 piece. Three sub-chunks per the to-do list. Own
  track.
- **Portrait art assets** — generate via the prompts.md prompts,
  save to `assets/sprites/portraits/portrait_<race>_<class>.png`,
  the HUD picks them up on next character load.
- **Server-auth mount state** (Track 22.C follow-up) — peer
  visibility of mounted players.
- **Animal Husbandry tradeskill / Spirit of Wolf interaction**
  (Track 22.C follow-up).
