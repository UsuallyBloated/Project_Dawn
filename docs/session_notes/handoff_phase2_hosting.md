# Handoff — Phase 2: Host it, invite one person

**For:** a fresh Claude session. **Written:** 2026-07-31, from a source survey (not from the plan doc).
**Repos:** client `f:\Projects\Project_Dawn`, server `F:\Projects\server`, **launcher `F:\Projects\launcher`**.
**Branch:** `fix/xp-leveling-overflow` (all).

**Phase goal (from `docs/schedule.md`):** someone who is not the user, from a machine that is not
theirs, makes an account, makes a character, kills something, and logs out clean.

> **Read this first.** Everything below was verified against source. Where the survey found a
> decision that is the user's to make, it is listed in **Part 1** as a question — *do not guess an
> answer and start building.* Ask, then execute. Several of these change what you build.

---

## Part 0 — The blocker nobody wrote down

**There is no launcher executable, and the game client cannot log in without one.**

- The game `.exe` contains **zero WebSocket code**. Account creation, login, and character select
  live entirely in `F:\Projects\launcher`, a **third Godot project** that `CLAUDE.md`'s "two repos"
  framing omits.
- `F:\Projects\launcher` has **no `export_presets.cfg`** and has never been exported. Every doc says
  "open it in Godot and press F5." That is a dev workflow, not something you can send a friend.
- So today **there is literally no artifact you can hand a tester that lets them make an account.**
  This blocks the phase outright and is a *build* task, not a docs task.
- The launcher repo also has **no git remote** (the other two are mirrored to GitHub). It is
  local-only and unbacked-up. Losing that folder loses the only auth client.

Additional distribution facts:
- The game `.exe` alone is not enough: the export's `include_filter` does **not** embed
  `gdext_net.dll`. A tester's folder needs `ProjectDawn.exe` + `gdext_net.dll` +
  `addons/gdext_net/gdext_net.dll` (mirror the current `builds/` layout) **plus** the launcher exe.
- The launcher finds the game by looking for `ProjectDawn.exe` **as a sibling file** (or via
  `$PROJECTDAWN_EXE`, which on the dev box is often set to `ProjectDawn.console.exe` — unset it
  before smoke-testing a package, or the launcher silently runs the wrong exe).
- `builds/addons/gdext_net/gdext_net.dll` is a **stale May-7 orphan** with a different hash that the
  export does *not* refresh. **Delete `builds/addons/` before zipping** or a 12-week-old DLL ships
  alongside the current one.
- Double-clicking `ProjectDawn.exe` with no launcher args does **not** error — it drops the user into
  an offline lobby as a canned level-50 Troll named "Chortle". A tester who skips the launcher will
  report "multiplayer doesn't work" while playing a perfectly functional single-player build.

---

## Part 1 — Decisions the user must make first

Ask these before writing code. Grouped by how much they change the work.

### Blocking the build
1. **Deploy topology.** Tailscale tailnet (the plan `server_design.md:93-95` already assumes), a
   public VPS, or a home port-forward? This sets `PROJECTDAWN_WORLD_ENDPOINT` and decides whether the
   plaintext auth socket is exposed to the open internet at all.
2. **Cleartext auth: accept or fix?** There is **no TLS anywhere**. The launcher hardcodes `ws://`
   and the server accepts a raw `TcpStream`. On a public host the friend's **password crosses the
   internet in the clear**. Tailscale covers this with WireGuard and needs *zero* code change; a
   `wss://` reverse proxy needs a launcher code change. This is a judgment call, not a technical one.
3. **How does the friend get a launcher?** (a) author an export preset and ship
   `launcher.exe` + `ProjectDawn.exe` + the DLLs in one zip, (b) fold login into the game client so
   there is one exe, or (c) something else. Option (a) is a new artifact — ask for icon/version.
