# Command & Tooling Reference

One place for the commands you actually type: CLI / cargo tools, the server run wrappers,
in-game chat commands, and keybinds. **Keep this current** as commands are added or renamed.

- Server repo is `F:\Projects\server`; client repo (this one) is `f:\Projects\Project_Dawn`.
- Dev/GM-gated items are marked **[GM]** — they only work for a GM account (`grant_gm`) or when the
  server runs with `PD_DEV_CMDS=1`. See systems_overview → "GM access + dev tooling".

---

## 1. Server & CLI (run from `F:\Projects\server`)

| Command | What it does |
|---|---|
| `.\scripts\run-server.ps1` | **Preferred run wrapper** (Windows). Dev commands OFF (hosted / GM-playtest). Streams to a unique `logs/server_<timestamp>.log` + `server.log`, refreshes `world_report.html` on exit. |
| `.\scripts\run-server.ps1 -Dev` | Same, but `PD_DEV_CMDS=1` (dev commands ON for **every** connection; local solo). |
| `cargo run -p projectdawn-server` | Run the server directly (auth WS `0.0.0.0:8765`, world UDP `0.0.0.0:7777`). Dev commands OFF unless `PD_DEV_CMDS=1`. |
| `scripts/dev-run.sh` | Bash run helper: sources `.env`, sets `RUST_LOG`. |
| `cargo run -p projectdawn-server --bin admin_report` | **Read-only** `world.db` viewer → console summary + local `world_report.html`. Accounts + characters (incl. soft-deleted), per-char four-tier coins + bank + inventory, and the newest 50 rows of the **GM action audit log** (who issued which dev command, when; each row ends `via=gm`, and anything with `dev` in it means the server ran with `PD_DEV_CMDS` on). WAL-aware, safe while the server runs. Optional args: `[db_path] [output_html]`. |
| `cargo run -p projectdawn-server --bin grant_gm -- <username> on\|off` | Set a per-account GM flag (**writes** `accounts.is_gm`). No args = list every account's GM status. Takes effect on that account's **next login**. |
| `cargo run -p projectdawn-server --bin reset_password -- <username>` | Reset a locked-out tester's password (**writes** the Argon2 hash **and purges every session** for that account in one transaction, so a live session can't outlive the reset). Generates a password and prints it **once**; add `--stdin` to supply one instead (`echo newpass \| cargo run ...`). The password is never an argv word: argv lands in shell history and other users' `ps`. |
| `cargo run -p projectdawn-server --bin admin_account` | List every account: flags, ban reason, live characters, live sessions. |
| `cargo run -p projectdawn-server --bin admin_account -- ban <username> [reason...]` | Ban an account (**writes** the flag and reason **and purges its sessions** in one transaction). The reason is shown to them at login. Refused from then on: login, any use of an existing session, and world connect. **A character already in the world is kicked by the running server within about ten seconds** and leaves by the ordinary unclean-exit path (no restart). A client exported 2026-10-04 or later shows the reason in a "Disconnected" notice; an older client just freezes. Re-running with no reason purges sessions again and keeps the reason on file. |
| `cargo run -p projectdawn-server --bin admin_account -- unban <username>` | Lift a ban and clear its reason. |
| `cargo run -p projectdawn-server --bin invite` | List every invite code: minted when, note, redeemed by whom, revoked. On `feat/public-hosting` until cutover day (`docs/design/public_hosting_plan.md`). |
| `cargo run -p projectdawn-server --bin invite -- new [n] [note...]` | Mint `n` codes (default 1, at most 50) with an optional memo, shown ONCE. One code makes one account; `PROJECTDAWN_REQUIRE_INVITE=1` makes Register demand one. |
| `cargo run -p projectdawn-server --bin invite -- revoke <code>` | Stop an unredeemed code working. A redeemed code cannot be revoked (the account exists; ban it). |
| `cargo run -p projectdawn-server --example provision_test_characters -- ws://100.93.108.112:8765 <account>` | **Make a throwaway test account with one character per class** a checklist needs (the list is in the file), over the ordinary auth socket. Prints the account's random password ONCE and the sqlite command to run on the host to set the levels (new characters are always level 1; run it with none of them logged in). Not privileged; an example, not one of the ops bins. |
| `cargo test` | Run the test suite (~30s incl. build). The `world_two_clients.rs` flake was root-caused 2026-09-16 and the suite runs green; if one fails, re-run it **alone** — a failure that reproduces in isolation is real, one that passes alone is load-sensitivity. |
| `cargo build --release` | Release build. |
| `scripts/backup.sh` | Deploy-host nightly `world.db` backup (cron/systemd; `sqlite3 .backup`, 7-day retention). Not a local-dev tool. |

