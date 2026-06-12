# Art Assets Checklist

Living inventory of the art and audio that needs to be produced. Counts reflect
the codebase as of 2026-05-14 — they grow whenever new spells, items, or zones
are added, so re-derive when in doubt:

| What | Where it lives | Current count |
|---|---|---|
| Spells | `data/spell_definitions.gd` (`ALL`) | 153 total, 36 rank variants → **~117 unique base spells** |
| Active skills | `data/skill_definitions.gd` (`ALL`) | **32** |
| Items | `data/loot/items/*.tres` | **157** |
| Mob archetypes | `data/loot_tables.gd` keys | 11 (Wolf, Boar, Bear, Snake, Spider, Bat, Rat, Skeleton, Zombie, Gnoll, Bandit) |
| Named bosses | `data/named_mob_definitions.gd` | 5 (Rotfang, Greth Bonecrusher, Ancient Crawler, Sable, The Undying) |
| Playable races | `data/character_data.gd` | 16 |
| Playable classes | `CLAUDE.md` | 18 (+2 planned) |
| Tradeskills | `data/recipe_definitions.gd` | 15 |
| Vendor archetypes | `data/vendor_definitions.gd` | 10 |
| Zones | `scenes/world.tscn` + atlas | 1 active, ~20 sketched in `docs/concepts/world/` |

Everything under `assets/` is currently empty; the game runs on Godot primitives
(`CapsuleMesh`, `TorusMesh`, default fonts, OmniLight3D bursts).

---

## 1. UI Sprites — `assets/sprites/ui/`

- [ ] Logo / splash variants (source: `docs/design/PD_Logo_discord_icon.png`)
- [ ] Window chrome — title bar, close button, resize handle, panel background (for `DraggablePanel`)
- [ ] HUD frames — player, target, target-of-target (planned), group, pet
- [ ] Bars — HP / MP / Stamina / XP / cast bar / buff timer (fill + frame)
- [ ] Hotbar slot + cooldown overlay sweep
- [ ] Buff & debuff icon frames (border / timer ring)
- [ ] Inventory bag panel + slot
- [ ] Paperdoll silhouette (per body type — heroic, slim, ogre, halfling, kobold)
- [ ] Quest journal, spell book, crafting, vendor, loot, dialogue, options window backgrounds
- [ ] Death screen overlay
- [ ] Chat log frame + tab indicators + "▼ latest" button
- [ ] Targeting reticle (replaces `TorusMesh` indicator on enemies)
- [ ] Cursor set — default, interact, attack, talk, loot, no-cast
- [ ] Lobby / character-creation backdrops
- [ ] Race selection portraits — **16** (one per race)
- [ ] Class selection portraits — **18** (or class crest sigils)
- [ ] Damage / heal floating-number stylings (currently plain `Label3D` text)
- [ ] Minimap frame + compass + map textures (when map system ships)

## 2. Spell Icons — `assets/sprites/icons/spells/`

~**117 unique base spells**; rank variants (Rk II / Rk III) can reuse the base
icon with a small rank pip overlay. Recommended 64×64.

By class (approximate — pull from `spell_definitions.gd` for exact list):

- [ ] Magician (~6): Fireball, Frost Bolt, Lightning Strike, Heal, Arcane Missile, Inferno
- [ ] Cleric (~6): Healing Light, Greater Heal, Smite, Divine Wrath, Complete Heal, Resurrection
- [ ] Druid (~9): Thorns, Regrowth, Wrath, Call Lightning, Entangle, Snare, Nature's Wrath, Ensnare, Spirit of Wolf
- [ ] Shaman (~7): Healing Wave, Mending, Spirit Bolt, Ancestral Strike, Slow, Torpor, Spirit of Bear, Gift of Insight
- [ ] Blood Mage (~4): Blood Bolt, Crimson Bolt, Life Drain, Hemorrhage, Exsanguinate
- [ ] Paladin (~5): Lay on Hands, Crusader's Mend, Righteous Fire, Judgment, Bless, Valor
- [ ] Shadow Knight (~3): Lifetap, Siphon, Dark Shroud
- [ ] Necromancer (~6): Summon Skeleton, Bone Shards, Soul Drain, Dark Decay, Enervation, Lich Form
- [ ] Enchanter (~9): Spellshield, Charm, Color Spray, Mesmerize, Rune, Cascade of Stars, Clarity, Breeze, Haste, Strength, Brilliance, Immobilize
- [ ] Bard (~9): Siren's Song, Dissonance, Battle Hymn, Chorus of Misery, Selos' Melody, Anthem of the Hunt, Poet's Mending, Wanderer's Chord, Mana Weave, Aria of Dismay
- [ ] Ranger (~5): Hunter's Mark, Nature's Cure, Ensnaring Roots, Camouflage, Hunter's Eye
- [ ] Witch Hunter (~5): Witchfire, Expose, Rite of Warding, Banishment, Spellbreak, Antimagic Ward
- [ ] Fallen Paladin (~4): Death's Embrace, Blood Price, Shadow Flame, Condemnation
- [ ] Redeemed Shadow Knight (~3): Sacrificial Mend, Radiant Bolt, Holy Mantle
- [ ] Wizard (~7): Ice Spear, Flame Wave, Thunder Clap, Blizzard, Meteor, Ice Storm, Gate
- [ ] Sorcerer (~6): Arcane Burst, Void Lance, Bloodfire, Tempest Bolt, Soul Surge, Arcane Nova
- [ ] Utility (~3): Bind Affinity, Gate (shared), port spells

