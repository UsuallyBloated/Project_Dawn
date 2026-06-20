# Session 2026-06-19 — Camp + Linkdead, Slice A (server linkdead + client X-button)

The EverQuest-style logout model from `docs/design/camp_and_linkdead.md`. Built and
playtest-verified the **involuntary** half (linkdead) this session; the **voluntary** half
(`/camp`) is Slice B and still open. Both repos, no wire-protocol change (so no DLL rebuild).

## The model

A character must stay in the world ~30 s before it actually leaves. Two triggers:

- **Clean leave** (Quit Game, or a future `/camp` completion): reaps immediately, account freed.
- **Unclean drop** (crash / killed client / network loss): the body goes **linkdead** — lingers
  ~30 s in-world, still targetable and **killable**, frozen in place; a same-account relogin is
  refused ("You already have a character in this world.", with a remaining-seconds countdown)
  until it reaps. Sits on the one-character-per-account deny-login already shipped.

## Server (`F:/Projects/server`, Slice A)

- `world/mod.rs` — new `LINKDEAD_SECS` (30 s, tunable) by `HEARTBEAT_TIMEOUT`.
- `world/connection.rs` — `PerConnection` gains `clean_disconnect: bool` and
  `linkdead_since: Option<Instant>`, plus a `linkdead_expired(now, window)` predicate (2 new
  unit tests for the reaper timing: never-expired when live, respects the window otherwise).
- `world/handlers.rs` — the `Disconnect` intent sets `clean_disconnect = true`; new
  `send_kick_with_reconnect` carries `Kick.reconnect_after_secs`.
- `world/tick.rs` —
  - Factored the old inline disconnect cleanup into a `reap_connection(...)` helper (+ a small
    `despawn_owned_pets`). `ClientDisconnected` now branches: **clean** reaps immediately;
    **unclean** marks the body linkdead and leaves it `in_world` so it stays in the targeting
    snapshots (killable) and the AOI grid (peers still see it). Pet despawns at once; group
    membership is kept for the window.
  - Linkdead bodies are frozen (skipped in the movement-integration pass).
  - Per-tick **reaper sweep** removes bodies past `LINKDEAD_SECS`; the heartbeat-idle sweep skips
    already-linkdead conns.
  - Deny-login populates `reconnect_after_secs` with the remaining linkdead seconds.
- `docs/server_design.md` — replaced the stale "60 s frozen / untargetable / seamless-resume"
  reconnect section (and the now-wrong Disconnect bullets) with this vulnerable wait-then-relog
  model.

**Bug found + fixed while building:** because `client_id == char_id`, a refused *same-character*
relogin collides with the lingering body's key and emits its own `ClientDisconnected` when it
tears down after the kick. Untreated, that stray event reset the reap timer (spam relogin →
never reaps). The handler now ignores any disconnect for an already-linkdead conn.

**Build decision (surfaced to the user, accepted):** both the 10 s app-heartbeat idle *and* a
true transport drop are treated as linkdead — simplest and most consistent; the tradeoff is a
~10 s hiccup sends you linkdead for the window. Tunable later.

## Client (`F:/Projects/Project_Dawn`)

- `autoloads/save_manager.gd` — the window **X button** (`_on_close_requested`) is now a hard
  self-kill: `OS.kill(OS.get_process_id())`. It sends no clean `Disconnect`, so the server takes
  it as an unclean drop → linkdead. It kills only that instance's PID, so a second client on the
  same machine keeps running (this also solved the tester's "can't kill one instance in Task
  Manager" problem). **Quit Game** in the Options screen is unchanged (clean save + `Disconnect`
  + quit) and stays the deliberate-logout path. File docstring updated.
- `README_FOR_TESTERS.md` — saving note clarified: X = a "crash" for testing linkdead; use Quit
  Game to log out cleanly.

## Verification

- Server: `cargo build` clean; **136 lib tests pass** (134 + 2 new reaper-timing). Ran the
  clean-disconnect integration test (`two_clients_see_each_other`) green.
