# Session 2026-07-11 — Disconnect flush: inventory + resources + skills

Server-only, branch `fix/xp-leveling-overflow`. **No wire change, no DLL rebuild, no client
change.** BUILT + 163 lib tests green, **awaiting playtest** (`disconnect_flush_checklist.md`)
— not committed. Follow-up to the gear-stat fix (committed b1df906), whose playtest surfaced
this.

## The bug

"Unequip the ring, log out, log back in → the ring is equipped again." The clean-logout flush
in `reap_connection` (tick.rs) saved coins, bank coins, both bank item vaults, quest progress,
and position — but **not inventory, resources, or passive skills**. Those three only persist on
the 60s periodic checkpoint (`persistence::checkpoint_dirty`). So any equip / unequip / loot /
move / drop / kill-XP / skill-up in the last <60s before a clean logout rolled back to the last
checkpoint on relog. The log confirmed it: `UnequipItem applied` at 15:39:20, `client requested
disconnect` 6 s later at 15:39:26, no inventory save between them.

Not caused by the gear-stat fix (that's client-only display); the gear-stat fix just made the
symptom visible via the ring reappearing equipped.

## Fix

`reap_connection` (tick.rs) gains three flush blocks after the bank flushes, mirroring the
periodic `checkpoint_dirty` exactly and the reap's existing coins/bank inline style:
- `inventory_dirty` → `db::save_inventory(conn.inventory.to_rows())`
- `is_dirty_for_resource_persist()` → `db::checkpoint_resources(hp/mp/stamina/xp/xp_to_next/
  level)` + `mark_resources_persisted()`
- `skills_dirty` → build weapon/armor/casting `SkillRow`s → `db::save_skills`

Behavior is identical to what the 60s checkpoint already does for those rows; this just makes a
clean logout flush the tail instead of dropping it. No new risk over the existing checkpoint
(same functions, same dirty flags).

## Verification

`cargo build` clean; 163 lib tests green. In-game relog/restart persistence is the playtest's
job (`disconnect_flush_checklist.md`).

## Open follow-ups (unchanged)

Dev-panel modernization (Test Panel ghost items + client-local Rotfang spawn) and quest slice D
(Brom's dialogue).