## 3. Active Skill Icons — `assets/sprites/icons/skills/`

**32 skills** — full list in `data/skill_definitions.gd`. 64×64.

- [ ] Warrior — Slash, Shield Bash, Pummel
- [ ] Rogue — Hide, Backstab, Evade
- [ ] Cleric — Holy Strike
- [ ] Shaman — Primal Strike
- [ ] Paladin — Divine Blow, Holy Shield
- [ ] Shadow Knight — Dark Strike, Harm Touch
- [ ] Bard — Swindler's Strike
- [ ] Ranger — Double Strike, True Shot, Aimed Shot, Rapid Shot, Dual Flurry
- [ ] Monk — Tiger Claw, Roundhouse, Flying Kick, Feign Death
- [ ] Witch Hunter — Silver Bolt, Exploit Weakness, Truesight Strike
- [ ] Beast Master — Claw Rake, Warder's Fury, Primal Instinct
- [ ] Alignment variants — Profane Strike, Dark Ward, Redeemed Strike, Penitent's Touch

## 4. Item Icons — `assets/sprites/icons/items/`

**157 items** authored as `.tres` — wire each to its `icon: Texture2D` field on
`ItemData`. 64×64.

- [ ] Weapons (~25): daggers, swords, clubs, staves, bows, ranged tools
- [ ] Armor (~45): cloth/leather/chain/plate sets, helms, vests, gloves, boots, leggings
- [ ] Consumables (~10): potions, elixirs, antidotes, food, drink
- [ ] Tradeskill raw materials (~50): ores, hides, pelts, herbs, gems, essences, silks, bones, meats
- [ ] Tradeskill processed (~15): ingots, leather strips, thread, fletchings, wires, settings
- [ ] Tools (~5): pickaxe, skinning knife, smithing hammer, sewing needle, tinkering kit
- [ ] Jewelry (~10): rings, simple settings, gemmed rings
- [ ] Misc (~10): coin purse, bottles, vials, clay, gears, springs, traps
- [ ] Boss drops (per `named_mob_definitions.gd`): Rotfang's Fang, Predator's Collar, etc.
- [ ] Augments / sockets (when system ships — see CLAUDE.md to-do)

## 5. Character Models — `assets/models/characters/<race>/`

Folder skeleton already exists for all 16 races. Reference heights:
`docs/reference/creature_heights.md`.

Per race:
- [ ] Body mesh — male + female (or a shared neutral if going androgynous)
- [ ] Head / face variants (low priority for V1 — 1 each is fine)
- [ ] Texture maps — diffuse, normal (skin tones, racial markings)

Shared (`assets/models/characters/_shared/`):
- [ ] Master humanoid rig (`_shared/rig/`)
- [ ] Animation set (`_shared/animations/`) — see §7

Races: Human, Elf, Dark Elf, Wood Elf, Gnome, Halfling, Dwarf, Half-Elf, Ogre,
Troll, Kel'varath, Minotaur, Fae, Felhari, Kobold, Half-Ogre.

## 6. NPC Models — `assets/models/characters/` (reuse race rigs)

- [ ] 10 vendor types (General Merchant, Alchemist, Blacksmith, Leatherworker, Tailor, Fletcher, Jeweler, Provisioner, Tinkerer, Pottery Vendor) — distinctive outfits
- [ ] Guards (Aldric the Guard et al.)
- [ ] Quest givers (reuse race mesh + outfit / name label)
- [ ] Trainers — class trainers, language trainers (TBD when system ships)

