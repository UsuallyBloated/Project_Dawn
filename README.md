# Project Dawn (client)

A multiplayer MMORPG in the spirit of classic EverQuest: Godot 4.4 client (this repo,
GDScript only) talking to a Rust authoritative server
([Project_Dawn_server](https://github.com/UsuallyBloated/Project_Dawn_server)). There is no
solo mode: the client is a view onto the server's world, and nearly all gameplay state is
server-authoritative.

If you are here to **play**, read `README_FOR_TESTERS.md`. The rest of this page is for
working on the code.

## The two repos

| | Repo | Language | Work branch |
|---|---|---|---|
| Client | this one | GDScript, Godot **4.4.1** | `fix/xp-leveling-overflow` |
| Server | `Project_Dawn_server` (clone it beside this repo as `server`) | Rust **1.95.0** (pinned) | `fix/xp-leveling-overflow` |

The branch name is historical; it is the mainline on both repos, and the hosted server
deploys from it. `master` and `main` are stale and should not be used.

## Set up

1. Clone both repos side by side (the client's DLL build script expects the server at
   `../server`; adjust `$serverDir` in `addons/gdext_net/build.ps1` if yours differs).
2. Build the wire layer: the client speaks the world protocol through the `gdext_net`
   GDExtension, whose source lives in the server repo (`crates/gdext-net`) and shares the
   `protocol` crate. Run `addons/gdext_net/build.ps1`; it builds the crate and copies
   `gdext_net.dll` into `addons/gdext_net/`. The DLL is gitignored and never committed.
   Rebuild it whenever the protocol or the gdext crate changes.
3. Start a server: in the server repo, `cp .env.example .env`, set `PROJECTDAWN_NETCODE_KEY`,
   then `cargo run -p projectdawn-server` (add `PD_DEV_CMDS=1` for the Test Panel's dev
   tools). Its README has the detail.
4. Open this folder in Godot 4.4.1 and run. The login screen's server field defaults to
   localhost; register an account, make a character, enter the world.

## Where to read next

- `CLAUDE.md`: the project's working notes. It is written for an AI assistant but it is the
  most complete map of the code: commands, architecture, conventions, and the one live
  To-Do list. Read "Architecture: two repos, one game" and "Code style" first.
- `docs/concepts/architecture/systems_overview.md`: every system that exists and how it
  works, kept current as things ship.
- `docs/concepts/architecture/README.md` and the server repo's `docs/server_design.md`:
  the client/server contract. Read before any change that crosses the wire.
- `docs/reference/commands.md`: every command you can type (CLI tools, chat commands, keys).
- `docs/session_notes/`: the per-session changelog, newest first in its `README.md`.
- `docs/playtest_notes/`: playtest checklists. An item is only "done" when a filled checklist
  shows it passing; `CHECKLIST_RUN_ORDER.md` says what to run next.

## Working here

- Server changes reach players only after a push and a redeploy of the hosted server; client
  changes only through a new export (`builds/`, gitignored, distributed by hand). Every
  export is stamped with its commit by `addons/build_stamp`.
- The spell data exists on both sides (`data/spell_definitions.gd` and the server's
  `spells.toml`); `tools/check_spell_lockstep.gd` reports drift and must read zero before a
  spell change is done.
- The project treats any player exploit, however small, as critical. Read the "Security /
  exploits" section of the To-Do before touching combat, inventory, casting or anything the
  server validates.
- Playtest feedback lands in `docs/playtest_notes/`; new checklists start from
  `TEMPLATE_checklist.md` there.
