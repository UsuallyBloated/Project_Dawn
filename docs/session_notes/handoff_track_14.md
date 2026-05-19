# Track 14 Handoff — Server-side Item Registry

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Tracks 1–13 closed the server-authoritative loop for movement,
visibility, enemies, player stats, PvP, buffs / CC, groups, AOI,
heals, AOE, cast-time gating, pets (summon / follow / attack /
threat / warder / charm), and **inventory + equipment** (load /
save / loot / move / split / drop / equip / unequip).

Track 13 ended with a clean architectural seam: the server tracks
**what** each player owns and **where** it sits. The last gap is
**what each item actually does** — its stats, its bag capacity, its
equippable slot, its lifesteal multiplier. Today the client knows
all of this (via `ItemData` .tres files); the server only knows
weapon damage (via `items.toml`). Track 14 lifts the rest.

After Track 14:
- Item-vs-slot validation on equip (server rejects helmet-in-weapon-slot).
- Stat recompute on equip / unequip — `max_hp` / `max_mp` /
  `equipped_armor` driven by the equipped set, no longer trusting
  the client's `EquipUpdate` claim.
- Bag locations work (`'bag_<i>'` rows in `character_items`).
- Inventory full rejection on loot (`max_stack` per item).
- Lifesteal `heal_amount` on ENEMY-target spells fires server-side.

Estimated 2–3 sessions depending on how much of the stat-recompute
plumbing you bite off. Three natural sub-tasks (registry +
validation; stat recompute; bag locations).

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `33e1c41` (Track 13.3 client: paperdoll mirrors server equip state) |
| Server | `F:\Projects\server\` | `main` | `bb3c4c0` (Track 13.3: equip / unequip with paperdoll persistence) |
| Launcher | `F:\Projects\launcher\` | `main` | `8d2a328` (protocol.gd: mirror inventory tags) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS) |

Run `git -C <each> log --oneline -5` before touching anything.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_19_track13.md` — Track 13
   close. Each sub-task ends with explicit deferrals all pointing
   at "needs server-side item registry"; Track 14 is the unblock.
3. `crates/projectdawn-server/data/items.toml` — current weapon-
   only registry. Track 14 extends it.
4. `crates/projectdawn-server/src/world/items.rs` — current lookup
   crate. `Weapon` struct + `lookup(path) -> Option<&Weapon>`. Track
   14 generalises to `Item` or splits into `Weapon` / `Armor` /
   `Bag` / `Consumable` etc.
5. `Project_Dawn/scripts/item_data.gd` — client-side authoring
   shape. Source of truth for what fields exist. Mirror to server.
6. `Project_Dawn/data/` + the ~155 `.tres` files in
   `assets/items/` (or wherever they live now) — bulk data to
   port. Probably want a GDScript export tool similar to
   `tools/export_spells.gd` (still stale, but the pattern works).
7. `crates/projectdawn-server/src/world/inventory.rs` — where the
   `add_item_locating` stack overflow + bag handling live. Once
   the registry knows `max_stack` and `bag_num_slots`, these
   methods grow real validation.
8. `crates/projectdawn-server/src/world/connection.rs` — where
   `equipped_armor` lives. Track 14 sub-task 14.2 recomputes it
   from the equipped set instead of trusting `EquipUpdate`.

---

## Scope

### Sub-task 14.1 — Registry + validation (~1 session)

The foundation. Server gets a generalised item lookup; equip
validates against it.

**Data side:**

Extend `data/items.toml` or split into multiple TOML files
(`items_weapons.toml`, `items_armor.toml`, etc.) — your call. The
shape per item:

