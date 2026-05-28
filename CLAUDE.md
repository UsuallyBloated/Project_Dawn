# Project notes

note for claude:  I will add play testing notes to the docs\playtest_notes\  Please have a look.  if this can be organized better, you're welcome to move it after i make additions.

You're doing a great job, Claude.  Thanks for the hard work!

## Engine
- Godot 4.3 (or whatever version you're on)
- GDScript only, no C#
- Targeting desktop (Windows/Mac/Linux)

## Project structure
- scenes/ — all .tscn scene files
- scripts/ — standalone .gd scripts not tied to a scene
- autoloads/ — singleton scripts registered in project.godot
- assets/ — game-ready art and audio (imported by Godot)
  - models/ — .glb / .gltf 3D models (characters, creatures, props, environment, weapons, armor)
  - textures/ — 2D textures for 3D models (characters, creatures, props, environment, ui)
  - materials/ — .tres material resources
  - sprites/ — 2D sprites (ui, icons/spells, icons/items)
  - fonts/ — .ttf / .otf
  - audio/ — .ogg / .wav (sfx, music, ambient, voice)
- ../Project_Dawn_Source/ — sibling folder for raw source files (.blend, .psd, .kra); NOT inside the Godot project to keep the import database lean. Export game-ready files into assets/ when ready.

## Code style

These are cheap rules — they apply to new code (or code we're already touching for another reason). They are not a mandate to stop and refactor existing files.

### Naming & structure
- Use snake_case for variables and functions (GDScript standard)
- Use PascalCase for class_name declarations
- Prefer signals over direct node references for cross-scene communication
- Use type hints on function signatures and exported vars (`func foo(x: int) -> bool:`, `var hp: int = 100`). Catches mistakes the editor can flag immediately instead of at runtime.

### File and function shape
- ~500–600 lines is the "ask yourself" threshold, not a hard cap. When a file crosses it, the question is "does this still have one responsibility?" — not "split it now." For reference, autoloads like `PetManager`→`WarderAI` and `PlayerStats`→`Alignment` were extracted when one autoload started owning two unrelated concerns. Follow the same pattern.
- `scripts/test_panel.gd` is a debug tool, not a feature drawer. It should only *invoke* systems (call public methods on autoloads), never contain gameplay logic. If logic accumulates there, it belongs in the system it's testing.

### Comments
- Do not put sprint labels (e.g. "Track 17.1 —", "Track 22.E —") in code comments. Keep the *content* of the comment — the *why* — but drop the label. Sprint context belongs in `docs/session_notes/`, not in source, because the label rots the moment the sprint ends.
- Only write a comment when the *why* is non-obvious: a hidden constraint, a workaround for a specific bug, a subtle invariant, behavior that would surprise a reader. Don't explain *what* the code does — good names should already do that.
- No commented-out code. If we delete it, delete it. Git history is the archive.

### UI
- Prefer `.tscn` scenes over `_build_xxx()` imperative UI construction in new HUD work. Scenes are easier to tweak visually and easier for a future contributor (or designer) to read than long chains of `Label.new()` + `add_theme_color_override()` calls.

### Constants and helpers
- Magic numbers and strings live at the top of the file as named constants. [autoloads/combat.gd](autoloads/combat.gd) is the reference — match it. This includes group names (e.g. `"enemies"`), asset path templates, and small string transforms.
- Inline string-munging like the portrait slugify in `hud.gd` (`race.to_lower().replace(" ", "_")...`) should be a small named helper, not buried in a UI method. Helpers make intent obvious and are reusable.

### Touch hygiene
- Leave a file cleaner than you found it. When editing for a feature, do small in-place cleanups: drop a dead branch, rename a confusing local, extract a constant. Don't *refactor* — just small wins as you pass through.

## What I'm building
- The game is similar to classic MMORPGs.
- Includes 18 classes: Warrior, Paladin, Shadow Knight, Cleric, Druid, Shaman, Beast Master, Rogue, Monk, Ranger, Witch Hunter, Bard, Magician, Wizard, Sorcerer, Enchanter, Necromancer, Blood Mage. Planned: Assassin, Warlock.
- Includes 16 playable races: Human, Elf, Dark Elf, Wood Elf, Gnome, Halfling, Dwarf, Half-Elf, Ogre, Troll, Kel`varath, Minotaur, Fae, Felhari, Kobold, Half-Ogre.
# UI
- Free mouse to click on UI, i.e. skill buttons or spell buttons
- While player holds right click engage camera control.
- Tab targeting.
- User interface overlay during game play.
- Inventory system, including 'paperdoll'
- Equipment system
# Mechanics
- Combat system featuring auto attack, skills, and spells
- Player leveling system; as character level increases, character becomes stronger.
- Equipment system

- Please don't change anything above the F:\PROJECTS\ directory.

---

# Architecture Reference

## Key Autoloads (Singletons)
| Autoload | Purpose |
|---|---|
| `PlayerStats` | HP/MP/stamina, STR/AGI/INT/WIS/CON, level, XP, race/class, bind point |
| `Combat` | Auto-attack loop, melee/ranged/spell damage, target management |
| `Spells` | Cast queue, cooldown tracking, `available[]` filtered by class/level/rank |
| `Skills` | Active skills (Shield Bash, Feign Death, etc.), cooldowns |
| `Inventory` | Bag slots, item stacks, `add_item()` / `remove_item()` / `stack_all()` |
| `Equipment` | Paperdoll slots, equip/unequip, dual wield gating via `can_dual_wield()` |
| `BuffManager` | All buff/debuff state: HoT, DoT, absorb, stat buffs, haste, speed, stealth, clarity, lich form, damage shield |
| `WeaponSkills` | Passive weapon skill tracking; extends `PassiveSkillTracker` |
| `ArmorSkills` | Passive armor skill tracking; extends `PassiveSkillTracker` |
| `CastingSkills` | Casting discipline tracking (evocation, alteration, etc.); extends `PassiveSkillTracker` |
| `GroupManager` | Group membership, XP distribution with 20% group bonus |
| `QuestManager` | Quest state (ACTIVE/COMPLETED/FAILED), objectives, signals |
| `DialogueManager` | Nearby NPC tracking; `open_nearby()` emits `dialogue_opened(npc_name)` |
| `Alignment` | Alignment score/tier, `get_effective_class()` for Fallen Paladin / Redeemed SK |
| `BardSongs` | Twist song system; single active song, pulses every 3 s |
| `PetManager` | Pet lifecycle: summon, unsummon, charm |
| `WarderAI` | Beast Master warder AI (retreat/fury/setup_for_class) |
| `TimeOfDay` | Day/night cycle, emits `hour_changed` |
| `VisionSystem` | Infravision/ultravision post-processing at night |
| `ZoneLoader` | Zone transitions, current zone path/name |
| `CombatLog` | Chat broker — listens to gameplay signals, emits `line_added(text, type)`; preserves the `add_line` / `chat_submitted` / `show_chat_input` API for existing callers |
| `ChatWindowManager` | Owns N `ChatWindow` (`scripts/chat_window.gd`) instances; create/rename/delete via right-click; layout persists through `GameSettings.chat_windows` |
| `DebugLog` | Timestamped log to `debug.log`; rotates at 2000 lines |
| `Settings` | Keybind persistence, UI panel positions, rebindable actions list |

## Key Data Files
| File | Purpose |
|---|---|
| `data/spell_definitions.gd` | All spell data as `const ALL: Array` of dicts; `DISCIPLINE` dict maps spell name → casting skill |
| `data/weapon_skill_definitions.gd` | All weapon skill keys, display names, per-class caps at level 60 |
| `data/weapon_item_table.gd` | Fallback weapon name → skill key (for runtime-generated items with no `.tres`) |
| `data/loot_tables.gd` | Named mob loot archetypes (Wolf, Skeleton, Gnoll, etc.) loaded from `.tres` files |
| `data/dialogue_definitions.gd` | `class_name DialogueDefinitions; const ALL` — NPC name → dialogue tree (node_id → {text, responses[]}); response `quest_condition` field filters by quest state |
| `data/quest_definitions.gd` | `class_name QuestDefinitions; const ALL` — quest id → {name, description, objectives, xp_reward, item_rewards, giver_npc, turn_in_npc} |
| `scripts/spell_data.gd` | `class_name SpellData extends Resource` — all spell fields including `rank` and `base_name` |
| `scripts/item_data.gd` | `class_name ItemData extends Resource` — all item fields |
| `scripts/skill_data.gd` | Active skill data class |
| `scripts/skill_definitions.gd` | All active skill entries |
| `scripts/mobile_character.gd` | Base class for `enemy.gd` and `pet.gd`; shared `_move_at_speed()` / `_face_toward()` |
| `autoloads/passive_skill_tracker.gd` | Base class for `WeaponSkills`, `ArmorSkills`, `CastingSkills`; shared `try_advance()` logic |

## Combat Architecture
- **Auto-attack:** `Combat._on_auto_attack()` fires on a timer. Checks `MELEE_RANGE = 3.0` m or `RANGED_RANGE = 25.0` m when `ItemData.is_ranged`. Damage uses DEX bonus for ranged, STR bonus for melee. Calls `WeaponSkills.try_advance()` on hit.
- **Spell casting:** `Spells.cast_spell(spell)` → optional cast bar → `_apply_spell()` → damage/heal/buff routed to appropriate systems. Casting skills advance on cast; Channeling advances when a hit survives interruption.
- **Spell ranks:** `SpellData.rank` (1/2/3) + `SpellData.base_name`. `setup_for_class()` keeps only the highest accessible rank per base spell. Discipline inherits from `base_name` automatically — no separate `DISCIPLINE` entry needed for rank variants.
- **Active skills:** `Skills.use_skill(skill)` → effect via `SkillData.EffectType` enum (STUN, FEIGN_DEATH, STEALTH, etc.).
- **Enemy state machine:** IDLE → CHASE → ATTACK → FLEE/LEASH. Caster enemies kite at `caster_range`; healer enemies flee to spawn when HP drops below `healer_flee_hp` fraction.
- **Alignment:** `Alignment.get_effective_class()` returns a modified class string (e.g. `"Paladin_Fallen"`) used by `Spells.setup_for_class()` and effectiveness scaling.

## Spell System Quick Reference
- `SpellData.min_level` gates availability; `setup_for_class()` filters on level-up.
- Rank II unlocks ~level 6–12 (+40% power); Rank III ~level 14–16 (+90% power).
- Bard songs set `is_song: true` and route through `BardSongs.activate_song()`, not standard buff handling.
- Buff spells call into `BuffManager` (stat buffs, HoT, DoT, absorb, haste, speed, clarity, damage shield).
- Port spells use `TargetType.PORT` with `port_zone_path` / `port_entry_id`; Gate uses empty strings to resolve to the bind point.

## Session Workflow
1. Check `docs/playtest_notes/` for any new user-reported bugs before starting.
2. Pick the next unchecked item from the To-Do List below.
3. Implement it; mark `[x]` in the To-Do List when done.
4. Append a summary to `docs/session_notes/session_YYYY_MM_DD.md` and update the index in `docs/session_notes/README.md`.
5. Run a code review pass if the session touches 5+ files or modifies a core system (combat, inventory, spells, PlayerStats).

---

# To-Do List

## High Priority (core feel)
- [x] **XP bar on HUD** — Progress bar toward next level, always visible
- [x] **Buff/debuff bar UI** — Icons with countdown timers for active buffs (absorb, HoT, evade boost, etc.)
- [x] **Scrollback on chat log** — Mouse wheel scrolls up; auto-scroll resumes when at bottom; "▼ latest" button appears when scrolled up and new messages arrive
- [x] **Player stat buffs** — SpellData has str/agi/int/wis/con/max_hp/max_mp buff fields; BuffManager.add_primary_stat_buff() applies directly to PlayerStats and undoes on expire/death/zone; Bless+Valor (Cleric/Paladin), Spirit of the Bear+Gift of Insight (Shaman), Strength+Brilliance (Enchanter) added to spell_definitions.gd
- [x] **Stun** — Shield Bash (Warrior/Paladin/Shadow Knight skill) stuns via SkillData.EffectType.STUN → enemy.stun(); stunned enemies skip entire physics state machine (no movement OR attacking)
- [x] **Slow** — "Slow" spell (Shaman/Enchanter) applies attack_slow_amount:0.7 via enemy.apply_attack_slow(); attack cooldown scaled by (1.0 + slow_amount)
- [x] **Root** — enemy.root() wired in spells.gd; roots block movement in _tick_chase() while allowing attack; Ensnare (Druid, 20s) and Immobilize (Enchanter, 15s) added to spell_definitions.gd
- [x] **Critical hits** — Auto-attack/skill crits scale with DEX (0–30%); spell crits scale with INT (0–20%); both roll 1.5–2.0× multiplier; crit log lines use distinct bright-gold `MsgType.CRIT` color
- [x] **Wire `alignment_changed` signal** — skills.gd, spells.gd, and hud.gd all connected; HUD shows alignment tier with color coding (Exalted/Good/Neutral/Bad/Evil)

## Medium Priority (gameplay depth)
- [x] **Passive weapon skills** — Skills like 1H Slashing, Piercing, 2H Blunt, Defense, Dodge that train up through use; each has a level-based cap; higher skill = better hit/damage chance; displayed live in character window Combat Skills section
- [x] **Damage shield** — Thorns effect: attacker takes X damage when hitting you (Druid/Enchanter)
- [x] **AOE spells** — Hit all enemies within a radius; needed for Magician/Druid at higher levels; `SpellData.TargetType.AOE`; `Combat.deal_aoe_spell_damage()`; Inferno/Nature's Wrath/Ice Storm/Arcane Nova added
- [x] **Elemental resistances** — Enemies have resist values (fire, ice, shadow, etc.) that reduce spell damage
- [x] **Spell ranks** — `SpellData.rank` + `base_name`; `setup_for_class()` keeps highest accessible rank per base spell; 36 Rk. II/III entries added; discipline falls back to base_name so no extra DISCIPLINE entries needed
- [x] **Ranged combat** — `ItemData.is_ranged`; `RANGED_RANGE = 25.0` in combat.gd; DEX-based damage; `archery` skill added to WeaponSkillDefinitions with per-class caps; arrow mesh projectile FX; "Hunter's Shortbow" seeded via test panel
- [x] **Proc weapons** — `ItemData.proc_chance/damage/damage_type/proc_name`; `Combat._try_fire_proc()` rolls on every main-hand and offhand hit; elemental FX + combat log line; "Flamebrand" (15% / 25 fire) seeded via test panel
- [x] **Meditation (sit-to-med)** — Sitting applies 5× HP/MP and 3× ST multiplier in regen.gd; movement auto-stands (player.gd); targeting while seated auto-stands via Regen._on_target_changed; food/drink regen stacks additively on top
- [x] **Food & drink items** — ItemData has `is_food`/`is_drink`/`food_hp_regen`/`food_mp_regen`/`food_duration`; right-click in inventory calls `add_food_buff`/`add_drink_buff`; Test Panel "Give Food & Drink" seeds Journeybread (+4 HP/tick) and Waterskin (+5 MP/tick) for 180s
- [x] **Bindpoint system** — Bind Affinity spell stores `bind_zone_path/entry_id/zone_name` on PlayerStats; `player_death._respawn()` routes through `ZoneLoader.travel_to()` when bind is set (falls back to `_respawn_position` if unset or file missing); death screen shows "Returning to [zone]..." vs "Respawning..."; XP loss now logged to combat log
- [ ] **Corpse run** — Gear stays on corpse on death; respawn naked and retrieve it (optional hardcore mode)
- [x] **Enemy spawn system** — Spawn points with respawn timers; world feels alive
- [x] **Named/boss mobs** — `data/named_mob_definitions.gd` (5 entries: Rotfang, Greth Bonecrusher, Ancient Crawler, Sable, The Undying); `EnemySpawner.named_mob_id` + `named_respawn_time` exports; `enemy.apply_named()` sets gold nameplate, scales HP/XP/damage, arms `_named_drops`; enrage at configurable HP% (speed+damage boost, red name); `Loot._on_enemy_died()` appends `_named_drops` after normal table roll; guaranteed + chance-based rare loot per boss
- [ ] **Incoming /tell RPC** — Receiving tells from other players over the network (outbound is done)
- [ ] **Mount system** — Design and implement mount summoning, speed modifier, and dismount-on-damage; required context before Animal Husbandry, Spirit of Wolf stacking, and Selos' Melody interactions can be fully designed
- [ ] **PvP flagging** — Design decision needed before implementation: when is PvP permitted, how is flagging triggered, what are the consequences; alignment kill deltas are already defined in docs/concepts/alignment/events.md
- [x] **Level-gated spell availability** — `SpellData.min_level` field; `spells.gd setup_for_class()` filters by `PlayerStats.level >= spell.min_level`; ~60 spells assigned appropriate thresholds; called on every level-up
- [x] **Group XP sharing** — `GroupManager.distribute_kill_xp(base_xp)` splits XP with 20% group bonus; `_rpc_receive_xp` RPC delivers each remote member's share; `enemy.gd._die()` routes through GroupManager

## Content & World
- [x] **Vendor NPCs** — `scenes/vendor_npc.tscn` (Area3D + capsule mesh + 2.5m proximity sphere + NameLabel3D); `scripts/vendor_npc.gd` registers with VendorManager on body_entered/exited; F key wired in hud.gd; Elara (General Merchant) and Brom (Provisioner) placed in world.tscn at spawn; 10 vendor types defined in `data/vendor_definitions.gd`; buy/sell window fully functional
- [x] **NPC dialogue system** — `DialogueNPC` (Area3D, proximity register); `DialogueManager` autoload; `DialogueDefinitions.ALL` dict (npc_name → tree of node ids); `dialogue_window.gd` (520×340 DraggablePanel, NPC text + numbered response buttons, goto/close/open_vendor actions); interact priority: DialogueManager > VendorManager > crafting station > skinning/mining; Aldric the Guard + Elara + Brom seeded with lore trees
- [x] **Quest system** — Full loop implemented: `QuestDefinitions.ALL` (4 kill quests); `DialogueDefinitions` wired with `give_quest`/`complete_quest` actions and `quest_condition` response filters; `dialogue_window.gd` evaluates conditions via `QuestManager.get_quest_status()`; `QuestManager.complete_quest()` delivers XP + item rewards via `Inventory.add_item()`; kill tracking automatic via `notify_kill()` in `enemy._die()`; Aldric gives Wolf Threat + Rotfang Hunt; Brom gives Rat Infestation + Gnoll Raiders
- [ ] **Faction system** — Race/class affects NPC standing; guards may attack on sight
- [x] **Multiple enemy types** — Casters that kite, healers that flee, undead with shadow resist; `spell_damage/caster_range/flee_range` exports on Enemy; `State.FLEE` for healers; EnemySpawner override groups added
- [x] **Crafting material sources** — "Cloth Scraps" added to enemy default loot table (mob-drop); "Flax" (raw ingredient for Linen Thread) added to General Merchant and Tailor vendor stock
- [x] **Race vision types** — ultravision (Dark Elf, Ogre, Troll, Kel`varath), infravision (Elf, Wood Elf, Half-Elf, Dwarf, Gnome, Halfling, Fae, Felhari, Kobold), normal (Human, Minotaur, Half-Ogre); VisionSystem autoload adjusts `adjustment_brightness` + infravision green tint at night; Revenant transformation grants ultravision separately
- [ ] **Weather system** — Rain, fog, storms; some mobs stronger/weaker in certain weather
- [x] **Day/night mob behavior** — EnemySpawner has `night_only: bool` export; TimeOfDay.hour_changed wired: spawns at hour 20, despawns at hour 6; normal `_spawn()` skips if night_only and it's daytime
- [x] **Fall damage** — `_on_land()` in player.gd; threshold 9 m/s; `(speed - threshold) × 5` HP; `Combat.receive_player_damage()`; incoming floating number; TODO: skip when Levitate/Feather Fall is active
- [ ] **Water & swimming** — Breath meter, drowning, Enduring Breath spell
- [ ] **Doors & locks** — Rogues pick locks; keys drop from mobs

## UI Polish
- [x] **Spell book window** — View all known spells, drag to hotbar slots
- [ ] **Target-of-target frame** — Show what your target is targeting (essential for group play)
- [x] **HP numbers on target frame** — Show actual HP values, not just a bar
- [ ] **Player portrait** — Race/class portrait in the HUD panel
- [x] **EQ-style multi-window chat system** — Four chunks (three from the original to-do plus tab docking):
  - [x] **Multi-window framework** — `CombatLog` is now a pure broker emitting `line_added(text, type)`; `autoloads/chat_window_manager.gd` owns N `ChatWindow` instances (each its own `DraggablePanel` with title bar + scroll + per-window LineEdit); right-click a window for New / Rename / Delete; layout (id/name/pos/size per window) persists through `GameSettings.chat_windows`.
  - [x] **Per-window message filters** — `ChatWindow.filters: Dictionary[String, bool]` keyed by `FILTER_KEYS` (one entry per `CombatLog.MsgType`); `add_line` short-circuits if the incoming type's key is false. Right-click → **Filters...** opens a grouped checkbox dialog (Combat / Chat / System). State persists alongside layout via `GameSettings.chat_windows`. Default for new and pre-chunk-2 windows is all enabled.
  - [x] **Per-window display settings** — `ChatWindow.bg_alpha` (0–100), `font_alpha` (10–100), `font_size` (9–21pt), `default_channel` ("", "say", "shout", "ooc", "group"). Right-click → **Display...** opens a dialog with two sliders, a SpinBox, and an OptionButton. `apply_display_settings` re-styles the panel and walks existing labels (each tagged with `msg_type` meta) to update font size and re-derive color at the new alpha. `default_channel` prepends `/<channel>` to non-slash input in `_on_chat_text_submitted`. Layout dict carries all four fields.
  - [x] **Tab docking** — `ChatWindow.group_id` (int) groups windows; group of 1 = solo (title bar). Group of 2+ replaces the title bar with a tab strip and hides non-active members entirely (their message history accumulates in the background). Drag a window onto another's title bar / tab strip → dock-merge. Drag a tab button out of the strip → undock to a new floating window at the cursor. `ChatWindowManager._groups` tracks `{members: Array[int], active: int}` per group_id; `dock` / `undock` / `set_active_tab` are the three group ops. `group_id` persists alongside the layout dict; restore rebuilds `_groups` from the saved ids.
- [ ] **Map / minimap** — Simple zone map showing player position
- [x] **Quest journal window** — `scripts/quest_journal.gd`; split panel (list/detail); Active/Completed tabs; objectives with ✓/○; toggle via J (keybind registered in settings.gd); QuestManager signals connected
- [x] **Inventory "stack all" button** — "Stack All" button in each BagWindow calls `Inventory.stack_all()`
- [x] **Dual wield paperdoll** — `Equipment.can_dual_wield()` gates offhand weapon slot; `_resolve_slot()` routes second weapon to "offhand" when dual_wield skill > 0; `combat.gd` fires offhand timer when slot is occupied
- [x] **Floating heal numbers** — Damage (with crit), incoming damage, heals, misses, XP gains; billboard Label3D always faces camera; per-category toggles in Options → Interface tab

## Class Abilities
- [x] **Feign Death** (Monk) — SkillData.FEIGN_DEATH; 80% success; all enemies in group de-aggro via `feign_death_deaggro()`; skill_definitions.gd + skills.gd
- [x] **Sneak & Hide** (Rogue) — SkillData.STEALTH; BuffManager.add_stealth(); aggro range vs stealthed players reduced in enemy.gd; breaks on attacking
- [x] **Track** (Ranger) — `scripts/track_window.gd`; lists all enemies within 60m with name/level/distance; refreshes every 2s; toggle via `TrackWindow.toggle()`
- [x] **Ranger spells in spell_definitions.gd** — Ensnaring Roots (root_duration:15), Camouflage (is_stealth), Hunter's Eye (accuracy_buff:0.15, crit_buff:0.10) added
- [x] **Witch Hunter spells in spell_definitions.gd** — Spellbreak (silence_duration:4), Antimagic Ward (is_dispel), Expose fixed to dispel (is_dispel) instead of damage
- [x] **Dual wield passive** — Caps defined in `WeaponSkillDefinitions.CLASS_CAPS` (Warrior 200, Rogue 250, Ranger 225, etc.); `combat.gd` calls `try_advance("dual_wield")` on off-hand swings; +20% miss penalty applied; paperdoll off-hand slot gating still needed (see UI Polish)
- [x] **Additional Bard twist songs** — Anthem of the Hunt, Poet's Mending, Wanderer's Chord, Mana Weave, Aria of Dismay added to spell_definitions.gd; bard_songs.gd `_pulse()` extended to handle accuracy/crit buffs and enemy attack slow
- [x] **Tradeskill implementation** — `crafting.gd` autoload (XP, success formula, racial multipliers, access gates); `crafting_window.gd` (K to open; skill dropdown, recipe list, ingredient checker, combine button, result feedback); `recipe_definitions.gd` (15 tradeskills: Smelting, Tanning, Leatherworking, Tailoring, Blacksmithing, Weaponsmithing, Woodworking, Fletching, Alchemy, Poison Making, Baking, Brewing, Jewelry Crafting, Pottery, Tinkering); `data/loot_tables.gd` (12 mob archetypes with `.tres`-backed crafting material drops); `skinning_knife.tres` + `try_skin()` on enemy corpses (F key, Skinning skill XP, pelt quality by skill level); all 150+ item `.tres` files; station proximity display (not yet enforced); see `docs/concepts/tradeskills/todo_list.md` for phase detail
- [ ] **Consumables system** — Food/drink buff slots in BuffManager; meditation regen loop (sit + food + drink = 3× MP regen + HP bonus); fermentation timer for Brewing; ritual consumable components for Cleric/Shaman/Necromancer abilities (design in docs/concepts/tradeskills/consumables.md and alchemy.md)
- [ ] **Bookbinding / player-authored lore** — Text input window when crafting Journal tier+; readable books findable in the world; Skill Manual passive XP bonus (+5-10% for 24h) on read; Bard Song Scroll (single-use song any class can play); Grand Grimoire housing item (design in docs/concepts/tradeskills/service.md)
- [ ] **Clockwork Engineering prestige path** — Tinkering 150+ for Gnomes/Kobolds unlocks Clockwork Engineering tier: Scout/Guardian Automatons, Clockwork Carrier, Clockwork Golem (Grandmaster end-goal); shares skill score with Tinkering (design in docs/concepts/tradeskills/tinkering.md)
- [x] **Revenant tradeskill retention** — Placeholder comment in transformations.gd; scores carry over automatically once tradeskill system is implemented (scores live outside PlayerStats)
- [x] **Augmentation/socketing** — ItemData: `gem_slots: int`, `socketed_augments: Array[String]`, `Type.AUGMENT`; UI/combine logic deferred until paperdoll update
- [x] **Bard song twist mechanic** — `autoloads/bard_songs.gd`; single active song, pulses every 3s via `BardSongs.activate_song()`; buff lingers 3.5s so twist cycling keeps effects active; Selos' Melody added as first twist song
- [x] **Complete Heal** (Cleric) — Spell data added (heal_amount:9999, cast_time:8s); resolves as self-heal for now; needs ALLY target type for multiplayer
- [ ] **Resurrection** (Cleric) — Spell data scaffolded (target_type:NONE); needs corpse system before functional implementation
- [x] **Torpor** (Shaman) — Spell data added (attack_slow:70%, hot_hps:12, duration:24s)
- [x] **Clarity / Breeze** (Enchanter) — Spell data added; BuffManager.add_mp_regen_buff(); regen.gd ticks clarity_mp per tick
- [x] **Haste** (Enchanter) — Spell data added; BuffManager.add_haste_buff(); combat.gd updates auto-attack interval via `_update_attack_interval()`
- [x] **Spirit of Wolf** (Druid / Shaman) — Spell data added; BuffManager.add_speed_buff(); player.gd multiplies move speed by `BuffManager.get_speed_mult()`
- [x] **Selos' Melody** (Bard) — Spell data added (is_song:true); routes through BardSongs twist system; pulses speed buff every 3s
- [x] **Lich Form** (Necromancer) — Spell data added (is_lich_form:true, lich_mp_regen:15); BuffManager.toggle_lich_form(); regen.gd skips HP regen + adds extreme MP regen while active
- [x] **Gate** (Wizard) — Already implemented (PORT target type, port_zone_path:"", port_entry_id:""); returns to bind point
- [x] **Exsanguinate** (Blood Mage) — Spell data added (mana_drain:60); spells.gd deals damage = min(drain, target.hp) and converts to caster MP

## Polish & Feel
- [x] **Spell visual effects** — Elemental color flash on enemy mesh + OmniLight3D burst per damage type (fire=orange, ice=blue, lightning=yellow, arcane=purple, holy=gold, nature=green, spirit=lavender, shadow=dark purple); physical hits flash white
- [ ] **Sound system** — Combat hit sounds, spell audio, ambient zone sounds, music
- [x] **Enemy hit reactions** — White mesh flash on physical hit; elemental-colored flash on spell hit; OmniLight3D burst at impact point for spell hits; all via `enemy.flash_spell_hit(color)` called from `combat.deal_spell_damage()`
- [x] **Death animations** — Enemies and player fall over instead of vanishing
- [ ] **Zone transition effects** — Fade to black / loading screen between zones
- [x] **Settings persistence** — Save keybinds, UI panel positions, chat prefs to disk
- [x] **Beast Master warder facing** — Pet idle state now calls `_face_toward(global_position + player_forward)` in pet.gd; pet presents front face to camera matching player look direction
- [x] **Debugger output to file** — `autoloads/debug_log.gd` (DebugLog autoload); writes to `res://debug.log` with timestamps; rotates to `debug_prev.log` at 2000 lines; API: `DebugLog.info/warn/error/combat(msg)`

## Social / Multiplayer
- [ ] **Language system** — Scaffolded: race starting skills, garble cipher per language, `/lang` and `/languages` commands, passive skill gain; needs multiplayer chat RPC integration and trainer NPCs to unlock skill 0 languages
- [ ] **LFG flag** — Mark yourself as Looking For Group; visible to others
- [ ] **Player inspect** — Right-click a player to see their equipment
- [ ] **Guild system** — Creation, ranks, guild bank, MOTD
- [ ] **Dueling** — Consensual 1v1 combat between players
- [ ] **`hear_language()` wiring** — `/lang` and `/languages` commands wired in hud.gd; `hear_language()` passive gain still not called from chat receive path; needs multiplayer chat RPC integration before it can trigger
- [ ] **Auction / bazaar** — List items for sale; other players browse and buy

## Technical Debt
- [x] **`player_stats.gd` refactor** — Alignment extracted to `autoloads/alignment.gd`; PlayerStats no longer owns alignment_score/tier/signal/get_effective_class
- [x] **`PetManager` split** — WarderAI extracted to `autoloads/warder_ai.gd`; PetManager is now generic pet lifecycle; warder retreat/fury/setup_for_class lives in WarderAI
- [x] **`hud.gd` split** — 907→478 lines; DeathScreen/CastBar/BuffBar/PetPanel/GroupPanel each in their own `scripts/hud_*.gd` file
- [x] **Wire cooldown signals to Hotbar** — `spell_cooldown_updated` and `skill_cooldown_updated` are emitted by spells.gd/skills.gd; Hotbar is fully signal-driven (hotbar.gd lines 52–54)
- [x] **`enemy.gd` / `pet.gd` CombatLog coupling** — enemy status effects emit via `Combat` signals; pet hits relay through `PetManager.pet_info`; `combat_log.gd` subscribes to both
- [x] **Duplicate movement helpers** — `scripts/mobile_character.gd` base class extracted; `enemy.gd` and `pet.gd` both extend it; each keeps its own `_move_toward()` since enemy applies snare scaling
- [x] **Duplicate `try_advance()` pattern** — `autoloads/passive_skill_tracker.gd` base class extracted; `WeaponSkills`, `ArmorSkills`, `CastingSkills` all extend it
- [ ] **Weapon item table gaps** — `data/weapon_item_table.gd` maps only a handful of weapons; others fall back to `hand_to_hand` for passive skill tracking; populate as new weapon items are added
- [x] **`combat.gd` magic numbers** — Melee range, evasion constants, crit chance constants replaced with named constants at file top
