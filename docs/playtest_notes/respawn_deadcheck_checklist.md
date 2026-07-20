# Respawn Dead-Check Playtest Checklist — 2026-07-19

Verifies exploit-audit **finding 3**: the server now refuses a `Respawn` from a **living**
player (the exploit spammed `Respawn` to floor HP at 25% for near-invulnerability), while a
dead player's respawn is unchanged. Server-only change (`handlers.rs`, gate on
`death_processed`), server commit `0d908d1`; **no client/DLL/wire change, so no re-export**.

The **exploit-closed side is covered automatically** by the integration test
`world_two_clients.rs::respawn_requires_being_dead` (green): a living player's `Respawn` does
NOT floor HP; a dead player's still restores ~25%. A stock client only sends `Respawn` after
death, so this manual pass is the **regression check** that normal death/respawn still works.

**Run:** server on `fix/xp-leveling-overflow` at `0d908d1` or later (dev on or off, doesn't
matter here). `server.log` anchors: the death sweep / `DeathBroadcast`, then the respawn.

## 1 — Normal death and respawn still works (the regression that matters)
- [x] **Die** — walk into a mob and let it kill you, or Test Panel **"Trigger Death"**. notes:
- [x] After the client respawn timer, you **respawn ALIVE at ~25% HP / 25% MP / 50% stamina**,
  naked, at your bind. notes: Right now there is no bind-point and players respawn exactly where they died, which isnt great.  Also the player can still move the character after death.  Let me know what you think of this.  It's probably an entire project in itself.
- [x] A **corpse** is left where you died; you can walk back and loot it. notes:
- [x] **Repeat once** (die → respawn) to confirm it's reliable across deaths. notes:

## 2 — HP / regen behave normally after respawn
- [x] After respawning at ~25%, **HP regenerates** back up over time (sit to speed it). notes:  HP and MP regen are still disabled, which is fine.  The way it is now works well with testing.
- [x] You can **take damage and die again** normally (the death penalty applies each time). notes:

## 3 — Exploit closed (needs a modified client; otherwise the integration test covers it)
- [-] *(Only if you can send a raw `Respawn` while ALIVE)* → nothing happens; HP is **NOT**
  floored to 25%. Stock clients only send `Respawn` after death, so this side is proven by the
  green integration test `respawn_requires_being_dead`, not reachable from the normal UI. notes:

## Notes / observations
- "Despawn All Enemies" on the test panel does NOT despawn enemies, instead they are invisible.
