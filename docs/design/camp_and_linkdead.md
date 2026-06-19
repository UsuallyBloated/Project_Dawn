# Camp and Linkdead (deliberate and involuntary logout)

Status: design locked 2026-06-19, not yet built. Owner decisions captured below.

## The one rule

A character must remain in the world about 30 seconds before it actually leaves. That single
rule fires two ways:

- **Voluntary, `/camp`:** you sit, run a ~30s countdown (vulnerable the whole time), then you
  are cleanly logged out and can relog immediately. The camp *was* the wait.
- **Involuntary, linkdead:** on a crash or a killed client, the server runs the ~30s for you.
  Your character lingers in the world (still targetable and killable), a same-account relogin is
  refused with "you already have a character in this world", and after the window it reaps and
  you can log back in.

This sits directly on top of the one-character-per-account deny-login already built (a duplicate
login is refused, the live session is never booted). Together they close three exploits:

1. You cannot escape danger by logging off (the camp countdown keeps you vulnerable).
2. You cannot escape by pulling the plug (linkdead keeps the body vulnerable for the window).
3. You cannot force-boot your own live session to relog elsewhere (deny-login).

This is the classic EverQuest model.

## Decisions (locked with the user, 2026-06-19)

- **Linkdead is vulnerable.** The lingering character stays targetable and killable for the full
  window. This overrides the stale `server_design.md` reconnect note (see below).
- **`/camp` requires sitting, cancelled by movement or damage.** You must be seated (`/sit`, or
  the sit toggle) to start a camp. If the character moves or takes damage during the countdown,
  the camp is cancelled and you stay in the world.
- **v1 is wait-then-fresh-login.** A relogin during the window is refused; you wait it out and log
  in fresh (a new load). No seamless reconnect-resume in v1 (that is a later enhancement, and the
  harder one to build safely).
- **The window is a tunable server constant** (about 30s), not a hard-coded magic number.

## What already exists (grounded in the code)