**The crate has 6 binaries** (`projectdawn-server`, `admin_report`, `grant_gm`,
`reset_password`, `admin_account`, `invite`), so a bare `cargo run -p projectdawn-server` resolves
to the server via the `default-run` manifest key; `--bin` selects the tools. `admin_report` is
read-only; `grant_gm`, `reset_password`, `admin_account` and `invite` write.

**The three tools that write never create a database** (they open with `mode=rw`). Run them from
the directory that holds `world.db`, or set `PROJECTDAWN_DATABASE_URL`. On the R720 the source tree
(`/opt/projectdawn/src`) and the live data (`/opt/projectdawn`) are different directories, so a
tool run from the source tree fails with "unable to open database" instead of quietly making an
empty `world.db` there.

**`PD_DEV_CMDS`** enables dev commands only when it equals exactly `"1"`. To run with them off, unset
it (`Remove-Item Env:\PD_DEV_CMDS`) or set anything else. In PowerShell, bare `null`/`false` are not
literals (use `$null`/`$false` or a string).

---

## 2. Client (Godot 4.4)

| Command | What it does |
|---|---|
| Open the project in Godot 4.4 and Run | Normal dev loop. |
| `godot --path f:\Projects\Project_Dawn` | Headless / from CLI. Godot exe: `F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe`. |
| `godot --headless --path . -s tools/check_login_url.gd` | **Login URL probe** (read-only, on `feat/public-hosting`). Checks `NetProtocol.auth_url_for` (a local host keeps `ws://` and the dev port, anything else gets `wss://` and 443, a typed scheme is kept) and that Register carries the invite only when typed. 14 checks, exit 1 on a failure. Runs without the global class cache, so a fresh worktree is fine. |
| `godot --headless --path . -s tools/check_wire_layer.gd` | Does the `gdext_net.dll` this checkout carries have everything `Net` reaches for by name (the `time_of_day` signal, the `rtt_ms` / `packet_loss` getters)? Prints OK / MISSING per name, exit 1 on any missing. Run it before an export: the DLL is gitignored and hand-copied, so a clean commit can carry a stale wire layer that presents as a server bug. |
| `godot --headless --path . -s tools/check_item_lockstep.gd` | **Item lockstep check** (read-only). Compares every `data/loot/items/*.tres` with the server's `items.toml` through the exporter's own field map and the server's defaults, and prints DRIFT, SERVER-ONLY and CLIENT-ONLY like the spell check. Exit code 1 on drift. Run it after editing an item on either side; on 2026-10-12 it found one drift (Arrow Bundle 200 vs 20) in 172 items. Add `-- <path>` to point at a different `items.toml`. |
| `godot --headless --path . -s tools/check_spell_lockstep.gd` | **Spell lockstep check** (read-only). Compares `data/spell_definitions.gd` with the server's `spells.toml` and prints DRIFT (a value that differs, a bug), SERVER-ONLY (a bug) and CLIENT-ONLY (spells the server refuses as unknown, listed by target type). Exit code 1 on drift. Run it after editing a spell on either side. Add `-- <path>` to point at a different `spells.toml`. |
| `python tools/schedule_detail.py` | **Regenerate the planner's week-by-week schedule** (`docs/schedule_detail.md` + `.html`) from `docs/schedule_detail.toml`, the CLAUDE.md To-Do and the checklists in `docs/playtest_notes/`. Refuses to write (exit 1) if a row names a checklist or To-Do entry that no longer exists; warns about open checklists nothing schedules. Run it in any session that changes a To-Do status or a checklist, then commit the plan file with both outputs. |
| `python tools/art_board/art_board.py` (or double-click `tools/art_board/open_art_board.bat`) | **Art Board**: a local page in the browser (127.0.0.1, ports 8790 to 8799) showing `art_assets_checklist.md` progress by section and a card per art subject in the review loop (`meshy_asset_pipeline.md`), with Approve / Re-roll / Sign off buttons. Sign-off ticks the checklist row. Never calls Meshy or touches the key; credits shown are the last balance the Meshy client saw. Close its console window to stop it. Add `--demo` for a copy filled with sample subjects at every step, in a throwaway folder on ports 8800 to 8809 (nothing real is read or changed). |
| `python tools/art_board/measure_glb.py <model.glb> [--subject gnome/male] [--hide NAME ...] [--record]` | **Model height and triangle check** (review loop step 5). Reads the GLB's vertex data (standard library only) and prints height, width, depth and triangle count as drawn, per node and in total, with the triangles judged against the 2,000 bare-body budget (PASS / OVER); `--hide` leaves out scaffolds such as `Human_Framework`; `--subject` compares the height with `creature_heights.md` (PASS / OUTSIDE THE RANGE, 2% tolerance); `--record` writes it onto the subject's Art Board card. Refuses Draco / meshopt-compressed files. |
| `blender --background --factory-startup --disable-autoexec --python tools/art_board/blender_review.py -- <out dir> <file.blend> ...` | **Blender model review.** Opens each `.blend` read-only (never saves; embedded scripts stay off), renders front and side model-sheet views on light grey, and writes `summary.json` (visible meshes, scaffolds left out, height after modifiers, vertex counts, modifiers, armatures). Blender on this machine: `D:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe`. First run 2026-10-14 into `Project_Dawn_Source/reference/blender_review/`. |

