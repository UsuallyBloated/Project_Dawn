# Track 16 Handoff — Spell book memorize workflow + Skill bar social library

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
Rust server (auth WS + world UDP), Godot launcher, standalone
procedural dungeon generator.

Tracks 14 and 15 closed the server-authoritative inventory loop:
items, equip / unequip, vendor buy / sell, drag-and-drop, destroy,
use-consumable, and `/give` all flow through `Net.broadcast_*` in
launcher mode now. Track 15.3 added pet GUARD / SIT. Track 15
follow-ups added the initial CoinsUpdate seed on EnterWorld, pet
auto-engage on owner damage, player damage INFO logging, and 6 UX
quick wins (Crude Health Potion data, pet targeting, sub-window
text-focus gate, source-slot icon hide during drag, paperdoll
left-click equip, hotbar right-click clear).

Track 16 is the **classic spellcasting feel** lift: spell book +
spell bar workflow rework, plus the matching skill-bar social /
macro library. Both have working scaffolding already; the work is
reshaping the UX and adding persistence + library management.

Estimated 2 sessions: sub-task 16.1 (spell book memorize) is the
bulk; 16.2 (skill-bar social library) is a clean follow-up on the
same input-gating + library pattern.

After Track 16:
- Casting a spell requires the player to memorize it first
  (classic-MMO feel). Memorize = sit + open spellbook + click
  spell + click target spell-bar slot.
- Spell book row left-click no longer casts. Spell bar slots are
  the only path to casting.
- Players have a per-character social / macro library that
  outlives any one bank, with create / edit / delete / assign-to-
  bank verbs.
