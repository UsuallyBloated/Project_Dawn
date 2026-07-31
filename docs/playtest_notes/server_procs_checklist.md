# Server-Authoritative Weapon Procs Playtest Checklist — 2026-07-30

Procs are now server-authoritative (PD_W0025). The server rolls `proc_chance` on each landed melee
swing, applies `proc_damage` itself (folded into the same swing's death cascade), and sends a
`ProcTriggered` message; the client renders the flavored "<proc_name> for N (Critical!)" hit from
that. The client no longer rolls or sends procs. Also fixes a live bug: Flamebrand was mis-tagged
ICE and now correctly procs FIRE.

**Build prereq (this one is heavier — the GDExtension changed):**
- [x] Rebuild the gdext GDExtension: run `addons/gdext_net/build.ps1` (rebuilds `gdext_net.dll` from the
  server crate + copies it into the addon). REQUIRED — the new `proc_triggered` signal lives in it.
- [x] Re-export Project_Dawn (GDScript changed too).
- [x] Rebuild + restart the server (release build).

> **Only proc weapon today: Flamebrand** (`proc_chance` 0.15, `proc_damage` 25, "Flaming Strike",
> FIRE). Get it with `/give` (dev) + equip via the paperdoll (server-side equip). Diagnostic:
> `server.log` is clean of errors; the proc has no dedicated log line server-side (it's a wire
> message), so the evidence is in-game.

## Setup
- [x] gdext rebuilt, client re-exported, server restarted
- [x] `/give` Flamebrand and equip it (main hand); have an enemy to fight

## 1 — Proc fires + shows the flavor (the headline)
- [x] **Auto-attack an enemy with Flamebrand for ~30-60s** → roughly 1 in 7 swings, a proc fires:
  a floating proc number + a **FIRE** flash + a combat-log line "Flaming Strike for 25 damage."
  notes:
- [x] **Occasionally the line reads "Flaming Strike for N damage (Critical!)"** (flat 5% crit, N ~38-50).
  notes:
- [x] **The flash is FIRE-colored, not ice** (the mis-tag fix). notes:

## 2 — Damage is real + authoritative
- [x] **The mob's HP drops by swing + proc** on a proc'd swing (not just the swing). notes:
- [x] **No double number / double proc** — one swing number + (on a proc) one proc number; the proc
  isn't applied twice. notes: It seems like the weapon might be hitting and proc-ing at the same time.  please look into this.

## 3 — Proc killing blow (the correctness case)
- [x] **Let a proc land the killing blow** (whittle a mob low, then a proc finishes it) → the mob
  dies, you get XP + loot exactly once (no missing loot, no "zombie" mob that won't die). notes: I think this worked correctly.  Please confirm if you can.

## 4 — Regression: normal weapons + spells unaffected
- [x] **Fight with a NON-proc weapon (e.g. iron short sword)** → no procs, normal swings, no change.
  notes:
- [x] **Cast a damage spell** → spells still apply damage + kill + loot normally (the proc path
  didn't disturb the spell path). notes:

## 5 — Dual-wield (per-hand)
- [x] **Dual-wield Flamebrand in one hand + a plain weapon in the other** → the Flamebrand hand
  procs, the plain hand doesn't; both swing normally. notes:

## Notes / observations
> Deploy note (not testable here): the PD_W0025 wire bump is a marker, not a connection gate — a
> stale client would connect and just not render procs (no crash). To refuse out-of-date clients on
> a real host, raise the auth `min_client_version` when you ship the new client build.
-
