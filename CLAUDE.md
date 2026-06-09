# Project Dawn

A multiplayer MMORPG inspired by classic EverQuest-era games. **Two repos:** a Godot
4.4 client (this repo) and a Rust authoritative server (`F:\Projects\server`).

> Note for Claude: playtest feedback lands in `docs/playtest_notes/` — skim it before
> starting a session. You're doing great work; thanks for the care.

---

## Commands

### Client (this repo — Godot 4.4, GDScript only, no C#)
- Run from the editor (open project in Godot 4.4), or headless:
  `godot --path f:\Projects\Project_Dawn`
- Debugging: see the **Debugging / chasing bugs** section below.
- Tester instructions: `README_FOR_TESTERS.md`

### Server (`F:\Projects\server` — Rust, toolchain pinned to 1.95.0)
- Run:   `cargo run -p projectdawn-server`  (auth WebSocket on `0.0.0.0:8765`)
- Test:  `cargo test`                       (~30s including build)
- Build: `cargo build --release`
- DB:    SQLite `world.db`; `sqlx` auto-applies migrations on first boot
- Dev helper: `scripts/dev-run.sh`

> Don't modify anything above `F:\Projects\`.

---

## Debugging / chasing bugs

The fastest way to chase a bug is the **in-game debug console** (`scripts/debug_console.gd`)
— a live, in-memory tail of `DebugLog` shown inside the running game. No alt-tabbing to
read `debug.log`, and it keeps working even if file IO is broken (it reads
`DebugLog.recent_lines` + the `line_emitted` signal, not the file).

- **Toggle:** `F2` or backtick `` ` ``; `ESC` closes; `/console` in chat is a fallback for
  when the keybind isn't reaching the game window. Intentionally *not* rebindable — it's
  a diagnostic tool, not a gameplay control.
- **Color-coded by level:** ERROR (red), WARN (yellow), COMBAT (blue), info (gray).
- **The loop:** instrument the suspect path with `DebugLog.info/warn/error/combat(msg)`,
  run the game, and watch it live in the console. Lines also persist to `debug.log`
  (rotates to `debug_prev.log` at 2000 lines) for after-the-fact reading.
- Especially valuable here because it's a client/server game — there's no easy debugger
  across the wire, so logging the live path is often the only window into a bug.

---

## Architecture: two repos, one game

- **Client** (this repo): Godot 4.4. Nearly all gameplay lives in ~49 autoload singletons.
- **Server** (`F:\Projects\server`): Rust authoritative server. **Pre-alpha — auth only**
  (Register / Login / CharList / CharCreate / CharDelete / Logout). The world UDP
  simulation is **not built yet**; clients run **local-save** until it lands.
- **The project is multiplayer-only.** There is no supported solo mode — don't scope
  features or tests around a solo path. Existing solo plumbing is vestigial.
- **Before any change that crosses the wire**, read the canonical contract:
  `docs/concepts/architecture/README.md` → `server/docs/server_design.md`. That covers
  networking/RPCs, save persistence (`autoloads/save_manager.gd`), and the
  server-authoritative state on `PlayerStats`, `Inventory`, `Equipment`, `QuestManager`,
  the passive skill trackers, `Combat`, and `Loot`.

### Known client↔server drift to watch
- Spells exist in **both** GDScript (`data/spell_definitions.gd`) and server `spells.toml`
  — adding/editing one without the other causes drift (e.g. a missing Warder's Mend).
- Leveling and max stats are **client-local** today; a server `HealthUpdate` can roll a
  fresh level-up back. Treat client leveling as provisional.
- Time-of-day is per-client; a server broadcast is planned.

---

## What I'm building

- Classic-MMO feel: tab targeting, hotbar of skills/spells, auto-attack + casting,
  paperdoll equipment, bag inventory, group play, a living day/night world.
- **18 classes:** Warrior, Paladin, Shadow Knight, Cleric, Druid, Shaman, Beast Master,
  Rogue, Monk, Ranger, Witch Hunter, Bard, Magician, Wizard, Sorcerer, Enchanter,
  Necromancer, Blood Mage. Planned: Assassin, Warlock.
- **16 races:** Human, Elf, Dark Elf, Wood Elf, Gnome, Halfling, Dwarf, Half-Elf, Ogre,
  Troll, Kel\`varath, Minotaur, Fae, Felhari, Kobold, Half-Ogre.
- **Stats:** STR / AGI / INT / WIS / CON / CHA (CHA is the confirmed 6th primary).

### UI conventions
- Free mouse to click UI (skill/spell buttons); hold **right-click** to engage camera
  control. Tab targeting; full HUD overlay; inventory with paperdoll; equipment system.

---

## Project structure

- `scenes/` — `.tscn` scene files
- `scripts/` — standalone `.gd` not tied to a scene (incl. `scripts/test_panel.gd` debug tool)
- `autoloads/` — singletons registered in `project.godot`
- `data/` — game data as GDScript consts (`spell_definitions.gd`, `loot_tables.gd`, etc.)
- `assets/` — game-ready art/audio imported by Godot (`models/ textures/ materials/ sprites/ fonts/ audio/`)
- `addons/`, `tools/`, `builds/`
- `docs/` — `concepts/ design/ reference/ playtest_notes/ session_notes/`
- `../Project_Dawn_Source/` — raw source (`.blend`, `.psd`, `.kra`); kept outside the
  project to keep Godot's import DB lean. Export game-ready files into `assets/`.

---

## Code style

These are cheap rules — they apply to new code (or code we're already touching for
another reason). They are **not** a mandate to stop and refactor existing files.

### Naming & structure
- `snake_case` for variables/functions; `PascalCase` for `class_name`.
- Prefer signals over direct node references for cross-scene communication.
- Type hints on signatures and exported vars (`func foo(x: int) -> bool:`, `var hp: int = 100`).

### File and function shape
- ~500–600 lines is the "ask yourself if this still has one responsibility" threshold,
  not a hard cap. Split on *responsibility*, not line count — e.g. `PetManager`→`WarderAI`,
  `PlayerStats`→`Alignment`, `hud.gd`→the `hud_*.gd` family.
- `scripts/test_panel.gd` is a debug tool, not a feature drawer. It should only *invoke*
  systems (call public autoload methods), never hold gameplay logic.

### Comments
This is a project people read to learn from and enjoy, not just ship. Comments that help
a newcomer (or future-you) understand the code are welcome — explaining *what* a system
or block does is fine here, not just *why*.

- **File headers help.** A 2–4 line comment at the top of a script saying what the system
  is and how it fits the whole is high-value and low-maintenance.
- **Orient, don't narrate.** A one-line summary over a non-trivial block is great. A
  comment that just restates the next line (`hp -= 10  # lower hp by 10`) is noise.