- Movement input correctly gates whenever any text input has focus
  (including the social editor's sub-window — already done in
  Track 15 follow-up, just stays for 16's reuse).

## Four repos at handoff

| Repo | Path | Branch |
|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` |
| Server | `F:\Projects\server\` | `main` |
| Launcher | `F:\Projects\launcher\` | `main` |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` |

Run `git -C <each> log --oneline -10` before touching anything. The
client + server have uncommitted Track 15 follow-up + Track 15
quick-wins changes — read the diff before starting.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_20_track15.md` — the
   server-authority lift closeout. The wire patterns there are the
   template for any new wire variant Track 16 needs (unlikely; this
   is UI work).
3. `docs/playtest_notes/testing_notes_2026_05_21.md` — user
   feedback that defined the Track 16 scope. Sub-task 16.1 is the
   "Spell Book" + "Spell Bar" sections; 16.2 is the "Skill bar"
   section.
4. `scripts/spell_book.gd` — current spellbook. Lines 144–147 are
   the click-to-cast handler that needs to become click-to-memorize.
   No persistence layer; rebuild fires on `Spells.spells_changed`.
5. `scripts/hotbar.gd` — spell bar / skill bar (same widget). The
   slot data model lives in `autoloads/social_hotkeys.gd`. Lines
   362–445 are the existing Social / Macro editor Window — works
   but lacks an "Add to library" and library-browse step.
6. `autoloads/social_hotkeys.gd` — `BANK_COUNT = 10`, `SLOT_COUNT =
   10`, persisted to `user://social_hotkeys.json`. `TYPE_SPELL` /
   `TYPE_SKILL` / `TYPE_SOCIAL` / `TYPE_EMPTY`. The library Track
   16.2 adds is a parallel store; this autoload stays mostly
   unchanged.
7. `autoloads/spells.gd` — `available: Array[SpellData]` is the
   server-of-truth for what the player can cast. `setup_for_class`
   filters by class + level + rank. `cast_spell(spell)` is the
   entry. Memorize state will be a new layer between `available`
   and `cast_spell`.
8. `scripts/player.gd` — `enum PlayerState { STANDING, CROUCHING,
   SITTING }` + `sit()` / `stand()` are already there (line 53,
   134). 16.1's memorize-requires-sitting check just reads
   `_player.state`.

---

## Scope

### Sub-task 16.0 — Known regressions from Track 15 UX batch (~half session)

Five bugs surfaced in the 2026-05-22 playtest, all from the
Track 15 UX quick-wins commit (yesterday). Fix these before
moving on; they're 1-line to ~20-line each and trace to clear
root causes diagnosed from server.log + the user's notes.

**Bug 1 — Stackable count visible during drag** (1 line)

`scripts/inventory_window.gd:_refresh_cell`. When `is_drag_source`
is true, I cleared `icon_rect.texture` and `name_label.visible`
but forgot to clear `count_label.text`. `bag_window.gd`'s
equivalent does it correctly — mirror that pattern. The else
branch:

```gdscript
count_label.text = "" if is_drag_source else (str(slot["count"]) if slot["count"] > 1 else "")
```

**Bug 2 — `_return_drag_to_source` in launcher mode doesn't
restore source-cell visual** (~5 lines)

`scripts/inventory_window.gd:_return_drag_to_source`. The
launcher branch calls `_clear_drag()` directly without
refreshing the source cell, so the icon stays hidden after a
cancel. Mirror what `cancel_drag()` does: capture `prev_si`
before clearing, then `_refresh_cell(prev_si)` (or
`Inventory.inventory_changed.emit()` for the bag case) after.

**Bug 3 — Left-click + paperdoll slot equip never lands**
(~10 lines)

Godot fires `_input` (Node-level) BEFORE `_gui_input` (Control-
level). `inventory_window._input` runs first on any left-click,
sees the click isn't over an inventory cell / bag window / trash,
and calls `_return_drag_to_source()` — clearing the drag before
paperdoll's `_gui_input` ever fires.

Fix: in `inventory_window._input`, before the
`_return_drag_to_source` call, also check whether the click is
on a paperdoll slot. Scan the scene tree for `paperdoll_window`
(or expose paperdoll's slot rects via a group), and if the
cursor is over any of its slot frames, early-return. This is
the same pattern as the existing bag-window and cell checks
already in `_input`.

**Bug 4 — Pet target overridden every tick by inheritance
pre-pass** (~10 lines, server-side)

`crates/projectdawn-server/src/world/tick.rs` — the pet
inheritance pre-pass runs every tick at 20 Hz and unconditionally
sets `pet.target` from `owner.last_attacked_enemy`. If the owner
stops attacking for 10s (`PET_TARGET_DECAY_SECS`), the pre-pass
sets pet's target to `None` even when the pet is actively
engaged with a live enemy. Symptom: pet stops mid-fight and
wanders back to owner.

Fix: when the pet already has a live target (target_id resolves
to an alive enemy in `enemy_target_snapshots`), skip the
override and keep the current target. Inheritance only kicks
in when `pet.target.is_none()` or when the held target is dead /
gone.

Playtest evidence: server.log shows pet 3000000002 lived 16
minutes and made one kill — should have been several. Damage
gap between owner attacks let the inheritance clear pet's
target repeatedly.

**Bug 5 — Sub-window text-focus walk only recurses one viewport
level** (~5 lines)

`scripts/player.gd:_viewport_has_text_focus`. The walk uses
`vp.get_children()` — only direct children of the root
viewport. The Social/Macro `Window` is parented deep (CanvasLayer
→ Hotbar → Window). The walk doesn't reach it. Result: spacebar
still jumps the character while editing macros.

Fix: recurse through the entire subtree, not just one level.
Cost is ~100 nodes per physics tick (still cheap), but if it
matters, gate on `state == STANDING` (only check when input
matters) or cache the result with a focus-change signal.

```gdscript
func _viewport_has_text_focus(vp: Viewport) -> bool:
    var f := vp.gui_get_focus_owner()
    if f != null and (f is LineEdit or f is TextEdit):
        return true
    return _scan_for_text_window(vp)

func _scan_for_text_window(node: Node) -> bool:
    for child in node.get_children():
        if child is Window:
            var inner = (child as Window).gui_get_focus_owner()
            if inner != null and (inner is LineEdit or inner is TextEdit):
                return true
        if _scan_for_text_window(child):
            return true
    return false
```

---

### Sub-task 16.1 — Spell book memorize workflow (~1.5 sessions)

**The classic feel** — and the user's exact ask:

> Player should not be able to cast a spell by clicking on the
> spell in the spellbook. Player has to "memorize" spell before it
> is able to be cast. Memorize requires the caster to sit, open
> their spell book, locate the desired spell, left-click the name
> of the spell, then left-click on the Spell Bar slot you would
> like to assign the spell.

This is two changes layered together:

1. **Spell book row click no longer casts.** Currently
   `spell_book.gd:144-147` left-click → `Spells.cast_spell(spell)`.
   That goes away. Row click instead selects the spell as the
   "memorize candidate" — visually highlighted, cursor / tooltip
   indicates "click a Spell Bar slot to memorize."

2. **Spell bar slot click while a memorize candidate is held** →
   assigns the spell to that slot. This already exists as
   `SocialHotkeys.set_slot_spell(slot, spell)` — the new wiring
   just needs to route the candidate through it.

   **Clarification on which "Spell Bar":** today `hotbar.gd`
   has TWO widgets — an auto-populated read-only row showing
   `Spells.available` (the `_spell_slots` array), and the
   user-configurable hotkey bar (the `_hotkey_slots` array,
   banks 1–10). Track 16.1 redesigns the auto row into a
   memorize bar: it stops being auto-populated and becomes the
   assignment target for memorized spells. **Right-click on a
   memorized slot then naturally means "remove memorization,"**
   closing the user's 2026-05-22 ask ("Right-click a spell on
   the hotbar, spell is not removed"). The hotkey bar's
   existing right-click-clear behaviour (Track 15 batch) stays.

   Additionally, the **memorize** action requires the player to
   be sitting (`_player.state == PlayerState.SITTING`). Standing
   memorize attempts should fail with a combat-log line
   ("You must be sitting to memorize spells.").

**Touchpoints:**

- `scripts/spell_book.gd`:
  - Add `_selected_for_memorize: SpellData = null` state on the
    spell book.
  - Rewrite the `bg.gui_input` lambda (lines 144–147): left-click
    → if sitting, set `_selected_for_memorize = spell` and visually
    highlight the row; if not sitting, log "You must be sitting
    to memorize spells." Don't cast.
  - Add a clear-on-close + clear-on-cast-bar-click reset.
  - Highlight rendering: change the row's normal_style bg color
    when it's the selected memorize candidate. Hover style stays
    distinct.
  - Persistence is already handled — `SocialHotkeys` saves to
    `user://social_hotkeys.json` on every slot mutation; the new
    `set_slot_spell` call inherits this.

- `scripts/hotbar.gd`:
  - In `_on_hotkey_input` left-click branch (line 320): if
    `SpellBook._selected_for_memorize != null`, call
    `SocialHotkeys.set_slot_spell(slot, _selected_for_memorize)`
    and clear the candidate. Else (existing behaviour),
    `SocialHotkeys.execute_slot(slot)`.
  - Visual feedback: while a memorize candidate is held, the
    hotbar's empty slots should subtly highlight (a thin gold
    border, matching the open-bag pattern in
    `inventory_window.gd:_refresh_cell`).

- `scripts/spell_book.gd` accessor for the candidate: prefer
  exposing a static-ish reader (a class const + a static var, or
  a singleton-style autoload reference) over passing the SpellBook
  instance through. The cleanest pattern is a tiny
  `autoloads/memorize.gd` that owns the candidate state and emits
  a `candidate_changed(spell: SpellData)` signal. Both spell_book
  and hotbar read from it. Doc this autoload addition explicitly
  in the session notes.

- `autoloads/memorize.gd` (new):
  ```gdscript
  extends Node

  signal candidate_changed(spell)  # null = cleared

  var candidate: SpellData = null

  func set_candidate(spell: SpellData) -> void:
      if candidate == spell:
          return
      candidate = spell
      candidate_changed.emit(spell)

  func clear() -> void:
      set_candidate(null)
  ```
  Register in `project.godot` under `[autoload]` as
  `Memorize="*res://autoloads/memorize.gd"`. Tiny — fewer than 20
  lines.

**Edge cases:**

- **Player stands up while a candidate is held** — the candidate
  should clear (memorize requires sitting; standing breaks it).
  Wire via `player.gd`'s state-change signal (or `Regen`'s
  `_on_sit_changed` if it exposes one) → `Memorize.clear()`.
