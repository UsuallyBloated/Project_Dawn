# Session 2026-05-20 — Track 14 Follow-ups: Lifesteal + Vendor Server-side

Two small Track 14 follow-up items shipped server-side:

1. **Lifesteal `heal_amount` on ENEMY-target spells.** Spells like
   Lifetap, Soul Drain, Exsanguinate were authored with both
   `base_damage > 0` and `heal_amount > 0` but the server arm
   ignored the heal. Now `apply_spell_damage_to_enemy` applies
   `caster.hp += min(heal_amount, damage_done)` after the
   damage roll lands.
2. **Vendor BuyItem / SellItem server-side dispatch.** The wire
   variants existed but were no-op'd. Server now processes both,
   mutates `conn.coins` + inventory, and fans `CoinsUpdate` +
   `InventoryDelta`. **Client lift deferred** — `vendor_window.gd`
   still mutates `PlayerStats.coins` + `Inventory` locally; the
   server's dispatch is dead-code until that lift lands. Wire
   shape unchanged.

## Lifesteal

`apply_spell_damage_to_enemy` signature widened: `connections`
goes from `&HashMap` to `&mut HashMap` so the helper can mutate
the caster's HP. Both call sites (single-target spell arm and
AOE arm) already had non-conflicting borrows; pass `&mut` at the
call.

The block that mutates the enemy now also returns
`damage_done = (hp_before - entity.hp).max(0.0)`. After the
block, if the spell carries both damage and heal:

```rust
if spell.heal_amount > 0.0 && damage_done > 0.0 {
    let heal = spell.heal_amount.min(damage_done);
    if let Some(caster) = connections.get_mut(&(caster_id as ClientId)) {
        let prev_hp = caster.hp;
        caster.hp = (caster.hp + heal).min(caster.max_hp);
        if caster.hp != prev_hp {
            handlers::fan_out_health_update(server, in_world_recipients,
                caster.char_id as u64, caster.hp, caster.max_hp);
        }
    }
}
```

Capping at `damage_done` (not raw `heal_amount`) matches the
GDScript reference: a 5-HP mob doesn't over-heal the caster.

### Integration test

`lifesteal_spell_heals_caster` — provisions a Shadow Knight,
SQL-bumps to level 10 + hp=5, walks to camp 0, waits for an
enemy Hit (confirms an enemy in range), captures baseline HP
from the latest self-HealthUpdate, casts Lifetap Rk. II
(50 dmg / 35 heal). Asserts a HealthUpdate for the caster lands
with hp ≥ baseline + 20 within 3 seconds (the +20 floor sits
well above any regen ticks that might drift the value).

## Vendor — server-side dispatch

### Scope decision

Server NPCs don't exist yet (NPCs are still client-side via
`scripts/vendor_npc.gd` + `data/vendor_definitions.gd`). That
means the server can't resolve `vendor_id` → vendor_type → stock
list. Three options:

| Option | Trade-off |
|---|---|
| Server NPCs first, then vendor | Right shape but blows scope |
| Skip stock validation, trust client on vendor_id | MVP this session ✓ |
| Defer entirely | Leaves coins / inventory unauthenticated |

Chose the MVP: server enforces **price + coin balance +
inventory cap** (all from the existing items.toml registry).
The `vendor_id` field is informational — a malicious client
could "buy" any stocked item at registry price, but coins
and inventory deltas are authoritative. Real stock validation
lands when server NPCs do.

### Server changes

`items::lookup_by_name(name) -> Option<&Item>` — O(N=158)
linear scan. Used by the BuyItem path (wire carries item name,
not path).

New `Outcome::BuyItemIntent` + `Outcome::SellItemIntent` +
matching `handle_message` arms. Both reject when `qty == 0` or
the player isn't in-world.

New tick.rs phases 4hi (BuyItem apply) + 4hj (SellItem apply):

**BuyItem**:
- Look up item by name via `items::lookup_by_name`.
- Compute total cost = `vendor_price * qty`.
- Reject if `conn.coins < total_cost`.
- Grant via `add_item_locating`. Partial fills (inventory cap
  ran out mid-stack) are accepted but charged only for what
  landed.
- Mutate `conn.coins`, fan `CoinsUpdate` + one `InventoryDelta`
  per touched slot.

**SellItem**:
- Resolve `SlotRef` into `(base, idx)` or `(bag_<N>, slot)`.
  `EquipSlot` rejects (player should unequip first).