4. **Fresh `world.db` or carry the dev one?** The current DB has **26 dev accounts, 137 characters,
   522 stale sessions, and one account already flagged `is_gm`**. Fresh = clean first-account
   experience; carrying = keeps the user's GM account and characters. Migrations auto-apply either way.

### Shapes the deploy
5. **Which single account gets `is_gm`?** If carrying the DB, run `grant_gm` with no args to audit and
   explicitly turn **off** anything that is not the user.
6. **Raise `min_client_version`?** It is currently **inert** (server wants `0.1.0`; both clients
   hardcode `0.1.0`). Raising it is a **three-repo** change (server env + `launcher/scripts/net/protocol.gd:9`
   + `Project_Dawn/scripts/net/protocol.gd:9`) and must happen *after* new builds are in the tester's
   hands, or it locks everyone out with an unhelpful error and no download link.
7. **Debug or release build on the host?** `scripts/run-server.ps1` runs a **debug** `cargo run`
   today. The `target/release` binary is months stale.
8. **Ship the Test Panel to the friend, or strip it?** The dev Test Panel mounts in **every**
   launcher-mode session (`scripts/world.gd:19-20`) — the friend sees a gold-bordered overlay with
   Spawn Mob / Level Up / Full Heal / Trigger Death. Server-routed buttons are `is_gm`-gated and
   no-op for them, but the client-side ones (Trigger Death, Despawn All Enemies, time-of-day) are
   **not** gated. The code comment already says to strip it.
9. **Does the friend self-register, or do you pre-create their account?** Register is currently open
   to anyone who can reach port 8765 — no invite code, no email verification.
10. **Backups:** cadence, destination, retention. `scripts/backup.sh` is POSIX-only with hardcoded
    `/var/lib/projectdawn` paths and has never run. The only backup that exists is one hand-taken
    `world.db.bak-pre0009` from 2026-07-07.

### Needs a live check (not answerable from the repo)
11. **Is `https://discord.gg/T77GRKNv` still live and watched?** That invite *is* the entire
    bug-report feature (below). Click it before Phase 2, not after.
12. **Static IP?** `world_endpoint` accepts **no DNS names**, so IP churn has no in-code answer.

---

## Part 2 — Server configuration (the exact facts)

Config is **env-var only** (there is no config.toml despite a doc comment saying so), read from the
process env plus a hand-rolled `.env` parser. Six fields, all in
`crates/projectdawn-server/src/config.rs`:

| Field | Env var | Default | Change for host? |
|---|---|---|---|
| auth_bind | `PROJECTDAWN_AUTH_BIND` | `0.0.0.0:8765` | No (already all-interfaces) |
| world_bind | `PROJECTDAWN_WORLD_BIND` | `0.0.0.0:7777` | **No — keep 0.0.0.0** |
| world_endpoint | `PROJECTDAWN_WORLD_ENDPOINT` | `127.0.0.1:7777` | **YES — the one mandatory change** |
| database_url | `PROJECTDAWN_DATABASE_URL` | `sqlite://world.db?mode=rwc` | Only if relocating the DB |
| min_client_version | `PROJECTDAWN_MIN_CLIENT_VERSION` | `0.1.0` | Decision #6 |
| netcode key | `PROJECTDAWN_NETCODE_KEY` | **none — required** | **YES — mint a fresh one** |

### `world_endpoint` — the trap that will cost you an afternoon
- It is **the address the friend's game actually dials.** It is signed *into* the renet ConnectToken;
  the GDExtension explicitly **discards** the `--world-endpoint` CLI arg
  (`gdext-net/src/lib.rs:509` literally does `let _ = world_endpoint;`).
- **Left at `127.0.0.1:7777`, the friend's client dials its own loopback.** Login, character list,
  and character select all work perfectly first, *then* Play hangs and times out. It looks exactly
  like a world-server bug. It is a config bug.
- It **must be an `IP:port` literal.** `.parse::<SocketAddr>()` does no DNS, so a hostname or DDNS
  name is a hard boot failure — *after* the auth socket is already listening, so the log shows two
  healthy startup lines and then the process exits.
