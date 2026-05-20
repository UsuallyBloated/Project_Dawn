# Track 15 Handoff — Client UI authority lift completion + PetCommand polish

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Track 14 closed the server-side authority loop for items: a
registry-backed item table, equip / max-HP / stat-recompute on
gear changes, bag locations, lifesteal heals, vendor BuyItem /
SellItem. The follow-up session also lifted the **left-click
drag-and-drop** flow and the **vendor buy / sell UI** to route
through `Net.broadcast_*` in launcher mode instead of mutating
`Inventory` / `PlayerStats.coins` locally.

Two carry-forward items remain in the UI lift:

- **Right-click flows** — `equip` / `unequip` / `consumable use`
  / `destroy` all still mutate `Equipment.equipped` / `Inventory`
  / `PlayerStats` directly. In launcher mode this diverges the
  client from server state until reconnect.
- **PetCommand `GUARD` / `SIT`** — the wire codes are reserved
  (`protocol::world::pet_command::{GUARD = 1, SIT = 4}`) but the
  server dispatch falls through to the catch-all no-op arm.

Track 15 closes both. Estimated 2 sessions — the right-click
lift is the bulk; GUARD / SIT is half a session if you want it
bundled, or split off as a one-shot.

After Track 15:
- Every player-driven inventory + equipment + vendor mutation
  flows through Net in launcher mode. The "client mutates local
  state, hopes server agrees" model is fully retired.
