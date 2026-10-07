# Scale Readiness Playtest Checklist — 2026-09-30

Two server-side fixes to the enemy position stream and the AOI grid, both built 2026-09-30
(server `ac38cc2` "Enemy positions fan on change plus a 500 ms keepalive", `c121341`
"Enemy and pet cell crossings fan spawn and despawn", and the review fixes `818a902`).
**Server-only: restart the
R720 on the new build; no client re-export is needed.** The first cuts an idle mob's Position
stream from 20 messages per second per visible player to 2 (it fans on movement or a turn,
plus a 500 ms keepalive). The second makes a mob or pet that walks INTO your 3x3 cell
neighbourhood appear (it used to stay invisible until you re-entered the world) and one that
walks out disappear. A third gap closed with it: walking into view of a friend's EXISTING pet
now shows the pet.

| Thing | Value | Where |
|---|---|---|
| Position keepalive | 500 ms (`ENEMY_POSITION_KEEPALIVE`) | `world/mod.rs` |
| Report line | `enemy position fan sent=N window_secs=60 enemies_alive=E players_in_world=P`, once a minute while anyone is online | `server.log` |
| What the old stream would have been | `E x P x 20 x 60` for the same window | arithmetic |
| AOI cell | 120 m; you see the 3x3 of cells around your own (~360 m square) | `world/aoi.rs` |

Diagnostics: `server.log` for the `enemy position fan` line. The in-game console shows nothing
new; these fixes are invisible when they work, which is the point of §1 and §3.

## Setup
- [x] Restart the R720 on the new build (`journalctl -u projectdawn -n 20` shows the new `build=` sha and `dev_cmds=false`) notes: every build on the R720 since 10-05 (`c0046af`, `6a802f4`, `e3a6fa8`) carries these fixes; `dev_cmds=false` on each boot line.
- [x] One character logged in and standing in town notes: the 10-06 and 10-07 sittings, one seat throughout.

## 1 — The stream is measured, not eyeballed
Filled 2026-10-07 from the journals of the two previous sittings (`GAME_LOG_charm_return_checklist.md` and the 10-06 paste); no separate sitting was needed.
- [x] **Stand idle in town for two full minutes, then read two consecutive `enemy position fan` lines from `server.log`** → `sent` is on the order of `enemies_alive x 2 x 60` (about a tenth of the old `enemies_alive x 20 x 60`); paste both lines here. notes: 2026-10-06, Caderyn idle in town after a cast: `20:46:16 enemy position fan sent=5060 window_secs=60 enemies_alive=54 players_in_world=1`, `20:47:16 ... sent=5060 ...`, `20:48:16 ... sent=5060 ...`. Steady at about 5,000 a minute for 54 mobs; the old stream for the same window would have been 54 x 20 x 60 = 64,800. Below the `x 2 x 60` estimate (6,480) because mobs in cells nobody can see cost nothing. The 10-07 idle stretch (16:41 to 16:48) sat between 4,928 and 5,016 every minute.
- [x] **Walk through a camp so several mobs chase you, then read the next line** → `sent` rises while they chase (a moving mob fans every tick) and falls back once they leash. notes: 2026-10-07, the Dire Wolf fight and first charm: `16:37:29 sent=5821`, `16:38:29 sent=6019`, then `16:39:29 sent=5311`, `16:40:29 sent=4889`. Again at the cave bats, `17:06:32 sent=6150` then `17:07:32 sent=4705`, and `17:51:33 sent=6295` then `17:52:33 sent=5491`. A mob moving for a full minute adds about 1,200 (20 a second), which is the size of each bump; each falls back to the 4,900 baseline the next minute.

## 2 — Regression: mobs move the way they did
- [ ] **Pull a mob and kite it in a circle** → it follows smoothly; no stutter or rubber-banding compared to before. notes:
- [ ] **Let it catch you and stand still** → it stops where it caught you and faces you; no sliding, no drifting back. notes:
- [ ] **Kill it** → the body drops where it died, as before. notes: (Claude, 10-07: you have killed dozens on this build across two sittings with the loot bags where the bodies fell; tick it if nothing looked off.)
- [ ] **Stand next to an idle camp for a minute** → the mobs stay exactly where they are (no twitch every half second). notes: (Claude, 10-07: the Bonepile head-count across a 60 s charm on the charm sheet is exactly this situation; tick it if the skeletons stood still while you counted.)
- [ ] **Watch a resting mob START to move (aggro one from range, or watch one leash home)** → it starts moving cleanly, with no slow wind-up and no visible jump. (Corrected 2026-10-02: an earlier version of this row predicted a half-second ease-in. Reading the client's interpolation showed the real effect is a one-off nudge of about one tick's travel, 10 to 25 cm depending on the mob, as it sets off, which should not be visible. Say so if it is.) notes: (Claude, 10-07: the Wild Boar coming from 22 m on the ported-spells sheet, and the returned charm walking home, are both this; tick it if neither jumped or crawled as it set off.)

## 3 — Things that walk into view appear (two seats)
- [ ] **Partner with a pet (a Beast Master warder or a Necromancer skeleton) logs in far from you, beyond ~360 m, and walks toward you** → the moment they appear, their pet appears WITH them; not later, not never. notes:
- [ ] **Same partner walks away until they vanish** → the pet vanishes with them. notes:
- [ ] **Partner summons a pet while out of your view, then YOU walk toward them** → when they come into view the pet is already there (the third gap: walking into view of an existing pet used to show nothing). notes:
- [ ] **A mob chasing your partner across a camp edge into your view** → it appears mid-chase with a name and health bar. Hard to stage on purpose; mark `[-]` if it never comes up, the integration test `enemy_crossing_a_cell_boundary_spawns_and_despawns_for_players` is the evidence. notes:

## 4 — Your own pet stays with you (one seat; needs the 2026-10-02 server build, `43dc287` or later)
Before this build, walking about 240 m from a parked pet dropped it from your pet panel and killed every `/pet` command until you walked back.

- [ ] **Summon or auto-summon a pet, `/pet guard`, then walk away well past 300 m (use `/loc` to measure)** → the pet panel keeps its name and health the whole way; no "pet dismissed" moment. notes:
- [ ] **From out there, `/pet follow`** → "Your pet follows you." and the pet comes running; it arrives beside you. notes:
- [ ] **Park it again, walk far away, then kill something near you** → the pet's health bar on the panel is untouched (it is still parked); `/pet attack` on a mob near you brings it running to fight. notes:
- [ ] **Regression: let the pet die, or re-summon over it** → the panel clears or swaps as before. notes:

## Notes / observations
-
