# Session 2026-05-19 — Track 13: Server-side Inventory (1, 2, 2.b, 3)

Four sub-tasks shipped today, seven commits across server + client.
Inventory lifts from "client-authoritative, server doesn't see it" to
"server is source of truth for what every player owns and where it
sits in their base inventory + paperdoll." 84 → 117 server tests.

After Track 13, every gameplay-relevant piece of player state is
server-authoritative: HP/MP/Stamina, position, target, buffs, CC,
group, pets, **inventory + equipment**. The remaining gap is *what
the items actually do* — stat block, bag size, equippability — which
all converge on the server-side item registry (Track 14, handoff
written).

## 13.1 — Foundation: schema + load/save (`783401c`)

Lays the storage layer. Server gains a `PlayerInventory` snapshot
per connection, populates it on `load_character`, persists on the
existing 60 s checkpoint cadence + disconnect-final-save. Loot
grants now mutate the server's view; wire shape is unchanged so the
client's existing flow keeps working.

- New `0002_inventory.sql` migration: `character_items` table keyed
  by `(char_id, location, slot)` with ON DELETE CASCADE. `location`
  is `'base'` today; `'bag_<i>'` (Track 14) and `'equip'` (13.3)
  arrive without another migration.
- `db::InventoryRow` + `load_inventory(pool, char_id)` +
  `save_inventory(pool, char_id, rows)` (atomic DELETE+INSERT in
  one transaction).
- New `world::inventory` module:
  - `PlayerInventory` with `base: Vec<Option<InventoryEntry>>` of
    length `BASE_SLOT_COUNT = 8`.
  - `add_item(path, count)` stacks onto existing same-path slot
    first, falls back to first empty. Unbounded stacks for now
    (server has no max_stack metadata).
- `PerConnection.inventory: PlayerInventory` + `inventory_dirty:
  bool`. Initialized in `from_spawn`; overwritten from DB rows
  immediately after `load_character` succeeds.
- Loot dispatch in tick.rs mutates `conn.inventory` and flips
  dirty. Inventory full just logs (the LootGranted still fires).
- `persistence::checkpoint_dirty` writes inventory rows alongside
  position + resources.

**Tests:** 7 unit tests on PlayerInventory semantics + 4
integration tests in `tests/inventory_persistence.rs` covering
roundtrip, atomic overwrite, fresh-character empty, ON DELETE
CASCADE.

## 13.2 — Authority lift: Snapshot + Delta + MoveItem (`8c495e2`, client `34dd6c8`)

Wire shape change. Protocol bumped `PD_W0008 → PD_W0009`. Server is
now the source of truth for **which slot** an item sits in.

- New variants:
  - `ServerWorldMsg::InventorySnapshot { entries: Vec<(String, u32, String, u32)> }`
    — fanned privately to new joiner on EnterWorld; parallel
    `(location, slot, item_path, count)` tuples.
  - `ServerWorldMsg::InventoryDelta { location, slot, item_path:
    Option<String>, count }` — single-slot mutation. None clears.
  - `ClientWorldMsg::MoveItem { src_location, src_slot,
    dst_location, dst_slot }` — replaces the unused scaffolded
    SlotRef-based variant that had no GDScript bincode encoder.
- New `PlayerInventory` methods:
  - `add_item_locating(path, count)` returns the chosen slot so the
    loot dispatch fans a targeted Delta.
  - `to_snapshot_entries()` projects to the wire shape.
  - `move_base(src, dst)` — atomic move/swap/merge.
- tick.rs:
  - `newly_in_world` loop sends `InventorySnapshot` privately to
    each new joiner.
  - Loot dispatch now calls `add_item_locating` and fans the
    server-chosen `InventoryDelta` alongside the existing
    LootGranted (which the client still uses for the combat-log
    line).
  - New phase 4hd processes `MoveItemIntent`: validates locations
    + delegates to `move_base` + fans `InventoryDelta` per touched
    slot.

**Client side:**
- `gdext-net`: `inventory_snapshot` / `inventory_delta` signals,
  `send_move_item` entrypoint.
