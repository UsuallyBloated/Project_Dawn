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
- **Ops bins (the crate has 6 binaries, so `--bin` selects — the plain
  `cargo run -p projectdawn-server` still runs the server via the `default-run` manifest key):**
  `--bin admin_report` (read-only: accounts + characters incl. soft-deletes, per-char
  coins/inventory, and the newest GM action audit rows → console + a local `world_report.html`),
  `--bin grant_gm -- <username> on|off` (set per-account GM; no args = list),
  `--bin reset_password -- <username>` (new password printed once, sessions purged),
  `--bin admin_account` (no args = list; `-- ban <username> [reason]` / `-- unban <username>`),
  and `--bin invite` (no args = list; `-- new [n] [note]` mints codes shown once; `-- revoke
  <code>`; on `feat/public-hosting` until cutover).
  The four that write open the DB with `mode=rw` and never create one: run them from the
  directory that holds `world.db` (on the R720 that is `/opt/projectdawn`, NOT the source tree)
  or set `PROJECTDAWN_DATABASE_URL`. Full detail in `docs/reference/commands.md`.
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
- **Graceful shutdown arrives with build `6c2bc45` (built 2026-10-23, not yet deployed).** From
  that build on, `systemctl stop`/`restart` saves everyone and tells them before closing (see
  `server_operations.md`, "Stopping safely"); before it, a restart discards up to 60 s of
  position, HP, XP, inventory and coins for everyone online. Either way, get people to log out
  first: it costs nothing, and a crash is never clean.

### Shipping a change to the R720

Client and server changes travel **different paths**. Client-side edits never touch the R720.

**Server change** (`F:\Projects\server`), reaches players after a restart:

```
git push                                  # from the dev box
# then on the R720:
sudo -u projectdawn -H bash
cd /opt/projectdawn/src && git pull && cargo build --release
exit
sudo systemctl stop projectdawn           # BEFORE the cp — see below
sudo -u projectdawn cp /opt/projectdawn/src/target/release/projectdawn-server /opt/projectdawn/projectdawn-server
sudo systemctl start projectdawn
journalctl -u projectdawn -n 20 --no-pager   # confirm dev_cmds=false + the new build= sha
```

Two traps, both hit in real deploys: forgetting the `cp` entirely (systemd runs
`/opt/projectdawn/projectdawn-server`, not the one under `target/release/`), and running the
`cp` while the service is up — Linux refuses to overwrite a running executable
("Text file busy", hit 2026-08-27), which is why the stop comes BEFORE the copy.

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

## Secrets and paid services (absolute rules)

- **The private key folder.** API keys live in a private folder outside both repos. Its path
  is written only in `.claude/hooks/secret_paths.local.json`, which git ignores; never write
  that path anywhere else (no doc, commit, chat, artifact or log). **Claude never reads,
  lists, copies, prints, uploads, commits or pushes anything in that folder, under any
  condition.** Nothing needs it to: our own Meshy client (`.claude/hooks/meshy_client.py`)
  and the spend gate read the key themselves, outside any tool call. A PreToolUse hook
  (`.claude/hooks/meshy_spend_gate.py`) refuses any tool call that names the folder or the
  key file, and any shell command or new script that would reach the key or run the client
  outside a Meshy tool call. Never edit, disable or work around that hook, and never spell a
  path or name in pieces to get past it.
- **Meshy spending.** Never spend more Meshy credits than the account holds, and every paid
  call waits for the user's approval. The same hook enforces it (live balance check,
  worst-case prices, unknown tools refused), and the client checks the balance again itself.
  Never call Meshy's API outside the Meshy tools. **The price tripwire**
  (`.claude/hooks/meshy_tripwire.json`, written when a task cost more than expected) blocks
  every paid call until the **user** reviews and clears it; Claude never touches it. Only
  `meshy_client.py` may contain Meshy's API address (the user's narrow exception,
  2026-10-14), and every change to it is shown to the user before it runs. When Meshy changes
  anything, follow "When Meshy changes something" in `docs/design/meshy_asset_pipeline.md`.

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
  — adding/editing one without the other causes drift. Recounted 2026-10-08: the client has
  156 spells, `spells.toml` has 135, so **21 are client-only** and are refused server-side as
  an unknown spell (no effect; since 10-02 no mana is taken either). All 21 need something the
  server does not model yet (ports, prestige classes, damage over time, mana drain, stealth);
  no pet spell is among them since Warder's Mend was ported on 10-07, and Torpor joined the
  server on 10-08 — see the To-Do "Client-only spell backlog". **Check it with
  `tools/check_spell_lockstep.gd`** (see `docs/reference/commands.md`): it compares every
  field the server carries and exits 1 on drift. On 2026-10-05 the 133 shared spells showed
  ZERO drift. *(The check used to excuse Bard songs' damage and heal fields because their
  pulses were client-side; since the song rework of 2026-10-20 the server carries every song
  field and the exception is gone. Recounted then: 158 client, 142 server, 16 client-only,
  zero drift.)*
  `tools/export_spells.gd` (Godot editor) is the intended regen path but is stale.
- *(Closed 2026-06-22: leveling used to be client-local and provisional. The corpse epic's
  Slice 0 moved XP + leveling server-side — `world/progression.rs::award_xp` is the single
  choke point and the client mirrors `XpGained` / `LevelUp`. The per-level stat tables are
  kept in **lockstep** on both sides (`char_data::level_gains` vs `CLASS_LEVEL_GAINS`) and
  anchor-tested, so editing one without the other IS still live drift to watch.)*
- *(Closed 2026-10-04, playtested 2026-10-09: time of day is server-driven. The server's
  `world/clock.rs` and the client's `autoloads/time_of_day.gd` each hold the day length
  (`DAY_LENGTH_SECS` / `DAY_DURATION`, 1200 s) and must stay in **lockstep**, since the client
  runs its own clock between the server's once-a-minute sends.)*

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
   `docs/session_notes/README.md`. If the session changed a To-Do status or a checklist,
   regenerate the planner's week-by-week detail: `python tools/schedule_detail.py` (edit
   `docs/schedule_detail.toml` first if a row needs to move), commit the plan file with both
   outputs, and republish the page at the link recorded in the plan file. The detail carries
   dates and dependencies only, never status.
5. Run a review pass (`/code-review`) if the session touches 5+ files or a core system
   (combat, inventory, spells, PlayerStats, networking).
6. **Tick only on playtest evidence.** An item earns `[x]` when a filled checklist in
   `docs/playtest_notes/` shows it passing — not when it compiles, not when `cargo test` is
   green, not when it's committed. Claude proposes the tick and cites the checklist row; the
   tester's result is the evidence. No checklist means the item is *built*, not *done*.
   Then, in one pass: tick it here and move its "what exists" note into
   `systems_overview.md` (not back into the to-do). **The schedule copies hold no per-item
   status** (restructured 2026-09-09: their item lists are frozen snapshots and this To-Do is
   the only live list), so a tick touches them only when it **closes a phase** — then update
   the one-line §7 row in **both** `docs/schedule.md` *and* `docs/schedule.html`.

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
  build (target **2026-11-08**, slipped from 09-14 on 09-09, then from 10-05 on 09-27), with the phases, the critical path, and the velocity the estimates
  are measured against. **There is one checkbox list in this project and it's the To-Do below.**
  The schedule holds no boxes: its per-phase bullets are the plan, and its status table is just a
  progress readout of what the To-Do already says. (Restructured 2026-09-09: the schedule's
  item lists are frozen snapshots; only its one-line status table is live.) Time-boxed by design — when the target lands,
  fold anything unfinished back into the To-Do and retire this pointer.
  `docs/schedule.html` is a browser-readable rendering of it for non-repo readers (open it
  locally); keep it in sync when the plan changes.
  **Week-by-week detail for the planner** → `docs/schedule_detail.html` (+ `.md`), generated
  from `docs/schedule_detail.toml` by `tools/schedule_detail.py`: one row per checklist sitting,
  build step, redeploy, decision or friend session, with owner, needs and dependencies. Dates
  only, never status; every row names the checklist or To-Do entry its status lives in.
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
- [x] **Group-mate HP/MP/stamina never reach the group panel in launcher mode** — **STALE
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
  **PLAYTESTED 2026-08-27, PASS** (`group_stats_and_tells_checklist.md`, a real two-account
  session: account 4's char joined account 1's, gid=1): bars live and correctly labeled in both
  directions, XP split logged (`pool=315 per_member=157 members=2`), round-robin loot enforced,
  clean logout, zero RPC-flood lines. Two follow-on findings, tracked separately: member rows
  are BLANK until the first resource update (own item below), and a skill's stamina cost is
  invisible to the partner (client-local spend — folded into the active-skills item).
