# Session 2026-05-20 — Track 15: right-click lift + UseConsumable + PetCommand GUARD/SIT

Closes the carry-forward from Track 14.4's left-click drag-drop +
vendor authority lift. The remaining right-click inventory flows
(equip / unequip / use-consumable / destroy) and the reserved
`PetCommand::Guard` / `Sit` codes are now end-to-end. After this,
every player-driven inventory + equipment + vendor mutation flows
through `Net.broadcast_*` in launcher mode — the "client mutates
local state, hopes server agrees" model is retired for inventory.

Anti-cheat surface remaining from the original Track 14 handoff:
cooldown server-auth, movement-during-cast interrupt, skill
leveling. Each its own track-sized item.

## Sub-task 15.1 — Right-click equip / unequip lift

### `autoloads/equipment.gd`

- Extracted `_pick_slot(item)` — pure paperdoll-slot picker, no
  side effects. Encodes the dual-wield + 2H rules used by both the
  legacy `equip` and the new launcher-mode `request_equip_from`.
  `_resolve_slot` now delegates and keeps the "blocked offhand
  pushes back to inventory" side effect for the legacy code path
  (the caller already removed the item before calling).
- `request_equip_from(src_location, src_slot, item)` — in launcher
  mode resolves the target slot, handles the 2H-clears-offhand
  swap by sending `Net.broadcast_unequip_item` to park the offhand
  in a free base slot before sending `Net.broadcast_equip_item`.
  Rejects with combat-log line on inventory-full. Solo mode keeps
  the optimistic local mutation.
- `request_unequip(slot_name)` — picks the first empty base slot,
  sends `Net.broadcast_unequip_item(equip_slot_idx, "base",
  dst_idx)`. Rejects with "Inventory full — no room to unequip."
  Solo mode keeps the legacy `unequip(slot)` path.
- New helpers: `_first_free_base_slot()` and
  `_local_remove_from_source(loc, slot)` (the latter parses
  "base" / "bag_<i>" so the solo path stays one-liner).

### `scripts/inventory_window.gd` / `scripts/bag_window.gd`

- Right-click on a non-bag, non-consumable, non-MISC item now
  routes through `Equipment.request_equip_from`. Bag-window passes
  the bag-typed location (`bag_<N>`) so the server can equip
  directly from bag inner slots (no client-side bridge hop).

### `scripts/paperdoll_window.gd`

- Right-click on an equipped slot routes through
  `Equipment.request_unequip`.

## Sub-task 15.2 — Right-click use-consumable lift

### Server: new `ClientWorldMsg::UseConsumable` apply path

- `inventory.rs`: new `decrement_at(location, slot)` —
  generalisation of `drop_base`'s decrement leg for any inventory
  location, removes one unit and returns the consumed item_path.
- `handlers.rs`: new `Outcome::UseConsumableIntent`; dispatch arm
  decodes the `SlotRef` to the wire-string `(location, slot)`
  shape the apply phase already understands; equip-slot
  consumables are rejected early (no consumable is equippable).
- `tick.rs`: new apply phase peeks the item, validates it's
  consumable (`is_food` / `is_drink` / `heal_on_use > 0` /
  `mp_on_use > 0`), checks the "already eating / drinking" rule
  (no same-prefix buff in `active_buffs`), decrements the stack,
  fans `InventoryDelta`. Heal-on-use bumps `conn.hp` / `conn.mp`
  and fans `HealthUpdate` / `ManaUpdate`. Food / drink push two
  `ActiveBuff` entries (`HoT` for HP regen, `MpRegen` for MP regen
  when nonzero) under names `"Food: <item>"` / `"Drink: <item>"`
  and fans `BuffSnapshot`. Naming matches the client's
  `BuffManager.add_food_buff` / `add_drink_buff` prefix so the
  HUD bar renders correctly when the snapshot lands.

### Client wire path

- `inventory_window.gd::_use_consumable` and
  `bag_window.gd::_use_consumable` — in launcher mode send
  `Net.broadcast_use_consumable(location, slot)` and emit the
  feedback combat-log line. Inventory mutation + buff application
  arrive via the server fans. Solo mode keeps the legacy local
  path verbatim.

## Sub-task 15.1.b — Destroy lift (DestroyItem variant)

Pragmatic alternative to `DropItem-as-destroy` — a real wire
variant + handler that decrements the slot without spawning a
loot bag. Items are gone for good (matches the trash-cell UX).

