# Track 13 Handoff — Server-side Inventory

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Tracks 1–12 closed the server-authoritative loop for movement,
visibility, enemies, player stats, PvP, buffs / CC, groups, AOI,
heals, AOE, cast-time gating, **pets** (summon / follow / attack /
threat / warder / charm). Every pet-using class plays end-to-end in
multiplayer.

Track 13 lifts the **last big trust gap in the gameplay loop**:
inventory. Today the client is authoritative on its own inventory:
loot pickup routes through the server (LootItem / LootAll intents,
`LootGranted` private message back), but once an item is "in" the
client's inventory, the server doesn't track it. Move it between bag
slots, drop it, equip it — all client-local. A modified client can
spawn arbitrary items, claim quest rewards it never earned, dupe
items by intercepting `LootGranted` and replaying it.

This is the single biggest economy hole left. After Track 13, server
state is the source of truth for what every player owns.

Estimated 2–3 sessions depending on how much UI you re-plumb at once.
Three natural sub-tasks (server schema + protocol; inventory ops on
the wire; equipment + paperdoll).

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | (TBD — Track 12 notes + this handoff pending commit) |
| Server | `F:\Projects\server\` | `main` | `65979de` (Track 12 Piece C: PET_CHARM via id-partition re-key) |
| Launcher | `F:\Projects\launcher\` | `main` | `e38f89e` (protocol.gd: mirror PetCommand constants) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS) |

Run `git -C <each> log --oneline -5` before touching anything.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_19_track12.md` — Track 12
   close. Pet system is the model for how to lift state server-side
   without breaking the local fallback path; inventory follows the
   same pattern (server is authoritative when in launcher mode;
   solo / Test Room keeps the legacy local autoload).
3. `autoloads/inventory.gd` (304 lines) — client inventory model.
   The shape to mirror server-side:
   - `BASE_SLOT_COUNT = 8` flat slots
   - `base_slots[i] = null | { "item": ItemData, "count": int }`
   - `bag_contents[i] = null` (non-bag slot) or `Array[bag.bag_num_slots]`
     of the same `{item, count}` shape
   - Stacking, swap-with-empty, swap-with-other-stack semantics
4. `autoloads/equipment.gd` — paperdoll slots (weapon / offhand /
   helm / chest / gloves / boots / ring1 / ring2 / amulet / waist /
   cloak / shoulders / legs / wrists). `can_dual_wield()` gates
   offhand based on the `dual_wield` skill level.
5. `crates/projectdawn-server/src/world/loot.rs` — existing
   server-side loot bag handling. The `LootItem` / `LootAll` intent
   path already has the shape we extend.
6. `crates/projectdawn-server/src/db/mod.rs:375-503` —
   `CharacterSpawn` + `load_character`. Inventory rows need to load
   here too.
7. `migrations/0001_init.sql` — current schema. Adding inventory
   means a new migration (`0002_inventory.sql`).
8. `scripts/item_data.gd` — ItemData fields. Stack semantics,
   bag_num_slots, type enum, equip slot, stat affixes.
9. `crates/projectdawn-server/src/world/items.rs` — server-side
   item registry already exists for weapon swing lookups; same
   loader can power the inventory item index.

---

## Scope

### Sub-task 13.1 — Schema + load/save (~1 session)

Server learns where every item is. Read on character load, write on
checkpoint + disconnect.

**Schema additions** (new migration `0002_inventory.sql`):

```sql
-- Flat inventory rows keyed by (char, location, slot). Location
-- distinguishes the 8 base slots, the contents of each bag, and
-- the paperdoll. The bag-in-base-slot constraint lives in app
-- code: if a base slot holds a bag (location='base', slot=i, and
-- the item.type == BAG), then rows can exist at location='bag_i'.
CREATE TABLE IF NOT EXISTS character_items (
    char_id      INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    location     TEXT    NOT NULL,
    slot         INTEGER NOT NULL,
    item_path    TEXT    NOT NULL,
    count        INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (char_id, location, slot)
);
CREATE INDEX IF NOT EXISTS idx_char_items_char ON character_items(char_id);
```

