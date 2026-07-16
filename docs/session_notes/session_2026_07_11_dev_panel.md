# Session 2026-07-11 (playtested + committed 2026-07-16) — Dev panel modernization + /give gate

Both repos, branch `fix/xp-leveling-overflow`. **No wire change, no DLL rebuild** (reuses the
existing `GmCommand`). Built 2026-07-11, playtest-verified and **COMMITTED 2026-07-16**
(server `a765573` + the client commit on this branch). Closes the loose threads the quest
playtests surfaced (ghost items, client-local Rotfang) plus the exploit audit's #1 finding.

## What changed and why

Three problems, all confirmed in earlier triage:

1. **Ghost items.** The Test Panel give-buttons (`_give_bow/_proc/_consumables/_bags/_crafting`)
   called `Inventory.add_item()` client-only, so the server never recorded them, causing the
   inventory desync (reward overwriting a ghost, `EquipItem rejected, source slot empty`).
2. **`/give` ungated.** `GmCommand` (the `/give` chat command plus `GmGive`) had no `is_dev`
   check. The exploit audit's top finding: any in-world client could mint any item, free and
   persisted.
3. **Rotfang client-local, and no Rat mob.** `_spawn_named_enemy` spawned a client puppet (no
   credit, golden orb) instead of `DevSpawnMob`, and there was no Rat mob to test
   `rat_infestation`.

## Server (`F:\Projects\server`)

- `handlers.rs`: **gated the `GmCommand` handler with `!conn.is_dev`**, like
  `HealSelf`/`DevSpawnMob`. Closes the ungated-`/give` mint exploit and backs the Test Panel's
  server-side gives (which run with `PD_DEV_CMDS=1`). No new wire message: `GmCommand` carries
  a `line` string, and give-by-`lookup_by_name` (exact match) already exists.
- `main.rs`: added a boot-time `dev_cmds=true/false` field to the startup banner plus a WARN
  when enabled, so it is never ambiguous whether the gate is active. A `$env:` var persists
  across restarts in the same shell, which masked the fix during the first playtest.

## Client (`f:\Projects\Project_Dawn`)

- `autoloads/item_registry.gd`: `all_items()`, every indexed template sorted by name (for the
  picker).
- `scripts/test_panel.gd`:
  - New **GEAR** section (declutters the packed RESOURCES): a searchable **item picker** (filter
    LineEdit + ItemList + Qty SpinBox + "Give Selected Item"; double-click also gives) that
    grants ANY registry item, plus the moved loadout buttons.
  - New `_grant(item, qty)` helper: launcher mode sends `Net.broadcast_gm_command("give <name>
    <qty>")` (server-recorded, dev-gated); Test Room adds a fresh local copy. All give-buttons
    route through it.
  - The two runtime-built give-buttons swapped to registry items so they are grantable
    server-side: consumables to `bread_loaf`/`water_flask`, bags to `small_pouch` (x2).
  - **Rat** added to `NORMAL_MOBS` (level 1) so `rat_infestation` is fully testable.
  - `_spawn_named_enemy` now routes through `Net.send_dev_spawn_mob` in launcher mode using the
    named mob's resolved stats (level; base enemy 50 HP / 5 dmg times the named multipliers).
    Rotfang becomes a real server creature (kill credit + server corpse). Caveat: enrage and
    guaranteed loot are client-only named-mob features with no server side, so it is a generic
    server mob with the named display name. Enough for `rotfang_hunt` (kill credit; reward is
    the server-granted Hunter's Medal).

## Design note

Chose to **reuse the existing `GmCommand` give-by-name** rather than add a new `DevGiveItem`
wire message (floated earlier as "givepath"): `lookup_by_name` is an exact case-sensitive
match, the picker always sends an explicit trailing qty (so the parser is unambiguous even for
number-ending names), and the picker selects a real registry item, so by-name is safe and needs
zero wire change. Gating `GmCommand` (option B, user's call) fixes the exploit in the same spot.

## Verification

163 server lib tests; clean `cargo build`; headless client boot parses clean (Test Panel +
registry). Playtested 2026-07-16 against the checklist: picker grants persist across relog, Rat
and Rotfang full quest loops complete (`rat_infestation` reward 150, `rotfang_hunt` reward
48800), no ghost/overwrite errors.

The `/give` gate was proven across three preserved server logs:

- `dev_panel_gate_retest_devon.log` (dev on): `GmGive rejected, inventory full` (blocked by
  full bags, not the gate).
- `dev_panel_gate_retest_devon_run2.log` (dev on): `GmGive applied ... qty=1` once there was
  room. Confirms the earlier failure was the full inventory, not the gate.
- `dev_panel_gate_retest_devoff.log` (dev off, boot line `dev_cmds=false`): zero `GmGive` lines.
  The client showed "requested..." (optimistic broadcast) but nothing minted. Exploit closed.

## Open follow-ups

Named-mob enrage + guaranteed-loot server side (so a server Rotfang drops its fang and enrages);
the other exploit-audit items (swing-rate limit, Respawn dead-check, cast class/level gate).
Also noted during playtest: character can attack while seated (unrelated bug, separate task).