- Client: headless boot clean (0 script/parse errors).
- **Two-client playtest (server.log):** hard-killed client A via X → app-heartbeat timeout at
  10 s → marked linkdead → an enemy kept damaging the body the whole window (hp 87→54) →
  reaped at exactly 30.0 s. Client B's **Quit Game** logged a clean `client requested disconnect`
  and reaped instantly with no linger. No runtime warnings/errors.

---

# Slice B — `/camp` (voluntary sit-gated logout), 2026-06-20

The deliberate mirror of linkdead. Both repos, wire **PD_W0016 → PD_W0017**, gdext DLL rebuilt.
Recon + adversarial review were both run as multi-agent workflows.

## The behavior

Sit, type `/camp`, watch an amber "Making camp... 30" countdown; standing/moving or taking damage
cancels it; survive the full 30 s seated and you log out cleanly. `/camp cancel` aborts.

## Wire (PD_W0017)

`ClientWorldMsg::Camp` / `CancelCamp` and `ServerWorldMsg::CampUpdate { remaining_secs: u32,
active: bool }`, all appended at enum ends; `WORLD_PROTOCOL_ID` bumped. gdext: `send_camp` /
`send_cancel_camp` + the `camp_update` signal (Incoming variant + classify + fire emit); DLL rebuilt.

## Server

- `CAMP_SECS` (30 s) in `world/mod.rs`; `camp_since` + `last_damaged_at` on `PerConnection`
  (+ `note_damage_taken`).
- `handlers.rs`: sit-gated `Camp` handler (rejects if not seated / already camping), `CancelCamp`,
  `send_camp_update`; `DeathBroadcast` now clears `camp_since` (death aborts a camp).
- `tick.rs`: per-tick "5c camp sweep" — cancel on `!is_sitting` or `last_damaged_at >= camp_since`
  (the marker is set at the 5 player-damage sites: PvP melee, PvP spell, both thorns reflects, enemy
  melee); `camp_since` cleared on the linkdead transition; the deny-login reason now carries a "try
  again in ~Ns" estimate from the lingering linkdead seconds.

## Client

- `hud.gd`: `/camp` (gated on `Combat.is_player_seated()`) + `/camp cancel`; an amber HUD countdown
  label driven by `Net.world_camp_update`, ticked in `_process`. Cancels locally on stand for
  responsiveness; resets the overlay on any `app_disconnected`.
- `net.gd`: `broadcast_camp` / `broadcast_cancel_camp` + the `world_camp_update` relay.
- `protocol.gd`: documentary tags for the new messages.

## Key decision — completion is CLIENT-DRIVEN

At the countdown's end the *client* runs the same clean logout as Quit Game (a clean `Disconnect`
that reaps the body + frees the account; exits to desktop). The server does NOT force a mid-world
kick — there is no in-game return-to-lobby/char-select flow yet, so a kick would strand the player
in a frozen world. The server owns the vulnerability window + the cancel rules. Revisit if a
return-to-char-select flow lands.

## Review (multi-agent, 6 dimensions) — 3 real bugs, all fixed

1. Same-tick damage didn't cancel a fresh camp (`>` → `>=`, since `camp_since` and same-tick
   `last_damaged_at` share the one per-tick `Instant`).
2. Death while camping didn't abort the camp (`DeathBroadcast` now clears `camp_since`).
3. Completion handoff: the original server-kick stranded the in-world client + left a stale
   "Making camp... 0" label. Fixed by the client-driven completion + a HUD reset on any disconnect.
Protocol append-only, the gdext bridge, and all 5 damage hooks reviewed clean.

## Verification

- Server `cargo build` clean; **136 lib tests** pass. Client editor-mode compile clean.
- **Playtest 2026-06-20: works.** (Checklist: `docs/playtest_notes/camp_checklist.md`.)

## Not done (deferred)

- An in-game return-to-char-select flow (camp/kick would use it instead of exit-to-desktop).
- A live-ticking relogin countdown in the lobby UI (the server sends `reconnect_after_secs`; the
  client currently shows the server's one-shot "try again in ~Ns" string).
