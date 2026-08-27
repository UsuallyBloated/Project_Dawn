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

### Hosted server (the R720) — live since 2026-08-10

There is now a **real hosted server**, not just localhost. A Dell PowerEdge R720 in the
basement runs Ubuntu Server 26.04 and serves the game over a private **Tailscale** tailnet at
`100.93.108.112` (auth TCP 8765, world UDP 7777). It runs under systemd as the `projectdawn`
service account from `/opt/projectdawn`, starts itself after a reboot, and backs up nightly.

**This changes where a playtest can happen.** Local `cargo run` is still the dev loop; the
R720 is where anything involving another person happens.

| Doc | Covers |
|---|---|
| `docs/deployment/server_operations.md` | **Start here.** Running, updating, recovering, triage. |
| `docs/deployment/inviting_a_player.md` | Onboarding one tester. |
| `docs/deployment/r720_host_setup.md` | How the machine was built, and why. |
| `server/docs/deployment_linux.md` | Deploying the app to a fresh Linux box. |

Three things to know before touching it:

- **It runs with `PD_DEV_CMDS` unset.** Dev tools come from per-account `is_gm` instead, which
  rides the signed connect token. Verify `dev_cmds=false` on the boot log line after **every**
  start; `true` means every connected player has `/give`, mob spawning and instant levels.
- **It deploys from GitHub, not from your working tree.** A server change only reaches it
  after being committed **and pushed**. The host tracks `fix/xp-leveling-overflow`, not the
  default branch. (A stale deploy on 2026-08-08 was running a six-week-old `main` with none of
  the Phase 1 exploit gates in it; the only symptom was a missing field in one log line.)
- **There is no graceful shutdown.** `systemctl restart` discards up to 60 s of position, HP,
  XP, inventory and coins for everyone online. Get people to log out first.

### Shipping a change to the R720

Client and server changes travel **different paths**. Client-side edits never touch the R720.

**Server change** (`F:\Projects\server`), reaches players after a restart:

```
git push                                  # from the dev box
# then on the R720:
sudo -u projectdawn -H bash
cd /opt/projectdawn/src && git pull && cargo build --release
cp target/release/projectdawn-server ~/ && exit
sudo systemctl restart projectdawn
journalctl -u projectdawn -n 20 --no-pager   # confirm dev_cmds=false
```

Forgetting the `cp` is the usual mistake: systemd runs `/opt/projectdawn/projectdawn-server`,
not the one under `target/release/`.

**Client change** (this repo), reaches players only via a **new build**:

```
git push
# re-export from Godot into builds/
#   confirm the export log shows: [BuildStamp] stamped <sha>
# send the new zip to testers
```

The R720 needs nothing. Testers keep running whatever executable they last received, so a
client fix is not live until they have a fresh build.

**Every export is stamped automatically** by `addons/build_stamp`, which derives the commit from
git at export time and injects it into the build. Nothing to remember and nothing to bump by hand.
A tester's build identifies itself three ways: bottom-right on the login screen, in the `debug.log`
header, and via `/version`. Two things worth knowing:
- **`UNSTAMPED BUILD` in red on the login screen means the addon is disabled.** Godot silently
  disables an addon whose script fails to load, and rewrites `project.godot` to match, so the
  `[editor_plugins]` enable line must stay committed. A build that can't identify itself is a
  broken build, not a cosmetic problem.
- **The stamp fingerprints `gdext_net.dll` separately** from the commit sha, because the DLL is
  gitignored and hand-copied into `builds/`. A client on a clean commit can still carry a stale
  wire layer, which presents as a server bug.

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
  — adding/editing one without the other causes drift. Quantified 2026-07-22: the client has
  156 spells, `spells.toml` has 124, so **~32 are client-only** and get dropped server-side as
  "unknown spell" (mana spent, no effect). Life Drain + Dark Shroud closed that day; the rest
  need server support first (9 `PORT` teleport/gate spells, prestige-class tags like
  `Paladin_Fallen`, `Warder's Mend` PET_HEAL) — see the To-Do "Client-only spell backlog".
  `tools/export_spells.gd` (Godot editor) is the intended regen path but is stale.
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
- **Right-click is the interact verb everywhere**: use/open in inventory, and (as a tap) talk /
  loot / mine / bank on world objects; **left-click only targets**. Free mouse to click UI
  (skill/spell buttons); hold **right-click** (drag) to engage camera
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
   `systems_overview.md` (not back into the to-do), and — if it closes a phase item — update
   **both** `docs/schedule.md` *and* `docs/schedule.html`. They are two hand-maintained copies of
   the same plan; the `.html` is what a non-repo reader opens, so a stale one is a wrong answer to
   an outside audience. (This step used to name only the `.md`, and the `.html` silently fell 11
   days behind through the whole Phase 1 push — it still read "In progress" after the phase had
   closed. Same drift the gate below exists to prevent, one file over.)

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
- **Commands you type** (CLI/cargo tools, server run wrappers, in-game chat commands, keybinds) →
  `docs/reference/commands.md`. Keep it current when a command is added or renamed.
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
- [ ] **Group-mate HP/MP/stamina never reach the group panel in launcher mode** — **STALE
  ENTRY, CORRECTED 2026-08-26: the fix was BUILT 2026-08-11** (client `5bde067`, the same day
  the bug was found); only the two-player playtest never happened, and this entry kept
  describing the bug as fully open for two weeks (evidence for the standing audit item).
  **What actually exists** (verified against code + git, not the old description): (a)
  `_flush_stats` has the launcher guard — launcher mode refreshes only the local row and never
  fires the legacy ENet RPCs, so the "unknown peer ID" flood is dead; (a+) the local row is
  keyed by `Net.get_player_id()` (server char_id), not Godot's `get_unique_id()`, so the
  mislabeling is dead too; (b) member bars are server-driven WITHOUT the new wire message this
  entry used to call for — the server already fans every player's HealthUpdate / ManaUpdate /
  StaminaUpdate to all in-world clients with no range culling, `GroupManager._apply_peer_stat`
  merges them into member rows, and `regen.rs` carries the broadcast policy (a swing >5% of max
  fans immediately; `MAX_BROADCAST_GAP` 500 ms keeps idle regen ticking). Cheaper than the
  design proposed here, and already in place. **Needs only a two-player playtest** —
  `group_stats_and_tells_checklist.md` (two accounts; one-char-per-account permits two-boxing).
