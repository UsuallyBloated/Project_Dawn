# Session 2026-07-11 — Quest slice D: Brom's dialogue (rat/gnoll quests reachable)

Client-only, branch `fix/xp-leveling-overflow`. **No wire change, no server change, no DLL
rebuild.** BUILT + validated (script compile + editor scene-import clean), **awaiting playtest**
(`quest_sliceD_brom_checklist.md`) — not committed. This is the last root problem of the quest
phase-2 plan.

## The gap

Brom's FULL quest dialogue tree (`rat_infestation` + `gnoll_raiders`, with the slice-A
READY-gated turn-ins) was already authored in `data/dialogue_definitions.gd` — but unreachable:
`scenes/world.tscn` instantiated Brom from `vendor_npc.tscn`, so he registered only with
VendorManager and his dialogue never opened. He needs to be BOTH a talker (quests) and a vendor
(Provisioner).

## Fix

- `scripts/dialogue_npc.gd`: `DialogueNPC` gains optional `vendor_name` / `vendor_type` exports.
  When `vendor_name` is set, the NPC also registers with `VendorManager` on proximity (alongside
  `DialogueManager`). Empty for pure talkers (Aldric) — a no-op there.
- `scenes/world.tscn`: Brom's "Provisioner" node now instances `dialogue_npc.tscn` (was
  `vendor_npc.tscn`) with `npc_name = "Brom"` (matches the `"Brom"` dialogue tree key),
  `npc_title = "Provisioner"`, and the vendor fields carried over.

Interaction opens his **dialogue** because the HUD's `_try_open_targeted_npc` routes
`dialogue_npcs` ahead of `vendor_npcs` (hud.gd:709); his root "Show me what you have."
(`open_vendor` action) reaches the vendor via `VendorManager.open_nearby`, which now finds Brom
as the nearby vendor. Nothing changed in `dialogue_definitions.gd` — the tree was ready.

## Scope note

`gnoll_raiders` is fully testable (the Test Panel spawns Gnolls; its reward is the slice-B
Scout's Leather Boots, now reachable end-to-end). `rat_infestation` is acceptable + gates
correctly, but the Test Panel has no "Rat" mob yet, so its kill/turn-in isn't testable this
round — I'll add "Rat" to the dev spawn as part of the next task (dev-panel modernization),
keeping slice D scoped to the dialogue wiring.

## Verification

Headless boot: all scripts compile clean (DialogueNPC with the new exports). Headless
editor-import of `world.tscn`: clean, the rewired Brom node loads with no errors. In-game
dialogue/vendor/quest behavior is the playtest's job.

## Quest phase 2 — status after this

Closes the last of the plan's 7 root problems. Slices A (server objective tracking), B (item
rewards), and D (Brom's dialogue) are done; the phase-2 plan is complete pending this playtest.
Remaining follow-up: dev-panel modernization (Test Panel ghost items, client-local Rotfang
spawn, and adding a Rat mob).
