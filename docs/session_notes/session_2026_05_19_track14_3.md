# Session 2026-05-19 — Track 14.3: Bag Locations

Lifts the last `from_rows` exclusion. `'bag_<i>'` rows now load,
persist, snapshot, and move-item-between on the server, and the
client's `Inventory.gd` routes them into `bag_contents[i]` on both
the EnterWorld snapshot and live `InventoryDelta` updates.

Closes Track 14's original sub-task list (14.1 / 14.2 / 14.3).
Cross-cutting follow-ups from the handoff (lifesteal `heal_amount`,
vendor `BuyItem` / `SellItem`) remain. The client drag-and-drop
UI still mutates `Inventory` locally instead of going through
`Net.broadcast_move_item` — that's a separate UI-authority pass.

## Bag fixture

The pre-Track-14 codebase had zero bag `.tres` files (only mob-drop
materials, weapons, armor, consumables). Added `small_pouch.tres`
(`type = 12` BAG, `bag_num_slots = 4`, `vendor_price = 20`) as a
test fixture and regenerated `items.toml` via
`tools/export_items_oneshot.py` — 158 entries now.

## `PlayerInventory.bags: HashMap<u8, Vec<Option<InventoryEntry>>>`

Sparse map keyed by the base-slot index that holds the bag.
Vec length = `items::bag_num_slots(bag.item_path)` from the
registry. `None` entries mean empty bag slots.

`ensure_bag_init(base_idx)` is the synchroniser — called after
every mutation that could change a base slot. Allocates a fresh
Vec when a bag-typed item arrives in a base slot; drops the Vec
when the slot becomes empty or holds a non-bag.

Called from: `from_rows`, `add_item_locating` (loot grants),
`move_base`, `move_bag_to_base` / `move_base_to_bag` /
`move_bag_to_bag` (via `move_across`), `split_base`, `drop_base`,
`equip_from_base`, `unequip_to_base`. Cheap idempotent op so
defensive calls are fine.

## Move dispatch — `move_across`

Single top-level entry point that resolves the `(location, slot)`
pair on each side and routes to the right helper:

| src → dst | helper |
|---|---|
| `base` → `base` | `move_base` (existing) |
| `bag_N` → `bag_N` (same N) | `move_bag` (new) |
| `bag_M` → `bag_N` (different) | `move_bag_to_bag` (new) |
| `base` → `bag_N` | `move_base_to_bag` (new) |
| `bag_N` → `base` | `move_bag_to_base` (new) |

`equip` locations stay on the dedicated `equip_from_base` /
`unequip_to_base` paths — equipment isn't reachable via MoveItem.

`tick.rs` phase 4hd was simplified to always call `move_across`;
the per-touched-slot InventoryDelta fan now reads back from
either `base` or `bags[N]` depending on the returned location
string.

## Mutation rules (matching GDScript + a Track 14.3 hardening)