- **For genuinely subtle code**, still explain the *why*: a hidden constraint, a bug
  workaround, an invariant, something that would surprise a reader.
- **Keep comments true.** When you change the code, update the comment in the same pass —
  a comment that contradicts the code is worse than none.
- No sprint labels in code (e.g. "Track 22.G —"); that context lives in `docs/session_notes/`.
- No commented-out code. Git history is the archive.

### UI / constants
- Prefer `.tscn` scenes over imperative `_build_xxx()` UI in new HUD work.
- Magic numbers/strings (group names, path templates, small transforms) live as named
  constants at the top of the file — `autoloads/combat.gd` is the reference.

### Touch hygiene
Leave a file cleaner than you found it — but keep it *adjacent* and *small*.

- Clean what you're already changing: drop a dead branch, rename a confusing local,
  extract a constant, add a missing file-header comment. Wins that sit right next to your
  diff.
- Don't go hunting. Unrelated cleanups elsewhere in the file are scope creep — they bury
  the real change and make review harder. Give them their own commit, or just mention them.
- Never *refactor* under cover of a feature change. If a file genuinely needs
  restructuring, that's its own task.

---

## Session workflow

1. Check `docs/playtest_notes/` for new user-reported bugs before starting.
2. Pick the next open item from **To-Do** (below) or the user's request.
3. Implement it; mark `[x]` and move its "what exists" note into
   `docs/concepts/architecture/systems_overview.md` (not back into this to-do).
4. Append a summary to `docs/session_notes/session_YYYY_MM_DD.md` and update
   `docs/session_notes/README.md`.
5. Run a review pass (`/code-review`) if the session touches 5+ files or a core system
   (combat, inventory, spells, PlayerStats, networking).

---

## Architecture reference

### Autoloads (49, grouped — source of truth is the `[autoload]` block in `project.godot`)

| Domain | Autoloads |
|---|---|
| **Progression** | `PlayerStats`, `Alignment`, `Skills`, `Spells`, `WeaponSkills`, `ArmorSkills`, `CastingSkills`, `Memorize`, `SpellBar`, `Regen`, `CharacterSetup` |
| **Combat** | `Combat`, `BuffManager`, `DamageNumbers`, `PlayerDeath`, `Targeting`, `Loot`, `NetCombatBroadcaster` |
| **Items / economy** | `Inventory`, `Equipment`, `ItemRegistry`, `VendorManager`, `Crafting`, `StationManager` |
| **Pets / transforms** | `PetManager`, `WarderAI`, `Transformations`, `MountManager` |
| **World / environment** | `ZoneLoader`, `TimeOfDay`, `VisionSystem`, `SenseHeading` |
| **Social / quest / UI** | `GroupManager`, `QuestManager`, `DialogueManager`, `CombatLog`, `ChatWindowManager`, `BardSongs`, `Languages`, `SocialHotkeys`, `GameSettings`, `DebugLog` |
| **Networking (client)** | `Network`, `Net`, `SaveManager`, `RemotePlayerManager`, `RemoteEnemyManager`, `RemoteLootBagManager`, `RemotePetManager` |

