# Camp + Linkdead: Implementation Plan (kickoff for a fresh session)

You are implementing the EverQuest-style **camp** and **linkdead** logout system in Project Dawn.
This document is self-contained, but read these two first for the full rationale and the decisions
already locked with the user:

- `docs/design/camp_and_linkdead.md` (the spec and the why)
- `docs/session_notes/handoff_camp_linkdead.md` (the short checklist)

Do not re-litigate the locked decisions below; they came out of a design conversation with the user.

---

## 0. Orientation (read before touching code)

Project Dawn is a **multiplayer-only** MMORPG: a Godot 4.4 GDScript client
(`F:/Projects/Project_Dawn`, this repo) and a Rust authoritative server (`F:/Projects/server`).
They share a wire protocol (`crates/protocol`) bridged into the client by the `gdext_net`
GDExtension DLL.

Constraints a fresh session WILL trip on:

- **Run server cargo from `F:/Projects/server`.** The toolchain is pinned (rust 1.95.0) by
  `rust-toolchain.toml`; running from elsewhere silently picks the wrong rustc.
- **Append-only enums.** bincode encodes enum variants by position. Any new `ClientWorldMsg`,
  `ServerWorldMsg`, or `KickCode` variant MUST be appended at the END of its enum, or every later
  discriminant shifts and client/server desync silently.
- **Bump `WORLD_PROTOCOL_ID`** in `crates/protocol/src/world.rs` whenever you change the wire (it is
  PD_W0016 now, so go to PD_W0017). After ANY protocol or gdext change, **rebuild the DLL**:
  `addons/gdext_net/build.ps1` (about 45-60s, run it plainly, no `2>&1`). The DLL is gitignored.
- **gdext cannot encode tagged enums from the GDScript client.** Camp/CancelCamp carry no payload so
  this is a non-issue here, but keep any client-to-server message to primitives/strings.
- Server logs to **stdout** (no log file). Capture with `... | Tee-Object server.log`. Run with dev
  commands enabled: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server`.
- **Do not modify anything above `F:/Projects/`.**
- Style: the user dislikes em-dashes and the arrow glyphs; use plain punctuation and words like "to".
  Match the comment density and idiom of the surrounding code.

Build / verify commands:

- Server tests: `cargo test -p projectdawn-server --lib` (from `F:/Projects/server`, about 30s).
- Server build: `cargo build -p projectdawn-server`.
- Client boot check (must be 0 errors): run
  `"F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --path f:\Projects\Project_Dawn --quit`
  and confirm no `SCRIPT ERROR` / `Parse Error`.
- Live debugging: the in-game debug console (backtick) tails `DebugLog`. Instrument the
  disconnect/camp paths with `DebugLog.info/warn(...)` while building; it is the only window into a
  client/server bug.

---

## 1. The model (locked, do not change)

One rule: **a character must remain in the world about 30s before it actually leaves.** Two triggers:

- **Voluntary `/camp`:** the player must be SITTING to start, a ~30s countdown runs (the character is
  vulnerable throughout), it is CANCELLED if the character MOVES or TAKES DAMAGE, and on completion
  the player logs out cleanly and can relog at once.
- **Involuntary linkdead:** an unclean disconnect (crash, killed client, network drop) leaves the
  body in-world and VULNERABLE for ~30s, a same-account relogin is refused with
  "You already have a character in this world.", and after the window it reaps.

Locked decisions: linkdead is vulnerable (killable); `/camp` requires sitting and cancels on
move/damage; v1 is **wait-then-fresh-login** (NO seamless reconnect-resume); ~30s is a tunable
server constant. This builds ON TOP of the one-character-per-account deny-login already shipped.

Together these close three exploits: log-off-to-escape, pull-the-plug-to-escape, and
force-boot-your-own-session.

---

## 2. What already exists (do NOT rebuild)

- **Deny-login:** `world/tick.rs`, in the `ServerEvent::ClientConnected` arm (search
  `duplicate login refused`). Refuses a duplicate login, never boots the live session, sends the
  kick reason, and lets the client self-disconnect so the reliable reason actually flushes.
- **Server-authoritative sit state:** `conn.is_sitting` (`world/connection.rs`), set by
  `ClientWorldMsg::Sit` / `Stand` (`world/handlers.rs`, search `ClientWorldMsg::Sit`), and the
  server already clears `is_sitting` when it integrates a movement intent. Your camp cancel rule
  maps directly onto this flag plus a damage event.
