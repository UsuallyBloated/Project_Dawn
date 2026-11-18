# Code structure assessment, 2026-11-17

The user's question, the night of 2026-11-17: "have a look at the game's use of tools and
functions. Are we taking an object oriented approach? Are we suffering from bloat? Can we be
more efficient? ... please dont build something for the sake of building something."

Measured, not guessed: line counts and function lengths by script, coupling between the 50
client autoloads, a dead-function sweep, duplication by name and by body, signal use against
direct calls, and the server's module and function sizes. A read-only agent took the client
breadth measurements; every number quoted from it that this note leans on was re-checked by
hand (the dead functions, the four-way copy, the giant functions). Nothing here was changed in
code. The recommendations in §5 are few, ranked, and each says when it is worth doing; §6 says
what is not worth doing.

## 1. The short answer

- **Object oriented? Mostly no, and that is the right call for both halves.** The client is
  fifty singletons (Godot autoloads) talking to each other, which is a service layer, not an
  object model; Godot's own idiom is composition of nodes plus signals, and the code uses
  inheritance only where it pays (one window base class under 22 windows, one NPC base under
  three, one tracker base under three skill systems). The server is a data-oriented tick:
  one `WorldState`, 23 step functions in a fixed order, rules as free functions; that is the
  shape a 20 Hz authoritative simulation wants, and it tests well (726 tests, a 31% test
  ratio, every lint that matters on).
- **Bloat? Yes, in two specific places, and not where one would guess.** On the server, the
  tick split of 2026-11-01 made files but not functions: four functions are between 1,000
  and 1,950 lines each. On the client, the user interface is built in code (129 `_build`
  and `_make` functions, 141 `Label.new()`), and one chat-command dispatcher is a 475-line
  if-chain. Everything else is proportionate: the data files, the tools, the autoload count.
- **Efficiency? Runtime is not the problem; reading time is.** The server spends 0.5 to
  0.8 ms of its 50 ms tick (the `world health` line) and nobody has reported client
  slowness. The cost of the bloat is paid by whoever reads, reviews or audits the giant
  functions: tonight's cross-over audit spent most of its time inside them.

## 2. The numbers

### Client (GDScript, 125 scripts, 31,800 lines in `autoloads/` and `scripts/`; 3,955 in `data/`; 7,134 in `tools/`)

| Measure | Value |
|---|---|
| Autoloads registered | 50 (plus `PassiveSkillTracker`, a base class, unregistered) |
| Largest scripts | `hud.gd` 1,860; `net.gd` 1,487; `hotbar.gd` 959; `test_panel.gd` 790; `recipe_definitions.gd` 734 |
| Functions over 80 lines | 24; the longest `hud.gd::_handle_chat_input` 475 (the chat command dispatcher), `quest_journal.gd::_build_ui` 166, `hud.gd::_on_target_changed` 151 |
| `hud.gd` | 75 functions, median 7 lines; the five longest are 45% of the file; it reaches 26 of the 50 autoloads |
| UI built in code | 129 `_build*` / `_make*` functions; `Label.new()` 141 times in 34 files; `add_theme_color_override` 178 in 32; `Button.new()` 71; 16 scenes, 5 of them UI |
| Signals vs calls | 183 signals declared, 500 `.connect` calls (234 on autoload signals); 782 direct cross-autoload calls |
| Coupling hubs | `CombatLog` referenced 373 times (169 of them `add_line`, the chat sink); `Net` 274; `PlayerStats` 239; then a long tail |
| Autoloads nobody references by name | `VisionSystem`, `CharacterSetup`, `RemoteLootBagManager`, `RemoteCorpseManager`, `NetCombatBroadcaster` (they run on signals; not dead) |
| Dead functions (defined, never called anywhere) | 25, a lower bound: `Net.broadcast_split_stack`, `Net.broadcast_buff_snapshot`, `PlayerStats.lose_xp`, `QuestManager.fail_quest`, `Languages.hear_language / garble / grant_language`, `Crafting.get_recipes / gain_skill_xp / get_all_skills_by_category`, `Memorize.is_committing / get_commit_spell`, `BuffManager.get_snapshot_arrays`, `CastingSkills.get_interrupt_chance`, `DamageNumbers.spawn_xp`, `DebugLog.combat`, `ItemRegistry.find_exact`, `SocialHotkeys.set_slot_social`, `chat_window.apply_layout`, `mobile_character._move_at_speed`, and five helpers in `scripts/net/protocol.gd` (`slot_base`, `slot_bag`, `slot_equip`, `vec3_from_godot`, `vec3_to_godot`) |
| Duplicated bodies | the five `remote_*_manager.gd` share `clear_all`, `_instantiate_into`, `get_by_id`, `_scene_hosts_local_player` (identical, with a parameter none uses); `remote_enemy.gd` and `remote_pet.gd` share `_physics_process` (23 lines) and `_process`; `on_position_update`, `apply_buff_snapshot`, `get_spell_resist` identical across the three remote entity scripts; coin formatting in three places (`Currency.format_coins`, `trade_window._coin_text`, `vendor_window._coins_text`) |
| Data | 18 `data/*.gd` files, all `class_name` + `const` literals (Arrays of Dictionaries or string-keyed Dictionaries); the 181 item `.tres` loaded by `ItemRegistry` scanning the directory; every pair the server also holds has a lockstep check |
| Tooling | 19 `check_*.gd` (in `check_all.ps1`), 24 `probe_*.gd` |