- **Deny-login** at [tick.rs:756-769](../../../server/crates/projectdawn-server/src/world/tick.rs#L756-L769)
  refuses a duplicate login and never boots the live session. Because a linkdead character is
  still in the `connections` map under its account, this already refuses relogin during the
  linger window. We only refine the message and the countdown.
- **Sit state is server-authoritative.** `ClientWorldMsg::Sit` / `Stand`
  ([handlers.rs:701-720](../../../server/crates/projectdawn-server/src/world/handlers.rs#L701-L720))
  set `conn.is_sitting` ([connection.rs:171](../../../server/crates/projectdawn-server/src/world/connection.rs#L171)),
  and the server already flips `is_sitting` back to false when it integrates a movement intent.
  So "must be sitting" and "cancel on move" are both already trackable server-side. The client
  broadcasts sit/stand from `regen.gd`. (The sit toggle defaults to Z in `settings.gd`; the user
  referenced X, which is a trivial rebind, not part of this work.)
- **Precedent for a sit-gated action:** "You must be sitting to memorize spells"
  (`memorize.gd:104`). Same gate shape. That one is client-side; camp must be server-authoritative.
- **Disconnect today is instant and final** at
  [tick.rs:874-1091](../../../server/crates/projectdawn-server/src/world/tick.rs#L874-L1091):
  it despawns the entity, fans `EntityDespawn`, frees the account, runs pet/group cleanup, and
  flushes the DB. `NETCODE_TIMEOUT_SECS = 15` and `HEARTBEAT_TIMEOUT = 10s` live in `world/mod.rs`.
- **A disconnected character is currently unkillable** the instant it leaves `connections`,
  because the enemy-AI and PvP targeting snapshots are built from
  `connections.values().filter(in_world)` ([tick.rs:5814-5818](../../../server/crates/projectdawn-server/src/world/tick.rs#L5814-L5818)).
  "Vulnerable while linkdead" is the new behavior to build.
- **Doc conflict to reconcile:** `server_design.md:615-619` documents a *different*, never-built
  reconnect model (a 60s grace where the entity is frozen, untargetable, and resumes seamlessly
  with no load screen). That is the opposite of this design on two axes (untargetable vs
  vulnerable, resume vs wait). This design replaces it; update that section when Slice A lands.

## Slice A: server-side linkdead linger and reap

1. On an **unclean disconnect** (a transport timeout, not a clean `Disconnect` intent), do not
   despawn immediately. Mark the connection linkdead: add `linkdead_since: Option<Instant>` to
   `PerConnection`; keep it in `connections` with `in_world = true` so it stays in the targeting
   snapshots (vulnerable) and the AOI grid (peers still see the body); freeze its movement (zero
   its integrated direction so the body does not drift).
2. A **clean `Disconnect`** (Quit Game, or a `/camp` completing) reaps immediately via the
   existing path. The account frees at once.
3. **Reap sweep** in the tick loop: when `now - linkdead_since >= LINKDEAD_SECS`, run the existing
   disconnect cleanup (despawn fan-out, pet/group cleanup, DB flush, remove from `connections`).
4. **Relogin during the window** is already refused by deny-login. Refine the reason to the EQ
   phrasing and populate the existing-but-unused `ServerWorldMsg::Kick.reconnect_after_secs` with
   the remaining seconds so the client can show a countdown.
5. **If a linkdead character is killed**, it dies through the normal death path. The corpse and
   corpse-run system is not built yet (it is an open to-do), so death does what it does today.
   Fine for v1; revisit when corpses land.

Call these out at build time rather than silently choosing:

- **Pet and group cleanup during linger.** Today disconnect immediately removes the pet
  (`tick.rs` around 960) and group membership (around 974). Recommendation: keep group membership
  for the window so a brief linkdead does not double-vanish the player from the roster, but
  despawn the pet immediately (a linkdead player cannot command it, and an orphaned pet is worse).
  Confirm in build.
- **Worst-case total time.** A hard crash can take up to the 15s netcode timeout to *detect*,
  then about 30s of linger, so up to ~45s before relogin. Measure the linger from detection.
  Acceptable; document it.

## Slice B: `/camp`

1. **Protocol:** append `ClientWorldMsg::Camp` and `ClientWorldMsg::CancelCamp` at the end of the
   enum (bincode is positional). A small server-to-client confirm (accepted / cancelled /
   remaining) so the client countdown stays in sync; reuse a lean message if one fits. Bump
   `WORLD_PROTOCOL_ID`.
2. **Server:** on `Camp`, gate on `conn.is_sitting` (reject with "You must be sitting to camp." if
   standing) and not-already-camping; set `conn.camp_since = now`. Camp sweep: cancel if
   `is_sitting` flips false (covers movement and an explicit stand) or the connection took damage
   since `camp_since`; on completion (`now - camp_since >= CAMP_SECS`) send the clean disconnect
   and reap immediately. `CancelCamp` clears it.
3. **Damage hook:** at the player-damage application path (where PvP and enemy damage reduce a
   connection's hp), clear any in-progress camp so the sweep cancels it.
4. **Client:** a `/camp` command in `hud.gd::_handle_chat_input` next to `/sit` and `/stand`; a
   countdown panel (a simple HUD label or a `DraggablePanel`) driven by the server confirm; block
   movement and abilities locally during the countdown for responsiveness (the server stays
   authoritative); surface "You must be sitting to camp." on rejection.
5. **Relogin UX:** `lobby.gd` already shows the kick reason. Refine a refused relogin to show the
   EQ "you already have a character in this world" plus the `reconnect_after_secs` countdown.

## Constants

Add tunable server constants near `HEARTBEAT_TIMEOUT` in `world/mod.rs`: `LINKDEAD_SECS` (about
30) and `CAMP_SECS` (about 30). The connect-token lifetime only matters if we ever do seamless
resume; v1 fresh-relogin gets a brand new token from the launcher, so there is no token-expiry
edge here.

## Out of scope for v1

- **Seamless reconnect-resume** on a brief network blip (the `server_design.md` 60s model). A
  later enhancement; it needs session resurrection, AOI re-attach, and connect-token juggling.
- **Corpse interactions** for a killed linkdead character (blocked on the corpse system, an
  existing to-do).

## Verification (when built)

- **Linkdead, two clients:** A is in-world; kill A's client. A's body lingers about 30s, a mob or
  another player can still hit and kill it, a same-account relogin is refused with a countdown,
  then it reaps and relogin works.
- **`/camp`:** standing, `/camp` is rejected ("You must be sitting to camp."); `/sit` then
  `/camp` starts the countdown; moving or taking a hit cancels it; surviving the full window
  seated logs you out cleanly and you can relog immediately.
- **Server tests** for the camp gate (sit precondition, cancel-on-stand, cancel-on-damage) and the
  linkdead reaper timing.
