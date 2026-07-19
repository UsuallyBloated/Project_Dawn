# Project Dawn

A multiplayer MMORPG inspired by classic EverQuest-era games. **Two repos:** a Godot
4.4 client (this repo) and a Rust authoritative server (`F:\Projects\server`).

> Note for Claude: playtest feedback lands in `docs/playtest_notes/` — skim it before
> starting a session. You're doing great work; thanks for the care.

> Please do the required research and dont fabricate answers.

> Please minimize the amount of em-dashes and also the ←/→ arrows.  People use these very rarely and they look odd to us. 

> I need you to be vigilant of potential exploits that the player could use to break the game.  This is critical as any exploit, no matter how large or small, can be the comple undoing of this project.  Also keep in mind the tools that we are using for development; these might seem like exploits but they are critical tools for saving time while testing.
---

## Commands

### Client (this repo — Godot 4.4, GDScript only, no C#)
- Run from the editor (open project in Godot 4.4), or headless:
  `godot --path f:\Projects\Project_Dawn`
- Debugging: see the **Debugging / chasing bugs** section below.
- Tester instructions: `README_FOR_TESTERS.md`

### Server (`F:\Projects\server` — Rust, toolchain pinned to 1.95.0)
- Run:   `cargo run -p projectdawn-server`  (auth WebSocket on `0.0.0.0:8765`)
- **Playtest run (dev commands):** set `PD_DEV_CMDS=1` or the dev-gated handlers
  (`HealSelf`/`DamageSelf` behind the Test Panel's **Full Heal** etc.) are silently
  ignored server-side — the client fills the bars optimistically but the server doesn't,
  so Full Heal looks like it works and doesn't. PowerShell:
  `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server`. (`/pvp on` is *not* dev-gated, so
  it works regardless — which masked this.)
- Test:  `cargo test`                       (~30s including build)
- Build: `cargo build --release`
- DB:    SQLite `world.db`; `sqlx` auto-applies migrations on first boot
- Dev helper: `scripts/dev-run.sh` (sources `.env` — put `PD_DEV_CMDS=1` there)
- **Windows run wrapper: `scripts/run-server.ps1`** — `.\scripts\run-server.ps1` (dev commands
  OFF, the hosted / GM-playtest mode) or `.\scripts\run-server.ps1 -Dev` (`PD_DEV_CMDS=1`, dev for
  everyone). Streams live to a unique `logs/server_<timestamp>.log` (never overwritten on restart)
  **and** `server.log`, and regenerates `world_report.html` on exit. Preferred over the raw
  `cargo run` for playtests, since it stops losing logs across restarts.
- **Ops bins (read-only DB tools; the crate has 3 binaries, so `--bin` selects — the plain
  `cargo run -p projectdawn-server` still runs the server via the `default-run` manifest key):**
  `cargo run -p projectdawn-server --bin admin_report` (accounts + characters incl. soft-deletes
  and per-char coins/inventory → console + a local `world_report.html`), and
  `cargo run -p projectdawn-server --bin grant_gm -- <username> on|off` (set per-account GM; no
  args = list). `grant_gm` writes; `admin_report` is read-only.
- **GM playtest (dev commands OFF, only `is_gm` accounts get tools):** `PD_DEV_CMDS` enables dev
  commands *only* when it equals exactly `"1"`, so to run with them off, unset it or set anything
  else. PowerShell (note: bare `null`/`false` are not literals — use `$null`/`$false` or a string):
  `Remove-Item Env:\PD_DEV_CMDS -EA Ignore; cargo run -p projectdawn-server`.

> Don't modify anything above `F:\Projects\`.

---

## Debugging / chasing bugs

The fastest way to chase a bug is the **in-game debug console** (`scripts/debug_console.gd`)
— a live, in-memory tail of `DebugLog` shown inside the running game. No alt-tabbing to
read `debug.log`, and it keeps working even if file IO is broken (it reads
`DebugLog.recent_lines` + the `line_emitted` signal, not the file).

- **Toggle:** backtick `` ` ``; `ESC` closes; `/console` in chat is a fallback for
  when the keybind isn't reaching the game window. Intentionally *not* rebindable — it's
  a diagnostic tool, not a gameplay control. (`F2` used to toggle it too, but is now EQ's
  "target group member 1" — see `docs/concepts/controls/`.)
- **Color-coded by level:** ERROR (red), WARN (yellow), COMBAT (blue), info (gray).
- **The loop:** instrument the suspect path with `DebugLog.info/warn/error/combat(msg)`,
  run the game, and watch it live in the console. Lines also persist to `debug.log`
  (rotates to `debug_prev.log` at 2000 lines) for after-the-fact reading.
- Especially valuable here because it's a client/server game — there's no easy debugger
  across the wire, so logging the live path is often the only window into a bug.

### Cheap subagents (delegate mechanical work)

Two read-only project subagents live in `.claude/agents/`. Prefer them over doing the
work in the main session, which runs on the expensive model:
- **log-scanner** (Haiku): grep `server.log` / `debug.log` for a pattern and report hits.
- **doc-sweeper** (Sonnet): "everywhere we documented X" sweeps of `docs/`.
Keep the main model for design, code, and any exploit or verification work.

---

## Architecture: two repos, one game

- **Client** (this repo): Godot 4.4. Nearly all gameplay lives in ~53 autoload singletons.
- **Server** (`F:\Projects\server`): Rust authoritative server. Auth (Register / Login /
  CharList / Char{Create,Delete} / Logout over WebSocket) **plus a live world UDP
  simulation** (renet, 20 Hz): server-authoritative movement, combat, regen, enemy AI,
  pets, inventory/equipment, four-tier currency + coin loot drops, group state + loot
  rights, passive skills, XP/leveling, player corpses + resurrection, quests. Wire
  protocol is **PD_W0024** (`crates/protocol`); the client
  bridges it via the `gdext_net` GDExtension (source in the server repo, shares the
  `protocol` crate). A `--local-save` dev path still exists for solo iteration without a
  server. (This line was "auth-only, world not built" through ~early 2026 — long stale.)
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
- *(Closed 2026-06-22: leveling used to be client-local and provisional. The corpse epic's
  Slice 0 moved XP + leveling server-side — `world/progression.rs::award_xp` is the single
  choke point and the client mirrors `XpGained` / `LevelUp`. The per-level stat tables are
  kept in **lockstep** on both sides (`char_data::level_gains` vs `CLASS_LEVEL_GAINS`) and
  anchor-tested, so editing one without the other IS still live drift to watch.)*
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
2. Pick the next open item from **To-Do** (below) or the user's request. During the
   friends-build push, `docs/schedule.md` says which phase we're in and what's in it.
3. Implement it. **Don't tick anything yet** — built is not done.
4. Append a summary to `docs/session_notes/session_YYYY_MM_DD.md` and update
   `docs/session_notes/README.md`.
5. Run a review pass (`/code-review`) if the session touches 5+ files or a core system
   (combat, inventory, spells, PlayerStats, networking).
6. **Tick only on playtest evidence.** An item earns `[x]` when a filled checklist in
   `docs/playtest_notes/` shows it passing — not when it compiles, not when `cargo test` is
   green, not when it's committed. Claude proposes the tick and cites the checklist row; the
   tester's result is the evidence. No checklist means the item is *built*, not *done*.
   Then, in one pass: tick it here, move its "what exists" note into
   `systems_overview.md` (not back into the to-do), and update the phase row in
   `docs/schedule.md` if it closes one.

> **Why the gate exists.** Step 3 used to read "implement it; mark `[x]`", and two lists went
> stale in that gap. On 2026-07-16 a docs pass aimed *specifically* at stale claims still left
> quest phase 2 listed as open with six sub-items that had all shipped the week before. And
> `corpse_slice3_checklist.md` still reads FAILED for resurrection work that was playtested
> clean and committed 06-26. Both drifted the same way: "done" got recorded in a session note
> and never propagated to the list anyone reads. Ticking on playtest evidence, in the same
> pass, is what keeps them honest — and it means neither of us is marking our own homework.

---

## Architecture reference

### Autoloads (53, grouped — source of truth is the `[autoload]` block in `project.godot`)

| Domain | Autoloads |
|---|---|
| **Progression** | `PlayerStats`, `Alignment`, `Skills`, `Spells`, `WeaponSkills`, `ArmorSkills`, `CastingSkills`, `Memorize`, `SpellBar`, `Regen`, `CharacterSetup` |
| **Combat** | `Combat`, `BuffManager`, `DamageNumbers`, `PlayerDeath`, `Targeting`, `Loot`, `NetCombatBroadcaster` |
| **Items / economy** | `Inventory`, `Equipment`, `ItemRegistry`, `VendorManager`, `Crafting`, `StationManager`, `Currency`, `Encumbrance` |
| **Pets / transforms** | `PetManager`, `WarderAI`, `Transformations`, `MountManager` |
| **World / environment** | `ZoneLoader`, `TimeOfDay`, `VisionSystem`, `SenseHeading` |
| **Social / quest / UI** | `GroupManager`, `QuestManager`, `DialogueManager`, `CombatLog`, `ChatWindowManager`, `BardSongs`, `Languages`, `SocialHotkeys`, `GameSettings`, `DebugLog` |
| **Networking (client)** | `Network`, `Net`, `SaveManager`, `RemotePlayerManager`, `RemoteEnemyManager`, `RemoteLootBagManager`, `RemotePetManager` |

Per-autoload responsibilities and the combat/spell deep dive live in
`docs/concepts/architecture/systems_overview.md`.
### Godot .exe location

"F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe"

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

- **Current plan, dates & sequencing** → `docs/schedule.md` — the push to a playable friends
  build (target 2026-09-14), with the phases, the critical path, and the velocity the estimates
  are measured against. **There is one checkbox list in this project and it's the To-Do below.**
  The schedule holds no boxes: its per-phase bullets are the plan, and its status table is just a
  progress readout of what the To-Do already says. Time-boxed by design — when the target lands,
  fold anything unfinished back into the To-Do and retire this pointer.
  `docs/schedule.html` is a browser-readable rendering of it for non-repo readers (open it
  locally); keep it in sync when the plan changes.
- **What systems exist & how they work** → `docs/concepts/architecture/systems_overview.md`
- **Server / wire protocol / DB / save migration** → `server/docs/server_design.md`
  (pointer at `docs/concepts/architecture/README.md`)
- **Design concepts** (lore, classes, races, tradeskills, alignment) → `docs/concepts/`
- **Per-session changelog** → `docs/session_notes/` (index in its `README.md`)
- **Playtest bug reports & checklists** → `docs/playtest_notes/`. Author new playtest
  checklists from `docs/playtest_notes/TEMPLATE_checklist.md` (the default format): numbered
  sections of `- [ ] **action** → expected result. notes:` rows the tester fills in place
  with `[x]`/`[-]` + findings. Keep the per-row `notes:` hooks — they're what makes a
  "didn't work" result triage-able against `server.log`.

---

## To-Do (open items only)

> Completed work is no longer tracked here — it's described in
> `docs/concepts/architecture/systems_overview.md` and dated in `docs/session_notes/`.
> **Current focus:** the friends-build push — see `docs/schedule.md` for the phase we're in.
> That doc sequences a subset of these items into dated phases; it does **not** replace this
> list. **This is the one checkbox list.** Tick per the gate in **Session workflow** step 6:
> code written *and* playtest-confirmed, never one without the other.

### Multiplayer / networking
- [ ] **Incoming `/tell` RPC** — receiving tells from other players (outbound done)
- [ ] **PvP flagging** — when is PvP permitted, how is it triggered, consequences;
  alignment kill deltas defined in `docs/concepts/alignment/events.md`. (Pet PvP
  inheritance landed 2026-06-11 — pets inherit the owner's `/pvp` flag on melee, spell, and
  AOE; see systems_overview.)
- [ ] **Pet buffs — AGI/INT/WIS combat mappings** — pets are stat-driven and take ALLY buffs
  (STR→pet melee dmg, Valor→max HP, Haste→attack speed, Spirit of Wolf→move speed, HoT,
  Thorns reflect) as of 2026-06-10 (`Entity` has `PrimaryStats` + `active_buffs`; see
  systems_overview). Still open: AGI/INT/WIS are stored + buffable but have no pet
  dodge / spell-power model yet, so they're display-only.
- [ ] **Player inspect** — right-click a player to see their equipment *(in progress:
  `scripts/inspect_window.gd`)*
- [ ] **LFG flag**, **Guild system**, **Dueling**, **Auction / bazaar**
- [ ] **Language system wiring** — `hear_language()` passive gain not yet called from the
  chat-receive path; needs multiplayer chat RPC + trainer NPCs
- [ ] **Quest reward item follow-ups** *(surfaced while closing quest phase 2; phase 2 itself
  shipped — see systems_overview)* — (a) the **Tarnished Silver Ring** (wolf_threat reward)
  equips but its **AGI +1 never applies** to the character sheet; ring-specific, since the gnoll
  boots apply their stats fine, so it is likely a bad stat block in the ring `.tres`. (b) The
  **Hunter's Medal** (rotfang_hunt turn-in, STR +2 / CON +2) was never re-tested landing on
  turn-in — `5ae6808` closed only the kill-credit + golden-orb complaints on that quest, not the
  item itself. Fix the ring; re-test the Medal. Evidence: `quest_phase2_sliceB_checklist.md`.

### Security / exploits
> Findings doc: `docs/security/exploit_audit_2026-07-08.md` (read-only audit, ran 2026-07-10/11).
> Finding #1 (ungated `/give`) is **fixed** (2026-07-16), and the **per-account `is_gm` keystone is
> DONE + playtested 2026-07-19** (server `82f55a9`, a green integration test, and
> `gm_access_checklist.md`): dev commands now gate on `conn.can_use_dev_cmds()` = `is_dev || is_gm`,
> so a hosted server runs with `PD_DEV_CMDS` off and grants tools to a GM account only (set it with
> the `grant_gm` bin). See systems_overview → "GM access + dev tooling". The rest below are still
> open, worst first. Framing from the audit: the server validates *magnitudes* well (damage, XP,
> heal amounts) but under-validates *eligibility/timing* (which weapon, which spell/class, is it
> time to swing, are you dead, did you finish the quest).

- [ ] **Server-side melee swing-rate limit** (High) — no swing timer on the connection, so a
  client can spam `Attack` for an attack-speed hack. Needs a server-tracked per-connection
  swing cooldown.
- [ ] **`Respawn` dead-check** (High) — the `Respawn` handler floors HP to 25% with no check
  that you actually died, so a living player can top up HP on demand.
- [ ] **CastSpell class/level gate** (Medium) — casting has no class/level validation except
  the resurrection arm, so any class can cast any spell it can name.
- [ ] **Assorted trust gaps** (Medium/Low) — `Attack` trusts the client's `weapon_path`; no
  login rate limiting; `BuyItem` ignores `vendor_id`; cross-store transfers persist as separate
  txns (crash-window dupe/loss; the corpse-loot path is the only atomic one); username
  enumeration on the auth path.
- [ ] **Unclean-kill relogin was not refused** — `banker_slice2_checklist.md:54` is ticked `[x]`
  but its own note reads *"Killed A's client, then immediately logged back in successfully"*,
  which contradicts the row's stated expectation and the design. This guard is what blocks the
  Lineage II force-off pattern (a live session should linger vulnerable ~30s after an unclean
  kill, and a relogin inside that window should be refused). Security-adjacent. Re-test first —
  it may not reproduce.

> **Closed by quest phase 2** *(no longer open)*: "CompleteQuest doesn't verify objectives".
> Slice A moved objective state server-side — a forged `CompleteQuest` now pays nothing because
> the turn-in is rejected until every server-counted objective is met. See systems_overview.

### Hosting / deployment
> New category. Nothing in the repo's history is a deployment; everything has run on localhost.
> This is the schedule's highest-risk phase (Phase 2) precisely for that reason. Blocked on the
> `is_gm` keystone above.
- [ ] **Stand up a deploy target + host it** — pick a target (VPS, or port-forward from the dev
  box); netcode private-key handling for a real host (the server refuses to boot without it);
  production env with `PD_DEV_CMDS` OFF and `is_gm` on your account only; client build pointed at
  the real host; refresh `README_FOR_TESTERS.md` (it predates ~10 weeks of work); confirm the
  in-game bug-report button still routes somewhere you read. Done = someone who is not you, from a
  machine that is not yours, makes an account, makes a character, kills something, logs out clean.

### Death / corpses
> The corpse epic **SHIPPED** (Slices 0-3 + the monster-orb unification, wire PD_W0018 to
> PD_W0022, committed 2026-06-22 to 06-26). Server-authoritative XP/leveling + death penalty,
> the corpse run (gear + coin to a persisted corpse, naked respawn, harsh decay), owner-only
> corpse retrieval, and Cleric/Paladin resurrection all exist. "What exists" now lives in
> `systems_overview.md` → "Death, corpses & resurrection"; the design + as-built deviations are
> in `docs/design/corpse_and_resurrection_plan.md`. Only the follow-ups below are open.

- [ ] **Res-sickness** — specced in the plan's Slice 3 but dropped from v1: a short debuff on
  res-accept (reduced stats/regen for a few minutes) via the server buff system. The last piece
  of the plan as written.
- [ ] **Respawn at bind / Soul Binder NPC** — respawn still honors the *client's* bind
  (`PlayerStats.bind_zone_path`); there is no server-authoritative bind and
  `ClientWorldMsg::BindAtCurrentLocation` is an inert wire variant with no server handler. Needs
  an NPC + server bind + a server-driven respawn teleport.
- [ ] **Corpse auto-re-equip on loot** — looting your own corpse returns gear to your bags; you
  re-equip by hand. A clean version needs the corpse to remember each item's equip-slot
  provenance.
- [ ] **Per-creature corpse models / scale** — corpses (player + mob) share
  `scripts/corpse_body.gd`'s capsule; needs authored per-creature meshes.
- [ ] **Tune `corpses::CORPSE_LINGER_SECS` for the considered production value** — **raised to 7
  days (604800 s) in Phase 0 (2026-07-17)** off the 300 s (5 min) test value (user-accepted
  without a separate playtest: a pure value change, mechanic unchanged), so a friend who dies deep
  can log off and corpse-run the next evening. What remains open is only Phase 4's *considered*
  production tuning (EQ used tens of minutes to days); 7 days is a fine friends-build value. The
  duplicate-name trap was resolved 2026-07-17 (the enemy-despawn constant is now
  `ENEMY_DESPAWN_LINGER_SECS`).

### Combat / weapons
- [ ] **Bard song rework** — songs are half-built: they auto-pulse client-only (never re-broadcast),
  so the server applies a song's effect once on cast and nothing sustains it; heal songs do a raw
  `set_hp` (HP-bar bounce, no buff-window entry). Make them server-authoritative + weaving-aware +
  buff-window-visible. A real subsystem, not a fix. Design note: `docs/design/bard_song_rework.md`.
- [ ] **Two-handed damage arc (cleave)** — large 2H weapons (axes/polearms) hit multiple
  enemies in a frontal cone on auto-attack, giving 2H its own identity vs. dual-wield.
  Per-weapon opt-in flag (not all 2H), narrow cone + secondary-target damage/cap so it
  doesn't trivialize multi-pulls; needs server-side resolution like spell AOE. Design note:
  `docs/design/two_handed_cleave.md`.
- [ ] **Attack while seated.** A character can auto-attack without standing up (spotted in the
  2026-07-16 dev-panel playtest). Standing should be required to swing. Worth checking whether
  the sit regen bonus still applies mid-fight: if it does, this is an exploit (free in-combat
  regen), not just an animation bug.
- [ ] **Named mobs lost enrage + guaranteed drops.** Both live only in client-side
  `data/named_mob_definitions.gd` with no server side, so every named mob is currently a generic
  mob wearing a name (e.g. Rotfang's guaranteed fang did not drop). Needs server-side named-mob
  stats + guaranteed/rare drop resolution. Flagged in `session_2026_07_11_dev_panel.md:79`.

### World systems
- [ ] **Mount system** — *`MountManager` autoload exists (client-side v1); feature is not
  fully wired* (server speed clamp, Animal Husbandry / Spirit-of-Wolf stacking / Selos'
  Melody interactions still pending)
- [ ] **Faction system** — race/class affects NPC standing; guards attack on sight
- [ ] **Weather system**; **Water & swimming** (breath/drowning); **Doors & locks** (lockpicking)
- [ ] **Zone transition effects** — fade/loading screen

### UI polish
- [ ] **Player portrait** in HUD *(slugify + slot landed; art pending)*; **Map / minimap**
- [ ] **Bank Items-tab does not live-refresh on deposit.** A deposited item visibly *vanishes*
  from the UI. The server stores it correctly and it returns on relog, so nothing is actually
  lost, but no tester will believe that — highest *perceived* severity on the friends-build list.
  Client-side `BankWindow` refresh. Repro in `quest_phase2_sliceA_checklist.md:99`.
- [ ] **Bags open on left-click instead of right-click.** `banker_slice2_checklist.md:57`.
  Untriaged; the tester's guess is these are stale pre-grammar bags. Should match the
  right-click quick-transfer grammar (`docs/design/inventory_interaction_grammar.md`).

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
