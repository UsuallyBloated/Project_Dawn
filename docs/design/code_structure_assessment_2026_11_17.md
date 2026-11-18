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
| Duplicated bodies | the five `remote_*_manager.gd` share `clear_all` (all five) and, three of them, `get_by_id` and `_scene_hosts_local_player` (identical, with a parameter none uses); their `_instantiate_into` bodies are five different builds, not copies (corrected 2026-11-18); `remote_enemy.gd` and `remote_pet.gd` share `_physics_process` (23 lines) and `_process`; `on_position_update`, `apply_buff_snapshot`, `get_spell_resist` identical across the three remote entity scripts; coin formatting in three places (`Currency.format_coins`, `trade_window._coin_text`, `vendor_window._coins_text`) |
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
| R1 | **Delete the 25 dead functions** after a glance at each (`Languages.hear_language` is the hook the open language item names; deleting it loses nothing, git has it, and the item's text already says it is not called). **DONE 2026-11-18** (two commits on the deploy branch; `session_2026_11_18_r1_dead_code.md`): 20 deleted with what only they used (the `SlotRef` and `Vec3` helper constants, crafting's XP constants and map, and the whole `MobileCharacter` script, whose two subclasses left with the offline code). Five kept on the user's read of the list: `DebugLog.combat` (a documented log level the console colours), the three `Languages` functions (unfinished, not dead: the wiring item), and `fail_quest` (for the failable quests to come), each with a comment saying so. The floating XP number, whose options checkbox existed and did nothing, was wired to `xp_gained` instead of deleted (off by default). All 19 checks and 24 probes green after. The lesson for the next sweep: "defined, never called" is the lower bound; a function waiting on an unbuilt feature is unfinished, and the glance is for telling the two apart. | Any quiet hour; one commit. | Small | No dead code is the rule; a dead wire send (`broadcast_split_stack`) is a trap for the next reader. |
| R2 | **`apply_casts` into one function per target-type arm** (`cast_enemy`, `cast_ally`, `cast_pet_charm`, ...), same file, moves only, the pre-flight's `ResolvedTarget` already the seam. ~~Then `handle_message` by message family the same way.~~ **DONE 2026-11-18 (section 8.5; server `09b03ff` to `2ddfe7b`, eleven commits, each token-compared and suite-green).** **Re-analyzed 2026-11-18 (section 8): the cast half stands, about a day, the 580-line prelude untouched, a `CastContext` lent to each arm, biggest arm first, after the door and in a window with no branch on the file. The handler half is dropped: its 1,930 lines are 77 arms averaging 25, a family split buys nothing to read and conflicts with `feat/public-hosting`; its four arms over 80 lines move out when next touched, and the three dead wire intents come off at the next bump.** | One function per sitting, as its own commit, in a quiet window after the door, before the next spell feature. | About a day | The next spell feature and every review of one gets a 200-line read instead of 1,950. |
| R3 | **A `RemoteEntityManager` base** under the five `remote_*_manager.gd` (and a `RemoteEntity` base under the three remote scripts), lifting the identical bodies. **Re-read 2026-11-18 (user: "Are we ready with R3?"): the §2 row overstated the sharing.** `_instantiate_into` is five different bodies (11 to 30 lines, each building its own scene); what is identical is `clear_all` (7 lines, all five, a local's name apart), `get_by_id` (3 lines, three files) and `_scene_hosts_local_player` (3 lines, three files, a 5-line variant in the player manager): about 13 lines a file. A base class for that alone is §6's building for its own sake. **Stays parked at its moment**, and becomes a half-hour inside the animation-channel work rather than a task. | When the remote animation-state channel (the jump relay's successor) next touches them. | Half an hour, inside that work | The next per-entity message lands once. |
| R4 | **`_handle_chat_input` as a command table** (`Dictionary` of name to Callable, each command its own small function). **DONE 2026-11-18 (section 10.5; client `1cc2088` to `13b795a` and the check's last commit, six commits).** **Re-analyzed 2026-11-18 (section 10): stands, reshaped.** It is 40 arms averaging 9 lines, so the gain is not length; it is that a string if-chain has no compiler and no test, and it shows: about ten unreachable lines since the sticky channel, five commands answering their bare form wrong, eight autoloads the HUD reaches only for commands. A probe first, then the dispatcher out of `hud.gd` into the HUD family, then two lookup tables with the bodies moved verbatim, then five listed changes as their own commit. | The next time a command is added (`/fly` is written and waiting on `feat/gm-flight`), or now on the user's call. | Half a day, not an hour | 475 lines become a table and twenty short functions; the audit's "does a prefix swallow" question becomes a lookup. |
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

## 8. R2 re-analyzed after R1 (2026-11-18)

The user, before starting R2: "can we re-analyze the plan for R2 knowing what we learned
from R1?" R1's lesson was that a measurement produces candidates, not verdicts: "no callers"
listed five functions the project had made for a reason. R2's measurement is "two functions
of 1,900 lines". This section reads the two functions for the reasons they have that shape,
who else has them open, and what holds them, before anything moves.

### 8.1 What the two functions actually are

**`apply_casts` (casting.rs, 1,952 lines, the file's only function)** is a per-cast
pipeline with the arms at its end:

| Part | Lines | What it is |
|---|---|---|
| The per-cast prelude | about 580 (lines 33 to 580) | Every gate in the order the audits fixed: a corpse casts nothing; class and level; the memorized bar; the cast-time gate; the per-spell cooldown; mana; the alignment off-side copy of the spell; `cast_target_refusal` (presence, reach, liveness, the PvP gates, one home since 10-14); the instant-cast fizzle; THEN the mana and HP come off, the cooldown is stamped, a hostile cast ends Hide, the casting skill advances, a song starts. |
| The `match` on the target type | about 1,370 | Eleven arms: ENEMY 401, PORT about 200, ALLY 155, AOE 94, SUMMON_ITEM 91, SELF 80, PET_SUMMON 72, PET_CHARM 67, BIND 56, CORPSE 44, PET_HEAL 39. |

The prelude's ORDER is the security property ("a refusal costs nothing": every check before
anything is spent). The arms only apply. The 10-14 refactor that collapsed the arms' private
copies of the checks into the pre-flight is why the arms are safe to move and the prelude is
not: the one choke point the audits lean on must stay one body. So the shape has a reason,
and the reason covers 580 of the 1,952 lines. The other 1,370 are eleven bodies inline
because Rust makes extraction a chore, not because anything binds them: each arm reads about
fourteen prelude locals (`caster_cid`, `caster_pos`, `mana_cost`, `hp_cost`, `dmg_type`,
`caster_int`, `resolved`, the penalised `spell`, `new_mp`, `discipline`, ...) plus the eight
`WorldState` fields the function destructures and `in_world_recipients_now`. Moving an arm
means either a function of twenty-odd parameters (the crate allows `too_many_arguments`; 19
sites do it already) or a `CastContext` struct built once per cast and lent to the arm. Either
works; neither is a one-line change.

**`handle_message` (handlers.rs, 1,930 lines)** is a different animal, and the measurement
misled here the way "no callers" did in R1. It is a 99-line prelude (the kicked gate, the
dead-state whitelist) and then 77 arms, one per client message, whose sizes are:

| Arm | Lines |
|---|---|
| `CastStartBroadcast` | 126 |
| `DevSpawnMob` | 110 |
| `Move` | 99 |
| `GmCommand` | 88 |
| `UseSkill`, `CastSpell`, `BindAtCurrentLocation`, `DevSetFaction`, `GiveCoins`, `Respawn` | 49 to 55 |
| The other 67 | under 40, most under 25 |

It is long because the protocol has 77 messages, not because the arms are entangled. A split
"by message family" would turn one 1,930-line function into eight 250-line ones that each
still read as a list of small arms: the per-arm read is already 25 lines. The reading cost the
assessment counted is real only for the four arms over 80 lines, and one of those
(`CastStartBroadcast`) is the relay the 10-30 cast-relay hardening wrote, read twice since.

### 8.2 Who else has the files open

| File | Unmerged edits on a branch | What that means for a split |
|---|---|---|
| `casting.rs` | None. | Free to move now. |
| `handlers.rs` | `feat/public-hosting`: +140 lines (the intent budgets, `intent_class`'s exhaustive match, the GM command bucket), already 19 commits behind the deploy branch. | A split of `handle_message` before the hosting merge-forward puts a conflict in the repo's biggest function on the branch the cutover depends on. The merge-forward goes first, whatever else is decided. |

Churn: `handlers.rs` has 49 commits in 45 days, the cast path 96. The R2 row's moment,
"BEFORE the next feature in that file", names a moving target: there is always a next
feature in these two (Sneak, Stone Skin, target-of-target heals, the per-spell DoT resist
and group songs all land in `casting.rs`; every new intent lands in `handlers.rs`). The real
condition is a quiet window with no open branch touching the file, which is neither the
door (2026-11-19) nor the bump after it.

### 8.3 What holds them

- `apply_casts`: 219 world tests, 192 cast sends across 12 of the test files (`spells.rs`,
  `songs.rs`, `pets.rs`, `death.rs`, `height.rs`, `obstacles.rs`, ...), every exploit the
  audits closed pinned by a test that fails on the old code. **No fuzz target reaches it**:
  the seeded soak and both `cargo-fuzz` targets stop at `handle_message` (a cast is queued as
  an intent and applied by the tick, which the soak does not run).
- `handle_message`: the same suite, the 20,000-message seeded soak in every `cargo test`, the
  two `cargo-fuzz` targets (`decode_and_handle`, `handle_arbitrary`), and invariants S4 and X2
  name it by function.

So a cast split's only net is the suite, and the tick split's standard applies in full:
moves only, every arm's body and its comments verbatim (the project keeps its history
comments; cleaning them up while moving is the mixed-purpose diff the touch-hygiene rule
forbids), the diff read with `git diff --color-moved` so a moved block shows as a move and a
changed line shows as a change, the suite green after every arm, and a run of the twelve
spell test files three times at the end (the flaky rule: a failure that passes alone is load
sensitivity, one that fails alone has a cause).

### 8.4 The re-ranked recommendation

1. **`apply_casts`: yes, as a deliberate pass, in a quiet window after the door and before the
   next spell feature.** The arms are big, nothing binds them, no branch has the file open, and
   the spell queue is long enough that the read is paid back several times. Shape: a
   `CastContext` (the prelude's locals, built once per cast) lent to one `fn cast_<arm>` per
   target type in the same file, the prelude untouched, one arm per commit, biggest first so
   the shape is proven on ENEMY (its PvP half and its mob half are the two 200-line reads
   inside it, and may be two functions). About a day, not "a few hours".
2. **`handle_message`: drop the family split.** The length is 77 small arms; a split buys a
   file layout, not a shorter read, and costs a conflict with the hosting branch. Instead: the
   four arms over 80 lines move out to their own functions WHEN each is next touched (the
   touch-hygiene rule), and `StackAll`, `TurnInQuest` and `CancelCast`, declared on the wire
   with no handler since 08-24, come off the protocol at the next bump (the R1 lesson's other
   half: that one IS dead, and has been recorded as deletable for three months). After the
   hosting merge-forward in every case.
3. **Nothing in either function is deleted by R2.** The R1 trap (a stub for a planned feature
   read as dead) has no purchase on a pure move; the trap here is the opposite one, a line
   changed under cover of a move. `--color-moved` and the per-arm commits are the guard.
4. **Say before doing, per arm:** the `CastContext` shape goes in front of the user before the
   first commit, since it is the one design choice in the pass.

The R2 row in section 5 is amended to point here.

### 8.5 Built (2026-11-18, the same day; user: "Lets go ahead with R2")

The cast half as 8.4 says, on the server deploy branch, `09b03ff` to `2ddfe7b` plus the
header commit: a Copy `CastContext` (what the prelude decided: the intent, the spell as
cast, the resolved target, the caster's id, position and INT, the costs, the damage type,
the clock and the audience) and a `CastWorld` (the `WorldState` fields the arms borrow,
reborrowed per cast), each arm a `cast_<type>` function taking both by value and
destructuring what it uses. Eleven commits, biggest first (ENEMY 401, PORT 178, ALLY 155,
AOE 94, SUMMON_ITEM 91, SELF 80, PET_SUMMON 72, PET_CHARM 67, BIND 56, CORPSE 44, PET_HEAL
39, the default 32), each body extracted by a script from its line range (never retyped) and
then compared with the original with whitespace, commas and braces removed: every one
token-identical, the only differences the arm-level `continue`s that are `return`s in a
function (and one trailing `continue` at the end of SUMMON_ITEM's body, a needless `return`
clippy asks to drop). The context structs grew a field only when an arm read it; `max_hp`
and `side`, which the name count had suggested, turned out to be an arm's own local and a
word in a comment. `apply_casts` is 672 lines now, all prelude and the twelve-line match.
The suite ran green after every commit (481 unit, 201 world, clippy and fmt clean); one run
found a fourth flaky roam test, which passed alone and got the sibling's 60 m region
(`d003fd2`, test code only). No behaviour change; no redeploy needed (it rides the next one).


## 9. R3 re-analyzed the same way (2026-11-18)

The user: "Lets review R3 the way R2 was and then proceed with R3." The row named two bases,
a `RemoteEntityManager` under the five managers and a `RemoteEntity` under the three remote
entity scripts, "lifting the identical bodies". Read function by function, with each body
hashed after trailing-whitespace removal:

### 9.1 What the eight files actually share

**The three entity scripts** (`remote_player.gd` 348 lines, `remote_enemy.gd` 210,
`remote_pet.gd` 243; all `extends CharacterBody3D`, each the root script of its scene):

| Shared | Where it is identical | Lines |
|---|---|---|
| The interpolation state: `BUFFER_CAPACITY` 5, `INTERP_LAG` 0.1, `_snapshots`, `_last_seq`, `is_dead` | all three | 5 declarations each |
| `on_position_update` (drop a stale sequence, ignore while dead, append a snapshot, cap the buffer) | all three (the player's has comments) | 9 |
| `_physics_process` (cold start on one snapshot, else find the pair straddling now minus the lag and lerp position and yaw) | enemy and pet identical; the player's is the same algorithm with comments and **one line less: on a cold start it sets the position but not the yaw** | 23 |
| The buff countdown: `buff_names`, `buff_durations`, `_BUFF_INF_SENTINEL`, the `buffs_changed` signal, and the `_process` that ticks the durations down | enemy and pet identical; the player's `_process` is the same loop between its jump advance and its cast-bar auto-end | 10 |
| `hp_changed(current, maximum)` and `died(self)` signals | all three (the `died` parameter is named peer, enemy and pet; every connection is by position) | 2 |

Not shared, and staying where it is: `apply_health_update`, `apply_buff_snapshot`,
`get_spell_resist`, `set_targeted`, `flash_spell_hit`, `apply_death` (each type's own
rules), the pet's allegiance tint, the player's casting, jump and mana and stamina bars.

**The five managers** (138 to 572 lines, all `extends Node`, each wired to its own set of
`Net` signals in `_ready`): `clear_all` identical in all five (7 lines, a local's name
apart); `get_by_id` identical in three (3 lines); `_scene_hosts_local_player` identical in
three with a trailing comment on the player's (3 lines). `_instantiate_into`, which the §2
row counted as shared, is five different builds (11 to 30 lines, each its own scene and
fields). About 13 lines a file.

So the sharing the row pointed at is mostly on the entity side, not the manager side: the
network interpolation rule (how a remote body is drawn 100 ms behind the server's stream,
the rule the 10-02 enemy-stream note reasons about) and the buff countdown exist three
times, byte for byte but for comments.

### 9.2 Who has the files open, and what holds them

No branch carries an unmerged edit to any of the eight (`feat/public-hosting` and
`feat/gm-flight` both clean on them); churn is low (12 manager commits and 4 entity commits
in 45 days). What exercises them headless: `check_nameplates.gd` instantiates all three
remote scenes (so a script that fails to load fails the check), `probe_swing_retime.gd` and
`probe_ammo_slot.gd` instantiate `remote_enemy.tscn`, `probe_fizzle_cooldown.gd` reaches the
player manager. **Nothing drives the interpolation or the buff countdown**: those have only
ever been verified in play (two seats). A base-class move with no net under the one
behaviour that matters would be the R2 split without its token compare.

### 9.3 The shape, re-ranked

1. **`RemoteEntity` (a `class_name`, `extends CharacterBody3D`) under the three entity
   scripts: yes, the real R3.** It carries the interpolation state and both of its functions,
   the buff countdown state, its signal and its `_process`, `is_dead`, and the two signals.
   Enemy and pet lose their copies outright. The player keeps its `_process` as jump advance,
   `super(delta)`, cast-bar auto-end, and loses its `_physics_process` and
   `on_position_update`. **One deliberate change rides it:** a remote player on a cold start
   (its first snapshot after entering view) takes the snapshot's yaw as the other two do,
   instead of facing the scene's default for the one tick until the second snapshot. The
   facing sheet's late-joiner row passed on the old behaviour because the second snapshot is
   50 ms behind; the unified one is the better of the two and is called out, not hidden.
2. **`RemoteEntityManager` (`extends Node`) under the five managers: yes, but the minor
   half.** `_by_id`, `_spawn_data`, `clear_all`, `get_by_id`, `_scene_hosts_local_player`.
   Its value is one home for the "does this scene host the local player" rule (a real rule
   with a four-line comment in four places), not the line count.
3. **A probe first, before anything moves:** `tools/probe_remote_interpolation.gd`, run
   against the three scenes as they are today: a cold start snaps to the one snapshot; two
   snapshots interpolate toward the newer and arrive; a stale sequence is dropped; a dead
   body takes no snapshot and does not move; a buff duration ticks down and emits, the
   infinite sentinel does not. The one check the old player fails is the cold-start yaw,
   item 1's deliberate change. Then the moves, compared token-wise as R2's were, the probe
   and all 19 checks green after each commit, one commit per base.
4. **Moment:** its stated one has not come, and the user has called it now; the cost is a
   few hours and the files are quiet, so nothing argues against it beyond the principle,
   which the user has weighed.

### 9.4 Built

Both bases, the same afternoon, two commits on the client deploy branch.

**`RemoteEntity`** (`scripts/remote_entity.gd`, 124 lines, `class_name`, `extends CharacterBody3D`; the three scripts `extends` it by path, which needs no class cache): the interpolation state and both of its functions, the buff countdown state, its signal and its `_process`, `is_dead`, `hp_changed` and `died(entity)`. The player keeps `_process` as `_advance_jump(delta)`, `super(delta)`, its cast-bar auto-end. Code-token compare (comments and whitespace removed): `on_position_update` identical to all three originals, the buff tick identical to enemy and pet, `_physics_process` identical to enemy and pet and one line apart from the player (the cold-start yaw, item 1 of 9.3). The probe written first against the old scripts (`tools/probe_remote_interpolation.gd`, 33 checks: 32 of 33 on the old code, the miss that yaw line) is 33 of 33 after. The four files 801 lines to 678.

**`RemoteEntityManager`** (`autoloads/remote_entity_manager.gd`, `extends Node`; the five managers extend it by path): `_spawn_data`, `_by_id`, `get_by_id`, `_scene_hosts_local_player`, `clear_all`, with the comments that sat above them in the player manager; the corpse and loot managers' spawn-dict shapes, which sat beside the deleted declarations, moved into their headers. Five files 88 lines out, 9 in; every removed line read and matched to a move. (`get_enemy` and `get_pet`, each a second name for `get_by_id` with callers, were left: a rename for another day.)

After each half: all 19 checks and all 25 probes green. No wire or server change; rides the next export. The one behaviour change is the cold-start yaw, called out above.

## 10. R4 re-analyzed the same way (2026-11-18)

The user: "Review R4 knowing what we learned R1, R2 and R3." The three lessons, applied in
order: R1, a measurement lists candidates and the user reads the list before anything is
deleted; R2, read the function for why it has its shape, who else has it open and what holds
it, and a long list of small arms is not a tangle; R3, the row's own description can be
wrong, so read body by body, and where nothing drives the behaviour a probe comes first.
Nothing was changed in code for this section. One throwaway headless read of the real
dispatcher (the real `hud.tscn`, 48 inputs, the lines each produced) backs every claim below
about what an input does today.

### 10.1 What the function actually is

`hud.gd::_handle_chat_input`, lines 1368 to 1842, 475 lines:

| Part | Lines | What it is |
|---|---|---|
| The prelude | 11 | The sender's name; `ChatChannel.normalize` (the sticky channel's one canonical form for every line); an empty line returns; the lowered copy. |
| The arms | 377 of code, 98 of comment | 40 top-level `if` blocks, each ending in `return`, then "Unknown command". Mean 9.4 code lines; 27 of the 40 are ten lines or fewer. The biggest: `/give` 32, `/testpanel` 32, `/loc` 24, `/con` 23, `/ping` 17, `/r` 15, `/invite` 15, `/loot` 13. |

44 command words in all (aliases counted). The arms share three locals (`text`, `lower`,
`my_name`) and nothing else; no arm reads what another wrote, and no order is load-bearing
(the only two prefixes tested without a trailing space are `/loot` and `/items`, and no other
command begins with either). So this is `handle_message`'s shape, not `apply_casts`'s: long
because there are forty commands. **The row's numbers were off in the same direction R3's
were:** "twenty short functions" is forty; "475 lines become a table" does not shorten
anything (forty signatures and about sixty table rows go in); "an hour" is half a day once it
has a net.

By R2's reading alone that is the case for dropping it, as the handler's family split was
dropped. Three things make it different from the handler:

1. **Nothing holds a string if-chain.** The server's handler is a `match` on an enum: the
   compiler refuses a missing arm and an arm cannot shadow another. This is forty string
   tests in sequence that nothing checks, and it has drifted (10.2).
2. **Nothing tests it.** `handle_message` has the suite, the 20,000-message soak and two fuzz
   targets. `_handle_chat_input` is driven by no check and no probe: `probe_chat_channel.gd`
   holds `ChatChannel` and the chat line and only listens on `chat_submitted`;
   `check_window_click_blocking.gd` loads the real `hud.tscn`, so a parse error fails
   `check_all` and nothing more.
3. **It is the busiest quarter of the most overgrown client file.** 10 of `hud.gd`'s 20
   commits in 45 days touched these lines; five commands arrived in that time (`/ping`,
   `/stopsong`, `/con`, `/factions`, `/loc raw`) and a sixth is written (`/fly`). Eight of the
   26 autoloads `hud.gd` reaches, it reaches only from here (`GroupManager`, `PetManager`,
   `Languages`, `Alignment`, `ItemRegistry`, `SenseHeading`, `ChatWindowManager`,
   `BardSongs`).

### 10.2 What the read found (R1's lesson: candidates, each verified, the user reads the list)

The sticky channel (10-25) put `ChatChannel.normalize` in front of the dispatcher. Since then
the dispatcher only ever sees a channel line in its one canonical form (`/say`, `/shout`,
`/ooc`, `/g`, `/tell Name`), and parts of it can no longer be reached:

| Finding | Evidence (the headless read) | Kind |
|---|---|---|
| The alias checks `/s `, `/sh `, `/group ` and `/t ` in the dispatcher never match. | `/s hi` arrives as `/say hi`, `/sh hi` as `/shout hi`, `/group hi` and `/gsay hi` as `/g hi`, `/t Bob hi` as `/tell Bob hi`. The aliases live in `ChatChannel.COMMANDS`. | Unreachable |
| The `/r` arm's send half and its "reopen the line addressed to them" half never run. | With a sender on file, `/r hi` arrives as `/tell Ann hi` and a bare `/r` as an empty line (nothing sent; the chat line itself stays on `[Tell: Ann]`, which is the sticky channel doing the reopen's job). The only reachable part is "No one has sent you a tell yet." | Unreachable, superseded (not waiting on a feature) |
| The `/tell` usage line never prints. | `/tell Bob` arrives empty; a bare `/tell` falls to "Unknown command: /tell". | Unreachable today |
| Five commands answer their bare form with "Unknown command" although each has a usage line written: `/give`, `/lang`, `/kick`, `/damage`, `/heal`. | Each is tested as `begins_with("/x ")` and the line arrives trimmed. `/invite`, `/items` and `/loot` handle their bare form. | A small wart, visible to players |
| `/itemsfoo` lists items matching "foo". | `begins_with("/items")` with no space. | A quirk |
| Four comments contradict the code under them. | `/give`: "inventory authority is client-only today ... should gate on is_gm" above the line that sends the server's GM command; `/damage` and `/heal`: waiting on a CastSpell port that landed long ago; `/console`: the F2 key (it is backtick). | Comment debt |
| Eight sprint labels ("Track 6 sub-task 3", "Camp slice B", "Round-7B", ...). | The code style rule: none in code. | Comment debt |

**Kept as they are, on purpose** (the R1 list, so it is read before anything moves):
`/languages` and `/lang` (the language system is unfinished, the user's 11-18 call),
`/damage`, `/heal`, `/give`, `/items`, `/testpanel`, `/console` (dev tools, server-gated
where they act), `/pvp` (a player toggle by the 11-02 call), `/track`. Also outside R4: a
message that begins with a slash runs as a command instead of being sent (`/tell Bob /loot`
runs `/loot`); that is `ChatChannel`'s stated rule, not the dispatcher's.

The docs are in step: `commands.md` section 3 names every command word the dispatcher
handles (compared by script; `/gsay`, which `ChatChannel` accepts, is the one word not
listed). No drift to fix there.

### 10.3 Who else has the file open, and what holds it

| | |
|---|---|
| Open branches on `hud.gd` | One: `feat/gm-flight` (16 commits behind), +43 lines, 22 of them a `/fly` arm inside this function. Its client half merges at the bump after the door. If R4 lands first, that hunk has no home and `/fly` is re-added by hand as one function and its table keys (ten minutes, and it must be written down where the flight merge will see it). `feat/public-hosting` does not touch the file. |
| The stated moment | "The next time a command is added": that is the `/fly` merge. A command a week has arrived for six weeks, so, as with R2, the moment is always near and never quiet. |
| The net today | None for the dispatcher (10.1). |
| Exploit surface | None. Every arm either prints from local state or asks the server, which gates the request itself; nothing a command decides is trusted. A regression here breaks a command for an honest player, it cannot grant one to a dishonest one. |
| The door | The door zip is `a1a154e` and stays that. Like R1 and R3 this is client only and rides the next export, which wants a sitting with the commands before it goes to anyone. |

### 10.4 The shape, re-ranked

1. **A probe first** (R3's lesson): `tools/probe_chat_commands.gd`, written against the
   dispatcher as it is today. The real `hud.tscn`, a stub body in the `player` group, a
   recorder on `CombatLog.line_added`; about 120 inputs (every command's plain form, every
   alias, the bare forms, trailing words, mixed case, the channel forms) with the lines each
   must produce, and for the silent arms that no "Unknown command" follows. The throwaway
   read proved it stands up and runs in seconds. It passes whole on the old code; every later
   step leaves it green except the rows 4 changes on purpose.
2. **The dispatcher out of `hud.gd`**, into `scripts/hud_chat_commands.gd`, a Node the HUD
   builds with the rest of its family (`hud_cast_bar.gd`, `hud_group_panel.gd`, ...) and that
   answers `CombatLog.chat_submitted` itself. With it go `_send_tell`, `_loc_number` and
   `_npc_display_name`; `_inspect_player` stays (the right-click path uses it). The HUD hands
   it four things once: the body, the debug console, the track window, and the inspect call.
   Moves only, compared token by token as R2's arms were. `hud.gd` 1,860 lines to about
   1,370, and 26 systems reached to 18. This is the style rule's own example (the `hud_*.gd`
   family), and it is what keeps forty new functions from making `hud.gd` 1,950 lines.
3. **Two lookup tables, the bodies verbatim.** `_exact`: the whole lowered line to a
   Callable (`/sit`, `/camp cancel`, `/pet follow`, `/loc raw`, `/pvp off`, ...). `_with_args`:
   the first word to a Callable, for the commands that take a name, a message or a number
   (`/say`, `/tell`, `/give`, `/kick`, ...). Dispatch: normalize; the whole line in `_exact`;
   else its first word in `_with_args`; else "Unknown command". That reproduces today's
   matching exactly (an exact command with a trailing word stays unknown), so every arm's body
   moves into `func _cmd_<name>(text, lower)` unchanged but for one indent: the arms already
   end in `return`, so there is not even R2's `continue` to rewrite. An alias is a second key
   on the same Callable; a key cannot appear twice in a table, so nothing can shadow.
4. **The deliberate changes, their own commit, each a probe row that flips** (the list the
   user reads first):
   - the four alias checks and the `/r` arm's two unreachable halves deleted (about ten
     lines);
   - bare `/give`, `/lang`, `/kick`, `/damage`, `/heal` and `/tell` print their usage line;
   - `/itemsfoo` is an unknown command;
   - the four stale comments corrected and the eight sprint labels removed.
5. **Not now:** a check holding `commands.md` to the tables (the docs are in step by hand
   today; add it the day a command ships undocumented), and a `/help` command (nobody asked).

**The one design choice** (R2's rule: it goes in front of the user before the first
commit): the dispatcher's new home and the handler signature in item 2 and 3, a Node in the
HUD family with two tables and every handler `(text, lower)`. The cheaper variants are the
tables in place inside `hud.gd` (skip item 2: an hour less, `hud.gd` grows to about 1,950
lines) or the probe and item 4 alone (about three hours, the if-chain stays).

**Size and moment:** about half a day (the probe two hours, the move one, the tables an hour
and a half, the listed changes half an hour), one commit per item, all 19 checks and the
probes green after each. It can go now: no server or wire change, no redeploy, nothing for
the door. The cost of going before the flight merge is the `/fly` re-add above.

### 10.5 Built (2026-11-18, the same day; user: "Stick with the full shape, as you recommended. Go ahead.")

On the client deploy branch, one commit per item, the command check, all checks and all
probes run green after each:

1. **The probe first** (`1cc2088`): the real `hud.tscn`, a stub body in the `player` group,
   each line typed in where a player's goes (`CombatLog.chat_submitted`) and the lines the
   game prints back compared with a table. 144 checks, all passing on `hud.gd` as it stood;
   two planted faults (a renamed command, a dropped alias) each failed it.
2. **The move** (`7542359`): the dispatcher, `_send_tell`, `_loc_number` and
   `_npc_display_name` cut out of `hud.gd` by script into `scripts/hud_chat_commands.gd`, a
   Node the HUD builds with its family and that answers `chat_submitted` itself. Token for
   token identical to the originals but for the inspect call, a Callable in its new home;
   every line that left or entered either file listed and accounted for. `hud.gd` 1,860
   lines to 1,363; the eight autoloads it reached only for commands are no longer its
   business. `probe_factions.gd` calls the NPC-name helper where it now lives.
3. **The tables** (`7eeed82`): forty `_cmd_<name>(text, lower)` functions and two
   dictionaries, `_exact` (the whole lowered line, 50 keys) and `_with_args` (the first
   word, 18). Generated by script from the committed dispatcher, every body cut from its
   line range and dedented, never retyped; the generator refuses to write unless each
   function's tokens equal its arm's (apart from the arm's closing `return`, dropped in 35,
   and the sender's name, which the four channel commands now ask for themselves) and the
   hand-written tables hold exactly the command words read out of the old conditions. No
   probe row changed. Two more planted faults (a dropped key, a key on the wrong function)
   each failed it.
4. **The listed changes** (`710c040`), each a probe row that flips (eight rows): bare
   `/give`, `/lang`, `/kick`, `/damage`, `/heal`, `/tell` and `/t` print their usage (a
   first-word command is found with or without anything after it); `/itemsfoo` is no
   command; the `/s`, `/sh` and `/group` alias checks and the `/r` command's two unreachable
   halves deleted; four stale comments corrected and eight sprint labels removed.
   `commands.md` says what a bare `/r` does since the sticky channel, and lists `/gsay`.
5. **The review pass** (`13b795a`, `/code-review` at medium: eight findings, seven fixed, one
   recorded). The probe became `tools/check_chat_commands.gd`, so `check_all.ps1` runs it
   (20 checks): the review's point was that a net nobody runs is not one. It now also fails
   on a command in the tables with no row and on a word in both tables (each proven on a
   planted fault; the "shadowed" check it replaced tested a harmless direction). Nine
   comments and docs that still named `hud.gd` as the command handler corrected. A tell is
   sliced at its first space, so the `/t` key cannot mis-slice whatever arrives. `/loot`
   reports and `/loot <mode>` sets, as two functions. The console toggle and its line live
   once, in `hud.gd`, shared by the backtick key and `/console`. The flight handoff says
   where `feat/gm-flight`'s `/fly` arm goes at its merge.
6. **The inspect wiring** (the last commit): the check targets a stub remote player and
   types `/inspect` in reach and out of it, so every piece the HUD hands the commands (the
   body, the console toggle, the track window, the inspect call) is exercised. 151 checks.

After: `hud.gd` 1,370 lines, `hud_chat_commands.gd` 571 (41 command functions), the
check 469. No server or wire change; it rides the next export. The door zip
(`a1a154e`) is untouched.

**Found and not changed (the user's calls):**
- `/kick`, `/invite`, `/pvp` and `/autosplit` print a success line the moment they send,
  before the server has answered (`/kick Nobody` as leader prints "Kicked Nobody from the
  group."). The vendor window had the same fault and was changed on 2026-08-24 to describe
  the request, never the outcome. Older than R4, and the check pins today's wording, so
  the rows move when the wording does. A To-Do entry under UI polish. **Answered the same
  day** (user: "Can you change the success lines to send at the correct time?"): built on
  `feat/command-confirm` in both repos, the server saying each line when it has done the
  thing; the To-Do entry has it.
- `ChatWindowManager.show_chat_input(prefill)`: the `/r` reopen half was the only caller
  that passed a prefill. The parameter has no caller now; left in place (the R1 rule: a
  candidate, not a verdict).

**What the check cannot see:** what a command sends to the server (it has no world
connection). Those lines moved token for token, so the next sitting's ordinary use of the
commands is their evidence; nothing here wants a sheet of its own.