- Nothing validates reachability. `0.0.0.0:7777`, a LAN IP, or a stale tailnet IP all parse and boot
  cleanly, then silently break every remote client. **The boot log line is your only confirmation.**
- Only **one** endpoint can be advertised at a time, so local and remote testing become mutually
  exclusive without an env swap + restart.

### Netcode key
`PROJECTDAWN_NETCODE_KEY`, **64 hex chars = 32 bytes**, no default, loud boot refusal if
missing/malformed. **Mint a fresh one for the host** — the current key has sat in a dev working
directory since 2026-05-06 and on a USB snapshot. Anyone holding it can forge ConnectTokens the world
server accepts, **including the `is_gm` bit** (packed into the token's `user_data[8]`). `.env` is
gitignored, so a naive redeploy loses the key and the server refuses to boot — decide where it lives.

### `.env` gotchas (all verified by running the binary)
- **A UTF-8 BOM silently destroys the first key line.** PowerShell's `Out-File -Encoding utf8` and
  `Set-Content` write a BOM by default. If it lands on `PROJECTDAWN_WORLD_ENDPOINT` you silently fall
  back to localhost. Write with `[System.IO.File]::WriteAllLines`, or keep a `#` comment as line 1
  (which is why the current file works).
- **`PD_DEV_CMDS=1` in `.env` defeats `run-server.ps1`'s non-Dev mode.** The script only clears the
  *shell* variable; the `.env` loader then re-sets it. `CLAUDE.md` actively advises putting it in
  `.env` for `dev-run.sh`, so this trap is one copy-paste away. **Check the boot line reads
  `dev_cmds=false` on every hosted start.**
- **A real shell env var always beats `.env`.** A leftover `$env:PD_DEV_CMDS` from an earlier
  PowerShell window silently overrides the file for that window's lifetime.
- **CWD matters.** `.env` and `world.db` are both resolved relative to the process working directory.
  A systemd unit or shortcut without the right `WorkingDirectory` **silently creates a brand-new empty
  database with no accounts**. `run-server.ps1` handles this; nothing else does.

---

## Part 3 — Pointing a client at the host

**No client re-export is needed for the host change.** This surprised the survey and it is worth
internalising: the world address rides inside a server-signed token, so it is pure runtime config.

- The tester types the **auth** address into the launcher's Server field (persisted to
  `user://launcher.cfg`, default `127.0.0.1:8765`). Decide whether to change
  `DEFAULT_AUTH_HOST` (`launcher/scripts/main.gd:8`) to the real host so testers never type it.
- **The field takes `host:port` and is prefixed verbatim with `ws://`.** A tester typing just
  `dawn.example.com` gets port **80**, not 8765. No validation, no port defaulting.
- The tester has **no UI anywhere** to see or set the world UDP address — it comes back inside
  `LoginOk` from the server's env var.
- Unlike `world_endpoint`, the **auth** host *is* a free-form string, so a DNS name works there. The
  asymmetry is an easy trap.

**Ordering rule (already burned us once):** rebuild the gdext DLL **before** the Godot export, or the
export silently packages the previous DLL. Verify by hashing `builds/gdext_net.dll` against
`addons/gdext_net/gdext_net.dll`.

**Build/export notes:** Windows x86_64 only (no linux/macos entries in the `.gdextension`), Vulkan
required, no VC++ redist needed (the DLL is `+crt-static`). A stale exported client still *connects*
to a newer server — the protocol id is validated server-side only — which has already produced one
"everything looks fine, clients don't render each other" hunt.

---

## Part 4 — Production security + ops