- Sell price per unit = `vendor_price / 2` (matches GDScript).
- Refuses to sell a non-empty bag from a base slot (matches
  Track 14.3's drop / move rule — bag must be emptied first).
- Subtract qty from the source slot. Clear it on count == 0;
  call `ensure_bag_init` so the bags map stays consistent.
- Credit coins, fan `CoinsUpdate` + `InventoryDelta`.

New `handlers::send_coins_update` helper — single-recipient
private send, encoding `ServerWorldMsg::CoinsUpdate { coins }`
(the variant existed in the protocol crate since Track 6 but
nothing was emitting it).

### Integration tests (3 new)

- `buy_item_charges_coins_and_grants_stack` — seed 100 coins,
  buy 3 Minor Healing Potions (12 ea), assert base[0] holds 3
  potions + CoinsUpdate(64).
- `buy_item_rejects_insufficient_coins` — seed 5 coins, attempt
  to buy 1 potion (cost 12); assert no CoinsUpdate fires
  within 500 ms.
- `sell_item_credits_coins_and_removes_stack` — seed inventory
  with 4 potions in base[0], coins=0; sell all 4; assert
  InventoryDelta clears the slot + CoinsUpdate(24) lands
  (12 / 2 * 4 = 24).

### Client lift — explicit follow-up

`scripts/vendor_window.gd::_do_buy` / `_do_sell` still mutate
locally via `PlayerStats.spend_coins` / `Inventory.add_item` /
`PlayerStats.add_coins` / `Inventory.remove_item`. They should
route through new `Net.broadcast_buy_item` / `broadcast_sell_item`
wrappers and stop touching `PlayerStats.coins` directly. The
existing `Net.world_inventory_delta` signal already handles the
delta side; a new `world_coins_update` signal needs adding to
`gdext-net` + `net.gd` + `player_stats.gd`.

Same pattern as the Track 13/14.3 carry-forward for drag-and-
drop (`inventory_window.gd` / `bag_window.gd` still mutate
locally). Both lifts can ride one combined client refactor pass.

## Tests

Lib tests unchanged at 111. Integration tests grew from 32 to 35
across the two follow-ups.

`tests/world_two_clients.rs` final counts:
- 32 (post-14.3 baseline)
- +1 `lifesteal_spell_heals_caster`
- +1 `buy_item_charges_coins_and_grants_stack`
- +1 `buy_item_rejects_insufficient_coins`
- +1 `sell_item_credits_coins_and_removes_stack`
- = 35 total. All pass; `pet_attacks_owners_target` parallel-cargo
  flake recorded in earlier sessions did not surface this run.

## Files touched

- `server/crates/projectdawn-server/src/world/tick.rs` —
  lifesteal in `apply_spell_damage_to_enemy`, signature widened,
  call sites updated; new vendor intent buffers + apply phases
  4hi / 4hj.
- `server/crates/projectdawn-server/src/world/handlers.rs` —
  new `Outcome::BuyItemIntent` / `SellItemIntent` + handler
  arms; new `send_coins_update`.
- `server/crates/projectdawn-server/src/world/items.rs` —
  new `lookup_by_name`.
- `server/crates/projectdawn-server/tests/world_two_clients.rs` —
  `send_buy_item` / `send_sell_item` helpers + 4 new tests;
  `SlotRef` added to the import list.

No `Project_Dawn` (client) changes this session — server is
ready, client lift is the next step.

## Track 14 status

Original three sub-tasks (14.1 registry, 14.2 stat recompute,
14.3 bag locations) + the two cross-cutting follow-ups
(lifesteal, vendor server-side) are all done. Remaining from
the original handoff's cross-cutting list:

- **Client drag-and-drop authority lift** — inventory_window.gd
  / bag_window.gd / vendor_window.gd all still mutate local
  state instead of routing through Net. One client refactor
  pass closes both 14.3 + vendor.
- **PetCommand GUARD / SIT** — unrelated to inventory; deferred
  from Track 12.

Handoff's "After Track 14" big-ticket items kick in next:
cooldown server-auth, movement-during-cast interrupt, skill
leveling server-side, zone transitions.

## Verification done

- `cargo +1.95.0 build` clean (one pre-existing warning).
- `cargo +1.95.0 test --lib -p projectdawn-server` — 111/111 pass.
- `cargo +1.95.0 test --tests -p projectdawn-server` — 154/154
  pass across all integration suites (3 auth_smoke + 4
  inventory_persistence + 1 world_smoke + 35 world_two_clients
  + 111 lib).
- No client `.gd` changes; nothing for the user to rebuild.
