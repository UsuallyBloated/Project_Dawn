# Handoff: Camp and Linkdead (deliberate + involuntary logout)

Status: design locked 2026-06-19, not started. Full spec:
`docs/design/camp_and_linkdead.md`. This is the actionable checklist; read the design doc for the
why and the grounded code pointers.

## The model in one line

A character must remain in the world about 30s before it leaves. Voluntary via `/camp` (sit,
watch a 30s countdown, vulnerable, then clean logout), involuntary via linkdead (a crash leaves
the body in-world and killable for ~30s, relogin refused meanwhile, then it reaps). Sits on top
of the one-character-per-account deny-login already built.

## Locked decisions

- Linkdead character is VULNERABLE (targetable + killable) for the window.
- `/camp` requires the player to be SITTING; cancelled if the character MOVES or TAKES DAMAGE.
- v1 is wait-then-fresh-login. No seamless reconnect-resume. Relogin during the window is refused
  with "You already have a character in this world."
- Window is a tunable server constant (~30s), not a magic number.

## Already in place (do not rebuild)

- Deny-login: `world/tick.rs` ~756-769 (refuses the duplicate login, never boots the live session).
- Server-authoritative sit state: `conn.is_sitting` (`connection.rs:171`), set by `Sit`/`Stand`
  (`handlers.rs:701-720`), auto-cleared on movement integration. The whole camp cancel rule maps
  onto this flag plus a damage event.
- `ServerWorldMsg::Kick` already carries an unused `reconnect_after_secs: Option<u32>` for the
  countdown.

## Slice A: server linkdead linger + reap

- [ ] Add `linkdead_since: Option<Instant>` to `PerConnection`; add `LINKDEAD_SECS` (~30) to
  `world/mod.rs`.
- [ ] On an UNCLEAN (timeout) disconnect, mark linkdead instead of despawning: keep in
  `connections` with `in_world = true` (stays in targeting snapshots and the AOI grid), freeze
  movement. A CLEAN `Disconnect` (Quit / camp complete) reaps immediately (current path).
- [ ] Reap sweep: when `now - linkdead_since >= LINKDEAD_SECS`, run the existing disconnect
  cleanup (despawn fan, pet/group cleanup, DB flush, remove).
- [ ] Decide at build: keep group membership for the window (recommended), despawn pet immediately.
- [ ] Relogin refusal already fires via deny-login; populate `reconnect_after_secs`.

## Slice B: /camp

- [ ] Protocol: append `ClientWorldMsg::Camp` + `CancelCamp` at the enum END; add a server confirm
  message for the countdown; bump `WORLD_PROTOCOL_ID`. Rebuild the gdext DLL.
- [ ] Server: gate `Camp` on `conn.is_sitting` ("You must be sitting to camp."); track `camp_since`;
  cancel sweep on `is_sitting == false` (move/stand) or a damage event since `camp_since`; on
  completion send the clean disconnect + reap. Add `CAMP_SECS` (~30).
- [ ] Damage hook: clear an in-progress camp at the player-damage application path.
- [ ] Client: `/camp` in `hud.gd::_handle_chat_input` (next to `/sit`/`/stand`); a countdown panel;
  block input locally during the countdown; show the "must be sitting" rejection.

## Cleanup / reconcile

- [ ] Replace the stale `server_design.md:615-619` reconnect section (60s frozen, untargetable,
  seamless) with this vulnerable wait-then-relog model.

## Verify

- Two clients: kill A's client, A's body lingers ~30s and is killable, relogin refused with a
  countdown, then reaps and relogin works.
- `/camp`: standing rejects; sitting then `/camp` runs 30s; move or take a hit cancels; survive
  seated logs out clean and relogs at once.
- Server tests for the camp gate and the reaper timing.

## Note from this session

The 2026-06-19 banker playtest "kill A's client then relog" row actually exercised a CLEAN close
(window X, which sends a clean `Disconnect`), so the account freed immediately and relogin
succeeded. That is correct deny-login behavior. A true hard-kill (Task Manager) is what leaves a
stale session for the netcode timeout, and is exactly the case this linkdead track makes a
deliberate ~30s.
