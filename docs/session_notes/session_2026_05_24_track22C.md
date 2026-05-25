# Track 22.C — Mount system (client-side v1)

Date: 2026-05-24.

Walking the Track 22 menu in alphabetical order; Option C lands
the mount system as the first piece. Design call locked the
mechanics before any code:

| Question | Answer |
|---|---|
| Summon source | Item-based whistles (right-click in inventory) |
| Zone perms | Per-zone blacklist (`NO_MOUNT_ZONES` in ZoneData) |
| Dismount trigger | Any incoming damage (classic EQ feel) |
| Speed math | Mount multiplier overrides every other speed source |

Scope: client-only v1. Server doesn't model mount state. Forging
a free mount is harmless — speed cap stays enforced at
`MAX_MOVE_SPEED = 7.5 m/s` on the server's `Move` integration,
and the multiplier just changes how fast the client predicts
local movement.

## Touchpoints

**`scripts/item_data.gd`** — three new `@export` fields on
`ItemData`:
- `is_mount: bool = false`
- `mount_speed_mult: float = 1.6`
- `mount_name: String = ""`

**`autoloads/mount_manager.gd`** (new):
- State: `current_mount: ItemData = null`.
- `is_mounted()`, `summon(item)`, `dismount(reason)`.
- `get_effective_speed_mult()` returns `current_mount.mount_speed_mult`
  when mounted, else falls through to `BuffManager.get_speed_mult()`.
  Player.gd's physics tick reads from this instead of BuffManager
  directly.
- Auto-dismount in `_ready` via `ZoneLoader.zone_changed` subscription
  — entering a no-mount zone drops the rider during the fade.
- Signals: `mount_changed(mounted, mount_name)`, `dismount_reason(reason)`.
- Registered in `project.godot` after Memorize / SpellBar.

**`data/zone_data.gd`** — new `NO_MOUNT_ZONES: Array[String]`
constant (mirrors the existing `NON_BINDABLE_ZONES` pattern).
Empty list = mounts everywhere. Add a dungeon's `res://` path
to mark it as no-mount.

**Right-click summon**:
- `scripts/inventory_window.gd` right-click branch checks
  `item.is_mount` before the BAG / CONSUMABLE / equip branches.
  Same toggling logic in `scripts/bag_window.gd`.
- Re-clicking the current mount's whistle → dismount.
- Clicking a different mount's whistle → swap.

**Dismount triggers**:
- `autoloads/combat.gd::receive_player_damage` — any hit fires
  `MountManager.dismount("hit")`.
- `autoloads/player_death.gd::_die` — death dismount as a safety
  net for non-damage death paths (falls, scripted).
- `scripts/hud.gd` chat handler — new `/dismount` command.
- Auto on zone change into `NO_MOUNT_ZONES`.

**`scripts/player.gd`** — physics tick now reads
`MountManager.get_effective_speed_mult()` in place of
`BuffManager.get_speed_mult()` directly. When unmounted the value
matches the legacy BuffManager-only path; when mounted the mount
multiplier wins.

## Authored content

`data/loot/items/brown_steed_whistle.tres` — example whistle:
- `is_mount = true`
- `mount_speed_mult = 1.6` (1.6× base 5.0 m/s = 8.0 m/s; clips to
  server's MAX_MOVE_SPEED = 7.5 m/s for the actual wire integration)
- `mount_name = "Brown Steed"`
- `vendor_price = 350`
- `item_type = misc`

`items.toml` regenerated (168 → 169 entries). Server registry
recognises the whistle as a misc item; the mount fields are
client-only metadata not exported to the server.

## Server impact

None. Server-side `MAX_MOVE_SPEED = 7.5` still clamps the unit
direction × cap math in the `Move` arm. The mount multiplier
inflates the client's local prediction; if it produces a higher
effective speed, the server's clamp drops it on the wire. So a
forged `is_mount = true` whistle gives a client a slightly faster
visual prediction but doesn't translate to a forged real-position
on the server. Real server-auth lift (mount-flag on PerConnection,
broadcast for peer visibility) is a follow-up if PvP balance
needs it.

## Carry-forward

- **Mount mesh / visual** — v1 is speed-only; the player character
  doesn't actually ride a model. Stretch goal: attach a horse mesh
  beneath the player, animate idle / move while mounted, hide on
  dismount.
- **Peer-visible mount state** — peers see the mounted player
  moving fast but don't see a mount underneath them. Needs a
  client-broadcast (`ClientWorldMsg::MountUpdate`) + peer-side
  `RemotePlayer.is_mounted` flag once mesh support lands.
- **Animal Husbandry / Spirit of Wolf interaction** — both
  reference mounts as a precondition. Animal Husbandry tradeskill
  produces whistles; Spirit of Wolf design call needs to decide
  whether SoW prebuffs are eaten when mounting (currently they're
  simply ignored — mount multiplier wins outright).
- **Combat-only dismount option** — current rule is "any incoming
  damage." If playtest finds it too punishing (e.g., a single DoT
  tick dismounts you), revisit with the threshold-based option
  from the design menu.

## Files touched

Client (`F:\Projects\Project_Dawn\`):
- `autoloads/mount_manager.gd` (new)
- `project.godot` (registered MountManager)
- `scripts/item_data.gd` (+3 mount fields)
- `data/zone_data.gd` (+NO_MOUNT_ZONES)
- `data/loot/items/brown_steed_whistle.tres` (new)
- `scripts/inventory_window.gd` (right-click mount branch)
- `scripts/bag_window.gd` (right-click mount branch)
- `scripts/player.gd` (speed mult through MountManager)
- `autoloads/combat.gd` (dismount on damage)
- `autoloads/player_death.gd` (dismount on death)
- `scripts/hud.gd` (/dismount command)

Server (`F:\Projects\server\`):
- `crates/projectdawn-server/data/items.toml` (regenerated; 168 → 169)

No server code changes; 116/116 lib tests pass.

## Verify by hand

1. `/give brown_steed_whistle` (or loot one from a vendor once
   stocked).
2. Right-click the whistle in inventory → "You mount your Brown
   Steed." Move speed visibly faster.
3. Take a hit from an enemy → "You are dismounted (hit)." Speed
   returns to walking.
4. Right-click whistle again → re-mount. `/dismount` chat command
   drops you. Walking into a NO_MOUNT_ZONES entry drops you with
   "no mounts allowed here."
