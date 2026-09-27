# Handoff: where things stand after Phase 2 (2026-08-11)

Cold-start context for a session picking this up fresh. Covers 2026-08-05 to 08-11, in which
the project stopped being a localhost thing.

Read this first, then `CLAUDE.md`. The detailed record is
`docs/session_notes/session_2026_08_11.md`.

---

## The one-paragraph version

The game is now **hosted on a physical Dell PowerEdge R720** in the user's basement, running
Ubuntu Server 26.04, serving over a private **Tailscale** tailnet. On 2026-08-11 a second person
(the user's wife) connected from her own machine, registered, made a character, killed something,
grouped, and logged out clean. That closed **Phase 2**, the highest-risk phase in
`docs/schedule.md`. Her session found three bugs in about ten minutes, none of which were
findable solo. One is fixed; two are open.

---

## What exists now that did not on 2026-08-04

| | |
|---|---|
| **Host** | Dell PowerEdge R720, service tag `6D8LBY1`, Ubuntu Server 26.04 LTS, hostname `projectdawn` |
| **Reach** | Tailscale, `100.93.108.112`. Auth TCP 8765, world UDP 7777. Nothing exposed to the internet. |
| **Layout** | `/opt/projectdawn`, `projectdawn` system account, systemd unit `projectdawn.service`, `enabled` |
| **Source on host** | `/opt/projectdawn/src`, tracking branch **`fix/xp-leveling-overflow`** |
| **Storage** | VD0 4x300GB RAID 10 + hot spare (OS, `world.db`); VD1 3x1.2TB RAID 5 at `/data` (backups) |
| **Backups** | Nightly 04:00 to `/data`; weekly off-site to Google Drive via a dev-box scheduled task. Restore verified. |
| **Access** | SSH key-only, `ssh wrightt@100.93.108.112`. Passwords disabled, root login off. |

**New docs.** `docs/deployment/` holds `r720_host_setup.md` (how the machine was built),
`server_operations.md` (**start here** for running it), and `inviting_a_player.md` (onboarding
checklist). `README_FOR_TESTERS.md` was rewritten from scratch. `server/docs/deployment_linux.md`
already existed and is authoritative from app deployment onward.

> **`docs/deployment/` is deliberately uncommitted.** The user asked for these to stay untracked
> working documents. Do not `git add .` in this repo.

---

## Things that will bite you if you do not know them

**Client and server changes travel different paths.** A server change reaches players after
push, pull on the R720, `cargo build --release`, `cp target/release/projectdawn-server ~/`, and
`systemctl restart projectdawn`. Forgetting the `cp` is the classic mistake: systemd runs the
copied binary, not the one in `target/`. A **client** change reaches nobody until the build is
re-exported from Godot and the new zip is sent out.

**The host deploys from GitHub, not from the working tree.** Uncommitted or unpushed server work
does not exist as far as the R720 is concerned.

**Check `dev_cmds=false` on the boot line after every start.** `journalctl -u projectdawn -n 20
--no-pager`. It is a two-in-one check: dev commands are off, *and* the build is at least as new
as commit `a765573` (which added that field). See the stale-deploy story below.

**There is no graceful shutdown.** `systemctl restart` discards up to 60 s of position, HP, XP,
inventory and coins for everyone online. Get people to log out first.

**`/opt/projectdawn` is mode 750.** The operator's own account cannot read it without `sudo`.
That is the service isolation working.

**`grant_gm` does not read `.env`** and defaults to `world.db` relative to the current directory
with `mode=rwc`, so running it from the wrong place silently creates an empty database and
reports no accounts. Always pass `PROJECTDAWN_DATABASE_URL` explicitly; the full command is in
`server_operations.md`.

---

## The stale-deploy story, because it will happen again

The R720's first deployment ran a binary **six weeks old with none of the Phase 1 exploit gates
in it**. `git clone` takes the repo's *default* branch, which was `main` at `98728ea` (26 June),
while all work was on `fix/xp-leveling-overflow`, 30 commits ahead.

**The only symptom was a missing field in one log line.** Everything else looked healthy.

Two habits came out of it: clone with `-b <branch>` explicitly, and treat the presence of
`dev_cmds=` on the boot line as a build-freshness check.

Also discovered at the same time: both repos were far ahead of GitHub (server 30 commits, client
59). Both have been pushed. Worth checking `git status -sb` on both occasionally.

---

## Open right now

**1. Uncommitted server change: the rate-limit kill switch.** `crates/projectdawn-server/src/`
`auth/mod.rs` and `main.rs` are modified and **not committed, not deployed**. Adds
`PD_NO_RATE_LIMIT=1` to disable auth rate limiting, following the `PD_DEV_CMDS` idiom
(`OnceLock`, exact `"1"`, loud WARN at boot, reported on the startup line as `rate_limit`). The
user asked for this because the 5-per-60s cap is not worth worrying about during private testing.
Builds clean, 179 lib tests pass. **To finish:** commit, push, pull and rebuild on the R720, and
set `PD_NO_RATE_LIMIT=1` in `/opt/projectdawn/.env`. It is a security control being switched off;
it must come back before any public exposure, which is why the boot WARN exists.

**2. Respawn death-loop (high, user says a different sprint).** The first tester died, respawned
on the spot beside the mobs that killed her, and died again 20 seconds later. No bind point, no
death lock, no post-respawn invulnerability. Unwinnable for a new player. Existing To-Do item,
now escalated with evidence.

**3. `world_two_clients.rs` has 13 stable failures.** `cargo test` reports `29 passed; 13
failed`, and the **same** set fails in parallel, serially, and on a stashed tree with no local
changes. The docs describe these as timing-flaky with a varying set; that is no longer true. Lib
(179) and protocol (15) tests all pass. Until this is understood, `cargo test` cannot tell you
whether a server change is safe.

**4. Two `.uid` files untracked** (`autoloads/auth_client.gd.uid`, `scripts/login.gd.uid`).
Godot 4.4 script-identity files. Godot's guidance is to commit them; nobody has decided.

---

## Fixed this session, for context

**Group panel showed one player's stats under another's name** (client `5bde067`). `GroupManager`
was still driving group stats over Godot's **vestigial ENet multiplayer**, which this game does
not otherwise use (it talks to the server through `gdext_net` + renet). In launcher mode this
fired RPCs at server char_ids against an empty peer list, and because `multiplayer.get_unique_id()`
is `1` on every client while the leader's char_id was also 1, the non-leader's own stats were
written into the leader's row. Fixed three ways: a launcher-mode guard on `_flush_stats`, keying
`_local_stats()` on `Net.get_player_id()`, and subscribing to the server's existing
`world_health_update` / `world_mana_update` / `world_stamina_update` fan-out. **No wire change was
needed** — the server already broadcasts those to every in-world client with no range culling.

Worth internalising: a code comment at `group_manager.gd:31` asserted the legacy RPCs were
unreachable in launcher mode. It was right about the action methods and wrong about the
signal-driven path, and that was enough to hide the bug until two people grouped up.

**Also fixed:** `global_position` set before `add_child` in three remote entity managers (client
`a4d67ea`), two missing `has_signal()` guards in `hud.gd`, and an expired Discord invite in
`options_screen.gd::BUG_REPORT_URL` (fixed in code, not just the README).

---

## Where to look

| Question | File |
|---|---|
| How do I run / update / recover the server? | `docs/deployment/server_operations.md` |
| How do I get a new tester on? | `docs/deployment/inviting_a_player.md` |
| How was the machine built, and why? | `docs/deployment/r720_host_setup.md` |
| How do I deploy to a fresh Linux box? | `server/docs/deployment_linux.md` |
| What happened in the first real session? | `docs/playtest_notes/first_external_tester_2026_08_11.md` |
| What is built and how does it work? | `docs/concepts/architecture/systems_overview.md` |
| What is left to do? | The To-Do in `CLAUDE.md`. It is the one checkbox list. |
