# Project notes

note for claude:  I will add play testing notes to the docs\playtest_notes\  Please have a look.  if this can be organized better, you're welcome to move it after i make additions.

## Engine
- Godot 4.3 (or whatever version you're on)
- GDScript only, no C#
- Targeting desktop (Windows/Mac/Linux)

## Project structure
- scenes/ — all .tscn scene files
- scripts/ — standalone .gd scripts not tied to a scene
- assets/ — sprites, sounds, fonts
- autoloads/ — singleton scripts registered in project.godot

## Conventions
- Use snake_case for variables and functions (GDScript standard)
- Use PascalCase for class_name declarations
- Prefer signals over direct node references for cross-scene communication

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

- Please don't change anything above this PROJECTS folder.

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
- [ ] **Passive weapon skills** — Skills like 1H Slashing, Piercing, 2H Blunt, Defense, Dodge that train up through use; each has a level-based cap; higher skill = better hit/damage chance
- [x] **Damage shield** — Thorns effect: attacker takes X damage when hitting you (Druid/Enchanter)
- [ ] **AOE spells** — Hit all enemies within a radius; needed for Magician/Druid at higher levels
- [x] **Elemental resistances** — Enemies have resist values (fire, ice, shadow, etc.) that reduce spell damage
- [ ] **Spell ranks** — Spells gain power at certain levels (Rank I → II → III)
- [ ] **Ranged combat** — Bow attacks for Ranger; range-check before auto-attack
- [ ] **Proc weapons** — Equipment with on-hit spell effects
- [x] **Meditation (sit-to-med)** — Sitting applies 5× HP/MP and 3× ST multiplier in regen.gd; movement auto-stands (player.gd); targeting while seated auto-stands via Regen._on_target_changed; food/drink regen stacks additively on top
- [x] **Food & drink items** — ItemData has `is_food`/`is_drink`/`food_hp_regen`/`food_mp_regen`/`food_duration`; right-click in inventory calls `add_food_buff`/`add_drink_buff`; Test Panel "Give Food & Drink" seeds Journeybread (+4 HP/tick) and Waterskin (+5 MP/tick) for 180s
- [ ] **Bindpoint system** — Bind is a spell cast by eligible casters (not a chat command); casters can bind themselves or others; warriors/melee without the spell must find a caster or use a bind stone (world object); respawn at bind location instead of a fixed point on death
- [ ] **Corpse run** — Gear stays on corpse on death; respawn naked and retrieve it (optional hardcore mode)
- [x] **Enemy spawn system** — Spawn points with respawn timers; world feels alive
- [ ] **Named/boss mobs** — Rare spawns with special loot tables and behaviors
- [ ] **Incoming /tell RPC** — Receiving tells from other players over the network (outbound is done)
- [ ] **Mount system** — Design and implement mount summoning, speed modifier, and dismount-on-damage; required context before Animal Husbandry, Spirit of Wolf stacking, and Selos' Melody interactions can be fully designed
- [ ] **PvP flagging** — Design decision needed before implementation: when is PvP permitted, how is flagging triggered, what are the consequences; alignment kill deltas are already defined in docs/concepts/alignment/events.md

## Content & World
- [ ] **Vendor NPCs** — Buy/sell items; prices scale with faction
- [ ] **NPC dialogue system** — Click NPC → dialogue window with response buttons
- [ ] **Quest system** — Kill X, collect Y, deliver Z; quest log window; XP/item rewards
- [ ] **Faction system** — Race/class affects NPC standing; guards may attack on sight
- [ ] **Multiple enemy types** — Casters that kite, healers that flee, undead with shadow resist
- [x] **Race vision types** — ultravision (Dark Elf, Ogre, Troll, Kel`varath), infravision (Elf, Wood Elf, Half-Elf, Dwarf, Gnome, Halfling, Fae, Felhari, Kobold), normal (Human, Minotaur, Half-Ogre); VisionSystem autoload adjusts `adjustment_brightness` + infravision green tint at night; Revenant transformation grants ultravision separately
- [ ] **Weather system** — Rain, fog, storms; some mobs stronger/weaker in certain weather
- [x] **Day/night mob behavior** — EnemySpawner has `night_only: bool` export; TimeOfDay.hour_changed wired: spawns at hour 20, despawns at hour 6; normal `_spawn()` skips if night_only and it's daytime
- [ ] **Fall damage** — Damage from long drops; Levitate/Feather Fall spell counters it
- [ ] **Water & swimming** — Breath meter, drowning, Enduring Breath spell
- [ ] **Doors & locks** — Rogues pick locks; keys drop from mobs

## UI Polish
- [x] **Spell book window** — View all known spells, drag to hotbar slots
- [ ] **Target-of-target frame** — Show what your target is targeting (essential for group play)
- [x] **HP numbers on target frame** — Show actual HP values, not just a bar
- [ ] **Player portrait** — Race/class portrait in the HUD panel
- [ ] **Chat channel tabs** — Separate tabs for Say, OOC, Group, Tells
- [ ] **Map / minimap** — Simple zone map showing player position
- [x] **Floating heal numbers** — Damage (with crit), incoming damage, heals, misses, XP gains; billboard Label3D always faces camera; per-category toggles in Options → Interface tab

## Class Abilities
- [x] **Feign Death** (Monk) — SkillData.FEIGN_DEATH; 80% success; all enemies in group de-aggro via `feign_death_deaggro()`; skill_definitions.gd + skills.gd
- [x] **Sneak & Hide** (Rogue) — SkillData.STEALTH; BuffManager.add_stealth(); aggro range vs stealthed players reduced in enemy.gd; breaks on attacking
- [x] **Track** (Ranger) — `scripts/track_window.gd`; lists all enemies within 60m with name/level/distance; refreshes every 2s; toggle via `TrackWindow.toggle()`
- [x] **Ranger spells in spell_definitions.gd** — Ensnaring Roots (root_duration:15), Camouflage (is_stealth), Hunter's Eye (accuracy_buff:0.15, crit_buff:0.10) added
- [x] **Witch Hunter spells in spell_definitions.gd** — Spellbreak (silence_duration:4), Antimagic Ward (is_dispel), Expose fixed to dispel (is_dispel) instead of damage
- [ ] **Tradeskill implementation** — Recipes, combine window, skill XP (full design in docs/concepts/tradeskills/)
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

## Social / Multiplayer
- [ ] **Language system** — Scaffolded: race starting skills, garble cipher per language, `/lang` and `/languages` commands, passive skill gain; needs multiplayer chat RPC integration and trainer NPCs to unlock skill 0 languages
- [ ] **LFG flag** — Mark yourself as Looking For Group; visible to others
- [ ] **Player inspect** — Right-click a player to see their equipment
- [ ] **Guild system** — Creation, ranks, guild bank, MOTD
- [ ] **Dueling** — Consensual 1v1 combat between players
- [ ] **`hear_language()` wiring** — Function exists in languages.gd and is never called; wire passive language learning to the chat receive path or remove it before the language system ships
- [ ] **Auction / bazaar** — List items for sale; other players browse and buy

## Technical Debt
- [x] **`player_stats.gd` refactor** — Alignment extracted to `autoloads/alignment.gd`; PlayerStats no longer owns alignment_score/tier/signal/get_effective_class
- [x] **`PetManager` split** — WarderAI extracted to `autoloads/warder_ai.gd`; PetManager is now generic pet lifecycle; warder retreat/fury/setup_for_class lives in WarderAI
- [x] **`hud.gd` split** — 907→478 lines; DeathScreen/CastBar/BuffBar/PetPanel/GroupPanel each in their own `scripts/hud_*.gd` file
- [x] **Wire cooldown signals to Hotbar** — `spell_cooldown_updated` and `skill_cooldown_updated` are emitted by spells.gd/skills.gd; Hotbar is fully signal-driven (hotbar.gd lines 52–54)
- [x] **`enemy.gd` / `pet.gd` CombatLog coupling** — enemy status effects emit via `Combat` signals; pet hits relay through `PetManager.pet_info`; `combat_log.gd` subscribes to both
