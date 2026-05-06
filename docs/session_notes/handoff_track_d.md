# Track D Handoff — Game ↔ World Net Adapter

> **For pasting into a fresh Claude Code conversation.** Copy the entire
> contents of this file (between this line and the bottom of the file)
> as the next session's opening prompt.

---

You're picking up Project Dawn — a Godot 4.4 / GDScript MMORPG client,
its companion Rust server (auth WebSocket + world UDP), and a separate
Godot launcher project.

## Repo state at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Client | `F:\Projects\Project_Dawn\` | `master` | (run `git log --oneline -3` to confirm) |
| Server | `F:\Projects\server\` | `main` | `3aa9d30` |
| Launcher | `F:\Projects\launcher\` | `main` | `0bc0464` |
| Procedural Dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `774d73e` |

Run `git -C <each> log --oneline -5` before touching anything to confirm
the state still matches.

## Read these in order before doing anything

1. `F:\Projects\Project_Dawn\CLAUDE.md` — project conventions, autoload
   map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_06.md`
   — Tracks A (GDScript protocol mirror), B (launcher), C pre-flight,
   and C implementation. The "Track C — World UDP server" section at
   the bottom is the directly upstream context for this session.
3. `F:\Projects\server\docs\server_design.md` — wire-protocol contract,
   especially §6 (wire protocol), §10 (connection lifecycle), §17
   (launcher protocol), §19 (client migration path).
4. `F:\Projects\Project_Dawn\scripts\net\protocol.gd` — the GDScript
   mirror you'll extend.
5. `F:\Projects\launcher\scripts\main.gd` and
   `F:\Projects\launcher\scripts\net\protocol.gd` — the launcher's
   current Play-button flow and protocol copy.

## Current reality

- **Auth WebSocket service**: shipping. Register / Login / CharList /
  CharCreate / CharDelete / Logout / **RequestWorldToken** (new).
  Argon2id, 256-bit session tokens, 30-min TTL.
- **World UDP service**: shipping (slice 1). renet 2.0 + renet_netcode
  2.0 in Secure mode (32-byte private key). 20 Hz tick. Two channels
  (0=ReliableOrdered system, 1=Unreliable position). Server-authoritative
  speed cap. 60s position checkpoint. Single player at a time, no AOI,
  no combat / inventory / chat. **Server-side end-to-end test passes**:
  `tests/world_smoke.rs` drives the full Auth WS → ConnectToken →
  renet handshake → Move → Position → Disconnect cycle.
- **Launcher**: shipping for the auth flow only. Register → CharCreate
  → CharDelete → Logout → Play hands off `--auth-token` / `--char-id` /
  `--world-endpoint` / `--client-version` to `ProjectDawn.exe` via
  `OS.create_process`. The launcher does **not** call `RequestWorldToken`
  yet — that's part of this session.
- **Game client**: still client-authoritative against local saves. Does
  not parse the launcher CLI args yet. Has no networking code beyond
  the existing `scripts/net/protocol.gd` constants/builders.
- **The bridge between game client and renet**: doesn't exist. **This is
  the central piece of your work.**

---

## The central decision Track D must make

**How does GDScript talk to `renet`?**

Godot 4 has built-in WebSocket and ENet networking, but `renet` is its
own UDP protocol with `netcode.io`-style cryptographic handshake. None
of Godot's built-ins speak it. Three architectural options:

### Option A — GDExtension wrapping renet (recommended)

Write a small Rust GDExtension that exposes `RenetClient` +
`NetcodeClientTransport` + bincode encode/decode + the protocol crate
to GDScript. Use [gdext](https://github.com/godot-rust/gdext) (the
canonical Rust binding for Godot 4).

**Pros:** Single process, no IPC overhead, the protocol crate is
already in the workspace and can be shared verbatim. Production-grade.
gdext is mature on Godot 4.x.

**Cons:** Adds a Rust GDExtension to the game's build pipeline. The
.dll has to ship with the game .exe. Cross-platform builds (later) need
per-platform .dll/.so/.dylib.

**Effort:** ~2–3 days for a minimal shim covering Connect /
Disconnect / send / receive / poll. The protocol crate is already done.

### Option B — Sidecar subprocess

Game spawns a small Rust binary (`projectdawn-net.exe`) on connect.
Game ↔ subprocess speaks length-prefixed bincode over stdin/stdout.
Subprocess speaks renet ↔ server.

**Pros:** Zero GDExtension complexity. Pure-IPC boundary is easy to
debug (you can `tee` the pipe). Easy to swap implementations later.