- `Net.gd`: re-emit + `broadcast_move_item` wrapper.
- `scripts/net/protocol.gd` (and launcher mirror):
  `SW_INVENTORY_SNAPSHOT` / `SW_INVENTORY_DELTA` tags +
  `INV_LOCATION_BASE` / `INV_LOCATION_EQUIP` constants +
  `inv_location_bag(i)` helper.
- `autoloads/inventory.gd` subscribes to the new signals.
  `_on_inventory_snapshot` wipes `base_slots` and rebuilds from
  the wire tuples; `_on_inventory_delta` applies single-slot
  mutations. Only fires in launcher mode (Net never emits these
  in solo).
- `RemoteLootBagManager._on_loot_granted` skips local
  `Inventory.add_item` in launcher mode — server's Delta does
  the slot mutation; the manager just logs the pickup.

**Tests:** 2 integration tests — `inventory_snapshot_arrives_on_enter_world`
(empty snapshot fans on EnterWorld), `move_item_empty_source_drops_silently`
(negative path).

## 13.2.b — Split + Drop (`61d66d1`, client `279d499`)

Finishes the move/split/drop trio. Bag-location MoveItem stays
deferred (needs item registry for `bag_num_slots`).

- New variants on PD_W0009 (no bump — additive):
  - `ClientWorldMsg::SplitStack { src_location, src_slot, dst_location, dst_slot, count }`
  - `ClientWorldMsg::DropItem { location, slot, count }`
    (count == 0 = whole stack)
- New `PlayerInventory` methods:
  - `split_base(src, dst, count)` — empty-dst transfer / same-path
    merge / different-path reject. Drains src completely if
    `count == entry.count`.
  - `drop_base(slot, count)` — partial or whole stack. Returns
    `(item_path, actual_removed)` or None on empty.
- Two new dispatch phases (4he, 4hf):
  - SplitStack fans one Delta per touched slot.
  - DropItem fans a Delta for the source slot (cleared or with
    residual count) + spawns a server-owned `LootBag` at the
    player's pos via the existing AOI-filtered loot pipeline. FFA
    — any nearby player can pick it up.
- Removed the stale scaffolded SlotRef-based `DropItem` variant
  alongside the prior `MoveItem`/`EquipItem`/`UnequipItem` purge.

**Client side:**
- `gdext-net`: `send_split_stack` + `send_drop_item`.
- `Net.gd`: `broadcast_split_stack` + `broadcast_drop_item`.

**Tests:** 7 new unit tests on split/drop semantics, 2 integration
tests (`split_stack_carves_off_count`, `drop_item_creates_loot_bag_at_player_pos`).
Used the `db::save_inventory` direct-write pattern to seed
inventory before EnterWorld so tests don't need a real loot-drop
flow.

## 13.3 — Equipment / paperdoll (`bb3c4c0`, client `33e1c41`)

Items now move between inventory and the paperdoll authoritatively,
paperdoll persists, EnterWorld snapshot includes equip rows. Stat
recompute + item-vs-slot validation are **explicitly deferred** —
both need the server-side item registry that lands in Track 14.

- New variants on PD_W0009:
  - `ClientWorldMsg::EquipItem { src_location, src_slot, equip_slot }`
  - `ClientWorldMsg::UnequipItem { equip_slot, dst_location, dst_slot }`
  - `equip_slot` u8 maps to `protocol::world::EquipSlot` enum order
    (weapon=0, offhand=1, head=2, chest=3, legs=4, feet=5, hands=6,
    ring=7, neck=8).
- `PlayerInventory.equipment: HashMap<u8, InventoryEntry>` (sparse;
  only occupied slots).
- `equip_from_base(src, equip_slot)` + `unequip_to_base(equip_slot,
  dst)` — both handle swap-with-existing.
- `from_rows` honours 'equip' rows; `to_rows` /
  `to_snapshot_entries` include them so persistence + snapshot
  survive across restarts.
- Two new dispatch phases (4hg, 4hh) fan one InventoryDelta per
  touched slot — typically two Deltas per intent (base slot + equip
  slot).