- [ ] **Remote players never show a jump** *(reported 2026-08-14)*. Player 1 jumps; player 2 sees
  them slide along the ground. Nothing about a jump crosses the wire, and it's dropped in three
  separate places: (a) **the client never reports it** — `scripts/player.gd:444` is the only caller
  of `Net.send_movement()` and hardcodes `jumping = false`, even though `net.gd:374` and the gdext
  `send_move` both carry the flag; (b) **the server discards it** — `world/handlers.rs:487`
  destructures `jumping: _`; (c) **there's nowhere to put it coming back out** —
  `ServerWorldMsg::Position` (`protocol/src/world.rs:953`) carries only `pos / vel / yaw /
  sequence`, and the server zeroes Y on every Move (`handlers.rs:518`, *"server does not simulate
  gravity or jumping"*), so even the vertical displacement is gone. `RemotePlayer` interpolates
  pos + yaw only (`remote_player.gd:243`).
  **Two ways to do it.** Cheap/cosmetic: send the real `jumping` flag, have the server relay it as
  a one-shot event alongside the jumper's next Position, and let each remote client play its own
  hop locally. The server stays free of gravity. Expensive: real server-side vertical physics —
  much larger, and it buys anti-cheat we don't need yet. Prefer the cosmetic version; it's also
  the first piece of a general **remote animation-state** channel (jump now, swing/cast/sit poses
  later). Needs a gdext rebuild + client re-export either way.
  **Exploit note:** cosmetic-only is safe precisely because the server keeps owning XZ — a forged
  `jumping` flag can then only make you *look* silly, not move you. Don't let the flag become an
  input to position.
- [ ] **Incoming `/tell` RPC** — **STALE ENTRY, CORRECTED 2026-08-26: built 2026-05-28**
  (`195891d`, "Chat wire-up: /say /shout /ooc /tell over the network"). The server fans
  `ChatMessage` to the single Tell target and `combat_log.gd:150` renders "%s tells you" into
  the Tells (In) channel — the full loop has existed for three months and was simply never
  exercised by two players. Rides the same two-player playtest as the group panel
  (`group_stats_and_tells_checklist.md`).
- [ ] **PvP flagging** — when is PvP permitted, how is it triggered, consequences;
  alignment kill deltas defined in `docs/concepts/alignment/events.md`. (Pet PvP
  inheritance landed 2026-06-11 — pets inherit the owner's `/pvp` flag on melee, spell, and
  AOE; see systems_overview.)
- [ ] **Pet buffs — AGI/INT/WIS combat mappings** — pets are stat-driven and take ALLY buffs
  (STR→pet melee dmg, Valor→max HP, Haste→attack speed, Spirit of Wolf→move speed, HoT,
  Thorns reflect) as of 2026-06-10 (`Entity` has `PrimaryStats` + `active_buffs`; see
  systems_overview). Still open: AGI/INT/WIS are stored + buffable but have no pet
  dodge / spell-power model yet, so they're display-only.
- [ ] **Pet level does not scale with owner level** *(found 2026-08-26: a level 22 Beast Master's
  warder is level 5)*. User call: pet levels need adjusting; the rule is TBD — discuss before
  building (likely the warder tracks owner level, EQ-style). Server-side (pet spawn stats).
- [ ] **Player inspect** — right-click a player to see their equipment *(in progress:
  `scripts/inspect_window.gd`; noted 2026-08-26: the wire round-trip already exists —
  `broadcast_inspect_player` / `world_inspect_result` — so this may be further along than "in
  progress"; settle it in the audit pass)*
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
> the `grant_gm` bin). See systems_overview → "GM access + dev tooling". The **`Respawn` dead-check**
> (finding 3) is **DONE + playtested 2026-07-20** (server `0d908d1`, integration test
> `respawn_requires_being_dead`): `Respawn` gates on `conn.death_processed`, so a living player's
> Respawn is a no-op (no HP top-up). The **CastSpell class/level gate** is **DONE + playtested
> 2026-07-22** (server `a96826d`, `cast_class_level_gate_checklist.md`): the cast resolver rejects a
> `CastSpell` unless the caster's class is in the spell's `classes` and their level meets `min_level`,
> checked before any mana / cooldown / skill side effect; the regression sweep passed with zero gate
> rejections in `server.log`. The **`Attack` weapon_path trust gate** (finding 5) is **DONE +
> playtested 2026-07-23** (server `9089b4b`, `attack_weapon_path_checklist.md`): the resolver derives
> the swung weapon from the server's equipment map (`PerConnection::equipped_weapon_path`, slot 0
> main / 1 off) instead of the client's claim, so a modified client can't swing a weapon it hasn't
> equipped; regression sweep (melee / unarmed / dual-wield / ranged / range) all passed. The
> **melee swing-rate limit** (High) is **DONE + playtested 2026-07-29** (server `335b5b1`,
> `swing_rate_limit_checklist.md`): a per-connection, per-hand minimum swing interval derived from
> the equipped weapon's `weapon_delay` (assumes max haste so hasted players never trip; drops "too
> fast" same-hand swings silently, advancing the timer only on accepts). Adversarially reviewed (3
> lenses); folded in a HIGH bypass fix — an off-hand Attack with an empty slot 1 (a forged free
> fist-damage stream) is now rejected. Regression sweep passed with zero base-swing false positives;
> the only `server.log` rejections were Flamebrand's proc (a known client-driven second Attack, see
> the server-procs To-Do). The **login rate-limit + auth-timing gate** is **DONE + playtested
> 2026-07-31** (server `a75d9d0`, then `6cddff2` / `fcfdf9a` / `339ea97`,
> `login_rate_limit_checklist.md`): a per-IP attempt cap on Login **and** Register
> (`LoginRateLimiter`, 5 per 60 s, atomic check-and-reserve, a login success clears only the Login
> budget) plus a dummy Argon2 verify on the no-user path so response timing can't leak account
> existence. Two playtest-found bugs were fixed during the run: the original loopback exemption made
> it untestable *and* unprotected on localhost (dropped), and the launcher's auto-login after a
> Register cleared the shared counter so Register never throttled (Login/Register now hold separate
> per-IP budgets). Throttle rejections log at INFO with the client IP for operator visibility.
> **This was the last Phase 1 exploit gate — the phase is complete.** Framing from the audit: the
> server validates *magnitudes* well (damage, XP, heal amounts) but under-validates
> *eligibility/timing* (which weapon, which spell/class, is it time to swing, are you dead, did you
> finish the quest).

- [x] **Assorted trust gaps** (Medium/Low) — *(`Attack` weapon_path and login rate-limiting +
  auth-timing are both DONE + playtested — moved to the blockquote above.)* The last gap —
  `BuyItem` ignoring `vendor_id` — **closed 2026-08-26 by the NPC proximity gate** (vendor_id is
  now honoured and range-checked; evidence in `proximity_gate_checklist.md`).
  **Cross-store transfer atomicity (finding 8) is DONE + playtested 2026-08-21** (server
  `393cc64`, `atomic_transfers_checklist.md`: bank, vendor and death paths all clean). An item never simply changes, it *moves*, and every move spans
  two tables: a bank deposit touches `character_items` + `bank_items`, a vendor sale touches
  `character_items` + the wallet, and death touches both plus `corpses`. Each store had its own
  write function opening its own transaction with an `.await` between, so a crash in that gap either
  **lost** the item or **duplicated** it — and the dupe is the worse half, because losses get
  reported and dupes get exploited quietly. New `db::save_stores_atomic()` writes every store for a
  connection in one transaction, used by **both** the periodic checkpoint and the disconnect flush
  (both had the window). Death was the sharpest case: it wrote the corpse, then stripped the player
  in two further separate writes whose errors were discarded with `let _ =`, so a crash mid-strip
  duplicated the player's coin outright. `save_corpse` now takes `strip_owner` and clears the
  owner's inventory and wallet **inside the corpse transaction**. Regression test:
  `save_corpse_strips_the_owner_in_the_same_transaction`. Suites: 181 unit green, 41/42 integration
  (the one failure is the known-flaky `pet_pulls_aggro_via_threat_reaggro`, which passes alone).
