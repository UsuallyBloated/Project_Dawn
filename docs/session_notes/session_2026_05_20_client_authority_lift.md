# Session 2026-05-20 — Client drag-and-drop + vendor authority lift

Closes the carry-forward from Tracks 13.2 / 13.3 / 14.3 / 14.4:
the client-side inventory + vendor UI now routes mutations
through `Net.broadcast_*` in launcher mode instead of mutating
`Inventory` and `PlayerStats.coins` locally. The server's
`MoveItem` / `BuyItem` / `SellItem` dispatch (which has been
authoritative since the respective tracks) now actually receives
the player's intents instead of dropping silently.

Two lifts left as known follow-ups:
- Right-click flows (equip / unequip / use consumable /
  destroy / drop). These still mutate locally via
  `Equipment.equip` / `Inventory.remove_*_at` and don't send the
  matching wire variants. Smallest, most cohesive lift on its
  own.
- Item destroy via `_confirm_destroy` in `bag_window.gd` —
  currently calls `cancel_drag` (which just dropped the local
  state); should route through `DropItem` (or a new
  "delete forever" variant) in launcher mode.

## Wire decode: `CoinsUpdate`

The `ServerWorldMsg::CoinsUpdate { coins: i64 }` variant has
existed since Track 6 but the gdext-net `classify` arm fell
through to `Incoming::Raw`. Added the typed decode path:

- `#[signal] fn coins_update(coins: i64);` on `NetClient`.
- `Incoming::CoinsUpdate { coins: i64 }` variant.
- Classify arm: `ServerWorldMsg::CoinsUpdate { coins } => Incoming::CoinsUpdate { coins }`.
- Fire arm: `emit_signal("coins_update", &[coins.to_variant()])`.

DLL rebuild required — the static-CRT release build was
regenerated and copied into `Project_Dawn/addons/gdext_net/gdext_net.dll`
(4.0 MB).

## Wire encode: `send_buy_item` / `send_sell_item`

Two new `#[func]` exports on `NetClient`:

```rust
fn send_buy_item(&mut self, vendor_id: i64, item_name: GString, qty: i64) -> bool;
fn send_sell_item(&mut self, location: GString, slot: i64, qty: i64) -> bool;
```

`send_sell_item` parses the GDScript-friendly string location
(`"base"` or `"bag_<i>"`) into the protocol's `SlotRef` enum so
the vendor UI never has to mint a typed enum from GDScript.
EquipSlot sells are not exposed (server rejects them anyway).

## Net.gd

- New `signal world_coins_update(coins: int)`.
- `coins_update.connect(_on_coins_update)` in the connection
  setup block.
- `_on_coins_update` re-emits `world_coins_update` and routes
  through `PlayerStats.apply_remote_coins(coins)` so existing
  HUD / vendor UI subscribers stay wired via the existing
  `coins_changed` signal.
- New `broadcast_buy_item(vendor_id, item_name, qty)` and
  `broadcast_sell_item(location, slot, qty)` wrappers that
  gate on `_state == State.CONNECTED_APP`.

## PlayerStats.gd

New `apply_remote_coins(new_coins: int)` — overwrites `coins`
and emits `coins_changed`. The only path that touches `coins`
from the server side; `spend_coins` / `add_coins` remain for
solo / Test Room mode and the now-shrunk legacy paths in
`vendor_window.gd`.

## inventory_window.gd

`_on_cell_input` LEFT-click pickup branch — in launcher mode
SKIPS the `Inventory.clear_base_slot(index)` call. The source
slot stays visually filled until the server-fanned
`InventoryDelta` from the drop click confirms the move. Solo
mode preserves the optimistic local clear.

`_on_cell_input` LEFT-click drop branch — in launcher mode
routes through `Net.broadcast_move_item(src_loc, src_slot,
"base", index)`. `src_loc` is `"base"` if the drag originated
from another base slot (`drag_source_bi == -1`), or
`NetProtocol.inv_location_bag(drag_source_bi)` if it came from a
bag inner. `end_drag()` runs without local mutation; the server
fans `InventoryDelta` per touched slot, which `autoloads/inventory.gd._on_inventory_delta`
already applies.

`_return_drag_to_source` — short-circuits to `_clear_drag()`
in launcher mode (nothing to restore; the slot was never
emptied).

