# Session Notes

Developer changelogs written after each work session. Each file records what was built, which files were touched, and implementation notes or caveats. Use these to reconstruct what changed and why without digging through git blame.

Files named `session_YYYY_MM_DD.md`. Where a session produced separate lore/content and code passes, a `_code` suffix distinguishes the code-focused file.

---

## Index

| Date | File | Topics |
|------|------|--------|
| 2026-04-26 | [session_2026_04_26.md](session_2026_04_26.md) | Project bootstrap, player movement, HUD bars |
| 2026-04-27 | [session_2026_04_27.md](session_2026_04_27.md) | Combat autoload, player stats, character creation, enemy AI, terrain |
| 2026-04-28 | [session_2026_04_28.md](session_2026_04_28.md) | Inventory, equipment, skills, spells, regen, damage numbers, loot, networking, hotbar, paperdoll, crafting scaffold, loot tables, 22 starter items |
| 2026-04-29 | [session_2026_04_29.md](session_2026_04_29.md) | Zone system, buff manager, group manager, pet manager, settings persistence, social commands, weapon skills, CharacterData refactor, drag-drop inventory, class/race docs (all 18 classes, all 17 races), tradeskill docs, transformation docs, alignment docs |
| 2026-04-30 | [session_2026_04_30.md](session_2026_04_30.md) | World lore (deities, dominion war, architects, languages, calendar), factions, 8 NPC profiles, zone expansions, ASCII maps; day/night mobs, food & drink, enemy hit reactions, spell VFX, crits, stun/root/slow/silence, elemental resists, damage shield, alignment extraction, WarderAI split, HUD split (907→478 lines), buff types, new spell definitions, bard twist, race vision, Feign Death/Sneak/Track, hotbar cooldowns, CombatLog decoupling, spell book, floating combat text |
| 2026-05-01 | [session_2026_05_01.md](session_2026_05_01.md) | Character window combat skills + armor skills sections, QuestManager, quest journal (J key), pet idle facing fix, caster/healer enemy types, mobile_character.gd + passive_skill_tracker.gd base classes, bard twist songs, level-gated spells, group XP sharing, spell ranks, proc weapons, bindpoint death respawn, vendor NPC bug fixes, NPC dialogue system; crafting stations, mining system, fall damage; named/boss mobs (5 bosses, enrage, gold nameplate, guaranteed + rare loot); full quest loop (QuestDefinitions, dialogue give/complete actions, quest_condition filters, item rewards); code review: fixed @onready null crash in EnemySpawner.apply_named(), fixed notify_collect() Crafting cross-coupling; loot bug fix (ResourceLoader.exists() false positive), inventory redesign (8 flat base slots, bags-as-items), item stacking fix, ToT frame positioning fix, paperdoll item name display |
