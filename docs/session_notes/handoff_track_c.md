# Track C Handoff — World UDP Server

> **For pasting into a fresh Claude Code conversation.** Copy the entire
> contents of this file (between this line and the bottom of the file)
> as the next session's opening prompt.

---

You're picking up Project Dawn — a Godot 4.4 / GDScript MMORPG client,
its companion Rust server, and a separate Godot launcher project.

## Repo state at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Client | `F:\Projects\Project_Dawn\` | `master` | (run `git log --oneline -3` to confirm) |
| Server | `F:\Projects\server\` | `main` | `f5ce434` |
| Launcher | `F:\Projects\launcher\` | `main` | `0bc0464` |
| Procedural Dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `774d73e` |

Run `git -C <each> log --oneline -5` before touching anything to confirm
the state still matches.

## Read these in order before doing anything

1. `F:\Projects\Project_Dawn\CLAUDE.md` — project conventions, autoload
   map, To-Do list. **Do NOT modify.**
2. `F:\Projects\Project_Dawn\docs\session_notes\session_2026_05_06.md`
   — Track A (GDScript protocol mirror) and Track B (launcher) context.
3. `F:\Projects\server\docs\server_design.md` — wire-protocol contract
   and architecture decisions.
4. `F:\Projects\server\README.md` — quick-start.

## Current reality

- **Auth WebSocket service**: shipping. Register / Login / CharList /
  CharCreate / CharDelete / Logout, Argon2id-hashed passwords, 256-bit
  session tokens, 30-min TTL. 5/5 tests pass. `cargo run -p
  projectdawn-server` listens on `0.0.0.0:8765`.
- **Launcher**: shipping. End-to-end verified by the user against the
  auth service: Register → CharCreate → CharDelete → Logout → Play.
  Hands off `--auth-token` / `--char-id` / `--world-endpoint` /
  `--client-version` to `ProjectDawn.exe` via `OS.create_process`.
- **Game client**: still client-authoritative against local saves. Has
  not parsed the launcher CLI args yet.
- **World UDP server**: not yet started. **This is your work.**

---

## Research that informs Track C

I (the previous Claude) researched three things before writing this
plan. Findings below.

### 1. renet version and security posture

- **Current stable**: `renet 2.0` (released January 2026). Use this,
  not the `0.0.16` sketched in the design doc.
- **Architecture**: core `renet` crate (channels + reliability) +
  transport (`renet_netcode` for UDP). Two-layer model: transport
  authenticates the connection, application protocol authenticates
  the session within it.
- **Two server auth modes** in `ServerAuthentication`:
  - `Unsecure`: any client that can reach the port can establish a
    renet connection. **No encryption**. Application-layer
    `session_token` is the only check.
  - **Secure (via `ConnectToken`)**: 32-byte private key shared
    between auth service and world server. Auth service signs a
    `ConnectToken` after validating the user's session; client uses
    that token to establish the renet connection; server's
    `NetcodeServerTransport` verifies it with the same private key.
    UDP packets are encrypted.

### 2. How production MMOs handle persistence

Researched via the prdeving.wordpress.com MMO architecture article,
plantbasedgames.io blog, GameDev.net threads. Consensus pattern:

1. **Source of truth is in-memory**, not the database. The DB is a
   persistence medium for crash recovery, not the live state.
2. **Save selectively, not constantly**. WoW-style cadence:
   - **Position**: every ~30 seconds (we'll do 60s — cheaper)
   - **Inventory**: every change, atomic SQL transaction per mutation
     (this is the entire dupe-prevention strategy)
   - **Zone change**: full save
   - **Level-up**: full save
   - **Logout / disconnect**: full save
   - **Periodic checkpoint** for active players: every 60s, just
     position + dirty quest rows
3. **No client-driven save calls** — the existing
   `SaveManager.save()` autoload becomes a no-op once the world
   server is online (per `server_design.md` §19 client migration).

`server_design.md` §9 already specifies this. Stay aligned.

### 3. Security audit (all three repos, dated 2026-05-06)

Status of currently-committed code:
- ✓ **No secrets in any repo**. Verified by grepping for
  `api[_-]?key`, `secret[_-]?key`, `private[_-]?key`, `aws_access`,
  hardcoded passwords, etc. across all three repos. The single match
  in `Project_Dawn/.claude/settings.local.json` is a literal
  `test-key-smoke` placeholder string in a permission allowlist —
  not a real key.
- ✓ `.env` was never committed in any repo (verified via
  `git log --all --full-history -- .env`).
- ✓ `.env.example` files contain only placeholder values.
- ✓ `.gitignore` excludes `.env`, `*.db*`, `target/`, `debug.log`
  in all relevant repos.

Status of the existing auth service:
- ✓ **Argon2id with default OWASP-current parameters** for password
  hashing (~50ms per attempt).
- ✓ **256-bit session tokens** via `OsRng::fill_bytes`, stored as
  raw BLOB on disk, transmitted as 64-char hex.
- ✓ **All SQL queries parameterized** with `bind()`. No injection.
- ✓ **Internal errors sanitized** — `error.rs` returns "internal
  server error" for `Internal` variants; never leaks server-side
  detail.
- ✓ **Banned-account check** on every login.
- ✓ **No password or token logging** at any tracing level.
- ✗ **No login rate limiting**. Friend-tier brute force is bounded
  by argon2 cost (~10/sec); not catastrophic for alpha. Add before
  public hosting.
- ✗ **No TLS** on the WebSocket. Relies on Tailscale WireGuard.
  Acceptable inside the tailnet; **must add TLS before public**.

---

## Decisions made (with reasoning)

### Decision 1 — renet auth mode: **Secure from the start**.

The user's instruction was *"absolutely no shortcuts ever taken when
security is in question."* That's a strong steer.

`Unsecure` mode means any process that can reach the world UDP port
can establish a renet connection. The application-layer
`session_token` rejects unknown connections at the first packet, but
the connection-establishment surface is wider than necessary. For
**~1 day of additional work** the secure path gives:

- Cryptographic guarantee that only auth-issued connections succeed
- Encrypted UDP packets (defends against tailnet packet inspection)
- Industry-standard pattern (no rip-and-replace later)

### Decision 2 — Netcode-token handoff: **temp file, not CLI arg**.

The launcher gets a `WorldConnectToken` (~2 KB signed blob) from the
auth service after `LoginOk`. Passing it via CLI args (`--connect-token=<hex>`)
would expose it in `ps` / Task Manager output to any local user.

Instead: launcher writes the token bytes to a temp file with
restrictive permissions, passes `--world-token-path=<path>` to the
game. Game reads, **immediately deletes** the file, then connects.
Token is single-use and expires within 30 seconds anyway, but
defense in depth.

### Decision 3 — Position persistence cadence: **60 seconds + events**.

Design doc §9 says "every 5 minutes". I'd shorten to 60 seconds.
SQLite WAL writes are cheap (~1 ms for the position row) and the
cost of losing 5 minutes of position on a crash feels rough for an
MMO. Inventory writes per-mutation as the doc already specifies.

### Decision 4 — Secret-management policy going forward.

1. **Never commit secrets**. If one slips through, rotate it
   immediately and rewrite history.
2. **All secrets via env vars**. `.env` gitignored; `.env.example`
   ships placeholders only.
3. **Server refuses to start without `PROJECTDAWN_NETCODE_KEY`**.
   No silent default-key fallback. Print explicit instructions if
   missing.
4. **No password / token / netcode-key logging** at any tracing
   level. Maintain the current discipline.
5. **Add `gitleaks` pre-commit hook** to all three repos as a
   future hardening pass (not this session — separate task).

---

## Track C slice scope

**In scope** (one weekend, ~3 days):

- Add `renet` 2.0 + `renet_netcode` 2.0 to `Cargo.toml` workspace
  dependencies, pinned with `=` constraint.
- Add `PROJECTDAWN_NETCODE_KEY` to `.env.example` and `Config`. **Refuse
  to start the server if not set.**
- New protocol messages in `crates/protocol/src/auth.rs`:
  - `ClientAuthMsg::RequestWorldToken { session_token, char_id }`
  - `ServerAuthMsg::WorldConnectToken { token_bytes: Vec<u8>,
    world_endpoint, expires_at_unix: i64 }`
- New `crates/projectdawn-server/src/world/` module:
  - `mod.rs` — `serve(cfg, pool)` — renet listener + tick loop
  - `tick.rs` — 20 Hz scheduler
  - `connection.rs` — per-connection state: `account_id`, `char_id`,
    `position: Vec3`, `last_seen: Instant`
  - `handlers.rs` — `Connect`, `Disconnect`, `Heartbeat`, `Move`
  - `persistence.rs` — 60s checkpoint loop
- Auth handler addition: `RequestWorldToken` → validate session →
  generate `ConnectToken` via `renetcode::ConnectToken::generate` with
  the private key → return token bytes.
- Move-intent handler: validate `direction.length() <= 1.0`, integrate
  with `max_speed * tick_dt`, write to in-memory state. Position
  broadcast every tick to all connected players (one player for now).
- Heartbeat timeout: drop connection if no packet for 10 seconds.
- One Rust integration test in `tests/world_smoke.rs`: spin up auth +
  world on ephemeral ports, drive a renet client through Connect →
  Move → receive Position → Disconnect.

**Out of scope** (separate later sessions):

- Area of interest culling (irrelevant for one player)
- Combat / AI / inventory / chat / quests
- GM commands
- Login rate limiting (separate hardening pass)
- Mid-session reconnect window (60s grace per §11)
- Game-side CLI parser (`--world-token-path=...` etc.) — track D's
  job, after C lands
- Client `autoloads/net.gd` adapter — track D

---

## Proposed file structure

```
F:\Projects\server\
├── Cargo.toml                                  # +renet, +renet_netcode (=pinned)
├── .env.example                                # +PROJECTDAWN_NETCODE_KEY=
├── migrations/                                 # no schema changes this session
├── crates/protocol/src/auth.rs                 # +RequestWorldToken, +WorldConnectToken
├── crates/projectdawn-server/src/
│   ├── world/                                  # NEW MODULE
│   │   ├── mod.rs                              # public serve()
│   │   ├── tick.rs                             # 20 Hz scheduler
│   │   ├── connection.rs                       # per-conn state
│   │   ├── handlers.rs                         # Connect/Disconnect/Heartbeat/Move
│   │   └── persistence.rs                      # 60s position checkpoint
│   ├── auth/mod.rs                             # +RequestWorldToken handler
│   ├── config.rs                               # +netcode_private_key: [u8; 32]
│   └── main.rs                                 # spawn world::serve alongside auth::serve
└── tests/
    └── world_smoke.rs                          # Connect→Move→Position→Disconnect
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
- **Do not modify the launcher** until track D — track C is purely
  server-side.