### Server (Rust, 5 crates, 39 workspace dependencies)

| Measure | Value |
|---|---|
| Source | `world/` 46 files, 29,848 lines; `world/tick/` 30 files, 17,379; `db/mod.rs` 3,035; `protocol` 2,487; `gdext-net/src/lib.rs` 3,508 in one file (66 signals, 83 funcs) |
| Tests | 726 `#[test]` / `#[tokio::test]`; `tests/` 17,828 non-blank lines against 56,751 of source (31%) |
| Lints | `unwrap_used`, `expect_used`, `string_slice` denied in live code; clippy `-D warnings` and rustfmt blocking in CI; `#![forbid(unsafe_code)]` on three crates |
| Largest files | `handlers.rs` 4,093; `inventory.rs` 3,796; `entity.rs` 3,584; `casting.rs` 1,952; `obstacles.rs` 1,682; `connection.rs` 1,589 |
| Giant functions | `casting.rs::apply_casts` 1,945 lines (the file's only function); `handlers.rs::handle_message` 1,930 (of 83 functions in the file, the rest average 26); `enemy_ai.rs::run_enemy_ai` 1,121; `melee.rs::apply_attacks` 988; `looting.rs::apply_loot_intents` 848; `trading.rs::apply_trade_intents` 656; `intake.rs::route_outcome` 628 |
| Runtime | `world health`: median tick 0.5 to 0.8 ms, worst 13.3 ms, budget 50 ms (2026-11-02, two seats); `over_budget=0` |
| Allocation smell, unmeasured | `.clone()` 56 times in `handlers.rs`, 45 in `inventory.rs`; the obstacle rule's lookups allocate per pass (flagged at the build) |

## 3. Object orientation, honestly

**Client.** Fifty autoloads is a service-locator architecture: any script can reach any
system by name. The upside is what made the pace of the last six weeks possible (a feature
touches the systems it needs and nothing has to be threaded through constructors). The cost
is that coupling is invisible: `hud.gd` reaches 26 systems, `Targeting` calls into 14, and
the direct-call count (782) is half again the connect count (500), where the project's own
style rule says "prefer signals for cross-scene communication". Nothing here is wrong for a
game of this size; it is simply not OO, and turning it into OO (a class per system, injected
dependencies) would be building for its own sake. Where inheritance earns its keep it is
used: `DraggablePanel` under 22 windows gave every window the same drag, raise and click
behaviour in one place (the window-click fix of 10-29 landed once, for all of them). The
three remote entity scripts and their five managers are the one place inheritance is
*missing* and the duplication shows it (§2).

**Server.** The tick is deliberately not OO: `WorldState` is the data, each step is a
function over it, and rules live as free functions in named modules (`cast_rules`,
`skills`, `obstacles`, `fall`). That is the idiom Rust rewards (borrowing a struct's fields
separately is easy; a web of objects holding references to each other is not), it is what
makes the harness testable (a test is a client talking to a real world), and the lint set
keeps it honest. The one OO structure the server does have, `Entity` with its state
machine, is where four sessions' rules now meet (the cross-over audit's seam C) and it held.

## 4. Bloat, honestly

**Where it is.**

1. **Four server functions of 1,000 to 1,950 lines.** `apply_casts` is one `match` over
   the spell's target type with every arm's body inline; `handle_message` the same over
   the wire message; `run_enemy_ai` the whole AI sweep; `apply_attacks` the whole swing.
   The tick split of 11-01 was "moves only, checked line by line", so these came through
   intact. They are correct and tested; what they cost is reading. Every audit, review and
   feature in them means holding a 2,000-line function in one's head, and the night's
   cross-over read spent most of its time in exactly these four.
2. **The client builds its UI in code.** 129 build functions, 141 `Label.new()`, 178 colour
   overrides, 53 `StyleBoxFlat.new()`. This is where most of the client's size is, and why
   `hud.gd` is 1,860 lines and every window script is 400 to 700. The code style rule
   already says "prefer `.tscn` scenes over imperative `_build_xxx()` UI in new HUD work";
   the existing windows predate it.