**Cons:** Extra process to manage (crash, cleanup, zombies). IPC adds
~0.1–0.5ms per message (probably fine for 20 Hz, but real). Two
binaries to ship. Stdin/stdout buffering is a footgun on Windows.

**Effort:** ~1–2 days for the subprocess + a `subprocess.gd` adapter.

### Option C — Pure GDScript bincode + raw `PacketPeerUDP`

Reimplement renet's `netcode.io` handshake + reliability layer + bincode
in GDScript. Use Godot's `PacketPeerUDP`.

**Pros:** No native code. Single-binary shipment.

**Cons:** Massive effort (renet's reliability layer is non-trivial).
Hand-rolled crypto is dangerous. bincode in GDScript is fragile and slow.
Will fight encoding edge cases for weeks. **Not recommended.**

**Effort:** Weeks. Don't.

### My recommendation

**Option A (GDExtension via gdext).** The Rust workspace is set up,
the protocol types are already shared, and gdext is a well-trodden
path on Godot 4.x. Spend the half-day learning gdext's build flow, then
the bridge itself is small.

**Stop here. Ask the user which option they want before writing any
code.** This is a load-bearing decision — the rest of the slice scope
below assumes Option A. If the user picks B or C, the file plan
changes significantly.

---

## Track D slice scope (assuming Option A)

**In scope** (one weekend, ~3–4 days):

### Server repo (`F:\Projects\server\`)

Likely **zero** changes. The protocol crate already defines
`RequestWorldToken` / `WorldConnectToken` and the auth handler is wired.
If the GDExtension needs new helpers from the protocol crate, add them
here.

### New crate: `crates/gdext-net/` in the server workspace

Rust GDExtension exposing the renet client to GDScript. Public surface
(GDScript-callable):

```
NetClient.gd (autogen by gdext)
  func connect_to(token_bytes: PackedByteArray, world_endpoint: String) -> bool
  func disconnect_now() -> void
  func is_connected() -> bool
  func poll(delta: float) -> void           # call every _process
  func send_msg(channel: int, bytes: PackedByteArray) -> void
  func receive_msg(channel: int) -> PackedByteArray   # null when empty
  func encode_client_msg(dict: Dictionary) -> PackedByteArray
  func decode_server_msg(bytes: PackedByteArray) -> Dictionary
  signal connected()
  signal disconnected(reason: String)
  signal message_received(channel: int, bytes: PackedByteArray)
```

Internally: thin wrapper over `RenetClient` + `NetcodeClientTransport`
+ `bincode::serde` against the existing `protocol::world` types.
Channels match the server (0=system, 1=position).

Build target: cross-compile for Windows for now. Add Linux/Mac when
those targets actually need to run the client.

Output: `target/release/gdext_net.dll` copied into
`Project_Dawn/addons/gdext_net/` alongside a `.gdextension` config file.

### Client repo (`F:\Projects\Project_Dawn\`)

- `scripts/net/protocol.gd` — add `make_request_world_token(session, char_id)`
  builder, `AUTH_REQUEST_WORLD_TOKEN` / `AUTH_WORLD_CONNECT_TOKEN` tag
  constants, decoder for `WorldConnectToken { token_bytes, world_endpoint,
  expires_at_unix }`. **Mirror this change to the launcher copy in the
  same session** (see Hard rules below — they must stay 1:1).
- `scripts/cli_args.gd` (new) — parse `OS.get_cmdline_args()` for
  `--auth-token=`, `--char-id=`, `--world-token-path=`,
  `--world-endpoint=`, `--client-version=`. Returns a struct or `null`
  if the launcher didn't pass them (alpha-with-fallback mode).
- `autoloads/net.gd` (new) — single-owner network adapter. Wraps the
  GDExtension's `NetClient`. State machine: Disconnected → Connecting →
  Connected → Disconnected. Reads `--world-token-path`, **immediately
  deletes the file** after read, then connects.
- `addons/gdext_net/gdext_net.gdextension` — Godot extension config
  pointing at the .dll.
- `addons/gdext_net/gdext_net.dll` — built artifact. **Do not commit
  the .dll** unless the user wants to. Gitignore it; document the build
  command in `addons/gdext_net/README.md`.

### Game integration (still in `Project_Dawn`)

- On game start, parse CLI args. If `--auth-token` etc. are present:
   1. Read token file at `--world-token-path`.
   2. Delete the file.
   3. Decode the JSON / bytes (depends on what the launcher writes —
      see below) into a `PackedByteArray` of the raw renet ConnectToken.
   4. `Net.connect_to(token_bytes, world_endpoint)`.
   5. Wait for `Net.connected` signal. Send app-layer `Connect`
      message. Wait for `ConnectOk`. Transition out of loading screen.
- If CLI args are absent (alpha-with-fallback mode): **keep the
  existing local-save Test Room / Test Dungeon flow unchanged.** That's
  the dev-iteration path per `server_design.md` §19. No behavior change
  for the local-save case.
- For slice 1, the only intent the game sends to the server is
  `Move`. Combat / inventory / chat / quests stay client-side until
  later tracks fan them out.

### Launcher repo (`F:\Projects\launcher\`)

- `scripts/main.gd` — extend the Play button flow:
   1. After char select, send `RequestWorldToken { session_token,
      char_id }`.
   2. On `WorldConnectToken` reply: write `token_bytes` to a tempfile.
      Use `OS.get_cache_dir()` or similar; on Windows, the user's
      `%LOCALAPPDATA%\Temp` is the right home. Set restrictive perms
      if Godot exposes them; if not, accept user-readable for the
      ~30-second token lifetime.
   3. Spawn the game .exe with `--world-token-path=<temp_file_path>`
      added to the existing args.
   4. Game reads the file and deletes it (game side, not launcher).
- `scripts/net/protocol.gd` — **identical** changes as the
  Project_Dawn copy. They diff to zero or this gets ugly fast.

---

## Out of scope (explicitly deferred)

- **Replicating other players** — server has no fan-out beyond the
  owner. Slice 1 is single-player on the wire. Multi-player connection
  + AOI + EntitySpawn handling lands in track E.
- **Combat / inventory / chat / quests on the wire** — server doesn't
  emit those events yet. The game continues to handle them locally
  via the existing autoloads.
- **Mid-session reconnect** (`server_design.md` §11) — server doesn't
  implement the 60s grace window yet.
- **Cross-platform builds** of the GDExtension — Windows only for now.
- **Auto-update for the launcher** (`server_design.md` §13) — separate
  task; needs a host that can serve `update_manifest.json`.
- **TLS for the auth WS** — Tailscale provides encryption inside the
  tailnet. Add when going public.
- **Linux/Mac client builds.**

---

## Proposed file structure

Assuming Option A (GDExtension):

```
F:\Projects\server\
└── crates/gdext-net/                  # NEW
    ├── Cargo.toml                     # cdylib; gdext + renet + protocol deps
    └── src/
        └── lib.rs                     # NetClient struct exposed to Godot

F:\Projects\Project_Dawn\
├── addons/gdext_net/                  # NEW
│   ├── gdext_net.gdextension          # Godot config
│   ├── gdext_net.dll                  # built artifact, .gitignored
│   └── README.md                      # build instructions
├── autoloads/
│   └── net.gd                         # NEW — Net autoload, registered in project.godot
├── scripts/
│   ├── cli_args.gd                    # NEW — parse OS.get_cmdline_args()
│   └── net/
│       └── protocol.gd                # MODIFIED — RequestWorldToken builder + tags
├── project.godot                      # MODIFIED — add Net autoload
└── docs/session_notes/
    └── session_YYYY_MM_DD.md          # APPENDED

F:\Projects\launcher\
├── scripts/
│   ├── main.gd                        # MODIFIED — Play button: RequestWorldToken + temp file
│   └── net/
│       └── protocol.gd                # MODIFIED — must mirror Project_Dawn's exactly
```

---

## Hard rules (carry forward from prior sessions)

- **Do not modify** in `Project_Dawn`:
  - `CLAUDE.md`
  - `addons/procedural_dungeon/`
  - `scripts/enemy.gd`
  - `docs/concepts/world/maps/`
  - `docs/reference/`
  - `docs/playtest_notes/testing_notes_2026_05_02.md`
  - `docs/playtest_notes/testing_notes_2026_05_05.md`
- **`scripts/net/protocol.gd` MUST stay 1:1 between `Project_Dawn` and
  `launcher`.** Any change to one is a change to both, in the same
  session. Diff at commit time to confirm.
- **`PROJECTDAWN_NETCODE_KEY` must NEVER appear in any commit, log
  line, error message, or test fixture.** Test private keys are random
  per-test bytes generated at runtime, not constants in source.
- **Token files are short-lived.** The game reads the file at
  `--world-token-path` and **deletes it immediately**, before connecting.
  Even if the connection fails, the file is gone. The 30s token TTL is a
  belt-and-suspenders backstop, not the primary defense.
- **Launcher → game handoff is via temp file, not CLI arg.** CLI args
  are visible in `ps` / Task Manager output. The token is the cryptographic
  gate on the world server; treat it like a password.
- **Local-save Test Room flow must keep working** when the game is run
  without launcher CLI args. That's the dev-iteration path until full
  parity. Detect the absence of CLI args and fall back; do not error.
- **Pin `gdext` to a specific version** in `crates/gdext-net/Cargo.toml`.
  Use `=X.Y.Z` so an incidental upgrade can't change codegen. Verify the
  pin against [crates.io](https://crates.io/crates/godot) before adding.
- **Match existing commit-message tone** in each repo. Run
  `git log --oneline -5` per repo and read the latest commit body.
  HEREDOC body, Co-Authored-By footer.
- **Pause and ask** before any destructive git operation, before
  pushing to a remote, before touching files outside the agreed scope.
- **User runs Windows / PowerShell.** Use the Bash tool for POSIX
  scripts; PowerShell tool for native Windows ops.

---

## Verification plan

For Option A (GDExtension):

1. **Build the GDExtension** for Windows:
   ```
   cd F:\Projects\server
   cargo build -p gdext-net --release
   ```
   Confirm `target/release/gdext_net.dll` exists. Copy to
   `F:\Projects\Project_Dawn\addons\gdext_net\` (or wire a build script).

2. **Open `Project_Dawn` in Godot 4.4.** Editor should detect the
   .gdextension and load the .dll without errors. `class NetClient`
   should be available in GDScript autocomplete.

3. **Server-side: existing 6/6 tests still pass.**
   ```
   cd F:\Projects\server
   cargo test
   ```

4. **End-to-end manual verification**:
   - Start server with `PROJECTDAWN_NETCODE_KEY` set.
   - Open launcher in Godot, register a fresh account, create a
     character, click Play.
   - Game .exe spawns, parses CLI args, reads token file (verify file
     is deleted by the time the connection completes), connects to
     world UDP, sees `ConnectOk`.
   - WASD movement updates position; the server's debug log shows the
     incoming Move messages.
   - Quit game cleanly; verify the launcher returns to char select
     (or quits, depending on launcher behavior).

5. **Alpha-with-fallback mode**:
   - Run `Project_Dawn` directly (no launcher, no CLI args).
   - Existing local-save Test Room flow should be unchanged.

---

## Deliverables for the session

1. **One commit per repo touched**, matching existing commit-message
   style (HEREDOC body, Co-Authored-By footer). Expect commits in:
   - `F:\Projects\server\` — the GDExtension crate (only if Option A).
   - `F:\Projects\Project_Dawn\` — net adapter, CLI parser, protocol.gd
     update, project.godot autoload registration, addons/gdext_net/
     scaffold, session notes.
   - `F:\Projects\launcher\` — Play-flow extension, protocol.gd mirror.
2. **Append a section** to `session_YYYY_MM_DD.md` (today's date)
   describing what was built. Update the index in
   `Project_Dawn/docs/session_notes/README.md`.
3. **A `addons/gdext_net/README.md`** documenting how to rebuild the
   .dll on a fresh clone. The user (and any future dev) needs to be
   able to rebuild without you.

---

## Open questions to ask the user before starting

1. **Confirm Option A (GDExtension via gdext) vs B (sidecar subprocess)
   vs C (pure GDScript).** This is the load-bearing call. Don't write
   any Rust or GDScript until the architecture is locked in. The rest
   of this plan assumes A.
2. **Where does the .dll live?** Options:
   - Inside the game repo at `addons/gdext_net/gdext_net.dll`,
     gitignored, rebuilt via documented script.
   - Inside the game repo, **committed** so the launcher's "Play"
     flow Just Works on a fresh checkout.
   - In the server repo's `target/release/`, with a copy step on
     game .exe export.
   The committed-DLL path is the easiest for the user; the rebuilt path
   is the cleanest. Ask which they prefer.
3. **gdext version pin.** Verify the latest stable on crates.io before
   adding to `Cargo.toml` — pin with `=`. (As of Track C work date,
   `godot` crate ≥ 0.2.x supports Godot 4.x; verify before pinning.)
4. **CLI arg conflict resolution.** If the user runs the game .exe
   manually with both `--auth-token=...` AND no `--world-token-path`,
   what should happen? Suggest: log a warning, fall through to
   local-save mode. Don't error — friendlier for dev iteration.

Begin by reading the five docs in the "Read these in order" section,
then ask the four open questions above. Do not start writing code
until the user has answered question 1 (architecture) at minimum.