`location` values:
- `'base'` — slot ∈ [0, 7]
- `'bag_0'..'bag_7'` — slot ∈ [0, bag.bag_num_slots-1]; only valid
  when `base_slots[bag_index].item.type == BAG`
- `'equip'` — slot maps to the equipment slot id (numeric, defined
  in protocol or item_data)

`item_path` is the same `.tres` path the client's `ItemRegistry`
keys on. `ItemData.resource_path` round-trips between client and
server.

**Server-side state.** Add a parallel structure to `PerConnection`:

```rust
struct PlayerInventory {
    base: [Option<InventorySlot>; 8],
    bags: HashMap<u8, Vec<Option<InventorySlot>>>, // bag_base_idx → contents
    equipment: HashMap<u8, InventorySlot>,         // slot_id → item
}

struct InventorySlot {
    item_path: String,
    count: u32,
}
```

Load on `load_character`; persist on `checkpoint_position` (60 s
cadence) and on disconnect-final-save. Same path the existing
position checkpoint uses.

**No new protocol variants yet** — sub-task 13.1 just establishes
the source of truth. Clients still drive their local inventory;
server's view is read-write but writes only on disconnect (the
client's last `inventory_changed`-derived snapshot wins).

Actually — re-think this. For 13.1 to be useful as a foundation,
the **server's view should reflect server-authoritative changes**
(loot grants). Today `LootGranted` is private and the server
doesn't track what landed where. Sub-task 13.1 plumbs LootGranted
to mutate the server's `PlayerInventory`. Client side stays
authoritative for now on moves between slots; the server's snapshot
becomes more accurate as items are gained/lost server-side.

### Sub-task 13.2 — Move / split / drop intents (~1 session)

Server takes authority on slot-to-slot mutations.

**New protocol variants:**

```rust
ClientWorldMsg::MoveItem {
    src_location: String,   // 'base' | 'bag_0' .. 'bag_7' | 'equip'
    src_slot: u32,
    dst_location: String,
    dst_slot: u32,
},
ClientWorldMsg::SplitStack {
    src_location: String,
    src_slot: u32,
    dst_location: String,
    dst_slot: u32,
    count: u32,
},
ClientWorldMsg::DropItem {
    location: String,
    slot: u32,
    count: u32,            // 0 = whole stack
},
```

```rust
ServerWorldMsg::InventorySnapshot {
    base: Vec<Option<(String, u32)>>,
    bags: Vec<(u8, Vec<Option<(String, u32)>>)>,
    equipment: Vec<(u8, String, u32)>,
},
ServerWorldMsg::InventoryDelta {
    location: String,
    slot: u32,
    item_path: Option<String>,  // None = slot cleared
    count: u32,
},
```

Server processes intents; emits `InventoryDelta` on every successful
mutation. New joiner / re-connect gets a full `InventorySnapshot`
on EnterWorld (existing seed-loop pattern). Protocol bump
PD_W0008 → PD_W0009.

Client: `autoloads/inventory.gd` becomes a render-only mirror in
launcher mode. Drag-and-drop UI in `inventory_window.gd` /
`bag_window.gd` builds intents and sends through Net rather than
mutating `base_slots` / `bag_contents` directly. Same pattern as
`PetManager.summon()` short-circuiting in launcher mode (Track 11.5).

**Drop creates a server-owned loot bag at the player's feet** —
exactly the existing `LootBagSpawn` path. Reuses `loot.rs` shapes.

### Sub-task 13.3 — Equipment / paperdoll (~half session)

Adds the equipment slots into the same system.

**New protocol variant:**

```rust
ClientWorldMsg::EquipItem {
    src_location: String,
    src_slot: u32,
    equip_slot: u8,   // weapon=0, offhand=1, helm=2, ...
},
ClientWorldMsg::UnequipItem {
    equip_slot: u8,
    dst_location: String,
    dst_slot: u32,
},
```

Server validates: item is equippable, equip_slot matches the item's
authored slot, can_dual_wield gate for offhand, stat re-computation
on equip/unequip (updates max_hp / max_mp / max_stamina /
equipped_armor + fans HealthUpdate / etc.).

