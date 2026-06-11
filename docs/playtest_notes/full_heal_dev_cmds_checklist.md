# Full Heal / Dev Commands Playtest Checklist — 2026-06-11

Confirms the Test Panel's dev commands actually take effect server-side now that the server
is launched with `PD_DEV_CMDS=1` (previously `HealSelf` / `DamageSelf` were silently dropped
— "Full Heal is a lie"). **Re-export Project_Dawn; server must be running with
`$env:PD_DEV_CMDS=1` set before `cargo run`.**

Tip: each successful Full Heal logs `dev full restore (hp/mp/stamina)` in `server.log`; each
Damage Self logs `dev heal self` / a damage line. If you DON'T see those, the env var didn't
take (wrong session / server not restarted).

## Setup
- [x] Re-export Project_Dawn
- [x] Server running with `PD_DEV_CMDS=1` (same PowerShell session, set before `cargo run`)
- [x] One client logged in, in-world

## 1 — Full Heal restores HP **server-side** (sticks)
- [x] Take damage (pull an enemy, or Damage Self) to drop HP well below max. notes:
- [x] Click **Full Heal** → HP rises to max **and stays** (doesn't snap back on the next
  server tick like it used to). notes:
- [x] `server.log` shows `dev full restore (hp/mp/stamina)` for that click. notes:

## 2 — Full Heal restores MANA server-side (the real test)
- [x] Drain mana: cast spells until low (watch for "Cast failed: Not enough mana"). notes:
- [x] Click **Full Heal** → MP bar fills. notes:
- [x] **Immediately cast an expensive spell** (e.g. Summon Skeleton / Greater Heal) → it
  **succeeds** (no "insufficient mana"). This proves the *server's* mana was restored, not
  just the client bar. notes:
- [x] `server.log` shows **no** `insufficient mana` rejection right after the Full Heal. notes:

## 3 — Damage Self (the other dev command)
- [x] Click **Damage Self** → HP drops and **stays** dropped (server applied it, not just a
  local flicker). notes:

## Notes / observations
-Great work!
