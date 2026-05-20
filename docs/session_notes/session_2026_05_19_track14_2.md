# Session 2026-05-19 — Track 14.2: Stat Recompute on Equip

Server now derives `max_hp` / `max_mp` / `max_stamina` / per-stat
bonuses / `equipped_armor` from the equipped item set instead of
trusting the client's `EquipUpdate` claim. The Track 6 handler
that cached the client's armor number stays for one track as a
logged no-op; old clients still send the message.

Sub-tasks 14.1 and 14.2 of the handoff are now closed. 14.3 (bag
locations) is the remaining piece of the original Track 14 plan.

## `EquipStatBonuses` cache on `PerConnection`

New field `equip_stat_bonuses: EquipStatBonuses`. Holds the running
total of stat affixes contributed by the currently-equipped item
set. Initialised to zero in `from_spawn`. The recompute pass diffs
the new gear total against this cached snapshot so it can apply
signed deltas to `conn.{strength, ..., max_hp, equipped_armor}`
without re-deriving the base race+class formula.

Kept distinct from `active_buffs` deltas. Spells like Bless layer
their `apply_stat_deltas` directly onto `conn.strength` /
`conn.max_hp`. Equipment changes only read / write `equip_stat_bonuses`,
so the two systems compose without stomping each other. Unit test
`recompute_orthogonal_to_external_max_hp_changes` pins the
contract.

## `inventory::recompute_equipped_stats(conn) -> RecomputeResult`

The core helper. Iterates `conn.inventory.equipment`, looks each
item up in the registry, sums affixes, applies the diff against
`conn.equip_stat_bonuses`. Returns `RecomputeResult` flags
indicating which of `max_hp` / `max_mp` / `max_stamina` actually
changed so the caller knows whether to fan resource updates.