```toml
[[item]]
path = "res://items/sword.tres"
name = "Bronze Sword"
item_type = "WEAPON"          # WEAPON / ARMOR / BAG / CONSUMABLE / MATERIAL / etc.
equip_slot = "weapon"          # for ARMOR + WEAPON: which paperdoll slot
stack_size = 1                 # max stack; > 1 for stackable consumables / materials
# Optional per-type fields:
damage_min = 3
damage_max = 6
weapon_delay = 2.0
skill = "1h_slashing"
is_two_handed = false
is_ranged = false
bag_num_slots = 0              # > 0 for BAGs
# Stat affixes (Track 14.2 reads these on equip):
str_bonus = 0
agi_bonus = 0
int_bonus = 0
wis_bonus = 0
con_bonus = 0
max_hp_bonus = 0
max_mp_bonus = 0
armor = 0                      # contributes to equipped_armor
```

Author or auto-generate from the existing `.tres` files. The
client's `tools/` already has an export pattern (`export_spells.gd`,
stale but functional); writing `export_items.gd` is the natural
move.

**Server side:**

- Replace `items::Weapon` + `items::lookup` with a generalised
  `Item` struct (or trait-based — your call). Existing `Weapon`
  usages in `combat.rs` shift to reading from the new struct's
  weapon fields.
- New helpers:
  - `items::is_equippable_in_slot(path, slot_u8) -> bool` — Track
    13.3's equip dispatch consults this to reject mismatched
    equips.
  - `items::max_stack(path) -> u32` — `PlayerInventory.add_item_locating`
    enforces this instead of unbounded stacks.
  - `items::bag_num_slots(path) -> Option<u32>` — `'bag_<i>'`
    location handling in `PlayerInventory` reads this.

**Dispatch changes:**

- `equip_from_base` in `inventory.rs` validates via
  `items::is_equippable_in_slot` before mutating. Reject = no
  Deltas, log at info.
- `add_item_locating` caps stack growth at `max_stack`; overflow
  spills into a new slot or returns `Err("inventory full")`.
