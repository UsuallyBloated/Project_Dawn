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
- [ ] Restart the R720 on the new build (`journalctl -u projectdawn -n 20` shows the new `build=` sha and `dev_cmds=false`)
- [ ] One character logged in and standing in town

## 1 — The stream is measured, not eyeballed
- [ ] **Stand idle in town for two full minutes, then read two consecutive `enemy position fan` lines from `server.log`** → `sent` is on the order of `enemies_alive x 2 x 60` (about a tenth of the old `enemies_alive x 20 x 60`); paste both lines here. notes:
- [ ] **Walk through a camp so several mobs chase you, then read the next line** → `sent` rises while they chase (a moving mob fans every tick) and falls back once they leash. notes:

## 2 — Regression: mobs move the way they did
- [ ] **Pull a mob and kite it in a circle** → it follows smoothly; no stutter or rubber-banding compared to before. notes:
- [ ] **Let it catch you and stand still** → it stops where it caught you and faces you; no sliding, no drifting back. notes:
- [ ] **Kill it** → the body drops where it died, as before. notes:
- [ ] **Stand next to an idle camp for a minute** → the mobs stay exactly where they are (no twitch every half second). notes:
- [ ] **Watch a resting mob START to move (aggro one from range, or watch one leash home)** → it starts moving cleanly, with no slow wind-up and no visible jump. (Corrected 2026-10-02: an earlier version of this row predicted a half-second ease-in. Reading the client's interpolation showed the real effect is a one-off nudge of about one tick's travel, 10 to 25 cm depending on the mob, as it sets off, which should not be visible. Say so if it is.) notes:

## 3 — Things that walk into view appear (two seats)
- [ ] **Partner with a pet (a Beast Master warder or a Necromancer skeleton) logs in far from you, beyond ~360 m, and walks toward you** → the moment they appear, their pet appears WITH them; not later, not never. notes:
- [ ] **Same partner walks away until they vanish** → the pet vanishes with them. notes:
- [ ] **Partner summons a pet while out of your view, then YOU walk toward them** → when they come into view the pet is already there (the third gap: walking into view of an existing pet used to show nothing). notes:
- [ ] **A mob chasing your partner across a camp edge into your view** → it appears mid-chase with a name and health bar. Hard to stage on purpose; mark `[-]` if it never comes up, the integration test `enemy_crossing_a_cell_boundary_spawns_and_despawns_for_players` is the evidence. notes:

## Notes / observations
-