---

## 3. In-game chat commands

Parsed in `scripts/hud.gd::_handle_chat_input`. Press Enter to open chat, type the command.

### Movement / state
| Command | Effect |
|---|---|
| `/sit`, `/stand` | Sit / stand. |
| `/camp`, `/camp cancel` | Sit-gated ~30s logout to desktop; cancels on stand/move/damage. |
| `/dismount` | Dismount. |

### Pet
| Command | Effect |
|---|---|
| `/pet follow` \| `guard` \| `passive` \| `sit` \| `attack` \| `back` \| `dismiss` | Pet commands (owner's pet only). |

### Chat channels
| Command | Effect |
|---|---|
| `/say <msg>` (`/s`) | Local say. |
| `/shout <msg>` (`/sh`) | Shout. |
| `/ooc <msg>` | Out-of-character channel. |
| `/tell <name> <msg>` (`/t`) | Private tell. The recipient sees it in their Tells (In) channel. |
| `/r <msg>` (`/reply`) | Reply to whoever last sent you a tell. `/r` alone reopens the chat line holding `/tell <name> `. Reply targets last for the session and reset when you enter the world. |
| `/group <msg>` (`/g`) | Group chat. |

### Social / info
| Command | Effect |
|---|---|
| `/inspect` | Inspect your current player target's equipment (a right-click on the player does the same). Works within 20 m; further away you get "You are too far away to inspect X." (the server has its own 30 m backstop). |
| `/sense`, `/sense heading` | Sense heading (direction readout, fuzzy below max skill). |
| `/loc` (or `/location`) | Your position as `x, y, z` to one decimal (paste-ready for `zone_camps.toml` / `npcs.toml`), coordinates only; which way you face is `/sense`. Free for everyone, works while dead. Compass: +Z is north, +X is east. |
| `/track` | Tracking (ranger-style). |
| `/languages` | List languages you know. |
| `/lang <name>` | Set your active spoken language. |

### Group
| Command | Effect |
|---|---|
| `/invite [name]` | Invite a player (or your current target) to your group. |
| `/accept` (`/accept invite`) | Accept a pending group invite. |
| `/leave` (`/leave group`) | Leave your group. |
| `/kick <name>` | Leader-only: remove a member. |

### PvP / loot
| Command | Effect |
|---|---|
| `/pvp [on\|off]` | Toggle your PvP flag (both sides must be on to fight; not dev-gated). |
| `/autosplit [on\|off]` | Toggle auto-splitting looted coin to nearby group members. |
| `/loot [rr\|ffa]` | Leader-only loot mode: Round Robin or Free-for-all (`/loot` alone reports the mode). |

### Dev / diagnostics
| Command | Effect |
|---|---|
| `/console` | Toggle the in-game debug console (fallback for the backtick keybind). |
| `/ping` (or `/latency`) | Round trip to the world server in milliseconds and renet's packet-loss estimate, from the wire layer's own ack timing (the UDP path play runs on, smoothed), e.g. `Round trip to the server: 48 ms, packet loss 0%.` Not GM-gated: the point is to ask a tester for the number. The server logs the same per player once a minute as a `player link` line. A DLL older than 2026-10-13 answers that it predates the command. |
| `/version` (or `/build`) | Report the running client build: commit sha, branch, export timestamp, and the `gdext_net.dll` fingerprint. **Not GM-gated** — the point is to ask a tester to read it back. The same line is written into `debug.log`'s header, and the sha alone shows bottom-right on the login screen. |
| **[GM]** `/testpanel` (or `/gm`) | Show/hide the dev Test Panel. It only mounts for GM accounts and the offline Test Room, so a normal player gets "not available". Deliberately a command, not a keybind. |
| `/items <substring>` | List registry items matching a substring (no spawn; pairs with `/give`). |
| **[GM]** `/give <item name> [count]` | Spawn a registry item into your inventory (server-recorded). Needs a name matching ONE item. |
| **[GM]** `/heal <amount>` | Dev self-heal via the server `HealSelf` path. |
| **[GM]** `/damage <amount>` | Dev self-damage via the server `DamageSelf` path. |

The **Test Panel** (client debug tool) exposes the same dev actions as buttons (Full Heal, Level Up,
Grant 250 XP, Give Selected Item, Spawn Normal/Named, give-coins). Those routing to the server are
**[GM]**-gated; buttons like Trigger Death and time-of-day are client-side/legitimate and not gated.
Note: Full Heal fills the bars optimistically client-side even when the server refuses it (a display
lie that self-corrects), so it can look like it worked for a non-GM.

**Every [GM] command that reaches the server is recorded** in the GM action audit log (read it with
`admin_report`), and a command that cannot be recorded is refused rather than run. The budget is
generous (a burst of 128, then 8 a second), so ordinary use never meets it; a script hammering dev
commands gets "Dev commands are rate limited; that one was not run."

---

## 4. Keybinds

Fixed keys (in code):
| Key | Action |
|---|---|
| `` ` `` (backtick) | Toggle the debug console (`ESC` closes; `/console` is the fallback). |
| `Enter` | Open / send chat. |
| `Tab` (chat line open) | Cycle tell reply targets: an empty line becomes `/tell <newest sender> `, and on a tell it moves to the next older sender, keeping the message. With the chat line closed, Tab is still Cycle Target (rebindable). |
| `1`–`0` | Hotbar slots 1-10. |
| `Alt` + `1`–`0` | Spell-bar slots. |
| `F2` | Target group member 1. |
| Right-click (tap) | **World interact**: talk / vendor / bank on an NPC, loot a corpse or bag, inspect another player, mine a vein, use a station, skin a dead mob. A right-*drag* is still the camera. The old proximity-F interact is retired — the cursor must be on the object, deliberately (bot resistance). |
| Left-click | Target only (enemy, NPC, corpse). Never interacts. |

Window toggles (inventory, quest journal `J`, character, spellbook, crafting `K`, etc.) are input
**actions** and are **rebindable** in Options → Keybinds (`GameSettings.keybinds`,
`scripts/options_screen.gd`). The canonical control scheme lives in `docs/concepts/controls/`.