- Loot dispatch in tick.rs treats `inventory full` as a real
  reject: the bag stack stays in the loot bag (don't drain it),
  log a denial, don't send LootGranted.

**Tests:**

- Unit: `items::is_equippable_in_slot` for a weapon, an armor
  piece, a consumable.
- Integration: `equip_rejects_wrong_slot` — seed a non-weapon item
  in base 0, send EquipItem(0 → 0 weapon slot), assert no Deltas.
- Integration: `loot_full_inventory_retains_bag_stack` — fill all
  8 base slots, kill a mob that drops a unique item, assert the
  bag still has the stack after the looter sends LootAll.

### Sub-task 14.2 — Stat recompute on equip (~1 session)

The anti-cheat closeout for equipment. Server reads stat affixes
from the registry and bumps `PerConnection.max_hp` / `max_mp` /
`equipped_armor` accordingly. Client's `EquipUpdate` message
becomes deprecated (or a sanity check).

**Recompute approach:**

```rust
fn recompute_equipped_stats(conn: &mut PerConnection) {
    let mut bonus_str = 0;
    let mut bonus_armor = 0;
    let mut bonus_max_hp = 0.0;
    // ... etc.
    for (slot, entry) in &conn.inventory.equipment {
        if let Some(item) = items::lookup(&entry.item_path) {
            bonus_str += item.str_bonus;
            bonus_armor += item.armor;
            bonus_max_hp += item.max_hp_bonus;
            // ... etc.
        }
    }
    // Combine with base stats from CharacterSpawn (race + class formula).
    // Update conn.{stats, max_hp, max_mp, equipped_armor}.
    // Fan HealthUpdate / ManaUpdate / StaminaUpdate if max_* changed.
}
```

Called from the equip / unequip dispatch in tick.rs after the
inventory mutation lands. Also called from `from_spawn` after the
inventory loads (so persisted equip applies on connect).

**HP / MP behaviour when max changes:**

Match the GDScript behaviour. Today the client adds the bonus to
both current + max on equip. Mirror server-side: bumping `max_hp`
by 20 also bumps current `hp` by 20 (clamped at the new max);
removing a +20 HP item reduces current HP by 20 down to 1 minimum
(no instant-kill from unequipping).

**Deprecate `EquipUpdate`:**

The handler stays for one track as a no-op (logged) — old clients
still send it. Track 15 or later can remove it from the protocol.

**Tests:**

- Unit: `recompute_equipped_stats` against synthetic registry +
  PlayerInventory.
- Integration: `equip_increases_max_hp` — provision a Warrior with
  base max_hp 150, seed a +20 HP chest item, equip, assert a
  HealthUpdate with max_hp = 170 lands.

### Sub-task 14.3 — Bag locations (~half session)

Lift the last `from_rows` exclusion. `'bag_<i>'` rows now load,
persist, snapshot, and move-item-between.

**`PlayerInventory.bags: HashMap<u8, Vec<Option<InventoryEntry>>>`**
keyed by base slot index that holds the bag. Vec length =
`items::bag_num_slots(bag.item_path)` looked up at populate time.

**Mutation rules:**

- Placing a bag-typed item into a base slot via MoveItem
  initialises the bag's contents Vec (all None).
- Moving a bag OUT of its base slot only succeeds if the bag is
  empty (matching GDScript). Reject with log otherwise.
- Inside-bag MoveItem (`'bag_3'` → `'bag_3'`) routes through a new
  `move_bag(base_idx, src_slot, dst_slot)` method.
- Across-bag-or-base moves (`'bag_3'` → `'base'`, `'base'` →
  `'bag_3'`, `'bag_3'` → `'bag_5'`) need a new `move_across` method
  that handles the bag-existence + capacity checks.

**Snapshot:**

`to_snapshot_entries` and `to_rows` already iterate `equipment`;
extend to also iterate the bags map. The wire's existing string-
based location handles `'bag_<i>'` without changes.

**Client side:**

`autoloads/inventory.gd._on_inventory_snapshot` already has the
TODO comment for bag routing. Wire it into `bag_contents[i]`.

**Tests:**

- Unit: place bag → put item in → take item out → take bag out
  (latter only succeeds when bag empty).
- Integration: `bag_contents_persist_across_reconnect` — seed a
  bag with one item via DB, EnterWorld, assert snapshot includes
  both rows.

## Cross-cutting cleanups (small wins)

- **`export_items.gd`** in `Project_Dawn/tools/` — auto-generate
  the server's items TOML from the .tres files. Same pattern as the
  stale `export_spells.gd`; fixing both together is a "tools day"
  worth scheduling.
- **Lifesteal `heal_amount` on ENEMY-target spells** — once the
  item / spell registry is server-side, the ENEMY arm in
  `tick.rs::apply_spell_damage_to_enemy` can apply
  `caster.hp += min(spell.heal_amount, damage_done)`. Tiny addition
  to the helper.
- **Vendor / shop intents** — `ClientWorldMsg::BuyItem` /
  `SellItem` are no-op'd on the server today. Once the registry
  knows item prices (or vendors list prices in a vendor TOML),
  these can fold into the same flow (cost = coins delta, inventory
  delta on success). Probably a sub-task 14.4 or its own small
  track.
- **`PetCommand::GUARD` / `SIT`** are still reserved no-ops from
  Track 12 — unrelated to inventory but worth carrying forward as
  a small UX improvement once you're touching the dispatch layer.

## After Track 14

Server is the source of truth for every gameplay-relevant piece of
player state AND every item's properties. Last big remaining
server-auth items:

- **Cooldown server-auth** — per-player per-spell cooldown map;
  reject CastSpell that arrives before cooldown expires.
- **Movement-during-cast interrupt** — server compares caster pos
  at `cast_set_at` vs now in the gate.
- **Skill leveling** — `WeaponSkills` / `ArmorSkills` /
  `CastingSkills` autoloads track per-skill progression;
  currently client-only.
- **Zone transitions** — when a second zone lands.

After that the netcode is functionally complete and focus shifts
to content / UI / polish / playtest scaling.

Pick one and write the next handoff.
