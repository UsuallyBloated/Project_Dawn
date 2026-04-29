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
- The game is similar to EverQuest.
- Includes 18 classes: Warrior, Paladin, Shadow Knight, Cleric, Druid, Shaman, Beast Master, Rogue, Monk, Ranger, Witch Hunter, Bard, Magician, Wizard, Sorcerer, Enchanter, Necromancer, Blood Mage. Planned: Assassin, Warlock.
- Includes 17 playable races: Human, Elf, Dark Elf, Wood Elf, Gnome, Halfling, Dwarf, Half-Elf, Ogre, Troll, Iksar, Minotaur, Revenant, Fae, Vah Shir, Kobold, Half-Ogre.
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
- [ ] **Buff/debuff bar UI** — Icons with countdown timers for active buffs (absorb, HoT, evade boost, etc.)
- [ ] **Scrollback on chat log** — Scroll up to read older messages; currently only 6 lines visible
- [ ] **Player stat buffs** — Spells that temporarily raise STR/AGI/INT/WIS/max HP/MP (Cleric, Shaman, Enchanter)
- [ ] **Stun** — Shield Bash and similar skills should briefly stun enemies (can't attack or move)
- [ ] **Slow** — Reduce enemy attack speed by a percentage; Shaman/Enchanter staple
- [ ] **Root** — Enemy can't move but can still attack/cast; distinct from mez
- [ ] **Critical hits** — Chance to deal 150–200% damage on melee/spells, scaling with stats

## Medium Priority (gameplay depth)
- [ ] **Passive weapon skills** — Skills like 1H Slashing, Piercing, 2H Blunt, Defense, Dodge that train up through use; each has a level-based cap; higher skill = better hit/damage chance
- [ ] **Damage shield** — Thorns effect: attacker takes X damage when hitting you (Druid/Enchanter)
- [ ] **AOE spells** — Hit all enemies within a radius; needed for Magician/Druid at higher levels
- [ ] **Elemental resistances** — Enemies have resist values (fire, ice, shadow, etc.) that reduce spell damage
- [ ] **Spell ranks** — Spells gain power at certain levels (Rank I → II → III)
- [ ] **Ranged combat** — Bow attacks for Ranger; range-check before auto-attack
- [ ] **Proc weapons** — Equipment with on-hit spell effects
- [ ] **Food & drink** — Consumables that boost out-of-combat regen; sitting + food + drink = fast regen (very EQ)
- [ ] **Bindpoint system** — `/bind` at camps/inns; respawn at bind instead of a fixed point on death
- [ ] **Corpse run** — Gear stays on corpse on death; respawn naked and retrieve it (optional hardcore mode)
- [ ] **Enemy spawn system** — Spawn points with respawn timers; world feels alive
- [ ] **Named/boss mobs** — Rare spawns with special loot tables and behaviors
- [ ] **Incoming /tell RPC** — Receiving tells from other players over the network (outbound is done)

## Content & World
- [ ] **Vendor NPCs** — Buy/sell items; prices scale with faction
- [ ] **NPC dialogue system** — Click NPC → dialogue window with response buttons
- [ ] **Quest system** — Kill X, collect Y, deliver Z; quest log window; XP/item rewards
- [ ] **Faction system** — Race/class affects NPC standing; guards may attack on sight
- [ ] **Multiple enemy types** — Casters that kite, healers that flee, undead with shadow resist
- [ ] **Weather system** — Rain, fog, storms; some mobs stronger/weaker in certain weather
- [ ] **Day/night mob behavior** — Undead only spawn at night, etc.
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
- [ ] **Tradeskill implementation** — Recipes, combine window, skill XP (doc exists in docs/concepts/tradeskills.md)
- [ ] **Augmentation/socketing** — Gem slots in gear for bonus stats

## Polish & Feel
- [ ] **Spell visual effects** — Particles for fire, ice, lightning, holy, shadow; spells are currently invisible
- [ ] **Sound system** — Combat hit sounds, spell audio, ambient zone sounds, music
- [ ] **Enemy hit reactions** — Color flash or brief knockback when damaged
- [ ] **Death animations** — Enemies and player fall over instead of vanishing
- [ ] **Zone transition effects** — Fade to black / loading screen between zones
- [ ] **Settings persistence** — Save keybinds, UI panel positions, chat prefs to disk

## Social / Multiplayer
- [ ] **LFG flag** — Mark yourself as Looking For Group; visible to others
- [ ] **Player inspect** — Right-click a player to see their equipment
- [ ] **Guild system** — Creation, ranks, guild bank, MOTD
- [ ] **Dueling** — Consensual 1v1 combat between players
- [ ] **Auction / bazaar** — List items for sale; other players browse and buy
