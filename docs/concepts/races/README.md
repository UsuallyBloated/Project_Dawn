# docs/concepts/races: Directory Index

Sixteen playable races, each with its own file: lore, the male and female physical
description (weight, build, distinctive features) and the race's allowed classes.

---

## One home for each fact

| Fact | Lives in |
|---|---|
| Race heights (metres, every race) | [creature_heights.md](../../reference/creature_heights.md), matching the Blender height chart (each race at the middle of its range) |
| Which races may play which classes, and why | [race_class_restrictions.md](../../design/race_class_restrictions.md) |
| Everything else about a race | Its own file, listed below |

The old `races.md` overview was retired on 2026-10-14: every part of it was duplicated
here, in the race files or in the two docs above, and its heights had drifted from the
height chart.

---

## Individual Race Files

| File | Race | Default Alignment | Starting Zone |
|---|---|---|---|
| [human.md](human.md) | Human | Neutral | Greenshire |
| [elf.md](elf.md) | Elf (High Elf) | Good | Aelindra |
| [dark_elf.md](dark_elf.md) | Dark Elf | Evil | Vel'Sharath |
| [wood_elf.md](wood_elf.md) | Wood Elf | Neutral | Ardenmoor |
| [gnome.md](gnome.md) | Gnome | Neutral | Cogsworth |
| [halfling.md](halfling.md) | Halfling | Good | Greenshire |
| [dwarf.md](dwarf.md) | Dwarf | Good | Dwarven Mountain Holds |
| [half_elf.md](half_elf.md) | Half-Elf | Neutral | Greenshire |
| [ogre.md](ogre.md) | Ogre | Evil | Ashfang Hold |
| [troll.md](troll.md) | Troll | Evil | Ashfang Hold |
| [kel_varath.md](kel_varath.md) | Kel`varath | Evil | Bonecourt |
| [minotaur.md](minotaur.md) | Minotaur | Neutral | Auroch's Rest |
| [fae.md](fae.md) | Fae | Neutral | Fae Mere |
| [felhari.md](felhari.md) | Felhari | Neutral | Khala Savannahs |
| [kobold.md](kobold.md) | Kobold | Evil | Kobold Deeps |
| [half_ogre.md](half_ogre.md) | Half-Ogre | Neutral | Eastern Badlands |

---

## In Design, Not Yet Playable

*Greenlit in `docs/design/race_expansion_brainstorm.md`; not in `data/character_data.gd` yet.*

| File | Race | Default Alignment | Starting Zone |
|---|---|---|---|
| [aerathi.md](aerathi.md) | Aerathi (the Stoop-kin) | Neutral | TBD: cliff eyrie |
| [vesperin.md](vesperin.md) | Vesperin | Neutral | TBD: jungle canopy city |
| [sylphari.md](sylphari.md) | Sylphari | Neutral | TBD: jungle groves |

---

*Race/class restrictions are tracked in `data/character_data.gd` (`LOCKED_COMBOS`). Zone lore for starting areas is in `docs/concepts/world/`.*
