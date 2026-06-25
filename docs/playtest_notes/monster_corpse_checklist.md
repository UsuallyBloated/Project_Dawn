# Monster Orb to Corpse — Playtest Checklist — 2026-06-24

The golden loot orbs are gone: a slain creature now leaves a **body** (the same gray capsule a player
corpse uses) with a white **"<creature>'s corpse"** nameplate. Loot mechanics are UNCHANGED, it's the
same loot bag underneath (group rights, round-robin, coin split, 120s linger, despawn-when-empty), just
re-skinned. A player-DROPPED item still drops the old golden **sack** (no creature died). Wire is now
**PD_W0021**. Per-creature model + size is still deferred; every body is the same generic capsule for now.

**Build prerequisites (all three):**
- Re-export / reload Project_Dawn, then reload the Godot editor so the rebuilt `gdext_net.dll` (PD_W0021)
  loads.
- Restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:/Projects/server`.
  No new migration.
- Old PD_W0020 clients/servers will refuse to talk. Capture: `... | Tee-Object server.log`.

| Rule | Value |
|---|---|
| Creature death | leaves a body ("<creature>'s corpse", white nameplate), not a golden orb |
| Loot | unchanged — click to open the same loot window; group rights / round-robin / coin split intact |
| Despawn | unchanged — empties when looted clean, else 120s linger (EntityDespawn) |
| Player-dropped item | still a golden **sack** (creature_name empty -> not a body) |
| Player corpse | still a body, now a **white** nameplate (was reddish) |
| Per-creature model/scale | NOT yet — all bodies are the same generic capsule |

## Setup
- [x] Re-export client, reload editor (PD_W0021 DLL), restart server. notes:

## 1 — Creature leaves a body
- [x] Kill a mob that drops loot -> a **gray body** appears where it died (NOT a floating golden orb), with
  a white **"<creature>'s corpse"** nameplate. notes: 
- [x] The nameplate reads the creature's actual name (e.g. "a plague rat's corpse" / "Skeleton's corpse"),
  matching how that mob is named. notes:
- [x] Kill two DIFFERENT creatures -> each body shows its OWN name. notes:

## 2 — Looting is unchanged
- [x] Click the body -> the **same loot window** opens; Take / Take All work; items land in your bags. notes:
- [x] Coin on the body still credits/splits to the group exactly as the orb did. notes:
- [x] The body **despawns** when looted clean, and an un-looted body despawns after ~120s. notes:
- [x] In a group, loot rights / round-robin behave exactly as before (no regression from the re-skin). notes:

## 3 — Player-dropped item stays a sack
- [x] Drop an item to the ground (if your build supports it) -> it appears as the **golden sack**, NOT a
  body (no creature died). Still lootable. notes:  (skip if item-drop isn't reachable in your build)

## 4 — Player corpse regression (Slice 2)
- [x] Die -> your corpse still appears as a body and now reads **"<your name>'s corpse" in white** (was a
  reddish tint). notes: So cool.  When do we implement the player being respawned back at their bind location? Make note of it and we can talk about it later.
- [x] Your corpse still loots + despawns exactly as in the corpse-run slice. notes:
- [x] You can tell your own corpse from a nearby monster body by the **name** (both are white now). notes:

## Notes / observations
- I would really like if your equipment automatically re-equipped.  Let me know what you think.