- **Spell book closes while candidate is held** — clear.
- **Combat starts while candidate is held** — depends on design.
  Classic MMO: sitting in combat is impossible (you stand
  automatically), so the player-stands-up edge case covers it.
- **Spell removed from `available` list (level-up rank refresh)**
  — if the candidate was the now-removed rank, clear. Wire via
  `Spells.spells_changed`.

**Tests / verification:**

- Manual smoke: sit → open spellbook → click "Magic Missile" →
  click empty hotbar slot → spell appears in slot. Cast from
  hotbar. Standing → click spell → see "must be sitting" log.
- No server work — memorization is pure client-side UI.

### Sub-task 16.2 — Skill bar social / macro library (~1 session)

**The user's exact ask:**

> No way to add the social/macro button to skill bar. No "add"
> button to finish the button and add it to the skill bar.
> Players should have personal libraries of social/macro buttons.

The Track 15 hotbar UX has the social editor pop directly to a
specific slot (the `_ctx_slot` they right-clicked). Track 16.2
adds a **library tier** on top: socials live in a
character-scoped library, and slot assignment is a separate verb.

**The new model:**

- A character has a `socials_library: Array[Dictionary]` — every
  social/macro they've authored, persistent across banks.
- Slot assignment is "pick from library." A slot stores a
  reference (e.g. library index or UUID) to the library entry; the
  library entry owns the canonical `label` + `lines`.