Per-autoload responsibilities and the combat/spell deep dive live in
`docs/concepts/architecture/systems_overview.md`.

### Key data files

| File | Purpose |
|---|---|
| `data/spell_definitions.gd` | All spells as `const ALL: Array`; `DISCIPLINE` maps spell → casting skill |
| `data/weapon_skill_definitions.gd` | Weapon skill keys, display names, per-class caps at lvl 60 |
| `data/weapon_item_table.gd` | Fallback weapon name → skill key (runtime items without `.tres`) |
| `data/loot_tables.gd` | Named mob loot archetypes from `.tres` |
| `data/dialogue_definitions.gd` | NPC → dialogue tree; responses filter by quest state |
| `data/quest_definitions.gd` | Quest id → objectives, rewards, giver/turn-in NPC |
| `data/named_mob_definitions.gd` | Boss/named-mob stats, enrage, guaranteed/rare drops |
| `scripts/spell_data.gd` / `item_data.gd` / `skill_data.gd` | Resource classes |
| `scripts/mobile_character.gd` | Base for `enemy.gd` + `pet.gd` (shared movement) |
| `autoloads/passive_skill_tracker.gd` | Base for `WeaponSkills` / `ArmorSkills` / `CastingSkills` |

---

## Where things are documented

- **What systems exist & how they work** → `docs/concepts/architecture/systems_overview.md`
- **Server / wire protocol / DB / save migration** → `server/docs/server_design.md`
  (pointer at `docs/concepts/architecture/README.md`)
- **Design concepts** (lore, classes, races, tradeskills, alignment) → `docs/concepts/`
- **Per-session changelog** → `docs/session_notes/` (index in its `README.md`)
- **Playtest bug reports** → `docs/playtest_notes/`

---

## To-Do (open items only)

> Completed work is no longer tracked here — it's described in
> `docs/concepts/architecture/systems_overview.md` and dated in `docs/session_notes/`.
> **Current focus:** client networking + PvP (RemotePlayer/Pet targeting, PvP flagging).

### Multiplayer / networking
- [ ] **Incoming `/tell` RPC** — receiving tells from other players (outbound done)
- [ ] **PvP flagging** — when is PvP permitted, how is it triggered, consequences;
  alignment kill deltas defined in `docs/concepts/alignment/events.md`. Pets should
  inherit the owner's PvP flag (today any player can attack any pet).
- [ ] **ALLY-target buff routing over the network** — stat/haste/clarity/shield buffs
  still apply to the caster even when the ALLY target is a peer; only heals route via the
  server.
- [ ] **Player inspect** — right-click a player to see their equipment *(in progress:
  `scripts/inspect_window.gd`)*
- [ ] **LFG flag**, **Guild system**, **Dueling**, **Auction / bazaar**
- [ ] **Language system wiring** — `hear_language()` passive gain not yet called from the
  chat-receive path; needs multiplayer chat RPC + trainer NPCs

### Death / corpses
- [ ] **Corpse run** — gear stays on corpse; respawn naked and retrieve (optional hardcore)
- [ ] **Resurrection (Cleric)** — scaffolded; blocked on the corpse system

### World systems
- [ ] **Mount system** — *`MountManager` autoload exists (client-side v1); feature is not
  fully wired* (server speed clamp, Animal Husbandry / Spirit-of-Wolf stacking / Selos'
  Melody interactions still pending)
- [ ] **Faction system** — race/class affects NPC standing; guards attack on sight
- [ ] **Weather system**; **Water & swimming** (breath/drowning); **Doors & locks** (lockpicking)
- [ ] **Zone transition effects** — fade/loading screen

### UI polish
- [ ] **Player portrait** in HUD *(slugify + slot landed; art pending)*; **Map / minimap**

### Tradeskill depth
- [ ] **Consumables system** (food/drink regen loop, fermentation, ritual components)
- [ ] **Bookbinding / player-authored lore**
- [ ] **Clockwork Engineering prestige** (Tinkering 150+ for Gnomes/Kobolds)

### Audio & tech debt
- [ ] **Sound system** — combat/spell/ambient/music
- [ ] **EQ-style food/water gating** — food/water should gate base HP/MP regen (no food =
  no regen) instead of stacking as additive buffs; passive consumption from inventory,
  no buff-bar entry
- [ ] **Weapon item table gaps** — `data/weapon_item_table.gd` maps only a few weapons;
  others fall back to `hand_to_hand` for passive skill tracking
