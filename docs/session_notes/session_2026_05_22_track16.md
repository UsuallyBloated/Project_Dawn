# Track 16 — Spell book memorize workflow + Skill bar social library

Date: 2026-05-22.

Track 16 lifted the spell book and skill bar into the classic-MMO
feel: memorize-a-spell-to-the-bar workflow + a character-scoped
social/macro library that outlives any one slot. Five Track 15 UX
regressions found in the 2026-05-22 playtest were fixed first
(sub-task 16.0) before the new work landed.

## 16.0 — Track 15 regression fixes

All five bugs traced to the Track 15 UX quick-wins batch
(2026-05-21). One-line to ~20-line each; surgical fixes per the
diagnoses in `handoff_track_16.md`.

**Bug 1 — Stackable count visible during drag** —
`scripts/inventory_window.gd:_refresh_cell`. The `is_drag_source`
branch cleared the icon and name label but left `count_label.text`
intact, so a half-stack drag showed both the floating overlay and
the source-slot count. Mirrored bag_window.gd's pattern:
`count_label.text = "" if is_drag_source else ...`.

**Bug 2 — `_return_drag_to_source` in launcher mode left the source
cell painted empty** —
`scripts/inventory_window.gd:_return_drag_to_source`. The launcher
branch dropped the drag overlay but skipped the source-cell repaint.
Since `_refresh_cell` reads `drag_item` to decide whether to paint the
slot empty (Bug 1 fix's same flag), clearing the drag without
re-painting left the cell stale. Capture `prev_bi/prev_si` before
`_clear_drag()`, then `_refresh_cell(prev_si)` after.

**Bug 3 — Left-click + paperdoll slot equip never lands** —
`scripts/inventory_window.gd:_input`. Godot fires Node-level `_input`
BEFORE Control-level `_gui_input`. The inventory window's `_input`
ran first on any left-click, saw the click wasn't over a base cell /
bag window / trash, and called `_return_drag_to_source()` — clearing
the drag before paperdoll's `_gui_input` ever fired. Added a
`_find_paperdoll_window()` scan (mirrors the pattern paperdoll already
uses to find inventory_window) and an early-return when the click
lands inside the paperdoll's global rect.

**Bug 4 — Pet target overridden every tick by inheritance pre-pass**
(server) —
`crates/projectdawn-server/src/world/tick.rs`. The pre-pass mapped
every Follow-stance pet to an inherited target each tick at 20 Hz.
When the owner's `last_attacked_enemy` aged past
`PET_TARGET_DECAY_SECS` (10 s), `inherited` became `None` and the
unconditional `pet.target = target` write zeroed out the pet's target
mid-fight. Symptom: pet stops, wanders back to owner.
Fixed by checking the pet's current target against
`enemy_target_snapshots` before inheritance runs; if the pet already
has a live target, keep it and skip the owner re-inherit. Inheritance
only fires when the pet has no live target.

**Bug 5 — Sub-window text-focus walk only recurses one viewport
level** — `scripts/player.gd:_viewport_has_text_focus`. The previous
walk iterated direct children of the root viewport and only descended
when the child was itself a Window. The Social/Macro Window lives
deeper (CanvasLayer → Hotbar → Window), so the walk never reached it
and spacebar still jumped the character while typing a macro.
Rewrote as `_scan_for_text_window(node)` that recurses through the
entire subtree, checking each Window's own focus owner. Cost is a
~100-node scan per physics tick; cheap.

## 16.1 — Spell book memorize workflow

The classic-MMO feel: a player can't cast directly from the spell
book. Memorize requires sit + open book + click spell + click a spell
bar slot. The clicked slot stores the memorized spell and that's the
only path to casting.

**Two new autoloads**:

`autoloads/memorize.gd` — tiny state layer between the spell book
(selects) and the spell / hotkey bar (assigns). Holds
`candidate: SpellData` and emits `candidate_changed(spell)`. Polls
the local player's `state` each frame; when the player stands up
(or zones / dies / etc.), the candidate clears so a stale "still
holding spell" state doesn't leak across gestures.

`autoloads/spell_bar.gd` — per-character memorize bar storage. 10
slots, each holds a spell name (or "" empty). Persists to
`user://spell_bar.json` with a debounced save. `Spells.spells_changed`
sweeps the slots and clears any whose memorized spell is no longer
in `Spells.available` (level-up rank refresh, alignment shift, etc.).

Both registered in `project.godot` under `[autoload]`.

**`scripts/spell_book.gd` rebuild**:
- Row left-click no longer casts. Sit-gated select: if the player
  is sitting it sets `Memorize.set_candidate(spell)` and highlights
  the row gold; otherwise it logs "You must be sitting to memorize
  spells." and clears the candidate.
- Hint label added under the title: "Sit, click a spell, then click
  a Spell Bar slot to memorize."
- Click on the same spell twice deselects (toggle off).
- `visibility_changed` clears the candidate on close (the gesture
  belongs to one open of the book).
- `Memorize.candidate_changed` repaints every row so the highlight
  follows the active candidate.
- `Spells.spells_changed` clears the candidate if its spell was
  refreshed out of the available list.

**`scripts/hotbar.gd` spell-bar rework**:
- The right-side spell bar was an auto-populated read-only row
  showing `Spells.available[0..10]`. Now it's a player-configurable
  memorize bar driven by `SpellBar`. Each slot reads its memorized
  spell from `SpellBar.get_spell(i)`.
- `_on_spell_clicked` left-click branch:
  - With a memorize candidate held → `SpellBar.set_slot(index,
    candidate.spell_name)` + `Memorize.clear()` (completes the
    memorize gesture).
  - Without a candidate → `SpellBar.cast_slot(index)` (casts the
    memorized spell, or no-op if empty).
- `_on_spell_clicked` right-click clears the slot — closes the
  user's 2026-05-22 ask "Right-click a spell on the hotbar, spell
  is not removed."
- `_unhandled_input` Alt+digit now routes through
  `SpellBar.cast_slot(slot_idx)` (was `Spells.cast_by_index` against
  the defunct auto list).
- `_on_spell_hover` reads the memorized spell from SpellBar for the
  tooltip; falls back to "Click to memorize <name> here." when a
  candidate is held over an empty slot.
- The hotkey bar's left-click branch (`_on_hotkey_input`) also
  accepts a memorize candidate: `SocialHotkeys.set_slot_spell(slot,
  candidate)` + clear. Empty slots subtly highlight while a
  candidate is held (gold border, matches the open-bag pattern).

**Edge cases handled**:
- Player stands up while a candidate is held → Memorize polls
  `_player.state` and clears.
- Spell book closes while candidate is held → cleared via
  `visibility_changed`.
- Memorized spell is refreshed out of availability (level-up etc.)
  → SpellBar's `_on_spells_changed` clears the slot, fires
  `slot_changed`, hotbar refreshes.

## 16.2 — Skill bar social/macro library tier

Lifts socials/macros into a character-scoped library that outlives
any one slot. Editing a library entry instantly updates every slot
that references it.

**`autoloads/social_hotkeys.gd` extensions**:
- New `library: Array[Dictionary]` field. Each entry:
  `{ id: String, label: String, lines: Array[String] }`. IDs minted
  as `lib_<unix>_<seq>`.
- New verbs: `library_add(label, lines) -> id`,
  `library_edit(id, label, lines)` (refreshes label on referencing
  slots), `library_delete(id)` (clears referencing slots),
  `library_list()`, `library_get(id)`.
- Slot type `TYPE_SOCIAL` gained a `library_id` field. Legacy
  `set_slot_social(slot, label, lines)` still works — it mints a
  library entry and stores the ref. New code calls
  `set_slot_social_ref(slot, library_id)` directly.
- `execute_slot` for `TYPE_SOCIAL` reads `lines` from the library
  entry by `library_id` (falls back to inline `lines` for any
  pre-migration slots that slipped through).
- Save schema is now a Dictionary with `banks` + `library` +
  `next_lib_seq`. `_load` accepts the legacy top-level-Array schema
  and migrates inline-lines socials into library entries on load
  (so existing `user://social_hotkeys.json` files keep their
  macros). Both schemas round-trip cleanly.

**`scripts/hotbar.gd` social editor rebuild**:
- The right-click context menu gained `Manage Socials...` and
  renamed `Create Social...` to `Assign Social...`. Both open the
  same window in different modes:
  - "Assign Social..." → pick mode: click a library entry to assign
    to `_ctx_slot` (or save a new entry — auto-assigns in pick mode).
  - "Manage Socials..." → browse mode: full CRUD across the library
    with no slot assignment.
- The editor itself became two-pane: left rail is an ItemList of
  library entries + "New social" / "Delete" buttons; right pane is
  the existing label + 5-line editor + "Save" / "Close".
- "Save" writes through `library_add` (when no entry is selected)
  or `library_edit` (when one is). Status label tells the player
  which mode they're in.
- "Delete" calls `library_delete` which walks every bank and clears
  every slot referencing the deleted entry.
- `SocialHotkeys.library_changed` re-populates the ItemList.

## Files touched

Client (`F:\Projects\Project_Dawn\`):
- `scripts/inventory_window.gd` (16.0 bugs 1, 2, 3)
- `scripts/player.gd` (16.0 bug 5)
- `scripts/spell_book.gd` (16.1 — row click → memorize candidate)
- `scripts/hotbar.gd` (16.1 spell bar rework + memorize candidate
  routing; 16.2 social library editor rebuild)
- `autoloads/social_hotkeys.gd` (16.2 library tier + migration)
- `autoloads/memorize.gd` (new, 16.1)
- `autoloads/spell_bar.gd` (new, 16.1)
- `project.godot` (registered Memorize + SpellBar)

Server (`F:\Projects\server\`):
- `crates/projectdawn-server/src/world/tick.rs` (16.0 bug 4)

`cargo +1.95.0 check -p projectdawn-server` clean (one pre-existing
dead-code warning, not Track 16's).

## Carry-forward

- **Cooldown server-auth + movement-during-cast interrupt** — still
  outstanding from the Track 14/15 handoffs.
- **Skill leveling server-auth** — WeaponSkills / ArmorSkills /
  CastingSkills are still client-only.
- **Zone transitions** — large track when a second zone lands.
- **Memorize bar reset on death / zone change** — currently relies
  on the player-stands-up trigger. If death drops the player to
  STANDING, Memorize.clear fires; verify on first playtest.
- **No memorize cost yet** — classic MMO charges MP to memorize.
  Out of scope for 16; reopen with the consumable-spell-component
  thread.