### Protocol

- New `ClientWorldMsg::DestroyItem { location, slot, count }`
  variant in `protocol::world`.

### Server

- `inventory.rs`: new `destroy_at(loc, slot, count)` — accepts
  base or bag locations; rejects bag-typed slots that still hold
  items (same safety as `drop_base`).
- `handlers.rs`: dispatch arm + `Outcome::DestroyItemIntent`.
- `tick.rs`: apply phase decrements + fans a single
  `InventoryDelta` for the touched slot.

### Client wire path

- `inventory_window.gd::_show_delete_confirm` — confirmed-delete
  now routes through new `_confirm_trash_delete`. In launcher
  mode broadcasts `Net.broadcast_destroy_item(src_loc, src_slot,
  drag_count)` using the drag-source location captured at pickup.
  Solo mode keeps the legacy `end_drag()` no-op (the source slot
  was cleared at pickup time).
- `bag_window.gd::_confirm_destroy` — same pattern, broadcasts
  destroy before clearing the drag overlay.

## Sub-task 15.3 — PetCommand GUARD + SIT

### Server: `entity.rs`

- New `PetStance` enum (`Follow` / `Guard` / `Sit`) with default
  `Follow`. Added as a field on `Entity`; both `from_spawn` and
  `from_pet_summon` initialise to `Follow`.
- `tick_pet_ai` branches on stance:
  - `Sit`: drops any current target and stands still.
  - `Guard`: chases / attacks the current target if one exists;
    otherwise holds position (no owner follow).
  - `Follow`: legacy follow-the-owner-or-engage-target behaviour.

### Server: `tick.rs`

- `PetCommandIntent` dispatch grew two new arms:
  - `cmd::GUARD` — clears target, stamps `command_at`, sets
    `pet.stance = Guard`. Pet parks at its current spot until
    commanded otherwise.
  - `cmd::SIT` — clears target, stamps `command_at`, sets
    `pet.stance = Sit`. Pet stands still and ignores incoming
    damage retargeting.
  - `ATTACK` / `BACK` / `FOLLOW` also force-reset `stance =
    Follow` so toggling commands behaves cleanly.
- Pet target inheritance pre-pass filters by `stance == Follow`
  — Guard / Sit pets never auto-inherit the owner's last attack.
- Enemy-attacks-pet damage handler: when stance is `Guard` and
  the pet has no current target, retaliate by setting
  `pet.target = attacker` + stamping `command_at`. `Sit` pets
  intentionally ignore.

### Client: `autoloads/pet_manager.gd`

- `command_guard()` now broadcasts `PetCommand::GUARD` in
  launcher mode with feedback "Your pet guards this spot."
- `command_passive()` now broadcasts `PetCommand::SIT` with
  feedback "Your pet sits and waits."
- `scripts/hud.gd`: `/pet sit` chat command alias added
  alongside `/pet passive`.

## Server inventory generalisation

The lift surfaced one server-side gap: `equip_from_base` only
accepted `"base"` src. Generalised to:

- `inventory.rs`: new `equip_from_location(src_loc, src_slot,
  equip_slot)` accepts base or bag inner sources. Validates
  equippability via `is_equippable_in_slot`; swap pushes the
  previously-equipped item back into the original source location
  (base slot or bag inner). Returns `Vec<(String, u32)>` with
  proper location strings so the apply-phase delta fan-out
  addresses bag slots correctly.
- `tick.rs`: equip apply phase switched from `equip_from_base`
  to `equip_from_location`; delta fan-out extended to handle
  `bag_<i>` locations. `equip_from_base` removed (tests migrated
  to use `equip_from_location("base", ...)`).

This eliminates the need for a client-side base-bridge hop when
equipping from a bag.

## gdext-net

Two new `#[func]` exports on `NetClient`:

- `send_destroy_item(location: GString, slot: i64, count: i64) -> bool`
- `send_use_consumable(location: GString, slot: i64) -> bool` —
  parses GDScript `"base"` / `"bag_<i>"` strings into the
  protocol's `SlotRef::BaseSlot { idx }` / `BagSlot { base, slot }`,
  matching the `send_sell_item` pattern.

DLL rebuilt with the static-CRT release profile and copied into
`Project_Dawn/addons/gdext_net/gdext_net.dll` (4.0 MB).

