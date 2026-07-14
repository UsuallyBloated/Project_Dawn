# Session 2026-07-11 — Gear stat bonuses display in launcher mode

Client-only, branch `fix/xp-leveling-overflow`. **No wire change, no DLL rebuild.** BUILT +
logic-traced, **awaiting playtest** (`gear_stat_display_checklist.md`) — not committed.
Follow-up to the quest slice-B playtest, which surfaced this pre-existing bug via the
Tarnished Silver Ring's AGI +1 not showing.

## The bug

In launcher/multiplayer mode, equipping is server-authoritative. The server DOES apply a
gear item's stat bonuses (`inventory.rs::recompute_equipped_stats` adds `agi_bonus` etc. to
the connection), but **the six primary stats — STR/AGI/DEX/INT/WIS/CHA — have no
server→client wire message**, and the client's server-driven equip path
(`Equipment.apply_remote_equip`) deliberately skipped local stat recompute. So the character
sheet never moved when you equipped gear. STR/CON only *looked* like they worked because
HP/MP/Stamina gear moves the resource bars (which ARE fanned); the numbers didn't update
either. This hit all gear, all six stats — not just the ring.

## Fix (client-side; values already match the server)

`autoloads/equipment.gd` — the three server-driven paths now mirror the local `equip` path's
stat application (via the existing `_apply_stat_bonuses`/`_remove_stat_bonuses` →
`PlayerStats.apply_item_bonuses`/`remove_item_bonuses`):
- `apply_remote_equip`: remove any item already in that slot (defensive), then apply the new
  item's bonuses.
- `apply_remote_unequip`: remove the item's bonuses.
- `apply_remote_snapshot_clear`: remove each worn item's bonuses before nulling.

`autoloads/player_stats.gd::apply_character` — after its ABSOLUTE reset to the gear-free base
(and the `_base_*` snapshot), **re-layer any gear currently on the paperdoll**.

## Why the re-layer is required (the subtle part)

`apply_character` resets public stats to base absolutely. Two server paths send an
`InventorySnapshot` that runs `apply_remote_snapshot_clear`:
1. **EnterWorld** (relog) — preceded by `apply_character` (stats already at base).
2. **Death** (`tick.rs:8301`) — the server strips gear and fans an EMPTY snapshot, with NO
   `apply_character` first (stats still have gear baked in).

So `snapshot_clear` MUST strip gear bonuses (for death → naked shows base). But on a relog the
paperdoll dict can be stale (autoloads persist across a logout-to-lobby), so a bare strip would
subtract a bonus `apply_character` already removed by its reset → stats drift BELOW base each
relog. The `apply_character` re-layer restores the invariant **public = base + worn gear**
before `snapshot_clear` runs, so the strip is always balanced. Traced clean for: single-session
equip/unequip, relog (stale + fresh dict), death empty-snapshot, gear-swap, and the dev
`apply_character` re-apply (which this also fixes — a dev Level Up previously dropped gear
stats). Max HP/MP/Stamina stay server-authoritative: the local player's max is set absolutely
from the server (`remote_player_manager.gd:155`), so applying full item bonuses can't leave a
lasting double on the resource pools.

## Verification

Headless Godot boot: clean, zero script errors. Logic traced across all reset paths (above).
In-game equip/unequip/relog/death behavior is the playtest's job.

## Not fixed here (tracked separately)

The two dev-tool issues from the slice-B playtest — Test Panel "ghost items" (client-only
grants) and the client-local Rotfang spawn — are the next follow-up (dev-panel modernization).
