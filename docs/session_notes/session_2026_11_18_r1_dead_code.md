# Session 2026-11-18: R1 of the structure assessment, the 25 dead client functions

The user: "start on R1" (`docs/design/code_structure_assessment_2026_11_17.md` §5, R1:
delete the 25 functions its dead-function sweep found, "after a glance at each").

## 1. The verification

Every one of the 25 names was grepped as a whole word across the client repo's scripts,
scenes, resources, data, tools and `project.godot` (a `.tscn` can connect a method the code
never calls; `call("name")` and `has_method("name")` are strings the same grep catches). Each
had exactly one hit, its own `func` line, plus two comments. Nothing on the server or in the
DLL refers to GDScript names.

## 2. What went, and what each deletion took with it

24 functions deleted. The glance at each found what only that function used, which went too:

- `Net.broadcast_split_stack` and `Net.broadcast_buff_snapshot` (the DLL's two sends stay in
  the wire layer, which lives in the server repo). `net_combat_broadcaster.gd`'s header and
  its trailing note still described buff snapshots as client-driven; rewritten.
- `PlayerStats.lose_xp`.
- `QuestManager.fail_quest`, and with it the `quest_failed` signal (the journal was its one
  listener, with nothing left to emit it) and the journal's connect line. `Status.FAILED`
  stays: the enum's values are saved ints and the wire's `QuestStatus` carries it.
- `Languages.hear_language`, `garble`, `grant_language`, the private `_apply_cipher` only
  `garble` called, and the `skill_improved` signal nothing listened to. The file header now
  says where the wiring item picks these up (git, `6fef33b`).
- `Crafting.get_recipes`, `gain_skill_xp`, `get_all_skills_by_category`, the `XP_PER_LEVEL`
  and `RACIAL_XP_MULTIPLIER` constants and the `_skill_xp` map only `gain_skill_xp` read.
- `Memorize.is_committing`, `get_commit_spell`.
- `BuffManager.get_snapshot_arrays`.
- `CastingSkills.get_interrupt_chance` (the server rolls the interrupt; one comment line
  says so).
- `DamageNumbers.spawn_xp`, and with it the "XP Gains" checkbox under floating text in the
  options screen, the `floating_text_xp` setting it set, and `DamageNumber.Type.XP`. The
  function's own comment said it was kept for a future toggle; the toggle existed and did
  nothing, which is a worse trap than the dead function (a stale `floating_text_xp` key in an
  existing settings file is ignored).
- `ItemRegistry.find_exact`.
- `SocialHotkeys.set_slot_social` (its comment rewritten for the ref API that stays).
- `chat_window.apply_layout`.
- `mobile_character._move_at_speed`, and the whole `MobileCharacter` script: its only other
  function, `_face_toward`, was called by `_move_at_speed` alone, and nothing extends the
  class since the offline `enemy.gd` and `pet.gd` left with Phase 5. The file and its `.uid`
  are removed, and CLAUDE.md's key-files row with them.
- `protocol.gd`'s `slot_base`, `slot_bag`, `slot_equip` with the three `SLOT_*` constants
  only they used, and `vec3_from_godot`, `vec3_to_godot` with `vec3`, which the sweep had not
  listed and which had no caller either.

**Kept: `DebugLog.combat`.** It is one of the four log levels CLAUDE.md's debugging section
names, and the console colours COMBAT lines; a level with no writer today is API, not dead
code. The user's call if it should go too.

**Left, flagged:** `LanguageDefinitions.GARBLE_CIPHERS` (data) has no reader now; it is the
content the language wiring needs and R1 is about functions. `Crafting.skill_level_changed`
has two listeners (the crafting window, the HUD) and no emitter until tradeskills move to the
server; it is the seam that build fills.

## 3. Evidence

All 19 checks (`tools/check_all.ps1` against the deploy server) and all 24 `tools/probe_*.gd`
green, no script errors in any probe's output. 19 files, 24 lines in and 263 out, plus the
removed script. No wire change, no server change; rides the next export.