- **Do not commit** `debug.log`, `builds/`, `target/`, `world.db*`,
  `.env`.
- **Pin renet at exactly 2.0.x** in `Cargo.toml` (use `=2.0.0` or
  current 2.0.x point). Don't allow auto-upgrade through `^`.
- **Refuse to start the server** without `PROJECTDAWN_NETCODE_KEY`.
  No silent default-key fallback.
- **Match existing commit-message tone**. Run `git log --oneline -5`
  per repo and read the latest commit body. Use HEREDOC for the
  body. Co-Authored-By footer.
- **User runs Windows / PowerShell**. Use the Bash tool for POSIX
  scripts.
- **Pause and ask** before any destructive git operation, before
  pushing to a remote, before touching files outside the agreed-on
  scope.
- **Local saves on the client must keep working** — that's the
  alpha's persistence model until track D wires the net adapter.

---

## Verification plan

1. **Generate a private key** for first run:
   ```
   PROJECTDAWN_NETCODE_KEY=$(openssl rand -hex 32) cargo run -p projectdawn-server
   ```
   On Windows PowerShell:
   ```
   $env:PROJECTDAWN_NETCODE_KEY = (1..32 | ForEach { '{0:x2}' -f (Get-Random -Max 256) }) -join ''
   cargo run -p projectdawn-server
   ```