- [ ] **Remote players never show a jump** *(reported 2026-08-14)*. Player 1 jumps; player 2 sees
  them slide along the ground. Nothing about a jump crosses the wire, and it's dropped in three
  separate places: (a) **the client never reports it** — `scripts/player.gd:489` (was :444) is the only caller
  of `Net.send_movement()` and hardcodes `jumping = false`, even though `net.gd:374` and the gdext
  `send_move` both carry the flag; (b) **the server discards it** — `world/handlers.rs:494`
  (was :487) destructures `jumping: _`; (c) **there's nowhere to put it coming back out** —
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
  **BUILT 2026-10-14 (the cosmetic version), pending the Oct 22 bump** (on `feat/jump-relay` in
  both repos, server `4975e4d`, client `82cf979` (the shas were `%s` placeholders until
  2026-10-19), branched from `feat/trade-window` like the hunger window
  so it rides the same `PD_W0028`; awaits the trade session's merge, which was offline when it was
  built; `remote_jump_checklist.md`, 9 rows, on the branch). (a) `player.gd` latches a jump and
  sends it on the next Move's `jumping` flag, once. (b) The Move handler reads the flag:
  `PerConnection::note_move_jump` relays only its rising edge, at most once per
  `JUMP_RELAY_MIN_INTERVAL` (500 ms; an honest jump lasts 0.7 s), and a relayed jump stands the
  player; nothing reads the flag into position, Y stays the server's zero. (c) A new
  `ServerWorldMsg::PlayerJumped { id }` appended after `HungerUpdate`, fanned to the in-world
  players who can see the jumper (the Say reach), never the jumper; the DLL's `player_jumped`
  signal, connected by name; `RemotePlayer.play_jump` draws the local jump arc (the same 7 m/s
  and 20 m/s² as `player.gd`, 1.2 m, 0.7 s) as an offset on the visual and nameplate, never on
  the interpolated position; a corpse does not hop. Tests: a unit test on the edge-and-rate rule;
  an integration test with a watcher beside a jumper (one jump plus a forged burst of ten flags
  inside the interval reaches the watcher as exactly one cue and the jumper as none, an edge
  past the interval relays again, and the jumper's own Position keeps y = 0); a headless probe
  of the hop (lift along the arc, the apex, an exact landing, no hop on a corpse). The first
  piece of the remote animation-state channel.
- [x] **Incoming `/tell` RPC** — **STALE ENTRY, CORRECTED 2026-08-26: built 2026-05-28**
  (`195891d`, "Chat wire-up: /say /shout /ooc /tell over the network"). The server fans
  `ChatMessage` to the single Tell target and `combat_log.gd:150` renders "%s tells you" into
  the Tells (In) channel — the full loop has existed for three months and was simply never
  exercised by two players. Rides the same two-player playtest as the group panel
  (`group_stats_and_tells_checklist.md`). **Playtested 2026-08-27, PASS both directions** —
  "X tells you" renders in Tells (In), sender echo correct. Follow-up request recorded as its
  own item: EQ-style `/r` reply + TAB tell-cycling.
- [ ] **EQ-style `/r` reply + TAB tell-cycling** *(requested 2026-08-27 during the tells
  playtest)*. `/r` replies to the most recent tell sender; pressing TAB cycles through everyone
  who has sent you a tell this session. Client-only chat UX (command parsing + a small
  tell-sender history in `ChatWindowManager` or `CombatLog`).
  **BUILT 2026-10-02, pending playtest** (client-only, rides the next export;
  `tell_reply_and_inspect_click_checklist.md` §1-2). `CombatLog` keeps the last ten tell
  senders, newest first, cleared on entering the world. `/r <msg>` (or `/reply`) answers the
  newest; a bare `/r` reopens the chat line holding `/tell <name> `. TAB in the chat line
  turns an empty line into a tell to the newest sender and, on a tell, steps to the next older
  one keeping the typed message; a `/say`, plain text, or a message addressed to someone who
  never sent a tell is left alone (TAB must not re-address words written for someone else). TAB no longer walks
  keyboard focus out of the chat line (which used to hide it mid-sentence). Headless probes
  cover the history and the TAB handler; the live key path and the reopen are the playtest.
- [ ] **Camp / kick return-to-lobby flow + live relogin countdown** *(deferred 2026-06-19 in the
  camp/linkdead session's "Not done"; recovered by the 2026-09-29 crack audit)*. `/camp`
  completion and a server kick both exit to the desktop because there is no in-game
  return-to-character-select flow; a kick strands the player. Also the lobby shows the
  server's one-shot "try again in ~Ns" string instead of a live-ticking countdown from
  `reconnect_after_secs`. Client-only (the wire already carries the seconds).
  **Scoped 2026-10-04, and it is three different sizes of job.** (1) **The stranding was worse
  than recorded and is BUILT, pending playtest** (client, next export;
  `inspect_range_gm_audit_ban_checklist.md` §3): when the world connection ended in game (a
  kick, a ban, a server restart, a network drop) the client showed NOTHING. `Net` emitted
  `app_disconnected(reason)` and in the world only the camp label listened, so the player
  stood in a frozen world with no message, and the 10-02 ban kick's "told why" was not true
  on screen. New `scripts/hud_disconnect_notice.gd`: the screen dims, a "Disconnected" panel
  shows the server's reason (or a plain line when there is none), a relogin hint, and Quit;
  the same line goes to chat and the debug log. (2) **The live countdown is not client-only.**
  The wire carries `reconnect_after_secs` but the DLL drops it (the `kicked` signal passes
  reason and code only), so it needs a wire-layer change and a DLL rebuild, no protocol bump.
  (3) **A real return to character select is a multi-day client job, not a small one:** the
  session token and the auth socket live in the login SCENE and are lost on a scene change;
  `Net.leave_session` relies on process exit to close the socket; and 54 autoloads hold
  per-character state that a second character would inherit unless each is audited (the
  hotbar bleed of 08-26 was one of them). Needs its own design pass and a state-reset audit
  before any code.
  **(2) BUILT 2026-10-15, pending the Oct 22 export and the playtest** (server `33c7e28` the DLL,
  client `1159a79`; `relogin_countdown_checklist.md`, 8 rows; no protocol change, no server change).
  The DLL's `classify` keeps the kick's `reconnect_after_secs` and emits a separate
  `kick_retry_after(secs)` just before `kicked` (a third argument would have changed
  `kicked`'s arity; a separate signal costs an old client only the countdown). `Net` connects
  it by name, holds it as pending until the `kicked` that follows (so an earlier kick's time
  never shows on a later one that named none) and exposes `get_kick_retry_remaining()`; the
  lobby shows "You can log in again in N s." ticking to "now" in place of the server's "about
  Ns" sentence, and starts with its `_process` off. Display only: the server still decides.
  Tests: a `classify` unit test in the DLL crate (27 s carried, a ban carries -1) and a headless
  probe of the launcher-mode lobby (5, 2, now, stops; a later ban shows no stale countdown).
  **Bump-day note:** the trade branch edited the same `SIGNALS` line of
  `tools/check_wire_layer.gd`; the merge keeps both lists' entries.
- [x] **Tell testers about the ~45 s worst-case relogin after a crash** — **DONE 2026-09-30
  (a doc line with no playtest surface, ticked on the edit like the reset_password bin)**.
  `camp_and_linkdead.md` §Risks called the number out ("a hard crash can take up to the 15 s
  netcode timeout to detect, then about 30 s of linger, so up to ~45 s before relogin.
  Acceptable; document it.") and `systems_overview.md` carries it for developers, but
  `README_FOR_TESTERS.md`'s X-button paragraph said "about 30 seconds" and nothing about
  detection time, so a tester refused at 40 s had no reference saying that was expected. One
  bullet added there. Surfaced by the 2026-09-30 belt-and-braces sweep, one of the two
  findings the hand audit missed.
- [ ] **Reconnect grace on a brief network blip (session resurrection)** *(server_design.md
  "deferred enhancement"; audit 2026-09-29)*. Today a drop is linkdead: the body lingers ~30 s
  and a relogin is refused until it reaps. Seamless resume (the old 60 s frozen-and-untargetable
  model) would need session resurrection, AOI re-attach, and connect-token juggling. A design
  call before any build; not a friends-build need.
- [ ] **Target-of-target heal routing** *(memory note, "future feature"; audit 2026-09-29)*. An
  ALLY heal cast with an enemy targeted should route to the enemy's target (the EQ assist-heal
  pattern) instead of failing on the target type. Server cast resolver change plus the client's
  target-of-target frame as the visible hint.
- [ ] **Held-item bank and vendor interactions** *(cursor design's carried open question,
  `cursor_slot_and_reequip.md` §Open questions; audit 2026-09-29)*. Deposit-from-cursor and
  sell-from-cursor were deferred ("place it first"). `SlotRef` has no cursor variant, so both
  are small wire additions plus the `destroy_at`-style guard for a held full bag.
- [ ] **No-drop / no-trade item flag** *(flagged in `inventory_interaction_grammar.md` §8 and by
  the trade design's ledger, which explicitly has no rule "until itemization grows one"; audit
  2026-09-29)*. `ItemData` carries no binding flag; the two account-shared bank slots and the
  trade window both traditionally reject bound items. One flag on `ItemData` + `items.toml`,
  refusals in the bank quick-transfer and `TradeOfferItem`, with a chat line.
  **DECIDED 2026-10-19 (user): conjured food and water are NO RENT.** Confirmed meaning (EQ's
  "Temporary" tag, which P99 shows on Summoned: Black Bread): the item is destroyed once the
  character has been logged out for 30 minutes, not at the instant of logout, so a quick relog
  or a crash keeps it (Allakhazam's EQ item-tag reference; no classic-only source found that
  differs). Built with this flag. **Waits on the user's yes for a migration** (2026-10-19):
  the 30-minute rule needs the time a character logged out, and the database keeps none per
  character (only an account's last login and a session's last-seen).
  **NO RENT BUILT 2026-10-19, pending the Oct 22 bump and the playtest** (`feat/server-speed`,
  same commits as audit fix 5, migration 0015; checklist §8). `no_rent` on items (both sides,
  lockstep-checked), set on conjured bread and water; every departure stamps
  `characters.logged_out_at`; at the next login 30 minutes or more later the server removes
  every NO RENT stack (inventory, worn, bags, the cursor, both bank vaults); the tooltip leads
  with "NO RENT". Test: 31 minutes away loses the conjured bread, 10 minutes keeps it, an
  ordinary loaf is never touched, logout stamps the time. **The no-drop / no-trade binding flag
  this entry is about is still open**; NO RENT was the part decided.
  **Rule DECIDED 2026-10-19 (user):** no-drop / no-trade is for items made only for a quest,
  with no other use (not a tradeskill ingredient, not usable like a potion); which items, not
  yet decided. **Checked the same day: nothing qualifies today.** Quests count kills only, so
  no quest-only item exists (the one quest item, the Hunter's Medal, is a reward worn at the
  neck). The flag waits on the first fetch or delivery quest (Quest and loot content plumbing,
  item (a)), and gets built with it.
- [ ] **Pet persistence across logout: a design call** *(server_design.md open question 2;
  audit 2026-09-29)*. Today the warder auto-summons on every EnterWorld and conjured pets
  simply vanish, which is a de-facto answer nobody made on purpose. Confirm or change it when
  the taming epic (pet option C) is designed, since maturity makes persistence matter.
- [ ] **Loot rights odds and ends** *(group_loot_and_coin.md "known v1 limitations" + the
  06-16 Round 2 checklist rows that were built but never ticked; audit 2026-09-29)*. (a) An RR
  corpse claimed by a member who never loots it expires with its items lost (use-it-or-lose-it;
  a fallback rotation was "revisit if playtest dislikes it"). (b) The `/autosplit` group-notice
  rows (`group_loot_coin_checklist.md` Round 2 §3) never got a two-seat tick: one toggle while
  grouped is the whole check. Rides the next two-seat session with the member-leaves refill.
- [x] **Idle enemies rebroadcast unchanged positions at 20 Hz** — **DONE + playtested
  2026-10-07** (`scale_readiness_checklist.md` §1 and §2, all rows PASS: the live stream sat
  at about 5,000 Position sends a minute for 54 mobs and one player, where the old code sent
  64,800; it rose by about one mob's worth, 1,200, during each fight and fell back the next
  minute; mobs kited, caught, killed, idled and set off without a visible seam). What exists
  is in systems_overview → Networking, "The enemy position stream". *(Original entry, for the
  record:)* *(found 2026-09-15 while
  triaging the phase 4 test breakage; user flagged the lag angle)*. `tick.rs` step 6b fans
  every living enemy's Position to all AOI-visible players every tick, and idle mobs in this
  game never move (`tick_idle` only watches for targets), so the phase 4 population doubling
  doubled a stream that is almost entirely redundant — a stalled or slow client drops packets
  sooner than it used to. Fix shape: fan only when the enemy moved since its last broadcast,
  with a slow keepalive — the exact pattern `regen.rs` already uses for resources (>5% swing
  or 500 ms gap). Server-only, but measure before/after (a bandwidth counter in the log)
  rather than eyeballing; needs its own small pass.
  **BUILT 2026-09-30, pending playtest** (server `ac38cc2`; `scale_readiness_checklist.md`
  §1-2; server-only, no client change). Exactly the regen pattern: `Entity` keeps the
  pos / yaw / time of its last send and fans only on a move past 0.005 m, a turn past
  0.001 rad, or the 500 ms `ENEMY_POSITION_KEEPALIVE`; the sequence advances only on a real
  send. **Measured:** the new integration test counts one idle mob's Position messages to one
  player over 2 s, 32 before and 4 after. A new `enemy position fan` log line (sends, window,
  alive enemies, players in world) reports the live stream once a minute while anyone is
  online, so the R720 shows the same before/after from one deploy (the old stream is
  `enemies_alive x players x 20 x window`). `AiEvents.moved`, whose comment claimed to gate
  this and which nothing ever read, is deleted. Ticks on the §1 log-line row.
  Review pass (`818a902`): step 6b now tests the audience first (allocation-free
  `aoi.can_see` per connection) and only marks and encodes when someone can see the mob, so a
  camp with no player near it costs nothing per keepalive. **The "known cosmetic" recorded here was overstated, corrected
  2026-10-02 after reading `remote_enemy.gd`'s interpolation:** the review predicted a mob
  easing into motion over up to 500 ms. The client renders 100 ms behind, so of the span
  between the last keepalive and the first moving snapshot only the final 100 ms is ever
  drawn: the mob is nudged forward by at most about one tick of travel (10 to 25 cm at the speeds in `zone_camps.toml`) as it
  sets off, then moves at full speed. No fix is planned; §2 of the checklist keeps a row in
  case it is visible after all.
- [x] **An owner's own pet "despawns" on the HUD when it is merely out of view** — **DONE +
  playtested 2026-10-07** (`scale_readiness_checklist.md` §4, all four rows PASS: a parked pet
  kept its panel past 300 m, `/pet follow` and `/pet attack` from out there brought it, the
  panel cleared on death and swapped on re-summon). What exists is in systems_overview →
  Networking, "The own-pet rule". *(Original entry, for the record:)* *(review
  finding on the cell-crossing fan, 2026-09-30; recorded, not built)*. The AOI despawn means
  "out of your neighbourhood", but `remote_pet_manager.gd::_on_entity_despawn` treats an
  own-pet despawn as "gone" and calls `PetManager.dismiss_remote_pet()`, clearing the pet
  panel and `/pet` commands while the server pet is alive. Reachable only when owner and pet
  are two cells apart (120 m plus): pre-existing via the owner walking away (step 5b's lost
  arm), and now also via the pet crossing away. The pet AI keeps pets within tens of metres,
  so it is theoretical today; the right fix is client-side (treat an own-pet despawn as
  hidden, not dismissed, and re-attach on the next PetSpawn) and rides an export.
  **Re-read 2026-10-02: it is not theoretical.** `/pet guard` and `/pet sit` pin the pet
  (`entity.rs::tick_pet_ai` returns before the follow step for both stances), so an owner who
  walks two cells away loses the panel and every `/pet` command (all gated on
  `PetManager.has_pet()`, a live node), and cannot call the pet back until they walk into
  view of it again. The client-only fix is also weaker than it looked: one `EntityDespawn`
  means both "left your view" and "is gone" (a charm ending, a replacement summon), and the
  client can only guess which from distance. Deaths and HP are not the problem; the server
  fans those to everyone in the world, not by view.
  **Needs a design call (user)**, each a small server change, none built: (1) the owner
  always sees their own pet (never send the owner a view-loss despawn for it, and always
  include the owner in its position fan), which keeps guard-and-walk-away working as in EQ;
  (2) a leash: a pet further than some distance from its owner drops its stance and returns
  or warps to the owner; (3) WoW's answer, the pet is dismissed past a distance with a line
  saying so.
  **DECIDED 2026-10-02 (user): (1), "You should absolutely see your own pet, wherever it
  is." BUILT same day, pending playtest** (server `43dc287`; `scale_readiness_checklist.md`
  §4; server-only, no client change, rides the next redeploy). One helper, `pet_owner_cid`,
  carries the rule: the owner is always in the pet's Position audience, is skipped by both
  view-loss despawn paths (the pet crossing a cell, and the owner's own crossing, which also
  no longer re-sends a PetSpawn the owner never lost), and is added wherever the pet really
  ends (charm expiry, the body expiring). Integration test
  `owner_keeps_seeing_a_pet_parked_two_cells_away` parks a skeleton, walks the owner two cells
  off, and calls it back; it fails on the previous code at the first assertion. Not an
  information leak: the owner learns only their own pet's position, and the pet goes only
  where the owner already sent it.
- [ ] **The cursor-slot epic: left-click ground pickup + corpse auto-re-equip** *(left-click
  requested 2026-08-27; the user chose the full server-side cursor slot — "Option B for sure.
  this sounds amazing and we need the corpse auto-re-equip feature" — over a client-only
  auto-loot shortcut)*. Design: `docs/design/cursor_slot_and_reequip.md`. Two slices:
  **Slice 1 (PD_W0027)** — a real `Inventory.cursor` slot server-side ("cursor" as a location
  string, which MoveItem / InventoryDelta / the DB column all carry with zero encoding
  changes), a `LootToCursor` intent gated exactly like the loot window (range, loot rights,
  single-stack + zero-coin bags only), death strip + encumbrance + persistence coverage, and
  the client mouse-attach render. **Slice 2** — corpse item rows gain equip-slot provenance
  (a real migration) and self-corpse loot restores gear to its slots, bags second, cursor as
  overflow. Corpses stay right-click loot throughout; left-click grabs only lone ground
  items. One protocol bump, one gdext rebuild, one re-export for slice 1.
  **Slice 1 BUILT 2026-08-27, pending playtest** (server `73074a8`, 210/210 unit tests incl. 8
  new cursor tests; client + refreshed gdext DLL in this commit; `cursor_slot_checklist.md`).
  What fell out nearly free: equip-from-hand (paperdoll click while holding, old piece pops to
  cursor), drop-from-hand and trash-from-hand via the existing Drop/Trash cells, eat-from-hand
  server-side. **Deploy note: BOTH sides move together** — an old client cannot connect once
  the R720 runs PD_W0027, so restart + new export are one step.
  **Playtested 2026-08-28: 13 of 14 rows PASS** (`cursor_slot_checklist.md` — the moves law,
  persistence across logout, weight, round-robin refusal all clean). **One CRITICAL find,
  fixed same morning: the death dupe** (server `f8c609b`) — `clear_all()` predated the cursor
  and left the hand full after the corpse had taken the copy; one line + a regression test on
  the exact death sequence. Retest §4 after the redeploy. **Slice 1.5 queued from the
  feedback**: (a) left-click on a kill-loot corpse/bag TARGETS it (consistent with left-click
  = target; also makes the standing `hud.gd::_tracked_target` guard item live — loot bags
  will need the `has_signal` guards or the signals); (b) left-click a WORN paperdoll item
  with an empty hand lifts it to the cursor (UnequipItem to "cursor"; small server support);
  (c) clicking the WORLD (terrain/sky) while holding = drop confirm, and the inventory's Drop
  cell is removed outright (user: clicking the environment is the intuitive drop; drag-drops
  already use the world-click path); (d) **every pickup attaches to the cursor regardless of
  source** — retire the local invisible-drag in launcher mode and route all lifts through the
  real cursor (the old drag ghost rendered `item.icon`, null for all 172 items, so lifts
  showed NOTHING on the mouse; the server cursor shows the name — unify on it).
  **Slice 1.5 BUILT 2026-08-28, pending playtest** (`cursor_slice15_checklist.md`; server
  `22837b9` unequip-to-cursor + the client batch; no protocol bump). All four asks plus the
  standing `hud.gd::_tracked_target` guards (loot bags are targets now, so the `has_signal`
  guards went in). One ask deferred as its own epic: **clicking an entity while holding should
  also open a TRADE window** (EQ give/trade) — recorded below; entity clicks target-only until
  then.
  **Slice 1.5 playtested — PASS, all 14 rows** (marks recovered 2026-09-09 after an unsaved-tab
  delay; the 08-28 log corroborates independently, and §1 confirms the death dupe is dead on
  the fixed build). **Two bugs from the notes, both diagnosed + FIXED 2026-09-09, retest
  pending:** (1) equip-from-hand SWAP blanked the held item — the EquipItem delta fan was
  cursor-blind and sent an empty cursor delta while the server still held the swapped-out
  piece; all five hand-rolled delta readers now go through `peek_at` (three were latent
  same-bug: partial drop/destroy from the hand, and eat-from-hand which the peek refused).
  Server-only. (2) Drop-confirm clicks passed through to the world and instantly re-prompted —
  the dialogs are native popup Windows invisible to the hovered-control check while player.gd
  polls hardware buttons; the dialogs now report closes and `request_ground_drop` ignores taps
  in a 400 ms echo window. Client-only. Also from the notes: the movable-full-bags design item
  directly below.
- [x] **Full bags should move with their contents** — **DONE + playtested 2026-10-09**
  (`full_bags_move_checklist.md`, all nine rows PASS; the log shows a held bag surviving a
  relog, a death while holding one leaving an 18-stack corpse looted empty, and the sell and
  bag-in-bag refusals). What exists is in systems_overview → Items (bags). The tester asked
  whether a swap swaps places or contents: places, each bag keeping its own contents, which is
  what they wanted. *(Original entry:)* *(asked 2026-09-09 on the slice 1.5
  checklist: "We plan on changing this, correct?")*. Today a non-empty bag refuses to lift or
  move ("Empty the bag before moving it.") because the server keys a bag's contents to the
  base slot holding it — moving the bag would orphan them. EQ moves full bags freely, so the
  ask is legitimate; the build is a server change (re-key the `bags` map entry when its parent
  base slot moves) with the client mirroring the same re-key.
  **Scope SETTLED 2026-09-17 (user): the cursor may hold a non-empty bag**, with the
  bag-in-bag ban unchanged. Death-path note for the build: a cursor holding a
  non-empty bag must strip bag AND contents to the corpse (extend the `clear_all` cursor
  coverage and its regression test).
  **BUILT 2026-09-27, pending playtest** (server `fd39b99` + client `8f27abb`;
  `full_bags_move_checklist.md`; no protocol bump, both sides ride the next
  redeploy + export together). The bags map entry follows its bag on every move: base moves
  and swaps re-key to the destination, lifts re-key under `CURSOR_BAG_KEY` (255), places
  re-key back; bags never merge, so same-path pairs swap. The sentinel key makes
  persistence, weight, snapshots and the death strip cover a held bag's contents for free
  (regression test `death_strips_a_held_bag_and_its_contents`). Held-bag inners are
  unaddressable from the wire, the placer never fills a held bag, and destroying/dropping
  a held full bag refuses rather than orphaning contents. Client mirrors bag_255 into a
  cursor-bag store that Encumbrance weighs.
- [ ] **Trade window** *(requested 2026-08-28 with the cursor work: "a click that lands on an
  entity (enemy, NPC, player) still targets but ALSO opens a trade window. EQ works like
  this")*. **DESIGNED 2026-09-19: `docs/design/trade_window.md`** — escrow by locking (offered
  items never leave the owner's inventory until a single-transaction commit, so a crash loses
  nothing), every offer edit clears both accepts, receiver placement through the real placer
  (`can_accept` both ways + `merge_capped`), a ten-point exploit ledger that doubles as the
  test list, and a PD_W0028 wire sketch (protocol bump, gdext rebuild, both-sides deploy).
  All four §6 calls DECIDED 2026-09-19 (user): 8 slots per side, instant open, 10 m range for
  now (user flags it as far; tuning candidate after the first playtest), NPC give stays slice 2
  WITH a standing instruction to pull it forward if slice 1 leaves it nearly free. Build-ready;
  queued behind the phase 4 deploy/playtest and the bags + dead-XP batch. Until built, entity
  clicks while holding target only.
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
  warder is level 5)*. **Research DONE 2026-09-17 (user-commissioned): `docs/design/pet_levels.md`**
  — EQ classic (spell-owned pets, level rolled per summon, the max-pet ritual), EQ Legends'
  modern 1:1 simplification, WoW's owner-tracking shape, and SWG's taming + pet-maturity system
  (per the user's standing "more SWG influence" note). Three options in the doc: A =
  owner-derived levels now (warder = owner-1; Summon Skeleton capped ~10; optional variance
  roll), B = the EQ pet spell line with the content pass, C = SWG-style Beast Master taming as
  its own later epic. **DECIDED 2026-09-19 (user): C is the Beast Master's destination**
  ("Taming is needed... gives variation to pet classes") — summoners conjure, Beast Masters
  raise. **A proceeds as the interim** in the post-deploy server batch, with the discussion's
  two refinements: the variance roll on MANUAL summons only (warder deterministic owner-1),
  and pets at ~70% of the mob stat curve so a pet class is not a duo by itself (scalar is a
  playtest tuning knob). Accepted cost: A's free warder scaling is replaced by earned maturity
  when C lands — tell whoever mains Beast Master. B stays folded into the spell-backlog pass.
  **Interim A BUILT 2026-09-27, pending playtest** (server `1f73459` + `5cf7508`;
  `xp_eligibility_and_pet_levels_checklist.md` §2). Warder = owner-1 deterministic on both
  the auto-summon and the retreat-respawn; manual summons roll the EQ 0..=2 gamble; Summon
  Skeleton caps at 10; stats interpolate the hand-authored camp ladder at
  `PET_STAT_SCALAR = 0.70` (the tuning knob, `pet_templates.rs`), with an anchor test that
  fails if `zone_camps.toml` moves without the curve. All three summon paths route through
  one `summon_scaled_pet` helper. Integration test pins the original bug: a level 22 Beast
  Master now gets a level 21 warder.
- [ ] **Player inspect** — right-click a player to see their equipment *(audit 09-09 settled
  the 08-26 flag: this is BUILT, not "in progress" — the window is mounted by the HUD and
  opened by a chat command (`hud.gd` ~1399: `open_for` + `broadcast_inspect_player`) over the
  existing wire round-trip. Remaining: the right-click-a-player trigger this entry names, and a
  playtest — no checklist has ever exercised it)*
  **Right-click trigger BUILT 2026-10-02, pending playtest** (client-only, next export;
  `tell_reply_and_inspect_click_checklist.md` §3). A right-click tap on a living player targets
  them and opens inspect through the same path as `/inspect` (20 m client range, the server's
  30 m gate behind it); a right-drag is still the camera. The range gate itself has rows in
  `inspect_range_gm_audit_ban_checklist.md` §1.
- [ ] **LFG flag**, **Guild system**, **Dueling**, **Auction / bazaar**, and the later social
  layer recorded elsewhere and pulled in by the 2026-09-29 audit: **player-owned towns + guild
  taxes** (user idea 2026-06-18, "revisit later", sparked by the Banker fee mechanic) and a
  **mail system** (server_design.md open question 6, "defer until requested").
- [ ] **Language system wiring** — `hear_language()` passive gain not yet called from the
  chat-receive path; needs multiplayer chat RPC + trainer NPCs
- [x] **Quest reward item follow-ups** — **STALE ENTRY, CORRECTED + TICKED 2026-10-02: both
  halves were done and playtested, and this entry never caught up.** (a) The **Tarnished
  Silver Ring's AGI +1 not applying** was fixed on 2026-07-14 (client `b1df906`, "Gear stat
  bonuses display in launcher mode": the six primary stats have no server-to-client sync, so
  the client's server-driven equip path now applies gear bonuses itself) and playtested with
  the ring as the test item: `gear_stat_display_checklist.md` §1-4, every row passing (equip
  toggles AGI, relog keeps it, death strips it, STR and CON items move too). The one note from
  that sitting ("unequip, relog, it is equipped again") was the disconnect-flush bug, fixed and
  passed in `disconnect_flush_checklist.md` §1. The 09-09 audit looked at this entry, disproved
  its hypothesis, and proposed a diff against the gnoll boots, without finding that the fix
  had shipped eight weeks earlier; a 2026-10-02 read of both sides of the equip path found
  nothing wrong because there is nothing wrong. (b) The **Hunter's Medal landing on turn-in**
  passed 2026-09-22 (`phase4_content_checklist.md`, the Rotfang turn-in row: refused on full
  bags, paid on the retry). One eyeball is left and has a row, not an entry: the Medal is a
  NECK item, the one slot nobody looked at for STR/CON on the sheet
  (`inspect_range_gm_audit_ban_checklist.md` §6).

### Security / exploits
- [ ] **Housekeeping audit 2026-10-23: the hotfix (Phase 0) and the later phases** *(the
  user asked for the code to be compared with the kodr-skills standards; findings and every
  id: `docs/security/housekeeping_audit_2026_10_23.md`)*. **Phase 0 BUILT and DEPLOYED
  2026-10-23** (R720 boot line `build="3d938ca" dev_cmds=false`, 19:52 UTC), **pending the
  playtest** (server `6f18a5e` + review fixes `3d938ca` on
  the deploy branch, merged into `feat/server-speed` as `019bfb3`; client
  `tools/check_vendor_lockstep.gd`; `hotfix_crash_and_dupes_checklist.md`; server-only, no
  export). H1: one chat line with an accented letter at byte 512 crashed the whole server
  (a byte slice in the tick task); cut on a char boundary now. H2: a drop waited for the
  60 s checkpoint, so a restart after someone picked it up and logged out left the item with
  both; drops are saved at once (one commit per dropper per tick, at most four drops a tick)
  and so are pickups. H3: immediate saves wrote one store alone (the quest reward the bags
  only; corpse loot, death and the trade commit the bags and wallet but not the vaults), so a
  crash after an unsaved bank withdrawal left the item in two places; every store is written
  together now. H4: a failed read at login played on with empty stores and the next save
  wiped them (a whole account bank); the login is refused instead. H5: vendors sold any item
  with a price, named drops included; each vendor's stock now lives in `npcs.toml` too, and
  on `feat/server-speed` the vendor must also serve the buyer on faction. H6: a failed
  corpse save skipped the corpse for good; it retries next tick. Eleven tests, each failing
  on the unfixed code. **Phase 1, durability, BUILT 2026-10-23, pending the redeploy and the
  playtest** (server `b36904e` + review fixes `6c2bc45` on the deploy branch, merged into
  `feat/server-speed` as `a7a318f`; `phase1_durability_checklist.md`; server-only, no export;
  user calls: build on the deploy branch, the EQ-flavoured restart line). A stop or restart
  (SIGTERM, Ctrl-C, a closed console on Windows) now saves everyone first (failed saves
  retried for 12 s), then tells each player "The world is being restarted. Your progress has
  been saved; please log in again in a minute." (or that their last moments could not be
  saved), and exits non-zero if anyone was not saved; a second signal quits at once. One save
  path, `persistence::flush_connection`, for the checkpoint, logout, the retry queue and
  shutdown. A logout save that fails is retried every second and the account's relogin is
  refused until it lands (given up after 2 minutes with an error, to the last saved state).
  XP is written inside the corpse, quest-completion and resurrection transactions (a crash
  used to return a death's XP while its corpse kept the refund, and lose a quest's or a
  resurrection's XP). A failing world loop now ends the process. Five tests, each failing with
  its fix disabled. Accepted residual: a character whose corpse save failed (the database
  already failing) and who leaves before the retry is saved without its corpse. **The redeploy
  INTO this build is not clean** (the old binary is the one stopped): everyone logs out first.
  **Later phases (planned, not built):** 2 the `tick.rs` split, right after the Oct 22 bump merges (user
  decision); 3 guardrails (lints, CI, `cargo deny`/`audit`, a fuzz target, panic
  containment); 4 the client/server line (fall damage on the server then `DeathBroadcast`
  gone, user decision; swing pacing on real haste; cast relays; intent budgets; a stats
  message; the ~20 unchecked lockstep pairs; wire hygiene); 5 remove the offline client code
  (user decision); 6 observability and auth polish.
- [ ] **Client-decided outcomes (audit 2026-10-19)** *(user, 2026-10-19: "Events happening on
  the client are a no-go")*. Findings, verified by hand: `docs/security/client_authority_audit_2026_10_19.md`.
  Order, worst first (user: "go ahead with recommendations"): (1) the server stops relaying
  client-made Hit/Miss/Evade broadcasts (only the Test Panel sends them; since the 10-14
  stand-on-hit client change a forged one would stand another player, cancelling seated regen
  and `/camp`; not live until the Oct 22 export); (2) movement speed decided by the server (a
  modified client runs 1.5x; Spirit of Wolf counts twice for an honest one; mounts and carry
  weight need server models); (3) heal and nuke stat bonuses and casting-skill multipliers on
  the server; (4) the melee miss roll and weapon-skill damage on the server; (5) memorized
  spell gems tracked by the server (a wire message); (6) active skills, Bard songs, alignment
  and fall damage as their own builds (the first three have entries already).
  **Fixes 1 to 3 BUILT 2026-10-19, pending the redeploy, the Oct 22 export and the playtest**
  (`client_authority_fixes_checklist.md`, 15 rows). (1) server `23bba2c`, deploy branch: the
  three relays gated and audited like any dev command; the relay test has a plain account's
  forged hit reach nobody (fails on the old relay). (2) `feat/server-speed` in both repos,
  server `9a3e1aa`, client `291d433`: `RUN_SPEED` (5 m/s) x the server's speed buff x snare x
  the new `encumbrance.rs` (coins and every carried and worn stack against 10 + STR, a port of
  the client's `encumbrance.gd`; `items.toml` gained `weight`, compared by
  `check_item_lockstep.gd`); the stamina half of encumbrance, documented but never wired,
  now runs; mounts refuse online. Test: the per-tick step off the server's own Position fan
  (0.25 m run, the same for a forged over-long direction, the crawl floor at 40,000 copper),
  failing on the old formula at 0.375. **Must ship with the export**: an older client against
  the new server walks at two thirds speed. (3) server `b81da60`, deploy branch, works with
  any client: `spell_power.rs`, the client's formula as is (user: "stick with the client's
  spell formula for now"): `(base + INT x 0.5) x evocation` on hostile spells, `+ WIS x 0.3`
  on heals, abjuration on absorbs, alteration on durations, a per-hit crit off INT; the
  alignment multiplier waits for server-side alignment; six spells missing from the server's
  discipline map added. Tests: unit tests on the formula; a heal test (60 + WIS x 0.3, flat
  60 on the old code). Research for the later balance pass: `docs/design/spell_formula_research.md`
  (EQ, WoW, D&D 5e and 3.5e, M&M, Lineage II). Also found and fixed on the way: the
  hand-eating test raced the hunger drain (`3173fbc`).
  **Fix 4 BUILT 2026-10-19, pending the Oct 22 bump and the playtest** (`feat/server-speed`,
  server `fb49a20`, client `031d435`; checklist §4). `combat.rs` owns the whole swing, the
  client's `weapon_skills.gd` numbers: the miss (35% at no skill to a 5% floor, 80% with a
  weapon type the class cannot use, the off hand 20 points more, accuracy buffs off), the
  skill damage multiplier (1.0 to 1.15, 0.5 unusable); a seated target is never missed. A miss
  fans a Miss; on a mob it adds one point of hate (my call, EQ's: a swing angers a mob, and it
  keeps the pet's assist working) and trains the weapon skill and defense, as the client did.
  The client rolls no miss online and draws the server's on whatever it hit, with "You miss
  X.". Four weapons named no skill (the server judged them hand-to-hand, the client's name
  table otherwise, so they trained the wrong skill): both sides name it now. Test:
  `the_server_rolls_the_melee_miss` (a Rogue with a two-handed staff, a Miss in eight swings;
  fails with misses disabled). Tests that need a landed swing master the attacker's skill; the
  six camp-walking tests walk by the server's own position, not the wall clock. **Fix 5 waits
  on the user's yes for a migration** (the server has nowhere to keep a character's spell bar).
  **Fix 5 BUILT 2026-10-19 (migration approved: "go ahead"), pending the Oct 22 bump and the
  playtest** (`feat/server-speed`, server `ea9ff32`, client `817c786`; checklist §7; migration
  `0015_spell_gems_and_logout_time.sql`, forward-only, ships in the merged build). The server
  holds the bar (`spell_gems.rs`, the client's rules: ten gems, `3 + level/5` open, memorize
  seated 2 s at half the mana, forget free) and refuses a cast of a spell in no gem before
  anything is spent. New intents `MemorizeStart` / `MemorizeFinish` / `ForgetSpell` /
  `SeedSpellGems` and a `SpellGems` snapshot, under PD_W0028; the DLL's four sends and
  `spell_gems` signal, wired by name. **Existing bars** lived only on players' machines, so a
  character the server never held a bar for offers its bar once, each spell checked as a
  memorize would be (accepted residual: that one seed skips the memorize time and mana, for
  spells the character could memorize anyway). Tests: a refused unmemorized cast, the memorize
  timing (early, stood-up and closed-gem refusals, then half of 20 mana), the one-time seed
  across a relog; the harness pre-memorizes every class spell, so the 70 existing casts are
  unchanged. **Hosting-branch note:** add the four spell-bar intents to the per-connection
  intent budgets when `feat/public-hosting` merges (a refused one answers with the bar). **The
  client-authority list's fixes 1 to 5 are all built;** item 6 (active skills, Bard songs,
  alignment, fall damage) stays as their own builds. **Item 6's active skills BUILT
  2026-10-19** (the "Active skills partly do not work online" entry has it); **Bard songs
  BUILT 2026-10-20** (the "Bard song rework" entry); **alignment DESIGNED 2026-10-20** as
  part of the factions design (the "Faction system" entry, `factions_and_alignment.md`,
  decisions pending); **alignment BUILT 2026-10-23** with factions slice 1 (that entry);
  fall damage remains.
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
- [x] **Login rate limit is too tight for real humans** — **CLOSED 2026-09-17 by user
  decision: "We don't need the login rate-limit."** The `PD_NO_RATE_LIMIT=1` kill-switch stays
  active on the R720 indefinitely; no threshold retune happens. Nothing is deleted — the
  limiter, the dummy-Argon2 timing defence, and the kill-switch all remain in the code, so
  re-enabling is removing one env var. **Standing security caveat (the reason this is safe):**
  the server is reachable only over the private tailnet, so brute-force exposure is near zero.
  **If the server is ever exposed beyond Tailscale, re-enabling the limiter is mandatory
  before the port opens** — that caveat is the surviving obligation of this item. (History:
  found 2026-08-11 when the 5-per-60s gate pushed the first tester into creating a duplicate
  account; the 2026-09-17 fresh-world wipe retired those duplicates.)
