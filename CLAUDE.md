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
- Includes three base classes Warrior, Mage, Rogue
- Includes 8 playable races Ogre, Troll, Gnome, Halfling, Human, Dwarf, Elf, Half-Elf, Dark-Elf, Wood-Elf.  (more to be added)
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