**Dev-command gate.** Every dev handler calls `can_use_dev_cmds()` = `is_dev || is_gm`. `is_dev` is
process-global from `PD_DEV_CMDS == "1"`, **cached in a `OnceLock`** — so flipping it mid-run does
nothing, a restart is always required. Production = start with `PD_DEV_CMDS` unset (plain
`.\scripts\run-server.ps1`, no `-Dev`), then
`cargo run -p projectdawn-server --bin grant_gm -- <username> on` for exactly one account.
**`grant_gm` takes effect on that account's next world login**, not immediately.

**Ports:** inbound **TCP 8765** (auth) + inbound **UDP 7777** (world). Many VPS providers and home
routers block UDP or expose only TCP by default, and **UDP failures are silent**. Both binds are IPv4
(`0.0.0.0`), so an IPv6-only path will not connect.

**Things that will bite an operator:**
- **No graceful shutdown.** No Ctrl-C/SIGTERM handler. Killing the server discards up to **60 s**
  (`CHECKPOINT_INTERVAL`) of position, HP/MP, XP, inventory, and coins **for every player online**. A
  clean player-side logout flushes immediately. **Operational rule: get everyone to log out, then stop.**
- **The DB is not WAL**, despite two source comments claiming it is (verified: `journal_mode=delete`,
  `synchronous=FULL`). So running `admin_report` against a **live** server can block the server's
  commits (5 s busy timeout). Switching to WAL is a cheap two-line hardening but needs an exclusive
  lock — do it while stopped.
- **No kick, no ban, no shutdown warning.** `GmCommand` implements only `/give`. `accounts.is_banned`
  is *read* at login but **nothing ever writes it**. Removing a disruptive player means stopping the
  server and running raw SQL — and even then it only blocks the next *login*; the live session keeps
  playing. (There is a written plan for this: `handoff_account_admin.md`.)
- **Clock skew breaks world login invisibly.** ConnectTokens live **30 s** and the client validates
  against its own clock. A friend's PC more than ~30 s off fails at the transport handshake *after* a
  perfectly successful login. Verify NTP before blaming the network. A cold Godot first-run (shader
  compile, antivirus scan) can also eat that 30 s budget — retry from the launcher works.
- **Logs:** UTF-16 with ANSI codes (PowerShell `Tee-Object`), `server.log` is overwritten each run,
  `logs/server_<timestamp>.log` accumulates with **no rotation**. Throttle events now log at INFO
  (`Login rejected — rate limited`), so brute-force *is* visible.
- **`server/README.md` is badly stale** and will mislead you: it claims the world simulation is "not
  yet implemented" and tells you to promote a GM with raw SQL. **Trust `config.rs` and `CLAUDE.md`.**

**Rate limiting (already shipped + playtested):** per-IP, 5 attempts / 60 s, **separate budgets for
Login and Register**, success clears the Login budget. The loopback exemption was deliberately
removed. Note a friend who mistypes five times is locked out for a minute **with no countdown shown**,
and if you and the friend ever share a public IP you share the budget.

**Accepted-risk list — get explicit sign-off before a friend connects.** All need a *modified* client
except (e): (a) `BuyItem` ignores `vendor_id` (buy any priced item from anywhere, ≤360 copper);
(b) cross-store transfers persist as separate transactions, so a crash mid-write can dupe or lose a
banked item; (c) movement has a speed cap but no server-side collision (clip through walls at legal
speed); (d) `InspectPlayer` has no range gate; (e) the unclean-kill relogin refusal has never been
reconciled and should be re-tested on the real host.

---

## Part 5 — Tester-facing work

### `README_FOR_TESTERS.md` is worse than stale — it is inverted
Written 2026-05-05, last touched 06-19. It documents a **single-player, local-save, no-server alpha**
and explicitly says: *"No multiplayer. The lobby's Host/Join buttons exist but the server doesn't yet
— Test Room is the only working entry point."* Handing that to a Phase 2 tester actively misdirects
them. It never mentions accounts, the launcher, login, character creation, corpses, resurrection,
death penalty, quests, the banker, currency, `/camp`, groups, or PvP. It also points testers at
`CLAUDE.md` — the internal dev doc containing the To-Do and the open-exploit list. **Do not ship that
pointer.**

