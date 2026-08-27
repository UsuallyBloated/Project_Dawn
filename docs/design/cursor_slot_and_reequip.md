# The Cursor Slot & Corpse Auto-Re-equip

*Drafted 2026-08-27. Decision: the user chose the full server-side cursor slot ("Option B")
over a client-only auto-loot shortcut, explicitly to unlock corpse auto-re-equip.*

## Why

Two long-standing wants converge on one missing primitive:

1. **Left-click picks up a ground item** (requested 2026-08-27). The user's grammar: corpses
   stay right-click to loot, but a lone item sitting on the ground should be grabbed by
   left-click and ride the mouse until placed — the same feel as lifting an item inside a bag.
2. **Corpse auto-re-equip** (requested 2026-06-24). Looting your own corpse should put your
   gear back ON, not into your bags. Any honest version needs an overflow home for items that
   can't be placed — which is exactly what a cursor slot is.

Today "on the cursor" is a client-side illusion: during an inventory drag the item never
leaves its server slot until the drop lands as one `MoveItem`. There is no server state for
"held", so nothing that originates outside your own inventory (a ground item, corpse
overflow, a future summoned item) can ride the cursor honestly.

## The model (EQ's, essentially)

A per-character **cursor slot**: `Inventory.cursor: Option<InventoryEntry>` — at most one
stack. It is a real inventory location named `"cursor"`, which matters because all three
layers already speak location *strings*:

| Layer | Change needed |
|---|---|
| Wire `MoveItem` / `InventoryDelta` | **none** — `src_location`/`location` are `String` |
| DB `character_items.location` | **none** — the column is documented "intentionally loose so future locations don't need another migration" |
| Server `Inventory::move_across` + the delta fan | teach them the `"cursor"` string |

The one genuine protocol addition is the ground-pickup intent (client → server), so the
epic carries **one protocol bump (PD_W0027)**, one gdext rebuild, one client re-export.

### Rules (exploit analysis inline)

- **One stack, ever.** The cursor never holds more than one stack. Lifts onto an occupied
  cursor are refused (or merge via `merge_capped` when same-item — remainder stays put).
- **Placing follows existing MoveItem law**: empty destination moves, same-item destination
  merges capped, different-item destination **swaps** (the displaced stack lands on the
  cursor — EQ behavior, and `move_across` already swaps between slots).
- **Ground pickup is loot, not magic**: `LootToCursor { bag_id }` runs the SAME gates as the
  loot window — `LOOT_PICKUP_RANGE`, loot rights (round robin / FFA ownership), dead-check —
  and only succeeds when the bag holds **exactly one item stack and zero coin** and the
  cursor is empty. Anything else refuses via `send_refusal` ("There's more than one thing
  there — right-click to loot." / "You're already holding something."). Removal from the bag,
  cursor write, bag despawn and the delta fan happen atomically in one tick step — the
  corpse-loot lesson (a crash between "remove" and "grant" must not lose or dupe).
- **Death strips the cursor too.** The corpse gather works off the inventory's rows; the
  cursor row must be included or dying with a held item becomes an item-loss (or, worse, a
  dupe-on-crash) window. A regression test pins it.
- **Encumbrance counts it.** A held stack weighs what it weighs.
- **Persistence is free but must be verified**: `to_rows`/`from_rows` gain the `"cursor"`
  location, and `save_stores_atomic` + the disconnect flush inherit it. Logging out with an
  item on cursor keeps it there, like EQ.
- **No new oracle surface**: refusals name facts an honest client can see ("more than one
  thing there"), nothing about internal state.
- **ESC does NOT drop the held item.** Placing or an explicit ground-drop are the only exits
  (accidental destruction is worse than a sticky cursor). `DropItem` accepts
  `location="cursor"` so a full-bags player can always put the item down.

### Client behavior

- `LootBagSpawn` already tells the client the bag's stack count; left-click on a ground bag
  in launcher mode sends `LootToCursor` (the server stays authoritative — a refusal is a chat
  line). Right-click loot is unchanged everywhere; corpses are untouched by this epic's
  slice 1.
- When the server cursor is occupied (known via `InventoryDelta location="cursor"`), the
  item renders attached to the mouse (the skill-carry ghost pattern, with the item name), and
  inventory left-clicks send `MoveItem cursor → slot` instead of starting a local visual
  drag. Local drags for ordinary rearranging stay exactly as they are — no extra round-trips
  on the common path.
- Equip-by-click on the paperdoll with a held item (`EquipItem src_loc="cursor"`) if the
  equip handler's location parsing extends cheaply; otherwise it waits for slice 2.

## Slices

**Slice 1 — the cursor exists (PD_W0027).** Server: cursor field, `move_across` + delta fan +
`correct_client_slots` speak `"cursor"`, `LootToCursor` handler with the full gate set, death
strip + encumbrance + persistence coverage, unit + integration tests. Gdext: the new intent.
Client: cursor mirror + mouse-attached render, left-click ground routing, place/equip clicks.

**Slice 2 — corpse auto-re-equip.** Corpse item rows gain equip-slot provenance (this one IS
a migration), `save_corpse` records which slot each equipped item died in, and self-corpse
loot restores gear to its slots first, bags second, cursor as the single-stack overflow,
honest chat line for anything that stays on the corpse. Design detail deferred until slice 1
is playtested.

## Open questions (carried, not blocking slice 1)

- Should kill-loot bags with a single item stack + coin allow left-click (grab item, leave
  coin)? v1 says no — keep the rule crisp.
- Bank/vendor interactions with a held item (deposit-from-cursor, sell-from-cursor): deferred;
  place it first.
- Slice 2's exact overflow order and whether a partially-lootable corpse should re-equip at
  all or refuse whole.