## 7. Animations — `assets/models/characters/_shared/animations/`

Single shared library, retargeted to any humanoid rig.

- [ ] Idle (combat / non-combat)
- [ ] Walk, run, sprint
- [ ] Jump, fall, land
- [ ] Sit (meditate) → stand
- [ ] Melee swings — 1H, 2H, dual-wield
- [ ] Bow draw + loose
- [ ] Spell cast — channel (looping), instant, finish
- [ ] Hit react (front / back / stagger)
- [ ] Death — fall forward / fall back
- [ ] Feign Death drop
- [ ] Emotes — wave, bow, cheer, point (low priority)
- [ ] Mount-ride idle / run (gated on mount system)

Quadrupeds / non-humanoids (wolves, bears, snakes, etc.) need their own rigs +
clips — keep minimal: idle / walk / run / attack / hit / death.

## 8. Creature / Enemy Models — `assets/models/creatures/`

### Mob archetypes (from `data/loot_tables.gd`)
- [ ] Wolf
- [ ] Boar
- [ ] Bear
- [ ] Snake
- [ ] Spider (small + large variants)
- [ ] Bat
- [ ] Rat
- [ ] Skeleton (cloth / armored variants)
- [ ] Zombie / Ghoul (Plagued Ghoul, Festering)
- [ ] Wraith (Ancient Wraith)
- [ ] Bone Colossus (large skeleton — reuse + scale)
- [ ] Gnoll (Brute + standard)
- [ ] Bandit (reuses Human rig + outfit)

### Named bosses (`data/named_mob_definitions.gd`)
- [ ] Rotfang — large wolf, distinct fur / scars
- [ ] Greth Bonecrusher
- [ ] Ancient Crawler
- [ ] Sable
- [ ] The Undying

Recolored or scaled archetypes are acceptable V1.

### Pets
- [ ] Beast Master warders (Wolf, Bear, Boar — reuse mob meshes)
- [ ] Summoned Skeleton (reuse archetype)
- [ ] Charmed enemies (reuse caster mesh)

## 9. Weapon Models — `assets/models/weapons/`

One mesh per weapon family, then per-tier swatch / texture variants.

- [ ] Dagger, Short Sword, Long Sword, Greatsword
- [ ] Axe (1H / 2H)
- [ ] Mace (1H / 2H), War Hammer
- [ ] Spear, Polearm
- [ ] Staff, Wand
- [ ] Bow, Crossbow, Throwing
- [ ] Shields — Buckler, Round, Tower, Kite
- [ ] Caster off-hand — Tome, Orb
- [ ] Tradeskill tools — Skinning Knife, Pickaxe, Smithing Hammer, Sewing Needle, Tinkering Kit (small mesh; double as world props)