- When the library entry changes (edit), all assigned slots
  visually reflect.

**Touchpoints:**

- `autoloads/social_hotkeys.gd`:
  - Add `library: Array[Dictionary]` — each entry
    `{ id: String (uuid-ish), label, lines: Array[String] }`.
  - New verbs: `library_add(label, lines) -> String (id)`,
    `library_edit(id, label, lines)`, `library_delete(id)`,
    `library_list() -> Array[Dictionary]`.
  - Slot type `TYPE_SOCIAL` gets a new field `library_id` (in
    addition to the existing inline `lines` for back-compat).
    `set_slot_social(slot, library_id)` is the lifted entry. The
    legacy `set_slot_social(slot, label, lines)` stays for one
    track as a deprecation path.
  - `execute_slot` for `TYPE_SOCIAL` reads from the library entry
    instead of the inline lines.
  - Save / load: extend `user://social_hotkeys.json` schema to
    include the `library` array. Add a one-shot migration that
    promotes any inline-lines slots into library entries on first
    load.

- `scripts/hotbar.gd`:
  - The current social editor Window (lines 362–445) becomes the
    library editor — opens with a left rail listing all library
    entries + "New social..." button. Selecting an entry shows
    the existing label + 5-line editor on the right. Buttons:
    "Save" (writes to library, updates assigned slots), "Delete"
    (removes from library, clears assigned slots), "Cancel."
  - The "Create Social..." context menu item now opens the
    library, NOT a fresh editor. Library-add is a button inside
    the library.
  - New context menu item "Assign Social..." opens the library
    in pick mode → click an entry → it lands in `_ctx_slot`.
  - The "Assign Spell..." and "Assign Skill..." entries stay
    unchanged.

**Edge cases:**

- **Migration** of existing `user://social_hotkeys.json` files:
  if a slot has inline `lines`, mint a library entry (label =
  slot's `label`, lines = slot's `lines`) and replace the slot
  with a `library_id` ref. Do this in `_load()` before
  `_set_slot` calls land.
- **Empty library** edge: the assign menu shows "(no socials
  yet — click New social to create one)."
- **Many-slot reassignment** if user deletes a library entry:
  walk every bank's slots, clear any slot whose `library_id`
  matches the deleted entry.

**Tests / verification:**

- Manual smoke: create a "Greet" social with `/say Hello %t!` →
  appears in library → assign to bank 1 slot 3 → execute slot 3
  → log shows greeting. Edit "Greet" to use `/yell` instead →
  slot 3 now yells.

---

## Cross-cutting cleanups (small wins, this track or follow-ups)

- **Destroy button "some items not others"** — user reported this
  in the May 21 notes but didn't specify which items. If they
  follow up with a repro, look at the trash flow in
  `inventory_window.gd:_show_delete_confirm` /
  `_confirm_trash_delete` and the bag destroy in
  `bag_window.gd:_confirm_destroy`. Most likely cause: drag source
  state (`drag_source_bi` / `_si`) wasn't updated by some path
  that doesn't go through `begin_drag`.
- **Soul Drain + Bind Affinity** not in server `spells.toml` —
  cast attempts log `unknown spell name — server-side cast dropped`
  but the client renders a fake damage number. Either populate
  `crates/projectdawn-server/data/spells.toml` (add entries
  mirroring the GDScript spell definitions for those two) or
  silence the client's predictive damage display when launcher
  mode would result in a server reject. Picking the first is
  ~10 lines of TOML.
- **Named-mob runtime loot has no .tres** — Chitinous Ring,
  Pristine Venom Sac, and the other 13 named drops live in
  `data/named_mob_definitions.gd` as inline dicts. They're
  client-only items, so equip / sell / destroy silently fail
  server-side ("source slot empty" / "unknown item path"). Two
  options: (a) author one `.tres` per named drop (~15 entries,
  regen `items.toml` via `tools/export_items_oneshot.py`); or
  (b) build a runtime registry that the server side can validate
  against (bigger lift). Pick (a) for the cleaner ROI.

---

## Carry-forward from Track 15

Track 15 closed inventory authority. The remaining server-auth
items from the original Track 14 / 15 handoffs:

- **Cooldown server-auth** — per-player per-spell cooldown map;
  reject `CastSpell` that arrives before the cooldown expires.
  Tightly coupled with the next item.
- **Movement-during-cast interrupt** — server compares caster
  pos at `cast_set_at` vs now in the gate. Prevents kiters from
  breaking the cast-time gate via "I didn't move" forging.