- **Kick countdown field:** `ServerWorldMsg::Kick` already carries an unused
  `reconnect_after_secs: Option<u32>` (always `None` today). Use it for the relogin countdown.
- **Targeting snapshots:** built from `connections.values().filter(in_world)` (`world/tick.rs`,
  search `player_snapshots`, and the PvP target validation + enemy AI `tick_chase` in `entity.rs`).
  A connection that stays in `connections` with `in_world = true` remains targetable. That is the
  lever for keeping a linkdead body vulnerable.
- **Timers:** `world/mod.rs` has `NETCODE_TIMEOUT_SECS = 15` (transport idle) and
  `HEARTBEAT_TIMEOUT = 10s` (app-level idle; the tick loop proactively disconnects idle clients).

---

## 3. Slice A: server linkdead linger + reap (do this first)

Goal: an unclean disconnect leaves the character in-world and killable for ~30s, then reaps; a clean
disconnect (Quit, or a `/camp` completion) reaps immediately as today.

1. Add `LINKDEAD_SECS` (about 30s) near `HEARTBEAT_TIMEOUT` in `world/mod.rs`.
2. Add `linkdead_since: Option<Instant>` and a `clean_disconnect: bool` to `PerConnection`
   (`world/connection.rs`), both default to None/false in `from_spawn`.
3. **Distinguish clean from unclean.** The only clean case is the player asking to leave: set
   `conn.clean_disconnect = true` in the app `ClientWorldMsg::Disconnect` handler (`handlers.rs`)
   before it returns `Outcome::Disconnect`. A `/camp` completion (Slice B) sets the same flag. Every
   other path (app-heartbeat idle, netcode timeout, transport drop) is unclean.
4. **Restructure `ServerEvent::ClientDisconnected`** (`world/tick.rs`). Today it despawns, flushes,
   and removes unconditionally. Change it to:
   - If `conn.clean_disconnect` is true: reap immediately via the existing logic.
   - Otherwise: set `conn.linkdead_since = Some(now)` and RETURN, leaving the body in `connections`
     with `in_world = true` and still in the AOI grid. Do NOT fan `EntityDespawn` yet (peers should
     keep seeing the body), and do NOT remove it.
   - Factor the existing despawn + pet/group cleanup + DB flush + `connections.remove` into a
     `reap_connection(...)` helper so both the immediate path and the reaper call the same code.
5. **Freeze the linkdead body:** where the tick loop integrates a connection's movement intent
   (search `latest_direction` / the move integration), skip it when `linkdead_since.is_some()` so
   the body does not drift.
6. **Reaper sweep** in the tick loop: for each connection whose `linkdead_since` is older than
   `LINKDEAD_SECS`, call `reap_connection(...)` (despawn fan-out, pet/group cleanup, DB flush,
   remove). Note: by this point renet has already dropped the transport, so do not call
   `server.disconnect` again; just remove from `connections` and fan the despawn.
7. **Skip linkdead connections in the heartbeat-idle sweep** so it does not keep re-flagging a body
   that is already on its linkdead timer.
8. **Relogin refusal** is already handled by deny-login (the linkdead conn is still in `connections`
   under the same account). Populate `reconnect_after_secs` in that `send_kick` with the remaining
   linkdead seconds.
9. **Pet/group during linger** (decide and comment): recommended is to keep group membership for the
   window (so a brief linkdead does not double-vanish the player from the roster) but despawn the pet
   immediately (a linkdead player cannot command it).

Build-time decision to surface (do not silently choose): should the app-heartbeat idle (10s) trigger
linkdead, or only a true transport drop? Treating both as linkdead is the simplest and most
consistent (both mean the client stopped talking), at the cost that a ~10s network hiccup sends you
linkdead for the window rather than letting you resume. Recommend treating both as linkdead for v1
and tuning the timers later; flag it for the user.

Verify Slice A (two clients on one machine is fine):

- A is in-world. **Hard-kill** A's client (Task Manager, NOT the Quit button). A's body stays about
  30s; a mob or player B can still damage and kill it; a same-account relogin is refused with the
  countdown; after the window the body reaps and relogin works.
- A clean Quit still frees the account immediately.
- `cargo test -p projectdawn-server --lib` stays green; add a reaper-timing test if feasible.