Tiers (texture variants): Copper → Bronze → Iron → Steel → Mithril → Adamantite,
plus uniques (Flamebrand, Hunter's Shortbow, etc.).

## 10. Armor Models — `assets/models/armor/`

Folder is empty. Decide whether armor visually swaps on the paperdoll character
or stays icon-only.

- [ ] Cloth set — robe, cap, gloves, slippers, pants
- [ ] Leather set — vest, cap, gloves, boots, leggings, bracers
- [ ] Chain set — coif, vest, gloves, boots, leggings
- [ ] Plate set — full kit (when high-tier items land)
- [ ] Cloak (planned)
- [ ] Tier swatch progression — same UV, recolored textures

## 11. Environment & Props — `assets/models/environment/` + `assets/models/props/`

### Starter zone (current `scenes/world.tscn`)
- [ ] Trees (deciduous, pine, dead)
- [ ] Rocks (small, medium, boulder)
- [ ] Grass / fern / mushroom clusters (for foliage system)
- [ ] Ruined crypt entrance — already a camp in `zone_data.gd`
- [ ] Gnoll war camp props (totem, fire pit, hide tent)
- [ ] Bandit outpost (wooden palisade, cart)
- [ ] Wraith Gate (stone arch)

### Town / settlement
- [ ] Cottage, smithy, tavern, vendor stall, watch tower
- [ ] Cobblestone road segments
- [ ] Signposts, fences, gates

### Props (interior)
- [ ] Barrel, crate, table, chair, bed, bookshelf
- [ ] Cooking fire, anvil, forge, loom, tanning rack, alchemy bench, pottery wheel, tinker bench, jewelry workbench
- [ ] Mining node (replace placeholder in `scenes/mining_node.tscn`)
- [ ] Crafting station (replace `scenes/crafting_station.tscn` placeholder)

### Terrain & sky
- [ ] Terrain textures — grass, dirt, stone, sand, snow, marsh, ash
- [ ] Skybox (currently `PhysicalSkyMaterial`; needs cloud LUTs, moon, stars)
- [ ] Water shader — river / pond / ocean

### Future zones
Atlas in `docs/concepts/world/cartographers_atlas.md` outlines ~20 zones
(Greyfen, Drowned Hold, Ashfang Hold, Aelindra, Khala Savannahs, Kobold Deeps,
etc.). Defer until starter zone is fully dressed.

## 12. VFX — `assets/textures/` (+ particle materials)

- [ ] Spell impact textures per damage type — fire, ice, lightning, shadow, arcane, holy, nature, spirit (current burst is OmniLight3D-only)
- [ ] Melee swoosh / parry spark
- [ ] Beam textures (channel spells, Life Drain, Siphon)
- [ ] Cast circle decals (per discipline)
- [ ] Aura spheres — stealth, lich form, damage shield, absorb
- [ ] Footstep dust / mist (per terrain)
- [ ] Arrow trail / projectile FX
- [ ] Level-up burst
- [ ] Death dissolve

## 13. Audio — `assets/audio/{sfx,music,ambient,voice}/`

All folders are currently empty.

### SFX
- [ ] Combat hits — slash / blunt / pierce × hit / miss / parry / block
- [ ] Bow loose + arrow impact
- [ ] Spell cast start / finish per discipline (evocation, alteration, abjuration, conjuration, divination)
- [ ] Spell impact per damage type
- [ ] Crit sting
- [ ] Damage taken (player) + low-HP heartbeat
- [ ] Death — player + ~10 creature variants
- [ ] Footsteps × terrain (grass, dirt, stone, wood, water, sand)
- [ ] Crafting — hammer ring, anvil clank, loom click, fire crackle, pour, snip, knife slice
- [ ] UI — button click, panel open / close, error, level up, quest complete, item pickup, coin pickup, eat / drink

### Music
- [ ] Title / lobby theme
- [ ] Starter zone — day theme + night theme
- [ ] Combat sting (looping)
- [ ] Named / boss fight theme
- [ ] Death sting
- [ ] Victory / level-up jingle
- [ ] Future zone themes (deferred per atlas)

### Ambient loops
- [ ] Forest day, forest night, crypt, cave, marsh, town square, tavern, dungeon, windy plain

### Voice
- [ ] Player exertion (grunt on hit, death cry) — optional per race
- [ ] Casting voice lines (low priority)
- [ ] NPC greetings (low priority — can stay text-only V1)

## 14. Fonts — `assets/fonts/`

- [ ] Body UI font (branded — currently Godot default)
- [ ] Title / header display font
- [ ] Combat log / damage number font (monospace or tabular figures)
- [ ] Chat input font

---

## Recommended order of operations

1. **One UI theme pass** — window chrome, frames, bars, hotbar slots. Replaces the most-visible Godot defaults.
2. **Spell + active-skill icons** — every player sees these every second; placeholder colored squares are jarring.
3. **Item icons** — inventory is constantly visible; covers 157 entries with one batch.
4. **Humanoid base mesh + rig + animation set** — unlocks player, NPCs, bandits, gnolls, skeletons in one go (palette / outfit swap).
5. **Mob archetype meshes** — quadrupeds + spiders + bats; the rest reuse the humanoid rig.
6. **Combat SFX + zone ambient loop** — silence sells worse than placeholder graphics.
7. **Starter zone environment dressing** — trees, rocks, props for crafting stations.
8. **Music tracks** — title + starter zone + combat sting.
9. **Boss-specific meshes** — only after archetypes; bosses can ride on archetype recolors until then.
10. **Future zones & their bespoke creatures** — defer until starter loop is polished.

## Notes

- Keep raw source files (`.blend`, `.psd`, `.kra`) in `../Project_Dawn_Source/` per CLAUDE.md — only game-ready files belong in `assets/`.
- When wiring an icon, fill `ItemData.icon` on the `.tres`; `Inventory` / `Hotbar` will pick it up automatically.
- Animation clips should land on the shared rig under `_shared/animations/` so every race can use them without re-export.
- Boss meshes can re-use archetype meshes with a different material + size scale until bespoke art exists.