2. **Confirm both listeners bind**:
   - Auth WS on `0.0.0.0:8765`
   - World UDP on `0.0.0.0:7777`
3. **Run tests**:
   ```
   cargo test -p projectdawn-server
   ```
   The new `world_smoke` test should pass alongside the existing 5
   auth tests.
4. **No new files committed that shouldn't be**: `git status` after
   each commit; check for stray `.db`, `.env`, `target/`, etc.

---

## Deliverables for the session

1. **One commit per repo touched**, matching the existing
   commit-message style (HEREDOC body, Co-Authored-By footer).
   Expect commits in:
   - `F:\Projects\server\` — the bulk of the work
   - `F:\Projects\Project_Dawn\` — only `docs/session_notes/`
     (append today's date file, update README.md index)
2. **Append a section** to `session_YYYY_MM_DD.md` (today's date)
   describing what was built.
3. **Update the index** in
   `Project_Dawn/docs/session_notes/README.md`.
4. **Do NOT touch the launcher repo** this session.

---

## Open questions to ask the user before starting

1. **Confirm the secure renet path is the right call.** This adds
   ~1 day vs. unsecure mode. The user explicitly chose
   security-first earlier in the conversation, but verify they
   still want this scope.
2. **`world_endpoint` value**: defaults to `127.0.0.1:7777`. Once
   the user has Tailscale, this becomes their tailnet IP. Confirm
   default is fine for local testing.
3. **Database schema changes**: I'm planning to leave the
   `characters` table as-is (it already has `pos_x`, `pos_y`,
   `pos_z`, `yaw`, `zone`). No new migration this session. Verify
   they're OK with that.

Begin by reading the four docs in the "Read these in order" section,
then ask the three open questions above. Do not start writing Rust
until you have answers.
