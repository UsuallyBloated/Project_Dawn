# Session 2026-07-11 — Seed the XP bar on login

Server-only, branch `fix/xp-leveling-overflow`. **No wire change, no DLL rebuild, no client
change.** BUILT + 163 lib tests green, **awaiting playtest** (`xp_seed_checklist.md`) — not
committed. Micro-follow-up surfaced by the disconnect-flush playtest.

## The bug

On login the XP bar read `0/X` until the first kill snapped it to the real total. Persistence
was fine (the disconnect-flush fix saved the XP correctly) — the client just never learned its
loaded value: `ConnectOk` carries `{name, race, class, level}` but no XP, so `apply_character`
leaves `PlayerStats.xp = 0` and nothing seeds it until an `XpGained` arrives.

## Fix

One block in the enter-world seed pass (tick.rs), right beside the coins seed (whose comment
describes the identical "client sits at default 0 until synced" class): send
`XpGained { amount: 0, current: conn.xp, to_next: conn.xp_to_next }` to the new joiner. The
client's `apply_remote_xp` sets the bar absolutely and only prints a combat line when
`amount > 0` (and the loss line only when `amount < 0`), so `amount = 0` seeds it silently.
Reuses the existing `XpGained` message — no protocol bump.

## Verification

`cargo build` clean; 163 lib tests green. In-game login-bar behavior is the playtest's job.
