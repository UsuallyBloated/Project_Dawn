# Project notes

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
- Includes 17 playable races: Human, Elf, Dark Elf, Wood Elf, Gnome, Halfling, Dwarf, Half-Elf, Ogre, Troll, Kel`varath, Minotaur, Revenant, Fae, Felhari, Kobold, Half-Ogre.
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
- [ ] **XP bar on HUD** — Progress bar toward next level, always visible
- [x] **Buff/debuff bar UI** — Icons with countdown timers for active buffs (absorb, HoT, evade boost, etc.)
- [ ] **Scrollback on chat log** — Scroll up to read older messages; currently only 6 lines visible
- [ ] **Player stat buffs** — Spells that temporarily raise STR/AGI/INT/WIS/max HP/MP (Cleric, Shaman, Enchanter)
- [ ] **Stun** — Shield Bash and similar skills should briefly stun enemies (can't attack or move)
- [ ] **Slow** — Reduce enemy attack speed by a percentage; Shaman/Enchanter staple
- [ ] **Root** — Enemy can't move but can still attack/cast; distinct from mez
- [ ] **Critical hits** — Chance to deal 150–200% damage on melee/spells, scaling with stats
- [x] **Wire `alignment_changed` signal** — skills.gd, spells.gd, and hud.gd all connected; HUD shows alignment tier with color coding (Exalted/Good/Neutral/Bad/Evil)

## Medium Priority (gameplay depth)
- [ ] **Passive weapon skills** — Skills like 1H Slashing, Piercing, 2H Blunt, Defense, Dodge that train up through use; each has a level-based cap; higher skill = better hit/damage chance
- [ ] **Damage shield** — Thorns effect: attacker takes X damage when hitting you (Druid/Enchanter)
- [ ] **AOE spells** — Hit all enemies within a radius; needed for Magician/Druid at higher levels
- [ ] **Elemental resistances** — Enemies have resist values (fire, ice, shadow, etc.) that reduce spell damage
- [ ] **Spell ranks** — Spells gain power at certain levels (Rank I → II → III)
- [ ] **Ranged combat** — Bow attacks for Ranger; range-check before auto-attack
- [ ] **Proc weapons** — Equipment with on-hit spell effects
- [ ] **Meditation (sit-to-med)** — Sitting triggers meditate state; mana regenerates 3× faster; movement or damage cancels it; pairs with food & drink for the full EQ regen loop
- [ ] **Food & drink items** — BuffManager slots and regen.gd wiring are done; still need actual food/drink ItemData resources and a consume action that calls `add_food_buff` / `add_drink_buff`
- [ ] **Bindpoint system** — `/bind` at camps/inns; respawn at bind instead of a fixed point on death
- [ ] **Corpse run** — Gear stays on corpse on death; respawn naked and retrieve it (optional hardcore mode)
- [ ] **Enemy spawn system** — Spawn points with respawn timers; world feels alive
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
- [ ] **Weather system** — Rain, fog, storms; some mobs stronger/weaker in certain weather
- [ ] **Day/night mob behavior** — Undead only spawn at night, etc.; requires wiring TimeOfDay's `hour_changed` signal to mob spawners and NPC schedulers (signal is emitted every in-game hour but currently has 0 listeners)
- [ ] **Fall damage** — Damage from long drops; Levitate/Feather Fall spell counters it
- [ ] **Water & swimming** — Breath meter, drowning, Enduring Breath spell
- [ ] **Doors & locks** — Rogues pick locks; keys drop from mobs

## UI Polish
- [ ] **Spell book window** — View all known spells, drag to hotbar slots
- [ ] **Target-of-target frame** — Show what your target is targeting (essential for group play)
- [ ] **HP numbers on target frame** — Show actual HP values, not just a bar
- [ ] **Player portrait** — Race/class portrait in the HUD panel
- [ ] **Chat channel tabs** — Separate tabs for Say, OOC, Group, Tells
- [ ] **Map / minimap** — Simple zone map showing player position
- [ ] **Floating heal numbers** — Extend damage numbers to show heals and misses

## Class Abilities
- [ ] **Feign Death** (Monk) — Drop to ground, enemies de-aggro; chance to fail
- [ ] **Sneak & Hide** (Rogue) — Stealth system; no aggro if approaching from behind
- [ ] **Track** (Ranger) — Window listing nearby mob names and distances
- [ ] **Ranger spells in spell_definitions.gd** — Ensnaring Roots, Snare, Camouflage, and Hunter's Eye are designed in docs/concepts/classes/ranger.md but have no entries in data/spell_definitions.gd yet
- [ ] **Witch Hunter spells in spell_definitions.gd** — Spellbreak, Antimagic Ward, and reworked Expose (buff-strip) are designed in docs/concepts/classes/witch_hunter.md but not in data/spell_definitions.gd yet
- [ ] **Tradeskill implementation** — Recipes, combine window, skill XP (full design in docs/concepts/tradeskills/)
- [ ] **Consumables system** — Food/drink buff slots in BuffManager; meditation regen loop (sit + food + drink = 3× MP regen + HP bonus); fermentation timer for Brewing; ritual consumable components for Cleric/Shaman/Necromancer abilities (design in docs/concepts/tradeskills/consumables.md and alchemy.md)
- [ ] **Bookbinding / player-authored lore** — Text input window when crafting Journal tier+; readable books findable in the world; Skill Manual passive XP bonus (+5-10% for 24h) on read; Bard Song Scroll (single-use song any class can play); Grand Grimoire housing item (design in docs/concepts/tradeskills/service.md)
- [ ] **Clockwork Engineering prestige path** — Tinkering 150+ for Gnomes/Kobolds unlocks Clockwork Engineering tier: Scout/Guardian Automatons, Clockwork Carrier, Clockwork Golem (Grandmaster end-goal); shares skill score with Tinkering (design in docs/concepts/tradeskills/tinkering.md)
- [ ] **Revenant tradeskill retention** — On earned Revenant transformation, all tradeskill scores carry over unchanged; if Revenant is ever offered as a starting race, start at 0 with no past-life retention
- [ ] **Augmentation/socketing** — Gem slots in gear for bonus stats
- [ ] **Bard song twist mechanic** — Songs pulse effects every ~3s while active; only one song plays at a time; skilled players manually cycle 3–4 songs fast enough to keep all timers active simultaneously (the EQ "twist")
- [ ] **Complete Heal** (Cleric) — 8s cast, heals target to full HP; the cornerstone spell of serious group play
- [ ] **Resurrection** (Cleric) — Restore a dead player at their corpse with partial XP return; only class with this
- [ ] **Torpor** (Shaman) — Massive slow + powerful HoT combined in one spell; makes Shaman irreplaceable in groups
- [ ] **Clarity / Breeze** (Enchanter) — Regenerates target's mana rapidly; Clarity is the high-level version; Breeze is lesser; makes long sessions possible for casters
- [ ] **Haste** (Enchanter) — Reduces target's melee auto-attack delay; effectively doubles warrior DPS; defines group synergy
- [ ] **Spirit of Wolf** (Druid / Shaman) — Movement speed buff; everyone wants this for zone traversal; AoE version for groups
- [ ] **Selos' Melody** (Bard) — Bard's movement speed song; affects whole group; stacks with SoW
- [ ] **Lich Form** (Necromancer) — Toggle: disables HP regen, grants extreme mana regen instead; changes how you play entirely
- [ ] **Gate** (Wizard) — Instant teleport to bind point; emergency escape; Wizard utility pillar
- [ ] **Exsanguinate** (Blood Mage) — Drains enemy HP directly into caster's mana pool; the defining Blood Mage fantasy spell

## Polish & Feel
- [ ] **Spell visual effects** — Particles for fire, ice, lightning, holy, shadow; spells are currently invisible
- [ ] **Sound system** — Combat hit sounds, spell audio, ambient zone sounds, music
- [ ] **Enemy hit reactions** — Color flash or brief knockback when damaged
- [ ] **Death animations** — Enemies and player fall over instead of vanishing
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
- [ ] **`player_stats.gd` refactor** — 20+ responsibilities in one autoload; extract Alignment into its own autoload before buff stacking and faction systems are added or this becomes unmaintainable
- [ ] **`PetManager` split** — 238 lines mixing pet state, Warder AI, and Beast Master-specific logic; split into PetManager (lifecycle) + WarderAI (behavior) before Magician elemental pets can be added cleanly
- [ ] **`hud.gd` split** — 786 lines managing 10+ unrelated concerns; split into focused panels (CoreHUD, BuffBar, GroupPanel, PetPanel, CastBar, DeathScreen) before more UI items from this list land
- [ ] **Wire cooldown signals to Hotbar** — `spell_cooldown_updated` and `skill_cooldown_updated` are emitted by spells.gd/skills.gd but Hotbar currently polls; switching to signal-driven removes the polling loop
- [ ] **`enemy.gd` / `pet.gd` CombatLog coupling** — both scripts call `CombatLog.add_line()` directly for mesmerize feedback and pet hit events; should emit signals (e.g. `mez_applied`, `hit_target`) that `combat_log.gd` subscribes to, same pattern used for `combat.gd`