- **Bag-empty-required-to-move-out** — `move_base` rejects when
  `bags[src]` has any `Some(_)` entry; same on the swap target
  (you can't replace a non-empty bag in a base slot via swap).
- **No bag-in-bag** — `move_base_to_bag` rejects when the source
  item is bag-typed; `move_bag_to_base` rejects when the swap
  would push a bag back into a bag inner slot.
- **Bag must be empty to drop** — `drop_base` now returns `None`
  for non-empty bags (the client UI should empty first).
- **Track 14.3 hardening on `unequip_to_base`** — the swap-back
  rejects when `base[dst]`'s item isn't equippable in
  `equip_slot` (via `items::is_equippable_in_slot`). Stops a
  swap unequip from pushing a bag / consumable / mismatched
  gear into the paperdoll. Required updating the
  `unequip_swaps_with_existing_base_slot` unit test to use two
  real weapons (was synthetic cloth-in-weapon-slot).

## Snapshot / row plumbing

`from_rows` is now two-pass: pass 1 processes base + equip rows
(initialising bag Vecs for any bag-typed base entries via
`ensure_bag_init`); pass 2 processes `bag_<i>` rows into the
allocated Vecs. Out-of-range bag slots and rows pointing at a
base slot that turned out not to hold a bag are silently dropped.

`to_rows` and `to_snapshot_entries` walk the `bags` map and emit
one row per occupied inner slot, location string `"bag_<i>"`.
Wire shape unchanged — the existing string-based location field
already accommodated it.

## Client: `autoloads/inventory.gd`

`_on_inventory_snapshot` does the same two-pass walk: base first
(allocates `bag_contents[i]` for bag entries via
`_init_bag_contents`), then bag_<i> entries (write into the
allocated Vec). Rows whose parent base slot turned out not to be
a bag drop silently.

`_on_inventory_delta` extended with a `location.begins_with("bag_")`
branch — same parse-base-idx + write-inner-slot logic. The
base-slot branch also clears `bag_contents[slot]` on a base-slot
clear or on a non-bag item landing (kept consistent with the
server's `ensure_bag_init`).

Client-side, the drag-and-drop UI in `inventory_window.gd` /
`bag_window.gd` still mutates `Inventory` directly without
routing through `Net.broadcast_move_item`. That's a separate
authority-lift pass — Track 14.3's scope was just the
receive-side wiring. Until that lift, dragging an item into a
bag in launcher mode will diverge locally until the next
snapshot resyncs.

## Tests

Lib tests: 98 → 111 (+13).

`world::inventory::tests` (Track 14.3):
- `ensure_bag_init_allocates_inner_vec_for_bag` — pouch placed in
  base[3] gets a 4-slot Vec allocated.
- `ensure_bag_init_clears_when_base_no_longer_bag` — swap a
  pouch for a sword; `bags[3]` is removed.
- `add_item_locating_initialises_bag_on_loot_grant` — looted
  pouch lands in base[0] with its Vec allocated.
- `move_bag_swaps_inner_slots` — same-bag swap between inner
  slots 0 and 2.
- `move_base_rejects_non_empty_bag` — non-empty pouch rejects
  base→base move; both slots untouched.
- `move_base_allows_empty_bag` — empty pouch moves, `bags` entry
  follows the bag.
- `move_across_base_to_bag_rejects_bag_in_bag` — pouch into
  another pouch's inner slot rejects.
- `move_across_base_to_bag_transfers_item` — potion moves from
  base[1] into pouch's inner slot 2.
- `move_across_bag_to_base_swap_rejects_bag_dst` — swap that
  would land a bag in a bag inner slot rejects.
- `drop_base_rejects_non_empty_bag` — non-empty pouch's
  `drop_base` returns `None`.
- `roundtrip_with_bag_contents` — pouch + 2 inner items
  round-trips through `to_rows` → `from_rows` with the inner
  Vec sized correctly.
- `snapshot_entries_include_bag_rows` — `to_snapshot_entries`
  emits a `bag_0` entry alongside the base entry.
- `unequip_rejects_swap_into_nonequippable_base` — 14.3
  hardening: unequip swap with a potion in dst rejects.

`tests/world_two_clients.rs` (Track 14.3):
- `bag_contents_persist_across_reconnect` — seed pouch in base
  slot 0 + potions in `bag_0[2]` via DB, EnterWorld, assert the
  InventorySnapshot includes both rows.

Final count: 111 lib + 31 integration tests pass. No flakes this
run.

## Files touched

- `Project_Dawn/data/loot/items/small_pouch.tres` — new bag fixture.
- `server/crates/projectdawn-server/data/items.toml` — regenerated
  (158 entries).
- `server/crates/projectdawn-server/src/world/inventory.rs` —
  new `bags` field, `ensure_bag_init`, `move_bag`, `move_across`,
  three move helpers, two-pass `from_rows`, extended `to_rows` /
  `to_snapshot_entries`, bag-empty rules on `move_base` /
  `drop_base`, swap-back hardening on `unequip_to_base`, 13 new
  unit tests + 1 updated test.
- `server/crates/projectdawn-server/src/world/tick.rs` —
  `MoveItem` dispatch routed through `move_across`; per-slot
  delta payload lookup handles both `base` and `bag_<i>`
  locations.
- `server/crates/projectdawn-server/tests/world_two_clients.rs` —
  new `bag_contents_persist_across_reconnect`.
- `Project_Dawn/autoloads/inventory.gd` — two-pass snapshot
  with bag routing; bag_<i> branch in `_on_inventory_delta`.

## Carry-forward after Track 14

Track 14's original three sub-tasks are now done. Remaining
items from the handoff's cross-cutting list:

- **Lifesteal `heal_amount` on ENEMY-target spells** — small
  addition to `tick::apply_spell_damage_to_enemy`: when a spell
  with both `base_damage > 0` and `heal_amount > 0` lands,
  `caster.hp += min(heal_amount, damage_done)` + HealthUpdate.
  Spell registry already has the field.
- **Vendor `BuyItem` / `SellItem`** — registry now has
  `vendor_price`. Needs a vendor TOML (which vendors stock which
  items) + a coins delta on success.
- **Client drag-and-drop authority lift** — inventory_window.gd /
  bag_window.gd still mutate `Inventory` locally. They should
  route base/bag moves through `Net.broadcast_move_item` so the
  server is the single source of truth all the way to the UI.

Then the handoff's "After Track 14" big-ticket items kick in:
cooldown server-auth, movement-during-cast interrupt, skill
leveling server-side, zone transitions.

## Verification done

- `cargo +1.95.0 build` clean (one pre-existing warning).
- `cargo +1.95.0 test --lib -p projectdawn-server` — 111/111 pass.
- `cargo +1.95.0 test --tests -p projectdawn-server` — 150/150
  pass across all integration suites; no flake this run.
- Client `.gd` edits limited to the snapshot/delta receivers
  in `autoloads/inventory.gd`. Tool scripts unchanged.
