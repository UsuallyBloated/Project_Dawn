# Live Relogin Countdown Playtest Checklist — 2026-10-15

When a login is refused because your character is still in the world (you closed the game with
the window X, crashed, or dropped, and the body lingers about 30 seconds), the lobby used to
show the server's one-shot estimate, "You can try again in about 27s.", which never moved. It
now counts down live: "You can log in again in 27 s.", then 26, ... and ends on "You can log in
again now." **Needs the next export with the rebuilt `gdext_net.dll`** (the Oct 22 bump-day
build); the server needs nothing (it has sent the seconds since the duplicate-login refusal was
built). Run `godot --headless --path . -s tools/check_wire_layer.gd` on the export's checkout
first; it must list `kick_retry_after` as OK.

Diagnostics: `server.log` has `duplicate login refused — account already in-world` with
`reconnect_after_secs=Some(N)`; `debug.log` has `Net: kicked code=DuplicateLogin`. A refusal
in the first ~10 seconds after the window X gets no answer at all (the old connection still
holds the slot until the heartbeat times out): that is expected, try again.

## Setup
- [ ] The next export, with `check_wire_layer.gd` listing `kick_retry_after` OK
- [ ] One account and character

## 1 — The countdown
- [ ] **Enter the world, close the game with the window X, relaunch, and log in after about 12 seconds** → the lobby says "Disconnected: You already have a character in this world. You can log in again in N s." with N about 15 to 20, and the number drops by one each second. notes:
- [ ] **The old "You can try again in about Ns." sentence** → not shown beside the countdown. notes:
- [ ] **Watch it to the end** → it settles on "You can log in again now." and stops changing. notes:
- [ ] **Relaunch and log in once it says now** → the login succeeds. notes:

## 2 — Kicks with no time
- [ ] **Log in on a second client while the first is still in the world and playing** → refused with "You already have a character in this world." and no countdown (a live session has no end time; log the other one out). notes:
- [ ] **(Optional, needs SSH) Ban a throwaway account while it is in the world** → the in-world notice shows the ban reason; no countdown anywhere. Unban after. notes:

## 3 — The old wire layer (optional)
- [ ] **A client on the pre-bump DLL** → the lobby shows the server's "about Ns" sentence exactly as before; nothing else changes. notes:

## Notes / observations
-