- **Skill leveling server-auth** — `WeaponSkills` / `ArmorSkills`
  / `CastingSkills` autoloads still track per-skill progression
  client-only. Each needs a server-auth lift (mirror of
  `PlayerStats` — server owns the truth, client renders +
  broadcasts the progression events).
- **Zone transitions** — when a second zone lands. Big track:
  server-side zone routing, world-token re-issue or re-handshake,
  position handoff, AOI grid per zone.

After Tracks 16 + the carry-forward, the netcode is functionally
complete and focus shifts to content / UI / polish / playtest
scaling.

---

## Known flaky tests

`world_two_clients.rs` integration tests have 1–3 intermittent
failures per full-suite run, always among the AI-walks-into-melee
timing tests:

- `lifesteal_spell_heals_caster`
- `player_attack_kills_enemy_and_corpse_despawns`
- `enemy_aggros_chases_and_attacks_player`
- `pet_pulls_aggro_via_threat_reaggro`
- `aoe_spell_damages_nearby_enemies`

All pass when run in isolation. Track 11 notes flagged this and
bumped timeouts 20s → 35s; that helped but didn't fix the
underlying parallel-test scheduling sensitivity. **None of Track
16's work touches combat AI**, so failures during Track 16 are
almost certainly pre-existing — re-run before assuming a
regression.

A real fix would either (a) serialize the AI-timing tests via
`--test-threads=1` on a CI-specific profile or (b) replace the
real-time waits with manual tick advancement. Out of scope for
Track 16 but worth a dedicated track eventually.

---

## Quick-reference: what's already done since the last handoff

So the next session doesn't redo work:

**Track 15.1 / 15.2 / 15.3** (committed status: uncommitted, in
working tree):
- Right-click equip / unequip via `Equipment.request_equip_from` /
  `request_unequip`.
- Server `equip_from_location` (generalised from `equip_from_base`
  to accept bag sources).
- `DestroyItem` wire variant + apply.
- `UseConsumable` server handler (validates is_food / is_drink /
  heal_on_use; decrements; fans HealthUpdate / ManaUpdate /
  BuffSnapshot with `"Food: "` / `"Drink: "` name prefixes).
- `PetCommand::GUARD` / `SIT` server-side: `PetStance` enum on
  `Entity`; `tick_pet_ai` branches; inheritance pre-pass filters
  by stance; Guard pets retaliate on damage.
- `send_destroy_item` + `send_use_consumable` + `send_gm_command`
  `#[func]` exports on `NetClient`; DLL rebuilt (static-CRT
  release, 4.1 MB, deployed).

**Track 15 follow-ups:**
- Initial `CoinsUpdate` seed on EnterWorld (fixes "gold not
  tracked").
- Pet auto-engage owner's attacker (sets
  `conn.last_attacked_enemy` on damage).
- INFO logs for player damage + all inventory intent applies /
  rejects.
- Server-side `/give` via `GmCommand` parser + apply phase.
- `_use_consumable` UX fix (no more "can't use" misfire when we
  did send the broadcast).
- `DebugLog.LOG_PATH` → `user://debug.log` (works in launcher
  exports; print the resolved path on startup).
- Chat scroll auto-snap: `await get_tree().process_frame` before
  reading `v_scroll_bar.max_value`.

**Track 15 UX quick wins (last session before this handoff):**
- `crude_health_potion.tres`: `heal_on_use = 30.0`; `items.toml`
  regenerated via `tools/export_items_oneshot.py`.
- `targeting.gd`: pets + remote_pets are valid click targets.
  `hud.gd:_on_target_changed`: pet branch renders HP + level.
- `player.gd:_is_text_input_focused`: recurses through sub-window
  viewports so social-editor typing gates movement (fixes
  spacebar-jumps-while-editing).
- `inventory_window.gd` / `bag_window.gd`: source-slot icon hides
  during drag (drag overlay is the one-and-only on-screen copy).
- `paperdoll_window.gd`: left-click on a paperdoll slot equips
  the dragged item (via new `target_slot_hint` param on
  `Equipment.request_equip_from`).
- `hotbar.gd`: right-click slot with spell/skill clears it
  immediately; empty/social slots still open the context menu.

None of these are committed. Read the working-tree diff before
writing your own changes.

---

## Pick one and write the next handoff

Recommended start: **16.1 spell-book memorize.** It's the bigger
of the two and unblocks 16.2's clean library tier (since both
share the input-gating + slot-assignment pattern). 16.2 follows
naturally once memorize is wired.

If you have time after 16.1 + 16.2, the cross-cutting cleanups
(Soul Drain TOML, named-mob `.tres`, destroy button repro) are
small wins that close visible gaps in the playtest log.