- [ ] **Login rate limit is too tight for real humans** *(found 2026-08-11, first external
  tester)* — the Phase 1 gate is 5 attempts per 60 s per IP. The tester logged out, tried to log
  back in, tripped it (`Login rejected — rate limited ... window_secs=60 max_attempts=5`), and
  **created a second account rather than waiting**. She now has two accounts and two characters,
  and there is no account-deletion tooling to tidy that up. The gate worked exactly as designed;
  the problem is the threshold. Note the threat model has also changed: nothing can reach 8765
  without being on the tailnet, so brute-force risk is currently near zero while the usability
  cost is demonstrated. Options: raise to ~10 per 60 s, or keep 5 over a 5-minute window. Server
  change (`LoginRateLimiter`), so it needs a push, a pull on the R720, a rebuild and a restart.
- [ ] **No way to reset an account password** *(requested 2026-08-14)*. A tester who forgets their
  password is locked out permanently, and their only recovery is registering *another* account —
  which is exactly how the duplicate accounts in the item above happened. Nothing in the server can
  change a password today: `db/mod.rs` hashes on `create_account` (`:76`) and verifies on login
  (`:162`), and there is no `ChangePassword` wire message, no `set_password` DB call, and no ops
  bin for it (the crate's only ops bins are `admin_report` and `grant_gm`).
  **Scope it as an operator tool first, not a self-serve flow.** `accounts.email` exists
  (`migrations/0001_init.sql:12`) but is nullable, nothing collects or verifies it, and there is no
  mail path; the server is also reachable only from inside the tailnet. So an emailed reset link is
  both unbuildable and unnecessary right now. The friends-build answer is a `reset_password` bin
  next to `grant_gm`: `cargo run -p projectdawn-server --bin reset_password -- <username>`, argon2
  the new password, write it, **and delete that account's rows from `sessions`** so a live session
  can't outlive the reset.
  **Exploit note:** a later in-game or launcher-facing "change my password" needs three things an
  operator bin doesn't: the *old* password re-verified, its own rate-limit budget (`LoginRateLimiter`
  is keyed to Login and Register only, so a change-password endpoint would be an unmetered Argon2
  oracle), and the same session invalidation. That's the argument for doing the bin first.
- [x] **Server move-merge ignores `stack_size`** — **DONE + playtested 2026-08-21** (server
  `393cc64`, §5 of `atomic_transfers_checklist.md`). A playtest had built a **41-stack of Bread
  Loaf** whose cap was 10, because the move paths merged with a bare `saturating_add`. The helper
  `items::max_stack()` already existed with **zero callers** outside the deposit path. New
  `merge_capped()` backs all five move-merge sites, filling the destination and leaving the
  remainder in the source; the split path rejects instead, since it names an explicit count.
  Log proof: three consecutive `DestroyItem ... bread_loaf count=20` rather than one 60-stack.
- [ ] **Silent refusals: the server refuses without telling the client** *(found 2026-08-21 as
  the vendor bug; **audited and BATCH 1 BUILT 2026-08-23**, server-only; playtest
  `silent_refusals_checklist.md`)*. The server validates well but **reports** poorly: it logs a
  refusal and moves on, sending nothing. The client then keeps a stale view (the 08-18 inventory
  desync, which lasted until relog) or announces a success that never happened ("Ordered X" while
  the server refused for full bags). An audit counted **62 silent rejection arms against 40 that
  answer**.
  **The fix costs nothing to ship.** `ChatMessage` on the System channel is already encoded,
  decoded by gdext, re-emitted by `Net`, and rendered unattributed by `CombatLog` — so
  `handlers::send_refusal()` needs **no protocol bump, no gdext rebuild and no client re-export**.
  Do **not** build on `ServerWorldMsg::Error` or `BroadcastMessage`: both have zero senders and are
  absent from gdext's `Incoming` enum, so they would be silently discarded — the very failure being
  fixed. Prefer private `send_refusal` over `fan_out_cast_fail`, which broadcasts and would leak a
  caster's failures to bystanders.
  **Batch 1 done (16 sites):** all 6 `BuyItem` arms, all 7 `SellItem` arms, and the three worst
  spell arms. The spell ones matter most because **the client spends mana, starts the cooldown and
  applies local buffs BEFORE it sends the cast**, so a refusal drained the bar for nothing. The
  unknown-spell arm (the ~32 client-only spell backlog, so it fires in ordinary play) now **also
  refunds the mana** with `fan_out_mana_update` — the server never deducted it, so sending its own
  true value corrects the client's optimistic spend, the same principle as `correct_client_slots`.
  **Batch 2 still open**, in the audit's priority order: the rest of the inventory family
  (`EquipItem`, `UnequipItem`, `SplitStack`, `DropItem`, `DestroyItem`, `UseConsumable`), the
  remaining 8 post-mana-deduct cast arms, the 10 group arms (6 of which have **no server log
  either**, so a failed `/kick` is invisible on both sides), and `BindAtCurrentLocation`, whose
  client claims success unconditionally and could quietly rebuild the death loop.
  **Deliberately left silent** (confirmed correct): anti-cheat gates, dev/GM authorization (a reply
  is an oracle for whether `PD_DEV_CMDS` is on or an account is GM), transport/lifecycle gates, and
  rejections only a forged client can reach.
  **Also found:** 9 declared wire intents have no handler at all (`UseSkill`, `CancelCast`,
  `StackAll`, `Interact`, `DialogueResponse`, `TurnInQuest`, `StartCombine`, `StartMining`,
  `StartSkinning`) — they hit `_ => Outcome::Continue` with no log and no reply. **Audited
  2026-08-24**; the outcome is the three items directly below, plus these dispositions to save a
  re-audit: `StackAll` and `TurnInQuest` are correctly dead (superseded by `MoveItem` and
  `CompleteQuest`) and could be deleted from the protocol; `Track` needs no wire message and works;
  `Interact`/`DialogueResponse` as *conversation* are fine client-local, but the *proximity gate*
  a real `Interact` would have provided was never built — see the first item below.