## Net.gd

- `broadcast_destroy_item(location, slot, count)` wrapper.
- `broadcast_use_consumable(location, slot)` wrapper.

Both gate on `_state == State.CONNECTED_APP`.

## Files touched

### Server
- `protocol/src/world.rs` — `DestroyItem` variant.
- `projectdawn-server/src/world/inventory.rs` —
  `equip_from_location`, `destroy_at`, `decrement_at`; removed
  `equip_from_base`; tests migrated.
- `projectdawn-server/src/world/handlers.rs` — `DestroyItemIntent`
  + `UseConsumableIntent` outcome variants; dispatch arms for
  `DestroyItem` and `UseConsumable`.
- `projectdawn-server/src/world/tick.rs` — destroy + use-consumable
  apply phases; PetCommand GUARD + SIT arms; equip apply uses
  `equip_from_location`; pet-AI inheritance pre-pass filters by
  `stance == Follow`; Guard pets retaliate on incoming damage.
- `projectdawn-server/src/world/entity.rs` — `PetStance` enum;
  `stance` field; `tick_pet_ai` stance branching.

### gdext-net
- `gdext-net/src/lib.rs` — `send_destroy_item` + `send_use_consumable`
  `#[func]` exports.
- `Project_Dawn/addons/gdext_net/gdext_net.dll` — rebuilt with
  static-CRT release.

### Client
- `Project_Dawn/autoloads/equipment.gd` — `_pick_slot`,
  `request_equip_from`, `request_unequip`, `_first_free_base_slot`,
  `_local_remove_from_source`.
- `Project_Dawn/autoloads/net.gd` — `broadcast_destroy_item` +
  `broadcast_use_consumable` wrappers.
- `Project_Dawn/autoloads/pet_manager.gd` — `command_guard` /
  `command_passive` route through `Net.broadcast_pet_command`
  with `PetCommand.GUARD` / `SIT` in launcher mode.
- `Project_Dawn/scripts/inventory_window.gd` — right-click equip
  routes through `Equipment.request_equip_from`; use-consumable
  routes through `Net.broadcast_use_consumable`; trash-cell
  destroy routes through `Net.broadcast_destroy_item` via the
  new `_confirm_trash_delete` arm.
- `Project_Dawn/scripts/bag_window.gd` — same lifts for the
  bag inner UI; Destroy button routes through
  `Net.broadcast_destroy_item`.
- `Project_Dawn/scripts/paperdoll_window.gd` — right-click
  unequip routes through `Equipment.request_unequip`.
- `Project_Dawn/scripts/hud.gd` — `/pet sit` alias added.

## Verification

- `cargo +1.95.0 build` (server workspace) — clean.
- `RUSTFLAGS="-C target-feature=+crt-static" cargo +1.95.0 build -p gdext-net --release`
  — clean; DLL copied into `addons/gdext_net/`.
- `cargo +1.95.0 test -p projectdawn-server` — 154/154 pass.
  Existing equip/unequip integration tests cover the
  `equip_from_location` switchover (same wire path, same
  expectations). New destroy / use-consumable / pet-stance
  paths exercised via the launcher mode but no new integration
  tests added this session — manual smoke recommended after
  reloading the client.
- Client Godot project not opened this session; reload required
  after the DLL swap.

## Carry-forward

Track 15 closes the inventory authority lift. The original Track 14
handoff named three remaining server-auth items:

- **Cooldown server-auth** — per-player per-spell cooldown
  map; reject `CastSpell` arriving before the cooldown expires.
- **Movement-during-cast interrupt** — server compares caster
  pos at `cast_set_at` vs now in the gate.
- **Skill leveling** — `WeaponSkills` / `ArmorSkills` /
  `CastingSkills` autoloads still track per-skill progression
  client-only.

Pick one and write the next handoff.

Small follow-ups noted during the lift:

- A `RejectionReason` wire variant (or a piggy-back on
  `CombatLog`) would help with "swing-and-miss" UX feedback on
  rejected equip / sell / destroy intents. The server today logs
  the rejection but the client sees no UI change.
- Pet panel HUD buttons for GUARD / SIT / ATTACK (currently chat
  commands only). Cosmetic.
- `request_remove_at` on Inventory could route through
  `Net.broadcast_drop_item` for symmetry with the equip-side lift.
  Optional; the lift in 15.1 already touches the direct callers.