**Stop and report after Slice A verifies.** This is the structural change; the user will want to
playtest the linkdead behavior before you build `/camp`.

---

## 4. Slice B: /camp (do second; independently shippable)

Goal: a deliberate, sit-gated 30s logout.

1. **Protocol** (`crates/protocol/src/world.rs`): append `ClientWorldMsg::Camp` and
   `ClientWorldMsg::CancelCamp` at the END of the enum. Add a server confirm so the client countdown
   stays in sync: append `ServerWorldMsg::CampUpdate { remaining_secs: u32, active: bool }` at the
   END (`active = false` means cancelled or finished). Bump `WORLD_PROTOCOL_ID` to PD_W0017.
2. **gdext** (`crates/gdext-net/src/lib.rs`): add `send_camp` / `send_cancel_camp` (mirror
   `send_sit` / `send_stand`) and a `camp_update` signal with decode + emit (mirror an existing
   simple `ServerWorldMsg`). Rebuild the DLL.
3. **Server:** add `CAMP_SECS` (about 30) to `world/mod.rs` and `camp_since: Option<Instant>` to
   `PerConnection`. Handle `Camp`: reject if `!conn.is_sitting` (send a "You must be sitting to camp."
   line) or already camping; otherwise set `camp_since = now` and fan a `CampUpdate`. A camp sweep
   each tick: cancel (clear `camp_since`, fan `CampUpdate { active: false }`) if `is_sitting` is
   false (covers move and stand) or the connection took damage since `camp_since`; on completion
   (`now - camp_since >= CAMP_SECS`) set `clean_disconnect = true` and reap via the immediate path.
   `CancelCamp` clears it.
4. **Damage hook:** at the player-damage application site(s) (grep for where a player connection's
   `hp` is reduced by incoming PvP and enemy damage), clear `camp_since` so the sweep cancels the
   camp.
5. **Client:**
   - A `/camp` command in `scripts/hud.gd::_handle_chat_input` (next to `/sit` and `/stand`), sends
     `Camp`. Gate locally on the known sit state for a fast rejection line, but the server is
     authoritative.
   - A countdown panel (a simple HUD label is fine) driven by the `camp_update` signal; hide it on
     `active = false`.
   - Block movement and abilities locally during the countdown for responsiveness.
   - Surface the "You must be sitting to camp." rejection.
6. **Refused-relogin polish:** `scripts/lobby.gd` shows the kick reason; if `reconnect_after_secs`
   is present, append the remaining seconds.

Verify Slice B:

- Standing then `/camp` is rejected with "You must be sitting to camp."
- `/sit` then `/camp` starts a 30s countdown; moving OR taking a hit cancels it (the countdown
  clears and you stay in the world); surviving the full window seated logs you out cleanly and you
  can relog immediately.
- Client boots clean; server tests green.

---

## 5. Cross-cutting

- **Reconcile** `server_design.md:615-619`. It documents the OPPOSITE, never-built reconnect model
  (a 60s grace where the entity is frozen, untargetable, and resumes seamlessly). Replace that
  section with this vulnerable wait-then-relog model when Slice A lands.
- **Worst-case timing:** a hard crash takes up to the 15s netcode timeout to be DETECTED, then ~30s
  of linger, so up to ~45s before relogin. That is expected; document it. Token lifetime is a
  non-issue because a fresh relogin gets a brand new connect token.

---

## 6. Out of scope (v1)

- Seamless reconnect-resume on a brief network blip (the old `server_design.md` model).
- Corpse interactions for a killed linkdead character (the corpse system is a separate open to-do).

---

## 7. Wrap-up

- Commits: one server commit per slice (or a combined "Camp + linkdead (server)"); one client commit
  for Slice B plus the relogin-countdown polish. Stage explicit files (the server repo has stray
  `.exe` / `server.log` files; do not commit them). End commit messages with
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Docs to update when done: move the feature from the CLAUDE.md to-do into
  `docs/concepts/architecture/systems_overview.md` ("what exists"), reconcile `server_design.md`,
  write a dated session note in `docs/session_notes/` and add its README index row, and author a
  playtest checklist from `docs/playtest_notes/TEMPLATE_checklist.md`.
- The user playtests between slices. Do not commit until they have verified, matching their usual
  flow. A review pass (`/code-review`) is worthwhile since this touches the connection lifecycle and
  combat targeting.
