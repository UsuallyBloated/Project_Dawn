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
| `cargo run -p projectdawn-server --bin admin_report` | **Read-only** `world.db` viewer → console summary + local `world_report.html`. Accounts + characters (incl. soft-deleted), per-char four-tier coins + bank + inventory. WAL-aware, safe while the server runs. Optional args: `[db_path] [output_html]`. |
| `cargo run -p projectdawn-server --bin grant_gm -- <username> on\|off` | Set a per-account GM flag (**writes** `accounts.is_gm`). No args = list every account's GM status. Takes effect on that account's **next login**. |
| `cargo test` | Run the test suite (~30s incl. build). Integration tests in `tests/world_two_clients.rs` are timing-flaky; re-run a failure individually. |
| `cargo build --release` | Release build. |
| `scripts/backup.sh` | Deploy-host nightly `world.db` backup (cron/systemd; `sqlite3 .backup`, 7-day retention). Not a local-dev tool. |

**The crate has 3 binaries** (`projectdawn-server`, `admin_report`, `grant_gm`), so a bare
`cargo run -p projectdawn-server` resolves to the server via the `default-run` manifest key; `--bin`
selects the tools.

**`PD_DEV_CMDS`** enables dev commands only when it equals exactly `"1"`. To run with them off, unset
it (`Remove-Item Env:\PD_DEV_CMDS`) or set anything else. In PowerShell, bare `null`/`false` are not
literals (use `$null`/`$false` or a string).

---

## 2. Client (Godot 4.4)

| Command | What it does |
|---|---|
| Open the project in Godot 4.4 and Run | Normal dev loop. |
| `godot --path f:\Projects\Project_Dawn` | Headless / from CLI. Godot exe: `F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe`. |

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
| `/tell <name> <msg>` (`/t`) | Private tell (outbound; incoming `/tell` RPC still open per the To-Do). |
| `/group <msg>` (`/g`) | Group chat. |

### Social / info
| Command | Effect |
|---|---|
| `/inspect` | Inspect your current player target's equipment. |
| `/sense`, `/sense heading` | Sense heading (direction readout). |
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

---

## 4. Keybinds

Fixed keys (in code):
| Key | Action |
|---|---|
| `` ` `` (backtick) | Toggle the debug console (`ESC` closes; `/console` is the fallback). |
| `Enter` | Open / send chat. |
| `1`–`0` | Hotbar slots 1-10. |
| `Alt` + `1`–`0` | Spell-bar slots. |
| `F2` | Target group member 1. |

Window toggles (inventory, quest journal `J`, character, spellbook, crafting `K`, etc.) are input
**actions** and are **rebindable** in Options → Keybinds (`GameSettings.keybinds`,
`scripts/options_screen.gd`). The canonical control scheme lives in `docs/concepts/controls/`.