3. **One dispatcher.** `_handle_chat_input` is 475 lines of `if lower == "/x"`. It works,
   nothing is swallowed (the audit checked), and every new command adds another branch.
4. **25 dead functions** (git keeps them; the rule is no dead code) and about a dozen
   duplicated bodies across the remote entity scripts and managers.

**Where it is not.** The autoload count is not bloat (each has one job; the user's rule of
"split on responsibility" produced them). The data files as `const` literals are fine at
this size and are lockstep-checked. The 7,100 lines of tools are the safety net, not bloat.
The `gdext-net` crate in one 3,500-line file is a thin bridge (one signal and one function
per message) and splitting it would gain nothing. The 39 dependencies are lean. The
dependency on `CombatLog.add_line` (169 call sites) is a chat sink, not coupling.

## 5. Recommendations, ranked, each with its moment

The project's own rule applies: clean what you are already touching; never refactor under
cover of a feature; a real restructuring is its own small task. None of these is urgent and
none is a friends-build item.

| # | What | When | Size | Why it pays |
|---|---|---|---|---|
| R1 | **Delete the 25 dead functions** after a glance at each (`Languages.hear_language` is the hook the open language item names; deleting it loses nothing, git has it, and the item's text already says it is not called). **DONE 2026-11-18** (one commit on the deploy branch; `session_2026_11_18_r1_dead_code.md`): 24 deleted with what only they used (the `SlotRef` and `Vec3` helper constants, crafting's XP constants and map, the `quest_failed` and `skill_improved` signals, the floating XP number's options checkbox and setting, and the whole `MobileCharacter` script, whose two subclasses left with the offline code). `DebugLog.combat` kept: a documented log level the console colours, not dead in the same sense. All 19 checks and 24 probes green after. | Any quiet hour; one commit. | Small | No dead code is the rule; a dead wire send (`broadcast_split_stack`) is a trap for the next reader. |
| R2 | **`apply_casts` into one function per target-type arm** (`cast_enemy`, `cast_ally`, `cast_pet_charm`, ...), same file, moves only, the pre-flight's `ResolvedTarget` already the seam. Then `handle_message` by message family the same way. | One function per sitting, as its own commit, BEFORE the next feature in that file (the next spell work; the next wire bump). | A few hours each | The next spell feature and every review of one gets a 200-line read instead of 1,950. |
| R3 | **A `RemoteEntityManager` base** under the five `remote_*_manager.gd` (and a `RemoteEntity` base under the three remote scripts), lifting the identical bodies. | When the remote animation-state channel (the jump relay's successor) next touches them. | Half a day | Removes about a dozen copies; the next per-entity message lands once. |
| R4 | **`_handle_chat_input` as a command table** (`Dictionary` of name to Callable, each command its own small function). | The next time a command is added. | An hour | 475 lines become a table and twenty short functions; the audit's "does a prefix swallow" question becomes a lookup. |
| R5 | **New windows as `.tscn`, existing ones left alone** until the deferred UI theming pass, which is the one moment converting them earns its cost. | The theming pass. | Per window | Already the rule; stated here so nobody converts a working window on its own. |
| R6 | **Measure before touching allocations.** A `tracing` span count or a `perf` run on the R720 under two seats before any `.clone()` hunt. | Only if the `world health` line ever shows `over_budget` or the median climbs past a few ms. | Small to measure | The tick runs at 1 to 2% of its budget; there is nothing to win today. |

## 6. Not worth doing

- An ECS, a dependency-injection container, or a class hierarchy for the autoloads. The
  service-locator shape is why fifty systems could be built in six months; making it OO
  would cost weeks and buy a diagram.
- Splitting autoloads or files to hit a count. `net.gd` at 1,487 lines is one signal
  handler per wire message; `handlers.rs` at 4,093 is 83 functions averaging 26 lines plus
  the one giant (R2).
- Splitting `gdext-net/src/lib.rs`.
- Converting data files to resources. The `.tres` route exists for items because the
  editor edits them; the rest are tables that the lockstep checks read as code.
- Any of the above before the door on Thursday.

## 7. Method and limits

Counts are from regex over the source (comments stripped, strings blanked), not a parser;
the function-length numbers run from one `func`/`fn` line to the next, so a nested closure
or a test module inflates the enclosing function in a few cases (the four server giants
were confirmed by reading their files' function lists). The dead-function sweep matches
names, so a function sharing a name with a live one elsewhere is not listed: 25 is a floor.
No runtime profile was taken; the efficiency reading rests on the `world health` line.