- [x] **No server-side proximity gate on vendor / bank / quest turn-in** — **DONE + playtested
  2026-08-26** *(found 2026-08-24; built 2026-08-25, server `3b5359e`;
  `proximity_gate_checklist.md`: honest town play completely unaffected — zero range refusals
  during ordinary play — and the gate proven at ~190 m out: four
  `bank op rejected — no banker within range` log lines with the chat refusal shown. The only
  unexercised row is the die/corpse-run regression, whose path this change does not touch —
  corpse loot has its own pre-existing range check. What exists is in systems_overview →
  NPCs/vendors.)*. Because `Interact` was never built, the server has no NPC
  position model, so nothing checks *where the player is standing*. Confirmed against `tick.rs`:
  combat, spell targeting, resurrection (`RES_CAST_RANGE`), corpse loot and loot bags
  (`LOOT_PICKUP_RANGE`) all range-check; **vendor, bank and quest turn-in do not**. A modified client
  can therefore: (a) `BankStoreItem` its whole inventory from the bottom of a dungeon one second
  before dying, so the corpse holds nothing and the **gear-loss half of the death penalty is
  voided**; (b) buy/sell with no vendor nearby, and buy any `items.toml` entry with `vendor_price>0`
  regardless of which vendor stocks it (`BuyItem`'s `vendor_id` is explicitly informational); (c)
  turn in quests, collecting real server-granted rewards + XP, without walking to the NPC. An honest
  client cannot (a 6 m gate lives at `hud.gd`), which is exactly why the gate must move server-side.
  **Not a mint** — no items/coins/XP the server did not authorise; coins are spent at registry
  price and quest objectives are still verified. Medium because it nullifies a *designed consequence*
  (corpse-run stakes) and vendor access control is currently decorative.
  **Fix:** a small static NPC-position table (toml alongside `items.toml`), then honour `vendor_id`
  and range-check `BuyItem`/`SellItem` against that vendor, the four bank ops against the banker, and
  `CompleteQuest` against the quest's turn-in NPC — copying `RES_CAST_RANGE`/`LOOT_PICKUP_RANGE`.
  **Closes the standing "`BuyItem` ignores `vendor_id`" gap and the Banker proximity gate deferred
  from the Banker MVP, in one pass.** Server-only: push + R720 restart (the client dialogue tweak
  — dropping the optimistic bind line — is cosmetic and rides the next export).
  **Built as:** new `npcs.toml` + `world/npcs.rs` position table (mirror of `world.tscn`, same
  lockstep as items/quests), `NPC_SERVICE_RANGE = 15 m` (looser than the client's 6 m UI gate — a
  remote-abuse backstop, never refusing an honest player; a unit test enforces that the starter
  spawn reaches every town NPC). Gated: BuyItem/SellItem (vendor), all five bank loops (banker —
  the death-penalty arm), CompleteQuest (new optional `turn_in_npc` in quests.toml; dev quests
  stay ungated), BindAtCurrentLocation (soul_binder). Two integration tests prove it directly: a
  buy from 200 m out is refused with no coin change, the same char at spawn buys fine.
- [x] **Tradeskills create phantom items and can cause real item loss** — **DONE + playtested
  2026-08-24** (client `a065a19`, `tradeskill_guard_checklist.md`: every online row passes; the
  three Test Room regression rows were skipped, offline path untouched by inspection). What exists
  is in systems_overview → Items/economy. Mining, crafting and skinning now refuse honestly in
  launcher mode ("isn't available online yet") **before touching anything**, closing both the
  phantom-item ghost and the sharp edge — crafting deleting real ingredients from the client
  mirror and desyncing slot indices so a legitimate Sell/Destroy hit the wrong real item. Log
  proof: Pickaxe + ore in hand, zero tradeskill wire traffic, and a post-refusal inventory
  shuffle with zero `source slot empty` rejections. **Real server-authoritative tradeskills**
  (the CompleteQuest pattern) remain a later build — tracked under Tradeskill depth.
- [ ] **Active skills partly do not work online, and three abort with silent runtime errors** *(found
  2026-08-24; **GUARDS BUILT 2026-08-25, pending playtest** — `active_skill_guards_checklist.md`,
  rides the pending re-export; content gap, no security surface — the swing-rate limiter blocks skill-spam abuse)*.
  Three failure modes at once: (a) **damage multipliers discarded** — Backstab 3.0x, Harm Touch
  2.5x, Aimed Shot 3.0x, Flying Kick 2.2x go through `combat.gd:368` as a plain `Attack`, so the
  server rolls a *normal* swing and the multiplier is worth nothing; worse, that Attack shares the
  main-hand swing-rate limiter with auto-attack, so a skill fired mid-cycle is dropped for zero after
  the client already spent stamina + started a 6-20s cooldown. (b) **Three effects throw silent
  GDScript errors** — Shield Bash (`stun`), Feign Death (`feign_death_deaggro`) and Warder's Fury
  (`set_attack_target`) call methods that exist only on the *local* `Enemy`/`Pet`, which do not exist
  in launcher mode; the calls abort mid-function and are invisible (engine errors do not reach
  `debug.log` or the console). (c) **Evade/Hide/Holy Shield are decoration** — consumed only in
  `Combat.receive_player_damage`, which is not called for server-dealt damage.
  **Cheap correctness now:** `has_method()` guards / no-op stubs on `RemoteEnemy`/`RemotePet` for
  `stun`/`root`/`snare`/`feign_death_deaggro`/`set_attack_target` (matching the existing
  `get_spell_resist` precedent) so a missing method degrades to nothing-happens instead of aborting;
  and redirect Warder's Fury to `PetManager.command_attack`, which already has a working launcher
  branch (a one-line fix). Real server-authoritative active skills are their own build. Also correct
  the **stale comment at `tick.rs:3603`** claiming a client-side movement cast-cancel that does not
  exist, before someone trusts it as a backstop.
  **Built 2026-08-25:** STUN / FEIGN_DEATH / EVADE / ABSORB / STEALTH skills now refuse honestly
  online *before* any stamina or cooldown is paid (the tradeskill rule: refusal beats placebo);
  damage skills stay usable as normal swings. Warder's Fury routes through
  `PetManager.command_attack`, so the warder actually attacks online. CC no-op stubs added to
  `RemoteEnemy` (stun/root/snare/attack-slow/silence/feign-deaggro) and `RemotePet`
  (set_attack_target/heal) — **the audit undersold this**: the spell paths call
  root/snare/slow/silence directly on the target too, so every CC spell against a server enemy was
  aborting its own cast function mid-way. The stale `tick.rs` comment is corrected (server
  `9b320c8`): that movement gate is the ONLY cast-movement defence, not a backstop.
  **Still open in this item:** the discarded damage multipliers (needs a server skill model), and
  real server-side enemy CC (stun/root/slow as replicated state) — both server builds.
  **Guards playtested 2026-08-26** (`active_skill_guards_checklist.md` §1-3 all pass: refusals
  cost nothing, damage skills still swing, CC casts complete cleanly; the offline §4 rows are
  retired permanently — there is no offline version of this game). One new finding folded in:
  **Warder's Fury only engages when the warder is already beside the target** — the command lands
  but the pet does not path to the enemy first; server pet-AI follow-up for the server build.
  The playtest also surfaced how skills reach the player at all: the book window (B) now has a
  **Skills tab** with pickup-and-place hotbar assignment (client `274f015` + `c697cde`; the old
  "Assign Skill..." context menu is removed at user direction — it never worked from the
  tester's seat).
- [x] **Right-click is the world-interact verb** — **DONE + playtested 2026-08-24** (client
  `fa2ff04`, all 13 rows of `right_click_interact_checklist.md`). One mouse grammar everywhere:
  right-click (tap) interacts — NPC talk/vendor/bank, corpse + bag loot, veins, stations,
  skinning — left-click only targets, a right-*drag* is still the camera (same 6px threshold as
  left-click targeting), and the proximity-F chain is retired for bot resistance. Corpses:
  left-click keeps targeting for res casts; right-click targets AND loots. The camera section
  playtested clean — drags starting over NPCs/corpses open nothing. Central router
  `Targeting.interact_at()`; ranges unchanged from the F values. The same session also exercised
  a full death→res cycle on the 08-23 offer-consumption rewrite (`refund=82156`), verifying the
  riskiest recent server change incidentally.
- [ ] **`CancelCast` is a missing feature, not a broken one** *(found 2026-08-24; **BUILT
  2026-08-25, pending playtest** — `cancel_cast_checklist.md`, rides the pending re-export)*.
  Movement (WASD/jump/autorun) and ESC now abort a live cast — ESC cancels the cast *before*
  touching windows — with "You stop casting." and an immediate **mana refund**. The refund is the
  substance: mana is spent optimistically at cast start, but the server only deducts when the
  completed cast arrives, so on every cancel path (deliberate, and server interrupts too, which
  share `cancel_cast`) nothing was ever truly taken and the client now says so instantly. This
  also makes the corrected `tick.rs` movement-gate comment's ideal true: the client genuinely
  cancels on movement now, with the server gate as the forged-client backstop it was meant to be.
  **No wire change**: the dead `CancelCast` intent stays unsent — a dangling server-side CastStart
  cache is overwritten by the next cast's own CastStart, so client-only cancel is clean. That
  intent is now confirmed deletable alongside `StackAll`/`TurnInQuest`.
  **Deliberate call, flagged not decided:** an interrupted cast also refunds (consistency with
  server truth). Classic-EQ interrupts *eat* the mana; wanting that is a server design change —
  deduct at CastStart — not a client tweak. One cosmetic gap: peers' view of a cancelled cast bar
  runs out on its own (telling them needs the wire intent + a gdext rebuild; not worth it yet).
  **Playtested 2026-08-26** (`cancel_cast_checklist.md`): every row passes except
  hit-while-casting, which never fired (zero `interrupted (hit during cast)` lines in the log —
  unexercised, not failed; the server's Track 19A channeling roll is real). The tester's "mana
  refunded then immediately consumed again" observation was **triaged as the immediate re-cast's
  own optimistic spend, not a refund failure**: the chat log shows a *completed* Regrowth right
  after the cancel (feel-effects + "You cast" + Alteration skill-up — lines only a finished cast
  produces), and client regen is launcher-gated so no drift alternative exists. Tick waits on one
  15-second re-check: cancel and touch nothing; the bar must stay refunded.
- [ ] **Bank coin deposit will not break a larger coin** *(found 2026-08-21; **BUILT 2026-08-21,
  pending playtest** — `Coins::take_breaking_higher`, applied to deposit AND withdraw)*. With
  `1p 5g 5s 75c`, depositing `6s` is refused ("You don't have that coin to deposit") rather than
  breaking a gold into silver. The four tiers are **deliberately independent stacks** with flat
  per-coin weight, so auto-breaking would cut against that design. A design call, not a bug: either
  the banker breaks coin as a service (fits the Banker's "relief valve" role), or the refusal
  message should explain the tier rule instead of sounding like a bug.
- [ ] **Coin normalises through a corpse, which changes its weight** *(found 2026-08-21; **BUILT
  2026-08-21, pending playtest** — corpse loot now returns coin tier by tier)*. Died
  with `1p 5g 7s 312c`, looted back `1p 5g 10s 12c`. The **value is identical** (312c = 3s 12c) so
  nothing is lost, but the game charges *flat weight per coin*, so 312 coins became 15 and the
  player returned lighter than they died. Dying compresses your coin. Minor, but exploit-shaped:
  a player carrying a large copper float could deliberately die to shed weight. The corpse stores
  a total and reconstitutes it normalised; preserving the original per-tier split would keep the
  four-independent-stacks design honest.
  **Fixed at `tick.rs`'s corpse-loot block**, which flattened the corpse to `total_copper()` and
  added it back with `add_payout` (which normalises). It now returns the corpse's coin with
  `add_each`, tier by tier: what went onto the body is what comes back off it.
- [ ] **Stack All scope** *(requested 2026-08-21; **BUILT 2026-08-21, pending playtest** — both the
  hosted and offline paths now consolidate within a container only)*. Ask for it to consolidate only within a
  container rather than across the whole inventory. The tester's note is cut off mid-sentence, so
  **the exact rule wanted needs confirming** before building anything — most likely "merge within a
  bag, and within the base slots, but never move items between the two".

- [ ] **Audit the schedule and the To-Do for accuracy end to end** *(raised 2026-08-24 by the user:
  "the schedule seemed a bit fucked... it's just a pile of inaccurate information. Some boxes are
  checked, and others aren't even though the task is listed as Done. This needs a review or 10.")*.
  **The concern is well founded**, and there is hard evidence: on 2026-08-24 `schedule.md` and
  `schedule.html` were found drifted in **opposite** directions (named mobs done in one and open in
  the other, atomic transfers stale in both, and neither carried the `stack_size` cap or the
  silent-refusal work). Either file read alone looked plausible, which is the worst kind of wrong.
  Fixed in `433fc69`, but that was one spot check, not an audit.
  **Suspected causes, to confirm rather than assume:** (a) the tick gate says update both schedule
  copies in the same pass, and that has been missed more than once; (b) work that arrives as a
  *finding* rather than a planned bullet (the whole refusal audit) never gets added to the schedule
  at all, so the phase looks emptier than it is; (c) the To-Do and the schedule describe the same
  work in different words, so neither reads as authoritative; (d) **six of the eight closed Phase 3
  items were originally recorded under a cause that was wrong**, so even accurate checkboxes sit
  next to inaccurate descriptions.
  **Scope when picked up:** walk every schedule bullet and every To-Do entry against the session
  notes and the git history, reconcile the two schedule copies line by line, and decide whether the
  schedule should keep prose descriptions at all or just point at the To-Do. Worth doing as its own
  pass with fresh eyes, not squeezed alongside feature work.

- [ ] **Gate and the Soul Binder use two different bind points** *(found 2026-08-24 while
  playtesting the refusals)*. Binding at Sister Maelis then casting Gate says *"You have no bind
  point. Cast Bind Affinity first."* **There are two unconnected bind concepts:**
  | | Set by | Read by |
  |---|---|---|
  | **Server bind** (`bind_x/y/z`) | the Soul Binder, via `broadcast_bind_at_current_location()` | **Respawn** |
  | **Client bind** (`PlayerStats.bind_zone_path`) | casting Bind Affinity, `spells.gd:446` | **Gate** (`spells.gd:136`) |
  The NPC sets the one Gate does not read. Casting Bind Affinity then sets the *client* field
  locally — while the server refuses the BIND target type, which is now the "That magic has no
  effect here yet." line — after which Gate starts working. That is the exact sequence the tester
  hit.
  **And Gate returns you to where you cast it**, because `set_bind_point(zone_path, "default", ...)`
  stores a **zone and entry id, not a position**, so Gate resolves to the zone's default entry. In a
  one-zone game that is roughly where you stand. Succor behaves the same way.
  **Fix direction:** one bind, server-owned, **as its own sprint** (agreed 2026-08-24). The server
  already persists a real position; the client should learn it (there is no message carrying it —
  the 2026-08-23 bind confirmation is chat text, not data) and Gate should read that rather than its
  own legacy field, which is vestigial from the offline era. Deliberately not patched quickly,
  because this is the bind system that produced the first tester's unwinnable death loop.
  **Sprint scope, and it is smaller than the To-Do implies.** The "9 PORT spells" line
  miscategorises the work:
  | Spell | Actually blocked on |
  |---|---|
  | Gate, Succor, Evacuate | **server handling** — implementable now, no new content |
  | 4x `Teleport:`, 3x `Circle of` | **seven zone scenes that do not exist** (`scenes/zones/` has never existed) — content, not engineering |
  So the sprint is: server-side `PORT` for the bind-return / same-zone cases (3 spells), server-side
  `BIND` for Bind Affinity, a wire addition so the client learns its bind position (protocol bump,
  gdext rebuild, re-export), Gate reading it, and retiring `PlayerStats.bind_zone_path`. Server
  support for the other seven would be moot — there is nowhere to send anyone.
- [ ] **The vendor window claims a quantity and price the server never agreed to** *(found
  2026-08-24; **BUILT 2026-08-24, pending playtest** — client `vendor_window.gd`, needs a
  re-export)*. Chat correctly said "Only 7 fit in your bags." while the vendor dialog said
  "Ordered Honey x20 for 1s." `vendor_window.gd:366-370` prints its success line the instant it
  sends, using a quantity and a price it computed **itself**, before the server has answered. The
  server half is fixed (it now reports every refusal); this is the remaining client half.
  **Fixed by describing the REQUEST, never the outcome:** "Asked the merchant for Honey x20." and
  "Offered Iron Short Sword to the merchant.", with no price asserted. The outcome is the server's
  to report — a refusal arrives as a chat line, a success shows up as the items and coin actually
  changing. The sell path had it worse and got the same treatment: its price was computed locally as
  `vendor_price / 2` for an intent with **seven** silent refusal paths, so a player could be shown a
  coin total for a sale that never happened.
  **Note this is not a shift of authority.** The vendor transaction has been server-authoritative
  since Track 14 — the server looks up the item, computes the price from `vendor_price`, validates
  coin and bag space, charges, and fans `CoinsUpdate` + `InventoryDelta`. The client was only
  narrating an outcome it could not know. The offline paths still transact locally and keep their
  "Purchased" / "Sold" wording, which is accurate there.

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
> **DONE + playtested 2026-08-11.** The game is hosted on a physical Dell PowerEdge R720 over
> Tailscale. What exists is in `systems_overview.md` → "Hosted deployment (the R720)"; how to
> run it is in `docs/deployment/server_operations.md`; the session evidence is
> `docs/playtest_notes/first_external_tester_2026_08_11.md`.
- [x] **Stand up a deploy target + host it** — **CLOSED on tester evidence 2026-08-11.** A
  second person, on a machine that is not the operator's, connected over the tailnet,
  registered account 2, created a character, killed a Plague Rat (`kill credit granted
  killer=2`), grouped, and logged out clean (`client requested disconnect char_id=2`) — with no
  `GM account connected` line, confirming she held no elevated access. That is the definition
  of done, met by someone other than the author.

> **Two findings came out of that first session** and are open below: the respawn death-loop
> (Death / corpses) and the login rate limiter forcing a duplicate account (Security).

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
- [x] **Respawn at bind / Soul Binder NPC + a real death state** — **DONE + playtested 2026-08-13**
  (proof: after die/respawn/logout the character's `pos` equals `bind_x/z` to every decimal, where a
  fallback would have written 0/0). What exists is in systems_overview → "Respawn, bind points, and
  the death lock". Playtest found and fixed two follow-ons: mobs kept beating the corpse (server
  `97c7fac`) and the corpse twitched on movement keys (client `80cbf55`). **The §6 regression sweep
  passed 2026-08-14** — the death path was the real risk of this change, and it is intact: the
  de-level penalty fired (`36` to `35`), the corpse was created with gear (`item_stacks=3`),
  Reclaim Soul offered/accepted with an XP refund (`45372`), and the corpse looted empty and
  despawned. Three cosmetic rows remain unexercised (bind-while-dead refusal, offline Test Room
  respawn, corpse-at-death-site as its own row); see `respawn_bind_checklist.md`.
  *(was: BUILT 2026-08-12, server
  `9e42a76` + gdext `c576d75` / client `973e846`, pending playtest.)* Respawn is now
  server-authoritative: it teleports you to your **bind point**, or the **starter spawn** when
  unbound, never the death site. **Sister Maelis** (Soul Binder, at the town spawn) sets the bind via
  a new `bind_soul` dialogue action, wiring up `BindAtCurrentLocation` (a dormant wire variant that
  had no sender AND no handler). Migration `0011` adds `bind_x/y/z`; the pre-existing `bind_zone` is
  reused and the `bind_entry`/`bind_zone_name` TEXT columns stay dormant (they modelled the old
  client-local save). A **death lock** refuses `Move` while dead. Binding is refused while dead so a
  corpse can't bind where it fell.
  **Root cause was not the missing bind.** `Respawn` restored HP but never touched *position*, and
  the server owns position — so the client's own respawn move (seeded in `player.gd`) was overridden
  by the next Position broadcast and you were dragged back to your corpse. `player_death.gd` now
  defers to the server's Teleport in launcher mode.
  **Requires a client re-export** (gdext gained the bind send). Playtest:
  `respawn_bind_checklist.md`. Deliberately NOT included: post-respawn invulnerability (a safe
  respawn location should make it unnecessary — revisit if the playtest says otherwise).
  Original evidence: `docs/playtest_notes/first_external_tester_2026_08_11.md`.
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
- [ ] **Proc follow-ups** *(the server-authoritative proc core shipped + playtested 2026-07-31, PD_W0025
  — see systems_overview)*: (a) **elemental resist for procs** — the server has no enemy-resist model
  at all, so proc damage is flat; needs resist fields on `MobTemplate`/`Entity` first. (b) **PvP-player
  procs** — procs fire on enemies/pets only; the PvP branch has no server death cascade, so it was
  left out of v1.
- [ ] **Bard song rework** — songs are half-built: they auto-pulse client-only (never re-broadcast),
  so the server applies a song's effect once on cast and nothing sustains it; heal songs do a raw
  `set_hp` (HP-bar bounce, no buff-window entry). Make them server-authoritative + weaving-aware +
  buff-window-visible. A real subsystem, not a fix. Design note: `docs/design/bard_song_rework.md`.
- [ ] **Two-handed damage arc (cleave)** — large 2H weapons (axes/polearms) hit multiple
  enemies in a frontal cone on auto-attack, giving 2H its own identity vs. dual-wield.
  Per-weapon opt-in flag (not all 2H), narrow cone + secondary-target damage/cap so it
  doesn't trivialize multi-pulls; needs server-side resolution like spell AOE. Design note:
  `docs/design/two_handed_cleave.md`.
- [ ] **Seated-combat penalties (EQ-style)** *(follow-ups the attack-while-seated fix surfaced;
  that fix — a swing stands the attacker, and the seated regen bonus is suppressed in combat —
  shipped + playtested 2026-07-20, server `3bb9b6d` / client `9303682`)*: (a) a seated player should
  take **bonus damage** and be a **bonus crit target** (higher crit chance + crit damage against
  them); (b) **taking damage should stand you up** (another stand trigger, alongside movement +
  attacking). Both EQ-authentic; neither is in the shipped fix.
- [x] **Named mobs lost enrage + guaranteed drops** — **DONE + playtested 2026-08-21**
  (server `393cc64`, `named_mobs_checklist.md`). What exists is in systems_overview → Combat.
  **They were never placed in the world**, which the old wording missed: no scene or spawner ever
  set `named_mob_id`, so even offline the only way to meet one was the Test Panel. Now server-side
  via `named.rs` + `named_mobs.toml`, with three hooks each chosen as the single place that covers
  every case: scaling in `Entity::from_spawn`, enrage from the once-per-tick AI sweep (enemy HP is
  cut in six places with no shared helper), and loot folded into `roll_for_mob`, which all three
  kill paths already call. `DevSpawnMob` recovers the id from the name the client already sends, so
  the Test Panel spawns a real one with no wire change.
  **The log confirms every number:** `max_hp=175.0` (50 x 3.5, scaled once — 612 would be double),
  `raw_amount=9` calm (5 x 1.8), `named mob enraged` at 27/175 = 15.4%, then `raw_amount=13`
  (9 x 1.4). Ordinary mobs untouched. Still open by design: nothing places one in the world (a
  one-line camp tag, but which camp is content), and `xp_mult` is parsed but unapplied.
- [ ] **Client-only spell backlog (~32 spells missing from `spells.toml`)** *(quantified
  2026-07-22 from a Life Drain / Dark Shroud playtest; those two are now ported)*. The client's
  `spell_definitions.gd` has 156 spells; the server has 124. A client-only spell is dropped as
  "unknown spell" (mana spent, no effect). The simple base-class ENEMY/SELF ones can be ported
  as-is; the rest need server support first: **9 `PORT` teleport/gate/evac spells** (no server
  target-type handler), **prestige-class tags** (`Paladin_Fallen`, `Shadow Knight_Redeemed` — the
  cast gate keys on base `conn.class`, so these need the prestige-class model), and **`Warder's
  Mend` PET_HEAL** (also its own long-standing gap). `tools/export_spells.gd` is the intended regen
  path but is stale. Audit list: see the "Known drift" note + the 2026-07-22 session note.

### World systems
- [ ] **Mount system** — *`MountManager` autoload exists (client-side v1); feature is not
  fully wired* (server speed clamp, Animal Husbandry / Spirit-of-Wolf stacking / Selos'
  Melody interactions still pending)
- [ ] **Faction system** — race/class affects NPC standing; guards attack on sight
- [ ] **Time of day is per-client; make it server-driven** *(reported 2026-08-14; this is the
  "server broadcast is planned" line in "Known client↔server drift" made into a real item)*. No two
  players share a sky. `autoloads/time_of_day.gd` starts at `START_HOUR = 8.0` and advances purely
  from `_process(delta)` against a 20-minute `DAY_DURATION`, so the clock restarts at 8 AM every
  time the **game process** launches (it's an autoload, so it's already ticking at the login screen,
  not from character login) and then drifts by client uptime. Two friends who launched an hour apart
  are in different parts of the day.
  **Half the wire already exists, dormant.** `ServerWorldMsg::TimeOfDay { hour: f32 }` is declared
  at `protocol/src/world.rs:1074` and `server_design.md:348` documents it as broadcast *"every 1
  minute"* — but **nothing in the server ever constructs it**, and neither `gdext_net` nor `Net`
  handles it. Same shape as `BindAtCurrentLocation` before the respawn sprint: a variant with no
  sender and no receiver.
  **Work:** a server-side world clock ticked in the world loop and broadcast on a cadence; a gdext
  decode plus a `Net` signal; and `TimeOfDay` becoming a *follower* — adopt the server hour and keep
  interpolating locally between broadcasts so the sky doesn't step once a minute. The authoritative
  day length moves server-side; `DAY_DURATION` stays only as the offline / Test Room fallback. No
  protocol bump (the variant is already in the shared enum), but it does need a gdext rebuild and a
  client re-export.
- [ ] **Weather system**; **Water & swimming** (breath/drowning); **Doors & locks** (lockpicking)
- [ ] **Zone transition effects** — fade/loading screen
- [ ] **Test Panel "Despawn All Enemies" leaves enemies invisible, not gone** (playtest
  2026-07-20) — the button appears to drop the client visual while the enemy persists (server
  entity / `RemoteEnemy` not actually despawned), so "cleared" enemies may still be there. Dev-tool
  bug (`test_panel.gd::_despawn_all_enemies`); likely needs the despawn to route through the server
  like `DevSpawnMob` does, not a client-only removal.

### UI polish
- [ ] **Player portrait** in HUD *(slugify + slot landed; art pending)*; **Map / minimap**
- [ ] **Hotbar + socials bleed between characters** *(found 2026-08-26 during the active-skill
  playtest: skills placed on the Warrior's hotbar appeared on the Monk's; **BUILT 2026-08-26,
  pending playtest** — `hotbar_per_character_checklist.md`, needs a re-export)*. `SocialHotkeys`
  persisted every bank, slot and the macro library to a single global
  `user://social_hotkeys.json`, loaded once at process start — every character on a machine
  shared one hotbar state, though the Track 16.2 header claimed "per-character". The audit
  found **`SpellBar` had the same disease** (`user://spell_bar.json`), so the memorized spell
  bar bled too; `Memorize` itself persists nothing (its state lives in SpellBar).
  **Built as:** both stores keyed by server char_id (`social_hotkeys_c<id>.json` /
  `spell_bar_c<id>.json`), reloaded on `Net.app_connected` (fires on every path into the
  world), with the previous character's pending debounced save flushed BEFORE the swap so the
  timer can't write one character's bars into another's file. Each character's first login
  seeds from the legacy global file so nobody's existing bars vanish (one visible echo of the
  old shared layout per character, then permanent divergence); the legacy file is never
  written again in launcher mode and remains the Test Room's store. SpellBar's reload runs
  before the lobby's `apply_character` handler in the same emission, so the existing
  `spells_changed` prune clears any seeded spell the class can't use. Headless proof ran green:
  two simulated characters, isolation + persistence + legacy files untouched.
- [x] **Bank Items-tab: a deposited item renders as an empty slot** — **DONE + playtested
  2026-08-17** (client `8ad7f39`, all 11 rows of `bank_vault_display_checklist.md` pass, including
  the relog row that proves nothing was ever lost). What exists is in systems_overview → Banker
  NPC. **It was never a refresh bug**, despite this entry previously being titled "does not
  live-refresh on deposit" — the repaint ran every time and drew nothing, because a vault cell had
  only an icon and a count label, `ItemData.icon` is null for all 172 items, and the count label is
  blank for a stack of 1. Fixed with the name-label fallback `inventory_window.gd` already had,
  which is why bags never showed it. Highest *perceived* severity on the friends-build list, and
  the whole of it was one absent `Label`.
- [x] **Bags open on left-click instead of right-click** — **DONE + playtested 2026-08-18**
  (client `c3ef9f4`, all 14 rows of `bag_click_grammar_checklist.md` pass). What exists is in
  systems_overview → Inventory. **Not stale pre-grammar bag items**, which was the standing guess:
  `_on_cell_input` called `_toggle_bag()` from the **left**-click path as well as the right-click
  one, so both buttons opened a bag and a bag could never be picked up at all. Left-click now
  lifts, per `inventory_interaction_grammar.md` §3. Bags becoming movable reached two previously
  unreachable cases, both handled: the client mirrors the server's non-empty-bag refusal up front,
  and orphaned bag windows (keyed by base slot index) are closed on refresh. The playtest also
  removed the static slot-count badge from bag cells at the user's request.
- [x] **Inventory desyncs from the server and cannot recover until relog** — **DONE + playtested
  2026-08-20** (server `4f86796` + client `2310e8b`; 19 of 20 rows of
  `inventory_desync_checklist.md`, the only gap being offline Test Room Stack All). What exists is
  in systems_overview → Inventory. Presented as items sticking to the cursor or **appearing to
  vanish**; no item was ever lost, but it read exactly like loss.
  **Three faults, found in two rounds.** (1) The server logged a rejected `MoveItem` and sent the
  client nothing, so a wrong client never learned it was wrong; it now answers with the true
  contents of both named slots. (2) The client silently discarded `bag_<i>` deltas it thought it
  had no home for, trusting a "next snapshot" that only happens at enter-world; it now makes room,
  applies them, and warns. (3) **The origin, found by the tester:** `Stack All` rewrote the whole
  inventory **locally** and told the server nothing, so one click turned the client's view into
  fiction. It now asks the server to perform each merge, and is merge-only (it used to relocate via
  `_first_free_slot()`, which scans base before bags and so emptied bags into the main window).
  **Proof in the log:** Stack All fires six `MoveItem applied` inside one millisecond, and the
  following seven minutes of heavy dragging produce **zero** rejections, where the same activity
  before the fix refused one slot six-plus times in a row until a relog.
  The test `move_item_empty_source_drops_silently` had **asserted the bug as the contract**;
  rewritten as `move_item_empty_source_corrects_client`.
- [ ] **Confirm what can become `hud.gd::_tracked_target`.** Two `is_connected()` calls in
  `_show_self_target()` (`hud.gd:821`, `:823`) check `hp_changed` and `died` **without** a
  `has_signal()` guard. That is safe only while `_tracked_target` is restricted to
  `RemotePlayer` / `RemoteEnemy` / `RemotePet`, all of which declare both. But
  `scripts/corpse_body.gd` declares **no** signals and `scripts/loot_bag.gd` declares only
  `items_changed`, so if a corpse or loot bag can reach that variable, targeting one and
  pressing F1 logs `Nonexistent signal` twice. Surfaced 2026-08-10 while fixing the same class
  of bug on the `mp_changed` / `stamina_changed` lines a few lines below, which **were**
  firing (targeting an enemy then switching away). Left unfixed deliberately: adding guards
  speculatively would be changing working code on a hunch. Check `Targeting` /
  `Combat.set_target` for whether corpses reach the HUD target frame; guard both lines if they
  can.

### Tradeskill depth
- [ ] **Server-authoritative tradeskills** — mining/crafting/skinning currently refuse online
  (guarded 2026-08-24 after the phantom-item finding); building them for real means the
  CompleteQuest pattern (client sends intent, grants nothing optimistically, server owns the
  roll/ingredients/skill-ups + persists skill levels, which currently reset every launch) plus
  server-side node state. Pairs naturally with the NPC proximity-gate table, since nodes need
  server positions too.
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
- [ ] **`world_two_clients.rs`: three genuinely flaky enemy-AI tests** *(the 13 stable failures are
  FIXED, server `6a1a92e` + `db3df02`, 2026-08-11)*. The suite sat at a stable `29 passed; 13 failed`
  for three weeks. It was **not** flakiness and **not** a server regression: the file was last edited
  07-19 and three gates landed after it, so the fixtures asserted pre-gate behavior — the CastSpell
  class/level gate (11 tests casting spells a **level 1** character can't, three also as the wrong
  class), the melee swing-rate limit (a test bursting 10 Attacks in one frame, correctly dropped as
  forgery), and the `meditate` skill (6 casting keys became 7). Fixed the fixtures, not the server.
  Now **39-42 of 42, with a fully green run reachable**. What remains is the pre-existing
  load-sensitive flakiness in `aoe_spell_damages_nearby_enemies`, `pet_attacks_owners_target` and
  `pet_pulls_aggro_via_threat_reaggro` — all pass in isolation, all vary run to run.
  **The "three" is wrong, and the rule built on it is a triage hazard** *(corrected 2026-08-23)*.
  On 2026-08-23 **five** distinct tests were observed failing under load in a single sitting, each
  passing in isolation: the three above plus `charm_converts_enemy_to_pet` and
  `player_attack_kills_enemy_and_corpse_despawns`. Proven not to be a regression by an A/B — the
  **clean tree failed too**, with a different subset each run.
  The old rule read *"a failure outside those three is a real regression"*, which cuts both ways:
  it sends you chasing a phantom, and it invites waving away a genuine regression as "probably
  flake". **Better rule: any failure that reproduces IN ISOLATION is real; a failure that passes
  alone is load-sensitivity, whichever test it is.** Closing this item means making them
  deterministic (the harness waits on enemy AI reaching the player) rather than maintaining a list;
  see `server/docs/flaky_integration_tests.md`.
