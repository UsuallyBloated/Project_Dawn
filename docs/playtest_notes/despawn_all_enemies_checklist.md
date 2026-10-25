# Despawn All Enemies Playtest Checklist — 2026-10-19

The Test Panel's **Despawn All Enemies** used to free only your own client's copies of the mobs:
they vanished from your screen and stayed in the world, still fighting everyone else and still
able to hit you, invisible (To-Do "Test Panel 'Despawn All Enemies' leaves enemies invisible",
reported 2026-07-20). Online it now asks the server, which removes every enemy in your view and
says how many went. "In view" is the server's own neighbourhood around you: everything within
120 m for certain, and up to about 240 m depending on where you stand in the grid. Pets
(yours, a group-mate's, a charmed mob) are never touched. It is a removal, not a kill: no XP, no
loot, no corpse. Camp mobs respawn on their camp's normal timer.

**Needs the Oct 22 bump (server and export together):** the new request is part of PD_W0028.
On the export's checkout, `godot --headless --path . -s tools/check_wire_layer.gd` must list
`send_dev_despawn_enemies` as OK. A GM account (`grant_gm`), since the panel mounts only for one.

Diagnostics: `server.log` has `dev despawn enemies` with `count`; `admin_report` shows a
`dev_despawn_enemies` row per press in the GM action audit. On a build whose wire layer lacks
the send, the button prints "TestPanel: this build's wire layer cannot despawn enemies online."
instead.

## Setup
- [ ] The Oct 22 redeploy and export (`check_wire_layer.gd` lists `send_dev_despawn_enemies` OK)
- [ ] A GM account with the Test Panel showing (`/testpanel` if it is hidden)
- [ ] For §2, a second seat (two-boxing works), ideally a Beast Master for the warder row

## 1 — The mobs really go
- [ ] **Spawn two mobs with the Test Panel, then press Despawn All Enemies** → both vanish at once and chat says "Despawned N enemies." (N at least 2; mobs at nearby camps count too). notes:
- [ ] **Stand where they were and press Tab** → nothing to target; nothing hits you over the next half minute. notes:
- [ ] **Do it beside a camp** → the camp empties, and its mobs come back on the camp's usual respawn timer, not at once and not never. notes:
- [ ] **Press it with nothing around** → "Despawned 0 enemies." and nothing else happens. notes:

## 2 — What it leaves alone
- [ ] **A second seat beside you watching** → their screen loses the same mobs at the same moment (before, they still saw and fought them). notes:
- [ ] **A pet in view (the second seat's warder, or your own)** → stays, still follows and fights. notes:
- [ ] **A charmed mob in view** → stays under its charmer (it is a pet); when the charm ends it comes back as usual. notes:
- [ ] **A mob's corpse you have not looted yet** → still there and lootable. notes:
- [ ] **The second seat far off (300 m or more) fighting a mob** → their fight carries on; the button only reaches your neighbourhood. notes:

## 3 — The record
- [ ] **After a press, run `admin_report` on the R720** → the newest GM action row reads `dev_despawn_enemies` with your position. notes:

## Notes / observations
-