Things a rewrite must cover that currently appear nowhere:
- **Character names** reject digits and spaces (letters, apostrophe, backtick only) — "Grognak42"
  fails. **Usernames** conversely allow digits but reject apostrophes. Two different rulesets,
  neither documented.
- **The window X button is a deliberate hard-crash simulation, not a quit.** The tester stays linkdead
  ~30 s: their body remains in the world and killable, and their own relogin is refused during that
  window. Without this note, "I closed the game and it wouldn't let me back in" reads as a bug.
- Known-broken things to *not* report (confirm with the user which to disclose): bank Items tab does
  not live-refresh on deposit (item appears to vanish, returns on relog), bags open on left-click, no
  sound at all, no player portrait, incoming `/tell` not implemented, no bind point so you respawn
  where you died with no death lock, corpse gear needs manual re-equip, ~32 of 156 spells silently
  fail server-side, named mobs have no enrage or guaranteed drops (Rotfang's fang will not drop),
  bard songs apply once instead of sustaining, the Tarnished Silver Ring's AGI +1 does not apply, and
  mounts/weather/swimming/faction are absent.

### The bug-report button transmits nothing
It is a single button calling `OS.shell_open("https://discord.gg/T77GRKNv")`
(`scripts/options_screen.gd`). No HTTP endpoint, no telemetry, no upload. A remote tester's report
reaches the user **only** if they manually type it in Discord and manually attach
`%APPDATA%\Godot\app_userdata\Project_Dawn\debug.log`.

**Worse:** `debug.log` is opened with `FileAccess.WRITE` at startup, so it is **wiped every launch**.
A tester who hits a bug, closes the game, reopens it, then goes to grab the log has already destroyed
it. The `debug_prev.log` rotation fires at 2000 lines, not on restart, so it is not a backup. If the
README says "attach debug.log", it must also say **copy it before relaunching**.

Ask the user whether to keep the Discord redirect or build real capture (an HTTP endpoint was already
scoped and deferred in `handoff_2026_07_18.md:92`).

---

## Part 6 — Suggested execution order

1. Get answers to **Part 1** (especially topology, TLS stance, and the launcher-distribution choice).
2. **Unblock distribution:** author the launcher export preset, export it, and assemble a single
   tester package (launcher + game + both DLLs). Delete `builds/addons/` first. Give the launcher repo
   a remote/backup while you are in there.
3. **Stand up the host:** fresh netcode key, `.env` written without a BOM, `world_endpoint` = the real
   `IP:port`, `PD_DEV_CMDS` unset (**verify `dev_cmds=false` in the boot line**), firewall TCP 8765 +
   UDP 7777, NTP on. Decide fresh-vs-carried DB. `grant_gm` exactly one account.
4. **Smoke-test it yourself from a second machine** (not the dev box, not loopback) end to end:
   register, create a character, kill something, log out clean. This is the phase's definition of done
   rehearsed with a known-good tester.
5. **Rewrite `README_FOR_TESTERS.md`** for the hosted flow, with the literal address to type.
6. **Verify the Discord invite**, then invite the one friend.
7. Record the result in a session note + a playtest checklist under `docs/playtest_notes/`
   (`TEMPLATE_checklist.md` is the format), and tick the To-Do's hosting item **only on that evidence**
   (`CLAUDE.md` session workflow step 6 — and note step 6 requires updating **both** `docs/schedule.md`
   *and* `docs/schedule.html`).

---

## Conventions for the incoming session
- Read `CLAUDE.md` first. Minimize em-dashes and left/right arrows in prose and UI text.
- Commit style: explain *why*; end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Don't tick anything without playtest evidence.
- Verify against source rather than trusting docs — this survey found `server/README.md`,
  `README_FOR_TESTERS.md`, two "WAL" code comments, and `CLAUDE.md`'s "two repos" framing all wrong.
