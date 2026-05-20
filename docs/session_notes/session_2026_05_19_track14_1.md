# Session 2026-05-19 — Track 14.1: Server-side Item Registry + Equip Validation

Sub-task 14.1 of the handoff. Server gains a generalised item lookup
(`items::Item` replacing the weapon-only `Weapon`); equip dispatch
rejects mismatched slots; loot `add_item_locating` respects
per-item `max_stack` and refunds leftover stacks to the bag instead
of dropping them. 91 → 99 server lib tests (+8).

Closes three deferrals from Track 13.3's handoff:
- Item-vs-slot validation on equip (helm-in-weapon-slot rejected).
- `max_stack` ceilings — pickup overflow spills into a new slot,
  capped at the registry value; further overflow stays in the bag.
- Foundation for 14.2 (stat recompute) and 14.3 (bag locations).

Not yet shipped: stat recompute (14.2), bag locations (14.3),
lifesteal `heal_amount`, vendor pricing intents. Those keep the
existing TODO comments and lean on the registry that landed today.

## Data side — items.toml regenerated from .tres

The registry's source of truth is the existing 157
`data/loot/items/*.tres` files. Two paths to regenerate the TOML:

1. **`tools/export_items_oneshot.py`** — Python one-shot used to
   bootstrap the initial TOML. Re-runnable for follow-ups, but the
   canonical regen tool is the GDScript editor script below.
2. **`tools/export_items.gd`** — `@tool extends EditorScript`,
   mirrors the `export_spells.gd` pattern. Open in Godot, File →
   Run. Emits the same TOML the Python one does so swapping
   between the two has no diff.

Output path is hard-coded to
`F:/Projects/server/crates/projectdawn-server/data/items.toml`;
adjust if the server lives elsewhere on your machine.

Default-suppression keeps the TOML lean — fields whose values match
the script defaults (`0`, `0.0`, `false`, `""`) are omitted. The
Rust struct's `#[serde(default)]` rehydrates them. Always-emitted:
`path`, `name`, `item_type`, `stack_size`.

Field rename map (client `.tres` → server TOML):

| client | TOML |
|---|---|
| `item_name` | `name` |
| `type` (int) | `item_type` (snake_case string) |
| `bonus_strength` / `bonus_dexterity` / … | `str_bonus` / `dex_bonus` / … |
| `bonus_max_hp` / `bonus_max_mp` | `max_hp_bonus` / `max_mp_bonus` |
| `weapon_damage_min` / `weapon_damage_max` | `damage_min` / `damage_max` |
| `weapon_skill` | `skill` |
| `bonus_armor` | `armor` |

## Server side — `world::items` rewrite

`crates/projectdawn-server/src/world/items.rs`:

- New `ItemType` enum (13 variants — Weapon, Offhand, Head, Chest,
  Legs, Feet, Hands, Ring, Neck, Consumable, Misc, Augment, Bag).
  `#[serde(rename_all = "snake_case")]` matches the TOML.
- New `Item` struct replaces `Weapon`. Same field names where they
  overlap (`damage_min`, `damage_max`, `weapon_delay`, `skill`,
  `is_ranged`) so existing callers in `combat.rs` /`tick.rs` don't
  change — just the resolved type does.
- `lookup(path) -> Option<&'static Item>` signature unchanged.
- New helpers:
  - `is_equippable_in_slot(path, slot_u8) -> bool` — encodes the
    type-to-slot map. Weapons may sit in slot 0 (weapon) or slot 1
    (offhand for dual-wield); other equippable types map 1:1 to
    their slot index. Consumables / misc / augments / bags always
    return false. Unknown paths always return false.
  - `max_stack(path) -> u32` — registry value or `u32::MAX` for
    unknown paths (preserves the legacy unbounded-stack behaviour
    for runtime-built items).
  - `bag_num_slots(path) -> Option<u32>` — `Some(n)` for BAG-typed
    items with non-zero capacity; consumed by Track 14.3.

The Track 6 dual-wield skill gate still lives client-side; the
server intentionally only checks type compatibility for now. Skill
leveling moves server-side in a later track.

## Equip validation in `equip_from_base`

`PlayerInventory::equip_from_base` now:

1. Range-checks `src` and `equip_slot` (existing behaviour).
2. **New**: inspects `self.base[src]`'s `item_path` and calls
   `items::is_equippable_in_slot(...)`. Rejects without mutating
   either slot if the type doesn't match. Items not in the
   registry reject too — closes the door on a forged path.
3. Continues with the existing take / insert / swap-back flow.

`Err("item not equippable in this slot")` is the new failure mode;
tick.rs's existing `EquipItem rejected` debug log already prints
the `Err` content unchanged.

## `add_item_locating` — `max_stack` + leftover refund

Signature changed from `Result<usize, &str>` to
`Result<(Vec<usize>, u32), &str>`:

- First pass tops up existing same-item stacks up to `max_stack`.
- Second pass claims empty slots, each starting a fresh stack
  capped at `max_stack`.
- Returns the list of touched slot indices (so the caller fans one
  InventoryDelta per slot) plus a leftover count for the portion
  that didn't fit. Empty `touched_slots` + nonzero `leftover` =
  full inventory.

The convenience `add_item(path, count)` shim becomes a strict
"must place all or fail" wrapper for unit-test ergonomics.

## Loot dispatch — partial fill stays in the bag

`tick.rs` phase 4ka (loot apply):

- Branches on `add_item_locating`'s new return shape; fans an
  `InventoryDelta` per touched slot (was: one delta for the
  single returned slot).
- Computes `placed = count - leftover`; sends `LootGranted` for
  the placed portion only.
- `leftover > 0` pushes the unplaced stack back into `bag.items`
  via `loot::LootItemStack`. The existing `bag.items.is_empty()`
  branch below handles the bag-still-has-items / bag-now-empty
  fan-out unchanged, so the looter (and any nearby spectators) see
  the bag's residual contents via the next `fan_out_loot_bag_spawn`.
- Logs `loot partially placed; remainder refunded to bag` at info
  level when a refund fires.

## Tests

Lib tests: 91 → 99.

`world::items` (8 new):
- `embedded_toml_parses`, `empty_path_returns_none`,
  `unknown_path_returns_none`, `iron_short_sword_resolves_as_weapon`,
  `cloth_robe_resolves_as_chest`,
  `minor_healing_potion_resolves_as_consumable_with_stack`,
  `is_equippable_*` (weapon-or-offhand / chest-only / consumable-never /
  unknown-never), `max_stack_known_vs_unknown`.

`world::inventory` (5 new + 2 updated to use registered paths):
- `equip_rejects_wrong_slot_type` — cloth robe into weapon slot,
  asserts source + paperdoll unchanged on reject.
- `equip_rejects_consumable_in_any_slot` — health potion across
  slots 0..=8, all reject.
- `equip_rejects_unknown_item_path` — forged `res://items/forged_lies.tres`
  rejects.
- `add_item_caps_at_max_stack_and_spills` — 15 potions into 8
  empty slots: slot 0 → 10, slot 1 → 5, leftover 0.
- `add_item_returns_leftover_when_inventory_caps_out` — 80 potions
  fill all 8 slots at cap, additional 5 returns leftover 5,
  touched empty.
- `add_item_partial_fill_returns_leftover` — pre-loaded with 7
  capped potion stacks + 1 sword: 25 more potions can't be placed
  anywhere, leftover 25, touched empty.

Existing integration suite (`tests/inventory_persistence.rs`,
`tests/world_two_clients.rs`, `tests/world_smoke.rs`) still passes
unchanged.

## Files touched

- `crates/projectdawn-server/src/world/items.rs` — rewrite
  (Weapon → Item, ItemType enum, new helpers).
- `crates/projectdawn-server/src/world/inventory.rs` —
  `add_item_locating` signature + max_stack logic;
  `equip_from_base` validation; new tests.
- `crates/projectdawn-server/src/world/tick.rs` — loot dispatch
  branch on new return shape + leftover refund.
- `crates/projectdawn-server/data/items.toml` — regenerated, 7 →
  157 entries.
- `Project_Dawn/tools/export_items.gd` — new canonical exporter.
- `Project_Dawn/tools/export_items_oneshot.py` — bootstrap helper.

## Carry-forward for 14.2 / 14.3

The handoff's stat recompute (14.2) reads `*_bonus` / `armor` fields
from the registry that landed today; nothing else gated. The bag
locations work (14.3) reads `bag_num_slots` (already wired) plus
the existing `from_rows` / `to_rows` / `to_snapshot_entries`
plumbing on `PlayerInventory`. Both should land cleanly on top.

Lifesteal `heal_amount` on ENEMY-target spells is a tiny add to
`tick::apply_spell_damage_to_enemy` — server-side spell registry
already has `heal_amount`; just needs to fire the caster heal when
the spell has both `base_damage > 0` and `heal_amount > 0`.

## Verification done

- `cargo +1.95.0 build` clean (one pre-existing unrelated warning).
- `cargo +1.95.0 test --lib -p projectdawn-server` — 99/99 pass.
- `cargo +1.95.0 test --test inventory_persistence` — 4/4 pass.
- Godot project not opened this session; tool scripts under
  `tools/` are isolated EditorScripts that don't load at runtime.
  No client `.gd` files were changed.

User should regenerate `items.toml` via `tools/export_items.gd` (or
the Python one-shot) whenever an item `.tres` field the server
cares about changes. Other `.tres` edits — descriptions, icons,
augment slot contents — stay client-only and don't need a regen.