- Pet GUARD parks the pet at its current spot and switches it
  to a passive defense stance (returns aggro on the pet,
  doesn't chase unless attacked). SIT puts the pet in a low-
  alert idle that doesn't re-target.
- Anti-cheat surface remaining: cooldown server-auth,
  movement-during-cast interrupt, skill leveling (each its own
  track-sized item).

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `e6531ba` (Client drag-and-drop + vendor authority lift) |
| Server | `F:\Projects\server\` | `main` | `62a4895` (gdext-net: CoinsUpdate decoder + send_buy_item / send_sell_item) |
| Launcher | `F:\Projects\launcher\` | `main` | `8d2a328` (protocol.gd: mirror inventory tags) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS) |

Run `git -C <each> log --oneline -5` before touching anything.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_20_client_authority_lift.md` —
   the lift session that closed left-click drag-drop + vendor.
   Documents the patterns Track 15 should follow for the right-
   click flows. Carry-forward list at the bottom is Track 15's
   scope.
3. `docs/session_notes/session_2026_05_19_track14_2.md` —
   Track 14.2 stat recompute. Relevant for 15.1 because the
   equip / unequip lift drives the same server-side recompute
   path; you're just routing the trigger through the wire
   instead of the local `Equipment.equip` call.
4. `Project_Dawn/autoloads/equipment.gd` — the local equip /
   unequip mutation lives here. `equip(item)`, `unequip(slot)`,
   `_resolve_slot(item)`. The dual-wield + 2H-clears-offhand
   logic stays client-side as a *slot picker* — only the actual
   mutation moves to the server.
5. `Project_Dawn/scripts/inventory_window.gd` — the right-click
   arm in `_on_cell_input` (~line 255). Calls
   `Inventory.remove_base_at(index)` + `Equipment.equip(item)`
   today.
6. `Project_Dawn/scripts/bag_window.gd` — same right-click arm
   in `_on_slot_input` (~line 242) for bag inner slots.
   `_confirm_destroy` (~line 302) handles the destroy flow.
7. `crates/projectdawn-server/src/world/tick.rs` — Track 12's
   pet command dispatch (`PetCommandIntent`, ~line 2870). The
   GUARD / SIT arms land here. Helper docs on enemy state
   machine in `world/entity.rs`.
8. `Project_Dawn/autoloads/pet_manager.gd` + the pet UI panel
   in `scripts/hud_pet_panel.gd` — for 15.4 if the bonus is
   bundled.

---

## Scope

### Sub-task 15.1 — Right-click equip / unequip lift (~1 session)

The current flow:

```gdscript
# inventory_window.gd:_on_cell_input right-click
Inventory.remove_base_at(index)
Equipment.equip(item)
```

`Equipment.equip` then mutates `equipped[slot]` locally,
applies `PlayerStats.apply_item_bonuses`, and emits
`equipment_changed`. Server has no idea.

**The lift:** in launcher mode, send `Net.broadcast_equip_item(src_location,
src_slot, equip_slot_idx)` and let the server-side recompute
do the rest. The client's `_resolve_slot(item)` stays — it's the
slot picker (dual-wield logic + 2H weapon clears offhand
decision). What changes is where the actual mutation lands.

**Touchpoints:**

- `autoloads/equipment.gd` — add `request_equip_from(src_location,
  src_slot, item)` (new) that:
  - Calls `_resolve_slot(item)` to compute the target paperdoll
    slot.
  - In launcher mode → `Net.broadcast_equip_item(src_location,
    src_slot, equip_slot_idx)` and returns. The
    `Equipment.apply_remote_equip` + `Inventory._on_inventory_delta`
    handlers (already wired since Track 13.3) update local state.
  - In solo / Test Room mode → falls through to the legacy
    `equip(item)` + `Inventory.remove_*_at` flow.
- `Equipment.unequip(slot)` — split into `request_unequip(slot)`
  on the same pattern. Locally the unequip pushes the item back
  to inventory via `Inventory.add_item(item)`; the lifted version
  routes `Net.broadcast_unequip_item(slot_idx, "base", dst_idx)`
  with a server-chosen `dst_idx` (find-first-empty in
  `inventory_window.gd` or `bag_window.gd`).
  Actually — the server's `unequip_to_base(slot, dst)` requires
  a specific dst. Client picks "first empty base slot," or the
  call rejects if no room. The "no room — push to a bag" case
  doesn't translate cleanly; pick a dst the client knows is
  empty.
- `inventory_window.gd` + `bag_window.gd` right-click arms —
  replace `Inventory.remove_base_at(index)` + `Equipment.equip(item)`
  with `Equipment.request_equip_from("base", index, item)` (or
  the `bag_<N>` variant for bag_window).

**2H weapon edge case:**

Equipping a 2H weapon when an offhand weapon is held requires
two server ops: `UnequipItem(offhand, base, free_slot)` then
`EquipItem(base, src_slot, weapon)`. The client picks an empty
base slot for the offhand to land in. If no empty slot exists,
reject the equip locally (combat log line: "Inventory full —
free a slot to swap weapons"). Server-side validation already
handles the EquipItem half via Track 14.2's recompute; the
unequip-offhand step is just a regular `UnequipItem` flow.

Same for equipping an offhand weapon while a 2H is in main hand
— route the existing `Inventory.add_item(item)` reject in
`_resolve_slot` ("equipping an offhand with a 2H equipped").

**Right-click "use consumable":**

`inventory_window.gd:_use_consumable(item, index)` currently
calls `Inventory.remove_at(...)` + applies the food / drink /
heal buff locally. Wire intent already exists
(`ClientWorldMsg::UseConsumable { slot: SlotRef }`) but is
no-op'd server-side. Two options:

- **Option A (scope-creep):** lift the use-consumable flow now.
  Requires server-side handler that decrements the inventory
  stack, fans `InventoryDelta`, applies the food / heal buff
  via the existing buff system, and fans `BuffSnapshot`. ~half
  session of work.
- **Option B (defer):** keep `_use_consumable` local for Track
  15; document as Track 16 carry-forward. Consumables are
  visible to the player only (no shared state) so the divergence
  is less harmful than equip / unequip.

Pick A if you're feeling thorough; B if you want to keep 15
focused.

**Right-click "destroy" flow:**

`bag_window.gd:_confirm_destroy` deletes a dragged item without
spawning a corpse. The existing wire variant
`ClientWorldMsg::DropItem { location, slot, count }` is close
but spawns a loot bag — that's not destruction. Two options:

- **Add `DestroyItem` wire variant:** new variant + server
  handler that just decrements the slot without spawning a loot
  bag. Cleanest.
- **Route through `DropItem`:** server spawns a loot bag at the
  player's feet; the bag de-spawns after `LOOT_BAG_LINGER_SECS`.
  Items aren't *truly* destroyed but become unrecoverable for
  the player after ~2 minutes. Pragmatic; no protocol change.

Pick whichever feels right. The DropItem-as-destroy approach is
zero-server-change and matches the current optimistic "item is
gone" UI feel. The DestroyItem variant is cleaner long-term.

**Tests:**

- Integration: `right_click_equip_routes_through_wire` — seed a
  weapon in base[0], right-click via the test client, assert an
  EquipItem wire message lands at the server (and the
  subsequent InventoryDelta fans). Could also be a manual
  smoke test if integration is heavy.

### Sub-task 15.2 — Right-click "use consumable" lift (~half session, optional)

Only if you went with Option A above. Otherwise skip.

**Server side:**

- `ClientWorldMsg::UseConsumable { slot: SlotRef }` handler in
  `handlers.rs` → new `Outcome::UseConsumableIntent`.
- Apply phase in `tick.rs`: resolve slot, validate item is a
  consumable (`item.heal_on_use > 0` / `item.is_food` /
  `item.is_drink`), decrement the stack, fan `InventoryDelta`
  for the slot. Apply the food / drink / heal effect via
  `buffs::apply_*` and fan `BuffSnapshot`. For heal potions,
  bump `conn.hp` and fan `HealthUpdate`.

**Client side:**

- `inventory_window.gd:_use_consumable` and `bag_window.gd:_use_consumable`
  — in launcher mode, send `Net.broadcast_use_consumable(location,
  slot_idx)`. New `Net.broadcast_use_consumable` wrapper. New
  `send_use_consumable(location, slot)` `#[func]` on `NetClient`
  (parses GDScript string → `SlotRef` like `send_sell_item` did).
- Don't touch `Inventory.remove_at` or `BuffManager.add_*` in
  launcher mode — both arrive via server fans.

### Sub-task 15.3 — PetCommand GUARD + SIT (~half session)

Server defines the codes but doesn't implement the behaviour.
The pet AI state machine in `world/entity.rs` is the right
place to land them.

**GUARD semantics:**

- Pet stops following the owner.
- Pet stays at its current position (treated like a leash
  anchor).
- Pet still re-aggros if attacked. Threat works normally.
- When the owner moves out of some range, pet doesn't follow.
- Toggling back to FOLLOW (via the `/pet back` chat command or
  a new pet panel button) resumes the legacy follow behaviour.

**SIT semantics:**

- Pet idles in place.
- Pet does NOT re-aggro on incoming damage (or aggros at a much
  lower threshold).
- Useful for "park the pet, don't help me right now" scenarios.
- Some MMOs treat SIT as "out of combat regen accelerator." Up
  to you whether to mirror that.

**Touchpoints:**

- `world/entity.rs` — extend the pet's state machine. Existing
  states: `Idle`, `Chase`, `Attack`, `Flee`, `Leash`. New
  states: `Guard` (or reuse `Idle` with a guard flag), `Sit`
  (similar). The aggro / re-target logic in `tick_pet_ai`
  consults the state.
- `world/tick.rs` — PetCommand dispatch arms for `GUARD` and
  `SIT`. Just set the pet's state + optionally pin
  `command_at` (matches Track 12 Piece A1 sticky timer).
- `Project_Dawn/autoloads/pet_manager.gd` — chat commands
  `/pet guard` and `/pet sit` route to
  `Net.broadcast_pet_command(GUARD, 0)` / `(SIT, 0)`.
  The pet UI panel in `scripts/hud_pet_panel.gd` can add
  buttons for both.
- Combat log lines: "Wolf is now guarding." / "Wolf sits."

**Tests:**

- Unit: `pet_guard_holds_position_under_owner_move` — owner
  walks away from a GUARDing pet; pet stays put.
- Unit: `pet_sit_ignores_player_attacks` — owner attacks an
  enemy; SIT pet doesn't inherit the target.
- Unit: `pet_guard_still_reaggros_on_attack` — enemy attacks
  the GUARDing pet; pet enters Chase / Attack.

---

## Cross-cutting cleanups (small wins, this track or follow-ups)

- **`Net.broadcast_use_consumable` + DLL rebuild.** If 15.2
  lands, the gdext-net DLL needs a fresh `send_use_consumable`
  export and a rebuild + copy. Mirror the build.ps1 flow.
- **`request_equip_from` symmetry on the inventory side.**
  Inventory could grow a `request_remove_at(location, slot)`
  that routes to `Net.broadcast_drop_item` in launcher mode
  instead of mutating directly. Optional; the lift in 15.1
  already touches the direct callers.
- **Combat log on rejected equip / sell.** Server returns no
  delta on rejection today; the client just sees no UI change.
  Worth a "swing-and-miss" log line ("You can't sell that
  here" / "Inventory full"). Could add a `RejectionReason`
  wire variant or piggy-back on `CombatLog` chat. Minor UX.
- **Right-click pet panel buttons.** Pet panel HUD currently
  shows pet name + HP bar. Adding GUARD / SIT / ATTACK buttons
  is a nice UX addition once 15.3 lands.

---

## After Track 15

Client authority finishing pass is done. Last server-auth
items from the original Track 14 handoff:

- **Cooldown server-auth** — per-player per-spell cooldown
  map; reject `CastSpell` that arrives before the cooldown
  expires. Tightly coupled with the next item.
- **Movement-during-cast interrupt** — server compares caster
  pos at `cast_set_at` vs now in the gate. Prevents kiters
  from breaking the cast-time gate via "I didn't move" forging.
- **Skill leveling** — `WeaponSkills` / `ArmorSkills` /
  `CastingSkills` autoloads still track per-skill progression
  client-only. Each needs a server-auth lift (mirror of
  PlayerStats — server owns the truth, client renders +
  broadcasts the progression events).
- **Zone transitions** — when a second zone lands. Big track:
  server-side zone routing, world-token re-issue or
  re-handshake, position handoff, AOI grid per zone.

After that the netcode is functionally complete and focus
shifts to content / UI / polish / playtest scaling.

Pick one and write the next handoff.