**Client side:**
- `gdext-net`: `send_equip_item` / `send_unequip_item`.
- `Net.gd`: `broadcast_equip_item` / `broadcast_unequip_item`.
- `Inventory` autoload's `_on_inventory_snapshot` now routes 'equip'
  entries to `Equipment.apply_remote_equip(slot, item)`. New
  `apply_remote_snapshot_clear()` wipes the paperdoll before the
  fresh fan-out re-applies.
- `_on_inventory_delta` routes 'equip' to
  `Equipment.apply_remote_equip` / `_unequip`.
- `Equipment` autoload's three new `apply_remote_*` methods set/clear
  the equipped dict + emit `equipment_changed` **without** running
  the legacy `add/remove_stat_bonuses` path. Stats stay
  client-trusted via the legacy `EquipUpdate` message until the
  server-side item registry lands.

**Tests:** 7 new unit tests on equip/unequip/swap semantics, 3
integration tests (`equip_item_moves_base_to_paperdoll`,
`equip_item_empty_source_drops_silently`,
`snapshot_includes_persisted_equipment`).

## Test results

117 server tests pass (started Track 13 at 84): +24 across the
four sub-tasks. The `pet_pulls_aggro_via_threat_reaggro` test
continues to be intermittently flaky under sustained parallel-binary
CPU contention; passes isolated in ~6 s. Known issue from Track 12.

## Commits

- Server `783401c` — Track 13.1: server-side inventory foundation
- Server `8c495e2` — Track 13.2: snapshot + delta + MoveItem (PD_W0008 → PD_W0009)
- Client `34dd6c8` — Track 13.2 client: Inventory autoload + RemoteLootBagManager gating
- Server `61d66d1` — Track 13.2.b: SplitStack + DropItem
- Client `279d499` — Track 13.2.b client: broadcast wrappers
- Server `bb3c4c0` — Track 13.3: equip / unequip + paperdoll persistence
- Client `33e1c41` — Track 13.3 client: paperdoll mirror via Equipment.apply_remote_*

Launcher's `scripts/net/protocol.gd` already received the inventory
tag mirror in commit `8d2a328` (Track 13.2). 13.2.b and 13.3 added
no new tags so no further launcher commits needed.

## Documented deferrals

All point at the same root cause: **no server-side item registry**.

- **'bag_<i>' locations** — `PlayerInventory` doesn't model bag rows
  because the server doesn't know `bag_num_slots` per bag item.
- **Item-vs-slot validation** — server only byte-range-checks
  equip_slot indices. A modified client could equip a helmet into
  the weapon slot.
- **Stat recompute on equip/unequip** — `max_hp` / `max_mp` /
  `equipped_armor` stay driven by the legacy client-trusted
  `EquipUpdate` message because the server doesn't know what stats
  the equipped item grants.
- **Inventory full rejection on loot** — server uses unbounded
  stacks, so "inventory full" never trips. Real rejection needs
  `max_stack` per item.
- **Lifesteal `heal_amount` on ENEMY-target spells** (Lifetap, Soul
  Drain) — same waiting room since Track 9.

Track 14 (handoff `handoff_track_14.md`) lays this in.

## Notes / quality

- Removed three scaffolded SlotRef-based variants (`MoveItem`,
  `EquipItem`, `UnequipItem`, `DropItem`) that pre-existed in the
  protocol crate but were never wired — the GDScript side has no
  bincode encoder for tagged enums. Replaced with the string-based
  location wire shape that round-trips cleanly through gdext-net.
- The InventorySnapshot fan-out on EnterWorld is always-fire (even
  when empty) so the client treats receiving it as the "seed
  complete, defer to Deltas" signal. Avoids a race where loot
  arrives before the seed lands.
- `pet_pulls_aggro_via_threat_reaggro` flake threshold is still 35 s
  per the Track 12 bump; no further timeout adjustment needed.
- `total_count_of` on PlayerInventory carries `#[allow(dead_code)]`
  for now — Track 14 picks it up to validate "player has at least
  N of item X" for crafting / vendor sell flows.