- [x] **No way to reset an account password** — **BUILT 2026-09-30** (server `1c1f523`;
  `cargo run -p projectdawn-server --bin reset_password -- <username>` generates and prints a
  password once, or `-- <username> --stdin` reads one; the password is never an argv word,
  since argv lands in shell history and other users' `ps`). `db::reset_password` writes the
  Argon2 hash AND purges every session row for the account in ONE transaction, so a live
  session cannot outlive the reset; the bin is a thin front end so there is one
  implementation. Unit-tested: new password works, old one stops, a pre-reset session token
  stops being redeemable, a short password is refused leaving the old intact, unknown account
  errors. Exercised against a COPY of the dev `world.db`. **This is a tool, not a feature —
  ticked on the tests plus the dry run, since there is no in-game surface to playtest.** The
  self-serve change-password flow stays open below. *(Original entry, for the record:)*
  A tester who forgets their
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
- [ ] **Self-serve change-password flow** *(the surviving half of the item above, 2026-09-30)*. The
  operator bin covers the lockout case; a player changing their own password needs the three
  things named directly above (old password re-verified, its own rate-limit budget, session
  invalidation), plus a launcher or in-game surface. Not a friends-build need.
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
  **Batch 2 SHIPPED 2026-08-23 — this entry sat stale for 17 days** *(caught by the 09-09
  audit)*: `f1aaf79` ("Report refusals, batch 2: inventory, group, and bind") covered the
  inventory family, the group arms, and `BindAtCurrentLocation`, and the 08-24
  `silent_refusals_checklist.md` playtest exercised the surface; later handler reads confirm
  EquipItem / UnequipItem / SplitStack / DropItem / DestroyItem / UseConsumable all answer
  today. **RECOUNTED + CLOSED OUT 2026-09-30** (server `2e59690` on the deploy branch,
  cherry-picked from the trade branch; pending playtest). The recount found **11 silent arms,
  8 player-reachable**, each charging full mana for nothing; all 8 now refund and report via
  the out-of-range arm's pattern: ALLY heal on someone who just died or zoned, an ENEMY nuke
  with NO target selected (the user reported exactly this on 2026-05-05 and the server half
  was that it ate the mana), an ENEMY spell on yourself, a PvP target dead or gone (liveness
  hoisted above the mutable borrow so the refusal can refund), AOE with no radius, PET_SUMMON
  with an empty or unknown pet_type (the client-only spell backlog reaches this in ordinary
  play), and all three PET_CHARM arms. Only PET_SUMMON's vanished-caster arm stays silent —
  nobody left to tell. Several arms went debug to info so player-visible failures show at the
  default log level. **Checked, no change needed:** `fan_out_cast_fail`'s broadcast is not a
  leak, because the client filters CastFail by caster id (`remote_player_manager.gd:216`) and
  bystanders only use it to cancel the caster's bar. Integration test
  `enemy_spell_without_a_target_refunds_and_reports` pins the headline case (line AND refund).
  Ticks when a playtest sees a refused cast keep its mana.
  **Superseded in shape 2026-10-02:** the cast refusals no longer refund, because they no
  longer take anything; a pre-flight refuses before the mana comes off (see "Spells had no
  reach" above), and the refusal arrives as "Cast failed: <reason>". The playtest row is the
  same: a refused cast keeps its mana.
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
  **2026-08-27:** the group playtest showed a skill's stamina cost is invisible to group-mates —
  the spend is client-local (`skills.gd`), the server's stamina never moves, so nothing fans.
  Another face of the missing server skill model tracked here.
  **Seen again in the 2026-10-07 journal:** six `Attack rejected — swing-rate limit (too
  fast)` lines for char 1 in four minutes of melee, wielding Bonecrusher's War Axe
  (`weapon_delay` 3.2, no proc, so `min_interval` 1.25). With no proc on the weapon the only
  client-driven second Attack inside 1.25 s is an active damage skill fired mid-cycle: this
  gap in play, not a limiter false positive. Each one cost the stamina and the cooldown the
  client had already spent. The user can confirm which skill was on the bar.
  **SERVER-SIDE ACTIVE SKILLS BUILT 2026-10-19, pending the Oct 22 bump and the playtest**
  (client-authority audit item 6, the first of its four; user: "GO!!!"; `feat/server-speed`
  in both repos; `active_skills_checklist.md`, 23 rows). `UseSkill` carries the skill's name
  under the unshipped PD_W0028 (it was a never-sent `skill_id`), and the server owns all of
  it: `data/active_skills.toml` (every one of the client's 32 skills; `active_skills.rs`;
  `tools/check_active_skill_lockstep.gd` exits 1 on any difference either side), the class
  gate, a per-skill cooldown (`COOLDOWN_GRACE` 250 ms, the global cooldown's reasoning), the
  stamina (charged and fanned at once, so a group-mate's panel moves with it), and the swing:
  the ordinary main-hand roll times the skill's multiplier (Backstab x3 is real now), outside
  the auto-attack limiter, so a skill fired mid-cycle is no longer dropped. Effects, all
  server-side: **Shield Bash** stuns the mob for 3 s (a new `CcKind::Stun`, frozen like mez
  but damage does not wake it; "Stunned" on its frame; on a player, no move, swing, cast or
  skill); **Evade** and **Primal Instinct** deflect every melee swing for 5 s (fanned as an
  Evade); **Holy Shield** is a 60-point absorb; **Hide** keeps idle mobs from noticing the
  user (a mob already provoked still finds them; moving, the first swing, a damage skill or
  a hostile cast ends it); **Feign Death** rolls 80% on the server, a success wipes the user from every
  mob's hate and holds them unnoticed until they move (standing ends it, as in EQ; two
  minutes at most); **Warder's Fury** is the hit plus `/pet attack`; **Truesight Strike**
  never misses and ignores Evade. A refusal (unknown, not your class, stunned, on cooldown,
  too tired, no target, too far, dead) costs nothing and answers with a private `SkillFail`
  so the client drops the cooldown it drew. The client sends and shows: no stamina spent,
  no local effect, the buff bar follows the server's snapshot (Evade, Hide and the shield
  reconstructed from the skill definition, cleared when the server drops them). **Not
  built:** the four alignment variants (Paladin_Fallen, Shadow Knight_Redeemed) are refused
  for everyone until alignment is server-side; a stunned player's own bar shows nothing (the
  name reaches peers' frames); Feign Death ends the user's DoTs with their hate (an
  FD-and-DoT farm would otherwise pay from safety). Tests: unit (the table, the cooldown
  grace, the FD roll, a hidden player unseen by the idle scan yet found by threat, a stunned
  mob neither moving nor swinging) and seven integration tests (Backstab tripled, charged
  and refused on cooldown, class and stamina; the stun; feign death told and held until a
  move; hide until the first swing; evade; the shield; a guarding warder sent by the skill),
  every one failing on the previous server, which had no `UseSkill` handler at all. A
  headless probe covers the client half. **Hosting-branch note:** add `UseSkill` to the
  per-connection intent budgets when `feat/public-hosting` merges.
  **Review pass the same night, 12 findings, all fixed** (session note §9): the skill's
  target refusals were a char-id oracle (three lines told absent, unflagged and far apart;
  presence, liveness and reach share one line now, the 10-02 rule, and the plain Attack's
  "Unable to attack <name>" names only a target in reach); one `UseSkill` per user per tick
  (the CastSpell rule; every copy in a forged datagram was answered); **Hide ends on
  movement** (its 30 s on a 10 s cooldown was a free walk through every camp; classic EQ's
  Hide held only while you stood still, and a later Sneak skill is the EQ answer if walking
  hidden is wanted); a Hide while hidden and a Holy Shield while its pool holds are refused
  ("You are already hidden.", "Your shield still holds.": a re-press used to refill the pool
  for 10 stamina); a stun refuses a CastStart and ends a running cast outright (a bar begun
  under the stun and released after it went through); the stamina spend rides the regen fan
  alone (it was fanned twice); a skill-backed success line goes through `send_system_line`,
  not `send_refusal`; the helpers sit where rustdoc attaches their own comments. Tests
  strengthened: Backstab's bound skips a crit (a crit alone could reach it), Feign Death
  tries fresh monks until a success so the hold path is always exercised, Hide covers the
  step and the re-use refusal, and the harness heartbeats through long waits (a 10.3 s silent
  wait had read as a drop at the server's 10 s timeout).
  **DECIDED 2026-10-20 (user): Hide ending on movement stands ("Good choice"), and a Sneak
  skill will be built** (EQ's: the rogue moves at a walk while sneaking, unseen from behind;
  with Hide it is the classic move-while-hidden pair). Not designed yet: its own entry below.
- [ ] **Sneak skill (Rogue)** *(user 2026-10-20, with the Hide decision)*. The skill that lets
  a hidden rogue move: in classic EQ, Sneak alone makes the rogue invisible to mobs facing
  away and walks them at a reduced speed; Sneak and Hide together let them move unseen. Needs
  a design pass on the server side (a Sneak buff that `end_on_move` spares, a speed multiplier
  while it holds, and whether facing matters, which needs the facing model this project does
  not have); a new entry in both skill tables and the lockstep check. Not a friends-build
  need; sequenced after the remaining client-only systems (Bard songs, alignment).
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
- [x] **`CancelCast` is a missing feature, not a broken one** *(found 2026-08-24; **BUILT
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
  15-second re-check: cancel and touch nothing; the bar must stay refunded. **CLOSED 2026-08-27,
  item DONE + playtested**: the deliberate cancel-and-wait ran clean (plump, Reclaim Soul on
  FIGHTME's corpse, ESC mid-bar, 20 seconds untouched, mana never re-consumed on either group
  display), and the hit-while-casting row exercised itself in the same session (`cast
  interrupted by incoming damage caster=4 spell=Reclaim Soul`, 21:37:03) with a clean re-cast
  and res offer/accept after. Every row of `cancel_cast_checklist.md` now passes.
- [x] **Bank coin deposit will not break a larger coin** *(found 2026-08-21; **BUILT 2026-08-21,
  pending playtest** — `Coins::take_breaking_higher`, applied to deposit AND withdraw)*. With
  `1p 5g 5s 75c`, depositing `6s` is refused ("You don't have that coin to deposit") rather than
  breaking a gold into silver. The four tiers are **deliberately independent stacks** with flat
  per-coin weight, so auto-breaking would cut against that design. A design call, not a bug: either
  the banker breaks coin as a service (fits the Banker's "relief valve" role), or the refusal
  message should explain the tier rule instead of sounding like a bug. **DONE + playtested
  2026-08-27** (§1 of `coin_and_stack_checklist.md`: deposit and withdraw both break a higher
  tier; asking for more value than held is still refused, with the refusal line).
- [x] **Coin normalises through a corpse, which changes its weight** *(found 2026-08-21; **BUILT
  2026-08-21, pending playtest** — corpse loot now returns coin tier by tier)*. Died
  with `1p 5g 7s 312c`, looted back `1p 5g 10s 12c`. The **value is identical** (312c = 3s 12c) so
  nothing is lost, but the game charges *flat weight per coin*, so 312 coins became 15 and the
  player returned lighter than they died. Dying compresses your coin. Minor, but exploit-shaped:
  a player carrying a large copper float could deliberately die to shed weight. The corpse stores
  a total and reconstitutes it normalised; preserving the original per-tier split would keep the
  four-independent-stacks design honest.
  **Fixed at `tick.rs`'s corpse-loot block**, which flattened the corpse to `total_copper()` and
  added it back with `add_payout` (which normalises). It now returns the corpse's coin with
  `add_each`, tier by tier: what went onto the body is what comes back off it. **DONE + playtested 2026-08-27**
  (§2: per-tier counts return exactly; encumbrance identical before the death and after the
  corpse run).
- [x] **Stack All scope** *(requested 2026-08-21; **BUILT 2026-08-21, pending playtest** — both the
  hosted and offline paths now consolidate within a container only)*. Ask for it to consolidate only within a
  container rather than across the whole inventory. The tester's note is cut off mid-sentence, so
  **the exact rule wanted needs confirming** before building anything — most likely "merge within a
  bag, and within the base slots, but never move items between the two". **DONE +
  playtested 2026-08-27** (§3: merges stay within each container; post-merge dragging produced
  zero `source slot empty` rejections — the desync canary stayed quiet).

- [x] **Audit the schedule and the To-Do for accuracy end to end** *(raised 2026-08-24 by the user:
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
  **Audit RUN 2026-09-09** (full read of both schedule copies + code-verified walk of the open
  To-Do entries; closes when the two decisions below land). Stale entries found and corrected in
  the same pass: silent-refusals batch 2 (shipped 08-23, listed open for 17 days), player
  inspect ("in progress" but built + command-triggered), the ring-reward hypothesis (disproven
  on BOTH data sources), the rate-limit entry (missing the active kill-switch), the group-bars
  verify step (settled: server-side fan), stale line refs on the jump entry. Schedule drift
  found and synced: the html header chip still read "Status · Aug 11", the md status row and
  html item lists had again drifted opposite ways (html carried four phase-3 entries the md
  bullet list lacks; md's row carried three sittings the html lacked), both risk tables still
  taught the retired "flaky trio" rule, and neither copy mentioned the Aug 28 to Sep 9
  cursor-slot epic at all — confirming suspected cause (b): finding-shaped work never reaches
  the schedule. **Decision 1 (structural): DECIDED 2026-09-09 — yes.** Stop carrying per-item status in the schedule —
  freeze each phase's bullets as "the plan as drafted", keep one-line status-table entries, and
  let this To-Do be the only live list. That is the html's own "one home per fact" rule, which
  both copies violate; three hand-synced tellings of phase 3 is the root cause of every
  recurrence. **Decision 2 (the date): DECIDED 2026-09-09 — slipped.** New
  target **2026-10-05**, the mechanical re-base (phase 4's full three weeks now Sep 10 to
  Oct 1, plus the original slack); the three-hour content bar stands. Applied to both schedule
  copies same pass. Decision 1 landed the same day: both copies' item lists frozen as dated snapshots, the
  one-line §7 status table is the schedule's only live part, and Session workflow step 6 now
  reflects it. **Item CLOSED 2026-09-09** — both decisions applied.

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
  **DESIGNED 2026-10-04: `docs/design/bind_and_gate.md`** (EQ and SWG reference, what exists,
  a twelve-point exploit ledger, three slices). **Six decisions wait on the user (§7)**, each
  with a recommendation: where Bind Affinity may bind (recommended: not within 60 m of a
  hostile spawn point, which keeps the caster perk and removes the self-built death loop),
  binding others (self only for now), an unbound Gate (goes to the starter spawn like
  Respawn), the pet on Gate (comes along unless parked), Succor and Evacuate (wait for the
  content pass: their numbers are offline-era leftovers and the only safe point is the town),
  and who gets Gate (content call). **The scope shrank again:** the wire addition this entry
  expected is NOT needed. The client never has to know where the bind is; the server moves
  the player with the existing `Teleport` message and confirms a bind with a chat line. So
  slice 1 (Bind Affinity + Gate) needs no protocol bump and no DLL rebuild, and does not have
  to wait for the trade window's deploy day. Also verified while writing it: online today the
  client runs its own Gate and bind in the same function that sends the cast, so Gate
  reloads the whole world scene and Bind Affinity prints "You are now bound" next to the
  server's "That magic has no effect here yet."
  **ALL SIX DECIDED 2026-10-05 (user), recorded in the design doc's §7:** self-bind anywhere;
  a GROUP MEMBER can be bound only inside a safe area (town); every character is bound at the
  starter spawn from birth; the pet always comes on Gate; Succor and Evacuate get built now;
  Gate goes to the nine pure casters plus Bard. Build-ready as step 2 of
  `docs/design/spell_batch_plan_2026_10_05.md` (approved 10-07).
  **BUILT 2026-10-08, pending playtest** (server `75ab979`; client `spells.gd` + the Gate class
  list in the same-day commit; `bind_and_gate_checklist.md`, 23 rows; needs the redeploy AND
  the next export, since the old client still reloads the world scene on Gate). One bind, the
  server's: a `BIND` arm (self anywhere; a group member only inside a safe area; a non-member
  gets one line whether absent or present, so no is-online oracle) and a `PORT` arm
  (`Spell.port` "bind" for Gate, "safe" for Succor and Evacuate: the nearest safe area's
  arrival point; the destination never comes from the client; the move is the existing
  `Teleport`, no wire change). `data/safe_areas.toml` holds the town square, with a unit test
  that no camp's aggro plus jitter reaches into a safe area. Every mover is wiped from every
  mob's hate and the cleared mobs are fanned as `EntityTarget None` (`wipe_hate` is shared
  with the death sweep, which had never fanned the change either); pets come along in Follow
  with their AOI cell updated; Evacuate takes the alive, present, non-linkdead members within
  30 m and nobody else. Gate: ten classes at 8, 50 mana, 5 s, 300 s cooldown; Succor:
  Druid/Wizard 12; Evacuate: Druid 16. `PlayerStats.bind_zone_path` is offline-only now.
  Tests, all failing on the previous code: Gate lands at the bind and the aggroed mob drops
  the caster; a second Gate inside the cooldown is refused; a Warrior cannot Gate; a group
  member is bound only in the square; Evacuate moves the member in reach and not the stranger
  beside them; binding a stranger is refused before the mana comes off. What exists is in
  systems_overview → "Respawn, bind points, and the death lock". The seven zone ports stay
  client-only and refuse online (no zones to send anyone to).
  **Review pass, two HIGH finds fixed same day** (server `7e07351`, both test-pinned, failing
  on `75ab979`): a CHARMED mob is a pet with the charmer as owner, so it rode every port into
  the town square and stood there hostile when the charm ended (a named mob, even); it is now
  released where it stands and walks home, as when its charmer logs out, and only summoned
  pets are carried. And the arm cleared the pet's target but not the owner's
  `last_attacked_enemy`, so the pet pre-pass handed the pet its old target back within 10 s
  and it walked out of town to fight unsupervised (a pet kill credits the owner); the mover's
  last-attacked fields are cleared with the port. Smaller: bind-other reaches 30 m like any
  friendly cast; the pet's move fans next tick, not at the keepalive; the group-bind test reads
  both binds back from the DB and Evacuate's test has a grouped member out of reach.
  **Flagged, not changed (content):** the square is 10 m round the spawn and cannot grow much
  (the Bonepile's nearest spawn leaves 10.3 m of aggro clearance), so a group member standing
  at the far NPCs on the z = 5 row (x out to 14) cannot be bound; the user may want a second
  safe area there or the NPCs closer in.
- [x] **The vendor window claims a quantity and price the server never agreed to** *(found
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
  "Purchased" / "Sold" wording, which is accurate there. **DONE + playtested 2026-08-27** (§4:
  request wording shown, server refusal arrives in chat, no coin charged on refusal, sell price
  is the server's number). The full-bags row surfaced the separate bag-space finding directly
  below.
- [ ] **Buying and granting ignore bag space** *(found 2026-08-27 during the vendor-narration
  playtest: "Your bags are full" with empty slots in two carried pouches)*. Server-side:
  `inventory.rs::add_item_locating` places into the `BASE_SLOT_COUNT` base slots only — the
  `bags` map is never considered — so `BuyItem` and `GmGive` (they share the refusal string)
  refuse a purchase the player has room for. Log: three consecutive
  `BuyItem rejected — inventory full, no stack placed` with both pouches empty. Scope when
  fixing: every `add_item`/`add_item_locating` caller (loot and quest rewards likely share the
  placer — confirm), a pass-3 bag scan, and nothing new on the wire (`InventoryDelta` already
  speaks `bag_<i>`). Decide deliberately whether any path should stay base-only by design; the
  tester's expectation is that bags fill.
  **BUILT 2026-09-09, pending playtest** (server `393e0eb`; `bagspace_groupbars_checklist.md`;
  no client change, no protocol bump). The placer runs its two passes over bag inners too —
  base top-ups, bag top-ups, base empties, bag empties, deterministic bag order — with the
  bag-in-bag ban intact, and all six call-site delta fans (BuyItem, GmGive, bank withdraw,
  quest rewards, corpse loot, loot bags) went location-aware through `peek_at`. Per the user's
  call ("have them both use the same system"), `can_accept` — the quest turn-in pre-flight —
  now clones the inventory and probes the REAL placer instead of hand-simulating base-only
  placement, so capacity answers and actual placement can never disagree. 217/217 tests, four
  new. **Field evidence so far (09-25 to 09-27):** the loot refund path ("partially placed;
  remainder refunded", seven-plus firings), the GmGive full-bags refusal, and the can_accept
  turn-in pre-flight all behaved correctly in real play — but the pouch-interior placement
  rows (`bagspace_groupbars_checklist.md` §1) remain unexercised because no tester has
  carried a pouch on the fresh world yet. Ticks when §1 runs.
- [x] **Group panel bars are blank until the first resource update** — **DONE + playtested
  2026-09-27** (server `01dd8fa`; `bagspace_groupbars_checklist.md` §2 +
  `phase4_content_checklist.md` §6: the first two-seat session on the build, and both
  members' panels showed full HP/MP/stamina the moment the group formed). What exists is in
  systems_overview → Networking ("Group panel seeding"). One row rides the next two-seat
  session: a member leaving while the survivor watches their panel (unobserved — both seats
  disconnected 2 s apart).

- [ ] **NaN Move direction poisons position and bypasses range gates** *(found 2026-09-25
  during the zone-size research; verified in source, not yet exploited in play)*. A forged
  Move whose `direction` carries NaN/Infinity slips through `clamp_length`
  (`connection.rs:43` tests `len > max`, false for NaN) and the tick makes `conn.pos`
  permanently NaN. Every rejection gate shaped `if dist > RANGE { refuse }` then passes
  (comparisons with NaN are false): corpse loot `tick.rs:7898`, loot bags `:8123`/`:8406`,
  res `:3817`, attack and spell range. A modified client could loot any corpse/bag and act
  from anywhere; NaN also spreads into mob positions via chase AI, and SQLite persists NaN
  as NULL (reloads 0.0). An honest client can never send one. **Fix is a few lines:**
  reject non-finite direction components in the Move handler, mirroring the `is_finite`
  guard `DevSpawnMob` already has (`handlers.rs:793`). Server-only. Fits the audit frame:
  magnitudes validated, eligibility inputs less so. Details in
  `docs/design/zone_size_limits.md` §5.
  **BUILT 2026-09-27** (server `4a55be7`): the guard drops the packet before any state
  including sequence bookkeeping; integration test `nan_move_direction_is_dropped` pins the
  exploit end to end (only a forged client can send one, so the test is the exploit-side
  evidence, the respawn-dead-check precedent). Ticks after the redeploy's ordinary-movement
  regression row (`xp_eligibility_and_pet_levels_checklist.md` §3).
- [ ] **Public-host hardening checklist (mandatory before any exposure beyond Tailscale)**
  *(the residuals from the 2026-07-29 rate-limit build and systems_overview's "known
  residuals", plus server_design.md's "add later" list; gathered by the 2026-09-29 audit so
  they stop living in three places)*. The friends build deliberately accepts all of these on a
  private tailnet. (1) Re-enable `LoginRateLimiter` (remove `PD_NO_RATE_LIMIT`; the standing
  caveat on the closed rate-limit item). (2) A banned account is distinguishable by error code
  and a faster no-Argon2 path (needs a ban-UX decision). (3) The fixed window allows a ~2x
  burst across its boundary; an attacker rotating IPs (an IPv6 /64) gets a fresh budget per
  address; NAT/CGNAT co-tenants share one budget (no global cap). (4) From server_design: a
  per-account login budget, action rate limits (e.g. 30 inventory ops/s), position-anomaly
  logging, a nightly dupe-detection query, an optional client integrity hash, input replays.
  (5) TLS for the auth WebSocket. None of it is a friends-build blocker; all of it gates a
  public port.
  **Plan 2026-10-08, BUILT 2026-10-12 (slices 1 to 3), pending the host sitting and the
  cutover playtest** (`docs/design/public_hosting_plan.md`; `feat/public-hosting` in both
  repos, server `e977cf4` + `eb7d96f` + `fe004db`, client `198c333`;
  `public_hosting_checklist.md`). The user is leaving Tailscale for good (a tester runs Nord
  Meshnet, which will not run beside it): a port forward, DuckDNS, Caddy for TLS, invite
  codes, one cutover day. Server: socket limits (64 KB cap, 10 s handshake, 10 min idle, 8
  connections per address), `X-Forwarded-For` trusted from loopback only, the limiter keyed
  by IPv6 /64 with a global ceiling and a per-account budget (items 1, 3 and 4), a ban that
  answers like a wrong password until the password is right (item 2), an `invites` table
  (migration 0012, forward-only) with `Register.invite` burned in the account's own
  transaction and the `invite` bin, `PROJECTDAWN_WORLD_ENDPOINT` as a name with an address
  watch that checkpoints everyone and exits for systemd when it moves, and two
  per-connection intent budgets (inventory 64/16 s, cosmetic broadcasts 40/20 s; finding
  10c's rate cap). Client: `wss://` for any non-local server (item 5), an invite field,
  `tools/check_login_url.gd`. Kept off the deploy branches until cutover: exported early,
  the wss rule would stop the tailnet testers connecting, and the migration means an older
  binary cannot boot on the migrated `world.db`. Still later, by the plan: a per-account
  login budget is in; position-anomaly logging, the nightly dupe query, the client
  integrity hash and input replays are not. **Reviewed 2026-10-12** (server `72fa214`,
  client `9a43c33`; session note §6): the account and global caps were lockout levers
  (one address could keep an owner out indefinitely, two dozen could refuse every login),
  closed by exempting the source an account last logged in from and refunding a success;
  every auth send under the idle timeout; canonical addresses; wider intent budgets; the
  launcher keeps its session across the idle close. The review also found two bugs older
  than the branch, fixed on the deploy branch as their own entry (Death / corpses).
  **Latency readout BUILT 2026-10-13, pending the export** (on the DEPLOY branches, server
  `a18e355`, client `f6aa0ff`; `public_hosting_checklist.md` §1 has its row; session note §5).
  Asked for after the user's "keeping latency in mind?" question: `/ping` prints renet's
  smoothed round trip and packet-loss estimate for the world connection (the DLL's new
  `rtt_ms` / `packet_loss`, called by name so a stale DLL costs the command, not `Net`), the
  server logs a `player link` line per player once a minute, and `tools/check_wire_layer.gd`
  says whether a checkout's DLL carries what `Net` calls by name. Needs the DLL rebuild the
  Oct 22 export already carries; the server half rides the next redeploy.
- [ ] **Exploit-audit finding 10 residuals (Low)** *(`docs/security/exploit_audit_2026-07-08.md`
  §Finding 10; the only audit finding with open parts, never given a To-Do home until
  2026-09-29)*. (a) `InspectPlayer` has no range or line-of-sight gate (any in-world paperdoll
  readable from anywhere; minor disclosure, and the NPC proximity idiom makes it a five-line
  fix). (b) Movement has a speed cap but no server-side collision, so a modified client clips
  through walls at legal speed (the height model work is the natural home). (c)
  Hit/Miss/Evade and the cast broadcasts are cosmetic fan-outs a client can forge onto peers'
  screens (no state change; worth a rate cap when public). `EquipItem` item-vs-slot, the
  fourth part, is DONE (Track 14.1).
  **(a) BUILT 2026-10-01, pending playtest** (server `3523bd1` + review fixes `30f0474`, client
  `cd9f1d1`; `inspect_range_gm_audit_ban_checklist.md` §1). `InspectPlayer` requires the two
  players within `INSPECT_RANGE` (30 m, written keep-only-when-in-range so a non-finite
  distance refuses); the client checks its own tighter 20 m first so an honest player gets a
  clean "too far" line. The review caught that the first cut's refusal NAMED the target and
  answered far and absent ids differently, which would have made the gate a char_id to name map
  and an is-online oracle; far, offline and never-existed now get one generic line and the same
  empty result. No line-of-sight half (there is no server collision model; that stays with
  (b)). (b) and (c) remain open.
- [ ] **GM action audit log** *(deferred "to a fast follow" when `is_gm` shipped 2026-07-17;
  server_design's day-one rule "all GM actions audited"; the `gm_actions` table has existed
  since the auth schema; audit 2026-09-29)*. Write one row per dev/GM command (`/give`, coin
  grants, dev spawns, Full Heal, Level Up) with account, char, payload, timestamp. Read-only
  value today (one operator), load-bearing the day a second GM exists.
  **BUILT 2026-10-01, pending playtest** (server `b47aadb` + review fixes `30f0474`;
  `inspect_range_gm_audit_ban_checklist.md` §2; server-only). The gate and the audit are ONE
  call, `PerConnection::authorize_dev_cmd`: a dev command runs only if its `gm_actions` row
  was queued, and one that cannot be recorded is REFUSED, never run unrecorded. All six
  dev-gated handlers go through it (`grant_xp`, `dev_spawn_mob`, `damage_self`, `heal_self`,
  `give_coins`, `give`). Rows are written in one transaction per tick, before any reap, and
  `reap_connection` flushes its own. Each row ends `via=gm`, `via=dev` or `via=gm+dev`: on the
  R720 anything with `dev` in it means the server ran with `PD_DEV_CMDS` on. A refused
  (unauthorized) attempt writes nothing, so no ordinary client can make the server write. The
  write bound is a per-connection token bucket (burst 128, refill 8/s), sized so the Test
  Panel's crafting-materials button (about 34 gives in one frame) is recorded whole.
  `admin_report` shows the newest 50 rows (console + HTML card). **The review's catch, and why
  the shape changed:** the first cut capped a tick at 8 rows but still RAN the commands past
  the cap, so a GM client could bury a coin grant behind eight fillers.
- [ ] **Account admin tooling: ban/unban and delete/purge bins** *(`handoff_account_admin.md`
  2026-07-31; audit 2026-09-29)*. `is_banned` is enforced at login but nothing can set it, and
  there is no account delete or purge. Same shape as `grant_gm` and the scoped
  `reset_password` bin above: operator-only, session rows cleared on ban.
  **Ban/unban BUILT 2026-10-01, pending playtest** (server `81150c7` + review fixes `30f0474`;
  `inspect_range_gm_audit_ban_checklist.md` §3). New `admin_account` bin: no args lists accounts
  (flags, ban reason, live characters, live sessions), `ban <username> [reason]`, `unban
  <username>`. `db::set_account_banned` writes the flag and reason AND purges the account's
  sessions in one transaction. The ban bites at login, at EVERY session redemption
  (`touch_session`; the review found that a login in flight when the ban landed got a usable
  session, because only the login path checked the flag), and at world connect
  (`KickCode::BannedNow`, for a connect token minted just before the ban). A re-ban with no
  reason keeps the reason on file. **Delete/purge is deliberately NOT built and stays open
  here:** the 2026-09-17 wipe retired the throwaway accounts that motivated it, and every child
  table cascades from accounts or characters EXCEPT `gm_actions` (which now has rows), so a
  delete must first decide what happens to audit history.
- [ ] **Kick by account: a ban or password reset does not remove a character already in the
  world** *(the stated limit of both ops tools, 2026-10-01)*. `admin_account ban` and
  `reset_password` close every way IN (login, session use, world connect), but a connection
  that is already in the world keeps playing until it drops; today the operator's only lever is
  a server restart, which costs everyone up to 60 s of progress. Shape: at the 60 s checkpoint
  (the world loop already has the pool there), read the banned account ids, and kick any
  connection whose account is in the set with `KickCode::BannedNow`. One small query a minute.
  Decide deliberately whether the kicked character reaps at once or lingers linkdead like any
  other unclean exit (lingering is the anti-force-off default and is probably right).
  **Ban half BUILT 2026-10-02, pending playtest** (server `9b0bf87` + `8e662d6`;
  `inspect_range_gm_audit_ban_checklist.md` §3). The world loop runs a ban sweep every
  `BAN_SWEEP_INTERVAL` (10 s, tighter than the checkpoint this entry proposed, since the query
  runs on its own task and never blocks the loop): any connection whose account is banned is
  sent `KickCode::BannedNow`, its messages are ignored from that moment, and the server drops
  the transport `KICK_FLUSH_GRACE` (1 s) later so the kick arrives first. The character then
  leaves by the ordinary unclean-exit path (the linger was kept, as proposed). **Found
  2026-10-04: the kicked CLIENT showed nothing** (no in-world listener for the kick reason);
  the disconnect notice built that day is what makes "told why" true, and it needs the
  export. **Still open:
  the password-reset half.** Nothing in the database says "end sessions that began before
  now", and adding a column for it means a migration, after which an older binary refuses to
  boot on that database (no rollback). `reset_password` names the lever instead: ban, wait
  for the `banned account kicked from the world` log line, unban.
  **DEFERRED FAR OUT 2026-10-16 (user): "I dont want the password-reset kick for a long time.
  Im not worried about systems being abused by the people who are using the server."** Not a
  friends-build item; it sits in the planner's after-the-door strip. Revisit only if the
  player base grows beyond people the user knows, alongside the public-host hardening.
  **Scope of the deferral (user, same day):** it covers this one operator tool only. It does
  NOT relax anti-cheat work: development stays vigilant for hacks, dupes and cheats in every
  build, whoever is playing.
- [ ] **PET_CHARM had no range check** *(found 2026-10-01 while reading the charm arm for a test
  fix; **BUILT same day, pending playtest**, server `30f0474`;
  `inspect_range_gm_audit_ban_checklist.md` §4)*. The charm arm checked that the target id was a
  live enemy and nothing else, so a modified client could charm ANY mob in the world by id from
  anywhere (a named mob from the safety of town). It now has the nuke arm's reach
  (`RANGED_ATTACK_RANGE`, 25 m), written keep-only-when-in-range, refunding and answering "That
  target is too far away." Integration test `charm_refuses_a_target_out_of_range` runs the
  exploit as a client would: the caster names the id of a mob two cells away that it was never
  even told exists. Same audit frame as always: the server validated what the spell does and
  not whether the caster was entitled to cast it there. The sweep of the other target-type
  arms ran 2026-10-02 and found two more; see the entry directly below.
- [ ] **Spells had no reach on heals, buffs or PvP nukes, and a refused cast was a free
  skill-up** *(found by the 2026-10-02 sweep; **BUILT same day, pending playtest**: server
  `fe0e789` + `8e662d6`, client `228db25`; `inspect_range_gm_audit_ban_checklist.md` §4)*.
  **ALLY spells** (heals and buffs, on a player or a pet) and **ENEMY spells against a player**
  had no range check at all: a modified client could keep a friend alive in a dungeon from
  town, or nuke a PvP-flagged player from across the world, by naming an id. Separately, the
  09-30 refund work handed mana back AFTER the handler had stamped the cooldown and rolled
  the casting skill, so a cast the server was always going to refuse was a free skill-up
  attempt and still burned its cooldown; Bind Affinity (no server arm, on ten classes' bars
  at level 1) made that reachable from an HONEST hotbar every three seconds.
  **Built as** `cast_target_refusal`, one pre-flight that runs before the mana comes off and
  covers every target type: presence, liveness, reach (`RANGED_ATTACK_RANGE`, 25 m, written
  keep-only-when-in-reach) and the PvP gates for ENEMY / ALLY / PET_CHARM; CORPSE; an AOE with
  no radius; a summon with no known pet; any type with no arm. A refused cast costs nothing
  at all. Also: **one CastSpell per caster per tick** (one cast bar used to authorise any
  number in a single datagram); refusals are a **private CastFail** (the client's signal to
  drop the cooldown it started; current builds print "Cast failed: <reason>"); and **no
  refusal names a player** (far, offline and never-existed targets share one line; "Unable to
  attack <name>" used to answer for any connected char id from anywhere). Client half, next
  export: a 24 m range check before the cast bar, and the cooldown handed back on a refused
  cast. Tests run the exploits as a client would and fail on the previous code.
  **Design note, flagged not decided:** heals now share the nuke's 25 m reach because spells
  have no range field; say so if heals should reach further (a per-spell range is the real
  answer, with the content pass).
  **DECIDED 2026-10-19 (user): per-spell ranges, "we should do this for sure", on the
  Monsters and Memories baseline.** Research (the M&M wiki, three pages re-checked by hand):
  every single-target spell there lists 30 m (nukes, DoTs, heals, buffs on others, snares,
  roots, slows, mez, stun, charm, fear, lifetaps, debuffs, dispels, bind, resurrection); only
  shapes differ (group spells 30 m to the target plus a 15 to 20 m radius, point-blank AoE a
  10 m radius, one 15 m cone). Build: a real `range` field per spell on both sides, every
  single-target spell defaulting to 30 m (hostile goes from 25 m to 30 m), an AoE radius kept
  separate from the range, the tooltip showing the spell's own number.
  **BUILT 2026-10-19, pending the Oct 22 bump and the playtest** (`feat/server-speed`, server
  `aa225c5`, client `6ab89f1`; checklist §6). `Spell.range` / `SpellData.range` (0 = 30 m) and
  `reach()`, the one reach for every targeted cast, the resurrection's corpse and Evacuate's
  gather; hostile spells go 25 to 30 m; the client checks one metre inside. **The leash floor
  moved 30 to 35 m** (it exists so no mob can be hit from beyond its own leash; a unit test now
  holds every spell inside it). `check_spell_lockstep.gd` compares `range` even when only one
  side writes it (a planted one-sided range is caught). Test: `a_nuke_reaches_thirty_metres`
  (a Smite at about 28 m lands, at 33 m is refused; fails at the old 25 m).
- [x] **Unclean-kill relogin was not refused** — **RE-TESTED 2026-10-13, the refusal holds;
  ticked on the integration test** (server `f58b796`,
  `an_unclean_drop_refuses_relogin_until_the_body_is_reaped`, 43 s of the server's own
  timers) **plus the 06-19 to 06-20 camp-and-linkdead verification**; the test suite is its
  own checklist, as with the flaky-trio item. What the test pins, from the client's seat: a
  client dropped without a Disconnect leaves its body in the world; for the 10 s until the
  heartbeat timeout the old netcode connection still holds the client id and a second
  handshake is ignored outright (a relogin can never boot a live session, the Lineage II
  force-off); from then until the 30 s linger ends, the Connect is refused with a
  DuplicateLogin kick carrying the countdown; after it the login succeeds, and knocking
  every few seconds through the window does not extend it (the dodge-the-reap trap the
  disconnect handler guards against). The checklist row's note ("immediately logged back in
  successfully") does not reproduce against the current server and is annotated in place.
  *(Original entry:)* `banker_slice2_checklist.md:54` is ticked `[x]`
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

- [ ] **Dead group members would receive XP shares (code-confirmed, never seen in play)**
  *(raised 2026-08-27; the original log observation was MISREAD — the tester corrected it:
  FIGHTME had respawned at bind and was alive and in range when the 21:35:30 share landed,
  then took the res teleport later, which the log alone could not show)*. What survives is the
  code fact, verified after the correction: the kill-credit split's member filter is
  online-only (`tick.rs` ~504, `connections.contains_key(m)`) with no dead-check, and a dead
  player stays connected under the death lock — so a member lying dead awaiting a res would
  collect full shares. Classic EQ pays a corpse nothing. A one-line alive filter, but a design
  call — discuss before building. Not exploit-shaped: dead is strictly worse for farming.
  **DECIDED 2026-09-19 (user): "30m plus the alive filter sounds good."** Build shape, settled
  from the 09-09 brainstorm: gate XP shares by proximity to the dying enemy at 30 m (mirroring
  the coin split's `GROUP_COIN_SHARE_RANGE` — verified: the XP split has no range gate today
  while coin does) AND filter out dead members, since a corpse lying beside the mob would
  still collect under pure proximity. The user's companion wish —
  remove a dead player from NPC aggro lists — is ALREADY BUILT and verified (`tick.rs` ~8990:
  the death sweep wipes aggro + threat and clears the mob's target so it leashes; shipped with
  the 08-13 corpse-beating fix).
  **BUILT 2026-09-27, pending playtest** (server `ba2af81` + review fixes `5cf7508`;
  `xp_eligibility_and_pet_levels_checklist.md` §1). As decided: XP shares require online AND
  alive AND within 30 m of the dying enemy (creditor exempt from the range half only — a pet
  owner may direct a kill from afar); alive means `!death_processed && hp > 0.0` so a member
  dropped in the same tick as the kill is already a corpse. The pool divides among eligible
  members only. Integration test pins the exact scenario (dead member beside the mob: no
  share, no dilution — the killer collects 263, not a 157 split). **One deliberate scope
  call, flagged for the user:** quest kill-credit takes the alive filter but NOT the range
  gate — the decision covered XP shares, and range-gating journal ticks would silently change
  quest play; say the word if journal ticks should be range-gated too.
- [ ] **A dead character died again on relogin, and lost reliable packets were never resent**
  *(both found 2026-10-12 by the review of the hosting branch; both older than it; **BUILT
  the same day on the deploy branch, pending redeploy + playtest**: server `6a09aa1` +
  `645606a`, `dead_relogin_and_resend_checklist.md`)*. (a) `from_spawn` set `death_processed: false`
  for every spawn, so a character persisted at 0 HP (a crash, a window-X, a restart while
  dead) was killed again by the death sweep on its first tick back: a second XP penalty and
  a second, empty corpse. Now `death_processed: spawn.hp <= 0.0`; Respawn still works (it
  gates on that flag); the client learns it is dead from the HP seed as before. The
  integration test fails on the old code at the XP assertion. (b) The world loop never
  called `RenetServer::update`, the only place renet's per-connection clock moves, and its
  reliable channels resend a lost packet only when that clock passes the resend time: a
  lost inventory delta, chat line, kick or teleport was never resent. Invisible on a
  lossless tailnet; on the internet it would have read as random desyncs. Called every
  tick now. No client change for either.
- [ ] **Res-sickness** — specced in the plan's Slice 3 but dropped from v1: a short debuff on
  res-accept (reduced stats/regen for a few minutes) via the server buff system. The last piece
  of the plan as written.
  **BUILT 2026-10-14 and REBUILT 2026-10-15 to the P99 design, pending the redeploy, the export
  and the playtest** (server `528ae23`, client `9c5e333`; `res_sickness_checklist.md`, 13 rows; the
  server half works on the client testers hold, the sheet and buff-bar entry need the export).
  **DECIDED 2026-10-15 (user): "Lets keep the design you found on the P99 wiki page. Difficult
  is what we are looking for."** So, classic EQ's Resurrection Effects as Project 1999 keeps
  them: five minutes; "You are exhausted." on landing, "You feel your strength return." when it
  wears off; the player **lands at a quarter of max HP with no mana** (one-shot at the accept,
  announced at once; not damage, so no stand or camp cancel rides on it); and STR, AGI, INT, WIS
  and CON (EQ's STA) lose a **level-scaled fraction of their intrinsic value** (race, class and
  level via `char_data::compute`, never gear or buffs), a tenth at level 1 to a half at 60
  (`buffs::RES_SICKNESS_CUT_AT_1 / _AT_60 / _ARRIVAL_HP_FRACTION / _SECS`, tuning knobs). P99's
  shape: about half a level 60's STR. The first build's level/4 cut and regen halving are gone
  (the regen half was never P99's). The debuff rides the stat-buff path, so the buff tick
  expires it and undoes its deltas like any stat buff. Intrinsic because the client computes the
  same cut from the race, class and level it knows: `PlayerStats.intrinsic_character` (the
  race-class-level math `apply_character` always ran, now callable on its own) and
  `BuffManager`'s reconcile, the fraction in f64 in the same order of operations on both sides
  so they round the same product (kept in lockstep by hand). **Unchanged, by the 2026-06-22
  lock:** the XP refund tiers (25/50/75%). **Flagged:** buffs are not persisted, so a relog
  clears the sickness, as camping did in classic (the dodge costs the camp or linkdead wait; a
  knob if it should persist). Tests: unit (the fraction at 1, 20, 60 and past 60; the cut on
  sample stats and on a level 60 Human Warrior, half off STR 142 and nothing below zero) and an
  integration test where a Warrior dies and respawns, a Cleric 20 casts Resurrection (Minor) on
  the corpse, the owner accepts, is summoned, is told the line, lands at a quarter HP with no
  mana and carries the sickness with five minutes on it; a headless probe for the client half
  (a Human Warrior at 1, 20 and 60). Full suite green (276 unit, 98 integration). *(History:
  the 2026-10-14 build took one point per four levels and halved regen, sized on a wrong claim
  about the stat scale; the user caught it the same evening.)*
  **Server half DEPLOYED 2026-10-19** (R720 boot line `build="33c7e28" dev_cmds=false`, no
  migration); the landing at a quarter HP with no mana, the two chat lines and the
  stat cut are live on the 10-13 export; the sheet and the buff-bar countdown wait for the Oct 22 export.
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
  provenance. **Now slice 2 of the cursor-slot epic** (user-committed 2026-08-27; design:
  `docs/design/cursor_slot_and_reequip.md`) — the cursor slot is the overflow home that makes
  an honest version possible.
  **BUILT 2026-10-13, pending a redeploy and playtest** (server `d598ad6` + `5986f26`, migration
  `0014_corpse_equip_slot.sql`, approved by the user with the instruction to clear the R720's
  four old corpses by hand; `corpse_reequip_checklist.md`, 11 rows; server-only, no export).
  Worn gear goes back on the slot it died in when that slot is empty and still takes it,
  everything else to the bags; overflow stays on the corpse with "Your bags are full: N items
  stay on your corpse." rather than going to the cursor (design doc, slice 2's note). Tests: the
  corpse list covers exactly the stacks the death strip takes, the restore rule refuses an
  occupied or wrong slot, the slot survives a partial loot in the DB, and an integration test
  has a Warrior die in a cap and robe and loot them back onto slots 2 and 3 with the bread in
  the bags and the gear persisted as worn.
  **DEPLOYED 2026-10-14** (R720 boot line `build="5986f26" dev_cmds=false`, the four old
  corpses cleared by hand in the same stop, `loaded persisted corpses count=0`), so
  `corpse_reequip_checklist.md` is runnable now on the 10-13 export.
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
- [ ] **The spell batch (decisions of 2026-10-05; plan APPROVED 2026-10-07)**.
  One sitting of user answers decided a cluster of spell-system work. Plan and build order:
  `docs/design/spell_batch_plan_2026_10_05.md`. **APPROVED 2026-10-07 (user: "Approved.
  Thanks!")**; step 0's leash and charm halves had already shipped and passed (the cast-code
  entry below), the remaining four step 0 items start 10-08, then steps 1 to 5 in order,
  each its own commit with its own tests and checklist.
  **Step 0 BUILT 2026-10-08** (server `5d8d385`; `cast_hardening_checklist.md`; the
  cast-code entry has the detail). **Step 1 BUILT 2026-10-08, pending playtest** (server
  `c71b686`, client in the same-day commit; `small_rules_checklist.md`; needs a redeploy AND
  the next export, since Slow, Torpor and Aria's numbers and the 29 m friendly check changed
  on the client too). What it is: `GROUP_SHARE_RANGE` 200 m for XP, journal ticks and the
  coin split (journal credit takes the same alive-and-in-range test as XP now);
  `FRIENDLY_SPELL_RANGE` 30 m for ALLY and PET_HEAL in the pre-flight, hostile spells keep
  25 m; Slow 5% for 30 s at 10 mana, Torpor on the server at 10% for 60 s at 20 mana with
  no heal, Aria of Dismay 8%, none with a cooldown of its own until step 4; one attack slow
  per target with the strongest winning (`Entity::apply_cc` ignores a weaker one, the
  pre-flight refuses it at no cost); every new character born bound at the starter spawn
  (`create_character`). Tests: a share reaches a group-mate at 150 m and stops past 200 m, a
  heal lands at 28 m and is refused at about 34 m, Slow is refused while Torpor holds, a new
  character loads bound. "Ships silent" is recorded in both schedule files' §4.
  **Step 2 BUILT 2026-10-08, pending playtest** (server `75ab979`, client in the same-day
  commit; `bind_and_gate_checklist.md`; needs the redeploy AND the export; detail on the
  "Gate and the Soul Binder" entry above; the review pass's two HIGH finds are fixed in
  `7e07351`). **Step 3 BUILT 2026-10-08, pending playtest** (server `4303459`, server-only;
  `interrupt_charge_checklist.md`, 13 rows; needs the redeploy, no export). An interrupt from a
  hit that did real damage charges the spell's mana times the fraction of the bar that had run
  (`cast_gate::interrupt_charge`, the server's own cast time so a forged long bar cannot
  shrink it), capped at the mana held; the caster alone gets the true ManaUpdate behind the
  CastFail and "Your concentration breaks: N mana lost."; a zero-damage or absorbed hit
  charges nothing (a damage shield must not be a mana drain), and a deliberate cancel never
  reaches the server. All five interrupt sites pass their applied damage. Integration test
  pins the line, the charge and the settled mana; fails on the previous code.
  **Step 4 BUILT 2026-10-08, pending playtest** (server `9c4895e`, client in the same-day
  commit; `global_cooldown_checklist.md`, 16 rows; needs the redeploy AND the export, since
  the gem greying and the client-side refusal are client code). After any accepted cast no
  spell may START for `GLOBAL_COOLDOWN` (2.0 s server, 2.25 s client, so an honest player is
  never refused): a timed cast is refused at its CastStart with a private "You cannot cast
  again yet." and the true mana (nothing cached, no cast time lost), an instant one at its
  CastSpell. Bard songs are exempt on both sides (`Spell.is_song` on the six songs, compared
  by the lockstep check), or twisting stops working. The client refuses before any bar or
  mana, `hotbar.gd` greys every non-song gem for it (a gem under a longer cooldown of its own
  keeps that one), and a refused or interrupted cast starts none. Tests: refused at the start
  and the release fails the cast-time gate, lands after the cooldown, an instant cast refused
  (fails on the previous code); three songs 100 ms apart all accepted. Exploit lens: without
  it a modified client fires every instant spell on its bar inside one second.
  **Step 5 BUILT 2026-10-08, pending playtest, the last of the batch** (server `d593609`,
  client `9783d3a`; `damage_over_time_checklist.md`, 17 rows; needs the redeploy AND the
  export: the ticks, lines and kills work on the old client, the target-frame icons and the
  client no longer running its own DoT online do not). Entangle and Dark Decay are server
  spells: the direct hit with the cast, then `Entity::active_dots` ticks every 3 s for dps x 3
  (whole ticks counted off the duration), builds aggro, breaks mez, fans the hit and the
  caster's "<spell> for N" line, and a tick that kills goes through `kill_enemy`, the one kill
  step now shared by the spell arm and both damage-shield reflect sites (a Thorns kill paid
  nothing before). Anti-farming: a mob entering Leash or Dead sheds its DoTs and takes none
  on the walk home; the caster's DoTs end on death, any port, and logout, on mobs and on
  flagged players alike (PvP DoTs ride the player buff list as `BuffEffect::Dot`). The
  target frame shows what is on a mob (DoTs plus Mesmerized / Rooted / Snared / Slowed) via
  the mob's BuffSnapshot, fanned to the players who can see it. **The review pass caught two
  exploits before the commit:** a DoT cast on a mob walking home kept ticking on an idle mob
  that could never acquire its caster, paying a full kill from safety (now refused on the
  walk and cleared at the door); and the kill step rolled LOOT for owned victims, which the
  melee and pet-kill paths had ALWAYS done (a warder is "Wolf" with a wolf's table and
  returns free every 15 s, so two flagged accounts could farm its bag); every path now drops
  nothing for a pet or a charmed mob, as none ever paid XP for one. Also from the review: the
  last tick of a DoT was a float coin-flip (now a count), PvP DoTs outlived a caster who
  logged out, a 0-HP body could stand unkilled, mob snapshots went to everyone in the world.
  Tests: entity cadence incl. exactly six ticks at the real 20 Hz; a DoT kill pays XP and
  loot, a DoT ends when its caster Gates, a DoT ends when the mob leashes, a Thorns kill
  pays; all fail on the previous code. **Not built, flagged:** per-spell DoT resistance (no
  resist model exists), a DoT on a charmed pet carried through a charm ending (the charm
  rebuilds the mob fresh, so none crosses), and `/pvp off` ending a DoT already on you (a dev
  toggle today). **The spell batch is built end to end**; five checklists wait on one redeploy
  and one export: `cast_hardening`, `small_rules`, `bind_and_gate`, `interrupt_charge`,
  `global_cooldown`, `damage_over_time`.
  **Deliberate scope note:** PvP attack slows on players go through `apply_buff` (same-named
  refresh) and are not under the strongest-wins rule yet; only slows on mobs are. **Decided (user):** the group share range
  becomes **200 m** for XP shares, quest journal ticks AND the coin split (was 30 m; journal
  ticks had no range rule); friendly spells reach **30 m**; **Slow** = level 8, 10 mana, 1.0 s
  cast, 5% attack slow for 30 s; **Torpor** = level 20, 20 mana, 1.5 s cast, 10% for 1 minute,
  NO heal; attack slows do not stack (one at a time, strongest wins); a **global cooldown**
  gets built now; **damage over time** gets a server model (Dark Decay, Entangle); an
  **interrupted cast costs mana in proportion to progress, hits only** (a deliberate cancel
  stays free); the friends build **ships silent** (no time to source audio by 11-08). Bind and
  Gate decisions are on that item. **Known trade-off, user informed:** at 200 m a group-mate
  can sit in town and share XP and coin from the nearest camps. **Aria of Dismay DECIDED
  2026-10-07 (user): "needs to be adjusted to fit on par with Slow and Torpor. 35% is a nutty
  slow."** Step 1 takes it to 8% (level 16, between Slow's 5% at 8 and Torpor's 10% at 20),
  on both sides; the server entry carries no slow at all today, so online the song does
  nothing. d2 (Torpor, no heal) was re-confirmed the same day.
- [ ] **Cast-code findings from the 2026-10-05 design review** *(a reviewer agent's read of
  the code; status marked per item)*. Step 0 of the spell batch plan.
  (a) **CONFIRMED IN PLAY 2026-10-06 and BUILT the same day, pending redeploy** (server
  `6a802f4`; `ported_spells_checklist.md` §4, whose rows rerun as the regression after the
  redeploy). Mobs with a leash shorter than spell reach could be nuked with no response:
  `tick_idle` ignores attackers beyond `leash_range()`, leash defaulted to aggro x 2, and
  spells reach 25 m. Seen as a Wild Boar (aggro 10, leash 20) taking Chorus of Misery from
  about 22 m without moving while Plagued Zombies (leash 28) came at once. Fix: new
  `MIN_LEASH_RANGE` (30 m, `world/mod.rs`) floors the leash of every mob that aggros at all;
  aggro-0 dev dummies stay passive; a long leash is untouched. A unit test pins the floor and
  an integration test nukes a 1 m-aggro dummy from 20 m and waits for the mob to turn (it
  checks its own setup off the server's Position fan, because a first cut passed on the old
  code on a stale target message from spawn time). **PLAYTESTED 2026-10-06 evening, PASS**
  (`ported_spells_checklist.md` §5: the boar came for the bard from 22 m on the redeployed
  `6a802f4`).
  (b) **CONFIRMED IN PLAY 2026-10-06 and BUILT the same day** (same commit, same checklist
  rows). Charm expired the tick after it landed: the decay sweep tested
  `now.duration_since(exp) >= 0.0`, which saturates to zero while `exp` is still ahead. Seen
  twice in the log as `charm expired` 50 ms after the charm. One line (`now >= exp`);
  `charm_converts_enemy_to_pet` now also asserts no despawn for 1.5 s after the PetSpawn and
  fails on the old code. **PLAYTESTED 2026-10-06 evening, PASS** (§5: the charm held its full
  60 s). The tester's follow-up from that row, that the mob should come back hostile at expiry
  instead of vanishing, is its own entry directly below. Both fixes were built ahead of the
  batch plan's approval because they were proven bugs on the host, not design; the other four
  parts of step 0 still wait on the plan.
  (c) **Verified and BUILT 2026-10-08, pending playtest** (server `5d8d385`;
  `cast_hardening_checklist.md`, needs a redeploy). The dead-state gate at message arrival
  already refused a cast once the death sweep had run; the real window was the tick in
  which hp hit zero with a cast queued before the sweep (a PvP hit or dev damage lands
  before the cast step, the sweep runs after it). The cast step now refuses any caster at
  0 HP or `death_processed`. Test: `a_dead_caster_casts_nothing` sends the dev damage and a
  Smite in one batch; on the old code the Smite landed.
  (d) **BUILT 2026-10-08, pending playtest** (same commit and checklist). Every refusal from
  the cast handler goes through `refuse_cast`: a private CastFail plus a ManaUpdate with the
  server's true mana (class/level, the cast-time gate, moved, cooldown, not enough mana, the
  resurrection arm's four). The silenced and mesmerized refusals, which fan to every peer
  BUT the sender, now also reach the caster with a ManaUpdate. **Deliberate exception:**
  interrupts keep their fan to peers, so the bar peers drew cancels; the caster is already
  among the recipients. Test: `a_refusal_reaches_only_the_caster_with_the_true_mana` (a
  bystander hears nothing).
  (e) **BUILT 2026-10-08, pending playtest** (same commit). A finished cast cannot be held:
  past `CAST_HOLD_GRACE_MS` (2 s) after the bar's end the release is refused as lapsed and
  the stale bar dropped (`a_finished_cast_cannot_be_held`). An interrupt that lands after a
  bar began beats that bar's completion even in the same tick
  (`PerConnection::cast_interrupted_at`, stamped by `roll_cast_interrupt`; the gate read the
  cache as of dispatch, which let a hit earlier in the tick clear the live cache while the
  cast still went through). Casting stands the caster at CastStart and on an instant cast.
  The pure decisions are `world/cast_gate.rs` with unit tests. Client follow-up, not built:
  the client should stand the local player on cast start too; **BUILT 2026-10-12, pending
  playtest** (client, next export; `chat_wrap_and_pet_buttons_checklist.md` §4): `cast_spell`
  stands a seated caster and goes on instead of refusing with "You cannot cast while
  sitting.", and Regen forwards the Stand (today it only stops drawing
  you seated when the server's regen or the next Sit/Stand catches up).
  (f) **Verified: a mob finished off by a damage shield (Thorns) pays nothing**, no XP, no
  quest credit, no loot (`tick.rs` ~8085 marks it dead and fans EntityDied, nothing else).
- [x] **A charm that ends should hand the mob back, not delete it** — **DONE + playtested
  2026-10-07** (`charm_return_checklist.md`, all 9 rows PASS on `e3a6fa8`: the mob came back
  with its HP and attacked; the Bonepile count did not grow across a charm; a charmed pet
  that died respawned on the camp's timer; the quit case logged `charm broken by owner
  leaving — mob returned`; re-charming the returned mob worked. What exists is in
  systems_overview → Pets, "Charm (server)".) **One refinement from the sitting, BUILT
  2026-10-07, pending redeploy** (server `3e1c200`): a returned mob with nobody to hate now
  walks home instead of standing where the pet was, so the quit case ends like the walk-away
  case; one re-check row in the checklist's §3. *(Original entry, for the record:)* *(user,
  2026-10-06, on the §5 rerun: "When charm expires the target vanishes. It should revert to
  being its original npc enemy type.")*. Today the charm arm (`tick.rs` ~5378) converts the enemy into
  a pet entity and frees its camp slot at once (`spawner.on_enemy_died`), and the expiry sweep
  (~3117) removes the pet with no body and no replacement: the Track 12 v1 call, "mob runs
  away". EQ breaks a charm by handing the mob back, hostile and usually straight onto the
  charmer, which is what makes charm dangerous to lean on. Build shape: the charmed pet keeps
  its `spawn_point_idx` and the slot stays occupied for the charm's life; at expiry (and on
  the owner's logout) the pet is rebuilt as an enemy at its position with its current HP, back
  in its slot, with threat on the former owner so it comes for them; a pet that dies while
  charmed frees the slot as any death would. **Exploit lens, and the reason for the slot
  rule:** with the slot freed at charm time (as now), a revert would add a mob to the camp on
  every charm whose replacement had already spawned, a charm-and-wait farm for XP and loot.
  Server-only. **DECIDED 2026-10-06 (user): yes, it attacks the charmer, EQ-authentic. BUILT
  the same evening, pending playtest** (server `e3a6fa8`; `charm_return_checklist.md`; needs a
  redeploy, no export). As shaped: the slot and home ride on the pet and the charm arm no
  longer frees the slot; one helper, `return_charmed_mob`, serves both ways a charm ends (the
  expiry sweep, and `despawn_owned_pets` when the charmer goes linkdead or is reaped): the pet
  is despawned for everyone who saw it and `Entity::released_from_charm` rebuilds the enemy
  (fresh id, same template, the pet's HP and position, its slot and home; a named mob is not
  scaled twice), then `turn_on` sets threat and Chase on the charmer when they are in the
  world and alive. A pet that dies charmed frees the slot through the ordinary corpse sweep.
  Tests: a unit test on the rebuild, and an integration test that charms with a Bard's 30 s
  Siren's Song in real time and waits for the EnemySpawn, the EntityTarget and the first hit
  on the bard; it fails on the previous code at the EnemySpawn.
- [ ] **Proc follow-ups** *(the server-authoritative proc core shipped + playtested 2026-07-31, PD_W0025
  — see systems_overview)*: (a) **elemental resist for procs** — the server has no enemy-resist model
  at all, so proc damage is flat; needs resist fields on `MobTemplate`/`Entity` first. (b) **PvP-player
  procs** — procs fire on enemies/pets only; the PvP branch has no server death cascade, so it was
  left out of v1.
- [ ] **Bard song rework** — songs are half-built: they auto-pulse client-only (never re-broadcast),
  so the server applies a song's effect once on cast and nothing sustains it; heal songs do a raw
  `set_hp` (HP-bar bounce, no buff-window entry). Make them server-authoritative + weaving-aware +
  buff-window-visible. A real subsystem, not a fix. Design note: `docs/design/bard_song_rework.md`.
  **DECIDED 2026-10-20 (user) and BUILT the same day, pending the Oct 22 bump and the playtest**
  (`feat/server-speed`, server `6afcf6a`, client `e1be328`; `bard_songs_checklist.md`, 16 rows;
  the research in session note 2026-10-20 §2: P99's rules, a 3 s sing, a 6 s pulse, 12 to 18 s
  of linger, one song at a time, four songs the practical twist). Classic EQ's model: **a song
  takes 3 s to sing** (the song's `cast_time`, so the existing cast-time gate enforces it, which
  makes twisting a skill and an instant four-song cycle a forgery), **costs nothing** (user:
  "Please stick with this", clarified: EQ's were free, not cheap; mana stays the cost of the
  bard's real spells), and the **server pulses the one active song every 6 s**
  (`SONG_PULSE_SECS`), each pulse's effect **lingering 12 s** (`SONG_LINGER_SECS`, the low end
  of EQ's range, so four songs hold and a fifth drops) as the ordinary buffs, refreshed by name:
  the heal song is a heal-over-time of its per-pulse heal spread over the pulse (the Slice 0
  ask, buff-window visible, no bounce), speed, haste, mana regen and accuracy/crit go through
  the buffs the server had. A new song replaces the current one while the old one's effect
  lingers (twisting); re-singing the active song, the new `StopSong` intent (`/stopsong`, or
  re-clicking the song), any non-song cast and death end it; **movement never does** (the cast
  movement gate and the client's cancel-on-move both pass songs). Aria of Dismay pulses its
  slow on the bard's current target while it is a live mob in reach, skips a pulse out of
  reach and stops when the target dies or goes. **Every song scales with level** (user: "a
  level 1 character should not be as capable as a level 10 character"; EQ scaled each song by
  level, Selo's +20% at 5 to +65% at 50): a song runs at `SONG_SCALE_AT_LEARN` of its
  listed effect at the level the class learns it, climbing to the full effect at
  `SONG_FULL_AT_LEVEL` (50); the data carries the level-50 values; both knobs are mirrored in
  `bard_songs.gd`. **Selos' Melody alone carries EQ's Selo's curve** (user, the same day: "our
  speed spell should match the scaling of the EQ Selos'", after a first reading had put every
  song on it for an hour): a per-song `song_scale_at_learn` (0.3077, 20/65; 0 means the
  global 0.4) and `move_speed_mult` 1.65, so a level 1 bard runs +20% and a level 50 +65%,
  faster than Spirit of Wolf only from the 30s. **Poet's Mending and Wanderer's Chord were
  matched to their P99 counterparts the same day** (user: "go ahead with matching"): 11 a
  pulse at 50 (Hymn of Restoration's line, about 4 when learned at 4) and +10% haste
  (Anthem de Arms); Aria of Dismay (your 8%) and Anthem of the Hunt (no counterpart) on hold. **Mana Weave cut to P99's mana song** (user: "adjust ours to what the P99
  numbers are"): 6 mana per 6 s pulse (1.0 a second), down from 12 a second, twelve times
  EQ's; EQ gave it to the group and not the bard, so when group songs come, follow that. The
  other five checked against P99 and found at or under it (Selos' +35% ceiling vs EQ's +65%;
  Poet's 8 vs Hymn of Restoration's 13 at 60; Wanderer's +12% vs Anthem de Arms' +10%; Aria 8%
  vs Largo's 15 to 35%); three of them matched to EQ's later the same day, below. The client sends
  and shows: no local pulse online, the buff bar follows the server's snapshot through
  `BardSongs.apply_song_buffs` (scaled the same way), the spell lockstep check no longer
  excuses songs (zero drift, 158 client, 142 server). **Not built, flagged:** instruments and
  the singing skill; group-wide songs (ours are self-only); a PvP target under Aria (the song
  stops on one); a singing pose for peers. Tests: unit (the scale at the learn level, 25 and
  50; the pulse effects of Selos', Poet's and Mana Weave; every song a 3 s sing and free) and
  four integration (a forged instant release refused, the first pulse's 12 s linger, the
  refresh at 6 s, the stop and the effect running out 12 s after the last pulse, read off the
  clock; two songs twisted and both up, the active song re-sung stops it, a nuke ends it; a
  sing on the move through fifteen metres, and a level 1 bard's Selos' measured at 0.300 m a
  tick, 1.2x, where the flat data would give 1.65x), every one failing on the previous server; the
  GCD song test rewritten for the sing time; a headless probe for the client half.
  **Harness lessons:** the position channel clogs through a long wait and a later speed
  measurement reads the stale positions it kept (the heartbeating pumps drain it now), and a
  timing assertion reads the clock, not the windows' nominal lengths.
- [ ] **Dwarf racial ability: Stone Skin** *(user idea 2026-10-19, instead of making Dwarves
  permanently stone; "go ahead with stone skin")*. Active: the skin turns to granite, a large
  cut to physical damage taken and no knockback, paid for by being rooted in place, on a long
  cooldown (starting knobs 50%, 10 s, 10 min). Shape follows Lineage II's Ultimate Defense (the
  user's comparison: huge defence, unable to move); EQ's Monk Stonestance and WoW's Stoneform
  are the nearer-but-costless cousins. Written up in `docs/design/race_stats.md` under Dwarf,
  with sources in the 2026-10-19 session note. **Open (user):** whether it also cuts magic
  damage. **Before it can be built:** no racial ability exists on the server yet (all of
  `race_stats.md`'s are design only; Troll regen is the one race perk that shipped), so Stone
  Skin is the first and needs a server-side home: a race-gated intent, a server cooldown, a
  self buff carrying the cut and the root, and the no-stacking rule with Guard and Dark Bond.
  **Exploit lens:** never a client-side effect, or a modified client gives any race a free
  damage cut; the server checks the race on every use.
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
  **Researched 2026-10-14, and the rule is exactly what the sources keep:** the Project 1999
  wiki (Decoy's Enchanter Notebook) says an enemy hitting a sitting player always hits for the
  maximum it can, taking damage while sitting forces you to stand, and that stand closes an open
  spellbook; EQEmu's `attack.cpp` has both halves (a seated client is always hit, and the damage
  table returns its top entry). Not a separate crit bonus: the "bonus damage" of (a) is the max
  roll with no mitigation. **DECIDED 2026-10-14 (user): "Both halves, the P99 rule... Changes
  the med game for casters: sitting near a mob is now dangerous, as in EQ."**
  **BUILT 2026-10-14, pending the redeploy, the export and the playtest** (server `d4f6b47`, client
  `2495276`; `seated_combat_checklist.md`, 16 rows; the server half works on the client testers
  hold, the body standing on a hit needs the export). The damage half is `combat::mitigated`
  (one home: the mob swing and the PvP swing both call it; a seated target gets no armor off)
  and `combat::calc_swing_max` (the top of the attacker's band for a seated PvP target; the
  crit roll stays, a crit being luck on top of the roll; a mob's swing is flat, so its max is
  the amount). The stand half is one line in `PerConnection::note_damage_taken`, which every
  player-damage site already calls (melee, spells, DoT ticks, damage shields), so the seated
  regen rate, `/camp` and the seated rule all end with the first hit. Nothing on the wire
  carries the flag, so the client stands its own body on the Hit it receives, never on a
  zero-damage one. Tests: unit (the band max, the offhand, the mitigation table, the stand) and
  an integration test where a seated player is hit by bare fists for exactly 4 + STR/5, a
  `/camp` straight after is refused (the one intent that needs the server's own seated flag)
  and the same `/camp` after sitting again is accepted; it fails on the previous code at the
  camp assertion. Headless probe for the client half. Full suite green (275 unit, 97
  integration). **Exploit lens:** both rules key on the server's own seated flag, which the
  client can only set through the Sit intent, so a client that lies about standing simply
  forgoes the seated regen; a client that ignores the stand keeps drawing itself seated but is
  standing to the server and gets no seated regen and no seated rule.
  **Server half DEPLOYED 2026-10-19** (R720 boot line `build="33c7e28" dev_cmds=false`, no
  migration); `seated_combat_checklist.md` §1 and §2 are runnable now on the 10-13
  export; the body standing on a hit (§3) waits for the Oct 22 export.
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
  one-line camp tag, but which camp is content). `xp_mult` was REMOVED 2026-10-13 (user decision):
  a named kill pays by its level alone, as in EQ.
- [ ] **Heal magnitude client/server drift** *(deferred 2026-06-22 when the heal-bar bounce was
  fixed; still the case per the launcher-gaps memory; audit 2026-09-29)*. The server applies a
  flat `heal_amount` while the client's spell data adds `WIS*0.3 * effectiveness`, and at least
  one spell disagrees by rank (server "Mending Rk. II" 38 vs client "Mending" 25). Displayed
  heals are the server's number now, so nothing is wrong on screen, but the formulas need one
  owner: port the WIS term server-side or delete it client-side, and make `spells.toml` and
  `spell_definitions.gd` agree per rank. Also gate consumable-heal prediction the same way the
  self-heal gate works (masked today only because food heals are 0).
  **DECIDED 2026-10-19 (user): the WIS bonus moves to the server**, with the standing rule
  "Events happening on the client are a no-go." Re-read the same day: the rank mismatch is
  stale (both sides carry "Mending" 25 and "Mending Rk. II" 38), and the drift is wider than
  heals: nukes add `INT x 0.5` on the client only, and the casting-skill multipliers too. Fix 3
  of the client-authority audit (Security, "Client-decided outcomes").
- [ ] **EQ parity: the inflation pass** *(user, 2026-10-20, after the Bard song pass found Mana
  Weave at twelve times P99's: "A lot of our spells, skills, effects, etc are pretty over
  inflated"; baseline P99, scope and format settled the same day; **research DONE 2026-10-20,
  `docs/design/eq_parity_audit.md`, nothing built, the user's calls pending on §8**)*. Every
  server spell (142), the 16 client-only ones, the 32 active skills, the mobs, the weapons, the
  player pools, regen and XP set against their P99 counterparts (PQDI's class lists for the
  level-scaled spell figures, the P99 wiki and forums for mobs and weapons, EQEmu's source for
  the pool and skill formulas), as ratios at the same level. **The finding: the inflation is on
  the player's side at levels 1 to 10 and almost nowhere else.** Player pools at level 1 are 5
  to 10x EQ's (a Human Warrior 200 HP against 32; a Wizard 210 mana against 22) while the
  per-level gains are EQ's, so level 50 lands in line for melee and priests (casters' HP under);
  level 1 to 10 nukes and heals are 4 to 6x (Smite 35 against Strike 7; Healing Light 60 against
  Minor Healing 10; Ice Spear 50 against Frost Bolt 5 to 7) and in line from 12 to 20 (Meteor
  130 against Force Shock 171); the regeneration buffs are 6 to 12x and 12 to 33 levels early
  (Clarity 8 mana a second at 14 against 4 a tick at 29; Regrowth 5 HP a second at 1 against
  Regeneration 5 a tick at 34); Haste 50% against 30%. **Already EQ's:** mob damage per hit (the
  2 x level + 2 rule to the point), the HP and mana regen tables, the XP curve, the weapon bands,
  the stat buffs, shields, absorbs, roots, mez, snare and speed; mob hit points sit 1.5 to 3x
  above at levels 1 to 6. **Recommendations, worst first (§8, the user's calls):** (1) EQ's pool
  formula outright (`5 + level x factor / 10 + STA x level x factor / 3000`, mana `22.5 x
  level`), the one change that fixes the feel of level 1 to 10 by itself; (2) the level 1 to 10
  spells reshaped to EQ's lines per the class tables, the 12+ spells left alone; (3) the regen
  buffs to P99's per-tick figures and levels; (4) Haste to 30%; (5) low-level mob HP toward
  P99's, after the pools move; (6) leave alone everything already EQ's and the user's own calls
  (Slow and Torpor under EQ, Aria 8%, conjured food x10, the 25/50/75 res tiers, the spell
  formula "for now"); (7) a second pass on mana costs and cast times (not in PQDI's lists) and
  mid-level mob HP if wanted. All data edits on both sides, held by the lockstep checks; no new
  knobs. Planner row d9.
  **DECIDED 2026-10-20 (user): "yes to all"** five, then three calls on the spell formula when
  the build plan was laid out: the INT and WIS bonuses go ("If the INT and WIS bonus is not P99
  accurate, then we can discard it"), the casting skills follow P99's rules (where they never
  scaled an effect but decided whether a cast FIZZLED), and the INT spell crit stays ("even
  though its not classic"). **BUILT 2026-10-20, pending the Oct 22 bump and the playtest**
  (`feat/server-speed` in both repos, server `0b60460`, client `92c1442`;
  `eq_parity_checklist.md`, 36 rows; the audit's §9 has every number). (1) EQ's pool formula
  on both sides (`char_data::base_hp` / `base_mana` / `hp_level_factor`, mirrored in
  `CharacterData`; EQEmu's integer arithmetic so the sheet shows the server's number; our
  CON, INT and WIS in EQ's stats' place; a Human Warrior 28 HP at 1 and 1,886 at 50, a Wizard
  17 HP and 17 mana; the pure melee keep a token 20 mana; the per-level HP and mana gains are
  gone from both gain tables and a level change recomputes, up and down; existing characters
  recompute at login with current values clamped). (2) The level 1 to 10 spells at EQ's
  numbers AND EQ's mana costs: the costs were the audit's "second pass", but the first test
  run showed that with 16 mana at level 1 and 15-to-35-mana spells nobody could cast, so each
  changed spell took its PQDI counterpart's cost (Strike 12, Minor Healing 10, Burst of Flame
  7, Fire Bolt 40, about one mana a point); Rune and Bind Affinity to 10 for the same reason.
  (3) The regen buffs at P99's rates, levels, durations and costs (Breeze 16, 2 a tick for 27
  min at 35; Clarity 29, 4 a tick at 75; Regrowth 34, 5 a tick for 20.5 min at 100, Rk. II 44
  at 200; Haste 30% for 11 min at 80; Lich Form at 4 a tick; Healing Wave's HoT dropped),
  because a 2-a-tick Breeze over the old 30 s would have been a net loss. (4) The mobs at
  levels 1 to 9 toward P99's (16 at 1, 80 at 6, 160 at 9), the pet curve with them. (5)
  `spell_power::empower` and the client's three terms deleted; a spell does its listed
  number; the crit stays. (6) **Fizzles**: EQEmu's `CheckFizzle` as `cast_gate::fizzle_chance`
  (par `5 x spell level - 10`, at most 235, plus the level, against skill plus level; a Bard's
  CHA against 110; base 10%, clamped 1 to 95), rolled by the server at a timed cast's
  CastStart and an instant cast's CastSpell, after the target checks and before the mana: a
  fizzle answers "Your spell fizzles!" (the client prints EQ's line as is), burns a quarter of
  the mana (EQEmu's rule; classic charged for a fizzle too, "reduced and capped" in June 1999
  per P99's patch notes), starts the gem's refresh (the global cooldown; P99's pages list a
  2.25 s "fizzle time") and trains nothing; songs never fizzle (no singing skill yet).
  **`Config::fizzles`**, always on for a running server with no env var, exists only so the
  integration harness can turn the roll off (a 10% coin flip on every single-cast test) and
  back on for the one test about it. **Exploit lens:** every roll and every number is the
  server's; a forged CastStart that fizzles costs the forger mana and the refresh; a client
  that skips CastStart fails the cast-time gate as before. Tests: unit (the pools at both
  ends against EQEmu's formula, the fizzle formula at par, under, over, the stat term, the
  Bard, both clamps, the quarter mana; the pet curve anchors) and integration (`a_heal_is_its_
  listed_number`, the DoT test on the new numbers, `a_cast_can_fizzle_on_a_low_casting_skill`:
  a level 16 Magician with no evocation fizzles Fireball Rk. III at its start, loses 10.5 of
  42, is refused inside the refresh, and fizzles the instant Frost Bolt Rk. III from its
  CastSpell); every test that pinned an old number moved (310 unit, 129 integration green);
  the client probe (the formula's anchors, a level 1 to 5 to 3 round trip through
  `apply_server_level`) and the spell lockstep check (zero drift, 142 shared). **Flagged, not
  built:** cast times (most level 1 nukes are instant; EQ's took 1.1 to 1.8 s); mid-level mob
  HP; Lich Form's hit point drain (EQ's lich line paid HP for the mana; ours is a free Breeze
  at 20); a fizzle's line to bystanders; per-spell `base_difficulty`.
  **Three integration tests this pass made timing-dependent, FIXED 2026-10-23** (server
  `b25a19d`; the suite then ran 134 of 134 six full runs in a row). (1)
  `pet_pulls_aggro_via_threat_reaggro` failed every time: the camp's Decrepit Skeleton has
  16 HP now and the pet killed it before its threat could pass the owner's; the test fights its
  own 500 HP dev spawn and still fails with the 1.3x switch rule broken. (2)
  `owner_keeps_seeing_a_pet_parked_two_cells_away` failed about one full run in four: the
  owner's walk ended 7.4 m from a Cave Bat, a level 6 Necromancer can now die to it, and a
  dead owner leaves the AI's target list so the pet stood still; the walk moved to a row clear
  of every camp. (3) `a_cast_can_fizzle_on_a_low_casting_skill` read the regen fan's
  full-mana update instead of the fizzle's when one landed first; it reads the update after
  the fizzle line. All three were test faults; the server was right.
- [ ] **Regen model and race trade-off follow-ups** *(`regen_model.md` §Deferred + §Open tuning,
  `race_xp_regen_tradeoffs_plan.md` slices 1 and 3; audit 2026-09-29 confirmed no race XP
  multiplier exists in `progression.rs`)*. Open: the pool-size formulas (STA to max HP, the
  `((80 x level)/425) x WIS/INT` mana equation) as their own task; Feign Death posture regen
  (needs an FD state); more fast-regen races beyond Troll; the Meditate cap formula and
  training rate; whether stamina gets a sitting bonus; low-level HP regen feel (1-2 per 6 s).
  Race plan slice 1 (per-race XP rate multiplier applied before the group split, shown in
  character creation) and slice 3 (the other perks, e.g. Ogre stun immunity once CC exists)
  were never built; only slice 2 (Troll regen) shipped.
- [ ] **Dual wield as an unlockable passive** *(user ask 2026-05-02: "unlocked by those who can
  use it at somewhere between 13 and 20"; today `dual_wield` is an ordinary weapon skill with
  a per-class cap and no level gate; audit 2026-09-29)*. Design call on the level, then a
  server-side gate on the off-hand swing plus a client "you cannot dual wield yet" refusal.
  **DECIDED 2026-10-19 (user), ordered by the class caps already in
  `weapon_skill_definitions.gd`, Rangers earliest at the user's wish:** level 13 Ranger, Rogue;
  15 Warrior, Witch Hunter, Bard; 20 Shadow Knight, Beast Master; **Monk born with it (level
  1)**, as in classic EQ (P99 wiki: Monk 1, Rogue and Warrior 13, Ranger and Bard 17; Paladin
  and Shadow Knight never). Monk's `dual_wield` cap is 0 today and becomes 250 (EQ's Monk had
  the highest). The build must let a Monk's empty off-hand swing a fist, which the server
  refuses for everyone today (the 2026-07-29 swing-limit review closed a forged fist stream
  that way), so the opening is Monk-only and server-decided. Paladin, the casters and the
  priests stay at none.
  **BUILT 2026-10-19, pending the Oct 22 bump and the playtest** (`feat/server-speed`, server
  `803d7f4`, client `bfd8753`; `client_authority_fixes_checklist.md` §5). `skills::dual_wield_level`
  and the client's `DUAL_WIELD_LEVELS`; the Attack path refuses an off-hand swing before the
  level; a Monk with both hands empty punches with the off hand (no one else swings an empty
  off hand); an off-hand swing trains dual wield on the server; the client prints "You will be
  able to dual wield at level N." on equipping an off-hand weapon early. Test:
  `dual_wield_is_earned_by_class_and_level` (a Warrior 1's off hand unanswered, answered past
  15; a bare-handed Monk 1's answered), failing on the previous code. The dual wield skill
  itself still changes nothing about the swing (as on the client); a later pass could tie the
  off hand's chance to swing to it, as EQ did.
- [ ] **Facing and view angle** *(user 2026-05-05: "currently doesn't seem like any PC or NPC has
  a view angle. Everything has to face the direction of their combat target"; audit
  2026-09-29)*. No facing model exists: mobs snap to their target and remote players show
  yaw only. Scope with the remote animation-state channel (the jump relay is its first piece).
- [ ] **Two small verifies the closed gates left behind** *(audit 2026-09-29)*: (a) the
  swing-rate limiter's **haste spot-check** (assumes max haste; the schedule's own caveat says
  it is "unit/design-covered but never eye-tested"): cast Haste, swing a fast weapon, confirm
  zero `too fast` rejections in the log; (b) the passive-skill **"L1 cap = starting score"**
  quirk (handoff_track_22 Option F, "deferred for next playtest's verdict", never revisited):
  a level 1 character cannot advance any weapon or armor skill because the cap equals the
  start; decide whether that is EQ-authentic enough to keep.
  **Seen again 2026-10-09 on Sense Heading** (`loc_command_checklist.md` note: "I don't think
  there is a skill for /sense"): it starts at the level-1 cap, so a fresh character always reads
  exact and the skill is invisible until leveling raises the cap; it is also client-local and
  resets every launch (`character_setup.gd` re-initializes it).
- [ ] **Client-only spell backlog (~32 spells missing from `spells.toml`)** *(quantified
  2026-07-22 from a Life Drain / Dark Shroud playtest; those two are now ported)*. The client's
  `spell_definitions.gd` has 156 spells; the server has 124. A client-only spell is dropped as
  "unknown spell" (mana spent, no effect). The simple base-class ENEMY/SELF ones can be ported
  as-is; the rest need server support first: **9 `PORT` teleport/gate/evac spells** (no server
  target-type handler), **prestige-class tags** (`Paladin_Fallen`, `Shadow Knight_Redeemed` — the
  cast gate keys on base `conn.class`, so these need the prestige-class model), and **`Warder's
  Mend` PET_HEAL** (also its own long-standing gap). `tools/export_spells.gd` is the intended regen
  path but is stale. Audit list: see the "Known drift" note + the 2026-07-22 session note.
  **Recounted and partly PORTED 2026-10-05, pending playtest** (server `c0046af`;
  `ported_spells_checklist.md`; server-only, works on the client testers already have). The
  32 split into 13 ordinary class nukes, 10 ports, and 9 blocked on other systems. **Nine of
  the 13 are plain direct damage and are now in `spells.toml` with the client's values
  unchanged:** Blizzard and Thunder Clap (Wizard), Bloodfire, Void Lance and Tempest Bolt
  (Sorcerer), Cascade of Stars (Enchanter), Chorus of Misery (Bard), Feral Shriek (Beast
  Master), Judgment (Paladin). A unit test pins all nine and an integration test has a level
  4 Sorcerer land Bloodfire (it fails without the data). **The nine PLAYTESTED 2026-10-06,
  PASS** (`ported_spells_checklist.md` §1 to §3: six characters, one per class, all with
  spell kills; Cascade of Stars reached the server's interrupt roll, which the old server
  could not do; no unknown-spell line all evening; an old Bard song still resolves). **The 22
  that remain (23 until Warder's Mend was ported on 10-07, below), by what blocks each:** 10 ports (Gate, Succor, Evacuate: the bind and Gate design; seven zone ports:
  zones that do not exist); 7 prestige-class spells (`Paladin_Fallen` x4, `Shadow
  Knight_Redeemed` x3: the cast gate keys on the base class); **damage over time, which the
  server does not model at all** (Dark Decay, Entangle: the only two DoT spells in the game,
  and most of their damage is the DoT, so porting the direct hit alone would misrepresent
  them); Exsanguinate (mana drain, no server field); Camouflage (stealth); and **Torpor**.
  **Warder's Mend, the one PET_HEAL, PORTED 2026-10-07, pending playtest** (server `8a826a5`;
  the tester asked for no client-only pet spells; `xp_eligibility_and_pet_levels_checklist.md`
  §3's pet-spell row, after the redeploy): the cast pre-flight resolves PET_HEAL to the
  caster's own live pet in reach ("You have no pet to mend." otherwise) and the arm heals it
  by `heal_amount` and fans its HealthUpdate, whatever the client had targeted. The lockstep
  check now reads 134 server spells, 22 client-only, no pet spell among them. *(Corrected the same day: this entry first said Torpor's data
  "looks wrong", an ENEMY spell that heals. That was a misreading. The data matches the
  design in `docs/concepts/classes/shaman.md`: Torpor slows the TARGET's attacks by 70% and
  puts a heal-over-time on the CASTER, the Shaman's signature line. The client applies
  `hot_hps` to the local player whatever the target type.)* It is blocked only because the
  server's ENEMY arm applies the slow but has no step that gives the caster the HoT, a small
  addition. The user was asked on the wrong premise and answered "remove the heal";
  **re-confirmed 2026-10-07 on the corrected premise: no heal.** Torpor became the 10%, one
  minute attack slow of the spell batch's step 1 (Slow is 5% for 30 s at level 8) and
  **joined the server on 2026-10-08** (`c71b686`), leaving 21 client-only. The file header in `spells.toml` now states what the server models and what it
  does not.

### World systems
- [x] **Phase 4 content: the replacement world** — **DONE + playtested 2026-09-27**
  (`phase4_content_checklist.md`, all 28 rows PASS across the 09-22 to 09-27 sittings;
  plan + verified reward actuals in `docs/design/phase4_content_plan.md`). What exists is
  in systems_overview → World & environment ("The phase 4 world") and NPCs/quests (the
  second quest tier, Hadrik, Elara). Every tier payout, named-mob multiplier and per-level
  XP value landed to the digit in play, and the gates (level_req, proximity, bag-space
  pre-flight, round-robin, dead-state) all refused correctly under real use. Standing
  watch item: Flamebrand's Flaming Strike procs have not yet been observed in a server
  log — check on the next melee session with it equipped. `xp_mult` on named mobs was removed
  2026-10-13 (user decision; a named kill pays by level alone).
- [x] **Enemy AOI cell-crossing spawn/despawn gap** — **DONE + playtested 2026-10-07**
  (`scale_readiness_checklist.md` §3, the two-seat rows, all four PASS: a partner's pet
  appeared with them, vanished with them, and was already there when the tester walked into
  view of it; the mob-into-view row ticked as well). What exists is in systems_overview →
  Networking, "AOI crossings". *(Original entry, for the record:)* *(found 2026-09-25 in the
  zone-size research, recorded only in that session note until the 2026-09-29 audit)*. When an enemy crosses an
  AOI cell boundary (a mob chasing into a player's view), the server never fans an
  `EnemySpawn` / `EntityDespawn` for it: the client receives Position updates for an id it
  was never given a spawn for, so the mob is invisible until a re-enter. Server-only; a
  scale-readiness prerequisite next to the idle-enemy rebroadcast fix.
  **BUILT 2026-09-30, pending playtest** (server `c121341`; `scale_readiness_checklist.md`
  §3; server-only). The crossing loop now uses the `(gained, lost)` cells `aoi.update`
  already returned and discarded: players in the gained cells get the entity's EnemySpawn
  or PetSpawn, players in the lost cells an EntityDespawn, a mirror of the step 5b player
  handler. **A third gap found while verifying, never recorded until now: pets were
  invisible to a player walking INTO view of them**, because the player crossing handler
  tested ids against `LOOT_BAG_ID_BASE` first and the partitions stack (player < enemy <
  bag < pet), so a pet matched the bag arm, found neither a bag nor a corpse, and was
  skipped; it gains a pet arm ahead of the bag arm. Three integration tests seed the second
  client two cells from spawn through the characters table (no 240 m walk) and all three
  fail on the previous tick.rs with their asserted messages. Ticks on the §3 two-seat rows
  (the mob-into-view row may stay `[-]`; the test is its evidence).
  Review pass (`818a902`) folded in three more of the same class: the EnterWorld pet seed
  keyed visibility on the OWNER's cell while every other pet path keys on the pet's own (a
  ghost pet with no Positions, or Positions with no spawn, depending on which was near); the
  EnterWorld ENEMY seed iterated the whole `enemies` map with no pet skip, and the client's
  enemy manager has no partition guard, so a late joiner got a second, enemy-flavoured node
  for every visible pet riding the pet's Positions; and the spawn-by-kind choice now lives in
  one `fan_out_entity_spawn` used by both the player crossing and the entity crossing, so no
  partition-test ordering can swallow a kind again.
- [ ] **Multi-zone epic** *(deliberately out of every phase so far: phase 4 plan §4.5, phase 5
  plan Track D item 5, the procedural dungeon memory; audit 2026-09-29 gives it a home)*.
  The server simulates one zone (`conn.zone` unpopulated, `npcs.toml` has no zone field);
  zones need server zone keying, zone lines and a transition wire message, the AOI split, and
  corpse/bind zone handling (the 06-23 "cross-zone bind corpse rendering" caveat). The
  procedural dungeon (`F:\Projects\ProceduralDungeon`, seed-deterministic BSP) is its first
  customer. Caves and stacked floors additionally need real Y (the height model), not a sample.
  **Structure to carry into the design** *(from the 2026-10-12 research on how EQ, WoW,
  Lineage II, SWG and Ragnarok split their servers; user agreed all five)*. Stay one process
  for now; build the seams so a later split is a deployment change, not a rewrite.
  (1) **Zone as a self-contained unit** (EQ's zone-per-process shape, inside one process): each
  zone owns its entities, AOI and tick, keyed by zone id, under a world layer. (2) **Keep the
  login/world split as it is**: the signed connect token already lets auth move to its own
  process. (3) **Cross-zone services stay out of zone code** (tells, groups, guilds, the ban
  sweep; Ragnarok's Inter server, EQ's chat service). (4) **One path for database writes**
  (Lineage II's CacheD role): `save_stores_atomic` and the corpse transaction are the rule,
  not a coincidence. (5) **Every object is owned by exactly one zone at a time** (Blizzard's
  JAM talk, GDC 2013): the zone handoff is the dupe vector, so a character or item crossing
  zones moves in one atomic step, never existing in both or neither. Deliberately NOT
  borrowed: a separate NPC/AI process (Lineage II, Aion) and EVE's single-shard cluster.
- [ ] **Quest and loot content plumbing deferred by phase 4** *(`phase4_content_plan.md`
  §4.3/§4.5; audit 2026-09-29)*. (a) Quest objective types beyond kills: fetch, delivery,
  dialogue (the server counts kills only). (b) Loot tables as data: `loot.rs` is code, so
  gear drops and tables for the Ossuary/Wraith Gate line wait on a data-driven table format.
  (c) Per-vendor server-side stocking: the server sells anything with a `vendor_price` to
  anyone in range of any vendor; stock lists are client-only. Fine at friends scale, a
  correctness gap for a public host. (d) **Ask 2026-10-07 (user): humanoid mobs (bandits,
  gnolls, anything with a lore history) should have gear tables and be equipped from them,
  and carry coin; animals carry none.** This wants a creature type on the mob template
  (humanoid / beast / undead / ...), the hook EQ keys loot by creature and WoW keys both loot
  and spell eligibility on (its charm takes only humanoids and beasts). Content and data;
  sequenced behind (b).
  **DECIDED 2026-10-19 (user): the table format for (b) and (d) uses cascading rarity tiers**
  (from candlesan's short "Making an RPG with Loot? Let me save you some time."). Each roll
  tries the table's tiers rarest first, each at its own fixed chance; the first that hits makes
  a weighted pick from that tier's own list. Materials sit in the bottom tier, so adding one
  never moves a rare rate. Why: today's tables are one weighted pool with an empty bucket
  (`loot.rs::roll_for_mob`), where every entry's chance depends on every other (a Fresh Wolf
  Pelt is 1/8.5, about 11.8%, and one new 2.0 entry drops it to about 9.5%); harmless while the
  tables hold only materials, wrong once gear arrives. Named rares already have fixed chances
  (`named_mobs.toml` `drop_chance`). **Decide when building:** what a tier that hits with an
  empty list does (after a hotfix disables its last item): drop nothing, or fall through, which
  quietly makes the lower tiers more common. Rolls stay server-side; a fixed rate per tier is
  directly testable, like the 400-roll collar test.
- [ ] **Character creation follow-ups** *(scattered: race expansion memory 2026-06, the CHA
  memory, `item_weight_proposal.md` §Findings, `classes.md`; audit 2026-09-29)*. (a) The three
  drafted races (Aerathi, Vesperin, Sylphari) exist as docs only (`race_expansion_brainstorm.md`
  + race files), no code. (b) CHA's distribution by race is still open (CHA itself is the
  confirmed sixth primary). (c) There is no creation-stat floor, so a Fae caster's STR can go
  negative and its carry capacity (5.0) falls under the 5.5 cloth kit; pairs with the Fae gear
  line under Items. (d) Race/class restrictions are "design targets, not fully implemented"
  (`LOCKED_COMBOS` partial vs `race_class_restrictions.md`). (e) The Citizen class concept
  (non-combat: mobile merchant + field money-changer + bodyguard pet; field-exchange role
  committed 2026-06-16) and the planned Assassin/Warlock need class-kit design before code.
- [ ] **Change your appearance in game, at any time** *(user, 2026-10-15, while setting the
  art pipeline's base-body rule)*. Players will be able to modify their character's look
  whenever they want, from in game. This is why every race's base body is made bald,
  beardless and with no accent colour (`docs/design/meshy_asset_pipeline.md`, "The bare base
  body"): hair, beards, markings and accent colours become separate, swappable pieces on top
  of it. Not designed yet: which pieces, where the choice is made, what it costs, and how the
  server stores and fans an appearance (others must see the change). **Idea, same day (user):
  body sliders**, e.g. a Gnome's build from wiry to stout ("Perhaps a caster would be wiry
  while a melee character would be more stout"); the approved Gnome base pack is the wiry end.
  **Needs its own research session first (user):** how customisable characters are done in
  comparable games (EQ's and SWG's character creators, later MMOs), and what sliders mean for
  the art pipeline. A Meshy model is one fixed mesh, so a build slider would likely need extra
  shapes of the same body authored in Blender (blend shapes), and every piece of equipment
  would have to follow them; that cost belongs in the research, before any slider is promised.
  **Second slider idea (user, same day): height**, from the race's minimum to its maximum in
  `creature_heights.md` (a Gnome 0.90 to 1.05 m). Cheap by comparison: a uniform scale of the
  model, so equipment follows with no extra shapes. Two calls for the design: the server must
  clamp the stored height to the race's range (a forged value would otherwise reach every other
  player), and whether the collision capsule and camera scale with it or it stays cosmetic (a
  shorter character hiding behind cover is a PvP edge, small within one race).
- [ ] **Fall damage follow-ups** *(the `TODO` in `player.gd::_on_land` since 2026-05-01 and the
  pet-collision memory; audit 2026-09-29)*. (a) Skip fall damage under Levitate / Feather
  Fall once those buffs are checked. (b) A player caught between their own pet and an enemy
  takes repeated fall-damage ticks from physics knock-around (a client `_on_land` threshold or
  collision-layer fix).
- [ ] **Mount system** — *`MountManager` autoload exists (client-side v1); feature is not
  fully wired* (server speed clamp, Animal Husbandry / Spirit-of-Wolf stacking / Selos'
  Melody interactions still pending)
- [ ] **Faction system** — race/class affects NPC standing; guards attack on sight. Also the
  user's 2026-05-05 framing, recovered by the 2026-09-29 audit: players should be able to
  attack NPCs and suffer the consequences (evil races farming reputation by killing good
  merchants/guards/villagers, good races by killing bad guards); ask the user for the
  reputation rules before designing.
  **DESIGNED 2026-10-20: `docs/design/factions_and_alignment.md`**, nine decisions waiting on
  the user (§6), nothing built. The user's direction, the same day, turned the alignment
  build into this: "I think casting spells should have a pretty miniscule effect in the over
  all... We need factions: Killing mobs and running quests are the big two", and the
  equation: **"spells: .001% of their spell cost."** Researched: EQEmu's faction code (a
  kill's hits go to every player on the mob's hate list, each NPC's hit table negated for
  quests, standing capped per faction, nine levels at 1100 / 750 / 500 / 100 / 0 / -100 /
  -500 / -750, no charisma term, merchants con Dubious at worst), P99's table and rules
  (vendors refuse at Dubious, quests need Indifferent, kill-on-sight at Threatening), SWG's
  two systems (GCW points from kills and missions, spent at a recruiter; every other faction a
  -5000 to 5000 standing moved by killing its enemies). The design: `factions.toml` (six to
  start: the town, the Watch, gnolls, bandits, the restless dead, wildlife, with ally and
  enemy links), a `faction` on every mob and NPC, a kill paying `-hit` to its faction and
  `+hit / 2` to each enemy (`hit = 4 + level`, named x3, derived from the links instead of a
  table per mob), quests with explicit `faction_hits`, standing persisted and clamped at
  2000, a `Consider` intent for the con line, vendors refusing at Dubious and quest givers at
  Apprehensive; and **alignment server-owned**: a float score moved by kills (per-mob tiers
  from `events.md`), quests (`alignment_delta`) and spells at a hundred-thousandth of their
  mana, the momentum rule, seeded once from the class start, feeding the prestige-class
  gates and the 0.7 / 0.4 off-side penalty on the server, the client told by
  `AlignmentUpdate`. Migration 0016 and a bump. Ten-point exploit ledger. Three slices:
  the system; guards that fight and attackable NPCs (the user's 2026-05-05 framing);
  SWG's joinable faction with spendable standing. After the door by the schedule.
  **ALL NINE DECIDED 2026-10-23 (user), recorded in the design's §6; build-ready, not
  built:** the six factions and the derived hit rule; **a kill's hits go to EQ's hate list**
  ("EQ's hate list is the way"), not the XP group; EQEmu's thresholds ("I think we can trust
  EQEmu"; P99's two pages are player estimates 50 to 100 points either side); vendors and
  the banker refuse at Dubious, quest givers at Apprehensive, the soul binder always serves;
  alignment seeded from the class start once; the 0.7 / 0.4 off-side penalty kept, on the
  server; everyone Indifferent in v1 **with the race-and-class start table built and empty**
  ("can we build the system for this?"); the content values as proposed; no GM freeze, and
  **a GM faction tool**: sliders in the Test Panel setting the GM's OWN standing with each
  faction to an absolute value through a `DevSetFaction` intent, GM-only and audited like
  every dev command (EQEmu's own are `#faction review / reset / view` and
  `#factionassociation`, a delta; EQ Live's Guide robes were identification with small stats,
  the powers being the account flag, so a "Breastplate of Indifference" is a later cosmetic).
  Planner d10 answered; the build sits on the after-the-door strip.
  **SLICE 1 BUILT 2026-10-23, pending the Oct 22 bump and the playtest** (user: "Lets rock
  and roll!"; `feat/server-speed`, server `5efd45d` + `30c270a`, client `22ebde7`;
  `factions_checklist.md`, 37 rows; migration `0016_factions_and_alignment.sql`, forward-only,
  ships in the merged build). Server: `data/factions.toml` (six factions, ally and enemy
  links, empty race and class start tables read from day one), a `faction` and `alignment`
  tier on every camp mob and NPC, `faction_hits` and `alignment_delta` on all nine quests;
  `world/factions.rs` and `world/alignment.rs`; a kill pays `-(4 + level)` (x3 named) to its
  faction and half of it to each enemy, to everyone on the mob's hate list (its damage and
  threat maps together, so a missed swing or a healer it hated counts), and the kill's
  alignment move goes to the top damager; quest turn-in pays its explicit hits and delta;
  standing per character in `character_factions`, clamped at 2000, conned at EQEmu's nine
  levels, sent as `FactionUpdate`; merchants and the banker refuse at Dubious or worse ("X will
  not deal with you."), quest givers at Apprehensive or worse, at accept and turn-in ("X has
  nothing to say to you."), the soul binder never; alignment held by the server
  (`alignment_score`, existing since 0001 and never written, plus `alignment_seeded`), seeded
  once from the class start, moved by kills, quests and every cast (0.001% of its mana, the
  user's equation, through the momentum rule), sent as `AlignmentUpdate` on a 0.01 move or a
  tier crossing; the prestige class decided by the server at the cast, memorize and skill gates
  (a Paladin at Evil casts the Fallen kit and loses the Paladin's), the seven prestige spells on
  the server with the client's numbers (spell lockstep 149 shared, 9 client-only, zero drift);
  the 0.7 / 0.4 off-side penalty applied as a penalised copy of the spell. Wire, under PD_W0028:
  `Consider` (an NPC by id or display name, a mob by entity id; EQ's faction phrase plus one
  level phrase per colour, the colour bands from the P99 wiki's Consider page; anything else
  gets "You cannot consider that.") and the GM-only, audited `DevSetFaction` (the GM's own
  standing, set to an absolute value), `FactionUpdate`, `AlignmentUpdate`; the DLL's signals and
  sends. Client: `Alignment` follows the server (the class seed applies only until the server
  speaks, so a class re-apply no longer resets it; the first server score re-runs the kits);
  `/con` (`/consider`) and `/factions`; the Test Panel's FACTIONS (GM) sliders; its normal
  mobs renamed to camp names, so a dev spawn (named or not) carries its camp's faction;
  `data/faction_definitions.gd` held by `tools/check_faction_lockstep.gd`. Tests: unit (the
  table, hits, levels, the con bands, the penalty copy, momentum, a dev spawn's camp faction)
  and five integration tests, each failing on the previous server (a kill pays the hate list
  and moves the killer's alignment; a quest pays its hits and a shunned Brom refuses, the
  standing surviving a relog; a plain account's slider is a silent no-op and Consider names no
  standing; a Paladin at Evil casts the Fallen kit and not the Paladin's; a Neutral Paladin
  casts at 0.7); `tools/probe_factions.gd`, 17 checks. Suite: 324 unit, 133 of 134
  integration; the one failure, `pet_pulls_aggro_via_threat_reaggro`, fails on the branch
  without this build too (filed under the EQ parity entry). **Calls made in the build, for the
  user to overrule:** the hate list is damage plus threat; the alignment move goes to the top
  damager, not the group; the con line is two sentences, not EQ's double-dash join, with one
  level phrase per colour (the P99 page varies them by level band above 6); `/con` names an
  NPC by its display name (the client holds no server ids for NPCs); the quest-accept gate
  uses the quest's turn-in NPC as its giver; the GM slider sets the standing NPCs see.
  **Not built, flagged:** the faction on the character sheet and a dialogue header (the
  design's slice 1 named both; `/factions` is the readout for now); a per-tick budget on
  `Consider` (add `Consider` and `DevSetFaction` to the intent budgets when
  `feat/public-hosting` merges); a GM tool for alignment (the checklist sets it by hand in
  SQLite); coloured con lines; conning players.
- [x] **Time of day is per-client; make it server-driven** — **DONE + playtested 2026-10-09**
  (`time_of_day_checklist.md`, every row PASS including §2's two seats: the clocks agreed to the
  minute and through a full day, dusk came together, the sky carried on across a relaunch and a
  server restart, no step at the minute sends, the Test Panel's Pause behaves, night vision
  intact; the old-client row skipped by choice). What exists is in systems_overview → World &
  environment. *(Original entry:)* *(reported 2026-08-14; this is the
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
  **BUILT 2026-10-04, pending playtest** (server `e8164b1`, client in this commit;
  `time_of_day_checklist.md`; needs the redeploy AND the export, in either order). The server's
  new `world/clock.rs` derives the hour from the wall clock over a 20-minute day, so every
  client is told the same hour, a restart does not reset the day, and nothing is persisted.
  The hour goes to each player on entering the world and to everyone once a minute. The wire
  layer decodes it (`time_of_day` signal, rebuilt DLL), `Net` re-emits `world_time_of_day`,
  and `TimeOfDay` follows: a difference over one game hour is a jump (the first send after
  login), anything smaller is absorbed by running the clock up to 4x fast or down to a
  quarter speed, never backwards, so the sun does not step. The Test Panel's Pause holds a
  hand-set sky; unpaused, the clock rejoins the server at the next send. Nothing on the server
  reads the hour (the sky is cosmetic; night vision is a client-side tint). An older client
  drops the message harmlessly, so the server half can deploy first. If a build ever
  carries a DLL without the signal, `Net` says so in the console and falls back to the local
  clock instead of failing to load. **Export note:** the DLL is hand-copied into `builds/`;
  the copy there today (09-25) predates this, so the export must take the rebuilt
  `addons/gdext_net/gdext_net.dll` with it.
- [ ] **Weather system**; **Water & swimming** (breath/drowning); **Doors & locks** (lockpicking)
- [ ] **Zone transition effects** — fade/loading screen
- [ ] **Test Panel "Despawn All Enemies" leaves enemies invisible, not gone** (playtest
  2026-07-20) — the button appears to drop the client visual while the enemy persists (server
  entity / `RemoteEnemy` not actually despawned), so "cleared" enemies may still be there. Dev-tool
  bug (`test_panel.gd::_despawn_all_enemies`); likely needs the despawn to route through the server
  like `DevSpawnMob` does, not a client-only removal.
  **BUILT 2026-10-19, pending the Oct 22 bump and the playtest** (on `feat/jump-relay` in both
  repos, server `9500051`, client `827de57`, so it rides the jump relay into the merge;
  `despawn_all_enemies_checklist.md`, 13 rows, on that branch). A new `DevDespawnEnemies`
  appended to `ClientWorldMsg` under the unshipped PD_W0028, gated and audited exactly like
  `DevSpawnMob` (a plain account's request is ignored and writes no row). The server removes
  every UNOWNED enemy in the GM's AOI neighbourhood (the set the client button used to hide):
  pets and charmed mobs stay; no XP, loot or corpse; loot bags and player corpses are a
  separate map and stay; the camp slot is freed as the body sweep frees it, so camp mobs
  respawn on their timer. The GM is told "Despawned N enemies." The Test Panel calls the
  DLL's `send_dev_despawn_enemies` by name (an older wire layer costs the button, not the
  panel) and keeps the local free for the offline Test Room; `check_wire_layer.gd` lists the
  send. Tests: an integration test (the plain request does nothing; the GM's despawns two
  dummies for a bystander, leaves the bystander's warder, reports the count, writes one
  audit row; a Smite at a removed id is refused) that fails on a no-op despawn, and a
  headless probe of both button paths that fails on the old button.

### UI polish
- [ ] **The consider command (`/con`)** *(user, 2026-10-23, on seeing the P99 Consider page:
  "This is 1000% a mechanic we need in Project Dawn. Please add it to the list.")*. **First
  piece BUILT 2026-10-23 with factions slice 1, pending the bump and the playtest**
  (`factions_checklist.md` §2): `/con` (or `/consider`) on the target asks the server, which
  answers with EQ's faction phrase from the player's standing ("Brom regards you
  indifferently.") and, for a mob, one level phrase per con colour (white "Looks like an even
  fight.", yellow one or two above "Looks like quite a gamble.", red three or more above "What
  would you like your tombstone to say?", blue "Looks like you would have the upper hand.",
  green "Looks like a reasonably safe opponent."), blue reaching 3 levels below at levels 1 to
  12, 4 at 13 to 17, then one more every four levels (15 at 58), the colour ranges the P99 wiki's
  Consider page calls accurate. **Open:** the page's per-band wording (its phrases change with
  the player's level band); coloured con lines in chat; a keybind; conning players; and a
  design call on whether the con colour decides XP as EQ's light blue and green did.
- [ ] **In-game UI layout is "pretty busted"** *(user, machine day 2026-09-22, on the fresh
  1280x720 startup window)*. No specifics captured yet — needs a screenshot pass naming which
  windows/anchors misbehave at which sizes. Belongs to the deferred cohesive UI theming/polish
  pass (direction TBD, do not start a redesign unprompted; central lever is
  `scripts/ui_theme.gd`); likely interacts with the canvas_items/expand stretch at non-16:9
  window sizes. Same-day context: the startup window shrink to 1280x720 (login.gd) may have
  surfaced layout sins the old full-screen window hid.
- [ ] **Combine character, equipment, and inventory into one window** *(user ask, twice:
  2026-05-02 "paperdoll, character, inventory combined to one window?" and 2026-05-05
  "Character, Equipment and Inventory to be combined to a single window"; never filed until the
  2026-09-29 audit)*. Belongs to the theming/layout pass; a design call on the layout first.
- [ ] **ESC-menu UI scale slider** *(user 2026-05-05; audit 2026-09-29)*. The two code-level
  dials now exist (`LOGIN_UI_SCALE` in login.gd, `GAME_UI_SCALE` in hud.gd); expose the game
  one as a slider persisted in `GameSettings`. Also from the same notes: window backgrounds
  should scale with the display, and "be critical" about HUD scaling at every resolution.
- [ ] **Nameplate and targeting polish** *(user 2026-05-01/05; audit 2026-09-29)*. (a) NPC and
  enemy name labels are visible through walls ("not good"; the dungeon checklist called it
  intentional-for-now, fix before ship). (b) Merchant/guard NPC names do not flash when
  targeted. (c) The target-of-target frame was called "huge, taking up too much space"; make
  it adjustable/movable with the other HUD pieces.
  **(a) BUILT 2026-10-15, pending the export and the playtest** (client `fc0042f`;
  `nameplates_through_walls_checklist.md`, 9 rows; client only). Verified before building:
  enemy and NPC plates have depth-tested since `40dcad6` (2026-05-01, the day the complaint
  was written; `enemy.tscn` went from `no_depth_test = true` to false), and every mob, NPC,
  pet and station scene since carries false. The one plate still drawn through walls was
  **other players'** (`remote_player.tscn`, true since `7faceef`, 2026-05-11), now false.
  Exploit lens: that was a PvP information leak (a player hiding behind a wall showed their
  name through it); a group-mate gets no exception, as in EQ. `tools/check_nameplates.gd`
  instantiates all ten nameplate scenes headless and exits 1 if any draws through geometry;
  it failed on the previous code for `remote_player.tscn` alone. Damage numbers stay drawn
  over everything on purpose. (b) and (c) remain open.
- [ ] **Playtest asks from the charm-return sitting (2026-10-07)** *(the tester's notes on
  `charm_return_checklist.md`)*. (a) **Chat lines did not wrap**: long combat lines were
  clipped at the window's right edge. **BUILT 2026-10-07, pending playtest** (client;
  `chat_wrap_and_pet_buttons_checklist.md` §1): message labels wrap at the window's width and
  re-wrap on resize (`autowrap_mode` on the label; the scroll container never scrolls
  sideways, so the width is bounded). (b) **Pet panel buttons** ("Buttons for attack, guard,
  etc. would be terrific"). **BUILT 2026-10-07, pending playtest** (§2): a row of five buttons
  on the pet panel, each the same `PetManager` call as its `/pet` command. (c) **Re-target
  the returned mob when a charm ends**: the returned mob is a fresh enemy id, so the client
  sees a pet despawn and an enemy spawn with no link, and the player must click it again. EQ
  keeps the target because the mob is one entity throughout. **DECIDED 2026-10-07 (user):
  "I want ours to work the same as EQ", one entity throughout, the target kept across the
  charm landing and ending.** Not built. The honest shape is a wire change, not a client
  guess: the charm re-keys the mob between the enemy and pet id partitions (the client routes
  every message by partition), so the spawn that replaces a despawn has to SAY what it
  replaces, a `replaces: Option<EntityId>` on `PetSpawn` and `EnemySpawn`, and the client's
  `Targeting` moves its target to the new id when the old one was targeted (the same hook
  keeps the target when the mob is charmed, not only when it is released). That is a
  protocol bump plus a DLL rebuild and an export, so it rides the next bump day (the trade
  window's) rather than forcing one of its own. The client-heuristic alternative (same name,
  same frame, within a metre) is rejected: it guesses, and a camp of same-named mobs makes it
  wrong. **BUILT 2026-10-12 on the `feat/trade-window` branches, pending playtest** (server
  `98ff015`, client `20ba679`; `charm_retarget_checklist.md`, on the branch until the merge;
  rides the Oct 22 bump with the trade window, nothing on the deploy branch). Both spawns
  carry a trailing `replaces`, set only at the charm landing (pet replaces enemy) and the
  charm ending (mob replaces pet), on charm expiry and on the charmer leaving alike. The DLL
  emits a separate `entity_replaced(old, new)` after the spawn so the spawn signals keep their
  arity; `Targeting` keeps the target's id (a despawn frees the node without clearing
  Combat's target) and moves to the new node on a match. The real-time charm test pins all
  three values and fails on either site sending `None`; a headless probe covers the client
  handler and fails with it disconnected. (d) **Spell tooltips should show max
  range** with MP, cooldown and description. All spells share one reach today (client 24 m,
  server 25 m; heals decided to 30 m), so the tooltip can show that now and a per-spell
  number when spells get their own ranges. **BUILT 2026-10-12, pending playtest** (client,
  next export; `chat_wrap_and_pet_buttons_checklist.md` §3): `Spells.spell_range_text` gives
  the kind's reach (hostile 24 m, friendly 29 m to others, a corpse 30 m, nothing for a
  spell with no target to reach) and all three tooltips (hotbar gem, spell bar gem, book
  row) end with it. (e) **Design question from the 10-07
  journal, for the user: should named mobs be charm-immune?** Mirelle (Enchanter 20) charmed
  The Undying (a named, 1,325 HP, the `the_undying` quest's target), used it as a pet to kill
  a Giant Spider and a Barrow Zombie, re-charmed it each time the charm ended (it did turn on
  her in the gaps: one hit for 57), and killed it at 327 HP for the kill credit and the
  317,600 XP quest reward. EQ-authentic as play goes (charming above your level is the
  Enchanter's signature and the gaps are the danger), and EQ makes most raid and quest bosses
  charm-immune for exactly this reason. Nothing in the server is charm-immune today.
  **DECIDED 2026-10-07 (user): "dont make named mobs charm-immune."** Named mobs stay
  charmable; no flag. (EQ's other gate, a maximum target level on each charm rank, was
  described but not asked about and is not decided; charm today has no level cap at all.)
- [ ] **Remaining EQ keybinds** *(`docs/concepts/controls/README.md`:179; audit 2026-09-29)*:
  F7/F8 nearest PC/NPC target, F10 UI toggle, and the rest of that list are not mirrored.
- [ ] **Chat: persist the active tab per window group** *(22G chunk 4 follow-up, "small,
  ~5 minutes", 2026-05-26; audit 2026-09-29)*. Rides with the `/r` + TAB item.
  **Mostly existed already; the gap is closed 2026-10-02, pending playtest**
  (`tell_reply_and_inspect_click_checklist.md` §4). The layout has carried `is_active_tab`
  and the restore has read it for months, and a clean quit saved it; what was missing was a
  save when the tab is clicked, so the window X (a hard kill) lost the choice. One line.
- [ ] **Art asset pipeline** *(pointer; audit 2026-09-29)*. The art work is tracked in its own
  checkbox list, `docs/design/art_assets_checklist.md` (the one deliberate exception to
  "one checkbox list", since it is an asset manifest, not a task queue); "future zone themes"
  are deferred there per the atlas. Nothing in it is on any schedule.
- [ ] **Player portrait** in HUD *(slugify + slot landed; art pending)*; **Map / minimap**
- [x] **`/loc` command** — **DONE + playtested 2026-10-09** (`loc_command_checklist.md`, all five rows
  PASS on the 10-05 build: matches Sister Maelis's position, the four facings, `/sense`, works
  while dead, NPC directions read true). What exists is in systems_overview → UI / HUD. **One
  change from the sitting, BUILT same day, rides the next export:** `/loc` prints coordinates
  only (user: "should only show coordinates, not direction facing. that's what Sense heading
  is for"); `SenseHeading.exact_facing` is removed. *(Original entry:)* *(designed 2026-09-25, `docs/design/location_command.md`)*.
  **BUILT 2026-09-27, pending playtest** (client-only, rides the next export;
  `loc_command_checklist.md`). Prints `x, y, z` to one decimal (paste-ready for the toml
  authoring files) plus an exact facing, free for everyone, working while dead; `/sense`
  keeps the skill's fuzzy roll. **The compass is SETTLED (user, 2026-09-27): +Z is north,
  +X is east** — the camp labels and quest dialogue stand, and `sense_heading.gd`'s ring
  flipped to match (the audit found the content already consistent; sense_heading was the
  only -Z-north code). GM drift extra deliberately not in v1. `commands.md` updated.
- [x] **Hotbar + socials bleed between characters** *(found 2026-08-26 during the active-skill
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
  **DONE + playtested 2026-08-27** (all rows pass: isolation both directions across
  Warrior/Monk, memorized bar per-character on Chumby, macro library isolated Funk to Zoltan,
  pickup-and-place + bank switching intact). The "PATK" macro that appeared on every character
  was legacy user data riding the seed, not a code default — removed from the legacy file and
  all seven per-character files at user request, same day.
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
- [x] **Confirm what can become `hud.gd::_tracked_target`.** Two `is_connected()` calls in
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
  can. **Resolved in code 2026-08-28:** slice 1.5 made loot bags real targets (left-click a
  kill corpse), so the precondition flipped and the `has_signal` guards went in on all three
  unguarded lines. **Ticked 2026-09-09 on `cursor_slice15_checklist.md` §4's F1-retarget row:
  corpse targeted, F1 self-target, retarget — console clean.**

### Items / economy
> New section 2026-09-29 (the crack audit): economy and itemization items used to sit in
> memory notes and design docs with no To-Do home. Runtime inventory mechanics stay under
> Multiplayer / networking; what an item IS lives here.
- [ ] **Banker exchange fee bands** *(systems_overview "Still open: exchange fee bands";
  `handoff_banker_npc.md`: the plumbing is in place so a rate is a one-line change, currency.md's
  bands (2-5% up, 0-1% down) come "in a later pass as named constants"; audit 2026-09-29)*.
  The MVP exchanges at 0%. A design call on the bands, then the constants; the Citizen class's
  field exchange is the intended premium alternative.
- [ ] **Fae gear line** *(user direction 2026-06-12: Fae get their own clothing/gear category,
  far smaller and lighter than even gnomes; the item-weight proposal's "Findings out of scope";
  audit 2026-09-29)*. Design work, not a patch: its own weights and stock, and it is what makes
  the Fae carry-capacity problem (Character creation follow-ups, above) go away.
- [ ] **Gem sockets / augments** *(Track 13 deferred 2026-05-19; `ItemData.gem_slots` exists and
  is unused; audit 2026-09-29)*. Needs an item-identity decision first (server_design open
  question 1: unique runtime items as UUID rows vs JSON snapshots), since a socketed item is
  no longer its registry entry.
- [ ] **Itemization oddities from the weight pass** *(`item_weight_proposal.md` §Findings;
  audit 2026-09-29)*: Damaged Wolf Pelt stacks to 20 (12.0 weight) while Fresh/Pristine stack
  to 5, so the junk pelt is the heaviest to hoard; Adamantite Ore's full stack (120.0) exceeds
  every carry cap (harmless fiction, the carry limit binds first); the Brown Steed Whistle's
  0.5 weight wants one description clause. Content-pass fodder, not bugs.

### Tradeskill depth
- [ ] **Tradeskill content gaps** *(`docs/concepts/items/equipment.md`, `items/README.md`, and
  `docs/concepts/tradeskills/todo_list.md`, the tradeskill sub-list that lives outside this
  To-Do; audit 2026-09-29)*. Plate armor, bow/crossbow, and necklace recipes are not in
  `recipe_definitions.gd`; several raw materials are blocked on mobs (spiders and bats now
  exist in phase 4, so spider venom/silk and bat blood can unblock), on elementals (not
  designed), and on Farming (not implemented). Content, sequenced behind the server build below.
- [ ] **Server-authoritative tradeskills** — mining/crafting/skinning currently refuse online
  (guarded 2026-08-24 after the phantom-item finding); building them for real means the
  CompleteQuest pattern (client sends intent, grants nothing optimistically, server owns the
  roll/ingredients/skill-ups + persists skill levels, which currently reset every launch) plus
  server-side node state. Pairs naturally with the NPC proximity-gate table, since nodes need
  server positions too.
  **2026-09-22 (user, first lap of the new world): the five crafting stations and three ore
  veins are REMOVED from `world.tscn` "for the time being"** — the Forge sat one meter from
  Hadrik and blocked him, and all eight have been dead furniture since the online guards.
  Git holds them (commit removing: see session 09-22); re-place them WITH npcs.toml-style
  server positions when this item is built.
- [ ] **Consumables system** (food/drink regen loop, fermentation, ritual components).
  **Ask 2026-10-07 (user):** a consumable's cooldown should equal its effect's length, so
  drinking a second Water Flask while the first still works is refused rather than wasted
  (Water Flask: 180 s). Confirmed in play that stacking flasks does not stack the regen.
  Belongs with the server-side consumables pass; consumable effects are client-side today.
  **Traced and stopgapped 2026-10-12** (server `a9219b9`, pending redeploy;
  `dead_relogin_and_resend_checklist.md` §3): the server DID refuse a second drink while one
  ran, but the mana-only leg of the drink buff is named `Drink MP: X` and the check looked
  only for `Drink: X`, so a Water Flask (mana only) was taken again. Both names are checked
  now. **Superseded in shape by the EQ food and water design above**, where eating by hand
  when full is refused with EQ's own line and nothing is ever "wasted" by stacking.
- [ ] **Bookbinding / player-authored lore**
- [ ] **Clockwork Engineering prestige** (Tinkering 150+ for Gnomes/Kobolds)

### Audio & tech debt
- [ ] **Sound system** — combat/spell/ambient/music. **DECIDED 2026-10-05 (user): the friends
  build ships silent**; there is no time to source audio by 2026-11-08. This answers the
  schedule's one standing open question (§4); the schedule files get the note with the spell
  batch's first step.
- [ ] **EQ-style food/water gating** — food/water should gate base HP/MP regen (no food =
  no regen) instead of stacking as additive buffs; passive consumption from inventory,
  no buff-bar entry. **DIRECTION CONFIRMED 2026-10-12 (user): "Our food and water system
  needs to work like EQ. Instead of like quick consumables." DESIGNED 2026-10-12:
  `docs/design/food_and_water.md`** (EQ's rules from the Project 1999 wiki and forums and
  EQEmulator: hunger and thirst counters, the first food in slot order eaten by itself when
  the counter empties, sizes in 144 s units, stages with "You are hungry." and the explode
  line, no HP or mana regen when out, nobody dies of it; the design, an eight-point exploit
  ledger, three slices). **Six decisions wait on the user (§7)**: the scale (a Bread Loaf as a
  20-minute meal, a 2-hour cap), what stops when famished, race timing, the hand-eat rules,
  Summon Food/Drink for Mag/Cle/Dru, the HUD form. Slice 1 needs one protocol bump
  (`HungerUpdate`), so it rides a bump day. Supersedes the buff model in
  `docs/concepts/tradeskills/consumables.md` "The Regen Loop".
  **ALL SIX DECIDED 2026-10-13 (user), recorded in §7:** EQ's own pace (a Bread Loaf is a
  48-minute meal, a Water Flask a 36-minute drink, the cap 4 hours); no food stops HP regen,
  no water stops mana regen, either stops stamina; the drain is per race (Human 1.0,
  Halfling 2.0 from the sources, the rest 1.0 with Ogre/Troll 1.5 and Fae 0.75 as our own
  flagged calls); hand-eating by EQ's rules exactly; **Summon Food/Drink corrected on the
  user's challenge** (one item per cast; Magician 1, Cleric and Shaman in the single digits,
  Druid 10 to 14; stacks only from Magician 21/22 and Cleric 29/33) for slice 2; the bars in
  their own small window (two icons beside a progress bar), planned as a note before the
  client half is built. Build-ready: slice 1 is the server half plus the chat lines, aimed
  at the Oct 22 bump day.
  **Slice 1 BUILT 2026-10-13, pending review, merge and playtest** (server
  `feat/food-and-water` `40d9f03`, client `7728793`; `food_and_water_checklist.md`, 20
  rows; no wire change, so it needs the redeploy and the export but no bump). What exists:
  `world/hunger.rs` (the counters in seconds of fullness, EQ's 144 s unit, a 4-hour cap,
  the per-race drain, the three stages told once each, the first-in-slot-order search,
  `feed`), migration `0013_hunger.sql` (every existing character full), persistence with
  the resource checkpoint and the reap, the drain and auto-eat at the regen step for the
  living in the world (the dead and the lobby do not drain; a famished character eats the
  tick it runs out, fans the delta and is told "You eat a Bread Loaf."), the regen gate
  (`regen::natural_regen_allowed`: food for HP, water for mana, both for stamina), the
  UseConsumable arm under EQ's hand-eat rules (refused when full with the explode line,
  half size when early), the food and drink buffs deleted. Bread Loaf 2880 s, Water Flask
  2160 s on both sides (the item lockstep check is green). Tests: unit (drain by race, the
  immune Revenant, the stage lines, the cap, slot order through bags and past a held bag)
  and integration (base slot before pouch and regen back, out of food means no HP regen
  while the dead do not drain, the full refusal and the halved hand-eat).
  **Reviewed 2026-10-13** (session note §3): a forged `race: "Revenant"` at creation was
  starvation-immune for life (the transformation's stat block was reachable;
  `create_character` validated only the name), closed by `char_data::CREATION_RACES` and
  `PLAYABLE_CLASSES` refusing anything off the creation lists, with the immunity no longer
  keyed on the race; meditate skill-ups gated on water; the eat runs before the stage
  lines; a famished login is told its stage; the server narrates a hand-eat and the client
  stopped (`6b63ffe`). Accepted residual: one loaf per character per crash between the
  resource and store writes. Merge into the deploy branch next, then the Oct 22 redeploy.
  **Slice 1 DEPLOYED 2026-10-13** (server `f58b796` on the R720, migration `0013` applied;
  client exported from `25eefb1`), so `food_and_water_checklist.md` is runnable now.
  **The hunger window DECIDED and BUILT 2026-10-13, pending the Oct 22 bump** (design §8 with
  the user's five answers: below the character bar, never hidden, bars tick between sends, EQ's
  eating emote for the room, glyphs for now; built on `feat/hunger-window`, server `993c82d`,
  client `c7c53b3`, branched from `feat/trade-window` so it rides the same `PD_W0028`; **MERGED
  into `feat/trade-window` 2026-10-13** by the trade session (a fast-forward, both repos), so it
  rides the Oct 22 bump; `hunger_window_checklist.md`, 18 rows, on that branch). A
  `HungerUpdate` to the owner only (entering, any eat or drink, a stage change, death and
  respawn, once a minute) carrying the counters and the drain rate; the panel under `$Panel`,
  hidden until the first update; a full bar flashes on a hand-eat the server will refuse; EQ's
  `Chomp, chomp, chomp... X takes a bite from a Y.` (EQEmu's `EATING_MESSAGE`) to everyone
  within say range, never the eater. Tests: an integration test with a watcher beside a
  starving Halfling (the update carries the meal and the 2.0 rate, the watcher hears the emote
  and never the eater's counters); a headless panel probe, 17 checks.
  **Slice 2, Summon Food and Summon Drink, BUILT 2026-10-15, pending the redeploy, the export and
  the playtest** (server `4577350`, client `ec4fff2`; `summon_food_checklist.md`, 15 rows; both sides
  move together: an old client knows neither the spell nor the item). **The user's numbers
  (2026-10-15, from Monsters and Memories): "conjure 1 to 4 slices of bread / flasks of water,
  scaling by level."** Built as a new `SUMMON_ITEM` target type: the spell's `summon_item` goes
  into the caster's bags through the real placer, `summon_count` of them (one at the level the
  class learns the spell, one more per `SUMMON_LEVELS_PER_EXTRA` = 10 levels, capped at
  `summon_max` = 4; the step is a knob, M&M does not publish theirs), with "You conjure X xN."
  and the inventory deltas; the pre-flight refuses "Your bags are full." before the mana comes
  off (the placer's own `can_accept`). The design's per-class levels (Summon Drink: Magician 1,
  Shaman 2, Cleric 3, Druid 10; Summon Food: Magician 1, Cleric 9, Shaman 9, Druid 14) are
  honoured by a new `class_min_levels` table on a spell (the cast gate's level check and the
  client's spell book both read `required_level(class)`, `min_level` for a class absent from
  it); the lockstep check learned inline tables and dictionaries for it. Two new items on both
  sides, Conjured Bread (a 48-minute meal) and Conjured Water (a 36-minute drink), with no
  vendor value, so the existing SellItem rule refuses them (no coin faucet from free food); the
  item lockstep check is green with 174 on each side. 10 mana, 4 s cast, no cooldown of its
  own. **Flagged, not built:** EQ landed summoned items on the cursor (ours go to the bags), and
  EQ's were NO RENT and vanished on logout (ours persist; a no-rent flag is the open "no-drop /
  no-trade item flag" item). Tests: a unit test on the count and the per-class levels; an
  integration test where a Magician 1 conjures one bread and is told, and a Magician 35
  conjures four water; a headless probe of the client's data and the two item resources.
  **DECIDED 2026-10-19 (user): +1 item per level after the class learns the spell, cap 10**
  (was +1 per ten levels, cap 4): a Magician conjures 10 per cast from level 10. Safe because
  conjured food cannot be sold and becomes NO RENT (the no-drop flag item).
  **BUILT 2026-10-19** (`feat/server-speed`, server `f7c0d05`, client `d0d4c4d`;
  `summon_food_checklist.md` updated on that branch).
  **Server half DEPLOYED 2026-10-19** (R720 boot line `build="33c7e28" dev_cmds=false`, no
  migration); the spells stay unreachable until the Oct 22 export, since the 10-13
  client knows neither the spells nor the items.
- [ ] **Exporter drift** *(the "Known drift" note names `tools/export_spells.gd` as stale; the
  2026-07-10 session flagged the `items.toml` exporter emitting `weapon_delay` /
  `proc_damage_type` on every item plus a stale `arrow_bundle`; audit 2026-09-29)*. Both
  generators are the intended lockstep tools for the two client/server data pairs and neither
  is trusted; one regen-and-diff pass each, then keep them honest.
  **Spells half answered a different way, 2026-10-05:** `tools/check_spell_lockstep.gd` is a
  read-only CHECK (drift, server-only, client-only; exit 1 on drift) that reads the client's
  real `SpellDefinitions.ALL`, so the two files can be verified without trusting or running
  the stale exporter. It found the files in step. The exporter itself is still stale, and the
  items pair (`items.toml` vs the `.tres` files) has no check yet; the same shape would do.
  **Items half answered the same way, 2026-10-12:** `tools/check_item_lockstep.gd` compares all 172
  `.tres` items with `items.toml` through `export_items.gd`'s own field map and the server's serde
  defaults (proc fields compared only on items that proc). First run: one drift, the Arrow
  Bundle's stack (200 on the server, 20 in the `.tres`), fixed in the TOML the same day (server
  `93f5360`); the exporter itself stays stale and unrun. Both checks are in `commands.md`.
- [ ] **Docs debt** *(audit 2026-09-29)*: `server/README.md` is "badly stale" (still claims the
  world sim is unbuilt, per `deployment_linux.md`); `server/docs/flaky_integration_tests.md`
  still describes the flaky trio the 09-16 fix retired; `docs/concepts/passive_skills/*` says
  casting passives are "not yet implemented" while `CastingSkills` has shipped for months;
  `docs/deployment/` remains untracked by decision and CLAUDE.md links it as canonical (decide
  one way). Small, but each is a trap for the next reader.
  **Checked 2026-10-12:** three of the four are closed. `server/README.md` was rewritten on 10-08 (`c6fccd1`, no unbuilt-world claim remains); `flaky_integration_tests.md` has carried a RESOLVED header since 10-01 with no known-flaky test; `casting_passive.md` now says the system is implemented and where (client `CastingSkills`, server `world/skills.rs`). The `weapons_passive.md` line is about Parry and Riposte, which really are unbuilt. **Open: whether `docs/deployment/` stays untracked** (a user decision; CLAUDE.md links it as canonical and `public_hosting_sitting.md` joined it on 2026-10-12).
- [x] **The cast arms duplicate the pre-flight** — **DONE 2026-10-14, ticked on the suites**
  (server `c377a66` on the deploy branch; server-only, no wire change, no behaviour change, so no
  checklist: a refactor with no playtest surface, and a test suite is its own checklist, the
  flaky-trio precedent; the five spell checklists queued for the Oct 22 redeploy exercise every
  arm and are its regression sweep). `cast_target_refusal` returns a `ResolvedTarget` (Nothing /
  Player / Mob / Pet / Corpse) and the per-target-type arms act on it; every arm's own copy of
  the presence, reach, liveness and PvP checks is deleted (594 lines out, 230 in), along with
  the CORPSE arm's private class/level copy, which the general gate covers. The one fallback
  left in an arm is `cast_resolution_lost`: a target the pre-flight resolved a moment ago
  cannot be gone at the arm (they run back to back for one intent), so if it ever is, the
  server logs it at error, refunds and refuses rather than charging for nothing. The full suite
  was green before and after (272 unit, 96 integration) and a new unit test pins the variant
  each target kind resolves to (a mob, a rival's pet, a flagged player, one's own pet refused,
  an untargeted heal as a self-heal, Warder's Mend to the own pet whatever is targeted, a corpse
  with its owner, Bind on oneself). *(Original entry:)* *(review finding, 2026-10-02; recorded, not
  built)*. `cast_target_refusal` decides target presence, reach, liveness and the PvP gates
  before any side effect, and the per-target-type arms in `tick.rs` still carry their own
  copies of the same checks (now unreachable, with slightly different lines and the old
  refund-after-stamp order). Two homes for one rule: the next change to one (a per-spell
  range, a new target kind) silently reopens the free-roll or the disclosure if the other is
  missed. The right shape is for the pre-flight to return the RESOLVED target and for the arms
  to consume it, deleting their refusal branches. A refactor of the cast handler, so its own
  task, never under cover of a feature.
- [ ] **Procedural dungeon: pick the canonical copy** *(surfaced by the 2026-09-30
  belt-and-braces sweep, the other of its two findings)*. The generator exists twice:
  `addons/procedural_dungeon/` in this repo (12 scripts dated 2026-05-01 to 05-05, the plugin
  enabled in `project.godot` while its `plugin.gd` is an empty `_enter_tree` / `_exit_tree`
  shell that registers nothing) and the standalone project `F:\Projects\ProceduralDungeon\`
  (`dungeon_gen/`, its own README, todo list and session notes). No decision was ever
  recorded about which is the source of truth, there is no sync script, and the two are in
  step by luck. Decide when the multi-zone epic (the dungeon's first customer) is scheduled;
  until then either disable the empty plugin or write down why it stays enabled.
- [ ] **Localization scaffold** *(server_design.md open question 8: "wrap UI text in `tr()`
  calls preemptively so the i18n migration is just a translation file later"; audit
  2026-09-29)*. Nothing is wrapped. Cheapest done early, expensive done late.
- [ ] **Factor-later cleanups from 2026-06-16** *(deliberate, not bugs; audit 2026-09-29)*:
  `_on_hit` resolves attacker names inline instead of via `_attacker_display_name`; the
  base/bag post-state read is duplicated across ~6 apply blocks in `tick.rs`; the trash and
  drop confirm dialogs are parallel copies. Adjacent-touch material, never a standalone refactor.
- [ ] **Weapon item table gaps** — `data/weapon_item_table.gd` maps only a few weapons;
  others fall back to `hand_to_hand` for passive skill tracking
- [x] **`world_two_clients.rs`: three genuinely flaky enemy-AI tests** — **CLOSED 2026-09-16:
  the suite ran fully green (44/44) three consecutive times, the first in its history**
  (server `ebb161f` + `96c6036`; this item's definition of done was "make them
  deterministic", and a test suite is its own checklist, so this tick rests on the runs,
  not a playtest). The "load sensitivity" theory was wrong — three real mechanisms:
  (a) every camp-walking test shared one hardcoded walk into the old camp 0, so any layout
  or AI drift moved all of them at once (they now aim at a designated isolated single-pull
  spawn the camp data guarantees); (b) **casting while a mob melees you rolls a real ~70%
  interrupt per hit at channeling 0** — the pet tests summoned under fire and the AOE test
  cast under fire, so they were coin flips by construction (summon-first reorders + the AOE
  test dev-spawns its victim after the cast bar, via a new harness `send_dev_spawn` +
  `is_gm` grant); (c) a bare multi-second tokio sleep leaves the harness socket unserviced
  while the world's 20 Hz enemy-position fan fills it, dropping datagrams (including
  reliable slices) faster than the 150 ms resend lands — all cast-bar sleeps now pump the
  transport, and `wait_for` reports a mid-wait renet disconnect instead of reading as a
  silent timeout. `server/docs/flaky_integration_tests.md` should be updated to match when
  next touched. *(Original history below for the record.)* — *(the 13 stable failures are
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
