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
- Please don't change anything above this PROJECTS folder.
[one or two sentences about your game]