HP / MP / stamina behaviour mirrors `PlayerStats.apply_item_bonuses`
+ `remove_item_bonuses` in [autoloads/player_stats.gd:181-211](../../autoloads/player_stats.gd#L181-L211):
- On equip (max goes up): only the max moves. Current resources
  stay put; the player has to heal back into the new headroom.
- On unequip (max goes down): max drops, and current is clamped
  against the new max if it was above it.
- Floors: `max_hp >= 1.0`, `max_mp >= 0.0`, `max_stamina >= 1.0`.

`equipped_armor` is set to the sum of `armor` fields across the
equipped set (floored at 0). The Track 6 PvP / enemy-on-player
damage paths read `equipped_armor` unchanged, but they now get
the server-derived value instead of the client's claim.

Items not in the registry (`items::lookup` returns `None`)
contribute zero. That covers any stale `.tres` paths that survived
a rename without a re-export — they silently no-op until the
registry catches up.

## Three call sites

1. **`tick.rs` phase 4hg (EquipItem dispatch)** — after
   `equip_from_base` succeeds: recompute, then fan
   `HealthUpdate` / `ManaUpdate` / `StaminaUpdate` to
   `in_world_recipients_now` if any resource max moved. The fan
   includes the equipping player themselves so their HUD updates
   without waiting for the next regen broadcast.

2. **`tick.rs` phase 4hh (UnequipItem dispatch)** — mirror of 4hg
   in the other direction. Same recompute + fan-on-change logic.

3. **`tick.rs` Connect handler (load_character)** — right after
   `conn.inventory = PlayerInventory::from_rows(&inv_rows);`,
   call recompute so persisted equipped items reapply their
   bonuses before the EnterWorld snapshot fans the initial
   resource state. No explicit fan needed; step 4a's resource
   seed picks up the corrected `conn.max_hp` / `conn.max_mp` /
   `conn.max_stamina`.

The equip / unequip dispatch logs (`EquipItem applied`,
`UnequipItem applied`) now include `max_hp`, `max_mp`, and
`armor` so on-the-fly stat changes are visible in server logs
without needing extra DB inspection.

## `EquipUpdate` deprecated

The Track 6 handler that cached the client's `equipped_armor`
claim is now a logged no-op. Track 15 (or whichever future track
removes the variant) can drop it from the protocol; today it
stays so old clients still complete their handshake without
errors.

```rust
ClientWorldMsg::EquipUpdate { armor } => {
    // Track 14.2 — deprecated. The server now derives armor /
    // stat bonuses from the registry. Old clients still send
    // this; we log + ignore.
    tracing::debug!(
        char_id = conn.char_id,
        client_armor_claim = armor,
        server_armor = conn.equipped_armor,
        "EquipUpdate received — ignored (server-derived since Track 14.2)"
    );
    Outcome::Continue
}
```

## Tests

Lib tests: 91 → 98 (+7 new in `inventory::tests`, plus the 14.1
additions that were already in the post-14.1 baseline).
Integration tests: +1 (`equip_increases_max_hp` in
`world_two_clients.rs`).

`world::inventory::tests` (Track 14.2):
- `recompute_no_equipment_is_noop` — fresh conn + empty
  equipment → no change, no recompute flag set.
- `recompute_picks_up_chest_armor_and_stats` — Iron Chain Vest
  (str+1, con+2, max_hp+25, armor+18) lands correctly; current
  hp unchanged.
- `recompute_unequip_reverses_stats_and_clamps_current_hp` —
  player healed into the bonus headroom, unequip drops max
  back to base and clamps current hp down.
- `recompute_unequip_below_current_does_not_drop_hp` — current
  hp stays put when below the new max.
- `recompute_sums_across_multiple_pieces` — sword (str+2) +
  vest (str+1, armor+18) → str=13, armor=18.
- `recompute_ignores_unknown_item_paths` — orphaned path
  contributes nothing; no crash.
- `recompute_orthogonal_to_external_max_hp_changes` — Bless
  +30 max_hp pre-applied via `conn.max_hp +=` survives a
  subsequent equip + unequip cycle (gear deltas applied
  cleanly on top, bless preserved).

`tests/world_two_clients.rs` (Track 14.2):
- `equip_increases_max_hp` — seeds a vest in base slot 0,
  connects as Human Warrior (base max_hp = 200), sends
  EquipItem(0 → chest slot), asserts a `HealthUpdate { max_hp:
  225.0 }` arrives.

The Track 13.3 integration test `equip_item_moves_base_to_paperdoll`
needed an item-path swap (was `res://items/sword.tres`, now
`res://data/loot/items/iron_short_sword.tres`) — Track 14.1's
`is_equippable_in_slot` rejects unknown paths, so the synthetic
path that worked before would have been rejected silently
post-14.1. Caught when the test failed under the full suite run.

`pet_attacks_owners_target` is an unrelated parallel-cargo flake
(Track 11 notes document AI-walks-into-melee timing under CPU
contention); passes in isolation.

## Files touched

- `crates/projectdawn-server/src/world/connection.rs` — new
  `equip_stat_bonuses` field; init in `from_spawn`.
- `crates/projectdawn-server/src/world/inventory.rs` — new
  `EquipStatBonuses`, `RecomputeResult`,
  `recompute_equipped_stats` free function; 7 new unit tests.
- `crates/projectdawn-server/src/world/tick.rs` — recompute calls
  at three sites (load_inventory, equip dispatch, unequip
  dispatch); resource fan on max change.
- `crates/projectdawn-server/src/world/handlers.rs` —
  `EquipUpdate` demoted to no-op with deprecation log.
- `crates/projectdawn-server/tests/world_two_clients.rs` —
  registered weapon path in `equip_item_moves_base_to_paperdoll`;
  new `equip_increases_max_hp` integration test.

## Carry-forward

Track 14.3 (bag locations) is the remaining handoff item. Server
already has `items::bag_num_slots(path)` and `from_rows` /
`to_rows` plumbing; needs the `PlayerInventory.bags` HashMap,
the new MoveItem routing for `'bag_<i>'` locations, and the
empty-bag-required-to-unequip-bag rule.

Lifesteal `heal_amount` on ENEMY-target spells is a tiny add to
`tick::apply_spell_damage_to_enemy` — the spell registry already
has `heal_amount`; need to fire `caster.hp += min(heal_amount,
damage_done)` and a HealthUpdate.

Vendor pricing (`ClientWorldMsg::BuyItem` / `SellItem`) is a
14.4-ish follow-up: the registry now has `vendor_price`; needs
vendor TOML + a coins delta on success.

## Verification done

- `cargo +1.95.0 build` clean (one pre-existing warning).
- `cargo +1.95.0 test --lib -p projectdawn-server` — 98/98 pass.
- `cargo +1.95.0 test --test inventory_persistence` — 4/4 pass.
- `cargo +1.95.0 test --test world_two_clients` —
  isolated: 30/30 pass. Full-suite parallel run: 29/30
  (pet_attacks_owners_target flake; passes alone).
- No client `.gd` changes; old clients still send `EquipUpdate`
  and get a debug log line on the server.
