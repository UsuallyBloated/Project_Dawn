# Next-Session Handoff — written 2026-05-05

Self-contained prompt for the next Claude Opus client. The block between
the `===` markers is intended to be copied verbatim into a fresh
conversation.

```
======================================================================
You're picking up Project Dawn — a Godot 4.4 / GDScript MMORPG client,
its companion Rust server, and a standalone procedural dungeon
generator. Three repos:

- Client: F:\Projects\Project_Dawn\        (master branch, latest 2ec7757)
- Server: F:\Projects\server\              (main branch,   latest f5ce434)
- Dungeon: F:\Projects\ProceduralDungeon\  (master branch, latest 774d73e)

Read these in order before doing anything:

1. F:\Projects\Project_Dawn\CLAUDE.md
   - Project conventions, autoload map, To-Do list. Do NOT modify it.
2. F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_05.md
   - The most recent session record. Covers everything that landed
     today: Tier 1+2 saves, UI scaling, .tres class-cache fix
     (original session), then Track A (alpha distribution: bug-report
     button, Windows export preset, Tester README), then Track B
     (server kickoff: workspace, protocol crate, auth WS service).
3. F:\Projects\server\docs\server_design.md
   - Source of truth for the wire protocol and server architecture.
4. F:\Projects\server\README.md
   - Quick-start to run/test the server.

Run `git log --oneline -5` in all three repos to confirm state before
you begin anything.

CURRENT REALITY
- The local-save alpha (Project_Dawn) is shippable —
  builds/ProjectDawn.exe exists and was smoke-tested,
  README_FOR_TESTERS.md is ready, the Discord bug-report button is
  wired to https://discord.gg/T77GRKNv.
- The server (Projects/server/) compiles on Rust 1.95.0; the auth
  WebSocket service handles Register / Login / CharList / CharCreate /
  CharDelete / Logout against a local SQLite DB; 5/5 tests pass; the
  binary runs (`cargo run -p projectdawn-server`, listens on
  0.0.0.0:8765 by default). World UDP / renet handler is NOT yet
  wired — types are defined in protocol::world but no transport, no
  tick loop, no AI. Client still operates client-authoritative against
  local saves.
- ProceduralDungeon is the user's standalone seed-based BSP dungeon
  generator (Godot 4.4). It has its own session notes under
  F:\Projects\ProceduralDungeon\session_notes\. The Project_Dawn
  client embeds a slightly different copy of this generator at
  addons/procedural_dungeon/ — that copy is OFF-LIMITS (see hard
  rules); the standalone one at F:\Projects\ProceduralDungeon\ is
  fair game if the user asks.

HARD RULES (carry forward from prior session)
- Do not modify any of: CLAUDE.md, addons/procedural_dungeon/,
  scripts/enemy.gd, docs/concepts/world/maps/, docs/reference/,
  docs/playtest_notes/testing_notes_2026_05_02.md,
  docs/playtest_notes/testing_notes_2026_05_05.md. Those are the
  user's separate work in the Project_Dawn repo.
- Do not commit debug.log, builds/, or target/.
- Match the existing commit-message tone in each repo (run
  `git log --oneline -5` and read the latest commit body).
- Local saves on the client must keep working — that's the alpha's
  persistence model until the world server is online.
- User runs Windows / PowerShell. Use the Bash tool for POSIX scripts.
- Pause and ask before touching files outside the agreed-on scope,
  before any destructive git operation, and before pushing to a
  remote.
- The ProceduralDungeon repo's only untracked file as of handoff is
  scripts/test_player.gd.uid (Godot meta). Do not commit it without
  asking.

WHAT'S NOT DONE — pick ONE with the user before you start
The brief deliberately stops at "auth service running, verifiable".
The next agreed work item is up to the user. Options, in roughly
ascending complexity:

A. Client GDScript protocol mirror.
   New file: F:\Projects\Project_Dawn\scripts\net\protocol.gd
   Mirror the Rust types in
   F:\Projects\server\crates\protocol\src\auth.rs and world.rs as
   GDScript dicts/enums. Small but required before client can talk
   to server.

B. Launcher (separate Godot project).
   New project: F:\Projects\launcher\
   Login form + char-select + char-create UI. Calls the auth WS,
   stores session_token, hands off to ProjectDawn.exe with
   --auth-token / --char-id / --world-endpoint args. Per
   server_design.md Section 17.

C. World UDP server.
   crates/projectdawn-server/src/world/ — renet listener, 20 Hz tick
   loop, area-of-interest replication. Big chunk (1–2 weeks). Start
   with Connect/Heartbeat/Position only; no gameplay code yet.

D. Client net adapter.
   New autoload: F:\Projects\Project_Dawn\autoloads\net.gd
   Single owner of the renet client. Existing autoloads subscribe to
   Net.signal_x. Per server_design.md Section 19 Layer 1.

E. ProceduralDungeon work.
   F:\Projects\ProceduralDungeon\ has its own todo_list.md and
   session_notes/. If the user steers you here, read those first
   and treat the standalone repo as the source of truth (the
   addons/procedural_dungeon/ copy in the client repo will diverge
   and is off-limits).

F. Backlog items.
   Open in CLAUDE.md (faction system, mount system, PvP flagging,
   sound, target-of-target frame, player portrait, EQ-style
   multi-window chat, weather, swimming, etc.) or in the
   architecture doc's Open Questions section.

Most logical order on the network track is A → B → C → D, but the
user may have their own priority. ASK FIRST. Do not start work
without explicit go-ahead on the chosen track.

BEFORE YOU START
Once the user picks a track:
- For A or B: confirm the GDScript file path / launcher project name.
- For C: confirm Rust 1.95.0 toolchain still pinned, propose a small
  first slice (Connect + Heartbeat + position broadcast for one
  player), get sign-off before writing code.
- For D: explicitly note that this changes existing autoloads from
  authoritative to read-only mirrors — surface that risk before
  refactoring.
- For E: read F:\Projects\ProceduralDungeon\todo_list.md and the
  session_notes/ index, ask which item.
- For F: read the relevant section of CLAUDE.md, ask which item.

DELIVERABLES at end of session
- One commit per repo touched, matching existing commit-message
  style with HEREDOC.
- An appended section in
  F:\Projects\Project_Dawn\docs\session_notes\session_YYYY_MM_DD.md
  (today's date) describing what was done.
- Index update in
  F:\Projects\Project_Dawn\docs\session_notes\README.md.
- If ProceduralDungeon was touched, also append to its own
  F:\Projects\ProceduralDungeon\session_notes\session_YYYY_MM_DD.md
  and update the index there.

Begin by reading the four (five if pursuing E) docs above, then ask
the user which of options A–F to pursue.
======================================================================
```