UX side effect: the legacy "swap-then-continue-carrying-the-displaced-
item" behaviour is dropped in launcher mode. Drop-on-occupied
fires a server swap and ends the drag; users click the
displaced item again if they want to keep moving it.

## bag_window.gd

Same lift pattern as `inventory_window.gd` but with `bag_<N>`
locations on both src and dst. Pickup skips the local clear;
drop sends `Net.broadcast_move_item` and routes to
`NetProtocol.inv_location_bag(bag_index)` for the dst.

The destroy flow in `_confirm_destroy` is unchanged — flagged
as a known follow-up.

## vendor_window.gd

`_populate_list` SELL mode — rebuilt to walk
`Inventory.base_slots` + `Inventory.bag_contents` directly
instead of via `Inventory.all_slots()`. Each `_sell_items`
entry now carries `{item, count, location, slot_idx}` so the
server-side `SellItem` dispatch has the location context the
flat `all_slots()` was dropping.

`_do_buy` — in launcher mode:
- Pre-flight check: reject if `PlayerStats.coins < total` (UI
  affordance; the server enforces too).
- Send `Net.broadcast_buy_item(0, item.item_name, _qty)`.
  `vendor_id == 0` is informational; server NPCs don't yet
  exist (Track 14.4 carry-forward).
- Show "Ordered ..." feedback while the server confirms.
- Don't touch `PlayerStats.coins` or `Inventory` — both arrive
  via `CoinsUpdate` + `InventoryDelta`.

`_do_sell` — in launcher mode:
- Send `Net.broadcast_sell_item(location, slot_idx, actual_qty)`
  using the slot's tracked `(location, slot_idx)`.
- Show "Sold ..." feedback while the server confirms.
- Don't touch `Inventory.remove_item` or `PlayerStats.add_coins`.

Solo mode legacy paths preserved verbatim under the
`if Net.is_launcher_mode()` gate.

## Carry-forward

Right-click equip / unequip / consumable / destroy lifts remain
the natural next step. Touch points:
- `scripts/inventory_window.gd::_on_cell_input` right-click
  branch.
- `scripts/bag_window.gd::_on_slot_input` right-click branch.
- `autoloads/equipment.gd::equip` / `unequip` — currently
  mutate `equipped` locally; should route through
  `Net.broadcast_equip_item` / `broadcast_unequip_item`.
  `_resolve_slot` (dual-wield + 2H weapon logic) stays
  client-side as the slot picker.

Server NPCs + per-vendor stock validation is also unblocked
once that work lands.

## Files touched

- `server/crates/gdext-net/src/lib.rs` — new
  `coins_update` signal + `Incoming::CoinsUpdate` + classify
  arm + fire arm; new `send_buy_item` / `send_sell_item`
  `#[func]` exports.
- `Project_Dawn/addons/gdext_net/gdext_net.dll` — rebuilt
  with the static-CRT release profile to match the existing
  `build.ps1` (4.0 MB).
- `Project_Dawn/autoloads/net.gd` — `world_coins_update`
  signal + connect/re-emit + `broadcast_buy_item` /
  `broadcast_sell_item` wrappers + `_on_coins_update`
  handler routing through `PlayerStats.apply_remote_coins`.
- `Project_Dawn/autoloads/player_stats.gd` —
  `apply_remote_coins(int)`.
- `Project_Dawn/scripts/inventory_window.gd` — launcher-mode
  routing in `_on_cell_input` + `_return_drag_to_source`.
- `Project_Dawn/scripts/bag_window.gd` — launcher-mode
  routing in `_on_slot_input`.
- `Project_Dawn/scripts/vendor_window.gd` — `_populate_list`
  carries (location, slot_idx) per sell entry; `_do_buy` /
  `_do_sell` route through `Net.broadcast_*` in launcher mode.

## Verification done

- `cargo +1.95.0 build` (server workspace) — clean.
- `RUSTFLAGS="-C target-feature=+crt-static" cargo +1.95.0 build -p gdext-net --release`
  — clean; DLL copied into `addons/gdext_net/`.
- `cargo +1.95.0 test --tests -p projectdawn-server` — 154/154
  pass (no client-side wire change affects test coverage; the
  vendor server-side tests from the prior commit still hold).
- Client Godot project not opened this session; reload required
  after the DLL swap (the project file's gdext_net.gdextension
  picks it up automatically on reload).