`PerConnection.equipped_armor` already lives server-side and is
read by the PvE armor reduction. Equip changes recompute it.

Out: gem sockets / augments (deferred; the `ItemData.gem_slots` +
`socketed_augments` fields exist on the client but the apply path
is incomplete).

---

## Cross-cutting concerns

- **Loot grant routing.** Today `LootItem` / `LootAll` send
  `LootGranted` privately with `(item_path, count)`. The client adds
  it to its first-free slot. After 13.1, the server picks the slot
  (first-free or stack-onto-existing) and the `LootGranted`
  broadcast carries `(location, slot, item_path, count)` so the
  client can render at the exact server-chosen spot. Avoids
  divergence when two clients race a bag pickup.
- **Stack-onto-existing logic.** Lives on the server. Match client's
  `Inventory.add_item` algorithm: iterate slots, find first stack of
  same item with `count < max_stack`, top it up; overflow to next
  free slot.
- **Empty-slot fallback for full inventory.** Today the client's
  add_item returns false if no slot available; the loot is lost.
  Server side: same. Future enhancement: bag returns the item if
  inventory full (would require a `LootRejected` variant).
- **Vendors.** Sell / buy intents already exist as
  `ClientWorldMsg::BuyItem` / `SellItem` but are no-op'd on the
  server. 13.x can fold these into the same flow (cost = coins delta,
  inventory delta on success). Probably a fourth sub-task.
- **Quest rewards.** `TurnInQuest` intent fans server-side already;
  reward item grants need the same first-free-slot logic 13.1 builds.
  Probably folds into 13.1.

## Tests

Per sub-task:

**13.1:** load + persist roundtrip. Test creates a character, inserts
a row in `character_items`, asserts `load_character` populates the
server's `PlayerInventory` and the disconnect checkpoint writes it
back unchanged.

**13.2:** drag-and-drop. Client sends `MoveItem { base 0, base 1 }`;
asserts two `InventoryDelta` broadcasts (or one batched snapshot)
that reflect the swap. SplitStack with overflow.

**13.3:** equip a weapon (race + class permits); assert max_hp
recalculates if the item has +Constitution; unequip; assert revert.

## Implementation notes

- **Stacking semantics live on the server.** Client today is
  authoritative for stacking on add. After 13.1, server picks slots;
  client renders. Avoids "I picked it up, you picked it up, we both
  think we have it" desync that the current LootGranted-private
  flow papers over.
- **Item paths as wire identifiers.** `ItemData.resource_path` is
  the stable id. Already used in the client's `ItemRegistry` and
  the server's `items::lookup` for weapons. No GUID needed; the
  path IS the id.
- **Migrations.** First migration since `0001_init.sql`. Confirm
  sqlx's migrate-on-startup path picks it up automatically (the
  init.sql is loaded by `db::init` — adding a second file should
  Just Work, but verify in `db/mod.rs` setup).
- **Save cadence.** Position checkpoint is every 60 s. Inventory
  changes are rarer (manual drag, loot pickup, equip) — could
  checkpoint inventory on every mutation. Cheap (one upsert + one
  delete per slot). Or piggyback on the existing 60 s cadence.
  Recommend per-mutation initially; the disconnect-final-save is
  the durability guarantee.
- **Don't lift to RAII-style ownership.** The server's
  `PlayerInventory` is a snapshot; persistence is async write-back
  to SQLite. Don't try to enforce "every item has exactly one owner
  in memory at all times" — locking is too expensive and a snapshot
  + reconciliation is cleaner.

## After Track 13

Server is the source of truth for HP, MP, mana, position, target,
buffs, CC, group, pets, AND inventory. Every gameplay-relevant
piece of player state is server-authoritative.

Remaining server-auth work:
- **Cooldown server-auth** — per-player per-spell cooldown map; small.
- **Movement-during-cast interrupt** — caster pos at cast_set_at
  vs now; small.
- **Skill leveling** — `WeaponSkills` / `ArmorSkills` /
  `CastingSkills` autoloads track per-skill progression; currently
  client-only.
- **Zone transitions** — when a second zone lands.

After that the netcode is functionally complete and the focus shifts
to content / UI / polish.

Pick one and write the next handoff.
